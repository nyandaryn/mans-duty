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
# 3UOF8 30 mm HE-I of the 2A42: 49 g of A-IX-2, impact fuse. Game units.
const CANNON_RANGE := 6.5
const CANNON_DAMAGE := 170.0
# PG-7VL / RPG-22 shaped charge on a soft target: the thin steel body and
# the liner break up into a few metres of fragments; against men it is no
# fragmentation grenade. Game units.
const HEAT_RANGE := 7.0
const HEAT_DAMAGE := 150.0
# What each kind of burst does: reach and damage against men, whether its
# fragments come from a body above the fuse (lift) and follow the
# fragmentation rules (prone men are hit less), the size of the flash, the
# sound, how hard it is on the hearing, the cosmetic destruction around it
# and its kind for Demolition.HITS. "fpv_frag": the fragmentation charge of
# an FPV drone (about a kilogram of explosive in a cased charge); "cookoff":
# the ammunition of a vehicle going up.
const WARHEADS := {
 "rpo":{"reach":EFFECT_RANGE,"damage":240.0,"frag":false,"lift":0.0,"effect":1.0,"sound":"rpo_blast","db":2.0,"hearing":1.5,"sphere":3.0,"surfaces":8,"demolish":"rpo"},
 "mine":{"reach":MINE_RANGE,"damage":MINE_DAMAGE,"frag":true,"lift":0.35,"effect":0.8,"sound":"mine_blast","db":3.0,"hearing":1.5,"sphere":3.0,"surfaces":8,"demolish":"mine"},
 "grad":{"reach":GRAD_RANGE,"damage":GRAD_DAMAGE,"frag":true,"lift":0.35,"effect":-1.0,"sound":"mine_blast","db":6.0,"hearing":3.0,"sphere":6.0,"surfaces":16,"demolish":"grad"},
 "cannon":{"reach":CANNON_RANGE,"damage":CANNON_DAMAGE,"frag":true,"lift":0.35,"effect":0.35,"sound":"mine_blast","db":-4.0,"hearing":0.5,"sphere":1.5,"surfaces":3,"demolish":"cannon"},
 "heat":{"reach":HEAT_RANGE,"damage":HEAT_DAMAGE,"frag":true,"lift":0.0,"effect":0.6,"sound":"heat_blast","db":2.0,"hearing":1.2,"sphere":1.5,"surfaces":4,"demolish":"heat"},
 "fpv_frag":{"reach":15.0,"damage":230.0,"frag":true,"lift":0.15,"effect":0.7,"sound":"mine_blast","db":2.0,"hearing":1.4,"sphere":2.5,"surfaces":6,"demolish":"mine"},
 # OG-7V: 40 mm steel body, about 210 g of A-IX-1, ≥850 fragments of 0.9 g
 # (the maker's sheet); its "effective defeat radius" is given as 14 m.
 "og7":{"reach":14.0,"damage":200.0,"frag":true,"lift":0.0,"effect":0.5,"sound":"mine_blast","db":0.0,"hearing":1.1,"sphere":1.5,"surfaces":4,"demolish":"cannon"},
 "cookoff":{"reach":34.0,"damage":460.0,"frag":true,"lift":1.0,"effect":-1.0,"sound":"mine_blast","db":8.0,"hearing":3.0,"sphere":6.0,"surfaces":16,"demolish":"cookoff"},
}
# Grenades fired from the shoulder. "rpo": the RPO-A capsule (its own
# simple drag, as before). PG-7VL: thrown out of the tube at 112 m/s by the
# launch charge, the sustainer lit by a delay about 11 m out burns 0.4 s and
# drives it to about 270 m/s; drag k·v² with k fitted to the flight times of
# the RPG-7 firing manual (0.5/0.9/1.3/1.8/2.3 s to 100…500 m for PG-7V,
# the heavier VL a little slower); self-destruction after 4–6 s (4.5).
# RPG-22: the motor burns out in the tube, 133 m/s, then only drag and
# gravity (direct-fire range 160 m at 2 m target height checks out).
# The fuze arms 2.5 m out of the muzzle.
const ROCKETS := {
 "rpo":{"speed":0.0,"decay":0.018,"warhead":"rpo","round":"","life":9.0,"arm":0.0},
 "pg7vl":{"speed":112.0,"ignite":11.0,"burn":0.4,"thrust":440.0,"drag":0.00125,"warhead":"heat","round":"pg7vl","life":4.5,"arm":2.5},
 "rpg22":{"speed":133.0,"ignite":INF,"burn":0.0,"thrust":0.0,"drag":0.0008,"warhead":"heat","round":"rpg22","life":5.0,"arm":2.5},
 # OG-7V from the RPG-7: 152 m/s from the PG-7P charge and no sustainer;
 # k fitted to the maker's 170 m direct-fire range (2 m target, as for the
 # RPG-22 above). Its self-destruct time is not in the sources at hand:
 # 9 s is about 740 m of flight, near the 700 m maximum range given for it.
 "og7v":{"speed":152.0,"ignite":INF,"burn":0.0,"thrust":0.0,"drag":0.0015,"warhead":"og7","round":"og7v","life":9.0,"arm":2.5},
}
var game: Node3D
var rockets: Array[Dictionary]=[]
var mines: Array[Dictionary]=[]
var grads: Array[Dictionary]=[]
var detonations := 0
var last_detonation := Vector3.INF

