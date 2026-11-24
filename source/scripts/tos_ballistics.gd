class_name TosBallistics
extends RefCounted

# 220-mm unguided rocket MO.1.01.04M of the TOS-1A «Солнцепёк» (BM-1).
# Published data (VEHICLE-REFERENCES.md, «ТОС-1А»): length 3723 mm, 217 kg
# at launch, about 90 kg of thermobaric mixture in the head, fired from
# 3725-mm tubes, range 600–6000 m. The burn time and the propellant mass
# are not published: the flame is seen only by the launcher, so the motor is
# given a 0.9 s burn of 38 kg; the specific impulse (1995 m/s) is fitted to
# the 375 m/s at the end of the burn given by one source, the drag scale to
# the 6000 m maximum (reached at 43°). The blunt head with the fuse pin of
# the MRV-U1 sticking out of it («Буратино») has more drag than the Grad's
# ogive. A model fitted to those figures, not an official firing table.
const MASS := 217.0
const PROPELLANT := 38.0
const BURN := 0.9
const IMPULSE := 1995.1
const AREA := PI*0.11*0.11
const FORM := 2.9897
const RAILS := 3.725
const GRAVITY := 9.81
const CIRCLE := 6000
const SPAN := Vector2(600,6000)
const ELEVATION_MAX := 1000 # 60°
# Round-to-round dispersion. No official figures are published; the salvo
# of the TOS-1 is said to cover about 200 × 400 m. Taken as a 1.75 % spread
# of the motors' impulse (one sigma) and 8 thousandths of a radian in
# direction: the probable errors come to about 1/95 of the range in range
# and 1/185 in deflection. Four sigma: about 315 × 145 m at 4.5 km, about
# 330 × 190 m at 6 km (near the top of the range the range hardly changes
# with the impulse).
const IMPULSE_SPREAD := 0.0175
const ELEVATION_SPREAD := 0.0015
const DIRECTION_SPREAD := 0.0080
const TABLE_STEP := 5
static var rows_cache: Array=[]

static func drag_coefficient(mach: float) -> float:
 if mach<0.8:return 0.42
 if mach<1.05:return 0.42+(mach-0.8)/0.25*0.24
 if mach<1.3:return 0.66-(mach-1.05)/0.25*0.05
 return maxf(0.45,0.61-(mach-1.3)*0.10)

static func mass_at(age: float) -> float:
 return MASS-PROPELLANT*minf(age,BURN)/BURN

# Acceleration of the rocket. `launch` is the tube axis: in the tube the
# rocket moves only along it; afterwards the fins keep it nose into the wind.
static func acceleration(velocity: Vector3, height: float, age: float, travelled: float, launch: Vector3, impulse_scale: float) -> Vector3:
 var speed := velocity.length()
 var along := launch if travelled<RAILS or speed<1.0 else velocity/speed
 var thrust := IMPULSE*impulse_scale*PROPELLANT/BURN if age<BURN else 0.0
 var h := maxf(height,0.0)
 var density := 1.225*exp(-h/8500.0)
 var sound := maxf(340.3-0.0039*h,295.0)
 var drag: float=0.5*density*speed*speed*AREA*drag_coefficient(speed/sound)*FORM
 var force := along*thrust-(velocity/speed*drag if speed>0.0 else Vector3.ZERO)
 var result := force/mass_at(age)+Vector3.DOWN*GRAVITY
 if travelled<RAILS:result=launch*maxf(result.dot(launch),0.0)
 return result

# One fourth-order Runge–Kutta step of a rocket state:
# {position, velocity, age, travelled, launch, impulse}.
static func advance(state: Dictionary, dt: float) -> void:
 var p: Vector3=state.position
 var v: Vector3=state.velocity
 var t: float=state.age
 var s: float=state.travelled
 var launch: Vector3=state.launch
 var k: float=state.impulse
 var a1 := acceleration(v,p.y,t,s,launch,k)
 var v2 := v+a1*dt*0.5
 var a2 := acceleration(v2,p.y+v.y*dt*0.5,t+dt*0.5,s+v.length()*dt*0.5,launch,k)
 var v3 := v+a2*dt*0.5
 var a3 := acceleration(v3,p.y+v2.y*dt*0.5,t+dt*0.5,s+v2.length()*dt*0.5,launch,k)
 var v4 := v+a3*dt
 var a4 := acceleration(v4,p.y+v3.y*dt,t+dt,s+v3.length()*dt,launch,k)
 var next := p+(v+v2*2.0+v3*2.0+v4)*(dt/6.0)
 state.travelled=s+p.distance_to(next)
 state.position=next
 state.velocity=v+(a1+a2*2.0+a3*2.0+a4)*(dt/6.0)
 state.age=t+dt

# A rocket leaving the tube with its own spread of motor, elevation and
# direction (BlastSystem flies it with advance()).
static func state(origin: Vector3, bearing_mils: float, elevation_mils: float, impulse: float=1.0) -> Dictionary:
 var e := GradBallistics.radians(elevation_mils)
 var launch := GradBallistics.direction(bearing_mils)*cos(e)+Vector3.UP*sin(e)
 return {"position":origin,"velocity":Vector3.ZERO,"age":0.0,"travelled":0.0,"launch":launch,"impulse":impulse,"model":TosBallistics,"burn":BURN,"warhead":"tos"}

