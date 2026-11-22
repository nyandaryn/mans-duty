class_name BotKit
extends RefCounted

# What a soldier carries and how he fights with it. Hostile runs the common
# soldier (contact, cover, rifle fire); the kit adds the job of its role:
# - "rifle": the rifleman, as Hostile does;
# - "mg": PKM, long bursts, fire on groups and on the cover they hold,
#   lying behind the bipod;
# - "sniper": SVD, single aimed shots from far off, the gunners, the
#   grenade launchers and the drone pilots first; keeps away from close
#   fighting;
# - "rpg7": RPG-7 with a mix of rounds (ROUND_MIX): the PG-7VL for the
#   vehicles, the OG-7V for groups in the open and in windows, the TBG-7V
#   for the houses they fire from; the rifle in between; keeps a round that
#   pierces armour while enemy vehicles are about, and changes the round in
#   the tube for the target when the bag has a better one;
# - "rpg22": a rifleman with RPG-22 tubes, used on vehicles (and on a house
#   once no armour is left);
# - "uav": FPV drones from behind cover: flies over the enemy, finds a
#   vehicle or men in the open from the air and strikes them.
const KITS := ["rifle","mg","sniper","rpg7","rpg22","uav"]
const WEAPON := {"rifle":"ak74","mg":"pkm","sniper":"svd","rpg7":"ak74","rpg22":"ak74","uav":"ak74"}
const TITLES := {"rifle":"стрілець","mg":"кулеметник","sniper":"снайпер","rpg7":"гранатометник","rpg22":"стрілець з РПГ-22","uav":"оператор БПЛА"}
# Grenade launchers: reach against a vehicle and against men or a house,
# time to bring it up (RPG-7 off the back; the RPG-22 off the back and into
# its firing position, "ready in about 10 s": an armed one, kept drawn out,
# only comes off the back — ARMED_DRAW), to aim, to reload the RPG-7 from the
# bag (manual: about 6 s) and to put it away; how far behind the danger
# zone of the jet reaches (RPG-7: 30 m; RPG-22: 15 m).
const LAUNCHER := {
 "rpg7":{"armour":330.0,"soft":300.0,"draw":2.2,"aim":1.6,"reload":6.0,"stow":1.4,"danger":30.0,"round":"pg7vl"},
 "rpg22":{"armour":200.0,"soft":170.0,"draw":7.0,"aim":1.4,"reload":0.0,"stow":1.0,"danger":15.0,"round":"rpg22"},
}
const ARMED_DRAW := 2.0
# The RPG-7 grenadier's bag beside the PG-7VL in the tube (the bag takes
# three rounds): one of these, picked by a hash of where he joins the fight,
# not the global RNG (seeded scenarios keep their course).
const ROUND_MIX := [{"pg7vl":2,"og7v":1,"tbg7v":0},{"pg7vl":1,"og7v":2,"tbg7v":0},{"pg7vl":1,"og7v":1,"tbg7v":1}]
# How far each round is worth firing: armour (the PG-7VL's 330 m; the
# TBG-7V on light armour within its 200 m aimed range), and men (the OG-7V's
# 350 m aimed range with the RPG-7V1, kept to 300).
const ROUND_REACH := {"pg7vl":{"armour":330.0,"soft":260.0},"og7v":{"armour":0.0,"soft":300.0},"tbg7v":{"armour":180.0,"soft":200.0}}
# Unloading a round to put in another, on top of the reload.
const UNLOAD := 1.5
const FPV_SCRIPT := "res://scripts/fpv_drone.gd"

var bot: Hostile
var game: Node3D
var kind := "rifle"
# Rounds left in the bag for the RPG-7 (by kind; grenades: all of them),
# the one in the tube, RPG-22 tubes on the back.
var rounds := {"pg7vl":0,"og7v":0,"tbg7v":0}
var grenades: int:
 get:
  var total:=0
  for which in rounds:total+=int(rounds[which])
  return total
