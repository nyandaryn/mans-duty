extends RangeCourse

# «Навчання» for the UAV operator on the training range: a 7-inch FPV out of
# the pack and onto the pad, the goggles, the take-off and the flight in
# angle mode to a checkpoint; a strike with the PG-7VL warhead on a burnt-out
# BMP at 300 m; a fragmentation drone on the sandbagged position with its
# figures. A drone lost without a hit is made good by the range.
const FPV := preload("res://scripts/fpv_drone.gd")
const CHAPTERS := [
 {"title":"FPV: ЗЛІТ І ПОЛІТ","minutes":4,"about":"Майданчик БпЛА, дрон з наплічника на землю, окуляри, зліт, висота й політ у режимі «angle» до контрольної точки."},
 {"title":"КУМУЛЯТИВНИЙ ПО ТЕХНІЦІ","minutes":3,"about":"Захід на підбиту БМП за 300 м: висота, пікірування в дах або борт, бойова частина ПГ-7ВЛ спрацьовує від удару."},
 {"title":"ОСКОЛКОВИЙ ПО ПОЗИЦІЇ","minutes":3,"about":"Осколковий FPV по вогневій позиції в мішках за 350 м: захід і підрив над укриттям — від удару чи в повітрі, ЛКМ."}]
const STEPS := [
 [
  {"id":"pad","title":"Вийди на майданчик БпЛА","text":"Дощатий майданчик позаду вогневого рубежу, ліворуч (маркер «БПЛА»). Дрону для зльоту треба рівне місце, метр довкола — вільний.","keys":["W","A","S","D"]},
  {"id":"deploy","title":"Запусти FPV","text":"Y — FPV-дрон з наплічника (3,4 с), на землю перед собою (1 с), окуляри. Y ще раз — зняти окуляри; поки дрон на землі, він повернеться в наплічник.","keys":["Y"]},
  {"id":"takeoff","title":"Злети","text":"SPACE — газ: дрон відривається від землі, набирає висоту. Без газу він тримає висоту, CTRL — вниз. Набери 15 м. За 5 м від точки зльоту бойова частина взводиться.","keys":["SPACE","CTRL"]},
  {"id":"waypoint","title":"Долети до контрольної точки","text":"Режим «angle»: W / S — нахил уперед / назад, A / D — крен, SHIFT — більший нахил і швидкість, миша — поворот і нахил камери. Контрольна точка — 150 м уперед (маркер), над нею — понад 8 м від землі (ВИС на OSD — від точки зльоту).","keys":["W","A","S","D","SHIFT"]}],
 [
  {"id":"airborne","title":"FPV у повітрі","text":"Дрон з кумулятивною бойовою частиною в повітрі. Якщо він ще в наплічнику — Y, потім SPACE.","keys":["Y","SPACE"]},
  {"id":"strike","title":"Уразь БМП на 300 м","text":"Підбита БМП ліворуч у полі (маркер). Набери 25–40 м, вийди на ціль і пікіруй: W і CTRL — ціль у центрі кадру. ПГ-7ВЛ спрацьовує від удару; ЛКМ — підрив у повітрі.","keys":["W","CTRL","ЛКМ"],"caption":"влучання"}],
 [
  {"id":"frag_up","title":"Запусти осколковий FPV","text":"Y — наступний дрон, осколковий: по піхоті в окопах і за мішками. SPACE — зліт.","keys":["Y","SPACE"]},
  {"id":"frag","title":"Уразь вогневу позицію","text":"Позиція в мішках з трьома фігурами — 350 м уперед (маркер), поруч горілий автомобіль. Над позицією — пікірування; ЛКМ — підрив у повітрі на 2–3 м над мішками.","keys":["W","CTRL","ЛКМ"],"caption":"розрив до 6 м"}]]
# Warhead each step's drone carries.
const KIND_OF := {"deploy":"fpv_heat","takeoff":"fpv_heat","waypoint":"fpv_heat","airborne":"fpv_heat","strike":"fpv_heat","frag_up":"fpv_frag","frag":"fpv_frag"}
const CLIMB := 12.0
const WAYPOINT_RADIUS := 15.0
const FRAG_RADIUS := 6.0

var strikes := 0
var lost := 0
var note := ""

