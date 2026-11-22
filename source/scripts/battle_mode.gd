class_name BattleMode
extends Node

# Soldiers on each side: whole mechanized squads, one BMP-2 each — the
# driver-mechanic, the gunner-operator and seven men who dismount.
const SQUAD := 9
const SIZES := [18,27,36,54]
# The size chosen in the menu is ours; the enemy holds the village with three
# times as many. The menu does not say how many.
const ENEMY_RATIO := 3
# The rifleman's and the sniper's start: the squads stand dismounted on the
# field by their vehicles in the column's place, the battery of three «Grads»
# lays on the strongpoints and fires on the order, then «По машинах!» and
# the column moves off. The column waits this long for the player to board.
const MOUNT_PATIENCE := 90.0
const FIRE_DELAY := 2.4
# Seconds without a defender on his feet before a strongpoint, or the whole
# village, counts as cleared: a soldier knocked down for a moment is not yet
# out of the fight.
const CLEAR_TIME := 3.0
# Seconds before the commander's role passes to a soldier already on the field.
const TAKEOVER_TIME := 5.0
# Share of the defenders on posts scattered over the village in pairs; the
# rest hold the three strongpoints.
const SCATTERED_SHARE := 0.3
# Scattered posts keep this far from the attackers' start line, and this far
# from the middle of a strongpoint.
const POST_STANDOFF := 100.0
const POST_APART := 55.0
# Roles in a squad of ours (the seven who dismount, in seat order): the
# machine gunner, the grenadier with the RPG-7, two riflemen with RPG-22, the
# squad's sniper; every other squad has a drone pilot in place of a rifleman.
const SQUAD_KITS := ["mg","rpg7","rpg22","rifle","rpg22","sniper","rifle"]
# Roles of the defenders of a strongpoint in the order they take its posts:
# two machine guns, the grenadier, a sniper, a drone pilot, RPG-22 among the
# riflemen; on the scattered posts one of each pair has an RPG-22.
const DEFENCE_KITS := ["mg","rpg7","rifle","sniper","rpg22","mg","uav","rifle","rpg22","rifle","rifle","rpg22"]
var game: Node3D
var active := false
var finished := false
# Strongpoint the attackers storm now; -1 once all three are destroyed and
# they mop up the posts left in the village.
var sector := 0
var cleared: Array[bool]=[false,false,false]
var clear_timers: Array[float]=[0.0,0.0,0.0]
var last_cleared := -1
var quiet := 0.0
var enemy_total := 0
# Posts of the defenders left after the strongpoints, nearest to the
# attackers first.
var sweep: Array[Vector3]=[]
var respawn_left := 0.0
var command_left := 0.0
var serial := 0
var corpses: Array[Hostile]=[]
var panel: Control
var result_reason := ""
var budget_frame := -1
var cover_budget := 2
var path_budget := 4
var peak_cover_queries := 0
var peak_path_queries := 0
var crowd: CrowdRenderer
# Only a mortarman controls the assault: it starts held until his order and he
# can halt it (consolidate, wait for the end of the barrage) and resume it.
var halted := false
var awaiting := false
# The mechanized squads in column order; the column moves off on the order.
var mech: Array[MechSquad]=[]
var column_go := false
var vehicle_grid: AStarGrid2D
# "" (none or over), "barrage" (the squads wait while the battery fires) or
# "mount" (they board their vehicles).
var prep := ""
var prep_time := 0.0
var fire_at := -1.0
var done_at := -1.0
var held_said := false
var drive_warned := false
var battery: GradBattery
var armour: EnemyArmour
# The skipped start (F6 twice): the battery's fire, the boarding and the
# column's ride fast-forwarded behind a black screen.
const SKIP_WINDOW := 4.0
# The salvo under the black screen goes this many times faster than in the
# open: the launches, the rockets' flight, not the defenders.
var skip_pace := 8
const SKIP_STATES := ["field","board","mount","mounted","wait","march","approach"]
var skip_armed := 0.0
var skipping := false
var skip_token := 0
var skip_screen: CanvasLayer
var skip_shade: Control
var skip_note: Label
# Marks over the player's squad and over his vehicle when it is boarded.
var marks: Array[Sprite3D]=[]
var vehicle_mark: Label3D
static var mark_texture: ImageTexture

func setup(owner_game: Node3D) -> void:
 game=owner_game

func reset() -> void:
 for actor in corpses:
  if is_instance_valid(actor):actor.queue_free()
 if is_instance_valid(crowd):
  crowd.clear_all();crowd.queue_free()
 crowd=null
 active=false;finished=false;corpses.clear();respawn_left=0
 halted=false;awaiting=false;column_go=false
 prep="";prep_time=0.0;fire_at=-1.0;done_at=-1.0;held_said=false
 end_skip()
 # Stopped at once: a new start frees the world with the launchers in it
 # before the battery itself is gone.
 if is_instance_valid(battery):battery.process_mode=Node.PROCESS_MODE_DISABLED;battery.queue_free()
 battery=null
 marks.clear();vehicle_mark=null
 for squad in mech:
  if is_instance_valid(squad):
   if is_instance_valid(squad.vehicle):squad.vehicle.gunner.clear();squad.vehicle.queue_free()
   squad.queue_free()
 mech.clear()
 if is_instance_valid(armour):armour.clear();armour.queue_free()
 armour=null
 vehicle_grid=null

func start() -> void:
 reset();active=true;serial=0
 command_left=0;result_reason=""
 cleared=[false,false,false];clear_timers=[0.0,0.0,0.0];last_cleared=-1;quiet=0;sweep.clear()
 budget_frame=-1;peak_cover_queries=0;peak_path_queries=0
 crowd=CrowdRenderer.new();game.add_child(crowd);crowd.setup(game,enemies(game.battle_size)+32)
 for actor in game.allies:
  actor.set_meta("battle_personal",true)
  crowd.register(actor)
 # Both armies are on the field from the first second and nobody arrives
 # later: every casualty is final. Defenders hold the three strongpoints and
 # the posts between them; the attackers form up in front of the insertion,
 # the commander behind them.
 # The vehicles' map first: a BMP-2 of theirs at each strongpoint, its crew
 # beside it, counted in the defenders' strength.
 vehicle_grid=BmpRoutes.vehicle_grid(game.district)
 armour=EnemyArmour.new();armour.setup(game,self);armour.deploy()
 var defenders:=defence_counts(maxi(0,enemies(game.battle_size)-game.bots.size()))
 for index in range(3):
  for i in range(defenders[index]):deploy(false,index)
 deploy_posts(defenders[3])
 enemy_total=game.bots.size()
 sector=next_target(formation_base(true,0))
 # The attackers come up in their vehicles: the column waits under the
 # trees by the highway; the player's own vehicle, if he drives one, leads.
 for i in range(1 if game.player_class=="bmp" else 0,squad_count(game.battle_size)):deploy_squad(i)
 # Every class but the BM-21 commander starts with the battery's fire; the
 # column moves off after it.
 if barrage_class(game.player_class) and (not mech.is_empty() or game.player_class=="bmp"):prep="barrage"
 game.bmp.start_battle(self)
 if game.player_class=="mortarman":place_mortar_crew()
 if game.player_class in ["mortarman","grad"]:
  set_halt(true);awaiting=true
  game.squad.tell("Штурм очікує твоєї команди · G — %s" % ("радіо" if game.player_class=="grad" else "розрахунок"))
 column_go=not awaiting
 if prep!="":begin_field()
 mark_squad()

static func enemies(size: int) -> int:return size*ENEMY_RATIO

# The mortar crew starts on its firing position (BattleMap.MORTAR), not on
# the old start line at the forest strip: that was 190 m from the nearest
# strongpoint, in sight of the posts and inside the ground the opening
# salvo of the «Grads» lands on. The mortarman faces the village, the
# assistant beside him with the baseplate and the box of mines.
func place_mortar_crew() -> void:
 var spot:=mortar_position()
 var toward:=center(1)-spot;toward.y=0
 var yaw:=atan2(-toward.x,-toward.z)
 game.player.global_position=spot+Vector3.UP*0.12;game.player.rotation.y=yaw;game.player.velocity=Vector3.ZERO
 var helper: Hostile=game.crew.assistant
 if is_instance_valid(helper):
  var at:=spot+Basis(Vector3.UP,yaw)*Vector3(2.4,0,1.2)
  at.y=game.district.ground_height(at)+0.15
  helper.global_position=at;helper.rotation.y=yaw;helper.velocity=Vector3.ZERO
  helper.order_point=at;helper.has_cover=false
  game.crew.assistant_point=at
 game.squad.trail=PackedVector3Array([spot])
 if is_instance_valid(game.district.operation_area):game.district.operation_area.stream(spot,40)

