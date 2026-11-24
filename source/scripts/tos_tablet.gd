class_name TosTablet
extends PanelContainer

# The TOS-1A commander's tablet: the same sheet of the operation area as the
# BM-21 commander's (GradTablet.MapLayer), the vehicle's GPS position, the
# targets marked from the observation post's drone, the data the fire-
# control computer will get, the observer's corrections, and the firing
# table of the MO.1.01.04M. The computer of the BM-1 lays the package by
# itself: the crew gives it the target, not sight settings.
var game: Node3D
var command: TosCommand
var tabs: TabContainer
var view: Control
var layer: GradTablet.MapLayer
var overlay: Control
var own: Label
var target_box: VBoxContainer
var target_data: Label
var computer_text: Label
var table_grid: GridContainer
var zoom := 0.12
var center := Vector2.ZERO
var dragging := false
var shown_targets := -1

func setup(owner_game: Node3D, owner: TosCommand) -> void:
 game=owner_game;command=owner
 add_theme_stylebox_override("panel",game.panel_style(Color(0.035,0.05,0.04,0.96),game.GOLD))
 mouse_filter=Control.MOUSE_FILTER_STOP
 tabs=TabContainer.new();add_child(tabs)
 var map_page:=HBoxContainer.new();map_page.name="КАРТА";map_page.add_theme_constant_override("separation",10);tabs.add_child(map_page)
 view=Control.new();view.clip_contents=true;view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;view.size_flags_vertical=Control.SIZE_EXPAND_FILL
 view.mouse_filter=Control.MOUSE_FILTER_STOP;map_page.add_child(view)
 view.gui_input.connect(map_input)
 var backdrop:=ColorRect.new();backdrop.color=Color("e9e6d6");backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
 view.add_child(backdrop);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layer=GradTablet.MapLayer.new();view.add_child(layer)
 overlay=Control.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;view.add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.draw.connect(draw_overlay)
 var column:=ScrollContainer.new();column.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 column.custom_minimum_size.x=380;column.size_flags_vertical=Control.SIZE_EXPAND_FILL;map_page.add_child(column)
 var side:=VBoxContainer.new();side.size_flags_horizontal=Control.SIZE_EXPAND_FILL;side.add_theme_constant_override("separation",6);column.add_child(side)
 own=wrapped("",13);side.add_child(own)
 var centre: Button=game.button("ЦЕНТР НА МАШИНІ",func():center=Vector2(command.vehicle.global_position.x,command.vehicle.global_position.z))
 centre.custom_minimum_size.y=34;centre.focus_mode=Control.FOCUS_NONE;side.add_child(centre)
 side.add_child(game.label("ЦІЛІ (з дрона СП, T)",14,game.GOLD))
 target_box=VBoxContainer.new();side.add_child(target_box)
 target_data=wrapped("",14);side.add_child(target_data)
 var load_button: Button=game.button("В ОБЧИСЛЮВАЧ І НАВЕСТИ",func():command.load_target())
 load_button.custom_minimum_size.y=38;load_button.focus_mode=Control.FOCUS_NONE;side.add_child(load_button)
 side.add_child(game.label("ОБЧИСЛЮВАЧ БМ-1",14,game.GOLD))
 computer_text=wrapped("",14);side.add_child(computer_text)
 side.add_child(wrapped("Колесо — масштаб · ліва кнопка — зсув · M / ESC — закрити",12,Color("9aa58f")))
 var table_page:=VBoxContainer.new();table_page.name="ТАБЛИЦЯ СТРІЛЬБИ";tabs.add_child(table_page)
 table_page.add_child(wrapped("МО.1.01.04М · дальність %d – %d м · кут пакета в градусах при цілі на рівні машини · Вд ≈ Д/95, Вб ≈ Д/185 (серединні відхилення, оцінка гри)" % [roundi(TosBallistics.SPAN.x),roundi(TosBallistics.SPAN.y)],14,game.GOLD))
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;table_page.add_child(scroll)
 table_grid=GridContainer.new();table_grid.columns=6
 table_grid.add_theme_constant_override("h_separation",28);table_grid.add_theme_constant_override("v_separation",1)
 scroll.add_child(table_grid)
 for heading in ["Д, м","КУТ, °","ΔД / 1 тис., м","t, с","Вд, м","Вб, м"]:table_grid.add_child(game.label(heading,13,game.GOLD))
 for row in TosBallistics.firing_rows():
  for value in [str(row.range),"%.1f" % (row.elevation*0.06),"%.1f" % row.per_mil,"%.1f" % row.time,"%.0f" % row.vd,"%.0f" % row.vb]:
   table_grid.add_child(game.label(value,14))
 var help_page:=ScrollContainer.new();help_page.name="ПАМ’ЯТКА";tabs.add_child(help_page)
 var help:=wrapped(HELP,15);help.custom_minimum_size.x=900;help_page.add_child(help)

