class_name BmpCommand
extends Node

# The player and the BMP-2. As the driver-mechanic (class «механік-водій
# БМП») he drives his squad's vehicle and is the squad leader: dismount,
# mount up, follow the vehicle in file, storm dispersed. In the great assault
# a player of another class rides in the troop compartment of the leading
# vehicle among the squad and gets out with them at the drop point, in his
# turn through the right door (BmpTroops).
const REACH := 2.6
const COMMANDS := [["dismount","1","ДЕСАНТ · СПІШИТИСЯ"],["mount","2","ПО МІСЦЯХ · ПОСАДКА"],["file","3","ЗА БМП · КОЛОНОЮ ПО ОДНОМУ"],["assault","4","ШТУРМ РОЗСИПОМ"]]
var game: Node3D
var vehicle: BmpVehicle
var squad: MechSquad
var seat := ""
var look := Vector2.ZERO
var panel: Control
var caption: Label
var instruments: Label
var cockpit: BmpCockpit
# The passenger in the troop compartment: head and shoulders out of the roof
# hatch over his seat with the rifle, or inside among the squad.
var head_out := false
var hitbox_layers: Array[int]=[]
# The eyes standing in the troop hatch with the shoulders over the rim to
# shoot (vehicle frame); seated inside they are BmpArt.TROOP_EYE.
const TROOP_HEAD_OUT := Vector3(0.50,2.06,1.22)
# Looking along the bench to the doors when he sits down.
const TROOP_LOOK := Vector2(-0.45,-0.10)
# Inside the compartments, and with the face at the eyepiece of a prism.
const INSIDE_FOV := 70.0
const LEAN_FOV := 62.0
# The right button inside: decided on the press by what the eyes rest on —
# "lean" (to the eyepiece of a prism), "panel" (the instruments large at the
# bottom), "none".
var press := ""
var lean := 0.0
var lean_device := -1
var target := {}
# Magazines filled on the bench (the field inventory, TAB): the hands in the
# lap under this pivot of the troop compartment, the eyes down on them while
# the work begins.
var lap: Node3D
var was_working := false
var glance := 0.0
const LAP_PITCH := -0.55
const WORK_LOOK := Vector2(0.0,-0.80)

func setup(owner_game: Node3D, ui_root: Control) -> void:
 game=owner_game
 # Under the HUD: its compass and texts stay over the hull.
 cockpit=BmpCockpit.new()
 game.place(cockpit,ui_root,0,0,1,1)
 ui_root.move_child(cockpit,game.hud.get_index())
 cockpit.setup(game,self)
 panel=Control.new()
 game.place(panel,ui_root,0,0,1,1)
 panel.mouse_filter=Control.MOUSE_FILTER_STOP
 var backdrop:=ColorRect.new()
 backdrop.color=Color(0.02,0.035,0.03,0.80)
 game.place(backdrop,panel,0,0.55,1,1)
 game.bleed(backdrop)
 var content:=VBoxContainer.new()
 content.add_theme_constant_override("separation",9)
 game.place(content,panel,0.08,0.58,0.92,0.97)
 content.add_child(game.label("ВІДДІЛЕННЯ НА БМП-2 · КОМАНДИ",23,game.GOLD))
 caption=game.label("",15)
 caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 content.add_child(caption)
 var line:=HBoxContainer.new();line.add_theme_constant_override("separation",8)
 content.add_child(line)
 for item in COMMANDS:
  var button: Button=game.button("%s  ·  %s" % [item[1],item[2]],command.bind(item[0]))
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.custom_minimum_size.y=46
  button.add_theme_font_size_override("font_size",15)
  line.add_child(button)
 content.add_child(game.label("1–4 або кнопки · штурм — у точку, куди дивишся · G / Esc — закрити",13,game.GOLD))
 panel.hide()
 instruments=game.label("",17)
 game.place(instruments,ui_root,0.035,0.70,0.6,0.86)
 instruments.hide()

func active() -> bool:return is_instance_valid(vehicle)

func driver_class() -> bool:return game.player_class=="bmp"

func reset() -> void:
 close()
 if is_instance_valid(instruments):instruments.hide()
 if seat!="" and is_instance_valid(game.player) and game.player.is_inside_tree():release_player()
 head_out=false
 # Vehicles of the great assault belong to the battle; only a regular
 # map's vehicle is the command's own.
 if is_instance_valid(vehicle) and not (is_instance_valid(squad) and squad.battle!=null and squad.battle.active):
  if is_instance_valid(squad):squad.queue_free()
  vehicle.gunner.clear();vehicle.queue_free()
 vehicle=null;squad=null;seat="";look=Vector2.ZERO;clear_press()

