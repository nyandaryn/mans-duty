extends RangeCourse

# «Навчання» for the machine gunner on the training range: the PKM in its
# nest lying on the bipod, the frame sight set to the range, short bursts at
# chest targets at 100 m, the fire moved along a group of figures at 300 m, a
# long burst at 500 m; then the box changed (R), the bolt cocked by hand (V)
# and the belt changed whole from a can in the pack.
const CHAPTERS := [
 {"title":"ПОЗИЦІЯ І СОШКИ","minutes":3,"about":"Кулеметне гніздо праворуч від рубежу, положення лежачи, сошки на землю, прицілювання з ПКМ."},
 {"title":"ПРИЦІЛ І ЧЕРГИ","minutes":6,"about":"Рамковий приціл 1–15 на дальність, короткі черги по грудних мішенях на 100 м, перенесення вогню по групі на 300 м, довга черга на 500 м."},
 {"title":"КОРОБКА І СТРІЧКА","minutes":4,"about":"Заміна коробки зі стрічкою, зведення затвора вручну, заміна стрічки з цинку в наплічнику й контрольна черга."}]
const STEPS := [
 [
  {"id":"nest","title":"Займи кулеметне гніздо","text":"Гніздо в мішках праворуч від рубежу (маркер «КУЛЕМЕТ»). З ПКМ і коробкою — 9 кг у руках: бігом важче. W A S D — рух, SHIFT — біг.","keys":["W","A","S","D","SHIFT"]},
  {"id":"prone","title":"Ляж","text":"З ПКМ стріляють лежачи з сошок: кулемет стійкий, черга купна, силует найменший.","keys":["Z"]},
  {"id":"bipod","title":"Розклади сошки","text":"X — сошки на землю. На сошках (лежачи чи на опорі — бруствері, підвіконні) віддача втричі менша. Рушиш з місця або підведешся — сошки складуться.","keys":["X"]},
  {"id":"aim","title":"Прицілься","text":"ПКМ — приклад до плеча: мушка в прорізі рамкового прицілу на кришці ствольної коробки.","keys":["ПКМ"],"caption":"утримуй"}],
 [
  {"id":"sight1","title":"Приціл «1» — 100 м","text":"Повзунок рамкового прицілу — сотні метрів, 1–15. PgUp / PgDn — на поділку вперед / назад. Грудні мішені стоять на 100 м: встанови «1».","keys":["PgUp","PgDn"]},
  {"id":"burst100","title":"Короткі черги на 100 м","text":"Дві грудні мішені на 100 м (маркер). Коротка черга — 2–5 пострілів: натисни ЛКМ і майже одразу відпусти. Між чергами — поправ наведення.","keys":["ПКМ","ЛКМ"],"caption":"2 влучання · 2 короткі черги"},
  {"id":"sight3","title":"Приціл «3» — 300 м","text":"Три ростові фігури на 300 м — група. Встанови на прицілі «3».","keys":["PgUp","PgDn"]},
  {"id":"group300","title":"Перенеси вогонь по групі","text":"Коротка черга по одній фігурі, потім — по сусідній: кулеметник веде вогонь по групі, переносячи його з цілі на ціль, а не б'є довго в одну.","keys":["ПКМ","ЛКМ"],"caption":"влучання у 2 різні фігури"},
  {"id":"sight5","title":"Приціл «5» — 500 м","text":"Найдальша група — близько 500 м, біля валу. Встанови «5».","keys":["PgUp","PgDn"]},
  {"id":"long500","title":"Довга черга на 500 м","text":"Далеко розсіювання більше: довга черга 6–10 пострілів накриває групу. Утримуй ЛКМ трохи довше і веди кулемет по фігурах.","keys":["ПКМ","ЛКМ"],"caption":"влучання · довга черга"}],
 [
  {"id":"box","title":"Заміни коробку","text":"Стрічку відстріляно: рама із затвором пішла вперед, кулемет замовк. Утримуй R і натисни 1 — коробка з першого підсумка: кришку ствольної коробки вгору, порожню коробку з кронштейна в підсумок, нову — на кронштейн, стрічку на лоток, кришку закрити.","keys":["R","+","1"]},
  {"id":"cock","title":"Зведи затвор","text":"ПКМ стріляє з відкритого затвора: V — рукоятку перезаряджання назад до упору, затвор стає на бойовий звід, рукоятку вручну вперед. Тепер кулемет готовий до стрільби.","keys":["V"]},
  {"id":"belt","title":"Заміни стрічку з цинку","text":"Порожня коробка — в підсумку. TAB — інвентар: обери в наплічнику цинк зі стрічкою, потім цю коробку й «ЗАМІНИТИ СТРІЧКУ». Стрічку не перекладають по набою — її міняють цілком.","keys":["TAB"]},
  {"id":"control","title":"Контрольна черга","text":"Закрий інвентар (TAB). Приціл «1», коротка черга по грудній мішені на 100 м.","keys":["TAB","ПКМ","ЛКМ"],"caption":"1 влучання"}]]
