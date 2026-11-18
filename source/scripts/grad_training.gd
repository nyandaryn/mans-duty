class_name GradTraining
extends Control

# «Навчання»: the BM-21 drill taught step by step on the Avdiivka map with
# nobody on the field. Each step watches the real state of the vehicle; a
# card names the controls, a marker shows where to go, F6 does a step for the
# player. Five chapters can be started on their own: the vehicle is put in the
# state the previous chapters leave it in.
const TARGET_INDEX := 1
const LEFT_SECTOR := Vector2(-95.0,-45.0)
const RIGHT_SECTOR := Vector2(45.0,65.0)
const COUNTER_FIRE := 180.0
const CHAPTERS := [
 {"title":"МАРШ НА ВОГНЕВУ ПОЗИЦІЮ","minutes":6,"about":"Кабіна водія: запалювання й стартер, зчеплення та передачі, рух полем, вибір положення машини на вогневій позиції."},
 {"title":"ПЕРЕВЕДЕННЯ В БОЙОВЕ ПОЛОЖЕННЯ","minutes":4,"about":"Коробка відбору потужності й привід наведення, щитки, кран «БОЙОВЕ», стопор пакета, чохол і кронштейн прицілу."},
 {"title":"РОЗВІДКА ЦІЛІ ДРОНОМ","minutes":5,"about":"Термінал командира: дрон спостережного пункту через ретранслятор, пошук опорного пункту й лазерний далекомір."},
 {"title":"ДАНІ ДЛЯ СТРІЛЬБИ Й НАВЕДЕННЯ","minutes":6,"about":"Планшет і таблиця стрільби: кутомір, приціл, рівень. Наведення пакета по бусолі й рівню панорами ПГ-1М."},
 {"title":"ПУСК, КОРЕКТУРА, ЗМІНА ПОЗИЦІЇ","minutes":7,"about":"Пульт управління вогнем, пристрілювальна серія, доповідь СП і поправки, залп і відхід з позиції до відповіді противника."}]
