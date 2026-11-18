class_name Campaign
extends RefCounted

const SAVE_PATH := "user://campaign.cfg"
const BRANCHES := ["forest","settlements"]
const BRANCH_NAMES := {"forest":"ЛІСОВИЙ РУБІЖ","settlements":"НАСЕЛЕНІ ПУНКТИ"}
const IDS := ["forest_01","forest_02","forest_03","forest_04","forest_05","village_01","village_02","village_03","district_01","district_02"]
var completed: Array[String]=[]

static func mission(id: String) -> Dictionary:
 var index := IDS.find(id)
 if index<0:return {}
 var definitions := [
  {"title":"Межа поля","kind":"forest","biome":"meadow","seed":7101,"relief":7.0,"heading":-0.15,"brief":"Перетни хвилясте поле й витісни оборону з окопів перед двома лісосмугами.","belts":[[Vector2(-170,-45),Vector2(140,-90),14.0],[Vector2(-135,80),Vector2(-85,-165),10.0]],"trenches":[[Vector2(-95,-20),Vector2(-25,-35),Vector2(25,-20),Vector2(95,-45)],[Vector2(-25,-35),Vector2(-35,-85)]]},
  {"title":"Сосновий гребінь","kind":"forest","biome":"pine","seed":7207,"relief":17.0,"heading":0.25,"brief":"Підійди через нижню галявину до траншей на схилі соснового гребеня.","belts":[[Vector2(-175,-110),Vector2(165,-120),28.0],[Vector2(60,100),Vector2(130,-165),22.0]],"trenches":[[Vector2(-110,-45),Vector2(-50,-55),Vector2(-20,-35),Vector2(45,-65)],[Vector2(45,-65),Vector2(85,-100),Vector2(115,-80)]]},
  {"title":"Сухий яр","kind":"forest","biome":"dry","seed":7309,"relief":13.0,"heading":-0.35,"brief":"Використай сухий яр для підходу до відкритого оборонного рубежу.","belts":[[Vector2(-140,90),Vector2(-90,-160),12.0],[Vector2(-80,-145),Vector2(175,-80),16.0]],"trenches":[[Vector2(-65,5),Vector2(-20,-15),Vector2(40,-5),Vector2(90,-25)],[Vector2(40,-5),Vector2(55,-65),Vector2(105,-80)]]},
  {"title":"Березова низина","kind":"forest","biome":"wet","seed":7417,"relief":8.0,"heading":0.4,"brief":"Зайди на рубіж через мокру луку між березовими смугами; оборона займає сухі підвищення.","belts":[[Vector2(-170,-100),Vector2(130,-130),18.0],[Vector2(-150,85),Vector2(-120,-125),15.0],[Vector2(145,120),Vector2(125,-90),11.0]],"trenches":[[Vector2(-70,-30),Vector2(-15,-45),Vector2(20,-25),Vector2(80,-55)],[Vector2(80,-55),Vector2(65,-105)]]},
  {"title":"Перехрестя смуг","kind":"forest","biome":"autumn","seed":7523,"relief":12.0,"heading":-0.55,"brief":"Штурмуй дві лінії окопів у відкритих проміжках між перехресними лісосмугами.","belts":[[Vector2(-180,-95),Vector2(175,-95),16.0],[Vector2(-85,120),Vector2(50,-180),13.0],[Vector2(145,135),Vector2(155,-170),15.0]],"trenches":[[Vector2(-130,5),Vector2(-70,-15),Vector2(-20,0)],[Vector2(15,-35),Vector2(70,-55),Vector2(115,-35)],[Vector2(-70,-15),Vector2(-55,-65),Vector2(5,-80),Vector2(70,-55)]]},
  {"title":"Край садів","kind":"village","biome":"orchard","seed":8101,"relief":9.0,"heading":0.1,"brief":"Зайди з боку садів. Оборона тримає двори, вікна й розриви між хатами.","centers":[Vector2(-55,5),Vector2(45,-45),Vector2(5,-110)],"belts":[[Vector2(-160,110),Vector2(-155,-140),12.0]],"trenches":[]},
  {"title":"Село над балкою","kind":"village","biome":"dry","seed":8219,"relief":18.0,"heading":-0.3,"brief":"Подолай балку й штурмуй розкидані садиби на двох схилах.","centers":[Vector2(-85,20),Vector2(65,-25),Vector2(-15,-105)],"belts":[[Vector2(-160,-150),Vector2(135,-165),12.0]],"trenches":[]},
  {"title":"Млинівка","kind":"village","biome":"wet","seed":8329,"relief":10.0,"heading":0.5,"brief":"Через низину вийди до вигнутої сільської вулиці, господарських дворів і майстерень.","centers":[Vector2(-75,-40),Vector2(10,15),Vector2(85,-85)],"belts":[[Vector2(-175,120),Vector2(-160,-160),18.0]],"trenches":[]},
  {"title":"Старий квартал","kind":"district","biome":"urban","seed":9103,"relief":8.0,"heading":-0.15,"brief":"Зайди через двори старої забудови. Оборонці використовують різновисотні будинки й проходи.","centers":[Vector2(-65,25),Vector2(60,-30),Vector2(-40,-100)],"belts":[],"trenches":[]},
  {"title":"Верхній район","kind":"district","biome":"urban","seed":9221,"relief":16.0,"heading":0.35,"brief":"Штурмуй район на схилі: панельні будинки, гаражі й відкрита площа між оборонними вузлами.","centers":[Vector2(-80,-20),Vector2(65,10),Vector2(0,-110)],"belts":[],"trenches":[]}
 ]
 var result: Dictionary=definitions[index].duplicate(true)
 result.merge({"id":id,"branch":BRANCHES[0 if index<5 else 1],"stage":index%5+1,"size":400,"spawn":Vector2(0,175),"defender_count":12+(index%5)*2,"buildings":[]})
 if result.kind!="forest":
  var rng := RandomNumberGenerator.new()
  rng.seed=result.seed
  var placements: Array=[]
  for cluster in result.centers:
   for i in range(6 if result.kind=="village" else 4):
    var angle := i*TAU/(6 if result.kind=="village" else 4)+rng.randf_range(-0.3,0.3)
    var point: Vector2=cluster+Vector2(cos(angle),sin(angle))*rng.randf_range(22,43)
    var variant := (i+placements.size()+index)%5
    var size := Vector2(9+rng.randf()*5,8+rng.randf()*5) if result.kind=="village" else Vector2(14+rng.randf()*9,13+rng.randf()*8)
    # Keep irregular spacing without intersecting house foundations/pad blends.
    var valid := false
    for attempt in range(36):
     valid=true
     for existing in placements:
      var separation := (size.length()+Vector2(existing.size).length())*0.75+10
      if point.distance_to(existing.point)<separation:
       valid=false
       break
     if valid and absf(point.x)<170 and absf(point.y)<150:break
     point=cluster+Vector2.from_angle(angle+rng.randf_range(-0.4,0.4))*rng.randf_range(25,65)
    if not valid or absf(point.x)>=170 or absf(point.y)>=150:continue
    placements.append({"point":point,"size":size,"yaw":rng.randf_range(-0.55,0.55),"variant":variant,"floors":1+(variant%2) if result.kind=="village" else 2+variant%4})
  result.buildings=placements
 return result

func unlocked(id: String) -> bool:
 var index := IDS.find(id)
 if index<0:return false
 return index%5==0 or IDS[index-1] in completed

func complete(id: String) -> bool:
 if not unlocked(id):return false
 if id not in completed:completed.append(id)
 return true

func save_progress(path: String=SAVE_PATH) -> Error:
 var config := ConfigFile.new()
 config.set_value("campaign","schema",1)
 config.set_value("campaign","completed",completed)
 return config.save(path)

func load_progress(path: String=SAVE_PATH) -> void:
 completed.clear()
 var config := ConfigFile.new()
 if config.load(path)!=OK:return
 var saved: Variant=config.get_value("campaign","completed",[])
 if not saved is Array:return
 # Rebuild in branch order so corrupt saves cannot unlock disconnected stages.
 for id in IDS:
  if id in saved and unlocked(id):completed.append(id)
