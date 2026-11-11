extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(15):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/menu.png")
	game.start_match()
	for i in range(120):await process_frame
	game.player.position=Vector3(1,0.1,34)
	game.player.pitch=0.06
	for i in range(10):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/game.png")
	await create_timer(2.0).timeout
	print("RENDER: ",RenderingServer.get_video_adapter_name(),"; FPS ",Engine.get_frames_per_second())
	game.queue_free()
	for i in range(10):await process_frame
	quit()
