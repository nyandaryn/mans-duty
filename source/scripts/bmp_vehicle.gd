class_name BmpVehicle
extends RigidBody3D

# BMP-2 after its technical manual (ТО и ИЭ): 14 t; UTD-20S1 six-cylinder
# diesel, 300 hp at 2600 rpm, 1030 N·m at 1500–1600 rpm, governed at 2600;
# a dry multi-plate main clutch on a pedal; five forward gears and a reverse,
# synchronizers on 2nd–5th only; final drives 5.5 and an effective sprocket
# radius of 0.313 m: 10.6 / 19.6 / 29.1 / 43.3 / 65 km/h at 2600 rpm.
# Steering by a yoke through two planetary steering mechanisms (ПМП): a small
# deflection slips the steering clutch, the first stage gives a fixed 7.06 m
# radius with the inner track at 1/1.44 of the outer, full deflection brakes
# the inner track and the hull pivots about it (1.275 m). There is no neutral
# turn on the spot. Tracks 300 mm wide, 2.55 m between their centres, 3.6 m
# on the ground; six road wheels a side on torsion bars.
const MASS := 14000.0
const IDLE_RPM := 750.0
const GOVERNED_RPM := 2600.0
const STALL_RPM := 380.0
const GEARS := [-5.25,0.0,5.25,2.842,1.912,1.284,0.858]
const GEAR_NAMES := ["З","N","1","2","3","4","5"]
const NEUTRAL := 1
const FINAL := 5.5
const SPROCKET := 0.313
const EFFICIENCY := 0.82
const ENGINE_INERTIA := 2.4
const CLUTCH_CAPACITY := 1450.0
const TORQUE := [[0.0,0.0],[400.0,430.0],[750.0,760.0],[1100.0,950.0],[1550.0,1030.0],[2000.0,975.0],[2600.0,810.0],[2750.0,250.0],[2850.0,0.0]]
# Speed ratio of the outer to the inner track in the first stage of the ПМП.
const STAGE := 1.44
const GAUGE := 2.55
const CONTACT := 3.6
const YAW_INERTIA := 64000.0
# Torsion bars: about 9 cm of static deflection under 1/12 of the weight.
const WHEEL_SPRING := 125000.0
const WHEEL_DAMPER := 11000.0
const RAY_TOP := 0.85
const FREE_LENGTH := 0.95
const TRAVEL := 0.32
# Troop compartment: seven seats; the driver and the gunner have their own.
const SEATS := 7
const RADIO_TRACKS := [["res://assets/audio/radio/radio_200.mp3","200"]]

var game: Node3D
var friendly := true
var art: Dictionary
var wheel_mounts: Array[Vector3]=[]
var compressions := PackedFloat32Array()
var loads := PackedFloat32Array()
var load_total := 0.0
var ray: PhysicsRayQueryParameters3D
var engine_sound: AudioStreamPlayer3D
var radio_player: AudioStreamPlayer3D
var seat_camera: Camera3D
var gunner: BmpGunner
var driver_ai: BmpDriver
var squad: Node
var callsign := ""
# Who is inside: the troops in the rear, and the crew (bots or the player).
var aboard: Array[Hostile]=[]
var crew: Array[Hostile]=[]
var seat := ""
# Controls, set by the driver: the player or the bot behind the yoke.
var master := false
var running := false
var omega := 0.0
var heard_rpm := 0.0
const RECORDED_RPM := 1190.0
var heard_open := 0.0
# Readings of the driver's panel (BmpCockpit) within the manual's normal
# ranges: coolant 75–95 °C, oil pressure 2–8 kgf/cm², 24 V on the batteries
# and 27–28 V from the generator, the bottle of the air start at about
# 150 kgf/cm². A vehicle that has stood the night: the cooling is warm from
# the heater, the oil still cold.
var coolant := 46.0
var oil_temp := 32.0
var oil_pressure := 0.0
var volts := 0.0
var air_bottle := 142.0
var odometer := 2417.3
var engine_hours := 386.2
var starter := false
var crank_left := 0.0
var catching := 0.0
var throttle := 0.0
var hand_throttle := 0.0
var clutch_pedal := 0.0
var brake_pedal := 0.0
var yoke := 0.0
var yoke_input := 0.0
var gear := NEUTRAL
var parking := true
var hatch_open := true
var doors_wanted := false
var doors := 0.0
var hatch := 1.0
var drive_force := 0.0
var grind := 0.0
var notice := ""
var notice_left := 0.0
var radio_on := false
var radio_track := 0
var parked_time := 0.0
var paused_velocity := Vector3.ZERO
var paused_spin := Vector3.ZERO
var was_paused := false
var clock := 0.0
var track_phase := 0.0
var surface_check := 0.0
var road := 0.5
# Damage: hull integrity, a disabled running gear, a burning wreck.
var integrity := 1.0
var immobile := false
var destroyed := false
var burn := 0.0
var smoke_clock := 0.0
var ram_clock := 0.0
var ram_query: PhysicsShapeQueryParameters3D