const STEPS := [
 [
  {"id":"cab","title":"Сядь за кермо","text":"Машина стоїть у лісосмузі в похідному положенні. Підійди до лівих дверей кабіни — з’явиться підказка — і натисни F.","keys":["F"]},
  {"id":"ignition","title":"Увімкни запалювання","text":"На щитку загориться жовта лампа ЗАПАЛ.","keys":["I"]},
  {"id":"start","title":"Запусти двигун","text":"Тримай стартер, доки двигун не підхопить (0,5–1,5 с). Стартер крутить лише на нейтралі або з вижатим зчепленням.","keys":["X"],"caption":"утримуй"},
  {"id":"release","title":"Відпусти стоянкове гальмо","text":"Червона лампа СТОЯНК. згасне. Без неї машина не рушить.","keys":["SPACE"]},
  {"id":"first","title":"Увімкни першу передачу","text":"Вижми зчеплення (тримай SHIFT) і перемкни передачу вгору: N → 1. Без зчеплення шестерні скреготять і не вмикаються.","keys":["SHIFT","+","E"]},
  {"id":"move","title":"Рушай з місця","text":"Додай газ і плавно відпусти зчеплення. Кинеш різко на малих обертах — двигун заглухне, тоді знову X.","keys":["W","/","SHIFT"]},
  {"id":"drive","title":"Їдь на вогневу позицію","text":"ВП — відкрите поле за 600 м на південний захід (маркер «ВП»). Кермо A/D, гальмо S, вища передача — SHIFT + E. M — планшет із картою.","keys":["W","A","S","D"]},
  {"id":"orient","title":"Стань боком до цілі","text":"Пакет повертається на 102° ліворуч і 70° праворуч, а над кабіною пуск заблоковано. Постав машину так, щоб ціль була ліворуч під кутом 45–95°: маркер «ЦІЛЬ» — збоку від машини.","keys":["A","D"]},
  {"id":"park","title":"Зупинись і затягни стоянкове гальмо","text":"S — гальма. Вижми зчеплення, Q — до нейтралі N, потім SPACE. На ручнику машина тримає наведення під час залпу.","keys":["S","SHIFT","Q","SPACE"]}],
 [
  {"id":"pto","title":"Увімкни коробку відбору потужності","text":"КВП крутить генератор електроприводу наведення. Вмикають на місці: нейтраль і вижате зчеплення.","keys":["SHIFT","+","P"]},
  {"id":"throttle","title":"Додай ручний газ","text":"Генератору потрібні оберти близько 1400 за хвилину: натисни ] 7–8 разів. Тахометр — другий прилад на щитку.","keys":["]"]},
  {"id":"shields","title":"Опусти броньовані щитки","text":"Щитки закривають вітрове скло кабіни від полум’я та уламків під час пуску.","keys":["V"]},
  {"id":"exit","title":"Вийди з кабіни","text":"Далі — робота обслуги навколо машини. У цій версії ти виконуєш її сам.","keys":["F"]},
  {"id":"valve","title":"Кран «БОЙОВЕ»","text":"Лівий борт за кабіною (маркер). Кран вимикає ресори задніх мостів: машину менше розгойдує під час пуску.","keys":["F"]},
  {"id":"unlock","title":"Розстопори пакет","text":"Лівий борт біля середини машини. Похідне кріплення тримає пакет на марші; робота — 6 с.","keys":["F"]},
  {"id":"cover","title":"Зніми чохол","text":"Корма машини. Чохол знімається 20 с. Пуск через чохол його спалить.","keys":["F"]},
  {"id":"bracket","title":"Встанови кронштейн прицілу","text":"Місце навідника ліворуч від пакета. За 8 с приціл Д726-45 і панорама ПГ-1М у бойовому положенні.","keys":["F"]}],
 [
  {"id":"commander","title":"Сядь на місце командира","text":"Праві двері кабіни (маркер). Там пульт управління вогнем і термінал дрона спостережного пункту.","keys":["F"]},
  {"id":"drone","title":"Виклич дрон СП","text":"Спостережний пункт стоїть біля вихідних позицій штурму. Дрон злетить за 12 с; зв’язок іде через ретранслятор СП.","keys":["J"]},
  {"id":"pilot","title":"Візьми керування дроном","text":"Коли СП доповість, що дрон у повітрі, — J ще раз.","keys":["J"]},
  {"id":"find","title":"Знайди ціль","text":"Ціль — будинок-опорний пункт ОП-2 на першій вулиці, в колі «РАЙОН ЦІЛІ». Політ W/A/S/D, SPACE — вгору, CTRL — вниз, SHIFT — швидше. Колесо миші — зум.","keys":["W","A","S","D","SPACE","CTRL"]},
  {"id":"mark","title":"Познач ціль далекоміром","text":"Наведи перехрестя на будинок і натисни T. Позначка «Ц-1» має лягти ближче 40 м від цілі.","keys":["T"]},
  {"id":"back","title":"Повернись до пульта","text":"Дрон залишиться в повітрі й покаже розриви. J — до пульта.","keys":["J"]}],
 [
  {"id":"tablet","title":"Відкрий планшет","text":"Карта з GPS машини й позначеними цілями. Праворуч обери Ц-1: дальність Дт, дирекційний кут αц, кут місця ε і АВТОРОЗРАХУНОК установок.","keys":["M"]},
  {"id":"read","title":"Запиши дані цілі","text":"АВТОРОЗРАХУНОК дає кутомір, приціл і рівень для Ц-1 — запам'ятай їх. Як вони рахуються вручну, підкажуть наступні кроки. Коли готовий — ENTER.","keys":["ENTER"]},
  {"id":"gunner","title":"Займи місце навідника","text":"Закрий планшет (M), вийди з кабіни (F) і підійди до прицілу ліворуч від пакета.","keys":["M","F"]},
  {"id":"deflection","title":"Встанови кутомір","text":"Кутомір = αц − ПБ (1-55) + 30-00; якщо вийшло понад 60-00 — відніми 60-00. Q/E — по 0-01, з SHIFT — по 0-10, з ALT — по 1-00.","keys":["Q","E"]},
  {"id":"sight","title":"Встанови приціл","text":"Приціл — з таблиці стрільби для дальності (велике кільце). W/S — по 0-00,5, з SHIFT — по 0-10, з ALT — по 1-00.","keys":["W","S"]},
  {"id":"level","title":"Встанови рівень","text":"Рівень = 30-00 + кут місця цілі. A/D — по 0-01.","keys":["A","D"]},
  {"id":"boussole","title":"Наведи пакет по бусолі","text":"B — відкрити бусоль. Повертай пакет ← →, доки червона стрілка не стане на чорну риску. Стрілка ліворуч від риски — тисни ←.","keys":["B","←","→"]},
  {"id":"bubble","title":"Виведи бульбашку рівня","text":"↑ ↓ — кут пакета. Бульбашка має стати між рисками; праворуч від них — тисни ↑. Машина стоїть з креном, тож стрілка бусолі може зійти — доверни ← →.","keys":["↑","↓","←","→"]}],
 [
  {"id":"console","title":"Увімкни пульт","text":"Місце командира, E — пульт. ВБ-55 подає живлення, КОНТР. ПИТ. перевіряє лампу.","keys":["E"]},
  {"id":"arm","title":"Режим АВТ і програмний механізм","text":"Ключ — на АВТ, потім ЗВЕСТИ ПРОГРАМНИЙ МЕХАНІЗМ: він перемикає труби під час серії.","keys":["E"]},
  {"id":"sighting","title":"Пристрілювальна серія","text":"Утримуй SPACE (або кнопку ПУСК) близько 2 с — 4 ракети — і відпусти. Час польоту — на планшеті (~13 с до 5,5 км), СП доповість ще за 8 с.","keys":["SPACE"],"caption":"утримуй 2 с"},
  {"id":"report","title":"Дочекайся доповіді СП","text":"СП доповість, куди лягли розриви: переліт або недоліт у метрах, ліворуч або праворуч у тисячних. G — журнал радіо.","keys":["G"]},
  {"id":"correct","title":"Внеси поправки","text":"","keys":["F","Q","E","W","S"]},
  {"id":"salvo","title":"Залп","text":"Місце командира, пульт: звести програмний механізм, утримуй SPACE до кінця серії. 36 ракет — 18 с.","keys":["SPACE"],"caption":"утримуй"},
  {"id":"stow","title":"Пакет у похідне положення","text":"Противник засік пуск: відповідь прилетить за 2,5–4 хв. Біля прицілу виведи пакет на 0° і 0° (шкала повороту й квадрант), застопори пакет (F, лівий борт) і кран «ПОХІД».","keys":["←","→","↑","↓","F"]},
  {"id":"leave","title":"Залиш вогневу позицію","text":"За кермо: V — підняти щитки, SHIFT + P — вимкнути КВП, [ — прибрати ручний газ. Рушай і від’їдь від ВП на 300 м.","keys":["V","SHIFT","+","P","["]}]]

