class_name PlayerClass
extends RefCounted

# Each class has its own weapons, ammunition and equipment; only the mortarman
# leads a crew (one assistant) and gives orders.
const IDS := ["rifleman","machinegunner","grenadier","sniper","uav","mortarman","grad","bmp","tos"]
const TITLES := {"rifleman":"СТРІЛЕЦЬ","machinegunner":"КУЛЕМЕТНИК","grenadier":"ГРАНАТОМЕТНИК","sniper":"СНАЙПЕР","uav":"ОПЕРАТОР БПЛА","mortarman":"МІНОМЕТНИК","grad":"КОМАНДИР БМ-21","bmp":"МЕХАНІК-ВОДІЙ БМП","tos":"КОМАНДИР ТОС-1А"}
const PRIMARY := {"rifleman":["ak74","m16"],"machinegunner":["pkm"],"grenadier":["ak74"],"sniper":["svd"],"uav":["ak74","m16"],"mortarman":["ak74"],"grad":["ak74"],"bmp":["ak74"],"tos":["ak74"]}
const SECONDARY := {"rifleman":["pm","m9"],"machinegunner":["pm","m9"],"grenadier":["pm","m9"],"sniper":["pm","m9"],"uav":["pm","m9"],"mortarman":["pm","m9"],"grad":["pm","m9"],"bmp":["pm","m9"],"tos":["pm","m9"]}
# Infantry classes of the great assault: on foot with the squads.
const INFANTRY := ["rifleman","machinegunner","grenadier","sniper","uav"]
const ITEMS := {
# The rangefinder is not a pack item: every class carries one in a pouch on
# the plate carrier (K), so older presets lose the pack copy.
 "rifleman":["rpo_a","rpg22","ammo_ak74","ammo_m16","ammo_pm","ammo_m9","medkit","recon_drone"],
 "machinegunner":["ammo_pkm","ammo_pm","ammo_m9","medkit","recon_drone"],
 "grenadier":["rpg7","pg7vl","og7v","tbg7v","rpg22","ammo_ak74","ammo_pm","ammo_m9","medkit","recon_drone"],
 "uav":["fpv_heat","fpv_frag","recon_drone","ammo_ak74","ammo_m16","ammo_pm","ammo_m9","medkit"],
 "sniper":["ammo_svd","ammo_pm","ammo_m9","medkit","recon_drone"],
 "mortarman":["mortar_mine","ammo_ak74","ammo_pm","ammo_m9","medkit","recon_drone"],
 # Every class may carry a recon drone in the pack; the BM-21's commander
 # also has the observation post's drone at the terminal in his cab.
 "grad":["ammo_ak74","ammo_pm","ammo_m9","medkit","recon_drone"],
 "bmp":["ammo_ak74","ammo_pm","ammo_m9","medkit","recon_drone"],
 "tos":["ammo_ak74","ammo_pm","ammo_m9","medkit","recon_drone"]
}
const BRIEF := {
 "rifleman":"АК-74М або M16A4, пістолет, РПО-А «Шмель» або РПГ-22. Набої 5.45 / 5.56 / 9 мм. Діє самостійно: без власної групи й команд.",
 "machinegunner":"ПКМ (7,5 кг, коробки по 100 набоїв, 650 постр./хв), пістолет. Вогонь на придушення і по групах. X — сошки (лежачи чи на опорі віддача втричі менша), PgUp / PgDn — приціл 1–15.",
 "grenadier":"РПГ-7В1 з ПГО-7В3 і пострілами ПГ-7ВЛ (кумулятивні), ОГ-7В (осколкові) і ТБГ-7В (термобаричні), РПГ-22, АК-74М, пістолет. Б'є по техніці, по вогневих точках у будівлях. 4 — гранатомет (утримай — вибір), 5 — інший, R — заряджання РПГ-7 (утримай — вибір пострілу) або переведення РПГ-22 в бойове положення (назад не складається).",
 "uav":"FPV-дрони 7\" (кумулятивні й осколкові), розвіддрон, АК-74М, пістолет. Шукає противника з повітря і вражає техніку й піхоту. Y — FPV, J — розвіддрон.",
 "sniper":"СВД з ПСО-1, пістолет. Набої 7.62 × 54R / 9 мм. Діє самостійно: без власної групи й команд.",
 "mortarman":"Міномет 2Б14 «Піднос» (ствол і двонога — 30,1 кг), АК-74М, пістолет, 82-мм міни. Помічник несе опорну плиту й ящик мін. G — команди, N — міномет.",
 "bmp":"БМП-2 і своє відділення: навідник-оператор у башті, сім бійців десанту. Ти механік-водій і командир: ведеш машину (маса, стартер, фрикціон, п'ять передач, штурвал) і командуєш — десант, по місцях, за БМП, штурм розсипом. АК-74М, пістолет.",
 "tos":"Трофейна ТОС-1А «Солнцепёк»: бойова машина БМ-1 на шасі Т-72А, 24 некеровані ракети МО.1.01.04М з термобаричною бойовою частиною, 600–6000 м. Лише «Великий штурм»: ти механік-водій, навідник-оператор і командир — марш на ВП за 4 км від бою, домкрати, СУО, приціл-далекомір 1Д14, залп і відхід до відповіді противника. АК-74М, пістолет.",
 "grad":"РСЗВ БМ-21 «Град» на шасі Урал-375Д, 40 ракет 9М22У в пакеті. Лише «Великий штурм»: за 5 км від бою — розвідка дроном СП, залп, зміна позиції, наказ на штурм. АК-74М, пістолет."
}
# Pack loads of the 2B14: barrel 16.2 kg, bipod 13.9 kg, baseplate 17 kg.
const BARREL_AND_BIPOD := 30.1
const BASEPLATE := 17.0

static func valid(id: String) -> String:return id if id in IDS else "rifleman"

# Older settings and presets carry no class: the rifle decides it.
static func infer(primary: String) -> String:return "sniper" if primary=="svd" else ("machinegunner" if primary=="pkm" else "rifleman")

static func primary_for(id: String, weapon: String) -> String:
 var allowed: Array=PRIMARY[valid(id)]
 return weapon if weapon in allowed else allowed[0]

static func secondary_for(id: String, weapon: String) -> String:
 var allowed: Array=SECONDARY[valid(id)]
 return weapon if weapon in allowed else allowed[0]

static func allows(id: String, kind: String) -> bool:return kind in ITEMS[valid(id)]

# Personal allies: the mortarman's assistant; the BMP driver's gunner and
# seven men of the troop compartment.
static func allies(id: String) -> int:
 match id:
  "mortarman":return 1
  "bmp":return 1+BmpVehicle.SEATS
 return 0

# Removes what this class cannot carry; returns the removed item names.
static func clean_bag(id: String, bag: BackpackState) -> Array[String]:
 var removed: Array[String]=[]
 for entry in bag.items.duplicate():
  if not allows(id,entry.kind):
   removed.append(Equipment.ITEMS[entry.kind].name)
   bag.remove(int(entry.uid))
 return removed
