class_name ReconDrone
extends CharacterBody3D

# A full charge hovers for 40 minutes, as a Mavic 3 class recon quadcopter
# (46 minutes rated); flat out in sport it drains a quarter quicker.
const FLIGHT_SECONDS := 2400.0
# The radio link, DJI O3+ of the Mavic 3: 8 km in the open under CE rules
# (15 km FCC); houses or a ridge between the pilot and the drone cut it to
# about a third (https://www.dji.com/mavic-3/specs: 1.5–3 km in a town).
const MAX_LINK_DISTANCE := 8000.0
# Flight of a Mavic 3 class quadcopter, by DJI's specs
# (https://www.dji.com/mavic-3/specs): 895 g at take-off; 15 m/s level in
# N mode and 21 m/s in S (sport) at most 30° / 35° of pitch; climbing at
# 6 m/s (N) / 8 m/s (S), descending at 6 m/s; turning at up to 200°/s;
# holding its place in wind up to 12 m/s.
# The physics is the FPV's (fpv_drone.gd): the airframe leans, the thrust
# along its axis, gravity and the drag of the air move it, and the lean takes
# time. What differs is the flight controller, GPS and vision position hold:
# the sticks ask for a speed, not a lean. Let go, it brakes by leaning back,
# then holds the point and the height where it stopped against the wind and
# its gusts. Shift is sport mode.
const GRAVITY := 9.80665
const NORMAL_SPEED := 15.0
const SPORT_SPEED := 21.0
const NORMAL_TILT := 0.5236
const SPORT_TILT := 0.6109
const NORMAL_CLIMB := 6.0
const SPORT_CLIMB := 8.0
const DESCENT := 6.0
const YAW_RATE := 3.49
# Thrust to weight of about 2 on a full pack.
const MAX_LIFT := 2.0*GRAVITY
# Drag per unit of airspeed: linear (the rotors' H-force) and quadratic (the
# body). 15 m/s takes 21° of pitch, 21 m/s 33°.
const ROTOR_DRAG := 0.12
const BODY_DRAG := 0.00873
# Flight controller: how fast the airframe takes the lean it is given, the
# speed loop, the wind trim (integral), the position and height hold.
const ATTITUDE_RATE := 7.0
const SPEED_GAIN := 2.6
const TRIM_GAIN := 0.6
const HOLD_GAIN := 1.0
const CLIMB_GAIN := 4.5
# Obstacle sensing, the Mavic 3's vision sensors by DJI's specs: forward
# 0.5–20 m (effective up to 15 m/s), backward 0.5–16 m (12 m/s), sideways
# 0.5–25 m (15 m/s), upward 0.2–10 m (6 m/s), downward 0.3–18 m (6 m/s).
# They are off in sport mode. In N mode, set to brake, it slows along the way
# the sticks send it and hovers short of a wall, a tree or a house; backward
# it goes no faster than its rear sensors can stop it.
const FRONT_SENSING := 20.0
const BACK_SENSING := 16.0
const SIDE_SENSING := 25.0
const UP_SENSING := 10.0
const BACK_SENSING_SPEED := 12.0
const OBSTACLE_BRAKING := 4.0
const OBSTACLE_GAP := 2.5
const OBSTACLE_GAP_ABOVE := 1.0
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
# Half the side of the square the geofence keeps it in; 0 — the map's edge.
var limit := 0.0
var ceiling := 100.0
# The airframe's lean under its heading, and the thrust along its axis (m/s²).
var airframe := Basis()
var lift := 0.0
var sport := false
# Where the position hold keeps it (INF: braking, or the sticks are moving it).
var hold_point := Vector3.INF
var hold_height := INF
# The steady wind over the field (INF: the battlefield's); gusts come on top.
var wind := Vector3.INF
var wind_trim := Vector3.ZERO
var climb_trim := 0.0
var air_clock := 0.0
# The yaw stick: the heading the airframe turns to.
var yaw_target := 0.0
# Where the last physics step left it: moved or turned from outside, it holds
# the new place and heading.
var flown_to := Vector3.INF
var flown_yaw := INF
var touching := false
# What the sensors see this step: the distance to it (INF: nothing in the
# way), and whether the drone is braking for it.
var obstacle_distance := INF
var obstacle_braking := false
var sensor_query: PhysicsShapeQueryParameters3D
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
# Hit and still flying: what was hit (for the goggles), how long the warning
# stays up, and the harm to its flight — 0 sound, 1 barely flying (a chipped
# blade or a bent arm shakes it, pulls it aside, costs lift and charge).
var hit_part := ""
var hit_notice := 0.0
var damage := 0.0
var damage_pull := Vector3.ZERO
# The men firing at it just now (instance id → physics frame): only a few at
# a time get a clear shot at a speck in the sky.
var aimed_by: Dictionary={}
const PART_NAMES := {"camera":"ПІДВІС КАМЕРИ","arm":"ПРОМЕНЬ РАМИ","prop":"ПРОПЕЛЕР","warhead":"БОЙОВА ЧАСТИНА"}
# A blade sweeps a tenth of its disc: a round through the disc mostly passes
# between the blades.
const BLADE_SHARE := 0.12
const MOST_SHOOTERS := 3

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
  yaw_target-=event.relative.x*operator.sensitivity*0.7/zoom
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
 # Put somewhere from outside (deployed, the observation post's drone sent
 # up, a test): it holds the new place, already hovering if it is armed.
 if global_position.distance_to(flown_to)>0.5:
  hold_point=Vector3.INF;hold_height=INF
  if armed and not is_on_floor():lift=maxf(lift,GRAVITY)
 if yaw!=flown_yaw:yaw_target=yaw
 var stick := Vector3.ZERO
 sport=false
 if piloting and not fail_safe:
  var input := Input.get_vector("left","right","forward","back")
  stick=Vector3(input.x,float(Input.is_action_pressed("jump"))-float(Input.is_action_pressed("crouch")),input.y)
  sport=Input.is_action_pressed("sprint")
  if Input.is_action_pressed("jump") and battery>0 and health>0:armed=true
 air_clock+=delta
 if armed:
  battery=maxf(0,battery-delta/FLIGHT_SECONDS*(0.1+0.9*pow(lift/GRAVITY,1.5))*(1.0+damage))
  if fail_safe:notice="АВТОПОСАДКА · НИЗЬКА БАТАРЕЯ / ВТРАТА ЗВ’ЯЗКУ"
  fly_controlled(stick,fail_safe,delta)
 else:
  # Motors stopped: it falls through the air, or lies where it is.
  lift=0.0;wind_trim=Vector3.ZERO;climb_trim=0.0
  hold_point=Vector3.INF;hold_height=INF;yaw_target=yaw
  airframe=airframe.slerp(Basis(),1-exp(-delta*8)).orthonormalized()
  if is_on_floor():
   velocity.x=move_toward(velocity.x,0,delta*8)
   velocity.z=move_toward(velocity.z,0,delta*8)
   velocity.y-=GRAVITY*delta
  else:velocity+=(Vector3.DOWN*GRAVITY+drag(velocity-air()))*delta
 var before := velocity
 move_and_slide()
 flown_to=global_position;flown_yaw=yaw
 touching=get_slide_collision_count()>0
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
 hit_notice=maxf(0.0,hit_notice-delta)
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
 # The airframe leans; the camera on its three-axis gimbal keeps level.
 model.basis=airframe
 camera.rotation=Vector3(camera_pitch,0,0)
 # Damaged, it shakes: the picture with it.
 if damage>0.0:camera.rotation+=Vector3(sin(air_clock*29.0),0,sin(air_clock*31.0+1.0))*0.01*damage
 for i in range(rotors.size()):rotors[i].rotation.y+=delta*(130 if armed else 0)*(1 if i%2==0 else -1)
 if armed and not motor_sound.playing:motor_sound.play()
 elif not armed and motor_sound.playing:motor_sound.stop()
 motor_sound.pitch_scale=0.85+0.15*lift/GRAVITY+velocity.length()*0.012
 motor_sound.volume_db=-9+linear_to_db(maxf(operator.game.volume,0.0001))
 if downed>0.0:downed+=delta
 if piloting and ((health<=0 and (downed<=0.0 or downed>FALL_SHOWN or landed)) or (battery<=0 and landed)):
  if on_lost.is_valid():on_lost.call()
  else:operator.field_rig.cancel()

