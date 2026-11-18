class_name SniperTraining
extends RangeCourse

# «Навчання» for the sniper on the training range: the prone position and the
# PSO-1, the range from the rangefinder set on the elevation drum, a figure at
# 300 m, then the range read off the reticle for a figure at about 500 m.
const CHAPTERS := [
 {"title":"ПОЗИЦІЯ І ПРИЦІЛ ПСО-1","minutes":3,"about":"Позиція лежачи, приціл ПСО-1 4×, підсвітка сітки й затримка дихання."},
 {"title":"ДАЛЬНІСТЬ І БАРАБАН","minutes":4,"about":"Далекомір, барабан прицілу на дальність і два влучання в ростову мішень на 300 м."},
 {"title":"ДАЛЕКОМІРНА ШКАЛА","minutes":4,"about":"Дальність без далекоміра — за шкалою сітки ПСО-1 по зросту фігури 1,7 м; постріл на ≈500 м."}]
const STEPS := [
 [
  {"id":"mat","title":"Займи позицію","text":"Мат снайпера праворуч від рубежу (маркер «СНАЙПЕР»).","keys":["W","A","S","D"]},
  {"id":"prone","title":"Ляж","text":"Зі СВД стріляють лежачи: найменше гуляє сітка.","keys":["Z"]},
  {"id":"scope","title":"Подивись у приціл","text":"ПКМ — оптика ПСО-1, 4×. Утримуй, доки цілишся.","keys":["ПКМ"],"caption":"утримуй"},
  {"id":"light","title":"Підсвіти сітку","text":"L у прицілі — підсвітка сітки для сутінків і темного фону. Ще раз — вимкнути.","keys":["ПКМ","L"]},
  {"id":"breath","title":"Затримай дихання","text":"SHIFT у прицілі — затримати дихання: сітка майже не гуляє 4–5 с, потім боєць мусить віддихатися.","keys":["ПКМ","SHIFT"],"caption":"утримуй"}],
 [
  {"id":"measure","title":"Виміряй дальність","text":"K — далекомір. Коліщатко — кратність 6–12×: на 12× мішень удвічі більша. Наведи на ростову мішень з табличкою «300 м» (маркер) і натисни ЛКМ. K ще раз — сховати.","keys":["K","ЛКМ"]},
  {"id":"drum","title":"Встанови барабан","text":"Барабан прицілу — сотні метрів. У прицілі PgUp / PgDn — +100 / −100 м. Встанови дальність з далекоміра.","keys":["ПКМ","PgUp","PgDn"]},
  {"id":"hit300","title":"Влучи на 300 м","text":"Вершина центрального кутика — у центр фігури. SHIFT — затримати дихання, ЛКМ — постріл.","keys":["ПКМ","SHIFT","ЛКМ"],"caption":"2 влучання"}],
 [
  {"id":"estimate","title":"Визнач дальність за шкалою","text":"Фігура без таблички далі по смузі (маркер). Постав її ступні на нижню лінію далекомірної шкали ліворуч унизу сітки: де торкнеться голова — та дальність: цифри шкали — сотні метрів, для зросту 1,7 м. Встанови її на барабані.","keys":["ПКМ","PgUp","PgDn"]},
  {"id":"hit500","title":"Постріл на 500 м","text":"Затримай дихання й тисни плавно: на 500 м куля летить понад пів секунди.","keys":["ПКМ","SHIFT","ЛКМ"],"caption":"1 влучання"}]]

func course_id() -> String:return "sniper"
func course_title() -> String:return "СНАЙПЕР"
func course_role() -> String:return "СВД · ПСО-1 · ПОЛІГОН"
func chapters() -> Array:return CHAPTERS
func steps() -> Array:return STEPS
func loadout() -> Dictionary:return {"class":"sniper","primary":"svd","secondary":"pm","map":TrainingRange.ID,"bag":["medkit"]}
func target_ids() -> Array:return ["s300","s500"]

func prepare(index: int) -> void:
 if index==0:place(TrainingRange.SPAWN,TrainingRange.SNIPER+Vector3(0,0,-20));return
 place(TrainingRange.SNIPER,TrainingRange.TARGETS.s300.point if index==1 else TrainingRange.TARGETS.s500.point)
 stance(true)
 if index>=2:weapon().scope_zero=300

func on_enter(id: String) -> void:
 super.on_enter(id)
 if id=="light":seen["lit"]=weapon().scope_illuminated

func check(id: String) -> bool:
 var p:=player()
 match id:
  "mat":return flat_distance(p.global_position,TrainingRange.SNIPER)<1.8
  "prone":return p.prone
  "scope":return p.scope_sight.enabled
  "light":return weapon().scope_illuminated!=seen.get("lit",false)
  "breath":return saw("breath",p.holding_breath)
  "measure":return measured()
  "drum":return weapon().scope_zero==300
  "hit300":return hits("s300")>=2
  "estimate":return weapon().scope_zero==500
  "hit500":return hits("s500")>=1
 return false

func auto(id: String) -> void:
 match id:
  "mat":place(TrainingRange.SNIPER,TrainingRange.TARGETS.s300.point)
  "prone":stance(true)
  "light":weapon().scope_illuminated=not weapon().scope_illuminated
  "drum":weapon().scope_zero=300
  "hit300":score("s300",2)
  "estimate":weapon().scope_zero=500;face(TrainingRange.TARGETS.s500.point)
  "hit500":score("s500",1)

func readout_text(id: String) -> String:
 var p:=player()
 match id:
  "mat":return "До позиції %d м" % roundi(flat_distance(p.global_position,TrainingRange.SNIPER))
  "light":return "Підсвітка: %s" % ("увімкнена" if weapon().scope_illuminated else "вимкнена")
  "breath":return "Запас дихання %d %%" % roundi(p.breath_reserve*100)
  "measure":return p.field_rig.reading if p.field_rig.mode=="rangefinder" else ""
  "drum","estimate":return "Барабан: %d" % (weapon().scope_zero/100)
  "hit300":return hits_text("s300",2)+" · барабан %d" % (weapon().scope_zero/100)
  "hit500":return hits_text("s500",1)+" · барабан %d" % (weapon().scope_zero/100)
 return ""

func marker() -> Dictionary:
 var s:=current()
 if s.is_empty():return {}
 match s.id:
  "mat":return {"point":TrainingRange.SNIPER+Vector3(0,1.0,0),"caption":"СНАЙПЕР"}
  "measure","drum","hit300":return target_marker("s300","МІШЕНЬ")
  "estimate","hit500":return target_marker("s500","МІШЕНЬ")
 return {}

func result_lines() -> Array[String]:
 var lines: Array[String]=[]
 lines.append("ВЛУЧАНЬ НА 300 м  %d · НА 500 м  %d" % [targets.s300.hits if targets.has("s300") else 0,targets.s500.hits if targets.has("s500") else 0])
 return lines
