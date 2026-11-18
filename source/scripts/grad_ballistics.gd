class_name GradBallistics
extends RefCounted

# 122-mm 9M22U high-explosive fragmentation rocket of the BM-21 «Grad».
# Published data: length 2870 mm, 66.6 kg at launch, 20.45 kg of propellant,
# 18.4 kg warhead, top speed about 690 m/s, firing-table maximum 20.1 km.
# The motor burns 1.9 s; the specific impulse and the drag scale below are
# fitted so that this point-mass model reaches 690 m/s and 20.1 km. Brake
# rings slow the rocket on the descending branch: with the large ring the
# table covers 1.4–11.7 km, with the small one 11.7–15.9 km, without rings
# 15.9–20.1 km. This is a model fitted to those figures, not an official
# firing table.
const MASS := 66.6
const PROPELLANT := 20.45
const BURN := 1.9
const IMPULSE := 1981.1
const AREA := PI*0.061*0.061
const FORM := 1.1296
const RAILS := 3.0
const GRAVITY := 9.81
const CIRCLE := 6000
const RINGS := ["ВЕЛИКЕ КІЛЬЦЕ","МАЛЕ КІЛЬЦЕ","БЕЗ КІЛЕЦЬ"]
const RING_SHORT := ["ВК","МК","БК"]
const RING_DRAG := [0.6077,0.2240,0.0]
const RING_SPAN := [Vector2(1400,11700),Vector2(11700,15900),Vector2(15900,20100)]
const ELEVATION_MAX := 917 # 55°
# Round-to-round dispersion. Probable errors of the 9M22U: 1/326 of the range
# in range and 1/278 in deflection; one sigma is the probable error / 0.6745.
const IMPULSE_SPREAD := 0.0035
const ELEVATION_SPREAD := 0.0012
const DIRECTION_SPREAD := 0.0053
const TABLE_STEP := 5
static var tables: Dictionary = {}

static func drag_coefficient(mach: float) -> float:
 if mach<0.8:return 0.30
 if mach<1.05:return 0.30+(mach-0.8)/0.25*0.22
 if mach<1.3:return 0.52-(mach-1.05)/0.25*0.04
 return maxf(0.30,0.48-(mach-1.3)*0.10)

static func mass_at(age: float) -> float:
 return MASS-PROPELLANT*minf(age,BURN)/BURN

# Acceleration of the rocket. `launch` is the tube axis: on the rails the
# rocket moves only along it; afterwards the fins keep it nose into the wind.
static func acceleration(velocity: Vector3, height: float, age: float, travelled: float, launch: Vector3, ring: int, impulse_scale: float) -> Vector3:
 var speed := velocity.length()
 var along := launch if travelled<RAILS or speed<1.0 else velocity/speed
 var thrust := IMPULSE*impulse_scale*PROPELLANT/BURN if age<BURN else 0.0
 var h := maxf(height,0.0)
 var density := 1.225*exp(-h/8500.0)
 var sound := maxf(340.3-0.0039*h,295.0)
 var drag: float=0.5*density*speed*speed*AREA*(drag_coefficient(speed/sound)*FORM+float(RING_DRAG[ring]))
 var force := along*thrust-(velocity/speed*drag if speed>0.0 else Vector3.ZERO)
 var result := force/mass_at(age)+Vector3.DOWN*GRAVITY
 if travelled<RAILS:result=launch*maxf(result.dot(launch),0.0)
 return result

# One fourth-order Runge–Kutta step of a rocket state:
# {position, velocity, age, travelled, launch, ring, impulse}.
static func advance(state: Dictionary, dt: float) -> void:
 var p: Vector3=state.position
 var v: Vector3=state.velocity
 var t: float=state.age
 var s: float=state.travelled
 var launch: Vector3=state.launch
 var ring: int=state.ring
 var k: float=state.impulse
 var a1 := acceleration(v,p.y,t,s,launch,ring,k)
 var v2 := v+a1*dt*0.5
 var a2 := acceleration(v2,p.y+v.y*dt*0.5,t+dt*0.5,s+v.length()*dt*0.5,launch,ring,k)
 var v3 := v+a2*dt*0.5
 var a3 := acceleration(v3,p.y+v2.y*dt*0.5,t+dt*0.5,s+v2.length()*dt*0.5,launch,ring,k)
 var v4 := v+a3*dt
 var a4 := acceleration(v4,p.y+v3.y*dt,t+dt,s+v3.length()*dt,launch,ring,k)
 var next := p+(v+v2*2.0+v3*2.0+v4)*(dt/6.0)
 state.travelled=s+p.distance_to(next)
 state.position=next
 state.velocity=v+(a1+a2*2.0+a3*2.0+a4)*(dt/6.0)
 state.age=t+dt

