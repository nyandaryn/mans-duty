class_name TosTraining
extends TrainingCourse

# «Навчання» for the TOS-1A, taught step by step on the Avdiivka map with
# nobody on the field: the march on the levers, bringing the BM-1 into action
# in the maker's 90 s, a direct lay by the 1D14 at a target board in the
# open, fire by the coordinates of a strongpoint marked from the observation
# post's drone, and leaving the position before the answer comes. Each
# chapter can be started on its own: the vehicle is put in the state the
# previous chapters leave it in.
const TARGET_INDEX := 1
# A target board in the open 1.6 km from the firing position, 35° left of
# the line to the village: one of the few points the sight sees without a
# tree row across (checked over the SRTM relief and the OSM woods).
const BOARD := Vector3(-2047,0,2104)
const COUNTER_FIRE := 180.0
const NORM := 90.0
const CHAPTERS := [
 {"title":"МАРШ НА ВАЖЕЛЯХ","minutes":6,"about":"Місце механіка-водія: маса, маслозакачувальний насос і стартер, сім передач, поворот важелями на шасі Т-72 і вибір місця на вогневій позиції."},
 {"title":"ПРИВЕДЕННЯ В БОЙОВЕ · 90 с","minutes":3,"about":"Пульт командира: живлення СУО, домкрати, стопори платформи й пакета. Норматив виробника — 90 секунд від зупинки до пуску."},
 {"title":"ПРЯМЕ НАВЕДЕННЯ · 1Д14","minutes":5,"about":"Місце навідника-оператора: платформа, головка прицілу, лазерний далекомір і обчислювач. Пуск двох ракет по мішені за 1,6 км."},
 {"title":"СТРІЛЬБА ЗА КООРДИНАТАМИ","minutes":7,"about":"Дрон спостережного пункту, позначка цілі, планшет і дані в обчислювач. Залп дванадцятьма ракетами парами по опорному пункту за 4 км."},
 {"title":"ВІДХІД З ВОГНЕВОЇ ПОЗИЦІЇ","minutes":3,"about":"Пакет у похідне, стопори, домкрати — і геть з позиції, поки противник не відповів контрбатарейним вогнем."}]
