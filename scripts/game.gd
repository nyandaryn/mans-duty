extends Node3D

var debris: CartridgeDebris
var ballistics: Ballistics
var effects: Array[Dictionary] = []
var bullet_marks: Array[Node3D] = []
var district: District
var player: Operator
var bots: Array[Hostile] = []
var world_root: Node3D
var menu_camera: Camera3D
var sunlight: DirectionalLight3D
var running := false
var paused := false
var debug_invulnerable := false
var debug_checkbox: CheckButton
var killed := 0
var elapsed := 0.0
var damage_flash := 0.0
var symptom_material: ShaderMaterial
var blood: BloodSystem
var hit_marker := 0.0
var primary_tile: Button
var secondary_tile: Button
var outfit_caption: Label
var outfit_buttons: Array[Button] = []
var map_buttons: Array[Button] = []
var player_outfit := "ua_pixel"
var enemy_outfit := "rf_digital"
var outfit_preview: SubViewport
var preview_actor: Hostile
var selected_map := "city"
var map_option: OptionButton
var map_description: Label
var primary := "ak74"
var secondary := "pm"
var sensitivity := 0.0022
var volume := 0.65
var menu: Control
var pause_panel: Control
var result_panel: Control
var hud: Control
var hud_text: Label
var objective: Label
var health_label: Label
var result_title: Label
var result_stats: Label
var resume_button: Button
var hearing: CombatHearing
var sounds: Dictionary = {}
var audio_pool: Array[AudioStreamPlayer] = []
var audio_index := 0
var spatial_pool: Array[AudioStreamPlayer3D] = []
var spatial_index := 0
var orbit := 0.0
var settings := ConfigFile.new()
const CREAM = Color("e4e5d6")
const GOLD = Color("c8b17a")

