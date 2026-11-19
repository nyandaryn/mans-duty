class_name GradTablet
extends PanelContainer

# Commander's tablet: the map of the operation area (OpenStreetMap data and
# SRTM relief), GPS position of the launcher, targets marked from the drone
# with the topographic range and grid bearing to each, the firing tables of
# the 9M22U and the drill card. Sight settings are worked out by the crew.
var game: Node3D
var command: GradCommand
var tabs: TabContainer
var view: Control
var layer: Node2D
var overlay: Control
var side: VBoxContainer
var own: Label
var target_box: VBoxContainer
var target_data: Label
var solution_text: Label
var table_grid: GridContainer
var table_title: Label
var ring := 0
var zoom := 0.12
var center := Vector2.ZERO
var dragging := false
var shown_targets := -1

func setup(owner_game: Node3D, owner: GradCommand) -> void:
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
 layer=MapLayer.new();view.add_child(layer)
 overlay=Control.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;view.add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.draw.connect(draw_overlay)
 # The column scrolls on small screens: the computed settings make it long.
 var column:=ScrollContainer.new();column.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 column.custom_minimum_size.x=380;column.size_flags_vertical=Control.SIZE_EXPAND_FILL;map_page.add_child(column)
 side=VBoxContainer.new();side.size_flags_horizontal=Control.SIZE_EXPAND_FILL;side.add_theme_constant_override("separation",6);column.add_child(side)
 own=wrapped("",13);side.add_child(own)
 var centre: Button=game.button("ЦЕНТР НА МАШИНІ",func():center=Vector2(command.vehicle.global_position.x,command.vehicle.global_position.z))
 centre.custom_minimum_size.y=34;centre.focus_mode=Control.FOCUS_NONE;side.add_child(centre)
 side.add_child(game.label("ЦІЛІ (з дрона, T)",14,game.GOLD))
 target_box=VBoxContainer.new();side.add_child(target_box)
 target_data=wrapped("",14);side.add_child(target_data)
 side.add_child(game.label("АВТОРОЗРАХУНОК · ВЕЛИКЕ КІЛЬЦЕ",14,game.GOLD))
 solution_text=wrapped("",14);side.add_child(solution_text)
 side.add_child(wrapped("Колесо — масштаб · ліва кнопка — зсув · M / ESC — закрити",12,Color("9aa58f")))
 var table_page:=VBoxContainer.new();table_page.name="ТАБЛИЦІ СТРІЛЬБИ";tabs.add_child(table_page)
 var rings:=HBoxContainer.new();rings.add_theme_constant_override("separation",6);table_page.add_child(rings)
 for i in range(3):
  var b: Button=game.button(GradBallistics.RINGS[i],func():ring=i;fill_table())
  b.custom_minimum_size=Vector2(170,34);b.focus_mode=Control.FOCUS_NONE;rings.add_child(b)
 table_title=wrapped("",14,game.GOLD);table_page.add_child(table_title)
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;table_page.add_child(scroll)
 table_grid=GridContainer.new();table_grid.columns=6
 table_grid.add_theme_constant_override("h_separation",28);table_grid.add_theme_constant_override("v_separation",1)
 scroll.add_child(table_grid)
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
 fill_table()

