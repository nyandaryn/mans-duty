extends Node3D

var loadout_bag := BackpackState.new()
var loadout_screen: LoadoutScreen

var debris: CartridgeDebris
var ballistics: Ballistics
var blasts: BlastSystem
var concussion_overlay: ColorRect
var effects: Array[Dictionary] = []
var impact_disk: CylinderMesh
var bullet_marks: Array[Node3D] = []
var district: District
var player: Operator
var bots: Array[Hostile] = []
var allies: Array[Hostile] = []
var ally_count := 0
var battle_size := 20
var battle: BattleMode
var commands_open := false
var inventory_open := false
var inventory: CombatInventory
var squad: AssaultSquad
var crew: MortarCrew
var grad: GradCommand
var topo_map: TopoMap
var drone_feed: DroneFeed
var player_class := "rifleman"
var world_root: Node3D
var menu_camera: Camera3D
var sunlight: DirectionalLight3D
var running := false
var squad_tick := 0.0
var paused := false
var debug_invulnerable := false
var debug_checkbox: CheckButton
var killed := 0
var elapsed := 0.0
var damage_flash := 0.0
var symptom_material: ShaderMaterial
var blood: BloodSystem
var hit_marker := 0.0
var rifle_mag_tiles: Array[Button] = []
var pistol_mag_tiles: Array[Button] = []
var medkit_tiles: Array[Button] = []
var primary_tile: Button
var secondary_tile: Button
var outfit_caption: Label
var outfit_buttons: Array[Button] = []
var map_buttons: Array[Button] = []
var player_outfit := "ua_pixel"
var enemy_outfit := "rf_digital"
var outfit_preview: SubViewport
var campaign := Campaign.new()
var loading_panel: Control
var launching := false
var campaign_panel: Control
var mission_cards: Array[MissionCard]=[]
var campaign_brief: Label
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
var soldier_controls: Label
var result_title: Label
var result_stats: Label
var resume_button: MenuItem
var hearing: CombatHearing
var sounds: Dictionary = {}
var audio_pool: Array[AudioStreamPlayer] = []
var audio_index := 0
var spatial_pool: Array[AudioStreamPlayer3D] = []
var spatial_index := 0
var orbit := 0.0
var main_menu: MainMenu
var grad_training: GradTraining
# Every «Навчання» course by class, in the order of the training screen.
const COURSE_IDS := ["rifleman","sniper","mortarman","grad"]
var courses: Dictionary={}
# A training session borrows the BM-21 class and gives the loadout back.
var training := ""
var training_chapter := 0
var training_backup: Dictionary={}
var result_actions: VBoxContainer
var loading_title: Label
var loading_sub: Label
var loading_tip: Label
var pause_note: Label
var shadows_on := true
var fullscreen_on := false
var settings := ConfigFile.new()
# Wide monitors: the 3D view always fills the screen (Hor+), the interface
# lives in a centred frame no wider than this aspect; 0 — the whole width.
const UI_WIDTHS := [0.0,2.4,16.0/9.0]
const UI_WIDTH_LABELS := ["На весь екран","21:9","16:9"]
var ui_width := 1
var ui_root: Control
var frame_margin := 0.0
var bleeds: Array[Control]=[]
const CREAM = Color("e4e5d6")
const LOADING_TIPS := [
	"ПОРАДА: магазин міняй за укриттям — R, а повний обмін на плитоносці R + 1 / 2 / 3.",
	"ПОРАДА: кровотечу зупиняє аптечка (H). Чим довше чекаєш, тим слабша рука й повільніший біг.",
	"ПОРАДА: кущі ховають, але не зупиняють кулі. Стіна з цегли — зупиняє.",
	"ПОРАДА: далекомір (K) і карта (M) — швидший шлях до точних даних для міномета й «Града».",
	"ПОРАДА: «Град» стріляє з вогневої позиції за 5 км. Після залпу — одразу зміна позиції."]
const GOLD = Color("c8b17a")

# 0.24.0 renamed the game from «КВАРТАЛ — Зачистка» to «Mans Duty», and with
# it Godot's user folder (…/app_userdata/<name>). The settings, the campaign
# and the saved loadouts are copied over once; the old folder stays as it was.
const OLD_USER_DIR := "КВАРТАЛ — Зачистка"
const USER_FILES := ["settings.cfg","campaign.cfg","loadouts.cfg"]

static func migrate_user_data(old_dir: String, new_dir: String, files: Array) -> int:
	if old_dir==new_dir or not DirAccess.dir_exists_absolute(old_dir):return 0
	DirAccess.make_dir_recursive_absolute(new_dir)
	var copied := 0
	for file in files:
		var source: String=old_dir.path_join(file)
		var target: String=new_dir.path_join(file)
		if FileAccess.file_exists(target) or not FileAccess.file_exists(source):continue
		if DirAccess.copy_absolute(source,target)==OK:copied+=1
	return copied