# --- Starting a match --------------------------------------------------------
# A regular map: the player's vehicle stands near the insertion point with
# the gunner in the turret and seven men in the troop compartment.
func start() -> void:
 if not driver_class() or game.training!="":return
 if game.selected_map==BattleMap.ID:return
 vehicle=BmpVehicle.new()
 game.world_root.add_child(vehicle)
 vehicle.setup(game,"1")
 var at:=parking_spot()
 vehicle.look_at_from_position(at.origin+Vector3.UP*0.12,at.origin+Vector3.UP*0.12-at.basis.z,Vector3.UP)
 squad=MechSquad.new()
 add_child(squad)
 squad.setup(game,game.battle,0,vehicle,true)
 take_personal_squad()
 enter("driver")
 game.squad.tell("БМП-2 · двигун заглушено · I — маса, X — стартер · 1–4 — команди відділенню")

# «Навчання»: the course's vehicle at the head of the column's parking place
# on the field road, cold, the gunner in the turret and seven men aboard.
func start_training() -> void:
 vehicle=BmpVehicle.new()
 game.world_root.add_child(vehicle)
 vehicle.setup(game,"1")
 game.battle.place_vehicle(vehicle,BmpRoutes.parking(0,game.district))
 squad=MechSquad.new()
 add_child(squad)
 squad.setup(game,game.battle,0,vehicle,true)
 take_personal_squad()

# The great assault: the driver leads the column in the first vehicle; any
# other class (except the mortar crew and the BM-21) rides in it.
func start_battle(battle: BattleMode) -> void:
 if driver_class():
  vehicle=BmpVehicle.new()
  game.world_root.add_child(vehicle)
  vehicle.setup(game,"1")
  battle.place_vehicle(vehicle,BmpRoutes.parking(0,game.district))
  squad=MechSquad.new()
  battle.add_child(squad)
  squad.setup(game,battle,0,vehicle,true)
  battle.register_squad(squad)
  squad.start_spot=vehicle.global_position
  take_personal_squad()
  for actor in squad.members+vehicle.crew:actor.set_meta("battle_group",0)
  enter("driver")
  if battle.prep=="":game.squad.tell("Ти ведеш колону: %d БМП за тобою · I — маса, X — стартер · польовою дорогою до траси й на північ, до села ~2 км" % (battle.mech.size()-1))
  else:game.squad.tell("Ти — механік-водій головної БМП: %d за тобою · I — маса, X — стартер · стоїмо, поки б'ють «Гради»" % (battle.mech.size()-1))
  return
 if game.player_class in ["mortarman","grad"] or battle.mech.is_empty():return
 squad=battle.mech[0]
 vehicle=squad.vehicle
 # The rifleman and the sniper start on the field with the squad, dismounted
 # (BattleMode.begin_field puts them there).
 if battle.prep!="":return
 enter("troop")
 game.squad.tell("Ти в десантному відділенні першої БМП, з відділенням · колона рушить на штурм · F — вийти на зупинці")

# On foot in the squad's half ring behind the stern, facing where the
# vehicle faces.
func stand_by_vehicle() -> void:
 if not active() or not is_instance_valid(squad):return
 var count:=squad.on_foot().size()+1
 var spot:=squad.field_spot(count-1,count)
 spot.y=game.district.ground_height(spot)+0.05
 var facing:=-vehicle.global_basis.z
 var player: Operator=game.player
 player.global_position=spot
 player.rotation.y=atan2(-facing.x,-facing.z)
 player.pitch=0
 player.velocity=Vector3.ZERO

# The personal allies of the class: the first is the gunner-operator, the
# rest go into the troop compartment.
func take_personal_squad() -> void:
 for i in range(game.allies.size()):
  var actor: Hostile=game.allies[i]
  if actor.get_meta("battle_managed",false):continue
  if vehicle.crew.is_empty():
   vehicle.board_crew(actor,"gunner")
   continue
  if vehicle.room()<=0:break
  squad.members.append(actor)
  vehicle.board(actor)
 vehicle.gunner.manned=not vehicle.crew.is_empty()