func fill_table() -> void:
 table_title.text="9М22У · %s · дальність %d – %d м · Вд ≈ Д/326, Вб ≈ Д/278 · прицел у тисячних, рівень 30-00 = кут місця 0" % [GradBallistics.RINGS[ring],roundi(GradBallistics.RING_SPAN[ring].x),roundi(GradBallistics.RING_SPAN[ring].y)]
 for child in table_grid.get_children():table_grid.remove_child(child);child.queue_free()
 for heading in ["Д, м","ПРИЦІЛ","ΔД / 1 тис., м","t, с","Вд, м","Вб, м"]:table_grid.add_child(game.label(heading,13,game.GOLD))
 for row in GradBallistics.firing_rows(ring):
  for value in [str(row.range),GradHud.sight_text(snappedf(row.elevation,0.5)),"%.1f" % row.per_mil,"%.1f" % row.time,"%.0f" % row.vd,"%.0f" % row.vb]:
   table_grid.add_child(game.label(value,14))

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
 own.text="GPS: %s · h %.0f м\nКвадрат %s · дирекційний кут осі машини %s\nОН %s · ПБ %s · ракети з великими кільцями" % [data.coordinates_text(v.global_position),data.altitude(v.global_position.y),command.square_text(v.global_position),GradBallistics.mils_text(heading),GradBallistics.mils_text(command.main_direction),GradBallistics.mils_text(GradVehicle.BOUSSOLE_CORRECTION)]
 if shown_targets!=command.targets.size():
  shown_targets=command.targets.size()
  for child in target_box.get_children():child.queue_free()
  for i in range(command.targets.size()):
   var b: Button=game.button(command.targets[i].name,func():command.selected_target=i)
   b.custom_minimum_size.y=30;b.focus_mode=Control.FOCUS_NONE;target_box.add_child(b)
 if command.selected_target<0 or command.selected_target>=command.targets.size():
  target_data.text="Ціль не обрано. Познач ціль з дрона (T) і обери її тут.";solution_text.text="";return
 var t:Dictionary=command.targets[command.selected_target]
 var d:=command.firing_data(t.point)
 var lines: Array[String]=[]
 lines.append("%s: %s · h %.0f м" % [t.name,data.coordinates_text(t.point),data.altitude(t.point.y)])
 lines.append("Дт %d м · αц %s" % [roundi(d.distance),GradBallistics.mils_text(d.bearing)])
 lines.append("Перевищення %+.0f м · кут місця ε %+.0f тис." % [d.height,d.site])
 var span:Vector2=GradBallistics.RING_SPAN[0]
 lines.append(("+ " if d.distance>=span.x and d.distance<=span.y else "× ")+"дальність для великих кілець %d – %d м" % [roundi(span.x),roundi(span.y)])
 if d.distance<5000:lines.append("! Менше 5 км — лише у виняткових випадках")
 if absf(d.relative)<GradVehicle.CAB_ZONE:lines.append("! Зона кабіни: пуск лише з кутом від 11° (прицел ≥ 1-83)")
 target_data.text="\n".join(lines)
 solution_text.text=solution_lines(t)

# The whole firing solution next to what is set on the sight now.
func solution_lines(target: Dictionary) -> String:
 var v:=command.vehicle
 var s:=command.solution(target)
 var lines: Array[String]=[]
 if not s.in_range or s.sight<0.0:
  lines.append("× Поза дальністю великих кілець — ближче або далі позиція")
  return "\n".join(lines)
 var mark:=func(ok: bool) -> String:return "+" if ok else "×"
 var deflection_ok:=absf(wrapf(v.deflection-s.deflection,-3000.0,3000.0))<0.5
 var sight_ok:=absf(v.sight_setting-s.sight)<0.3
 var level_ok:=absf(v.level_setting-s.level)<0.5
 lines.append("%s Кутомір %s   (стоїть %s)" % [mark.call(deflection_ok),GradBallistics.mils_text(s.deflection),GradBallistics.mils_text(v.deflection)])
 lines.append("%s Приціл %s   (стоїть %s)" % [mark.call(sight_ok),GradHud.sight_text(s.sight),GradHud.sight_text(v.sight_setting)])
 lines.append("%s Рівень %s   (стоїть %s)" % [mark.call(level_ok),GradBallistics.mils_text(s.level),GradBallistics.mils_text(v.level_setting)])
 var needle:=wrapf(v.sight_bearing()-GradVehicle.BOUSSOLE_CORRECTION,-3000.0,3000.0)
 var bubble:=v.bubble_mils()
 var laid:=absf(needle)<=2.5 and absf(bubble)<=1.5
 lines.append("%s Бусоль %+.0f тис. · бульбашка %+.0f тис.%s" % [mark.call(laid),needle,bubble,"" if laid else " — наведи"])
 lines.append("%s Пакет на цілі" % mark.call(laid and deflection_ok and sight_ok and level_ok))
 lines.append("Політ %.0f с · 1 тис. прицілу ≈ %d м" % [s.time,roundi(s.per_mil)])
 lines.append("%s Курсовий кут цілі %+.0f° (сектори: ліво 45–95°, право 45–65°)" % [mark.call(s.in_sector),s.relative])
 if not s.in_sector:lines.append("  × ПОЗА СЕКТОРОМ: розверни машину на курс %.0f° (ціль ліворуч) або %.0f° (праворуч); зараз %.0f°" % [s.heading_left,s.heading_right,s.heading])
 if s.cab_zone:lines.append("! Зона кабіни: пуск заблоковано нижче 11°")
 if s.has("correction"):
  var c: Dictionary=s.correction
  var range_text:="переліт %d" % roundi(c.along) if c.along>15 else ("недоліт %d" % roundi(-c.along) if c.along<-15 else "по дальності в цілі")
  var side_text:=("праворуч %s" % GradBallistics.mils_text(absf(c.mils))) if c.mils>3 else (("ліворуч %s" % GradBallistics.mils_text(absf(c.mils))) if c.mils<-3 else "по напрямку в цілі")
  lines.append("ДОПОВІДЬ СП: %s, %s" % [range_text,side_text])
  if c.needed:lines.append("→ Поправлені: приціл %s, кутомір %s" % [GradHud.sight_text(c.sight),GradBallistics.mils_text(c.deflection)])
  else:lines.append("→ Поправки не потрібні — залп")
 return "\n".join(lines)

