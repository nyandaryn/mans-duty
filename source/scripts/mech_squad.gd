class_name MechSquad
extends Node

# One mechanized squad: a BMP-2 with its driver-mechanic and gunner-operator
# and seven men in the troop compartment who fight on foot. After doctrine
# and the practice of 2022–2025: the column keeps 25–50 m; troops dismount
# only behind the last cover before the objective, never under the enemy's
# guns, and the vehicle does not linger at the drop point; on the approach
# the men walk in file behind the hull, firing from behind it, and break
# into cover at contact or close to the enemy; the vehicle never leads them
# into the village — it supports from behind the line and changes its fire
# position; it comes up to take the men aboard only when the place is quiet,
# and only when the next objective is far.
const EXIT_INTERVAL := 0.7
const FILE_GAP := 2.3
const FILE_PACE := 1.5
const ASSAULT_LINE := 65.0
const REMOUNT_DISTANCE := 160.0
const CLEAR_RADIUS := 80.0
const BOARD_REACH := 4.0
const CONTACT_RANGE := 130.0
const PICKUP_PATIENCE := 70.0

var game: Node3D
var battle: BattleMode
var index := 0
var vehicle: BmpVehicle
var driver: BmpDriver
var members: Array[Hostile]=[]
var state := "wait"
var state_time := 0.0
var player_led := false
var ahead: MechSquad
var exit_clock := 0.0
var exits := 0
var after_dismount := "file"
var goal_sector := -2
var drop := Vector3.INF
var overwatch := Vector3.INF
var overwatch_time := 0.0
var overwatch_shots := 0
var road_end := 0.0
var leg := ""
var check_clock := 0.0
var command_point := Vector3.INF
var assault_direction := Vector3.FORWARD
var boarded_clock := 0.0
var start_spot := Vector3.INF
var file_mark := 0.0
var yield_time := 0.0
var file_mark_time := 0.0
# Where the hull has been: the file walks in its tracks round corners.
var trail := PackedVector3Array()

func setup(owner_game: Node3D, owner_battle: BattleMode, squad_index: int, carrier: BmpVehicle, led: bool=false) -> void:
 game=owner_game;battle=owner_battle;index=squad_index;vehicle=carrier;player_led=led
 name="MechSquad%d" % (index+1)
 driver=BmpDriver.new();driver.setup(vehicle)
 vehicle.squad=self
 if not player_led:vehicle.driver_ai=driver
 state="mounted" if player_led else "wait"

func district() -> Node3D:return game.district

# Bodies of the fallen are cleared from the field after a while: a freed
# member is simply gone.
func operational(actor: Object) -> bool:
 return is_instance_valid(actor) and not actor.dead and not actor.concussion.incapacitated()

# The dead are freed in time (after the match, with the corpses): forget them.
func prune() -> void:
 for i in range(members.size()-1,-1,-1):
  if not is_instance_valid(members[i]):members.remove_at(i)

func on_foot() -> Array[Hostile]:
 prune()
 var list: Array[Hostile]=[]
 for actor in members:
  if operational(actor) and actor.vehicle==null:list.append(actor)
 return list

func aboard() -> Array[Hostile]:
 prune()
 var list: Array[Hostile]=[]
 for actor in members:
  if operational(actor) and actor.vehicle==vehicle:list.append(actor)
 return list

func living() -> int:
 prune()
 var count:=0
 for actor in members:
  if operational(actor):count+=1
 return count

func centroid() -> Vector3:
 var list:=on_foot()
 if list.is_empty():return vehicle.global_position
 var sum:=Vector3.ZERO
 for actor in list:sum+=actor.global_position
 return sum/list.size()

func control(actor: Object, on: bool) -> void:
 if not is_instance_valid(actor):return
 actor.set_meta("mech_control",on)
 if not on:actor.set_meta("halt_point",actor.global_position)

func snap(point: Vector3) -> Vector3:
 if absf(point.x)>199 or absf(point.z)>199:return point
 var cell:Vector2i=district().nearest_cell(district().navigation_cell(point))
 return district().navigation_position(cell)

# Running to the doors: no stopping for cover on the way.
func run_to_door(actor: Hostile, index: int) -> void:
 move_to(actor,vehicle.exit_point(index),1.0)
 actor.has_cover=false
 actor.cover_timer=maxf(actor.cover_timer,0.6)

