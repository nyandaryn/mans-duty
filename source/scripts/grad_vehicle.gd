class_name GradVehicle
extends VehicleBody3D

# BM-21 «Grad» on the Ural-375D. Chassis: ZIL-375 V8, 180 hp at 3200 rpm,
# 465 N·m; gearbox 6.17/3.40/1.79/1.00/0.78, reverse 6.69; transfer case
# 1.30/2.15; final drive 8.91; 14.00-20 tyres with central inflation;
# 13.7 t loaded, up to 75 km/h, turning radius 10.5 m.
# Launcher: package of 40 tubes, traverse 102° left / 70° right of the axis
# (electric stops at 99°30′ / 67°30′), elevation 0–55° (electric stop
# 53°30′); within 34° of the cab the package is not fired below 11°. The
# electric drive (generator on the power take-off) lays at up to 7°/s in
# traverse and 5°/s in elevation; by hand 6′ per turn in traverse and 4′ per
# turn in elevation. Pulses 0.45–0.55 s apart: a full salvo takes 20 s.
const MASS := 13700.0
const IDLE_RPM := 600.0
const MAX_RPM := 3200.0
const STALL_RPM := 280.0
const GEARS := [-6.69,0.0,6.17,3.40,1.79,1.00,0.78]
const GEAR_NAMES := ["З","N","1","2","3","4","5"]
const NEUTRAL := 1
const TRANSFER := [1.30,2.15]
const FINAL := 8.91
const EFFICIENCY := 0.85
const ENGINE_INERTIA := 1.4
const CLUTCH_CAPACITY := 900.0
const TORQUE := [[0.0,0.0],[500.0,300.0],[1000.0,410.0],[1500.0,455.0],[1900.0,465.0],[2500.0,445.0],[3200.0,400.0],[3600.0,250.0]]
const MAX_STEER := 0.42
const STEER_TURNS := 1.8
const TRAVERSE_LEFT := -102.0
const TRAVERSE_RIGHT := 70.0
const ELECTRIC_LEFT := -99.5
const ELECTRIC_RIGHT := 67.5
const ELEVATION_TOP := 55.0
const ELECTRIC_TOP := 53.5
const CAB_ZONE := 34.0
const CAB_ELEVATION := 11.0
const TRAVERSE_RATE := 7.0
const ELEVATION_RATE := 5.0
const MANUAL_TRAVERSE := 0.1*2.0
const MANUAL_ELEVATION := 4.0/60.0*2.0
const PULSE := 0.5
const TYRE_FULL := 3.2
# Correction of the boussole (declination east about 8.4°, grid convergence
# -0.9° in zone 7): grid bearing = magnetic bearing + 1-55.
const BOUSSOLE_CORRECTION := 155.0

var game: Node3D
var art: Dictionary
var wheel_nodes: Array[VehicleWheel3D]=[]
var engine_sound: AudioStreamPlayer3D
var catching := 0.0
# Parked on the hand brake the body is held still (a raycast suspension
# creeps otherwise). The rocking under the launches is drawn, not simulated:
# springs on the body (pitch, yaw, roll and a bounce), a short shudder of the
# cab, and the package swinging on its trunnions and turntable.
var parked_time := 0.0
var rock := Vector3.ZERO
var rock_rate := Vector3.ZERO
var bounce := 0.0
var bounce_rate := 0.0
var shudder := Vector3.ZERO
var shudder_rate := Vector3.ZERO
var package_rock := Vector2.ZERO
var package_rate := Vector2.ZERO
var mirrors: Array[GradMirror]=[]
# The receiver on the dashboard; runs on the ignition and plays the tracks
# in turn.
const RADIO_TRACKS := [["res://assets/audio/radio/zalizna_zgraya.mp3","Залізна зграя"]]
var radio_on := false
var radio_track := 0
var radio_player: AudioStreamPlayer3D
var launch_players: Array[AudioStreamPlayer3D]=[]
var launch_index := 0
var seat_camera: Camera3D
var dashboard: GradDashboard
# Engine and transmission.
var ignition := false
var running := false
var omega := 0.0
var starter := false
var crank_left := 0.0
var throttle := 0.0
var hand_throttle := 0.0
var clutch_pedal := 0.0
var brake_pedal := 0.0
var steer := 0.0
var gear := NEUTRAL
var low_range := false
var handbrake := true
var power_takeoff := false
var drive_force := 0.0
var grind := 0.0
var notice := ""
var notice_left := 0.0
# Pneumatics: brake booster, rear spring lockout, central tyre inflation.
var air := 5.4
var tyre := TYRE_FULL
var inflation := 0
var springs_locked := false
# Launcher.
var azimuth := 0.0
var elevation := 0.0
var traverse_input := 0.0
var elevation_input := 0.0
var traverse_hold := 0.0
var elevation_hold := 0.0
var manual_drive := false
var travel_lock := true
var cover_on := true
var bracket_up := false
var shields_down := false
var shield_angle := 0.0
var battery_on := false
var lamp_test := 0.0
var fire_mode := 0
var program_wound := false
var single_armed := false
var lever := false
var lever_was := false
var fire_clock := 0.0
var order_step := 0
var order: PackedInt32Array
var loaded: Array[bool]=[]
var fired := 0
# Settings the last rocket left with: the observer's report corrects them.
var last_launch: Dictionary={}
var last_launch_time := -100.0
var salvo_rockets := 0
# Sight D726-45 with the PG-1M panorama.
var deflection := 3000.0
var sight_setting := 0.0
var level_setting := 3000.0
var boussole := false
var needle := 0.0
var head_pitch := 0.0
var damaged := false
var off_road := 1.0
var clock := 0.0
# Where the player sits: "", "driver", "commander" or "gunner".
var seat := ""
var steer_input := 0.0