func wrapped(value: String, font_size: int, color: Color=Color(0,0,0,0)) -> Label:
 var node: Label=game.label(value,font_size) if color.a==0 else game.label(value,font_size,color)
 node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.custom_minimum_size.x=40
 return node

func opened() -> void:
 if not layer.built:layer.build(command.data)
 if center==Vector2.ZERO and command.active():center=Vector2(command.vehicle.global_position.x,command.vehicle.global_position.z)
 shown_targets=-1

func map_input(event: InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
   var before:=screen_to_world(event.position)
   zoom=clampf(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.8),0.04,3.0)
   var after:=screen_to_world(event.position)
   center+=before-after
  elif event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
 elif event is InputEventMouseMotion and dragging:
  center-=event.relative/zoom

func world_to_screen(p: Vector2) -> Vector2:return (p-center)*zoom+view.size*0.5
func screen_to_world(p: Vector2) -> Vector2:return (p-view.size*0.5)/zoom+center

func _process(_delta: float) -> void:
 if not visible or not command.active():return
 layer.position=view.size*0.5-center*zoom
 layer.scale=Vector2(zoom,zoom)
 overlay.queue_redraw()
 refresh_side()

func refresh_side() -> void:
 var v:=command.vehicle
 var data:=command.data
 var heading:=GradBallistics.bearing(-v.global_basis.z)
 own.text="GPS: %s · h %.0f м\nКвадрат %s · дирекційний кут осі машини %s\nОН %s · ракет у пакеті %d / 24" % [data.coordinates_text(v.global_position),data.altitude(v.global_position.y),command.square_text(v.global_position),GradBallistics.mils_text(heading),GradBallistics.mils_text(command.main_direction),v.remaining()]
 if shown_targets!=command.targets.size():
  shown_targets=command.targets.size()
  for child in target_box.get_children():child.queue_free()
  for i in range(command.targets.size()):
   var b: Button=game.button(command.targets[i].name,func():command.selected_target=i)
   b.custom_minimum_size.y=30;b.focus_mode=Control.FOCUS_NONE;target_box.add_child(b)
 computer_text.text=TosHud.solution_text(v.solution)
 if command.selected_target<0 or command.selected_target>=command.targets.size():
  target_data.text="Ціль не обрано. Познач ціль з дрона СП (T) і обери її тут.";return
 var t:Dictionary=command.targets[command.selected_target]
 var d:=command.firing_data(t.point)
 var lines: Array[String]=[]
 lines.append("%s: %s · h %.0f м" % [t.name,data.coordinates_text(t.point),data.altitude(t.point.y)])
 lines.append("Дт %d м · αц %s · перевищення %+.0f м" % [roundi(d.distance),GradBallistics.mils_text(d.bearing),d.height])
 lines.append(("+ " if d.in_range else "× ")+"дальність %d – %d м" % [roundi(TosBallistics.SPAN.x),roundi(TosBallistics.SPAN.y)])
 lines.append(("+ " if d.in_sector else "× ")+"курсовий кут цілі %+.0f° (платформа ±100°)" % d.relative)
 if not d.in_sector:lines.append("  розверни машину на курс %.0f° (зараз %.0f°)" % [d.heading_wanted,d.heading])
 if d.in_range:lines.append("Кут пакета ≈ %.1f° · політ %.0f с" % [d.elevation*0.06,d.time])
 if d.distance<1500.0:lines.append("! Ближче 1,5 км: свої в зоні ураження еліпса 200 × 400 м")
 var report: Dictionary=command.last_report
 if not report.is_empty() and report.get("name","")==t.name and report.has("along"):
  var along: float=report.along;var mils: float=report.mils
  var range_text:="переліт %d" % roundi(along) if along>15 else ("недоліт %d" % roundi(-along) if along<-15 else "по дальності в цілі")
  var side_text:=("праворуч %s" % GradBallistics.mils_text(absf(mils))) if mils>3 else (("ліворуч %s" % GradBallistics.mils_text(absf(mils))) if mils<-3 else "по напрямку в цілі")
  lines.append("ДОПОВІДЬ СП: %s, %s" % [range_text,side_text])
  lines.append("→ «В обчислювач» врахує поправку: точку наведення зсунуто на відхилення")
 target_data.text="\n".join(lines)

