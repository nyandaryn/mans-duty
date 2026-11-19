class_name BmpCockpit
extends Control

# What the player sees from inside the BMP-2. The driver with the hatch shut
# looks through three TNPO-170A prism blocks under the rubber brow pad; at
# his left knee is the instrument panel (tachometer with the engine-hour
# counter, speedometer with the odometer, the GPK-59 gyro semi-compass,
# coolant and oil temperatures, oil pressure, the voltmeter, the gauge of the
# air-start bottle, the clock and the warning lamps), in front of him the
# yoke, at his right hand the gear gate. The right mouse button brings the
# panel up large, as in the BM-21 cab; with the hatch open it is the only
# way to read it. A passenger in the commander's seat of the turret looks
# through the TKN-3B and two TNPO-170A; the right button gives the TKN-3B
# at ×5 with its reticle.
const PANEL := Vector2(1100,480)
# Height of the middle of the prism windows on the screen (0 top, 1 bottom):
# the seat camera is pitched so that this band looks at the horizon.
const DRIVER_BAND := 0.29
const COMMANDER_BAND := 0.32
const INTERIOR := Color("1d211a")
const STEEL := Color("2c3128")
const PLATE := Color("394034")
const PLATE_EDGE := Color("23281f")
const RUBBER := Color("121311")
const FACE := Color("0d0e0c")
const BEZEL := Color("70746a")
const MARK := Color("e6e2d2")
const NEEDLE := Color("f2eee0")
const RED := Color("d2452f")
const AMBER := Color("e8a33a")
const GREEN := Color("6fcf4f")
var game: Node3D
var command: Node
var large := 0.0
var knob := Vector2(1,1)

func setup(owner_game: Node3D, owner_command: Node) -> void:
 game=owner_game;command=owner_command
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 hide()

func vehicle() -> BmpVehicle:return command.vehicle

func view() -> String:
 if not command.active() or not game.running or command.seat=="":return ""
 if command.seat=="driver":return "driver_open" if vehicle().hatch_open else "driver"
 if command.seat=="commander" and not command.head_out:return "commander"
 return ""

func aiming() -> bool:
 return Input.is_action_pressed("aim") and not game.commands_open and not game.paused and not game.inventory_open

# The right button: the panel large at the driver's seat, the TKN-3B at ×5
# at the commander's.
func instruments_shown() -> bool:return command.seat=="driver" and aiming()
func scope_shown() -> bool:return view()=="commander" and aiming()

func _process(delta: float) -> void:
 var mode:=view()
 visible=mode!=""
 if not visible:large=0.0;return
 large=move_toward(large,1.0 if instruments_shown() else 0.0,delta*6.0)
 var v:=vehicle()
 var slot: Vector2={0:Vector2(0,0),1:Vector2(1,1),2:Vector2(0,2),3:Vector2(1,0),4:Vector2(1,2),5:Vector2(2,0),6:Vector2(2,2)}.get(v.gear,Vector2(1,1))
 # The lever goes through neutral: across first, then along the slot.
 if absf(knob.x-slot.x)>0.01 and absf(knob.y-1.0)>0.01:knob.y=move_toward(knob.y,1.0,delta*12.0)
 else:
  knob.x=move_toward(knob.x,slot.x,delta*12.0)
  if absf(knob.x-slot.x)<=0.01:knob.y=move_toward(knob.y,slot.y,delta*12.0)
 queue_redraw()

func _draw() -> void:
 match view():
  "driver":
   var windows:=driver_windows()
   interior(windows)
   brow_pad(windows)
   for r in windows:prism(r)
   yoke()
   gear_gate()
   notice()
   panel(1.0)
  "driver_open":
   if large>0.0:panel(large)
  "commander":
   if scope_shown():scope();return
   var windows:=commander_windows()
   interior(windows)
   for i in range(windows.size()):prism(windows[i],i==1)
   draw_string(ThemeDB.fallback_font,Vector2(0,windows[1].end.y+46.0*unit()),"ТКН-3Б",HORIZONTAL_ALIGNMENT_CENTER,size.x,int(15*unit()),Color(MARK,0.35))

