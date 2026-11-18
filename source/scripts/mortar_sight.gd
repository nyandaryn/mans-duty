class_name MortarSight
extends Control

# Laying the mortar: charge, sight setting (elevation) and bearing in
# thousandths, with the firing table printed for the chosen charge. The sight
# never shows where a mine lands: corrections come from watching the bursts.
var game: Node3D
var crew: MortarCrew
var settings: Label
var details: Label
var mines: Label
var log_label: Label
var table_title: Label
var table: GridContainer
var elevation_box: SpinBox
var azimuth_box: SpinBox
var charge_buttons: Array[Button]=[]
var fire_button: Button
var shown_charge := -1
var history: Array[String]=[]

func setup(owner_game: Node3D, owner_crew: MortarCrew) -> void:
 game=owner_game;crew=owner_crew
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 var sheet := PanelContainer.new()
 sheet.add_theme_stylebox_override("panel",game.panel_style(Color(0.035,0.05,0.04,0.94),game.GOLD))
 game.place(sheet,self,0.32,0.04,0.985,0.96)
 sheet.mouse_filter=Control.MOUSE_FILTER_STOP
 var page := VBoxContainer.new();page.add_theme_constant_override("separation",8)
 sheet.add_child(page)
 page.add_child(wrapped("МІНОМЕТ 2Б14 «ПІДНОС» · ПРИЦІЛ МПМ-44М",19,game.GOLD))
 var columns := HBoxContainer.new();columns.add_theme_constant_override("separation",18)
 columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;page.add_child(columns)
 # Left: settings and actions. Right: the firing table for the chosen charge.
 var rows := VBoxContainer.new();rows.add_theme_constant_override("separation",7)
 rows.custom_minimum_size.x=460;columns.add_child(rows)
 settings=wrapped("",21);rows.add_child(settings)
 details=wrapped("",13);rows.add_child(details)
 var charges := HBoxContainer.new();charges.add_theme_constant_override("separation",6);rows.add_child(charges)
 var caption: Label=game.label("ЗАРЯД",14,game.GOLD);caption.custom_minimum_size.x=76;charges.add_child(caption)
 for i in range(MortarBallistics.CHARGES.size()):
  var button: Button=game.button(MortarBallistics.CHARGES[i],choose_charge.bind(i))
  button.toggle_mode=true;button.custom_minimum_size=Vector2(52,38);button.focus_mode=Control.FOCUS_NONE
  button.alignment=HORIZONTAL_ALIGNMENT_CENTER
  charges.add_child(button);charge_buttons.append(button)
 elevation_box=setting_row(rows,"ПРИЦІЛ",MortarBallistics.ELEVATION_MIN,MortarBallistics.ELEVATION_MAX,func(v: float):crew.mortar.set_elevation(int(v));refresh(),nudge_elevation)
 azimuth_box=setting_row(rows,"АЗИМУТ",0,MortarBallistics.CIRCLE-1,func(v: float):crew.mortar.set_azimuth(int(v));refresh(),nudge_azimuth)
 azimuth_box.allow_greater=false
 mines=wrapped("",15);rows.add_child(mines)
 fire_button=game.button("ПОСТРІЛ · SPACE",fire,true)
 fire_button.alignment=HORIZONTAL_ALIGNMENT_CENTER;fire_button.focus_mode=Control.FOCUS_NONE
 rows.add_child(fire_button)
 var actions := HBoxContainer.new();actions.add_theme_constant_override("separation",8);rows.add_child(actions)
 for entry in [["МІНА З ЯЩИКА",func():crew.take_from_box()],["ЗАКРИТИ · F / ESC",close]]:
  var action: Button=game.button(entry[0],entry[1])
  action.custom_minimum_size=Vector2(0,40);action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  action.add_theme_font_size_override("font_size",15);action.focus_mode=Control.FOCUS_NONE
  actions.add_child(action)
 actions.get_child(0).tooltip_text="Взяти міну з ящика біля міномета в наплічник."
 log_label=wrapped("",13,Color("b0bba7"));rows.add_child(log_label)
 var side := VBoxContainer.new();side.add_theme_constant_override("separation",6)
 side.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(side)
 table_title=wrapped("",14,game.GOLD);side.add_child(table_title)
 var scroll := ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;side.add_child(scroll)
 table=GridContainer.new();table.columns=4
 table.add_theme_constant_override("h_separation",18);table.add_theme_constant_override("v_separation",1)
 scroll.add_child(table)
 side.add_child(wrapped("Дальність — до рівня міномета, без поправок на вітер, температуру заряду й перевищення цілі.\n↑ ↓ — приціл ±1 (Shift ±10) · ← → — азимут ±1 (Shift ±10) · PgUp / PgDn — заряд",12,Color("b0bba7")))
 hide()

# Long lines wrap to the column instead of widening the panel.
func wrapped(text: String, font_size: int, color: Color=Color(0,0,0,0)) -> Label:
 var node: Label=game.label(text,font_size) if color.a==0 else game.label(text,font_size,color)
 node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 node.custom_minimum_size.x=40
 return node