static func radians(mils: float) -> float:return mils/CIRCLE*TAU
static func mils(angle: float) -> float:return angle/TAU*CIRCLE

# Soviet notation: 1186 thousandths are written 11-86.
static func mils_text(value: float) -> String:
 var v := posmod(roundi(value),CIRCLE)
 return "%d-%02d" % [v/100,v%100]

# Grid bearing in thousandths, clockwise from grid north (-Z).
static func bearing(direction: Vector3) -> float:
 return fposmod(mils(atan2(direction.x,-direction.z)),CIRCLE)

static func direction(bearing_mils: float) -> Vector3:
 var a := radians(bearing_mils)
 return Vector3(sin(a),0,-cos(a))

static func state(origin: Vector3, bearing_mils: float, elevation_mils: float, ring: int, impulse: float=1.0) -> Dictionary:
 var e := radians(elevation_mils)
 var launch := direction(bearing_mils)*cos(e)+Vector3.UP*sin(e)
 return {"position":origin,"velocity":Vector3.ZERO,"age":0.0,"travelled":0.0,"launch":launch,"ring":ring,"impulse":impulse}

# Range and time of flight to the level of the launcher.
static func simulate(ring: int, elevation_mils: float) -> Dictionary:
 var shot := state(Vector3.ZERO,0,elevation_mils,ring)
 var apex := 0.0
 while float(shot.age)<200.0:
  var t: float=shot.age
  var dt := 0.02 if t<BURN+0.3 else 0.1
  if t<BURN and t+dt>BURN:dt=BURN-t
  var before: Vector3=shot.position
  advance(shot,dt)
  var p: Vector3=shot.position
  apex=maxf(apex,p.y)
  if p.y<0.0 and Vector3(shot.velocity).y<0.0 and float(shot.age)>1.0:
   var f := before.y/(before.y-p.y)
   return {"range":-lerpf(before.z,p.z,f),"time":float(shot.age)-dt*(1.0-f),"apex":apex,"speed":Vector3(shot.velocity).length()}
 return {"range":-Vector3(shot.position).z,"time":shot.age,"apex":apex,"speed":0.0}

# Rows [elevation, range, time, apex] from the lowest useful elevation to the
# elevation of the greatest range (the ascending branch only).
static func table(ring: int) -> Array:
 if tables.has(ring):return tables[ring]
 var rows: Array=[]
 var elevation := 40
 var best := 0.0
 while elevation<=ELEVATION_MAX:
  var shot := simulate(ring,elevation)
  if float(shot.range)<best:break
  best=shot.range
  rows.append([float(elevation),float(shot.range),float(shot.time),float(shot.apex)])
  elevation+=TABLE_STEP if elevation<200 else TABLE_STEP*2
 tables[ring]=rows
 return rows

static func range_limits(ring: int) -> Vector2:
 return RING_SPAN[ring]

static func max_range(ring: int) -> float:
 return float(table(ring)[-1][1])

static func range_for(ring: int, elevation_mils: float) -> float:
 var rows := table(ring)
 if elevation_mils<=rows[0][0]:return rows[0][1]*elevation_mils/rows[0][0]
 for i in range(rows.size()-1):
  if elevation_mils<=rows[i+1][0]:
   return lerpf(rows[i][1],rows[i+1][1],(elevation_mils-rows[i][0])/(rows[i+1][0]-rows[i][0]))
 return rows[-1][1]

# Elevation for a range on the ascending branch; -1 when out of reach.
static func elevation_for(ring: int, distance: float) -> float:
 var rows := table(ring)
 for i in range(rows.size()-1):
  if distance>=rows[i][1] and distance<=rows[i+1][1]:
   return lerpf(rows[i][0],rows[i+1][0],(distance-rows[i][1])/maxf(rows[i+1][1]-rows[i][1],0.001))
 return -1.0

static func time_for(ring: int, distance: float) -> float:
 var rows := table(ring)
 for i in range(rows.size()-1):
  if distance>=rows[i][1] and distance<=rows[i+1][1]:
   return lerpf(rows[i][2],rows[i+1][2],(distance-rows[i][1])/maxf(rows[i+1][1]-rows[i][1],0.001))
 return rows[-1][2]

# Printed firing table: range, sight setting, change of range per thousandth,
# flight time, probable errors in range and deflection.
static func firing_rows(ring: int) -> Array:
 var span: Vector2=RING_SPAN[ring]
 var rows: Array=[]
 var distance := ceili(span.x/200.0)*200
 while distance<=span.y:
  var elevation := elevation_for(ring,distance)
  if elevation>=0:
   var change := absf(range_for(ring,elevation+1)-range_for(ring,elevation))
   rows.append({"range":distance,"elevation":elevation,"per_mil":change,"time":time_for(ring,distance),"vd":distance/326.0,"vb":distance/278.0})
  distance+=200
 return rows