# One step of the flight controller and the airframe under it. The sticks:
# x right, y up, z back.
func fly_controlled(stick: Vector3, fail_safe: bool, delta: float) -> void:
 obstacle_distance=INF;obstacle_braking=false
 # On its legs with the motors idling: it stays where it stands until the
 # throttle lifts it.
 var on_legs := is_on_floor() and stick.y<=0.05
 if on_legs:yaw_target=yaw
 else:yaw+=clampf(wrapf(yaw_target-yaw,-PI,PI)*8.0,-YAW_RATE,YAW_RATE)*delta
 var heading := Basis(Vector3.UP,yaw)
 var planar := Vector3(velocity.x,0,velocity.z)
 var box := fence()
 # Level flight: the sticks ask for a speed; centred, it brakes and holds.
 var target := Vector3.ZERO
 var asked := heading*Vector3(stick.x,0,stick.z)
 if asked.length()>0.05:
  target=asked.limit_length(1.0)*(SPORT_SPEED if sport else NORMAL_SPEED);hold_point=Vector3.INF
  if not sport:target=avoid(target,heading)
 elif hold_point==Vector3.INF:
  if planar.length()<0.4:hold_point=Vector3(clampf(global_position.x,box.position.x,box.end.x),0,clampf(global_position.z,box.position.y,box.end.y))
 else:target=(Vector3(hold_point.x-global_position.x,0,hold_point.z-global_position.z)*HOLD_GAIN).limit_length(3.0)
 # The geofence: it slows to a stop at the edge of the map, back if past it.
 target.x=clampf(target.x,minf((box.position.x-global_position.x)*0.8,2.0),maxf((box.end.x-global_position.x)*0.8,-2.0))
 target.z=clampf(target.z,minf((box.position.y-global_position.z)*0.8,2.0),maxf((box.end.y-global_position.z)*0.8,-2.0))
 # Height: the throttle asks for a climb or a descent; centred, it holds.
 var climb := 0.0
 if fail_safe:climb=-1.5;hold_height=INF
 elif absf(stick.y)>0.05:
  climb=stick.y*((SPORT_CLIMB if sport else NORMAL_CLIMB) if stick.y>0 else DESCENT);hold_height=INF
  if climb>0.3 and not sport:
   var above := sense(Vector3.UP,UP_SENSING)
   if above!=INF:
    obstacle_distance=minf(obstacle_distance,above)
    var room := sqrt(2.0*OBSTACLE_BRAKING*maxf(above-OBSTACLE_GAP_ABOVE,0.0))
    if room<climb:climb=room;obstacle_braking=true
 elif hold_height==INF:
  if absf(velocity.y)<0.3:hold_height=global_position.y
 else:climb=clampf((hold_height-global_position.y)*1.2,-2.0,2.0)
 # Close over the ground the descent eases off: it sets down at ~1 m/s.
 # (The ground is measured every step only while it goes down; otherwise
 # five times a second with the link.)
 if climb<-0.3 or velocity.y<-0.3:floor_height=ground_clearance()
 climb=maxf(climb,-(0.8+1.2*floor_height))
 var height: float=global_position.y-operator.game.district.ground_height(global_position)
 if height>ceiling:climb=minf(climb,maxf((ceiling-height)*0.8,-2.0))
 # The lean that gives the acceleration wanted, against its own drag.
 var resist := -drag(velocity)
 var error := target-planar
 var wanted := error*SPEED_GAIN+wind_trim+Vector3(resist.x,0,resist.z)
 var support := maxf(GRAVITY+(climb-velocity.y)*CLIMB_GAIN+climb_trim+resist.y,2.0)
 var lean := heading.inverse()*wanted
 var tilt := Vector2(atan(-lean.z/support),atan(lean.x/support))
 var most := SPORT_TILT if sport else NORMAL_TILT
 var saturated := tilt.length()>most
 if saturated:tilt=tilt.normalized()*most
 if on_legs:
  tilt=Vector2.ZERO;hold_point=Vector3.INF;hold_height=INF;wind_trim=Vector3.ZERO;climb_trim=0.0
 elif not touching:
  # The wind trim: what holds it against a steady wind (not while it
  # leans all it may, nor pressed against something).
  if not saturated:wind_trim=(wind_trim+error*TRIM_GAIN*delta).limit_length(GRAVITY*tan(most)*0.8)
  if absf(climb-velocity.y)<1.0:climb_trim=clampf(climb_trim+(climb-velocity.y)*TRIM_GAIN*delta,-3.0,3.0)
 airframe=airframe.slerp(Basis(Vector3.RIGHT,-tilt.x)*Basis(Vector3.BACK,-tilt.y),1-exp(-delta*ATTITUDE_RATE)).orthonormalized()
 var up := heading*airframe.y
 var wanted_lift := 0.25*GRAVITY if on_legs else clampf(support/maxf(up.y,0.5),0.25*GRAVITY,max_lift())
 lift=lerpf(lift,wanted_lift,1-exp(-delta*16))
 if on_legs:
  velocity.x=move_toward(velocity.x,0,delta*8)
  velocity.z=move_toward(velocity.z,0,delta*8)
  velocity+=(up*lift+Vector3.DOWN*GRAVITY)*delta
 else:velocity+=(up*lift+Vector3.DOWN*GRAVITY+drag(velocity-air()))*delta
 if damage>0.0 and not on_legs:
  velocity+=(damage_pull+Vector3(sin(air_clock*23.0)+0.6*sin(air_clock*37.1),0.5*sin(air_clock*19.3),sin(air_clock*27.7+2.0))*2.2*damage)*delta