func mortar_position() -> Vector3:
 return BmpRoutes.flat(BattleMap.MORTAR,game.district)

# On foot with the squad by its vehicle at the start.
static func field_class(id: String) -> bool:return id in PlayerClass.INFANTRY
# The start with the battery's fire: all but the BM-21 commander, who is
# himself the fire.
static func barrage_class(id: String) -> bool:return id in PlayerClass.INFANTRY+["bmp","mortarman"]

# --- The start on the field: the battery's fire, then «По машинах!» ----------
func begin_field() -> void:
 prep="barrage";prep_time=0.0;fire_at=-1.0;done_at=-1.0;held_said=false;drive_warned=false
 column_go=false
 for squad in mech:squad.form_up()
 if field_class(game.player_class):game.bmp.stand_by_vehicle()
 game.district.operation_area.stream(mech[0].vehicle.global_position,40)
 battery=GradBattery.new()
 add_child(battery)
 battery.setup(game,self)
 match game.player_class:
  "bmp":game.squad.tell("Колона стоїть, десант спішений: спершу б'ють «Гради» · на КПК — «Гради» і село · рушай після «Колона — вперед!»")
  "mortarman":game.squad.tell("Вогнева позиція за 0,8 км від села · спершу б'ють «Гради» · на КПК — «Гради» і село · потім десант сідає, і колона чекає твоєї команди · G — розрахунок")
  _:game.squad.tell("Відділення спішене біля БМП-1 · чекай команди · на КПК — «Гради» і село")

func barrage_shown() -> bool:return prep=="barrage" and is_instance_valid(battery)

func tick_prep(delta: float) -> void:
 prep_time+=delta
 # The driver at the head of the column is told once to stand fast.
 if game.player_class=="bmp" and not drive_warned and is_instance_valid(game.bmp.vehicle) and absf(game.bmp.vehicle.speed())>1.5:
  drive_warned=true
  game.squad.tell("Стояти! Колона рушає лише після «Колона — вперед!»" if prep=="barrage" else "Стояти! Твій десант ще сідає")
 if prep=="barrage":
  if not held_said and prep_time>1.5:held_said=true;game.radio_voice.say("hold")
  if fire_at<0.0 and battery.all_ready() and prep_time>8.0:
   fire_at=prep_time+FIRE_DELAY
   game.radio_voice.say("grad_fire")
  if fire_at>=0.0 and not battery.ordered and prep_time>=fire_at:battery.fire()
  if battery.finished():
   if done_at<0.0:done_at=prep_time
   elif prep_time-done_at>2.5:begin_mount()
  return
 # Boarding: the column moves off once every squad is in, the player too
 # (or he is left behind after a while).
 var boarded:=true
 for squad in mech:
  if squad.state in ["field","board"]:boarded=false
  # The driver's own men climb into his vehicle while it stands.
  if squad.player_led and squad.state=="mount" and prep_time<MOUNT_PATIENCE:boarded=false
 if boarded:finish_prep()

func begin_mount() -> void:
 prep="mount";prep_time=0.0
 game.radio_voice.say("mount_up")
 for squad in mech:squad.mount_up()
 stand_battery()
 match game.player_class:
  "bmp":game.squad.tell("«По машинах!» · стій, поки твій десант сідає: двері відчинені")
  "mortarman":game.squad.tell("«По машинах!» · десант сідає в БМП")
  _:game.squad.tell("«По машинах!» · БМП-1 — твоя машина · F біля кормових дверей")

# The player's squad keeps its doors open for him.
func waiting_for_player(squad: MechSquad) -> bool:
 return field_class(game.player_class) and prep=="mount" and game.bmp.squad==squad and game.bmp.seat!="troop" and prep_time<MOUNT_PATIENCE and is_instance_valid(game.player) and game.player.health>0 and not game.player.get_meta("battle_out",false)

func finish_prep() -> void:
 prep=""
 column_go=not halted
 # The mortarman's assault waits for his word; the column with it.
 if halted:
  game.squad.tell("Десант на броні · колона чекає твоєї команди · G — розрахунок")
  return
 game.radio_voice.say("column")
 if game.player_class=="bmp":game.squad.tell("«Колона — вперед!» · ти ведеш: польовою дорогою до траси й на північ, до села ~2 км")
 elif field_class(game.player_class) and game.bmp.seat!="troop":game.squad.tell("Колона рушила без тебе")

# --- Marks over the player's squad ------------------------------------------------
static func mark_image() -> ImageTexture:
 if mark_texture!=null:return mark_texture
 var image:=Image.create(32,32,false,Image.FORMAT_RGBA8)
 for y in range(32):
  for x in range(32):
   # A chevron pointing down: dark rim, light green inside.
   var half:=15.5-float(y)*0.5
   var dx:=absf(float(x)-15.5)
   if y>=2 and y<=30 and dx<=half:image.set_pixel(x,y,Color(0.55,0.95,0.55,1.0) if dx<=half-2.2 and y>=4 else Color(0.03,0.08,0.03,0.9))
 mark_texture=ImageTexture.create_from_image(image)
 return mark_texture

func mark_squad() -> void:
 for mark in marks:
  if is_instance_valid(mark):mark.queue_free()
 marks.clear()
 if is_instance_valid(vehicle_mark):vehicle_mark.queue_free()
 vehicle_mark=null
 var squad: MechSquad=game.bmp.squad
 if not is_instance_valid(squad):return
 for actor in squad.members:
  var mark:=Sprite3D.new()
  mark.name="SquadMark"
  mark.texture=mark_image()
  mark.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  mark.no_depth_test=true
  mark.fixed_size=true
  mark.pixel_size=0.00055
  mark.render_priority=10
  mark.shaded=false
  mark.position=Vector3(0,2.3,0)
  actor.add_child(mark)
  marks.append(mark)
 vehicle_mark=Label3D.new()
 vehicle_mark.name="BoardMark"
 vehicle_mark.text="БМП-%d · ПО МАШИНАХ" % (squad.index+1)
 vehicle_mark.font_size=40;vehicle_mark.outline_size=10
 vehicle_mark.modulate=Color(0.65,1.0,0.6);vehicle_mark.outline_modulate=Color(0,0,0,0.85)
 vehicle_mark.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 vehicle_mark.no_depth_test=true;vehicle_mark.fixed_size=true;vehicle_mark.pixel_size=0.0006
 vehicle_mark.render_priority=10
 vehicle_mark.position=Vector3(0,3.4,1.5)
 vehicle_mark.hide()
 squad.vehicle.add_child(vehicle_mark)

func update_marks() -> void:
 var seated: bool=game.bmp.seat!=""
 for mark in marks:
  if not is_instance_valid(mark):continue
  var actor:=mark.get_parent() as Hostile
  mark.visible=not seated and operational(actor) and actor.vehicle==null
 # The vehicle of the squad is marked all the time the player is out of
 # it, louder when it waits for him.
 if is_instance_valid(vehicle_mark):
  var squad: MechSquad=game.bmp.squad
  var boarding: bool=is_instance_valid(squad) and (waiting_for_player(squad) or (squad.state=="pickup" and squad.vehicle.doors>0.5))
  var text:="БМП-%d · ПО МАШИНАХ" % (squad.index+1) if boarding else "БМП-%d · ТВОЯ" % (squad.index+1)
  if vehicle_mark.text!=text:
   vehicle_mark.text=text
   vehicle_mark.modulate=Color(0.65,1.0,0.6) if boarding else Color(0.65,1.0,0.6,0.7)
   vehicle_mark.font_size=40 if boarding else 30
  vehicle_mark.visible=not seated and not squad.vehicle.destroyed and is_instance_valid(game.player) and not game.player.get_meta("battle_out",false)

static func squad_count(size: int) -> int:return maxi(1,int(size/SQUAD))

# A mechanized squad in its vehicle at its place in the column: the crew in
# their seats, seven men in the troop compartment.
func deploy_squad(index: int) -> MechSquad:
 var vehicle:=BmpVehicle.new()
 game.world_root.add_child(vehicle)
 vehicle.setup(game,str(index+1))
 place_vehicle(vehicle,BmpRoutes.parking(index,game.district))
 var squad:=MechSquad.new()
 add_child(squad)
 squad.setup(game,self,index,vehicle)
 register_squad(squad)
 var spot:=vehicle.global_position
 for role in ["driver","gunner"]:
  var actor:=spawn_soldier(true,spot,index)
  vehicle.board_crew(actor,role)
 for k in range(BmpVehicle.SEATS):
  var actor:=spawn_soldier(true,spot,index)
  var role: String=SQUAD_KITS[k%SQUAD_KITS.size()]
  if k==6 and index%2==0:role="uav"
  actor.set_kit(role)
  squad.members.append(actor)
  vehicle.board(actor)
 return squad