# A clear place for 7 × 3.2 m near the insertion point, nose along the
# player's heading.
func parking_spot() -> Transform3D:
 var district: Node3D=game.district
 var yaw: float=district.player_spawn_yaw
 var forward:=Vector3(-sin(yaw),0,-cos(yaw))
 var side:=Vector3(-forward.z,0,forward.x)
 var base: Vector3=district.player_spawn
 for distance in [9.0,13.0,6.0,18.0,24.0,30.0,40.0,55.0]:
  for lateral in [0.0,-5.0,5.0,-9.0,9.0]:
   for axis in [forward,side,-forward,-side]:
    var across:=Vector3(-axis.z,0,axis.x)
    var p: Vector3=base+axis*distance+across*lateral
    # Clean ground with room at the sides and a clear run ahead to move off.
    if footprint_clear(p,forward,1.0) and footprint_clear(p+forward*8.0,forward,0.6) and footprint_clear(p+forward*16.0,forward,0.6):
     p.y=district.ground_height(p)
     return Transform3D(Basis.looking_at(forward,Vector3.UP),p)
 var p:=base+forward*9.0
 p.y=district.ground_height(p)
 return Transform3D(Basis.looking_at(forward,Vector3.UP),p)

func footprint_clear(center: Vector3, forward: Vector3, margin: float=0.3) -> bool:
 var district: Node3D=game.district
 if district.grid==null:return true
 var side:=Vector3(-forward.z,0,forward.x)
 var heights: Array[float]=[]
 for along in [-4.0,-2.0,0.0,2.0,4.0]:
  for across in [-2.0,0.0,2.0]:
   var p: Vector3=center+forward*along+side*across
   var cell: Vector2i=district.navigation_cell(p)
   if not district.grid.is_in_boundsv(cell) or district.grid.is_point_solid(cell):return false
   heights.append(district.ground_height(p))
 if heights.max()-heights.min()>0.6:return false
 # Nothing standing in the volume of the hull (the grid is coarse for a
 # wall at a corner), not even a bin it would flatten: it parks clean.
 var query:=PhysicsShapeQueryParameters3D.new()
 var box:=BoxShape3D.new();box.size=Vector3(BmpArt.WIDTH+margin*2.0,1.7,BmpArt.HALF*2.0+0.6)
 query.shape=box
 query.collision_mask=1
 var at:=center;at.y=district.ground_height(center)+0.45+0.85
 query.transform=Transform3D(Basis.looking_at(forward,Vector3.UP),at)
 if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
 # Lamp posts have no collider: one would stand through the troop
 # compartment, in the passenger's face once the doors open.
 for post in district.get("posts") if district.get("posts") is Array else []:
  var d: Vector3=post-center
  if absf(d.dot(forward))<BmpArt.HALF+0.6 and absf(d.dot(side))<BmpArt.WIDTH*0.5+margin+0.3:return false
 return true

# --- Seats -----------------------------------------------------------------------
func enter(id: String) -> void:
 var player: Operator=game.player
 player.field_rig.cancel();game.inventory.close();game.close_panels()
 seat=id;look=TROOP_LOOK if id=="troop" else Vector2(0,-0.05);head_out=false;clear_press()
 vehicle.cabin()
 if id=="driver":vehicle.seat="driver"
 if id=="troop":vehicle.troops.seat_player()
 player.set_physics_process(false);player.set_process(false);player.set_process_unhandled_input(false)
 player.collision_layer=0;player.collision_mask=0;player.velocity=Vector3.ZERO
 hitbox_layers.clear()
 for area in player.find_children("*","Area3D",true,false):
  hitbox_layers.append(area.collision_layer);area.collision_layer=0
 player.viewmodel.hide();player.world_body.hide()
 vehicle.seat_camera.make_current()
 instruments.hide()
 place_player()

func release_player() -> void:
 var player: Operator=game.player
 player.field_rig.stand_up()
 player.anchor=Callable();head_out=false
 player.set_physics_process(true);player.set_process(true);player.set_process_unhandled_input(true)
 player.collision_layer=2;player.collision_mask=1|4|64
 var areas:=player.find_children("*","Area3D",true,false)
 for i in range(mini(areas.size(),hitbox_layers.size())):areas[i].collision_layer=hitbox_layers[i]
 hitbox_layers.clear()
 player.viewmodel.show();player.world_body.show()
 player.camera.make_current()
 if active():
  clear_press()
  vehicle.troop_hatch_open=false
  vehicle.troops.unseat_player()
  if vehicle.interior!=null:vehicle.interior.set_station("")

# Out at once: the driver through his hatch, a passenger behind the hull
# (the vehicle is lost, or the battle skipped the march).
func leave() -> void:
 if seat=="":return
 var spot: Vector3
 if seat=="driver":spot=vehicle.to_global(Vector3(-2.3,0,-1.3))
 else:spot=vehicle.exit_point(0)+vehicle.global_basis.z*0.6
 var away:=spot-vehicle.global_position
 out_at(spot,-away if seat=="driver" else vehicle.global_basis.z)

