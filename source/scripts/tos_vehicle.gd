class_name TosVehicle
extends TrackedVehicle

# BM-1 of the TOS-1A «Солнцепёк» (TosArt): the T-72A hull, the platform on
# the turret ring traversing ±100°, the package elevating 0…60°, two jacks
# at the rear corners lowered for firing, 24 MO.1.01.04M fired in pairs
# 0.5 s apart (a full package in 6 s) or one at a time (12 s). From the
# stop to the first rocket it takes 90 s (the maker's figure).
#
# The enemy's vehicle is moved by its owner along a route over the ground
# (`scripted`: like the defenders' BMPs, no track physics) and laid and
# fired by it (EnemyTos). The player's vehicle (make_drivable) runs on the
# tracks of TrackedVehicle with the T-72A's drive: the V-84MS, seven gears
# forward and one reverse in the two onboard gearboxes, steered by the two
# levers (inner_ratio). It is armoured as a T-72A (VehicleArmor.t72_tos)
# and its package of thermobaric rockets goes up when a jet or a fire gets
# into it.
const MASS := 44300.0
const ROCKETS := 24
const TRAVERSE := 100.0
const ELEVATION_TOP := 60.0
# Drive rates of the platform and the package (°/s), and of the jacks.
const TRAVERSE_RATE := 6.0
const ELEVATION_RATE := 4.0
const JACK_TIME := 14.0
const LAUNCH_INTERVAL := 0.5
# On the move: road and field speeds (m/s), turn rate (°/s).
const ROAD_SPEED := 12.0
const FIELD_SPEED := 7.0
const TURN_RATE := 24.0
const FAR_LAUNCH := 1500.0
# Kilometres behind the front: the riflemen, the grenade launchers and the
# BMP gunners only reckon with it when it is this close (the FPV crews and
# the Grads hunt it by its reported position).
const KNOWN_RANGE := 800.0

# --- The T-72A's drive (the player's vehicle) --------------------------------
# V-84MS: 840 hp at 2000 rpm, 3335 N·m at 1300. Onboard gearboxes 8.173 /
# 4.400 / 3.485 / 2.787 / 2.027 / 1.467 / 1.000, reverse 14.35, behind the
# 0.706 input step-up («гітара»); final drives 5.454; the sprocket's pitch
# radius 0.305 m (14 teeth of a 137 mm track): 7.3 / 13.6 / 17.2 / 21.5 /
# 29.5 / 40.8 / 59.8 km/h at 2000 rpm, 4.2 km/h in reverse (the manual:
# 7.32 … 60, reverse 4.18).
const IDLE_RPM := 800.0
const GOVERNED_RPM := 2000.0
const STALL_RPM := 450.0
const INPUT := 0.706
const GEARS := [-14.35*INPUT,0.0,8.173*INPUT,4.400*INPUT,3.485*INPUT,2.787*INPUT,2.027*INPUT,1.467*INPUT,1.000*INPUT]
const GEAR_NAMES := ["З","N","1","2","3","4","5","6","7"]
const NEUTRAL := 1
const FINAL := 5.454
const SPROCKET := 0.305
const TORQUE := [[0.0,0.0],[500.0,1500.0],[800.0,2650.0],[1100.0,3250.0],[1300.0,3335.0],[1700.0,3180.0],[2000.0,2940.0],[2120.0,1100.0],[2220.0,0.0]]
# Tracks 580 mm wide, 2.79 m between their centres, 4.27 m on the ground.
const GAUGE := 2.79
const CONTACT := 4.27
# Torsion bars: about 10 cm of static deflection under 1/12 of the weight.
const WHEEL_SPRING := 362000.0
const WHEEL_DAMPER := 26000.0
const RECORDED_RPM := 1525.0
# A lever pulled this far is at its stop.
const FULL_PULL := 0.9
const PRIMED_PRESSURE := 2.0
# The computer and the roll sensor settle after the power is on; the travel
# locks of the platform and the package are drawn by their solenoids.
const FCS_WARMUP := 40.0
const LOCK_TIME := 4.0
# The 1D14: a ×8 sight channel and a laser ranging 400–10000 m to ±10 m.
const SIGHT_FOV := 7.0
const LASER_RANGE := Vector2(400.0,10000.0)

var hull: VehicleDamage
var friendly := false
var rng := RandomNumberGenerator.new()
var loaded: Array[bool]=[]
var order := TosArt.firing_order()
var fired := 0
var platform_yaw := 0.0
var elevation := 0.0
var want_yaw := 0.0
var want_elevation := 0.0
var jacks := 0.0
var jacks_wanted := false
var route := PackedVector3Array()
var route_index := 0
# Speed on the scripted route (m/s).
var crawl := 0.0
var cruise := FIELD_SPEED
var travelled := 0.0
var salvo_left := 0
var salvo_clock := 0.0
var pairs := true
var cooking := false
var cook_clock := 0.0
var last_launch := -100.0
var far_heard := -100.0
var cloud: CPUParticles3D
var launch_players: Array[AudioStreamPlayer3D]=[]
var launch_index := 0
var engine_on := false
var shake := Vector3.ZERO
var shake_rate := Vector3.ZERO
var package_shape: CollisionShape3D
var platform_shape: CollisionShape3D