func try_board(actor: Hostile, index: int) -> void:
 if actor.global_position.distance_to(vehicle.exit_point(index))<BOARD_REACH and absf(vehicle.speed())<0.8 and vehicle.doors>0.8:vehicle.board(actor)

# A plain move order the soldier's own tactics carry out: he walks there and
# drops into cover nearby if he comes under fire.
func move_to(actor: Hostile, point: Vector3, radius: float=5.0) -> void:
 var goal:=snap(point)
 if actor.order_point.distance_to(goal)>2.5 or actor.order!="move":
  actor.has_cover=false;actor.path_timer=0;actor.cover_dwell=0
 actor.order="move"
 actor.order_point=goal
 actor.home=goal
 actor.defensive=true
 actor.defense_radius=radius
 actor.assault_arrived=false
 actor.fire_at_will=true

func set_state(next: String) -> void:
 # Back to fire support: a fresh fire position for the present objective.
 if next=="assault" and state!="assault":leg="";overwatch=Vector3.INF;overwatch_time=0.0
 state=next;state_time=0.0

func fighting_enemies() -> Array:
 return game.bots.filter(func(a):return battle.fighting(a)) if battle.active else game.bots.filter(func(a):return not a.dead and a.collapse<=0.5)

# The driver thinks a place is quiet when nobody of the enemy who can still
# fight is anywhere near it.
func quiet_at(point: Vector3, radius: float=CLEAR_RADIUS) -> bool:
 for actor in fighting_enemies():
  if actor.global_position.distance_to(point)<radius:return false
 return true

func exclude() -> Array[RID]:
 var list: Array[RID]=[]
 for squad in battle.mech:list.append(squad.vehicle.get_rid())
 return list

func space() -> PhysicsDirectSpaceState3D:return vehicle.get_world_3d().direct_space_state

func departed(gap: float) -> bool:
 if player_led:return start_spot==Vector3.INF or vehicle.global_position.distance_to(start_spot)>=gap
 if state!="march":return state!="wait"
 return driver.progress>=gap

# --- Frame ------------------------------------------------------------------
func _physics_process(delta: float) -> void:
 if not game.running or game.paused or not is_instance_valid(vehicle):return
 if battle.active and battle.finished:return
 state_time+=delta
 record_trail()
 prune()
 if vehicle.destroyed and state!="afoot":
  bail_out()
  return
 if player_led:
  tick_player(delta)
  return
 if driver.jams>=2 and not driver.hold and not driver.arrived and not state in ["wait","march"]:reroute()
 driver.cap=INF
 match state:
  "wait":tick_wait()
  "march":tick_march()
  "approach":tick_approach()
  "dismount":tick_dismount(delta)
  "file":tick_file()
  "assault":tick_assault(delta)
  "pickup":tick_pickup()
  "transfer":tick_transfer()
  "afoot":pass
 if not state in ["wait","march","afoot"]:give_way(delta)
 vehicle.gunner.allowed=state in ["approach","file","assault","pickup","transfer","dismount"] or (state=="march" and vehicle.global_position.length()<500.0)

func tick_wait() -> void:
 driver.stop()
 if not battle.column_go or battle.halted:return
 if ahead!=null and is_instance_valid(ahead.vehicle) and not ahead.vehicle.destroyed and not ahead.departed(BmpRoutes.COLUMN_GAP):return
 var route:=BmpRoutes.approach(index,district())
 driver.set_route(route,BmpRoutes.FIELD_SPEED,6.0)
 road_end=driver.lengths[BmpRoutes.ROAD.size()]
 set_state("march")
 if index==0 or (ahead!=null and ahead.player_led):game.squad.tell("Колона БМП рушила: машин — %d · до села близько двох кілометрів" % battle.mech.size())

func tick_march() -> void:
 if battle.halted:driver.stop();return
 driver.hold=false
 driver.cruise=BmpRoutes.ROAD_SPEED if driver.progress<road_end else BmpRoutes.FIELD_SPEED
 driver.cap=INF
 if ahead!=null and is_instance_valid(ahead.vehicle) and not ahead.vehicle.destroyed and (ahead.state=="march" or ahead.player_led):
  # Distance to the vehicle ahead along the road both are on.
  var gap:=gap_to(ahead)
  if gap<22.0:driver.cap=0.0
  elif gap<BmpRoutes.COLUMN_GAP:driver.cap=maxf(1.5,absf(ahead.vehicle.speed()))
 if driver.arrived:enter_village()

