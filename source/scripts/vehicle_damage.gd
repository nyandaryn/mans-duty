class_name VehicleDamage
extends RefCounted

# State of a vehicle under fire, shared by the BMP-2 and the BM-21 (and any
# vehicle added later: it needs an armour layout, occupants() and the hooks
# below). Works out a hit with VehicleArmor, then:
# - men on the jet's line die, those in its spall cone are wounded, and
#   everyone inside a vehicle a HEAT jet went through takes the overpressure;
# - an engine or transmission hit, or a torn track, stops the vehicle;
# - fuel catches fire often, ammunition sometimes goes up at once
#   (a catastrophic loss: everybody inside dies) and otherwise starts a fire
#   that sets it off a minute later; a burning vehicle is abandoned;
# - the gun and its sight can be put out of action.
# Hooks on the vehicle (duck-typed): occupants() -> [[actor, local point]],
# turret_yaw() -> float, on_immobile(), on_fire(), on_destroyed(catastrophic),
# and for the BM-21 cook_off_rockets().
var vehicle: Node3D
var armor: VehicleArmor
var game: Node3D
var immobile := false
var burning := false
var destroyed := false
var catastrophic := false
var weapon_out := false
var fire_left := 0.0
var smoke_clock := 0.0
var flames: MeshInstance3D
var hits := 0
var engine_hits := 0
var penetrations := 0
var last := {}
var history: Array[String]=[]
static var flame_material: StandardMaterial3D

func setup(owner: Node3D, layout: VehicleArmor) -> void:
 vehicle=owner;armor=layout;game=owner.game

func out_of_action() -> bool:return destroyed or burning or immobile

func note(text: String) -> void:
 history.append(text)
 if history.size()>12:history.remove_at(0)

func turret_yaw() -> float:
 return float(vehicle.turret_yaw()) if vehicle.has_method("turret_yaw") else 0.0

# A round strikes the hull at a point (world) going along a direction.
func strike(point: Vector3, direction: Vector3, round: String, pen_mm: float=-1.0) -> Dictionary:
 if destroyed:return {}
 if pen_mm<0.0:pen_mm=VehicleArmor.penetration(round)
 # Fragments rattling on the armour are not counted as hits.
 if round!="frag":hits+=1
 var inverse:=vehicle.global_transform.affine_inverse()
 var local_point:=inverse*point
 var local_dir:=(inverse.basis*direction).normalized()
 var yaw:=turret_yaw()
 var result:=armor.resolve(local_point,local_dir,round,pen_mm,yaw)
 last=result
 var data: Dictionary=VehicleArmor.ROUNDS.get(round,VehicleArmor.ROUNDS.frag)
 var heat: bool=data.heat
 # A shaped charge on the road wheels or the track breaks it whether or not
 # the jet reaches the hull behind.
 if result.zone=="tracks" and (heat or round=="frag") and not immobile:
  immobilize("перебита гусениця")
 if not result.penetrated:
  if round=="frag":return result
  if result.get("glanced",false):note("рикошет · %s" % result.plate.get("title",""))
  else:note("не пробито · %s %d мм" % [result.plate.get("title",""),roundi(float(result.los))])
  return result
 penetrations+=1
 note("пробито · %s %d мм" % [result.plate.get("title",""),roundi(float(result.los))])
 var reach:=clampf(float(result.residual)*float(data.jet),0.35,4.5)
 wound_occupants(local_point,local_dir,reach,heat,round)
 for hit in result.hits:
  var line: bool=hit.line
  match String(hit.part.kind):
   "engine":
    # One bullet through a truck's engine bay does not stop the engine.
    if round=="bullet":
     engine_hits+=1
     if engine_hits<3 and randf()>0.2:continue
    immobilize("пошкоджено двигун")
    if randf()<(0.30 if heat else 0.12)*(1.0 if line else 0.5):ignite(randf_range(40,90))
   "drive":immobilize("пошкоджено трансмісію")
   "fuel":
    var fire_odds:=0.65 if heat else (0.06 if round=="bullet" else 0.30)
    if randf()<fire_odds*(1.0 if line else 0.35):ignite(randf_range(35,80))
   "ammo":
    if line and randf()<(0.45 if heat else 0.25):explode()
    elif randf()<(0.55 if line else 0.2):ignite(randf_range(20,60))
   "weapon":
    if line or randf()<0.5:
     if not weapon_out:note("гармату виведено з ладу")
     weapon_out=true
   "missiles":
    # A missile's warhead or its motor: it burns, now and then it goes off.
    if line and randf()<(0.35 if heat else 0.15):explode()
    elif randf()<(0.6 if line else 0.25):ignite(randf_range(15,45))
   "rockets":
    if vehicle.has_method("has_rockets") and not vehicle.has_rockets():continue
    # The 9M22U motors and warheads in the tubes: a jet or a contact
    # charge sets them off nearly always, a bullet rarely.
    var chance: float={"pg7vl":0.85,"rpg22":0.8,"ap30":0.6,"frag":0.5,"bullet":0.04}.get(round,0.3)
    if randf()<chance*(1.0 if line else 0.4):
     note("займання ракет у пакеті")
     if vehicle.has_method("cook_off_rockets"):vehicle.cook_off_rockets()
     ignite(randf_range(6,14))
 return result