const STEPS := [
 [
  {"id":"driver","title":"Займи місце механіка-водія","text":"Машина стоїть у лісосмузі. Підійди до люка механіка-водія на носі зліва (маркер) і натисни F.","keys":["F"]},
  {"id":"master","title":"Увімкни масу","text":"Вимикач батарей подає живлення на щиток і насоси.","keys":["I"]},
  {"id":"prime","title":"Прокачай масло","text":"Утримуй P — маслозакачувальний насос (МЗН), доки тиск масла не перевищить 2 кгс/см² (кілька секунд). Сухий двигун стартер не крутить.","keys":["P"],"caption":"утримуй"},
  {"id":"start","title":"Запусти двигун","text":"Утримуй стартер, доки В-84 не підхопить. Датчик нейтралі не дасть крутити з увімкненою передачею.","keys":["X"],"caption":"утримуй"},
  {"id":"release","title":"Зніми гальма з защіпки","text":"SPACE — стоянкові гальма. Із затягнутими машина не рушить.","keys":["SPACE"]},
  {"id":"gear","title":"Увімкни передачу","text":"Вичави зчеплення (тримай SHIFT) і перемкни вгору: N → 1 → 2. По полю рушають з другої. Без зчеплення передача не вмикається.","keys":["SHIFT","+","E"]},
  {"id":"move","title":"Рушай","text":"Додай газ (W) і плавно відпусти зчеплення (SHIFT). Кинеш різко на малих обертах — двигун заглухне, тоді знову P і X.","keys":["W","/","SHIFT"]},
  {"id":"turn","title":"Поверни важелем","text":"Потягни лівий (A) або правий (D) важіль. Частковий хід — фрикціони борту пробуксовують, машина плавно повертає; до упору — борт на передачу нижче: на 2-й радіус 6 м. Повернись на 20°.","keys":["A","/","D"]},
  {"id":"drive","title":"Їдь на вогневу позицію","text":"ВП — поле за 600 м на схід (маркер «ВП»). Вищі передачі — SHIFT + E, гальмо — S. ПКМ — прилади. M — планшет із картою.","keys":["W","A","D","S"]},
  {"id":"orient","title":"Стань носом до цілі","text":"Платформа повертається на ±100°, але найкраще наводити, коли ціль попереду: так машину менше розгойдує при пуску. Маркер «ЦІЛЬ» — у межах 45° від носа.","keys":["A","D"]},
  {"id":"park","title":"Зупинись і затягни гальма","text":"S — гальмо до зупинки, SHIFT + Q — до нейтралі N, SPACE — гальма на защіпку. Від цієї миті йде норматив — 90 с.","keys":["S","SHIFT","Q","SPACE"]}],
 [
  {"id":"commander","title":"Перейди на місце командира","text":"C — наступне місце в машині: механік-водій → навідник → командир. Двигун лишається працювати: від нього гідравліка домкратів і приводів.","keys":["C"]},
  {"id":"console","title":"Відкрий пульт","text":"E — пульт командира БМ-1: живлення, домкрати, стопори, режим вогню.","keys":["E"]},
  {"id":"fcs","title":"Увімкни живлення СУО","text":"ЖИВЛЕННЯ СУО: баллістичний обчислювач і датчик крену готуються 40 с — увімкни першим, далі роби решту, поки він гріється.","keys":["E"]},
  {"id":"jacks","title":"Опусти домкрати","text":"ДОМКРАТИ: два кормові домкрати знімають навантаження з підвіски — машина не розгойдується при пуску. Опускаються лише на місці.","keys":["E"]},
  {"id":"stops","title":"Зніми стопори","text":"СТОПОРИ: на марші платформа й пакет застопорені на 0° і 0°. Знімаються 4 с.","keys":["E"]},
  {"id":"ready","title":"Дочекайся готовності СУО","text":"Лампа «СУО» на пульті загориться, коли обчислювач буде готовий. Перелік ліворуч — уся машина в бойовому.","keys":["E"]}],
 [
  {"id":"gunner","title":"Займи місце навідника-оператора","text":"C — до прицілу-далекоміра 1Д14. У прицілі ×8: марка-шеврон і шкала по 5 тисячних.","keys":["C"]},
  {"id":"traverse","title":"Наведи платформу на мішень","text":"Мішень — щит у полі за 1,6 км, на 35° ліворуч від носа (маркер). ← → — платформа (CTRL — точно). Марка має стати на мішень по напрямку.","keys":["←","→","CTRL"]},
  {"id":"range","title":"Виміряй дальність","text":"↑ ↓ або миша — головка прицілу: марку на основу мішені. R — лазер: 400 м – 10 км, ±10 м. Показання — червоним у полі зору.","keys":["↑","↓","R"]},
  {"id":"compute","title":"Дальність — в обчислювач","text":"ENTER: обчислювач візьме дальність, кут головки прицілу, крен і диферент машини — і сам наведе платформу й пакет. Зачекай, доки пакет стане.","keys":["ENTER"]},
  {"id":"arm","title":"Серія 2 і запобіжник","text":"C — до командира, E — пульт: СЕРІЯ до 2, ЗБРОЯ — зняти запобіжник. «ГОТОВИЙ ДО ПУСКУ» на пульті — можна.","keys":["C","E"]},
  {"id":"fire","title":"Пуск","text":"SPACE — пуск. Дві ракети підуть через 0,5 с. За кормою до 30 м — смертельна зона струменя.","keys":["SPACE"]},
  {"id":"observe","title":"Спостерігай розриви","text":"Політ на 1,6 км — кілька секунд. Розриви видно в прицілі (C — до навідника).","keys":["C"]}],
 [
  {"id":"drone","title":"Виклич дрон СП","text":"Місце командира, J. Спостережний пункт біля вихідних позицій штурму підніме дрон за 12 с; зв’язок через ретранслятор.","keys":["J"]},
  {"id":"pilot","title":"Візьми керування дроном","text":"Коли СП доповість, що дрон у повітрі, — J ще раз.","keys":["J"]},
  {"id":"find","title":"Знайди ціль","text":"Ціль — опорний пункт ОП-2 на півночі села, у колі «РАЙОН ЦІЛІ». W/A/S/D — політ, SPACE / CTRL — висота, SHIFT — швидше, колесо — зум.","keys":["W","A","S","D","SPACE","CTRL"]},
  {"id":"mark","title":"Познач ціль","text":"Перехрестя на будинок — T. Позначка має лягти ближче 40 м від цілі.","keys":["T"]},
  {"id":"back","title":"Повернись до пульта","text":"Дрон лишиться в повітрі й покаже розриви. J — до пульта.","keys":["J"]},
  {"id":"tablet","title":"Обери ціль на планшеті","text":"M — планшет: карта з GPS машини, сектор платформи й дальність. Праворуч обери позначену ціль.","keys":["M"]},
  {"id":"load","title":"Дані — в обчислювач","text":"«В ОБЧИСЛЮВАЧ І НАВЕСТИ» на планшеті (або ENTER на місці командира). Обчислювач рахує кут пакета з перевищенням цілі; пакет наведеться сам.","keys":["ENTER"]},
  {"id":"salvo","title":"Залп: 12 парами","text":"E — пульт: СЕРІЯ 12, ПАРАМИ, ЗБРОЯ. SPACE — пуск: 12 ракет за 3 с. Політ до 4 км — близько 20 с.","keys":["E","SPACE"]},
  {"id":"report","title":"Дочекайся доповіді СП","text":"СП доповість, де лягли розриви. G — журнал радіо. Якщо ОП-2 цілий — ще раз «В обчислювач» (врахує поправку) і пуск.","keys":["G","ENTER","SPACE"]}],
 [
  {"id":"stow","title":"Пакет у похідне","text":"Противник засік пуск: відповідь — за 2,5–4 хв. Пульт (E): ПОХІДНЕ — платформа й пакет на 0° і 0°.","keys":["E"]},
  {"id":"lock","title":"Застопори","text":"СТОПОРИ на пульті: 4 с.","keys":["E"]},
  {"id":"raise","title":"Підніми домкрати","text":"ДОМКРАТИ на пульті. Поки вони внизу, машина не рушить.","keys":["E"]},
  {"id":"seat","title":"До важелів","text":"C — місце механіка-водія.","keys":["C"]},
  {"id":"leave","title":"Залиш вогневу позицію","text":"SPACE — зняти гальма, SHIFT + E — передача, W — газ. Від’їдь від ВП на 300 м.","keys":["SPACE","SHIFT","E","W"]}]]

