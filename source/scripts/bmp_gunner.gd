class_name BmpGunner
extends RefCounted

# The gunner-operator in the left seat of the turret: the 2A42 30 mm cannon
# on the 2E36-1 stabilizer (30°/s in traverse, −5°…+74°) and the coaxial
# PKT. He searches through the BPK sight, holds the aim on the move and fires
# short bursts: high explosive at men behind cover, in houses or far away,
# the machine gun at men in the open nearby, armour-piercing (3UBR6, about
# 35 mm at 500 m) at enemy vehicles, which come first. He never fires
# across his own men, and only when the squad lets him. Either side: the
# vehicle's `friendly` says whose men are whose.
const TRAVERSE := 0.52
const ELEVATE := 0.61
const MIN_PITCH := -0.087
const MAX_PITCH := 1.29
const CANNON_INTERVAL := 0.2
const PKT_INTERVAL := 0.085
const SHELL_SPEED := 960.0
const REACH := 900.0
# 2A42 dead ground around the vehicle: below this the PKT takes over.
const CANNON_MINIMUM := 22.0
var vehicle: BmpVehicle
var game: Node3D
var yaw := 0.0
var pitch := 0.0
var rest_yaw := 0.0
var target: Node3D
var watching: Dictionary={}
var search_left := 0.0
var he := 340
var ap := 160
var pkt := 2000
var burst_left := 0
var weapon := ""
var shot_clock := 0.0
var pause_left := 0.0
var shells: Array[Dictionary]=[]
var tracers: Array=[]
var allowed := true
var manned := true
var since_burst := 100.0
var shots := 0
var ray: PhysicsRayQueryParameters3D
static var tracer_mesh: BoxMesh
static var tracer_material: StandardMaterial3D

func setup(owner: BmpVehicle) -> void:
 vehicle=owner;game=owner.game
 ray=PhysicsRayQueryParameters3D.create(Vector3.ZERO,Vector3.DOWN,1,[owner.get_rid()])

func enemies() -> Array:
 var list:=[]
 list.append_array(game.bots if vehicle.friendly else game.allies+[game.player])
 for other in game.get_tree().get_nodes_in_group("vehicles"):
  if other!=vehicle and other.friendly!=vehicle.friendly:list.append(other)
 return list

# His own side: never under his fire.
func own() -> Array:
 return game.allies+[game.player] if vehicle.friendly else game.bots

static func is_vehicle(actor: Node3D) -> bool:return actor.is_in_group("vehicles")

func fighting(actor: Node3D) -> bool:
 if not is_instance_valid(actor):return false
 if actor is Hostile:return not actor.dead and actor.collapse<=0.5 and actor.vehicle==null and not actor.concussion.incapacitated()
 if actor is Operator:
  return actor.is_inside_tree() and actor.health>0 and not actor.get_meta("battle_out",false) and (game.player_vehicle()==null or game.bmp.head_out)
 # A vehicle: until it burns or is wrecked.
 if actor.get("destroyed"):return false
 var state=actor.get("hull")
 return state==null or not state.burning

# Where he lays the sight on a man or a vehicle.
func center(actor: Node3D) -> Vector3:
 if actor is Hostile:return actor.global_position+Vector3.UP*lerpf(1.2,0.35,maxf(actor.tactical_prone,actor.collapse))
 if actor is Operator:return actor.camera.global_position+Vector3.DOWN*0.35
 return actor.to_global(Vector3(0,1.15,0))

func sight() -> Vector3:return vehicle.art.turret.to_global(Vector3(-0.42,0.95,-0.4))

func clear_to(from: Vector3, to: Vector3) -> bool:
 ray.from=from;ray.to=to;ray.collision_mask=1
 return game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func tick(delta: float) -> void:
 since_burst+=delta
 fly(delta)
 if vehicle.destroyed or not manned or vehicle.hull.weapon_out or vehicle.hull.burning:return
 search_left-=delta
 if search_left<=0:
  search_left=0.55+randf()*0.2
  search(0.6)
 aim(delta)
 fire(delta)
 vehicle.art.turret.rotation.y=yaw
 vehicle.art.gun.rotation.x=pitch