func draw_overlay() -> void:
 var data:=command.data
 var font:=ThemeDB.fallback_font
 var ink:=Color("20241a")
 var first:=screen_to_world(Vector2.ZERO);var last:=screen_to_world(view.size)
 var step:=1000.0 if zoom>0.035 else 2000.0
 var e0:=ceilf((data.easting+first.x)/step)*step
 while e0<data.easting+last.x:
  var sx:=world_to_screen(Vector2(e0-data.easting,0)).x
  overlay.draw_line(Vector2(sx,0),Vector2(sx,view.size.y),Color(0.1,0.2,0.5,0.45),1)
  overlay.draw_string(font,Vector2(sx+3,16),"%02d" % (int(e0/1000.0)%100),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.1,0.2,0.5))
  e0+=step
 var n0:=ceilf((data.northing-last.y)/step)*step
 while n0<data.northing-first.y:
  var sy:=world_to_screen(Vector2(0,data.northing-n0)).y
  overlay.draw_line(Vector2(0,sy),Vector2(view.size.x,sy),Color(0.1,0.2,0.5,0.45),1)
  overlay.draw_string(font,Vector2(4,sy-3),"%02d" % (int(n0/1000.0)%100),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.1,0.2,0.5))
  n0+=step
 for place in data.meta.get("places",[]):
  var p:=world_to_screen(Vector2(float(place[1]),float(place[2])))
  overlay.draw_string(font,p,str(place[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,15 if place[3]=="town" else 13,ink)
 for i in range(3):
  var c:Vector2=BattleMap.CENTERS[i]
  var p:=world_to_screen(c)
  overlay.draw_arc(p,maxf(4,45*zoom),0,TAU,24,Color(0.75,0.1,0.1),2)
  overlay.draw_string(font,p+Vector2(6,-6),"ОП-%d" % (i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.75,0.1,0.1))
 var post:=world_to_screen(Vector2(command.post.x,command.post.z))
 overlay.draw_rect(Rect2(post-Vector2(5,5),Vector2(10,10)),Color(0.1,0.3,0.7),false,2)
 overlay.draw_string(font,post+Vector2(8,4),"СП",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.1,0.3,0.7))
 var area:=world_to_screen(Vector2(TosCommand.FIRING_AREA.x,TosCommand.FIRING_AREA.z))
 overlay.draw_arc(area,maxf(5,150*zoom),0,TAU,32,Color(0.1,0.45,0.1),2)
 overlay.draw_string(font,area+Vector2(8,-8),"ВП",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.1,0.45,0.1))
 var main:=GradBallistics.direction(command.main_direction)
 overlay.draw_line(area,area+Vector2(main.x,main.z)*70,Color(0.1,0.45,0.1),2)
 if command.training and command.strongpoints.size()>1:
  var sp:Vector3=command.strongpoints[1].point
  var c:=world_to_screen(Vector2(sp.x,sp.z))
  var r:=maxf(8.0,60.0*zoom)
  for k in range(0,24,2):overlay.draw_arc(c,r,TAU*k/24.0,TAU*(k+1)/24.0,4,Color(0.85,0.45,0.05),2)
  overlay.draw_string(font,c+Vector2(r+4,4),"РАЙОН ЦІЛІ (ОП-2)",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.75,0.35,0.0))
 for i in range(command.targets.size()):
  var t:Dictionary=command.targets[i]
  var p:=world_to_screen(Vector2(t.point.x,t.point.z))
  var colour:=Color(0.85,0.1,0.05) if i==command.selected_target else Color(0.55,0.1,0.05)
  overlay.draw_line(p+Vector2(-6,-6),p+Vector2(6,6),colour,2);overlay.draw_line(p+Vector2(-6,6),p+Vector2(6,-6),colour,2)
  overlay.draw_string(font,p+Vector2(8,-4),t.name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,colour)
 for b in command.burst_log.slice(maxi(0,command.burst_log.size()-24)):
  var p:=world_to_screen(Vector2(b.x,b.z))
  overlay.draw_circle(p,maxf(2.0,20.0*zoom),Color(0.9,0.45,0.05,0.35))
 if is_instance_valid(command.drone):
  var dp:=world_to_screen(Vector2(command.drone.global_position.x,command.drone.global_position.z))
  overlay.draw_circle(dp,4,Color(0.2,0.2,0.9))
 var v:=command.vehicle
 var me:=world_to_screen(Vector2(v.global_position.x,v.global_position.z))
 var f:=-v.global_basis.z;var fwd:=Vector2(f.x,f.z).normalized()
 overlay.draw_colored_polygon(PackedVector2Array([me+fwd*12,me+fwd.rotated(2.5)*8,me+fwd.rotated(-2.5)*8]),Color(0.1,0.1,0.1))
 overlay.draw_arc(me,TosBallistics.SPAN.y*zoom,0,TAU,128,Color(0.2,0.2,0.2,0.5),1)
 overlay.draw_arc(me,TosBallistics.SPAN.x*zoom,0,TAU,48,Color(0.6,0.1,0.1,0.4),1)
 # The platform's sector: ±100° about the hull.
 var yaw:=atan2(fwd.y,fwd.x)
 for side: float in [-1.0,1.0]:
  var a:=yaw+side*deg_to_rad(TosVehicle.TRAVERSE)
  overlay.draw_dashed_line(me,me+Vector2(cos(a),sin(a))*TosBallistics.SPAN.y*zoom,Color(0.2,0.2,0.2,0.45),1.0,10.0)
 if command.selected_target>=0 and command.selected_target<command.targets.size():
  var t:Dictionary=command.targets[command.selected_target]
  overlay.draw_dashed_line(me,world_to_screen(Vector2(t.point.x,t.point.z)),Color(0.8,0.1,0.05),1.5,8.0)
 overlay.draw_string(font,Vector2(view.size.x-470,view.size.y-12),"© OpenStreetMap contributors (ODbL) · рельєф SRTM · 1 км сітка · %d м/піксель" % roundi(1.0/zoom),HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)