var tos: TosCommand
var board: StaticBody3D
var turn_from := 0.0
var stopped_at := -1.0
var shot: Dictionary={}
var leave_from := Vector3.ZERO
var lay_when_ready := false

func course_id() -> String:return "tos"
func course_title() -> String:return "ТОС-1А"
func course_role() -> String:return "ЕКІПАЖ БМ-1 «СОЛНЦЕПЁК»"
func chapters() -> Array:return CHAPTERS
func steps() -> Array:return STEPS
func loadout() -> Dictionary:return {"class":"tos","map":BattleMap.ID,"bag":[]}
func loading_tip() -> String:return "Полігон під Авдіївкою, противника немає. Картка кроку — праворуч угорі; F6 — виконати крок автоматично."
func death_text() -> String:return "Екіпаж вибув. Під час пуску ніхто не стоїть за кормою: струмінь б’є на десятки метрів."
func preparing_text() -> String:return "Машину ставлять на вогневу позицію."
func ground(point: Vector3) -> Vector3:return tos.ground(point)

func setup(owner_game: Node3D, ui_root: Control) -> void:
 super.setup(owner_game,ui_root)
 tos=game.tos

static func completed(owner_game: Node3D) -> Array:return progress(owner_game,"tos")

func on_begin() -> void:
 shot={};stopped_at=-1.0
 tos.training=true
 build_board()

func on_stop() -> void:
 if is_instance_valid(board):board.queue_free()
 board=null
 if is_instance_valid(tos):tos.training=false

func target_point() -> Vector3:return tos.strongpoints[TARGET_INDEX].point
func board_point() -> Vector3:return tos.ground(BOARD)