func course_id() -> String:return "uav"
func course_title() -> String:return "ОПЕРАТОР БПЛА"
func course_role() -> String:return "FPV · ПГ-7ВЛ · ОСКОЛКОВИЙ"
func chapters() -> Array:return CHAPTERS
func steps() -> Array:return STEPS
func loadout() -> Dictionary:return {"class":"uav","primary":"ak74","secondary":"pm","map":TrainingRange.ID,"bag":["fpv_heat","fpv_frag","medkit"]}
func target_ids() -> Array:return ["p1","p2","p3"]
func death_text() -> String:return "Оператор вибув. Почни розділ знову."

func on_begin() -> void:
 super.on_begin()
 strikes=0;lost=0;note=""

func prepare(index: int) -> void:
 if index==0:place(TrainingRange.UAV+Vector3(6,0,14),TrainingRange.UAV);return
 place(TrainingRange.UAV,TrainingRange.WAYPOINT)
 # The fragmentation chapter on its own: the drone of the chapter first.
 if index==2:
  for entry in player().backpack.items.duplicate():
   if entry.kind=="fpv_heat":player().backpack.remove(int(entry.uid))

func on_enter(id: String) -> void:
 super.on_enter(id)
 note=""

func rig() -> FieldRig:return player().field_rig

# The player's FPV, on the ground or in the air.
func drone() -> FPV:
 var d=rig().drone
 return d if is_instance_valid(d) and d is FPV and not d.over else null

func flying() -> bool:
 var d:=drone()
 return d!=null and d.launched() and d.piloting

func height() -> float:
 var d:=drone()
 if d==null:return 0.0
 return d.global_position.y-game.district.ground_height(d.global_position)

func tick(_delta: float) -> void:
 var s:=current()
 if s.is_empty():return
 var p:=player()
 # Lost without the step done: the range hands out another drone (not for
 # the one that has just struck).
 if (s.id=="strike" and burst_on_hulk()) or (s.id=="frag" and burst_on_position()):return
 var kind: String=KIND_OF.get(s.id,"")
 if kind!="" and s.id not in ["deploy"] and drone()==null and rig().mode not in ["access","fpv_place","goggles"] and p.backpack.count(kind)==0:
  if p.backpack.add(kind)>=0:
   # First in the pack: Y takes the step's drone, not another one.
   p.backpack.items.push_front(p.backpack.items.pop_back())
   lost+=1;note="Новий дрон у наплічнику · Y — запуск"

# A detonation since the step began, on the hulk or by the position.
func burst_on_hulk() -> bool:
 return game.blasts.detonations>blasts_at and TrainingRange.on_hulk("h300",game.blasts.last_detonation,0.8)

func burst_on_position() -> bool:
 return game.blasts.detonations>blasts_at and flat_distance(game.blasts.last_detonation,TrainingRange.POSITION)<FRAG_RADIUS

func check(id: String) -> bool:
 var p:=player()
 match id:
  "pad":return flat_distance(p.global_position,TrainingRange.UAV)<3.5
  "deploy":return rig().mode=="drone" and drone()!=null
  "takeoff":return flying() and height()>=CLIMB
  "waypoint":return flying() and flat_distance(drone().global_position,TrainingRange.WAYPOINT)<WAYPOINT_RADIUS and height()>8.0
  "airborne":return flying() and drone().warhead=="heat"
  "strike":
   if burst_on_hulk():strikes+=1;return true
  "frag_up":return flying() and drone().warhead=="frag"
  "frag":
   if burst_on_position():strikes+=1;return true
 return false

# The step's drone up in the goggles at once (F6): out of the pack, on the
# ground, goggles on.
func drone_up(kind: String) -> void:
 var p:=player()
 var d:=drone()
 if d!=null and d.warhead==("frag" if kind=="fpv_frag" else "heat"):
  if rig().mode!="drone" and d.begin_control():rig().mode="drone"
  return
 if d!=null or rig().mode!="":rig().cancel()
 if p.backpack.first(kind)<0:p.backpack.add(kind)
 var uid:=p.backpack.first(kind)
 if uid<0:return
 # In the pack's order: the step's drone first.
 var entry:=p.backpack.item(uid)
 rig().item_uid=uid;rig().kind=entry.kind;rig().fpv_warhead=FPV.warhead_of(entry)
 if rig().deploy_fpv() and rig().drone.begin_control():rig().mode="drone";rig().timer=0

# Up off the pad to a height, motors on (as the throttle does).
func lift(to: float) -> void:
 var d:=drone()
 if d==null:return
 if not d.launched():
  # Its resting height first: the lift is what counts as the take-off.
  if d.rest_y==INF:d.rest_y=d.global_position.y
  d.armed=true;d.state="manual"
 var ground: float=game.district.ground_height(d.global_position)
 d.global_position.y=maxf(d.global_position.y,ground+to)
 d.velocity=Vector3.ZERO

