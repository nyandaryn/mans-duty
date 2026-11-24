class_name TosHud
extends Control

# What the TOS-1A crew sees and touches: the driver's instruments and the
# strip of the TNPO-168V, the field of the 1D14 sight-rangefinder with the
# computer's readings, the commander's TKN-3A and the fire-control panel,
# the radio and the tablet.
const INK := Color("d9e4c9")
const DIM := Color("9aa58f")
const AMBER := Color("e8b45a")
const RED := Color("e0604e")
const GREEN := Color("8fd26a")
var game: Node3D
var command: TosCommand
var panels: Dictionary={}
var current := ""
var console_lamps: Label
var console_state: Label
var buttons: Dictionary={}
var radio_log: Label
var tablet: TosTablet

func setup(owner_game: Node3D, owner: TosCommand) -> void:
 game=owner_game;command=owner
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 build_console()
 build_radio()
 tablet=TosTablet.new();tablet.name="Tablet"
 game.place(tablet,self,0.03,0.05,0.97,0.95)
 tablet.setup(game,command)
 tablet.hide();panels.tablet=tablet
 resized.connect(fit_tablet)

func fit_tablet() -> void:
 var extra:=maxf(0.0,size.x*0.94-size.y*0.9*2.05)*0.5
 tablet.offset_left=extra;tablet.offset_right=-extra

func panel(left: float, top: float, right: float, bottom: float) -> VBoxContainer:
 var sheet:=PanelContainer.new()
 sheet.add_theme_stylebox_override("panel",game.panel_style(Color(0.035,0.05,0.04,0.93),game.GOLD))
 game.place(sheet,self,left,top,right,bottom)
 sheet.mouse_filter=Control.MOUSE_FILTER_STOP
 var page:=VBoxContainer.new();page.add_theme_constant_override("separation",7)
 sheet.add_child(page)
 sheet.hide()
 return page

func small(text: String, callback: Callable) -> Button:
 var b: Button=game.button(text,callback)
 b.custom_minimum_size=Vector2(0,38);b.focus_mode=Control.FOCUS_NONE
 b.add_theme_font_size_override("font_size",14);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 return b

func row(page: VBoxContainer) -> HBoxContainer:
 var line:=HBoxContainer.new();line.add_theme_constant_override("separation",6);page.add_child(line)
 return line

func build_console() -> void:
 var page:=panel(0.50,0.36,0.985,0.97)
 panels.console=page.get_parent()
 page.add_child(game.label("ПУЛЬТ КОМАНДИРА · БМ-1",20,game.GOLD))
 console_lamps=game.label("",15);page.add_child(console_lamps)
 var first:=row(page)
 buttons.fcs=small("ЖИВЛЕННЯ СУО",func():command.vehicle.toggle_fcs());buttons.fcs.toggle_mode=true;first.add_child(buttons.fcs)
 buttons.jacks=small("ДОМКРАТИ",func():command.vehicle.toggle_jacks());buttons.jacks.toggle_mode=true;first.add_child(buttons.jacks)
 buttons.stops=small("СТОПОРИ",func():command.vehicle.toggle_stops());buttons.stops.toggle_mode=true;first.add_child(buttons.stops)
 var second:=row(page)
 buttons.pairs=small("ПАРАМИ",func():command.vehicle.toggle_pairs());buttons.pairs.toggle_mode=true;second.add_child(buttons.pairs)
 buttons.series=small("СЕРІЯ 12",func():command.vehicle.cycle_series());second.add_child(buttons.series)
 buttons.armed=small("ЗБРОЯ",func():command.vehicle.toggle_armed());buttons.armed.toggle_mode=true;second.add_child(buttons.armed)
 var third:=row(page)
 third.add_child(small("ДАНІ З ПЛАНШЕТА → ОБЧИСЛЮВАЧ (ENTER)",func():command.load_target()))
 third.add_child(small("ПОХІДНЕ: ПАКЕТ 0° / 0°",func():stow()))
 console_state=game.label("",14);console_state.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(console_state)
 var fire_button: Button=game.button("ПУСК (SPACE)",func():command.fire(),true)
 fire_button.custom_minimum_size=Vector2(0,54);fire_button.focus_mode=Control.FOCUS_NONE
 page.add_child(fire_button)
 var note: Label=game.label("Порядок: машина на місці → двигун → живлення СУО (40 с на підготовку) → домкрати → стопори → дані цілі в обчислювач (з планшета або 1Д14 на місці навідника) → пакет наведеться сам → ЗБРОЯ → ПУСК. Серія йде через 0,5 с: парами 24 ракети — 6 с. E / ESC — закрити.",12,DIM)
 note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(note)

