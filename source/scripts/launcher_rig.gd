class_name LauncherRig
extends Node3D

# The grenade launchers in the player's hands (key 4; 5 — the next one in the
# pack):
# - RPO-A «Шмель»: one-shot capsule off the pack's outer mount;
# - RPG-7V1 with the PGO-7V3: taken off the mount, loaded with a PG-7VL from
#   the pack (R, 6 s), aimed through the 2.7× sight whose range chevrons
#   (2…5 — 200…500 m) and stadia scale are laid off the PG-7VL's own flight;
#   it stays in the hands after the shot, empty;
# - RPG-22: taken off the mount, then brought into the firing position (R):
#   the covers off, the sleeve drawn out until it locks, the sights spring
#   up and the trigger is cocked. That cannot be undone: an armed tube goes
#   back on the mount drawn out and comes off it ready. Aimed through the
#   rear peep at the front frame's bars 5 / 15 / 25 (50 / 150 / 250 m),
#   thrown away after the shot.
const ACCESS_TIME := 3.8
const KINDS := ["rpo_a","rpg7","rpg22"]
# Taking it off the mount, putting it back, loading the RPG-7, arming the
# RPG-22 (with the draw about 8 s: "ready to fire in about 10 s"; the sleeve
# locks at ARM_LOCK of the way).
const DRAW := {"rpo_a":ACCESS_TIME,"rpg7":3.0,"rpg22":2.2}
const STOW := {"rpo_a":2.0,"rpg7":2.4,"rpg22":2.2}
const LOAD_TIME := 6.0
const ARM_TIME := 6.0
const ARM_LOCK := 0.6
# Rounds the launchers fire (BlastSystem.ROCKETS) and their reports.
const ROUND := {"rpo_a":"rpo","rpg7":"pg7vl","rpg22":"rpg22"}
const REPORT := {"rpo_a":"rpo_launch","rpg7":"rpg7_launch","rpg22":"rpg22_launch"}
const TITLE := {"rpo_a":"РПО-А «ШМЕЛЬ»","rpg7":"РПГ-7В1","rpg22":"РПГ-22"}
# The backblast: how far behind the breech it maims (stylised, not firing
# guidance: the real danger zones are 15–30 m).
const BLAST_REACH := {"rpo_a":3.0,"rpg7":8.0,"rpg22":5.0}
# The PGO-7: field of view and the range of the top chevron.
const PGO_FIELD := 13.0
const PGO_TOP := 200.0
# Front frame of the RPG-22: its bars, by range.
const FRAME_RANGES := [50,150,250]
# Where the tube rests on the shoulder, as seen from the eye.
const SHOULDER_SEAT := Vector3(0.17,-0.13,0.0)
var operator: Operator
var kind := "rpo_a"
var mode := ""
var timer := 0.0
var item_uid := -1
var ads := 0.0
var queued := ""
var tube: Node3D
var models := {}
var left: Node3D
var right: Node3D
var arms: Array[Node3D]=[]
var notice := ""
var notice_left := 0.0
static var elevations := {}

func setup(owner_operator: Operator) -> void:
 operator=owner_operator
 left=Models.hand(self,"LauncherLeft",Vector3.ZERO)
 right=Models.hand(self,"LauncherRight",Vector3.ZERO)
 for i in range(2):arms.append(CharacterArt.shell(self,[Vector4(-0.13,0.095,0.085,0),Vector4(-0.06,0.09,0.08,0),Vector4(0.13,0.064,0.06,0)],"cloth",0.02))
 use_model("rpo_a")
 ScopeSight.set_first_person(self);Wardrobe.dress(self,operator.outfit_id,true);visible=false

# Elevation of the bore over the line to a point at the eye's height, for a
# round at a range: the flight (BlastSystem) and the sight standing `above`
# the bore.
static func elevation(round: String, distance: float, above: float) -> float:
 var key:="%s/%d/%.3f" % [round,int(distance),above]
 if not elevations.has(key):elevations[key]=BlastSystem.rocket_elevation(round,distance)+above/maxf(1.0,distance)
 return elevations[key]

# The PGO-7 stands 52 mm above the bore; its top chevron is the optical axis.
static func pgo_tilt() -> float:return elevation("pg7vl",PGO_TOP,Rpg7Art.EYEPIECE.y)

# Angle below the optical axis of the PGO-7's chevron for a range.
static func pgo_chevron(distance: float) -> float:return elevation("pg7vl",distance,Rpg7Art.EYEPIECE.y)-pgo_tilt()

