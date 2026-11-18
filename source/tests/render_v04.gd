extends SceneTree
var game: Node3D
func _initialize():call_deferred("run")
func frames(n: int):
	for i in range(n):await process_frame
func snap(name: String):
	await frames(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/"+name+".png")
	print("SNAP ",name," FPS=",Engine.get_frames_per_second())
func run():
	game=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.volume=0
	game.start_match()
	game.player.set_process_unhandled_input(false)
	for bot in game.bots:bot.set_physics_process(false)
	game.player.slot=1
	game.player.weapons[1]=WeaponState.new("pm")
	game.player.make_viewmodel()
	await snap("pm-hip")
	Input.action_press("aim")
	await frames(45)
	await snap("pm-ads")
	Input.action_release("aim")
	game.player.set_physics_process(false)
	game.hud.hide()
	var camera: Camera3D=game.menu_camera
	camera.current=true
	camera.position=Vector3(4,7,38)
	camera.look_at(Vector3(0,4,-5))
	await snap("lighting")
	var bot: Hostile=game.bots[0]
	bot.position=Vector3(0,0,30)
	bot.rotation=Vector3.ZERO
	bot.alerted=true
	bot.target=Vector3(0,0,20)
	bot.aim_weight=1
	bot.animate_pose(1,false)
	camera.position=Vector3(1.5,1.4,27.5)
	camera.look_at(Vector3(0,1.1,30))
	await snap("bot-aim")
	bot.stance=1
	bot.animate_pose(1,false)
	await snap("bot-crouch")
	bot.weapon.reload()
	bot.weapon.clock=0.4
	bot.animate_pose(1,false)
	await snap("bot-reload")
	bot.weapon.cancel()
	bot.stance=0
	bot.animate_pose(1,false)
	var area: Area3D=bot.model.get_node("LeftLeg/Hit_leg")
	var point := area.to_global(Vector3(0,-0.12,-0.11))
	var wound := DamageModel.wound("leg","ak74",1,Vector2(0.1,0.4),1)
	bot.apply_wound(wound,"leg",Vector3.BACK,point)
	game.blood.add_wound(bot,area,point,Vector3.FORWARD,wound)
	await frames(180)
	camera.position=Vector3(0.8,1.1,28.3)
	camera.look_at(Vector3(0,0.65,30))
	await snap("bleeding")
	bot.receive_hit(300,"head",Vector3.BACK,bot.position+Vector3.UP*1.65)
	await frames(180)
	camera.position=Vector3(1.5,3.0,27.8)
	camera.look_at(Vector3(0,0.3,30))
	await snap("ragdoll")
	game.start_match()
	for enemy in game.bots:enemy.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.player.receive_hit(20,"arm",Vector3.FORWARD,game.player.position)
	game.player.blood_loss=0.55
	await snap("wounded")
	var use := InputEventAction.new()
	use.action="bandage"
	use.pressed=true
	game.player._unhandled_input(use)
	await frames(100)
	await snap("medical-kit")
	await frames(300)
	await snap("treated")
	game.start_match()
	game.player.set_process_unhandled_input(false)
	game.player.set_physics_process(false)
	game.player.health=10000
	game.alert_bots(game.player.position)
	await frames(360)
	for enemy in game.bots:print("AI ",enemy.state," cover=",enemy.has_cover," aimed=",enemy.aim_weight," rounds=",enemy.weapon.rounds())
	await snap("combat")
	game.queue_free()
	await frames(5)
	quit()