# The passenger at the end of his way out through the right door.
func step_out(spot: Vector3, facing: Vector3) -> void:
 if seat!="troop":return
 out_at(spot,facing)
 game.squad.tell("Спішування: ти з десантом першої БМП")

func out_at(spot: Vector3, facing: Vector3) -> void:
 var player: Operator=game.player
 spot.y=game.district.ground_height(spot)
 var space:=vehicle.get_world_3d().direct_space_state
 var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(spot+Vector3.UP*4,spot+Vector3.DOWN*4,1,[vehicle.get_rid()]))
 if not hit.is_empty():spot=hit.position
 player.global_position=spot+Vector3.UP*0.05
 player.rotation.y=atan2(-facing.x,-facing.z)
 player.pitch=0
 if seat=="driver":
  vehicle.throttle=0;vehicle.brake_pedal=0;vehicle.clutch_pedal=0;vehicle.yoke_input=0
  vehicle.seat=""
 release_player()
 seat=""
 instruments.hide()
 if game.running and not game.paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

# The operator is replaced (the command passed to another soldier): the
# seat is simply empty now.
func vacate() -> void:
 if seat=="":return
 if seat=="driver" and is_instance_valid(vehicle):
  vehicle.throttle=0;vehicle.yoke_input=0;vehicle.seat=""
 if head_out and is_instance_valid(game.player):game.player.anchor=Callable()
 seat="";hitbox_layers.clear();head_out=false;clear_press()
 if is_instance_valid(vehicle):
  vehicle.troop_hatch_open=false
  vehicle.troops.unseat_player()
  if vehicle.interior!=null:vehicle.interior.set_station("")
 instruments.hide()

func place_player() -> void:
 var player: Operator=game.player
 if seat=="driver":player.global_position=vehicle.to_global(BmpArt.DRIVER_EYE+Vector3.DOWN*1.2)
 else:player.global_position=vehicle.to_global(BmpArt.TROOP_EYE+Vector3.DOWN*0.9)

# Where the eyes of the operator standing in the troop hatch are.
func hatch_point() -> Vector3:return vehicle.global_transform*TROOP_HEAD_OUT

# On his way out of the troop compartment: the camera goes with him.
func exiting() -> bool:return seat=="troop" and active() and vehicle.troops.player_moving()

func clear_press() -> void:
 press="";lean=0.0;lean_device=-1;target={}

# Which compartment the eyes are in: none with the hatch open or head out
# (the camera is outside then).
func station() -> String:
 match cockpit.view():
  "driver":return "driver"
  "troop":return "troop"
 return ""

func update_camera() -> void:
 var camera:=vehicle.seat_camera
 var view:=cockpit.view()
 var inside:=station()
 if inside!="":
  var cabin:=vehicle.cabin()
  var part:=cabin.holder(inside)
  var seat_eye:=cabin.eye(inside)
  var head:=part.global_transform*Transform3D(Basis(Vector3.UP,cabin.facing(inside)+look.x)*Basis(Vector3.RIGHT,look.y),seat_eye)
  var t:=smoothstep(0.0,1.0,lean)
  if lean_device>=0 and t>0.0:
   var at:=part.global_transform*cabin.lean_frame(inside,lean_device)
   var turn:=Quaternion(head.basis.orthonormalized()).slerp(Quaternion(at.basis.orthonormalized()),t)
   head=Transform3D(Basis(turn),head.origin.lerp(at.origin,t))
  if exiting():head=vehicle.global_transform*vehicle.troops.player_view();t=0.0
  camera.global_transform=head
  camera.fov=lerpf(INSIDE_FOV,LEAN_FOV,t)
  # Only the compartment, a few metres deep: the world comes in through
  # the prisms, and through the doors when they are open.
  if inside=="troop" and (vehicle.doors>0.01 or exiting()):
   camera.near=0.03;camera.far=6000;camera.cull_mask=BmpArt.INTERIOR_LAYER|1
  else:
   camera.near=0.02;camera.far=6.0;camera.cull_mask=BmpArt.INTERIOR_LAYER
  return
 camera.near=0.05;camera.far=6000;camera.cull_mask=1|OperatorBody.WORLD_BODY_LAYER
 camera.global_transform=vehicle.global_transform*Transform3D(Basis(Vector3.UP,look.x)*Basis(Vector3.RIGHT,look.y),BmpArt.DRIVER_HEAD_OUT)
 camera.fov=INSIDE_FOV