# The men inside: on the line of the jet (or slug) dead, near it hit by
# spall; behind a HEAT penetration everyone takes the pressure and the
# fumes. Distances in the vehicle frame.
func wound_occupants(from: Vector3, direction: Vector3, reach: float, heat: bool, round: String) -> void:
 for entry in occupants():
  var actor: Node3D=entry[0]
  var at: Vector3=entry[1]
  var along:=clampf((at-from).dot(direction),0.0,reach)
  var off:=at.distance_to(from+direction*along)
  var depth:=(at-from).dot(direction)
  if depth>-0.2 and depth<reach+0.3 and off<0.32:
   hurt(actor,600.0,1.0,direction)
  elif depth>-0.2 and depth<reach+0.8 and off<0.35+maxf(depth,0.0)*0.45:
   hurt(actor,randf_range(45,120) if heat else randf_range(25,80),0.5,direction)
  elif heat:
   hurt(actor,randf_range(6,18),0.35,direction)

func hurt(actor: Node3D, amount: float, severity: float, direction: Vector3) -> void:
 if not is_instance_valid(actor):return
 if actor is Hostile:
  if actor.dead:return
  if amount>=actor.health:forget(actor)
  actor.receive_blast(amount,severity,(vehicle.global_basis*direction).normalized())
 elif actor is Operator:
  if game.debug_invulnerable:return
  actor.receive_blast(amount,severity,(vehicle.global_basis*direction).normalized())

func occupants() -> Array:
 return vehicle.occupants() if vehicle.has_method("occupants") else []

# A man who dies inside stays inside: out of the seat lists, no ragdoll.
func forget(actor: Hostile) -> void:
 if vehicle is BmpVehicle:
  vehicle.aboard.erase(actor);vehicle.crew.erase(actor)
  vehicle.troops.forget(actor)
  if actor.get_meta("bmp_role","")=="gunner":vehicle.gunner.manned=false
  if actor.get_meta("bmp_role","")=="driver":vehicle.driver_ai=null;vehicle.throttle=0.0
 actor.set_meta("died_inside",true)

func immobilize(reason: String) -> void:
 if immobile:return
 immobile=true
 note(reason)
 if vehicle.has_method("on_immobile"):vehicle.on_immobile(reason)

func ignite(seconds: float) -> void:
 if destroyed:return
 if not burning:
  burning=true;fire_left=seconds
  note("пожежа")
  if vehicle.has_method("on_fire"):vehicle.on_fire()
  show_flames(true)
 else:fire_left=minf(fire_left,seconds)

# The ammunition (or the fuel and the rockets) goes up: nobody inside
# lives through it.
func explode() -> void:
 if destroyed:return
 catastrophic=true
 note("детонація боєкомплекту")
 for entry in occupants():hurt(entry[0],2000.0,1.0,Vector3.UP)
 finish(true)