func unit() -> float:return size.y/1000.0

# --- Prisms and the hull around them -----------------------------------------
func driver_windows() -> Array[Rect2]:
 var w:=size.x;var h:=size.y
 return [Rect2(w*0.075,h*0.205,w*0.24,h*0.17),Rect2(w*0.345,h*0.185,w*0.31,h*0.21),Rect2(w*0.685,h*0.205,w*0.24,h*0.17)]

func commander_windows() -> Array[Rect2]:
 var w:=size.x;var h:=size.y
 return [Rect2(w*0.10,h*0.255,w*0.22,h*0.13),Rect2(w*0.39,h*0.21,w*0.22,h*0.22),Rect2(w*0.68,h*0.255,w*0.22,h*0.13)]

# Steel everywhere but the windows, column by column between their edges.
func interior(windows: Array[Rect2]) -> void:
 var cuts: Array[float]=[0.0,size.x]
 for r in windows:cuts.append(r.position.x);cuts.append(r.end.x)
 cuts.sort()
 for i in range(cuts.size()-1):
  var x0:=cuts[i];var x1:=cuts[i+1]
  if x1-x0<0.5:continue
  var hole:=Rect2()
  for r in windows:
   if (x0+x1)*0.5>r.position.x and (x0+x1)*0.5<r.end.x:hole=r
  if hole.has_area():
   draw_rect(Rect2(x0,0,x1-x0,hole.position.y),INTERIOR)
   draw_rect(Rect2(x0,hole.end.y,x1-x0,size.y-hole.end.y),INTERIOR)
  else:draw_rect(Rect2(x0,0,x1-x0,size.y),INTERIOR)
 # Daylight from the prisms on the steel below them, darkness above.
 var top:=INF;var bottom:=0.0
 for r in windows:top=minf(top,r.position.y);bottom=maxf(bottom,r.end.y)
 var u:=unit()
 for k in range(6):
  draw_rect(Rect2(0,top-40*u-k*18*u,size.x,18*u),Color(0,0,0,0.05*k))
  draw_rect(Rect2(0,bottom+16*u+k*22*u,size.x,22*u),Color(0.75,0.8,0.65,0.035*(6-k)))
 # Welds and bolts of the hatch frame.
 for r in windows:
  for corner in [r.position+Vector2(-18,-18)*u,Vector2(r.end.x+18*u,r.position.y-18*u),Vector2(r.position.x-18*u,r.end.y+18*u),r.end+Vector2(18,18)*u]:
   draw_circle(corner,5*u,Color("3b4136"));draw_circle(corner-Vector2(1,1)*u,2.2*u,Color("4b5244"))

func prism(r: Rect2, eyepiece: bool=false) -> void:
 var u:=unit()
 # A greenish tint of the glass, darker at the edges, the prism's top shade.
 draw_rect(r,Color(0.28,0.46,0.36,0.10))
 for k in range(5):draw_rect(r.grow(-k*4*u),Color(0,0,0,0.16-0.03*k),false,4*u)
 draw_rect(Rect2(r.position,Vector2(r.size.x,r.size.y*0.14)),Color(0,0,0,0.22))
 if eyepiece:
  # Rubber eyecups of the binocular device: rounded, thick.
  draw_rect(r.grow(10*u),RUBBER,false,18*u)
  for corner in [r.position,Vector2(r.end.x,r.position.y),Vector2(r.position.x,r.end.y),r.end]:fillet(corner,r,26*u)
 else:
  draw_rect(r.grow(7*u),Color("101210"),false,12*u)
  draw_rect(r.grow(1.5*u),Color(0.55,0.6,0.5,0.35),false,2*u)