func setup(owner_game: Node3D) -> void:
 game=owner_game
 name="GradVehicle"
 mass=MASS
 center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
 center_of_mass=Vector3(0,1.25,0.35)
 collision_layer=1
 collision_mask=1|64
 set_meta("ballistic_material","steel")
 art=GradArt.build()
 add_child(art.root)
 dashboard=GradDashboard.new();dashboard.setup(self)
 for i in range(GradArt.MIRRORS.size()):
  var mirror:=GradMirror.new();mirror.setup(self,GradArt.MIRRORS[i],i);mirrors.append(mirror)
 radio_player=AudioStreamPlayer3D.new();radio_player.name="Radio";radio_player.position=GradArt.RADIO
 radio_player.unit_size=1.6;radio_player.max_distance=30.0;radio_player.bus=game.hearing.bus_name
 radio_player.finished.connect(next_track);add_child(radio_player)
 for shape_data in [[Vector3(1.20,0.90,1.45),Vector3(0,1.57,-2.85)],[Vector3(2.30,1.45,1.55),Vector3(0,1.95,-1.40)],[Vector3(2.30,0.55,3.90),Vector3(0,1.15,1.35)],[Vector3(1.70,0.70,2.40),Vector3(0,2.30,1.25)]]:
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=shape_data[0]
  shape.shape=box;shape.position=shape_data[1];add_child(shape)
 var wheel_mesh:=GradArt.wheel_mesh()
 for z in [GradArt.FRONT_AXLE]+GradArt.REAR_AXLES:
  for x in [-GradArt.TRACK,GradArt.TRACK]:
   var wheel:=VehicleWheel3D.new()
   wheel.position=Vector3(x,GradArt.WHEEL_RADIUS+0.30-0.08,z)
   wheel.wheel_radius=GradArt.WHEEL_RADIUS;wheel.wheel_rest_length=0.30;wheel.suspension_travel=0.28
   wheel.suspension_stiffness=36.0;wheel.suspension_max_force=95000.0
   wheel.damping_compression=1.8;wheel.damping_relaxation=2.4
   wheel.wheel_friction_slip=1.1;wheel.wheel_roll_influence=0.35
   wheel.use_as_traction=true;wheel.use_as_steering=z==GradArt.FRONT_AXLE
   var tyre_mesh:=MeshInstance3D.new();tyre_mesh.mesh=wheel_mesh;wheel.add_child(tyre_mesh)
   add_child(wheel);wheel_nodes.append(wheel)
 seat_camera=Camera3D.new();seat_camera.name="SeatCamera";seat_camera.near=0.05;seat_camera.far=6000;seat_camera.fov=75
 seat_camera.cull_mask=1|OperatorBody.WORLD_BODY_LAYER
 add_child(seat_camera)
 engine_sound=AudioStreamPlayer3D.new();engine_sound.stream=GradAudio.engine();engine_sound.unit_size=9;engine_sound.max_distance=400
 engine_sound.position=Vector3(0,1.5,-2.8);engine_sound.bus=game.hearing.bus_name;add_child(engine_sound)
 for i in range(8):
  var output:=AudioStreamPlayer3D.new();output.unit_size=40;output.max_distance=6000
  output.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
  output.position=GradArt.TURNTABLE+Vector3(0,0.6,0.8);add_child(output);output.bus=game.hearing.bus_name
  launch_players.append(output)
 order=GradArt.firing_order()
 loaded.resize(40);loaded.fill(true)
 apply_launcher()
 apply_shields(true)

