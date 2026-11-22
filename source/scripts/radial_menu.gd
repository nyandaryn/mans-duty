extends Control

# The ring of choices for a key that takes something out of the pack when
# the pack holds more than one kind of it (launchers, RPG-7 rounds, drones).
# A tap acts at once with the kind chosen last; held, the ring opens round
# the middle of the screen. The mouse leans the pointer into a sector, or 1…n
# picks it; letting the key go or the left button takes it, the right button,
# Esc or the cancel key closes it with nothing taken. The game goes on
# meanwhile: the legs walk, only the look and the weapon wait.

const HOLD := 0.25
const OUTER := 168.0
const INNER := 58.0
const DEADZONE := 26.0
# Keys that keep moving the soldier while the ring is up.
const PASS := ["forward","back","left","right","sprint","crouch","prone","jump","lean_left","lean_right"]

var operator: Node3D
var key := 0
var group := ""
var title := ""
var options: Array = []
var selected := -1
var pending := false
var hold_left := 0.0
var cursor := Vector2.ZERO
var picked: Callable
var tapped: Callable
# The mouse button that closed the ring stays down a moment: the rifle must
# not fire or come to the eye on that press.
var latch := MOUSE_BUTTON_NONE

func setup(owner_operator: Node3D) -> void:
 operator=owner_operator
 name="RadialMenu"
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 visible=false

func is_open() -> bool:return visible

# Waiting for the key to come up (a tap) or to be held long enough (the ring).
func engaged() -> bool:return visible or pending

# The fire and aim buttons are not the soldier's while the ring is up.
func blocks_weapon() -> bool:return visible or latch!=MOUSE_BUTTON_NONE

func arm(on_key: int, which: String, heading: String, choices: Array, initial: String, on_pick: Callable, on_tap: Callable) -> void:
 key=on_key;group=which;title=heading;options=choices;picked=on_pick;tapped=on_tap
 selected=-1
 for i in range(options.size()):
  if str(options[i].id)==initial and bool(options[i].get("enabled",true)):selected=i
 if selected<0:selected=first_enabled()
 pending=true;hold_left=HOLD;cursor=Vector2.ZERO;visible=false

func first_enabled() -> int:
 for i in range(options.size()):
  if bool(options[i].get("enabled",true)):return i
 return -1

func open() -> void:
 pending=false;visible=true;cursor=Vector2.ZERO
 queue_redraw()

func close() -> void:
 pending=false;visible=false;key=0
 picked=Callable();tapped=Callable()

# The key came up: before the hold the tap acts; with the ring open the
# sector under the pointer is taken.
func release(code: int) -> bool:
 if code!=key or key==0:return false
 if pending:
  var action:=tapped
  close()
  if action.is_valid():action.call()
  return true
 if visible:
  confirm()
  return true
 return false

func confirm() -> void:
 if selected<0 or selected>=options.size() or not bool(options[selected].get("enabled",true)):
  close();return
 var id:=str(options[selected].id)
 var action:=picked
 var which:=group
 close()
 if action.is_valid():action.call(which,id)

func choose(index: int) -> void:
 if index<0 or index>=options.size():return
 selected=index
 queue_redraw()

# Sector under a direction from the middle: the first at the top, clockwise.
func sector(direction: Vector2) -> int:
 if options.is_empty():return -1
 var step:=TAU/options.size()
 return posmod(roundi((direction.angle()+PI*0.5)/step),options.size())

func sector_angle(index: int) -> float:return -PI*0.5+index*TAU/maxi(1,options.size())

func _process(delta: float) -> void:
 if latch!=MOUSE_BUTTON_NONE and not Input.is_mouse_button_pressed(latch):latch=MOUSE_BUTTON_NONE
 if not engaged():return
 var game: Node3D=operator.game if operator!=null else null
 if game==null or not game.running or game.paused or game.commands_open or game.inventory_open:
  close();return
 if pending:
  hold_left-=delta
  if hold_left<=0:open()