# For the tests of the infantry assault: the column has already arrived —
# every squad is out on the start line in front of the insertion as the
# groups formed up before the BMPs, the vehicles behind it in support.
func skip_approach() -> void:
 var serial_before:=serial
 serial=0
 var afoot:=prep!=""
 if afoot:
  prep=""
  if is_instance_valid(battery):battery.queue_free()
  battery=null
 for squad in mech:
  squad.gunner_in_now()
  for actor in squad.on_foot():Idle.stop(actor)
  if squad.player_led:
   # The driver's men back in his vehicle.
   for actor in squad.on_foot():squad.control(actor,false);squad.vehicle.board(actor)
   squad.vehicle.open_doors(false)
   if squad.state in ["field","mount"]:squad.set_state("mounted")
   continue
  var vehicle:=squad.vehicle
  var spot:=formation_base(true,0)+BattleMap.offset(float(squad.index%3-1)*34.0,38.0+float(squad.index/3)*14.0)
  spot.y=game.district.ground_height(spot)
  vehicle.parking=true;vehicle.freeze=false
  place_vehicle(vehicle,Transform3D(Basis.looking_at(Vector3(BattleMap.north().x,0,BattleMap.north().y),Vector3.UP),spot))
  vehicle.linear_velocity=Vector3.ZERO;vehicle.angular_velocity=Vector3.ZERO
  for actor in vehicle.crew:actor.global_position=vehicle.global_position+vehicle.global_basis.y*0.9
  vehicle.open_doors(false)
  for actor in squad.aboard()+squad.on_foot():
   var point:Variant=safe_spawn(true,0)
   if point==null:point=formation_base(true,0)+BattleMap.offset(randf_range(-6,6),randf_range(-3,3))+Vector3.UP*0.05
   vehicle.aboard.erase(actor)
   actor.disembark(point,Vector3(-BattleMap.north().x,0,-BattleMap.north().y))
   actor.rotation.y=BattleMap.facing(true)
   squad.control(actor,false)
   serial+=1
  squad.drop=vehicle.global_position
  squad.goal_sector=sector
  squad.set_state("assault")
  for actor in squad.on_foot():assign(actor)
 serial=maxi(serial,serial_before)
 column_go=true
 # A passenger gets out with them; one still on the field by the column
 # is put behind his vehicle as if he had got out there.
 if game.bmp.seat=="troop":game.bmp.leave()
 elif afoot and is_instance_valid(game.bmp.vehicle) and game.bmp.seat=="":
  var spot:Vector3=game.bmp.vehicle.exit_point(0)+game.bmp.vehicle.global_basis.z*0.6
  spot.y=game.district.ground_height(spot)+0.05
  game.player.global_position=spot
  game.player.rotation.y=BattleMap.facing(true)

# For the tests of the ride: the battery has fired and everybody is aboard —
# the squads in their vehicles, the player in the lead one's troop
# compartment — as the old start had it.
func skip_field() -> void:
 if prep=="":return
 if is_instance_valid(battery):battery.queue_free()
 battery=null
 board_now()
 prep=""
 column_go=not halted
 if is_instance_valid(game.bmp.vehicle) and game.bmp.seat=="" and field_class(game.player_class):game.bmp.enter("troop")

# Everybody aboard at once: the gunners in their turrets, the men in the
# troop compartments, the doors shut.
func board_now() -> void:
 for squad in mech:
  squad.gunner_in_now()
  for actor in squad.on_foot():
   Idle.stop(actor)
   squad.control(actor,false)
   squad.vehicle.board(actor)
  squad.vehicle.open_doors(false)
  if squad.state in ["field","board","mount"]:squad.set_state("mounted" if squad.player_led else "wait")

# --- The skipped start: F6 twice --------------------------------------------
# The player may fast-forward what he only watches: the battery's fire, the
# boarding and the column's ride to the dismount line. Behind a black screen
# the launchers fire off their packages and the rockets fly and burst as in
# the open (unseen and unheard), the men board at once, and each vehicle is
# put where its ride would have ended: at its drop point in the village, the
# doors opening. The mortarman's halted column boards and waits for his word;
# once he gives it, the march can be skipped too.
func can_skip() -> bool:
 if not active or finished or skipping or respawn_left>0:return false
 if prep!="":return true
 if not column_go or halted:return false
 # The driver himself: while his vehicle is still far from the village.
 if game.player_class=="bmp":
  var own: BmpVehicle=game.bmp.vehicle
  if not is_instance_valid(own) or own.destroyed or own.immobile or game.bmp.seat!="driver":return false
  if not is_instance_valid(game.bmp.squad) or not game.bmp.squad.state in SKIP_STATES:return false
  var end: Vector2=BmpRoutes.CORRIDOR[-1]
  var at:=Vector2(own.global_position.x,own.global_position.z)
  return at.distance_to(end)>300.0 and maxf(absf(at.x),absf(at.y))>230.0
 for squad in mech:
  if squad.state in ["wait","march","approach"] and movable(squad):return true
 return false

func movable(squad: MechSquad) -> bool:
 return is_instance_valid(squad.vehicle) and not squad.vehicle.destroyed and not squad.vehicle.immobile

# What the skip leaves out, for the hints.
func skip_text() -> String:
 if prep!="":return "ОБСТРІЛ І ПОСАДКУ" if halted else "ОБСТРІЛ І МАРШ ДО ВИСАДКИ"
 return "МАРШ ДО ВИСАДКИ"

func _input(event: InputEvent) -> void:
 if not (event is InputEventKey) or not event.pressed or event.echo or event.physical_keycode!=KEY_F6:return
 if not game.running or game.paused or game.inventory_open:return
 if is_instance_valid(game.topo_map) and game.topo_map.visible:return
 if is_instance_valid(game.crew) and (game.crew.panel.visible or game.crew.sight.visible):return
 if not can_skip():return
 get_viewport().set_input_as_handled()
 if skip_armed<=0.0:
  skip_armed=SKIP_WINDOW
  game.squad.tell("F6 ще раз — пропустити %s" % skip_text().to_lower())
  return
 skip_armed=0.0
 skip_start()

func skip_start() -> void:
 if not can_skip():return
 var barrage:=prep!=""
 var title:="ПРИСКОРЕННЯ: ЗАЛП «ГРАДІВ» · ПОСАДКА" if barrage else "ПРИСКОРЕННЯ: МАРШ КОЛОНИ"
 if barrage and not halted:title+=" · МАРШ КОЛОНИ"
 skipping=true
 skip_token+=1
 var token:=skip_token
 open_skip_screen(title)
 game.radio_voice.hush()
 if not await skip_fade(token,1.0,0.35):return
 if barrage:
  # The salvo, laid at once and fired at its own rhythm, only faster; the
  # bursts as in the open.
  if is_instance_valid(battery):battery.rush()
  for i in range(60*60):
   if not is_instance_valid(battery) or battery.finished():break
   if not await skip_frame(token):return
   if not is_instance_valid(battery):break
   battery.hasten(skip_pace,get_physics_process_delta_time())
   var total:=0
   for vehicle in battery.launchers:
    if is_instance_valid(vehicle):total+=vehicle.fired+vehicle.remaining()
   if is_instance_valid(skip_note):skip_note.text="«ГРАДИ»: ПУСКІВ %d / %d · РАКЕТ У ПОВІТРІ %d" % [battery.fired(),total,battery.in_flight()]
  stand_battery()
  board_now()
  prep="";prep_time=0.0
  column_go=not halted
 var own: MechSquad=game.bmp.squad
 var own_out:=false
 if halted:
  game.squad.tell("Десант на броні · колона чекає твоєї команди · G — розрахунок")
  if is_instance_valid(skip_note):skip_note.text="ДЕСАНТ НА БРОНІ · КОЛОНА ЧЕКАЄ КОМАНДИ"
 else:
  arrive_all()
  if is_instance_valid(skip_note):skip_note.text="КОЛОНА НА РУБЕЖІ СПІШУВАННЯ"
  own_out=is_instance_valid(own) and not own.player_led and own.state in ["dismount","file"]
 # Black a moment longer while the vehicles settle where they were put.
 if not await skip_fade(token,1.0,0.6):return
 if not await skip_fade(token,0.0,0.6):return
 end_skip()
 # The squad's own order, heard as the picture comes back (MechSquad.voice
 # keeps quiet during the skip).
 if own_out:game.radio_voice.say("dismount")