func setup(owner_game: Node3D, label: String="") -> void:
 game=owner_game
 callsign=label
 name="Bmp"+label
 mass=MASS
 center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
 center_of_mass=Vector3(0,0.95,-0.15)
 inertia=Vector3(57000,YAW_INERTIA,16000)
 can_sleep=false
 # The resistances are modelled in drive(); no engine-wide damping on top.
 linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
 linear_damp=0.0
 # The hull stops the world; soldiers are never an obstacle to 14 t of
 # steel: they step aside, or are run over.
 collision_layer=1
 collision_mask=1
 var surface:=PhysicsMaterial.new();surface.friction=0.35;physics_material_override=surface
 set_meta("ballistic_material","steel")
 set_meta("vehicle",true)
 art=BmpArt.build()
 add_child(art.root)
 for shape_data in [[Vector3(2.85,0.56,6.6),Vector3(0,0.71,0)],[Vector3(3.05,0.66,4.3),Vector3(0,1.30,1.15)],[Vector3(3.05,0.44,2.2),Vector3(0,1.13,-2.2)],[Vector3(1.7,0.68,1.75),Vector3(0,BmpArt.ROOF+0.34,-0.25)]]:
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=shape_data[0]
  shape.shape=box;shape.position=shape_data[1];add_child(shape)
 for x in [-GAUGE*0.5,GAUGE*0.5]:
  for z in BmpArt.WHEELS_Z:wheel_mounts.append(Vector3(x,RAY_TOP,z))
 compressions.resize(wheel_mounts.size());compressions.fill(FREE_LENGTH-(RAY_TOP))
 loads.resize(wheel_mounts.size());loads.fill(0.0)
 ray=PhysicsRayQueryParameters3D.create(Vector3.ZERO,Vector3.DOWN,1,[get_rid()])
 seat_camera=Camera3D.new();seat_camera.name="SeatCamera";seat_camera.near=0.05;seat_camera.far=6000;seat_camera.fov=75
 seat_camera.cull_mask=1|OperatorBody.WORLD_BODY_LAYER
 add_child(seat_camera)
 engine_sound=AudioStreamPlayer3D.new();engine_sound.stream=GradAudio.looped("bmp_engine","res://assets/audio/bmp/engine.wav");engine_sound.unit_size=10;engine_sound.max_distance=600
 engine_sound.position=Vector3(0.6,1.1,-2.2);engine_sound.bus=game.hearing.bus_name;add_child(engine_sound)
 radio_player=AudioStreamPlayer3D.new();radio_player.name="Radio";radio_player.position=BmpArt.RADIO
 radio_player.unit_size=1.4;radio_player.max_distance=25.0;radio_player.bus=game.hearing.bus_name
 radio_player.finished.connect(next_track);add_child(radio_player)
 gunner=BmpGunner.new();gunner.setup(self)