# --- The player's vehicle ------------------------------------------------------
var scripted := true
# The steering levers, pulled 0…1: part way the lagging side's clutches
# slip toward the next lower gear, a full pull (FULL_PULL) locks it there.
var levers := Vector2.ZERO
var lever_input := Vector2.ZERO
# The oil pump before a start (МЗН): the starter turns a primed engine only.
var priming := false
var primed := 0.0
var prime_pressure := 0.0
var fcs_power := false
var fcs_warm := 0.0
var stops_locked := true
var stop_motion := 0.0
var armed := false
var series := 12
# The gunner's own traverse of the platform and the sight's head.
var traverse_input := 0.0
var fine := false
var sight_pitch := 0.0
var laser_reading: Dictionary={}
# What the computer laid the package on: from the 1D14 or from the tablet.
var solution: Dictionary={}
var fired_at := -100.0

func setup(owner_game: Node3D, seed_value: int=0) -> void:
 game=owner_game
 name="TosVehicle"
 rng.seed=seed_value if seed_value!=0 else 0x705
 mass=MASS
 freeze=true;freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC
 collision_layer=1
 collision_mask=1|64
 set_meta("ballistic_material","steel")
 hull=VehicleDamage.new();hull.setup(self,VehicleArmor.t72_tos())
 add_to_group("vehicles")
 art=TosArt.build()
 add_child(art.root)
 VehicleMarkings.apply(self,friendly)
 for shape_data in [[Vector3(3.30,1.05,6.86),Vector3(0,0.98,0)],[Vector3(2.44,0.50,2.45),Vector3(0,1.75,-0.13)]]:
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=shape_data[0]
  shape.shape=box;shape.position=shape_data[1];add_child(shape)
  if platform_shape==null and shape_data[1].y>1.5:platform_shape=shape
 package_shape=CollisionShape3D.new()
 var package_box:=BoxShape3D.new();package_box.size=Vector3(2.24,0.92,3.90)
 package_shape.shape=package_box;add_child(package_shape)
 loaded.resize(ROCKETS);loaded.fill(true)
 engine_sound=AudioStreamPlayer3D.new();engine_sound.stream=GradAudio.looped("bmp_engine","res://assets/audio/bmp/engine.wav")
 engine_sound.unit_size=12;engine_sound.max_distance=700;engine_sound.pitch_scale=0.78
 engine_sound.position=Vector3(0,1.2,2.0);engine_sound.bus=game.hearing.bus_name;add_child(engine_sound)
 for i in range(6):
  var output:=AudioStreamPlayer3D.new();output.unit_size=45;output.max_distance=6000
  output.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
  output.position=Vector3(0,2.6,1.0);add_child(output);output.bus=game.hearing.bus_name
  launch_players.append(output)
 pose()

# The player's vehicle: on its tracks, with the seats' camera.
func make_drivable() -> void:
 scripted=false
 hull_mass=MASS;idle_rpm=IDLE_RPM;governed_rpm=GOVERNED_RPM;stall_rpm=STALL_RPM
 gears=GEARS;neutral=NEUTRAL;gear=NEUTRAL;final_drive=FINAL;sprocket=SPROCKET;efficiency=0.80
 engine_inertia=6.0;clutch_capacity=4700.0;torque_curve=TORQUE
 friction=Vector2(90.0,0.12);starter_torque=600.0;starter_rpm=220.0;catch_rpm=180.0
 gauge=GAUGE;contact=CONTACT;yaw_inertia=219900.0
 wheel_spring=WHEEL_SPRING;wheel_damper=WHEEL_DAMPER;ray_top=0.85;free_length=0.95;travel=0.32
 frontal_area=8.0;recorded_rpm=RECORDED_RPM
 crush_half=Vector2(1.75,3.45);ram_width=TosArt.WIDTH+0.2;ram_half=TosArt.HALF
 wheel_radius=TosArt.WHEEL_RADIUS;wheel_height=TosArt.WHEEL_RADIUS+0.08;sprocket_radius=TosArt.SPROCKET_RADIUS
 # On the march the driver rides with his head out of the hatch.
 hatch_open=true;parking=true
 freeze=false
 center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
 center_of_mass=Vector3(0,1.05,0.2)
 inertia=Vector3(193600,219900,62060)
 can_sleep=false
 linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
 linear_damp=0.0
 var ground_friction:=PhysicsMaterial.new();ground_friction.friction=0.35;physics_material_override=ground_friction
 set_meta("vehicle",true)
 mount_wheels(TosArt.WHEELS_Z)
 seat_camera=Camera3D.new();seat_camera.name="SeatCamera";seat_camera.near=0.05;seat_camera.far=6000;seat_camera.fov=75
 seat_camera.cull_mask=1|OperatorBody.WORLD_BODY_LAYER
 add_child(seat_camera)
 engine_sound.unit_size=12;engine_sound.max_distance=700

# The cloud of smoke and dust the launches raise round the vehicle, made at
# the first launch: a new CPUParticles3D draws on the engine's global random
# numbers when it is made (Godot 4.5), and a seeded battle must play the
# same as before until the TOS fires.
func launch_cloud() -> CPUParticles3D:
 if cloud!=null:return cloud
 cloud=CPUParticles3D.new();cloud.name="LaunchCloud"
 cloud.amount=90;cloud.lifetime=8.0;cloud.randomness=0.3;cloud.emitting=false;cloud.local_coords=false
 cloud.use_fixed_seed=true;cloud.seed=rng.randi()
 cloud.mesh=TosEffects.quad("smoke")
 cloud.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;cloud.emission_box_extents=Vector3(3.5,0.8,5.0)
 cloud.position=Vector3(0,1.0,1.5)
 cloud.direction=Vector3.UP;cloud.spread=70.0;cloud.initial_velocity_min=1.5;cloud.initial_velocity_max=4.5
 cloud.damping_min=0.6;cloud.damping_max=1.2;cloud.gravity=Vector3(0.2,0.35,0.05)
 cloud.scale_amount_min=5.0;cloud.scale_amount_max=9.0
 cloud.scale_amount_curve=TosEffects.curve([[0.0,0.5],[0.15,1.0],[1.0,2.3]])
 cloud.color_ramp=TosEffects.ramp([[0.0,Color(0.55,0.52,0.47,0.0)],[0.04,Color(0.6,0.57,0.52,0.88)],[0.5,Color(0.72,0.7,0.66,0.6)],[1.0,Color(0.8,0.79,0.76,0)]])
 cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(cloud)
 return cloud