func stow() -> void:
 var v:=command.vehicle
 v.solution={};v.armed=false
 if v.can_traverse():v.want_yaw=0.0;v.want_elevation=0.0
 else:v.say("Стопори закрито або немає живлення приводів",2)

func build_radio() -> void:
 var page:=panel(0.20,0.12,0.80,0.86)
 panels.radio=page.get_parent()
 page.add_child(game.label("РАДІОСТАНЦІЯ Р-173 · МЕРЕЖА КОМБАТА",20,game.GOLD))
 var first:=row(page)
 first.add_child(small("ШТУРМОВИМ ГРУПАМ — ВПЕРЕД",func():command.order_assault(true);close_all()))
 first.add_child(small("ГРУПАМ ЗАКРІПИТИСЯ",func():command.order_assault(false);close_all()))
 var second:=row(page)
 second.add_child(small("СП: ПІДНЯТИ ДРОН",func():command.request_drone() if command.seat=="commander" else command.radio("СП","Дрон керується з термінала на місці командира.")))
 second.add_child(small("СП: ДОПОВІСТИ ОБСТАНОВКУ",func():report()))
 radio_log=game.label("",14);radio_log.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 radio_log.size_flags_vertical=Control.SIZE_EXPAND_FILL;page.add_child(radio_log)
 page.add_child(game.label("G / ESC — закрити",12,DIM))

func report() -> void:
 if command.training:
  command.radio("СП","Полігон. Навчальна ціль ОП-2 %s. Ракет у пакеті %d." % ["знищена" if command.strongpoints[1].destroyed else "ціла",command.vehicle.remaining()]);return
 var parts: Array[String]=[]
 for item in command.strongpoints:
  if item.destroyed:parts.append(item.title)
 command.radio("СП","Знищено ОП: %s. Штурм: %s." % [", ".join(parts) if not parts.is_empty() else "немає","очікує команди" if game.battle.awaiting else ("призупинено" if game.battle.halted else "триває")])

func open_panel() -> String:return current

func toggle(id: String) -> void:
 if current==id:close_all();return
 if id=="console" and command.seat!="commander":return
 close_all()
 current=id
 if id=="radio":
  var shift:=0.12 if game.tos_training.running else 0.0
  panels.radio.anchor_left=0.20-shift;panels.radio.anchor_right=0.80-shift
 panels[id].show()
 game.commands_open=true
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 if id=="tablet":tablet.opened()
 refresh()

func close_all() -> void:
 for id in panels:panels[id].hide()
 var was:=current
 current=""
 if was!="":
  game.commands_open=false
  if game.running and not game.paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func lamp_text(on: bool, text: String) -> String:return ("● " if on else "○ ")+text

