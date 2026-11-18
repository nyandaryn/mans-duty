class_name BlastSystem
extends Node3D

# Dimensionless, hand-tuned game damage. No pressure/impulse, TNT equivalence,
# medical thresholds or real-world lethal-radius prediction is implemented.
const EFFECT_RANGE := 16.0
# O-832DU: steel body, 0.45 kg TNT, impact fuse M-6. Fragments reach much
# further than the thermobaric RPO-A pressure effect; values remain game units.
const MINE_RANGE := 24.0
const MINE_DAMAGE := 260.0
# 9M22U: 18.4 kg warhead with 6.4 kg of explosive, impact fuse MRV on
# instantaneous action. Still dimensionless game units.
const GRAD_RANGE := 42.0
const GRAD_DAMAGE := 520.0
var game: Node3D
var rockets: Array[Dictionary]=[]
var mines: Array[Dictionary]=[]
var grads: Array[Dictionary]=[]
var detonations := 0
var last_detonation := Vector3.INF

func _ready() -> void:BlastEffect.prepare_textures()

func clear() -> void:
 rockets.clear()
 mines.clear()
 for grad in grads:
  if is_instance_valid(grad.node):grad.node.queue_free()
 grads.clear()
 last_detonation=Vector3.INF
 for child in get_children():child.queue_free()

func launch(origin: Vector3, direction: Vector3, shooter: Operator) -> void:
 var excluded: Array[RID]=[shooter.get_rid()]
 for area in shooter.find_children("Hit_*","Area3D",true,false):excluded.append(area.get_rid())
 rockets.append({"position":origin,"velocity":direction.normalized()*ShmelArt.INITIAL_SPEED,"age":0.0,"excluded":excluded})

func launch_mine(origin: Vector3, velocity: Vector3, shooter: Node3D) -> void:
 var excluded: Array[RID]=[]
 if shooter is CollisionObject3D:excluded.append(shooter.get_rid())
 for area in shooter.find_children("Hit_*","Area3D",true,false):excluded.append(area.get_rid())
 if shooter is Hostile:
  for area in shooter.hitboxes:excluded.append(area.get_rid())
 mines.append({"position":origin,"velocity":velocity,"age":0.0,"excluded":excluded,"whistle":false})

func launch_grad(shot: Dictionary, launcher: Node3D) -> void:
 var excluded: Array[RID]=[launcher.get_rid()]
 # The commander in the cab is part of the vehicle for the departing rocket.
 if is_instance_valid(game.player):
  excluded.append(game.player.get_rid())
  for area in game.player.find_children("Hit_*","Area3D",true,false):excluded.append(area.get_rid())
 shot.excluded=excluded
 shot.node=GradEffects.rocket_node(game)
 shot.origin=shot.position
 grads.append(shot)

# 9M22U rockets: the same equations as the firing tables, a ray per step.
func fly_grads(delta: float) -> void:
 var effects:=GradEffects.shared(game)
 for index in range(grads.size()-1,-1,-1):
  var shot: Dictionary=grads[index]
  var from: Vector3=shot.position
  var left:=delta
  while left>0.0:
   var t: float=shot.age
   var dt:=minf(left,1.0/120.0 if t<GradBallistics.BURN+0.2 else 1.0/60.0)
   if t<GradBallistics.BURN and t+dt>GradBallistics.BURN:dt=GradBallistics.BURN-t+0.00001
   GradBallistics.advance(shot,dt)
   left-=dt
  var to: Vector3=shot.position
  var hit:={}
  for attempt in range(3):
   var query:=PhysicsRayQueryParameters3D.create(from,to,1|16,shot.excluded)
   query.collide_with_areas=true;query.hit_from_inside=true
   hit=get_world_3d().direct_space_state.intersect_ray(query)
   if hit.is_empty() or not hit.collider.has_meta("boundary"):break
   shot.excluded.append(hit.rid);hit={}
  var crown:=tree_strike(from,to,shot)
  if hit.is_empty() and crown!=Vector3.INF:hit={"position":crown,"normal":Vector3.UP}
  effects.trail(from,to,float(shot.age))
  var node: Node3D=shot.node
  if not hit.is_empty():
   grads.remove_at(index)
   if is_instance_valid(node):node.queue_free()
   detonate(Vector3(hit.position)+Vector3(hit.normal)*0.1,"grad")
   continue
  if float(shot.age)>200.0 or to.y<-200.0:
   grads.remove_at(index)
   if is_instance_valid(node):node.queue_free()
   continue
  if is_instance_valid(node):
   var velocity: Vector3=shot.velocity
   node.global_position=to
   if velocity.length()>1.0:node.look_at(to+velocity,Vector3.UP if absf(velocity.normalized().y)<0.99 else Vector3.RIGHT)
   node.get_node("Flame").visible=float(shot.age)<GradBallistics.BURN

