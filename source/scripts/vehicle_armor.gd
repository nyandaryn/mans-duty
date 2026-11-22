class_name VehicleArmor
extends RefCounted

# The armour of a vehicle and what happens behind it. Plates are boxes over
# the hull, each with its outward normal and its nominal thickness in mm of
# rolled homogeneous steel; the parts behind them (the crew's places, the
# engine, fuel, ammunition, the weapon) are boxes too. Frame of the vehicle:
# -Z forward, +X right, the ground under the middle of the hull at y=0.
# Plates and parts marked "turret" are in the turret's own frame and turn
# with it.
#
# A round that strikes a plate meets its line-of-sight thickness: the
# nominal one over the cosine of the angle between the shot and the plate's
# normal. A shaped-charge jet (or an AP slug) that gets through goes on along
# its line with what it has left, wrecking what lies on it and throwing
# spall around it in a cone. This is the method of the vulnerability
# analyses (shot line, residual penetration, components on the line) in a
# coarse form: no ricochet mechanics beyond a grazing limit, no armour
# metallurgy, no fragment-by-fragment spall. The odds of a fire or of the
# ammunition going up are game values tuned to the published experience
# that HEAT through the thin armour of a BMP sets it on fire more often than
# not (see VEHICLE-REFERENCES.md).

# Beyond about 82° off the normal a grenade skids off and its fuze or jet
# does not bite; a slug ricochets.
const GRAZE := 0.14
# Rounds that strike a vehicle: penetration in mm RHA at the muzzle (for the
# 30 mm and the bullets it falls with range, see penetration()), how far the
# jet or slug carries behind the plate per mm it has left, and its spall cone.
const ROUNDS := {
 "pg7vl":{"title":"ПГ-7ВЛ","pen":500.0,"jet":0.0065,"cone":0.42,"heat":true},
 "rpg22":{"title":"РПГ-22","pen":390.0,"jet":0.0065,"cone":0.40,"heat":true},
 "ap30":{"title":"30-мм БТ","pen":35.0,"jet":0.06,"cone":0.30,"heat":false},
 "frag":{"title":"уламки","pen":10.0,"jet":0.05,"cone":0.25,"heat":false},
 "bullet":{"title":"куля","pen":6.0,"jet":0.12,"cone":0.12,"heat":false}
}

var plates: Array[Dictionary]=[]
var parts: Array[Dictionary]=[]
# Turret ring centre in the hull frame: plates and parts marked turret are
# given relative to it and turn with the turret.
var turret_pivot := Vector3.ZERO
var turret_radius := 0.0

# A zero normal: thin sheet all round (a truck's cab, its bonnet), its
# slope does not matter.
func plate(title: String, center: Vector3, half: Vector3, normal: Vector3, mm: float, turret: bool=false, zone: String="hull") -> void:
 plates.append({"title":title,"center":center,"half":half,"normal":normal.normalized() if normal!=Vector3.ZERO else Vector3.ZERO,"mm":mm,"turret":turret,"zone":zone})

func part(title: String, kind: String, center: Vector3, half: Vector3, turret: bool=false) -> void:
 parts.append({"title":title,"kind":kind,"center":center,"half":half,"turret":turret})