func _ready() -> void:BlastEffect.prepare_textures()

func clear() -> void:
 for rocket in rockets:free_grenade(rocket)
 rockets.clear()
 mines.clear()
 for grad in grads:
  if is_instance_valid(grad.node):grad.node.queue_free()
 grads.clear()
 last_detonation=Vector3.INF
 for child in get_children():child.queue_free()

func launch(origin: Vector3, direction: Vector3, shooter: Node3D, kind: String="rpo") -> void:
 var excluded: Array[RID]=[]
 if shooter is CollisionObject3D:excluded.append(shooter.get_rid())
 for area in shooter.find_children("Hit_*","Area3D",true,false):excluded.append(area.get_rid())
 if shooter is Hostile:
  for area in shooter.hitboxes:excluded.append(area.get_rid())
 var spec: Dictionary=ROCKETS[kind]
 var speed: float=ShmelArt.INITIAL_SPEED if kind=="rpo" else float(spec.speed)
 var rocket:={"kind":kind,"position":origin,"origin":origin,"velocity":direction.normalized()*speed,"age":0.0,"travel":0.0,"lit":-1.0,"excluded":excluded,"shooter":weakref(shooter),"puff":0.0}
 if kind!="rpo":
  rocket.node=grenade_node(kind)
  add_child(rocket.node)
  rocket.node.global_position=origin
 rockets.append(rocket)

# One step of a grenade's flight (shared with the sight tables: see
# rocket_drop()).
static func rocket_step(rocket: Dictionary, step: float) -> void:
 var spec: Dictionary=ROCKETS[rocket.get("kind","rpo")]
 var v: Vector3=rocket.velocity
 if rocket.get("kind","rpo")=="rpo":
  v+=Vector3.DOWN*9.81*step
  v*=exp(-0.018*step)
 else:
  var speed:=v.length()
  var accel:=Vector3.DOWN*9.81-v*float(spec.drag)*speed
  if float(rocket.lit)<0.0 and float(rocket.travel)>=float(spec.ignite):rocket.lit=float(rocket.age)
  if float(rocket.lit)>=0.0 and float(rocket.age)-float(rocket.lit)<float(spec.burn):accel+=v.normalized()*float(spec.thrust)
  v+=accel*step
 rocket.position=Vector3(rocket.position)+v*step
 rocket.travel=float(rocket.travel)+v.length()*step
 rocket.velocity=v
 rocket.age=float(rocket.age)+step

# Drop of a grenade below the line of departure at a range (for the sight
# scales: each mark is the angle the drop subtends).
static func rocket_drop(kind: String, distance: float, angle: float=0.0) -> float:
 var spec: Dictionary=ROCKETS[kind]
 var speed: float=ShmelArt.INITIAL_SPEED if kind=="rpo" else float(spec.speed)
 var rocket:={"kind":kind,"position":Vector3.ZERO,"velocity":Vector3(0,sin(angle),-cos(angle))*speed,"age":0.0,"travel":0.0,"lit":-1.0}
 var last:=Vector3.ZERO
 while -Vector3(rocket.position).z<distance and float(rocket.age)<12.0:
  last=rocket.position
  rocket_step(rocket,1.0/240.0)
 var p: Vector3=rocket.position
 var f:=clampf((distance+last.z)/maxf(last.z-p.z,0.0001),0.0,1.0)
 return last.y+(p.y-last.y)*f

