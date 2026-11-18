class_name MortarTraining
extends RangeCourse

# «Навчання» for the mortarman on the training range: the 2B14 brought into
# action alone in the pit, the firing data from the 1:10 000 sheet and the
# firing table, a first round watched and corrected until a burst lies on the
# enemy position 362 m away.
const HIT_RADIUS := 20.0
const CHAPTERS := [
 {"title":"РОЗГОРТАННЯ МІНОМЕТА","minutes":3,"about":"Вихід на вогневу позицію, розгортання 2Б14 «Піднос» самотужки й приціл МПМ-44М."},
 {"title":"ДАНІ ДЛЯ СТРІЛЬБИ","minutes":5,"about":"Дальність і дирекційний кут лінійкою по карті, таблиця стрільби, заряд, установки прицілу."},
 {"title":"ПОСТРІЛ І КОРЕКТУРА","minutes":5,"about":"Постріл, спостереження розриву, поправки по дальності й напрямку, ураження опорного пункту."}]
const STEPS := [
 [
  {"id":"pit","title":"Вийди на вогневу позицію","text":"Окоп з мішків праворуч (маркер «МІНОМЕТ»): відкрите небо над головою, поруч ящик мін.","keys":["W","A","S","D"]},
  {"id":"deploy","title":"Розгорни міномет","text":"Повернись обличчям до противника (маркер) і натисни N: плита, двонога, ствол, приціл. Самотужки ≈30 с, не рухайся.","keys":["N"]},
  {"id":"sight","title":"Відкрий приціл","text":"F біля міномета — приціл МПМ-44М: заряд, приціл і азимут, таблиця стрільби праворуч.","keys":["F"]}],
 [
  {"id":"map","title":"Відкрий карту","text":"Закрий приціл (F) і відкрий карту — M.","keys":["F","M"]},
  {"id":"ruler","title":"Виміряй лінійкою","text":"ЛКМ на окопі міномета (квадратик праворуч унизу аркуша) і тягни до опорного пункту противника ліворуч угорі. Лінійка дає дальність і дирекційний кут.","keys":["ЛКМ"],"caption":"тягни"},
  {"id":"charge","title":"Таблиця й заряд","text":"Закрий карту (M) і відкрий приціл (F). Таблиця — для поточного заряду: знайди дальність з лінійки. PgUp / PgDn — інший заряд.","keys":["M","F","PgUp","PgDn"]},
  {"id":"azimuth","title":"Встанови азимут","text":"← / → — азимут по 0-01, з SHIFT — по 0-10. Азимут — дирекційний кут з лінійки. Далі ніж 0-70 від двоноги — її переставляють (6 с).","keys":["←","→"]},
  {"id":"elevation","title":"Встанови приціл","text":"↑ / ↓ — приціл по 0-01, з SHIFT — по 0-10. Число — з таблиці для дальності з лінійки.","keys":["↑","↓"]}],
 [
  {"id":"fire","title":"Постріл","text":"SPACE у прицілі — постріл. Помічника немає: міну з ящика опускаєш сам.","keys":["SPACE"]},
  {"id":"observe","title":"Спостерігай розрив","text":"Закрий приціл (F) і дивись на опорний пункт або візьми далекомір (K). Розрив покаже, куди лягла міна.","keys":["F","K"]},
  {"id":"adjust","title":"Поправки й ураження","text":"","keys":["F","↑","↓","←","→","SPACE"]}]]

func course_id() -> String:return "mortarman"
func course_title() -> String:return "МІНОМЕТНИК"
func course_role() -> String:return "2Б14 «ПІДНОС» · ПОЛІГОН"
func chapters() -> Array:return CHAPTERS
func steps() -> Array:return STEPS
func loadout() -> Dictionary:return {"class":"mortarman","primary":"ak74","secondary":"pm","map":TrainingRange.ID,"bag":["medkit"]}
func target_ids() -> Array:return ["p1","p2","p3"]
func preparing_text() -> String:return "Міномет ставлять в окоп і наводять."

func crew() -> MortarCrew:return game.crew
func mortar() -> Mortar:return game.crew.mortar

func on_begin() -> void:
 super.on_begin()
 # Ten mines in a box beside the pit.
 crew().drop_load(TrainingRange.PIT+Vector3(-1.3,0,1.4),10,false)

