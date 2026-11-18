class_name RiflemanTraining
extends RangeCourse

# «Навчання» for the rifleman on the training range: moving and positions,
# shooting the AK-74M at 25 to 100 m, magazines and stoppages, the kit
# (rangefinder, map, inventory, dressing a wound) and the RPO-A at a bunker.
const CHAPTERS := [
 {"title":"РУХ І ПОЛОЖЕННЯ","minutes":3,"about":"Вихід на вогневий рубіж, присід, положення лежачи, нахил з-за укриття й подолання низької стінки."},
 {"title":"СТРІЛЬБА З АК-74М","minutes":4,"about":"Прицілювання, влучання в грудну мішень на 25 м, перемикач вогню, одиночні по ростовій мішені на 100 м."},
 {"title":"МАГАЗИНИ ТА ЗАТРИМКИ","minutes":4,"about":"Перевірка магазина, заміна магазина з підсумка, досилання затвором, перевірка патронника й контрольна серія."},
 {"title":"СПОРЯДЖЕННЯ","minutes":4,"about":"Далекомір, карта 1:10 000, польовий інвентар і перев’язка пораненої руки."},
 {"title":"РПО-А «ШМІЛЬ»","minutes":3,"about":"Реактивний піхотний вогнемет: зведення, приціл і постріл по бліндажу за 120 м. Позаду — 3 м вільного місця."}]
const STEPS := [
 [
  {"id":"line","title":"Вийди на вогневий рубіж","text":"Рубіж — гравійна смуга попереду (маркер «РУБІЖ»). W A S D — рух, SHIFT — біг.","keys":["W","A","S","D","SHIFT"]},
  {"id":"crouch","title":"Присядь","text":"Присід зменшує силует і розкид куль. CTRL — присісти, ще раз — підвестися.","keys":["CTRL"]},
  {"id":"prone","title":"Ляж","text":"Лежачи — найстійкіше положення для стрільби й найменша ціль для противника.","keys":["Z"]},
  {"id":"stand","title":"Підведись","text":"Z — підвестися з положення лежачи. Якщо боєць лишився на коліні — CTRL.","keys":["Z","CTRL"]},
  {"id":"lean","title":"Визирни з-за блока","text":"Стань за бетонний блок праворуч на рубежі (маркер). Q / E — нахил ліворуч / праворуч: з-за укриття виходять лише голова й зброя.","keys":["Q","E"],"caption":"утримуй"},
  {"id":"vault","title":"Подолай стінку","text":"Низька стінка ліворуч попереду рубежу (маркер). Підійди впритул і натисни SPACE — боєць перелізе. Обійти не рахується.","keys":["W","SPACE"]}],
 [
  {"id":"position","title":"Повернись на рубіж","text":"Стань на гравійну смугу навпроти мішеней (маркер).","keys":["W","A","S","D"]},
  {"id":"aim","title":"Прицілься","text":"ПКМ — приклад до плеча, погляд через приціл. Утримуй, доки цілишся.","keys":["ПКМ"],"caption":"утримуй"},
  {"id":"hit25","title":"Влучи в мішень на 25 м","text":"Грудна мішень №4 ліворуч попереду. Мушку — на центр мішені, плавно ЛКМ. Влучна мішень падає й за 2,5 с піднімається.","keys":["ПКМ","ЛКМ"],"caption":"3 влучання"},
  {"id":"mode","title":"Перемкни на одиночний вогонь","text":"Перекладач АК: АВТО ↔ ОДИН. На дальності одиночними точніше й ощадніше.","keys":["B"]},
  {"id":"hit100","title":"Ростова мішень на 100 м","text":"Мішень №6 у центрі смуги. Лежачи (Z) стійкіше. Мушку — на центр фігури, тисни плавно.","keys":["Z","ПКМ","ЛКМ"],"caption":"3 влучання"}],
 [
  {"id":"inspect","title":"Перевір магазин","text":"Скільки лишилося набоїв? Натисни й відпусти T: боєць відімкне магазин і оцінить його вагою й на око.","keys":["T"]},
  {"id":"swap","title":"Заміни магазин","text":"Утримуй R і натисни 1 — повний магазин з першого підсумка. Початий піде в підсумок, а не на землю.","keys":["R","+","1"]},
  {"id":"rack","title":"Досилання затвором","text":"Після порожнього магазина або при затримці — V: пересмикнути затвор. Патрон, що був у патроннику, вилетить.","keys":["V"]},
  {"id":"chamber","title":"Перевір патронник","text":"I — трохи відвести затвор і побачити, чи є патрон у патроннику.","keys":["I"]},
  {"id":"hit50","title":"Контрольна серія на 50 м","text":"Грудна мішень №4 праворуч попереду, 50 м.","keys":["ПКМ","ЛКМ"],"caption":"2 влучання"}],
 [
  {"id":"range","title":"Виміряй дальність","text":"K — далекомір з підсумка розвантаження. Наведи на ростову мішень і натисни ЛКМ. K ще раз — сховати.","keys":["K","ЛКМ"]},
  {"id":"map","title":"Відкрий карту","text":"Спершу сховай далекомір (K). M — карта 1:10 000, сітка через 100 м. Коліщатко — масштаб, ЛКМ — лінійка.","keys":["K","M"]},
  {"id":"inventory","title":"Відкрий інвентар","text":"Закрий карту (M) і натисни TAB — польовий інвентар: спорядження, магазини, наплічник.","keys":["M","TAB"]},
  {"id":"bandage","title":"Перев’яжи руку","text":"Уламок зачепив руку: тече кров, стан падає. Закрий інвентар (TAB) і натисни H — аптечка з пояса, 6 с.","keys":["TAB","H"]}],
 [
  {"id":"launcher","title":"Дістань РПО-А","text":"4 — зняти РПО-А з наплічника й звести (≈4 с). 1 — назад до автомата.","keys":["4"]},
  {"id":"fire","title":"Постріл по бліндажу","text":"Бліндаж за 120 м ліворуч попереду (маркер). ПКМ — приціл, ЛКМ — постріл. Позаду 3 м — нікого.","keys":["ПКМ","ЛКМ"]}]]

