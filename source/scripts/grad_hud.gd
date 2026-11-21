class_name GradHud
extends Control

# What the BM-21 commander sees and touches: the instruments in front of the
# driver, the field of the PG-1M panorama with the scales of the D726-45
# sight, the fire-control panel, the radio and the tablet.
const INK := Color("d9e4c9")
const DIM := Color("9aa58f")
const AMBER := Color("e8b45a")
const RED := Color("e0604e")
const GREEN := Color("8fd26a")
var game: Node3D
var command: GradCommand
var panels: Dictionary={}
var current := ""
var console_labels: Dictionary={}
var mode_buttons: Array[Button]=[]
var battery_button: Button
var lever_button: Button
var radio_log: Label
var tablet: GradTablet

func setup(owner_game: Node3D, owner: GradCommand) -> void:
 game=owner_game;command=owner
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 build_console()
 build_radio()
 tablet=GradTablet.new();tablet.name="Tablet"
 game.place(tablet,self,0.03,0.05,0.97,0.95)
 tablet.setup(game,command)
 tablet.hide();panels.tablet=tablet
 resized.connect(fit_tablet)

# The tablet is a device: on wide screens it stays about 2:1 and centred.
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

func build_console() -> void:
 var page:=panel(0.50,0.36,0.985,0.97)
 panels.console=page.get_parent()
 page.add_child(game.label("ПУЛЬТ УПРАВЛІННЯ ВОГНЕМ · БМ-21",20,game.GOLD))
 var lamps: Label=game.label("",15);page.add_child(lamps);console_labels.lamps=lamps
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);page.add_child(row)
 battery_button=small("ВБ-55 · БАТАРЕЯ",func():command.vehicle.toggle_battery());battery_button.toggle_mode=true;row.add_child(battery_button)
 row.add_child(small("КОНТР. ПИТ.",func():command.vehicle.test_lamp()))
 var modes:=HBoxContainer.new();modes.add_theme_constant_override("separation",6);page.add_child(modes)
 var caption: Label=game.label("КЛЮЧ",14,game.GOLD);caption.custom_minimum_size.x=70;modes.add_child(caption)
 for i in range(3):
  var b:=small(["ВИМК","АВТ","ОДИН"][i],func():command.vehicle.set_mode(i))
  b.toggle_mode=true;modes.add_child(b);mode_buttons.append(b)
 var program:=HBoxContainer.new();program.add_theme_constant_override("separation",6);page.add_child(program)
 program.add_child(small("ЗВЕСТИ ПРОГРАМНИЙ МЕХАНІЗМ",func():command.vehicle.wind_program()))
 var counter: Label=game.label("",16);counter.custom_minimum_size.x=210;program.add_child(counter);console_labels.counter=counter
 lever_button=game.button("ПУСК · УТРИМУЙ SPACE АБО КНОПКУ",func():pass,true)
 lever_button.custom_minimum_size=Vector2(0,54);lever_button.focus_mode=Control.FOCUS_NONE
 lever_button.action_mode=BaseButton.ACTION_MODE_BUTTON_PRESS
 page.add_child(lever_button)
 var note: Label=game.label("АВТ — серія через 0,5 с, поки тримаєш рукоятку (повний залп 20 с). ОДИН — кожне спрацювання одна ракета; перше після зведення лише ставить розподільник на трубу. Після «Стій» не виходь із кабіни 1–2 хв: можливий затяжний пуск. E / ESC — закрити.",12,DIM)
 note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(note)

func lever_button_down() -> bool:
 return current=="console" and is_instance_valid(lever_button) and lever_button.button_pressed

func build_radio() -> void:
 var page:=panel(0.20,0.12,0.80,0.86)
 panels.radio=page.get_parent()
 page.add_child(game.label("РАДІОСТАНЦІЯ Р-123М · МЕРЕЖА КОМБАТА",20,game.GOLD))
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);page.add_child(row)
 row.add_child(small("ШТУРМОВИМ ГРУПАМ — ВПЕРЕД",func():command.order_assault(true);close_all()))
 row.add_child(small("ГРУПАМ ЗАКРІПИТИСЯ",func():command.order_assault(false);close_all()))
 var row2:=HBoxContainer.new();row2.add_theme_constant_override("separation",6);page.add_child(row2)
 row2.add_child(small("СП: ПІДНЯТИ ДРОН",func():command.request_drone() if command.seat=="commander" else command.radio("СП","Дрон керується з термінала в кабіні командира.")))
 row2.add_child(small("СП: ДОПОВІСТИ ОБСТАНОВКУ",func():report()))
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
  # Left of the training card when it is on the screen.
  var shift:=0.12 if game.grad_training.running else 0.0
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