func refresh() -> void:
 if not command.active():return
 var v:=command.vehicle
 if current=="console":
  buttons.fcs.set_pressed_no_signal(v.fcs_power)
  buttons.jacks.set_pressed_no_signal(v.jacks_wanted)
  buttons.stops.set_pressed_no_signal(not v.stops_locked)
  buttons.stops.text="СТОПОРИ ЗНЯТО" if not v.stops_locked else "СТОПОРИ"
  buttons.pairs.set_pressed_no_signal(v.pairs)
  buttons.pairs.text="ПАРАМИ" if v.pairs else "ОДИНОЧНИМИ"
  buttons.series.text="СЕРІЯ %d" % v.series
  buttons.armed.set_pressed_no_signal(v.armed)
  console_lamps.text="   ".join([lamp_text(v.master,"МАСА"),lamp_text(v.running,"ГІДРАВЛІКА"),lamp_text(v.fcs_ready(),"СУО %d %%" % roundi(v.fcs_warm*100)),lamp_text(v.jacks>=1.0,"ДОМКРАТИ"),lamp_text(not v.stops_locked and v.stop_motion<=0.0,"СТОПОРИ ЗНЯТО"),lamp_text(v.armed,"ЗБРОЯ")])
  var lines: Array[String]=[]
  lines.append("Платформа %+.1f° → %+.1f° · пакет %.1f° → %.1f° · ракет %d" % [v.platform_yaw,v.want_yaw,v.elevation,v.want_elevation,v.remaining()])
  lines.append(solution_text(v.solution))
  var why:=v.ready_to_fire()
  lines.append("ГОТОВИЙ ДО ПУСКУ" if why=="" else "Пуск неможливий: %s" % why)
  console_state.text="\n".join(lines)
 if current=="radio":radio_log.text="\n".join(command.radio_log)

static func solution_text(s: Dictionary) -> String:
 if s.is_empty():return "Обчислювач: даних цілі немає"
 if s.has("error"):return "Обчислювач (%s): %s" % [s.get("source",""),s.error]
 return "Обчислювач (%s): Д %d м · перевищення %+.0f м · платформа %+.1f° · пакет %.1f° · політ %.0f с" % [s.source,roundi(s.distance),-float(s.drop),s.platform,s.package,s.time]

func _process(_delta: float) -> void:
 if not is_instance_valid(command) or not command.active() or not game.running:
  if visible and not command.active():queue_redraw()
  return
 if current!="":refresh()
 queue_redraw()

# --- Drawing ----------------------------------------------------------------
func text(at: Vector2, value: String, size_px: int=15, color: Color=INK, align: int=HORIZONTAL_ALIGNMENT_LEFT, width: float=-1) -> void:
 draw_string(ThemeDB.fallback_font,at+Vector2(1,1),value,align,width,size_px,Color(0,0,0,0.7))
 draw_string(ThemeDB.fallback_font,at,value,align,width,size_px,color)

func _draw() -> void:
 if not is_instance_valid(command) or not command.active() or not game.running:return
 var v:=command.vehicle
 if command.piloting:draw_drone();return
 match command.seat:
  "driver":draw_driver(v)
  "commander":draw_commander(v)
  "gunner":draw_sight(v)
  _:
   if game.player.global_position.distance_to(v.global_position)<16.0:draw_checklist(Vector2(size.x-430,top()))
 if v.notice_left>0 and v.notice!="":
  var room:=size.x-(500.0 if game.tos_training.visible else 0.0)
  text(Vector2(0,size.y*0.30),v.notice,18,AMBER,HORIZONTAL_ALIGNMENT_CENTER,room)

func top() -> float:
 var reserved: float=game.tos_training.reserved() if is_instance_valid(game.tos_training) else 0.0
 return maxf(140.0,reserved+30.0)

func draw_checklist(at: Vector2) -> void:
 var items:=command.checklist()
 if current!="":return
 draw_rect(Rect2(at-Vector2(12,26),Vector2(420,30+items.size()*22)),Color(0,0,0,0.45))
 text(at,"ПРИВЕДЕННЯ В БОЙОВЕ · НОРМАТИВ 90 с",14,game.GOLD)
 for i in range(items.size()):
  var done: bool=items[i][1]
  text(at+Vector2(0,22*(i+1)),("+ " if done else "· ")+str(items[i][0]),13,GREEN if done else DIM)