func draw_overlay() -> void:
 var data:=command.data
 var font:=ThemeDB.fallback_font
 var ink:=Color("20241a")
 # Kilometre grid of the SK-42 sheet with its labels.
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
 # The three strongpoints of the enemy and the observation post.
 for i in range(3):
  var c:Vector2=BattleMap.CENTERS[i]
  var p:=world_to_screen(c)
  overlay.draw_arc(p,maxf(4,45*zoom),0,TAU,24,Color(0.75,0.1,0.1),2)
  overlay.draw_string(font,p+Vector2(6,-6),"ОП-%d" % (i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.75,0.1,0.1))
 var post:=world_to_screen(Vector2(command.post.x,command.post.z))
 overlay.draw_rect(Rect2(post-Vector2(5,5),Vector2(10,10)),Color(0.1,0.3,0.7),false,2)
 overlay.draw_string(font,post+Vector2(8,4),"СП",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.1,0.3,0.7))
 var area:=world_to_screen(Vector2(GradCommand.FIRING_AREA.x,GradCommand.FIRING_AREA.z))
 overlay.draw_arc(area,maxf(5,150*zoom),0,TAU,32,Color(0.1,0.45,0.1),2)
 overlay.draw_string(font,area+Vector2(8,-8),"ВП",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.1,0.45,0.1))
 var main:=GradBallistics.direction(command.main_direction)
 overlay.draw_line(area,area+Vector2(main.x,main.z)*70,Color(0.1,0.45,0.1),2)
 # On the training ground the observer shows the area of the target.
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
 if is_instance_valid(command.drone):
  var dp:=world_to_screen(Vector2(command.drone.global_position.x,command.drone.global_position.z))
  overlay.draw_circle(dp,4,Color(0.2,0.2,0.9))
 # The launcher: position, heading and the reach of the large brake rings.
 var v:=command.vehicle
 var me:=world_to_screen(Vector2(v.global_position.x,v.global_position.z))
 var f:=-v.global_basis.z;var fwd:=Vector2(f.x,f.z).normalized()
 overlay.draw_colored_polygon(PackedVector2Array([me+fwd*12,me+fwd.rotated(2.5)*8,me+fwd.rotated(-2.5)*8]),Color(0.1,0.1,0.1))
 overlay.draw_arc(me,GradBallistics.RING_SPAN[0].y*zoom,0,TAU,128,Color(0.2,0.2,0.2,0.5),1)
 if command.selected_target>=0 and command.selected_target<command.targets.size():
  var t:Dictionary=command.targets[command.selected_target]
  overlay.draw_dashed_line(me,world_to_screen(Vector2(t.point.x,t.point.z)),Color(0.8,0.1,0.05),1.5,8.0)
 overlay.draw_string(font,Vector2(view.size.x-470,view.size.y-12),"© OpenStreetMap contributors (ODbL) · рельєф SRTM · 1 км сітка · %d м/піксель" % roundi(1.0/zoom),HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)