const GROUPS := {"100":["g100a","g100b"],"300":["g300a","g300b","g300c"],"500":["g500a","g500b","g500c"]}
const SHORT := Vector2i(2,5)
const LONG := Vector2i(6,15)
# A pause longer than this between shots ends a burst.
const BURST_GAP := 0.3

# Shots of the burst going on, the bursts finished in this step, all of them.
var burst := 0
var gap := 9.0
var last_shots := 0
var bursts: Array[int]=[]
var all_bursts: Array[int]=[]
var want_bipod := false

func course_id() -> String:return "machinegunner"
func course_title() -> String:return "КУЛЕМЕТНИК"
func course_role() -> String:return "ПКМ · ЧЕРГИ · ПОЛІГОН"
func chapters() -> Array:return CHAPTERS
func steps() -> Array:return STEPS
func loadout() -> Dictionary:return {"class":"machinegunner","primary":"pkm","secondary":"pm","map":TrainingRange.ID,"bag":["ammo_pkm","medkit"]}
func target_ids() -> Array:return GROUPS["100"]+GROUPS["300"]+GROUPS["500"]
func death_text() -> String:return "Кулеметник вибув. Почни розділ знову."

func on_begin() -> void:
 super.on_begin()
 burst=0;gap=9.0;bursts.clear();all_bursts.clear();want_bipod=false
 last_shots=0

func prepare(index: int) -> void:
 last_shots=player().shots
 if index==0:place(TrainingRange.MG+Vector3(-6,0,24),TrainingRange.MG);return
 place(TrainingRange.MG,TrainingRange.TARGETS.g300b.point)
 stance(true);want_bipod=true
 if index==2:weapon().scope_zero=100

func on_enter(id: String) -> void:
 super.on_enter(id)
 bursts.clear()
 var w:=weapon()
 match id:
  "box":
   # The belt shot out: the carrier has run home on an empty tray.
   if w.phase=="" and w.pending_slot<0:
    w.magazine.rounds=0;w.chambered=false;w.cocked=false
   seen["serial"]=w.magazine.get("serial",-1)
  "cock":
   # A gun that cocks itself after the box (as before the hand drill) has
   # nothing left to show here.
   if ready():seen["rack"]=true
  "belt":
   var low:=0
   for i in range(w.pouches.size()):
    if int(w.pouches[i].rounds)<int(w.pouches[low].rounds):low=i
   seen["box"]=low

# Ready to fire: a box on, the carrier back on the sear, a round on the tray.
func ready() -> bool:
 var w:=weapon()
 return w.phase=="" and w.pending_slot<0 and w.chambered and w.cocked

func tick(delta: float) -> void:
 var p:=player()
 if want_bipod and p.prone and not p.bipod and weapon().id=="pkm":p.bipod=true;want_bipod=false
 if p.shots>last_shots:
  burst+=p.shots-last_shots;last_shots=p.shots;gap=0.0
 else:
  gap+=delta
  if gap>BURST_GAP and burst>0:
   bursts.append(burst);all_bursts.append(burst);burst=0

func count(kind: Vector2i) -> int:
 var n:=0
 for b in bursts:
  if b>=kind.x and b<=kind.y:n+=1
 return n

func group_hits(group: String) -> int:
 var n:=0
 for id in GROUPS[group]:n+=hits(id)
 return n

func struck(group: String) -> int:
 var n:=0
 for id in GROUPS[group]:n+=int(hits(id)>0)
 return n

func at_nest() -> bool:return flat_distance(player().global_position,TrainingRange.MG)<2.0

func check(id: String) -> bool:
 var p:=player()
 match id:
  "nest":return at_nest()
  "prone":return p.prone
  "bipod":return p.bipod
  "aim":return p.ads_weight>0.8 and p.aim
  "sight1":return weapon().scope_zero==100
  "burst100":return group_hits("100")>=2 and count(SHORT)>=2
  "sight3":return weapon().scope_zero==300
  "group300":return struck("300")>=2
  "sight5":return weapon().scope_zero==500
  "long500":return group_hits("500")>=1 and count(LONG)>=1
  "box":return weapon().phase in ["","rack"] and weapon().pending_slot<0 and weapon().magazine.get("serial",-1)!=seen.get("serial",-1) and weapon().rounds()>0
  "cock":return saw("rack",weapon().phase=="rack") and ready()
  "belt":
   var w:=weapon()
   var i: int=seen.get("box",0)
   return i<w.pouches.size() and int(w.pouches[i].rounds)>=int(w.data.capacity) and not game.inventory.transfer.active
  "control":return group_hits("100")>=1
 return false

