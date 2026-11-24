class_name TosVehicle
extends RigidBody3D

# BM-1 of the TOS-1A «Солнцепёк» (TosArt): the T-72A hull, the platform on
# the turret ring traversing ±100°, the package elevating 0…60°, two jacks
# at the rear corners lowered for firing, 24 MO.1.01.04M fired in pairs
# 0.5 s apart (a full package in 6 s) or one at a time (12 s). From the
# stop to the first rocket it takes 90 s (the maker's figure).
#
# This vehicle is moved by its owner along a route over the ground (no
# track physics yet: like the defenders' BMPs it is driven by a script);
# the owner lays and fires it (EnemyTos). It is armoured as a T-72A
# (VehicleArmor.t72_tos) and its package of thermobaric rockets goes up
# when a jet or a fire gets into it.
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
var game: Node3D
var art: Dictionary
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
var speed := 0.0
var cruise := FIELD_SPEED
var travelled := 0.0
var salvo_left := 0
var salvo_clock := 0.0
var pairs := true
var cooking := false
var cook_clock := 0.0
var destroyed := false
var immobile := false
var clock := 0.0
var last_launch := -100.0
var far_heard := -100.0
var cloud: CPUParticles3D
var engine_sound: AudioStreamPlayer3D
var launch_players: Array[AudioStreamPlayer3D]=[]
var launch_index := 0
var engine_on := false
var shake := Vector3.ZERO
var shake_rate := Vector3.ZERO
var package_shape: CollisionShape3D
var platform_shape: CollisionShape3D

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

# Laid where it was told: the jacks down, the platform and the package
# still, the sight unbroken.
func laid() -> bool:
 return jacks>=1.0 and absf(platform_yaw-want_yaw)<0.05 and absf(elevation-want_elevation)<0.05

func ground(point: Vector3) -> Vector3:
 if game.selected_map==BattleMap.ID:return Vector3(point.x,AvdiivkaData.shared().height(point.x,point.z),point.z)
 return Vector3(point.x,game.district.ground_height(point),point.z)

# --- Orders from the owner ----------------------------------------------------
func drive(points: PackedVector3Array, road: bool=false) -> void:
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
  speed=move_toward(speed,0.0,delta*4.0)
  if speed<=0.0:return
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
 speed=move_toward(speed,target_speed,delta*(1.6 if speed<target_speed else 4.0))
 heading=heading.rotated(Vector3.UP,turn)
 var next:=global_position+heading*speed*delta
 travelled+=speed*delta
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
 var stopped:=speed<0.05
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
 engine_sound.pitch_scale=0.72+speed/ROAD_SPEED*0.25
 engine_sound.volume_db=linear_to_db(maxf(game.volume,0.0001))+lerpf(-4.0,3.0,clampf(speed/ROAD_SPEED,0,1))

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
 var turn:=travelled/TosArt.WHEEL_RADIUS
 for wheel in art.wheels:(wheel as Node3D).rotation.x=-turn
 for hub in art.drive:(hub as Node3D).rotation.x=-travelled/TosArt.SPROCKET_RADIUS
 if is_instance_valid(platform_shape):
  platform_shape.position=TosArt.RING+Basis(Vector3.UP,deg_to_rad(platform_yaw))*Vector3(0,0.25,0.12)
  platform_shape.rotation.y=deg_to_rad(platform_yaw)
 if is_instance_valid(package_shape):
  var centre:=cradle.global_transform*Vector3(0,TosArt.TUBE_BOTTOM+0.24,TosArt.TUBE_REAR-TosArt.TUBE_LENGTH*0.5)
  package_shape.global_transform=Transform3D(cradle.global_basis,centre)
 VehicleMarkings.flutter(self,art)

# --- Damage -------------------------------------------------------------------
func vehicle_hit(point: Vector3, direction: Vector3, round: String, pen_mm: float=-1.0) -> Dictionary:
 return hull.strike(point,direction,round,pen_mm)

func blast_hit(where: Vector3, kind: String) -> void:hull.blast(where,kind)

# The crew of the enemy's vehicle are not figures on the field.
func occupants() -> Array:return []

func forget_occupant(_actor: Node3D) -> void:pass

func on_immobile(_reason: String) -> void:
 immobile=true

func on_fire() -> void:
 salvo_left=0

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
 destroyed=true;immobile=true;cooking=false;salvo_left=0;engine_on=false
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