func say(text: String, seconds: float=4.0) -> void:
 notice=text;notice_left=seconds

func speed() -> float:return linear_velocity.dot(-global_basis.z)

func rpm() -> float:return omega*60.0/TAU
# The engine speed as heard and as the tachometer shows it: the crankshaft
# locked to the tracks follows every bounce of the running gear, the real
# flywheel and the sound of the exhaust do not.
func steady_rpm() -> float:return heard_rpm

func gear_ratio() -> float:return float(GEARS[gear])*FINAL

func engine_torque(r: float) -> float:
 for i in range(TORQUE.size()-1):
  if r<=TORQUE[i+1][0]:return lerpf(TORQUE[i][1],TORQUE[i+1][1],(r-TORQUE[i][0])/(TORQUE[i+1][0]-TORQUE[i][0]))
 return 0.0

func clutch_engagement() -> float:return clampf((0.75-clutch_pedal)/0.5,0.0,1.0)

func stationary() -> bool:return absf(speed())<0.4

# Ratio of the inner track speed to the outer one for a yoke deflection:
# the steering clutch slips, then the first stage holds, then the stopping
# brake of the inner track takes it down to a standstill.
func inner_ratio() -> float:
 var s:=absf(yoke)
 if s<0.04:return 1.0
 if s<0.55:return lerpf(1.0,1.0/STAGE,(s-0.04)/0.51)
 if s<0.8:return 1.0/STAGE
 return lerpf(1.0/STAGE,0.0,(s-0.8)/0.2)

# Speed for a gear at an engine speed, m/s (straight ahead).
static func gear_speed(index: int, engine_rpm: float) -> float:
 var ratio:=float(GEARS[index])*FINAL
 if ratio==0.0:return 0.0
 return engine_rpm*TAU/60.0/ratio*SPROCKET

func usable() -> bool:return not destroyed

# --- Driver's controls ---------------------------------------------------
func toggle_master() -> void:
 master=not master
 if not master and radio_on:set_radio(false)
 if not master and running:running=false;say("Маса вимкнена · подачу палива перекрито, двигун зупинено")
 else:say("Вимикач батарей (МАСА) %s" % ("увімкнено" if master else "вимкнено"),2)
 game.sound("click",-14)

func begin_crank() -> void:
 if starter:return
 starter=true
 crank_left=randf_range(0.8,1.6)
 if not master:say("Спершу вимикач батарей — МАСА (I)",2)

func toggle_radio() -> void:
 game.sound("click",-14)
 if not radio_on and not master:say("Радіо без живлення: увімкни масу (I)",2.5);return
 set_radio(not radio_on)
 say("Приймач: «%s»" % RADIO_TRACKS[radio_track][1] if radio_on else "Приймач вимкнено",2.5)

func set_radio(on: bool) -> void:
 radio_on=on
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

func radio_volume() -> float:return linear_to_db(maxf(game.volume,0.0001))-4.0

func update_radio() -> void:
 if not radio_on or game==null:return
 radio_player.stream_paused=game.paused
 radio_player.volume_db=radio_volume()

func shift(step: int) -> bool:
 if clutch_engagement()>0.15:
  grind=0.4;say("Скрегіт шестерень: вижми головний фрикціон (Shift)",2.5);return false
 var next:=clampi(gear+step,0,GEARS.size()-1)
 # First and reverse have no synchronizers: engaged only at a standstill.
 if next in [0,2] and gear==NEUTRAL and absf(speed())>1.0:
  grind=0.4;say("Першу й задню вмикають лише на місці",2.5);return false
 if next==0 and speed()>0.6:say("Задню — лише після повної зупинки",2.5);return false
 gear=next
 game.sound("click",-18)
 say("Передача %s" % GEAR_NAMES[gear],1.5)
 return true