var game: Node3D
var grad: GradCommand
var running := false
var chapter := 0
var step := 0
var start_chapter := 0
var skipped := 0
var clock := 0.0
var step_clock := 0.0
var preparing := 0.0
var lay_when_ready := false
var acked := false
var flash := 0.0
var done_title := ""
# "full" at the top right; "console" without the chapter line and footer so
# it stays above the fire control panel; "compact" (title, keys, readout) at
# the bottom right over the tablet and the radio.
var layout := ""
var banner_left := 0.0
var shot: Dictionary={}
var salvo_from := 0
var leave_from := Vector3.ZERO
var auto_fire := ""
var finished_chapters: Array[int]=[]
var card: PanelContainer
var card_style: StyleBoxFlat
var head: Label
var chapter_label: Label
var title: Label
var body: Label
var keys_holder: VBoxContainer
var readout: Label
var progress_bar: Control
var footer: Label
var banner: VBoxContainer
var banner_title: Label
var banner_sub: Label

func setup(owner_game: Node3D, ui_root: Control) -> void:
 game=owner_game;grad=game.grad
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 game.place(self,ui_root,0,0,1,1)
 theme=UiKit.theme()
 card=PanelContainer.new()
 card_style=UiKit.flat(Color(0.03,0.045,0.038,0.9),UiKit.ACCENT,0,4)
 card_style.content_margin_left=20;card_style.content_margin_right=18
 card_style.content_margin_top=14;card_style.content_margin_bottom=14
 card.add_theme_stylebox_override("panel",card_style)
 card.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(card)
 card.anchor_left=1;card.anchor_right=1;card.anchor_top=0;card.anchor_bottom=0
 card.offset_left=-470;card.offset_right=-22;card.offset_top=22;card.offset_bottom=22
 card.grow_horizontal=Control.GROW_DIRECTION_BEGIN
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",5)
 box.custom_minimum_size.x=410;card.add_child(box)
 head=UiKit.text("",13,UiKit.ACCENT,"head");box.add_child(head)
 head.clip_text=true;head.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;head.custom_minimum_size.x=10
 chapter_label=UiKit.text("",12,UiKit.MUTED,"head");box.add_child(chapter_label)
 title=UiKit.text("",27,UiKit.INK,"display");title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(title)
 body=UiKit.wrapped("",15,UiKit.SOFT);box.add_child(body)
 keys_holder=VBoxContainer.new();box.add_child(keys_holder)
 readout=UiKit.wrapped("",16,UiKit.ACCENT);readout.add_theme_font_override("font",UiKit.font("head"));box.add_child(readout)
 progress_bar=Control.new();progress_bar.custom_minimum_size.y=12;box.add_child(progress_bar)
 progress_bar.draw.connect(draw_progress)
 footer=UiKit.text("F6 — ПРОПУСТИТИ КРОК   ·   ESC — ПАУЗА",11,UiKit.FAINT,"head");box.add_child(footer)
 banner=VBoxContainer.new();banner.alignment=BoxContainer.ALIGNMENT_CENTER
 banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
 game.place(banner,self,0.1,0.36,0.9,0.56)
 banner_title=UiKit.text("",64,UiKit.INK,"display");banner_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;banner.add_child(banner_title)
 banner_sub=UiKit.text("",18,UiKit.ACCENT,"head");banner_sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;banner.add_child(banner_sub)
 banner.hide()
 hide()

static func completed(owner_game: Node3D) -> Array:
 return owner_game.settings.get_value("training","grad",[])

func record(index: int) -> void:
 var list:Array=completed(game).duplicate()
 if index not in list:list.append(index);list.sort()
 game.settings.set_value("training","grad",list)
 if not game.get_meta("automated_preview",false):game.settings.save("user://settings.cfg")

# --- Course -----------------------------------------------------------------
func begin(index: int) -> void:
 start_chapter=clampi(index,0,CHAPTERS.size()-1)
 chapter=start_chapter;step=0;skipped=0;clock=0;flash=0;banner_left=0;banner.hide()
 shot={};auto_fire="";acked=false;finished_chapters.clear()
 grad.training=true
 running=true
 preset(chapter)
 enter_step()
 show()

func stop() -> void:
 running=false;auto_fire="";banner_left=0;banner.hide()
 if is_instance_valid(grad):grad.training=false;grad.lever_key=false
 hide()

func current() -> Dictionary:
 return STEPS[chapter][step] if running and chapter<STEPS.size() and step<STEPS[chapter].size() else {}

func target_point() -> Vector3:
 return grad.strongpoints[TARGET_INDEX].point

func flat_distance(a: Vector3, b: Vector3) -> float:return Vector2(a.x-b.x,a.z-b.z).length()

# Firing data of the training target from where the launcher stands.
func ideal() -> Dictionary:
 var d:=grad.firing_data(target_point())
 return {"deflection":fposmod(float(d.bearing)-GradVehicle.BOUSSOLE_CORRECTION+3000.0,6000.0),"sight":snappedf(GradBallistics.elevation_for(0,d.distance),0.5),"level":3000.0+roundf(d.site),"bearing":d.bearing,"distance":d.distance,"site":d.site,"relative":d.relative}

func needle() -> float:
 return wrapf(grad.vehicle.sight_bearing()-GradVehicle.BOUSSOLE_CORRECTION,-3000.0,3000.0)

func in_sector(relative: float) -> bool:
 return (relative>=LEFT_SECTOR.x and relative<=LEFT_SECTOR.y) or (relative>=RIGHT_SECTOR.x and relative<=RIGHT_SECTOR.y)