# The squads on their way, in column order, each put at its drop point.
func arrive_all() -> void:
 var own: MechSquad=game.bmp.squad
 # The player with his squad, in its troop compartment (back in, if he got
 # out on the way).
 if field_class(game.player_class) and is_instance_valid(own) and own.state in SKIP_STATES and movable(own) and game.bmp.seat=="" and is_instance_valid(game.player) and game.player.health>0 and not game.player.get_meta("battle_out",false):
  game.bmp.enter("troop")
 for squad in mech:
  if squad.state in SKIP_STATES and movable(squad):arrive(squad)
 if is_instance_valid(game.district.operation_area):game.district.operation_area.stream(game.player.global_position,60)
 match game.player_class:
  "bmp":game.squad.tell("Колона на рубежі спішування · 1 — «Десант»")
  "mortarman","grad":game.squad.tell("Колона на рубежі спішування · групи висаджуються")
  _:if game.bmp.seat=="troop":game.squad.tell("Колона на рубежі спішування · десант виходить")

# One vehicle to the end of the column's road and on to a drop point, as
# MechSquad.enter_village picks it, and stopped there: the driver's route is
# cut to the spot, so he does not drive on to where the old one led.
func arrive(squad: MechSquad) -> void:
 var vehicle:=squad.vehicle
 var route:=PackedVector3Array()
 if squad.state=="approach" and squad.drop!=Vector3.INF and squad.driver.route.size()>=2:
  route=squad.driver.route
 else:
  var road:=BmpRoutes.approach(squad.index,game.district)
  put_vehicle(squad,road[-1],road[-1]-road[-2])
  if squad.player_led:
   squad.goal_sector=sector
   var taken: Array=[]
   for other in mech:
    if other!=squad and other.drop!=Vector3.INF:taken.append(other.drop)
   squad.drop=squad.pick_drop(squad.objective(),taken)
   route=squad.plan(squad.drop)
  else:
   squad.enter_village()
   if squad.state=="approach":route=squad.driver.route
 if squad.drop==Vector3.INF:squad.drop=vehicle.global_position
 var heading:=route[-1]-route[-2] if route.size()>=2 else squad.objective()-squad.drop
 put_vehicle(squad,squad.drop,heading)
 if squad.player_led:return
 squad.driver.set_route(PackedVector3Array([vehicle.global_position]),BmpRoutes.FIELD_SPEED,3.0)
 if squad.state=="dismount":squad.driver.stop()
 else:squad.begin_dismount("file")

func put_vehicle(squad: MechSquad, at: Vector3, heading: Vector3) -> void:
 var vehicle:=squad.vehicle
 heading.y=0.0
 if heading.length()<0.01:heading=-vehicle.global_basis.z;heading.y=0.0
 if not squad.player_led:vehicle.parking=true
 vehicle.freeze=false
 place_vehicle(vehicle,Transform3D(Basis.looking_at(heading.normalized(),Vector3.UP),at))
 vehicle.linear_velocity=Vector3.ZERO;vehicle.angular_velocity=Vector3.ZERO
 for actor in vehicle.crew:actor.global_position=vehicle.global_position+vehicle.global_basis.y*0.9

# The battery has done its work: it stands still from now on.
func stand_battery() -> void:
 if not is_instance_valid(battery):return
 for vehicle in battery.launchers:
  if is_instance_valid(vehicle):vehicle.engine_sound.stop();vehicle.process_mode=Node.PROCESS_MODE_DISABLED
 battery.process_mode=Node.PROCESS_MODE_DISABLED

func open_skip_screen(title: String) -> void:
 end_screen()
 skip_screen=CanvasLayer.new();skip_screen.name="SkipScreen";skip_screen.layer=2
 add_child(skip_screen)
 skip_shade=Control.new();skip_shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 skip_screen.add_child(skip_shade)
 skip_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 skip_shade.modulate.a=0.0
 var black:=ColorRect.new();black.color=Color(0.012,0.014,0.012);black.mouse_filter=Control.MOUSE_FILTER_IGNORE
 skip_shade.add_child(black);black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var text:Label=game.label(title,24,UiKit.INK)
 text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
 skip_shade.add_child(text);text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 text.anchor_bottom=0.5
 skip_note=game.label("",17,UiKit.MUTED)
 skip_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 skip_shade.add_child(skip_note);skip_note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 skip_note.anchor_top=0.5;skip_note.offset_top=14.0

# A frame of the skip; it waits out a pause with the screen out of the way of
# the pause menu. False once the skip is called off (a new start, the menu,
# the end of the battle).
func skip_frame(token: int) -> bool:
 await get_tree().physics_frame
 while token==skip_token and game.paused:
  if is_instance_valid(skip_screen):skip_screen.visible=false
  await get_tree().physics_frame
 if token!=skip_token:return false
 if not active or finished or not game.running:
  end_skip()
  return false
 if is_instance_valid(skip_screen):skip_screen.visible=true
 return true

# The screen to an opacity over a time of play.
func skip_fade(token: int, to: float, seconds: float) -> bool:
 var from:=skip_shade.modulate.a if is_instance_valid(skip_shade) else to
 var time:=0.0
 while time<seconds:
  if not await skip_frame(token):return false
  time+=get_physics_process_delta_time()
  if is_instance_valid(skip_shade):skip_shade.modulate.a=lerpf(from,to,clampf(time/seconds,0.0,1.0))
 return true

func end_screen() -> void:
 if is_instance_valid(skip_screen):skip_screen.queue_free()
 skip_screen=null;skip_shade=null;skip_note=null

func end_skip() -> void:
 skip_token+=1
 skipping=false;skip_armed=0.0
 end_screen()

# Column order: each squad follows the one before it.
func register_squad(squad: MechSquad) -> void:
 mech.append(squad)
 mech.sort_custom(func(a,b):return a.index<b.index)
 for i in range(mech.size()):mech[i].ahead=mech[i-1] if i>0 else null

func place_vehicle(vehicle: BmpVehicle, at: Transform3D) -> void:
 var spot:=at.origin
 spot.y=game.district.ground_height(spot)
 var data:=AvdiivkaData.shared() if is_instance_valid(game.district.operation_area) else null
 var normal:=data.normal_at(spot.x,spot.z) if data!=null and (absf(spot.x)>199 or absf(spot.z)>199) else Vector3.UP
 var forward:=-at.basis.z
 vehicle.global_transform=Transform3D.IDENTITY
 vehicle.look_at_from_position(spot+Vector3.UP*0.12,spot+Vector3.UP*0.12+forward,normal)

func set_halt(value: bool) -> void:
 halted=value
 if not value:
  # The first word of the mortarman sends the column waiting at the start.
  if awaiting and prep=="":
   for squad in mech:
    if squad.state=="wait":game.radio_voice.say("column");break
  awaiting=false;column_go=prep==""
 for actor in game.allies:
  # The men in the vehicles get their halt line where they dismount.
  if not actor.get_meta("battle_managed",false) or not operational(actor) or actor.vehicle!=null:continue
  if value:
   var cell:Vector2i=game.district.nearest_cell(game.district.navigation_cell(actor.global_position))
   actor.set_meta("halt_point",game.district.navigation_position(cell))
  assign(actor)
  # Everyone looks for cover at once, staggered against the per-frame budget.
  if value:actor.has_cover=false;actor.cover_timer=randf()*1.5

# Defenders of the three strongpoints and on the scattered posts.
static func defence_counts(size: int) -> Array[int]:
 var scattered:=roundi(size*SCATTERED_SHARE)
 var held:=size-scattered
 var first:=ceili(held/3.0)
 var second:=ceili((held-first)/2.0)
 return [first,second,held-first-second,scattered]

# An attacker in the formation, or a defender of a strongpoint on one of its
# firing positions in turn.
func deploy(friendly: bool, index: int) -> void:
 if not friendly:
  var slot:=0
  for actor in game.bots:
   if actor.get_meta("battle_sector",-1)==index and not actor.get_meta("armour_crew",false):slot+=1
  var defender:=spawn_soldier(false,garrison_post(index,slot),index,slot%BattleMap.POSITIONS[index].size())
  defender.set_kit(DEFENCE_KITS[slot%DEFENCE_KITS.size()])
  return
 var point:Variant=safe_spawn(true,index)
 # A full formation still places the soldier: at the base, slightly offset.
 if point==null:point=formation_base(true,index)+BattleMap.offset(randf_range(-6,6),randf_range(-3,3))+Vector3.UP*0.05
 spawn_soldier(true,point,index)