static func frame_marks() -> Array:
 var marks:=[]
 for distance in FRAME_RANGES:marks.append([distance,elevation("rpg22",distance,Rpg22Art.APERTURE.y)])
 return marks

# The model in the hands: built once a kind, the RPG-22 in both states.
func use_model(which: String, extended: bool=true) -> void:
 var key:=which+("" if extended else "/folded")
 if not models.has(key):
  var built: Node3D
  match which:
   "rpg7":built=Rpg7Art.build(false)
   "rpg22":built=Rpg22Art.build(extended,frame_marks())
   _:built=ShmelArt.build()
  add_child(built)
  ScopeSight.set_first_person(built)
  models[key]=built
 for other in models:models[other].visible=other==key
 tube=models[key]

func active() -> bool:return mode!=""

func carried(which: String) -> bool:return operator.backpack.first(which)>=0

# The first launcher of the pack in the order a man reaches for them, or the
# next one after the current.
func next_kind(after: String="") -> String:
 var order:=["rpg7","rpo_a","rpg22"]
 var start:=order.find(after)+1 if after!="" else 0
 for i in range(order.size()):
  var which: String=order[(start+i)%order.size()]
  if carried(which) and (which!=after or i==order.size()-1):return which
 return ""

func busy_reason() -> String:
 if operator.is_vaulting() or operator.field_rig.active() or operator.bandage_time>0 or operator.current().phase!="" or operator.current().pending_slot>=0 or operator.arm_injury>=0.5 or operator.injury_time>0 or not operator.concussion.can_fire():
  return "ГРАНАТОМЕТ НЕДОСТУПНИЙ: РУКИ ЗАЙНЯТІ АБО БОЄЦЬ ПОРАНЕНИЙ"
 return ""

func equip(uid: int=-1, which: String="") -> bool:
 if active():return false
 var reason:=busy_reason()
 if reason!="":notice=reason;notice_left=3;return false
 if uid>=0:which=str(operator.backpack.item(uid).get("kind",""))
 elif which=="":which=next_kind()
 if which not in KINDS:
  notice="Додай гранатомет (РПО-А, РПГ-7 або РПГ-22) до спорядження в лодауті.";notice_left=3
  return false
 if uid<0:uid=operator.backpack.first(which)
 if uid<0:notice="%s НЕМАЄ В НАПЛІЧНИКУ" % TITLE[which];notice_left=3;return false
 kind=which;item_uid=uid;mode="draw";timer=0;ads=0;notice="";notice_left=0;queued=""
 use_model(kind,kind!="rpg22" or armed())
 show_round()
 operator.aim=false;operator.ads_weight=0;operator.burst=0;operator.firing_sequence_active=false
 operator.game.inventory.hide_for_action()
 return true

func toggle() -> void:
 if active():
  if mode in ["draw","ready","load","arm"]:stow()
 else:equip()

# Key 5: put this one back and take the next, or take the next one out.
func cycle() -> void:
 var next:=next_kind(kind if active() else "")
 if active():
  if next!="" and next!=kind and mode in ["draw","ready"]:queued=next;stow()
 elif next!="":equip(-1,next)

# Back onto the mount (a load broken off leaves the round in the pack: it
# leaves the pack only once seated; an RPG-22 goes back as it is, folded or
# drawn out).
func stow() -> void:
 mode="stow";timer=0;ads=0

func cancel() -> void:
 mode="";timer=0;ads=0;visible=false;queued=""

# Ready to fire: the RPG-7 with a round in it, the RPG-22 armed.
func loaded() -> bool:
 match kind:
  "rpg7":return bool(operator.backpack.item(item_uid).get("loaded",false))
  "rpg22":return armed()
 return true

# The RPG-22 in its firing position: kept on the pack's item, since a drawn
# out tube stays so.
func armed() -> bool:
 return kind=="rpg22" and bool(operator.backpack.item(item_uid).get("extended",false))

func show_round() -> void:
 if kind!="rpg7":return
 var round:=tube.get_node_or_null("Grenade") as Node3D
 if round!=null:round.visible=loaded() or (mode=="load" and timer>LOAD_TIME*0.55)

# R with the RPG-7 in the hands: a PG-7VL from the pack into the muzzle.
func load_round() -> bool:
 if kind!="rpg7" or mode!="ready":return false
 if loaded():notice="РПГ-7 ВЖЕ ЗАРЯДЖЕНО";notice_left=1.5;return false
 if operator.backpack.first("pg7vl")<0:notice="НЕМАЄ ПОСТРІЛІВ ПГ-7ВЛ У НАПЛІЧНИКУ";notice_left=2;return false
 mode="load";timer=0;ads=0;notice=""
 return true