func firing_heading() -> float:
 var fp:=GradCommand.FIRING_AREA;var aim:=target_point()
 return GradBallistics.bearing(Vector3(aim.x-fp.x,0,aim.z-fp.z))*0.06+75.0

func place_vehicle(at: Vector3, heading_degrees: float) -> void:
 var v:=grad.vehicle
 var spot:=Vector3(at.x,grad.data.height(at.x,at.z)+0.3,at.z)
 v.release_parking()
 v.linear_velocity=Vector3.ZERO;v.angular_velocity=Vector3.ZERO
 v.global_transform=Transform3D(Basis(Vector3.UP,-deg_to_rad(heading_degrees)),spot)
 game.district.operation_area.stream(spot,40)
 game.district.operation_area.collide_trees(spot)

func run_engine() -> void:
 var v:=grad.vehicle
 v.ignition=true;v.running=true;v.omega=GradVehicle.IDLE_RPM/60.0*TAU
 v.gear=GradVehicle.NEUTRAL;v.handbrake=true;v.clutch_pedal=0

func deploy() -> void:
 var v:=grad.vehicle
 v.power_takeoff=true;v.hand_throttle=0.35
 v.shields_down=true;v.apply_shields(true)
 if not v.springs_locked:v.toggle_springs()
 v.travel_lock=false;v.set_cover(false);v.set_bracket(true)

func mark_training_target() -> void:
 grad.targets.append({"name":"Ц-%d" % (grad.targets.size()+1),"point":target_point()})
 grad.selected_target=grad.targets.size()-1

func lay_on_target() -> void:
 var v:=grad.vehicle;var d:=ideal()
 v.deflection=roundf(d.deflection);v.sight_setting=d.sight;v.level_setting=d.level
 lay_package()

func lay_package() -> void:
 var v:=grad.vehicle
 for i in range(10):
  v.azimuth=clampf(v.azimuth-needle()*0.06,GradVehicle.TRAVERSE_LEFT,GradVehicle.TRAVERSE_RIGHT)
  v.elevation=clampf(v.elevation-v.bubble_mils()*0.06,0.0,GradVehicle.ELEVATION_TOP)
  v.apply_launcher()

func laid() -> bool:
 return absf(needle())<=2.5 and absf(grad.vehicle.bubble_mils())<=1.5

func preset(index: int) -> void:
 var v:=grad.vehicle
 if index<=0:
  # A few steps from the driver's door, facing it, so the marker is in view.
  game.player.global_position=grad.ground(v.to_global(Vector3(-3.6,0,-1.0)))+Vector3.UP*0.1
  grad.face(v.to_global(Vector3(-1.45,1.0,-1.35)))
  return
 place_vehicle(GradCommand.FIRING_AREA,firing_heading())
 run_engine()
 if index==1:grad.enter("driver");return
 deploy()
 if index==2:
  game.player.global_position=grad.ground(v.to_global(Vector3(3.6,0,-1.0)))+Vector3.UP*0.1
  grad.face(v.to_global(Vector3(1.45,1.0,-1.35)))
  return
 mark_training_target()
 grad.enter("commander")
 if index>=4:
  # The package is laid once the vehicle has settled on the brake.
  preparing=1.6;lay_when_ready=true

# --- Steps ---------------------------------------------------------------
func enter_step() -> void:
 step_clock=0;acked=false
 var s:=current()
 if s.is_empty():return
 match s.id:
  "salvo":salvo_from=grad.vehicle.fired
  "leave":leave_from=shot.get("spot",grad.vehicle.global_position)
 refresh_card(true)

func check(id: String) -> bool:
 var v:=grad.vehicle
 match id:
  "cab":return grad.seat=="driver"
  "ignition":return v.ignition
  "start":return v.running
  "release":return not v.handbrake
  "first":return v.gear>=GradVehicle.NEUTRAL+1
  "move":return v.speed()>0.8
  "drive":return flat_distance(v.global_position,GradCommand.FIRING_AREA)<60.0
  "orient":return in_sector(ideal().relative) and flat_distance(v.global_position,GradCommand.FIRING_AREA)<110.0
  "park":return v.handbrake and absf(v.speed())<0.3 and v.gear==GradVehicle.NEUTRAL and in_sector(ideal().relative)
  "pto":return v.power_takeoff
  "throttle":return v.drive_power()>0.6
  "shields":return v.shields_down
  "exit":return grad.seat==""
  "valve":return v.springs_locked
  "unlock":return not v.travel_lock
  "cover":return not v.cover_on
  "bracket":return v.bracket_up
  "commander":return grad.seat=="commander"
  "drone":return grad.drone_eta>=0 or is_instance_valid(grad.drone)
  "pilot":return grad.piloting
  "find":return marked() or (grad.piloting and flat_distance(grad.drone.global_position,target_point())<450.0)
  "mark":return marked()
  "back":return not grad.piloting
  "tablet":return grad.hud.open_panel()=="tablet"
  "read":return acked
  "gunner":return grad.seat=="gunner"
  "deflection":return absf(wrapf(v.deflection-ideal().deflection,-3000.0,3000.0))<=2.0
  "sight":return absf(v.sight_setting-ideal().sight)<=1.0
  "level":return absf(v.level_setting-ideal().level)<=1.0
  "boussole":return absf(needle())<=2.5
  "bubble":return laid()
  "console":return v.battery_on
  "arm":return v.fire_mode==1 and v.program_wound
  "sighting":return v.fired-int(shot.get("from",0))>=2 and not v.lever and v.fired>0
  "report":return float(grad.last_report.get("time",-1.0))>float(shot.get("time",INF))
  "correct":
   var want:=corrected()
   return absf(v.sight_setting-float(want.sight))<=1.5 and absf(wrapf(v.deflection-float(want.deflection),-3000.0,3000.0))<=3.0 and laid()
  "salvo":return grad.strongpoints[TARGET_INDEX].destroyed or v.remaining()==0
  "stow":return v.travel_lock and not v.springs_locked
  "leave":return flat_distance(v.global_position,leave_from)>300.0
 return false