func toggle_parking() -> void:
 parking=not parking;say("Гальма на защіпці (стоянкове) — %s" % ("ЗАТЯГНУТО" if parking else "відпущено"),2);game.sound("click",-12)

func toggle_hatch() -> void:
 hatch_open=not hatch_open;game.sound("click",-10)
 say("Люк механіка-водія %s" % ("відкрито · голова назовні" if hatch_open else "закрито · огляд через призми ТНПО"),2)

func open_doors(open: bool) -> void:
 if doors_wanted==open:return
 doors_wanted=open
 game.spatial_shot("bolt",to_global(Vector3(0,1.0,BmpArt.HALF)),-8)

# --- Troops ---------------------------------------------------------------
func room() -> int:return SEATS-aboard.size()

func board(actor: Hostile) -> bool:
 if aboard.has(actor):return true
 if room()<=0 or destroyed:return false
 aboard.append(actor)
 actor.embark(self)
 return true

func board_crew(actor: Hostile, role: String) -> void:
 crew.append(actor)
 actor.set_meta("bmp_role",role)
 actor.embark(self)

# Where a soldier steps out behind the open doors, left and right in turn.
func exit_point(index: int) -> Vector3:
 var local:Vector3=BmpArt.EXITS[index%2]+Vector3(0,0,float(index/2)*0.6)
 return to_global(local)

func unload(actor: Hostile, index: int) -> void:
 aboard.erase(actor)
 var spot:=exit_point(index)
 if is_instance_valid(game.district) and game.district.grid!=null and absf(spot.x)<199 and absf(spot.z)<199:
  var cell:Vector2i=game.district.nearest_cell(game.district.navigation_cell(spot))
  var snapped:Vector3=game.district.navigation_position(cell)
  if snapped.distance_to(spot)<4:spot=snapped
 spot.y=game.district.ground_height(spot)+0.1
 actor.disembark(spot,global_basis.z)

# --- Frame ------------------------------------------------------------------
func _physics_process(delta: float) -> void:
 update_radio()
 if game==null:return
 # The engine falls silent with the game on pause, and plays on after it.
 if is_instance_valid(engine_sound):engine_sound.stream_paused=game.paused or not game.running
 if not game.running or game.paused:
  if not was_paused and not freeze:
   paused_velocity=linear_velocity;paused_spin=angular_velocity
   freeze_mode=RigidBody3D.FREEZE_MODE_STATIC;freeze=true
   was_paused=true
  return
 if was_paused:
  was_paused=false
  if not parking or parked_time<0.8:
   freeze=false;linear_velocity=paused_velocity;angular_velocity=paused_spin
 clock+=delta
 if notice_left>0:notice_left-=delta
 grind=maxf(0,grind-delta)
 if driver_ai!=null and seat!="driver" and not destroyed:driver_ai.tick(delta)
 if seat!="driver" and driver_ai==null:throttle=0;yoke_input=0
 steer_yoke(delta)
 simulate_engine(delta)
 update_gauges(delta)
 if not freeze:
  suspend(delta)
  drive(delta)
 hold_parked(delta)
 animate(delta)
 for actor in aboard+crew:
  if is_instance_valid(actor) and not actor.dead:actor.global_position=global_position+global_basis.y*0.9
 gunner.tick(delta)
 crush()
 ram()
 if destroyed:smolder(delta)
 if seat=="driver" and is_instance_valid(game.district.operation_area):game.district.operation_area.collide_trees(global_position)

func steer_yoke(delta: float) -> void:
 # The yoke is held over against its centring spring; let go, it returns.
 if yoke_input!=0.0:yoke=clampf(yoke+yoke_input*1.6*delta,-1,1)
 else:yoke=move_toward(yoke,0,delta*3.0)