func _ready() -> void:
	if not get_meta("automated_preview",false):load_settings()
	setup_input()
	setup_environment()
	setup_audio()
	build_district()
	ballistics=Ballistics.new()
	ballistics.game=self
	add_child(ballistics)
	setup_ui()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func setup_input() -> void:
	var actions := {"report_clear":KEY_ENTER,"inspect_mag":KEY_T,"inspect_chamber":KEY_I,"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"debug_god":KEY_F8,"prone":KEY_Z,"crouch":KEY_CTRL,"jump":KEY_SPACE,"reload":KEY_R,"rack":KEY_V,"mode":KEY_B,"primary":KEY_1,"secondary":KEY_2,"pause":KEY_ESCAPE,"lean_left":KEY_Q,"lean_right":KEY_E,"peek_up":KEY_C,"blind_modifier":KEY_ALT,"bandage":KEY_H}
	for action in actions:
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode=actions[action]
		InputMap.action_add_event(action,key)
	for action in ["fire","aim"]:
		InputMap.add_action(action)
		var mouse := InputEventMouseButton.new()
		mouse.button_index=MOUSE_BUTTON_LEFT if action=="fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action,mouse)

func setup_environment() -> void:
	var env := WorldEnvironment.new()
	var resource := Environment.new()
	resource.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("7897b0")
	sky_mat.sky_horizon_color=Color("c6d1dc")
	sky_mat.ground_horizon_color=Color("b2bdc7")
	sky_mat.ground_bottom_color=Color("5a6555")
	sky.sky_material=sky_mat
	resource.sky=sky
	resource.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	resource.ambient_light_color=Color("c4d2e4")
	resource.ambient_light_energy=0.30
	resource.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	resource.fog_enabled=false
	resource.fog_light_color=Color("9caeac")
	resource.fog_density=0.0018
	env.environment=resource
	add_child(env)
	sunlight=DirectionalLight3D.new()
	sunlight.rotation_degrees=Vector3(-42,-32,0)
	sunlight.light_color=Color("fff8ef")
	sunlight.light_energy=0.62
	sunlight.shadow_enabled=true
	sunlight.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sunlight.directional_shadow_max_distance=90.0
	sunlight.shadow_blur=1.3
	add_child(sunlight)
	menu_camera=Camera3D.new()
	menu_camera.fov=65
	add_child(menu_camera)
	menu_camera.position=Vector3(5,10,39)
	menu_camera.look_at(Vector3(0,4,-4))
	menu_camera.current=true

func build_district() -> void:
	world_root=Node3D.new()
	add_child(world_root)
	district=District.new()
	world_root.add_child(district)
	district.build(selected_map)
	blood=BloodSystem.new()
	blood.game=self
	world_root.add_child(blood)
	debris=CartridgeDebris.new()
	debris.game=self
	world_root.add_child(debris)

func start_match() -> void:
	hearing.reset()
	debris.clear()
	blood.clear()
	ballistics.clear()
	for effect in effects:
		if is_instance_valid(effect.node):effect.node.queue_free()
	effects.clear()
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	for bot in bots:
		if is_instance_valid(bot):
			remove_child(bot)
			bot.queue_free()
	bots.clear()
	if district.map_id!=selected_map:
		world_root.free()
		build_district()
	killed=0
	elapsed=0
	damage_flash=0
	hit_marker=0
	paused=false
	player=Operator.new()
	add_child(player)
	player.position=district.player_spawn
	player.rotation.y=district.player_spawn_yaw
	player.setup(self,primary,secondary)
	player.sensitivity=sensitivity
	for point in district.spawn_points:
		var bot := Hostile.new()
		add_child(bot)
		bot.setup(self,point)
		bots.append(bot)
	menu.hide()
	pause_panel.hide()
	result_panel.hide()
	hud.show()
	running=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	save_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_god") and not event.is_echo():set_debug_invulnerable(not debug_invulnerable)
	if event.is_action_pressed("report_clear") and running and not paused and player.position.distance_to(district.player_spawn)<5:finish(killed>=bots.size())
	if event.is_action_pressed("pause") and running:
		set_pause(not paused)
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and running and not get_meta("automated_preview",false): set_pause(true)

func set_pause(value: bool) -> void:
	paused=value
	pause_panel.visible=value
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if value:resume_button.grab_focus()

func to_menu() -> void:
	running=false
	paused=false
	pause_panel.hide()
	result_panel.hide()
	hud.hide()
	menu.show()
	menu_camera.current=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func finish(won: bool) -> void:
	running=false
	paused=false
	pause_panel.hide()
	result_panel.show()
	hud.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	result_title.text="ЛОКАЦІЮ ЗАЧИЩЕНО" if won else "ОПЕРАЦІЮ ЗІРВАНО"
	var accuracy := roundi(float(player.hits)/maxi(1,player.shots)*100)
	result_stats.text="НЕЙТРАЛІЗОВАНО     %02d / %02d\nЧАС ОПЕРАЦІЇ         %02d:%02d\nПОСТРІЛІВ             %d\nВЛУЧНІСТЬ              %d %%" % [killed,bots.size(),int(elapsed)/60,int(elapsed)%60,player.shots,accuracy]

func bot_down() -> void:
	killed+=1
	# Completion is reported by the player at insertion, never by a hidden kill counter.

func _process(delta: float) -> void:
	hearing.update(delta,running and not paused,volume)
	for output in audio_pool:output.stream_paused=paused
	for output in spatial_pool:output.stream_paused=paused
	for actor in bots:
		var voice := actor.get_node_or_null("PainVoice") as AudioStreamPlayer3D
		if voice:voice.stream_paused=paused
	if is_instance_valid(player):
		var voice := player.get_node_or_null("PainVoice") as AudioStreamPlayer3D
		if voice:voice.stream_paused=paused
	if not running and menu.visible:
		orbit+=delta*0.025
		menu_camera.position=Vector3(sin(orbit)*6,9,38)
		menu_camera.look_at(Vector3(0,4,-4))
	if running and not paused:
		elapsed+=delta
		damage_flash=maxf(0,damage_flash-delta)
		hit_marker=maxf(0,hit_marker-delta)
		symptom_material.set_shader_parameter("severity",pain_darkness())
		var w := player.current()
		objective.text="%s\nЗачистіть локацію й поверніться до старту.\nENTER біля старту — завершити операцію." % district.map_title
		hud_text.text="%s  /  %s\n%s\nR + 1 / 2 / 3 · ОБМІН МАГАЗИНА\nI · ПАТРОННИК   T · МАГАЗИН\nT + 1 / 2 / 3 · ПІДСУМОК" % [w.data.name,w.data.caliber,w.status()]
		health_label.text="СТАН  %03d" % ceili(player.health)
		health_label.modulate=Color("d49a7b") if player.health<35 else CREAM
	hud.queue_redraw()

func alert_bots(where: Vector3) -> void:
	for bot in bots: bot.hear(where)

func eject_case(where: Vector3, basis: Basis, weapon_id: String="ak74", live: bool=false) -> void:
	debris.eject(where,basis,weapon_id,live)

func impact(where: Vector3, normal: Vector3=Vector3.UP) -> void:
	# A ray starting inside a collider returns no valid surface normal.
	# Do not fabricate a horizontal decal in mid-air in that case.
	if normal.length_squared()<0.1:return
	normal=normal.normalized()
	# Small dark impact mark and short-lived dust, no bright projectile.
	var mark := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius=0.015
	disk.bottom_radius=0.015
	disk.height=0.001
	disk.radial_segments=8
	mark.mesh=disk
	mark.material_override=Models.surface("34352f")
	world_root.add_child(mark)
	mark.global_position=where+normal*0.003
	mark.quaternion=Quaternion(Vector3.UP,normal)
	bullet_marks.append(mark)
	if bullet_marks.size()>100:
		var old: Node3D=bullet_marks.pop_front()
		if is_instance_valid(old):old.queue_free()
	for i in range(3):
		var particle := Models.part(world_root,where+normal*0.025,Vector3.ONE*randf_range(0.012,0.03),"a39c88")
		effects.append({"node":particle,"velocity":normal*randf_range(0.5,1.4)+Vector3(randf_range(-0.5,0.5),0.3,randf_range(-0.5,0.5)),"life":0.3,"spin":Vector3(3,5,2),"type":"dust"})

func _physics_process(delta: float) -> void:
	if not running or paused:return
	for i in range(effects.size()-1,-1,-1):
		var effect: Dictionary=effects[i]
		if not is_instance_valid(effect.node):
			effects.remove_at(i)
			continue
		effect.life-=delta
		effect.velocity+=Vector3(0,-9.81,0)*delta
		effect.node.position+=effect.velocity*delta
		effect.node.rotation+=effect.spin*delta
		if effect.node.position.y<0.03:
			effect.node.position.y=0.03
			effect.velocity=Vector3.ZERO
			effect.spin=Vector3.ZERO
		if float(effect.life)<=0:
			effect.node.queue_free()
			effects.remove_at(i)

func load_settings() -> void:
	if settings.load("user://settings.cfg")==OK:
		player_outfit=Wardrobe.valid(str(settings.get_value("loadout","outfit","ua_pixel")))
		enemy_outfit=Wardrobe.valid(str(settings.get_value("operation","enemy_outfit","rf_digital")))
		selected_map=str(settings.get_value("operation","map","city"))
		if selected_map not in ["city","shelterbelt"]:selected_map="city"
		primary=str(settings.get_value("loadout","primary","ak74"))
		secondary=str(settings.get_value("loadout","secondary","pm"))
		if primary not in ["ak74","m16"]:primary="ak74"
		if secondary not in ["pm","m9"]:secondary="pm"
		sensitivity=clampf(float(settings.get_value("settings","sensitivity",0.0022)),0.0008,0.005)
		volume=clampf(float(settings.get_value("settings","volume",0.65)),0,1)

func save_settings() -> void:
	if get_meta("automated_preview",false):return
	settings.set_value("loadout","outfit",player_outfit)
	settings.set_value("operation","enemy_outfit",enemy_outfit)
	settings.set_value("operation","map",selected_map)
	settings.set_value("loadout","primary",primary)
	settings.set_value("loadout","secondary",secondary)
	settings.set_value("settings","sensitivity",sensitivity)
	settings.set_value("settings","volume",volume)
	settings.save("user://settings.cfg")

func setup_audio() -> void:
	hearing=CombatHearing.new()
	add_child(hearing)
	for kind in ["click","hurt"]:
		var count := 6500 if kind in ["rifle","pistol"] else 2200
		var bytes := PackedByteArray()
		bytes.resize(count*2)
		var smooth := 0.0
		for i in range(count):
			var t := float(i)/22050
			var decay := exp(-t*(23 if kind=="rifle" else 32))
			smooth=lerpf(smooth,randf_range(-1,1),0.55)
			var sample := (smooth*0.7+sin(t*TAU*(80 if kind=="rifle" else 135))*0.3)*decay
			if kind=="click":sample=smooth*exp(-t*95)*0.7
			if kind=="hurt":sample=sin(t*TAU*65)*exp(-t*35)*0.7
			bytes.encode_s16(i*2,int(clampf(sample,-1,1)*30000))
		var wav := AudioStreamWAV.new()
		wav.format=AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate=22050
		wav.data=bytes
		sounds[kind]=wav
	for key in ["ak74","m16","pm","m9","mag_in","mag_out","bolt","bolt_pull","pain_1","pain_2","pain_3","pain_4"]:
		sounds[key]=load("res://assets/audio/"+key+".wav")
	for i in range(32):
		var output := AudioStreamPlayer.new()
		add_child(output)
		output.bus=hearing.bus_name
		audio_pool.append(output)
	for i in range(24):
		var output := AudioStreamPlayer3D.new()
		output.max_distance=280
		output.unit_size=3
		output.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(output)
		output.bus=hearing.bus_name
		spatial_pool.append(output)

func sound(kind: String, db: float) -> void:
	if kind in ["ak74","m16","pm","m9"]:
		hearing.shot(0,true)
		db+=3
	if volume<=0:return
	var output := audio_pool[audio_index]
	audio_index=(audio_index+1)%audio_pool.size()
	output.stream=sounds[kind]
	output.volume_db=db+linear_to_db(volume)
	output.pitch_scale=randf_range(0.99,1.01)
	output.play()

func spatial_shot(weapon: String, where: Vector3, db: float=-5) -> void:
	if weapon in ["ak74","m16","pm","m9"] and is_instance_valid(player):
		hearing.shot(player.camera.global_position.distance_to(where))
	if volume<=0:return
	var output := spatial_pool[spatial_index]
	spatial_index=(spatial_index+1)%spatial_pool.size()
	output.stream=sounds[weapon]
	output.global_position=where
	output.volume_db=db+linear_to_db(volume)
	output.pitch_scale=randf_range(0.99,1.01)
	output.play()

func label(text: String, font_size: int = 18, color: Color = CREAM) -> Label:
	var node := Label.new()
	node.text=text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	return node

func panel_style(color: Color, border: Color = Color("555e50")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=border
	style.set_border_width_all(1)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=12
	style.content_margin_bottom=12
	return style

func button(text: String, callback: Callable, accent: bool = false) -> Button:
	var node := Button.new()
	node.text=text
	node.custom_minimum_size=Vector2(0,46)
	node.alignment=HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_font_size_override("font_size",18)
	node.add_theme_stylebox_override("normal",panel_style(Color("bba873") if accent else Color("252f29")))
	node.add_theme_stylebox_override("hover",panel_style(Color("d2bd86") if accent else Color("414d3d"),GOLD))
	node.add_theme_stylebox_override("pressed",panel_style(Color("8c815e")))
	node.add_theme_stylebox_override("focus",panel_style(Color(0,0,0,0),GOLD))
	node.add_theme_color_override("font_color",Color("1c2722") if accent else CREAM)
	node.add_theme_color_override("font_hover_color",Color("1c2722") if accent else CREAM)
	node.pressed.connect(callback)
	return node

func place(node: Control, parent: Node, left: float, top: float, right: float, bottom: float) -> void:
	parent.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.anchor_left=left
	node.anchor_top=top
	node.anchor_right=right
	node.anchor_bottom=bottom

func setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	canvas.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu=Control.new()
	place(menu,root,0,0,1,1)
	build_loadout(menu)
	# HUD is deliberately separate from interactive controls.
	hud=Control.new()
	hud.set_script(load("res://scripts/hud.gd"))
	hud.game=self
	place(hud,root,0,0,1,1)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var symptoms := ColorRect.new()
	symptoms.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var symptom_shader := Shader.new()
	symptom_shader.code="shader_type canvas_item; uniform float severity=0.0; void fragment(){float d=length((UV-vec2(0.5))*vec2(1.25,1.0));float edge=smoothstep(0.20,0.65,d);COLOR=vec4(0.015,0.018,0.022,clamp(severity*(0.72+edge*0.45),0.0,0.95));}"
	symptom_material=ShaderMaterial.new()
	symptom_material.shader=symptom_shader
	symptoms.material=symptom_material
	place(symptoms,hud,0,0,1,1)
	objective=label("",19)
	place(objective,hud,0.035,0.045,0.35,0.16)
	hud_text=label("",21)
	hud_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	place(hud_text,hud,0.59,0.76,0.96,0.96)
	health_label=label("",21)
	place(health_label,hud,0.035,0.93,0.3,0.99)
	var hint := label("Z  ЛЯГТИ     Q / E  НАХИЛ     C  ВИГЛЯНУТИ     ALT  ЛИШЕ ЗБРОЯ     H  АПТЕЧКА",12,Color("b0bba7"))
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	place(hint,hud,0.2,0.95,0.78,1)
	hud.hide()
	pause_panel=overlay(root)
	var pause_box := center_box(pause_panel)
	pause_box.add_child(label("ПАУЗА",44))
	pause_box.add_child(label("Операцію призупинено",18,GOLD))
	debug_checkbox=CheckButton.new()
	debug_checkbox.text="DEBUG: БЕЗСМЕРТЯ / ПОПОВНЕННЯ  [F8]"
	debug_checkbox.toggled.connect(set_debug_invulnerable)
	pause_box.add_child(debug_checkbox)
	resume_button=button("ПРОДОВЖИТИ",func():set_pause(false),true)
	pause_box.add_child(resume_button)
	pause_box.add_child(button("ПОЧАТИ ЗНОВУ",start_match))
	pause_box.add_child(button("ДО СПОРЯДЖЕННЯ",to_menu))
	pause_box.add_child(button("ВИЙТИ",func():get_tree().quit()))
	pause_panel.hide()
	result_panel=overlay(root)
	var result_box := center_box(result_panel)
	result_title=label("",36,GOLD)
	result_box.add_child(result_title)
	result_stats=label("",20)
	result_box.add_child(result_stats)
	result_box.add_child(button("ЩЕ ОДНА ОПЕРАЦІЯ",start_match,true))
	result_box.add_child(button("ДО СПОРЯДЖЕННЯ",to_menu))
	result_panel.hide()

func style_option(node: OptionButton) -> void:
	node.custom_minimum_size.y=47
	node.add_theme_font_size_override("font_size",19)
	node.add_theme_stylebox_override("normal",panel_style(Color("25302a")))
	node.add_theme_stylebox_override("hover",panel_style(Color("3d4939"),GOLD))
	node.add_theme_color_override("font_color",CREAM)

func overlay(root: Control) -> Control:
	var layer := Control.new()
	place(layer,root,0,0,1,1)
	var shade := ColorRect.new()
	shade.color=Color(0.045,0.075,0.06,0.93)
	place(shade,layer,0,0,1,1)
	return layer

func center_box(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",20)
	place(box,parent,0.29,0.22,0.71,0.88)
	return box

func set_debug_invulnerable(enabled: bool) -> void:
	debug_invulnerable=enabled
	if is_instance_valid(player):
		for weapon in player.weapons:weapon.debug_infinite=enabled
	for bot in bots:bot.weapon.debug_infinite=enabled
	if is_instance_valid(debug_checkbox):debug_checkbox.set_pressed_no_signal(enabled)
	if enabled and is_instance_valid(player):
		player.health=100
		player.bleeding=0
		player.blood_loss=0
		player.arm_injury=0
		player.leg_injury=0
		player.pain=0
		player.injury_time=0
		player.plate_integrity=1
		player.last_wound=""
		damage_flash=0

func select_map(index: int) -> void:
	if running:return
	selected_map="city" if index==0 else "shelterbelt"
	update_map_description()
	for i in range(map_buttons.size()):map_buttons[i].button_pressed=i==index
	save_settings()

func update_map_description() -> void:
	if not is_instance_valid(map_description):return
	map_description.text="Зачисть локацію й повернися до старту.\nМісто: відкриті перші поверхи,\nкімнати, двори й пошкоджені фасади.\nВерхні поверхи поки недоступні." if selected_map=="city" else "Зачисть локацію й повернися до старту.\nПосадка: густий ліс і підлісок,\nзвивисті стежки та польові сховки.\nКущі приховують, але не спиняють кулі."

func refresh_outfit_preview() -> void:
	if is_instance_valid(outfit_caption):outfit_caption.text=Wardrobe.LABELS[Wardrobe.IDS.find(player_outfit)]
	for i in range(outfit_buttons.size()):outfit_buttons[i].button_pressed=Wardrobe.IDS[i]==player_outfit
	if not is_instance_valid(outfit_preview):return
	if not is_instance_valid(preview_actor):
		preview_actor=Hostile.new()
		outfit_preview.add_child(preview_actor)
		preview_actor.setup(self,Vector3.ZERO)
		preview_actor.set_physics_process(false)
		preview_actor.rotation=Vector3.ZERO
		preview_actor.animate_pose(0,false)
	if str(preview_actor.get_meta("preview_weapon",""))!=primary:
		var rifle: Node3D=preview_actor.model.get_node("CarriedRifle")
		for child in rifle.get_children():child.free()
		var baked: Node3D=load("res://assets/models/"+("ak74m" if primary=="ak74" else primary)+".scn").instantiate()
		Models.clear_owners(baked)
		for child in baked.get_children():
			baked.remove_child(child)
			rifle.add_child(child)
		baked.free()
		Models.marker(rifle,"BotMuzzle",Vector3(0,0,-0.635))
		rifle.get_node("Magazine").set_meta("rest",Vector3.ZERO)
		preview_actor.set_meta("preview_weapon",primary)
	Wardrobe.dress(preview_actor.model,player_outfit)

func build_loadout(parent: Control) -> void:
	var shade := ColorRect.new()
	shade.color=Color(0.035,0.047,0.041,0.96)
	place(shade,parent,0,0,1,1)
	var title := label("MANS DUTY",34,CREAM)
	place(title,parent,0.03,0.035,0.30,0.11)
	var sub := label("СПОРЯДЖЕННЯ / ОПЕРАЦІЯ",12,GOLD)
	place(sub,parent,0.03,0.105,0.31,0.14)
	for i in range(2):
		var map_button := button("01   МІСТО" if i==0 else "02   ПОСАДКА",select_map.bind(i))
		map_button.toggle_mode=true
		map_button.button_pressed=(selected_map=="city")== (i==0)
		map_buttons.append(map_button)
		place(map_button,parent,0.48+i*0.25,0.045,0.71+i*0.25,0.115)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation",8)
	place(left,parent,0.03,0.18,0.30,0.83)
	left.add_child(label("01 / ЗБРОЯ ТА БОЄКОМПЛЕКТ",13,GOLD))
	primary_tile=inventory_slot("rifle","ОСНОВНА ЗБРОЯ",primary.to_upper(),132)
	primary_tile.pressed.connect(func():primary="m16" if primary=="ak74" else "ak74";refresh_inventory();save_settings())
	left.add_child(primary_tile)
	secondary_tile=inventory_slot("pistol","ПІСТОЛЕТ",secondary.to_upper(),112)
	secondary_tile.pressed.connect(func():secondary="m9" if secondary=="pm" else "pm";refresh_inventory();save_settings())
	left.add_child(secondary_tile)
	left.add_child(label("ПЛИТОНОСКА / 3 ПІДСУМКИ",12,GOLD))
	var vest := HBoxContainer.new()
	left.add_child(vest)
	for i in range(3):
		var slot := inventory_slot("magazine",str(i+1),"R + "+str(i+1),70)
		slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
		vest.add_child(slot)
	left.add_child(label("ПОЯС / 2 МАГАЗИНИ ДО ПІСТОЛЕТА",12,GOLD))
	var belt := HBoxContainer.new()
	left.add_child(belt)
	for i in range(2):
		var slot := inventory_slot("magazine",str(i+1),"ПОЯС",58)
		slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
		belt.add_child(slot)
	var center := VBoxContainer.new()
	place(center,parent,0.32,0.18,0.65,0.84)
	center.add_child(label("02 / ПЕРСОНАЖ",13,GOLD))
	var preview := SubViewportContainer.new()
	preview.custom_minimum_size=Vector2(0,250)
	preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview.stretch=true
	center.add_child(preview)
	outfit_preview=SubViewport.new()
	outfit_preview.size=Vector2i(400,360)
	outfit_preview.own_world_3d=true
	outfit_preview.transparent_bg=true
	preview.add_child(outfit_preview)
	for i in range(2):
		var light := DirectionalLight3D.new()
		light.rotation_degrees=Vector3(-25,-25,0) if i==0 else Vector3(20,140,0)
		light.light_energy=1.3 if i==0 else 0.6
		outfit_preview.add_child(light)
	var camera := Camera3D.new()
	outfit_preview.add_child(camera)
	camera.position=Vector3(1.35,1.2,-2.65)
	camera.look_at(Vector3(0,0.95,0))
	camera.fov=40
	outfit_caption=label("",16,GOLD)
	outfit_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(outfit_caption)
	map_description=label("",13,Color("9ca494"))
	center.add_child(map_description)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation",7)
	place(right,parent,0.68,0.18,0.97,0.84)
	right.add_child(label("03 / ГАРДЕРОБ",13,GOLD))
	for i in range(Wardrobe.IDS.size()):
		var item := button(Wardrobe.LABELS[i],choose_outfit.bind(i))
		item.custom_minimum_size.y=38
		item.add_theme_font_size_override("font_size",14)
		item.toggle_mode=true
		outfit_buttons.append(item)
		right.add_child(item)
	right.add_child(label("ФОРМА ПРОТИВНИКІВ",12,GOLD))
	var enemies := OptionButton.new()
	for name in Wardrobe.LABELS:enemies.add_item(name)
	enemies.selected=Wardrobe.IDS.find(enemy_outfit)
	style_option(enemies)
	enemies.item_selected.connect(func(index: int):enemy_outfit=Wardrobe.IDS[index];save_settings())
	right.add_child(enemies)
	right.add_child(label("Колір · тінь · рух · силует · дистанція\nФорма не змінює захист бронеплити.",12,Color("9ca494")))
	var settings_row := HBoxContainer.new()
	place(settings_row,parent,0.03,0.90,0.48,0.97)
	settings_row.add_child(label("ЗВУК",11,GOLD))
	var sound := HSlider.new()
	sound.max_value=1
	sound.step=0.05
	sound.value=volume
	sound.custom_minimum_size.x=80
	sound.value_changed.connect(func(value: float):volume=value;save_settings())
	settings_row.add_child(sound)
	settings_row.add_child(label("МИША",11,GOLD))
	var mouse := HSlider.new()
	mouse.min_value=0.0008
	mouse.max_value=0.005
	mouse.step=0.0001
	mouse.value=sensitivity
	mouse.custom_minimum_size.x=80
	mouse.value_changed.connect(func(value: float):sensitivity=value;save_settings())
	settings_row.add_child(mouse)
	var shadows := CheckButton.new()
	shadows.text="Тіні"
	shadows.button_pressed=sunlight.shadow_enabled
	shadows.toggled.connect(func(value: bool):sunlight.shadow_enabled=value)
	settings_row.add_child(shadows)
	place(button("ВИЙТИ",func():get_tree().quit()),parent,0.50,0.90,0.63,0.97)
	place(button("РОЗПОЧАТИ ОПЕРАЦІЮ   →",start_match,true),parent,0.68,0.89,0.97,0.97)
	refresh_inventory()
	refresh_outfit_preview()
	update_map_description()

func inventory_slot(kind: String, heading: String, text: String, height: float) -> Button:
	var slot := Button.new()
	slot.set_script(load("res://scripts/inventory_tile.gd"))
	slot.kind=kind
	slot.title=heading
	slot.subtitle=text
	slot.custom_minimum_size.y=height
	slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slot.add_theme_stylebox_override("normal",panel_style(Color("18221d"),Color("465043")))
	slot.add_theme_stylebox_override("hover",panel_style(Color("303c2e"),GOLD))
	slot.add_theme_stylebox_override("focus",panel_style(Color(0,0,0,0),GOLD))
	return slot

func refresh_inventory() -> void:
	refresh_outfit_preview()
	if is_instance_valid(primary_tile):
		primary_tile.subtitle=WeaponState.DATA[primary].name+"  /  Натисни для заміни"
		primary_tile.queue_redraw()
	if is_instance_valid(secondary_tile):
		secondary_tile.subtitle=WeaponState.DATA[secondary].name+"  /  Натисни для заміни"
		secondary_tile.queue_redraw()

func choose_outfit(index: int) -> void:
	player_outfit=Wardrobe.IDS[index]
	refresh_outfit_preview()
	save_settings()

func pain_darkness() -> float:
	return clampf(player.pain*0.32+minf(player.injury_time/1.5,1.0)*0.55+player.blood_loss*(0.55+0.12*sin(player.symptom_clock*1.7)),0,0.96)

func pain_voice(actor: Node3D, severe: bool=true) -> void:
	if not running or paused or volume<=0:return
	if elapsed<float(actor.get_meta("next_pain_voice",-1.0)):return
	actor.set_meta("next_pain_voice",elapsed+1.6)
	var voice := actor.get_node_or_null("PainVoice") as AudioStreamPlayer3D
	if not voice:
		voice=AudioStreamPlayer3D.new()
		voice.name="PainVoice"
		actor.add_child(voice)
	voice.position=actor.camera.position if actor is Operator else Vector3(0,1.15,0)
	voice.max_distance=100
	voice.unit_size=3
	voice.bus=hearing.bus_name
	voice.stream=sounds["pain_%d" % (randi_range(3,4) if severe else randi_range(1,2))]
	voice.volume_db=(-8.0 if severe else -13.0)+linear_to_db(volume)
	voice.pitch_scale=float(actor.get_meta("voice_pitch",1.0))
	voice.play()

func _exit_tree() -> void:
	for output in audio_pool:
		output.stop()
		output.stream=null
	for output in spatial_pool:
		output.stop()
		output.stream=null