# The right button: on the press it does what the eyes rest on, until it is
# let go.
func update_press(delta: float) -> void:
 var view:=cockpit.view()
 var held:=view!="" and cockpit.aiming() and not exiting()
 if not held:
  if press!="":press=""
 elif press=="":
  match view:
   "driver_open":press="panel"
   _:
    match str(target.get("kind","")):
     "prism":press="lean";lean_device=int(target.index)
     "panel":press="panel"
     _:press="panel" if view=="driver" else "none"
 lean=move_toward(lean,1.0 if press=="lean" else 0.0,delta*5.0)
 if lean<=0.0 and press!="lean":lean_device=-1

func look_limits() -> Vector4:
 if seat=="driver" and not vehicle.hatch_open:return Vector4(-1.75,1.75,-0.95,0.55)
 if seat=="driver":return Vector4(-1.9,1.9,-0.9,0.7)
 # On the bench the head and shoulders turn round to the doors and ahead.
 return Vector4(-2.4,2.4,-0.85,0.6)

# V on the bench: up into the roof hatch with the rifle, or back in.
func set_head_out(on: bool) -> void:
 if seat!="troop" or head_out==on or (on and exiting()):return
 var player: Operator=game.player
 var areas:=player.find_children("*","Area3D",true,false)
 if on:
  if vehicle.destroyed:return
  var forward:=-vehicle.seat_camera.global_basis.z
  player.rotation.y=atan2(-forward.x,-forward.z)
  player.pitch=0.0
  head_out=true;clear_press()
  vehicle.cabin().set_station("")
  player.anchor=hatch_point
  player.global_position+=hatch_point()-player.camera.global_position
  player.set_physics_process(true);player.set_process(true);player.set_process_unhandled_input(true)
  # Head and shoulders over the armour can be hit.
  for i in range(mini(areas.size(),hitbox_layers.size())):areas[i].collision_layer=hitbox_layers[i]
  player.field_rig.stand_up()
  player.viewmodel.show()
  player.camera.make_current()
  vehicle.troop_hatch_open=true
  vehicle.say("Відкрив люк десантного відділення · голова й плечі назовні, автомат у руках",2)
 else:
  head_out=false
  player.anchor=Callable()
  player.set_physics_process(false);player.set_process(false);player.set_process_unhandled_input(false)
  player.velocity=Vector3.ZERO
  for area in areas:area.collision_layer=0
  player.viewmodel.hide()
  look=TROOP_LOOK;clear_press()
  vehicle.troop_hatch_open=false
  vehicle.seat_camera.make_current()
  place_player()
 game.sound("click",-10)

# --- Frame ------------------------------------------------------------------
func _process(delta: float) -> void:
 if not active() or not game.running or game.paused:return
 if seat!="":
  if not head_out:
   place_player()
   update_press(delta)
   update_camera()
   var cabin:=vehicle.cabin()
   if cabin.station!=station():cabin.set_station(station())
   cabin.leaning=lean_device if lean>0.0 else -1
   # What the middle of the view rests on, for the next press and the
   # prompt under the dot.
   target=cabin.pick(vehicle.seat_camera) if lean<=0.0 and not exiting() else {}
   bench_work(delta)
  # Pinned again after all the physics of the frame: the hull must not
  # slide a step ahead of the eyes in the hatch.
  else:
   game.player.global_position+=hatch_point()-game.player.camera.global_position
   # His turn to get out: down from the hatch first.
   if exiting():set_head_out(false)
  if seat=="driver":read_controls(delta)
  # A bot is driving: the receiver plays all the way.
  if seat=="troop" and not vehicle.destroyed and not vehicle.radio_on:
   vehicle.master=true;vehicle.set_radio(true)
  # A passenger gets out with the squad in his turn (BmpTroops); at once
  # when the vehicle is lost.
  if seat=="troop" and vehicle.destroyed:
   leave()
   game.squad.tell("БМП підбито — ти з десантом пішки")
  elif seat=="driver" and vehicle.destroyed:
   leave()
   game.squad.tell("БМП знищено — покинь машину й веди відділення пішки")
 if seat!="":
  game.soldier_controls.text=hint_text()
  # The closed hatch has the panel itself (BmpCockpit); head out the panel
  # is down by the knee: a line of the main readings and the right button.
  instruments.visible=seat=="driver" and vehicle.hatch_open and cockpit.large<0.05
  instruments.text=instrument_text() if instruments.visible else ""
  if not head_out:game.hud_text.visible=false
 elif driver_class():
  var prompt:=station_prompt()
  game.soldier_controls.text=prompt if prompt!="" else game.control_hint()
 elif game.battle.active and is_instance_valid(squad):
  var prompt:=troop_prompt()
  game.soldier_controls.text=prompt if prompt!="" else game.control_hint()
 if driver_class() and is_instance_valid(squad):
  if game.training!="" and game.course()!=null:game.objective.text=game.course().objective_text()+"\n"+squad_status()
  elif not game.battle.active:game.objective.text=squad_status()
  else:game.objective.text=game.battle.status()+"\n"+squad_status()
 elif seat=="troop" and game.battle.active:
  game.objective.text=game.battle.status()+"\nКОЛОНА · %s" % column_text()
 var notice:=vehicle.notice if vehicle.notice_left>0 else ""
 if notice!="" and instruments.visible:instruments.text+="\n"+notice

