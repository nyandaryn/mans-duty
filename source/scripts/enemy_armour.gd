class_name EnemyArmour
extends Node

# The defenders' BMP-2s of the great assault: one at each strongpoint, parked
# in front of it with the engine off, its driver and gunner idling beside it
# (Idle). When the strongpoint takes the alarm — one of its men sees or hears
# the attack, shells fall near, the vehicle is hit or the attackers come
# within reach — the two run to it, the driver gets in through his hatch and
# starts the engine, the gunner climbs into the turret and opens fire. A
# vehicle set on fire is abandoned: the crew fight on foot with the
# strongpoint.
const ALARM_RANGE := 320.0
var game: Node3D
var battle: BattleMode
var vehicles: Array[BmpVehicle]=[]
# Per vehicle: {"vehicle", "sector", "crew": {role: Hostile}, "state"}.
var units: Array[Dictionary]=[]
var clock := 0.0

func setup(owner_game: Node3D, owner_battle: BattleMode) -> void:
 game=owner_game;battle=owner_battle;name="EnemyArmour"
 owner_battle.add_child(self)

func deploy() -> void:
 for index in range(BattleMap.CENTERS.size()):
  var at:Variant=parking(index)
  if at==null:continue
  var vehicle:=BmpVehicle.new()
  vehicle.friendly=false
  game.world_root.add_child(vehicle)
  vehicle.setup(game,"Z%d" % (index+1))
  vehicle.name="EnemyBmp%d" % (index+1)
  battle.place_vehicle(vehicle,at)
  vehicle.gunner.manned=false
  vehicle.master=false;vehicle.running=false;vehicle.parking=true
  vehicles.append(vehicle)
  var unit:={"vehicle":vehicle,"sector":index,"crew":{},"state":"parked"}
  for role in ["driver","gunner"]:
   var spot:=idle_spot(vehicle,role)
   var actor:=battle.spawn_soldier(false,spot,index,-1)
   actor.set_meta("armour_crew",true)
   actor.set_meta("armour_role",role)
   # Counted with the firing position nearest the vehicle.
   actor.set_meta("battle_position",nearest_position(index,vehicle.global_position))
   actor.set_kit("rifle")
   actor.home=spot;actor.target=spot
   Idle.place(actor,vehicle.to_global(Vector3(0,0,-6.0)))
   unit.crew[role]=actor
  units.append(unit)

# In front of the strongpoint, toward the attack, on open ground the hull
# fits and can turn on.
func parking(index: int) -> Variant:
 var center: Vector2=BattleMap.CENTERS[index]
 var look: Vector2=BattleMap.threat(center)
 var district: Node3D=game.district
 var grid: AStarGrid2D=battle.vehicle_grid
 var best: Variant=null
 var best_score:=INF
 for ring in [10.0,16.0,22.0,28.0,36.0]:
  for k in range(16):
   var dir:=Vector2.from_angle(TAU*k/16.0)
   var p: Vector2=center+dir*float(ring)
   var point:=Vector3(p.x,district.ground_height(Vector3(p.x,0,p.y)),p.y)
   if grid==null or not BmpRoutes.roomy(grid,district,point):continue
   var score:=(p-(center+look*18.0)).length()
   if score<best_score:best_score=score;best=point
  if best!=null:break
 if best==null:return null
 var forward:=Vector3(look.x,0,look.y).normalized()
 return Transform3D(Basis.looking_at(forward,Vector3.UP),best)

# Beside the vehicle: the driver by his hatch on the left front, the gunner
# by the right side.
func idle_spot(vehicle: BmpVehicle, role: String) -> Vector3:
 var local:=Vector3(-2.4,0,-1.6) if role=="driver" else Vector3(2.4,0,0.4)
 return battle.snap(vehicle.to_global(local))+Vector3.UP*0.05

func board_spot(vehicle: BmpVehicle, role: String) -> Vector3:
 var local:=Vector3(-2.1,0,-1.3) if role=="driver" else Vector3(2.1,0,-0.2)
 return battle.snap(vehicle.to_global(local))+Vector3.UP*0.05

func _physics_process(delta: float) -> void:
 if not game.running or game.paused or not battle.active:return
 clock+=delta
 if clock<0.25:return
 clock=0.0
 for unit in units:tick(unit)