func refresh() -> void:
 if not command.active():return
 var v:=command.vehicle
 if current=="console":
  battery_button.set_pressed_no_signal(v.battery_on)
  for i in range(mode_buttons.size()):mode_buttons[i].set_pressed_no_signal(v.fire_mode==i)
  var lamp:=func(on: bool, text: String) -> String:return ("● " if on else "○ ")+text
  console_labels.lamps.text="   ".join([lamp.call(v.battery_on,"ЖИВЛЕННЯ"),lamp.call(v.battery_on and v.lamp_test>0,"КОНТРОЛЬ"),lamp.call(v.battery_on and v.in_cab_zone(),"ЗОНА КАБІНИ"),lamp.call(v.battery_on and v.travel_lock,"СТОПОР")])
  console_labels.counter.text="ТРУБА № %s · РАКЕТ %d" % [str(v.next_tube_number()) if v.program_wound else "—",v.remaining()]
 if current=="radio":radio_log.text="\n".join(command.radio_log)

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
  "driver":draw_dashboard(v)
  "commander":draw_commander(v)
  "gunner":draw_sight(v)
  _:
   if game.player.global_position.distance_to(v.global_position)<16.0:draw_checklist(v,Vector2(size.x-430,top()))
 if v.notice_left>0 and v.notice!="":
  # Left of the training card when it is on the screen.
  var room:=size.x-(500.0 if game.grad_training.visible else 0.0)
  text(Vector2(0,size.y*0.30),v.notice,18,AMBER,HORIZONTAL_ALIGNMENT_CENTER,room)

# Below the training card when it is on the screen.
func top() -> float:
 var reserved: float=game.grad_training.reserved() if is_instance_valid(game.grad_training) else 0.0
 return maxf(140.0,reserved+30.0)

func draw_checklist(v: GradVehicle, at: Vector2) -> void:
 var items:=command.checklist()
 if current!="":return
 draw_rect(Rect2(at-Vector2(12,26),Vector2(420,30+items.size()*22)),Color(0,0,0,0.45))
 text(at,"ПЕРЕВЕДЕННЯ В БОЙОВЕ ПОЛОЖЕННЯ",14,game.GOLD)
 for i in range(items.size()):
  var done: bool=items[i][1]
  text(at+Vector2(0,22*(i+1)),("+ " if done else "· ")+str(items[i][0]),13,GREEN if done else DIM)

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

# The readings of the dashboard large on the screen, while the right mouse
# button is held; the warnings below are shown always.
func draw_dashboard(v: GradVehicle) -> void:
 var base:=Vector2(size.x*0.5,size.y-120)
 if command.instruments_shown():draw_instruments(v,base)
 if not v.running and v.ignition:text(base+Vector2(-470,-110),"Двигун не працює: X — стартер (нейтраль або вижате зчеплення)",14,AMBER)
 if v.travel_lock==false or v.springs_locked or not v.cover_on and v.speed()>2.0:
  if absf(v.speed())>1.0 and (not v.travel_lock or v.springs_locked):text(base+Vector2(-470,-130),"РУХ У БОЙОВОМУ ПОЛОЖЕННІ ЗАБОРОНЕНО: застопори пакет і постав кран у «ПОХІД»",14,RED)