# The operator's own frame is off on the seat: the field kit is ticked here,
# its hands put in the lap of the bench and drawn with the compartment.
func bench_work(delta: float) -> void:
 var rig: FieldRig=game.player.field_rig
 var tx: MagazineTransfer=game.inventory.transfer
 # Out through the doors with the squad: the magazine goes into the pouch
 # as it is.
 if exiting() and tx.active:
  tx.cancel()
  game.squad.tell("Спорядження магазина перервано: вихід із машини")
 var working: bool=station()=="troop" and not exiting() and rig.active()
 if working:
  var cabin:=vehicle.cabin()
  var part:=cabin.holder("troop")
  if not is_instance_valid(lap) or lap.get_parent()!=part:
   if is_instance_valid(lap):lap.queue_free()
   lap=Node3D.new();lap.name="PassengerLap";part.add_child(lap)
  lap.transform=Transform3D(Basis(Vector3.UP,cabin.facing("troop"))*Basis(Vector3.RIGHT,LAP_PITCH),cabin.eye("troop")+Vector3(0,-0.04,0))
  rig.seat_in(lap,BmpArt.INTERIOR_LAYER)
  # The eyes go down to the hands as the work begins.
  if tx.active and not was_working:glance=0.6
 elif rig.seated:rig.stand_up()
 was_working=working and tx.active
 if glance>0.0:
  glance=maxf(0.0,glance-delta)
  look=look.lerp(WORK_LOOK,clampf(delta*6.0,0.0,1.0))
 rig.tick(delta)

func work_text() -> String:
 var tx: MagazineTransfer=game.inventory.transfer
 if not tx.active:return ""
 if tx.box_bag!=null and tx.draw_left>0:return "ПАЧКА З НАПЛІЧНИКА"
 if tx.moved>=tx.planned:return "МАГАЗИН У ПІДСУМОК"
 return "СПОРЯДЖЕННЯ МАГАЗИНА · %d / %d · TAB — ІНВЕНТАР, «ЗУПИНИТИ»" % [int(tx.destination.rounds),int(tx.weapon.data.capacity)]

func read_controls(delta: float) -> void:
 var v:=vehicle
 if game.commands_open:
  v.throttle=0.0;v.yoke_input=0.0
  return
 var gas:=Input.is_action_pressed("forward")
 v.throttle=move_toward(v.throttle,1.0 if gas else 0.0,delta*(1.8 if gas else 3.5))
 v.brake_pedal=move_toward(v.brake_pedal,1.0 if Input.is_action_pressed("back") else 0.0,delta*3.0)
 var pedal:=Input.is_physical_key_pressed(KEY_SHIFT)
 v.clutch_pedal=move_toward(v.clutch_pedal,1.0 if pedal else 0.0,delta*(4.0 if pedal else 1.3))
 # The yoke turns right for a positive deflection.
 v.yoke_input=float(Input.is_action_pressed("right"))-float(Input.is_action_pressed("left"))
 v.starter=Input.is_physical_key_pressed(KEY_X) and v.starter

func instrument_text() -> String:
 var v:=vehicle
 var kmh:=v.speed()*3.6
 var lines:="%s · %4d об/хв · %3d км/год · ПЕРЕДАЧА %s" % ["ДВИГУН ПРАЦЮЄ" if v.running else ("ПУСК…" if v.starter else "ДВИГУН ЗАГЛУШЕНО"),roundi(v.steady_rpm()),roundi(kmh),BmpVehicle.GEAR_NAMES[v.gear]]
 var pedal:=v.clutch_engagement()
 var states: Array[String]=[]
 states.append("МАСА" if v.master else "МАСА ВИМК.")
 states.append("ФРИКЦІОН %s" % ("ВИЖАТО" if pedal<0.05 else ("ПРОБУКСОВУЄ" if pedal<0.95 else "ВІДПУЩЕНО")))
 if v.parking:states.append("СТОЯНКОВЕ")
 if absf(v.yoke)>0.04:states.append("ШТУРВАЛ %s %d%%" % ["ПРАВО" if v.yoke>0 else "ЛІВО",roundi(absf(v.yoke)*100)])
 states.append("ЛЮК %s" % ("ВІДКРИТО" if v.hatch_open else "ЗАКРИТО"))
 if v.radio_on:states.append("РАДІО «%s»" % BmpVehicle.RADIO_TRACKS[v.radio_track][1])
 if v.immobile:states.append("ХОДОВУ ПОШКОДЖЕНО")
 return lines+"\n"+" · ".join(states)