const HELP := """ВЕРСІЯ ДЛЯ ОДНОГО: ти командир, навідник і водій БМ-21 одночасно.

1. ВИСУВАННЯ. У кабіні водія: I — запалювання, X (утримувати) — стартер на нейтралі. Повітря в системі має бути понад 5,5 кгс/см². SHIFT — зчеплення, Q/E — передачі, SPACE — стоянкове гальмо, L — знижена передача роздатки (лише на місці). По полю краще знижена. Курс — на ВП, позначену на планшеті.

2. ВОГНЕВА ПОЗИЦІЯ. Рівне відкрите поле, попереду в напрямку стрільби не повинно бути лісосмуг і будівель: на великих кільцях ракета йде полого (до 5–6 км кут лише 6–9°) і зачепить крони. Розверни машину так, щоб ціль була в секторі обстрілу: ліво до 102°, право до 70° від осі машини. Пуск над кабіною (±34°) можливий лише з кутом від 11°, тобто прицел ≥ 1-83; на ближчих дальностях став машину боком до цілі.

3. ПЕРЕВЕДЕННЯ В БОЙОВЕ (норматив розрахунку — до 3,5 хв):
 • стоянкове гальмо; тиск у шинах 3,2 (T — накачка);
 • на ходу двигуна: зчеплення, нейтраль, P — коробка відбору потужності; [ ] — ручний газ ≈ 1500 об/хв для генератора приводу наведення;
 • V — броньовані щитки на вітрове скло;
 • зовні (F біля точки): кран «БОЙОВЕ / ПОХІД» (лівий борт), чохол (корма), похідне кріплення пакета (лівий борт), кронштейн прицілу (місце навідника).

4. ЦІЛІ. З місця командира J — дрон СП через ретранслятор. Шукай опорні пункти (окопи, бліндажі, групи бійців). T — позначити ціль лазерним далекоміром: координати потраплять на планшет.

5. ДАНІ ДЛЯ СТРІЛЬБИ. Планшет сам рахує всі установки для обраної цілі (АВТОРОЗРАХУНОК): кутомір, приціл, рівень, час польоту, курс машини для сектора, а після доповіді СП — поправлені приціл і кутомір. Поруч — що стоїть на прицілі зараз (+ збігається, × ні). Як це рахується вручну: планшет дає Дт і дирекційний кут αц від GPS машини. З таблиці (ВЕЛИКЕ КІЛЬЦЕ) — прицел для Дт. Кут місця ε = (hц − hвп) / (0,001 · Дт), рівень = 30-00 + ε.

6. НАВЕДЕННЯ (F біля місця навідника). Наведення в бусоль: кутомір = αц − ПБ, якщо результат менший за 30-00 — додай 30-00, інакше відніми 30-00 (ПБ = 1-55). Q/E — кутомір, B — відкрити бусоль, ← → — повертай пакет, доки стрілка не стане на індекс. W/S — прицел, A/D — рівень, ↑ ↓ — піднімай пакет, доки бульбашка рівня не стане посередині. Привід: коротке натискання — повзуча швидкість, утримання — до 7°/с; CTRL — ручні маховики.

7. ПУСК. Місце командира, E — пульт: ВБ-55, КОНТР. ПИТ., ключ АВТ або ОДИН, звести програмний механізм, SPACE — рукоятка пуску. Ракети йдуть через 0,5 с. За струменем ззаду (до 20 м) — смертельна зона.

8. КОРЕКТУРА. СП доповідає відхилення центру розривів від цілі: переліт/недоліт у метрах, ліворуч/праворуч у тисячних. Переліт 100 м — зменш прицел на 100 / ΔД (ΔД — з таблиці), недоліт — збільш. Праворуч 0-10 — зменш кутомір на 0-10, ліворуч — збільш; потім знову наведи стрілку бусолі й бульбашку.

9. ЗМІНА ПОЗИЦІЇ. Після залпу противник за 2–4 хв накриє ВП контрбатарейним вогнем. Пакет у похідне, кран «ПОХІД» — і геть.

10. ШТУРМ. G — радіо. Коли більшість опорних пунктів (ОП) знищено, віддай команду штурмовим групам. ОП займає три двори: знищений — коли уражено дві його позиції або вибуло дві третини гарнізону. Під час штурму не бий по ОП, де вже свої."""