# Through the sight: a man must stay in view a moment before he is made out
# and laid on; the nearest, then whoever is already laid on, comes first.
func search(step: float) -> void:
 var eye:=sight()
 var candidates: Array=[]
 for actor in enemies():
  if not fighting(actor):continue
  var d:=eye.distance_to(actor.global_position)
  var armour:=is_vehicle(actor)
  if d>(REACH*1.6 if armour else REACH):continue
  # Enemy armour first, then the grenade launchers that threaten his own.
  var weight:=d*(0.35 if armour else (0.6 if actor.get("kit") in ["rpg7","rpg22"] else 1.0))
  candidates.append([weight,actor,d])
 candidates.sort_custom(func(a,b):return a[0]<b[0])
 var seen: Dictionary={}
 for i in range(mini(candidates.size(),10)):
  var actor: Node3D=candidates[i][1]
  if not clear_to(eye,center(actor)):continue
  var id:=actor.get_instance_id()
  seen[id]=float(watching.get(id,0.0))+step
 watching=seen
 if is_instance_valid(target) and fighting(target) and watching.has(target.get_instance_id()):return
 target=null
 for i in range(candidates.size()):
  var actor: Node3D=candidates[i][1]
  var id:=actor.get_instance_id()
  # Recognition takes longer the further away the man is; a vehicle is
  # made out sooner.
  if float(watching.get(id,0.0))>=0.5+float(candidates[i][2])/(900.0 if is_vehicle(actor) else 400.0):target=actor;break

func aim_point() -> Vector3:
 if not is_instance_valid(target):return Vector3.INF
 return center(target)

func aim(delta: float) -> void:
 var wanted_yaw:=rest_yaw
 var wanted_pitch:=0.0
 var point:=aim_point()
 if point!=Vector3.INF:
  var pivot:Vector3=vehicle.art.gun.global_position
  var local:Vector3=vehicle.global_basis.inverse()*(point-pivot)
  wanted_yaw=atan2(-local.x,-local.z)
  wanted_pitch=clampf(atan2(local.y,Vector2(local.x,local.z).length()),MIN_PITCH,MAX_PITCH)
 yaw+=clampf(angle_difference(yaw,wanted_yaw),-TRAVERSE*delta,TRAVERSE*delta)
 pitch=move_toward(pitch,wanted_pitch,ELEVATE*delta)

func barrel() -> Vector3:return -vehicle.art.gun.global_basis.z

func fire(delta: float) -> void:
 shot_clock-=delta
 pause_left-=delta
 var point:=aim_point()
 if point==Vector3.INF or not allowed:burst_left=0;return
 var muzzle: Vector3=vehicle.art.muzzle.global_position
 var direction:=muzzle.direction_to(point)
 if barrel().angle_to(direction)>0.02:return
 if burst_left<=0:
  if pause_left>0:return
  var distance:=muzzle.distance_to(point)
  weapon=choose_weapon(distance)
  if weapon=="":return
  if not safe(muzzle,point):return
  burst_left=randi_range(8,14) if weapon=="pkt" else randi_range(3,5)
  shot_clock=0.0
 while burst_left>0 and shot_clock<=0.0:
  if weapon=="cannon":shoot_cannon(muzzle)
  elif weapon=="ap":shoot_ap(muzzle)
  else:shoot_pkt()
  burst_left-=1
  shots+=1
  shot_clock+=PKT_INTERVAL if weapon=="pkt" else CANNON_INTERVAL
  if burst_left==0:
   pause_left=randf_range(1.2,2.6);since_burst=0.0

func choose_weapon(distance: float) -> String:
 if is_vehicle(target):
  if ap>0 and distance<1500.0:return "ap"
  return "cannon" if he>0 else ""
 var covered: bool=(target is Hostile and (target.has_cover or target.tactical_prone>0.5)) or not clear_to(sight(),target.global_position+Vector3.UP*0.4)
 if distance>=CANNON_MINIMUM and he>0 and (covered or distance>400.0):return "cannon"
 if pkt>0 and distance<700.0:return "pkt"
 if he>0 and distance>=CANNON_MINIMUM:return "cannon"
 return ""

# No friendly soldier near the line of fire or near the burst.
func safe(from: Vector3, to: Vector3) -> bool:
 var reach:=7.0 if weapon=="cannon" else 3.0
 for actor in own():
  if not is_instance_valid(actor):continue
  if actor is Hostile and (actor.dead or actor.vehicle!=null):continue
  if actor is Operator and (not vehicle.friendly or actor.health<=0 or actor.get_meta("battle_out",false) or game.player_vehicle()!=null):continue
  var p: Vector3=actor.global_position+Vector3.UP
  if p.distance_to(to)<reach:return false
  var along:=(p-from).dot(from.direction_to(to))
  if along<1.0 or along>from.distance_to(to):continue
  if p.distance_to(from+from.direction_to(to)*along)<2.5:return false
 return true

