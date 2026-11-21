class_name BmpDriver
extends RefCounted

# The driver-mechanic bot: he works the same controls as the player — the
# battery switch and the starter, the main clutch pedal, the gear lever, the
# yoke, the fuel and brake pedals. He follows a route by looking ahead along
# it, picks the gear for the speed he wants (first only from a standstill,
# a low gear for sharp turns), eases the clutch out without stalling and
# reverses off an obstacle that stops him.
var vehicle: BmpVehicle
var route := PackedVector3Array()
var lengths := PackedFloat32Array()
var progress := 0.0
var cruise := 7.0
var arrive := 2.5
var cap := INF
var arrived := true
var hold := true
var wanted_gear := -1
var shift_phase := 0.0
var launch := 0.0
var stuck := 0.0
var backing := 0.0
var back_yoke := 0.0
var reverse_mode := false
var stopped_time := 0.0
var target_speed := 0.0
var heading_error := 0.0
# The way he turns round to a point behind: kept once chosen, so that a
# target straight astern does not flick the yoke from side to side.
var turn_side := 0.0
# Wanting to move and not moving, whatever the pedals do.
var blocked := 0.0
var backing_forward := false
var backing_from := Vector3.ZERO
# Backing off again and again at the same place of the route: something
# there will not give (the squad then marks it and drives round).
var jams := 0
var jam_progress := -INF
var jam_point := Vector3.ZERO
# Over a heap of rubble he crawls in first gear: from a little before the
# bow reaches it until the stern is off.
const RUBBLE_SPEED := 2.5

func setup(owner: BmpVehicle) -> void:
 vehicle=owner

func set_route(points: PackedVector3Array, speed: float, finish: float=2.5) -> void:
 route=points
 cruise=speed
 arrive=finish
 lengths.resize(points.size())
 var total:=0.0
 for i in range(points.size()):
  if i>0:total+=Vector2(points[i].x-points[i-1].x,points[i].z-points[i-1].z).length()
  lengths[i]=total
 progress=0.0
 arrived=points.size()<2
 hold=false
 stuck=0.0
 backing=0.0
 blocked=0.0
 turn_side=0.0
 jams=0
 jam_progress=-INF

func stop() -> void:
 hold=true

func total() -> float:return lengths[-1] if lengths.size()>0 else 0.0

func remaining() -> float:return maxf(0.0,total()-progress)