# A defender's post at a firing position: the first one in the emplacement,
# the others over the yard and the house around it.
func garrison_post(index: int, slot: int) -> Vector3:
 var spots: Array=BattleMap.POSITIONS[index]
 var spot: Vector2=spots[slot%spots.size()]
 var at:=Vector3(spot.x,0,spot.y)
 for attempt in range(40):
  var reach:=0.0 if attempt==0 and slot<spots.size() else randf_range(3.0,11.0)
  var point:Variant=post_point(at+Vector3(reach,0,0).rotated(Vector3.UP,randf()*TAU),2.5)
  if point!=null:return point
 return snap(at)+Vector3.UP*0.05

# Pairs on posts in the houses between the strongpoints, in different places
# every battle: away from the strongpoints and from the attackers' start line.
func deploy_posts(count: int) -> void:
 var data:=AvdiivkaData.shared()
 var houses: Array=[]
 for b in data.features.buildings:
  if b[6]!="H" or absf(b[0])>185 or absf(b[1])>185:continue
  var at:=Vector2(b[0],b[1])
  if at.distance_to(BattleMap.FORMATION)<POST_STANDOFF or at.distance_to(BattleMap.SPAWN)<POST_STANDOFF:continue
  var apart:=true
  for c in BattleMap.CENTERS:
   if at.distance_to(c)<POST_APART:apart=false
  if apart:houses.append(b)
 houses.shuffle()
 var taken: Array[Vector2]=[]
 for b in houses:
  if count<=0:break
  var at:=Vector2(b[0],b[1])
  var spaced:=true
  for other in taken:
   if other.distance_to(at)<30:spaced=false
  if not spaced:continue
  var reach:=maxf(b[2],b[3])*0.5+2.0
  var first:Variant=null
  var placed:=0
  for attempt in range(20):
   if placed>=mini(2,count):break
   var desired:=Vector3(at.x,0,at.y)+Vector3(reach+randf()*3,0,0).rotated(Vector3.UP,randf()*TAU)
   # The second of the pair stays within a few steps of the first.
   if first is Vector3:desired=first+Vector3(randf_range(2.0,4.0),0,0).rotated(Vector3.UP,randf()*TAU)
   var point:Variant=post_point(desired,2.5)
   if point==null:continue
   if first==null:first=point
   var sentry:=spawn_soldier(false,point,-1,-1)
   sentry.set_kit("rpg22" if placed==0 else "rifle")
   placed+=1
  if placed>0:taken.append(at);count-=placed
 # A village with no room for every post: the rest join the strongpoints.
 for i in range(count):deploy(false,i%3)

# A free navigation point near the desired one that the attackers can reach.
func post_point(desired: Vector3, tolerance: float) -> Variant:
 var district: District=game.district
 var cell:=district.nearest_cell(district.navigation_cell(desired))
 var point:=district.navigation_position(cell)
 if Vector2(point.x-desired.x,point.z-desired.z).length()>tolerance:return null
 if not district.navigation_regions.connected(cell,district.nearest_cell(district.navigation_cell(formation_base(true,0)))):return null
 for actor in game.bots:
  if is_instance_valid(actor) and actor.global_position.distance_to(point)<1.8:return null
 return point+Vector3.UP*0.05

func snap(point: Vector3) -> Vector3:
 return game.district.navigation_position(game.district.nearest_cell(game.district.navigation_cell(point)))

func budget(kind: String) -> bool:
 if not active:return true
 var frame:=Engine.get_physics_frames()
 if frame!=budget_frame:budget_frame=frame;cover_budget=2;path_budget=4
 if kind=="cover":
  if cover_budget<=0:return false
  cover_budget-=1;peak_cover_queries=maxi(peak_cover_queries,2-cover_budget)
 else:
  if path_budget<=0:return false
  path_budget-=1;peak_path_queries=maxi(peak_path_queries,4-path_budget)
 return true

# AI level of detail, in physics ticks between two updates of one soldier.
# Nearby and magnified soldiers update every tick; distant ones less often,
# off-screen ones least. Elapsed time is accumulated, so speeds, timers and
# rates of fire are unchanged. Outside the large battle everything is full rate.
var lod_frame := -1
var lod_camera: Camera3D
var lod_origin := Vector3.ZERO
var lod_zoom := 1.0

func update_interval(actor: Hostile) -> int:
 if not active:return 1
 var frame:=Engine.get_physics_frames()
 if frame!=lod_frame:
  lod_frame=frame
  lod_camera=game.get_viewport().get_camera_3d()
  if lod_camera!=null:
   lod_origin=lod_camera.global_position
   lod_zoom=clampf(lod_camera.fov/78.0,0.2,1.0)
   if is_instance_valid(game.player) and game.player.scope_sight!=null and game.player.scope_sight.enabled:lod_zoom=0.25
 # A camera closed this tick (the mortar sight) may already be out of the tree.
 if not is_instance_valid(lod_camera) or not lod_camera.is_inside_tree():return 1
 var distance:=actor.global_position.distance_to(lod_origin)
 if distance<28:return 1
 var apparent:=distance*lod_zoom
 if lod_camera.is_position_in_frustum(actor.global_position+Vector3.UP):
  if apparent<45:return 1
  return 2 if apparent<110 else 3
 return 3 if distance<60 else 4

# Middle of a strongpoint; without an index, of the one under assault, or
# the post the attackers make for while they mop up the village.
func center(index: int=-1) -> Vector3:
 var i:=sector if index<0 else index
 if i<0:return objective_point(0)
 var c: Vector2=BattleMap.CENTERS[clampi(i,0,2)]
 return Vector3(c.x,game.district.ground_height(Vector3(c.x,0,c.y)),c.y)

func position_point(index: int, slot: int) -> Vector3:
 var p: Vector2=BattleMap.POSITIONS[index][slot]
 return Vector3(p.x,game.district.ground_height(Vector3(p.x,0,p.y)),p.y)

func operational(actor: Hostile) -> bool:
 return is_instance_valid(actor) and not actor.dead and not actor.concussion.incapacitated()

# Still in the fight: alive, conscious and on his feet.
func fighting(actor: Hostile) -> bool:
 return operational(actor) and actor.collapse<=0.5

func post_of(actor: Hostile) -> Vector3:
 return actor.get_meta("battle_post",actor.home)

# Where the attackers come from for the current objective.
func staging() -> Vector3:
 return center(last_cleared) if last_cleared>=0 else formation_base(true,0)

# Nearest strongpoint not yet destroyed, or -1.
func next_target(from: Vector3) -> int:
 var best:=-1;var best_distance:=INF
 for i in range(3):
  if cleared[i]:continue
  var d:=center(i).distance_to(from)
  if d<best_distance:best=i;best_distance=d
 return best

# Where an attack group goes now: a firing position of the strongpoint under
# assault that still has defenders, a different one for each group; while
# mopping up, the post of one of the defenders left in the village.
func objective_point(group: int=0) -> Vector3:
 if sector>=0:
  var live: Array[int]=[]
  for actor in game.bots:
   if actor.get_meta("battle_sector",-1)!=sector or not operational(actor):continue
   var slot:int=actor.get_meta("battle_position",0)
   if slot not in live:live.append(slot)
  if live.is_empty():return center(sector)
  live.sort()
  return position_point(sector,live[group%live.size()])
 if sweep.is_empty():return staging()
 return sweep[group%sweep.size()]

func refresh_sweep() -> void:
 sweep.clear()
 if sector>=0:return
 var middle:=Vector3.ZERO;var count:=0
 for actor in game.allies:
  if operational(actor) and actor.vehicle==null:middle+=actor.global_position;count+=1
 middle=middle/count if count>0 else staging()
 var left: Array=game.bots.filter(func(a):return fighting(a))
 left.sort_custom(func(a,b):return post_of(a).distance_to(middle)<post_of(b).distance_to(middle))
 for actor in left:sweep.append(post_of(actor))

# Point the commander's display shows: the strongpoint under assault, or the
# nearest post left in the village.
func player_objective() -> Vector3:
 if sector>=0 or sweep.is_empty():return center()
 var from: Vector3=game.player.global_position
 var best: Vector3=sweep[0]
 for p in sweep:
  if p.distance_to(from)<best.distance_to(from):best=p
 return best