var tubes := 0
var loaded := false
var loaded_round := ""
# The round to put in on the next reload ("" — the best for what is about),
# and whether he aims again once it is in (a change of round for a target).
var next_round := ""
var then_aim := false
# The RPG-22 on his back already armed: drawn out, it cannot be folded again.
var armed := false
# How long this draw takes (an armed RPG-22 is quicker).
var draw_time := 0.0
# The grenade job: "" or draw / aim / reload / stow.
var phase := ""
var clock := 0.0
var using := ""
var aim_at: Node3D
var aim_point := Vector3.INF
var cool := 0.0
var held := 0.0
var fired := 0
# FPV drones in the operator's bag and the one in the air.
var drones := {"fpv_heat":0,"fpv_frag":0}
var drone: Node3D
var drone_cool := 0.0
var flights := 0
var launcher_node: Node3D

static func make(owner: Hostile, id: String) -> BotKit:
 var kit:=BotKit.new()
 kit.bot=owner;kit.game=owner.game;kit.kind=id
 match id:
  "rpg7":
   var at: Vector3=owner.global_position if owner.is_inside_tree() else owner.position
   kit.rounds=ROUND_MIX[absi(hash([owner.friendly,roundi(at.x),roundi(at.z),int(owner.get_meta("battle_group",0))]))%ROUND_MIX.size()].duplicate()
   kit.tubes=1;kit.loaded=true;kit.loaded_round="pg7vl"
  "rpg22":kit.tubes=2 if owner.friendly else 1
  "uav":kit.drones={"fpv_heat":3,"fpv_frag":2}
 return kit

func title() -> String:return TITLES.get(kind,"стрілець")

func busy() -> bool:return phase!="" or piloting()

func piloting() -> bool:return is_instance_valid(drone) and drone.has_method("alive") and drone.alive()

# Stands still for the job (aims a launcher, flies a drone).
func holds() -> bool:return phase in ["aim","reload"] or piloting()

# Up from cover while the launcher is on the shoulder.
func exposed() -> bool:return phase=="aim"

func facing() -> Vector3:
 if phase in ["draw","aim"] and aim_point!=Vector3.INF:return aim_point
 return Vector3.INF

func blocks_rifle() -> bool:return busy()

# --- Who is the enemy ---------------------------------------------------------
func opponents() -> Array:
 return game.bots if bot.friendly else game.allies+[game.player]

func own() -> Array:
 return game.allies+[game.player] if bot.friendly else game.bots

static func alive_actor(actor: Node3D) -> bool:
 if not is_instance_valid(actor):return false
 if actor is Hostile:return not actor.dead and actor.vehicle==null
 if actor is Operator:return actor.is_inside_tree() and actor.health>0 and not actor.get_meta("battle_out",false)
 return false

static func vehicle_alive(vehicle: Node3D) -> bool:
 if not is_instance_valid(vehicle) or vehicle.get("destroyed"):return false
 var hull=vehicle.get("hull")
 return hull==null or not hull.burning

func enemy_vehicles() -> Array:
 var list:=[]
 for vehicle in game.get_tree().get_nodes_in_group("vehicles"):
  if vehicle.friendly!=bot.friendly and vehicle_alive(vehicle):list.append(vehicle)
 return list

func eye() -> Vector3:return bot.n_head.to_global(CharacterArt.EYE)

# Clear line from a point to a vehicle: the first thing on the line is it.
func sees_vehicle(from: Vector3, vehicle: Node3D) -> bool:
 var at:=vehicle.to_global(Vector3(0,1.1,0))
 var hit:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,at,1))
 return not hit.is_empty() and BlastSystem.strike_target(hit.collider)==vehicle

# --- Each think tick ------------------------------------------------------------
func think(interval: float) -> void:
 cool=maxf(0.0,cool-interval)
 drone_cool=maxf(0.0,drone_cool-interval)
 if bot.vehicle!=null or bot.collapse>0.3 or bot.concussion.incapacitated():return
 match kind:
  "rpg7","rpg22":consider_launch()
  "uav":consider_drone()
  "mg":gather_fire()