func say(text: String, seconds: float=4.0) -> void:
 notice=text;notice_left=seconds

func speed() -> float:return linear_velocity.dot(-global_basis.z)

func rpm() -> float:return omega*60.0/TAU

func gear_ratio() -> float:return float(GEARS[gear])*float(TRANSFER[1 if low_range else 0])*FINAL

func engine_torque(r: float) -> float:
 for i in range(TORQUE.size()-1):
  if r<=TORQUE[i+1][0]:return lerpf(TORQUE[i][1],TORQUE[i+1][1],(r-TORQUE[i][0])/(TORQUE[i+1][0]-TORQUE[i][0]))
 return 0.0

func clutch_engagement() -> float:return clampf((0.75-clutch_pedal)/0.5,0.0,1.0)

func stationary() -> bool:return absf(speed())<0.4

# --- Driver's controls ----------------------------------------------------
func toggle_ignition() -> void:
 ignition=not ignition
 if not ignition and radio_on:set_radio(false)
 if not ignition and running:running=false;say("Запалювання вимкнено · двигун зупинено")
 else:say("Запалювання %s" % ("увімкнено" if ignition else "вимкнено"),2)
 game.sound("click",-14)

func toggle_radio() -> void:
 game.sound("click",-14)
 if not radio_on and not ignition:say("Приймач без живлення: увімкни запалювання (I)",2.5);return
 set_radio(not radio_on)
 say("Приймач: «%s»" % RADIO_TRACKS[radio_track][1] if radio_on else "Приймач вимкнено",2.5)

func set_radio(on: bool) -> void:
 radio_on=on
 var lamp: StandardMaterial3D=art.radio_display.mesh.material
 lamp.emission_energy_multiplier=0.45 if on else 0.0
 if on:play_track()
 else:radio_player.stop()

func play_track() -> void:
 radio_player.stream=load(RADIO_TRACKS[radio_track][0])
 radio_player.volume_db=radio_volume()
 radio_player.play()

func next_track() -> void:
 if not radio_on:return
 radio_track=(radio_track+1)%RADIO_TRACKS.size()
 play_track()

func radio_volume() -> float:return linear_to_db(maxf(game.volume,0.0001))-3.0

func update_radio() -> void:
 if not radio_on or game==null:return
 radio_player.stream_paused=game.paused
 radio_player.volume_db=radio_volume()

func shift(step: int) -> void:
 if clutch_engagement()>0.15:
  grind=0.4;say("Скрегіт шестерень: вижми зчеплення (Shift)",2.5);return
 var next:=clampi(gear+step,0,GEARS.size()-1)
 if next==0 and speed()>0.8:say("Задню — лише після повної зупинки",2.5);return
 if gear==0 and step>0 and speed()<-0.8:say("Спершу зупинись",2);return
 gear=next;game.sound("click",-18)
 # The lever is felt, not seen: the gear is named on the screen for a moment.
 say("Передача %s" % GEAR_NAMES[gear],1.5)

func toggle_range() -> void:
 if not stationary() or clutch_engagement()>0.15:say("Роздавальну коробку перемикають на місці з вижатим зчепленням",3);return
 low_range=not low_range;say("Роздавальна коробка: %s передача" % ("знижена" if low_range else "пряма"),2.5);game.sound("click",-16)

func toggle_handbrake() -> void:
 handbrake=not handbrake;say("Стоянкове гальмо %s" % ("ЗАТЯГНУТО" if handbrake else "відпущено"),2);game.sound("click",-12)