func tick(unit: Dictionary) -> void:
 var vehicle: BmpVehicle=unit.vehicle
 if not is_instance_valid(vehicle):return
 match String(unit.state):
  "parked":
   if alarm(unit):
    unit.state="manning"
    for role in unit.crew:
     var actor: Hostile=unit.crew[role]
     if BotKit.alive_actor(actor):
      Idle.stop(actor)
      actor.alerted=true
  "manning":
   if vehicle.hull.out_of_action():bail(unit);return
   var waiting:=0
   for role in unit.crew:
    var actor: Hostile=unit.crew[role]
    if not is_instance_valid(actor) or actor.dead or actor.vehicle!=null:continue
    if actor.collapse>0.3 or actor.concussion.incapacitated():continue
    var spot:=board_spot(vehicle,role)
    # Run for it: the boarding point is his "cover".
    actor.has_cover=true;actor.cover_point=spot;actor.cover_requires_prone=false
    actor.cover_timer=2.0;actor.flank_timer=0.0
    if actor.global_position.distance_to(spot)<1.8:board(vehicle,actor,role)
    else:waiting+=1
   if waiting==0:unit.state="manned"
  "manned":
   if vehicle.hull.burning or vehicle.destroyed:bail(unit)

# The strongpoint is awake, or the attack is upon the vehicle.
func alarm(unit: Dictionary) -> bool:
 var vehicle: BmpVehicle=unit.vehicle
 if vehicle.hull.hits>0:return true
 for role in unit.crew:
  var actor: Hostile=unit.crew[role]
  if is_instance_valid(actor) and actor.alerted and not actor.dead:return true
 for actor in game.bots:
  if actor.dead or int(actor.get_meta("battle_sector",-2))!=int(unit.sector):continue
  if actor.alerted and actor.global_position.distance_to(vehicle.global_position)<90.0:return true
 for actor in game.allies:
  if actor.dead:continue
  var at: Vector3=actor.vehicle.global_position if actor.vehicle!=null else actor.global_position
  if at.distance_to(vehicle.global_position)<ALARM_RANGE*(1.0 if actor.vehicle!=null else 0.6):return true
 return false

func board(vehicle: BmpVehicle, actor: Hostile, role: String) -> void:
 actor.has_cover=false
 vehicle.board_crew(actor,role)
 if role=="driver":
  vehicle.driver_ai=BmpDriver.new();vehicle.driver_ai.setup(vehicle)
  vehicle.driver_ai.hold=true
 else:
  vehicle.gunner.manned=true;vehicle.gunner.allowed=true

# Out through the hatches and on with the fight on foot.
func bail(unit: Dictionary) -> void:
 var vehicle: BmpVehicle=unit.vehicle
 unit.state="lost"
 var index_out:=0
 for role in unit.crew:
  var actor: Hostile=unit.crew[role]
  if not is_instance_valid(actor) or actor.dead:continue
  if actor.vehicle!=null:
   vehicle.crew.erase(actor)
   actor.set_meta("bmp_role","")
   var spot:=vehicle.to_global(Vector3(-2.4 if index_out%2==0 else 2.4,0,-1.0+index_out*0.4))
   actor.disembark(battle.snap(spot)+Vector3.UP*0.1,vehicle.global_basis.z)
  index_out+=1
  actor.remove_meta("armour_crew")
  # On foot they hold the nearest firing position of the strongpoint.
  var sector:=int(unit.sector)
  actor.set_meta("battle_post",battle.position_point(sector,int(actor.get_meta("battle_position",0))))
  actor.has_cover=false
  battle.assign(actor)
 vehicle.gunner.manned=false
 vehicle.driver_ai=null

func nearest_position(index: int, at: Vector3) -> int:
 var best:=0
 var best_d:=INF
 var spots: Array=BattleMap.POSITIONS[index]
 for i in range(spots.size()):
  var d:=Vector2(at.x,at.z).distance_to(spots[i])
  if d<best_d:best_d=d;best=i
 return best

func manned_count() -> int:
 var n:=0
 for unit in units:if unit.state=="manned":n+=1
 return n

func clear() -> void:
 for vehicle in vehicles:
  if is_instance_valid(vehicle):vehicle.queue_free()
 vehicles.clear();units.clear()