func auto(id: String) -> void:
 var p:=player()
 match id:
  "pad":place(TrainingRange.UAV,TrainingRange.WAYPOINT)
  "deploy":drone_up("fpv_heat")
  "takeoff","airborne":drone_up("fpv_heat");lift(CLIMB+3.0)
  "frag_up":drone_up("fpv_frag");lift(CLIMB+3.0)
  "waypoint":
   drone_up("fpv_heat");lift(CLIMB)
   var d:=drone()
   if d!=null:
    d.global_position=Vector3(TrainingRange.WAYPOINT.x,game.district.ground_height(TrainingRange.WAYPOINT)+20.0,TrainingRange.WAYPOINT.z)
    d.velocity=Vector3.ZERO
  "strike","frag":
   var point:=TrainingRange.HULKS.h300+Vector3(0,TrainingRange.HULL.y,0) if id=="strike" else TrainingRange.POSITION+Vector3(0,2.5,0)
   var d:=drone()
   if d!=null and d.launched():d.detonate(point,Vector3.DOWN,null)
   else:
    if d!=null or rig().mode!="":rig().cancel()
    var used:=p.backpack.first(KIND_OF[id])
    if used>=0:p.backpack.remove(used)
    game.blasts.warhead("heat" if id=="strike" else "frag",point,Vector3.DOWN,null)

func readout_text(id: String) -> String:
 var p:=player()
 var d:=drone()
 var extra:=("\n"+note) if note!="" else ""
 match id:
  "pad":return "До майданчика %d м" % roundi(flat_distance(p.global_position,TrainingRange.UAV))
  "deploy":
   match rig().mode:
    "access":return "Дрон з наплічника…"
    "fpv_place":return "На землю…"
    "goggles":return "Окуляри…"
   return "FPV у наплічнику: %d%s" % [p.backpack.count("fpv_heat")+p.backpack.count("fpv_frag"),extra]
 if d==null:return "Дрон не в повітрі%s" % extra
 # The card covers the OSD's link and video corner: they are repeated here.
 # «ВИС» on the OSD counts from the take-off point, the course from the ground.
 var flight:="Над землею %d м\nАКБ %d %% · зв’язок %d %% · відео %d %%" % [roundi(height()),roundi(d.battery*100),roundi(d.control*100),roundi(d.video*100)]
 match id:
  "waypoint":return "До точки %d м · %s" % [roundi(flat_distance(d.global_position,TrainingRange.WAYPOINT)),flight]
  "strike":return "До БМП %d м · %s" % [roundi(flat_distance(d.global_position,TrainingRange.HULKS.h300)),flight]+miss_text("strike")+extra
  "frag":return "До позиції %d м · %s" % [roundi(flat_distance(d.global_position,TrainingRange.POSITION)),flight]+miss_text("frag")+extra
 return flight+extra

func miss_text(id: String) -> String:
 if game.blasts.detonations<=blasts_at:return ""
 var center: Vector3=TrainingRange.HULKS.h300 if id=="strike" else TrainingRange.POSITION
 return "\nРозрив за %d м від цілі" % roundi(flat_distance(game.blasts.last_detonation,center))

func marker() -> Dictionary:
 var s:=current()
 if s.is_empty():return {}
 match s.id:
  "pad":return {"point":TrainingRange.UAV+Vector3(0,1.0,0),"caption":"БПЛА"}
  "takeoff","waypoint":return {"point":TrainingRange.WAYPOINT+Vector3(0,20.0,0),"caption":"КТ","ring":WAYPOINT_RADIUS}
  "airborne","strike":return {"point":TrainingRange.HULKS.h300+Vector3(0,3.0,0),"caption":"БМП"}
  "frag_up","frag":return {"point":TrainingRange.POSITION+Vector3(0,2.0,0),"caption":"ПОЗИЦІЯ"}
 return {}

# In the goggles the markers stay: the pilot finds the point by them.
func markers_hidden() -> bool:
 if not is_instance_valid(player()):return true
 if flying():return false
 return super.markers_hidden()

func result_lines() -> Array[String]:
 var lines: Array[String]=[]
 lines.append("УРАЖЕНЬ  %d" % strikes)
 if lost>0:lines.append("ДРОНІВ ВТРАЧЕНО  %d" % lost)
 return lines