func marked() -> bool:
 for t in grad.targets:
  if flat_distance(t.point,target_point())<40.0:return true
 return false

# Settings the observer's report calls for: the sight moves by the range
# error over the range change per mil, the deflection by the side error.
func corrected() -> Dictionary:
 var report: Dictionary=grad.last_report
 var base_sight: float=shot.get("sight",grad.vehicle.sight_setting)
 var base_deflection: float=shot.get("deflection",grad.vehicle.deflection)
 if report.get("miss",false) or not report.has("along"):
  var d:=ideal();return {"sight":d.sight,"deflection":d.deflection}
 var distance: float=ideal().distance
 var e:=GradBallistics.elevation_for(0,distance)
 var per_mil:=maxf(1.0,absf(GradBallistics.range_for(0,e+1.0)-GradBallistics.range_for(0,e)))
 var along: float=report.along if absf(report.along)>15.0 else 0.0
 var side: float=report.mils if absf(report.mils)>3.0 else 0.0
 return {"sight":snappedf(base_sight-along/per_mil,0.5),"deflection":fposmod(roundf(base_deflection-side),6000.0),"per_mil":per_mil,"along":along,"side":side}

func correct_text() -> String:
 var want:=corrected()
 if not want.has("per_mil"):return "Розривів біля цілі не видно: перевір дані на планшеті, знову встанови кутомір, приціл і рівень, наведи по бусолі й рівню."
 var parts: Array[String]=[]
 if want.along>0:parts.append("Переліт %d м: приціл менше на %d / %d ≈ %s." % [roundi(want.along),roundi(want.along),roundi(want.per_mil),GradHud.sight_text(absf(want.along)/want.per_mil)])
 elif want.along<0:parts.append("Недоліт %d м: приціл більше на %d / %d ≈ %s." % [roundi(-want.along),roundi(-want.along),roundi(want.per_mil),GradHud.sight_text(absf(want.along)/want.per_mil)])
 if want.side>0:parts.append("Праворуч %s: кутомір менше на %s." % [GradBallistics.mils_text(want.side),GradBallistics.mils_text(want.side)])
 elif want.side<0:parts.append("Ліворуч %s: кутомір більше на %s." % [GradBallistics.mils_text(-want.side),GradBallistics.mils_text(-want.side)])
 if parts.is_empty():parts.append("Розриви в цілі — поправки не потрібні.")
 return " ".join(parts)+" Біля прицілу (F) внеси поправки й знову наведи по бусолі та рівню."

func readout_text(id: String) -> String:
 var v:=grad.vehicle
 match id:
  "drive":return "До ВП: %d м" % roundi(flat_distance(v.global_position,GradCommand.FIRING_AREA))
  "orient","park":
   var r: float=ideal().relative
   return "Курсовий кут цілі %+d° · потрібно %d…%d° %s" % [roundi(r),roundi(LEFT_SECTOR.x),roundi(LEFT_SECTOR.y),"· ДОБРЕ" if in_sector(r) else ""]
  "throttle":return "Оберти %d / хв · потрібно понад 1360" % roundi(v.rpm())
  "find":
   if is_instance_valid(grad.drone):return "Дрон до цілі: %d м" % roundi(flat_distance(grad.drone.global_position,target_point()))
  "mark":
   if grad.targets.is_empty():return ""
   var t:Dictionary=grad.targets[-1]
   return "%s за %d м від ОП-2%s" % [t.name,roundi(flat_distance(t.point,target_point())),"" if flat_distance(t.point,target_point())<40.0 else " — познач ще раз"]
  "read","tablet":
   var d:=ideal()
   return "Ц-1: Дт %d м · αц %s · ε %+d тис." % [roundi(d.distance),GradBallistics.mils_text(d.bearing),roundi(d.site)]
  "deflection":return "Кутомір %s → потрібно %s" % [GradBallistics.mils_text(v.deflection),GradBallistics.mils_text(roundf(ideal().deflection))]
  "sight":return "Приціл %s → потрібно %s" % [GradHud.sight_text(v.sight_setting),GradHud.sight_text(ideal().sight)]
  "level":return "Рівень %s → потрібно %s" % [GradBallistics.mils_text(v.level_setting),GradBallistics.mils_text(ideal().level)]
  "boussole":return "Стрілка бусолі: %+d тис. від риски" % roundi(needle())
  "bubble":return "Бульбашка: %+.1f тис. · стрілка %+d" % [v.bubble_mils(),roundi(needle())]
  "sighting":return "Випущено: %d" % (v.fired-int(shot.get("from",0)))
  "report":
   var flight:=float(shot.get("time",grad.clock))+28.0-grad.clock
   return "Ракети в польоті: ~%d с" % ceili(flight) if flight>0 else "Розриви є — СП оцінює…"
  "correct":
   var want:=corrected()
   return "Приціл %s → %s · Кутомір %s → %s" % [GradHud.sight_text(v.sight_setting),GradHud.sight_text(want.sight),GradBallistics.mils_text(v.deflection),GradBallistics.mils_text(want.deflection)]
  "salvo":return "Ракет: %d · ОП-2 %s" % [v.remaining(),"ЗНИЩЕНО" if grad.strongpoints[TARGET_INDEX].destroyed else "ціла"]
  "stow","leave":
   var left:=float(shot.get("time",grad.clock))+COUNTER_FIRE-grad.clock
   var t:="Відповідь противника — через %d:%02d" % [int(left)/60,int(left)%60] if left>0 else "У бою позицію вже накрило б — швидше!"
   if id=="stow":t+=" · пакет %+.1f° / %.1f°" % [v.azimuth,v.elevation]
   else:t+=" · від ВП %d м" % roundi(flat_distance(v.global_position,leave_from))
   return t
 return ""