# Road distance to the vehicle ahead, by placing it on this squad's route;
# a vehicle off the route (the player's, driving his own way) does not hold
# the column up.
func gap_to(other: MechSquad) -> float:
 var at:=driver.locate(other.vehicle.global_position,driver.progress-30.0,driver.progress+300.0)
 if at.y>25.0:return INF
 return at.x-driver.progress

func objective() -> Vector3:
 return battle.objective_point(index)

func enter_village() -> void:
 goal_sector=battle.sector
 var target:=objective()
 var taken: Array=[]
 for squad in battle.mech:
  if squad!=self and squad.drop!=Vector3.INF:taken.append(squad.drop)
 drop=pick_drop(target,taken)
 var route:=plan(drop)
 if route.size()<2:begin_dismount("file");return
 driver.set_route(route,BmpRoutes.FIELD_SPEED*0.8,3.0)
 leg="drop"
 set_state("approach")

# A covered drop point for an objective, apart from the other squads'.
func pick_drop(target: Vector3, taken: Array) -> Vector3:
 for apart in [35.0,20.0,0.0]:
  var choice:=first_reachable(BmpRoutes.dismount_points(district(),battle.vehicle_grid,space(),target,vehicle.global_position,exclude(),95.0,175.0,taken,apart))
  if not choice.is_empty():return choice.point
 return vehicle.global_position

# The first of the places (best first) whose route is not a detour round
# half the village: {point, route}, or empty.
func first_reachable(points: Array) -> Dictionary:
 for p in points.slice(0,5):
  var route:=plan(p)
  if route.size()<2:continue
  if BmpRoutes.length_of(route)<vehicle.global_position.distance_to(p)*2.0+60.0:return {"point":p,"route":route}
 return {}

# A route in the village round the other vehicles standing in it.
func plan(to: Vector3) -> PackedVector3Array:
 var grid:=battle.vehicle_grid
 var marked: Array[Vector2i]=[]
 var here:=BmpRoutes.cell_of(district(),vehicle.global_position)
 for other in battle.mech:
  if other==self or not is_instance_valid(other.vehicle):continue
  if absf(other.vehicle.speed())>1.0 and not other.vehicle.destroyed:continue
  var at:=BmpRoutes.cell_of(district(),other.vehicle.global_position)
  for dz in range(-3,4):
   for dx in range(-3,4):
    var c:=at+Vector2i(dx,dz)
    if not grid.is_in_boundsv(c) or grid.is_point_solid(c) or maxi(absi(c.x-here.x),absi(c.y-here.y))<=2:continue
    grid.set_point_solid(c,true);marked.append(c)
 var route:=BmpRoutes.path(district(),grid,vehicle.global_position,to)
 for c in marked:grid.set_point_solid(c,false)
 return route

# Another vehicle near a place (where it is or where it goes to fire from).
func taken_by_other(point: Vector3, apart: float) -> bool:
 for other in battle.mech:
  if other==self or not is_instance_valid(other.vehicle):continue
  if other.vehicle.global_position.distance_to(point)<apart:return true
  if other.overwatch!=Vector3.INF and other.overwatch.distance_to(point)<apart:return true
 return false

# Give way: a vehicle on the next few metres of the route is waited for if
# it is moving and has the right of way (the lower number); one standing
# there is driven round.
func give_way(delta: float) -> void:
 if driver.hold or driver.arrived or driver.backing>0.0 or driver.route.size()<2:yield_time=0.0;return
 var here:=Vector2(vehicle.global_position.x,vehicle.global_position.z)
 var aim3:=driver.point_at(driver.progress+12.0)
 var aim:=Vector2(aim3.x,aim3.z)
 for other in battle.mech:
  if other==self or not is_instance_valid(other.vehicle):continue
  var at:=Vector2(other.vehicle.global_position.x,other.vehicle.global_position.z)
  if at.distance_to(here)>16.0:continue
  # Only what is ahead on the way, not alongside.
  var way:=(aim-here).normalized()
  if (at-here).dot(way)<2.0:continue
  if Geometry2D.get_closest_point_to_segment(at,here,aim).distance_to(at)>4.5:continue
  var moving:=absf(other.vehicle.speed())>0.8
  if moving and other.index>index:continue
  # Both waiting for each other: the lower number goes first.
  if other.yield_time>0.0 and other.index>index:continue
  driver.cap=0.0
  yield_time+=delta
  if yield_time>(8.0 if moving else 2.5):
   yield_time=0.0
   var route:=plan(driver.route[-1])
   if route.size()>=2:driver.set_route(route,driver.cruise,driver.arrive)
  return
 yield_time=0.0

