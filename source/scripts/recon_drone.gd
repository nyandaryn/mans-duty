class_name ReconDrone
extends CharacterBody3D

# A full charge hovers for 40 minutes, as a Mavic 3 class recon quadcopter
# (46 minutes rated); fast flight drains it up to a third quicker.
const FLIGHT_SECONDS := 2400.0
const MAX_LINK_DISTANCE := 450.0
var operator: Operator
var model: Node3D
var camera: Camera3D
var rotors: Array[Node3D]=[]
var battery := 1.0
var health := 1.0
var armed := false
var landed := true
var piloting := false
var yaw := 0.0
var camera_pitch := -0.12
var signal_strength := 1.0
var link_timer := 0.0
var lost_link_time := 0.0
var floor_height := 0.0
var notice := ""
var motor_sound: AudioStreamPlayer3D
# A drone flown through a relay (the observation post of the BM-21 class)
# measures its link from that point; the operator's own drone from him.
var relay := Vector3.INF
var link_range := MAX_LINK_DISTANCE
var limit := 195.0
var ceiling := 100.0
var zoomable := false
var zoom := 1.0
var base_fov := 95.0
var return_camera: Camera3D
var on_lost := Callable()
# Whose it is: the attackers fly the drones; the defenders shoot at them.
var friendly := true
# Shot down: it drops out of the air tumbling; the goggles show the fall
# a moment before the picture is gone.
var downed := 0.0
var spin_axis := Vector3.RIGHT
# Rounds going past: the pilot is told he is being shot at.
var fired_on := 0.0
const FALL_SHOWN := 1.2

func setup(owner_operator: Operator, entry: Dictionary) -> void:
 operator=owner_operator
 top_level=true
 add_to_group("drones")
 collision_layer=32
 collision_mask=1|2|4|8
 floor_max_angle=deg_to_rad(56)
 floor_snap_length=0.15
 battery=clampf(float(entry.get("battery",1.0)),0,1)
 health=clampf(float(entry.get("condition",1.0)),0,1)
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new();box.size=Vector3(0.40,0.13,0.34)
 shape.shape=box;add_child(shape)
 model=DroneArt.build();model.position.y=-0.065;add_child(model)
 for child in model.get_children():
  if child is Node3D and child.has_meta("rotor"):rotors.append(child)
 camera=Camera3D.new();camera.position=Vector3(0,0.012,-0.13)
 camera.fov=95;camera.near=0.03;camera.far=1500;camera.cull_mask=1|OperatorBody.WORLD_BODY_LAYER;add_child(camera)
 DamageModel.hitbox(self,self,"drone",Vector3.ZERO,Vector3(0.40,0.15,0.34))
 motor_sound=AudioStreamPlayer3D.new();motor_sound.stream=motor_audio()
 motor_sound.unit_size=6;motor_sound.max_distance=100;motor_sound.volume_db=-9
 add_child(motor_sound)

static func motor_audio() -> AudioStreamWAV:
 var data := PackedByteArray();data.resize(22050*2)
 for i in range(22050):
  var t := float(i)/22050
  var wave := (sin(TAU*220*t)+sin(TAU*440*t)*0.45+sin(TAU*660*t)*0.2)*(0.8+0.2*sin(TAU*37*t))
  data.encode_s16(i*2,int(wave*2600))
 var sample := AudioStreamWAV.new();sample.format=AudioStreamWAV.FORMAT_16_BITS
 sample.mix_rate=22050;sample.data=data;sample.loop_mode=AudioStreamWAV.LOOP_FORWARD;sample.loop_end=22050
 return sample

func begin_control() -> bool:
 if health<=0 or battery<=0:return false
 piloting=true;camera.make_current();notice="SPACE — ЗЛІТ / CTRL — ПОСАДКА"
 return true

func end_control() -> void:
 piloting=false
 if is_instance_valid(return_camera):return_camera.make_current()
 elif is_instance_valid(operator) and operator.is_inside_tree():operator.camera.make_current()

