class_name BmpTraining
extends TrainingCourse

# «Навчання» for the driver-mechanic of the BMP-2, on the route of the
# column of the great assault with nobody on the field: the cold start from
# the batteries and the instrument panel, moving off with the main clutch,
# the gears and the yoke on the field road and the highway, the closed hatch
# and the three TNPO-170A prisms on the way to the dismount line at the edge
# of the wood, the squad out through the rear doors and back aboard.
const JUNCTION := Vector2(168.9,1865.0)
const HIGHWAY := Vector2(68.3,1555.6)
# Chapter 3 starts on the highway before the turn into the field corridor;
# the squad dismounts in the corridor along the wood before the village,
# where the men can find their way on foot (the village's navigation grid).
const ROAD_START := Vector2(-132.7,955.2)
const ROAD_TURN := Vector2(-311.0,418.4)
const LINE := Vector2(-188.0,175.0)
const LINE_APPROACH := Vector2(-165.0,215.0)
const LINE_RADIUS := 35.0
const CHAPTERS := [
 {"title":"ПУСК ДВИГУНА","minutes":3,"about":"Місце механіка-водія, вимикач батарей (маса), щиток приладів: тахометр, спідометр, ГПК-59, температура, тиск масла, вольтметр. Пуск УТД-20 стартером з вижатим головним фрикціоном."},
 {"title":"РУШАННЯ Й ВОДІННЯ","minutes":5,"about":"Стоянкове гальмо, головний фрикціон і передачі, рушання без заглухання, штурвал і ступені повороту. Польовою дорогою від посадки до траси й трасою на північ."},
 {"title":"ЗАКРИТИЙ ЛЮК І ДЕСАНТ","minutes":5,"about":"Закритий люк: огляд відділення управління, погляд у призму ТНПО-170А, водіння через призми, вихід на рубіж спішування на краю лісу, команди відділенню: «Десант» і «По місцях»."}]