func simulate_engine(delta: float) -> void:
 if starter and master and not running:crank_left-=delta
 var r:=rpm()
 var open:=0.0
 if running:
  open=maxf(throttle,hand_throttle)
  # All-speed governor: holds the idle and cuts the fuel above 2600 rpm.
  open=maxf(open,clampf((IDLE_RPM+40.0-r)/300.0,0.0,0.4))
  if r>GOVERNED_RPM:open*=clampf((GOVERNED_RPM+150.0-r)/150.0,0.0,1.0)
 var torque:=engine_torque(r)*open if running else 0.0
 torque-=(30.0+r*0.035) if omega>0.5 else 0.0
 if starter and master and not running:torque+=230.0 if r<220.0 else 0.0
 var ratio:=gear_ratio()
 var engagement:=clutch_engagement() if ratio!=0.0 else 0.0
 if immobile or destroyed:engagement=0.0
 var k:=inner_ratio()
 # The outer track runs at the gearbox speed; the inner one at k of it.
 var outer:=speed()*2.0/(1.0+k)
 var transmitted:=0.0
 if engagement>0.0:
  var shaft:=outer/SPROCKET*ratio
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
 drive_force=transmitted*ratio*EFFICIENCY/SPROCKET*2.0/(1.0+k)
 if catching>0.0:catching-=delta
 if starter and master and not running and rpm()>200.0 and crank_left<=0.0 and not destroyed:
  running=true;catching=1.2;say("Двигун запущено",2)
 if running and ((rpm()<STALL_RPM and catching<=0.0) or not master or destroyed):
  running=false
  if master and not destroyed:say("Двигун заглух",3)
 if (running or (starter and master)) and not engine_sound.playing:engine_sound.play()
 elif not running and not starter and engine_sound.playing and rpm()<80:engine_sound.stop()
 heard_rpm=lerpf(heard_rpm,rpm(),1.0-exp(-delta*5.0))
 # The UTD-20 of the recording runs at about 1190 rpm.
 engine_sound.pitch_scale=clampf(maxf(heard_rpm,160.0)/RECORDED_RPM,0.2,2.6)
 heard_open=lerpf(heard_open,clampf(open,0,1),1.0-exp(-delta*4.0))
 engine_sound.volume_db=linear_to_db(maxf(game.volume,0.0001))+lerpf(-6.0,4.0,heard_open)-(10.0 if not running else 0.0)+(4.0 if seat=="driver" and hatch_open else 0.0)

func update_gauges(delta: float) -> void:
 var work:=heard_open*clampf(heard_rpm/GOVERNED_RPM,0.0,1.0)
 if running:
  coolant=move_toward(coolant,78.0+16.0*work,delta*(0.18+0.5*work))
  engine_hours+=delta/3600.0
 else:coolant=move_toward(coolant,18.0,delta*0.01)
 oil_temp=move_toward(oil_temp,coolant+4.0 if running else 18.0,delta*(0.12 if running else 0.008))
 var press:=0.0
 if running:press=lerpf(2.4,7.6,clampf((heard_rpm-IDLE_RPM)/(GOVERNED_RPM-IDLE_RPM),0.0,1.0))*(1.15-clampf((oil_temp-40.0)/300.0,0.0,0.25))
 elif starter and master:press=0.6
 oil_pressure=move_toward(oil_pressure,press,delta*6.0)
 var supply:=0.0
 if master:supply=19.5 if starter else (27.6 if running and heard_rpm>650.0 else 24.6)
 volts=move_toward(volts,supply,delta*20.0)
 odometer+=absf(speed())*delta/1000.0

# Twelve road wheels on rays: each is a spring and a damper on its arm.
func suspend(delta: float) -> void:
 var space:=get_world_3d().direct_space_state
 var up:=global_basis.y
 load_total=0.0
 for i in range(wheel_mounts.size()):
  var from:=to_global(wheel_mounts[i])
  ray.from=from;ray.to=from-up*(FREE_LENGTH+0.08)
  var hit:=space.intersect_ray(ray)
  var compression:=0.0
  if not hit.is_empty():compression=FREE_LENGTH-from.distance_to(hit.position)
  var rate:=(compression-compressions[i])/delta
  compressions[i]=compression
  loads[i]=0.0
  if compression<=0.0:continue
  var force:=WHEEL_SPRING*compression+WHEEL_DAMPER*rate
  if compression>TRAVEL:force+=WHEEL_SPRING*10.0*(compression-TRAVEL)
  force=maxf(force,0.0)
  loads[i]=force
  load_total+=force
  apply_force(up*force,from-global_position)

