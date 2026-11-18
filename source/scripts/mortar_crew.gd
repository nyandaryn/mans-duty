class_name MortarCrew
extends Node

# The player's mortar crew: the 2B14, the assistant (ammunition bearer with
# the baseplate and a box of ten mines) and the orders only a mortarman gives.
const ASSISTANT_MINES := MineBox.CAPACITY
const DEPLOY_TIME := 20.0 # Crew of two; the drill standard for a full crew from march is about 1.5 min.
const DEPLOY_ALONE := 32.0
const PACK_TIME := 12.0
const PICKUP_TIME := 5.0
const TAKE_TIME := 2.0
const PLATE_TIME := 3.0
const REACH := 2.3
const PLATE_REACH := 15.0
const BOX_REACH := 4.0
const FIRE_INTERVAL := 3.5
const LOADER_SPOT := 1.0
var game: Node3D
var mortar: Mortar
var boxes: Array[MineBox]=[]
var assistant: Hostile
var has_assistant := false
var assistant_point := Vector3.ZERO
var assistant_mines := 0
var assistant_plate := false
var player_plate := false
var task := ""
# "deploy" / "pack" while the mortar is being put together or taken apart.
var assembling := ""
var task_point := Vector3.ZERO
var fire_left := 0
var fire_clock := 0.0
var fired := 0
var panel: Control
var caption: Label
var buttons: Dictionary={}
var sight: MortarSight

func setup(owner_game: Node3D, ui_root: Control) -> void:
 game=owner_game
 panel=Control.new()
 game.place(panel,ui_root,0,0,1,1)
 panel.mouse_filter=Control.MOUSE_FILTER_STOP
 var backdrop := ColorRect.new()
 backdrop.color=Color(0.02,0.035,0.03,0.80)
 game.place(backdrop,panel,0,0.42,1,1)
 var content := VBoxContainer.new()
 content.add_theme_constant_override("separation",9)
 game.place(content,panel,0.08,0.45,0.92,0.97)
 content.add_child(game.label("МІНОМЕТНИЙ РОЗРАХУНОК · 2Б14 «ПІДНОС»",23,game.GOLD))
 caption=game.label("",15)
 caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 content.add_child(caption)
 for row in [
  ["ШТУРМ",[["resume","ПОЧАТИ / ПРОДОВЖИТИ ШТУРМ"],["halt","ЗАКРІПИТИСЯ · ЧЕКАТИ КІНЦЯ ОБСТРІЛУ"]]],
  ["МІНОМЕТ",[["deploy","РОЗГОРНУТИ ТУТ · N"],["pack","ЗГОРНУТИ · N"]]],
  ["ПОМІЧНИК",[["box","ПОСТАВИТИ ЯЩИК З МІНАМИ"],["fire1","ВОГОНЬ · 1 МІНА"],["fire3","ВОГОНЬ · 3 МІНИ"],["fire5","ВОГОНЬ · 5 МІН"],["fire_all","ВОГОНЬ · УСІМА"]]],
  ["",[["cease","ПРИПИНИТИ ВОГОНЬ"],["follow","ЗА МНОЮ"]]]]:
  var line := HBoxContainer.new();line.add_theme_constant_override("separation",8)
  content.add_child(line)
  var title: Label=game.label(row[0],13,game.GOLD);title.custom_minimum_size.x=110
  line.add_child(title)
  for item in row[1]:
   var button: Button=game.button(item[1],command.bind(item[0]))
   button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   button.custom_minimum_size.y=44
   button.add_theme_font_size_override("font_size",15)
   line.add_child(button);buttons[item[0]]=button
 buttons.halt.tooltip_text="Усі штурмові групи закріплюються на поточних рубежах і чекають, доки ти не скажеш продовжити (наприклад, до кінця мінометного обстрілу)."
 buttons.box.tooltip_text="Помічник несе ящик із мінами до розгорнутого міномета (або до місця, куди дивишся) і ставить його. З ящика F бере міну в наплічник; з ящика біля міномета ведеться вогонь."
 buttons.fire3.tooltip_text="Помічник сам стріляє з міномета з установками, які ти виставив у прицілі, використовуючи свої міни."
 content.add_child(game.label("G / Esc — закрити. Бій триває.",13,game.GOLD))
 panel.hide()
 sight=MortarSight.new()
 game.place(sight,ui_root,0,0,1,1)
 sight.setup(game,self)