func _ready() -> void:
	if not get_meta("automated_preview",false):
		migrate_user_data(OS.get_user_data_dir().get_base_dir().path_join(OLD_USER_DIR),OS.get_user_data_dir(),USER_FILES)
		load_settings()
	else:ally_count=0
	setup_input()
	battle=BattleMode.new();battle.setup(self);add_child(battle)
	setup_environment()
	sunlight.shadow_enabled=shadows_on
	if fullscreen_on and not get_meta("automated_preview",false):DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	setup_audio()
	build_district()
	ballistics=Ballistics.new()
	ballistics.game=self
	add_child(ballistics)
	blasts=BlastSystem.new();blasts.game=self;add_child(blasts)
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
	# CC0 photogrammetric supply crate, one instance beside the insertion point.
	var crate: Node3D=load("res://assets/props/ammo_box/ammo_box.gltf").instantiate()
	world_root.add_child(crate)
	crate.position=district.player_spawn+Vector3(1.2,-0.15,0.8)
	for mesh in crate.find_children("*","MeshInstance3D",true,false):
		mesh.create_trimesh_collision()
		for body in mesh.find_children("*","StaticBody3D",true,false):body.set_meta("ballistic_material","steel")

	blood=BloodSystem.new()
	blood.game=self
	world_root.add_child(blood)
	debris=CartridgeDebris.new()
	debris.game=self
	world_root.add_child(debris)