func objective_title() -> String:
 return BattleMap.TITLES[sector] if sector>=0 else "ЗАЧИСТКА СЕЛА"

# Resupply point: the attackers' rear, or a strongpoint's dugouts.
func depot(friendly: bool, index: int=-1) -> Vector3:
 # The attackers' ammunition point is where they formed up, not the
 # insertion point where the commander or the mortar crew may stand.
 if friendly:return formation_base(true,0)+BattleMap.offset(-14,6) if last_cleared<0 else center(last_cleared)
 return center(maxi(index,0))

# Strongpoint nearest to a point: where a scattered defender restocks.
func nearest_strongpoint(at: Vector3) -> int:
 var best:=0
 for i in range(3):
  if center(i).distance_to(at)<center(best).distance_to(at):best=i
 return best

func formation_base(friendly: bool, index: int) -> Vector3:
 if friendly:
  var f:Vector2=BattleMap.FORMATION
  return Vector3(f.x,game.district.ground_height(Vector3(f.x,0,f.y)),f.y)
 return center(index)

# Attackers' initial position: three lanes 34 m apart, rows of five soldiers
# 2.2 m apart, each next row 3 m further from the enemy.
func safe_spawn(friendly: bool, index: int) -> Variant:
 var base:=formation_base(friendly,index)
 var depth:=1.0 if friendly else -1.0
 var enemies: Array=game.bots if friendly else game.allies+[game.player]
 var preferred:=int(serial/4) if friendly else serial
 for attempt in range(90):
  var lane:=float((preferred+attempt)%3-1)*34
  var slot:=int(attempt/3)
  var desired:=base+BattleMap.offset(lane+float(slot%5-2)*2.2,depth*float(slot/5)*3)
  var point: Vector3=game.district.navigation_position(game.district.nearest_cell(game.district.navigation_cell(desired)))
  if Vector2(point.x-desired.x,point.z-desired.z).length()>4:continue
  var safe:=true
  for enemy in enemies:
   if not is_instance_valid(enemy) or (enemy is Hostile and not operational(enemy)) or (enemy is Operator and (enemy.health<=0 or enemy.get_meta("battle_out",false))):continue
   if enemy.global_position.distance_to(point)<20:safe=false;break
  for actor in game.allies+game.bots+[game.player]:
   if actor is Operator and actor.get_meta("battle_out",false):continue
   if is_instance_valid(actor) and not (actor is Hostile and actor.dead) and actor.global_position.distance_to(point)<1.8:safe=false;break
  if safe:return point+Vector3.UP*0.05
 return null

func spawn_soldier(friendly: bool, point: Vector3, index: int=0, slot: int=-1) -> Hostile:
 var actor:=Hostile.new();actor.friendly=friendly
 actor.formation_index=game.allies.size() if friendly else serial
 actor.set_meta("battle_managed",true);actor.set_meta("battle_group",index if friendly else int(serial/4)%3)
 if not friendly:
  actor.set_meta("battle_sector",index);actor.set_meta("battle_position",slot);actor.set_meta("battle_post",point)
 serial+=1
 game.add_child(actor);actor.setup(game,point)
 if friendly:actor.rotation.y=BattleMap.facing(true)
 else:
  # A defender watches the side the attack comes from.
  var look:=BattleMap.threat(Vector2(point.x,point.z))
  actor.rotation.y=atan2(-look.x,-look.y)
 actor.has_cover=false
 actor.think_timer=randf_range(0.1,0.8);actor.path_timer=randf_range(0.1,1.3)
 if friendly:game.allies.append(actor)
 else:game.bots.append(actor)
 if is_instance_valid(crowd):crowd.register(actor)
 assign(actor)
 # Before the attack the defenders live as on any quiet day at a post.
 if not friendly:
  var look:=BattleMap.threat(Vector2(point.x,point.z))
  Idle.place(actor,point+Vector3(look.x,0,look.y)*120.0)
 return actor

# Out of rounds: a comrade close by passes a spare magazine, or the soldier
# takes the magazines of a fallen soldier nearby. Returns the body to walk to,
# or null when resupplied on the spot or nothing is close.
func resupply(actor: Hostile) -> Variant:
 for other in (game.allies if actor.friendly else game.bots):
  if other==actor or not operational(other) or other.global_position.distance_to(actor.global_position)>12:continue
  var loaded:Array=range(other.weapon.pouches.size()).filter(func(i):return int(other.weapon.pouches[i].get("rounds",0))>0)
  if loaded.size()<2:continue
  if give_magazine(actor.weapon,other.weapon.pouches[loaded[0]]):
   other.weapon.pouches[loaded[0]]={}
   return null
 var nearest:Hostile=null
 for body in corpses+game.allies+game.bots:
  if not is_instance_valid(body) or not body.dead or body.weapon.id!=actor.weapon.id or body.weapon.ammunition_total()<=int(body.weapon.chambered):continue
  if body.global_position.distance_to(actor.global_position)>18:continue
  if nearest==null or body.global_position.distance_to(actor.global_position)<nearest.global_position.distance_to(actor.global_position):nearest=body
 if nearest==null:return null
 if nearest.global_position.distance_to(actor.global_position)>2.2:return nearest.global_position
 var spoils:Array=nearest.weapon.pouches+[nearest.weapon.magazine]
 for magazine in spoils:
  if int(magazine.get("rounds",0))>0 and give_magazine(actor.weapon,magazine.duplicate()):magazine.rounds=0
 return null

static func give_magazine(weapon: WeaponState, magazine: Dictionary) -> bool:
 for i in range(weapon.pouches.size()):
  if int(weapon.pouches[i].get("rounds",0))==0:
   weapon.pouches[i]=magazine.duplicate()
   return true
 return false

func assign(actor: Hostile) -> void:
 if not operational(actor) or not actor.get_meta("battle_managed",false):return
 # In a vehicle, or led by his squad on the approach: not the battle's man.
 if actor.vehicle!=null or actor.get_meta("mech_control",false) or actor.get_meta("armour_crew",false):return
 if not actor.friendly:
  defend(actor);return
 var group:int=actor.get_meta("battle_group",0)
 var objective:=objective_point(group)
 var supply:Variant=resupply(actor) if actor.weapon.ammunition_total()==0 else null
 if halted:
  # Consolidate where the halt found them: take cover there and hold.
  var goal:Vector3=actor.get_meta("halt_point",actor.global_position)
  if actor.home.distance_to(goal)>4:actor.has_cover=false;actor.path_timer=0;actor.cover_dwell=0
  actor.home=goal;actor.order_point=goal;actor.defensive=true;actor.defense_radius=12
  actor.order="assault";actor.order_direction=actor.position.direction_to(objective);actor.order_origin=actor.position
  actor.assault_arrived=true
  return
 var from:=staging()
 var forward:=Vector3(objective.x-from.x,0,objective.z-from.z)
 if forward.length()<1:forward=Vector3(BattleMap.north().x,0,BattleMap.north().y)
 forward=forward.normalized()
 var side:=Vector3(-forward.z,0,forward.x)
 var spread:=(actor.formation_index%4-1.5)*4
 var goal:=objective
 # Each group comes up on its own lane and stops short, then closes in on
 # the position it storms.
 if Vector2(actor.position.x-objective.x,actor.position.z-objective.z).length()>30:goal+=side*(float(group-1)*18+spread)-forward*16
 else:goal+=side*spread+forward*2
 # The sniper and the drone pilot work from behind the assault line: the
 # sniper where he overlooks the strongpoint, the pilot further back.
 var role:=actor.kit_id()
 if role in ["sniper","uav"]:goal=objective-forward*(140.0 if role=="sniper" else 220.0)+side*spread*2.5
 goal=snap(goal)
 if supply is Vector3:goal=snap(supply)
 elif actor.weapon.ammunition_total()==0:goal=restock(actor,depot(true))
 if actor.home.distance_to(goal)>4:
  actor.has_cover=false;actor.path_timer=0;actor.cover_dwell=0
 actor.home=goal;actor.order_point=goal;actor.defensive=true;actor.defense_radius=25
 actor.order="assault";actor.order_direction=actor.position.direction_to(objective);actor.order_origin=actor.position
 actor.assault_arrived=actor.position.distance_to(goal)<2.5