func course_id() -> String:return "rifleman"
func course_title() -> String:return "СТРІЛЕЦЬ"
func course_role() -> String:return "АК-74М · РПО-А · ПОЛІГОН"
func chapters() -> Array:return CHAPTERS
func steps() -> Array:return STEPS
func loadout() -> Dictionary:return {"class":"rifleman","primary":"ak74","secondary":"pm","map":TrainingRange.ID,"bag":["rpo_a","medkit"]}
func target_ids() -> Array:return ["t25","t50","t100"]
func death_text() -> String:return "Боєць вибув. Почни розділ знову; у бою рану перев’язують одразу (H)."

func prepare(index: int) -> void:
 if index==0:place(TrainingRange.SPAWN,TrainingRange.LINE+Vector3(0,0,-40));return
 place(TrainingRange.LINE+Vector3(0,0,0.5),TrainingRange.TARGETS.t100.point)
 if index>=2:weapon().mode_index=maxi(0,weapon().data.modes.find("ОДИН"))

func on_enter(id: String) -> void:
 super.on_enter(id)
 match id:
  "swap":seen["serial"]=weapon().magazine.get("serial",-1)
  "bandage":
   # A graze on the arm: a little bleeding, nothing broken.
   if not player().needs_bandage():
    player().apply_wound({"kind":"graze","plate_loss":0.0,"damage":2.0,"bleeding":0.25,"pain":0.25},"arm",Vector3.FORWARD,player().global_position)

func at_line() -> bool:
 var p:=player().global_position
 return absf(p.z-TrainingRange.LINE.z)<3.0 and absf(p.x)<22.0

func check(id: String) -> bool:
 var p:=player()
 match id:
  "line","position":return at_line()
  "crouch":return p.crouched
  "prone":return p.prone
  "stand":return not p.prone and not p.crouched
  "lean":return flat_distance(p.global_position,TrainingRange.BLOCK)<3.0 and absf(p.lean)>0.7
  "vault":
   saw("vaulting",p.is_vaulting())
   return seen.get("vaulting",false) and not p.is_vaulting() and p.global_position.z<TrainingRange.WALL.z-0.4 and absf(p.global_position.x-TrainingRange.WALL.x)<3.0
  "aim":return p.ads_weight>0.8 and p.aim
  "hit25":return hits("t25")>=3
  "mode":return weapon().mode()=="ОДИН"
  "hit100":return hits("t100")>=3
  "inspect":return saw("inspect",weapon().phase=="inspect_mag")
  "swap":return weapon().phase=="" and weapon().pending_slot<0 and weapon().magazine.get("serial",-1)!=seen.get("serial",-1)
  "rack":return saw("rack",weapon().phase=="rack")
  "chamber":return saw("chamber",weapon().phase=="inspect_chamber")
  "hit50":return hits("t50")>=2
  "range":return measured()
  "map":return game.topo_map.visible
  "inventory":return game.inventory_open
  "bandage":return step_clock>1.0 and not p.needs_bandage()
  "launcher":return p.launcher.mode=="ready"
  "fire":return game.blasts.detonations>blasts_at and flat_distance(game.blasts.last_detonation,TrainingRange.BUNKER)<6.0
 return false

