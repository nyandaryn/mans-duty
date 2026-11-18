class_name UiKit
extends RefCounted

# One visual language for the front end and the in-game overlays: condensed
# Noto Sans (SIL OFL 1.1) for titles and controls, dark translucent panels
# over the live scene, one amber accent.
const INK := Color("e9eadf")
const SOFT := Color("c9cdbf")
const MUTED := Color("969f90")
const FAINT := Color("5f685d")
const ACCENT := Color("e2b55c")
const ACCENT_DIM := Color("9b7b3c")
const DANGER := Color("e0644f")
const GOOD := Color("93cf6c")
const PANEL := Color(0.035,0.05,0.043,0.86)
const SHEET := Color(0.024,0.034,0.03,0.80)
const LINE := Color(0.86,0.9,0.82,0.13)
const DARK_TEXT := Color("15130d")
const FONT_FILES := {"display":"res://assets/fonts/NotoSans-ExtraCondensedBlack.ttf","head":"res://assets/fonts/NotoSans-CondensedSemiBold.ttf","body":"res://assets/fonts/NotoSans-Regular.ttf"}
static var fonts: Dictionary={}
static var cached_theme: Theme

# Arrows, circles and other symbols fall back to the engine font.
static func font(kind: String) -> Font:
 if fonts.has(kind):return fonts[kind]
 var variation:=FontVariation.new()
 variation.base_font=load(FONT_FILES[kind])
 var fallback: Array[Font]=[ThemeDB.fallback_font]
 variation.fallbacks=fallback
 if kind=="display":variation.spacing_glyph=1
 fonts[kind]=variation
 return variation

static func flat(color: Color, border: Color=Color(0,0,0,0), width: int=0, left: int=-1) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new()
 style.bg_color=color
 style.border_color=border
 style.set_border_width_all(width)
 if left>=0:style.border_width_left=left
 style.content_margin_left=16;style.content_margin_right=16
 style.content_margin_top=10;style.content_margin_bottom=10
 return style

