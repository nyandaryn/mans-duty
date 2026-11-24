class_name BmpVehicle
extends TrackedVehicle

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

var friendly := true
var radio_player: AudioStreamPlayer3D
# The compartments seen from the seats: built for the player's vehicle only.
var interior: BmpInterior
var troops: BmpTroops
var gunner: BmpGunner
var driver_ai: BmpDriver
var squad: Node
var callsign := ""
# Who is inside: the troops in the rear, and the crew (bots or the player).
var aboard: Array[Hostile]=[]
var crew: Array[Hostile]=[]
const RECORDED_RPM := 1190.0
var yoke := 0.0
var yoke_input := 0.0
var doors_wanted := false
var doors := 0.0
var doors_open := false
# The passenger's roof hatch over the troop compartment.
var troop_hatch_open := false
var troop_hatch := 0.0
var hatch := 1.0
var radio_on := false
var radio_track := 0
# Armour, hits, fire and the ammunition (VehicleDamage over VehicleArmor).
var hull: VehicleDamage
var burn := 0.0
var smoke_clock := 0.0

# Keys the gunner's own error in judging a range (BmpGunner.shoot_pkt): the
# order the vehicles were made in in this match, not the engine's object id.
static var made := 0
var judge_key := 0

func setup(owner_game: Node3D, label: String="") -> void:
 game=owner_game
 made+=1;judge_key=made
 configure()
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
 mount_wheels(BmpArt.WHEELS_Z)
 seat_camera=Camera3D.new();seat_camera.name="SeatCamera";seat_camera.near=0.05;seat_camera.far=6000;seat_camera.fov=75
 seat_camera.cull_mask=1|OperatorBody.WORLD_BODY_LAYER
 add_child(seat_camera)
 engine_sound=AudioStreamPlayer3D.new();engine_sound.stream=GradAudio.looped("bmp_engine","res://assets/audio/bmp/engine.wav");engine_sound.unit_size=10;engine_sound.max_distance=600
 engine_sound.position=Vector3(0.6,1.1,-2.2);engine_sound.bus=game.hearing.bus_name;add_child(engine_sound)
 radio_player=AudioStreamPlayer3D.new();radio_player.name="Radio";radio_player.position=BmpArt.RADIO
 radio_player.unit_size=1.4;radio_player.max_distance=25.0;radio_player.bus=game.hearing.bus_name
 radio_player.finished.connect(next_track);add_child(radio_player)
 gunner=BmpGunner.new();gunner.setup(self)
 troops=BmpTroops.new();troops.setup(self)
 hull=VehicleDamage.new();hull.setup(self,VehicleArmor.bmp2())
 add_to_group("vehicles")
 VehicleMarkings.apply(self,friendly)

# The receiver lamp closes the row of the driver's panel.
func panel_lamp() -> Array:return [radio_on,"ПРИЙМАЧ",BmpCockpit.GREEN]

func cabin() -> BmpInterior:
 if interior==null:
  interior=BmpInterior.new()
  interior.setup(self)
 return interior

# The figures of the BMP-2 for TrackedVehicle.
func configure() -> void:
 hull_mass=MASS;idle_rpm=IDLE_RPM;governed_rpm=GOVERNED_RPM;stall_rpm=STALL_RPM
 gears=GEARS;neutral=NEUTRAL;gear=NEUTRAL;final_drive=FINAL;sprocket=SPROCKET;efficiency=EFFICIENCY
 engine_inertia=ENGINE_INERTIA;clutch_capacity=CLUTCH_CAPACITY;torque_curve=TORQUE
 gauge=GAUGE;contact=CONTACT;yaw_inertia=YAW_INERTIA
 wheel_spring=WHEEL_SPRING;wheel_damper=WHEEL_DAMPER;ray_top=RAY_TOP;free_length=FREE_LENGTH;travel=TRAVEL
 frontal_area=6.5;recorded_rpm=RECORDED_RPM
 crush_half=Vector2(1.55,3.3);ram_width=BmpArt.WIDTH+0.2;ram_half=BmpArt.HALF
 wheel_radius=BmpArt.WHEEL_RADIUS;wheel_height=BmpArt.WHEEL_RADIUS+0.07;sprocket_radius=BmpArt.SPROCKET_RADIUS

# Ratio of the inner track speed to the outer one for a yoke deflection:
# the steering clutch slips, then the first stage holds, then the stopping
# brake of the inner track takes it down to a standstill.
func inner_ratio() -> float:
 var s:=absf(yoke)
 if s<0.04:return 1.0
 if s<0.55:return lerpf(1.0,1.0/STAGE,(s-0.04)/0.51)
 if s<0.8:return 1.0/STAGE
 return lerpf(1.0/STAGE,0.0,(s-0.8)/0.2)

func steer_side() -> float:return signf(yoke)

# Speed for a gear at an engine speed, m/s (straight ahead).
static func gear_speed(index: int, engine_rpm: float) -> float:
 var ratio:=float(GEARS[index])*FINAL
 if ratio==0.0:return 0.0
 return engine_rpm*TAU/60.0/ratio*SPROCKET