# R with the RPG-22 in the hands: into the firing position, once and for good.
func arm() -> bool:
 if kind!="rpg22" or mode!="ready":return false
 if armed():notice="РПГ-22 ВЖЕ В БОЙОВОМУ ПОЛОЖЕННІ";notice_left=1.5;return false
 mode="arm";timer=0;ads=0;notice=""
 return true

func handle_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  var scale := (0.22 if kind=="rpg7" else 0.55) if ads>0.5 else 1.0
  var yaw: float=-event.relative.x*operator.sensitivity*scale
  if not operator.prone or operator.prone_turn_clear(yaw):operator.rotate_y(yaw)
  operator.pitch=clampf(operator.pitch-event.relative.y*operator.sensitivity*scale,-1.30,1.30)
 if event is InputEventKey and event.pressed and not event.echo:
  match event.physical_keycode:
   KEY_4,KEY_1,KEY_2:toggle()
   KEY_5:cycle()
 if event.is_action_pressed("reload") and not event.is_echo():
  if kind=="rpg22":arm()
  else:load_round()
 if event.is_action_pressed("fire") and not event.is_echo():fire()

func tick(delta: float) -> void:
 notice_left=maxf(0,notice_left-delta)
 if notice_left==0:notice=""
 if not active():visible=false;return
 if not operator.game.running or operator.arm_injury>=0.5 or operator.injury_time>0 or not operator.concussion.can_fire():cancel();return
 timer+=delta
 if mode=="draw" and timer>=float(DRAW[kind]):mode="ready";timer=0
 elif mode=="load" and timer>=LOAD_TIME:
  var round:=operator.backpack.first("pg7vl")
  if round>=0:
   if not operator.game.debug_invulnerable:operator.backpack.remove(round)
   operator.backpack.item(item_uid)["loaded"]=true
   operator.game.sound("mag_in",-8)
  mode="ready";timer=0
 elif mode=="arm" and timer>=ARM_TIME:mode="ready";timer=0
 elif mode=="stow" and timer>=float(STOW[kind]):
  var next:=queued
  cancel()
  if next!="":equip(-1,next)
  return
 elif mode=="spent" and timer>=1.1:cancel();return
 if mode!="spent" and operator.backpack.item(item_uid).is_empty():cancel();return
 # Arming the RPG-22: the sleeve locks out part way and the sights spring up;
 # from then on it stays so, whatever is done with it.
 if kind=="rpg22":
  if mode=="arm" and timer>=ARM_TIME*ARM_LOCK and not armed():
   operator.backpack.item(item_uid)["extended"]=true
   operator.game.sound("click",-8)
  var extended:=armed() or mode=="spent"
  if (tube==models.get("rpg22",null))!=extended:use_model("rpg22",extended)
 show_round()
 # Folded, the RPG-22 has its sights down: nothing to aim with.
 var sighted:=mode=="ready" and (kind!="rpg22" or armed())
 ads=move_toward(ads,1.0 if sighted and Input.is_action_pressed("aim") and operator.concussion.can_aim() else 0.0,delta*(3.0 if kind=="rpg7" else 4.0))
 animate()

# The eye at the sight: where the tube stands then, and how it is tilted.
func sight_transform() -> Transform3D:
 match kind:
  "rpg7":
   var basis:=Basis(Vector3.RIGHT,pgo_tilt())
   return Transform3D(basis,Vector3(0,0,-0.03)-basis*Rpg7Art.EYEPIECE)
  "rpg22":return Transform3D(Basis.IDENTITY,Vector3(0,0,-0.07)-Rpg22Art.APERTURE)
 return Transform3D(Basis.IDENTITY,Vector3(-ShmelArt.SIGHT_X,-ShmelArt.SIGHT_Y,-0.40))

func shoulder_point() -> Vector3:
 match kind:
  "rpg7":return Rpg7Art.SHOULDER
  "rpg22":return Rpg22Art.SHOULDER
 return Vector3(0,-0.05,0.36)

# Through the PGO-7 the scope fills the view (the HUD draws it): the launcher
# itself is out of sight.
func through_scope() -> bool:return kind=="rpg7" and ads>0.85