func _exit_tree() -> void:
 if is_instance_valid(cloud):cloud.emitting=false

# --- State -------------------------------------------------------------------
func remaining() -> int:
 var count:=0
 for item in loaded:if item:count+=1
 return count

func has_rockets() -> bool:return remaining()>0
func out_of_action() -> bool:return hull.out_of_action()
func usable() -> bool:return not destroyed and not hull.burning
static func out_of_sight(vehicle: Node3D, from: Vector3) -> bool:
 return vehicle is TosVehicle and vehicle.global_position.distance_to(from)>KNOWN_RANGE
func firing() -> bool:return salvo_left>0
func moving() -> bool:return route_index<route.size()
func turret_yaw() -> float:return deg_to_rad(platform_yaw)
func standing() -> bool:return crawl<0.05 if scripted else absf(speed())<0.1

# Laid where it was told: the jacks down, the platform and the package
# still, the sight unbroken.
func laid() -> bool:
 return jacks>=1.0 and absf(platform_yaw-want_yaw)<0.05 and absf(elevation-want_elevation)<0.05

func ground(point: Vector3) -> Vector3:
 if game.selected_map==BattleMap.ID:return Vector3(point.x,AvdiivkaData.shared().height(point.x,point.z),point.z)
 return Vector3(point.x,game.district.ground_height(point),point.z)

# --- Orders from the owner ----------------------------------------------------
func drive_to(points: PackedVector3Array, road: bool=false) -> void:
 route=points;route_index=0;cruise=ROAD_SPEED if road else FIELD_SPEED
 if not route.is_empty():jacks_wanted=false;want_elevation=0.0;engine_on=true

func halt() -> void:
 route=PackedVector3Array();route_index=0

# Lay the package on a grid bearing and an elevation (thousandths). The
# ballistic computer takes the hull's tilt from the roll and pitch sensor:
# the platform angle and the package elevation are worked out in the hull's
# frame. False when the platform cannot turn that far (±100°) or the
# package cannot rise that high: the hull has to be turned.
func lay(bearing_mils: float, elevation_mils: float) -> bool:
 var aim:=laying(bearing_mils,elevation_mils)
 if absf(aim.x)>TRAVERSE or aim.y<0.0 or aim.y>ELEVATION_TOP:return false
 jacks_wanted=true;engine_on=true
 want_yaw=aim.x;want_elevation=aim.y
 return true

# (platform angle, package elevation) in degrees for a direction.
func laying(bearing_mils: float, elevation_mils: float) -> Vector2:
 var e:=GradBallistics.radians(elevation_mils)
 var world:=GradBallistics.direction(bearing_mils)*cos(e)+Vector3.UP*sin(e)
 var local:=global_basis.orthonormalized().inverse()*world
 return Vector2(rad_to_deg(atan2(-local.x,-local.z)),rad_to_deg(asin(clampf(local.y,-1.0,1.0))))

func stow() -> void:
 want_yaw=0.0;want_elevation=0.0;jacks_wanted=false

func can_lay(bearing_mils: float, elevation_mils: float=0.0) -> bool:
 var aim:=laying(bearing_mils,elevation_mils)
 return absf(aim.x)<=TRAVERSE and aim.y>=0.0 and aim.y<=ELEVATION_TOP

func fire_salvo(count: int, in_pairs: bool=true) -> bool:
 if not usable() or hull.weapon_out or not laid() or remaining()==0:return false
 salvo_left=mini(count,remaining());pairs=in_pairs;salvo_clock=0.0
 return true

# --- Simulation ---------------------------------------------------------------
func _physics_process(delta: float) -> void:
 if not scripted:
  drive_tick(delta)
  return
 if game==null or not game.running or game.paused:
  if is_instance_valid(engine_sound):engine_sound.stream_paused=true
  if is_instance_valid(cloud):cloud.speed_scale=0.0
  return
 if cloud!=null:cloud.speed_scale=1.0
 clock+=delta
 hull.tick(delta)
 if cooking:cook(delta)
 if destroyed:
  engine_sound.stream_paused=true
  return
 move(delta)
 work(delta)
 if salvo_left>0:salvo(delta)
 elif cloud!=null and cloud.emitting and clock-last_launch>1.5:cloud.emitting=false
 sound(delta)
 pose()

func move(delta: float) -> void:
 if immobile or hull.burning or jacks>0.0 or route_index>=route.size():
  crawl=move_toward(crawl,0.0,delta*4.0)
  if crawl<=0.0:return
 var goal: Vector3=route[mini(route_index,route.size()-1)] if not route.is_empty() else global_position
 var flat:=goal-global_position;flat.y=0
 if route_index<route.size() and flat.length()<4.0:
  route_index+=1
  if route_index>=route.size():return
  goal=route[route_index];flat=goal-global_position;flat.y=0
 var heading:=-global_basis.z;heading.y=0;heading=heading.normalized()
 var angle:=heading.signed_angle_to(flat.normalized(),Vector3.UP) if flat.length()>0.1 else 0.0
 var turn:=clampf(angle,-deg_to_rad(TURN_RATE)*delta,deg_to_rad(TURN_RATE)*delta)
 var target_speed:=cruise if absf(angle)<0.5 else 2.5
 if route_index>=route.size()-1:target_speed=minf(target_speed,maxf(1.5,flat.length()*0.4))
 if route_index>=route.size() or immobile or hull.burning:target_speed=0.0
 crawl=move_toward(crawl,target_speed,delta*(1.6 if crawl<target_speed else 4.0))
 heading=heading.rotated(Vector3.UP,turn)
 var next:=global_position+heading*crawl*delta
 travelled+=crawl*delta
 place(next,heading)