static func theme() -> Theme:
 if cached_theme!=null:return cached_theme
 var t:=Theme.new()
 t.default_font=font("body")
 t.default_font_size=16
 t.set_color("font_color","Label",INK)
 for kind in ["Button","OptionButton","CheckButton","CheckBox","MenuButton"]:
  t.set_font("font",kind,font("head"))
  t.set_font_size("font_size",kind,17)
  t.set_color("font_color",kind,SOFT)
  t.set_color("font_hover_color",kind,INK)
  t.set_color("font_focus_color",kind,INK)
  t.set_color("font_pressed_color",kind,INK)
  t.set_color("font_hover_pressed_color",kind,INK)
  t.set_color("font_disabled_color",kind,FAINT)
 for kind in ["Button","OptionButton"]:
  t.set_stylebox("normal",kind,flat(Color(1,1,1,0.035),LINE,1))
  t.set_stylebox("hover",kind,flat(Color(ACCENT,0.13),ACCENT,1,3))
  t.set_stylebox("pressed",kind,flat(Color(ACCENT,0.24),ACCENT,1,3))
  t.set_stylebox("hover_pressed",kind,flat(Color(ACCENT,0.28),ACCENT,1,3))
  t.set_stylebox("focus",kind,flat(Color(0,0,0,0),Color(ACCENT,0.7),1))
  t.set_stylebox("disabled",kind,flat(Color(1,1,1,0.015),Color(1,1,1,0.05),1))
 t.set_stylebox("normal","CheckButton",flat(Color(0,0,0,0)))
 t.set_stylebox("hover","CheckButton",flat(Color(ACCENT,0.08)))
 t.set_stylebox("pressed","CheckButton",flat(Color(0,0,0,0)))
 t.set_stylebox("hover_pressed","CheckButton",flat(Color(ACCENT,0.08)))
 t.set_stylebox("focus","CheckButton",flat(Color(0,0,0,0),Color(ACCENT,0.6),1))
 t.set_stylebox("panel","PopupMenu",flat(Color("0d1411"),ACCENT_DIM,1))
 t.set_stylebox("hover","PopupMenu",flat(Color(ACCENT,0.2)))
 t.set_font("font","PopupMenu",font("head"))
 t.set_font_size("font_size","PopupMenu",16)
 t.set_color("font_color","PopupMenu",SOFT)
 t.set_color("font_hover_color","PopupMenu",INK)
 t.set_constant("v_separation","PopupMenu",8)
 t.set_stylebox("normal","LineEdit",flat(Color(0,0,0,0.38),LINE,1))
 t.set_stylebox("focus","LineEdit",flat(Color(0,0,0,0.38),ACCENT,1))
 t.set_color("font_color","LineEdit",INK)
 t.set_color("font_placeholder_color","LineEdit",FAINT)
 t.set_stylebox("panel","PanelContainer",flat(PANEL,LINE,1))
 t.set_stylebox("panel","TabContainer",flat(Color(0,0,0,0.22),LINE,1))
 t.set_stylebox("tab_selected","TabContainer",tab_style(true))
 t.set_stylebox("tab_unselected","TabContainer",tab_style(false))
 t.set_stylebox("tab_hovered","TabContainer",tab_style(false,true))
 t.set_font("font","TabContainer",font("head"))
 t.set_font_size("font_size","TabContainer",16)
 t.set_color("font_selected_color","TabContainer",INK)
 t.set_color("font_unselected_color","TabContainer",MUTED)
 t.set_color("font_hovered_color","TabContainer",INK)
 var grabber:=flat(Color(1,1,1,0.18));grabber.content_margin_left=4;grabber.content_margin_right=4
 t.set_stylebox("grabber","VScrollBar",grabber)
 t.set_stylebox("grabber_highlight","VScrollBar",flat(Color(ACCENT,0.7)))
 t.set_stylebox("grabber_pressed","VScrollBar",flat(ACCENT))
 var lane:=flat(Color(1,1,1,0.04));lane.content_margin_left=3;lane.content_margin_right=3
 t.set_stylebox("scroll","VScrollBar",lane)
 var rail:=flat(Color(1,1,1,0.12));rail.content_margin_top=2;rail.content_margin_bottom=2
 t.set_stylebox("slider","HSlider",rail)
 var filled:=flat(ACCENT);filled.content_margin_top=2;filled.content_margin_bottom=2
 t.set_stylebox("grabber_area","HSlider",filled)
 t.set_stylebox("grabber_area_highlight","HSlider",filled)
 t.set_stylebox("panel","TooltipPanel",flat(Color("0d1411"),ACCENT_DIM,1))
 t.set_font("font","TooltipLabel",font("body"))
 t.set_font_size("font_size","TooltipLabel",14)
 t.set_color("font_color","TooltipLabel",SOFT)
 cached_theme=t
 return t

static func tab_style(selected: bool, hovered: bool=false) -> StyleBoxFlat:
 var style:=flat(Color(ACCENT,0.14) if selected else Color(1,1,1,0.05 if hovered else 0.0))
 style.border_color=ACCENT if selected else Color(0,0,0,0)
 style.border_width_bottom=3
 style.content_margin_left=18;style.content_margin_right=18
 style.content_margin_top=8;style.content_margin_bottom=8
 return style

static func text(value: String, size: int=16, color: Color=INK, kind: String="body") -> Label:
 var node:=Label.new()
 node.text=value
 node.add_theme_font_override("font",font(kind))
 node.add_theme_font_size_override("font_size",size)
 node.add_theme_color_override("font_color",color)
 return node

static func wrapped(value: String, size: int=16, color: Color=SOFT) -> Label:
 var node:=text(value,size,color)
 node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 return node