func prepare(index: int) -> void:
 # The mortar and its plate weigh 47 kg: the course starts near the pit.
 if index==0:place(TrainingRange.PIT+Vector3(-14,0,5),TrainingRange.PIT);return
 place(TrainingRange.PIT,TrainingRange.POSITION)
 deploy_now()
 if index>=2:lay()

# The firing data of the enemy position from the mortar.
func data() -> Dictionary:
 var from: Vector3=mortar().global_position if mortar().state=="deployed" else TrainingRange.PIT
 var d:=TrainingRange.distance(from,TrainingRange.POSITION)
 var charge:=0
 while charge<MortarBallistics.CHARGES.size()-1 and MortarBallistics.elevation_for(charge,d)<0:charge+=1
 var e:=MortarBallistics.elevation_for(charge,d)
 return {"distance":d,"azimuth":MortarBallistics.azimuth(TrainingRange.POSITION-from),"charge":charge,"elevation":roundi(e),"time":MortarBallistics.time_for(charge,e)}

func deploy_now() -> void:
 if mortar().state=="deployed":return
 var forward: Vector3=-player().global_basis.z;forward.y=0;forward=forward.normalized()
 var point: Vector3=player().global_position+forward*0.9
 point.y=game.district.ground_height(point)
 if mortar().state=="assembling":
  # The half-done work of N is called off, or it would finish again later.
  player().field_rig.cancel()
  crew().abort_assembly()
 crew().finish_deploy(point,MortarBallistics.azimuth(forward),false)

func lay() -> void:
 var d:=data()
 mortar().set_charge(d.charge);mortar().set_azimuth(d.azimuth);mortar().set_elevation(d.elevation)
 mortar().relay_left=0.0

# Where the last burst lay from the enemy position: along the line of fire
# (+ over) and across it (+ right), in metres.
func burst_offset() -> Vector2:
 var from: Vector3=mortar().global_position if is_instance_valid(mortar()) else TrainingRange.PIT
 var line:=Vector2(TrainingRange.POSITION.x-from.x,TrainingRange.POSITION.z-from.z).normalized()
 var miss:=Vector2(game.blasts.last_detonation.x-TrainingRange.POSITION.x,game.blasts.last_detonation.z-TrainingRange.POSITION.z)
 return Vector2(miss.dot(line),miss.dot(Vector2(-line.y,line.x)))

func burst_text() -> String:
 var o:=burst_offset()
 var along:="переліт %d м" % roundi(o.x) if o.x>3 else ("недоліт %d м" % roundi(-o.x) if o.x<-3 else "по дальності в цілі")
 var side:="праворуч %d м" % roundi(o.y) if o.y>3 else ("ліворуч %d м" % roundi(-o.y) if o.y<-3 else "по напрямку в цілі")
 return "Розрив: %s, %s" % [along,side]

func on_enter(id: String) -> void:
 super.on_enter(id)
 if id=="fire":seen["shots"]=mortar().shots

func check(id: String) -> bool:
 var p:=player()
 match id:
  "pit":return flat_distance(p.global_position,TrainingRange.PIT)<1.8
  "deploy":return mortar().state=="deployed"
  "sight","charge":return crew().sight.visible and (id=="sight" or MortarBallistics.elevation_for(mortar().charge,data().distance)>=0)
  "map":return game.topo_map.visible
  "ruler":
   var map: TopoMap=game.topo_map
   if not (map.ruler_from.is_finite() and map.ruler_to.is_finite()):return false
   return Vector2(TrainingRange.PIT.x,TrainingRange.PIT.z).distance_to(map.ruler_from)<12.0 and Vector2(TrainingRange.POSITION.x,TrainingRange.POSITION.z).distance_to(map.ruler_to)<15.0 and not map.measuring
  "azimuth":return absi(wrapi(mortar().azimuth-int(data().azimuth),-3000,3000))<=3
  "elevation":return absi(mortar().elevation-int(data().elevation))<=3
  "fire":return mortar().shots>int(seen.get("shots",0))
  "observe":return game.blasts.detonations>blasts_at
  "adjust":return game.blasts.detonations>blasts_at and flat_distance(game.blasts.last_detonation,TrainingRange.POSITION)<HIT_RADIUS
 return false

func can_skip(id: String) -> bool:return id!="observe"

func refuse_skip(_id: String) -> void:
 crew().tell("Міна в повітрі: дочекайся розриву.")