# --- Layouts ---------------------------------------------------------------------
# BMP-2 (Object 675) after the published armour scheme: upper glacis 7 mm
# laid back at 80°, lower glacis 19 mm at 57°, upper sides 16 mm at 14° over
# the tracks and 18 mm upright behind the road wheels, rear and doors 16 mm
# at 19°, roof 6–7
# mm, turret front 23 mm (sloped), turret sides 15 mm. The driver sits front
# left with the engine (UTD-20) to his right and the transmission across the
# nose; gunner left and commander right in the turret, the 500 rounds of
# 30 mm in a box on the turret's rotating floor, one 9M113 on the turret
# floor and three on the right wall of the fighting compartment. All 462 l
# of fuel are in the troop compartment: the centre tank between the benches
# (225 l), the tanks in the bench bases (58 and 55 l) and the two rear
# doors (67 and 55 l). (BMP-2 technical description, part I.)
static func bmp2() -> VehicleArmor:
 var a:=VehicleArmor.new()
 a.turret_pivot=BmpArt.TURRET
 a.turret_radius=1.0
 var half:=BmpArt.HALF
 # Hull: (centre, half size, outward normal, mm).
 a.plate("верхній лобовий лист",Vector3(0,1.28,-2.24),Vector3(1.45,0.40,1.15),Vector3(0,0.985,-0.174),7.0)
 a.plate("нижній лобовий лист",Vector3(0,0.68,-3.10),Vector3(1.15,0.30,0.30),Vector3(0,-0.839,-0.545),19.0)
 for s in [-1.0,1.0]:
  a.plate("борт над гусеницею",Vector3(s*1.50,1.30,0.30),Vector3(0.14,0.36,3.10),Vector3(s*0.97,0.24,0),16.0)
  # Behind the road wheels and the track: the hit there tears the running
  # gear before it reaches the 18 mm of the lower side.
  a.plate("ходова частина",Vector3(s*1.32,0.48,0.0),Vector3(0.30,0.50,3.40),Vector3(s,0,0),18.0,false,"tracks")
 a.plate("корма й двері",Vector3(0,0.95,half-0.05),Vector3(1.45,0.55,0.18),Vector3(0,0.33,0.94),16.0)
 a.plate("дах",Vector3(0,1.62,1.15),Vector3(1.45,0.08,2.25),Vector3.UP,6.0)
 # Turret (relative to the ring centre, its front is -Z).
 a.plate("лоб башти",Vector3(0,0.42,-0.80),Vector3(0.80,0.32,0.22),Vector3(0,0.55,-0.84),23.0,true)
 for s in [-1.0,1.0]:a.plate("борт башти",Vector3(s*0.85,0.40,0.10),Vector3(0.18,0.32,0.80),Vector3(s,0.25,0),15.0,true)
 a.plate("дах башти",Vector3(0,0.72,0.10),Vector3(0.70,0.06,0.85),Vector3.UP,6.0,true)
 a.plate("корма башти",Vector3(0,0.40,0.92),Vector3(0.70,0.30,0.12),Vector3(0,0.2,1),15.0,true)
 # Parts behind (centre, half size).
 a.part("механік-водій","driver",Vector3(-0.78,0.95,-1.35),Vector3(0.26,0.45,0.35))
 a.part("двигун","engine",Vector3(0.52,0.95,-1.85),Vector3(0.58,0.42,0.72))
 a.part("трансмісія","drive",Vector3(0,0.72,-2.85),Vector3(1.05,0.28,0.42))
 a.part("паливний бак між лавами","fuel",Vector3(0,0.85,1.55),Vector3(0.22,0.38,0.95))
 for s in [-1.0,1.0]:a.part("бак в основі сидінь","fuel",Vector3(s*0.62,0.62,1.55),Vector3(0.22,0.14,0.95))
 a.part("ПТКР 9М113 на правому борту","missiles",Vector3(1.10,1.10,-0.30),Vector3(0.16,0.20,0.65))
 for s in [-1.0,1.0]:a.part("двері-бак","fuel",Vector3(s*0.50,0.95,half-0.12),Vector3(0.36,0.42,0.07))
 a.part("боєкомплект 30 мм","ammo",Vector3(0,-0.25,0.05),Vector3(0.62,0.22,0.55),true)
 a.part("гармата 2А42 і приціл","weapon",Vector3(-0.05,0.40,-0.75),Vector3(0.45,0.20,0.35),true)
 a.part("навідник-оператор","gunner",Vector3(-0.42,0.05,-0.10),Vector3(0.28,0.55,0.32),true)
 a.part("командир","commander",Vector3(0.42,0.05,-0.10),Vector3(0.28,0.55,0.32),true)
 for s in [-1.0,1.0]:
  for z in BmpArt.TROOP_Z:a.part("лава десанту","troop",Vector3(s*0.62,0.95,z),Vector3(0.25,0.45,0.30))
 return a

# BM-21 on the Ural-375D: no armour at all. The cab is pressed sheet steel
# about 1.5 mm thick, the bonnet and the wings as thin; the frame rails and
# the launch package are not protection either. Engine (ZIL-375 petrol V8)
# under the bonnet, the fuel tanks on the frame under the cab doors, forty
# 9M22U in the tubes of the package over the rear axles.
static func bm21() -> VehicleArmor:
 var a:=VehicleArmor.new()
 a.plate("капот",Vector3(0,1.57,-2.85),Vector3(0.62,0.48,0.75),Vector3.ZERO,1.2)
 a.plate("кабіна",Vector3(0,1.95,-1.40),Vector3(1.17,0.75,0.80),Vector3.ZERO,1.5)
 a.plate("рама й баки",Vector3(0,1.15,1.35),Vector3(1.17,0.30,1.95),Vector3.ZERO,5.0)
 a.plate("пакет напрямних",Vector3(0,2.30,1.25),Vector3(0.88,0.38,1.25),Vector3.ZERO,2.0)
 a.part("двигун","engine",Vector3(0,1.45,-2.80),Vector3(0.45,0.38,0.60))
 a.part("водій","driver",Vector3(-0.48,1.85,-1.15),Vector3(0.28,0.45,0.32))
 a.part("командир машини","commander",Vector3(0.50,1.85,-1.15),Vector3(0.28,0.45,0.32))
 for s in [-1.0,1.0]:a.part("паливний бак","fuel",Vector3(s*0.95,0.95,-0.75),Vector3(0.22,0.25,0.45))
 a.part("ракети 9М22У в пакеті","rockets",Vector3(0,2.30,1.25),Vector3(0.82,0.34,1.45))
 a.part("ходова частина","drive",Vector3(0,0.70,0.9),Vector3(1.10,0.35,1.9))
 return a