# Elevation that puts a grenade on the line of sight at a range.
static func rocket_elevation(kind: String, distance: float) -> float:
 var low:=-0.05;var high:=0.35
 for i in range(28):
  var mid:=(low+high)*0.5
  if rocket_drop(kind,distance,mid)<0.0:low=mid
  else:high=mid
 return (low+high)*0.5

# Time of flight to a range (sight, lead on a moving target).
static func rocket_time(kind: String, distance: float) -> float:
 var spec: Dictionary=ROCKETS[kind]
 var speed: float=ShmelArt.INITIAL_SPEED if kind=="rpo" else float(spec.speed)
 var rocket:={"kind":kind,"position":Vector3.ZERO,"velocity":Vector3(0,0,-speed),"age":0.0,"travel":0.0,"lit":-1.0}
 while -Vector3(rocket.position).z<distance and float(rocket.age)<12.0:rocket_step(rocket,1.0/240.0)
 return float(rocket.age)

# A grenade in flight: its body, and the flame of the sustainer while it
# burns.
# The grenade in flight: the model of its launcher's art (fins open), built
# once and copied; a plain body when that art is missing.
static var grenade_models := {}
# The templates are out of the tree: freed with the game (see BotKit).
static func clear_grenade_models() -> void:
 for kind in grenade_models:
  if is_instance_valid(grenade_models[kind]):(grenade_models[kind] as Node).free()
 grenade_models.clear()
func grenade_node(kind: String) -> Node3D:
 if not grenade_models.has(kind) or not is_instance_valid(grenade_models[kind]):grenade_models[kind]=build_grenade(kind)
 return (grenade_models[kind] as Node3D).duplicate()

func build_grenade(kind: String) -> Node3D:
 if kind=="og7v":
  var og:=Node3D.new();og.add_child(LauncherRig.og7v_model(false))
  return og
 var art_path:="res://scripts/rpg7_art.gd" if kind=="pg7vl" else "res://scripts/rpg22_art.gd"
 var art: Node3D=null
 if kind in ["pg7vl","rpg22"] and ResourceLoader.exists(art_path):
  var script: Script=load(art_path)
  var built=script.grenade(false,true) if kind=="pg7vl" else script.grenade()
  if built is Node3D:art=built
 var root:=Node3D.new()
 if art!=null:
  root.add_child(art)
  if kind=="pg7vl":add_flame(root)
  return root
 var body:=MeshInstance3D.new()
 var mesh:=CylinderMesh.new()
 var radius:=0.0465 if kind=="pg7vl" else 0.036
 mesh.top_radius=radius*0.55;mesh.bottom_radius=radius;mesh.height=0.95 if kind=="pg7vl" else 0.6;mesh.radial_segments=8;mesh.rings=1
 var paint:=StandardMaterial3D.new();paint.albedo_color=Color("4b5138") if kind=="pg7vl" else Color("3f4535");mesh.material=paint
 body.mesh=mesh;body.rotation.x=-PI/2;root.add_child(body)
 if kind=="pg7vl":add_flame(root)
 return root

# The sustainer's flame behind the nozzles.
func add_flame(root: Node3D) -> void:
 var flame:=MeshInstance3D.new();flame.name="Flame"
 var quad:=QuadMesh.new();quad.size=Vector2(0.6,0.6)
 var glow:=StandardMaterial3D.new();glow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 glow.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 glow.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;glow.albedo_texture=BlastEffect.fire_texture;glow.albedo_color=Color(1,0.9,0.7,1)
 quad.material=glow;flame.mesh=quad;flame.position=Vector3(0,0,0.55);flame.visible=false;root.add_child(flame)