# A black frame round an opening (the eyepiece, the prism's window).
func mask(opening: Rect2, round: bool) -> void:
 var black:=Color(0.01,0.01,0.01)
 if round:
  var c:=opening.get_center();var r:=opening.size.x*0.5
  for k in range(64):
   var a0:=TAU*k/64;var a1:=TAU*(k+1)/64
   var far:=size.length()*3.0
   draw_colored_polygon(PackedVector2Array([c+Vector2(cos(a0),sin(a0))*r,c+Vector2(cos(a0),sin(a0))*far,c+Vector2(cos(a1),sin(a1))*far,c+Vector2(cos(a1),sin(a1))*r]),black)
  draw_arc(c,r,0,TAU,96,Color(0.15,0.15,0.13),4)
  return
 draw_rect(Rect2(-size.x,-size.y,size.x*3,opening.position.y+size.y),black)
 draw_rect(Rect2(-size.x,opening.end.y,size.x*3,size.y*2),black)
 draw_rect(Rect2(-size.x,opening.position.y,opening.position.x+size.x,opening.size.y),black)
 draw_rect(Rect2(opening.end.x,opening.position.y,size.x*2,opening.size.y),black)
 draw_rect(opening,Color(0.15,0.15,0.13),false,4)

func gauge(center: Vector2, radius: float, value: float, low: float, high: float, title: String, reading: String, red: float=INF) -> void:
 draw_circle(center,radius+4,Color(0.06,0.06,0.05,0.92))
 draw_arc(center,radius,deg_to_rad(135),deg_to_rad(405),48,Color(0.75,0.75,0.68),2)
 for k in range(11):
  var a:=deg_to_rad(135+270.0*k/10)
  var mark:=low+(high-low)*k/10.0
  draw_line(center+Vector2(cos(a),sin(a))*radius*0.82,center+Vector2(cos(a),sin(a))*radius,RED if mark>=red else INK,2)
 var t:=clampf((value-low)/(high-low),0,1)
 var angle:=deg_to_rad(135+270*t)
 draw_line(center,center+Vector2(cos(angle),sin(angle))*radius*0.86,AMBER,3)
 draw_circle(center,5,AMBER)
 text(center+Vector2(-radius,radius*0.55),title,12,DIM,HORIZONTAL_ALIGNMENT_CENTER,radius*2)
 text(center+Vector2(-radius,radius*0.95),reading,15,INK,HORIZONTAL_ALIGNMENT_CENTER,radius*2)

func lamp(at: Vector2, on: bool, title: String, color: Color=GREEN) -> void:
 draw_circle(at,7,color if on else Color(0.2,0.2,0.18))
 text(at+Vector2(12,5),title,12,INK if on else DIM)

func draw_driver(v: TosVehicle) -> void:
 # Closed down the eyes are in the compartment (TosInterior): a dot in the
 # middle of the view and the device it rests on.
 if command.closed_down() and command.lean<0.02:
  var c:=size*0.5
  draw_circle(c,3.6,Color(0,0,0,0.55));draw_circle(c,2.2,Color(1,1,1,0.75))
  var t: Dictionary=command.target
  if not t.is_empty():
   text(Vector2(0,c.y+40),"%s  ·  ПКМ — %s" % [t.title,"ДИВИТИСЯ" if t.kind=="prism" else "ВЕЛИКИМ ПЛАНОМ"],16,INK,HORIZONTAL_ALIGNMENT_CENTER,size.x)
 var base:=Vector2(size.x*0.5,size.y-120)
 if command.instruments_shown():draw_instruments(v,base)
 # The levers, always: where each one stands.
 var at:=Vector2(30,size.y-150)
 text(at,"ВАЖЕЛІ  Л: %s   П: %s" % [v.lever_text(v.levers.x),v.lever_text(v.levers.y)],15,AMBER if maxf(v.levers.x,v.levers.y)>0.06 else INK)
 text(at+Vector2(0,22),"ПЕРЕДАЧА %s · %d км/год · %d об/хв%s" % [TosVehicle.GEAR_NAMES[v.gear],roundi(absf(v.speed())*3.6),roundi(v.steady_rpm())," · ГАЛЬМА НА ЗАЩІПЦІ" if v.parking else ""],15)
 if not v.running and v.master:text(at+Vector2(0,44),"Двигун не працює: P — МЗН (тиск масла понад 1), X — стартер" if v.primed<=0.0 else "Масло прокачано: X — стартер",14,AMBER)
 elif not v.master:text(at+Vector2(0,44),"I — вимикач батарей (МАСА)",14,AMBER)
 if v.jacks>0.0:text(at+Vector2(0,66),"МАШИНА НА ДОМКРАТАХ — РУХ НЕМОЖЛИВИЙ",14,RED)
 elif not v.stops_locked and absf(v.speed())>1.0:text(at+Vector2(0,66),"РУХ ІЗ ЗНЯТИМИ СТОПОРАМИ ЗАБОРОНЕНО",14,RED)