# Stands the hull on the ground under it, pitched and rolled by the ground
# under its tracks.
func place(at: Vector3, heading: Vector3) -> void:
 var side:=heading.cross(Vector3.UP).normalized()
 var front:=ground(at+heading*2.2);var back:=ground(at-heading*2.2)
 var left:=ground(at-side*1.4);var right:=ground(at+side*1.4)
 var forward:=(front-back).normalized()
 var across:=(right-left).normalized()
 var up:=across.cross(forward).normalized()
 if up.y<0.0:up=-up
 # Built from the hull's long axis: on a side slope the heading stays the
 # one it was driven on (built from the cross axis it swung round).
 var side_axis:=forward.cross(up).normalized()
 var basis:=Basis(side_axis,side_axis.cross(forward).normalized(),-forward)
 var y:=(front.y+back.y+left.y+right.y)*0.25
 global_transform=Transform3D(basis,Vector3(at.x,y,at.z))

func work(delta: float) -> void:
 # The jacks go down only with the vehicle stopped; the package comes down
 # and the platform round before they come up.
 var stopped:=standing()
 if jacks_wanted and stopped:jacks=move_toward(jacks,1.0,delta/JACK_TIME)
 elif not jacks_wanted and absf(elevation)<0.5 and absf(platform_yaw)<0.5:jacks=move_toward(jacks,0.0,delta/JACK_TIME)
 if hull.weapon_out and salvo_left==0:return
 if jacks>=0.3 or not jacks_wanted:
  platform_yaw=move_toward(platform_yaw,want_yaw,TRAVERSE_RATE*delta)
  elevation=move_toward(elevation,want_elevation,ELEVATION_RATE*delta)

func salvo(delta: float) -> void:
 salvo_clock-=delta
 if salvo_clock>0.0:return
 salvo_clock=LAUNCH_INTERVAL
 var shots:=2 if pairs else 1
 for k in range(shots):
  if salvo_left<=0:break
  if not launch_next():salvo_left=0;break
  salvo_left-=1

func next_tube() -> int:
 for index in order:
  if loaded[index]:return index
 return -1

func launch_direction() -> Vector3:
 return (art.cradle as Node3D).global_basis*Vector3.FORWARD

func launch_next() -> bool:
 var index:=next_tube()
 if index<0:return false
 loaded[index]=false;fired+=1
 art.caps.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3.ZERO))
 var cradle: Node3D=art.cradle
 var axis:=TosArt.tube_axis(index)
 var rear:=cradle.to_global(Vector3(axis.x,axis.y,TosArt.TUBE_REAR))
 var front:=cradle.to_global(Vector3(axis.x,axis.y,TosArt.TUBE_REAR-TosArt.TUBE_LENGTH))
 var direction:=launch_direction()
 var right:=direction.cross(Vector3.UP).normalized()
 direction=direction.rotated(Vector3.UP,rng.randfn(0,TosBallistics.DIRECTION_SPREAD)).rotated(right,rng.randfn(0,TosBallistics.ELEVATION_SPREAD)).normalized()
 var shot:=TosBallistics.state(rear,0,0,1.0+rng.randfn(0,TosBallistics.IMPULSE_SPREAD))
 shot.launch=direction
 if not scripted:shot.player=true
 game.blasts.launch_tos(shot,self)
 last_launch=clock
 # On its jacks and locked springs the hull hardly moves; the package
 # shudders with each rocket leaving it.
 shake_rate+=Vector3(rng.randf_range(0.10,0.18),rng.randf_range(-0.05,0.05),signf(axis.x)*rng.randf_range(0.04,0.08))
 TosEffects.launch(game,front,rear,direction)
 launch_cloud().emitting=true
 play_launch(rear,remaining()==0 or salvo_left<=1)
 exhaust_danger(rear,direction)
 return true

# The jet behind the package burns and throws anyone standing there.
func exhaust_danger(rear: Vector3, direction: Vector3) -> void:
 for actor in [game.player]+game.allies+game.bots:
  if not is_instance_valid(actor) or (actor is Hostile and (actor.dead or actor.vehicle!=null)):continue
  if actor is Operator and game.player_sheltered():continue
  var offset:Vector3=actor.global_position+Vector3.UP-rear
  var behind:=-offset.dot(direction)
  if behind<0.0 or behind>30.0:continue
  var side:=(offset+direction*behind).length()
  if side>2.5+behind*0.45:continue
  var intensity:=clampf(1.0-behind/30.0,0,1)
  actor.receive_blast(220.0*intensity,clampf(intensity*1.4,0,1),direction*-1.0)

