extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 check(FlightModel.drag_coefficient(1.1)>2*FlightModel.drag_coefficient(0.5),"Transonic drag rise is retained")
 # Independent published reference: Hornady 2022 metric table, 60 gr 5.45
 # V-MAX, BC .285, 856 m/s. This validates the solver, not the game's FMJ load.
 var expected := {50:803.0,100:752.0,150:702.0,200:654.0,250:608.0,300:563.0}
 var position := Vector3.ZERO
 var velocity := Vector3(0,0,-856)
 var matched := 0
 for i in range(1000):
  var next := FlightModel.advance(position,velocity,0.285,1.0/240)
  for distance in expected:
   if -position.z<float(distance) and -next[0].z>=float(distance):
    var f: float= (distance+position.z)/(position.z-next[0].z)
    var speed := lerpf(velocity.length(),next[1].length(),f)
    check(absf(speed-expected[distance])<4.0,"Published velocity at %d m: %.2f vs %.0f" % [distance,speed,expected[distance]])
    matched+=1
  position=next[0];velocity=next[1]
  if matched==6:break
 check(matched==6,"All published range samples reached")
 for id in WeaponState.DATA:
  var a: Array[Vector3]=[Vector3.ZERO,Vector3(0,0,-float(Ballistics.PROFILES[id].speed))]
  var b := a.duplicate()
  for i in range(30):a=FlightModel.advance(a[0],a[1],FlightModel.BC[id],1.0/30)
  for i in range(144):b=FlightModel.advance(b[0],b[1],FlightModel.BC[id],1.0/144)
  check(a[0].distance_to(b[0])<0.005 and a[1].distance_to(b[1])<0.005,"Frame rate independent trajectory "+id)
  var height := 0.04
  var zero := float(Ballistics.PROFILES[id].zero)
  var angle := FlightModel.zero_angle(id,height,zero)
  check(absf(FlightModel.range_state(id,zero,angle).x-height)<0.001,"Physical zero includes bore offset and drag "+id)
  var at100 := FlightModel.range_state(id,100)
  var at300 := FlightModel.range_state(id,300)
  check(at300.y<at100.y and at300.x<at100.x and at300.z>at100.z,"Speed, drop, flight time vary with range "+id)
 var calm := FlightModel.advance(Vector3.ZERO,Vector3(0,0,-880),0.31,1)
 var windy := FlightModel.advance(Vector3.ZERO,Vector3(0,0,-880),0.31,1,Vector3(8,0,0))
 check(windy[0].x>calm[0].x+0.2,"Wind uses air-relative velocity")
 print("FAIL: " if failed else "PASS: ",checks," independent flight model checks")
 quit(1 if failed else 0)
