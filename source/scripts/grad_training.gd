class_name GradTraining
extends TrainingCourse

# «Навчання» for the BM-21 drill, taught step by step on the Avdiivka map with
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
  {"id":"find","title":"Знайди ціль","text":"Ціль — опорний пункт ОП-2 на півночі села, в колі «РАЙОН ЦІЛІ». Політ W/A/S/D, SPACE — вгору, CTRL — вниз, SHIFT — швидше. Колесо миші — зум.","keys":["W","A","S","D","SPACE","CTRL"]},
  {"id":"mark","title":"Познач ціль далекоміром","text":"Наведи перехрестя на будинок і натисни T. Позначка «Ц-1» має лягти ближче 40 м від цілі.","keys":["T"]},
  {"id":"back","title":"Повернись до пульта","text":"Дрон залишиться в повітрі й покаже розриви. J — до пульта.","keys":["J"]}],
 [
  {"id":"tablet","title":"Відкрий планшет","text":"Карта з GPS машини й позначеними цілями. Праворуч обери Ц-1: дальність Дт, дирекційний кут αц, кут місця ε і АВТОРОЗРАХУНОК установок.","keys":["M"]},
  {"id":"read","ack":true,"title":"Запиши дані цілі","text":"АВТОРОЗРАХУНОК дає кутомір, приціл і рівень для Ц-1 — запам'ятай їх. Як вони рахуються вручну, підкажуть наступні кроки. Коли готовий — ENTER.","keys":["ENTER"]},
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

var grad: GradCommand
var lay_when_ready := false
var shot: Dictionary={}
var salvo_from := 0
var leave_from := Vector3.ZERO
var auto_fire := ""

func course_id() -> String:return "grad"
func course_title() -> String:return "БМ-21 «ГРАД»"
func course_role() -> String:return "КОМАНДИР ОБСЛУГИ РСЗВ"
func chapters() -> Array:return CHAPTERS
func steps() -> Array:return STEPS
func loadout() -> Dictionary:return {"class":"grad","map":BattleMap.ID,"bag":[]}
func loading_tip() -> String:return "Полігон під Авдіївкою, противника немає. Картка кроку — праворуч угорі; F6 — виконати крок автоматично."
func death_text() -> String:return "Командир вибув. Під час пуску не стій позаду пакета: струмінь газів б’є на десятки метрів."
func preparing_text() -> String:return "Машину ставлять на вогневу позицію й наводять на ціль."
func ground(point: Vector3) -> Vector3:return grad.ground(point)

func setup(owner_game: Node3D, ui_root: Control) -> void:
 super.setup(owner_game,ui_root)
 grad=game.grad

static func completed(owner_game: Node3D) -> Array:return progress(owner_game,"grad")

func on_begin() -> void:
 shot={};auto_fire=""
 grad.training=true

func on_stop() -> void:
 auto_fire=""
 if is_instance_valid(grad):grad.training=false;grad.lever_key=false

func on_finish() -> void:
 auto_fire="";grad.lever_key=false

func target_point() -> Vector3:
 return grad.strongpoints[TARGET_INDEX].point

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

func prepare(index: int) -> void:preset(index)

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
func on_enter(id: String) -> void:
 match id:
  "salvo":salvo_from=grad.vehicle.fired
  "leave":leave_from=shot.get("spot",grad.vehicle.global_position)

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

func body_text(s: Dictionary) -> String:
 return correct_text() if s.id=="correct" else s.text

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

func refuse_skip(_id: String) -> void:
 grad.vehicle.say("Цей крок не пропускається: дочекайся доповіді СП",3)

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

func after_auto(id: String) -> void:
 if id in ["sighting","salvo"]:return
 if id in ["drive","move","orient"]:
  # Driving is done all at once: on the position, oriented and stopped.
  while not current().is_empty() and current().id in ["move","drive","orient"]:advance(false)
  return
 advance(false)

func before_advance(id: String) -> void:
 if id=="sighting":
  var v:=grad.vehicle
  shot["sight"]=v.sight_setting;shot["deflection"]=v.deflection;shot["spot"]=v.global_position

func result_lines() -> Array[String]:
 var lines: Array[String]=[]
 if not grad.burst_log.is_empty():
  var aim:=target_point();var centre:=Vector3.ZERO
  for p in grad.burst_log:centre+=p
  centre/=grad.burst_log.size()
  lines.append("РАКЕТ ВИПУЩЕНО  %d · ЦЕНТР РОЗРИВІВ ЗА %d м ВІД ЦІЛІ" % [grad.vehicle.fired,roundi(flat_distance(centre,aim))])
 lines.append("ОП-2  %s" % ("ЗНИЩЕНО" if grad.strongpoints[TARGET_INDEX].destroyed else "НЕ ЗНИЩЕНО"))
 return lines

# --- Frame ---------------------------------------------------------------
func on_prepared() -> void:
 if lay_when_ready:lay_when_ready=false;lay_on_target()

func tick(_delta: float) -> void:
 var s:=current()
 if auto_fire!="":drive_auto_fire()
 if s.id=="sighting" and not shot.has("from"):shot["from"]=grad.vehicle.fired
 if s.id=="sighting" and grad.vehicle.fired>int(shot.get("from",0)) and not shot.has("time"):shot["time"]=grad.clock

func drive_auto_fire() -> void:
 var v:=grad.vehicle
 var done:=v.remaining()==0
 if auto_fire=="sighting":done=done or v.fired-int(shot.get("from",0))>=4
 if auto_fire=="salvo":done=done or grad.strongpoints[TARGET_INDEX].destroyed and v.fired-salvo_from>=12
 grad.lever_key=not done
 if done:auto_fire=""

func layout_mode() -> String:
 var panel_open: String=grad.hud.open_panel()
 return "full" if panel_open=="" else ("console" if panel_open=="console" else ("compact_left" if panel_open=="tablet" else "compact"))

func markers_hidden() -> bool:
 return grad.seat=="gunner" or grad.hud.open_panel()!=""

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