# A rounded corner of the eyecup: rubber over the corner of the window.
func fillet(corner: Vector2, r: Rect2, radius: float) -> void:
 var inward:=Vector2(1.0 if corner.x<=r.position.x+1.0 else -1.0,1.0 if corner.y<=r.position.y+1.0 else -1.0)
 var center:=corner+inward*radius
 var a0:=atan2(0.0,-inward.x);var a1:=atan2(-inward.y,0.0)
 var points:=PackedVector2Array([corner])
 for k in range(9):
  var a:=lerp_angle(a0,a1,k/8.0)
  points.append(center+Vector2(cos(a),sin(a))*radius)
 draw_colored_polygon(points,RUBBER)

func brow_pad(windows: Array[Rect2]) -> void:
 var u:=unit()
 var left:=windows[0].position.x-30*u;var right:=windows[windows.size()-1].end.x+30*u
 var y:=windows[1].position.y-62*u;var h:=34*u
 draw_rect(Rect2(left,y,right-left,h),RUBBER)
 draw_circle(Vector2(left,y+h*0.5),h*0.5,RUBBER);draw_circle(Vector2(right,y+h*0.5),h*0.5,RUBBER)
 draw_line(Vector2(left,y+4*u),Vector2(right,y+4*u),Color(1,1,1,0.07),2*u)
 for k in range(1,12):draw_line(Vector2(lerpf(left,right,k/12.0),y+6*u),Vector2(lerpf(left,right,k/12.0),y+h-6*u),Color(0,0,0,0.35),1.5*u)

# The yoke of the steering mechanism: a bar with two grips on a column,
# turned as far as it is deflected.
func yoke() -> void:
 var u:=unit()
 var c:=Vector2(size.x*0.56,size.y*0.80)
 draw_rect(Rect2(c.x-16*u,c.y,32*u,size.y-c.y),Color("1a1d17"))
 var half:=size.x*0.105
 var turn:=vehicle().yoke*0.55
 var along:=Vector2(cos(turn),sin(turn))
 draw_line(c-along*half,c+along*half,STEEL,26*u)
 draw_line(c-along*half+Vector2(0,-6*u),c+along*half+Vector2(0,-6*u),Color(1,1,1,0.06),4*u)
 for side in [-1.0,1.0]:
  var end: Vector2=c+along*half*side
  draw_line(end,end+along*side*58*u,RUBBER,34*u)
 draw_circle(c,30*u,Color("23271f"));draw_circle(c,14*u,Color("3a3f34"))

# The gear gate under the driver's right hand: reverse and first on the
# left, second and third in the middle, fourth and fifth on the right.
func gear_gate() -> void:
 var u:=unit()
 var plate:=Rect2(size.x*0.775,size.y*0.70,size.x*0.15,size.y*0.20)
 draw_rect(plate,PLATE);draw_rect(plate,PLATE_EDGE,false,3*u)
 var font:=ThemeDB.fallback_font
 var at:=func(column: float, row: float) -> Vector2:return plate.position+Vector2(plate.size.x*(0.22+0.28*column),plate.size.y*(0.2+0.3*row))
 for column in range(3):draw_line(at.call(column,0),at.call(column,2),Color("0d0e0c"),14*u)
 draw_line(at.call(0,1),at.call(2,1),Color("0d0e0c"),14*u)
 var names:=[["ЗХ","1"],["2","3"],["4","5"]]
 for column in range(3):
  for row in range(2):
   var p: Vector2=at.call(column,row*2)
   draw_string(font,p+Vector2(14*u,(row*2-1)*-4*u+8*u),names[column][row],HORIZONTAL_ALIGNMENT_LEFT,-1,int(26*u),MARK)
 var top: Vector2=at.call(knob.x,knob.y)
 draw_line(Vector2(plate.get_center().x,plate.end.y+60*u),top,Color("2c2e2a"),11*u)
 draw_circle(top,26*u,Color("8a8a80"));draw_circle(top,23*u,Color("262622"));draw_circle(top-Vector2(7,7)*u,8*u,Color(1,1,1,0.22))
 var pedal:=vehicle().clutch_engagement()
 var state:="ФРИКЦІОН ВИЖАТО" if pedal<0.05 else ("ФРИКЦІОН ПРОБУКСОВУЄ" if pedal<0.95 else "")
 if state!="":draw_string(font,Vector2(plate.position.x,plate.position.y-14*u),state,HORIZONTAL_ALIGNMENT_CENTER,plate.size.x,int(18*u),AMBER)

