extends RangeCourse

# «Навчання» for the grenadier on the training range: the RPG-7V1 off the
# pack's mount, a PG-7VL loaded, the danger zone behind checked, the PGO-7's
# chevrons on burnt-out BMP hulks at 200 and 300 m; then the RPG-22 taken off
# its mount, brought into the firing position and fired at 150 m. A missed
# round is made good by the range: a new one in the pack.
const CHAPTERS := [
 {"title":"РПГ-7: ПІДГОТОВКА","minutes":3,"about":"Рубіж гранатометника, РПГ-7В1 з кріплення наплічника, заряджання пострілом ПГ-7ВЛ і перевірка небезпечної зони позаду."},
 {"title":"ПГО-7: ШЕВРОНИ","minutes":4,"about":"Оптичний приціл ПГО-7В3, 2,7×: шеврони 2…5 — дальність 200…500 м. Постріли по підбитих БМП на 200 і 300 м, перезаряджання."},
 {"title":"РПГ-22","minutes":3,"about":"Одноразовий РПГ-22: зняти з кріплення, перевести в бойове положення (назад не складається), рамка 5 / 15 / 25 — постріл по БМП на 150 м."}]
const STEPS := [
 [
  {"id":"post","title":"Вийди на рубіж гранатометника","text":"Гравійна смуга ліворуч від вогневого рубежу (маркер «ГРАНАТОМЕТ»). Попереду в полі — три підбиті БМП: на 150, 200 і 300 м.","keys":["W","A","S","D","SHIFT"]},
  {"id":"draw","title":"Зніми РПГ-7 з кріплення","text":"4 — РПГ-7В1 з кріплення наплічника на праве плече (3 с). 4 ще раз — назад на кріплення; 1 — до автомата.","keys":["4"]},
  {"id":"load","title":"Заряди ПГ-7ВЛ","text":"R — постріл з наплічника: метальний заряд у трубу, гранату — у дуло до фіксатора (6 с). Заряджений РПГ-7 можна повернути на кріплення.","keys":["R"]},
  {"id":"rear","title":"Перевір зону позаду","text":"З сопла б'є реактивний струмінь: позаду до 8 м — нікого, стіна ближче за метр ударить по самому стрільцю. Озирнись мишею назад — чисто — і повернись до цілі.","keys":["МИША"]}],
 [
  {"id":"scope","title":"Подивись у ПГО-7","text":"ПКМ — око до прицілу: 2,7×, поле зору 13°. Верхній шеврон — 200 м, нижче — 3, 4, 5: 300…500 м. Ліворуч — дальномірна шкала на ціль заввишки 2,7 м.","keys":["ПКМ"],"caption":"утримуй"},
  {"id":"hit200","title":"Шеврон «2» — БМП на 200 м","text":"Найближча прямо — БМП на 200 м (маркер). Вершину шеврона «2» — на середину борту, плавно ЛКМ.","keys":["ПКМ","ЛКМ"],"caption":"влучання в корпус"},
  {"id":"reload","title":"Перезаряди","text":"РПГ-7 лишився в руках, порожній. R — наступний ПГ-7ВЛ з наплічника.","keys":["R"]},
  {"id":"hit300","title":"Шеврон «3» — БМП на 300 м","text":"Дальня БМП ліворуч, 300 м (маркер). Шеврон «3» — на середину борту. Граната летить понад секунду: тримай приціл до розриву.","keys":["ПКМ","ЛКМ"],"caption":"влучання в корпус"}],
 [
  {"id":"swap","title":"Візьми РПГ-22","text":"5 — наступний гранатомет: РПГ-7 — на кріплення, РПГ-22 — з кріплення в руки. Він у похідному положенні: прицілів не видно, спуск не зведено.","keys":["5"]},
  {"id":"arm","title":"Переведи в бойове положення","text":"R — зняти кришки й висунути трубу до фіксації: приціли піднімаються, спуск зводиться (6 с). Назад РПГ-22 не складається — лише на кріплення.","keys":["R"]},
  {"id":"hit150","title":"Рамка «15» — БМП на 150 м","text":"Задній приціл — діоптр, передній — рамка з планками «5», «15», «25»: 50, 150, 250 м. БМП праворуч, 150 м (маркер): планку «15» — на середину борту, ЛКМ.","keys":["ПКМ","ЛКМ"],"caption":"влучання в корпус"}]]
const TARGET_OF := {"post":"h200","draw":"h200","load":"h200","rear":"h200","scope":"h200","hit200":"h200","reload":"h300","hit300":"h300","swap":"h150","arm":"h150","hit150":"h150"}