# A machine gunner lays his fire on where the most of them are.
func gather_fire() -> void:
 if bot.suppress_age>10.0:return
 var best:=bot.suppress_point
 var best_count:=0
 for actor in opponents():
  if not alive_actor(actor):continue
  var p: Vector3=actor.global_position
  if p.distance_to(bot.suppress_point)>14.0:continue
  var count:=0
  for other in opponents():
   if alive_actor(other) and other.global_position.distance_to(p)<6.0:count+=1
  if count>best_count:best_count=count;best=p+Vector3.UP*0.9
 if best_count>=2:bot.suppress_point=best

# --- Grenade launchers ---------------------------------------------------------
func launcher_ready() -> String:
 if kind=="rpg7" and (loaded or grenades>0):return "rpg7"
 if tubes>0:return "rpg22"
 return ""

func consider_launch() -> void:
 if phase!="" or cool>0.0 or not bot.alerted:return
 if bot.wound_timer>0 or bot.arm_wound>=0.5 or bot.weapon.phase!="":return
 var which:=launcher_ready()
 if which=="":return
 var spec: Dictionary=LAUNCHER[which]
 var from:=eye()
 # Armour first.
 var best: Node3D=null
 var best_d:=float(spec.armour)
 var vehicles:=enemy_vehicles()
 for vehicle in vehicles:
  var d:=from.distance_to(vehicle.global_position)
  if d<12.0 or d>best_d:continue
  if not sees_vehicle(from,vehicle):continue
  best=vehicle;best_d=d
 if best!=null:
  if which!="rpg7":
   begin(which,best,best.to_global(Vector3(0,1.1,0)))
   return
  # The PG-7VL; the TBG-7V on light armour close in; never the OG-7V
  # (with only those left he goes on with the men).
  var round:=pick_round(["pg7vl","tbg7v"],"armour",best_d)
  if round!="":
   begin(which,best,best.to_global(Vector3(0,1.1,0)),round)
   return
 # No armour in reach: a group, or the house they fire from. The RPG-7
 # keeps a round that pierces armour while there is any about; an RPG-22
 # goes on soft targets only when no enemy vehicle is left.
 if which=="rpg7":
  var point:=soft_target(from,float(spec.soft))
  if point==Vector3.INF:return
  var d:=from.distance_to(point)
  # Men in the open or at a window: the OG-7V; the house they hold: the
  # TBG-7V; the PG-7VL only as a spare.
  var order:=["tbg7v","og7v","pg7vl"] if soft_kind=="house" else ["og7v","tbg7v","pg7vl"]
  var round:=pick_round(order,"soft",d)
  if round=="" or (not vehicles.is_empty() and not spare_after(round)):return
  begin(which,null,point,round)
  return
 if not vehicles.is_empty():return
 var point:=soft_target(from,float(spec.soft))
 if point!=Vector3.INF:begin(which,null,point)

# The first round of a list he has (in the tube or the bag) that reaches.
func pick_round(order: Array, use: String, distance: float) -> String:
 for round in order:
  if distance>float(ROUND_REACH[round][use]):continue
  if (loaded and loaded_round==round) or int(rounds.get(round,0))>0:return round
 return ""

# After this round is fired, one that pierces armour is still left.
func spare_after(round: String) -> bool:
 var left:=int(rounds.pg7vl)+int(rounds.tbg7v)
 if loaded and loaded_round in ["pg7vl","tbg7v"]:left+=1
 if round in ["pg7vl","tbg7v"]:left-=1
 return left>0

# The round for the next reload: against armour while there is any about,
# else for men.
func reload_choice() -> String:
 if next_round!="" and int(rounds.get(next_round,0))>0:return next_round
 var order:=["pg7vl","tbg7v","og7v"] if not enemy_vehicles().is_empty() else ["og7v","tbg7v","pg7vl"]
 for round in order:
  if int(rounds.get(round,0))>0:return round
 return ""

