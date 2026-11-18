extends SceneTree

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var game: Node3D=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.volume=0
	game.start_match()
	for bot in game.bots:bot.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.player.camera.position.y=1.65
	for i in range(80):await process_frame
	for id in ["ak74","m16","pm","m9"]:
		game.player.slot=0 if id in ["ak74","m16"] else 1
		game.player.weapons[game.player.slot]=WeaponState.new(id)
		game.player.make_viewmodel()
		var state: WeaponState=game.player.current()
		for shot in range(int(state.data.capacity)):state.fire()
		for pose in ["hip","remove","insert","rack"]:
			state.phase="" if pose=="hip" else pose
			state.clock=state.phase_duration()*0.55
			if pose=="insert":state.magazine={}
			for i in range(30):
				game.player.update_pose(1.0/60)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/"+id+"-"+pose+"-detail.png")
	print("RELOAD RENDER complete")
	game.queue_free()
	for i in range(4):await process_frame
	quit()