func toggle_power_takeoff() -> void:
 if not power_takeoff and (gear!=NEUTRAL or clutch_engagement()>0.15 or not stationary()):
  say("КВП вмикають на місці: нейтраль і вижате зчеплення",3);return
 power_takeoff=not power_takeoff;say("Коробку відбору потужності %s" % ("УВІМКНЕНО · генератор приводу наведення" if power_takeoff else "вимкнено"),3);game.sound("click",-14)

func cycle_inflation() -> void:
 inflation=1 if inflation==0 else (-1 if inflation==1 else 0)
 say("Кран тиску в шинах: %s" % ["СПУСК","ЗАКРИТО","НАКАЧКА"][inflation+1],2.5);game.sound("click",-16)

func toggle_shields() -> void:
 shields_down=not shields_down;say("Броньовані щитки %s" % ("ОПУЩЕНО на вітрове скло" if shields_down else "підняті"),2.5)

# --- Launcher: travel ↔ action ------------------------------------------
func toggle_springs() -> bool:
 if air<1.5:say("Мало повітря в системі: кран не спрацює",3);return false
 springs_locked=not springs_locked;air=maxf(0,air-0.35)
 for i in range(2,6):
  var wheel:=wheel_nodes[i]
  wheel.suspension_stiffness=200.0 if springs_locked else 36.0
  wheel.damping_compression=6.0 if springs_locked else 1.8
  wheel.damping_relaxation=7.0 if springs_locked else 2.4
 game.sound("click",-8)
 say("Кран «БОЙОВЕ / ПОХІД»: %s" % ("БОЙОВЕ — ресори задніх мостів вимкнено" if springs_locked else "ПОХІД — ресори працюють"),3)
 return true

func toggle_lock() -> bool:
 if travel_lock:travel_lock=false;say("Пакет розстопорено",2.5);return true
 if absf(azimuth)>0.6 or elevation>0.6:say("Застопорити можна лише в похідному положенні: напрямок 0°, кут 0°",3);return false
 azimuth=0;elevation=0;travel_lock=true;apply_launcher();say("Пакет застопорено по-похідному",2.5);return true

func set_cover(on: bool) -> void:
 cover_on=on;art.cover.visible=on

func set_bracket(up: bool) -> void:
 bracket_up=up;apply_launcher()

# --- Fire-control panel -----------------------------------------------------
func toggle_battery() -> void:
 battery_on=not battery_on;if not battery_on:lamp_test=0;fire_mode=0
 game.sound("click",-10)

func test_lamp() -> void:
 if battery_on:lamp_test=1.5
 game.sound("click",-16)

func set_mode(value: int) -> void:
 fire_mode=value;single_armed=false;game.sound("click",-12)

func wind_program() -> void:
 if not battery_on:say("Пульт знеструмлено: ВБ-55",2);return
 program_wound=true;single_armed=false;game.sound("click",-8)
 say("Програмний механізм зведено · труба %d" % next_tube_number(),2.5)

func next_tube() -> int:
 for k in range(order.size()):
  var index:=order[(order_step+k)%order.size()]
  if loaded[index]:return index
 return -1

func next_tube_number() -> int:
 var index:=next_tube()
 return index+1 if index>=0 else 0

func remaining() -> int:
 var count:=0
 for item in loaded:if item:count+=1
 return count

func in_cab_zone() -> bool:return absf(azimuth)<CAB_ZONE and elevation<CAB_ELEVATION

func circuit_ready() -> bool:
 return battery_on and fire_mode>0 and program_wound and remaining()>0 and not in_cab_zone() and not travel_lock

func set_lever(held: bool) -> void:
 lever=held

# --- Laying ---------------------------------------------------------------
func drive_power() -> float:
 if not power_takeoff or not running:return 0.0
 return clampf((rpm()-650.0)/850.0,0.0,1.0)

func apply_launcher() -> void:
 art.turret.rotation.y=-deg_to_rad(azimuth)+package_rock.y
 art.cradle.rotation.x=deg_to_rad(elevation)+package_rock.x
 art.bracket.rotation.x=0.0 if bracket_up else -PI/2

func apply_shields(instant: bool=false) -> void:
 var target:=0.0 if shields_down else PI/2
 shield_angle=target if instant else move_toward(shield_angle,target,get_physics_process_delta_time()*1.4)
 for hinge in art.shields:hinge.rotation.x=shield_angle