# Three or more of them close together in sight, or the window a seen enemy
# fires from (a known contact behind a wall). soft_kind: "open" or "house".
var soft_kind := ""
func soft_target(from: Vector3, reach: float) -> Vector3:
 soft_kind="open"
 if bot.sees_player and is_instance_valid(bot.combat_target):
  var center: Vector3=bot.combat_target.global_position
  var d:=from.distance_to(center)
  if d>25.0 and d<reach:
   var near:=0
   for actor in opponents():
    if alive_actor(actor) and actor.global_position.distance_to(center)<7.0:near+=1
   if near>=3 and not own_near(center,14.0):return center+Vector3.UP*0.7
 if bot.suppress_age<6.0 and bot.last_visual_age<12.0:
  var point: Vector3=bot.suppress_point
  var d2:=from.distance_to(point)
  if d2>30.0 and d2<reach and not own_near(point,14.0):
   # Hidden behind something solid: the grenade on that wall.
   var hit:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,point,1))
   if not hit.is_empty() and Vector3(hit.position).distance_to(point)<5.0 and not hit.collider.has_meta("terrain"):
    soft_kind="house"
    return hit.position
 return Vector3.INF

func own_near(point: Vector3, radius: float) -> bool:
 for actor in own():
  if alive_actor(actor) and actor.global_position.distance_to(point)<radius:return true
 return false

func begin(which: String, target: Node3D, point: Vector3, round: String="") -> void:
 using=which;aim_at=target;aim_point=point
 phase="draw";clock=0.0;held=0.0
 # Another round wanted in the RPG-7: changed once it is off the back.
 next_round="";then_aim=false
 if which=="rpg7" and round!="" and not (loaded and loaded_round==round):next_round=round;then_aim=true
 draw_time=ARMED_DRAW if using=="rpg22" and armed else float(LAUNCHER[using].draw)
 show_launcher(true)

# The job in progress; true while it keeps the rifle down.
func act(delta: float) -> bool:
 if phase=="" and not piloting():return false
 if piloting():
  pose_pilot()
  return true
 if bot.wound_timer>0 or bot.collapse>0.2 or bot.concussion.active():
  # Knocked about: the launcher goes back on the back.
  if phase in ["draw","aim"]:phase="stow";clock=0.0
 clock+=delta
 var spec: Dictionary=LAUNCHER[using]
 if is_instance_valid(aim_at):
  if not vehicle_alive(aim_at):aim_at=null;phase="stow";clock=0.0
  else:aim_point=aim_at.to_global(Vector3(0,1.1,0))
 match phase:
  "draw":
   # The sleeve locks out two seconds before he is ready.
   if using=="rpg22" and not armed and clock>=draw_time-2.0:
    armed=true
    show_launcher(true)
   if clock>=draw_time:
    phase="reload" if then_aim else "aim";clock=0.0
  "aim":
   if clock>=float(spec.aim)+eye().distance_to(aim_point)*0.004:
    if safe_behind(float(spec.danger)):
     fire()
    else:
     held+=delta
     if held>3.0:phase="stow";clock=0.0
  "reload":
   if clock>=float(spec.reload)+(UNLOAD if loaded else 0.0):
    var round:=reload_choice()
    if round!="":
     # The round taken out goes back in the bag.
     if loaded and loaded_round!="":rounds[loaded_round]=int(rounds.get(loaded_round,0))+1
     rounds[round]=int(rounds[round])-1
     loaded=true;loaded_round=round
    next_round=""
    show_round(true)
    if then_aim and loaded and aim_point!=Vector3.INF:phase="aim"
    else:phase="stow"
    then_aim=false;clock=0.0
  "stow":
   if clock>=float(spec.stow):
    phase="";show_launcher(false)
    cool=randf_range(4.0,9.0)
 pose_launcher()
 return true

# Nobody of his own in the jet behind him and no wall at his back.
func safe_behind(danger: float) -> bool:
 var muzzle:=launcher_muzzle()
 var back:=-muzzle.direction_to(aim_point)
 for actor in own():
  if actor==bot or not alive_actor(actor):continue
  var rel: Vector3=actor.global_position+Vector3.UP-muzzle
  var along:=rel.dot(back)
  if along<0.0 or along>danger:continue
  if (rel-back*along).length()<along*0.5+1.5:return false
 var wall:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle,muzzle+back*2.0,1,[bot.get_rid()]))
 return wall.is_empty()