# Launches heard: close, the recorded launch, lower and heavier than a
# Grad's; kilometres away a rolling rumble that comes late.
func play_launch(at: Vector3, last: bool) -> void:
 var listener:=get_viewport().get_camera_3d()
 var distance:=listener.global_position.distance_to(at) if listener!=null else 0.0
 if distance>FAR_LAUNCH:
  if clock-far_heard>0.9 or last:far_heard=clock;game.distant_launch(at,distance)
  return
 var output:=launch_players[launch_index];launch_index=(launch_index+1)%launch_players.size()
 output.stream=TosAudio.clip("launch_tail" if last else "launch_close")
 output.volume_db=linear_to_db(maxf(game.volume,0.0001))+4.0
 output.pitch_scale=rng.randf_range(0.70,0.76)
 output.play()
 if is_instance_valid(game.player):game.hearing.shot(game.player.camera.global_position.distance_to(at)*0.4)

func sound(_delta: float) -> void:
 if not is_instance_valid(engine_sound):return
 engine_sound.stream_paused=not engine_on
 if engine_on and not engine_sound.playing:engine_sound.play()
 engine_sound.pitch_scale=0.72+crawl/ROAD_SPEED*0.25
 engine_sound.volume_db=linear_to_db(maxf(game.volume,0.0001))+lerpf(-4.0,3.0,clampf(crawl/ROAD_SPEED,0,1))

# Wheels, platform, package, ram and jacks after the state; the package
# shudders with the launches.
func pose() -> void:
 var platform: Node3D=art.platform
 platform.rotation.y=deg_to_rad(platform_yaw)
 shake_rate+=(-shake*TAU*TAU*9.0-shake_rate*2.0*0.25*TAU*3.0)*get_physics_process_delta_time()
 shake+=shake_rate*get_physics_process_delta_time()
 var cradle: Node3D=art.cradle
 cradle.rotation=Vector3(deg_to_rad(elevation)+shake.x*0.02,shake.z*0.01,0)
 var ram: Node3D=art.ram
 var bracket:=cradle.transform*TosArt.RAM_BRACKET
 var reach:=ram.position.distance_to(bracket)
 if reach>0.05:
  ram.look_at(platform.to_global(bracket),platform.global_basis.y)
  (ram.get_node("Rod") as Node3D).scale=Vector3(1,1,reach)
 for i in range(art.jacks.size()):
  var jack: Node3D=art.jacks[i]
  jack.position=TosArt.JACKS[i]+Vector3.DOWN*TosArt.JACK_STROKE*jacks
 if scripted:
  var turn:=travelled/TosArt.WHEEL_RADIUS
  for wheel in art.wheels:(wheel as Node3D).rotation.x=-turn
  for hub in art.drive:(hub as Node3D).rotation.x=-travelled/TosArt.SPROCKET_RADIUS
 else:animate_running_gear()
 if is_instance_valid(platform_shape):
  platform_shape.position=TosArt.RING+Basis(Vector3.UP,deg_to_rad(platform_yaw))*Vector3(0,0.25,0.12)
  platform_shape.rotation.y=deg_to_rad(platform_yaw)
 if is_instance_valid(package_shape):
  var centre:=cradle.global_transform*Vector3(0,TosArt.TUBE_BOTTOM+0.24,TosArt.TUBE_REAR-TosArt.TUBE_LENGTH*0.5)
  package_shape.global_transform=Transform3D(cradle.global_basis,centre)
 VehicleMarkings.flutter(self,art)

# --- The player's vehicle on its tracks ----------------------------------------
func drive_tick(delta: float) -> void:
 if game==null:return
 if is_instance_valid(engine_sound):engine_sound.stream_paused=game.paused or not game.running
 if not game.running or game.paused:
  if is_instance_valid(cloud):cloud.speed_scale=0.0
  if not was_paused and not freeze:
   paused_velocity=linear_velocity;paused_spin=angular_velocity
   freeze_mode=RigidBody3D.FREEZE_MODE_STATIC;freeze=true
   was_paused=true
  return
 if cloud!=null:cloud.speed_scale=1.0
 if was_paused:
  was_paused=false
  if not parking or parked_time<0.8:
   freeze=false;linear_velocity=paused_velocity;angular_velocity=paused_spin
 clock+=delta
 if notice_left>0:notice_left-=delta
 grind=maxf(0,grind-delta)
 if seat!="driver":throttle=0;lever_input=Vector2.ZERO;brake_pedal=0.0
 # On its jacks the hull does not move: they hold it like the brakes.
 if jacks>0.0:parking=true
 steer_levers(delta)
 if both_pulled() and (gear==0 or gear==NEUTRAL+1):brake_pedal=1.0
 prime(delta)
 simulate_engine(delta)
 update_gauges(delta)
 if prime_pressure>0.0 and not running:oil_pressure=maxf(oil_pressure,prime_pressure)
 if not freeze:
  suspend(delta)
  drive(delta)
 hold_parked(delta)
 hull.tick(delta)
 if cooking:cook(delta)
 if not destroyed:
  update_fcs(delta)
  work(delta)
  if salvo_left>0:salvo(delta)
  elif cloud!=null and cloud.emitting and clock-last_launch>1.5:cloud.emitting=false
 pose()
 crush()
 ram()
 if seat!="" and is_instance_valid(game.district.operation_area):game.district.operation_area.collide_trees(global_position)

# The levers come back on their springs when let go.
func steer_levers(delta: float) -> void:
 for i in range(2):
  if lever_input[i]>0.0:levers[i]=minf(1.0,levers[i]+lever_input[i]*1.4*delta)
  else:levers[i]=move_toward(levers[i],0.0,delta*3.0)

# Both levers pulled alike steer nowhere: both sides go a gear lower
# (gear_ratio), or in 1st and reverse both brake.
func steer_side() -> float:
 if levers.x<0.06 and levers.y<0.06:return 0.0
 if levers.x>=0.06 and levers.y>=0.06 and absf(levers.x-levers.y)<0.15:return 0.0
 return -1.0 if levers.x>=levers.y else 1.0