# Road surface under the tracks: 1 asphalt, 0.6 a dirt road, 0 a field.
func surface() -> float:
 surface_check-=get_physics_process_delta_time()
 if surface_check>0:return road
 surface_check=0.5
 var c:=Color(0.5,0.5,0.5)
 var data:=AvdiivkaData.shared() if is_instance_valid(game.district.operation_area) else null
 if absf(global_position.x)<199 and absf(global_position.z)<199:
  if game.district.terrain!=null and game.district.terrain.has_method("surface_color"):c=game.district.terrain.surface_color(Vector2(global_position.x,global_position.z))
  road=1.0 if c.v<0.42 and c.s<0.25 else 0.0
 elif data!=null:road=road_at(data,Vector2(global_position.x,global_position.z))
 else:road=0.0
 return road

# The roads of the operation area in 50 m cells, built on first use.
const ROAD_CELL := 50.0
static var road_cells: Dictionary={}
static var road_source: AvdiivkaData

static func road_at(data: AvdiivkaData, at: Vector2) -> float:
 if road_source!=data:
  road_source=data;road_cells.clear()
  for item in data.features.roads:
   if item[0] in OperationArea.SKIP_ROADS:continue
   var half:float=float(item[1])*0.5+0.6
   var paved:=1.0 if int(item[2])==1 else 0.6
   var line:=AvdiivkaData.pairs(item[3])
   for i in range(line.size()-1):
    var a:=line[i];var b:=line[i+1]
    var low:=Vector2i(floori((minf(a.x,b.x)-half)/ROAD_CELL),floori((minf(a.y,b.y)-half)/ROAD_CELL))
    var high:=Vector2i(floori((maxf(a.x,b.x)+half)/ROAD_CELL),floori((maxf(a.y,b.y)+half)/ROAD_CELL))
    for cx in range(low.x,high.x+1):
     for cz in range(low.y,high.y+1):
      var key:=Vector2i(cx,cz)
      if not road_cells.has(key):road_cells[key]=[]
      road_cells[key].append([a,b,half,paved])
 var best:=0.0
 for item in road_cells.get(Vector2i(floori(at.x/ROAD_CELL),floori(at.y/ROAD_CELL)),[]):
  var closest:=Geometry2D.get_closest_point_to_segment(at,item[0],item[1])
  if closest.distance_to(at)<=float(item[2]):best=maxf(best,float(item[3]))
 return best