func hint_text() -> String:
 if seat=="driver":
  return "W ПАЛИВО  S ГАЛЬМО  A/D ШТУРВАЛ  SHIFT ГОЛОВНИЙ ФРИКЦІОН  Q/E ПЕРЕДАЧА  I МАСА  X СТАРТЕР  SPACE СТОЯНКОВЕ\nV ЛЮК  R РАДІО  %s  1 ДЕСАНТ  2 ПО МІСЦЯХ  3 ЗА БМП  4 ШТУРМ РОЗСИПОМ  G КОМАНДИ  F ВИЙТИ" % ("ПКМ ЩИТОК" if vehicle.hatch_open else "МИША ОГЛЯД  ПКМ НА ПРИЗМІ — ДИВИТИСЯ, НА ЩИТКУ — ЩИТОК")
 if exiting():return "ВИХІД ЧЕРЕЗ ПРАВІ ДВЕРІ…"
 if head_out:return "ЛКМ ВОГОНЬ  ПКМ ПРИЦІЛ  R ПЕРЕЗАРЯДИТИ  ·  V — СХОВАТИСЯ В ДЕСАНТНЕ ВІДДІЛЕННЯ  ·  F — ВИЙТИ (НА ЗУПИНЦІ)  ·  M — КАРТА"
 var work:=work_text()
 if work!="":return work+"\nМИША — ОГЛЯД  ·  F — ВИЙТИ (НА ЗУПИНЦІ)"
 return "МИША — ОГЛЯД  ·  ПКМ НА ПРИЗМІ — ДИВИТИСЯ  ·  V — ВИГЛЯНУТИ З ЛЮКА З АВТОМАТОМ  ·  TAB — СПОРЯДИТИ МАГАЗИНИ  ·  F — ВИЙТИ (НА ЗУПИНЦІ)  ·  M — КАРТА"

# The passenger climbs in through an open door of his squad's vehicle.
func troop_prompt() -> String:
 if driver_class() or seat!="" or not active() or vehicle.destroyed or not game.battle.active:return ""
 # Seven men and the passenger: the eighth place is his (BmpTroops).
 if vehicle.doors<0.6 or absf(vehicle.speed())>0.8:return ""
 var from: Vector3=game.player.global_position
 for i in [0,1]:
  if from.distance_to(vehicle.exit_point(i))<REACH+0.6:return "F — СІСТИ В ДЕСАНТ БМП-%d" % (squad.index+1 if is_instance_valid(squad) else 1)
 return ""

func station_prompt() -> String:
 if not active() or vehicle.destroyed:return ""
 var from: Vector3=game.player.global_position
 if from.distance_to(vehicle.to_global(Vector3(-1.6,0.4,-1.3)))<REACH:return "F — МІСЦЕ МЕХАНІКА-ВОДІЯ"
 return ""

func squad_status() -> String:
 if not is_instance_valid(squad):return ""
 var phase: String={"field":"СПІШЕНІ БІЛЯ МАШИНИ","mounted":"ДЕСАНТ У МАШИНІ","dismount":"СПІШУВАННЯ","guard":"КРУГОВА ОБОРОНА ЗА КОРМОЮ","file":"КОЛОНОЮ ЗА БМП","assault":"ШТУРМ РОЗСИПОМ","mount":"ПОСАДКА","afoot":"ПІШКИ, БЕЗ МАШИНИ"}.get(squad.state,squad.state.to_upper())
 return "ВІДДІЛЕННЯ · %s · У МАШИНІ %d · ПІШКИ %d · ДО БОЮ ЗДАТНІ %d" % [phase,squad.aboard().size(),squad.on_foot().size(),squad.living()]

func column_text() -> String:
 if not is_instance_valid(squad):return ""
 match squad.state:
  "wait":return "ОЧІКУЄ НАКАЗУ" if game.battle.awaiting else "ВИШИКОВУЄТЬСЯ"
  "march":return "МАРШ · ДО СЕЛА %d м" % roundi(squad.driver.remaining())
  "approach","transfer":return "ВИХІД НА РУБІЖ СПІШУВАННЯ"
 return squad.state.to_upper()

