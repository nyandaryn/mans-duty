class_name MissionCard
extends Button

var mission: Dictionary={}
var available := false
var cleared := false
var selected := false
const GOLD := Color("c8b17a")
const INK := Color("e4e5d6")

func _ready() -> void:
 custom_minimum_size=Vector2(0,86)
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 mouse_entered.connect(queue_redraw)
 mouse_exited.connect(queue_redraw)
 focus_entered.connect(queue_redraw)
 focus_exited.connect(queue_redraw)

func configure(data: Dictionary, open: bool, done: bool, active: bool) -> void:
 mission=data
 available=open
 cleared=done
 selected=active
 disabled=not open
 tooltip_text=data.brief if open else "Заверши попередню операцію цієї гілки"
 queue_redraw()

func _draw() -> void:
 if mission.is_empty():return
 var background := Color(0.89,0.71,0.36,0.16) if selected else Color(0.03,0.045,0.04,0.8)
 if (is_hovered() or has_focus()) and available:background=Color(1,1,1,0.08) if not selected else background.lightened(0.08)
 draw_style_box(style(background),Rect2(Vector2.ZERO,size))
 var muted := Color("879087") if available else Color("515f56")
 var color := INK if available else muted
 draw_rect(Rect2(0,0,4,size.y),GOLD if selected else Color("45634d") if cleared else muted)
 var font := UiKit.font("head")
 draw_string(font,Vector2(17,25),"%02d" % int(mission.stage),HORIZONTAL_ALIGNMENT_LEFT,-1,17,GOLD if available else muted)
 draw_string(font,Vector2(52,25),mission.title,HORIZONTAL_ALIGNMENT_LEFT,size.x-210,18,color)
 var category: String={"forest":"ЛІСОСМУГА / ОКОПИ","village":"СЕЛО / САДИБИ","district":"МІСЬКИЙ КВАРТАЛ"}[mission.kind]
 draw_string(font,Vector2(52,48),category+"   ·   400 × 400 м",HORIZONTAL_ALIGNMENT_LEFT,size.x-210,11,muted)
 var state := "ЗАВЕРШЕНО" if cleared else ("ОБРАНО" if selected else "ДОСТУПНО") if available else "ЗАБЛОКОВАНО"
 draw_string(font,Vector2(52,70),state,HORIZONTAL_ALIGNMENT_LEFT,-1,11,GOLD if selected else muted)
 # Topographic overview uses the authored layout rather than interchangeable art.
 var bounds := Rect2(size.x-137,9,122,size.y-18)
 draw_rect(bounds,Color("101a17"))
 for i in range(1,4):
  draw_line(bounds.position+Vector2(bounds.size.x*i/4,0),bounds.position+Vector2(bounds.size.x*i/4,bounds.size.y),Color("243329"))
 for belt in mission.belts:
  draw_line(map_point(belt[0],bounds),map_point(belt[1],bounds),Color("425b3c") if available else Color("29362b"),maxf(2,float(belt[2])*bounds.size.x/400))
 for trench in mission.trenches:
  for i in range(trench.size()-1):draw_line(map_point(trench[i],bounds),map_point(trench[i+1],bounds),GOLD.darkened(0.25) if available else muted,1.5)
 for building in mission.buildings:
  var point := map_point(building.point,bounds)
  draw_rect(Rect2(point-Vector2(2,2),Vector2(4,4)),Color("8d9181") if available else muted)
 draw_circle(map_point(mission.spawn,bounds),2.2,GOLD if available else muted)
 if has_focus():draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),GOLD,false,2)

func map_point(point: Vector2, bounds: Rect2) -> Vector2:
 return bounds.position+(point+Vector2.ONE*200)/400*bounds.size

func style(color: Color) -> StyleBoxFlat:
 var box := StyleBoxFlat.new()
 box.bg_color=color
 box.border_color=GOLD if selected else Color("38483c")
 box.set_border_width_all(1)
 box.corner_radius_top_left=3
 box.corner_radius_top_right=3
 box.corner_radius_bottom_left=3
 box.corner_radius_bottom_right=3
 return box