func can_skip(id: String) -> bool:return id!="report"

# F6: the step is done for the player.
func auto(id: String) -> void:
 var v:=grad.vehicle
 match id:
  "cab":grad.enter("driver")
  "ignition":v.ignition=true
  "start":run_engine()
  "release":v.handbrake=false
  "first":v.gear=GradVehicle.NEUTRAL+1
  "move","drive","orient":
   # Put on the position, side-on to the target and stopped on the brake.
   place_vehicle(GradCommand.FIRING_AREA,firing_heading())
   if grad.seat!="driver":grad.enter("driver")
   if not v.running:run_engine()
   v.gear=GradVehicle.NEUTRAL;v.throttle=0;v.handbrake=true
  "park":v.handbrake=true;v.gear=GradVehicle.NEUTRAL;v.linear_velocity=Vector3.ZERO;v.angular_velocity=Vector3.ZERO
  "pto":v.gear=GradVehicle.NEUTRAL;v.power_takeoff=true
  "throttle":v.hand_throttle=0.35
  "shields":v.shields_down=true
  "exit":grad.leave()
  "valve":if not v.springs_locked:v.toggle_springs()
  "unlock":v.travel_lock=false
  "cover":v.set_cover(false)
  "bracket":v.set_bracket(true)
  "commander":grad.enter("commander")
  "drone":
   if not is_instance_valid(grad.drone):grad.spawn_drone();grad.drone_eta=-1
  "pilot":
   if grad.seat!="commander":grad.enter("commander")
   if not is_instance_valid(grad.drone):grad.spawn_drone();grad.drone_eta=-1
   grad.begin_piloting()
  "find":
   if is_instance_valid(grad.drone):
    var aim:=target_point()
    grad.drone.global_position=aim+Vector3(0,110,160)
    grad.drone.yaw=0.0
    grad.drone.camera_pitch=-0.6
  "mark":mark_training_target()
  "back":grad.end_piloting()
  "tablet":if grad.hud.open_panel()!="tablet":grad.hud.toggle("tablet")
  "read":acked=true
  "gunner":grad.hud.close_all();grad.enter("gunner")
  "deflection":v.deflection=roundf(ideal().deflection)
  "sight":v.sight_setting=ideal().sight
  "level":v.level_setting=ideal().level
  "boussole","bubble":lay_package()
  "console":if not v.battery_on:v.toggle_battery()
  "arm":v.set_mode(1);v.wind_program()
  "sighting","salvo":
   if grad.seat!="commander":grad.enter("commander")
   if not v.battery_on:v.toggle_battery()
   v.set_mode(1);v.wind_program()
   auto_fire=id
   return
  "correct":
   var want:=corrected()
   v.sight_setting=want.sight;v.deflection=want.deflection;lay_package()
  "stow":
   if grad.seat!="":grad.leave()
   v.azimuth=0;v.elevation=0;v.apply_launcher();v.travel_lock=true
   if v.springs_locked:v.toggle_springs()
  "leave":leave_from=v.global_position+Vector3(1000,0,0)

func skip() -> void:
 var s:=current()
 if s.is_empty() or preparing>0:return
 if not can_skip(s.id):
  grad.vehicle.say("Цей крок не пропускається: дочекайся доповіді СП",3);return
 skipped+=1
 auto(s.id)
 if s.id in ["sighting","salvo"]:return
 if s.id in ["drive","move","orient"]:
  # Driving is done all at once: on the position, oriented and stopped.
  while not current().is_empty() and current().id in ["move","drive","orient"]:advance(false)
  return
 advance(false)

func advance(by_player: bool=true) -> void:
 var s:=current()
 if s.is_empty():return
 if s.id=="sighting":
  var v:=grad.vehicle
  shot["sight"]=v.sight_setting;shot["deflection"]=v.deflection;shot["spot"]=v.global_position
 flash=0.9 if by_player else 0.4
 done_title=s.title
 if by_player:game.sound("click",-10)
 step+=1
 if step>=STEPS[chapter].size():
  finished_chapters.append(chapter);record(chapter)
  if chapter+1>=CHAPTERS.size():finish();return
  chapter+=1;step=0;game.training_chapter=chapter
  banner_title.text="РОЗДІЛ %d ЗАВЕРШЕНО" % chapter
  banner_sub.text="ДАЛІ: %s" % CHAPTERS[chapter].title
  banner_left=3.5
 enter_step()