func active() -> bool:return is_instance_valid(mortar)

func reset() -> void:
 close()
 if is_instance_valid(sight):sight.close()
 if is_instance_valid(mortar):mortar.queue_free()
 for box in boxes:
  if is_instance_valid(box):box.queue_free()
 mortar=null;boxes.clear();assistant=null;has_assistant=false
 assistant_mines=0;assistant_plate=false;player_plate=false
 task="";fire_left=0;fire_clock=0;fired=0;assembling=""

# Called after the player's own group is on the field.
func start() -> void:
 if game.player_class!="mortarman":return
 mortar=Mortar.new();game.add_child(mortar);mortar.setup(game)
 if not game.allies.is_empty():
  assistant=game.allies[0];has_assistant=true;assistant_point=assistant.global_position
  assistant.set_meta("crew_role","assistant")
  assistant_plate=true;assistant_mines=ASSISTANT_MINES
  var tag := assistant.model.get_node("Head").find_children("*","Label3D",false,false)
  if not tag.is_empty():
   var label := tag[0] as Label3D
   label.text="ПОМІЧНИК";label.pixel_size=0.0035
  # A ring on the assistant's pack: the 17 kg baseplate he carries.
  var plate := Models.tube(assistant.model,Vector3(0,1.15,0.30),0.24,0.04,"#4b5240",Vector3.BACK)
  plate.name="CarriedBaseplate"
 else:player_plate=true

func assistant_ready() -> bool:
 return has_assistant and is_instance_valid(assistant) and not assistant.dead and assistant.collapse<0.5 and assistant.treatment_time<=0 and not assistant.concussion.incapacitated()

func carried_mass() -> float:
 if not active():return 0.0
 return (PlayerClass.BARREL_AND_BIPOD if mortar.state=="carried" else 0.0)+(PlayerClass.BASEPLATE if player_plate else 0.0)

func tell(text: String) -> void:game.squad.tell(text)

func toggle() -> void:
 if not game.running or game.paused:return
 if panel.visible:close();return
 if not active():
  tell("Стрілець і снайпер діють самостійно: власної групи й команд немає.")
  return
 sight.close()
 game.commands_open=true
 game.player.burst=0
 game.player.firing_sequence_active=false
 panel.show()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 refresh()

func close() -> void:
 if not is_instance_valid(panel) or not panel.visible:return
 panel.hide()
 game.commands_open=false
 if game.running and not game.paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func status_text() -> String:
 if not active():return ""
 var where: String={"carried":"на тобі","assembling":"розгортається","deployed":"розгорнуто","packing":"згортається","dropped":"лежить на землі"}[mortar.state]
 var text := "Міномет: %s" % where
 if mortar.state=="deployed":text+=" · заряд %s · приціл %s · азимут %s" % [MortarBallistics.CHARGES[mortar.charge],MortarBallistics.mils_text(mortar.elevation),MortarBallistics.mils_text(mortar.azimuth)]
 if assistant_ready():
  text+="\nПомічник: мін при собі %d%s" % [assistant_mines," · опорна плита при ньому" if assistant_plate else ""]
  if task=="fire":text+=" · веде вогонь (%d)" % fire_left if fire_left<999 else " · веде вогонь усіма мінами"
  elif task=="box":text+=" · несе ящик"
 else:text+="\nПомічник вибув"
 var stocked := 0
 for box in boxes:stocked+=box.mines
 text+="\nУ ящиках: %d · у наплічнику: %d%s" % [stocked,game.player.backpack.count("mortar_mine")," · опорна плита на тобі" if player_plate else ""]
 if game.battle.active:text+="\nШтурм: "+("очікує твоєї команди" if game.battle.awaiting else ("призупинено, групи закріплюються" if game.battle.halted else "триває"))
 return text