func setting_row(rows: VBoxContainer, title: String, low: int, high: int, changed: Callable, nudge: Callable) -> SpinBox:
 var line := HBoxContainer.new();line.add_theme_constant_override("separation",6);rows.add_child(line)
 var caption: Label=game.label(title,14,game.GOLD);caption.custom_minimum_size.x=76;line.add_child(caption)
 var box := SpinBox.new();box.min_value=low;box.max_value=high;box.step=1;box.rounded=true
 box.custom_minimum_size=Vector2(116,38);box.add_theme_font_size_override("font_size",18)
 box.value_changed.connect(changed);line.add_child(box)
 for step in [-10,-1,1,10]:
  var button: Button=game.button("%+d" % step,nudge.bind(step))
  button.custom_minimum_size=Vector2(52,38);button.focus_mode=Control.FOCUS_NONE
  button.alignment=HORIZONTAL_ALIGNMENT_CENTER;button.add_theme_font_size_override("font_size",15)
  line.add_child(button)
 return box

func open() -> bool:
 if not crew.active() or crew.mortar.state!="deployed":return false
 if game.player.field_rig.active() or game.commands_open:return false
 game.commands_open=true
 game.player.burst=0;game.player.firing_sequence_active=false;game.player.aim=false
 show()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 elevation_box.set_value_no_signal(crew.mortar.elevation)
 azimuth_box.set_value_no_signal(crew.mortar.azimuth)
 shown_charge=-1
 refresh()
 return true

func close() -> void:
 if not visible:return
 hide()
 game.commands_open=false
 if game.running and not game.paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func choose_charge(index: int) -> void:
 crew.mortar.set_charge(index);refresh()

func nudge_elevation(step: int) -> void:
 crew.mortar.set_elevation(crew.mortar.elevation+step)
 elevation_box.set_value_no_signal(crew.mortar.elevation);refresh()

func nudge_azimuth(step: int) -> void:
 crew.mortar.set_azimuth(crew.mortar.azimuth+step)
 azimuth_box.set_value_no_signal(crew.mortar.azimuth);refresh()

func fire() -> void:
 var mortar := crew.mortar
 if crew.player_fire():
  history.push_front("Постріл %d · заряд %s · приціл %s · азимут %s · політ ≈ %.1f с" % [mortar.shots,MortarBallistics.CHARGES[mortar.charge],MortarBallistics.mils_text(mortar.elevation),MortarBallistics.mils_text(mortar.azimuth),MortarBallistics.time_for(mortar.charge,mortar.elevation)])
  history.resize(mini(history.size(),4))
 refresh()

func refresh() -> void:
 if not crew.active():return
 var mortar := crew.mortar
 settings.text="ЗАРЯД %s · ПРИЦІЛ %s · АЗИМУТ %s" % [MortarBallistics.CHARGES[mortar.charge],MortarBallistics.mils_text(mortar.elevation),MortarBallistics.mils_text(mortar.azimuth)]
 var offset := mortar.traverse_offset()
 var state := "Поворотний механізм: %+d тис. від напрямку двоноги (межа ±%d, далі — перенесення двоноги)." % [offset,Mortar.TRAVERSE]
 if mortar.relay_left>0:state="ПЕРЕНЕСЕННЯ ДВОНОГИ · %.1f с" % mortar.relay_left
 elif mortar.reload_left>0:state="ЗАРЯДЖАННЯ · %.1f с" % mortar.reload_left
 var limits := MortarBallistics.range_limits(mortar.charge)
 details.text="%s\nЗаряд %s: дальність %d – %d м · початкова швидкість %d м/с · кут %.1f°" % [state,MortarBallistics.CHARGES[mortar.charge],roundi(limits.x),roundi(limits.y),roundi(MortarBallistics.VELOCITY[mortar.charge]),mortar.elevation*0.06]
 for i in range(charge_buttons.size()):charge_buttons[i].set_pressed_no_signal(i==mortar.charge)
 var box := crew.box_mines_at_mortar()
 mines.text="Міни: ящик біля міномета %d · наплічник %d" % [box,game.player.backpack.count("mortar_mine")]
 fire_button.disabled=not mortar.ready_to_fire() or (box<=0 and game.player.backpack.count("mortar_mine")<=0)
 log_label.text="\n".join(history)
 if shown_charge!=mortar.charge:
  shown_charge=mortar.charge
  table_title.text="ТАБЛИЦЯ СТРІЛЬБИ · ЗАРЯД %s · МІНА О-832ДУ" % MortarBallistics.CHARGES[mortar.charge]
  for child in table.get_children():table.remove_child(child);child.queue_free()
  for heading in ["Д, м","ПРИЦІЛ","ΔД / тис., м","ЧАС, с"]:table.add_child(game.label(heading,13,game.GOLD))
  for row in MortarBallistics.firing_rows(mortar.charge):
   for text in [str(row.range),MortarBallistics.mils_text(row.elevation),"%.1f" % row.per_mil,"%.1f" % row.time]:
    table.add_child(game.label(text,14))

func _process(_delta: float) -> void:
 if visible and crew.active():
  if crew.mortar.relay_left>0 or crew.mortar.reload_left>0 or fire_button.disabled:refresh()

func _input(event: InputEvent) -> void:
 if not visible or not (event is InputEventKey) or not event.pressed:return
 var key: int=event.physical_keycode
 var fast := 10 if event.shift_pressed else 1
 var handled := true
 match key:
  KEY_SPACE:
   if not event.echo:fire()
  KEY_F,KEY_ESCAPE:
   if not event.echo:close()
  KEY_UP:nudge_elevation(fast)
  KEY_DOWN:nudge_elevation(-fast)
  KEY_RIGHT:nudge_azimuth(fast)
  KEY_LEFT:nudge_azimuth(-fast)
  KEY_PAGEUP:choose_charge(crew.mortar.charge+1)
  KEY_PAGEDOWN:choose_charge(crew.mortar.charge-1)
  _:handled=false
 if handled:get_viewport().set_input_as_handled()