# Twice against the same thing that will not give: it stays in the way, so
# it goes on the vehicles' map as an obstacle and the route goes round it.
func reroute() -> void:
 driver.jams=0
 var grid:=battle.vehicle_grid
 var here:=BmpRoutes.cell_of(district(),vehicle.global_position)
 var at:=BmpRoutes.cell_of(district(),driver.jam_point)
 for dz in range(-2,3):
  for dx in range(-2,3):
   var c:=at+Vector2i(dx,dz)
   if grid.is_in_boundsv(c) and maxi(absi(c.x-here.x),absi(c.y-here.y))>1:grid.set_point_solid(c,true)
 if driver.route.size()<2:return
 var route:=plan(driver.route[-1])
 if route.size()>=2:driver.set_route(route,driver.cruise,driver.arrive)

func tick_approach() -> void:
 if battle.halted:driver.stop();return
 driver.hold=false
 driver.cap=INF
 if driver.arrived or (state_time>90.0 and absf(vehicle.speed())<0.3):begin_dismount("file")

func begin_dismount(next: String) -> void:
 after_dismount=next
 exits=0
 exit_clock=0.4
 driver.stop()
 vehicle.open_doors(true)
 set_state("dismount")

func tick_dismount(delta: float) -> void:
 driver.stop()
 if absf(vehicle.speed())>1.5 or vehicle.doors<0.8:return
 exit_clock-=delta
 if exit_clock>0.0:return
 var inside:=aboard()
 if inside.is_empty():
  vehicle.open_doors(false)
  start_after_dismount()
  return
 var actor: Hostile=inside[0]
 vehicle.unload(actor,exits)
 exits+=1
 exit_clock=EXIT_INTERVAL
 control(actor,after_dismount!="assault")
 # Out of the door, the men first take their places right behind the hull.
 move_to(actor,file_slot(exits-1),4.0)

func start_after_dismount() -> void:
 match after_dismount:
  "file":start_file()
  "guard":set_state("guard")
  "file_player":
   for actor in on_foot():control(actor,true)
   set_state("file")
  "assault":
   for actor in on_foot():control(actor,false)
   if player_led:order_assault_to(command_point)
   set_state("assault")
  _:set_state(after_dismount)

# Where the men stand in file behind the hull, one after another in its
# tracks, a little to either side so they see past each other.
func file_slot(i: int) -> Vector3:
 var distance:=BmpArt.HALF+1.6+i*FILE_GAP
 var last:=vehicle.global_position
 var back:=vehicle.global_basis.z
 var p:=last+back*distance
 for k in range(trail.size()-1,-1,-1):
  var segment:=last.distance_to(trail[k])
  if segment>=distance:
   p=last.move_toward(trail[k],distance)
   back=(trail[k]-last).normalized()
   break
  distance-=segment
  if segment>0.01:back=(trail[k]-last).normalized()
  last=trail[k]
  p=last+back*distance
 var side:=Vector3(-back.z,0,back.x).normalized()
 p+=side*(0.5 if i%2==0 else -0.5)
 p.y=district().ground_height(p)
 return p

func record_trail() -> void:
 var here:=vehicle.global_position
 if trail.is_empty() or trail[-1].distance_to(here)>25.0:
  trail=PackedVector3Array([here]);return
 if trail[-1].distance_to(here)>0.8:
  trail.append(here)
  if trail.size()>60:trail.remove_at(0)

# In the file the hull is the cover: the men keep their places in it and go
# to ground only when fired upon.
func keep_file(men: Array[Hostile]) -> void:
 for i in range(men.size()):
  move_to(men[i],file_slot(i),2.5)
  if men[i].under_fire_time<=0.0:
   men[i].has_cover=false
   men[i].cover_timer=maxf(men[i].cover_timer,0.5)