# A warhead delivered by something other than a fired grenade (an FPV drone
# striking a vehicle or a man, or blowing up in the air): "heat" is the
# PG-7VL warhead the drone carries, "frag" a cased fragmentation charge.
func warhead(kind: String, point: Vector3, direction: Vector3, collider: Object, _source: Node3D=null) -> void:
 var body:=strike_target(collider)
 if kind=="heat":
  # FPV with a PG-7VL head: the same jet as from the launcher.
  if body!=null:body.vehicle_hit(point,direction,"pg7vl")
  else:behind_wall(point,direction,"pg7vl",collider)
  detonate(point-direction*0.05,"heat")
 else:
  # A charge going off on the armour: its blast and the fragments of its
  # case punch through thin steel at contact.
  if body!=null:body.vehicle_hit(point,direction,"frag",14.0)
  detonate(point-direction*0.05,"fpv_frag")

# A shaped charge on a wall: the jet goes through brick or concrete up to
# its reach (PG-7VL: 1.7 m of brickwork, 1.5 m of reinforced concrete; the
# RPG-22 in proportion to its armour figure) and comes out the far side as
# the jet and a cone of spall from the wall: the man in its line is hit as by
# the jet itself, those in the cone by the chunks, a few metres in. A wall
# too thick for it stops it all; on the near side only the blast works.
const WALL_REACH := 1.7
func behind_wall(entry: Vector3, line: Vector3, round: String, collider: Object) -> int:
 if collider==null or line.length()<0.5:return 0
 var pen: float=VehicleArmor.ROUNDS.get(round,{}).get("pen",0.0)
 if pen<=0.0:return 0
 var reach:=WALL_REACH*pen/500.0
 var space:=get_world_3d().direct_space_state
 # The far face of the wall: from beyond it back toward the entry.
 var probe:=PhysicsRayQueryParameters3D.create(entry+line*(reach+0.05),entry+line*0.01,1)
 var back:=space.intersect_ray(probe)
 if back.is_empty():return 0
 var exit: Vector3=back.position
 var thickness:=entry.distance_to(exit)
 # Something else stood further in the line: the jet ended inside the wall.
 if back.collider!=collider and thickness>0.6:return 0
 if thickness>reach:return 0
 var left:=1.0-thickness/reach
 var range_out:=lerpf(1.5,6.0,left)
 var struck:=0
 for actor in [game.player]+game.bots+game.allies:
  if not is_instance_valid(actor) or (actor is Hostile and (actor.dead or actor.vehicle!=null)):continue
  if actor is Operator and (actor.get_meta("battle_out",false) or game.player_sheltered()):continue
  var body: Vector3=actor.global_position+Vector3.UP*0.9
  var rel:=body-exit
  var along:=rel.dot(line)
  if along<0.1 or along>range_out:continue
  var off:=(rel-line*along).length()
  # The jet itself: a hand's breadth; the spall cone opens to ~25°.
  var amount:=0.0
  if off<0.35:amount=lerpf(220.0,120.0,along/range_out)
  elif off<along*0.45+0.4:amount=lerpf(90.0,25.0,along/range_out)*(0.5+0.5*left)
  else:continue
  # Nothing between the hole and him.
  var clear:=space.intersect_ray(PhysicsRayQueryParameters3D.create(exit+line*0.05,body,1))
  if not clear.is_empty() and Vector3(clear.position).distance_to(body)>0.6:continue
  if actor.has_method("blast_protection"):amount*=actor.blast_protection(exit)
  actor.receive_blast(amount,clampf(amount/160.0,0.2,1.0),line)
  struck+=1
 # The spall comes out as a dust jet on the far side.
 var effects:=GradEffects.shared(game)
 effects.puff(exit+line*0.4,0.8,0.7)
 effects.puff(exit+line*1.3,1.2,0.75)
 return struck

# The vehicle a grenade or a drone struck (a hull or one of its parts).
static func strike_target(collider: Object) -> Node3D:
 var node:=collider as Node
 for i in range(4):
  if node==null:return null
  if node.has_method("vehicle_hit"):return node as Node3D
  node=node.get_parent()
 return null

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
 if shot.get("quiet",false):shot.node.visible=false
 shot.origin=shot.position
 grads.append(shot)