var hit_count := 0
var fired := 0
var resupplied := 0
var note := ""

func course_id() -> String:return "grenadier"
func course_title() -> String:return "ГРАНАТОМЕТНИК"
func course_role() -> String:return "РПГ-7 · РПГ-22 · ПОЛІГОН"
func chapters() -> Array:return CHAPTERS
func steps() -> Array:return STEPS
func loadout() -> Dictionary:return {"class":"grenadier","primary":"ak74","secondary":"pm","map":TrainingRange.ID,"bag":["rpg7","pg7vl","pg7vl","rpg22","medkit"]}
func death_text() -> String:return "Гранатометник вибув. Перед пострілом — нікого позаду й жодної стіни за соплом."

func on_begin() -> void:
 super.on_begin()
 hit_count=0;fired=0;resupplied=0;note=""

func launcher() -> LauncherRig:return player().launcher
func hulk() -> Vector3:return TrainingRange.HULKS[TARGET_OF.get(current().get("id",""),"h200")]
func aim_point(id: String) -> Vector3:return TrainingRange.HULKS[id]+Vector3(0,1.1,0)

func prepare(index: int) -> void:
 if index==0:place(TrainingRange.GRENADIER+Vector3(8,0,22),TrainingRange.GRENADIER);return
 place(TrainingRange.GRENADIER,aim_point("h200" if index==1 else "h150"))
 if index==1:
  # On its own the chapter starts with a loaded RPG-7 on the shoulder.
  ready_rpg7(true)

func on_enter(id: String) -> void:
 super.on_enter(id)
 note=""

# The RPG-7 in the hands at once (F6, a chapter on its own), loaded or not.
func ready_rpg7(load: bool) -> void:
 var l:=launcher()
 if not (l.active() and l.kind=="rpg7"):
  l.cancel()
  if not l.equip(-1,"rpg7"):return
 l.mode="ready";l.timer=0
 if load and not l.loaded():load_now()

func load_now() -> void:
 var l:=launcher()
 var p:=player()
 if p.backpack.first("pg7vl")<0:p.backpack.add("pg7vl")
 var round:=p.backpack.first("pg7vl")
 if round>=0:p.backpack.remove(round)
 p.backpack.item(l.item_uid)["loaded"]=true
 l.mode="ready";l.timer=0;l.show_round()

# A burst on the hull of the step's hulk since the step began.
func hit_on(id: String) -> bool:
 return game.blasts.detonations>blasts_at and TrainingRange.on_hulk(id,game.blasts.last_detonation)

func looking_back() -> bool:
 var p:=player()
 var forward:=-p.global_basis.z;forward.y=0
 var to_target:=hulk()-p.global_position;to_target.y=0
 return forward.normalized().dot(to_target.normalized())<-0.5

func facing() -> bool:
 var p:=player()
 var forward:=-p.global_basis.z;forward.y=0
 var to_target:=hulk()-p.global_position;to_target.y=0
 return forward.normalized().dot(to_target.normalized())>0.9

func tick(_delta: float) -> void:
 var s:=current()
 if s.is_empty():return
 var p:=player()
 var l:=launcher()
 # Missed with the last one: the range hands out another round.
 var missed: bool=s.id in ["hit200","hit300","hit150"] and game.blasts.detonations>blasts_at and not hit_on(TARGET_OF[s.id])
 if missed and l.active() and l.kind=="rpg7" and not l.loaded() and l.mode=="ready" and p.backpack.count("pg7vl")==0:
  p.backpack.add("pg7vl");resupplied+=1;note="Новий ПГ-7ВЛ у наплічнику · R — зарядити"
 if missed and s.id=="hit150" and p.backpack.count("rpg22")==0 and not (l.active() and l.kind=="rpg22"):
  p.backpack.add("rpg22");resupplied+=1;note="Новий РПГ-22 на кріпленні · 5 — зняти, R — у бойове"
 if s.id in ["hit200","hit300","hit150"] and game.blasts.detonations>int(seen.get("counted",blasts_at)):
  seen["counted"]=game.blasts.detonations
  fired+=1