func drive(delta: float) -> void:
 if load_total<=1000.0:return
 var up:=global_basis.y
 var forward:=-global_basis.z
 var side:=global_basis.x
 var v:=linear_velocity.dot(forward)
 var lateral:=linear_velocity.dot(side)
 var yaw:=angular_velocity.dot(up)
 var weight:=load_total
 var ground:=surface()
 var grip:=lerpf(0.72,0.9,ground)
 var k:=inner_ratio()
 # Skidding the tracks sideways in a turn (the empirical formula for the
 # turning resistance falls with the radius): it brakes the vehicle and
 # takes engine power, so sharp turns want a low gear.
 var loss:=0.0
 if k<0.999:
  var radius:=GAUGE*0.5*(1.0+k)/maxf(1.0-k,0.0001)
  var skid:=0.78/(0.925+0.15*radius/GAUGE)
  loss=skid*weight*CONTACT*0.25*2.0*(1.0-k)/((1.0+k)*GAUGE)
 # Rolling resistance of tracks: about 0.035 on asphalt, 0.05 on a dirt
 # road, 0.07–0.08 on a field.
 var rolling:=lerpf(0.075,0.035,ground)*weight
 var resist:=rolling+loss+0.5*1.2*6.5*v*v
 var brakes:=brake_pedal*grip*weight
 if parking:brakes=maxf(brakes,grip*weight)
 if immobile or destroyed:brakes=maxf(brakes,0.6*weight)
 var push:=clampf(drive_force,-grip*weight,grip*weight)
 var hold:=resist+brakes
 var gravity_along:=MASS*get_gravity().dot(forward)
 var total:=push
 if absf(v)>0.3:total-=signf(v)*hold
 else:
  # Nearly at rest: the resistances act as static friction, to their limit.
  total-=clampf(push+gravity_along+MASS*v/delta*0.5,-hold,hold)
 # Track forces act at the ground: the hull squats and rises on them.
 apply_force(forward*total,global_basis*Vector3(0,0.15,0))
 # Tracks do not slide sideways until the ground lets go.
 var grip_side:=grip*weight
 apply_force(-side*clampf(lateral*MASS*6.0,-grip_side,grip_side),global_basis*Vector3(0,0.15,0))
 # Yaw: the tracks hold the hull on the kinematic rate of the steering
 # mechanism; braked tracks hold it straight.
 var wanted:=0.0
 if k<0.999:wanted=-signf(yoke)*v*2.0*(1.0-k)/((1.0+k)*GAUGE)
 var cap:=grip*weight*GAUGE*0.5
 apply_torque(up*clampf((wanted-yaw)*YAW_INERTIA*7.0,-cap,cap))
 track_phase+=v*delta

func hold_parked(delta: float) -> void:
 if freeze:
  if not parking or immobile:
   if not was_paused:freeze=false;parked_time=0.0
  return
 if parking and linear_velocity.length()<0.15 and angular_velocity.length()<0.06 and load_total>MASS*5.0:parked_time+=delta
 else:parked_time=0.0
 if parked_time>0.8:
  freeze_mode=RigidBody3D.FREEZE_MODE_STATIC
  freeze=true
  linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO

func is_parked() -> bool:return freeze and not was_paused

func animate(delta: float) -> void:
 var wheels: Array=art.wheels
 for i in range(wheels.size()):
  var wheel: MeshInstance3D=wheels[i]
  var lift:=clampf(compressions[i]-(FREE_LENGTH-RAY_TOP),-0.12,TRAVEL)
  wheel.position.y=BmpArt.WHEEL_RADIUS+0.07+lift
  wheel.rotation.x=-track_phase/BmpArt.WHEEL_RADIUS
 for hub in art.drive:hub.rotation.x=-track_phase/BmpArt.SPROCKET_RADIUS
 doors=move_toward(doors,1.0 if doors_wanted else 0.0,delta*1.6)
 var leaves: Array=art.doors
 for i in range(leaves.size()):leaves[i].rotation.y=(-1.0 if i==0 else 1.0)*doors*1.85
 hatch=move_toward(hatch,1.0 if hatch_open else 0.0,delta*2.5)
 art.hatch.rotation.z=-hatch*1.75
 art.yoke.rotation.z=-yoke*0.6

# A hull moving over a soldier on foot: nobody survives under 14 t.
func crush() -> void:
 var v:=linear_velocity.length()
 if v<1.2:return
 for actor in game.allies+game.bots+[game.player]:
  if not is_instance_valid(actor):continue
  if actor is Hostile and (actor.dead or actor.vehicle!=null):continue
  if actor is Operator and (actor.health<=0 or game.player_vehicle()==self):continue
  var local:=to_local(actor.global_position)
  if absf(local.x)<1.55 and absf(local.z)<3.3 and local.y>-0.6 and local.y<1.4:
   actor.receive_hit(400.0,"chest",linear_velocity.normalized(),actor.global_position+Vector3.UP)