func auto(id: String) -> void:
 match id:
  "pit":place(TrainingRange.PIT,TrainingRange.POSITION)
  "deploy":
   if flat_distance(player().global_position,TrainingRange.PIT)>2.0:place(TrainingRange.PIT,TrainingRange.POSITION)
   deploy_now()
  "sight","charge":
   game.topo_map.close()
   if not crew().sight.visible:crew().sight.open()
   if id=="charge":mortar().set_charge(data().charge)
  "map":
   crew().sight.close()
   if not game.topo_map.visible:game.topo_map.open()
  "ruler":
   game.topo_map.ruler_from=Vector2(TrainingRange.PIT.x,TrainingRange.PIT.z)
   game.topo_map.ruler_to=Vector2(TrainingRange.POSITION.x,TrainingRange.POSITION.z)
   game.topo_map.queue_redraw();game.topo_map.view.queue_redraw()
  "azimuth":mortar().set_azimuth(data().azimuth);mortar().relay_left=0.0
  "elevation":mortar().set_elevation(data().elevation)
  "fire":
   lay()
   mortar().reload_left=0.0
   if not crew().player_fire():mortar().fire(player())
  "adjust":game.blasts.detonate(TrainingRange.POSITION+Vector3(2,0,1),"mine")

func body_text(s: Dictionary) -> String:
 if s.id!="adjust":return s.text
 return "Міномет: що крутіше ствол, то ближче лягає міна. Переліт — приціл більше, недоліт — менше. Праворуч — азимут менше, ліворуч — більше: 0-01 на %d м — це ≈%.1f м убік. Ціль уражена, коли розрив ближче %d м." % [roundi(data().distance),data().distance/1000.0,roundi(HIT_RADIUS)]

func readout_text(id: String) -> String:
 var d:=data()
 match id:
  "pit":return "До окопу %d м" % roundi(flat_distance(player().global_position,TrainingRange.PIT))
  "deploy":return "Розгортання %d %%" % roundi(mortar().assembly*100) if mortar().state=="assembling" else ""
  "ruler":return game.topo_map.ruler_text() if game.topo_map.ruler_from.is_finite() and game.topo_map.ruler_to.is_finite() else ""
  "charge":return "Заряд %s: %s" % [MortarBallistics.CHARGES[mortar().charge],"дістає" if MortarBallistics.elevation_for(mortar().charge,d.distance)>=0 else "не дістає — інший заряд"]
  "azimuth":return "Азимут %s → потрібно %s" % [MortarBallistics.mils_text(mortar().azimuth),MortarBallistics.mils_text(d.azimuth)]
  "elevation":return "Приціл %d → потрібно %d (заряд %s, %d м)" % [mortar().elevation,d.elevation,MortarBallistics.CHARGES[mortar().charge],roundi(d.distance)]
  "fire":return "Приціл %d · азимут %s · заряд %s" % [mortar().elevation,MortarBallistics.mils_text(mortar().azimuth),MortarBallistics.CHARGES[mortar().charge]]
  "observe":return burst_text() if game.blasts.detonations>blasts_at else "Міна в польоті ≈%d с" % ceili(d.time)
  "adjust":
   if game.blasts.detonations==0:return ""
   return "%s · приціл %d, азимут %s" % [burst_text(),mortar().elevation,MortarBallistics.mils_text(mortar().azimuth)]
 return ""

func marker() -> Dictionary:
 var s:=current()
 if s.is_empty():return {}
 match s.id:
  "pit":return {"point":TrainingRange.PIT+Vector3(0,1.2,0),"caption":"МІНОМЕТ"}
  "deploy":return {"point":TrainingRange.POSITION+Vector3(0,4,0),"caption":"ПРОТИВНИК"}
  "sight","charge","fire":
   if crew().sight.visible or not is_instance_valid(mortar()):return {}
   return {"point":mortar().global_position+Vector3(0,1.0,0),"caption":"ПРИЦІЛ"}
  "observe","adjust":return {"point":TrainingRange.POSITION+Vector3(0,4,0),"caption":"ОПОРНИЙ ПУНКТ"}
 return {}

func result_lines() -> Array[String]:
 var lines: Array[String]=[]
 lines.append("МІН ВИПУЩЕНО  %d" % (mortar().shots if is_instance_valid(mortar()) else 0))
 if game.blasts.last_detonation.is_finite():
  lines.append("ОСТАННІЙ РОЗРИВ ЗА %d м ВІД ЦІЛІ" % roundi(flat_distance(game.blasts.last_detonation,TrainingRange.POSITION)))
 return lines