func spread(base: float) -> Vector3:
 var moving:=clampf(vehicle.linear_velocity.length()/8.0,0,1)
 var s:=base+moving*0.004
 return Vector3(randf_range(-s,s),randf_range(-s,s),randf_range(-s,s))

func shoot_cannon(muzzle: Vector3) -> void:
 he-=1
 var direction:=(barrel()+spread(0.0012)).normalized()
 ray.from=muzzle;ray.to=muzzle+direction*1500.0;ray.collision_mask=1|4
 var hit:=game.get_world_3d().direct_space_state.intersect_ray(ray)
 var point:Vector3=hit.position if not hit.is_empty() else ray.to
 shells.append({"point":point,"left":muzzle.distance_to(point)/SHELL_SPEED})
 streak(muzzle,point,0.09,Color(1.0,0.55,0.2))
 game.spatial_shot("mortar_launch",muzzle,-3)
 game.alert_opponents(vehicle,muzzle)
 vehicle.gunner_recoil()

# Armour-piercing tracer: the slug strikes the armour where the shot lands.
func shoot_ap(muzzle: Vector3) -> void:
 ap-=1
 var direction:=(barrel()+spread(0.0010)).normalized()
 ray.from=muzzle;ray.to=muzzle+direction*1800.0;ray.collision_mask=1|4
 var hit:=game.get_world_3d().direct_space_state.intersect_ray(ray)
 var point:Vector3=hit.position if not hit.is_empty() else ray.to
 var struck: Object=hit.get("collider")
 shells.append({"point":point,"left":muzzle.distance_to(point)/SHELL_SPEED,"ap":true,"collider":struck,"direction":direction,"distance":muzzle.distance_to(point),"normal":hit.get("normal",Vector3.UP)})
 streak(muzzle,point,0.09,Color(1.0,0.45,0.25))
 game.spatial_shot("mortar_launch",muzzle,-3)
 game.alert_opponents(vehicle,muzzle)
 vehicle.gunner_recoil()

func shoot_pkt() -> void:
 pkt-=1
 var origin: Vector3=vehicle.art.coax.global_position
 var direction:=(barrel()+spread(0.0025)).normalized()
 game.ballistics.launch(origin,direction,"svd",95.0,vehicle)
 if shots%3==0:streak(origin,origin+direction*minf(600.0,origin.distance_to(aim_point())+20.0),0.05,Color(1.0,0.35,0.25))
 game.spatial_shot("svd",origin,-4)
 game.alert_opponents(vehicle,origin)

func fly(delta: float) -> void:
 for i in range(shells.size()-1,-1,-1):
  shells[i].left-=delta
  if shells[i].left<=0:
   var shell: Dictionary=shells[i]
   shells.remove_at(i)
   if shell.get("ap",false):
    var struck: Object=shell.collider
    if is_instance_valid(struck) and struck.has_method("vehicle_hit"):
     struck.vehicle_hit(shell.point,shell.direction,"ap30",VehicleArmor.penetration("ap30",shell.distance))
    game.impact(shell.point,shell.normal,struck as Node3D)
   else:game.blasts.detonate(shell.point,"cannon")
 for i in range(tracers.size()-1,-1,-1):
  tracers[i][1]-=delta
  if tracers[i][1]<=0:
   if is_instance_valid(tracers[i][0]):tracers[i][0].queue_free()
   tracers.remove_at(i)

# A tracer: a short glowing streak along the shot.
func streak(from: Vector3, to: Vector3, life: float, color: Color) -> void:
 if tracer_mesh==null:
  tracer_mesh=BoxMesh.new();tracer_mesh.size=Vector3(0.05,0.05,1.0)
  tracer_material=StandardMaterial3D.new();tracer_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  tracer_material.vertex_color_use_as_albedo=false;tracer_material.albedo_color=Color(1.0,0.6,0.3)
 var length:=from.distance_to(to)
 if length<1.0:return
 var node:=MeshInstance3D.new();node.mesh=tracer_mesh;node.material_override=tracer_material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 vehicle.get_parent().add_child(node)
 node.look_at_from_position((from+to)*0.5,to,Vector3.UP if absf(from.direction_to(to).y)<0.98 else Vector3.RIGHT)
 node.scale=Vector3(1,1,minf(length,60.0))
 node.global_position=from+from.direction_to(to)*minf(length,60.0)*0.5+from.direction_to(to)*minf(length*0.4,200.0)
 tracers.append([node,life])

func clear() -> void:
 for item in tracers:
  if is_instance_valid(item[0]):item[0].queue_free()
 tracers.clear();shells.clear()