# The target board: a plywood shield on posts with a white field and a red
# cross, big enough for the sight at 1.6 km; it stops the laser.
func build_board() -> void:
 if is_instance_valid(board):board.queue_free()
 board=StaticBody3D.new();board.name="TosTargetBoard"
 board.set_meta("ballistic_material","wood")
 game.world_root.add_child(board)
 var at:=board_point()
 var face:=Vector3(TosCommand.FIRING_AREA.x,at.y,TosCommand.FIRING_AREA.z)
 board.look_at_from_position(at,face,Vector3.UP)
 board.rotate_object_local(Vector3.UP,PI)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(6.0,3.2,0.4)
 shape.shape=box;shape.position=Vector3(0,1.9,0);board.add_child(shape)
 var paint:=func(color: Color, size: Vector3, offset: Vector3) -> void:
  var mesh:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=size;mesh.mesh=cube
  var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=0.9
  mesh.material_override=material;mesh.position=offset;board.add_child(mesh)
 paint.call(Color(0.86,0.84,0.78),Vector3(6.0,3.2,0.12),Vector3(0,1.9,0))
 paint.call(Color(0.75,0.1,0.08),Vector3(5.2,0.5,0.14),Vector3(0,1.9,0))
 paint.call(Color(0.75,0.1,0.08),Vector3(0.5,2.8,0.14),Vector3(0,1.9,0))
 for x in [-2.6,2.6]:paint.call(Color(0.35,0.27,0.18),Vector3(0.2,1.6,0.2),Vector3(x,0.4,0.15))

# --- The vehicle put in a chapter's state -------------------------------------
func heading_to(point: Vector3) -> float:
 var fp:=TosCommand.FIRING_AREA
 return atan2(point.x-fp.x,-(point.z-fp.z))

func place(at: Vector3, yaw: float) -> void:
 var v:=tos.vehicle
 v.freeze=false;v.parked_time=0.0
 tos.place_vehicle(tos.ground(at),yaw)

func run_engine() -> void:
 var v:=tos.vehicle
 v.master=true;v.running=true;v.omega=TosVehicle.IDLE_RPM/60.0*TAU
 v.gear=TosVehicle.NEUTRAL;v.parking=true;v.clutch_pedal=0;v.starter=false

func deploy() -> void:
 var v:=tos.vehicle
 v.fcs_power=true;v.fcs_warm=1.0
 v.jacks_wanted=true;v.jacks=1.0;v.parking=true
 v.stops_locked=false;v.stop_motion=0.0

func mark_training_target() -> void:
 tos.targets.append({"name":"Ц-%d" % (tos.targets.size()+1),"point":target_point()})
 tos.selected_target=tos.targets.size()-1

func prepare(index: int) -> void:
 var v:=tos.vehicle
 build_board()
 if index<=0:
  game.player.global_position=tos.ground(v.to_global(Vector3(-3.4,0,-2.6)))+Vector3.UP*0.1
  tos.face(v.to_global(Vector3(-1.0,1.0,-2.4)))
  return
 place(TosCommand.FIRING_AREA,heading_to(target_point()))
 run_engine()
 stopped_at=tos.clock
 if index==1:tos.enter("driver");return
 deploy()
 tos.enter("commander")
 if index==3:mark_training_target();tos.selected_target=-1
 if index>=4:
  mark_training_target()
  preparing=1.6;lay_when_ready=true

func on_prepared() -> void:
 if lay_when_ready:
  lay_when_ready=false
  var v:=tos.vehicle
  v.compute(target_point(),"Ц-1")
  if v.lay_solution():v.platform_yaw=v.want_yaw;v.elevation=v.want_elevation

# --- Steps ------------------------------------------------------------------
func yaw_now() -> float:
 var f:=-tos.vehicle.global_basis.z
 return atan2(f.x,-f.z)

func on_enter(id: String) -> void:
 match id:
  "turn":turn_from=yaw_now()
  "commander":if stopped_at<0.0:stopped_at=tos.clock
  "fire","salvo":shot={"from":tos.vehicle.fired,"bursts":tos.burst_log.size(),"time":tos.clock}
  "leave":leave_from=tos.vehicle.global_position

func relative_to(point: Vector3) -> float:return float(tos.firing_data(point).relative)

func sight_error() -> float:
 var eye:=tos.vehicle.sight_transform()
 var f:=-eye.basis.z
 var to:=board_point()-eye.origin
 return rad_to_deg(Vector2(f.x,f.z).angle_to(Vector2(to.x,to.z)))

func ranged() -> bool:
 var reading: Dictionary=tos.vehicle.laser_reading
 return reading.has("point") and flat_distance(reading.point,board_point())<30.0

func marked() -> bool:
 for t in tos.targets:
  if flat_distance(t.point,target_point())<40.0:return true
 return false

func picked() -> bool:
 if tos.selected_target<0 or tos.selected_target>=tos.targets.size():return false
 return flat_distance(tos.targets[tos.selected_target].point,target_point())<40.0

