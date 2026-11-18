class_name MortarBallistics
extends RefCounted

# 82-mm 2B14 «Podnos» firing the O-832DU fragmentation mine (3.1 kg).
# Calibrated to published figures: elevation 45–85°, 85 m minimum range
# (charge 0 at 85°), about 3100 m on the full variable charge and 3922 m on
# the long-range charge, both at 45°. Muzzle velocities of the intermediate
# charges are interpolated and the drag coefficient is fitted to those ranges:
# this is a point-mass model, not an official firing table.
const MASS := 3.1
const AREA := PI*0.041*0.041
const DRAG := 0.04682
const GRAVITY := 9.81
const CIRCLE := 6000
const ELEVATION_MIN := 750 # 45°
const ELEVATION_MAX := 1417 # 85°
const CHARGES := ["0","1","2","3","4","Д"]
const VELOCITY := [70.0,98.7,127.4,156.1,184.8,211.0]
const TABLE_STEP := 25
const TABLE_DT := 0.05
# Round-to-round spread (1 sigma): propellant temperature and charge mass,
# laying error of the sight. Gives roughly 1/80 of range in depth.
const VELOCITY_SPREAD := 0.007
const ELEVATION_SPREAD := 1.0
const DIRECTION_SPREAD := 2.0
static var tables: Dictionary = {}

static func acceleration(velocity: Vector3, height: float) -> Vector3:
 var density := 1.225*exp(-maxf(height,0.0)/8500.0)
 return Vector3.DOWN*GRAVITY-velocity*(0.5*density*DRAG*AREA/MASS*velocity.length())

# One fourth-order Runge–Kutta step. The flight in the world and the firing
# table use the same equations, so the table describes the real trajectory.
static func advance(position: Vector3, velocity: Vector3, dt: float) -> Array:
 var a1 := acceleration(velocity,position.y)
 var v2 := velocity+a1*dt*0.5
 var a2 := acceleration(v2,position.y+velocity.y*dt*0.5)
 var v3 := velocity+a2*dt*0.5
 var a3 := acceleration(v3,position.y+v2.y*dt*0.5)
 var v4 := velocity+a3*dt
 var a4 := acceleration(v4,position.y+v3.y*dt)
 return [position+(velocity+v2*2.0+v3*2.0+v4)*(dt/6.0),velocity+(a1+a2*2.0+a3*2.0+a4)*(dt/6.0)]

static func radians(mils: float) -> float:return mils/CIRCLE*TAU
static func mils(angle: float) -> float:return angle/TAU*CIRCLE

# Soviet notation: 1186 thousandths are written 11-86.
static func mils_text(value: int) -> String:
 value=posmod(value,CIRCLE)
 return "%02d-%02d" % [value/100,value%100]

# Grid bearing in thousandths, clockwise from north (-Z), as on the compass.
static func azimuth(direction: Vector3) -> int:
 return posmod(roundi(mils(fposmod(atan2(direction.x,-direction.z),TAU))),CIRCLE)

static func direction(azimuth_mils: float) -> Vector3:
 var a := radians(azimuth_mils)
 return Vector3(sin(a),0,-cos(a))

static func launch_velocity(charge: int, elevation_mils: float, azimuth_mils: float, speed_scale: float=1.0) -> Vector3:
 var e := radians(elevation_mils)
 return (direction(azimuth_mils)*cos(e)+Vector3.UP*sin(e))*float(VELOCITY[charge])*speed_scale

# Range and time of flight to the level of the muzzle.
static func simulate(charge: int, elevation_mils: float) -> Dictionary:
 var position := Vector3.ZERO
 var velocity := launch_velocity(charge,elevation_mils,0)
 velocity=Vector3(-velocity.z,velocity.y,0)
 var time := 0.0
 var apex := 0.0
 while time<120:
  var next := advance(position,velocity,TABLE_DT)
  var p: Vector3=next[0]
  var v: Vector3=next[1]
  if p.y<0 and v.y<0:
   var f := position.y/(position.y-p.y)
   return {"range":lerpf(position.x,p.x,f),"time":time+TABLE_DT*f,"apex":apex}
  position=p;velocity=v;time+=TABLE_DT
  apex=maxf(apex,position.y)
 return {"range":position.x,"time":time,"apex":apex}

static func table(charge: int) -> Array:
 if tables.has(charge):return tables[charge]
 var rows: Array=[]
 var elevation := ELEVATION_MIN
 while true:
  var shot := simulate(charge,elevation)
  rows.append([float(elevation),float(shot.range),float(shot.time)])
  if elevation>=ELEVATION_MAX:break
  elevation=mini(ELEVATION_MAX,elevation+TABLE_STEP)
 tables[charge]=rows
 return rows

static func range_limits(charge: int) -> Vector2:
 var rows := table(charge)
 return Vector2(rows[-1][1],rows[0][1])

static func range_for(charge: int, elevation_mils: float) -> float:
 var rows := table(charge)
 elevation_mils=clampf(elevation_mils,ELEVATION_MIN,ELEVATION_MAX)
 for i in range(rows.size()-1):
  if elevation_mils<=rows[i+1][0]:
   return lerpf(rows[i][1],rows[i+1][1],(elevation_mils-rows[i][0])/(rows[i+1][0]-rows[i][0]))
 return rows[-1][1]

# High-angle fire: range falls as elevation rises between 45° and 85°.
static func elevation_for(charge: int, distance: float) -> float:
 var rows := table(charge)
 for i in range(rows.size()-1):
  var near: float=rows[i+1][1]
  var far: float=rows[i][1]
  if distance<=far and distance>=near:
   return lerpf(rows[i][0],rows[i+1][0],(far-distance)/maxf(far-near,0.001))
 return -1.0

static func time_for(charge: int, elevation_mils: float) -> float:
 var rows := table(charge)
 elevation_mils=clampf(elevation_mils,ELEVATION_MIN,ELEVATION_MAX)
 for i in range(rows.size()-1):
  if elevation_mils<=rows[i+1][0]:
   return lerpf(rows[i][2],rows[i+1][2],(elevation_mils-rows[i][0])/(rows[i+1][0]-rows[i][0]))
 return rows[-1][2]

# Printed rows: range, sight setting, range change per thousandth, flight time.
static func firing_rows(charge: int) -> Array:
 var limits := range_limits(charge)
 var span := limits.y-limits.x
 var step := 25 if span<=450 else (50 if span<=900 else (100 if span<=1900 else 200))
 var rows: Array=[]
 var distance := ceili(limits.x/step)*step
 while distance<=limits.y:
  var elevation := elevation_for(charge,distance)
  if elevation>=0:
   var change := absf(range_for(charge,elevation+1)-range_for(charge,elevation))
   rows.append({"range":distance,"elevation":roundi(elevation),"per_mil":change,"time":time_for(charge,elevation)})
  distance+=step
 return rows
