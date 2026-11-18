extends SceneTree

var checks := 0

func verify(condition: bool, explanation: String) -> void:
	checks+=1
	if not condition:
		printerr(explanation)
		quit(1)
		assert(condition,explanation)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var step := FlightModel.advance(Vector3.ZERO,Vector3(0,0,-100),INF,1)
	verify(step[0].is_equal_approx(Vector3(0,-4.903325,-100)),"Gravity follows physical acceleration")
	verify(step[1].is_equal_approx(Vector3(0,-9.80665,-100)),"Velocity integrates gravity")
	var slowed := FlightModel.advance(Vector3.ZERO,Vector3(0,0,-880),0.31,0.01)
	verify(slowed[1].length()<880,"Air resistance reduces velocity")
	verify(float(Ballistics.PROFILES.pm.speed)<float(Ballistics.PROFILES.ak74.speed),"Pistol flight is slower than rifle flight")
	var game: Node3D=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true) # This suite uses the fixed legacy city fixture.
	root.add_child(game)
	await process_frame
	game.volume=0
	game.start_match()
	for bot in game.bots:bot.set_physics_process(false)
	await physics_frame
	await physics_frame
	for id in ["ak74","m16","pm","m9"]:
		game.player.slot=0 if id in ["ak74","m16"] else 1
		game.player.weapons[game.player.slot]=WeaponState.new(id)
		game.player.make_viewmodel()
		game.player.viewmodel.position=game.player.ads_position()
		var rear: Vector3=game.player.viewmodel.get_node("RearSight").global_position
		var front: Vector3=game.player.viewmodel.get_node("FrontSight").global_position
		var camera: Camera3D=game.player.camera
		verify(absf(camera.to_local(rear).x)<0.00001 and absf(camera.to_local(rear).y)<0.00001,id+": rear sight is on eye axis")
		verify(absf(camera.to_local(front).x)<0.00001 and absf(camera.to_local(front).y)<0.00001,id+": front post tip aligns with rear sight")
		var state: WeaponState=game.player.current()
		state.reload()
		state.clock=state.phase_duration()*0.9
		game.player.viewmodel.animate(state,0.016)
		verify(game.player.viewmodel.magazine.position.y< -0.2,id+": magazine visibly leaves the well")
		state.update(state.phase_duration()*0.2)
		game.player.viewmodel.animate(state,0.016)
		verify(state.magazine.is_empty() and not state.held_old.is_empty() and game.player.viewmodel.magazine.visible,id+": removed magazine remains in hand until stowed")
	game.player.set_physics_process(false)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(4,4,0.01)
	collision.shape=shape
	wall.add_child(collision)
	wall.position=Vector3(0,2,25)
	game.add_child(wall)
	await physics_frame
	await physics_frame
	var hits_before: int=game.ballistics.hit_count
	game.ballistics.launch(Vector3(0,1.6,40),Vector3.FORWARD,"m16",30,game.player)
	verify(game.ballistics.projectiles.size()==1,"Bullet is queued, not immediate hitscan")
	game.set_pause(true)
	for i in range(3):await physics_frame
	verify(game.ballistics.projectiles.size()==1 and game.ballistics.projectiles[0].position==Vector3(0,1.6,40),"Pause freezes bullets")
	game.set_pause(false)
	for i in range(4):await physics_frame
	verify(game.ballistics.projectiles.is_empty() and game.ballistics.hit_count==hits_before+1,"Swept ray stops a fast bullet on a 1cm wall")
	game.ballistics.set_physics_process(false)
	var near_bot: Hostile=game.bots[0]
	near_bot.position=Vector3(1.2,100,-4)
	await physics_frame
	for dt in [0.004,0.05]:
		game.ballistics.clear();near_bot.suppression=0
		game.ballistics.launch(Vector3(0,101,0),Vector3.FORWARD,"ak74",36,game.player)
		for i in range(5):game.ballistics._physics_process(dt)
		verify(is_equal_approx(near_bot.suppression,0.8),"Near-miss impulse occurs once per bullet at delta "+str(dt))
	game.ballistics.clear()
	game.ballistics.launch(Vector3(0,2,40),Vector3.UP,"pm",1,game.player)
	game.start_match()
	verify(game.ballistics.projectiles.is_empty(),"Restart clears projectiles")
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout # Let the audio mix thread release stopped playback resources.
	print("PASS: %d ballistics, geometry, reload synchronization checks" % checks)
	quit()
