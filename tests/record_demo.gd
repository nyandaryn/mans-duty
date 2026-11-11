extends SceneTree

func _initialize() -> void:call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):await process_frame

func run() -> void:
	var game: Node3D=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.volume=0.55
	game.start_match()
	game.player.set_process_unhandled_input(false)
	for bot in game.bots:bot.set_physics_process(false)
	for id in ["ak74","m16","pm","m9"]:
		Input.action_release("aim")
		game.player.slot=0 if id in ["ak74","m16"] else 1
		game.player.weapons[game.player.slot]=WeaponState.new(id)
		game.player.make_viewmodel()
		await frames(35)
		Input.action_press("aim")
		await frames(40)
		game.player.shoot()
		await frames(25)
		Input.action_release("aim")
		# Empty state demonstrates extraction, insertion AND bolt/slide operation.
		var state: WeaponState=game.player.current()
		while state.chambered:state.fire()
		state.reload()
		await frames(230)
		await frames(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/"+id+"-final.png")
	print("DEMO complete")
	game.queue_free()
	await frames(4)
	quit()