func start_match() -> void:
	battle.reset()
	if selected_map in Campaign.IDS and not campaign.unlocked(selected_map):return
	inventory.close()
	hearing.reset()
	debris.clear()
	blood.clear()
	ballistics.clear()
	blasts.clear()
	for effect in effects:
		if is_instance_valid(effect.node):effect.node.queue_free()
	effects.clear()
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	for bot in bots+allies:
		if is_instance_valid(bot):
			remove_child(bot)
			bot.queue_free()
	bots.clear()
	allies.clear()
	close_panels()
	crew.reset()
	stop_courses()
	grad.reset()
	# The BM-21 fights only in the great assault.
	if player_class=="grad" and training=="":selected_map=BattleMap.ID
	if district.map_id!=selected_map or selected_map in Campaign.IDS or selected_map==BattleMap.ID:
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
	squad.spawn()
	crew.start()
	soldier_controls.text=control_hint()
	menu.hide()
	pause_panel.hide()
	result_panel.hide()
	hud.show()
	running=true
	if training!="":
		# The training ground: nobody on the field.
		if training=="grad":grad.start()
		course().begin(training_chapter)
	elif selected_map==BattleMap.ID:
		battle.start()
		grad.start()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	save_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_god") and not event.is_echo():set_debug_invulnerable(not debug_invulnerable)
	if not battle.active and training=="" and event.is_action_pressed("report_clear") and running and not paused and player.position.distance_to(district.player_spawn)<5:finish(combat_cleared())
	if event.is_action_pressed("pause") and running:
		set_pause(not paused)
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F11:
		set_fullscreen(DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_fullscreen(on: bool) -> void:
	fullscreen_on=on
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and running and not get_meta("automated_preview",false): set_pause(true)

func set_pause(value: bool) -> void:
	paused=value
	if value:
		close_panels()
		inventory.close()
	if is_instance_valid(district):
		for piece in district.fragments:
			if is_instance_valid(piece):piece.freeze=value
	for actor in bots+allies:
		var voice := actor.get_node_or_null("CoverVoice") as AudioStreamPlayer3D
		if voice:voice.stream_paused=value
	pause_panel.visible=value
	if is_instance_valid(pause_note):pause_note.text="НАВЧАННЯ ПРИЗУПИНЕНО" if training!="" else "ОПЕРАЦІЮ ПРИЗУПИНЕНО"
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if value:resume_button.focus_quietly()

func to_menu(screen: String="") -> void:
	var from_training := training!=""
	battle.reset()
	if is_instance_valid(player):player.field_rig.cancel()
	inventory.close()
	close_panels()
	crew.reset()
	stop_courses()
	grad.reset()
	end_training()
	running=false
	paused=false
	pause_panel.hide()
	result_panel.hide()
	hud.hide()
	menu.show()
	menu_camera.current=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	main_menu.open(screen if screen!="" else ("training" if from_training else "home"))

func course() -> TrainingCourse:return courses.get(training,null)

func stop_courses() -> void:
	for item in courses.values():item.stop()

# A course borrows its class, weapons, pack and map; end_training gives the
# player's own loadout back. Without an id the current (or the BM-21) course.
func begin_training(chapter: int, course_id: String="") -> void:
	if launching:return
	var id := course_id if course_id!="" else (training if training!="" else "grad")
	if not courses.has(id):return
	if training=="":
		training_backup={"class":player_class,"primary":primary,"secondary":secondary,"bag":loadout_bag.serialize(),"map":selected_map,"allies":ally_count}
	training=id
	var plan: Dictionary=courses[id].loadout()
	training_chapter=clampi(chapter,0,courses[id].chapters().size()-1)
	player_class=plan["class"]
	primary=PlayerClass.primary_for(player_class,plan.get("primary",primary))
	secondary=PlayerClass.secondary_for(player_class,plan.get("secondary",secondary))
	loadout_bag=BackpackState.new()
	loadout_bag.equipped=true
	for kind in plan.get("bag",[]):loadout_bag.add(kind)
	if plan.get("bag",[]).is_empty():loadout_bag=BackpackState.new()
	ally_count=0
	selected_map=plan["map"]
	await begin_operation()

func end_training() -> void:
	if training=="":return
	training=""
	if not training_backup.is_empty():
		player_class=training_backup["class"]
		primary=training_backup["primary"]
		secondary=training_backup["secondary"]
		loadout_bag=BackpackState.restore(training_backup["bag"])
		selected_map=training_backup["map"]
		ally_count=training_backup["allies"]
	training_backup={}
	refresh_inventory()
	update_map_description()

func operation_title() -> String:
	var info := operation_info()
	return "%s · %s" % [info.title,info.kind]

func operation_info() -> Dictionary:
	if selected_map==BattleMap.ID:return {"title":"ВЕЛИКИЙ ШТУРМ","kind":"АВДІЇВКА"}
	if selected_map in Campaign.IDS:
		var mission := Campaign.mission(selected_map)
		return {"title":str(mission.title).to_upper(),"kind":"КАМПАНІЯ · %02d" % int(mission.get("stage",1))}
	return {"title":{"city":"МІСЬКИЙ КВАРТАЛ","shelterbelt":"ЛІСОСМУГА"}.get(selected_map,selected_map.to_upper()),"kind":"ВІЛЬНА ЗАЧИСТКА"}

# Result screen with the actions that fit what has just ended.
func show_result(title: String, stats: String, actions: Array) -> void:
	running=false
	paused=false
	pause_panel.hide()
	hud.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	result_title.text=title
	result_stats.text=stats
	for child in result_actions.get_children():child.queue_free()
	for i in range(actions.size()):
		var entry: Array=actions[i]
		var node: Button=UiKit.cta(entry[0]+"   →",entry[1]) if i==0 else UiKit.ghost(entry[0],entry[1],17)
		if i>0:node.custom_minimum_size=Vector2(0,48)
		result_actions.add_child(node)
	result_panel.show()
	result_actions.get_child(0).call_deferred("grab_focus")

func training_result(title: String, stats: String) -> void:
	if is_instance_valid(player):player.field_rig.cancel()
	inventory.close()
	close_panels()
	var id := training
	show_result(title,stats,[["ДО НАВЧАННЯ",func():to_menu("training")],["ПРОЙТИ КУРС ЗНОВУ",func():begin_training(0,id)],["ГОЛОВНЕ МЕНЮ",func():to_menu("home")]])

func finish(won: bool) -> void:
	if battle.active and not battle.finished and not won and player.health<=0:
		if battle.player_fell():return
		battle.finished=true;battle.result_reason="Командир вибув. Живих бійців не лишилося."
	if is_instance_valid(player):player.field_rig.cancel()
	if is_instance_valid(player) and player.is_vaulting():player.vault.cancel()
	inventory.close()
	close_panels()
	if training!="":
		var id := training
		var why: String=course().death_text()
		stop_courses()
		show_result("НАВЧАННЯ ПЕРЕРВАНО",why,[["ПОВТОРИТИ РОЗДІЛ",func():begin_training(training_chapter,id)],["ДО НАВЧАННЯ",func():to_menu("training")]])
		return
	if won and selected_map in Campaign.IDS and campaign.complete(selected_map):
		if not get_meta("automated_preview",false):campaign.save_progress()
		refresh_campaign()
	var title := "ЛОКАЦІЮ ЗАЧИЩЕНО" if won else "ОПЕРАЦІЮ ЗІРВАНО"
	var accuracy := roundi(float(player.hits)/maxi(1,player.shots)*100)
	var stats := "НЕЙТРАЛІЗОВАНО     %02d / %02d\nЧАС ОПЕРАЦІЇ         %02d:%02d\nПОСТРІЛІВ             %d\nВЛУЧНІСТЬ              %d %%" % [killed,bots.size(),int(elapsed)/60,int(elapsed)%60,player.shots,accuracy]
	if battle.active:
		title="РУБЕЖІ ЗАХОПЛЕНО" if won else "ШТУРМ ЗУПИНЕНО"
		stats="%s\nРУБЕЖІ %d / 3 · ЧАС %02d:%02d" % [battle.result_reason,mini(battle.sector,3),int(elapsed)/60,int(elapsed)%60]
	show_result(title,stats,[["ЩЕ ОДНА ОПЕРАЦІЯ",begin_operation],["ДО СПОРЯДЖЕННЯ",func():to_menu("loadout")],["ГОЛОВНЕ МЕНЮ",func():to_menu("home")]])

func bot_down() -> void:
	killed+=1
	# Completion is reported by the player at insertion, never by a hidden kill counter.

func combat_cleared() -> bool:
	for bot in bots:
		if not bot.dead and not bot.concussion.incapacitated():return false
	return true

func _process(delta: float) -> void:
	hearing.injury_floor=player.concussion.severity*0.78 if running and is_instance_valid(player) else 0.0
	hearing.update(delta,running and not paused,volume)
	for output in audio_pool:output.stream_paused=paused
	for output in spatial_pool:output.stream_paused=paused
	for actor in bots+allies:
		var voice := actor.get_node_or_null("PainVoice") as AudioStreamPlayer3D
		if voice:voice.stream_paused=paused
	if is_instance_valid(player):
		var voice := player.get_node_or_null("PainVoice") as AudioStreamPlayer3D
		if voice:voice.stream_paused=paused
	if not running and menu.visible:
		# A slow crane shot along the street behind the menu.
		orbit+=delta*0.035
		var eye := Vector3(sin(orbit)*5.0,0,34.0+cos(orbit*0.8)*2.5)
		eye.y=district.ground_height(eye)+4.4+sin(orbit*1.7)*0.4
		menu_camera.position=eye
		menu_camera.look_at(Vector3(sin(orbit*0.5)*3.0,district.ground_height(Vector3(0,0,-20))+3.0,-20))
	if running and not paused:
		elapsed+=delta
		damage_flash=maxf(0,damage_flash-delta)
		hit_marker=maxf(0,hit_marker-delta)
		symptom_material.set_shader_parameter("severity",pain_darkness())
		concussion_overlay.visible=player.concussion.active()
		concussion_overlay.material.set_shader_parameter("severity",player.concussion.severity)
		concussion_overlay.material.set_shader_parameter("clock",player.symptom_clock)
		hud_text.visible=not player.field_rig.active()
		objective.visible=player.field_rig.mode not in ["rangefinder","drone"]
		health_label.visible=player.field_rig.mode!="drone"
		soldier_controls.visible=player.field_rig.mode!="drone"
		var w := player.current()
		objective.text="%s\nЗачистіть локацію й поверніться до старту.\nENTER біля старту — завершити операцію." % district.map_title
		if battle.active:objective.text=battle.status()
		elif training!="" and training!="grad":objective.text=course().objective_text()
		hud_text.text="%s  /  %s\n%s\nR + 1 / 2 / 3 · ОБМІН МАГАЗИНА\nI · ПАТРОННИК   T · МАГАЗИН\nT + 1 / 2 / 3 · ПІДСУМОК" % [w.data.name,w.data.caliber,w.status()]
		health_label.text="СТАН  %03d" % ceili(player.health)
		health_label.modulate=Color("d49a7b") if player.health<35 else CREAM
	hud.queue_redraw()

# A 122-mm burst kilometres away arrives as a low thump after the sound
# has travelled there.
func distant_blast(where: Vector3, distance: float) -> void:
	if volume<=0:return
	var delay := distance/343.0
	var db := 4.0-20.0*log(distance/250.0)/log(10.0)*0.75
	get_tree().create_timer(delay,false).timeout.connect(func():
		if not running:return
		var output := audio_pool[audio_index]
		audio_index=(audio_index+1)%audio_pool.size()
		output.stream=GradAudio.synth("thump")
		output.volume_db=db+linear_to_db(volume)
		output.pitch_scale=randf_range(0.85,1.05)
		output.play())

func grad_impact(where: Vector3) -> void:
	if is_instance_valid(grad) and grad.active():grad.impact(where)

func alert_bots(where: Vector3) -> void:
	for bot in bots: bot.hear(where)

func eject_case(where: Vector3, basis: Basis, weapon_id: String="ak74", live: bool=false) -> void:
	debris.eject(where,basis,weapon_id,live)

func impact(where: Vector3, normal: Vector3=Vector3.UP, surface: Node3D=null) -> void:
	# Knock-down targets of the training range count their hits.
	if surface!=null and surface.has_meta("range_target"):surface.get_meta("range_target").hit(where)
	# A ray starting inside a collider returns no valid surface normal.
	# Do not fabricate a horizontal decal in mid-air in that case.
	if normal.length_squared()<0.1:return
	normal=normal.normalized()
	# Small dark impact mark and short-lived dust, no bright projectile.
	var mark := MeshInstance3D.new()
	if impact_disk==null:
		impact_disk=CylinderMesh.new()
		impact_disk.top_radius=0.015
		impact_disk.bottom_radius=0.015
		impact_disk.height=0.001
		impact_disk.radial_segments=8
	mark.mesh=impact_disk
	mark.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.material_override=Models.surface("34352f")
	(surface if is_instance_valid(surface) else world_root).add_child(mark)
	mark.global_position=where+normal*0.003
	mark.quaternion=Quaternion(Vector3.UP,normal)
	# Destructible surfaces can free their child decals before this budget runs.
	bullet_marks=bullet_marks.filter(func(item):return is_instance_valid(item))
	bullet_marks.append(mark)
	if bullet_marks.size()>100:
		var old: Node3D=bullet_marks.pop_front()
		if is_instance_valid(old):old.queue_free()
	# Centimetre dust is invisible beyond a few dozen metres; skip it in big battles.
	if battle.active and Models.view_distance(self,where)>45:return
	for i in range(3):
		var particle := Models.particle(world_root,where+normal*0.025,randf_range(0.012,0.03),"a39c88")
		effects.append({"node":particle,"velocity":normal*randf_range(0.5,1.4)+Vector3(randf_range(-0.5,0.5),0.3,randf_range(-0.5,0.5)),"life":0.3,"spin":Vector3(3,5,2),"type":"dust"})

func _physics_process(delta: float) -> void:
	if not running or paused:return
	squad_tick-=delta
	if squad_tick<=0:
		squad_tick=0.5
		coordinate_squad()
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
	campaign.load_progress()
	selected_map="forest_01"
	if settings.load("user://settings.cfg")==OK:
		loadout_bag=BackpackState.restore(settings.get_value("loadout","backpack",{}))
		player_outfit=Wardrobe.valid(str(settings.get_value("loadout","outfit","ua_pixel")))
		battle_size=int(settings.get_value("operation","battle_size",20))
		if battle_size not in BattleMode.SIZES:battle_size=20
		enemy_outfit=Wardrobe.valid(str(settings.get_value("operation","enemy_outfit","rf_digital")))
		selected_map=str(settings.get_value("operation","map","city"))
		if selected_map not in Campaign.IDS and selected_map!=BattleMap.ID:selected_map="forest_01"
		primary=str(settings.get_value("loadout","primary","ak74"))
		secondary=str(settings.get_value("loadout","secondary","pm"))
		if primary not in ["ak74","m16","svd"]:primary="ak74"
		if secondary not in ["pm","m9"]:secondary="pm"
		player_class=PlayerClass.valid(str(settings.get_value("loadout","class",PlayerClass.infer(primary))))
		primary=PlayerClass.primary_for(player_class,primary)
		secondary=PlayerClass.secondary_for(player_class,secondary)
		PlayerClass.clean_bag(player_class,loadout_bag)
		ally_count=PlayerClass.allies(player_class)
		sensitivity=clampf(float(settings.get_value("settings","sensitivity",0.0022)),0.0008,0.005)
		volume=clampf(float(settings.get_value("settings","volume",0.65)),0,1)
		shadows_on=bool(settings.get_value("settings","shadows",true))
		fullscreen_on=bool(settings.get_value("settings","fullscreen",false))
		ui_width=clampi(int(settings.get_value("settings","ui_width",1)),0,UI_WIDTHS.size()-1)

	if selected_map in Campaign.IDS and not campaign.unlocked(selected_map):selected_map="forest_01"

func save_settings() -> void:
	if get_meta("automated_preview",false) or training!="":return
	settings.set_value("settings","shadows",sunlight.shadow_enabled if is_instance_valid(sunlight) else shadows_on)
	settings.set_value("settings","fullscreen",fullscreen_on)
	settings.set_value("settings","ui_width",ui_width)
	settings.set_value("loadout","outfit",player_outfit)
	settings.set_value("loadout","backpack",loadout_bag.serialize())
	settings.set_value("operation","enemy_outfit",enemy_outfit)
	settings.set_value("loadout","class",player_class)
	settings.set_value("operation","battle_size",battle_size)
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
	for key in ["ak74","m16","pm","m9","mag_in","mag_out","bolt","bolt_pull","pain_1","pain_2","pain_3","pain_4","cover"]:
		sounds[key]=load("res://assets/audio/"+key+".wav")
	# Recorded rifle placeholder; its provenance is documented in AUDIO-CREDITS.
	sounds["svd"]=sounds["ak74"]
	sounds["rpo_launch"]=ShmelArt.sound(false)
	sounds["rpo_blast"]=ShmelArt.sound(true)
	sounds["mortar_launch"]=Mortar.sound("launch")
	sounds["mine_whistle"]=Mortar.sound("whistle")
	sounds["mine_blast"]=Mortar.sound("blast")
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
	if kind in ["ak74","m16","svd","pm","m9"]:
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
	if weapon in ["ak74","m16","svd","pm","m9"] and is_instance_valid(player):
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
	if accent:
		var main := UiKit.cta(text,callback)
		main.custom_minimum_size=Vector2(0,46)
		main.add_theme_font_size_override("font_size",18)
		return main
	var node := Button.new()
	node.text=text
	node.custom_minimum_size=Vector2(0,46)
	node.alignment=HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_font_override("font",UiKit.font("head"))
	node.add_theme_font_size_override("font_size",18)
	node.add_theme_stylebox_override("normal",UiKit.flat(Color(0.05,0.07,0.06,0.85),UiKit.LINE,1))
	node.add_theme_stylebox_override("hover",UiKit.flat(Color(0.2,0.17,0.09,0.92),UiKit.ACCENT,1,3))
	node.add_theme_stylebox_override("pressed",UiKit.flat(Color(0.3,0.24,0.11,0.95),UiKit.ACCENT,1,3))
	node.add_theme_stylebox_override("hover_pressed",UiKit.flat(Color(0.34,0.27,0.12,0.95),UiKit.ACCENT,1,3))
	node.add_theme_stylebox_override("focus",UiKit.flat(Color(0,0,0,0),Color(UiKit.ACCENT,0.7),1))
	node.add_theme_stylebox_override("disabled",UiKit.flat(Color(0.05,0.07,0.06,0.5),Color(1,1,1,0.05),1))
	for state in ["font_color","font_focus_color"]:node.add_theme_color_override(state,UiKit.SOFT)
	for state in ["font_hover_color","font_pressed_color","font_hover_pressed_color"]:node.add_theme_color_override(state,UiKit.INK)
	node.add_theme_color_override("font_disabled_color",UiKit.FAINT)
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
	ui_root=root
	get_viewport().size_changed.connect(update_frame)
	menu=Control.new()
	place(menu,root,0,0,1,1)
	menu.theme=UiKit.theme()
	main_menu=MainMenu.new()
	main_menu.setup(self,menu)
	build_loadout(menu)
	build_campaign_panel(menu)
	battle.build_menu(menu)
	# Added last below the other screens so loading is visible during map build.
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
	concussion_overlay=ColorRect.new()
	concussion_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var concussion_material := ShaderMaterial.new()
	concussion_material.shader=load("res://shaders/concussion.gdshader")
	concussion_overlay.material=concussion_material
	place(concussion_overlay,hud,0,0,1,1)
	concussion_overlay.hide()
	objective=label("",19)
	place(objective,hud,0.035,0.045,0.35,0.16)
	hud_text=label("",21)
	hud_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	place(hud_text,hud,0.59,0.76,0.96,0.96)
	health_label=label("",21)
	place(health_label,hud,0.035,0.93,0.3,0.99)
	var hint := label("",12,Color("b0bba7"))
	soldier_controls=hint
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
	place(hint,hud,0.17,0.91,0.70,0.995)
	hud.hide()
	pause_panel=overlay(root)
	pause_panel.theme=UiKit.theme()
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation",2)
	place(pause_box,pause_panel,0.06,0.16,0.5,0.92)
	pause_note=UiKit.text("ОПЕРАЦІЮ ПРИЗУПИНЕНО",15,UiKit.ACCENT,"head")
	pause_box.add_child(pause_note)
	pause_box.add_child(UiKit.text("ПАУЗА",96,UiKit.INK,"display"))
	var pause_gap := Control.new()
	pause_gap.custom_minimum_size.y=18
	pause_box.add_child(pause_gap)
	resume_button=MenuItem.new().configure(self,"","ПРОДОВЖИТИ","",func():set_pause(false),36)
	pause_box.add_child(resume_button)
	pause_box.add_child(MenuItem.new().configure(self,"","ПОЧАТИ ЗНОВУ","Операція або розділ навчання — з початку",begin_operation,36))
	pause_box.add_child(MenuItem.new().configure(self,"","ГОЛОВНЕ МЕНЮ","",func():to_menu(),36))
	pause_box.add_child(MenuItem.new().configure(self,"","ВИЙТИ З ГРИ","",func():get_tree().quit(),36))
	debug_checkbox=CheckButton.new()
	debug_checkbox.text="DEBUG: БЕЗСМЕРТЯ / ПОПОВНЕННЯ  [F8]"
	debug_checkbox.focus_mode=Control.FOCUS_NONE
	debug_checkbox.toggled.connect(set_debug_invulnerable)
	place(debug_checkbox,pause_panel,0.06,0.92,0.5,0.97)
	pause_panel.hide()
	result_panel=overlay(root)
	result_panel.theme=UiKit.theme()
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation",10)
	place(result_box,result_panel,0.06,0.14,0.66,0.95)
	result_box.add_child(UiKit.text("ПІДСУМОК",15,UiKit.ACCENT,"head"))
	result_title=UiKit.text("",66,UiKit.INK,"display")
	result_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result_box.add_child(result_title)
	result_box.add_child(UiKit.rule(UiKit.ACCENT,2))
	result_stats=UiKit.text("",19,UiKit.SOFT,"head")
	result_stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result_box.add_child(result_stats)
	var result_gap := Control.new()
	result_gap.custom_minimum_size.y=16
	result_box.add_child(result_gap)
	result_actions=VBoxContainer.new()
	result_actions.add_theme_constant_override("separation",8)
	result_actions.custom_minimum_size.x=420
	result_actions.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	result_box.add_child(result_actions)
	result_panel.hide()

	squad=AssaultSquad.new()
	add_child(squad)
	squad.setup(self,root)
	crew=MortarCrew.new()
	add_child(crew)
	crew.setup(self,root)
	grad=GradCommand.new()
	add_child(grad)
	grad.setup(self,root)
	drone_feed=DroneFeed.new()
	drone_feed.setup(self,root)
	topo_map=TopoMap.new()
	topo_map.setup(self,root)
	inventory=CombatInventory.new()
	inventory.setup(self,root)
	# The step cards of «Навчання» stay above the map, the inventory and the
	# mortar sight; pause and results hide them.
	grad_training=GradTraining.new()
	grad_training.setup(self,root)
	courses={"rifleman":RiflemanTraining.new(),"sniper":SniperTraining.new(),"mortarman":MortarTraining.new()}
	for id in courses:courses[id].setup(self,root)
	courses["grad"]=grad_training
	loading_panel=Control.new()
	place(loading_panel,root,0,0,1,1)
	var backdrop := ColorRect.new()
	backdrop.color=Color("070b09")
	place(backdrop,loading_panel,0,0,1,1)
	var loading_box := VBoxContainer.new()
	loading_box.add_theme_constant_override("separation",4)
	place(loading_box,loading_panel,0.06,0.58,0.9,0.9)
	loading_sub=UiKit.text("",16,UiKit.ACCENT,"head")
	loading_box.add_child(loading_sub)
	loading_title=UiKit.text("",84,UiKit.INK,"display")
	loading_box.add_child(loading_title)
	loading_box.add_child(UiKit.rule(UiKit.ACCENT,3))
	loading_tip=UiKit.wrapped("",16,UiKit.MUTED)
	loading_box.add_child(loading_tip)
	loading_panel.hide()
	main_menu.finish_setup()
	# Pause, results and loading always cover the field overlays.
	for layer in [pause_panel,result_panel,loading_panel]:root.move_child(layer,-1)
	for layer in [symptoms,concussion_overlay,backdrop,topo_map]:bleed(layer)
	update_frame()

# Side margins of the interface frame for a screen of this size.
static func frame_margin_for(screen: Vector2, aspect: float) -> float:
	if aspect<=0.0 or screen.x<=screen.y*aspect:return 0.0
	return floorf((screen.x-screen.y*aspect)*0.5)

func set_ui_width(index: int) -> void:
	ui_width=clampi(index,0,UI_WIDTHS.size()-1)
	update_frame()
	save_settings()

func update_frame() -> void:
	if not is_instance_valid(ui_root):return
	var screen: Vector2=get_meta("screen_override",get_viewport().get_visible_rect().size)
	frame_margin=frame_margin_for(screen,UI_WIDTHS[ui_width])
	ui_root.offset_left=frame_margin
	ui_root.offset_right=-frame_margin
	bleeds=bleeds.filter(func(node: Control):return is_instance_valid(node))
	for node in bleeds:fit_bleed(node)

# Backdrops, shades and screen effects reach past the frame to the edges.
func bleed(node: Control, right: bool=true) -> void:
	node.set_meta("bleed_right",right)
	bleeds.append(node)
	fit_bleed(node)

func fit_bleed(node: Control) -> void:
	node.offset_left=-frame_margin
	node.offset_right=frame_margin if node.get_meta("bleed_right",true) else 0.0

# The whole screen in the local coordinates of an interface control.
static func screen_rect(node: Control) -> Rect2:
	return Rect2(-node.get_global_rect().position,node.get_viewport_rect().size)

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
	shade.color=Color(0.02,0.03,0.026,0.84)
	place(shade,layer,0,0,1,1)
	bleed(shade)
	var side := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient=Gradient.new()
	gradient.gradient.set_color(0,Color(0.01,0.015,0.012,0.9))
	gradient.gradient.set_color(1,Color(0.01,0.015,0.012,0.0))
	gradient.fill_to=Vector2(1,0)
	side.texture=gradient
	side.stretch_mode=TextureRect.STRETCH_SCALE
	side.mouse_filter=Control.MOUSE_FILTER_IGNORE
	place(side,layer,0,0,0.7,1)
	bleed(side,false)
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
	for bot in bots+allies:bot.weapon.debug_infinite=enabled
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
	if selected_map==BattleMap.ID:
		map_description.text="Великий штурм · %d × %d · три рубежі" % [battle_size,battle_size]
		return
	if selected_map in Campaign.IDS:
		var mission := Campaign.mission(selected_map)
		map_description.text=mission.title+" · 400 × 400 м\n"+mission.brief+"\nЗачисть позиції й повернися до старту."
		return
	map_description.text="Зачисть локацію й повернися до старту.\nМісто: відкриті перші поверхи,\nкімнати, двори й пошкоджені фасади.\nВерхні поверхи поки недоступні." if selected_map=="city" else "Зачисть локацію й повернися до старту.\nПосадка: густий ліс і підлісок,\nзвивисті стежки та польові сховки.\nКущі приховують, але не спиняють кулі."

func refresh_outfit_preview() -> void:
	if is_instance_valid(loadout_screen):loadout_screen.refresh()

func build_loadout(parent: Control) -> void:
	loadout_screen=LoadoutScreen.new()
	loadout_screen.setup(self,parent)
	refresh_inventory()
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
		primary_tile.show_weapon(primary)
		primary_tile.queue_redraw()
	if is_instance_valid(secondary_tile):
		secondary_tile.subtitle=WeaponState.DATA[secondary].name+"  /  Натисни для заміни"
		secondary_tile.show_weapon(secondary)
		secondary_tile.queue_redraw()
	for tile in rifle_mag_tiles:tile.show_weapon(primary)
	for tile in pistol_mag_tiles:tile.show_weapon(secondary)
	for tile in medkit_tiles:tile.show_item("medkit")

func choose_outfit(index: int) -> void:
	player_outfit=Wardrobe.IDS[index]
	refresh_outfit_preview()
	save_settings()

func pain_darkness() -> float:
	return clampf(maxf(player.concussion.darkness(player.symptom_clock),player.pain*0.32+minf(player.injury_time/1.5,1.0)*0.55+player.blood_loss*(0.55+0.12*sin(player.symptom_clock*1.7))),0,0.98)

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

func coordinate_squad() -> void:
	var assigned: Array[Hostile]=[]
	for bot in bots:
		if bot.dead or assigned.has(bot):continue
		if not bot.alerted or bot.arm_wound>=0.5 or bot.collapse>0.01 or bot.treatment_time>0:
			bot.assign_squad("",null)
			continue
		var buddy: Hostile
		var nearest := 45.0
		for ally in bots:
			if ally==bot or ally.dead or assigned.has(ally) or not ally.alerted or ally.arm_wound>=0.5 or ally.collapse>0.01 or ally.treatment_time>0:continue
			var distance: float=bot.global_position.distance_to(ally.global_position)
			if distance<nearest:
				nearest=distance
				buddy=ally
		if buddy==null or minf(bot.suppress_age,buddy.suppress_age)>8:
			bot.assign_squad("",null)
			continue
		# Transfer a time-stamped sighting, never refresh its age just by radio.
		var source: Hostile=bot if bot.suppress_age<buddy.suppress_age else buddy
		var receiver: Hostile=buddy if source==bot else bot
		receiver.suppress_age=source.suppress_age
		receiver.suppress_point=source.suppress_point
		var covering: Hostile=bot if int(elapsed/6+bot.get_index())%2==0 else buddy
		var moving: Hostile=buddy if covering==bot else bot
		if covering.weapon.phase!="" or covering.weapon.ammunition_total()==0:
			var swap := covering
			covering=moving
			moving=swap
		covering.assign_squad("cover",moving)
		moving.assign_squad("move",covering)
		assigned.append(bot)
		assigned.append(buddy)

func cover_voice(actor: Hostile) -> void:
	if volume<=0 or elapsed<float(actor.get_meta("next_cover_voice",-1.0)):return
	actor.set_meta("next_cover_voice",elapsed+4.5)
	var voice := actor.get_node_or_null("CoverVoice") as AudioStreamPlayer3D
	if voice==null:
		voice=AudioStreamPlayer3D.new()
		voice.name="CoverVoice"
		actor.add_child(voice)
	voice.position=Vector3(0,1.5,0)
	voice.max_distance=110
	voice.unit_size=5
	voice.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.bus=hearing.bus_name
	voice.stream=sounds.cover
	voice.volume_db=-3+linear_to_db(volume)
	voice.pitch_scale=float(actor.get_meta("voice_pitch",1.0))
	voice.play()

func build_campaign_panel(parent: Control) -> void:
	campaign_panel=Control.new()
	place(campaign_panel,parent,0,0,1,1)
	UiKit.sheet(self,campaign_panel,0.8)
	UiKit.header(self,campaign_panel,"ГОЛОВНЕ МЕНЮ   /   КАМПАНІЯ","КАМПАНІЯ","ДВІ ГІЛКИ · ДЕСЯТЬ ОПЕРАЦІЙ · 400 × 400 М",func():main_menu.back())
	for branch in range(2):
		var left := 0.035+branch*0.47
		place(UiKit.text(Campaign.BRANCH_NAMES[Campaign.BRANCHES[branch]].to_upper(),18,UiKit.ACCENT,"head"),campaign_panel,left,0.22,left+0.44,0.26)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",7)
		place(column,campaign_panel,left,0.265,left+0.455,0.88)
		for index in range(5):
			var id: String=Campaign.IDS[branch*5+index]
			var card := MissionCard.new()
			column.add_child(card)
			mission_cards.append(card)
			card.pressed.connect(select_mission.bind(id))
	campaign_brief=UiKit.wrapped("",14,UiKit.SOFT)
	place(campaign_brief,campaign_panel,0.035,0.915,0.965,0.985)
	refresh_campaign()
	campaign_panel.hide()

func refresh_campaign() -> void:
	for i in range(mission_cards.size()):
		var id: String=Campaign.IDS[i]
		mission_cards[i].configure(Campaign.mission(id),campaign.unlocked(id),id in campaign.completed,id==selected_map)
	if is_instance_valid(campaign_brief):
		campaign_brief.text=Campaign.mission(selected_map).get("brief","Обери першу операцію будь-якої гілки. Наступна відкриється після успішного завершення попередньої.")

func show_campaign() -> void:
	refresh_campaign()
	main_menu.show_screen("campaign")

func select_mission(id: String) -> void:
	if running or not campaign.unlocked(id):return
	selected_map=id
	refresh_campaign()
	update_map_description()
	save_settings()
	main_menu.show_screen("loadout")

func begin_operation() -> void:
	if launching:return
	launching=true
	if training!="":
		loading_sub.text="НАВЧАННЯ · %s · РОЗДІЛ %d" % [course().course_title(),training_chapter+1]
		loading_title.text=course().chapters()[training_chapter].title
		loading_tip.text=course().loading_tip()
	else:
		loading_sub.text="ПІДГОТОВКА ОПЕРАЦІЇ"
		loading_title.text=operation_title()
		loading_tip.text=LOADING_TIPS[randi()%LOADING_TIPS.size()]
	loading_panel.show()
	await get_tree().process_frame
	await get_tree().process_frame
	start_match()
	loading_panel.hide()
	launching=false

func alert_opponents(shooter: Hostile, where: Vector3) -> void:
	for actor in (bots if shooter.friendly else allies):actor.hear(where)

func _input(event: InputEvent) -> void:
	if not running or paused:return
	if battle.active and battle.respawn_left>0:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_TAB:
			inventory.toggle()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_ESCAPE and inventory_open:
			inventory.close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_G:
			# The BM-21 commander has the radio and the tablet instead (GradCommand).
			if is_instance_valid(grad) and grad.active():return
			if player.field_rig.mode=="drone" or player.is_vaulting() or player.launcher.active():return
			if topo_map.visible or crew.sight.visible:return
			inventory.close()
			crew.toggle()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_M:
			if is_instance_valid(grad) and grad.active():return
			if crew.panel.visible or crew.sight.visible or inventory_open:return
			if player.is_vaulting() or player.launcher.active():return
			topo_map.toggle()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_ESCAPE and commands_open:
			close_panels()
			get_viewport().set_input_as_handled()

# Modal overlays of the field: crew orders, the mortar sight and the map.
func close_panels() -> void:
	if is_instance_valid(crew):
		crew.close()
		crew.sight.close()
	if is_instance_valid(topo_map):topo_map.close()
	if is_instance_valid(grad):grad.close_panels()
	commands_open=false

func control_hint() -> String:
	var text := "SPACE  ПЕРЕЛІЗТИ    Z  ЛЯГТИ    Q / E  НАХИЛ    C  ВИГЛЯНУТИ    ALT  ЛИШЕ ЗБРОЯ    H  АПТЕЧКА\nV  ЗАТВОР    M  КАРТА    K  ДАЛЕКОМІР    J  ДРОН    U  ЕКРАН ДРОНА"
	if player_class=="rifleman":text+="    4  РПО-А"
	if player_class=="mortarman":text+="    G  РОЗРАХУНОК    N  МІНОМЕТ    F  ПРИЦІЛ / ЯЩИК"
	if player_class=="grad":text="SPACE  ПЕРЕЛІЗТИ    Z  ЛЯГТИ    H  АПТЕЧКА    F  БІЛЯ МАШИНИ — ДІЯ / КАБІНА / ПРИЦІЛ    M  ПЛАНШЕТ    G  РАДІО"
	return text

func set_player_class(id: String) -> Array[String]:
	player_class=PlayerClass.valid(id)
	primary=PlayerClass.primary_for(player_class,primary)
	secondary=PlayerClass.secondary_for(player_class,secondary)
	ally_count=PlayerClass.allies(player_class)
	if player_class=="grad" and selected_map!=BattleMap.ID:
		selected_map=BattleMap.ID
		update_map_description()
	var removed := PlayerClass.clean_bag(player_class,loadout_bag)
	refresh_inventory()
	save_settings()
	return removed