# Drag of the air moving past at this velocity (m/s²).
func drag(air_velocity: Vector3) -> Vector3:
 return -air_velocity*(ROTOR_DRAG+BODY_DRAG*air_velocity.length())

# The air it flies in: the steady wind and its gusts, a field drifting with
# the wind and changing as it goes (no random numbers: the same for every run).
func air() -> Vector3:
 if wind==Vector3.INF:
  var ballistics: Variant=operator.game.get("ballistics")
  wind=ballistics.wind if ballistics!=null else Vector3.ZERO
 var t := air_clock
 var p := global_position-wind*t
 var gust := Vector3(sin(t*0.37+p.x*0.031)*0.6+sin(t*1.13+p.z*0.047+1.0)*0.4,(sin(t*0.71+p.z*0.05)*0.6+sin(t*1.7+p.x*0.04)*0.4)*0.25,sin(t*0.43+p.z*0.029+2.0)*0.6+sin(t*1.31+p.x*0.043+0.5)*0.4)
 return wind+gust*(1.0+wind.length()*0.25)

# Thrust the pack can give: the voltage sags in the last quarter of the charge.
func max_lift() -> float:return MAX_LIFT*(0.8+0.2*clampf(battery/0.25,0.0,1.0))*(1.0-0.2*damage)