func finish() -> void:
 running=false;auto_fire="";grad.lever_key=false
 var lines: Array[String]=[]
 # "З" of the condensed head font reads as a "3" next to the digits.
 lines.append("РОЗДІЛИ  %d–%d / %d" % [start_chapter+1,CHAPTERS.size(),CHAPTERS.size()])
 lines.append("ЧАС  %02d:%02d" % [int(clock)/60,int(clock)%60])
 if not grad.burst_log.is_empty():
  var aim:=target_point();var centre:=Vector3.ZERO
  for p in grad.burst_log:centre+=p
  centre/=grad.burst_log.size()
  lines.append("РАКЕТ ВИПУЩЕНО  %d · ЦЕНТР РОЗРИВІВ ЗА %d м ВІД ЦІЛІ" % [grad.vehicle.fired,roundi(flat_distance(centre,aim))])
 lines.append("ОП-2  %s" % ("ЗНИЩЕНО" if grad.strongpoints[TARGET_INDEX].destroyed else "НЕ ЗНИЩЕНО"))
 if skipped>0:lines.append("ПРОПУЩЕНО КРОКІВ  %d" % skipped)
 hide()
 game.training_result("КУРС ЗАВЕРШЕНО" if start_chapter==0 and skipped==0 else "НАВЧАННЯ ЗАВЕРШЕНО","\n".join(lines))

# --- Frame ---------------------------------------------------------------
func _process(delta: float) -> void:
 visible=running and game.running and not game.paused and game.training!=""
 if not visible:return
 clock+=delta;step_clock+=delta
 flash=maxf(0,flash-delta)
 if banner_left>0:
  banner_left-=delta
  banner.visible=banner_left>0
  banner.modulate.a=clampf(banner_left/0.6,0,1)*clampf((3.5-banner_left)/0.3,0,1)
 var panel_open: String=grad.hud.open_panel()
 apply_layout("full" if panel_open=="" else ("console" if panel_open=="console" else ("compact_left" if panel_open=="tablet" else "compact")))
 if preparing>0:
  preparing-=delta
  if preparing<=0:
   if lay_when_ready:lay_when_ready=false;lay_on_target()
   refresh_card(true)
  else:refresh_card(false)
  queue_redraw();return
 var s:=current()
 if s.is_empty():return
 if auto_fire!="":drive_auto_fire()
 if s.id=="sighting" and not shot.has("from"):shot["from"]=grad.vehicle.fired
 if s.id=="sighting" and grad.vehicle.fired>int(shot.get("from",0)) and not shot.has("time"):shot["time"]=grad.clock
 if step_clock>0.35 and check(s.id):advance(true);return
 refresh_card(false)
 queue_redraw()

func drive_auto_fire() -> void:
 var v:=grad.vehicle
 var done:=v.remaining()==0
 if auto_fire=="sighting":done=done or v.fired-int(shot.get("from",0))>=4
 if auto_fire=="salvo":done=done or grad.strongpoints[TARGET_INDEX].destroyed and v.fired-salvo_from>=12
 grad.lever_key=not done
 if done:auto_fire=""

func refresh_card(rebuild: bool) -> void:
 var s:=current()
 if preparing>0:
  head.text="НАВЧАННЯ · РОЗДІЛ %d / %d" % [chapter+1,CHAPTERS.size()]
  chapter_label.text=CHAPTERS[chapter].title
  title.text="Підготовка позиції…";body.text="Машину ставлять на вогневу позицію й наводять на ціль.";readout.text=""
  return
 if s.is_empty():return
 if rebuild:
  head.text="НАВЧАННЯ · РОЗДІЛ %d / %d · КРОК %d / %d" % [chapter+1,CHAPTERS.size(),step+1,STEPS[chapter].size()]
  chapter_label.text=CHAPTERS[chapter].title
  title.text=s.title
  for child in keys_holder.get_children():child.queue_free()
  var keys: Array=s.get("keys",[])
  if not keys.is_empty():keys_holder.add_child(UiKit.keys_row(keys,s.get("caption","")))
  footer.text="F6 — ПРОПУСТИТИ КРОК   ·   ESC — ПАУЗА" if can_skip(s.id) else "ESC — ПАУЗА"
 body.text=correct_text() if s.id=="correct" else s.text
 var live:=readout_text(s.id)
 readout.text=live;readout.visible=live!=""
 if flash>0:
  head.text="ВИКОНАНО · "+done_title.to_upper();head.add_theme_color_override("font_color",UiKit.GOOD);card_style.border_color=UiKit.GOOD
 else:
  head.text="НАВЧАННЯ · РОЗДІЛ %d / %d · КРОК %d / %d" % [chapter+1,CHAPTERS.size(),step+1,STEPS[chapter].size()]
  head.add_theme_color_override("font_color",UiKit.ACCENT);card_style.border_color=UiKit.ACCENT
 progress_bar.queue_redraw()

func draw_progress() -> void:
 if not running:return
 var count: int=STEPS[chapter].size()
 var w:=progress_bar.size.x;var gap:=4.0
 var cell:=(w-gap*(count-1))/count
 for i in range(count):
  var colour:=UiKit.ACCENT if i<step else (Color(UiKit.ACCENT,0.45) if i==step else Color(1,1,1,0.12))
  progress_bar.draw_rect(Rect2(i*(cell+gap),4,cell,4),colour)

func apply_layout(mode: String) -> void:
 if mode==layout:return
 layout=mode
 chapter_label.visible=mode=="full"
 footer.visible=mode=="full"
 body.visible=mode=="full" or mode=="console"
 var bottom:=mode!="full" and mode!="console"
 # Over the tablet the card sits at the bottom left, on the map: the data
 # column on the right is what the player reads.
 var left:=mode=="compact_left"
 card.anchor_left=0.0 if left else 1.0;card.anchor_right=card.anchor_left
 card.offset_left=22.0 if left else -470.0;card.offset_right=470.0 if left else -22.0
 card.grow_horizontal=Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
 card.anchor_top=1.0 if bottom else 0.0;card.anchor_bottom=card.anchor_top
 card.offset_top=-22.0 if bottom else 22.0;card.offset_bottom=card.offset_top
 card.grow_vertical=Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
 card.reset_size()