static func spread_state(origin: Vector3, bearing_mils: float, elevation_mils: float) -> Dictionary:
 var bearing := bearing_mils+GradBallistics.mils(randfn(0.0,DIRECTION_SPREAD))
 var elevation := elevation_mils+GradBallistics.mils(randfn(0.0,ELEVATION_SPREAD))
 return state(origin,bearing,elevation,1.0+randfn(0.0,IMPULSE_SPREAD))

# Range and time of flight to the level of the launcher, or to a level
# `drop` metres below it (negative: above).
static func simulate(elevation_mils: float, impulse: float=1.0, drop: float=0.0) -> Dictionary:
 var shot := state(Vector3.ZERO,0,elevation_mils,impulse)
 var apex := 0.0
 while float(shot.age)<200.0:
  var t: float=shot.age
  var dt := 0.01 if t<BURN+0.3 else 0.05
  if t<BURN and t+dt>BURN:dt=BURN-t
  var before: Vector3=shot.position
  advance(shot,dt)
  var p: Vector3=shot.position
  apex=maxf(apex,p.y)
  if p.y<-drop and Vector3(shot.velocity).y<0.0 and float(shot.age)>0.5:
   var f := (before.y+drop)/(before.y-p.y)
   return {"range":-lerpf(before.z,p.z,f),"time":float(shot.age)-dt*(1.0-f),"apex":apex,"speed":Vector3(shot.velocity).length()}
 return {"range":-Vector3(shot.position).z,"time":shot.age,"apex":apex,"speed":0.0}

# Rows [elevation, range, time, apex] from the lowest useful elevation to the
# elevation of the greatest range (the ascending branch only).
static func table() -> Array:
 if not rows_cache.is_empty():return rows_cache
 var rows: Array=[]
 var elevation := 20
 var best := 0.0
 while elevation<=ELEVATION_MAX:
  var shot := simulate(elevation)
  if float(shot.range)<best:break
  best=shot.range
  rows.append([float(elevation),float(shot.range),float(shot.time),float(shot.apex)])
  elevation+=TABLE_STEP if elevation<300 else TABLE_STEP*2
 rows_cache=rows
 return rows

static func max_range() -> float:
 return float(table()[-1][1])

static func range_for(elevation_mils: float) -> float:
 var rows := table()
 if elevation_mils<=rows[0][0]:return rows[0][1]*elevation_mils/rows[0][0]
 for i in range(rows.size()-1):
  if elevation_mils<=rows[i+1][0]:
   return lerpf(rows[i][1],rows[i+1][1],(elevation_mils-rows[i][0])/(rows[i+1][0]-rows[i][0]))
 return rows[-1][1]

# Elevation for a range on the ascending branch; -1 when out of reach.
static func elevation_for(distance: float) -> float:
 if distance<SPAN.x or distance>SPAN.y:return -1.0
 var rows := table()
 for i in range(rows.size()-1):
  if distance>=rows[i][1] and distance<=rows[i+1][1]:
   return lerpf(rows[i][0],rows[i+1][0],(distance-rows[i][1])/maxf(rows[i+1][1]-rows[i][1],0.001))
 return -1.0

static func time_for(distance: float) -> float:
 var rows := table()
 for i in range(rows.size()-1):
  if distance>=rows[i][1] and distance<=rows[i+1][1]:
   return lerpf(rows[i][2],rows[i+1][2],(distance-rows[i][1])/maxf(rows[i+1][1]-rows[i][1],0.001))
 return rows[-1][2]

# Elevation that puts the rocket on a point `drop` metres below (negative:
# above) the launcher at `distance`, as the ballistic computer works it out
# with the height difference: the table value refined by bisection on the
# same flight model. -1 when out of reach.
static func elevation_to(distance: float, drop: float) -> float:
 var guess := elevation_for(distance)
 if guess<0.0:return guess
 var low := maxf(0.0,guess-120.0)
 var high := minf(float(table()[-1][0]),guess+120.0)
 if float(simulate(high,1.0,drop).range)<distance:return high
 for i in range(16):
  var middle := (low+high)*0.5
  if float(simulate(middle,1.0,drop).range)<distance:low=middle
  else:high=middle
 return (low+high)*0.5

# Printed firing table: range, elevation, change of range per thousandth,
# flight time, probable errors in range and deflection.
static func firing_rows() -> Array:
 var rows: Array=[]
 var distance := int(SPAN.x)
 while distance<=SPAN.y:
  var elevation := elevation_for(distance)
  if elevation>=0:
   var change := absf(range_for(elevation+1)-range_for(elevation))
   rows.append({"range":distance,"elevation":elevation,"per_mil":change,"time":time_for(distance),"vd":distance/95.0,"vb":distance/185.0})
  distance+=200
 return rows