# The geofence, x and z: the battlefield, or the whole operation area round
# the great assault (the 400 m square of the old maps held the drone back
# from far out there).
func fence() -> Rect2:
 if limit>0.0:return Rect2(-limit,-limit,limit*2,limit*2)
 var district: Node3D=operator.game.district
 if is_instance_valid(district.operation_area):
  var half: float=district.operation_area.data.half-60.0
  return Rect2(-half,-half,half*2,half*2)
 if district.map_id==TrainingRange.ID:return Rect2(-200,-415,400,670)
 return Rect2(-195,-195,390,390)

# The sticks send it along target: the sensor on that side looks ahead, and
# the speed toward what it sees is cut to what stops it OBSTACLE_GAP short.
func avoid(target: Vector3, heading: Basis) -> Vector3:
 var direction := target.normalized()
 var ahead := -(heading.inverse()*direction).z
 var reach := SIDE_SENSING
 if ahead>0.707:reach=FRONT_SENSING
 elif ahead<-0.707:
  reach=BACK_SENSING;target=target.limit_length(BACK_SENSING_SPEED)
 var distance := sense(direction,reach)
 if distance==INF:return target
 obstacle_distance=distance
 # Braking at a steady rate, and the last metres in proportion to the gap,
 # so that it settles there (and backs off a little if blown closer).
 var room := distance-OBSTACLE_GAP
 var allowed := maxf(minf(sqrt(2.0*OBSTACLE_BRAKING*maxf(room,0.0)),room*1.5),-1.0)
 if target.length()>allowed:
  target=direction*allowed;obstacle_braking=true
 return target