# 9M22U rockets: the same equations as the firing tables, a ray per step.
# A rocket of the skipped start (`quiet`, GradBattery.rush) flies unseen and
# bursts unheard: with the game's sounds off for the burst, or they would all
# come at once, and the distant ones seconds later, in the village.
func fly_grads(delta: float) -> void:
 var effects:=GradEffects.shared(game)
 for index in range(grads.size()-1,-1,-1):
  var shot: Dictionary=grads[index]
  var unseen: bool=shot.get("quiet",false)
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
  if not unseen:effects.trail(from,to,float(shot.age))
  var node: Node3D=shot.node
  if not hit.is_empty():
   grads.remove_at(index)
   if is_instance_valid(node):node.queue_free()
   var loud: float=game.volume
   if unseen:game.volume=0.0
   detonate(Vector3(hit.position)+Vector3(hit.normal)*0.1,"grad")
   game.volume=loud
   continue
  if float(shot.age)>200.0 or to.y<-200.0:
   grads.remove_at(index)
   if is_instance_valid(node):node.queue_free()
   continue
  if unseen:
   if is_instance_valid(node):node.visible=false
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
   rocket_step(rocket,step)
   var next: Vector3=rocket.position
   var query := PhysicsRayQueryParameters3D.create(from,next,1|16,rocket.excluded)
   query.collide_with_areas=true;query.hit_from_inside=true
   var hit := get_world_3d().direct_space_state.intersect_ray(query)
   var spec: Dictionary=ROCKETS[rocket.kind]
   if not hit.is_empty():
    rockets.remove_at(index)
    rocket.position=hit.position
    grenade_hit(rocket,hit)
   elif float(rocket.age)>float(spec.life):
    rockets.remove_at(index)
    # The self-destruct (the RPO-A capsule only falls).
    if rocket.kind!="rpo":detonate(next,String(spec.warhead))
    free_grenade(rocket)
   else:show_grenade(rocket,from,step)

func grenade_hit(rocket: Dictionary, hit: Dictionary) -> void:
 var spec: Dictionary=ROCKETS[rocket.kind]
 free_grenade(rocket)
 var point: Vector3=hit.position+hit.normal*0.035
 # Inside the arming distance the fuze does not work: the grenade breaks
 # up on what it hit.
 if float(rocket.travel)<float(spec.arm):
  game.impact(hit.position,hit.normal,hit.collider as Node3D)
  return
 if spec.warhead=="heat":
  var body:=strike_target(hit.collider)
  var line:=Vector3(rocket.velocity).normalized()
  if body!=null:body.vehicle_hit(hit.position,line,String(spec.round))
  else:behind_wall(hit.position,line,String(spec.round),hit.collider)
  detonate(point,"heat")
 else:detonate(point,String(spec.warhead))

func show_grenade(rocket: Dictionary, from: Vector3, step: float) -> void:
 var node: Node3D=rocket.get("node")
 if not is_instance_valid(node):return
 var to: Vector3=rocket.position
 var velocity: Vector3=rocket.velocity
 node.global_position=to
 if velocity.length()>1.0:node.look_at(to+velocity,Vector3.UP if absf(velocity.normalized().y)<0.99 else Vector3.RIGHT)
 var spec: Dictionary=ROCKETS[rocket.kind]
 var burning:=float(rocket.lit)>=0.0 and float(rocket.age)-float(rocket.lit)<float(spec.burn)
 var flame:=node.get_node_or_null("Flame")
 if flame!=null:flame.visible=burning
 # The sustainer leaves a short grey trail.
 rocket.puff=float(rocket.puff)-step
 if burning and float(rocket.puff)<=0.0:
  rocket.puff=0.018
  GradEffects.shared(game).puff(from,0.35,0.82)

func free_grenade(rocket: Dictionary) -> void:
 var node: Node3D=rocket.get("node")
 if is_instance_valid(node):node.queue_free()