func draw_instruments(v: TosVehicle, base: Vector2) -> void:
 draw_rect(Rect2(base-Vector2(470,92),Vector2(940,175)),Color(0.05,0.055,0.045,0.82))
 gauge(base+Vector2(-370,0),62,absf(v.speed())*3.6,0,80,"км/год","%d" % roundi(absf(v.speed())*3.6))
 gauge(base+Vector2(-215,0),62,v.steady_rpm(),0,3000,"об/хв","%d" % roundi(v.steady_rpm()),2200)
 gauge(base+Vector2(-60,0),50,v.oil_pressure,0,10,"МАСЛО","%.1f" % v.oil_pressure)
 gauge(base+Vector2(70,0),50,v.coolant,0,130,"ВОДА °C","%d" % roundi(v.coolant),115)
 text(base+Vector2(150,-50),"ПЕРЕДАЧА  %s" % TosVehicle.GEAR_NAMES[v.gear],24,AMBER)
 text(base+Vector2(150,-20),"ЗЧЕПЛЕННЯ %d %%  ГАЗ %d %%  РУЧНИЙ %d %%" % [roundi(v.clutch_pedal*100),roundi(maxf(v.throttle,v.hand_throttle)*100),roundi(v.hand_throttle*100)],13)
 text(base+Vector2(150,4),"НАПРУГА %.1f В · ПОВІТРЯ %d кгс/см²" % [v.volts,roundi(v.air_bottle)],13)
 lamp(base+Vector2(160,30),v.master,"МАСА",AMBER)
 lamp(base+Vector2(240,30),v.parking,"ЗАЩІПКА",RED)
 lamp(base+Vector2(340,30),v.priming,"МЗН")
 lamp(base+Vector2(400,30),v.jacks>0.0,"ДОМКРАТИ",RED)
 lamp(base+Vector2(160,54),v.oil_pressure<1.0 and v.running,"ТИСК МАСЛА",RED)
 lamp(base+Vector2(290,54),v.hatch_open,"ЛЮК")

func draw_commander(v: TosVehicle) -> void:
 if command.zoomed:
  var r:=minf(size.x,size.y)*0.42
  mask(Rect2(size*0.5-Vector2(r,r),Vector2(r,r)*2),true)
  var c:=size*0.5
  var ink:=Color(0.05,0.05,0.04)
  draw_line(c+Vector2(-r*0.6,0),c+Vector2(-8,0),ink,2);draw_line(c+Vector2(8,0),c+Vector2(r*0.6,0),ink,2)
  draw_line(c+Vector2(0,8),c+Vector2(0,r*0.5),ink,2)
  text(c+Vector2(-r,r+28),"ТКН-3А · ×5 · ПКМ — ×1",13,DIM,HORIZONTAL_ALIGNMENT_CENTER,r*2)
 draw_checklist(Vector2(size.x-430,top()))
 var at:=Vector2(30,size.y-230)
 text(at,"ПЛАТФОРМА %+.1f° · ПАКЕТ %.1f° · РАКЕТ %d · %s %d" % [v.platform_yaw,v.elevation,v.remaining(),"ПАРАМИ" if v.pairs else "ОДИНОЧНИМИ",v.series],15)
 text(at+Vector2(0,22),solution_text(v.solution),14,AMBER if not v.solution.is_empty() and not v.solution.has("error") else DIM)
 if command.selected_target>=0 and command.selected_target<command.targets.size():
  var t:Dictionary=command.targets[command.selected_target]
  var d:=command.firing_data(t.point)
  text(at+Vector2(0,44),"%s: Д %d м · α %s · курсовий %+.0f° · ENTER — в обчислювач" % [t.name,roundi(d.distance),GradBallistics.mils_text(d.bearing),d.relative],14,INK)
 if is_instance_valid(command.drone):
  text(at+Vector2(0,66),"ДРОН СП: АКБ %d %% · ЗВ’ЯЗОК %d %% · J — КЕРУВАТИ" % [roundi(command.drone.battery*100),roundi(command.drone.signal_strength*100)],14,DIM)
 elif command.drone_eta>=0:text(at+Vector2(0,66),"СП ГОТУЄ ДРОН: %d с" % ceili(command.drone_eta),14,DIM)
 var why:=v.ready_to_fire()
 text(at+Vector2(0,92),"ГОТОВИЙ ДО ПУСКУ · SPACE" if why=="" else "Пуск: %s" % why,16,GREEN if why=="" else DIM)