# A defender holds his own post to the end; out of rounds, he takes a
# comrade's magazine or walks to the dugouts of the nearest strongpoint.
func defend(actor: Hostile) -> void:
 var goal:=post_of(actor)
 var supply:Variant=resupply(actor) if actor.weapon.ammunition_total()==0 else null
 if supply is Vector3:goal=snap(supply)
 elif actor.weapon.ammunition_total()==0:
  var index:int=actor.get_meta("battle_sector",-1)
  goal=restock(actor,depot(false,index if index>=0 else nearest_strongpoint(actor.position)))
 if actor.home.distance_to(goal)>4:
  actor.has_cover=false;actor.path_timer=0;actor.cover_dwell=0
 actor.home=goal;actor.order_point=goal;actor.defensive=true;actor.defense_radius=14
 # A strategic destination is never a visual contact or an aim coordinate.
 if not actor.alerted:actor.target=goal

# Walks to the ammunition point; six seconds there give a full load.
func restock(actor: Hostile, point: Vector3) -> Vector3:
 var goal:=snap(point)
 if actor.position.distance_to(goal)<7:
  var time:float=actor.get_meta("resupply_time",0.0)+1
  actor.set_meta("resupply_time",time)
  if time>=6:actor.weapon=WeaponState.new(actor.weapon.id);actor.set_meta("resupply_time",0.0)
 else:actor.set_meta("resupply_time",0.0)
 return goal

func update_objective(delta: float) -> void:
 if finished:return
 var standing:=[0,0,0];var total:=0
 for actor in game.bots:
  if not fighting(actor):continue
  total+=1
  var index:int=actor.get_meta("battle_sector",-1)
  if index>=0:standing[index]+=1
 for i in range(3):
  if cleared[i]:continue
  clear_timers[i]=clear_timers[i]+delta if standing[i]==0 else 0.0
  if clear_timers[i]>=CLEAR_TIME:strongpoint_cleared(i)
 quiet=quiet+delta if total==0 else 0.0
 if quiet>=CLEAR_TIME:complete(true,"Противника в селі знищено.")

func strongpoint_cleared(index: int) -> void:
 cleared[index]=true
 var flag:=game.district.get_node_or_null("SectorFlag"+str(index)) as MeshInstance3D
 if flag:flag.material_override=Models.surface("d4b951")
 var title:String=BattleMap.TITLES[index].get_slice(" ",0)
 if index!=sector:
  game.squad.tell("%s ЗНИЩЕНО · ЦІЛЬ ШТУРМУ: %s" % [title,objective_title()])
  return
 last_cleared=index;command_left=0
 sector=next_target(center(index))
 refresh_sweep()
 if sector>=0:
  game.squad.tell("%s ЗНИЩЕНО · НАСТУПНА ЦІЛЬ: %s" % [title,BattleMap.TITLES[sector]])
  game.radio_voice.say("strongpoint")
 elif living(false)>0:game.squad.tell("УСІ ОП ЗНИЩЕНО · ЗАЧИСТКА СЕЛА · ПРОТИВНИКІВ: %d" % living(false))

func cleared_count() -> int:
 return cleared.count(true)

func retire_casualties() -> void:
 for friendly in [true,false]:
  var team:Array=game.allies if friendly else game.bots
  for actor in team.duplicate():
   if operational(actor):continue
   # Incapacitated casualties stay incapacitated and are never healed or
   # replaced: the battle has no reinforcements.
   if actor.get_meta("battle_personal",false):continue
   team.erase(actor);corpses.append(actor)
  while corpses.size()>20:
   var old:Hostile=corpses.pop_front()
   if is_instance_valid(old):old.queue_free()

# Command passes to the nearest fit soldier already on the field. There is
# no reserve: when no allied soldier is left standing the commander is the last.
func successor() -> Hostile:
 var from:Vector3=game.player.global_position if is_instance_valid(game.player) else game.district.player_spawn
 var best: Hostile=null;var best_distance:=INF
 var helper: Hostile=null
 for actor in game.allies:
  if not operational(actor) or actor.collapse>0.5 or actor.treatment_time>0 or actor.vehicle!=null:continue
  # The mortar assistant stays with the crew unless nobody else is left.
  if actor.get_meta("crew_role","")=="assistant":helper=actor;continue
  var distance:float=actor.global_position.distance_to(from)
  if distance<best_distance:best=actor;best_distance=distance
 if best!=null or helper!=null:return best if best!=null else helper
 # Nobody left on foot: a man still riding in a troop compartment (not the
 # vehicle's crew) takes over there.
 for squad in mech:
  if not is_instance_valid(squad.vehicle) or squad.vehicle.destroyed:continue
  for actor in squad.aboard():
   if not operational(actor) or actor.get_meta("bmp_role","")!="":continue
   var distance:float=squad.vehicle.global_position.distance_to(from)
   if distance<best_distance:best=actor;best_distance=distance
 return best

func living(friendly: bool) -> int:
 var count:=0
 for actor in game.allies if friendly else game.bots:
  if operational(actor):count+=1
 if friendly and is_instance_valid(game.player) and game.player.health>0 and not game.player.get_meta("battle_out",false):count+=1
 return count

func player_fell() -> bool:
 if respawn_left>0:return true
 # The BM-21 commander has no successor on the field.
 if game.player_class=="grad":
  if is_instance_valid(game.grad):game.grad.leave()
  complete(false,"Командир БМ-21 вибув.");return true
 if successor()==null:return false
 respawn_left=TAKEOVER_TIME
 game.crew.player_fell(game.player.global_position)
 game.inventory.close();game.close_panels();game.player.field_rig.stand_up();game.player.field_rig.cancel()
 game.player.launcher.cancel();game.player.set_physics_process(false);game.player.set_process_unhandled_input(false)
 game.player.set_meta("battle_out",true);game.player.collision_layer=0;game.player.collision_mask=0
 for area in game.player.find_children("*","Area3D",true,false):area.collision_layer=0
 game.player.viewmodel.hide();game.player.world_body.hide()
 return true

# The chosen soldier becomes the commander: his body leaves the AI army and
# the operator takes his place and heading. Nobody new enters the battlefield.
func respawn_player() -> void:
 var body:=successor()
 if body==null:
  complete(false,"Командир вибув. Живих бійців не лишилося.");return
 # His squad becomes the player's: its vehicle and the marks over its men.
 var own: MechSquad=null
 for squad in mech:
  if body in squad.members:own=squad
 var ride: BmpVehicle=body.vehicle as BmpVehicle
 if ride!=null:
  ride.aboard.erase(body);ride.troops.forget(body)
 var point:=body.global_position+Vector3.UP*0.05;var yaw:=body.rotation.y
 if ride!=null:point=ride.global_position+Vector3.UP*0.5
 game.allies.erase(body);game.squad.selected=-1;body.queue_free()
 if own!=null:own.members.erase(body)
 var old:Operator=game.player
 game.bmp.vacate()
 var next:=Operator.new();game.add_child(next);game.player=next;next.position=point;next.rotation.y=yaw;next.setup(game,game.primary,game.secondary);next.sensitivity=game.sensitivity
 old.queue_free();game.damage_flash=0;game.hearing.reset();game.squad.trail=PackedVector3Array([point])
 if own!=null and is_instance_valid(own.vehicle) and not own.vehicle.destroyed and not game.player_class in ["mortarman","grad","bmp"]:
  game.bmp.squad=own;game.bmp.vehicle=own.vehicle
  mark_squad()
  if ride==own.vehicle:
   game.bmp.enter("troop")
   game.squad.tell("Ти — у десанті БМП-%d, на місці бійця · F — вийти на зупинці" % (own.index+1))

func complete(won: bool, reason: String) -> void:
 finished=true;result_reason=reason
 if won:game.radio_voice.say("cleared")
 game.finish(won)

func _physics_process(delta: float) -> void:
 if not active or finished or not game.running or game.paused:return
 # A heavily concussed commander hands over to a soldier on the field.
 # With nobody left he stays where he lies: the assault never ends while the
 # commander is alive, only by his death or by the capture of all sectors.
 if game.player.concussion.incapacitated() and respawn_left<=0 and successor()!=null and game.player_class!="grad":player_fell()
 if respawn_left>0:
  respawn_left=maxf(0,respawn_left-delta)
  if respawn_left==0:respawn_player()
  if finished:return
 if skip_armed>0.0:skip_armed=maxf(0.0,skip_armed-delta)
 if prep!="" and not skipping:tick_prep(delta)
 update_marks()
 command_left-=delta
 if command_left<=0:
  command_left=1
  retire_casualties()
  refresh_sweep()
  for actor in game.allies+game.bots:assign(actor)
 update_objective(delta)

