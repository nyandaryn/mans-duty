class_name TrackedVehicle
extends RigidBody3D

# A tracked hull: the diesel and its all-speed governor, the starter, the
# main clutch (or the clutches of the gearboxes) on a pedal, the gearbox, the
# steering of one track against the other, the torsion bars on rays, the
# tracks on the ground, and the hull running over men, fences and sheds.
# Each vehicle sets the figures of its own hull in setup (BmpVehicle,
# TosVehicle) and its own law of steering: inner_ratio() and steer_side().
var hull_mass := 0.0
var idle_rpm := 0.0
var governed_rpm := 0.0
var stall_rpm := 0.0
# Overall gear ratios of the gearbox, reverse first, then neutral (0.0).
var gears: Array=[]
var neutral := 1
var final_drive := 1.0
var sprocket := 0.3
var efficiency := 0.82
var engine_inertia := 1.0
var clutch_capacity := 1.0
# Torque curve of the engine: [rpm, N·m] pairs.
var torque_curve: Array=[]
# Internal friction of the engine (N·m at rest and per rpm), the starter's
# torque and the speed below which it turns the engine.
var friction := Vector2(30.0,0.035)
var starter_torque := 230.0
var starter_rpm := 220.0
var catch_rpm := 200.0
var gauge := 2.5
var contact := 3.6
var yaw_inertia := 1.0
var wheel_spring := 1.0
var wheel_damper := 1.0
var ray_top := 0.85
var free_length := 0.95
var travel := 0.32
var frontal_area := 6.5
# Engine recording: the speed it was recorded at.
var recorded_rpm := 1190.0
# The hull's half width and half length for running men over, the width of
# the ram box and the distance of the bow from the centre.
var crush_half := Vector2(1.55,3.3)
var ram_width := 3.0
var ram_half := 3.3
var wheel_radius := 0.37
var wheel_height := 0.44
var sprocket_radius := 0.3

var game: Node3D
var art: Dictionary
var wheel_mounts: Array[Vector3]=[]
var compressions := PackedFloat32Array()
var loads := PackedFloat32Array()
var load_total := 0.0
var ray: PhysicsRayQueryParameters3D
var engine_sound: AudioStreamPlayer3D
var seat_camera: Camera3D
var seat := ""
# Controls, set by the driver: the player or a bot.
var master := false
var running := false
var omega := 0.0
var heard_rpm := 0.0
var heard_open := 0.0
# Readings of the driver's panel within the manuals' normal ranges: coolant
# 75–95 °C, oil pressure 2–8 kgf/cm², 24 V on the batteries and 27–28 V from
# the generator, the bottle of the air start at about 150 kgf/cm². A vehicle
# that has stood the night: the cooling is warm from the heater, the oil
# still cold.
var coolant := 46.0
var oil_temp := 32.0
var oil_pressure := 0.0
var volts := 0.0
var air_bottle := 142.0
var odometer := 2417.3
var engine_hours := 386.2
var starter := false
var crank_left := 0.0
var catching := 0.0
var throttle := 0.0
var hand_throttle := 0.0
var clutch_pedal := 0.0
var brake_pedal := 0.0
var gear := 1
var parking := true
var hatch_open := true
var drive_force := 0.0
var grind := 0.0
var notice := ""
var notice_left := 0.0
var parked_time := 0.0
var paused_velocity := Vector3.ZERO
var paused_spin := Vector3.ZERO
var was_paused := false
var clock := 0.0
var track_phase := 0.0
var surface_check := 0.0
var road := 0.5
var integrity := 1.0
var immobile := false
var destroyed := false
var engine_dead := false
var ram_clock := 0.0
var ram_query: PhysicsShapeQueryParameters3D

# Rays of the road wheels from their mounts (x = ± half the gauge).
func mount_wheels(wheels_z: Array) -> void:
 wheel_mounts.clear()
 for x in [-gauge*0.5,gauge*0.5]:
  for z in wheels_z:wheel_mounts.append(Vector3(x,ray_top,z))
 compressions.resize(wheel_mounts.size());compressions.fill(free_length-(ray_top))
 loads.resize(wheel_mounts.size());loads.fill(0.0)
 ray=PhysicsRayQueryParameters3D.create(Vector3.ZERO,Vector3.DOWN,1,[get_rid()])