# The 1D14: the round field with its aiming mark and the range readout;
# the computer's data below it.
func draw_sight(v: TosVehicle) -> void:
 var c:=size*0.5
 var r:=minf(size.x,size.y)*0.42
 mask(Rect2(c-Vector2(r,r),Vector2(r,r)*2),true)
 var ink:=Color(0.05,0.05,0.04)
 var per_mil:=r/(TosVehicle.SIGHT_FOV/360.0*6000.0*0.5)
 # The aiming chevron and the side marks every 5 thousandths.
 draw_polyline(PackedVector2Array([c+Vector2(-14,14),c,c+Vector2(14,14)]),ink,2)
 draw_line(c+Vector2(-r,0),c+Vector2(-24,0),ink,2);draw_line(c+Vector2(24,0),c+Vector2(r,0),ink,2)
 for k in range(-6,7):
  if k==0:continue
  var x:=c.x+k*5*per_mil
  draw_line(Vector2(x,c.y),Vector2(x,c.y+(9 if k%2==0 else 5)),ink,2)
 # The laser's reading in the field, lit red.
 var reading: Dictionary=v.laser_reading
 var shown:="— — — —"
 if not reading.is_empty():
  var d: float=reading.get("distance",-1.0)
  shown="%04d" % roundi(d) if d>0.0 else ("НЕМАЄ" if d==-1.0 else "< 400")
 text(c+Vector2(-r*0.5,r*0.62),shown,26,Color(0.95,0.25,0.15),HORIZONTAL_ALIGNMENT_CENTER,r)
 if not v.fcs_ready():text(c+Vector2(-r,-r*0.6),"СУО НЕ ГОТОВА · %d %%" % roundi(v.fcs_warm*100),18,Color(0.95,0.25,0.15),HORIZONTAL_ALIGNMENT_CENTER,r*2)
 var col:=Vector2(24,60)
 draw_rect(Rect2(col-Vector2(10,30),Vector2(360,260)),Color(0,0,0,0.6))
 text(col,"ПРИЦІЛ-ДАЛЕКОМІР 1Д14 · ×8",15,game.GOLD)
 text(col+Vector2(0,30),"ПЛАТФОРМА %+.1f° → %+.1f°" % [v.platform_yaw,v.want_yaw],18)
 text(col+Vector2(0,56),"ПАКЕТ %.1f° → %.1f°" % [v.elevation,v.want_elevation],18)
 text(col+Vector2(0,82),"ГОЛОВКА ПРИЦІЛУ %+.1f°" % v.sight_pitch,15)
 var tilt:=v.global_basis.get_euler()
 text(col+Vector2(0,106),"КРЕН %+.1f° · ДИФЕРЕНТ %+.1f°" % [rad_to_deg(tilt.z),rad_to_deg(tilt.x)],15,AMBER if absf(rad_to_deg(tilt.z))>4.0 else INK)
 text(col+Vector2(0,130),"ПРИВОДИ: %s" % ("ЗАСТОПОРЕНО" if v.stops_locked or v.stop_motion>0.0 else ("ГОТОВІ" if v.drives_powered() else "НЕМАЄ ЖИВЛЕННЯ (ДВИГУН)")),15,RED if not v.can_traverse() else INK)
 text(col+Vector2(0,154),"ДОМКРАТИ %d %%" % roundi(v.jacks*100),15,INK if v.jacks>=1.0 else AMBER)
 var s: Dictionary=v.solution
 var lines:=solution_text(s)
 text(col+Vector2(0,182),lines.substr(0,58),13,AMBER if not s.is_empty() and not s.has("error") else DIM)
 if lines.length()>58:text(col+Vector2(0,200),lines.substr(58,58),13,AMBER if not s.is_empty() and not s.has("error") else DIM)
 var why:=v.ready_to_fire()
 text(col+Vector2(0,222),"ГОТОВИЙ ДО ПУСКУ · SPACE" if why=="" else why,15,GREEN if why=="" else DIM)

