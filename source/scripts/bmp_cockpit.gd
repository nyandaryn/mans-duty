class_name BmpCockpit
extends Control

# What is drawn over the view from inside the BMP-2 (the compartments
# themselves are 3D: BmpInterior). A dot in the middle of the view and the
# name of the device it rests on; the right button on the instrument panel,
# or anywhere with the hatch open, slides the panel up large at the bottom
# left of the screen, leaving the view above it free: tachometer with the
# engine-hour counter, speedometer with the odometer, the GPK-59 gyro
# semi-compass, coolant and oil temperatures, oil pressure, the voltmeter, the
# gauge of the air-start bottle, the clock and the warning lamps. With
# `plate_only` it draws just the panel into the texture of the 3D one.
const PANEL := Vector2(1100,480)
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
var plate_only := false
var source: BmpVehicle

func setup(owner_game: Node3D, owner_command: Node) -> void:
 game=owner_game;command=owner_command
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 hide()

func vehicle() -> BmpVehicle:return source if source!=null else command.vehicle

func view() -> String:
 if command==null or not command.active() or not game.running or command.seat=="":return ""
 if command.seat=="driver":return "driver_open" if vehicle().hatch_open else "driver"
 if command.seat=="troop" and not command.head_out:return "troop"
 return ""

func aiming() -> bool:
 return Input.is_action_pressed("aim") and not game.commands_open and not game.paused and not game.inventory_open

# What the right button is doing now (BmpCommand decides on the press).
func instruments_shown() -> bool:return command.seat=="driver" and command.press=="panel"

func _process(delta: float) -> void:
 # The plate in the cabin is redrawn by BmpInterior when its texture renders.
 if plate_only:return
 var mode:=view()
 visible=mode!=""
 if not visible:large=0.0;return
 large=move_toward(large,1.0 if instruments_shown() else 0.0,delta*6.0)
 queue_redraw()

func _draw() -> void:
 if plate_only:draw_plate();return
 match view():
  "driver":
   if large<0.05:sight()
   notice()
   clutch()
   if large>0.0:panel(large)
  "driver_open":
   if large>0.0:panel(large)
  "troop":
   if not command.exiting():sight()
   notice()

func unit() -> float:return size.y/1000.0

# The dot in the middle of the view and what it rests on.
func sight() -> void:
 if command.lean>0.02:return
 var u:=unit()
 var c:=size*0.5
 draw_circle(c,3.6*u,Color(0,0,0,0.55));draw_circle(c,2.2*u,Color(1,1,1,0.75))
 var target: Dictionary=command.target
 if target.is_empty():return
 var action: String={"prism":"ПКМ — ДИВИТИСЯ","panel":"ПКМ — ВЕЛИКИМ ПЛАНОМ"}.get(target.kind,"")
 var text:="%s  ·  %s" % [target.title,action]
 var font:=ThemeDB.fallback_font
 var height:=int(17*u)
 draw_string(font,Vector2(1,c.y+38*u+1),text,HORIZONTAL_ALIGNMENT_CENTER,size.x,height,Color(0,0,0,0.8))
 draw_string(font,Vector2(0,c.y+38*u),text,HORIZONTAL_ALIGNMENT_CENTER,size.x,height,Color(MARK,0.9))

func notice() -> void:
 var v:=vehicle()
 if v.notice_left<=0.0 or v.notice=="":return
 var u:=unit()
 var font:=ThemeDB.fallback_font
 # Under the window of a prism even with the face at the eyepiece.
 var y:=size.y*0.81
 draw_string(font,Vector2(1,y+1),v.notice,HORIZONTAL_ALIGNMENT_CENTER,size.x,int(24*u),Color(0,0,0,0.8))
 draw_string(font,Vector2(0,y),v.notice,HORIZONTAL_ALIGNMENT_CENTER,size.x,int(24*u),AMBER)

# The main clutch held out or slipping: the driver feels it in his foot.
func clutch() -> void:
 var pedal:=vehicle().clutch_engagement()
 var state:="ФРИКЦІОН ВИЖАТО" if pedal<0.05 else ("ФРИКЦІОН ПРОБУКСОВУЄ" if pedal<0.95 else "")
 if state=="":return
 var u:=unit()
 draw_string(ThemeDB.fallback_font,Vector2(0,size.y*0.885),state,HORIZONTAL_ALIGNMENT_CENTER,size.x,int(18*u),AMBER)

# --- The driver's instrument panel --------------------------------------------
# Large, it slides up from the bottom edge and stays in the lower part of the
# screen, at the left where the panel is: the view above stays open, the
# course card at the bottom right stays clear.
func panel_rect() -> Rect2:
 var k:=minf(size.x*0.56/PANEL.x,size.y*0.42/PANEL.y)
 var w:=PANEL*k
 return Rect2(Vector2(size.x*0.02,size.y*0.905-w.y),w)

func panel(amount: float) -> void:
 var rect:=panel_rect()
 var t:=ease(amount,-2.0)
 var at:=Vector2(rect.position.x,lerpf(size.y+8.0,rect.position.y,t))
 var k:=rect.size.x/PANEL.x
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