func check(id: String) -> bool:
 var p:=player()
 var l:=launcher()
 match id:
  "post":return flat_distance(p.global_position,TrainingRange.GRENADIER)<4.0
  "draw":return l.active() and l.kind=="rpg7" and l.mode=="ready"
  "load":return l.active() and l.kind=="rpg7" and l.mode=="ready" and l.loaded()
  "rear":return saw("back",looking_back()) and facing()
  "scope":return l.through_scope()
  "hit200":
   if hit_on("h200"):hit_count+=1;return true
  "reload":return l.active() and l.kind=="rpg7" and l.mode=="ready" and l.loaded()
  "hit300":
   if hit_on("h300"):hit_count+=1;return true
  "swap":return l.active() and l.kind=="rpg22" and l.mode=="ready"
  "arm":return l.active() and l.kind=="rpg22" and l.mode=="ready" and l.armed()
  "hit150":
   if hit_on("h150"):hit_count+=1;return true
 return false

func auto(id: String) -> void:
 var p:=player()
 var l:=launcher()
 match id:
  "post":place(TrainingRange.GRENADIER,aim_point("h200"))
  "draw":ready_rpg7(false)
  "load","reload":ready_rpg7(true)
  "rear":face(hulk())
  "hit200","hit300","hit150":
   var target:=TARGET_OF[id] as String
   game.blasts.detonate(TrainingRange.HULKS[target]+Vector3(0,1.0,TrainingRange.HULL.z*0.5),"heat")
   if l.active() and l.kind=="rpg7":p.backpack.item(l.item_uid)["loaded"]=false;l.show_round()
   elif l.active() and l.kind=="rpg22":
    p.backpack.remove(l.item_uid);l.cancel()
  "swap":
   l.cancel()
   l.equip(-1,"rpg22");l.mode="ready";l.timer=0
  "arm":
   if not (l.active() and l.kind=="rpg22"):l.cancel();l.equip(-1,"rpg22")
   if l.active() and l.kind=="rpg22":
    p.backpack.item(l.item_uid)["extended"]=true
    l.use_model("rpg22",true);l.mode="ready";l.timer=0

func readout_text(id: String) -> String:
 var p:=player()
 var l:=launcher()
 var extra:=("\n"+note) if note!="" else ""
 match id:
  "post":return "До рубежу %d м" % roundi(flat_distance(p.global_position,TrainingRange.GRENADIER))
  "draw","load","reload":
   if l.mode=="draw":return "Знімання з кріплення…"
   if l.mode=="load":return "Заряджання %.1f с" % maxf(0.0,LauncherRig.LOAD_TIME-l.timer)
   return "ПГ-7ВЛ у наплічнику: %d · %s" % [p.backpack.count("pg7vl"),"заряджено" if l.active() and l.kind=="rpg7" and l.loaded() else "не заряджено"]+extra
  "rear":return "Позаду: %s" % ("чисто — тепер до цілі" if seen.get("back",false) else "не перевірено")
  "hit200","hit300","hit150":
   var target:=TARGET_OF[id] as String
   var d:=roundi(flat_distance(p.global_position,TrainingRange.HULKS[target]))
   if game.blasts.detonations>blasts_at and not hit_on(target):
    var miss:=flat_distance(game.blasts.last_detonation,TrainingRange.HULKS[target])
    var where:="недоліт" if flat_distance(game.blasts.last_detonation,p.global_position)<d else "переліт"
    return "Розрив за %d м від БМП — %s%s" % [roundi(miss),where,extra]
   return "Дальність %d м%s" % [d,extra]
  "swap":return "У руках: %s" % (LauncherRig.TITLE[l.kind] if l.active() else "—")
  "arm":
   if l.mode=="arm":return "Переведення %.1f с" % maxf(0.0,LauncherRig.ARM_TIME-l.timer)
   return "РПГ-22: %s" % ("бойове положення" if l.armed() else "похідне положення")
 return ""

func marker() -> Dictionary:
 var s:=current()
 if s.is_empty():return {}
 match s.id:
  "post":return {"point":TrainingRange.GRENADIER+Vector3(0,1.0,0),"caption":"ГРАНАТОМЕТ"}
  "rear","scope","hit200","reload","hit300","swap","arm","hit150":
   return {"point":hulk()+Vector3(0,3.0,0),"caption":"БМП"}
 return {}

func markers_hidden() -> bool:
 return super.markers_hidden() or (is_instance_valid(player()) and launcher().through_scope())

func result_lines() -> Array[String]:
 var lines: Array[String]=[]
 lines.append("ВЛУЧАНЬ У БМП  %d · ПОСТРІЛІВ  %d" % [hit_count,maxi(fired,hit_count)])
 if resupplied>0:lines.append("ВИДАНО ДОДАТКОВО  %d" % resupplied)
 return lines