func refresh() -> void:
 caption.text=status_text()
 var battle: bool=game.battle.active
 buttons.resume.disabled=not battle or not game.battle.halted
 buttons.halt.disabled=not battle or game.battle.halted
 buttons.deploy.disabled=mortar.state!="carried"
 buttons.pack.disabled=mortar.state!="deployed"
 var helper := assistant_ready()
 buttons.box.disabled=not helper or assistant_mines<=0
 for id in ["fire1","fire3","fire5","fire_all"]:buttons[id].disabled=not helper or mortar.state!="deployed"
 buttons.cease.disabled=not helper or task!="fire"
 buttons.follow.disabled=not helper

func command(id: String) -> void:
 if not game.running or game.paused or not active():return
 match id:
  "resume":
   game.battle.set_halt(false);tell("Штурм: ВПЕРЕД! Групи продовжують наступ.")
  "halt":
   game.battle.set_halt(true);tell("Штурм призупинено: групи закріплюються й чекають команди.")
  "deploy":deploy()
  "pack":pack()
  "box":place_box()
  "fire1":fire_mission(1)
  "fire3":fire_mission(3)
  "fire5":fire_mission(5)
  "fire_all":fire_mission(999)
  "cease":
   if task=="fire":finish_task("Помічник припинив вогонь. Випущено: %d." % fired)
  "follow":
   finish_task("");order(assistant,"follow",game.player.global_position)
   tell("Помічник: іду за тобою.")
 close()

# --- orders to the assistant ------------------------------------------------

func order(actor: Hostile, id: String, point: Vector3) -> void:
 if not is_instance_valid(actor) or actor.dead:return
 actor.order=id
 actor.order_point=point
 actor.order_origin=game.player.global_position
 actor.order_direction=-game.player.global_basis.z
 actor.assault_arrived=false;actor.cover_dwell=0
 actor.set_meta("hold_point",point)
 actor.has_cover=false;actor.cover_requires_prone=false;actor.auto_cover=false
 actor.flank_timer=0;actor.path_timer=0;actor.path=PackedVector2Array();actor.path_index=0
 actor.cover_timer=0;actor.squad_role=""

func reachable(point: Vector3) -> Variant:
 var cell: Vector2i=game.district.nearest_cell(game.district.navigation_cell(point))
 var snapped: Vector3=game.district.navigation_position(cell)
 if Vector2(snapped.x-point.x,snapped.z-point.z).length()>3:return null
 return snapped

func finish_task(message: String) -> void:
 if task=="fire" and assistant_ready():assistant.fire_at_will=true
 task="";fire_left=0
 if assistant_ready():order(assistant,"hold",assistant.global_position)
 if message!="":tell(message)

func loader_spot() -> Vector3:
 var forward := MortarBallistics.direction(mortar.bipod_azimuth)
 return mortar.global_position+Vector3(forward.z,0,-forward.x)*LOADER_SPOT-forward*0.3

func place_box() -> void:
 if not assistant_ready():tell("Помічника немає поруч.");return
 if assistant_mines<=0:tell("У помічника не лишилося мін.");return
 var target: Variant=null
 if mortar.state=="deployed":
  var forward := MortarBallistics.direction(mortar.bipod_azimuth)
  target=reachable(mortar.global_position-forward*1.3+Vector3(-forward.z,0,forward.x)*1.0)
 if target==null:
  game.squad.aim_point()
  if game.squad.point_valid and game.squad.point.distance_to(game.player.global_position)<40:target=reachable(game.squad.point)
 if target==null:target=reachable(game.player.global_position-game.player.global_basis.z*1.5)
 if target==null:tell("Помічник не бачить, куди поставити ящик.");return
 if task=="fire":assistant.fire_at_will=true
 task="box";task_point=target
 order(assistant,"move",target)
 tell("Помічник несе ящик із мінами (%d)." % assistant_mines)

func fire_mission(count: int) -> void:
 if not assistant_ready():tell("Помічника немає поруч.");return
 if mortar.state!="deployed":tell("Спершу розгорни міномет і наведи його.");return
 if assistant_mines+box_mines_at_mortar()<=0:tell("Помічник: мін немає ні при собі, ні в ящику біля міномета.");return
 task="fire";fire_left=count;fired=0;fire_clock=1.5
 var spot: Variant=reachable(loader_spot())
 task_point=spot if spot!=null else mortar.global_position
 order(assistant,"hold",task_point)
 assistant.fire_at_will=false
 tell("Помічник: є вогонь%s за встановленими даними." % ("" if count>=999 else " %d %s" % [count,"міною" if count==1 else "мінами"]))

