class_name VestKind
extends RefCounted

# Body armour: what each vest stops, where, and what it weighs.
#
# - «Корсар М3с» (Темп-3000; the AFU standard): soft armour of DSTU 4103
#   class 1 round the torso with the sides, the collar, the shoulder
#   protectors and the groin flap (55–67 dm² in all); class 4 plates
#   250 × 300 mm (7.5 dm²) front and back, rated for 5.45 7N10 and 7.62 LPS;
#   11.6 kg with everything.
# - 6Б45 «Ратник» (the Russian standard): soft armour against 1.1 g fragments
#   at up to 550 m/s over 45–50 dm² with the collar, the shoulder protectors
#   and the groin flap; «Гранит» 5А plates (GOST class 5: LPS, 7N24, M855),
#   15–16.4 dm² front and back; 8–9 kg.
# - Plate carrier: plates only, DSTU class 6 (the B-32 of the SVD) at about
#   2.7 kg each in a 1.4 kg carrier; nothing soft round them.
#
# Plates: a plate holds a round when its penetration (DamageModel) stays
# under its rating, which drops as the plate is broken up by hits (the
# old plate of the game, class 4, is 0.90 + 0.35 × integrity = 1.25 × (0.72 +
# 0.28 × integrity)). Soft armour stops pistol rounds (class 1: the PM; the
# 9 mm only once it has lost speed) and most of the fragments of a burst:
# body armour cuts the fragment wounds of the chest and the abdomen about
# four times (0.24 of them get through), a plate nearly all.
#
# A burst is weighed by where its fragments strike a man standing in the
# open and how dangerous a wound there is (frontal area: head and neck 12 %,
# chest 16 %, abdomen 11 %, arms 22 %, legs 39 %): head 0.22, neck 0.05,
# chest 0.25, abdomen 0.18, groin 0.04, shoulders 0.03, the rest of the
# arms 0.07, legs 0.16.
const KINDS := ["korsar","ratnik","carrier"]
const HARM := {"head":0.22,"neck":0.05,"chest":0.25,"abdomen":0.18,"groin":0.04,"shoulders":0.03,"arms":0.07,"legs":0.16}
const SOFT_STOP := 0.76
const PLATE_STOP := 0.98
const DATA := {
 "korsar":{"name":"КОРСАР М3С","brief":"Стандарт ЗСУ. Плити 4 класу ДСТУ (7Н10, ЛПС) 25 × 30 см спереду й ззаду; м'яка броня 1 класу по всьому торсу з боками, комір, наплічники, захист паху.","mass":11.6,"plate":Vector2(0.25,0.30),"rating":1.25,"class":"4 кл. ДСТУ","soft":true,
  "plate_cover":{"chest":0.70},"soft_cover":{"chest":0.30,"abdomen":0.90,"neck":0.60,"shoulders":0.80,"groin":0.70}},
 "ratnik":{"name":"6Б45 «РАТНИК»","brief":"Стандарт ЗС РФ. Плити «Граніт» 5А (ЛПС, 7Н24, M855) спереду й ззаду; противоуламкова м'яка броня, високий комір, довгі наплічники, захист паху.","mass":9.0,"plate":Vector2(0.255,0.32),"rating":1.45,"class":"Бр5 / 5А","soft":true,
  "plate_cover":{"chest":0.72},"soft_cover":{"chest":0.28,"abdomen":0.90,"neck":0.70,"shoulders":0.90,"groin":0.80}},
 "carrier":{"name":"ПЛИТОНОСКА","brief":"Лише плити 6 класу ДСТУ (бронебійна Б-32) 25 × 30 см у легкому чохлі з камербандом. Від уламків — тільки там, де плита; боки, плечі й пах відкриті.","mass":6.9,"plate":Vector2(0.25,0.30),"rating":1.60,"class":"6 кл. ДСТУ","soft":false,
  "plate_cover":{"chest":0.70,"abdomen":0.20},"soft_cover":{}},
}
# What the soldier wears besides the vest: uniform 1.8 kg, boots 1.7,
# helmet 1.4, belt with empty pouches 1.0, the rangefinder 0.4.
const BODY_GEAR_MASS := 6.3

static func valid(id: String, fallback: String="korsar") -> String:return id if id in KINDS else fallback

static func mass(id: String) -> float:return float(DATA[valid(id)].mass)

static func label(id: String) -> String:return String(DATA[valid(id)].name)

# The share of a burst's harm that still reaches a man in this vest.
static func blast_factor(id: String) -> float:
 var data: Dictionary=DATA[valid(id)]
 var stopped:=0.0
 for zone in HARM:
  var covered:=float(data.plate_cover.get(zone,0.0))*PLATE_STOP+float(data.soft_cover.get(zone,0.0))*SOFT_STOP
  stopped+=float(HARM[zone])*covered
 return 1.0-stopped

# A plate holds the round (penetration in DamageModel's units).
static func plate_holds(id: String, penetration: float, integrity: float) -> bool:
 return integrity>0.0 and penetration<float(DATA[valid(id)].rating)*(0.72+0.28*integrity)

# Soft armour over the chest and the abdomen against a pistol round.
static func soft_holds(id: String, weapon: String, energy: float) -> bool:
 if not bool(DATA[valid(id)].soft):return false
 if weapon=="pm":return true
 if weapon=="m9":return energy<0.80
 return false

# Plate hitbox size (width, height, thickness) and its centre height on the
# body (the top at the notch of the breastbone, 1.42 m).
static func plate_box(id: String) -> Vector3:
 var plate: Vector2=DATA[valid(id)].plate
 return Vector3(plate.x,plate.y,0.05)

static func plate_center_y(id: String) -> float:
 return 1.42-float(DATA[valid(id)].plate.y)*0.5

# The vest of a bot: ours mostly in the Korsar, theirs in the 6B45, about one
# in four of either in a plate carrier.
static func issue(friendly: bool, index: int) -> String:
 if index%4==3:return "carrier"
 return "korsar" if friendly else "ratnik"