func launcher_muzzle() -> Vector3:
 if is_instance_valid(launcher_node) and not bot.render_far and launcher_node.has_node("Muzzle"):
  return (launcher_node.get_node("Muzzle") as Node3D).global_position
 return bot.global_position+Vector3.UP*lerpf(1.45,1.05,clampf(bot.stance,0,1))+bot.global_basis.x*0.18-bot.global_basis.z*0.55

func fire() -> void:
 var spec: Dictionary=LAUNCHER[using]
 var round: String=loaded_round if using=="rpg7" and loaded_round!="" else String(spec.round)
 var muzzle:=launcher_muzzle()
 var point:=aim_point
 # The lead on a moving vehicle: its speed over the time of flight, judged
 # by eye.
 if is_instance_valid(aim_at):
  var velocity: Vector3=aim_at.linear_velocity if aim_at is RigidBody3D else Vector3.ZERO
  point+=velocity*BlastSystem.rocket_time(round,muzzle.distance_to(point))*randf_range(0.7,1.25)
 var distance:=muzzle.distance_to(point)
 # Range judged with the stadia scale of the PGO-7 (RPG-7) or by eye
 # (RPG-22), the elevation laid off the scale.
 var judged:=distance*(1.0+randf_range(-0.07,0.07) if using=="rpg7" else 1.0+randf_range(-0.12,0.12))
 var line:=muzzle.direction_to(point)
 var axis:=line.cross(Vector3.UP).normalized()
 line=line.rotated(axis,BlastSystem.rocket_elevation(round,judged))
 var wobble:=0.004+bot.suppression*0.002+(0.004 if bot.stance<0.5 else 0.0)
 line=(line+Vector3(randf_range(-wobble,wobble),randf_range(-wobble,wobble),randf_range(-wobble,wobble))).normalized()
 game.blasts.launch(muzzle,line,bot,round)
 var report:="rpg7_launch" if using=="rpg7" else "rpg22_launch"
 game.spatial_shot(report if game.sounds.has(report) else "rpo_launch",muzzle,3)
 game.alert_opponents(bot,muzzle)
 # The backblast raises dust behind.
 var effects:=GradEffects.shared(game)
 for k in range(3):effects.puff(muzzle-line*(1.5+k*1.8),0.9+k*0.4,0.75)
 fired+=1
 if using=="rpg7":
  loaded=false;loaded_round=""
  show_round(false)
  if grenades>0:phase="reload";clock=0.0
  else:phase="stow";clock=0.0
 else:
  tubes-=1
  armed=false
  # The empty tube is thrown away.
  discard_tube()
  phase="stow";clock=0.0
 aim_at=null

# --- FPV drones -------------------------------------------------------------------
func consider_drone() -> void:
 if piloting() or drone_cool>0.0 or not bot.alerted:return
 if not ResourceLoader.exists(FPV_SCRIPT):return
 var which:="fpv_heat" if int(drones.fpv_heat)>0 and (not enemy_vehicles().is_empty() or int(drones.fpv_frag)==0) else "fpv_frag"
 if int(drones[which])<=0:return
 var area:=search_center()
 if area==Vector3.INF:return
 var script: Script=load(FPV_SCRIPT)
 var from:=bot.global_position+Vector3.UP*1.2-bot.global_basis.z*1.0
 drone=script.launch(game,bot,bot.friendly,"heat" if which=="fpv_heat" else "frag",from)
 if drone==null:return
 drones[which]=int(drones[which])-1
 flights+=1
 drone.search_area(area,90.0,pick_target)
 drone_cool=randf_range(25.0,45.0)

# Where to look for them: what this side has seen of the enemy lately,
# else ahead toward their side.
func search_center() -> Vector3:
 if bot.suppress_age<30.0:return bot.suppress_point
 if bot.alerted and bot.target!=Vector3.ZERO and bot.target.distance_to(bot.global_position)>40.0:return bot.target
 var battle=game.battle
 if battle.active:
  if bot.friendly:return battle.objective_point(int(bot.get_meta("battle_group",0)))
  for vehicle in enemy_vehicles():return vehicle.global_position
  for actor in opponents():
   if alive_actor(actor):return actor.global_position
 return Vector3.INF