class MapLayer extends Node2D:
 # The whole 12 × 12 km sheet in a dozen draw calls: one mesh for the houses,
 # one multiline per line style.
 const STYLES := {"woods":Color(0.25,0.5,0.2,0.9),"rows":Color(0.2,0.45,0.15),"water":Color(0.2,0.4,0.85),"rails":Color(0.1,0.1,0.1),"primary":Color(0.85,0.4,0.1),"secondary":Color(0.85,0.6,0.1),"tertiary":Color(0.8,0.65,0.25),"track":Color(0.5,0.35,0.2),"minor":Color(0.45,0.45,0.42)}
 var built := false
 var data: AvdiivkaData
 var texture: ImageTexture
 var lines: Dictionary={}
 var houses: ArrayMesh
 func segments(style: String, points: PackedVector2Array) -> void:
  if points.size()<2:return
  var list: PackedVector2Array=lines.get(style,PackedVector2Array())
  for k in range(points.size()-1):
   list.append(points[k]);list.append(points[k+1])
  lines[style]=list
 func build(source: AvdiivkaData) -> void:
  data=source;built=true
  var image:=Image.create_from_data(data.size,data.size,false,Image.FORMAT_RGB8,data.cover)
  image.adjust_bcs(1.25,0.85,0.75)
  texture=ImageTexture.create_from_image(image)
  var f:Dictionary=data.features
  for w in f.woods:segments("woods",AvdiivkaData.pairs(w))
  for r in f.rows:segments("rows",AvdiivkaData.pairs(r))
  for item in f.streams:segments("water",AvdiivkaData.pairs(item[1]))
  for w in f.water:segments("water",AvdiivkaData.pairs(w))
  for r in f.rails:segments("rails",AvdiivkaData.pairs(r))
  for r in f.roads:
   if r[0] in OperationArea.SKIP_ROADS:continue
   var kind:String=r[0]
   if kind in ["trunk","trunk_link","primary_link"]:kind="primary"
   if not STYLES.has(kind):kind="minor"
   segments(kind,AvdiivkaData.pairs(r[3]))
  var vertices:=PackedVector2Array()
  var colors:=PackedColorArray()
  for b in f.buildings:
   var c:=cos(float(b[4]));var s:=sin(float(b[4]))
   var x:=float(b[0]);var z:=float(b[1]);var w:=float(b[2])*0.5;var d:=float(b[3])*0.5
   var q: Array=[]
   for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
    q.append(Vector2(x+c*corner.x*w+s*corner.y*d,z-s*corner.x*w+c*corner.y*d))
   for index in [0,1,2,0,2,3]:vertices.append(q[index]);colors.append(Color(0.35,0.3,0.28))
  houses=ArrayMesh.new()
  var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
  if not vertices.is_empty():houses.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  queue_redraw()
 func _draw() -> void:
  if not built:return
  var h:=data.half+data.step*0.5
  draw_texture_rect(texture,Rect2(-h,-h,h*2,h*2),false)
  for style in ["woods","rows","water","rails","minor","track","tertiary","secondary","primary"]:
   if lines.has(style):draw_multiline(lines[style],STYLES[style],-1)
  if houses.get_surface_count()>0:draw_mesh(houses,null)