func handle_input(event: InputEvent) -> void:
 if zoomable and event is InputEventMouseButton and event.pressed:
  # Hybrid zoom of a Mavic 3T class camera: 1× to 28×.
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=minf(28.0,zoom*1.4)
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=maxf(1.0,zoom/1.4)
  camera.fov=rad_to_deg(2.0*atan(tan(deg_to_rad(base_fov)*0.5)/zoom))
 if event is InputEventMouseMotion:
  yaw-=event.relative.x*operator.sensitivity*0.7/zoom
  camera_pitch=clampf(camera_pitch-event.relative.y*operator.sensitivity*0.7/zoom,-1.5,0.4)
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F:
  if landed:armed=false;notice="МОТОРИ ВИМКНЕНО · J — ЗНЯТИ ОКУЛЯРИ"
  else:notice="СПЕРШУ ПОСАДИ ДРОН · CTRL — ЗНИЖЕННЯ"

# In the air under power: what the enemy hears and shoots at.
func flying() -> bool:return armed and health>0 and not landed

func ground_clearance() -> float:
 var ray := PhysicsRayQueryParameters3D.create(global_position,global_position+Vector3.DOWN*200,1,[get_rid()])
 var hit := get_world_3d().direct_space_state.intersect_ray(ray)
 return maxf(0,global_position.y-Vector3(hit.position).y-0.065) if not hit.is_empty() else 200.0

func update_link(delta: float) -> void:
 link_timer-=delta
 if link_timer>0:return
 link_timer=0.2
 var station:=operator.camera.global_position if relay==Vector3.INF else relay
 var distance := global_position.distance_to(station)
 signal_strength=clampf(1-distance/link_range,0,1)
 var ray := PhysicsRayQueryParameters3D.create(station,global_position,1,[get_rid(),operator.get_rid()])
 if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():signal_strength*=0.3
 floor_height=ground_clearance()

