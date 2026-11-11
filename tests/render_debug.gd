extends SceneTree
func _initialize():call_deferred("run")
func frames(n: int):
	for i in range(n):await process_frame
func snap(name: String):
	await frames(40)
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
	game.set_debug_invulnerable(true)
	await snap("debug-enabled")
	game.set_pause(true)
	await snap("debug-pause")
	game.set_pause(false)
	game.player.set_physics_process(false)
	game.hud.hide()
	var space := game.get_world_3d().direct_space_state
	for x in [6.5,7.0,7.5]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,0.9,39),Vector3(x,0.9,37),1))
		game.impact(hit.position,hit.normal)
	game.menu_camera.current=true
	game.menu_camera.position=Vector3(9,1.35,40)
	game.menu_camera.look_at(Vector3(7,0.65,38))
	await snap("concrete-impacts")
	game.queue_free()
	await frames(4)
	quit()