func say(text: String, seconds: float=4.0) -> void:
 notice=text;notice_left=seconds

func speed() -> float:return linear_velocity.dot(-global_basis.z)

func rpm() -> float:return omega*60.0/TAU
# The engine speed as heard and as the tachometer shows it: the crankshaft
# locked to the tracks follows every bounce of the running gear, the real
# flywheel and the sound of the exhaust do not.
func steady_rpm() -> float:return heard_rpm

func gear_ratio() -> float:return float(gears[gear])*final_drive

func engine_torque(r: float) -> float:
 for i in range(torque_curve.size()-1):
  if r<=torque_curve[i+1][0]:return lerpf(torque_curve[i][1],torque_curve[i+1][1],(r-torque_curve[i][0])/(torque_curve[i+1][0]-torque_curve[i][0]))
 return 0.0

# The last lamp of the driver's panel (BmpCockpit): lit, title, colour.
func panel_lamp() -> Array:return [false,"",Color.BLACK]

func clutch_engagement() -> float:return clampf((0.75-clutch_pedal)/0.5,0.0,1.0)

func stationary() -> bool:return absf(speed())<0.4

# Ratio of the inner track's speed to the outer one's (1 straight ahead).
func inner_ratio() -> float:return 1.0

# Which way the hull is being turned: −1 left, +1 right, 0 straight.
func steer_side() -> float:return 0.0

# Speed for a gear at an engine speed, m/s (straight ahead).
func speed_in(index: int, engine_rpm: float) -> float:
 var ratio:=float(gears[index])*final_drive
 if ratio==0.0:return 0.0
 return engine_rpm*TAU/60.0/ratio*sprocket

func usable() -> bool:return not destroyed

# --- Driver's controls -----------------------------------------------------
func begin_crank() -> void:
 if starter:return
 starter=true
 crank_left=randf_range(0.8,1.6)
 if not master:say("Спершу вимикач батарей — МАСА (I)",2)

func toggle_parking() -> void:
 parking=not parking;say("Гальма на защіпці (стоянкове) — %s" % ("ЗАТЯГНУТО" if parking else "відпущено"),2);game.sound("click",-12)

# --- Engine, suspension and tracks -----------------------------------------
func simulate_engine(delta: float) -> void:
 if starter and master and not running:crank_left-=delta
 var r:=rpm()
 var open:=0.0
 if running:
  open=maxf(throttle,hand_throttle)
  # All-speed governor: holds the idle and cuts the fuel above the governed speed.
  open=maxf(open,clampf((idle_rpm+40.0-r)/300.0,0.0,0.4))
  if r>governed_rpm:open*=clampf((governed_rpm+150.0-r)/150.0,0.0,1.0)
 var torque:=engine_torque(r)*open if running else 0.0
 torque-=(friction.x+r*friction.y) if omega>0.5 else 0.0
 if starter and master and not running:torque+=starter_torque if r<starter_rpm else 0.0
 var ratio:=gear_ratio()
 var engagement:=clutch_engagement() if ratio!=0.0 else 0.0
 if immobile or destroyed:engagement=0.0
 var k:=inner_ratio()
 # The outer track runs at the gearbox speed; the inner one at k of it.
 var outer:=speed()*2.0/(1.0+k)
 var transmitted:=0.0
 if engagement>0.0:
  var shaft:=outer/sprocket*ratio
  var needed:=torque+engine_inertia*(omega-shaft)/delta
  var capacity:=clutch_capacity*engagement
  if absf(needed)<=capacity:
   transmitted=needed;omega=shaft
  else:
   transmitted=capacity*signf(needed)
   omega+=(torque-transmitted)/engine_inertia*delta
 else:
  omega+=torque/engine_inertia*delta
 omega=maxf(omega,0.0)
 drive_force=transmitted*ratio*efficiency/sprocket*2.0/(1.0+k)
 if catching>0.0:catching-=delta
 if starter and master and not running and rpm()>catch_rpm and crank_left<=0.0 and not destroyed and not engine_dead:
  running=true;catching=1.2;say("Двигун запущено",2)
 if running and ((rpm()<stall_rpm and catching<=0.0) or not master or destroyed or engine_dead):
  running=false
  if master and not destroyed:say("Двигун заглух",3)
 if (running or (starter and master)) and not engine_sound.playing:engine_sound.play()
 elif not running and not starter and engine_sound.playing and rpm()<80:engine_sound.stop()
 heard_rpm=lerpf(heard_rpm,rpm(),1.0-exp(-delta*5.0))
 engine_sound.pitch_scale=clampf(maxf(heard_rpm,160.0)/recorded_rpm,0.2,2.6)
 heard_open=lerpf(heard_open,clampf(open,0,1),1.0-exp(-delta*4.0))
 engine_sound.volume_db=linear_to_db(maxf(game.volume,0.0001))+lerpf(-6.0,4.0,heard_open)-(10.0 if not running else 0.0)+(4.0 if seat=="driver" and hatch_open else 0.0)