func notice() -> void:
 var v:=vehicle()
 if v.notice_left<=0.0 or v.notice=="":return
 var u:=unit()
 var font:=ThemeDB.fallback_font
 var y:=size.y*0.49
 draw_string(font,Vector2(1,y+1),v.notice,HORIZONTAL_ALIGNMENT_CENTER,size.x,int(24*u),Color(0,0,0,0.8))
 draw_string(font,Vector2(0,y),v.notice,HORIZONTAL_ALIGNMENT_CENTER,size.x,int(24*u),AMBER)

# --- The commander's TKN-3B at ×5 -------------------------------------------
func scope() -> void:
 var c:=size*0.5
 var r:=size.y*0.43
 draw_arc(c,r+size.x,0,TAU,96,Color.BLACK,size.x*2.0)
 draw_arc(c,r,0,TAU,96,Color("0a0b0a"),6)
 var line:=Color(0.05,0.07,0.05,0.85)
 # Chevron and the scale of thousandths across the field.
 draw_line(c,c+Vector2(-18,22),line,2);draw_line(c,c+Vector2(18,22),line,2)
 for k in range(-8,9):
  if k==0:continue
  var x:=c.x+k*r*0.1
  draw_line(Vector2(x,c.y),Vector2(x,c.y+(12 if k%2==0 else 6)),line,2)
 draw_line(Vector2(c.x-r*0.85,c.y),Vector2(c.x-r*0.12,c.y),line,2)
 draw_line(Vector2(c.x+r*0.12,c.y),Vector2(c.x+r*0.85,c.y),line,2)
 draw_line(Vector2(c.x,c.y+r*0.12),Vector2(c.x,c.y+r*0.6),line,2)
 var font:=ThemeDB.fallback_font
 draw_string(font,c+Vector2(r*0.62,r*0.86),"ТКН-3Б ×5",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(MARK,0.55))

# --- The driver's instrument panel --------------------------------------------
func panel(amount: float) -> void:
 var hidden_low:=view()=="driver_open"
 # At the driver's left knee, above the line of the key hints.
 var small_k:=minf(size.x*0.40/PANEL.x,size.y*0.42/PANEL.y)
 var small_at:=Vector2(size.x*0.012,size.y*0.885-PANEL.y*small_k)
 if hidden_low:small_at=Vector2(size.x*0.06,size.y*1.02)
 var big_k:=minf(size.x*0.88/PANEL.x,size.y*0.84/PANEL.y)
 var big_at:=(size-PANEL*big_k)*0.5+Vector2(0,size.y*0.04)
 var t:=ease(large,-2.0)
 if large>0.0:draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,0.5*t))
 var k:=lerpf(small_k,big_k,t)
 var at:=small_at.lerp(big_at,t)
 draw_set_transform(at,0.0,Vector2(k,k))
 draw_plate()
 draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func draw_plate() -> void:
 var v:=vehicle()
 var font:=ThemeDB.fallback_font
 draw_rect(Rect2(Vector2.ZERO,PANEL),PLATE)
 draw_rect(Rect2(Vector2.ZERO,PANEL),PLATE_EDGE,false,8)
 for corner in [Vector2(18,18),Vector2(PANEL.x-18,18),Vector2(18,PANEL.y-18),PANEL-Vector2(18,18)]:
  draw_circle(corner,7,Color("2a2f25"));draw_line(corner-Vector2(4,4),corner+Vector2(4,4),Color("1a1d17"),2)
 var power:=v.master
 # Tachometer with the engine-hour counter, speedometer with the odometer.
 dial(Vector2(150,152),112,v.steady_rpm()/100.0 if power or v.running else 0.0,0,35,1,5,"ТАХОМЕТР · ОБ/ХВ ×100",26)
 counter(Vector2(150,215),("%06d" % floori(v.engine_hours*10.0)))
 dial(Vector2(420,152),112,absf(v.speed())*3.6,0,80,2,10,"СПІДОМЕТР · КМ/ГОД")
 counter(Vector2(420,215),("%06d" % floori(v.odometer*10.0)))
 compass(Vector2(690,152),106)
 plate_label(Vector2(690,152+106+30),"ГІРОНАПІВКОМПАС ГПК-59")
 # The small gauges along the bottom row, each with its plate below.
 var row:=370.0
 dial(Vector2(95,row),56,v.coolant if power else 40.0,40,120,5,20,"ВОДА °C",105)
 dial(Vector2(265,row),56,v.oil_temp if power else 40.0,40,120,5,20,"МАСЛО °C",110)
 dial(Vector2(435,row),56,v.oil_pressure if power else 0.0,0,10,0.5,2,"ТИСК МАСЛА",INF,1.0)
 dial(Vector2(605,row),56,v.volts,0,30,1,10,"ВОЛЬТМЕТР")
 dial(Vector2(775,row),56,v.air_bottle,0,200,10,50,"ПОВІТРЯ",INF,40.0)
 clock(Vector2(945,row),56)
 plate_label(Vector2(945,row+56+30),"ГОДИННИК АЧС-1")
 # Warning lamps light from the batteries.
 var lamps:=[[v.master,"МАСА",GREEN],[v.starter,"СТАРТЕР",AMBER],[v.oil_pressure<1.0,"ТИСК МАСЛА",RED],[v.coolant>105.0,"ПЕРЕГРІВ",RED],[v.parking,"СТОЯНКОВЕ",AMBER],[v.radio_on,"ПРИЙМАЧ",GREEN]]
 for i in range(lamps.size()):
  var entry: Array=lamps[i]
  lamp(Vector2(880,62+i*38),power and bool(entry[0]),str(entry[1]),entry[2])