func _physics_process(delta: float) -> void:
 if not is_instance_valid(operator):return
 if not operator.game.running:
  motor_sound.stop();return
 if operator.game.paused:
  motor_sound.stream_paused=true
  return
 motor_sound.stream_paused=false
 update_link(delta)
 lost_link_time=lost_link_time+delta if signal_strength<0.04 else 0.0
 var fail_safe := battery<=0.04 or lost_link_time>1.5 or health<=0
 if battery<=0 or health<=0:armed=false
 var desired := Vector3.ZERO
 if piloting and not fail_safe:
  var input := Input.get_vector("left","right","forward","back")
  var speed := 12.0 if Input.is_action_pressed("sprint") else 6.0
  desired=Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.y)*speed
  desired.y=(float(Input.is_action_pressed("jump"))-float(Input.is_action_pressed("crouch")))*3.0
  if Input.is_action_pressed("jump") and battery>0 and health>0:armed=true
 if armed:
  battery=maxf(0,battery-delta/FLIGHT_SECONDS*(1.0+velocity.length()*0.025))
  if fail_safe:
   desired=Vector3(0,-1.0,0);notice="АВТОПОСАДКА · НИЗЬКА БАТАРЕЯ / ВТРАТА ЗВ’ЯЗКУ"
  if global_position.y-operator.game.district.ground_height(global_position)>ceiling:desired.y=minf(desired.y,-0.5)
  if absf(global_position.x)>limit:desired.x=-signf(global_position.x)*2
  if absf(global_position.z)>limit:desired.z=-signf(global_position.z)*2
  velocity=velocity.move_toward(desired,delta*4.0)
 else:
  velocity.x=move_toward(velocity.x,0,delta*8)
  velocity.z=move_toward(velocity.z,0,delta*8)
  velocity.y-=9.80665*delta
 var before := velocity
 move_and_slide()
 # Descending into a slope produces a tangential slide velocity. Waiting for
 # that slide to stop before disarming would keep the motors pushing forever.
 if is_on_floor() and before.y<=0 and (fail_safe or (piloting and Input.is_action_pressed("crouch"))):
  armed=false;velocity=Vector3.ZERO
 landed=is_on_floor() and absf(velocity.y)<0.25 and Vector2(velocity.x,velocity.z).length()<0.5
 if landed and (fail_safe or (piloting and Input.is_action_pressed("crouch"))):armed=false
 for i in range(get_slide_collision_count()):
  var collision := get_slide_collision(i)
  var impact := maxf(0,-before.dot(collision.get_normal()))
  if impact>5.5:health=maxf(0,health-(impact-5.5)*0.12)
 if health<=0 and downed<=0.0:armed=false;notice="ДРОН ПОШКОДЖЕНО"
 fired_on=maxf(0.0,fired_on-delta)
 var local_velocity := Basis(Vector3.UP,yaw).inverse()*velocity
 # Rest on the supporting slope; level the airframe as the motors lift it.
 var target_basis := Basis(Vector3.UP,yaw)
 if landed and not armed:
  var normal := get_floor_normal()
  var back := (target_basis.z-normal*target_basis.z.dot(normal)).normalized()
  target_basis=Basis(normal.cross(back).normalized(),normal,back)
 if downed>0.0 and not landed:
  # Falling with a motor or a prop shot away: it turns over.
  rotate(spin_axis,delta*7.0)
 else:quaternion=quaternion.slerp(target_basis.get_rotation_quaternion(),1-exp(-delta*8))
 model.rotation.x=lerpf(model.rotation.x,-local_velocity.z*0.035,1-exp(-delta*6))
 model.rotation.z=lerpf(model.rotation.z,-local_velocity.x*0.035,1-exp(-delta*6))
 camera.rotation=Vector3(camera_pitch+model.rotation.x*0.3,0,model.rotation.z*0.25)
 for i in range(rotors.size()):rotors[i].rotation.y+=delta*(130 if armed else 0)*(1 if i%2==0 else -1)
 if armed and not motor_sound.playing:motor_sound.play()
 elif not armed and motor_sound.playing:motor_sound.stop()
 motor_sound.pitch_scale=1.0+velocity.length()*0.025
 motor_sound.volume_db=-9+linear_to_db(maxf(operator.game.volume,0.0001))
 if downed>0.0:downed+=delta
 if piloting and ((health<=0 and (downed<=0.0 or downed>FALL_SHOWN or landed)) or (battery<=0 and landed)):
  if on_lost.is_valid():on_lost.call()
  else:operator.field_rig.cancel()

# A rifle round through it, or fragments of a burst nearby: a quadcopter of
# this class does not fly on with a motor, a prop arm or the battery hit.
func receive_hit(amount: float, _zone: String, _incoming: Vector3, _point: Vector3) -> void:
 if health<=0:return
 var airborne:=armed and not landed
 health=maxf(0,health-amount/25.0)
 if health>0:return
 armed=false
 if airborne:
  downed=0.001
  spin_axis=Vector3(randf_range(-1,1),randf_range(-0.3,0.3),randf_range(-1,1)).normalized()
  notice="ДРОН ЗБИТО"
  if is_instance_valid(operator) and operator.field_rig!=null:operator.field_rig.drone_notice="Дрон збито."
  if is_instance_valid(operator) and is_instance_valid(operator.game):
   operator.game.spatial_shot("bolt",global_position,-4)
   GradEffects.shared(operator.game).puff(global_position,0.6,0.35,Vector3(0,-0.4,0))

# A round past it, close: the pilot sees the warning on the goggles.
func near_miss() -> void:
 if health>0:fired_on=2.0

# The red line across the picture: shot down, or rounds going past.
func alarm() -> String:
 if downed>0.0:return "ДРОН ЗБИТО"
 return "ПО ДРОНУ ВЕДУТЬ ВОГОНЬ" if fired_on>0.0 else ""

func can_recover() -> bool:
 if not landed or armed or global_position.distance_to(operator.camera.global_position)>2.3:return false
 var ray := PhysicsRayQueryParameters3D.create(operator.camera.global_position,global_position,1,[operator.get_rid(),get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