func update_gauges(delta: float) -> void:
 var work:=heard_open*clampf(heard_rpm/governed_rpm,0.0,1.0)
 if running:
  coolant=move_toward(coolant,78.0+16.0*work,delta*(0.18+0.5*work))
  engine_hours+=delta/3600.0
 else:coolant=move_toward(coolant,18.0,delta*0.01)
 oil_temp=move_toward(oil_temp,coolant+4.0 if running else 18.0,delta*(0.12 if running else 0.008))
 var press:=0.0
 if running:press=lerpf(2.4,7.6,clampf((heard_rpm-idle_rpm)/(governed_rpm-idle_rpm),0.0,1.0))*(1.15-clampf((oil_temp-40.0)/300.0,0.0,0.25))
 elif starter and master:press=0.6
 oil_pressure=move_toward(oil_pressure,press,delta*6.0)
 var supply:=0.0
 if master:supply=19.5 if starter else (27.6 if running and heard_rpm>650.0 else 24.6)
 volts=move_toward(volts,supply,delta*20.0)
 odometer+=absf(speed())*delta/1000.0

# The road wheels on rays: each is a spring and a damper on its arm.
func suspend(delta: float) -> void:
 var space:=get_world_3d().direct_space_state
 var up:=global_basis.y
 load_total=0.0
 for i in range(wheel_mounts.size()):
  var from:=to_global(wheel_mounts[i])
  ray.from=from;ray.to=from-up*(free_length+0.08)
  var hit:=space.intersect_ray(ray)
  var compression:=0.0
  if not hit.is_empty():compression=free_length-from.distance_to(hit.position)
  var rate:=(compression-compressions[i])/delta
  compressions[i]=compression
  loads[i]=0.0
  if compression<=0.0:continue
  var force:=wheel_spring*compression+wheel_damper*rate
  if compression>travel:force+=wheel_spring*10.0*(compression-travel)
  force=maxf(force,0.0)
  loads[i]=force
  load_total+=force
  apply_force(up*force,from-global_position)

# Road surface under the tracks: 1 asphalt, 0.6 a dirt road, 0 a field.
func surface() -> float:
 surface_check-=get_physics_process_delta_time()
 if surface_check>0:return road
 surface_check=0.5
 var c:=Color(0.5,0.5,0.5)
 var data:=AvdiivkaData.shared() if is_instance_valid(game.district.operation_area) else null
 if absf(global_position.x)<199 and absf(global_position.z)<199:
  if game.district.terrain!=null and game.district.terrain.has_method("surface_color"):c=game.district.terrain.surface_color(Vector2(global_position.x,global_position.z))
  road=1.0 if c.v<0.42 and c.s<0.25 else 0.0
 elif data!=null:road=road_at(data,Vector2(global_position.x,global_position.z))
 else:road=0.0
 return road