func lay(delta: float) -> void:
 if travel_lock:traverse_input=0;elevation_input=0
 traverse_hold=traverse_hold+delta if traverse_input!=0 else 0.0
 elevation_hold=elevation_hold+delta if elevation_input!=0 else 0.0
 var power:=drive_power()
 if manual_drive or power<=0.0:
  azimuth+=traverse_input*MANUAL_TRAVERSE*delta
  elevation+=elevation_input*MANUAL_ELEVATION*delta
  azimuth=clampf(azimuth,TRAVERSE_LEFT,TRAVERSE_RIGHT)
  elevation=clampf(elevation,0.0,ELEVATION_TOP)
 else:
  # A spring-centred handwheel: a slight turn crawls, a full turn races.
  var t_rate:=TRAVERSE_RATE*power*clampf(0.015+pow(traverse_hold/1.6,2),0,1)
  var e_rate:=ELEVATION_RATE*power*clampf(0.015+pow(elevation_hold/1.6,2),0,1)
  var next_az:=azimuth+traverse_input*t_rate*delta
  var next_el:=elevation+elevation_input*e_rate*delta
  azimuth=clampf(next_az,minf(azimuth,ELECTRIC_LEFT),maxf(azimuth,ELECTRIC_RIGHT))
  elevation=clampf(next_el,0.0,maxf(elevation,ELECTRIC_TOP))
 apply_launcher()

# Unit vector of the tube axes in the world as laid. The rocking of the body
# and of the package under a salvo is part of the round-to-round dispersion
# (GradBallistics), so it is left out here.
func laid_basis() -> Basis:
 return global_basis*Basis(Vector3.UP,-deg_to_rad(azimuth))*Basis(Vector3.RIGHT,deg_to_rad(elevation))

func launch_direction() -> Vector3:
 return (laid_basis()*Vector3.FORWARD).normalized()

func absolute_elevation_mils() -> float:
 return GradBallistics.mils(asin(clampf(launch_direction().y,-1,1)))

func package_bearing() -> float:
 var d:=launch_direction();d.y=0
 return GradBallistics.bearing(d.normalized() if d.length()>0.01 else -global_basis.z)

# The panorama looks along the package at 30-00; the reading falls as the
# head turns clockwise.
func sight_bearing() -> float:
 return fposmod(package_bearing()+3000.0-deflection,6000.0)

func bubble_mils() -> float:
 return absolute_elevation_mils()-(sight_setting+level_setting-3000.0)

func cant_degrees() -> float:
 var right:=global_basis*Basis(Vector3.UP,-deg_to_rad(azimuth))*Vector3.RIGHT
 return rad_to_deg(asin(clampf(right.y,-1,1)))

func panorama_transform() -> Transform3D:
 var origin:Vector3=art.panorama.global_position
 var yaw:=-GradBallistics.radians(sight_bearing())
 var basis:=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,deg_to_rad(head_pitch))
 return Transform3D(basis,origin)

# --- Simulation -----------------------------------------------------------
func _physics_process(delta: float) -> void:
 update_radio()
 if game==null or not game.running or game.paused:return
 clock+=delta
 if notice_left>0:notice_left-=delta
 if lamp_test>0:lamp_test-=delta
 grind=maxf(0,grind-delta)
 simulate_engine(delta)
 simulate_air(delta)
 drive(delta)
 hold_parked(delta)
 update_rock(delta)
 lay(delta)
 apply_shields()
 fire(delta)
 if is_instance_valid(game.district.operation_area):game.district.operation_area.collide_trees(global_position)