func draw_instruments(v: GradVehicle, base: Vector2) -> void:
 draw_rect(Rect2(base-Vector2(470,92),Vector2(940,175)),Color(0.05,0.055,0.045,0.82))
 gauge(base+Vector2(-370,0),62,absf(v.speed())*3.6,0,90,"км/год","%d" % roundi(absf(v.speed())*3.6))
 gauge(base+Vector2(-215,0),62,v.steady_rpm(),0,4000,"об/хв","%d" % roundi(v.steady_rpm()),3200)
 gauge(base+Vector2(-60,0),50,v.air,0,10,"ПОВІТРЯ","%.1f" % v.air)
 gauge(base+Vector2(70,0),50,v.tyre,0,4,"ШИНИ","%.1f" % v.tyre)
 text(base+Vector2(-110,78),"кгс/см²",11,DIM,HORIZONTAL_ALIGNMENT_CENTER,230)
 var gear: String=GradVehicle.GEAR_NAMES[v.gear]
 text(base+Vector2(150,-50),"ПЕРЕДАЧА  %s" % gear,24,AMBER)
 text(base+Vector2(150,-20),"РОЗДАТКА  %s" % ("ЗНИЖЕНА" if v.low_range else "ПРЯМА"),15)
 text(base+Vector2(150,4),"ЗЧЕПЛЕННЯ %d %%  ГАЗ %d %%  РУЧНИЙ %d %%" % [roundi(v.clutch_pedal*100),roundi(maxf(v.throttle,v.hand_throttle)*100),roundi(v.hand_throttle*100)],13)
 text(base+Vector2(150,26),"КРАН ШИН: %s" % ["СПУСК","ЗАКРИТО","НАКАЧКА"][v.inflation+1],13)
 lamp(base+Vector2(160,52),v.ignition,"ЗАПАЛ.",AMBER)
 lamp(base+Vector2(250,52),v.handbrake,"СТОЯНК.",RED)
 lamp(base+Vector2(345,52),v.power_takeoff,"КВП")
 lamp(base+Vector2(410,52),v.springs_locked,"БОЙОВЕ",AMBER)
 lamp(base+Vector2(160,74),v.air<4.5,"ТИСК ПОВІТРЯ",RED)
 lamp(base+Vector2(290,74),v.shields_down,"ЩИТКИ")

func draw_commander(v: GradVehicle) -> void:
 draw_checklist(v,Vector2(size.x-430,top()))
 var at:=Vector2(30,size.y-210)
 text(at,"ПАКЕТ: %s %d°%02d′ · КУТ %d°%02d′ · РАКЕТ %d" % ["ліво" if v.azimuth<0 else "право",int(absf(v.azimuth)),int(fmod(absf(v.azimuth),1.0)*60),int(v.elevation),int(fmod(v.elevation,1.0)*60),v.remaining()],15)
 if command.selected_target>=0 and command.selected_target<command.targets.size():
  var t:Dictionary=command.targets[command.selected_target]
  var d:=command.firing_data(t.point)
  text(at+Vector2(0,24),"%s: Д %d м · α %s · курсовий %+.0f°" % [t.name,roundi(d.distance),GradBallistics.mils_text(d.bearing),d.relative],15,AMBER)
 if is_instance_valid(command.drone):
  text(at+Vector2(0,48),"ДРОН СП: АКБ %d %% · ЗВ’ЯЗОК %d %% · J — КЕРУВАТИ" % [roundi(command.drone.battery*100),roundi(command.drone.signal_strength*100)],14,DIM)
 elif command.drone_eta>=0:text(at+Vector2(0,48),"СП ГОТУЄ ДРОН: %d с" % ceili(command.drone_eta),14,DIM)
 if v.battery_on and v.lamp_test>0:lamp(Vector2(size.x-140,size.y-60),true,"КОНТРОЛЬ",AMBER)