# What the drone camera makes out from the air (called by the FPV): an
# enemy vehicle first, else a group of men, else one man in the open; never
# with men of our own close by.
func pick_target(from: Vector3, reach: float) -> Node3D:
 var space:=game.get_world_3d().direct_space_state
 var best: Node3D=null
 var best_d:=reach
 for vehicle in enemy_vehicles():
  var d:=from.distance_to(vehicle.global_position)
  if d>best_d or own_near(vehicle.global_position,10.0):continue
  if not sees_vehicle(from,vehicle):continue
  best=vehicle;best_d=d
 if best!=null:return best
 var best_score:=-INF
 var checked:=0
 for actor in opponents():
  if not alive_actor(actor):continue
  var p: Vector3=actor.global_position+Vector3.UP*0.9
  var d:=from.distance_to(p)
  if d>reach:continue
  checked+=1
  if checked>24:break
  if own_near(p,12.0):continue
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(from,p,1))
  if not hit.is_empty():continue
  var group:=0
  for other in opponents():
   if alive_actor(other) and other.global_position.distance_to(p)<6.0:group+=1
  var score:=float(group)*40.0-d
  if score>best_score:best_score=score;best=actor
 return best

# Goggles on, the controls in the hands, crouched by his cover.
func pose_pilot() -> void:
 bot.stance=move_toward(bot.stance,1.0,0.1)
 if bot.render_far:return
 var rifle: Node3D=bot.n_rifle
 rifle.position=Vector3(0.22,0.95,0.05);rifle.rotation=Vector3(-1.2,0,0.3)
 bot.pose_arm("Left",Vector3(-0.12,1.12,-0.30))
 bot.pose_arm("Right",Vector3(0.10,1.12,-0.30))

# --- The launcher on the body --------------------------------------------------
func show_launcher(on: bool) -> void:
 if not on:
  if is_instance_valid(launcher_node):launcher_node.queue_free()
  launcher_node=null
  bot.n_rifle.visible=true
  return
 if is_instance_valid(launcher_node):launcher_node.queue_free()
 launcher_node=launcher_model(using,armed if using=="rpg22" else loaded)
 bot.model.add_child(launcher_node)
 if using=="rpg7":LauncherRig.seat_round(launcher_node,loaded_round if loaded else "")
 launcher_node.position=Vector3(0.18,1.28,0.25)
 launcher_node.rotation=Vector3(PI/2,0,-0.2)

# Built once per kind and state, then copied: the meshes are shared. The
# templates stay out of the tree, so the game frees them when it leaves
# (clear_models), or they would leak at exit.
static var models := {}
static func clear_models() -> void:
 for key in models:
  if is_instance_valid(models[key]):(models[key] as Node).free()
 models.clear()
static func launcher_model(which: String, ready: bool) -> Node3D:
 var key:="%s/%s" % [which,str(ready)]
 if models.has(key) and is_instance_valid(models[key]):return (models[key] as Node3D).duplicate()
 var built:=build_launcher(which,ready)
 models[key]=built.duplicate()
 return built

static func build_launcher(which: String, ready: bool) -> Node3D:
 var path:="res://scripts/%s_art.gd" % which
 if ResourceLoader.exists(path):
  var art: Script=load(path)
  if art.has_method("build"):
   var built=art.build(ready)
   if built is Node3D:
    # The other rounds of the RPG-7, hidden in the muzzle (seat_round).
    if which=="rpg7":LauncherRig.add_round_models(built)
    return built
 # Plain stand-in: a tube with the grenade or the folded sights.
 var root:=Node3D.new()
 var tube:=MeshInstance3D.new()
 var mesh:=CylinderMesh.new()
 mesh.top_radius=0.03 if which=="rpg7" else 0.038;mesh.bottom_radius=mesh.top_radius
 mesh.height=0.95 if which=="rpg7" else 0.85;mesh.radial_segments=8
 var paint:=StandardMaterial3D.new();paint.albedo_color=Color("4b4f3a");mesh.material=paint
 tube.mesh=mesh;tube.rotation.x=PI/2;root.add_child(tube)
 if which=="rpg7" and ready:
  var head:=MeshInstance3D.new();var cone:=CylinderMesh.new()
  cone.top_radius=0.012;cone.bottom_radius=0.0465;cone.height=0.36;cone.radial_segments=8;cone.material=paint
  head.mesh=cone;head.rotation.x=-PI/2;head.position.z=-0.62;root.add_child(head)
 return root