func box_at_mortar() -> MineBox:
 if not is_instance_valid(mortar) or mortar.state!="deployed":return null
 for box in boxes:
  if is_instance_valid(box) and box.mines>0 and box.global_position.distance_to(mortar.global_position)<BOX_REACH:return box
 return null

func box_mines_at_mortar() -> int:
 var box := box_at_mortar()
 return box.mines if box!=null else 0

# --- the player's own actions -------------------------------------------------

func toggle_deploy() -> void:
 if not active():return
 # N again, like any step, calls off the deployment or pack-up in progress.
 if assembling!="":
  game.player.field_rig.interrupt_work("СКАСОВАНО")
  abort_assembly()
  return
 if mortar.state=="deployed":pack()
 elif mortar.state=="carried":deploy()

func deploy() -> bool:
 if not active() or mortar.state!="carried":return false
 var helper := assistant_ready() and assistant_plate and assistant.global_position.distance_to(game.player.global_position)<PLATE_REACH
 if not helper and not player_plate:
  tell("Опорна плита в помічника: він має бути поруч (до %d м)." % int(PLATE_REACH))
  return false
 var forward: Vector3=-game.player.global_basis.z;forward.y=0;forward=forward.normalized()
 var point: Vector3=game.player.global_position+forward*0.9
 point.y=game.district.ground_height(point)
 var overhead := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.3,point+Vector3.UP*30,1)
 if not game.get_world_3d().direct_space_state.intersect_ray(overhead).is_empty():
  tell("Над мінометом перекриття: для мінних траєкторій потрібне відкрите небо.")
  return false
 var mils := MortarBallistics.azimuth(forward)
 if not game.player.field_rig.work("РОЗГОРТАННЯ МІНОМЕТА",DEPLOY_TIME if helper else DEPLOY_ALONE,finish_deploy.bind(point,mils,helper)):
  tell("Руки зайняті: спершу закінчи поточну дію.")
  return false
 mortar.begin_assembly(point,mils)
 assembling="deploy"
 kneel_at(point,helper)
 tell("Розгортаємо міномет: опорна плита, двонога, ствол, приціл. Рух або N — скасувати.")
 return true

# The crew kneels at the work: the mortarman, and the assistant beside the plate.
func kneel_at(point: Vector3, helper: bool) -> void:
 if not game.player.prone:game.player.crouch_requested=true
 if not helper or not assistant_ready():return
 var forward: Vector3=-game.player.global_basis.z;forward.y=0;forward=forward.normalized()
 var spot: Variant=reachable(point+Vector3(forward.z,0,-forward.x)*1.0)
 var place: Vector3=spot if spot!=null else game.player.global_position
 order(assistant,"hold",place)
 var facing := Vector3(point.x-place.x,0,point.z-place.z)
 if facing.length()>0.1:assistant.order_direction=facing.normalized()
 assistant.set_meta("crew_kneel",true)

func release_crew() -> void:
 if is_instance_valid(assistant):assistant.remove_meta("crew_kneel")

func abort_assembly() -> void:
 if assembling=="deploy":mortar.carry()
 elif assembling=="pack":mortar.restore()
 assembling=""
 release_crew()

func finish_deploy(point: Vector3, mils: int, helper: bool) -> void:
 assembling=""
 release_crew()
 if helper and assistant_ready() and assistant_plate:assistant_plate=false
 elif player_plate:player_plate=false
 elif assistant_plate and assistant_ready():assistant_plate=false
 else:mortar.carry();tell("Немає опорної плити: розгортання зірване.");return
 if assistant_ready():
  var carried := assistant.model.get_node_or_null("CarriedBaseplate")
  if carried:carried.visible=assistant_plate
 mortar.place(point,mils)
 tell("Міномет розгорнуто. Основний напрямок %s. F біля міномета — приціл." % MortarBallistics.mils_text(mils))

