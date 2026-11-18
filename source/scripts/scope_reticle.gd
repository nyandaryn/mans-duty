extends Control
var sight: ScopeSight
var ink := Color.BLACK
var shift := Vector2.ZERO

func project(angle: Vector2) -> Vector2:
 var focal := size.y/(2*tan(deg_to_rad(ScopeSight.FIELD_OF_VIEW)*0.5))
 return size*0.5+Vector2(tan(angle.x),tan(angle.y))*focal

func line(a: Vector2, b: Vector2, width: float=1.7) -> void:
 draw_line(project(a+shift),project(b+shift),ink,width,true)

func chevron(y: float) -> void:
 line(Vector2(-0.0018,y+0.0015),Vector2(0,y),2)
 line(Vector2(0,y),Vector2(0.0018,y+0.0015),2)

func text_at(point: Vector2, text: String) -> void:
 draw_string(ThemeDB.fallback_font,project(point+shift),text,HORIZONTAL_ALIGNMENT_CENTER,-1,16,ink)

func _draw() -> void:
 if not is_instance_valid(sight) or not is_instance_valid(sight.operator):return
 var weapon := sight.operator.current()
 ink=Color(0.84,0.10,0.035) if weapon.scope_illuminated else Color(0.018,0.016,0.012)
 shift=ScopeSight.reticle_angles(weapon.scope_zero,weapon.scope_windage)
 chevron(0)
 var reference := ScopeSight.reticle_angles(1000).y
 for distance in [1100,1200,1300]:chevron(ScopeSight.reticle_angles(distance).y-reference)
 for side in [-1,1]:
  for i in range(1,11):
   var x: float=side*i*0.001
   line(Vector2(x,0),Vector2(x,0.002 if i%5==0 else 0.001))
  line(Vector2(side*0.001,0),Vector2(side*0.010,0))
  line(Vector2(side*0.013,0),Vector2(side*0.026,0),3)
  text_at(Vector2(side*0.010-0.0015,0.005),"10")
 # Angular gaps exactly match a 1.7 m object, regardless of screen resolution.
 var baseline := 0.023
 line(Vector2(-0.035,baseline),Vector2(-0.014,baseline))
 var previous := Vector2.ZERO
 for distance in range(200,1001,10):
  var x := lerpf(-0.014,-0.035,float(distance-200)/800)
  var point := Vector2(x,baseline-atan(1.7/distance))
  if distance>200:line(previous,point)
  if distance%200==0:
   line(point,point-Vector2(0,0.0008))
   text_at(point-Vector2(0.0009,0.0018),str(distance/100))
  previous=point
 text_at(Vector2(-0.036,baseline+0.004),"1,7")