# A 30 mm round rocks the hull a little on its suspension.
func gunner_recoil() -> void:
 if freeze:return
 var back:Vector3=-gunner.barrel()
 apply_impulse(back*900.0,art.gun.global_position-global_position)

# Fences, posts, boards and sheds give way to 14 t: the bow (or the stern
# in reverse) flattens light pieces of the yard it runs into. House walls
# and masonry stop it.
func ram() -> void:
 ram_clock-=get_physics_process_delta_time()
 var v:=speed()
 if ram_clock>0.0 or absf(v)<0.3 or destroyed:return
 # Fast, it looks every frame: the bow must not hit a fence before it falls.
 ram_clock=0.05 if absf(v)<3.0 else 0.0
 if ram_query==null:
  ram_query=PhysicsShapeQueryParameters3D.new()
  var box:=BoxShape3D.new();box.size=Vector3(BmpArt.WIDTH+0.2,1.5,1.4)
  ram_query.shape=box;ram_query.collision_mask=1;ram_query.exclude=[get_rid()]
 var end:=-(BmpArt.HALF+0.3) if v>0.0 else BmpArt.HALF+0.3
 ram_query.transform=global_transform*Transform3D(Basis.IDENTITY,Vector3(0,1.05,end))
 for hit in get_world_3d().direct_space_state.intersect_shape(ram_query,12):
  var body: Object=hit.collider
  if body is DestructibleSurface and crushable(body):flatten(body,-global_basis.z*signf(v))

static func crushable(body: DestructibleSurface) -> bool:
 if body.breaking:return false
 # Fence panels of the great assault: bullets do not cut them, a hull does.
 if body.has_meta("crushable"):return true
 if body.has_meta("indestructible"):return false
 var shape_node:=body.get_child(0) as CollisionShape3D
 if shape_node==null or not shape_node.shape is BoxShape3D:return false
 var size: Vector3=shape_node.shape.size*body.global_basis.get_scale()
 var thin:=minf(size.x,minf(size.y,size.z))
 return size.x*size.y*size.z<0.5 or (thin<0.13 and size.y<2.6)

func flatten(body: DestructibleSurface, direction: Vector3) -> void:
 var district: Node3D=body.district
 if not is_instance_valid(district):return
 body.breaking=true
 var shape_node: CollisionShape3D=body.get_child(0)
 var size: Vector3=shape_node.shape.size
 var bounds:=AABB(-size/2,size)
 district.fragment(body.global_position,size,body.tint,body.get_meta("ballistic_material","wood"),direction,body.global_basis)
 if body.has_meta("fence_mesh"):BattleMap.knock_fence(body)
 elif body.batch!=null and body.batch_index>=0:body.batch.set_instance_transform(body.batch_index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
 body.collision_layer=0;body.collision_mask=0
 district.refresh_navigation(body.global_transform*bounds,body.get_instance_id(),[])
 body.queue_free()
 game.spatial_shot("bolt",body.global_position,-6)

# --- Damage -----------------------------------------------------------------
func damage(amount: float, where: Vector3) -> void:
 if destroyed:return
 integrity-=amount
 if integrity<=0.35 and not immobile:
  immobile=true;say("Ходову пошкоджено: машина знерухомлена",4)
 if integrity<=0.0:destroy(where)

func destroy(_where: Vector3) -> void:
 destroyed=true;immobile=true;running=false;burn=1.0
 throttle=0;clutch_pedal=1
 set_radio(false)
 # The troops bail out through the doors; the crew through the hatches.
 open_doors(true)

func smolder(delta: float) -> void:
 smoke_clock-=delta
 if smoke_clock>0:return
 smoke_clock=0.6
 GradEffects.shared(game).puff(to_global(Vector3(randf_range(-0.6,0.6),1.9,randf_range(-1.5,1.5))),2.2,0.15,Vector3(0.4,1.2,0))