func start_file() -> void:
 var target:=objective()
 var route:=plan(target)
 # The file goes up to the assault line only, then the men break into cover.
 var cut:=PackedVector3Array()
 for p in route:
  if p.distance_to(target)<ASSAULT_LINE:
   if not cut.is_empty():
    var last:=cut[-1]
    var t:=clampf((last.distance_to(target)-ASSAULT_LINE)/maxf(last.distance_to(p),0.01),0,1)
    cut.append(last.lerp(p,t))
   break
  cut.append(p)
 var length:=0.0
 for i in range(1,cut.size()):length+=cut[i].distance_to(cut[i-1])
 # Too short to be worth it, or a detour the men walk straighter on foot.
 var direct:=vehicle.global_position.distance_to(target)-ASSAULT_LINE
 if cut.size()<2 or length<15.0 or length>maxf(direct,0.0)*2.0+60.0:
  disperse()
  return
 driver.set_route(cut,FILE_PACE,3.0)
 leg="file"
 set_state("file")
 file_mark=0.0;file_mark_time=0.0

func tick_file() -> void:
 var men:=on_foot()
 var lagging:=false
 keep_file(men)
 for i in range(men.size()):
  if men[i].global_position.distance_to(file_slot(i))>9.0:lagging=true
 # The vehicle goes at a walking pace and stops for the file to close up.
 driver.hold=battle.halted or lagging
 driver.cap=FILE_PACE
 if battle.halted:disperse();return
 # The vehicle does not get on (it cannot turn, the way is blocked, the
 # men do not close up): on foot from here.
 if driver.progress>file_mark+3.0:file_mark=driver.progress;file_mark_time=state_time
 if driver.arrived or contact(men) or vehicle.immobile or state_time-file_mark_time>45.0 or state_time>240.0:disperse()

func contact(men: Array[Hostile]) -> bool:
 var under_fire:=0
 for actor in men:
  if actor.under_fire_time>0.0:under_fire+=1
  if actor.sees_player and is_instance_valid(actor.combat_target) and actor.global_position.distance_to(actor.combat_target.global_position)<CONTACT_RANGE:return true
 return under_fire>=2

# Into cover, by the assault tactics of the battle: the men leave the hull
# and storm their positions; the vehicle draws back to support with fire.
func disperse() -> void:
 for actor in on_foot():
  control(actor,false)
  actor.has_cover=false;actor.path_timer=0;actor.cover_timer=randf()*0.8
  battle.assign(actor)
 driver.stop()
 overwatch=Vector3.INF
 goal_sector=battle.sector
 set_state("assault")
 if index==0:game.squad.tell("Відділення %d спішилось і пішло на штурм" % (index+1))

func tick_assault(delta: float) -> void:
 var men:=on_foot()
 for actor in men:
  if actor.get_meta("mech_control",false):control(actor,false)
 support(delta)
 check_clock-=delta
 if check_clock>0.0:return
 check_clock=2.0
 if battle.sector!=goal_sector:
  goal_sector=battle.sector
  overwatch=Vector3.INF
  var target:=objective()
  if men.size()>=2 and centroid().distance_to(target)>REMOUNT_DISTANCE and not vehicle.immobile:
   set_state("pickup");leg="";driver.stop()