func draw_drone() -> void:
 var d:=command.drone
 if not is_instance_valid(d):return
 var c:=size*0.5
 var ink:=Color(0.92,0.96,0.88)
 draw_line(c+Vector2(-40,0),c+Vector2(-8,0),ink,2);draw_line(c+Vector2(8,0),c+Vector2(40,0),ink,2)
 draw_line(c+Vector2(0,-40),c+Vector2(0,-8),ink,2);draw_line(c+Vector2(0,8),c+Vector2(0,40),ink,2)
 draw_arc(c,3,0,TAU,12,ink,2)
 var lost:=d.signal_strength<0.04
 if lost:draw_rect(game.screen_rect(self),Color(0.4,0.42,0.38,0.85))
 elif d.signal_strength<0.3:draw_rect(game.screen_rect(self),Color(0.5,0.5,0.45,(0.3-d.signal_strength)*1.2*randf()))
 text(Vector2(30,40),"ДРОН СП · РЕТРАНСЛЯТОР · АКБ %d %% · ЗВ’ЯЗОК %d %%%s" % [roundi(d.battery*100),roundi(d.signal_strength*100)," · НЕМАЄ СИГНАЛУ" if lost else ""],17,ink)
 text(Vector2(30,64),"ВИСОТА %.0f м · %.0f км/год · ЗУМ %.1f× · АЗ %s" % [d.floor_height,d.velocity.length()*3.6,d.zoom,GradBallistics.mils_text(GradBallistics.bearing(-d.camera.global_basis.z))],15,ink)
 var reading:=command.rangefinder()
 if reading.is_empty():text(Vector2(30,size.y-110),"ЛД: — — —",17,ink)
 else:
  var p:Vector3=reading.point
  text(Vector2(30,size.y-110),"ЛД %.0f м · %s · h %.0f м" % [reading.distance,command.data.coordinates_text(p),command.data.altitude(p.y)],17,AMBER)
 text(Vector2(30,size.y-84),"T — ПОЗНАЧИТИ ЦІЛЬ · КОЛЕСО — ЗУМ · WASD / SPACE / CTRL — ПОЛІТ · SHIFT — ШВИДКО · J — ДО ПУЛЬТА",14,ink)
 if d.notice!="":text(Vector2(30,size.y-58),d.notice,15,ink)
 var alarm:=d.alarm()
 if alarm!="":text(Vector2(0,size.y*0.30),alarm,24,Color(RED,0.55+0.45*absf(sin(float(Time.get_ticks_msec())*0.008))),HORIZONTAL_ALIGNMENT_CENTER,size.x)
 var y:=maxf(100.0,top()-20.0)
 for t in command.targets:
  text(Vector2(size.x-330,y),"%s  %s" % [t.name,command.data.coordinates_text(t.point)],13,ink);y+=18
