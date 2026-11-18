class_name LauncherRig
extends Node3D

const ACCESS_TIME := 3.8
var operator: Operator
var mode := ""
var timer := 0.0
var item_uid := -1
var ads := 0.0
var tube: Node3D
var left: Node3D
var right: Node3D
var arms: Array[Node3D]=[]
var notice := ""
var notice_left := 0.0

func setup(owner_operator: Operator) -> void:
 operator=owner_operator
 tube=ShmelArt.build();add_child(tube)
 left=Models.hand(self,"LauncherLeft",Vector3.ZERO)
 right=Models.hand(self,"LauncherRight",Vector3.ZERO)
 for i in range(2):arms.append(CharacterArt.shell(self,[Vector4(-0.13,0.095,0.085,0),Vector4(-0.06,0.09,0.08,0),Vector4(0.13,0.064,0.06,0)],"cloth",0.02))
 ScopeSight.set_first_person(self);Wardrobe.dress(self,operator.outfit_id,true);visible=false

func active() -> bool:return mode!=""
func equip(uid: int=-1) -> bool:
 if active() or operator.is_vaulting() or operator.field_rig.active() or operator.bandage_time>0 or operator.current().phase!="" or operator.current().pending_slot>=0 or operator.arm_injury>=0.5 or operator.injury_time>0 or not operator.concussion.can_fire():
  notice="РПО-А НЕДОСТУПНИЙ: РУКИ ЗАЙНЯТІ АБО БОЄЦЬ ПОРАНЕНИЙ";notice_left=3
  return false
 if uid<0:uid=operator.backpack.first("rpo_a")
 if operator.backpack.item(uid).get("kind","")!="rpo_a":notice="Додай РПО-А «Шмель» до спорядження в лодауті.";notice_left=3;return false
 item_uid=uid;mode="draw";timer=0;ads=0;notice="";notice_left=0
 operator.aim=false;operator.ads_weight=0;operator.burst=0;operator.firing_sequence_active=false
 operator.game.inventory.hide_for_action()
 return true

func toggle() -> void:
 if active():
  if mode in ["draw","ready"]:mode="stow";timer=0
 else:equip()

func cancel() -> void:
 mode="";timer=0;ads=0;visible=false

func handle_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  var scale := 0.55 if ads>0.5 else 1.0
  var yaw: float=-event.relative.x*operator.sensitivity*scale
  if not operator.prone or operator.prone_turn_clear(yaw):operator.rotate_y(yaw)
  operator.pitch=clampf(operator.pitch-event.relative.y*operator.sensitivity*scale,-1.30,1.30)
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_4,KEY_1,KEY_2]:toggle()
 if event.is_action_pressed("fire") and not event.is_echo():fire()

func tick(delta: float) -> void:
 notice_left=maxf(0,notice_left-delta)
 if notice_left==0:notice=""
 if not active():visible=false;return
 if not operator.game.running or operator.arm_injury>=0.5 or operator.injury_time>0 or not operator.concussion.can_fire():cancel();return
 timer+=delta
 if mode=="draw" and timer>=ACCESS_TIME:mode="ready";timer=0
 elif mode=="stow" and timer>=2.0:cancel();return
 elif mode=="spent" and timer>=1.1:cancel();return
 if mode!="spent" and operator.backpack.item(item_uid).is_empty():cancel();return
 ads=move_toward(ads,1.0 if mode=="ready" and Input.is_action_pressed("aim") and operator.concussion.can_aim() else 0.0,delta*4)
 animate()