func simulate_engine(delta: float) -> void:
 if starter and ignition and not running:
  crank_left-=delta
 var r:=rpm()
 var open:=0.0
 if running:
  open=maxf(throttle,hand_throttle)
  # Idle jet and the governor of the ZIL-375.
  open=maxf(open,clampf((IDLE_RPM+60.0-r)/350.0,0.0,0.35))
  # Choke and accelerator pump: a freshly caught engine runs up to idle.
  if catching>0.0:open=maxf(open,0.6 if r<IDLE_RPM else 0.0)
  if r>MAX_RPM:open*=clampf((MAX_RPM+200.0-r)/200.0,0.0,1.0)
 var torque:=engine_torque(r)*open if running else 0.0
 torque-=(18.0+r*0.024) if omega>0.5 else 0.0
 if starter and ignition and not running:torque+=130.0 if r<220.0 else 0.0
 # Load of the generator on the power take-off.
 if power_takeoff and running:torque-=12.0+absf(traverse_input)*20.0+absf(elevation_input)*20.0
 var ratio:=gear_ratio()
 var engagement:=clutch_engagement() if ratio!=0.0 else 0.0
 var wheel_omega:=speed()/GradArt.WHEEL_RADIUS
 var transmitted:=0.0
 if engagement>0.0:
  var shaft:=wheel_omega*ratio
  var needed:=torque+ENGINE_INERTIA*(omega-shaft)/delta
  var capacity:=CLUTCH_CAPACITY*engagement
  if absf(needed)<=capacity:
   transmitted=needed;omega=shaft
  else:
   transmitted=capacity*signf(needed)
   omega+=(torque-transmitted)/ENGINE_INERTIA*delta
 else:
  omega+=torque/ENGINE_INERTIA*delta
 omega=maxf(omega,0.0)
 drive_force=transmitted*ratio*EFFICIENCY/GradArt.WHEEL_RADIUS
 if catching>0.0:catching-=delta
 if starter and ignition and not running and rpm()>200.0 and crank_left<=0.0:
  running=true;catching=1.5;say("Двигун запущено",2)
 if running and ((rpm()<STALL_RPM and catching<=0.0) or not ignition):
  running=false
  if ignition:say("Двигун заглух",3)
 # The engine sound follows the crankshaft.
 if (running or (starter and ignition)) and not engine_sound.playing:engine_sound.play()
 elif not running and not starter and engine_sound.playing and rpm()<80:engine_sound.stop()
 engine_sound.pitch_scale=clampf(maxf(rpm(),180.0)/700.0,0.35,3.6)
 engine_sound.volume_db=linear_to_db(maxf(game.volume,0.0001))+lerpf(-8.0,2.0,clampf(open,0,1))-(10.0 if not running else 0.0)

func begin_crank() -> void:
 if starter:return
 starter=true
 crank_left=randf_range(0.5,1.3)
 if not ignition:say("Спершу запалювання (I)",2)

func simulate_air(delta: float) -> void:
 if running:air=minf(7.3,air+0.03*rpm()/1000.0*delta)
 if inflation!=0 and running:
  if inflation>0 and air>4.5:
   tyre=minf(TYRE_FULL,tyre+0.035*delta);air-=0.02*delta
  elif inflation<0:tyre=maxf(0.5,tyre-0.06*delta)
 if inflation>0 and tyre>=TYRE_FULL-0.001:inflation=0;say("Тиск у шинах %.1f кгс/см² · кран закрито" % tyre,3)

func drive(delta: float) -> void:
 var v:=speed()
 # Steering: power-assisted while the engine runs.
 var rate:=1.6 if running else 0.5
 var input:=steer_input if seat=="driver" else 0.0
 if input!=0.0:steer=clampf(steer+input*rate*delta,-1,1)
 else:steer=move_toward(steer,0,delta*clampf(absf(v)*0.06,0,0.8))
 steering=-steer*MAX_STEER
 show_steering()
 var air_factor:=clampf((air-0.8)/4.0,0.15,1.0)
 var braking:=brake_pedal*235.0*air_factor
 var parking:=220.0 if handbrake else 0.0
 # Off the road the soft ground resists more and grips less.
 var ground:=1.0
 if is_instance_valid(game.district.operation_area):
  ground=0.75 if not on_road() else 1.0
 off_road=ground
 var grip:=(1.15 if ground>=1.0 else 0.95)*(1.0+(TYRE_FULL-tyre)*0.06)
 # VehicleBody3D drives along its +Z; the cab of this one faces −Z.
 for wheel in wheel_nodes:
  wheel.engine_force=-drive_force/6.0
  wheel.brake=maxf(braking,parking)
  wheel.wheel_friction_slip=grip
 var rolling:=(0.022 if ground>=1.0 else 0.06)*(1.0+(TYRE_FULL-tyre)*0.12)*MASS*9.81
 var drag:=0.5*1.2*5.9*v*v
 if absf(v)>0.05:apply_central_force(-global_basis.z*signf(v)*(rolling+drag))
 # Parked on locked brakes the tyres do not let the body creep round under
 # the launch blasts.
 if handbrake and absf(v)<0.6:
  apply_torque(Vector3.UP*(-angular_velocity.y*MASS*30.0))
  var lateral:=linear_velocity.dot(global_basis.x)
  apply_central_force(-global_basis.x*lateral*MASS*4.0)