func check(id: String) -> bool:
 var v:=tos.vehicle
 match id:
  "driver":return tos.seat=="driver"
  "master":return v.master
  "prime":return v.primed>0.0 or v.running
  "start":return v.running
  "release":return not v.parking
  "gear":return v.gear>=TosVehicle.NEUTRAL+1
  "move":return v.speed()>0.8
  "turn":return absf(angle_difference(turn_from,yaw_now()))>deg_to_rad(20.0)
  "drive":return flat_distance(v.global_position,TosCommand.FIRING_AREA)<70.0
  "orient":return absf(relative_to(target_point()))<=45.0 and flat_distance(v.global_position,TosCommand.FIRING_AREA)<120.0
  "park":
   var done:=v.parking and absf(v.speed())<0.3 and v.gear==TosVehicle.NEUTRAL
   if done and stopped_at<0.0:stopped_at=tos.clock
   return done
  "commander":return tos.seat=="commander"
  "console":return tos.hud.open_panel()=="console"
  "fcs":return v.fcs_power
  "jacks":return v.jacks>=1.0
  "stops":return not v.stops_locked and v.stop_motion<=0.0
  "ready":return v.fcs_ready() and v.jacks>=1.0 and not v.stops_locked and v.stop_motion<=0.0
  "gunner":return tos.seat=="gunner"
  "traverse":return absf(sight_error())<=0.6
  "range":return ranged()
  "compute":return v.solution.get("source","")=="1Д14" and not v.solution.has("error") and v.laid() and v.elevation>=1.0
  "arm":return v.armed and v.series==2
  "fire":return v.fired-int(shot.get("from",0))>=2
  "observe":return tos.burst_log.size()-int(shot.get("bursts",0))>=2
  "drone":return tos.drone_eta>=0 or is_instance_valid(tos.drone)
  "pilot":return tos.piloting
  "find":return marked() or (tos.piloting and is_instance_valid(tos.drone) and flat_distance(tos.drone.global_position,target_point())<450.0)
  "mark":return marked()
  "back":return not tos.piloting
  "tablet":return tos.hud.open_panel()=="tablet" and picked()
  "load":return picked() and v.solution.get("source","")==tos.targets[tos.selected_target].name and not v.solution.has("error") and v.laid() and v.elevation>=1.0
  "salvo":return v.fired-int(shot.get("from",0))>=12 or v.remaining()==0
  "report":return tos.strongpoints[TARGET_INDEX].destroyed or v.remaining()==0
  "stow":return absf(v.platform_yaw)<0.5 and v.elevation<0.5
  "lock":return v.stops_locked and v.stop_motion<=0.0
  "raise":return v.jacks<=0.0
  "seat":return tos.seat=="driver"
  "leave":return flat_distance(v.global_position,leave_from)>300.0
 return false

