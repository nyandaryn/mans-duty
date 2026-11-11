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
	seed(123)
	var game: Node3D=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.volume=0
	game.start_match()
	await frames(3)
	var player: Operator=game.player
	player.set_physics_process(false)
	verify(player.position.distance_to(game.district.player_spawn)<0.3,"Player starts in the rear courtyard")
	for bot in game.bots:
		verify(not bot.line_clear(bot.position+Vector3.UP*1.6,player.camera.global_position),"Building blocks every initial enemy sightline")
		verify(game.district.path(bot.position,player.position).size()>1,"Enemies can reach courtyard without crossing a building")
	for exit_point in [Vector3(17,0,43),Vector3(39,0,43)]:verify(game.district.path(player.position,exit_point).size()>1,"Both courtyard exits are reachable")
	await frames(480)
	verify(player.health==100,"Player is not hit during first eight seconds while orienting")
	for bot in game.bots:bot.set_physics_process(false)
	player.position=Vector3(0,0.05,35)
	player.rotation=Vector3.ZERO
	player.prone_requested=true
	player.update_cover(1)
	verify(player.prone and player.camera.position.y<0.45,"Prone lowers the eye to ground level")
	verify(absf(player.body_shape.rotation.x-PI/2)<0.01,"Collision body lies horizontally")
	verify(player.leg_areas[0].position.z>0.9 and player.abdomen_area.position.y>0,"Prone anatomy extends behind head and stays above ground")
	Input.action_press("sprint")
	Input.action_press("forward")
	for i in range(20):player._physics_process(1.0/60)
	verify(Vector2(player.velocity.x,player.velocity.z).length()<0.9,"Sprint cannot exceed crawling speed")
	Input.action_release("forward")
	Input.action_release("sprint")
	Input.action_press("aim")
	player._physics_process(0.016)
	verify(player.aim,"Iron sights remain available while prone")
	Input.action_release("aim")
	player.cooldown=0
	verify(player.shoot(),"Player can fire from prone")
	var side_wall := StaticBody3D.new()
	var side_collision := CollisionShape3D.new()
	var side_box := BoxShape3D.new()
	side_box.size=Vector3(0.15,1,2)
	side_collision.shape=side_box
	side_wall.add_child(side_collision)
	game.add_child(side_wall)
	side_wall.position=player.position+Vector3(0.85,0.5,0.5)
	await frames(2)
	verify(not player.posture_clear(player.body_shape.shape,player.body_shape.transform,PI/2),"Turning cannot sweep the prone legs through a wall")
	var motion := InputEventMouseMotion.new()
	motion.relative=Vector2(-PI/(2*player.sensitivity*(0.65 if player.aim else 1.0)),0)
	var previous_yaw := player.rotation.y
	player._unhandled_input(motion)
	verify(is_equal_approx(player.rotation.y,previous_yaw),"Mouse turn respects prone collision")
	side_wall.free()
	var ceiling := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(3,0.15,3)
	collision.shape=shape
	ceiling.add_child(collision)
	game.add_child(ceiling)
	ceiling.position=player.position+Vector3(0,0.75,0.5)
	await frames(2)
	player.prone_requested=false
	player.update_cover(1)
	verify(player.prone,"Low ceiling prevents standing through cover")
	ceiling.free()
	await frames(2)
	player.prone_requested=false
	player.update_cover(1)
	verify(not player.prone and player.camera.position.y>1.5,"Player can rise when clear")
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size=Vector3(2,2,0.2)
	wall_shape.shape=wall_box
	wall.add_child(wall_shape)
	game.add_child(wall)
	wall.position=player.position+Vector3(0,1,0.8)
	await frames(2)
	player.prone_requested=true
	player.update_cover(1)
	verify(not player.prone,"Cannot put legs through a wall when lying down")
	wall.free()
	game.queue_free()
	await frames(3)
	print("PASS: %d prone, collision, protected-spawn and navigation checks" % checks)
	quit()
