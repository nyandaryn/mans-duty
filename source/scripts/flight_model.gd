class_name FlightModel
extends RefCounted

# G1 Cd/Mach observations from BRL, via JBM / go_ballisticcalc Drag.go.
# The table is reference data; the game profiles are representative FMJ loads.
const G1 = [
 Vector2(0.00,0.2629),
 Vector2(0.05,0.2558),
 Vector2(0.10,0.2487),
 Vector2(0.15,0.2413),
 Vector2(0.20,0.2344),
 Vector2(0.25,0.2278),
 Vector2(0.30,0.2214),
 Vector2(0.35,0.2155),
 Vector2(0.40,0.2104),
 Vector2(0.45,0.2061),
 Vector2(0.50,0.2032),
 Vector2(0.55,0.2020),
 Vector2(0.60,0.2034),
 Vector2(0.70,0.2165),
 Vector2(0.725,0.2230),
 Vector2(0.75,0.2313),
 Vector2(0.775,0.2417),
 Vector2(0.80,0.2546),
 Vector2(0.825,0.2706),
 Vector2(0.85,0.2901),
 Vector2(0.875,0.3136),
 Vector2(0.90,0.3415),
 Vector2(0.925,0.3734),
 Vector2(0.95,0.4084),
 Vector2(0.975,0.4448),
 Vector2(1.0,0.4805),
 Vector2(1.025,0.5136),
 Vector2(1.05,0.5427),
 Vector2(1.075,0.5677),
 Vector2(1.10,0.5883),
 Vector2(1.125,0.6053),
 Vector2(1.15,0.6191),
 Vector2(1.20,0.6393),
 Vector2(1.25,0.6518),
 Vector2(1.30,0.6589),
 Vector2(1.35,0.6621),
 Vector2(1.40,0.6625),
 Vector2(1.45,0.6607),
 Vector2(1.50,0.6573),
 Vector2(1.55,0.6528),
 Vector2(1.60,0.6474),
 Vector2(1.65,0.6413),
 Vector2(1.70,0.6347),
 Vector2(1.75,0.6280),
 Vector2(1.80,0.6210),
 Vector2(1.85,0.6141),
 Vector2(1.90,0.6072),
 Vector2(1.95,0.6003),
 Vector2(2.00,0.5934),
 Vector2(2.05,0.5867),
 Vector2(2.10,0.5804),
 Vector2(2.15,0.5743),
 Vector2(2.20,0.5685),
 Vector2(2.25,0.5630),
 Vector2(2.30,0.5577),
 Vector2(2.35,0.5527),
 Vector2(2.40,0.5481),
 Vector2(2.45,0.5438),
 Vector2(2.50,0.5397),
 Vector2(2.60,0.5325),
 Vector2(2.70,0.5264),
 Vector2(2.80,0.5211),
 Vector2(2.90,0.5168),
 Vector2(3.00,0.5133),
 Vector2(3.10,0.5105),
 Vector2(3.20,0.5084),
 Vector2(3.30,0.5067),
 Vector2(3.40,0.5054),
 Vector2(3.50,0.5040),
 Vector2(3.60,0.5030),
 Vector2(3.70,0.5022),
 Vector2(3.80,0.5016),
 Vector2(3.90,0.5010),
 Vector2(4.00,0.5006),
 Vector2(4.20,0.4998),
 Vector2(4.40,0.4995),
 Vector2(4.60,0.4992),
 Vector2(4.80,0.4990),
 Vector2(5.00,0.4988)
]
const BC = {"ak74":0.31,"m16":0.304,"svd":0.411,"pm":0.12,"m9":0.16}
const AIR_DENSITY := 1.225
const SOUND_SPEED := 340.3
const BC_TO_SI := 703.06958 # lb/in² to kg/m² (BC uses diameter², not frontal area).
const MAX_STEP := 1.0/240.0
static var zero_cache: Dictionary={}

static func drag_coefficient(mach: float) -> float:
 var lo := 0
 var hi := G1.size()-1
 while hi-lo>1:
  var middle := (lo+hi)/2
  if G1[middle].x<mach:lo=middle
  else:hi=middle
 return lerpf(G1[lo].y,G1[hi].y,clampf((mach-G1[lo].x)/(G1[hi].x-G1[lo].x),0,1))

static func acceleration(velocity: Vector3, bc: float, wind: Vector3=Vector3.ZERO) -> Vector3:
 var relative := velocity-wind
 var speed := relative.length()
 var factor := AIR_DENSITY*PI/(8.0*bc*BC_TO_SI)*drag_coefficient(speed/SOUND_SPEED)
 return Vector3(0,-9.80665,0)-relative*speed*factor

static func advance(position: Vector3, velocity: Vector3, bc: float, delta: float, wind: Vector3=Vector3.ZERO) -> Array[Vector3]:
 # RK4 with bounded integration steps: stable across render/physics rates.
 var remaining := delta
 while remaining>0.0000001:
  var h := minf(remaining,MAX_STEP)
  var a := acceleration(velocity,bc,wind)
  var b := acceleration(velocity+a*h*0.5,bc,wind)
  var c := acceleration(velocity+b*h*0.5,bc,wind)
  var d := acceleration(velocity+c*h,bc,wind)
  position+=velocity*h+(a+b+c)*(h*h/6.0)
  velocity+=(a+b*2+c*2+d)*(h/6.0)
  remaining-=h
 return [position,velocity]

static func range_state(id: String, distance: float, angle: float=0.0) -> Vector3:
 var point := Vector3.ZERO
 var velocity := Vector3(0,sin(angle),-cos(angle))*float(Ballistics.PROFILES[id].speed)
 var time := 0.0
 for i in range(7200):
  var next := advance(point,velocity,float(BC[id]),MAX_STEP)
  if -next[0].z>=distance:
   var fraction := (distance+point.z)/(point.z-next[0].z)
   return Vector3(lerpf(point.y,next[0].y,fraction),lerpf(velocity.length(),next[1].length(),fraction),time+MAX_STEP*fraction)
  point=next[0];velocity=next[1];time+=MAX_STEP
 return Vector3(point.y,velocity.length(),time)

static func zero_angle(id: String, height: float, distance: float) -> float:
 var key := id+str(snappedf(height,0.0001))+str(distance)
 if zero_cache.has(key):return zero_cache[key]
 var low := 0.0
 var high := 0.08
 for i in range(17):
  var angle := (low+high)*0.5
  if range_state(id,distance,angle).x<height:low=angle
  else:high=angle
 zero_cache[key]=(low+high)*0.5
 return zero_cache[key]