# Fire support from behind the line: an overwatch place the objective cannot
# reach the hull at; a new one after a few bursts there.
func support(delta: float) -> void:
 # The assault is held: the vehicle holds where it is too.
 if battle.halted:driver.stop();return
 overwatch_time+=delta
 if vehicle.gunner.since_burst<0.1:overwatch_shots+=1
 var target:=battle.center() if battle.sector>=0 else objective()
 var moved:=overwatch_time>35.0 and overwatch_shots>=2
 # Out of the fight far behind: closer again.
 var far:=overwatch_time>20.0 and (driver.arrived or driver.hold) and vehicle.global_position.distance_to(target)>150.0
 if overwatch==Vector3.INF or moved or far:
  overwatch_time=0.0;overwatch_shots=0
  var rear:=drop if drop!=Vector3.INF else vehicle.global_position
  var points:=BmpRoutes.overwatch_points(district(),battle.vehicle_grid,space(),target,rear,exclude(),75.0+randf()*15.0,140.0,12)
  var choice:=first_reachable(points.filter(func(p):return not taken_by_other(p,20.0)))
  # No fire position within reach: up behind the men, or toward the
  # objective if they are gone.
  if choice.is_empty():
   var men:=on_foot()
   var base:=centroid() if not men.is_empty() else target
   var keep:=40.0 if not men.is_empty() else 90.0
   if vehicle.global_position.distance_to(base)>keep+30.0:
    var spot:=base+(vehicle.global_position-base).normalized()*keep
    var cell:=BmpRoutes.free_cell(battle.vehicle_grid,BmpRoutes.cell_of(district(),spot),15)
    if cell.x!=999999:choice=first_reachable([district().navigation_position(cell)])
  if choice.is_empty():driver.stop();overwatch=vehicle.global_position
  else:overwatch=choice.point;driver.set_route(choice.route,4.0,3.0);leg="overwatch"
 # Too close to an enemy still fighting: back away from him first.
 if not quiet_at(vehicle.global_position,45.0) and leg!="withdraw":
  var back:=vehicle.global_position+(vehicle.global_position-target).normalized()*40.0
  var route:=plan(back)
  if route.size()>=2:driver.set_route(route,5.0,3.0);leg="withdraw";overwatch_time=30.0
 if leg=="withdraw" and driver.arrived:leg="";overwatch=Vector3.INF

func tick_pickup() -> void:
 var men:=on_foot()
 if men.is_empty():set_state("assault");return
 var rally:=centroid()
 # The vehicle comes only to a quiet place; until then the men fight on.
 if leg=="":
  if not quiet_at(rally) or state_time>PICKUP_PATIENCE:
   if state_time>PICKUP_PATIENCE:set_state("assault")
   return
  var cell:=BmpRoutes.free_cell(battle.vehicle_grid,BmpRoutes.cell_of(district(),rally),20)
  if cell.x==999999:set_state("assault");return
  var spot:Vector3=district().navigation_position(cell)
  # Round half the village to them: they rather come to the vehicle.
  var choice:=first_reachable([spot])
  if not choice.is_empty():driver.set_route(choice.route,5.0,3.0)
  else:driver.stop()
  leg="pickup"
  state_time=0.0
  if index==0:game.squad.tell("БМП %d іде за десантом: «До машини!»" % (index+1))
  return
 # The vehicle cannot get through to them: the men come to it where it is.
 if not (driver.arrived or driver.hold) and state_time>45.0 and absf(vehicle.speed())<0.5:driver.stop()
 var waiting:=driver.arrived or driver.hold
 if waiting:
  vehicle.open_doors(true)
  for i in range(men.size()):
   control(men[i],true)
   run_to_door(men[i],i)
   try_board(men[i],i)
  if aboard().size()==living() or (state_time>PICKUP_PATIENCE and not aboard().is_empty()):
   for actor in on_foot():control(actor,false)
   vehicle.open_doors(false)
   transfer()
  elif state_time>PICKUP_PATIENCE*1.5:
   for actor in on_foot():control(actor,false)
   vehicle.open_doors(false)
   set_state("assault")

func transfer() -> void:
 goal_sector=battle.sector
 var target:=objective()
 var taken: Array=[]
 for squad in battle.mech:
  if squad!=self and squad.drop!=Vector3.INF and squad.state in ["approach","transfer","dismount","file"]:taken.append(squad.drop)
 drop=pick_drop(target,taken)
 var route:=plan(drop)
 if route.size()<2:begin_dismount("file");return
 driver.set_route(route,BmpRoutes.FIELD_SPEED,3.0)
 leg="transfer"
 set_state("transfer")
 if index==0:game.squad.tell("Відділення %d на броні: до наступної цілі" % (index+1))

func tick_transfer() -> void:
 if battle.halted:driver.stop();return
 driver.hold=false
 driver.cap=INF
 if driver.arrived or (state_time>120.0 and absf(vehicle.speed())<0.3):begin_dismount("file")

