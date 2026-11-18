class_name MenuItem
extends Button

# Large entry of the main and pause menus: number, title, a line of detail
# when it is the active one, an accent bar and a short slide.
var number := ""
var title := ""
var detail := ""
var badge := ""
var title_size := 34
var shift := 0.0
var glow := 0.0
var game: Node3D
var quiet := false

func configure(owner_game: Node3D, index: String, heading: String, line: String, on_press: Callable, size_px: int=34) -> MenuItem:
 game=owner_game;number=index;title=heading;detail=line;title_size=size_px
 text=""
 flat=true
 focus_mode=Control.FOCUS_ALL
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 custom_minimum_size=Vector2(0,title_size+26)
 add_theme_stylebox_override("focus",StyleBoxEmpty.new())
 mouse_entered.connect(func():if not has_focus():grab_focus())
 focus_entered.connect(func():if not quiet and is_visible_in_tree() and is_instance_valid(game):game.sound("click",-30))
 pressed.connect(func():
  if is_instance_valid(game):game.sound("click",-12)
  on_press.call())
 return self

# Focus set by the menu itself (a screen opens, the game pauses) makes no
# click: the click is for the player's own navigation, and its random pitch
# would also shift the shared random sequence of seeded scenarios.
func focus_quietly() -> void:
 quiet=true
 grab_focus()
 quiet=false

func active() -> bool:return has_focus() or is_hovered()

func _process(delta: float) -> void:
 var target:=1.0 if active() else 0.0
 var next:=move_toward(glow,target,delta*7.0)
 if next!=glow:glow=next;shift=14.0*ease(glow,0.4);queue_redraw()

func _draw() -> void:
 var h:=size.y
 if glow>0.0:
  var band:=PackedVector2Array([Vector2(0,0),Vector2(size.x,0),Vector2(size.x,h),Vector2(0,h)])
  var c:=Color(UiKit.ACCENT,0.13*glow);var clear:=Color(UiKit.ACCENT,0.0)
  draw_polygon(band,PackedColorArray([c,clear,clear,c]))
  draw_rect(Rect2(0,0,4,h),Color(UiKit.ACCENT,glow))
 var head:=UiKit.font("head")
 var display:=UiKit.font("display")
 var x:=22.0+shift
 var baseline:=4.0+title_size*0.92
 if number!="":
  draw_string(head,Vector2(x,baseline-title_size*0.55),number,HORIZONTAL_ALIGNMENT_LEFT,-1,13,UiKit.ACCENT if glow>0.5 else UiKit.FAINT)
  x+=34.0
 var color:=UiKit.INK if not disabled else UiKit.FAINT
 color.a=lerpf(0.66,1.0,glow) if not disabled else 0.6
 draw_string(display,Vector2(x,baseline),title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size,color)
 if badge!="":
  var w:=display.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x
  var at:=Vector2(x+w+14,baseline-title_size*0.62)
  var bw:=head.get_string_size(badge,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+12
  draw_rect(Rect2(at,Vector2(bw,17)),UiKit.ACCENT)
  draw_string(head,at+Vector2(6,13),badge,HORIZONTAL_ALIGNMENT_LEFT,-1,11,UiKit.DARK_TEXT)
 if detail!="" and glow>0.0:
  draw_string(UiKit.font("body"),Vector2(x,baseline+18),detail,HORIZONTAL_ALIGNMENT_LEFT,size.x-x-10,14,Color(UiKit.MUTED,glow))