const STEPS := [
 [
  {"id":"seat","title":"Сядь на місце механіка-водія","text":"БМП стоїть у посадці при польовій дорозі, двигун холодний. Люк механіка-водія — ліворуч попереду корпусу (маркер). Підійди й натисни F.","keys":["F"]},
  {"id":"master","title":"Увімкни масу","text":"Вимикач батарей (маса) живить щиток, стартер і приймач. На щитку загориться зелена лампа МАСА.","keys":["I"]},
  {"id":"panel","title":"Подивись на щиток","text":"Тримай ПКМ — щиток приладів великим планом. Двигун ще не працює: тахометр на нулі, горить червона лампа ТИСК МАСЛА.","keys":["ПКМ"],"caption":"утримуй"},
  {"id":"start","title":"Запусти двигун","text":"Передача — нейтраль. Вижми головний фрикціон (тримай SHIFT) і тримай стартер X, доки двигун не підхопить (1–2 с).","keys":["SHIFT","+","X"],"caption":"утримуй"},
  {"id":"gauges","title":"Перевір тиск масла й заряд","text":"ПКМ — щиток. За кілька секунд тиск масла має піднятися вище 2 кгс/см², вольтметр — показати 27–28 В: генератор заряджає батареї. Лампа ТИСК МАСЛА гасне.","keys":["ПКМ"]}],
 [
  {"id":"release","title":"Зніми зі стоянкового гальма","text":"Защіпка тримає гальма затягнутими; лампа СТОЯНКОВЕ на щитку згасне.","keys":["SPACE"]},
  {"id":"first","title":"Увімкни першу передачу","text":"Вижми головний фрикціон (тримай SHIFT) і E: нейтраль → 1. Без фрикціона шестерні не ввійдуть.","keys":["SHIFT","+","E"]},
  {"id":"move","title":"Рушай","text":"Додай паливо (W) і плавно відпусти SHIFT. Кинеш фрикціон різко на малих обертах — двигун заглухне, тоді знову X.","keys":["W","/","SHIFT"]},
  {"id":"second","title":"Друга передача","text":"Розженися до 8–10 км/год, вижми фрикціон і SHIFT + E — друга. На польовій дорозі — друга-третя.","keys":["SHIFT","+","E"]},
  {"id":"junction","title":"Польовою дорогою до траси","text":"Уздовж посадки на схід, до перехрестя з трасою (маркер «ТРАСА»). Штурвал A/D: що далі відхилиш, то крутіший поворот. S — гальмо.","keys":["W","A","S","D"]},
  {"id":"highway","title":"Трасою на північ","text":"На перехресті — ліворуч, на північ, і трасою до маркера. На рівному — третя-четверта передача (SHIFT + E). M — карта з маршрутом колони.","keys":["SHIFT","+","E","M"]},
  {"id":"stop","title":"Зупинись","text":"S — гальма; вижми фрикціон, Q — до нейтралі, SPACE — стоянкове. Машина стоїть, двигун працює.","keys":["S","SHIFT","Q","SPACE"]}],
 [
  {"id":"hatch","title":"Закрий люк","text":"Під обстрілом механік-водій їде з закритим люком: сидіння опущене, попереду три призми ТНПО-170А, ліворуч щиток приладів, праворуч — куліса передач. Мишею — огляд.","keys":["V"]},
  {"id":"prism","title":"Подивись у призму","text":"Наведи крапку на середню призму й тримай ПКМ: обличчя — до налобника, у призмі дорога попереду. Відпустиш ПКМ — знову видно щиток і важелі. На щитку ПКМ — прилади великим планом.","keys":["ПКМ"],"caption":"утримуй"},
  {"id":"line","title":"До рубежу спішування","text":"Рушай і веди машину, дивлячись у призму (ПКМ на ній): трасою на південний захід до повороту, далі полем уздовж лісу до рубежу перед селом (маркер). M — карта з маршрутом.","keys":["W","A","S","D","M"]},
  {"id":"halt","title":"Зупинись на рубежі","text":"Десант виходить лише з машини, що стоїть: S, фрикціон, нейтраль.","keys":["S","SHIFT","Q"]},
  {"id":"dismount","title":"Команда «Десант»","text":"1 — відділення виходить через кормові двері й займає кругову оборону за кормою. Дочекайся, доки вийдуть усі сім.","keys":["1"]},
  {"id":"mount","title":"Команда «По місцях»","text":"2 — посадка в машину. Двері зачиняються, коли всі на місцях.","keys":["2"]}]]

func course_id() -> String:return "bmp"
func course_title() -> String:return "БМП-2"
func course_role() -> String:return "МЕХАНІК-ВОДІЙ"
func chapters() -> Array:return CHAPTERS
func steps() -> Array:return STEPS
# Seven men in the troop compartment and the gunner-operator in the turret.
func loadout() -> Dictionary:return {"class":"bmp","primary":"ak74","secondary":"pm","map":BattleMap.ID,"bag":[],"allies":8}
func loading_tip() -> String:return "Маршрут колони під Авдіївкою, противника немає. Картка кроку — праворуч угорі; F6 — виконати крок автоматично."
func death_text() -> String:return "Механік-водій вибув. Почни розділ знову."
func preparing_text() -> String:return "Машину виводять на місце розділу."

func command() -> BmpCommand:return game.bmp
func vehicle() -> BmpVehicle:return game.bmp.vehicle
func squad() -> MechSquad:return game.bmp.squad
func ground(point: Vector3) -> Vector3:return Vector3(point.x,game.district.ground_height(point),point.z)
static func flat(p: Vector2) -> Vector3:return Vector3(p.x,0,p.y)

var odometer_from := 0.0

func on_begin() -> void:
 command().start_training()
 odometer_from=vehicle().odometer