func pack() -> bool:
 if not active() or mortar.state!="deployed":return false
 if game.player.global_position.distance_to(mortar.global_position)>REACH:
  tell("Підійди до міномета, щоб згорнути його.");return false
 if task=="fire":finish_task("")
 if not game.player.field_rig.work("ЗГОРТАННЯ МІНОМЕТА",PACK_TIME,finish_pack):return false
 mortar.begin_packing()
 assembling="pack"
 kneel_at(mortar.global_position,assistant_ready() and assistant.global_position.distance_to(game.player.global_position)<PLATE_REACH)
 tell("Згортаємо міномет. Рух або N — скасувати.")
 return true

func finish_pack() -> void:
 assembling=""
 release_crew()
 mortar.carry()
 if assistant_ready() and assistant.global_position.distance_to(game.player.global_position)<PLATE_REACH:
  assistant_plate=true
  var carried := assistant.model.get_node_or_null("CarriedBaseplate")
  if carried:carried.visible=true
  tell("Міномет згорнуто: ствол і двонога — на тобі, плиту забрав помічник.")
 else:
  player_plate=true
  tell("Міномет згорнуто. Опорну плиту несеш сам (+17 кг).")

func nearest_box() -> MineBox:
 var best: MineBox
 var best_distance := REACH
 for box in boxes:
  if not is_instance_valid(box) or box.empty():continue
  var distance: float=box.global_position.distance_to(game.player.global_position)
  if distance<best_distance:best=box;best_distance=distance
 return best

func mortar_near() -> bool:
 return active() and mortar.state!="carried" and mortar.global_position.distance_to(game.player.global_position)<REACH

# F acts on whichever is closer: the mortar or a box / dropped load.
func box_first(box: MineBox) -> bool:
 if box==null:return false
 if not mortar_near():return true
 return box.global_position.distance_to(game.player.global_position)<mortar.global_position.distance_to(game.player.global_position)

func prompt() -> String:
 if not active() or game.player.field_rig.active():return ""
 var box := nearest_box()
 if not box_first(box):
  if mortar_near() and mortar.state=="deployed":return "F — ПРИЦІЛ МІНОМЕТА · N — ЗГОРНУТИ"
  if mortar_near() and mortar.state=="dropped":return "F — ПІДНЯТИ МІНОМЕТ"
 if box!=null:
  if box.plate and not player_plate and mortar.state!="deployed" and not assistant_plate:return "F — ЗАБРАТИ ОПОРНУ ПЛИТУ (17 кг)"
  if box.mines>0:return "F — ВЗЯТИ МІНУ В НАПЛІЧНИК · У ЯЩИКУ %d" % box.mines
 return ""

func interact() -> bool:
 if not active():return false
 var box := nearest_box()
 if mortar_near() and not box_first(box):
  if mortar.state=="deployed":return sight.open()
  if mortar.state!="dropped":return false
  return game.player.field_rig.work("ПІДЙОМ МІНОМЕТА",PICKUP_TIME,func():mortar.carry();tell("Міномет на тобі."))
 if box==null:return false
 return use_box(box)

func use_box(box: MineBox) -> bool:
 if box.plate and not player_plate and mortar.state!="deployed" and not assistant_plate:
  return game.player.field_rig.work("ОПОРНА ПЛИТА",PLATE_TIME,take_plate.bind(box))
 if box.mines>0:
  if not game.player.backpack.equipped:tell("Для мін потрібен наплічник.");return true
  if not has_room():
   tell("У наплічнику немає місця для міни (1 × 2) або перевищено 18 кг.");return true
  return game.player.field_rig.work("МІНА З ЯЩИКА",TAKE_TIME,take_mine.bind(box))
 return false

# From the sight: the box beside the mortar is within arm's reach.
func take_from_box() -> bool:
 var box := box_at_mortar()
 if box==null:tell("Біля міномета немає ящика з мінами.");return false
 sight.close()
 return use_box(box)

func has_room() -> bool:
 var probe := BackpackState.restore(game.player.backpack.serialize())
 return probe.add("mortar_mine")>=0

func take_mine(box: MineBox) -> void:
 if not is_instance_valid(box) or box.mines<=0:return
 if game.player.backpack.add("mortar_mine")<0:tell("У наплічнику немає місця для міни.");return
 box.mines-=1;box.refresh()
 tell("Міну взято. У ящику: %d · у наплічнику: %d" % [box.mines,game.player.backpack.count("mortar_mine")])