# The gap between the airframe and the first thing along a unit direction
# within reach (INF: nothing): a sphere the airframe's size swept along it,
# one query; hugging a wall already, a ray instead.
func sense(direction: Vector3, reach: float) -> float:
 if sensor_query==null:
  var sphere := SphereShape3D.new();sphere.radius=0.22
  sensor_query=PhysicsShapeQueryParameters3D.new();sensor_query.shape=sphere
  sensor_query.collision_mask=collision_mask
 var excluded: Array[RID]=[get_rid()]
 if is_instance_valid(operator):excluded.append(operator.get_rid())
 sensor_query.exclude=excluded
 sensor_query.transform=Transform3D(Basis(),global_position)
 sensor_query.motion=direction*reach
 var space := get_world_3d().direct_space_state
 var sweep := space.cast_motion(sensor_query)
 if sweep[1]>=1.0:return INF
 if sweep[1]>0.0:return sweep[0]*reach
 var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position,global_position+direction*reach,collision_mask,excluded))
 return INF if hit.is_empty() else maxf(global_position.distance_to(hit.position)-0.22,0.0)

# The warning on the goggles.
func obstacle_text() -> String:
 if not obstacle_braking:return ""
 if velocity.length()<0.5:return "ПЕРЕШКОДА %.1f м · ЗУПИНКА" % obstacle_distance
 return "ПЕРЕШКОДА %.1f м · ГАЛЬМУЮ" % obstacle_distance

# The flight mode for the goggles.
func mode_text() -> String:
 if not armed:return "МОТОРИ ВИМКНЕНО"
 if landed:return "НА ЗЕМЛІ"
 var text := "S · СПОРТ · ДАТЧИКИ ПЕРЕШКОД ВИМКНЕНО" if sport else "N"
 if hold_point!=Vector3.INF and hold_height!=INF:text+=" · ЗАВИСАННЯ"
 if damage>0.0:text+=" · ПОШКОДЖЕНО"
 return text

# Where things are on the airframe (the model's coordinates): the body with
# the battery and the flight controller, the camera on its gimbal, the four
# motors on their arms, the props over them (Mavic 3: 9.4-inch props on a
# 380 mm diagonal).
func airframe_parts() -> Dictionary:
 var motors: Array[Vector3]=[Vector3(-0.19,0.045,-0.15),Vector3(0.19,0.045,-0.15),Vector3(-0.19,0.045,0.15),Vector3(0.19,0.045,0.15)]
 var roots: Array[Vector3]=[]
 for motor in motors:roots.append(Vector3(signf(motor.x)*0.04,0.04,signf(motor.z)*0.06))
 return {"body":[Vector3(0,0.045,0),Vector3(0.058,0.044,0.09)],"camera":[Vector3(0,0.012,-0.095),Vector3(0.024,0.02,0.02)],
  "motors":motors,"roots":roots,"motor_radius":0.016,"motor_height":0.02,"arm_radius":0.012,"prop_up":0.023,"prop_radius":0.11,"warhead":[]}