func both_pulled() -> bool:return minf(levers.x,levers.y)>=FULL_PULL

# The lagging side's gearbox a gear lower: in 2nd–7th the hull turns on a
# radius set by the gear (R = B·i(n−1)/(i(n−1)−i(n)) to the outer track:
# 6.0 / 13.4 / 13.9 / 10.2 / 10.1 / 8.8 m); in 1st and in reverse the
# gearbox of that side brakes and the hull turns about the stopped track.
# Part way the clutches slip and the radius runs from straight to that.
# There is no neutral turn: in neutral the levers do nothing.
func lower_gear_ratio() -> float:
 if gear>=NEUTRAL+2:return float(GEARS[gear])/float(GEARS[gear-1])
 return 0.0

func inner_ratio() -> float:
 var s:=maxf(levers.x,levers.y)
 if s<0.06 or gear==NEUTRAL:return 1.0
 var k1:=lower_gear_ratio()
 if s<FULL_PULL:return lerpf(1.0,k1,(s-0.06)/(FULL_PULL-0.06))
 return k1

func gear_ratio() -> float:
 if both_pulled() and gear>=NEUTRAL+2:return float(GEARS[gear-1])*final_drive
 return super.gear_ratio()

func lever_text(value: float) -> String:
 if value<0.06:return "—"
 if value<FULL_PULL:return "пробуксовка"
 return "до упору"

# Gears are changed with the gearboxes' clutch pedal down, one at a time;
# reverse only from neutral at a standstill. With the brake on its latch no
# gear goes in. The BA-20 unit keeps 7→6, 6→5 and 5→4 out above the speed
# the lower gear can take.
func shift(step: int) -> bool:
 if clutch_engagement()>0.15:
  grind=0.4;say("Вижми педаль зчеплення (Shift), потім перемикай",2.5);return false
 var next:=clampi(gear+step,0,GEARS.size()-1)
 if next==gear:return false
 if parking and next!=NEUTRAL:say("Гальма на защіпці: спершу зніми (SPACE)",2.5);return false
 if next==0 and absf(speed())>0.5:say("Задню — лише на місці",2.5);return false
 if step<0 and gear>=NEUTRAL+5 and absf(speed())>speed_in(next,GOVERNED_RPM):
  say("БА-20: швидкість завелика для %s-ї передачі — пригальмуй" % GEAR_NAMES[next],2.5);return false
 gear=next
 game.sound("click",-18)
 say("Передача %s" % GEAR_NAMES[gear],1.5)
 return true

func toggle_master() -> void:
 master=not master
 if not master:priming=false;fcs_power=false;armed=false
 if not master and running:running=false;say("Маса вимкнена · подачу палива перекрито, двигун зупинено")
 else:say("Вимикач батарей (МАСА) %s" % ("увімкнено" if master else "вимкнено"),2)
 game.sound("click",-14)

func toggle_hatch() -> void:
 hatch_open=not hatch_open;game.sound("click",-10)
 say("Люк механіка-водія %s" % ("відкрито · голова назовні" if hatch_open else "закрито · огляд через прилад ТНПО-168В"),2)

# The oil pump (МЗН) brings the pressure to 2 kgf/cm² in 2–12 s before the
# starter may turn the engine; primed, it may for a minute.
func prime(delta: float) -> void:
 if primed>0.0:primed-=delta
 if priming and master and not running:
  prime_pressure=move_toward(prime_pressure,2.8,0.35*delta)
  if prime_pressure>=PRIMED_PRESSURE:
   if primed<=0.0:say("Тиск масла %.1f кгс/см² — можна запускати (X)" % prime_pressure,2)
   primed=60.0
 else:
  prime_pressure=move_toward(prime_pressure,0.0,0.15*delta)
  if priming and not master:priming=false;say("МЗН без живлення: увімкни масу (I)",2)

# The neutral sensor keeps the starter off with a gear in.
func begin_crank() -> void:
 if starter or running:return
 if master and gear!=NEUTRAL:say("Стартер — лише на нейтралі (SHIFT + Q до N)",3);return
 if master and primed<=0.0:say("Спершу прокачай масло: утримуй P (МЗН), доки тиск не стане понад 2 кгс/см²",3);return
 super.begin_crank()

# The brake pedal's latch goes on in neutral only.
func toggle_parking() -> void:
 if jacks>0.0 and parking:say("Машина на домкратах: спершу підніми їх (пульт командира)",3);return
 if not parking and gear!=NEUTRAL:say("Гальма на защіпку — лише на нейтралі (SHIFT + Q до N)",3);return
 super.toggle_parking()

# --- Fire control ---------------------------------------------------------------
func fcs_ready() -> bool:return fcs_power and fcs_warm>=1.0

# Hydraulics and the drives work from the engine; the computer and the
# roll sensor from the batteries.
func drives_powered() -> bool:return running and not hull.weapon_out