func prepare(index: int) -> void:
 var cmd:=command()
 var v:=vehicle()
 if cmd.seat!="":cmd.leave()
 if index==0:
  # Two steps from the driver's hatch, facing it.
  game.player.global_position=ground(v.to_global(Vector3(-3.2,0,-1.6)))+Vector3.UP*0.1
  var d: Vector3=game.player.global_position-v.to_global(Vector3(-0.8,1.4,-1.3))
  game.player.rotation.y=atan2(d.x,d.z);game.player.pitch=-0.15
  return
 if index==2:put(ROAD_START,ROAD_TURN)
 run_engine()
 cmd.enter("driver")

# The vehicle on the road at `at`, its nose towards `toward`.
func put(at: Vector2, toward: Vector2) -> void:
 var v:=vehicle()
 var forward:=flat(toward-at).normalized()
 # Parked and frozen while it is carried: a moving body would be pulled back
 # by the step already under way. The released brake unfreezes it.
 v.parking=true;v.freeze_mode=RigidBody3D.FREEZE_MODE_STATIC;v.freeze=true
 var spot:=Transform3D(Basis.looking_at(forward,Vector3.UP),flat(at))
 v.linear_velocity=Vector3.ZERO;v.angular_velocity=Vector3.ZERO
 game.battle.place_vehicle(v,spot)
 # Once more before the next step, for a body that was moving.
 get_tree().physics_frame.connect(func():if is_instance_valid(v):game.battle.place_vehicle(v,spot),CONNECT_ONE_SHOT)
 game.district.operation_area.stream(v.global_position,40)
 game.district.operation_area.collide_trees(v.global_position)

func run_engine() -> void:
 var v:=vehicle()
 v.master=true;v.running=true;v.starter=false
 v.omega=BmpVehicle.IDLE_RPM/60.0*TAU;v.heard_rpm=BmpVehicle.IDLE_RPM
 v.gear=BmpVehicle.NEUTRAL;v.parking=true;v.clutch_pedal=0.0;v.throttle=0.0
 v.coolant=maxf(v.coolant,78.0);v.oil_temp=maxf(v.oil_temp,64.0);v.oil_pressure=2.6;v.volts=27.6

func near(point: Vector2, radius: float) -> bool:
 return Vector2(vehicle().global_position.x,vehicle().global_position.z).distance_to(point)<radius

func check(id: String) -> bool:
 var v:=vehicle();var cmd:=command()
 if not is_instance_valid(v):return false
 match id:
  "seat":return cmd.seat=="driver"
  "master":return v.master
  "panel":return cmd.cockpit.large>0.95
  "start":return v.running
  "gauges":return v.running and v.oil_pressure>=2.0 and v.volts>=26.5
  "release":return not v.parking
  "first":return v.gear==BmpVehicle.NEUTRAL+1
  "move":return v.speed()>0.8
  "second":return v.gear>=BmpVehicle.NEUTRAL+2 and v.speed()>1.5
  "junction":return near(JUNCTION,22.0)
  "highway":return near(HIGHWAY,25.0)
  "stop":return v.parking and absf(v.speed())<0.3 and v.gear==BmpVehicle.NEUTRAL and v.running
  "hatch":return not v.hatch_open
  "prism":return cmd.press=="lean" and cmd.lean>0.95
  "line":return near(LINE,LINE_RADIUS)
  "halt":return absf(v.speed())<0.5 and near(LINE,LINE_RADIUS+15.0)
  "dismount":return squad().aboard().is_empty() and squad().state=="guard" and squad().on_foot().size()>=1
  "mount":return squad().state=="mounted" and squad().on_foot().is_empty() and v.doors<0.05
 return false

