extends SceneTree
func _initialize():call_deferred("run")
func frames(n: int):
	for i in range(n):await process_frame
func snap(name: String):
	await frames(50)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/"+name+".png")
func run():
	var game: Node3D=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.start_match()
	game.volume=0
	game.player.set_process_unhandled_input(false)
	for bot in game.bots:bot.set_physics_process(false)
	await snap("sheltered-spawn")
	game.player.prone_requested=true
	await snap("prone")
	Input.action_press("aim")
	await snap("prone-ads")
	Input.action_release("aim")
	game.player.prone_requested=false
	await snap("standing")
	game.menu_camera.current=true
	game.menu_camera.position=Vector3(43,16,47)
	game.menu_camera.look_at(Vector3(28,0,37))
	game.hud.hide()
	await snap("courtyard")
	game.queue_free()
	await frames(4)
	quit()