# --- Commands ---------------------------------------------------------------
func toggle() -> void:
 if not game.running or game.paused:return
 if panel.visible:close();return
 if not is_instance_valid(squad) or not driver_class():return
 game.commands_open=true
 game.player.burst=0
 game.player.firing_sequence_active=false
 caption.text=squad_status()
 panel.show()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func close() -> void:
 if not is_instance_valid(panel) or not panel.visible:return
 panel.hide()
 game.commands_open=false
 if game.running and not game.paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func command(id: String) -> void:
 close()
 if not is_instance_valid(squad) or not game.running:return
 match id:
  "dismount":squad.order_dismount()
  "mount":squad.order_mount()
  "file":squad.order_file()
  "assault":
   var aim:=aim_point()
   squad.order_assault(aim,Vector3(aim.x-vehicle.global_position.x,0,aim.z-vehicle.global_position.z))

# Where the squad storms: the point the player looks at, or 60 m ahead of
# the vehicle.
func aim_point() -> Vector3:
 var camera: Camera3D=vehicle.seat_camera if seat!="" else game.player.camera
 var from:=camera.global_position
 var to:=from-camera.global_basis.z*250.0
 var hit:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1,[vehicle.get_rid()]))
 if not hit.is_empty():return hit.position
 var ahead:=vehicle.global_position-vehicle.global_basis.z*60.0
 ahead.y=game.district.ground_height(ahead)
 return ahead

func _input(event: InputEvent) -> void:
 if not active() or not game.running or game.paused:return
 if game.battle.active and game.battle.respawn_left>0:return
 # Over the map sheet its own keys work (N, M, Esc).
 if game.topo_map.visible:return
 if not (event is InputEventKey or event is InputEventMouseMotion):return
 if event is InputEventKey and event.pressed and not event.echo:
  var key: int=event.physical_keycode
  if key==KEY_G and driver_class() and (seat!="" or not game.player.field_rig.active()):
   game.inventory.close();toggle();accept();return
  if panel.visible:
   if key==KEY_ESCAPE:close();accept();return
   for item in COMMANDS:
    if key==KEY_1+COMMANDS.find(item):command(item[0]);accept();return
   return
  if seat=="" and key==KEY_F and driver_class() and station_prompt()!="":
   if absf(vehicle.speed())>1.5:vehicle.say("На ходу в машину не сідають",2);accept();return
   enter("driver");accept();return
  if seat=="" and key==KEY_F and troop_prompt()!="":
   enter("troop")
   game.squad.tell("Ти в десанті БМП-%d, з відділенням · V — виглянути з люка · F — вийти на зупинці" % (squad.index+1))
   accept();return
 if seat=="":return
 # Head out the operator looks and aims himself.
 if head_out and event is InputEventMouseMotion:return
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  # At the eyepiece the face stays where it is; on the way out the eyes
  # look where he goes.
  if lean>0.0 or press=="lean" or exiting():accept();return
  var s: float=game.player.sensitivity
  var limits:=look_limits()
  look.x=clampf(look.x-event.relative.x*s,limits.x,limits.y)
  look.y=clampf(look.y-event.relative.y*s,limits.z,limits.w)
  accept();return
 if not (event is InputEventKey) or not event.pressed or event.echo:return
 match event.physical_keycode:
  KEY_F:
   if absf(vehicle.speed())>1.5:vehicle.say("На ходу не виходять: зупинись",2)
   elif seat=="troop":
    if head_out:set_head_out(false)
    vehicle.troops.unload_player()
   else:leave()
  KEY_M,KEY_TAB:return
  KEY_V when seat=="troop":set_head_out(not head_out)
  _:
   if seat!="driver":
    if event.physical_keycode in [KEY_ESCAPE,KEY_F11]:return
    # In the hatch: the rifle, the magazines and the rangefinder, but not
    # stance, the launcher, the drone or the mortar.
    if head_out and not (event.is_action("crouch") or event.is_action("prone") or event.is_action("jump") or event.is_action("sprint") or event.physical_keycode in [KEY_4,KEY_J,KEY_U,KEY_N,KEY_G]):return
    accept();return
   match event.physical_keycode:
    KEY_E:vehicle.shift(1)
    KEY_Q:vehicle.shift(-1)
    KEY_I:vehicle.toggle_master()
    KEY_X:vehicle.begin_crank()
    KEY_SPACE:vehicle.toggle_parking()
    KEY_V:vehicle.toggle_hatch()
    KEY_R:vehicle.toggle_radio()
    KEY_1:command("dismount")
    KEY_2:command("mount")
    KEY_3:command("file")
    KEY_4:command("assault")
    _:return
 accept()

func accept() -> void:get_viewport().set_input_as_handled()

func close_panels() -> void:close()