func animate() -> void:
 visible=active()
 if not visible:return
 tube.position=Vector3(0.22,-0.18,-0.36).lerp(Vector3(-ShmelArt.SIGHT_X,-ShmelArt.SIGHT_Y,-0.40),smoothstep(0,1,ads))
 tube.rotation=Vector3.ZERO
 if mode=="ready" and ads<1:
  var direction := operator.camera.global_basis.inverse()*operator.point_fire_direction(tube.global_position)
  tube.quaternion=Quaternion.IDENTITY.slerp(Basis.looking_at(direction,Vector3.UP).get_rotation_quaternion(),1-smoothstep(0,1,ads))
 if mode=="draw":
  var p := clampf(timer/ACCESS_TIME,0,1)
  tube.position=Vector3(0.38,-0.44,0.23).lerp(tube.position,smoothstep(0.15,0.92,p))
  tube.rotation=Vector3(-0.9,0.25,0.7)*(1-smoothstep(0.15,0.92,p))
 elif mode=="stow" or mode=="spent":
  var p := clampf(timer/(2.0 if mode=="stow" else 1.1),0,1)
  tube.position+=Vector3(0.20,-0.65,0.25)*smoothstep(0,1,p)
  tube.rotation.z=p*0.65
 left.position=tube.transform*Vector3(-0.055,-0.10,-0.20)
 right.position=tube.transform*Vector3(-0.035,-0.10,0.16)
 left.rotation=tube.rotation+Vector3(0,0,-0.3);right.rotation=tube.rotation
 if mode=="draw" and timer<ACCESS_TIME*0.35:
  left.position=left.position.lerp(Vector3(-0.25,-0.55,-0.20),1-smoothstep(0,ACCESS_TIME*0.35,timer))
 for i in range(2):
  var hand := left if i==0 else right
  var wrist := hand.position+hand.basis*Vector3(0,-0.055,0.02)
  var elbow := Vector3(-0.30 if i==0 else 0.37,-0.48,0.12)
  arms[i].position=(wrist+elbow)*0.5;arms[i].quaternion=Quaternion(Vector3.UP,elbow.direction_to(wrist))
  arms[i].scale=Vector3(1,wrist.distance_to(elbow)/0.26,1)

func fire() -> bool:
 if mode!="ready" or not operator.game.running or operator.game.paused or operator.game.inventory_open or operator.game.commands_open or not operator.concussion.can_fire():return false
 if operator.backpack.item(item_uid).get("kind","")!="rpo_a":cancel();return false
 var muzzle: Vector3=tube.get_node("Muzzle").global_position
 var query := PhysicsRayQueryParameters3D.create(operator.camera.global_position,tube.global_position,1,[operator.get_rid()])
 query.hit_from_inside=true
 var space := operator.get_world_3d().direct_space_state
 var obstruction := space.intersect_ray(query)
 if obstruction.is_empty():
  query.from=tube.global_position;query.to=muzzle
  obstruction=space.intersect_ray(query)
 if not obstruction.is_empty():notice="СТВОЛ ГРАНАТОМЕТА ПЕРЕКРИТО";notice_left=1.5;return false
 var direction := (-tube.global_basis.z+tube.global_basis.y*0.032*smoothstep(0,1,ads)).normalized()
 direction=(direction+tube.global_basis.x*sin(operator.symptom_clock*1.3)*operator.concussion.severity*0.02).normalized()
 if not operator.game.debug_invulnerable:operator.backpack.remove(item_uid)
 mode="spent";timer=0;ads=0;notice=""
 operator.game.blasts.launch(muzzle,direction,operator)
 operator.shots+=1
 operator.game.sound("rpo_launch",-3)
 operator.game.hearing.shot(0,true)
 operator.game.alert_bots(operator.global_position)
 operator.recoil_velocity.y+=0.25
 # A stylised rear jet is also dangerous in the game. These distances and
 # damage values are deliberately uncalibrated, not real firing guidance.
 var rear: Vector3=tube.to_global(Vector3(0,0,0.40))
 var back := tube.global_basis.z
 for actor in [operator]+operator.game.bots+operator.game.allies:
  if actor==operator or not is_instance_valid(actor) or (actor is Hostile and actor.dead):continue
  var offset: Vector3=actor.global_position+Vector3.UP-rear
  if offset.length()<3 and offset.normalized().dot(back)>0.65 and operator.game.blasts.transmission(rear,rear+offset)>0.5:actor.receive_blast(70,0.3,-back)
 var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(rear,rear+back*1.1,1,[operator.get_rid()]))
 if not wall.is_empty():operator.receive_blast(35,0.3,-back)
 return true