const HELP := """ВЕРСІЯ ДЛЯ ОДНОГО: ти механік-водій, навідник-оператор і командир БМ-1 одночасно. C — наступне місце, F — вийти з машини.

1. ЗАПУСК (місце механіка-водія). I — вимикач батарей (МАСА). P (утримувати) — маслозакачувальний насос МЗН, доки тиск масла не перевищить 2 кгс/см² (2–12 с). X (утримувати) — стартер. Передача — нейтраль, зчеплення вичавлене (SHIFT).

2. РУХ. Сім передач уперед і одна назад, перемикання лише з вичавленим зчепленням (SHIFT + Q/E). Назад — лише з місця. W — газ, S — гальмо, SPACE — стоянкові гальма на защіпці. Поворот — важелі A/D: частковий хід — фрикціони відстаючого борту пробуксовують, плавний поворот; до упору — борт на передачу нижче, радіус залежить від передачі (на 2-й 6 м, на 3-й–4-й 13–14 м, на 7-й 9 м). На першій і задній до упору — гальмо борту, поворот навколо гусениці. Обидва важелі до упору — обидва борти на передачу нижче (на першій — гальмо). На нейтралі важелі не діють, розвороту на місці немає. Гальма на защіпку й стартер — лише на нейтралі; передача при затягнутій защіпці не вмикається. Блок БА-20 не дасть понизити 7→6, 6→5, 5→4 на завеликій швидкості. H — люк (по-похідному голова зовні, по-бойовому — прилад ТНПО-168В). ПКМ — прилади.

3. ВОГНЕВА ПОЗИЦІЯ. Відкрите рівне поле в межах 6 км від цілей; ціль — у секторі платформи ±100° від осі машини. Ракета летить по крутій траєкторії (кут пакета до 60°), тож лісосмуга попереду не заважає, але в зоні струменя за кормою (до 30 м) нікого не має бути.

4. ПРИВЕДЕННЯ В БОЙОВЕ (норматив виробника — 90 с від зупинки до пуску):
 • стоянкові гальма (SPACE);
 • двигун працює: гідравліка домкратів і приводів наведення живиться від нього;
 • місце командира, E — пульт: ЖИВЛЕННЯ СУО (обчислювач і датчик крену готуються 40 с), ДОМКРАТИ, СТОПОРИ.

5. ПРЯМЕ НАВЕДЕННЯ (місце навідника, приціл-далекомір 1Д14 ×8). ← → — платформа, CTRL — точно; ↑ ↓ або миша — головка прицілу. Наведи марку на ціль, R — лазерний далекомір (400 м – 10 км, ±10 м), ENTER — дальність у обчислювач: він сам врахує крен і диферент машини й наведе пакет.

6. СТРІЛЬБА ЗА КООРДИНАТАМИ. Місце командира, J — дрон СП через ретранслятор. T — позначити ціль лазером дрона. M — планшет: обери ціль, «В ОБЧИСЛЮВАЧ І НАВЕСТИ» (або ENTER на місці командира). Пакет наведеться сам.

7. ПУСК. На пульті: РЕЖИМ (одиночними або парами), СЕРІЯ 1 / 2 / 6 / 12 / 24, ЗБРОЯ (запобіжник). SPACE на місці навідника чи командира — пуск. Ракети сходять через 0,5 с: 12 парами — 3 с, 24 одиночними — 12 с.

8. КОРЕКТУРА. СП доповідає відхилення центру розривів від цілі. Повторне «В обчислювач» по тій самій цілі зсуває точку наведення на доповідане відхилення.

9. ВІДХІД. Через 2,5–4 хв після пуску противник накриє ВП контрбатарейним вогнем. Пульт: ПОХІДНЕ (пакет на 0°/0°), СТОПОРИ, ДОМКРАТИ вгору — і геть. Рух на домкратах неможливий.

10. ШТУРМ. G — радіо. Знищ більшість опорних пунктів (ОП) і віддай команду штурмовим групам. Еліпс залпу — 200 × 400 м: по ОП, де вже свої, не бий."""