func update_fcs(delta: float) -> void:
 if fcs_power and not master:fcs_power=false
 fcs_warm=move_toward(fcs_warm,1.0 if fcs_power else 0.0,delta/FCS_WARMUP if fcs_power else delta)
 if stop_motion>0.0:
  stop_motion-=delta
  if stop_motion<=0.0:say("Стопори платформи й пакета %s" % ("ЗАКРИТО" if stops_locked else "ЗНЯТО"),2)
 # The gunner's own traverse: the platform follows his handwheel.
 if traverse_input!=0.0 and can_traverse():
  want_yaw=clampf(want_yaw+traverse_input*TRAVERSE_RATE*(0.2 if fine else 1.0)*delta,-TRAVERSE,TRAVERSE)
 # Locked, or with no power for the drives, the platform stays as it is.
 if stops_locked or stop_motion>0.0 or not drives_powered():
  want_yaw=platform_yaw;want_elevation=elevation
 # Off its jacks the package rides on its travel rest.
 if jacks<1.0 and not jacks_wanted and want_elevation>0.0 and absf(platform_yaw)<0.5:want_elevation=0.0

func can_traverse() -> bool:return not stops_locked and stop_motion<=0.0 and drives_powered()

func toggle_jacks() -> bool:
 if not jacks_wanted and not standing():say("Домкрати опускають лише на місці",2.5);return false
 if not running:say("Домкрати на гідравліці: заведи двигун",2.5);return false
 if jacks_wanted and (absf(elevation)>0.5 or absf(platform_yaw)>0.5):
  want_yaw=0.0;want_elevation=0.0;solution={}
  say("Пакет іде в похідне положення, домкрати піднімуться за ним",3)
 jacks_wanted=not jacks_wanted
 if jacks_wanted:parking=true
 game.sound("click",-14)
 return true

func toggle_stops() -> bool:
 if stop_motion>0.0:return false
 if not stops_locked and (absf(platform_yaw)>0.5 or elevation>0.5):say("Стопори закривають на 0° і 0°: виведи платформу й пакет у похідне",3);return false
 if not master:say("Стопори без живлення: увімкни масу",2);return false
 stops_locked=not stops_locked;stop_motion=LOCK_TIME
 game.sound("click",-14)
 return true

func toggle_fcs() -> void:
 if not master and not fcs_power:say("СУО без живлення: увімкни масу",2);return
 fcs_power=not fcs_power
 if not fcs_power:armed=false
 say("Живлення СУО %s" % ("УВІМКНЕНО · обчислювач і датчик крену готуються %d с" % int(FCS_WARMUP) if fcs_power else "вимкнено"),3)
 game.sound("click",-14)

func cycle_series() -> void:
 var choices:=[1,2,6,12,24]
 series=choices[(choices.find(series)+1)%choices.size()]
 game.sound("click",-18)

func toggle_pairs() -> void:
 pairs=not pairs;game.sound("click",-18)

func toggle_armed() -> void:
 if not fcs_ready() and not armed:say("СУО не готова: живлення й %d с на підготовку" % int(FCS_WARMUP),2.5);return
 armed=not armed
 game.sound("click",-12)

# The 1D14's laser along the sight's line: the slant range to what it hits.
func sight_transform() -> Transform3D:
 var platform: Node3D=art.platform
 var head:=platform.global_transform*Transform3D(Basis.IDENTITY,TosArt.SIGHT+Vector3(0,0.04,-0.16))
 return head*Transform3D(Basis(Vector3.RIGHT,deg_to_rad(sight_pitch)),Vector3.ZERO)

func range_target() -> Dictionary:
 if not fcs_ready():say("Далекомір не готовий: живлення СУО",2);return {}
 var eye:=sight_transform()
 var from:=eye.origin
 var to:=from-eye.basis.z*LASER_RANGE.y
 var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1,[get_rid()]))
 game.sound("click",-20)
 if hit.is_empty():laser_reading={"distance":-1.0,"time":clock};return laser_reading
 var p: Vector3=hit.position
 var d:=from.distance_to(p)
 if d<LASER_RANGE.x:laser_reading={"distance":-2.0,"time":clock};return laser_reading
 # ±10 m: the reading is rounded to five metres and off by a few.
 var reading:=snappedf(d+rng.randf_range(-6.0,6.0),5.0)
 laser_reading={"distance":reading,"point":from+(p-from).normalized()*reading,"time":clock,"pitch":sight_pitch}
 return laser_reading

# The computer: a range and a bearing to a point (or the last laser
# reading), the drop to it, the elevation for the range from the firing
# table and the laying in the hull's frame from the roll sensor.
func compute(point: Vector3, source: String) -> Dictionary:
 if not fcs_ready():say("Обчислювач не готовий",2);return {}
 var from:=(art.cradle as Node3D).global_position
 var flat:=Vector2(point.x-from.x,point.z-from.z)
 var distance:=flat.length()
 var result:={"point":point,"distance":distance,"source":source,"drop":from.y-point.y}
 if distance<TosBallistics.SPAN.x or distance>TosBallistics.SPAN.y:
  result.error="Дальність %d м поза межами 600–6000 м" % roundi(distance)
  solution=result;return result
 var bearing:=GradBallistics.bearing(Vector3(flat.x,0,flat.y))
 var e:=TosBallistics.elevation_to(distance,from.y-point.y)
 result.bearing=bearing;result.elevation=e;result.time=TosBallistics.time_for(distance)
 var aim:=laying(bearing,e)
 result.platform=aim.x;result.package=aim.y
 if absf(aim.x)>TRAVERSE:result.error="Ціль поза сектором ±100°: розверни машину"
 elif aim.y>ELEVATION_TOP:result.error="Потрібен кут понад 60°"
 solution=result
 return result

# The drives follow the computer once the vehicle stands on its jacks.
func lay_solution() -> bool:
 if solution.is_empty() or solution.has("error"):return false
 # The hull may have settled on its jacks since: lay again from its tilt.
 var aim:=laying(float(solution.bearing),float(solution.elevation))
 if absf(aim.x)>TRAVERSE or aim.y<0.0 or aim.y>ELEVATION_TOP:return false
 want_yaw=aim.x;want_elevation=aim.y
 return true