# What a round meets on its line through the airframe's box: "body",
# "motor", "camera", "arm", "prop" (a blade, by BLADE_SHARE where it crosses
# a disc), "warhead", or "" — only air between them.
func struck_part(point: Vector3, incoming: Vector3) -> String:
 var parts := airframe_parts()
 var into := model.global_transform.affine_inverse()
 var way := (model.global_basis.inverse()*incoming).normalized()
 var start: Vector3=into*point-way*0.06
 var discs: Array[int]=[]
 for i in range(120):
  var at: Vector3=start+way*(i*0.005)
  for piece in ["body","camera"]:
   var box: Array=parts[piece]
   var off: Vector3=(at-box[0]).abs()
   if off.x<box[1].x and off.y<box[1].y and off.z<box[1].z:return piece
  if not parts.warhead.is_empty():
   var axis: Vector3=at-parts.warhead[0]
   if absf(axis.z)<parts.warhead[2] and Vector2(axis.x,axis.y).length()<parts.warhead[1]:return "warhead"
  for k in range(parts.motors.size()):
   var motor: Vector3=parts.motors[k]
   var across := Vector2(at.x-motor.x,at.z-motor.z).length()
   if across<parts.motor_radius and absf(at.y-motor.y)<parts.motor_height:return "motor"
   var root: Vector3=parts.roots[k]
   if at.distance_to(Geometry3D.get_closest_point_to_segment(at,root,motor))<parts.arm_radius:return "arm"
   if across<parts.prop_radius and absf(at.y-motor.y-parts.prop_up)<0.006 and not discs.has(k):
    discs.append(k)
    if randf()<BLADE_SHARE:return "prop"
 return ""

# A rifle round: a motor or the body (the battery, the flight controller)
# hit brings it down; a broken arm or blade often does, otherwise it flies on
# shaking and pulled aside; a round through the gaps does nothing.
# Fragments of a burst nearby pepper the whole airframe.
func receive_hit(amount: float, zone: String, incoming: Vector3, point: Vector3) -> void:
 if health<=0:return
 var airborne:=armed and not landed
 if zone=="drone":
  var part := struck_part(point,incoming)
  if part=="" or amount<4.0:return
  var fatal := part=="body" or part=="motor" or (part=="arm" and randf()<0.5) or (part=="prop" and randf()<0.4)
  health=0.0 if fatal else maxf(0.0,health-0.5)
  if health>0:
   wounded(part)
   return
 else:
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

# Hit and still in the air: the pilot is told what was hit; it flies on worse.
func wounded(part: String) -> void:
 hit_part=part;hit_notice=3.0
 damage=minf(1.0,damage+0.5)
 var side := Vector2(sin(float(get_instance_id()%97)),cos(float(get_instance_id()%89))).normalized()*0.8
 damage_pull+=Vector3(side.x,-0.3,side.y)
 notice="ДРОН УРАЖЕНО: %s" % PART_NAMES.get(part,part)
 if is_instance_valid(operator) and operator.field_rig!=null and operator.field_rig.drone==self:
  operator.field_rig.drone_notice="Дрон уражено (%s), летить гірше." % String(PART_NAMES.get(part,part)).to_lower()

# A man of the other side takes aim at it: yes while fewer than
# MOST_SHOOTERS others have a go at it just now.
func take_aim(shooter: Object) -> bool:
 var frame := Engine.get_physics_frames()
 var id := shooter.get_instance_id()
 for other in aimed_by.keys():
  if frame-int(aimed_by[other])>45:aimed_by.erase(other)
 if not aimed_by.has(id) and aimed_by.size()>=MOST_SHOOTERS:return false
 aimed_by[id]=frame
 return true

# How far the enemy hears it over the battle: a Mavic class drone is quiet,
# above some 30 m it is hardly heard at all.
func heard_within() -> float:return 35.0

# The red line across the picture: shot down, hit, or rounds going past.
func alarm() -> String:
 if downed>0.0:return "ДРОН ЗБИТО"
 if hit_notice>0.0:return "ДРОН УРАЖЕНО: %s" % PART_NAMES.get(hit_part,hit_part)
 return "ПО ДРОНУ ВЕДУТЬ ВОГОНЬ" if fired_on>0.0 else ""

# The wrist display takes this drone's picture while the goggles are off
# (an analog FPV has none to give it).
func shows_on_wrist() -> bool:return true

func can_recover() -> bool:
 if not landed or armed or global_position.distance_to(operator.camera.global_position)>2.3:return false
 var ray := PhysicsRayQueryParameters3D.create(operator.camera.global_position,global_position,1,[operator.get_rid(),get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
