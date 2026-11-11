extends SceneTree

var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	assert(game.menu.visible and not game.running,"Menu is the initial screen")
	game.start_match()
	await physics_frame
	await physics_frame
	assert(game.bots.size()==10 and game.running,"Match spawns ten enemies")
	for bot in game.bots:
		var cell := Vector2i(roundi(bot.position.x),roundi(bot.position.z))
		assert(not game.district.grid.is_point_solid(cell),"Bot spawn does not overlap cover")
		var route: PackedVector2Array=game.district.path(bot.position,game.player.position)
		assert(route.size()>1,"Every bot has a route to the player's spawn")
	game.set_pause(true)
	var old_time: float=game.elapsed
	var old_pos: Vector3=game.player.position
	for i in range(5):await physics_frame
	assert(game.elapsed==old_time and game.player.position==old_pos,"Pause freezes simulation")
	game.set_pause(false)
	game.player.current().fire()
	game.player.current().reload()
	game.player.current().update(0.71)
	game.player.switch_weapon(1)
	game.player.switch_weapon(0)
	assert(game.player.current().magazine.is_empty() and game.player.current().chambered,"Switching preserves interrupted reload state")
	game.start_match()
	await physics_frame
	await physics_frame
	# Put the player and target in a dedicated clear firing lane.
	game.player.position=Vector3(0,0.2,40)
	game.player.rotation=Vector3.ZERO
	for i in range(game.bots.size()):game.bots[i].set_physics_process(false)
	game.bots[0].position=Vector3(0,0,8)
	await physics_frame
	Input.action_press("aim")
	for i in range(45):await physics_frame
	game.player.shoot()
	assert(game.player.hits==0,"Bullet damage is not instantaneous")
	for i in range(6):await physics_frame
	assert(game.player.hits==1,"Ballistic projectile hits visible enemy")
	game.player.cooldown=0
	game.player.recoil=0
	game.player.pitch=0
	game.player.camera.rotation.x=0
	game.player.gun_kick=0
	for i in range(20):await physics_frame
	game.player.shoot()
	for i in range(6):await physics_frame
	assert(game.bots[0].dead,"Headshots kill enemy")
	for bot in game.bots:
		if not bot.dead:bot.take_damage(1000)
	assert(game.running and not game.result_panel.visible,"Last kill cannot reveal itself through automatic victory")
	game.player.position=game.district.player_spawn
	var report := InputEventKey.new()
	report.physical_keycode=KEY_ENTER
	report.pressed=true
	game._unhandled_input(report)
	assert(not game.running and game.result_panel.visible,"Player returns and explicitly reports the operation complete")
	game.start_match()
	await physics_frame
	game.player.take_damage(1000)
	assert(not game.running and game.result_panel.visible,"Player death ends match")
	Input.action_release("aim")
	game.to_menu()
	assert(game.menu.visible and not game.hud.visible,"Return to loadout")
	await create_timer(0.5).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout # Let the audio mix thread release stopped playback resources.
	print("PASS: match lifecycle, navigation, pause, swapping, ballistic flight, victory and defeat")
	quit()