func auto(id: String) -> void:
 var p:=player()
 var w:=weapon()
 match id:
  "nest":place(TrainingRange.MG,TrainingRange.TARGETS.g300b.point)
  "prone":stance(true)
  "bipod":stance(true);want_bipod=true
  "sight1":w.scope_zero=100
  "sight3":w.scope_zero=300
  "sight5":w.scope_zero=500
  "burst100":score("g100a",1);score("g100b",1);all_bursts.append_array([4,4])
  "group300":score("g300a",1);score("g300b",1);all_bursts.append_array([4,4])
  "long500":score("g500b",1);all_bursts.append(8)
  "box":
   # The fullest box from the pouch on, the nearly empty one into it; the
   # bolt went home at the end of the belt.
   if w.phase=="" and w.pending_slot<0 and not w.pouches.is_empty():
    var full:=0
    for i in range(w.pouches.size()):
     if int(w.pouches[i].rounds)>int(w.pouches[full].rounds):full=i
    var held:=w.magazine;w.magazine=w.pouches[full];w.pouches[full]=held
    w.chambered=false;w.cocked=false
  "cock":
   if w.phase=="":w.cocked=true;w.chamber()
  "belt":
   if game.inventory.transfer.active:game.inventory.stop_transfer()
   if game.inventory_open:game.inventory.toggle()
   var i: int=seen.get("box",0)
   if i<w.pouches.size():
    var old:=int(w.pouches[i].rounds)
    w.pouches[i].rounds=int(w.data.capacity)
    # The belt from the can in the box, the rest of the old one in the can.
    var can:=p.backpack.first("ammo_pkm")
    if can>=0:
     if old>0:p.backpack.item(can).rounds=old
     else:p.backpack.remove(can)
  "control":
   if game.inventory_open:game.inventory.toggle()
   score("g100a",1)

func readout_text(id: String) -> String:
 var p:=player()
 var w:=weapon()
 var last:=("остання черга %d" % bursts[-1]) if not bursts.is_empty() else ("черга %d…" % burst if burst>0 else "")
 match id:
  "nest":return "До гнізда %d м" % roundi(flat_distance(p.global_position,TrainingRange.MG))
  "bipod":return "Сошки: %s" % ("на опорі" if p.bipod else "складені")
  "sight1","sight3","sight5":return "Приціл: %d" % (w.scope_zero/100)
  "burst100":return "Влучань %d / 2 · коротких черг %d / 2%s" % [mini(group_hits("100"),2),mini(count(SHORT),2),(" · "+last) if last!="" else ""]+long_hint()
  "group300":return "Уражено фігур %d / 2 · приціл %d%s" % [mini(struck("300"),2),w.scope_zero/100,(" · "+last) if last!="" else ""]
  "long500":return "Влучань %d / 1 · довгих черг %d / 1 · приціл %d%s" % [mini(group_hits("500"),1),mini(count(LONG),1),w.scope_zero/100,(" · "+last) if last!="" else ""]
  "box","cock":return "У коробці %d · %s" % [w.rounds(),"готовий до стрільби" if ready() else "затвор не зведено"]
  "belt":
   var i: int=seen.get("box",0)
   var left:=int(w.pouches[i].rounds) if i<w.pouches.size() else 0
   return "Коробка в підсумку: %d / %d · цинків у наплічнику: %d" % [left,int(w.data.capacity),p.backpack.count("ammo_pkm")]
  "control":return "Влучань %d / 1 · приціл %d" % [mini(group_hits("100"),1),w.scope_zero/100]
 return ""

# A burst of more than five on the near targets: let go sooner.
func long_hint() -> String:
 if not bursts.is_empty() and bursts[-1]>SHORT.y:return "\nДовга черга — відпускай ЛКМ раніше"
 return ""

func marker() -> Dictionary:
 var s:=current()
 if s.is_empty():return {}
 match s.id:
  "nest":return {} if at_nest() else {"point":TrainingRange.MG+Vector3(0,1.0,0),"caption":"КУЛЕМЕТ"}
  "sight1","burst100","control":return target_marker("g100a","100 м")
  "sight3","group300":return target_marker("g300b","300 м")
  "sight5","long500":return target_marker("g500b","500 м")
 return {}

func result_lines() -> Array[String]:
 var lines: Array[String]=[]
 var near:=0;var mid:=0;var far:=0
 for id in GROUPS["100"]:near+=targets[id].hits if targets.has(id) else 0
 for id in GROUPS["300"]:mid+=targets[id].hits if targets.has(id) else 0
 for id in GROUPS["500"]:far+=targets[id].hits if targets.has(id) else 0
 lines.append("ВЛУЧАНЬ  100 м  %d · 300 м  %d · 500 м  %d" % [near,mid,far])
 if not all_bursts.is_empty():
  var total:=0
  for b in all_bursts:total+=b
  lines.append("ЧЕРГ  %d · У СЕРЕДНЬОМУ  %.1f ПОСТРІЛУ" % [all_bursts.size(),float(total)/all_bursts.size()])
 return lines