func animate() -> void:
 visible=active()
 if not visible:return
 var sight:=sight_transform()
 var shoulder:=SHOULDER_SEAT-shoulder_point()
 if kind=="rpo_a":shoulder=Vector3(0.22,-0.18,-0.36)
 var blend:=smoothstep(0,1,ads)
 tube.position=shoulder.lerp(sight.origin,blend)
 tube.quaternion=Quaternion.IDENTITY.slerp(sight.basis.get_rotation_quaternion(),blend)
 if mode in ["ready","load"] and ads<1:
  var direction := operator.camera.global_basis.inverse()*operator.point_fire_direction(tube.global_position)
  tube.quaternion=Basis.looking_at(direction,Vector3.UP).get_rotation_quaternion().slerp(sight.basis.get_rotation_quaternion(),blend)
 var reach_time:=float(DRAW[kind])
 if mode=="draw":
  var p := clampf(timer/reach_time,0,1)
  tube.position=Vector3(0.38,-0.44,0.23).lerp(tube.position,smoothstep(0.15,0.92,p))
  tube.rotation=Vector3(-0.9,0.25,0.7)*(1-smoothstep(0.15,0.92,p))
 elif mode=="stow" or mode=="spent":
  var p := clampf(timer/(float(STOW[kind]) if mode=="stow" else 1.1),0,1)
  tube.position+=Vector3(0.20,-0.65,0.25)*smoothstep(0,1,p)
  tube.rotation.z=p*0.65
 elif mode=="load":
  # Muzzle up and forward off the shoulder, the round pushed in from the front.
  var p := clampf(timer/LOAD_TIME,0,1)
  var lift:=smoothstep(0,0.15,p)*(1-smoothstep(0.85,1,p))
  tube.position+=Vector3(-0.06,-0.10,-0.05)*lift
  tube.rotation=Vector3(0.55*lift,0,0.25*lift)
 elif mode=="arm":
  # Off the shoulder and across the chest: the covers pulled off, then the
  # sleeve drawn back out of the tube until it locks.
  var p := clampf(timer/ARM_TIME,0,1)
  var down:=smoothstep(0,0.12,p)*(1-smoothstep(0.88,1,p))
  tube.position+=Vector3(-0.14,-0.16,-0.06)*down
  tube.rotation=Vector3(0.10*down,0.55*down,0.12*down)
 tube.visible=not through_scope()
 var grip: Vector3
 var support: Vector3
 match kind:
  "rpg7":grip=Rpg7Art.GRIP;support=Rpg7Art.SUPPORT
  "rpg22":grip=Rpg22Art.GRIP;support=Rpg22Art.SUPPORT
  _:grip=Vector3(-0.035,-0.10,0.16);support=Vector3(-0.055,-0.10,-0.20)
 left.position=tube.transform*support
 right.position=tube.transform*grip
 left.rotation=tube.rotation+Vector3(0,0,-0.3);right.rotation=tube.rotation
 if mode=="draw" and timer<reach_time*0.35:
  left.position=left.position.lerp(Vector3(-0.25,-0.55,-0.20),1-smoothstep(0,reach_time*0.35,timer))
 elif mode=="load":
  # The left hand fetches the round from the pack and seats it in the muzzle.
  var p := clampf(timer/LOAD_TIME,0,1)
  var muzzle:=tube.transform*Rpg7Art.MUZZLE
  var pack:=Vector3(-0.30,-0.60,0.10)
  left.position=pack.lerp(muzzle,smoothstep(0.2,0.5,p)).lerp(tube.transform*support,smoothstep(0.75,0.95,p))
 elif mode=="arm":
  # The left hand at the front cover, then on the sleeve, pulling it back.
  var p := clampf(timer/ARM_TIME,0,1)
  var front:=tube.transform*Vector3(0,0,-0.36)
  var rear:=tube.transform*Vector3(0,0,0.30)
  var at:=front.lerp(rear,smoothstep(0.15,0.30,p)*(1-smoothstep(0.30,0.40,p)))
  left.position=at.lerp(tube.transform*Vector3(0,-0.03,0.36),smoothstep(0.40,ARM_LOCK,p)).lerp(tube.transform*support,smoothstep(0.75,0.95,p))
 left.visible=not through_scope();right.visible=left.visible
 for i in range(2):
  var hand := left if i==0 else right
  var wrist := hand.position+hand.basis*Vector3(0,-0.055,0.02)
  var elbow := Vector3(-0.30 if i==0 else 0.37,-0.48,0.12)
  arms[i].position=(wrist+elbow)*0.5;arms[i].quaternion=Quaternion(Vector3.UP,elbow.direction_to(wrist))
  arms[i].scale=Vector3(1,wrist.distance_to(elbow)/0.26,1)
  arms[i].visible=left.visible