# Distance along the route of the point nearest to the vehicle, searched a
# little behind and ahead of the last one.
func project(at: Vector3) -> float:
 var best:=progress
 var best_distance:=INF
 var here:=Vector2(at.x,at.z)
 for i in range(route.size()-1):
  if lengths[i+1]<progress-15.0:continue
  if lengths[i]>progress+40.0:break
  var a:=Vector2(route[i].x,route[i].z);var b:=Vector2(route[i+1].x,route[i+1].z)
  var ab:=b-a
  var t:=clampf((here-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
  var d:=here.distance_to(a+ab*t)
  if d<best_distance:best_distance=d;best=lengths[i]+ab.length()*t
 return maxf(best,progress)

# Distance along the route of the point nearest to a position, within a
# window of the route, and how far off the route the position is.
func locate(at: Vector3, low: float, high: float) -> Vector2:
 var best:=Vector2(low,INF)
 var here:=Vector2(at.x,at.z)
 for i in range(route.size()-1):
  if lengths[i+1]<low:continue
  if lengths[i]>high:break
  var a:=Vector2(route[i].x,route[i].z);var b:=Vector2(route[i+1].x,route[i+1].z)
  var ab:=b-a
  var t:=clampf((here-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
  var d:=here.distance_to(a+ab*t)
  if d<best.y:best=Vector2(lengths[i]+ab.length()*t,d)
 return best

func point_at(distance: float) -> Vector3:
 if route.is_empty():return vehicle.global_position
 if distance<=0.0:return route[0]
 for i in range(route.size()-1):
  if lengths[i+1]>=distance:
   var span:=lengths[i+1]-lengths[i]
   return route[i].lerp(route[i+1],(distance-lengths[i])/maxf(span,0.0001))
 return route[-1]

func tick(delta: float) -> void:
 var v:=vehicle
 if v.destroyed:return
 # Starting up: battery on, clutch down, neutral, crank.
 if not v.running:
  v.master=true
  v.throttle=0.0;v.yoke_input=0.0
  v.clutch_pedal=1.0
  if v.gear!=BmpVehicle.NEUTRAL and v.clutch_engagement()<0.15:v.gear=BmpVehicle.NEUTRAL
  if not v.starter:v.begin_crank()
  return
 v.starter=false
 var speed:=v.speed()
 if hold or arrived or route.size()<2:
  stand(delta,speed)
  return
 progress=project(v.global_position)
 var left:=remaining()
 if left<arrive and absf(speed)<0.6:
  arrived=true
  stand(delta,speed)
  return
 v.parking=false
 # Look ahead along the route, further at speed.
 var ahead:=clampf(4.5+absf(speed)*1.3,5.0,20.0)
 var aim:=point_at(progress+ahead)
 if left<ahead:aim=route[-1]
 var local:=v.global_basis.inverse()*(aim-v.global_position)
 heading_error=atan2(local.x,-local.z)
 if absf(heading_error)>2.4:
  if turn_side==0.0:turn_side=signf(heading_error) if absf(heading_error)<3.0 else (1.0 if randf()<0.5 else -1.0)
  heading_error=turn_side*absf(heading_error)
 elif absf(heading_error)<1.6:turn_side=0.0
 # A target close behind is backed to rather than turned round to.
 reverse_mode=absf(heading_error)>2.3 and left<14.0
 var e:=heading_error
 if reverse_mode:e=-(PI*signf(e)-e)
 var wanted:=clampf(e*2.4,-1.0,1.0)
 if reverse_mode:wanted=-wanted
 target_speed=minf(cruise,cap)
 var sharp:=absf(e)
 if sharp>0.3:target_speed=minf(target_speed,lerpf(cruise,1.8,clampf((sharp-0.3)/0.7,0,1)))
 target_speed=minf(target_speed,sqrt(2.0*1.0*maxf(0.0,left-arrive*0.5))+0.6)
 if rubble_ahead():target_speed=minf(target_speed,RUBBLE_SPEED)
 if reverse_mode:target_speed=minf(target_speed,2.5)
 # Told to wait (a vehicle in the way, the column closing up): stand.
 if cap<0.3 and backing<=0.0:
  stand(delta,speed)
  return
 # Moving off: straight first, the turn once the tracks roll.
 if launch>0.0 or absf(speed)<0.8:wanted=clampf(wanted,-0.5,0.5)
 # Backing off until clear of it: four metres, or as long as it takes.
 if backing>0.0:
  backing-=delta
  if v.global_position.distance_to(backing_from)>4.0:backing=0.0
  wanted=back_yoke
  reverse_mode=not backing_forward
  target_speed=2.0
 # Wanting to go and standing still for long, whatever the pedals did
 # (a wall the clutch keeps stalling the engine against): back off.
 if target_speed>0.8 and absf(speed)<0.3 and shift_phase<=0.0:blocked+=delta
 else:blocked=maxf(0.0,blocked-delta*2.0)
 if blocked>6.0 and backing<=0.0:
  blocked=0.0
  back_off()
 # No way back either: forward the other way round.
 elif blocked>5.0 and backing>0.0:
  blocked=0.0
  backing_forward=not backing_forward
  back_yoke=-back_yoke
  backing=8.0
  backing_from=v.global_position
 steer(delta,wanted)
 drive(delta,speed,target_speed,sharp)

func rubble_ahead() -> bool:
 var district: Node3D=vehicle.game.district
 if not is_instance_valid(district) or not district.has_meta("rubble_cells"):return false
 for reach in [-BmpArt.HALF,0.0,BmpArt.HALF,BmpArt.HALF+4.0,BmpArt.HALF+9.0]:
  if BmpRoutes.on_rubble(district,point_at(progress+reach)):return true
 return BmpRoutes.on_rubble(district,vehicle.global_position)

# Off the obstacle: reverse with the yoke over, so the bow swings toward
# the way on; if it was the reverse that hit something, forward instead.
func back_off() -> void:
 var v:=vehicle
 jams=jams+1 if absf(progress-jam_progress)<5.0 else 1
 jam_progress=progress
 jam_point=v.global_position+(v.global_basis.z if reverse_mode else -v.global_basis.z)*(BmpArt.HALF+1.2)
 stuck=0.0
 backing=8.0
 backing_from=v.global_position
 backing_forward=reverse_mode
 back_yoke=-signf(heading_error) if absf(heading_error)>0.1 else (1.0 if randf()<0.5 else -1.0)
 if backing_forward:back_yoke=-back_yoke

func steer(delta: float, wanted: float) -> void:
 var v:=vehicle
 # Hands on the yoke: it moves at the rate the steering spring allows.
 var diff:=wanted-v.yoke
 v.yoke_input=clampf(diff*6.0,-1.0,1.0) if absf(diff)>0.03 else 0.0
 if absf(wanted)<0.03 and absf(v.yoke)<0.05:v.yoke_input=0.0

# Engine speed a gear would turn at a road speed.
static func revs(gear: int, speed: float) -> float:
 return absf(speed)/BmpVehicle.gear_speed(gear,1.0)

# One gear at a time, as a driver does: up when the engine is high in its
# range, more speed is wanted and the next gear still pulls after the change
# (the vehicle slows while the clutch is out); down when the engine labours.
func best_gear(speed: float, wanted: float, sharp: float) -> int:
 if reverse_mode:return 0
 var magnitude:=absf(speed)
 var gear:=vehicle.gear if vehicle.gear>=2 else 2
 # Fifth is an overdrive for the road: taken only near the top of fourth.
 var top:=2350.0 if gear==5 else 2150.0
 if gear<6 and revs(gear,magnitude)>top and wanted>magnitude+0.4 and revs(gear+1,magnitude-0.4)>1050.0:gear+=1
 elif gear>2 and revs(gear,magnitude)<1000.0:gear-=1
 # Faster than wanted by a lot in a high gear: a lower one brakes with
 # the engine on the way down.
 elif gear>3 and magnitude>wanted+2.5 and revs(gear-1,magnitude)<2300.0:gear-=1
 if (sharp>0.55 or absf(vehicle.yoke)>0.6) and gear>3:gear=3
 return gear

func drive(delta: float, speed: float, wanted: float, sharp: float) -> void:
 var v:=vehicle
 var gear:=best_gear(speed,wanted,sharp)
 # Changing direction: stop first.
 if (gear==0 and speed>0.4) or (gear>=2 and speed<-0.4):
  v.throttle=0.0;v.brake_pedal=1.0;v.clutch_pedal=1.0
  return
 if gear!=v.gear and shift_phase<=0.0:
  # First and reverse only from a standstill (no synchronizers).
  if (gear==0 or gear==2) and absf(speed)>0.8 and v.gear!=BmpVehicle.NEUTRAL:gear=v.gear
  elif gear!=v.gear:
   wanted_gear=gear
   shift_phase=0.55
 if shift_phase>0.0:
  shift_phase-=delta
  v.throttle=0.0
  v.clutch_pedal=1.0
  if shift_phase<0.3 and wanted_gear>=0 and v.gear!=wanted_gear:
   v.gear=wanted_gear
   if absf(speed)<0.5:launch=1.0
  if shift_phase<=0.0:wanted_gear=-1
  return
 var error:=wanted-absf(speed)
 # Easing out the clutch from a standstill, holding the revs up.
 if launch>0.0:
  if v.rpm()>950.0:launch=maxf(0.0,launch-delta*0.9)
  # The engine sags under the load: the clutch back down, at once if it
  # is about to die.
  elif v.rpm()<620.0:launch=1.0
  elif v.rpm()<720.0:launch=minf(1.0,launch+delta*3.0)
  v.clutch_pedal=lerpf(0.25,1.0,launch)
  v.throttle=0.6 if v.rpm()<1300.0 else 0.3
  v.brake_pedal=0.0
  if absf(speed)>1.2:launch=0.0
 else:
  v.clutch_pedal=0.0
  v.throttle=clampf(0.3+error*0.45,0.0,1.0) if error>-0.4 else 0.0
  v.brake_pedal=clampf((-error-0.8)*0.35,0.0,1.0)
  # Lugging the engine in too high a gear: change down.
  if v.rpm()<850.0 and v.gear>2 and wanted>0.5:wanted_gear=v.gear-1;shift_phase=0.55
  # About to stall: clutch down and move off again.
  if v.rpm()<700.0 and v.gear==2:launch=1.0
  elif v.rpm()<600.0 and v.gear>2:wanted_gear=v.gear-1;shift_phase=0.55
 # Pushing against something that will not give: back off and try again.
 if v.throttle>=0.3 and v.clutch_engagement()>0.9 and absf(speed)<0.2 and launch<=0.0:stuck+=delta
 else:stuck=maxf(0.0,stuck-delta)
 if stuck>3.0 and backing<=0.0:back_off()

func stand(delta: float, speed: float) -> void:
 var v:=vehicle
 v.yoke_input=0.0 if absf(v.yoke)<0.05 else -signf(v.yoke)
 v.throttle=0.0
 v.brake_pedal=1.0
 v.clutch_pedal=1.0
 launch=0.0
 shift_phase=0.0
 if absf(speed)<0.3:
  stopped_time+=delta
  if v.gear!=BmpVehicle.NEUTRAL:v.gear=BmpVehicle.NEUTRAL
  if stopped_time>1.0:
   v.parking=true
   v.clutch_pedal=0.0
 else:stopped_time=0.0