func readout_text(id: String) -> String:
 var v:=tos.vehicle
 match id:
  "prime":return "Тиск масла %.1f кгс/см² · потрібно понад 2" % v.oil_pressure
  "gear","move":return "Передача %s · %d км/год" % [TosVehicle.GEAR_NAMES[v.gear],roundi(absf(v.speed())*3.6)]
  "turn":return "Поворот %d° з 20° · важелі Л: %s · П: %s" % [roundi(absf(rad_to_deg(angle_difference(turn_from,yaw_now())))),v.lever_text(v.levers.x),v.lever_text(v.levers.y)]
  "drive":return "До ВП: %d м · %s · %d км/год" % [roundi(flat_distance(v.global_position,TosCommand.FIRING_AREA)),TosVehicle.GEAR_NAMES[v.gear],roundi(absf(v.speed())*3.6)]
  "orient","park":
   var r:=relative_to(target_point())
   return "Курсовий кут цілі %+d° · потрібно в межах ±45° %s" % [roundi(r),"· ДОБРЕ" if absf(r)<=45.0 else ""]
  "commander","console","fcs","jacks","stops","ready":
   var t:=tos.clock-stopped_at if stopped_at>=0.0 else 0.0
   return "Від зупинки %d с · норматив %d с · СУО %d %%" % [roundi(t),roundi(NORM),roundi(v.fcs_warm*100)]
  "traverse":return "Марка від мішені: %+.1f° по напрямку · платформа %+.1f°" % [sight_error(),v.platform_yaw]
  "range":
   var reading: Dictionary=v.laser_reading
   if reading.has("point"):return "1Д14: %d м · точка за %d м від мішені%s" % [roundi(reading.distance),roundi(flat_distance(reading.point,board_point())),"" if ranged() else " — наведи точніше"]
   return "Головка прицілу %+.1f° · R — виміряти" % v.sight_pitch
  "compute","load":return "Пакет %.1f° → %.1f° · платформа %+.1f° → %+.1f°" % [v.elevation,v.want_elevation,v.platform_yaw,v.want_yaw]
  "arm":return "Серія %d · %s · %s" % [v.series,"ЗБРОЯ" if v.armed else "запобіжник","ГОТОВИЙ" if v.ready_to_fire()=="" else v.ready_to_fire()]
  "fire","salvo":return "Випущено %d · ракет у пакеті %d" % [v.fired-int(shot.get("from",0)),v.remaining()]
  "observe":
   var bursts:=tos.burst_log.slice(int(shot.get("bursts",0)))
   if bursts.is_empty():return "Ракети в польоті…"
   var centre:=Vector3.ZERO
   for p in bursts:centre+=p
   centre/=bursts.size()
   return "Центр розривів за %d м від мішені" % roundi(flat_distance(centre,board_point()))
  "find":
   if is_instance_valid(tos.drone):return "Дрон до цілі: %d м" % roundi(flat_distance(tos.drone.global_position,target_point()))
  "mark":
   if tos.targets.is_empty():return ""
   var t:Dictionary=tos.targets[-1]
   return "%s за %d м від ОП-2%s" % [t.name,roundi(flat_distance(t.point,target_point())),"" if flat_distance(t.point,target_point())<40.0 else " — познач ще раз"]
  "report":return "Ракет %d · ОП-2 %s" % [v.remaining(),"ЗНИЩЕНО" if tos.strongpoints[TARGET_INDEX].destroyed else "ціла"]
  "stow","lock","raise","seat","leave":
   var left:=float(shot.get("time",tos.clock))+COUNTER_FIRE-tos.clock
   var t:="Відповідь противника — через %d:%02d" % [int(left)/60,int(left)%60] if left>0 else "У бою позицію вже накрило б — швидше!"
   if id=="stow":t+=" · пакет %+.1f° / %.1f°" % [v.platform_yaw,v.elevation]
   if id=="leave":t+=" · від ВП %d м" % roundi(flat_distance(v.global_position,leave_from))
   return t
 return ""

func can_skip(id: String) -> bool:return not id in ["observe"]

func refuse_skip(_id: String) -> void:
 tos.vehicle.say("Цей крок не пропускається: дочекайся розривів",3)