func muzzle_point() -> Vector3:
 var marker:=tube.get_node_or_null("Muzzle") as Node3D
 return marker.global_position if marker!=null else tube.to_global(Vector3(0,0,-0.5))

func breech_point() -> Vector3:
 var marker:=tube.get_node_or_null("Breech") as Node3D
 return marker.global_position if marker!=null else tube.to_global(Vector3(0,0,0.40))

func fire() -> bool:
 if mode!="ready" or not operator.game.running or operator.game.paused or operator.game.inventory_open or operator.game.commands_open or not operator.concussion.can_fire():return false
 if operator.backpack.item(item_uid).get("kind","")!=kind:cancel();return false
 if not loaded():
  operator.game.sound("click",-12)
  notice="РПГ-7 НЕ ЗАРЯДЖЕНО · R — ЗАРЯДИТИ ПГ-7ВЛ" if kind=="rpg7" else "РПГ-22 У ПОХІДНОМУ ПОЛОЖЕННІ · R — ПРИВЕСТИ В БОЙОВЕ"
  notice_left=2
  return false
 var muzzle: Vector3=muzzle_point()
 var query := PhysicsRayQueryParameters3D.create(operator.camera.global_position,tube.global_position,1,[operator.get_rid()])
 query.hit_from_inside=true
 var space := operator.get_world_3d().direct_space_state
 var obstruction := space.intersect_ray(query)
 if obstruction.is_empty():
  query.from=tube.global_position;query.to=muzzle
  obstruction=space.intersect_ray(query)
 if not obstruction.is_empty():notice="СТВОЛ ГРАНАТОМЕТА ПЕРЕКРИТО";notice_left=1.5;return false
 var direction := -tube.global_basis.z
 if kind=="rpo_a":direction=(direction+tube.global_basis.y*0.032*smoothstep(0,1,ads)).normalized()
 # The RPG from the shoulder without the sight: the grenade goes roughly
 # where the tube points (the RPO-A's hip fire is as before).
 if ads<0.5 and kind!="rpo_a":direction=(direction+tube.global_basis.x*randf_range(-0.012,0.012)+tube.global_basis.y*randf_range(-0.012,0.012)).normalized()
 direction=(direction+tube.global_basis.x*sin(operator.symptom_clock*1.3)*operator.concussion.severity*0.02).normalized()
 var rear: Vector3=breech_point()
 var back := tube.global_basis.z
 operator.game.blasts.launch(muzzle,direction,operator,ROUND[kind])
 operator.shots+=1
 var report: String=REPORT[kind]
 operator.game.sound(report if operator.game.sounds.has(report) else "rpo_launch",-3)
 operator.game.hearing.shot(0,true)
 operator.game.alert_bots(operator.global_position)
 operator.recoil_velocity.y+=0.25 if kind=="rpo_a" else 0.12
 if kind=="rpg7":
  # The launcher stays in the hands, empty; the next round from the pack (R).
  operator.backpack.item(item_uid)["loaded"]=false
  show_round()
  timer=0;notice=""
 else:
  if not operator.game.debug_invulnerable:operator.backpack.remove(item_uid)
  mode="spent";timer=0;ads=0;notice=""
 backblast(rear,back,space)
 return true

# A stylised rear jet is also dangerous in the game. These distances and
# damage values are deliberately uncalibrated, not real firing guidance.
func backblast(rear: Vector3, back: Vector3, space: PhysicsDirectSpaceState3D) -> void:
 var reach: float=BLAST_REACH[kind]
 for actor in [operator]+operator.game.bots+operator.game.allies:
  if actor==operator or not is_instance_valid(actor) or (actor is Hostile and actor.dead):continue
  var offset: Vector3=actor.global_position+Vector3.UP-rear
  if offset.length()<reach and offset.normalized().dot(back)>0.65 and operator.game.blasts.transmission(rear,rear+offset)>0.5:
   actor.receive_blast(70.0*(1.0-0.6*offset.length()/reach),0.3,-back)
 # Dust thrown up behind.
 var effects:=GradEffects.shared(operator.game)
 if kind!="rpo_a":
  for k in range(3):effects.puff(rear+back*(1.0+k*1.4),0.8+k*0.35,0.7)
 var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(rear,rear+back*1.1,1,[operator.get_rid()]))
 if not wall.is_empty():operator.receive_blast(35,0.3,-back)