# The roads of the operation area in 50 m cells, built on first use.
const ROAD_CELL := 50.0
static var road_cells: Dictionary={}
static var road_source: AvdiivkaData

static func road_at(data: AvdiivkaData, at: Vector2) -> float:
 if road_source!=data:
  road_source=data;road_cells.clear()
  for item in data.features.roads:
   if item[0] in OperationArea.SKIP_ROADS:continue
   var half:float=float(item[1])*0.5+0.6
   var paved:=1.0 if int(item[2])==1 else 0.6
   var line:=AvdiivkaData.pairs(item[3])
   for i in range(line.size()-1):
    var a:=line[i];var b:=line[i+1]
    var low:=Vector2i(floori((minf(a.x,b.x)-half)/ROAD_CELL),floori((minf(a.y,b.y)-half)/ROAD_CELL))
    var high:=Vector2i(floori((maxf(a.x,b.x)+half)/ROAD_CELL),floori((maxf(a.y,b.y)+half)/ROAD_CELL))
    for cx in range(low.x,high.x+1):
     for cz in range(low.y,high.y+1):
      var key:=Vector2i(cx,cz)
      if not road_cells.has(key):road_cells[key]=[]
      road_cells[key].append([a,b,half,paved])
 var best:=0.0
 for item in road_cells.get(Vector2i(floori(at.x/ROAD_CELL),floori(at.y/ROAD_CELL)),[]):
  var closest:=Geometry2D.get_closest_point_to_segment(at,item[0],item[1])
  if closest.distance_to(at)<=float(item[2]):best=maxf(best,float(item[3]))
 return best

func drive(delta: float) -> void:
 if load_total<=1000.0:return
 var up:=global_basis.y
 var forward:=-global_basis.z
 var side:=global_basis.x
 var v:=linear_velocity.dot(forward)
 var lateral:=linear_velocity.dot(side)
 var yaw:=angular_velocity.dot(up)
 var weight:=load_total
 var ground:=surface()
 var grip:=lerpf(0.72,0.9,ground)
 var k:=inner_ratio()
 # Skidding the tracks sideways in a turn (the empirical formula for the
 # turning resistance falls with the radius): it brakes the vehicle and
 # takes engine power, so sharp turns want a low gear.
 var loss:=0.0
 if k<0.999:
  var radius:=gauge*0.5*(1.0+k)/maxf(1.0-k,0.0001)
  var skid:=0.78/(0.925+0.15*radius/gauge)
  loss=skid*weight*contact*0.25*2.0*(1.0-k)/((1.0+k)*gauge)
 # Rolling resistance of tracks: about 0.035 on asphalt, 0.05 on a dirt
 # road, 0.07–0.08 on a field.
 var rolling:=lerpf(0.075,0.035,ground)*weight
 var resist:=rolling+loss+0.5*1.2*frontal_area*v*v
 var brakes:=brake_pedal*grip*weight
 if parking:brakes=maxf(brakes,grip*weight)
 if immobile or destroyed:brakes=maxf(brakes,0.6*weight)
 var push:=clampf(drive_force,-grip*weight,grip*weight)
 var hold:=resist+brakes
 var gravity_along:=hull_mass*get_gravity().dot(forward)
 var total:=push
 if absf(v)>0.3:total-=signf(v)*hold
 else:
  # Nearly at rest: the resistances act as static friction, to their limit.
  total-=clampf(push+gravity_along+hull_mass*v/delta*0.5,-hold,hold)
 # Track forces act at the ground: the hull squats and rises on them.
 apply_force(forward*total,global_basis*Vector3(0,0.15,0))
 # Tracks do not slide sideways until the ground lets go.
 var grip_side:=grip*weight
 apply_force(-side*clampf(lateral*hull_mass*6.0,-grip_side,grip_side),global_basis*Vector3(0,0.15,0))
 # Yaw: the tracks hold the hull on the kinematic rate of the steering
 # mechanism; braked tracks hold it straight.
 var wanted:=0.0
 if k<0.999:wanted=-steer_side()*v*2.0*(1.0-k)/((1.0+k)*gauge)
 var cap:=grip*weight*gauge*0.5
 apply_torque(up*clampf((wanted-yaw)*yaw_inertia*7.0,-cap,cap))
 track_phase+=v*delta