# Room the card takes at the top right, for the other overlays.
func reserved() -> float:
 return card.get_rect().end.y+16 if visible and (layout=="full" or layout=="console") else 0.0

# --- Markers on the scene --------------------------------------------------
func marker() -> Dictionary:
 var s:=current()
 if s.is_empty() or preparing>0:return {}
 var station:=func(id: String) -> Dictionary:
  for item in grad.stations():
   if item.id==id:return {"point":item.point,"caption":{"driver":"КАБІНА","commander":"КОМАНДИР","gunner":"ПРИЦІЛ","valve":"КРАН","lock":"СТОПОР","cover":"ЧОХОЛ"}[id]}
  return {}
 match s.id:
  "cab":return station.call("driver") if grad.seat=="" else {}
  "drive":return {"point":grad.ground(GradCommand.FIRING_AREA)+Vector3.UP*2.0,"caption":"ВП"}
  "orient","park":return {"point":target_point()+Vector3.UP*20.0,"caption":"ЦІЛЬ"}
  "valve":return station.call("valve") if grad.seat=="" else {}
  "unlock":return station.call("lock") if grad.seat=="" else {}
  "cover":return station.call("cover") if grad.seat=="" else {}
  "bracket","gunner":return station.call("gunner") if grad.seat=="" else {}
  "commander":return station.call("commander") if grad.seat=="" else {}
  "find","mark":return {"point":target_point()+Vector3.UP*6.0,"caption":"РАЙОН ЦІЛІ","ring":60.0}
  "stow":
   if grad.seat=="" and grad.vehicle.travel_lock==false and absf(grad.vehicle.azimuth)<0.6 and grad.vehicle.elevation<0.6:return station.call("lock")
   if grad.seat=="" and grad.vehicle.travel_lock:return station.call("valve")
   return station.call("gunner") if grad.seat=="" else {}
  "correct":return station.call("gunner") if grad.seat=="" else {}
  "salvo","console","sighting","arm":return station.call("commander") if grad.seat=="" else {}
 return {}

func _draw() -> void:
 if not running or not visible:return
 if grad.seat=="gunner" or grad.hud.open_panel()!="":return
 var m:=marker()
 if m.is_empty():return
 var camera:=get_viewport().get_camera_3d()
 if camera==null:return
 var point: Vector3=m.point
 # Too close to the eye to project: the station is right here.
 if camera.global_position.distance_to(point)<1.2:return
 var pulse:=0.5+0.5*sin(clock*4.0)
 if m.has("ring") and not camera.is_position_behind(point):
  var ring:=PackedVector2Array()
  for k in range(33):
   var a:=TAU*k/32.0
   var p:=grad.ground(point+Vector3(cos(a),0,sin(a))*float(m.ring))+Vector3.UP*2.0
   if camera.is_position_behind(p) or camera.global_position.distance_to(p)<1.0:ring.clear();break
   ring.append(camera.unproject_position(p))
  if ring.size()>1:
   for k in range(0,ring.size()-1,2):draw_line(ring[k],ring[k+1],Color(UiKit.ACCENT,0.8),2.0)
 var margin:=48.0
 var screen:=camera.unproject_position(point)
 var behind:=camera.is_position_behind(point)
 var inside:=not behind and Rect2(Vector2(margin,margin),size-Vector2(margin,margin)*2).has_point(screen)
 var distance:=camera.global_position.distance_to(point)
 var caption:="%s · %s" % [m.caption,("%d м" % roundi(distance)) if distance<1000 else ("%.1f км" % (distance/1000.0)).replace(".",",")]
 var font:=UiKit.font("head")
 if inside:
  var r:=11.0+pulse*3.0
  var diamond:=PackedVector2Array([screen+Vector2(0,-r),screen+Vector2(r,0),screen+Vector2(0,r),screen+Vector2(-r,0),screen+Vector2(0,-r)])
  draw_colored_polygon(diamond.slice(0,4),Color(UiKit.ACCENT,0.25))
  draw_polyline(diamond,UiKit.ACCENT,2.0)
  var w:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
  draw_rect(Rect2(screen+Vector2(-w*0.5-8,r+6),Vector2(w+16,22)),Color(0,0,0,0.55))
  draw_string(font,screen+Vector2(-w*0.5,r+22),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,UiKit.INK)
  return
 # Off screen: an arrow on the edge pointing the way.
 var centre:=size*0.5
 var direction:=(screen-centre)
 if behind:direction=-direction
 if direction.length()<1.0:direction=Vector2(0,1)
 direction=direction.normalized()
 var half:=size*0.5-Vector2(margin,margin)
 var scale:=minf(half.x/maxf(absf(direction.x),0.001),half.y/maxf(absf(direction.y),0.001))
 var at:=centre+direction*scale
 var tip:=at+direction*14.0;var side:=direction.orthogonal()*9.0
 draw_colored_polygon(PackedVector2Array([tip,at-direction*6.0+side,at-direction*6.0-side]),UiKit.ACCENT)
 var label_at:=at-direction*34.0
 var w2:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
 draw_string(font,label_at-Vector2(w2*0.5,-4),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,UiKit.INK)

func _input(event: InputEvent) -> void:
 if not running or not game.running or game.paused:return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_F6:skip();get_viewport().set_input_as_handled();return
  if event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER] and current().get("id","")=="read":
   acked=true;get_viewport().set_input_as_handled()
