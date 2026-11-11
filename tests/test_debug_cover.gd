extends SceneTree
var checks := 0
func verify(ok: bool, message: String):
	checks+=1
	if not ok:
		printerr("FAIL: ",message)
		quit(1)
		assert(ok,message)
func _initialize():call_deferred("run")
func frames(n: int):
	for i in range(n):await physics_frame
func run():
	var game: Node3D=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.start_match()
	game.volume=0
	game.player.set_physics_process(false)
	for bot in game.bots:bot.set_physics_process(false)
	await frames(3)
	var player: Operator=game.player
	verify(not game.debug_invulnerable,"Debug immortality defaults off")
	player.receive_hit(10,"arm",Vector3.ZERO,player.position)
	verify(player.health<100 and player.arm_injury>0,"Normal damage remains enabled")
	game.set_debug_invulnerable(true)
	verify(player.health==100 and player.arm_injury==0 and player.bleeding==0,"Enabling debug mode restores testing ability")
	player.apply_wound(DamageModel.wound("head","ak74",1,Vector2.ZERO,1),"head",Vector3.FORWARD,player.position)
	player.receive_hit(500,"leg",Vector3.FORWARD,player.position)
	player.take_damage(500)
	verify(player.health==100 and player.leg_injury==0 and game.running,"Immortality blocks fatal hits, wounds and direct damage")
	player.position=Vector3(0,0,35)
	player.rotation=Vector3.ZERO
	player.update_cover(1)
	await frames(2)
	game.ballistics.launch(Vector3(0,1.60,32),Vector3.BACK,"ak74",68,game.bots[0])
	game.ballistics._physics_process(0.005)
	verify(player.health==100 and game.blood.wounds.is_empty(),"Actual head projectile causes neither wounds nor blood in debug mode")
	verify(game.debug_checkbox.button_pressed,"Pause checkbox reflects keyboard/debug state")
	game.set_debug_invulnerable(false)
	player.take_damage(10)
	verify(player.health==90,"Disabling debug restores damage")
	var toggle := InputEventAction.new()
	toggle.action="debug_god"
	toggle.pressed=true
	game._unhandled_input(toggle)
	verify(game.debug_invulnerable,"F8 action enables immortality")
	game.debug_checkbox.button_pressed=false
	verify(not game.debug_invulnerable,"Pause checkbox disables immortality")
	var space := game.get_world_3d().direct_space_state
	for x in [-7.0,7.0]:
		var gap := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x-2,0.9,38.35),Vector3(x+2,0.9,38.35),1))
		verify(gap.is_empty(),"Upper-side empty air of tapered barrier is not solid")
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,0.9,39),Vector3(x,0.9,37),1))
		verify(not hit.is_empty(),"Real barrier surface still stops shots")
		verify(absf(hit.position.z-(38.19-(0.9-0.65)*0.04/0.45))<0.003,"Impact lies on sloped visible surface, not bounding box")
		game.impact(hit.position,hit.normal)
		verify(game.bullet_marks[-1].global_position.distance_to(hit.position)<0.004,"Impact mark hugs real surface")
	var count: int=game.bullet_marks.size()
	game.impact(Vector3(7,0.9,38.35),Vector3.ZERO)
	verify(game.bullet_marks.size()==count,"Inside-collider ray cannot create floating impact mark")
	game.ballistics.launch(Vector3(5,0.9,38.35),Vector3.RIGHT,"ak74",68,player)
	game.ballistics._physics_process(0.005)
	verify(game.ballistics.projectiles.size()==1,"Actual projectile passes former invisible barrier volume")
	game.ballistics.clear()
	game.ballistics.launch(Vector3(7,0.9,39),Vector3.FORWARD,"ak74",68,player)
	game.ballistics._physics_process(0.005)
	verify(game.ballistics.projectiles.is_empty(),"Actual projectile stops on real concrete")
	game.queue_free()
	await frames(3)
	print("PASS: %d debug immortality and exact cover checks" % checks)
	quit()