func auto(id: String) -> void:
 var p:=player()
 match id:
  "line","position":place(TrainingRange.LINE+Vector3(0,0,0.5),TrainingRange.TARGETS.t100.point);stance(false)
  "crouch":stance(false,true)
  "prone":stance(true)
  "stand":stance(false)
  "lean":place(TrainingRange.BLOCK+Vector3(-1.3,0,1.0),TrainingRange.TARGETS.t50.point)
  "vault":place(TrainingRange.WALL+Vector3(0,0,-1.6),TrainingRange.TARGETS.t25.point)
  "hit25":score("t25",3)
  "mode":weapon().mode_index=maxi(0,weapon().data.modes.find("ОДИН"))
  "hit100":score("t100",3)
  "swap":
   var w:=weapon()
   if w.phase=="" and w.pending_slot<0 and not w.pouches.is_empty():
    var held:=w.magazine;w.magazine=w.pouches[0];w.pouches[0]=held
  "rack":weapon().chamber()
  "hit50":score("t50",2)
  "map":
   if p.field_rig.mode!="":p.field_rig.cancel()
   if not game.topo_map.visible:game.topo_map.open()
  "inventory":
   game.topo_map.close()
   if not game.inventory_open:game.inventory.toggle()
  "bandage":
   if game.inventory_open:game.inventory.toggle()
   p.bleeding=0.0;p.health=100.0;p.arm_injury=0.0;p.pain=0.0;p.injury_time=0.0
  "launcher":
   if p.launcher.mode=="":p.launcher.toggle()
  "fire":game.blasts.detonate(TrainingRange.BUNKER+Vector3(0,1.0,1.9))

func readout_text(id: String) -> String:
 var p:=player()
 match id:
  "line","position":return "До рубежу %d м" % roundi(maxf(0.0,p.global_position.z-TrainingRange.LINE.z))
  "lean":return "Нахил %+d %%" % roundi(p.lean*100)
  "hit25":return hits_text("t25",3)
  "mode":return "Перекладач: %s" % weapon().mode()
  "hit100":return hits_text("t100",3)
  "inspect","swap","rack","chamber":
   var w:=weapon()
   return "У магазині %d · патрон у патроннику: %s" % [w.rounds(),"так" if w.chambered else "ні"]
  "hit50":return hits_text("t50",2)
  "range":return p.field_rig.reading if p.field_rig.mode=="rangefinder" else ""
  "bandage":return "Кровотеча · стан %d" % ceili(p.health) if p.needs_bandage() else ""
  "fire":
   if game.blasts.detonations>blasts_at:
    return "Розрив за %d м від бліндажа%s" % [roundi(flat_distance(game.blasts.last_detonation,TrainingRange.BUNKER))," — ще раз: бери вище" if flat_distance(game.blasts.last_detonation,TrainingRange.BUNKER)>=6.0 else ""]
   return "Дальність 120 м"
 return ""

func marker() -> Dictionary:
 var s:=current()
 if s.is_empty():return {}
 match s.id:
  "line","position":return {} if at_line() else {"point":TrainingRange.LINE+Vector3(0,1.0,0),"caption":"РУБІЖ"}
  "lean":return {"point":TrainingRange.BLOCK+Vector3(0,1.7,0),"caption":"БЛОК"}
  "vault":return {"point":TrainingRange.WALL+Vector3(0,1.5,0),"caption":"СТІНКА"}
  "hit25":return target_marker("t25","25 м")
  "hit100","range":return target_marker("t100","100 м")
  "hit50":return target_marker("t50","50 м")
  "fire":return {"point":TrainingRange.BUNKER+Vector3(0,2.6,0),"caption":"БЛІНДАЖ"}
 return {}

func result_lines() -> Array[String]:
 var lines: Array[String]=[]
 var total:=0
 for t in targets.values():total+=t.hits
 lines.append("ВЛУЧАНЬ У МІШЕНІ  %d" % total)
 return lines