# --- Driver's controls ---------------------------------------------------
func toggle_master() -> void:
 master=not master
 if not master and radio_on:set_radio(false)
 if not master and running:running=false;say("Маса вимкнена · подачу палива перекрито, двигун зупинено")
 else:say("Вимикач батарей (МАСА) %s" % ("увімкнено" if master else "вимкнено"),2)
 game.sound("click",-14)

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

# The music ducks under the commander's orders on the radio net.
func radio_volume() -> float:
 var voice=game.get("radio_voice")
 return linear_to_db(maxf(game.volume,0.0001))-4.0-(14.0 if voice!=null and voice.speaking() else 0.0)

func update_radio() -> void:
 if not radio_on or game==null:return
 radio_player.stream_paused=game.paused
 radio_player.volume_db=radio_volume()
 # The crew hear the R-173 in the intercom headsets: in the turret as loud
 # as in the driver's seat, where the set stands at the left elbow.
 var command=game.get("bmp")
 if command!=null and command.vehicle==self and command.seat!="":
  radio_player.global_position=seat_camera.global_transform*Vector3(-0.3,-0.25,-0.45)
 else:radio_player.position=BmpArt.RADIO

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

func toggle_hatch() -> void:
 hatch_open=not hatch_open;game.sound("click",-10)
 say("Люк механіка-водія %s" % ("відкрито · голова назовні" if hatch_open else "закрито · огляд через призми ТНПО"),2)

# The doors stay open while anybody is still in a doorway.
func open_doors(open: bool) -> void:
 doors_wanted=open

func doors_wanted_now() -> bool:return doors_wanted or troops.busy()

# --- Troops ---------------------------------------------------------------
func room() -> int:return SEATS-aboard.size()

# Aboard at once (the column forms up), or `walk`: in through his door to
# a seat (BmpTroops).
func board(actor: Hostile, walk: bool=false) -> bool:
 if aboard.has(actor):return true
 if room()<=0 or destroyed:return false
 aboard.append(actor)
 actor.embark(self)
 troops.take(actor,walk)
 return true

# Everybody out through the doors, row by row.
func unload_all() -> void:troops.unload_all()

func board_crew(actor: Hostile, role: String) -> void:
 crew.append(actor)
 actor.set_meta("bmp_role",role)
 actor.embark(self)

# Where a soldier steps out behind the open doors, left and right in turn.
func exit_point(index: int) -> Vector3:
 var local:Vector3=BmpArt.EXITS[index%2]+Vector3(0,0,float(index/2)*0.6)
 return to_global(local)

# Out at once (the vehicle is lost).
func unload(actor: Hostile, index: int) -> void:
 aboard.erase(actor)
 troops.forget(actor)
 actor.rotation=Vector3.ZERO
 actor.disembark(ground_spot(exit_point(index),true),global_basis.z)

# A point on the ground for a man stepping out: on the walkable grid when
# `snap` or when the point itself is in a wall.
func ground_spot(spot: Vector3, snap: bool) -> Vector3:
 var district: Node3D=game.district
 if is_instance_valid(district) and district.grid!=null and absf(spot.x)<199 and absf(spot.z)<199:
  var cell:Vector2i=district.navigation_cell(spot)
  if snap or not district.grid.is_in_boundsv(cell) or district.grid.is_point_solid(cell):
   var snapped:Vector3=district.navigation_position(district.nearest_cell(cell))
   if snapped.distance_to(spot)<4:spot=snapped
 if is_instance_valid(district):
  spot.y=district.ground_height(spot)+0.1
  # On a heap of rubble: on top of it, not in it.
  if BmpRoutes.on_rubble(district,spot):
   var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(spot+Vector3.UP*3.0,spot,1,[get_rid()]))
   if not hit.is_empty() and hit.collider.has_meta("rubble"):spot.y=hit.position.y+0.1
 return spot

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
 # The troops are placed by BmpTroops: on their seats or on the way.
 for actor in crew:
  if is_instance_valid(actor) and not actor.dead:actor.global_position=global_position+global_basis.y*0.9
 gunner.tick(delta)
 crush()
 ram()
 hull.tick(delta)
 if seat=="driver" and is_instance_valid(game.district.operation_area):game.district.operation_area.collide_trees(global_position)

func steer_yoke(delta: float) -> void:
 # The yoke is held over against its centring spring; let go, it returns.
 if yoke_input!=0.0:yoke=clampf(yoke+yoke_input*1.6*delta,-1,1)
 else:yoke=move_toward(yoke,0,delta*3.0)