# Where the launcher rests on the shoulder and where the hands hold it,
# from the constants of its art (SHOULDER, GRIP, SUPPORT).
static var holds_cache := {}
static func art_points(which: String) -> Dictionary:
 if holds_cache.has(which):return holds_cache[which]
 var points:={"SHOULDER":Vector3(0,-0.03,0.25),"GRIP":Vector3(0,-0.10,-0.18),"SUPPORT":Vector3(0,-0.03,-0.30)}
 var path:="res://scripts/%s_art.gd" % which
 if ResourceLoader.exists(path):
  var map:=(load(path) as Script).get_script_constant_map()
  for key in points.keys():
   if map.has(key):points[key]=map[key]
 holds_cache[which]=points
 return points

# The top of the right shoulder in the body's frame (shoulder pivot
# (0.218, 1.38) less the deltoid): where the tube lies.
const SHOULDER_TOP := Vector3(0.16,1.50,0.02)
const CARRY := Vector3(0.20,1.05,0.18)

# On the right shoulder at the aim point, the firing hand on the grip, the
# other under the tube; down along the body while it is brought up or put
# away.
func pose_launcher() -> void:
 if not is_instance_valid(launcher_node):return
 bot.n_rifle.visible=false
 if bot.render_far:return
 var points:=art_points(using)
 var up:=1.0
 if phase=="draw":up=smoothstep(0.2,1.0,clock/maxf(draw_time,0.1))
 elif phase=="stow":up=1.0-smoothstep(0.0,1.0,clock/float(LAUNCHER[using].stow))
 elif phase=="reload":up=0.35
 var pitch:=0.0
 var yaw:=0.0
 if aim_point!=Vector3.INF:
  var rel:=bot.model.global_transform.affine_inverse()*aim_point-SHOULDER_TOP
  pitch=clampf(atan2(rel.y,maxf(1.0,Vector2(rel.x,rel.z).length())),-0.6,0.8)
  yaw=clampf(atan2(-rel.x,-rel.z),-0.4,0.4)
 var aim:=Basis.from_euler(Vector3(pitch,yaw,0))
 var carry:=Basis.from_euler(Vector3(PI/2-0.3,0,-0.2))
 var on_shoulder:=SHOULDER_TOP-aim*Vector3(points.SHOULDER)
 launcher_node.transform=Transform3D(carry.slerp(aim,up),CARRY.lerp(on_shoulder,up))
 bot.pose_arm("Right",launcher_node.transform*Vector3(points.GRIP))
 bot.pose_arm("Left",launcher_node.transform*Vector3(points.SUPPORT))

# The round in the muzzle of the RPG-7 (the one loaded), gone with the
# shot, back on reload.
func show_round(on: bool) -> void:
 if is_instance_valid(launcher_node) and using=="rpg7":LauncherRig.seat_round(launcher_node,loaded_round if on and loaded else "")

# The empty RPG-22 tube is thrown down where he fired from.
func discard_tube() -> void:
 if not is_instance_valid(launcher_node):return
 var tube:=launcher_node
 launcher_node=null
 var at:=tube.global_position
 tube.get_parent().remove_child(tube)
 game.world_root.add_child(tube)
 at.y=game.district.ground_height(at)+0.04
 tube.global_transform=Transform3D(Basis.from_euler(Vector3(0,randf()*TAU,0)),at+bot.global_basis.x*0.5)
 game.get_tree().create_timer(120.0).timeout.connect(tube.queue_free)

func clear() -> void:
 show_launcher(false)
 phase=""