func status() -> String:
 var target:=player_objective();var offset:Vector3=target-game.player.position
 var bearing:=wrapf(rad_to_deg(atan2(-offset.x,-offset.z)),0,360)
 if prep!="":return prep_status()
 if respawn_left>0:return "КОМАНДИР ВИБУВ · КОМАНДУВАННЯ ПРИЙМЕ НАЙБЛИЖЧИЙ БОЄЦЬ ЧЕРЕЗ %d с\nУ строю: %d · бій триває" % [ceili(respawn_left),living(true)]
 if awaiting:return "ШТУРМ ОЧІКУЄ КОМАНДИ ГРАВЦЯ · G — %s\nГрупи на вихідних рубежах · СИЛИ %d : %d" % ["РАДІО" if game.player_class=="grad" else "РОЗРАХУНОК",living(true),living(false)]
 if halted:return "ШТУРМ ПРИЗУПИНЕНО · ГРУПИ ЗАКРІПЛЮЮТЬСЯ · G — ПРОДОВЖИТИ\n%s · СИЛИ %d : %d" % [objective_title(),living(true),living(false)]
 if sector<0:return "ЗАЧИСТКА СЕЛА · НАЙБЛИЖЧИЙ ПОСТ %d м / %03d°\nУСІ ОП ЗНИЩЕНО · ЗАЛИШИЛОСЬ ПРОТИВНИКІВ %d · СИЛИ %d : %d" % [offset.length(),bearing,living(false),living(true),living(false)]
 return "ШТУРМ · %s · %d м / %03d°\nОП ЗНИЩЕНО %d / 3 · СИЛИ %d : %d%s" % [objective_title(),offset.length(),bearing,cleared_count(),living(true),living(false)," · F6 — ДО ВИСАДКИ" if can_skip() else ""]

func prep_status() -> String:
 var line:="ВИХІДНИЙ РУБІЖ · ВІДДІЛЕННЯ СПІШЕНЕ БІЛЯ БМП · ЧЕКАЙ КОМАНДИ"
 if game.player_class=="bmp":line="ВИХІДНИЙ РУБІЖ · КОЛОНА СТОЇТЬ · РУШАЙ ПІСЛЯ «КОЛОНА — ВПЕРЕД!»"
 elif game.player_class=="mortarman":line="ВОГНЕВА ПОЗИЦІЯ МІНОМЕТА · ПЕРШИМИ Б'ЮТЬ «ГРАДИ» · ПОТІМ ШТУРМ ЧЕКАЄ ТВОЄЇ КОМАНДИ"
 if prep=="mount":
  match game.player_class:
   "bmp":line="«ПО МАШИНАХ!» · СТІЙ: ТВІЙ ДЕСАНТ СІДАЄ"
   "mortarman":line="«ПО МАШИНАХ!» · ДЕСАНТ СІДАЄ В БМП"
   _:line="«ПО МАШИНАХ!» · %s" % ("ТИ В ДЕСАНТІ БМП-1 · КОЛОНА ЧЕКАЄ ПОСАДКИ" if game.bmp.seat=="troop" else "F БІЛЯ КОРМОВИХ ДВЕРЕЙ БМП-1")
 elif is_instance_valid(battery):
  if not battery.ordered:line+="\n«ГРАДИ» НАВОДЯТЬСЯ: ГОТОВІ %d / 3" % battery.ready_count()
  elif not battery.finished():line+="\n«ГРАДИ» ВЕДУТЬ ВОГОНЬ ПО ОП-1…3 · РАКЕТ У ПОВІТРІ %d" % battery.in_flight()
  else:line+="\nЗАЛП ЗАВЕРШЕНО"
 line+=" · СИЛИ %d : %d" % [living(true),living(false)]
 if can_skip():line+="\nF6 — ПРОПУСТИТИ %s" % skip_text()
 return line

# Our strength in the menu: men and vehicles, not the enemy's.
static func size_text(n: int) -> String:return "%d · %d БМП" % [n,squad_count(n)]

func build_menu(parent: Control) -> void:
 panel=Control.new();game.place(panel,parent,0,0,1,1)
 UiKit.sheet(game,panel,0.8)
 UiKit.header(game,panel,"ГОЛОВНЕ МЕНЮ   /   ВЕЛИКИЙ ШТУРМ","ВЕЛИКИЙ ШТУРМ","АВДІЇВКА · ПРИВАТНИЙ СЕКТОР · 400 × 400 М · ЗАЧИСТКА СЕЛА",func():game.main_menu.back())
 var map:=Control.new();map.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.place(map,panel,0.035,0.25,0.5,0.82)
 map.draw.connect(func():
  var s:=map.size;var side:=minf(s.x,s.y);var o:=Vector2((s.x-side)*0.5,0);var box:=Vector2(side,side)
  map.draw_rect(Rect2(o,box),Color(0.04,0.07,0.055,0.9))
  for k in range(1,8):
   map.draw_line(o+Vector2(side*k/8,0),o+Vector2(side*k/8,side),Color(1,1,1,0.06))
   map.draw_line(o+Vector2(0,side*k/8),o+Vector2(side,side*k/8),Color(1,1,1,0.06))
  map.draw_rect(Rect2(o,box),UiKit.LINE,false,1.0)
  var font:=UiKit.font("head")
  var at:=func(p: Vector2) -> Vector2:return o+(p+Vector2.ONE*200)/400*side
  # The village: streets and houses, any of which may hide a post.
  var data:=AvdiivkaData.shared()
  for road in data.features.roads:
   var points:=AvdiivkaData.pairs(road[3])
   for k in range(points.size()-1):
    var a:=points[k];var b:=points[k+1]
    if maxf(absf(a.x),absf(a.y))>260 and maxf(absf(b.x),absf(b.y))>260:continue
    var ca:=a.clamp(Vector2.ONE*-200,Vector2.ONE*200);var cb:=b.clamp(Vector2.ONE*-200,Vector2.ONE*200)
    map.draw_line(at.call(ca),at.call(cb),Color(1,1,1,0.14),2.0)
  for b in data.features.buildings:
   if absf(b[0])>196 or absf(b[1])>196:continue
   var half:=Vector2(b[2],b[3])*0.25*side/400.0+Vector2.ONE
   map.draw_rect(Rect2(at.call(Vector2(b[0],b[1]))-half,half*2),Color(1,1,1,0.22))
  for i in range(3):
   var p:Vector2=at.call(BattleMap.CENTERS[i]);var r:=side*45.0/400.0
   map.draw_circle(p,r,Color(UiKit.DANGER,0.12));map.draw_arc(p,r,0,TAU,40,Color(UiKit.DANGER,0.8),2.0)
  # Firing positions of the three strongpoints.
  for spot in BattleMap.positions():
   var q:Vector2=at.call(spot.point)
   map.draw_rect(Rect2(q-Vector2(4,4),Vector2(8,8)),Color(UiKit.DANGER,0.9))
  for i in range(3):
   var p:Vector2=at.call(BattleMap.CENTERS[i])
   map.draw_circle(p,13,Color(0.05,0.07,0.06));map.draw_arc(p,13,0,TAU,24,UiKit.ACCENT,2.0)
   map.draw_string(font,p+Vector2(-5,6),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,17,UiKit.INK)
  var start:Vector2=at.call(BattleMap.SPAWN)
  map.draw_colored_polygon(PackedVector2Array([start+Vector2(0,-11),start+Vector2(9,6),start+Vector2(-9,6)]),UiKit.ACCENT)
  map.draw_string(font,o+Vector2(12,side-12),"○ ОП-1 · 2 · 3    ■ ПОЗИЦІЇ    ▲ ВИХІД ШТУРМУ",HORIZONTAL_ALIGNMENT_LEFT,-1,13,UiKit.MUTED)
 )
 var text:=UiKit.wrapped(BattleMap.MENU_TEXT,16,UiKit.SOFT)
 game.place(text,panel,0.54,0.25,0.965,0.74)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);game.place(row,panel,0.035,0.85,0.5,0.92)
 var caption:=UiKit.text("НАШИХ БІЙЦІВ",16,UiKit.ACCENT,"head");caption.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(caption)
 var size:=OptionButton.new();size.custom_minimum_size=Vector2(150,46)
 for n in SIZES:size.add_item(size_text(n))
 size.selected=maxi(0,SIZES.find(game.battle_size));row.add_child(size)
 size.item_selected.connect(func(i:int):game.battle_size=SIZES[i];game.save_settings())
 var pick:=UiKit.cta("ОБРАТИ ШТУРМ →",func():game.selected_map=BattleMap.ID;game.save_settings();game.update_map_description();game.main_menu.show_screen("loadout"))
 game.place(pick,panel,0.54,0.83,0.965,0.9)
 panel.hide()