# A round gauge: 270° scale from the lower left, numbers on the major marks.
# `red_high` paints the scale red above a value, `red_low` below one.
func dial(c: Vector2, r: float, value: float, low: float, high: float, step: float, label_step: float, title: String, red_high: float=INF, red_low: float=-INF) -> void:
 var font:=ThemeDB.fallback_font
 draw_circle(c,r+8,BEZEL);draw_circle(c,r+4,Color("2a2c27"));draw_circle(c,r,FACE)
 if red_high<high:draw_arc(c,r*0.9,deg_to_rad(135+270*(red_high-low)/(high-low)),deg_to_rad(405),16,RED,r*0.07)
 if red_low>low:draw_arc(c,r*0.9,deg_to_rad(135),deg_to_rad(135+270*(red_low-low)/(high-low)),16,RED,r*0.07)
 var count:=roundi((high-low)/step)
 var number_size:=int(r*0.19)
 for k in range(count+1):
  var mark:=low+step*k
  var a:=deg_to_rad(135+270.0*k/count)
  var dir:=Vector2(cos(a),sin(a))
  var major:=absf(mark/label_step-roundf(mark/label_step))<0.001
  draw_line(c+dir*r*(0.78 if major else 0.88),c+dir*r*0.97,MARK,r*0.035 if major else r*0.02)
  if major:
   var label:=str(roundi(mark))
   var w:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size).x
   draw_string(font,c+dir*r*0.6+Vector2(-w*0.5,number_size*0.36),label,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size,MARK)
 plate_label(c+Vector2(0,r+30),title)
 var a:=deg_to_rad(135+270*clampf((value-low)/(high-low),0,1))
 var dir:=Vector2(cos(a),sin(a))
 draw_line(c-dir*r*0.16,c+dir*r*0.86,NEEDLE,r*0.04)
 draw_circle(c,r*0.1,Color("3a3c36"))

# White letters on the plate under a gauge.
func plate_label(c: Vector2, text: String) -> void:
 draw_string(ThemeDB.fallback_font,Vector2(c.x-150,c.y),text,HORIZONTAL_ALIGNMENT_CENTER,300,16,Color(MARK,0.8))

