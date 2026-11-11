extends SceneTree
func _initialize():call_deferred("run")
func frames(n: int):
	for i in range(n):await process_frame
func run():
	var game: Node3D=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.volume=0
	game.start_match()
	game.player.set_physics_process(false)
	for enemy in game.bots:enemy.set_physics_process(false)
	game.hud.hide()
	var bot: Hostile=game.bots[0]
	bot.position=Vector3(0,0,30)
	bot.rotation=Vector3.ZERO
	bot.alerted=true
	bot.aim_weight=1
	bot.known_height=1.6
	bot.target=Vector3(0,0,20)
	var camera: Camera3D=game.menu_camera
	camera.current=true
	for stance in [0.0,1.0]:
		bot.stance=stance
		bot.animate_pose(1,false)
		camera.position=Vector3(1.45,1.6-stance*0.49,30.10)
		camera.look_at(Vector3(0,1.48-stance*0.49,29.8))
		await frames(60)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+("/head-standing.png" if stance==0 else "/head-crouching.png"))
	game.queue_free()
	await frames(4)
	quit()