# A rocket skimming a tree line in the first few hundred metres bursts in the
# crowns: the firing position needs a clear line ahead.
func tree_strike(from: Vector3, to: Vector3, shot: Dictionary) -> Vector3:
 var area: OperationArea=game.district.operation_area if is_instance_valid(game.district) else null
 if area==null or Vector3(shot.origin).distance_to(to)>900.0:return Vector3.INF
 var ground:=area.data.height(to.x,to.z)
 if to.y-ground>24.0:return Vector3.INF
 var key:=Vector2i(floori(to.x/OperationArea.TREE_CHUNK),floori(to.z/OperationArea.TREE_CHUNK))
 for i in area.tree_chunks.get(key,PackedInt32Array()):
  var tree:=Vector2(area.tree_x[i],area.tree_z[i])
  var flat:=Geometry2D.get_closest_point_to_segment(tree,Vector2(from.x,from.z),Vector2(to.x,to.z))
  if flat.distance_to(tree)>2.6:continue
  var top:=area.data.height(tree.x,tree.y)+area.tree_h[i]
  var along:=Vector2(from.x,from.z).distance_to(flat)/maxf(Vector2(from.x,from.z).distance_to(Vector2(to.x,to.z)),0.001)
  var y:=lerpf(from.y,to.y,along)
  if y<top and y>top-area.tree_h[i]*0.75:return Vector3(flat.x,y,flat.y)
 return Vector3.INF

func fly_mines(step: float) -> void:
 for index in range(mines.size()-1,-1,-1):
  var mine := mines[index]
  var from: Vector3=mine.position
  var next := MortarBallistics.advance(from,mine.velocity,step)
  var to: Vector3=next[0]
  mine.velocity=next[1];mine.age+=step
  var hit := {}
  for attempt in range(3):
   var query := PhysicsRayQueryParameters3D.create(from,to,1|16,mine.excluded)
   query.collide_with_areas=true;query.hit_from_inside=true
   hit=get_world_3d().direct_space_state.intersect_ray(query)
   # The invisible edge of the play area is not a target.
   if hit.is_empty() or not hit.collider.has_meta("boundary"):break
   mine.excluded.append(hit.rid);hit={}
  if not hit.is_empty():
   mines.remove_at(index)
   detonate(hit.position+hit.normal*0.05,"mine")
   continue
  if mine.age>120 or to.y<-60:mines.remove_at(index);continue
  mine.position=to
  var falling: Vector3=mine.velocity
  # The descending mine is heard in its last second and a half.
  if not mine.whistle and falling.y<0 and is_instance_valid(game.player):
   var height: float=to.y-game.district.ground_height(to)
   if height<-falling.y*1.5 and game.player.global_position.distance_to(to)<220:
    mine.whistle=true
    game.spatial_shot("mine_whistle",to,-4)

func _physics_process(delta: float) -> void:
 if not game.running or game.paused:return
 if not grads.is_empty():fly_grads(minf(delta,0.1))
 var remaining := minf(delta,0.25)
 while remaining>0:
  var step := minf(remaining,1.0/120);remaining-=step
  if not mines.is_empty():fly_mines(step)
  for index in range(rockets.size()-1,-1,-1):
   var rocket := rockets[index]
   var from: Vector3=rocket.position
   rocket.velocity+=Vector3.DOWN*9.81*step
   rocket.velocity*=exp(-0.018*step)
   var next: Vector3=from+Vector3(rocket.velocity)*step
   var query := PhysicsRayQueryParameters3D.create(from,next,1|16,rocket.excluded)
   query.collide_with_areas=true;query.hit_from_inside=true
   var hit := get_world_3d().direct_space_state.intersect_ray(query)
   rocket.age+=step
   if not hit.is_empty():
    rockets.remove_at(index)
    detonate(hit.position+hit.normal*0.035)
   elif rocket.age>9:rockets.remove_at(index)
   else:rocket.position=next