# F6: the step is done for the player.
func auto(id: String) -> void:
 var v:=tos.vehicle
 match id:
  "driver","seat":tos.enter("driver")
  "master":v.master=true
  "prime":v.master=true;v.primed=60.0
  "start":run_engine()
  "release":v.parking=false
  "gear":v.gear=TosVehicle.NEUTRAL+2
  "move","turn","drive","orient":
   place(TosCommand.FIRING_AREA,heading_to(target_point()))
   if tos.seat!="driver":tos.enter("driver")
   if not v.running:run_engine()
   v.gear=TosVehicle.NEUTRAL;v.throttle=0;v.parking=true
  "park":v.parking=true;v.gear=TosVehicle.NEUTRAL;v.linear_velocity=Vector3.ZERO;v.angular_velocity=Vector3.ZERO
  "commander":tos.enter("commander")
  "console":if tos.hud.open_panel()!="console":tos.hud.toggle("console")
  "fcs":v.fcs_power=true;v.master=true
  "jacks":
   if not v.running:run_engine()
   v.jacks_wanted=true;v.jacks=1.0
  "stops":v.stops_locked=false;v.stop_motion=0.0
  "ready":
   if not v.running:run_engine()
   deploy()
  "gunner":tos.hud.close_all();tos.enter("gunner")
  "traverse":
   var want:=v.laying(GradBallistics.bearing(board_point()-v.global_position),0.0)
   v.want_yaw=want.x;v.platform_yaw=want.x
  "range":
   var eye:=v.sight_transform()
   var to:=board_point()+Vector3.UP*1.2-eye.origin
   var flat:=Vector2(to.x,to.z).length()
   var platform_pitch:=rad_to_deg(-eye.basis.z.y)-v.sight_pitch
   v.sight_pitch=clampf(rad_to_deg(atan2(to.y,flat))-platform_pitch,-8.0,20.0)
   v.range_target()
   if not ranged():v.laser_reading={"distance":snappedf(eye.origin.distance_to(board_point()),5.0),"point":board_point(),"time":tos.clock}
  "compute":
   if not ranged():auto("range")
   tos.lay_by_laser()
   v.platform_yaw=v.want_yaw;v.elevation=v.want_elevation
  "arm":
   v.series=2;v.armed=true
  "fire","salvo":
   if id=="salvo":
    if not picked():mark_training_target()
    if v.solution.is_empty():tos.load_target()
    v.platform_yaw=v.want_yaw;v.elevation=v.want_elevation
   v.series=2 if id=="fire" else 12;v.pairs=true;v.armed=true
   if tos.seat=="driver" or tos.seat=="":tos.enter("commander")
   tos.fire()
  "drone":
   if tos.seat!="commander":tos.enter("commander")
   if not is_instance_valid(tos.drone):tos.spawn_drone();tos.drone_eta=-1
  "pilot":
   if tos.seat!="commander":tos.enter("commander")
   if not is_instance_valid(tos.drone):tos.spawn_drone();tos.drone_eta=-1
   tos.begin_piloting()
  "find":
   if is_instance_valid(tos.drone):
    var aim:=target_point()
    tos.drone.global_position=aim+Vector3(0,110,160)
    tos.drone.yaw=0.0
    tos.drone.camera_pitch=-0.6
  "mark":mark_training_target()
  "back":tos.end_piloting()
  "tablet":
   if not marked():mark_training_target()
   for i in range(tos.targets.size()):
    if flat_distance(tos.targets[i].point,target_point())<40.0:tos.selected_target=i
   if tos.hud.open_panel()!="tablet":tos.hud.toggle("tablet")
  "load":
   if not picked():auto("tablet")
   tos.load_target()
   v.platform_yaw=v.want_yaw;v.elevation=v.want_elevation
  "report":
   var sp: Dictionary=tos.strongpoints[TARGET_INDEX]
   if not sp.destroyed:sp.destroyed=true;tos.destroyed+=1
  "stow":
   v.solution={};v.armed=false;v.want_yaw=0.0;v.want_elevation=0.0;v.platform_yaw=0.0;v.elevation=0.0
  "lock":
   v.want_yaw=0.0;v.want_elevation=0.0;v.platform_yaw=0.0;v.elevation=0.0
   v.stops_locked=true;v.stop_motion=0.0
  "raise":
   v.want_yaw=0.0;v.want_elevation=0.0;v.platform_yaw=0.0;v.elevation=0.0
   v.jacks_wanted=false;v.jacks=0.0
  "leave":leave_from=v.global_position+Vector3(1000,0,0)

func after_auto(id: String) -> void:
 if id in ["move","turn","drive","orient"]:
  while not current().is_empty() and current().id in ["move","turn","drive","orient"]:advance(false)
  return
 advance(false)

func result_lines() -> Array[String]:
 var lines: Array[String]=[]
 if not tos.burst_log.is_empty():lines.append("РАКЕТ ВИПУЩЕНО  %d З 24" % tos.vehicle.fired)
 lines.append("ОП-2  %s" % ("ЗНИЩЕНО" if tos.strongpoints[TARGET_INDEX].destroyed else "НЕ ЗНИЩЕНО"))
 return lines

func layout_mode() -> String:
 var panel_open: String=tos.hud.open_panel()
 return "full" if panel_open=="" else ("console" if panel_open=="console" else ("compact_left" if panel_open=="tablet" else "compact"))

func markers_hidden() -> bool:
 return tos.hud.open_panel()!="" or tos.piloting and not current().get("id","") in ["find","mark"]

func marker() -> Dictionary:
 var s:=current()
 if s.is_empty() or preparing>0:return {}
 match s.id:
  "driver":
   if tos.seat=="":
    for item in tos.stations():
     if item.id=="driver":return {"point":item.point,"caption":"МЕХАНІК-ВОДІЙ"}
  "drive":return {"point":tos.ground(TosCommand.FIRING_AREA)+Vector3.UP*2.0,"caption":"ВП"}
  "orient","park":return {"point":target_point()+Vector3.UP*20.0,"caption":"ЦІЛЬ"}
  "traverse","range":return {"point":board_point()+Vector3.UP*4.0,"caption":"МІШЕНЬ"} if tos.seat!="gunner" else {}
  "find","mark":return {"point":target_point()+Vector3.UP*6.0,"caption":"РАЙОН ЦІЛІ","ring":60.0}
 return {}
