extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func snap(name: String) -> void:
	for i in range(100):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/"+name+".png")
	print(name," FPS=",Engine.get_frames_per_second()," draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func run() -> void:
	var game: Node3D=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.volume=0
	game.start_match()
	game.player.set_process_unhandled_input(false)
	game.player.set_physics_process(false)
	game.hud.hide()
	for bot in game.bots:bot.set_physics_process(false)
	game.player.viewmodel.hide()
	var camera: Camera3D=game.menu_camera
	camera.current=true
	camera.position=Vector3(5,7,38)
	camera.look_at(Vector3(0,4,-5))
	await snap("district")
	camera.position=Vector3(-11,2.7,30)
	camera.look_at(Vector3(-7,0.9,25))
	await snap("car")
	game.bots[0].position=Vector3(0,0,30)
	game.bots[0].rotation.y=0.3
	camera.position=Vector3(0.6,1.45,27.3)
	camera.look_at(Vector3(0,0.98,30))
	await snap("soldier")
	camera.position=Vector3(9,2.0,42)
	camera.look_at(Vector3(17,2.3,28))
	await snap("courtyard")
	game.player.camera.current=true
	game.player.viewmodel.show()
	game.hud.show()
	game.player.set_physics_process(true)
	for bot in game.bots:bot.set_physics_process(true)
	for i in range(180):await process_frame
	await snap("gameplay")
	game.queue_free()
	for i in range(5):await process_frame
	quit()