func animate(delta: float) -> void:
 animate_running_gear()
 # The heavy doors (they are the fuel tanks) swing out and slow at the end.
 var want:=doors_wanted_now()
 if want!=doors_open:
  doors_open=want
  game.spatial_shot("bolt",to_global(Vector3(0,1.0,BmpArt.HALF)),-8)
 doors=move_toward(doors,1.0 if want else 0.0,delta*1.1)
 var swing:=smoothstep(0.0,1.0,doors)*1.85
 var leaves: Array=art.doors
 for i in range(leaves.size()):leaves[i].rotation.y=(-1.0 if i==0 else 1.0)*swing
 troop_hatch=move_toward(troop_hatch,1.0 if troop_hatch_open else 0.0,delta*2.2)
 art.troop_hatch.rotation.z=-smoothstep(0.0,1.0,troop_hatch)*1.65
 hatch=move_toward(hatch,1.0 if hatch_open else 0.0,delta*2.5)
 art.hatch.rotation.z=-hatch*1.75
 VehicleMarkings.flutter(self,art)

# A 30 mm round rocks the hull a little on its suspension.
func gunner_recoil() -> void:
 if freeze:return
 var back:Vector3=-gunner.barrel()
 apply_impulse(back*900.0,art.gun.global_position-global_position)

# --- Damage -----------------------------------------------------------------
# A round or a grenade strikes the hull (VehicleArmor works out the rest).
func vehicle_hit(point: Vector3, direction: Vector3, round: String, pen_mm: float=-1.0) -> Dictionary:
 return hull.strike(point,direction,round,pen_mm)

# A burst near the vehicle: its fragments on the armour.
func blast_hit(where: Vector3, kind: String) -> void:hull.blast(where,kind)

# How much of a blast outside gets in to the men (VehicleDamage): the rear
# doors open, the driver's head out of his hatch, the roof hatch up.
func openings() -> float:
 var open:=1.0
 if doors>0.3:open+=0.5
 if hatch_open and hatch>0.5:open+=0.15
 if troop_hatch_open:open+=0.2
 return open

func turret_yaw() -> float:return art.turret.rotation.y

func out_of_action() -> bool:return hull.out_of_action()

# Everybody inside and where (vehicle frame): the crew in their seats, the
# squad on the benches, the player where he sits (not with his head out of
# a hatch: then the hull is not between him and the jet).
func occupants() -> Array:
 var list:=[]
 for actor in crew:
  if not is_instance_valid(actor) or actor.dead:continue
  var role:=String(actor.get_meta("bmp_role",""))
  if role=="driver":list.append([actor,BmpArt.DRIVER_EYE+Vector3(0,-0.45,0)])
  else:list.append([actor,turret_point(BmpArt.GUNNER_EYE+Vector3(0,-0.55,0))])
 for actor in aboard:
  if not is_instance_valid(actor) or actor.dead:continue
  var place:=troops.seat_of(actor)
  list.append([actor,BmpTroops.seat_spot(place)+Vector3(0,0.45,0) if place>=0 else Vector3(0,0.95,1.4)])
 if game.player_vehicle()==self and not game.bmp.head_out and is_instance_valid(game.player):
  var at:=BmpTroops.seat_spot(BmpTroops.PLAYER_SEAT)+Vector3(0,0.45,0)
  if game.bmp.seat=="driver":at=BmpArt.DRIVER_EYE+Vector3(0,-0.45,0)
  list.append([game.player,at])
 return list

# A point of the turret (given as if it faced ahead) where it is now.
func turret_point(point: Vector3) -> Vector3:
 return BmpArt.TURRET+(point-BmpArt.TURRET).rotated(Vector3.UP,turret_yaw())

func on_immobile(reason: String) -> void:
 immobile=true
 if reason.contains("двигун"):engine_dead=true
 say(reason.left(1).to_upper()+reason.substr(1)+": машина знерухомлена",4)

# Fire inside: the crew and the troops get out at once (their squad sees to
# it, see MechSquad); the player is told.
func on_fire() -> void:
 say("ПОЖЕЖА В МАШИНІ! Покинути машину!",6)
 open_doors(true)
 if game.player_vehicle()==self:game.squad.tell("Пожежа в БМП — негайно покинь машину!")

func on_destroyed(blast: bool) -> void:
 destroy(Vector3.ZERO)
 burnt()
 if blast:
  # The ammunition went up under the turret: it is thrown off the ring.
  var turret: Node3D=art.turret
  turret.position+=Vector3(randf_range(-0.5,0.5),0.35,randf_range(-0.4,0.6))
  turret.rotation+=Vector3(randf_range(-0.45,0.45),randf_range(-0.6,0.6),randf_range(-0.35,0.35))

# The paint burns off: everything darkens to scorched steel.
static var burnt_material: StandardMaterial3D
func burnt() -> void:
 if burnt_material==null:
  burnt_material=StandardMaterial3D.new()
  burnt_material.vertex_color_use_as_albedo=true
  burnt_material.albedo_color=Color(0.22,0.20,0.19)
  burnt_material.roughness=0.95
 for item in art.root.find_children("*","MeshInstance3D",true,false):
  if item.name=="Flames":continue
  (item as MeshInstance3D).material_override=burnt_material

func damage(amount: float, where: Vector3) -> void:
 if destroyed:return
 integrity-=amount
 if integrity<=0.35 and not immobile:
  immobile=true;say("Ходову пошкоджено: машина знерухомлена",4)
 if integrity<=0.0:destroy(where)

func destroy(_where: Vector3) -> void:
 if destroyed and not running:return
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