func hold_parked(delta: float) -> void:
 if freeze:
  if not handbrake:release_parking()
  return
 if handbrake and linear_velocity.length()<0.15 and angular_velocity.length()<0.06:parked_time+=delta
 else:parked_time=0.0
 if parked_time>0.8:
  freeze_mode=RigidBody3D.FREEZE_MODE_STATIC
  freeze=true
  linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO

func release_parking() -> void:
 freeze=false;parked_time=0.0

func is_parked() -> bool:return freeze

# The wheel turns about its column: clockwise, as the driver sees it, to
# the right.
func show_steering() -> void:
 art.steering.rotation.y=-steer*STEER_TURNS*TAU*0.25

func kick(rate: Vector3) -> void:rock_rate+=rate

# One launch: the rocket drags the package after it along the tubes and the
# package springs back as it leaves, so the vehicle pitches and rolls toward
# the line of fire and back, bounces on its tyres and the cab shudders.
# Rockets go alternately from the left and the right half of the package,
# so the roll swings from side to side through the salvo.
func launch_kick(index: int, direction: Vector3) -> void:
 var local:=global_basis.inverse()*direction
 var side:=signf(GradArt.tube_axis(index).x)
 kick(Vector3(local.z*0.16+randf_range(-0.04,0.04),side*0.04+randf_range(-0.015,0.015),-local.x*0.21+side*0.08+randf_range(-0.04,0.04)))
 bounce_rate-=randf_range(0.09,0.15)
 shudder_rate+=Vector3(randf_range(-1,1),randf_range(-0.4,0.4),randf_range(-1,1))*0.5
 package_rate+=Vector2(randf_range(0.14,0.22),side*randf_range(0.07,0.12))

static func spring(value, rate, w: float, z: float, delta: float) -> Array:
 rate+=(-value*w*w-rate*2.0*z*w)*delta
 return [value+rate*delta,rate]

func update_rock(delta: float) -> void:
 # About 2 Hz on the tyres with the rear springs locked out, lightly damped,
 # so the body keeps swaying through the salvo; softer on the springs.
 var w:=TAU*(2.2 if springs_locked else 1.4)
 var z:=0.10 if springs_locked else 0.07
 var step:=spring(rock,rock_rate,w,z,delta);rock=step[0];rock_rate=step[1]
 step=spring(bounce,bounce_rate,w*1.3,z*1.4,delta);bounce=step[0];bounce_rate=step[1]
 step=spring(shudder,shudder_rate,TAU*9.0,0.22,delta);shudder=step[0];shudder_rate=step[1]
 step=spring(package_rock,package_rate,TAU*3.2,0.07,delta);package_rock=step[0];package_rate=step[1]
 if rock.length()<0.00001 and rock_rate.length()<0.0001:rock=Vector3.ZERO;rock_rate=Vector3.ZERO
 if absf(bounce)<0.00001 and absf(bounce_rate)<0.0001:bounce=0.0;bounce_rate=0.0
 if shudder.length()<0.00001 and shudder_rate.length()<0.0001:shudder=Vector3.ZERO;shudder_rate=Vector3.ZERO
 if package_rock.length()<0.00001 and package_rate.length()<0.0001:package_rock=Vector2.ZERO;package_rate=Vector2.ZERO
 art.root.transform=Transform3D(Basis.from_euler(rock+shudder),Vector3(0,bounce,0))

var road_check := 0.0
var road_cached := true
func on_road() -> bool:
 road_check-=get_physics_process_delta_time()
 if road_check>0:return road_cached
 road_check=0.5
 var c: Color=game.district.terrain.surface_color(Vector2(global_position.x,global_position.z)) if absf(global_position.x)<200 and absf(global_position.z)<200 else AvdiivkaData.shared().cover_at(global_position.x,global_position.z)
 road_cached=c.v<0.42 and c.s<0.25
 return road_cached


