extends SceneTree
var checks := 0
func verify(value: bool, message: String):
	checks+=1
	assert(value,message)
func _initialize():call_deferred("run")
func frames(n: int):
	for i in range(n):await physics_frame
func run():
	seed(417)
	var game: Node3D=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.volume=0
	game.start_match()
	game.player.set_physics_process(false)
	for enemy in game.bots:enemy.set_physics_process(false)
	var bot: Hostile=game.bots[0]
	bot.position=Vector3(0,0,30)
	bot.rotation=Vector3.ZERO
	bot.alerted=true
	bot.aim_weight=1
	bot.known_height=1.6
	var head: Node3D=bot.model.get_node("Head")
	for stance in [0.0,1.0]:
		bot.stance=stance
		bot.target=Vector3(0,30,20)
		bot.animate_pose(1,false)
		verify(head.rotation.x<=0.1001,"High target cannot throw the head backward")
		verify(head.position.z<0,"Aiming leans head forward toward the sight")
		bot.target=Vector3(0,-30,20)
		bot.animate_pose(1,false)
		verify(head.rotation.x>=-0.2801,"Looking down keeps bounded neck flexion")
	bot.stance=0
	bot.target=Vector3(0,0,20)
	bot.animate_pose(1,false)
	var eye := head.to_global(Vector3(0.047,0.17,-0.126))
	var sight: Vector3=bot.model.get_node("CarriedRifle/RearSight").global_position
	verify(absf(eye.x-sight.x)<0.035 and absf(eye.y-sight.y)<0.04,"Eye aligns with sight without head extension")
	await frames(2)
	bot.receive_hit(300,"head",Vector3.BACK,bot.position+Vector3.UP*1.65)
	await frames(2)
	var corpse: Corpse=bot.get_node("Corpse")
	verify(corpse.get_node("NeckJoint") is Generic6DOFJoint3D,"Neck has separate directional angular limits")
	var skull: RigidBody3D=corpse.get_node("Head")
	var torso: RigidBody3D=corpse.get_node("Torso")
	var reference := torso.global_basis.inverse()*skull.global_basis
	await frames(180)
	var relative := torso.global_basis.inverse()*skull.global_basis
	var angles := (relative*reference.inverse()).get_euler()
	print("NECK settled relative angles ",angles)
	verify(absf(angles.x)<0.6 and absf(angles.z)<0.4,"Settled head remains within a bounded neck pose")
	game.queue_free()
	await frames(3)
	print("PASS: %d neck pose and ragdoll checks" % checks)
	quit()