func draw_sight(v: GradVehicle) -> void:
 var c:=size*0.5
 var r:=minf(size.x,size.y)*0.42
 # The round field of view of the panorama, the rest of the eyepiece black.
 for k in range(64):
  var a0:=TAU*k/64;var a1:=TAU*(k+1)/64
  var p0:=c+Vector2(cos(a0),sin(a0))*r;var p1:=c+Vector2(cos(a1),sin(a1))*r
  # Far past the edges: the frame may be narrower than the screen.
  var q0:=c+Vector2(cos(a0),sin(a0))*size.length()*3.0;var q1:=c+Vector2(cos(a1),sin(a1))*size.length()*3.0
  draw_colored_polygon(PackedVector2Array([p0,q0,q1,p1]),Color(0.01,0.01,0.01))
 draw_arc(c,r,0,TAU,96,Color(0.15,0.15,0.13),4)
 # Reticle of the PG-1M: crosshair with thousandth marks (10° field).
 var per_mil:=r/(10.0/360.0*6000.0*0.5)
 var ink:=Color(0.05,0.05,0.04)
 draw_line(c+Vector2(-r,0),c+Vector2(-6,0),ink,2);draw_line(c+Vector2(6,0),c+Vector2(r,0),ink,2)
 draw_line(c+Vector2(0,-r),c+Vector2(0,-6),ink,2)
 for k in range(-8,9):
  if k==0:continue
  var x:=c.x+k*10*per_mil
  draw_line(Vector2(x,c.y-(10 if k%5==0 else 5)),Vector2(x,c.y),ink,2)
 # Boussole window: the needle swings to the index when the line of sight
 # points to magnetic north.
 var win:=c+Vector2(-r*0.62,r*0.62)
 draw_rect(Rect2(win-Vector2(110,26),Vector2(220,52)),Color(0.85,0.82,0.7,0.95))
 draw_line(win+Vector2(0,-24),win+Vector2(0,24),ink,2)
 if v.boussole:
  var offset:=wrapf(v.sight_bearing()-GradVehicle.BOUSSOLE_CORRECTION,-3000.0,3000.0)
  v.needle=lerpf(v.needle,clampf(offset,-300,300),0.08)+sin(command.clock*9.0)*0.6
  draw_line(win+Vector2(-v.needle*0.33,-20),win+Vector2(-v.needle*0.33,20),RED,3)
  text(win+Vector2(-108,40),"БУСОЛЬ ВІДКРИТО",12,AMBER)
 else:text(win+Vector2(-108,40),"БУСОЛЬ ЗААРЕТОВАНО · B",12,DIM)
 # Level bubble of the sight: centred when the package stands at the set
 # sight plus the angle of site.
 var bub:=c+Vector2(r*0.62,r*0.62)
 draw_rect(Rect2(bub-Vector2(110,18),Vector2(220,36)),Color(0.75,0.85,0.55,0.95))
 draw_line(bub+Vector2(-14,-18),bub+Vector2(-14,18),ink,2);draw_line(bub+Vector2(14,-18),bub+Vector2(14,18),ink,2)
 var shift:=clampf(-v.bubble_mils()*4.0,-96,96)
 draw_circle(bub+Vector2(shift,0),12,Color(0.95,0.97,0.85))
 draw_arc(bub+Vector2(shift,0),12,0,TAU,24,ink,1.5)
 # Scales.
 var col:=Vector2(24,60)
 draw_rect(Rect2(col-Vector2(10,30),Vector2(330,330)),Color(0,0,0,0.6))
 text(col,"ПАНОРАМА ПГ-1М · ПРИЦІЛ Д726-45",15,game.GOLD)
 text(col+Vector2(0,32),"КУТОМІР   %s" % GradBallistics.mils_text(v.deflection),22)
 text(col+Vector2(0,62),"ПРИЦІЛ    %s" % sight_text(v.sight_setting),22)
 text(col+Vector2(0,92),"РІВЕНЬ    %s" % GradBallistics.mils_text(v.level_setting),22)
 var power:=v.drive_power()
 text(col+Vector2(0,124),"ПРИВІД: %s" % ("РУЧНИЙ" if v.manual_drive or power<=0 else "ЕЛЕКТРО %d %%" % roundi(power*100)),15,AMBER if power<=0 else INK)
 text(col+Vector2(0,148),"ШКАЛА ПОВОРОТУ: %s %d°%02d′" % ["ліво" if v.azimuth<0 else "право",int(absf(v.azimuth)),int(fmod(absf(v.azimuth),1.0)*60)],15)
 text(col+Vector2(0,172),"КВАДРАНТ: %d°%02d′" % [int(v.elevation),int(fmod(v.elevation,1.0)*60)],15)
 text(col+Vector2(0,196),"КРЕН МАШИНИ: %.1f°" % v.cant_degrees(),15,AMBER if absf(v.cant_degrees())>3.0 else INK)
 if v.travel_lock:text(col+Vector2(0,224),"ПАКЕТ ЗАСТОПОРЕНО",15,RED)
 elif v.in_cab_zone():text(col+Vector2(0,224),"ЗОНА КАБІНИ: пуск заблоковано нижче 11°",14,RED)
 text(col+Vector2(0,252),"Кутомір = α − ПБ ± 30-00 · ПБ %s" % GradBallistics.mils_text(GradVehicle.BOUSSOLE_CORRECTION),13,DIM)
 text(col+Vector2(0,272),"Рівень = 30-00 + кут місця цілі",13,DIM)

static func sight_text(value: float) -> String:
 var whole:=floori(value)
 var half:=value-whole>=0.25
 return "%d-%02d%s" % [whole/100,whole%100,",5" if half else ""]

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