# A drum counter in the lower gap of the dial; the last drum is white.
func counter(c: Vector2, digits: String) -> void:
 var font:=ThemeDB.fallback_font
 var cell:=13.0
 var w:=cell*digits.length()+6
 draw_rect(Rect2(c.x-w*0.5,c.y-13,w,26),Color("050505"))
 for i in range(digits.length()):
  var last:=i==digits.length()-1
  var x:=c.x-w*0.5+3+i*cell
  if last:draw_rect(Rect2(x,c.y-11,cell-1,22),MARK)
  draw_string(font,Vector2(x,c.y+7),digits[i],HORIZONTAL_ALIGNMENT_CENTER,cell,19,FACE if last else MARK)

# The GPK-59: a card turning under a fixed index, the course in degrees.
func compass(c: Vector2, r: float) -> void:
 var font:=ThemeDB.fallback_font
 draw_circle(c,r+8,BEZEL);draw_circle(c,r+4,Color("2a2c27"));draw_circle(c,r,FACE)
 var forward:=-vehicle().global_basis.z
 var course:=fposmod(rad_to_deg(atan2(forward.x,-forward.z)),360.0)
 if not vehicle().master:course=0.0
 for k in range(72):
  var bearing:=k*5.0
  var a:=deg_to_rad(bearing-course-90.0)
  var dir:=Vector2(cos(a),sin(a))
  var major:=k%6==0
  draw_line(c+dir*r*(0.8 if major else (0.86 if k%2==0 else 0.9)),c+dir*r*0.97,MARK,3.0 if major else 1.5)
  if major:
   var label:=str(roundi(bearing/10.0)) if k!=0 else "П"
   var w:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
   draw_string(font,c+dir*r*0.64+Vector2(-w*0.5,8),label,HORIZONTAL_ALIGNMENT_LEFT,-1,21,RED if k==0 else MARK)
 draw_colored_polygon(PackedVector2Array([c+Vector2(0,-r*0.78),c+Vector2(-10,-r-6),c+Vector2(10,-r-6)]),AMBER)
 # The middle under glass: the course and the name of the device.
 draw_circle(c,r*0.44,Color("161814"))
 draw_arc(c,r*0.44,0,TAU,48,BEZEL,2)
 draw_string(font,c+Vector2(-r,-r*0.08),"ГПК-59",HORIZONTAL_ALIGNMENT_CENTER,r*2,15,Color(MARK,0.7))
 draw_string(font,c+Vector2(-r,r*0.24),"%03d°" % roundi(course),HORIZONTAL_ALIGNMENT_CENTER,r*2,28,AMBER)

# The clock: the operation began at 05:40.
func clock(c: Vector2, r: float) -> void:
 var font:=ThemeDB.fallback_font
 draw_circle(c,r+8,BEZEL);draw_circle(c,r+4,Color("2a2c27"));draw_circle(c,r,FACE)
 for k in range(12):
  var a:=TAU*k/12.0-PI*0.5
  draw_line(c+Vector2(cos(a),sin(a))*r*0.8,c+Vector2(cos(a),sin(a))*r*0.95,MARK,3 if k%3==0 else 1.5)
 var minutes:=5*60+40+float(game.elapsed)/60.0
 var hour:=TAU*fmod(minutes/60.0,12.0)/12.0-PI*0.5
 var minute:=TAU*fmod(minutes,60.0)/60.0-PI*0.5
 draw_line(c,c+Vector2(cos(hour),sin(hour))*r*0.5,NEEDLE,4)
 draw_line(c,c+Vector2(cos(minute),sin(minute))*r*0.78,NEEDLE,2.5)
 draw_circle(c,4,Color("3a3c36"))

func lamp(at: Vector2, on: bool, title: String, color: Color) -> void:
 if on:draw_circle(at,19,Color(color,0.3))
 draw_circle(at,14,Color("101110"))
 draw_circle(at,11,color.lightened(0.15) if on else color.darkened(0.78))
 draw_string(ThemeDB.fallback_font,at+Vector2(22,6),title,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(MARK,0.85))