# --- Firing -----------------------------------------------------------------
func fire(delta: float) -> void:
 var pressed:=lever and not lever_was
 lever_was=lever
 if fire_clock>0:fire_clock-=delta
 if not lever or not battery_on or fire_mode==0:return
 if not program_wound:
  if pressed:say("Програмний механізм не зведено",2)
  return
 if in_cab_zone():
  if pressed:say("БЛОКУВАННЯ: пакет у зоні кабіни нижче 11°",3)
  return
 if travel_lock:
  if pressed:say("Пакет застопорено по-похідному",2)
  return
 if fire_mode==2:
  if not pressed:return
  # In single fire the first actuation steps the distributor onto the
  # first tube; every next one launches a rocket.
  if not single_armed:single_armed=true;game.sound("click",-8);return
  launch_next()
  return
 if fire_clock<=0:
  if launch_next():fire_clock=randf_range(0.45,0.55)

func launch_next() -> bool:
 var index:=next_tube()
 if index<0:
  say("Пакет порожній",3);lever=false;return false
 order_step=(order.find(index)+1)%order.size()
 loaded[index]=false;fired+=1
 last_launch={"sight":sight_setting,"deflection":deflection,"level":level_setting}
 art.rockets.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3.ZERO))
 var cradle:Node3D=art.cradle
 var axis:=GradArt.tube_axis(index)
 var rear:=cradle.to_global(Vector3(axis.x,axis.y,GradArt.TUBE_REAR))
 var front:=cradle.to_global(Vector3(axis.x,axis.y,GradArt.TUBE_REAR-GradArt.TUBE_LENGTH))
 var direction:=launch_direction()
 # Round-to-round dispersion: tip-off, thrust and the motion of the package.
 var right:=direction.cross(Vector3.UP).normalized()
 direction=direction.rotated(Vector3.UP,randfn(0,GradBallistics.DIRECTION_SPREAD)).rotated(right,randfn(0,GradBallistics.ELEVATION_SPREAD)).normalized()
 var shot:=GradBallistics.state(rear,0,0,0,1.0+randfn(0,GradBallistics.IMPULSE_SPREAD))
 shot.launch=direction
 shot.velocity=Vector3.ZERO
 game.blasts.launch_grad(shot,self)
 # The tubes are open behind, so the jet hardly pushes the launcher; the
 # rail friction, the spin-up in the helical groove and the blast on the
 # ground rock it.
 launch_kick(index,direction)
 if not freeze:
  apply_impulse(-direction*220.0,rear-global_position)
  apply_torque_impulse(direction*randf_range(8.0,14.0)+Vector3(randf_range(-1,1),0,randf_range(-1,1))*90.0)
 GradEffects.launch(game,front,rear,direction)
 play_launch(rear,remaining()==0 or fire_mode==2)
 last_launch_time=clock
 if cover_on:
  set_cover(false);say("ЧОХОЛ ПРОГОРІВ: пуск із зачохленим пакетом",4)
  GradEffects.burn(game,cradle.to_global(Vector3(0,0.4,-1.0)))
 exhaust_danger(rear,direction)
 if remaining()==0:say("Залп завершено: пакет порожній",4);lever=false
 return true

# Recorded launches: the close one for each rocket, the long rolling tail
# after the last of a series.
func play_launch(at: Vector3, last: bool) -> void:
 var output:=launch_players[launch_index];launch_index=(launch_index+1)%launch_players.size()
 output.stream=GradAudio.clip("launch_tail" if last else "launch_close")
 output.volume_db=linear_to_db(maxf(game.volume,0.0001))+2.0
 output.pitch_scale=randf_range(0.96,1.04)
 output.play()
 if is_instance_valid(game.player):
  game.hearing.shot(game.player.camera.global_position.distance_to(at)*0.5)

# The jet behind the package burns and throws anyone standing there.
func exhaust_danger(rear: Vector3, direction: Vector3) -> void:
 for actor in [game.player]+game.allies+game.bots:
  if not is_instance_valid(actor) or (actor is Hostile and actor.dead):continue
  if actor is Operator and seat!="":continue
  var offset:Vector3=actor.global_position+Vector3.UP-rear
  var behind:=-offset.dot(direction)
  if behind<0.0 or behind>22.0:continue
  var side:=(offset+direction*behind).length()
  if side>2.0+behind*0.45:continue
  var intensity:=clampf(1.0-behind/22.0,0,1)
  actor.receive_blast(160.0*intensity,clampf(intensity*1.4,0,1),direction*-1.0)