# --- Geometry --------------------------------------------------------------------------
# Penetration of a round at a range: the 30 mm AP (3UBR6) loses about a
# third between the muzzle and 1500 m; bullets by their energy.
static func penetration(round: String, distance: float=0.0, energy: float=1.0) -> float:
 var data: Dictionary=ROUNDS.get(round,ROUNDS.frag)
 if round=="ap30":return lerpf(float(data.pen),22.0,clampf(distance/1500.0,0,1))
 if round=="bullet":return float(data.pen)*energy
 return float(data.pen)

static func turret_frame(point: Vector3, pivot: Vector3, yaw: float) -> Vector3:
 return (point-pivot).rotated(Vector3.UP,-yaw)

static func box_distance(p: Vector3, center: Vector3, half: Vector3) -> float:
 var q:=(p-center).abs()-half
 return Vector3(maxf(q.x,0),maxf(q.y,0),maxf(q.z,0)).length()+minf(maxf(q.x,maxf(q.y,q.z)),0.0)

# Entry and exit of a segment through a box, as fractions of the segment,
# or Vector2(-1,-1).
static func segment_box(from: Vector3, to: Vector3, center: Vector3, half: Vector3) -> Vector2:
 var d:=to-from
 var t0:=0.0;var t1:=1.0
 for axis in range(3):
  var lo:=center[axis]-half[axis];var hi:=center[axis]+half[axis]
  if absf(d[axis])<0.000001:
   if from[axis]<lo or from[axis]>hi:return Vector2(-1,-1)
   continue
  var a:=(lo-from[axis])/d[axis];var b:=(hi-from[axis])/d[axis]
  if a>b:var swap:=a;a=b;b=swap
  t0=maxf(t0,a);t1=minf(t1,b)
  if t0>t1:return Vector2(-1,-1)
 return Vector2(t0,t1)

# The plate a hit at a point of the hull (vehicle frame) lands on: the one
# whose box is nearest, among those facing the shot.
func plate_at(point: Vector3, direction: Vector3, turret_yaw: float) -> Dictionary:
 var best: Dictionary={}
 var best_score:=INF
 for p in plates:
  var at:=turret_frame(point,turret_pivot,turret_yaw) if p.turret else point
  var toward:=direction.rotated(Vector3.UP,-turret_yaw) if p.turret else direction
  var facing:=-toward.dot(p.normal) if p.normal!=Vector3.ZERO else 1.0
  var score:=box_distance(at,p.center,p.half)+(0.0 if facing>0.0 else 1.5)
  if score<best_score:best_score=score;best=p
 return best

# Where a round that struck the hull at a point (vehicle frame) goes: the
# plate it met, whether it got through and with what left, and the parts on
# its line and in its spall cone ({part, depth, line}).
func resolve(point: Vector3, direction: Vector3, round: String, pen_mm: float, turret_yaw: float) -> Dictionary:
 var data: Dictionary=ROUNDS.get(round,ROUNDS.frag)
 var p:=plate_at(point,direction,turret_yaw)
 var result:={"plate":p,"penetrated":false,"residual":0.0,"los":0.0,"hits":[],"zone":String(p.get("zone","hull"))}
 if p.is_empty():return result
 var toward:=direction.rotated(Vector3.UP,-turret_yaw) if p.turret else direction
 var cosine:=-toward.dot(p.normal) if p.normal!=Vector3.ZERO else 1.0
 result.los=float(p.mm)/maxf(cosine,0.05)
 if cosine<GRAZE:
  result.glanced=true
  return result
 if pen_mm<=float(result.los):return result
 result.penetrated=true
 result.residual=pen_mm-float(result.los)
 var reach:=clampf(float(result.residual)*float(data.jet),0.35,4.5)
 var cone:=float(data.cone)
 for part_data in parts:
  var from:=point;var dir:=direction
  if part_data.turret:
   from=turret_frame(point,turret_pivot,turret_yaw);dir=toward
  var span:=segment_box(from,from+dir*reach,part_data.center,part_data.half)
  if span.x>=0.0:
   result.hits.append({"part":part_data,"depth":span.x*reach,"line":true})
   continue
  # Spall: the part's nearest point within the cone opening behind the plate.
  var c: Vector3=part_data.center
  var rel:=c-from
  var along:=rel.dot(dir)
  if along<0.05 or along>reach*0.7+0.6:continue
  var off:=(rel-dir*along).length()-Vector2(part_data.half.x,part_data.half.z).length()*0.7
  if off<along*tan(cone):result.hits.append({"part":part_data,"depth":along,"line":false})
 return result