func hold_parked(delta: float) -> void:
 if freeze:
  if not parking or immobile:
   if not was_paused:freeze=false;parked_time=0.0
  return
 if parking and linear_velocity.length()<0.15 and angular_velocity.length()<0.06 and load_total>hull_mass*5.0:parked_time+=delta
 else:parked_time=0.0
 if parked_time>0.8:
  freeze_mode=RigidBody3D.FREEZE_MODE_STATIC
  freeze=true
  linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO

func is_parked() -> bool:return freeze and not was_paused

# The road wheels rise on their arms and turn with the tracks.
func animate_running_gear() -> void:
 var wheels: Array=art.wheels
 for i in range(wheels.size()):
  var wheel: MeshInstance3D=wheels[i]
  var lift:=clampf(compressions[i]-(free_length-ray_top),-0.12,travel)
  wheel.position.y=wheel_height+lift
  wheel.rotation.x=-track_phase/wheel_radius
 for hub in art.drive:hub.rotation.x=-track_phase/sprocket_radius

func carries_player() -> bool:return game.player_vehicle()==self

# A hull moving over a soldier on foot: nobody survives under it.
func crush() -> void:
 var v:=linear_velocity.length()
 if v<1.2:return
 for actor in game.allies+game.bots+[game.player]:
  if not is_instance_valid(actor):continue
  if actor is Hostile and (actor.dead or actor.vehicle!=null):continue
  if actor is Operator and (actor.health<=0 or carries_player()):continue
  var local:=to_local(actor.global_position)
  if absf(local.x)<crush_half.x and absf(local.z)<crush_half.y and local.y>-0.6 and local.y<1.4:
   actor.receive_hit(400.0,"chest",linear_velocity.normalized(),actor.global_position+Vector3.UP)

# Fences, posts, boards and sheds give way to the hull: the bow (or the
# stern in reverse) flattens light pieces of the yard it runs into. House
# walls and masonry stop it; the heap of a fallen house it drives over.
func ram() -> void:
 ram_clock-=get_physics_process_delta_time()
 var v:=speed()
 if ram_clock>0.0 or absf(v)<0.3 or destroyed:return
 # Fast, it looks every frame: the bow must not hit a fence before it falls.
 ram_clock=0.05 if absf(v)<3.0 else 0.0
 if ram_query==null:
  ram_query=PhysicsShapeQueryParameters3D.new()
  var box:=BoxShape3D.new();box.size=Vector3(ram_width,1.5,1.4)
  ram_query.shape=box;ram_query.collision_mask=1;ram_query.exclude=[get_rid()]
 var end:=-(ram_half+0.3) if v>0.0 else ram_half+0.3
 ram_query.transform=global_transform*Transform3D(Basis.IDENTITY,Vector3(0,1.05,end))
 for hit in get_world_3d().direct_space_state.intersect_shape(ram_query,12):
  var body: Object=hit.collider
  if body is DestructibleSurface and crushable(body):flatten(body,-global_basis.z*signf(v))

static func crushable(body: DestructibleSurface) -> bool:
 if body.breaking:return false
 # Fence panels of the great assault and the broken corners of walls left
 # on a heap of rubble: a hull puts them over.
 if body.has_meta("crushable"):return true
 if body.has_meta("indestructible"):return false
 var shape_node:=body.get_child(0) as CollisionShape3D
 if shape_node==null or not shape_node.shape is BoxShape3D:return false
 var size: Vector3=shape_node.shape.size*body.global_basis.get_scale()
 var thin:=minf(size.x,minf(size.y,size.z))
 return size.x*size.y*size.z<0.5 or (thin<0.13 and size.y<2.6)

func flatten(body: DestructibleSurface, direction: Vector3) -> void:Demolition.flatten(game,body,direction)