func transmission(from: Vector3, to: Vector3) -> float:
 var excluded: Array[RID]=[]
 var gain := 1.0
 for layer in range(4):
  var query := PhysicsRayQueryParameters3D.create(from,to,1,excluded);query.hit_from_inside=true
  var hit := get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty():return gain
  var material: String=hit.collider.get_meta("ballistic_material","")
  if material not in ["glass","fabric","wood"]:return 0
  gain*=0.75 if material=="glass" else 0.65 if material=="fabric" else 0.35
  excluded.append(hit.rid)
 return 0

func actor_exposure(where: Vector3, actor: Node3D) -> float:
 var head: Vector3=actor.camera.global_position if actor is Operator else actor.model.get_node("Head").to_global(CharacterArt.EYE)
 var chest: Vector3=actor.chest_area.global_position if actor is Operator else actor.model.to_global(Vector3(0,1.25,0))
 return (transmission(where,head)+transmission(where,chest)+transmission(where,chest+actor.global_basis.x*0.2))/3.0

# Lying flat or in a crouch hides most of the body from ground-burst fragments.
func posture_factor(actor: Node3D) -> float:
 if actor is Operator:return 0.45 if actor.prone else (0.75 if actor.crouched else 1.0)
 return lerpf(lerpf(1.0,0.5,clampf(float(actor.stance),0,1)),0.4,clampf(float(actor.tactical_prone),0,1))

func detonate(where: Vector3, kind: String="rpo") -> void:
 detonations+=1
 last_detonation=where
 var grad := kind=="grad"
 var mine := kind=="mine" or grad
 if grad:GradEffects.impact(game,where)
 else:
  var effect := BlastEffect.new();add_child(effect);effect.setup(game,where,0.8 if mine else 1.0)
 game.spatial_shot("mine_blast" if mine else "rpo_blast",where,(6 if grad else 3) if mine else 2)
 if is_instance_valid(game.player):
  var distance: float=game.player.camera.global_position.distance_to(where)
  game.hearing.exposure=minf(1.6,game.hearing.exposure+(3.0 if grad else 1.5)/pow(maxf(1,distance/9),1.2))
  if grad and distance>250:game.distant_blast(where,distance)
 if grad and game.has_method("grad_impact"):game.grad_impact(where)
 var reach := GRAD_RANGE if grad else (MINE_RANGE if mine else EFFECT_RANGE)
 # Fragments leave the body of the mine above the fuse, not the soil surface.
 var source := where+Vector3.UP*(0.35 if mine else 0.0)
 # Resolve exposure before cosmetic fractures, so one frame cannot make a
 # protective wall disappear retroactively for actors behind it.
 for actor in [game.player]+game.bots+game.allies:
  if not is_instance_valid(actor) or (actor is Hostile and actor.dead):continue
  if actor is Operator and actor.get_meta("battle_out",false):continue
  var distance: float=actor.global_position.distance_to(where)
  if distance>=reach:continue
  var intensity := pow(maxf(0,1-distance/reach),2)*actor_exposure(source,actor)
  if mine:intensity*=posture_factor(actor)
  if intensity<0.015:continue
  actor.receive_blast((GRAD_DAMAGE if grad else (MINE_DAMAGE if mine else 240.0))*intensity,clampf(intensity*1.35,0,1),where.direction_to(actor.global_position))
 # Bursts pin down everyone close by: heads down, into cover, no peeking.
 for bot in game.bots+game.allies:
  if bot.dead:continue
  bot.hear(where)
  var near: float=bot.global_position.distance_to(where)
  if near<reach*1.6:bot.shell_burst(where,clampf(1-near/(reach*1.6),0,1))
 # Reuse bounded local destruction; never traverse every scene object.
 var sphere := SphereShape3D.new();sphere.radius=6.0 if grad else 3.0
 var query := PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.transform.origin=where;query.collision_mask=1
 var seen := {}
 for contact in get_world_3d().direct_space_state.intersect_shape(query,24):
  var body: Object=contact.collider
  if not body is DestructibleSurface or seen.has(body.get_instance_id()):continue
  if body.get_meta("ballistic_material","") not in ["wood","glass","fabric"]:continue
  seen[body.get_instance_id()]=true
  var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(where,body.global_position,1))
  if hit.is_empty() or hit.collider!=body:continue
  body.strike(hit.position,where.direction_to(body.global_position),1200,true)
  if seen.size()>=(16 if grad else 8):break