func ready_to_fire() -> String:
 if remaining()==0:return "Пакет порожній"
 if not fcs_ready():return "СУО не готова"
 if not armed:return "Запобіжник: увімкни ЗБРОЯ"
 if stops_locked or stop_motion>0.0:return "Стопори не знято"
 if jacks<1.0:return "Машина не на домкратах"
 if absf(platform_yaw-want_yaw)>0.05 or absf(elevation-want_elevation)>0.05:return "Пакет ще наводиться"
 if elevation<1.0:return "Пакет на опорі: наведи на ціль"
 return ""

func fire() -> bool:
 var why:=ready_to_fire()
 if why!="":say("ПУСК НЕМОЖЛИВИЙ: %s" % why,2.5);game.sound("click",-10);return false
 if salvo_left>0:return false
 if not fire_salvo(series,pairs):return false
 fired_at=clock
 return true

# --- Damage -------------------------------------------------------------------
func vehicle_hit(point: Vector3, direction: Vector3, round: String, pen_mm: float=-1.0) -> Dictionary:
 return hull.strike(point,direction,round,pen_mm)

func blast_hit(where: Vector3, kind: String) -> void:hull.blast(where,kind)

# The crew of the enemy's vehicle are not figures on the field; the
# player inside his is.
func occupants() -> Array:
 if scripted or seat=="" or not is_instance_valid(game.player):return []
 var at:=TosArt.DRIVER_EYE+Vector3(0,-0.45,0)
 if seat=="gunner":at=TosArt.GUNNER_EYE+Vector3(0,-0.3,0)
 elif seat=="commander":at=TosArt.COMMANDER_EYE+Vector3(0,-0.3,0)
 return [[game.player,at]]

func forget_occupant(_actor: Node3D) -> void:pass

func carries_player() -> bool:return not scripted and seat!=""

func openings() -> float:return 1.0+(0.15 if hatch_open else 0.0)

func on_immobile(reason: String) -> void:
 immobile=true
 if reason.contains("двигун"):engine_dead=true
 if not scripted:say(reason.left(1).to_upper()+reason.substr(1)+": машина знерухомлена",4)

func on_fire() -> void:
 salvo_left=0
 if not scripted:say("ПОЖЕЖА В МАШИНІ! Покинути машину!",6)

# A jet or a fire in the package: the rockets go off one after another —
# some leave their tubes and fly off anywhere — and then the package goes
# up all at once.
func cook_off_rockets() -> void:
 if cooking or not has_rockets():return
 cooking=true;cook_clock=0.4

func cook(delta: float) -> void:
 if destroyed:cooking=false;return
 cook_clock-=delta
 if cook_clock>0.0:return
 cook_clock=rng.randf_range(0.4,1.6)
 var tube:=next_tube()
 if tube<0:return
 loaded[tube]=false
 art.caps.set_instance_transform(tube,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3.ZERO))
 var cradle: Node3D=art.cradle
 var axis:=TosArt.tube_axis(tube)
 var spot:=cradle.to_global(Vector3(axis.x,axis.y,-1.8))
 if rng.randf()<0.35:
  # The motor lit: the rocket leaves the tube on its own.
  var direction:=(launch_direction()+Vector3(rng.randf_range(-0.3,0.3),rng.randf_range(0.0,0.4),rng.randf_range(-0.3,0.3))).normalized()
  var shot:=TosBallistics.state(cradle.to_global(Vector3(axis.x,axis.y,TosArt.TUBE_REAR)),0,0,rng.randf_range(0.6,1.0))
  shot.launch=direction
  game.blasts.launch_tos(shot,self)
  TosEffects.launch(game,cradle.to_global(Vector3(axis.x,axis.y,TosArt.TUBE_REAR-TosArt.TUBE_LENGTH)),cradle.to_global(Vector3(axis.x,axis.y,TosArt.TUBE_REAR)),direction)
 else:
  var flash:=BlastEffect.new();game.world_root.add_child(flash);flash.setup(game,spot,0.8)
  game.spatial_shot("mine_blast",spot,2)
  GradEffects.shared(game).puff(spot,2.0,0.25,Vector3(0.3,1.6,0))

func on_destroyed(blast: bool) -> void:
 destroyed=true;immobile=true;cooking=false;salvo_left=0;engine_on=false;running=false
 route=PackedVector3Array()
 var left:=remaining()
 for i in range(loaded.size()):
  if loaded[i]:art.caps.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3.ZERO))
  loaded[i]=false
 # The rockets left in the package go up together: each about 90 kg of
 # thermobaric mixture.
 if blast and left>0:
  var package:=(art.cradle as Node3D).to_global(Vector3(0,0.5,-1.8))
  game.blasts.detonate(package,"cookoff_tos")
  if left>12:game.blasts.detonate(package+global_basis.z*1.5,"cookoff_tos")
 burnt()

func burnt() -> void:
 if GradVehicle.burnt_material==null:
  GradVehicle.burnt_material=StandardMaterial3D.new()
  GradVehicle.burnt_material.vertex_color_use_as_albedo=true
  GradVehicle.burnt_material.albedo_color=Color(0.22,0.20,0.19)
  GradVehicle.burnt_material.roughness=0.95
 for item in art.root.find_children("*","MeshInstance3D",true,false):
  if item.name=="Flames":continue
  (item as MeshInstance3D).material_override=GradVehicle.burnt_material
 var caps: MultiMeshInstance3D=(art.cradle as Node3D).get_node("Caps")
 caps.visible=false