func _input(event: InputEvent) -> void:
 if not engaged():return
 if event is InputEventKey and not event.pressed and event.physical_keycode==key:
  release(key)
  get_viewport().set_input_as_handled()
  return
 if not visible:return
 if event is InputEventMouseMotion:
  cursor=(cursor+event.relative).limit_length(OUTER)
  if cursor.length()>DEADZONE:choose(sector(cursor))
  queue_redraw()
  get_viewport().set_input_as_handled()
  return
 if event is InputEventMouseButton:
  if event.pressed:
   match event.button_index:
    MOUSE_BUTTON_LEFT:latch=MOUSE_BUTTON_LEFT;confirm()
    MOUSE_BUTTON_RIGHT:latch=MOUSE_BUTTON_RIGHT;close()
    MOUSE_BUTTON_XBUTTON1:close()
    MOUSE_BUTTON_WHEEL_UP:choose(posmod(selected-1,options.size()))
    MOUSE_BUTTON_WHEEL_DOWN:choose(posmod(selected+1,options.size()))
  get_viewport().set_input_as_handled()
  return
 if event is InputEventKey and event.pressed:
  var code: int=event.physical_keycode
  if code==KEY_ESCAPE or code==KEY_QUOTELEFT:
   close()
  elif code>=KEY_1 and code<KEY_1+options.size():
   choose(code-KEY_1);confirm()
  else:
   for action in PASS:
    if event.is_action(action):return
  get_viewport().set_input_as_handled()

func _draw() -> void:
 if not visible:return
 var font:=ThemeDB.fallback_font
 var center:=get_viewport_rect().size*0.5
 var count:=maxi(1,options.size())
 var step:=TAU/count
 draw_circle(center,OUTER+24,Color(0.02,0.035,0.03,0.55))
 for i in range(options.size()):
  var option: Dictionary=options[i]
  var enabled:=bool(option.get("enabled",true))
  var mid:=sector_angle(i)
  var points:=PackedVector2Array()
  var gap:=0.025 if count>1 else 0.0
  for k in range(17):
   var a:=mid-step*0.5+gap+(step-2*gap)*k/16.0
   points.append(center+Vector2(cos(a),sin(a))*OUTER)
  for k in range(16,-1,-1):
   var a:=mid-step*0.5+gap+(step-2*gap)*k/16.0
   points.append(center+Vector2(cos(a),sin(a))*INNER)
  var fill:=Color(0.10,0.13,0.10,0.88)
  if i==selected:fill=Color(0.50,0.44,0.26,0.92) if enabled else Color(0.30,0.24,0.20,0.9)
  elif not enabled:fill=Color(0.07,0.07,0.07,0.8)
  draw_colored_polygon(points,fill)
  var text_color:=Color("f0e7cf") if enabled else Color(0.55,0.55,0.5)
  var at:=center+Vector2(cos(mid),sin(mid))*(INNER+OUTER)*0.5
  var lines:=[str(option.get("title","")),"× %d" % int(option.count) if option.has("count") else "",str(option.get("detail",""))]
  var y:=at.y-20
  for n in range(lines.size()):
   var line:String=lines[n]
   if line=="":continue
   var font_size:=16 if n==0 else 13
   var width:=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
   draw_string(font,Vector2(at.x-width*0.5,y+font_size),line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,text_color)
   y+=font_size+4
  var number:="%d" % (i+1)
  var corner:=center+Vector2(cos(mid),sin(mid))*(OUTER+13)
  draw_string(font,corner+Vector2(-4,5),number,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.85,0.78,0.55,0.9))
 draw_circle(center,INNER-6,Color(0.03,0.05,0.04,0.92))
 var heading_width:=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
 draw_string(font,center+Vector2(-heading_width*0.5,5),title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c8b17a"))
 if cursor.length()>DEADZONE:
  draw_line(center,center+cursor.limit_length(INNER-8),Color(0.9,0.82,0.55,0.9),2)
 var hint:="МИША / 1–%d — ВИБІР · ВІДПУСТИ КЛАВІШУ АБО ЛКМ — ВЗЯТИ · ПКМ / ESC / ~ — ЗАКРИТИ" % options.size()
 var hint_width:=font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
 draw_string(font,Vector2(center.x-hint_width*0.5,center.y+OUTER+46),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f0e7cf"))