func auto(id: String) -> void:
 var v:=vehicle();var cmd:=command()
 match id:
  "seat":cmd.enter("driver")
  "master":v.master=true
  "panel":pass
  "start","gauges":run_engine()
  "release":v.parking=false
  "first":v.gear=BmpVehicle.NEUTRAL+1
  "move","second":
   v.parking=false;v.gear=BmpVehicle.NEUTRAL+2
   v.linear_velocity=-v.global_basis.z*2.5
  "junction":put(JUNCTION,HIGHWAY);settle()
  "highway":put(HIGHWAY,HIGHWAY+(HIGHWAY-JUNCTION).normalized()*50.0);settle()
  "stop":settle()
  "hatch":v.hatch_open=false
  "prism":v.hatch_open=false
  "line","halt":put(LINE.lerp(LINE_APPROACH,0.5),LINE);settle()
  "dismount":
   settle()
   squad().order_dismount()
  "mount":
   for actor in squad().on_foot():v.board(actor)
   squad().set_state("mounted")
   v.open_doors(false)

# Standing still where F6 put it: neutral, the brake latched, engine on.
func settle() -> void:
 var v:=vehicle()
 v.linear_velocity=Vector3.ZERO;v.angular_velocity=Vector3.ZERO
 v.throttle=0.0;v.gear=BmpVehicle.NEUTRAL;v.parking=true
 if not v.running:run_engine()
 if command().seat!="driver":command().enter("driver")

func readout_text(id: String) -> String:
 var v:=vehicle()
 if not is_instance_valid(v):return ""
 var at:=Vector2(v.global_position.x,v.global_position.z)
 match id:
  "panel","gauges":return "Тиск масла %.1f кгс/см² · %.1f В · %d об/хв" % [v.oil_pressure,v.volts,roundi(v.steady_rpm())]
  "start":return "Стартер крутить…" if v.starter else ("Двигун заглушено" if not v.running else "")
  "first","move","second","stop","halt":return "Передача %s · %d км/год · %d об/хв" % [BmpVehicle.GEAR_NAMES[v.gear],roundi(absf(v.speed())*3.6),roundi(v.steady_rpm())]
  "junction":return "До траси %d м · %d км/год" % [roundi(at.distance_to(JUNCTION)),roundi(absf(v.speed())*3.6)]
  "highway":return "До маркера %d м · %d км/год · передача %s" % [roundi(at.distance_to(HIGHWAY)),roundi(absf(v.speed())*3.6),BmpVehicle.GEAR_NAMES[v.gear]]
  "line":return "До рубежу %d м · %d км/год" % [roundi(at.distance_to(LINE)),roundi(absf(v.speed())*3.6)]
  "dismount":return "У машині %d · вийшли %d" % [squad().aboard().size(),squad().on_foot().size()]
  "mount":return "У машині %d / %d" % [squad().aboard().size(),squad().members.size()]
 return ""

func marker() -> Dictionary:
 var s:=current()
 var v:=vehicle()
 if s.is_empty() or not is_instance_valid(v):return {}
 match s.id:
  "seat":return {"point":v.to_global(Vector3(-0.78,1.9,-1.3)),"caption":"ЛЮК МЕХАНІКА-ВОДІЯ"}
  "junction":return {"point":ground(flat(JUNCTION))+Vector3.UP*3.0,"caption":"ТРАСА","ring":12.0}
  "highway":return {"point":ground(flat(HIGHWAY))+Vector3.UP*3.0,"caption":"ТРАСОЮ НА ПІВНІЧ","ring":14.0}
  "line","halt":return {"point":ground(flat(LINE))+Vector3.UP*3.0,"caption":"РУБІЖ СПІШУВАННЯ","ring":LINE_RADIUS*0.6}
 return {}

func markers_hidden() -> bool:
 return game.topo_map.visible or command().cockpit.large>0.3

# Over the prisms the card goes down to the gear gate; the big panel too.
func layout_mode() -> String:
 if game.topo_map.visible:return "compact_left"
 if command().seat=="driver" and is_instance_valid(vehicle()) and (not vehicle().hatch_open or command().cockpit.large>0.05):return "compact"
 return "full"

func result_lines() -> Array[String]:
 var lines: Array[String]=[]
 if is_instance_valid(vehicle()):lines.append("ПРОЙДЕНО  %.1f КМ" % (vehicle().odometer-odometer_from))
 return lines
