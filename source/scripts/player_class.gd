class_name PlayerClass
extends RefCounted

# Each class has its own weapons, ammunition and equipment; only the mortarman
# leads a crew (one assistant) and gives orders.
const IDS := ["rifleman","sniper","mortarman","grad","bmp"]
const TITLES := {"rifleman":"СТРІЛЕЦЬ","sniper":"СНАЙПЕР","mortarman":"МІНОМЕТНИК","grad":"КОМАНДИР БМ-21","bmp":"МЕХАНІК-ВОДІЙ БМП"}
const PRIMARY := {"rifleman":["ak74","m16"],"sniper":["svd"],"mortarman":["ak74"],"grad":["ak74"],"bmp":["ak74"]}
const SECONDARY := {"rifleman":["pm","m9"],"sniper":["pm","m9"],"mortarman":["pm","m9"],"grad":["pm","m9"],"bmp":["pm","m9"]}
const ITEMS := {
# The rangefinder is not a pack item: every class carries one in a pouch on
# the plate carrier (K), so older presets lose the pack copy.
 "rifleman":["rpo_a","ammo_ak74","ammo_m16","ammo_pm","ammo_m9","medkit","recon_drone"],
 "sniper":["ammo_svd","ammo_pm","ammo_m9","medkit","recon_drone"],
 "mortarman":["mortar_mine","ammo_ak74","ammo_pm","ammo_m9","medkit","recon_drone"],
 # The drone of the BM-21 belongs to the observation post, not to the pack.
 "grad":["ammo_ak74","ammo_pm","ammo_m9","medkit"],
 "bmp":["ammo_ak74","ammo_pm","ammo_m9","medkit","recon_drone"]
}
const BRIEF := {
 "rifleman":"АК-74М або M16A4, пістолет, РПО-А «Шмель». Набої 5.45 / 5.56 / 9 мм. Діє самостійно: без власної групи й команд.",
 "sniper":"СВД з ПСО-1, пістолет. Набої 7.62 × 54R / 9 мм. Діє самостійно: без власної групи й команд.",
 "mortarman":"Міномет 2Б14 «Піднос» (ствол і двонога — 30,1 кг), АК-74М, пістолет, 82-мм міни. Помічник несе опорну плиту й ящик мін. G — команди, N — міномет.",
 "bmp":"БМП-2 і своє відділення: навідник-оператор у башті, сім бійців десанту. Ти механік-водій і командир: ведеш машину (маса, стартер, фрикціон, п'ять передач, штурвал) і командуєш — десант, по місцях, за БМП, штурм розсипом. АК-74М, пістолет.",
 "grad":"РСЗВ БМ-21 «Град» на шасі Урал-375Д, 40 ракет 9М22У в пакеті. Лише «Великий штурм»: за 5 км від бою — розвідка дроном СП, залп, зміна позиції, наказ на штурм. АК-74М, пістолет."
}
# Pack loads of the 2B14: barrel 16.2 kg, bipod 13.9 kg, baseplate 17 kg.
const BARREL_AND_BIPOD := 30.1
const BASEPLATE := 17.0

static func valid(id: String) -> String:return id if id in IDS else "rifleman"

# Older settings and presets carry no class: the rifle decides it.
static func infer(primary: String) -> String:return "sniper" if primary=="svd" else "rifleman"

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