func transmission(from: Vector3, to: Vector3) -> float:
 var excluded: Array[RID]=[]
 var gain := 1.0
 for layer in range(4):
  var query := PhysicsRayQueryParameters3D.create(from,to,1,excluded);query.hit_from_inside=true
  var hit := get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty():return gain
  var material: String=hit.collider.get_meta("ballistic_material","")
  # Fragments go through a fence of sheet steel as through boards.
  if hit.collider.has_meta("sheet_scale"):material="wood"
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
 var spec: Dictionary=WARHEADS.get(kind,WARHEADS.rpo)
 var grad := kind=="grad" or kind=="cookoff"
 var frag: bool=spec.frag
 if float(spec.effect)<0.0:GradEffects.impact(game,where)
 else:
  var effect := BlastEffect.new();add_child(effect);effect.setup(game,where,float(spec.effect))
 var sound: String=spec.sound if game.sounds.has(spec.sound) else "mine_blast"
 game.spatial_shot(sound,where,float(spec.db))
 if is_instance_valid(game.player):
  var distance: float=game.player.camera.global_position.distance_to(where)
  game.hearing.exposure=minf(1.6,game.hearing.exposure+float(spec.hearing)/pow(maxf(1,distance/9),1.2))
  if grad and distance>250:game.distant_blast(where,distance)
 if kind=="grad" and game.has_method("grad_impact"):game.grad_impact(where)
 var reach: float=spec.reach
 var damage: float=spec.damage
 # Fragments leave the body of the mine above the fuse, not the soil surface.
 var source := where+Vector3.UP*float(spec.lift)
 # Resolve exposure before cosmetic fractures, so one frame cannot make a
 # protective wall disappear retroactively for actors behind it.
 for actor in [game.player]+game.bots+game.allies:
  if not is_instance_valid(actor) or (actor is Hostile and actor.dead):continue
  if actor is Operator and actor.get_meta("battle_out",false):continue
  # Men inside the armour are out of reach of fragments and blast.
  if (actor is Hostile and actor.vehicle!=null) or (actor is Operator and game.player_sheltered()):continue
  var distance: float=actor.global_position.distance_to(where)
  if distance>=reach:continue
  var intensity := pow(maxf(0,1-distance/reach),2)*actor_exposure(source,actor)
  if frag:intensity*=posture_factor(actor)
  # Body armour takes part of the fragments (VestKind).
  if actor.has_method("blast_protection"):intensity*=actor.blast_protection(where)
  if intensity<0.015:continue
  actor.receive_blast(damage*intensity,clampf(intensity*1.35,0,1),where.direction_to(actor.global_position))
 # Vehicles: the fragments on their armour (VehicleDamage).
 for vehicle in get_tree().get_nodes_in_group("vehicles"):
  if vehicle.has_method("blast_hit") and vehicle.global_position.distance_to(where)<reach+8.0:vehicle.blast_hit(where,kind)
 # A drone near the burst, in the air or on the ground: fragments and the
 # blast wave bring it down.
 for drone in get_tree().get_nodes_in_group("drones"):
  if drone.health<=0:continue
  var distance: float=drone.global_position.distance_to(where)
  if distance>=reach:continue
  var intensity:=pow(maxf(0,1-distance/reach),2)*transmission(source,drone.global_position)
  if intensity<0.015:continue
  drone.receive_hit(damage*intensity,"blast",where.direction_to(drone.global_position),drone.global_position)
 # Bursts pin down everyone close by: heads down, into cover, no peeking.
 for bot in game.bots+game.allies:
  if bot.dead or bot.vehicle!=null:continue
  bot.hear(where)
  var near: float=bot.global_position.distance_to(where)
  if near<reach*1.6:bot.shell_burst(where,clampf(1-near/(reach*1.6),0,1))
 # Houses brought down, fences put over (after the exposure above: a wall
 # that falls now still sheltered those behind it).
 Demolition.blast(game,where,String(spec.demolish))
 # Reuse bounded local destruction; never traverse every scene object.
 var sphere := SphereShape3D.new();sphere.radius=float(spec.sphere)
 var query := PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.transform.origin=where;query.collision_mask=1
 if is_instance_valid(game.district):query.exclude=Demolition.ground(game.district)
 var seen := {}
 for contact in get_world_3d().direct_space_state.intersect_shape(query,24):
  var body: Object=contact.collider
  if not body is DestructibleSurface or seen.has(body.get_instance_id()):continue
  if body.get_meta("ballistic_material","") not in ["wood","glass","fabric"]:continue
  seen[body.get_instance_id()]=true
  var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(where,body.global_position,1))
  if hit.is_empty() or hit.collider!=body:continue
  body.strike(hit.position,where.direction_to(body.global_position),1200,true)
  if seen.size()>=int(spec.surfaces):break