func take_plate(box: MineBox) -> void:
 if not is_instance_valid(box) or not box.plate:return
 box.plate=false;box.refresh();player_plate=true
 tell("Опорну плиту взято (+17 кг).")

# The player fires from the sight: mines from the box beside the mortar first.
func player_fire() -> bool:
 if not active() or mortar.state!="deployed" or not mortar_near():return false
 if not mortar.ready_to_fire():return false
 var box := box_at_mortar()
 var uid: int=game.player.backpack.first("mortar_mine")
 if box==null and uid<0:tell("Немає мін: ні в ящику біля міномета, ні в наплічнику.");return false
 if not mortar.fire(game.player):return false
 if box!=null:box.mines-=1;box.refresh()
 else:game.player.backpack.remove(uid)
 game.player.shots+=1
 return true

# --- per-frame crew behaviour -------------------------------------------------

func player_fell(where: Vector3) -> void:
 if not active():return
 sight.close()
 if assembling!="":abort_assembly()
 if mortar.state=="carried":mortar.drop(Vector3(where.x,game.district.ground_height(where),where.z))
 if player_plate:
  drop_load(where+Vector3(0.8,0,0),0,true)
  player_plate=false

func drop_load(where: Vector3, mines: int, plate: bool) -> void:
 if mines<=0 and not plate:return
 where.y=game.district.ground_height(where)
 var box := MineBox.new();game.add_child(box)
 box.setup(where,randf()*TAU,mines,plate,mines>0)
 boxes.append(box)

func _physics_process(delta: float) -> void:
 if not is_instance_valid(game) or not game.running or game.paused or not active():return
 if is_instance_valid(sight) and sight.visible and (not mortar_near() or mortar.state!="deployed"):sight.close()
 if assembling!="":
  var rig: FieldRig=game.player.field_rig
  if rig.mode=="work":
   var progress := clampf(rig.timer/maxf(rig.work_time,0.01),0,1)
   mortar.set_assembly(progress if assembling=="deploy" else 1.0-progress)
   rig.work_target=mortar.work_point()
  else:abort_assembly()
 if has_assistant and (not is_instance_valid(assistant) or assistant.dead):
  drop_load(assistant.global_position if is_instance_valid(assistant) else assistant_point,assistant_mines,assistant_plate)
  assistant_mines=0;assistant_plate=false
  if task!="":task="";fire_left=0
  assistant=null;has_assistant=false
  tell("Помічник вибув. Його міни й плита лишилися на місці.")
  return
 if not assistant_ready():return
 assistant_point=assistant.global_position
 if task=="box":
  # Carrying the box he goes straight to the spot: a cover close by must not
  # count as arriving (near the mortar the cover search used to keep him put).
  assistant.cover_timer=maxf(assistant.cover_timer,1.0)
  assistant.has_cover=false
  if Vector2(assistant.position.x-task_point.x,assistant.position.z-task_point.z).length()<1.6:
   var box := MineBox.new();game.add_child(box)
   box.setup(Vector3(task_point.x,game.district.ground_height(task_point),task_point.z),assistant.rotation.y,assistant_mines,false)
   boxes.append(box)
   var count := assistant_mines
   assistant_mines=0
   finish_task("Ящик із мінами встановлено (%d)." % count)
 elif task=="fire":
  if mortar.state!="deployed":finish_task("Міномет згорнуто: вогонь припинено.");return
  assistant.cover_timer=maxf(assistant.cover_timer,1.0)
  assistant.has_cover=false
  if Vector2(assistant.position.x-task_point.x,assistant.position.z-task_point.z).length()>1.6:return
  fire_clock-=delta
  if fire_clock>0 or not mortar.ready_to_fire():return
  var box := box_at_mortar()
  if assistant_mines<=0 and box==null:finish_task("Помічник: міни скінчилися. Випущено: %d." % fired);return
  if not mortar.fire(assistant):return
  if assistant_mines>0:assistant_mines-=1
  else:box.mines-=1;box.refresh()
  fired+=1;fire_left-=1;fire_clock=FIRE_INTERVAL
  if fire_left<=0:finish_task("Помічник: вогонь закінчено. Випущено: %d." % fired)
 if panel.visible:refresh()