func finish(blast: bool) -> void:
 destroyed=true;immobile=true
 var top:=vehicle.to_global(Vector3(0,1.6,0))
 if blast:
  var effect:=BlastEffect.new();game.world_root.add_child(effect);effect.setup(game,top,2.2)
  game.spatial_shot("mine_blast",top,6)
 else:
  # Burnt out: what was still inside dies in the fire.
  for entry in occupants():hurt(entry[0],2000.0,1.0,Vector3.UP)
 show_flames(true)
 burning=true;fire_left=INF
 if vehicle.has_method("on_destroyed"):vehicle.on_destroyed(blast)

func tick(delta: float) -> void:
 if not burning:return
 smoke_clock-=delta
 if smoke_clock<=0.0:
  smoke_clock=0.35 if not destroyed else 0.7
  GradEffects.shared(game).puff(vehicle.to_global(Vector3(randf_range(-0.7,0.7),2.0,randf_range(-1.2,1.6))),2.0,0.18,Vector3(0.5,1.6,0.2))
 if is_instance_valid(flames):
  var flicker:=0.85+0.3*sin(Time.get_ticks_msec()*0.017)*sin(Time.get_ticks_msec()*0.011)
  flames.scale=Vector3.ONE*flicker*(1.4 if destroyed else 1.0)
 if destroyed:return
 fire_left-=delta
 if fire_left<=0.0:
  # The ammunition cooks off in the fire.
  note("боєкомплект вибухнув у вогні")
  catastrophic=true
  finish(true)

func show_flames(on: bool) -> void:
 if not on:
  if is_instance_valid(flames):flames.queue_free()
  return
 if is_instance_valid(flames):return
 BlastEffect.prepare_textures()
 if flame_material==null:
  flame_material=StandardMaterial3D.new()
  flame_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  flame_material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
  flame_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  flame_material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;flame_material.billboard_keep_scale=true
  flame_material.albedo_texture=BlastEffect.fire_texture
  flame_material.albedo_color=Color(1,0.85,0.6,0.95)
 var quad:=QuadMesh.new();quad.size=Vector2(2.2,2.8)
 flames=MeshInstance3D.new();flames.name="Flames";flames.mesh=quad;flames.material_override=flame_material
 flames.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 flames.position=Vector3(0.3,2.0,0.6)
 vehicle.add_child(flames)
 var glow:=OmniLight3D.new();glow.omni_range=9.0;glow.light_energy=1.6;glow.light_color=Color(1,0.55,0.22);glow.shadow_enabled=false
 flames.add_child(glow)

# Fragments of a burst nearby: a few rays of fragments at the vehicle's
# box, each a strike with what the fragment still pierces at that range.
func blast(where: Vector3, kind: String) -> void:
 if destroyed:return
 var spec: Array={"grad":[14.0,26.0,10],"mine":[6.0,9.0,6],"cannon":[2.5,4.0,3],"heat":[3.0,4.0,3],"rpo":[4.0,5.0,4],"fpv_frag":[5.0,8.0,5],"cookoff":[20.0,30.0,12]}.get(kind,[0.0,0.0,0])
 var reach: float=spec[0]
 if reach<=0.0:return
 var center:=vehicle.to_global(Vector3(0,1.1,0))
 var distance:=where.distance_to(center)
 if distance>reach+3.0:return
 var count:=clampi(int(float(spec[2])*clampf(3.0/maxf(distance,1.0),0.1,1.0)+0.5),1,int(spec[2]))
 for i in range(count):
  var aim:=vehicle.to_global(Vector3(randf_range(-1.4,1.4),randf_range(0.4,1.7),randf_range(-3.0,3.0)))
  var dir:=where.direction_to(aim)
  var ray:=PhysicsRayQueryParameters3D.create(where,where+dir*(reach+4.0),1)
  var hit:=vehicle.get_world_3d().direct_space_state.intersect_ray(ray)
  if hit.is_empty() or hit.collider!=vehicle:continue
  var pen: float=float(spec[1])*clampf(1.0-where.distance_to(hit.position)/(reach+3.0),0.0,1.0)
  if pen<1.0:continue
  strike(hit.position,dir,"frag",pen)