# Filled accent button: the one action a screen leads to.
static func cta(title: String, callback: Callable) -> Button:
 var node:=Button.new()
 node.text=title
 node.custom_minimum_size=Vector2(0,58)
 node.alignment=HORIZONTAL_ALIGNMENT_LEFT
 node.add_theme_font_override("font",font("head"))
 node.add_theme_font_size_override("font_size",22)
 var normal:=flat(ACCENT);normal.content_margin_left=24
 var hover:=flat(ACCENT.lightened(0.14));hover.content_margin_left=28
 var pressed:=flat(ACCENT.darkened(0.18));pressed.content_margin_left=24
 node.add_theme_stylebox_override("normal",normal)
 node.add_theme_stylebox_override("hover",hover)
 node.add_theme_stylebox_override("pressed",pressed)
 node.add_theme_stylebox_override("hover_pressed",pressed)
 node.add_theme_stylebox_override("focus",flat(Color(0,0,0,0),INK,2))
 node.add_theme_stylebox_override("disabled",flat(Color(ACCENT,0.25)))
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
  node.add_theme_color_override(state,DARK_TEXT)
 node.pressed.connect(callback)
 return node

static func ghost(title: String, callback: Callable, size: int=16) -> Button:
 var node:=Button.new()
 node.text=title
 node.custom_minimum_size=Vector2(0,42)
 node.add_theme_font_size_override("font_size",size)
 node.pressed.connect(callback)
 return node

# A keyboard key drawn as a cap: [SHIFT] [E].
static func keycap(key: String) -> PanelContainer:
 var cap:=PanelContainer.new()
 var style:=flat(Color(1,1,1,0.07),Color(1,1,1,0.32),1)
 style.border_width_bottom=3
 style.content_margin_left=9;style.content_margin_right=9
 style.content_margin_top=2;style.content_margin_bottom=3
 style.corner_radius_top_left=4;style.corner_radius_top_right=4
 style.corner_radius_bottom_left=4;style.corner_radius_bottom_right=4
 cap.add_theme_stylebox_override("panel",style)
 cap.add_child(text(key,14,INK,"head"))
 return cap

static func keys_row(keys: Array, caption: String="") -> HBoxContainer:
 var row:=HBoxContainer.new()
 row.add_theme_constant_override("separation",6)
 for key in keys:
  if key=="+" or key=="/":row.add_child(text(key,14,MUTED,"head"))
  else:row.add_child(keycap(key))
 if caption!="":
  var note:=text(caption,13,MUTED)
  note.size_flags_vertical=Control.SIZE_SHRINK_CENTER
  row.add_child(note)
 return row

# Header of every front-end screen: breadcrumb, title, subtitle and the way
# back (ESC as well).
static func header(game: Node3D, parent: Control, crumb: String, title: String, subtitle: String, back: Callable) -> Button:
 var box:=VBoxContainer.new()
 box.add_theme_constant_override("separation",0)
 box.mouse_filter=Control.MOUSE_FILTER_IGNORE
 game.place(box,parent,0.035,0.035,0.72,0.2)
 box.add_child(text(crumb,13,MUTED,"head"))
 box.add_child(text(title,58,INK,"display"))
 if subtitle!="":box.add_child(text(subtitle,15,ACCENT,"head"))
 var row:=HBoxContainer.new()
 row.alignment=BoxContainer.ALIGNMENT_END
 row.add_theme_constant_override("separation",10)
 game.place(row,parent,0.62,0.045,0.965,0.1)
 var back_button:=ghost("‹   НАЗАД",back,17)
 back_button.custom_minimum_size=Vector2(170,44)
 row.add_child(back_button)
 row.add_child(keycap("ESC"))
 for child in row.get_children():
  if child is Control and child!=back_button:child.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 return back_button

# Translucent sheet over the graded menu scene.
static func sheet(game: Node3D, parent: Control, alpha: float=0.8) -> ColorRect:
 var shade:=ColorRect.new()
 shade.color=Color(SHEET,alpha)
 shade.mouse_filter=Control.MOUSE_FILTER_STOP
 game.place(shade,parent,0,0,1,1)
 return shade

static func rule(color: Color=LINE, height: float=1.0) -> ColorRect:
 var line:=ColorRect.new()
 line.color=color
 line.custom_minimum_size=Vector2(0,height)
 line.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return line