# The vehicle is lost: whoever is inside gets out as he can, the squad goes
# on as infantry.
func bail_out() -> void:
 var index_out:=0
 for actor in vehicle.aboard.duplicate()+vehicle.crew.duplicate():
  if not is_instance_valid(actor) or actor.dead:continue
  vehicle.aboard.erase(actor);vehicle.crew.erase(actor)
  var spot:=vehicle.exit_point(index_out)
  if actor.get_meta("bmp_role","")!="":spot=vehicle.to_global(Vector3(-2.4 if index_out%2==0 else 2.4,0,-1.0+index_out*0.4))
  index_out+=1
  if actor.get_meta("bmp_role","")=="":vehicle.unload(actor,index_out)
  else:actor.disembark(snap(spot)+Vector3.UP*0.1,vehicle.global_basis.z)
  control(actor,false)
  if randf()<0.35:actor.receive_blast(140.0,0.8,Vector3.UP)
  if actor.get_meta("bmp_role","")!="":actor.set_meta("bmp_role","");members.append(actor)
 vehicle.gunner.manned=false
 set_state("afoot")
 for actor in on_foot():
  if battle.active and not player_led:battle.assign(actor)

# --- The squad of the player: he drives and commands ----------------------
func tick_player(delta: float) -> void:
 vehicle.gunner.allowed=true
 match state:
  "dismount":tick_dismount(delta)
  "file":keep_file(on_foot())
  "guard":
   var men:=on_foot()
   for i in range(men.size()):
    var angle:=(float(i)-(men.size()-1)*0.5)*0.42
    var local:=Vector3(sin(angle)*7.0,0,BmpArt.HALF+3.0+cos(angle)*2.0)
    move_to(men[i],vehicle.to_global(local),4.0)
  "mount":
   var men:=on_foot()
   vehicle.open_doors(true)
   for i in range(men.size()):
    run_to_door(men[i],i)
    try_board(men[i],i)
   if on_foot().is_empty():
    boarded_clock+=delta
    if boarded_clock>1.0:vehicle.open_doors(false);set_state("mounted");game.squad.tell("Десант на місцях: %d" % aboard().size())
   else:boarded_clock=0.0
  "assault","mounted":pass

func order_dismount() -> void:
 if aboard().is_empty():game.squad.tell("У машині десанту немає");return
 if absf(vehicle.speed())>2.0:game.squad.tell("До спішування — зупинись (швидкість до 7 км/год)");return
 begin_dismount("guard")
 game.squad.tell("«Відділення, до машини!» · спішування, кругова оборона за кормою")

func order_mount() -> void:
 if on_foot().is_empty():game.squad.tell("Усі на місцях");return
 if absf(vehicle.speed())>0.8:game.squad.tell("Для посадки зупинись");return
 boarded_clock=0.0
 for actor in on_foot():control(actor,true)
 set_state("mount")
 game.squad.tell("«По місцях!» · посадка в машину: %d" % on_foot().size())

func order_file() -> void:
 if not aboard().is_empty():
  if absf(vehicle.speed())>2.0:game.squad.tell("До спішування — зупинись");return
  begin_dismount("file_player")
 else:
  for actor in on_foot():control(actor,true)
  set_state("file")
 game.squad.tell("«За машиною, в колону по одному — за мною!»")

func order_assault(point: Vector3, direction: Vector3) -> void:
 command_point=point
 assault_direction=direction
 if not aboard().is_empty():
  if absf(vehicle.speed())>2.0:game.squad.tell("До спішування — зупинись");return
  begin_dismount("assault")
 else:
  order_assault_to(point)
  set_state("assault")
 game.squad.tell("«Відділення, вперед, розсипом — до бою!»")

# Each man to his own place around the aimed point, spread across the
# direction of the attack.
func order_assault_to(point: Vector3) -> void:
 var forward:=Vector3(assault_direction.x,0,assault_direction.z).normalized()
 if forward.length()<0.1:forward=-vehicle.global_basis.z
 var side:=Vector3(-forward.z,0,forward.x)
 var men:=on_foot()
 for i in range(men.size()):
  var actor:=men[i]
  control(actor,false)
  var offset:=side*(float(i)-(men.size()-1)*0.5)*7.0-forward*float(i%2)*3.0
  var goal:=snap(point+offset)
  actor.order="assault"
  actor.order_point=goal
  actor.home=goal
  actor.order_origin=vehicle.global_position
  actor.order_direction=forward
  actor.assault_arrived=false
  actor.cover_dwell=0
  actor.fire_at_will=true
  actor.has_cover=false;actor.path_timer=0;actor.flank_timer=0;actor.cover_timer=randf()*0.5
  actor.burst_left=0;actor.think_timer=0
