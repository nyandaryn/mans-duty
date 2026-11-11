extends SceneTree
var game: Node3D
var checks := 0
func verify(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		printerr("FAIL: ",message)
		quit(1)
		assert(ok,message)
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func run() -> void:
	seed(417)
	var stopped := DamageModel.wound("plate","ak74",0.98,Vector2.ZERO,1.0)
	verify(stopped.kind=="blunt" and stopped.bleeding==0,"Intact ceramic plate stops configured rifle projectile without open bleeding")
	verify(DamageModel.wound("plate","ak74",0.98,Vector2.ZERO,0.1).kind=="plate_penetration","Damaged plate can be penetrated")
	verify(DamageModel.wound("head","pm",0.3,Vector2.ONE,1).damage>=100,"Head hit is fatal regardless of graze coordinates")
	var artery := DamageModel.wound("leg","ak74",1,Vector2(0.1,0.4),1)
	var graze := DamageModel.wound("leg","ak74",1,Vector2(0.95,0.3),1)
	verify(artery.kind=="arterial" and artery.bleeding>3 and artery.disabled,"Central upper-leg hit produces severe bleeding and loss of function")
	verify(graze.kind=="graze" and not graze.disabled and graze.bleeding<0.2,"Marginal hit is a lighter graze")
	verify(DamageModel.wound("abdomen","ak74",1,Vector2.ZERO,1).kind=="internal","Unprotected abdomen has internal injury")
	game=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.volume=0
	game.start_match()
	game.player.set_physics_process(false)
	for bot in game.bots:bot.set_physics_process(false)
	await frames(3)
	var bot: Hostile=game.bots[0]
	bot.position=Vector3(0,0,0)
	bot.rotation=Vector3.ZERO
	await frames(2)
	game.ballistics.launch(Vector3(0,1.65,30),Vector3.FORWARD,"ak74",36,game.player)
	await frames(5)
	verify(bot.dead,"One actual AK projectile to the head neutralizes at 30m")
	await frames(100)
	verify(game.blood.wounds.size()>0 and game.blood.ground_marks.size()>0,"Actual wound stains the body and creates ground blood marks")
	var corpse: Corpse=bot.get_node_or_null("Corpse")
	# Default Node name is class-independent: find by type.
	if corpse==null:
		for child in bot.get_children():
			if child is Corpse:corpse=child
	verify(corpse!=null and corpse.bodies.size()==11,"Death creates jointed rigid bodies and detached rifle")
	var torso: RigidBody3D=corpse.get_node("Torso")
	verify(torso.global_position.y<0.85 and torso.global_position.y>0.05,"Ragdoll torso falls onto ground rather than rotating in place")
	var before := torso.global_transform
	game.set_pause(true)
	await frames(2)
	before=torso.global_transform
	await frames(8)
	verify(torso.global_transform.is_equal_approx(before),"Pause freezes corpse simulation")
	game.set_pause(false)
	var wounded: Hostile=game.bots[1]
	wounded.receive_hit(DamageModel.damage("ak74","chest",0.98),"chest",Vector3.FORWARD,wounded.position+Vector3.UP)
	verify(not wounded.dead and wounded.wound_timer>0 and wounded.bleeding>0,"Chest wound interrupts aim and causes bleeding")
	wounded.receive_hit(20,"leg",Vector3.FORWARD,wounded.position)
	verify(wounded.leg_wound>0,"Leg injury reduces mobility")
	var listener: Hostile=game.bots[2]
	listener.hear(listener.position+Vector3(0,0,95))
	verify(listener.pending_delay>0,"Distant gunfire creates delayed hearing contact")
	listener.pending_delay=0
	listener._physics_process(0.016)
	verify(listener.alerted and listener.contact_age<0.1,"Hearing changes behavior after reaction delay")
	verify(listener.state!="patrol","Alerted bot leaves patrol state")
	listener.weapon.magazine.rounds=0
	listener.weapon.chambered=false
	listener._physics_process(0.016)
	verify(listener.weapon.phase=="remove","Bot starts a real magazine reload when empty")
	for i in range(300):listener._physics_process(1.0/60)
	verify(listener.weapon.chambered and listener.weapon.rounds()>0,"Bot reload chambers from a finite magazine")
	var operator: Operator=game.player
	operator.position=Vector3(0,0,35)
	operator.rotation=Vector3.ZERO
	Input.action_press("crouch")
	operator.update_cover(1)
	verify(operator.body_shape.shape.height<1.3,"Crouch shrinks movement capsule")
	var crouch_eye := operator.camera.position.y
	Input.action_press("peek_up")
	operator.update_cover(1)
	verify(operator.camera.position.y>crouch_eye+0.3,"Top peek exposes eye and body above low cover")
	Input.action_press("blind_modifier")
	operator.update_cover(1)
	operator.update_pose(1)
	verify(operator.blind_mode==2 and operator.camera.position.y<crouch_eye+0.05,"Blind top fire keeps head down")
	verify(operator.viewmodel.position.y>0.5,"Blind top fire raises weapon only")
	Input.action_release("peek_up")
	Input.action_release("blind_modifier")
	Input.action_press("lean_right")
	operator.update_cover(1)
	verify(operator.camera.position.x>0.3,"Lean shifts viewpoint sideways")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(0.1,3,3)
	collision.shape=box
	wall.add_child(collision)
	wall.position=operator.position+Vector3(0.22,1,0)
	game.add_child(wall)
	await frames(2)
	operator.update_cover(1)
	verify(operator.camera.position.x<0.12,"Lean camera stops before a wall")
	for action in ["crouch","lean_right"]:Input.action_release(action)
	wall.queue_free()
	await frames(2)
	operator.receive_hit(24,"arm",Vector3.FORWARD,operator.position)
	verify(not operator.shoot(),"Arm injury prevents firing")
	var event := InputEventAction.new()
	event.action="bandage"
	event.pressed=true
	operator._unhandled_input(event)
	verify(operator.bandage_time==Operator.MEDICAL_TIME,"Universal kit starts timed treatment")
	var old_health := operator.health
	for i in range(120):operator._physics_process(1.0/60)
	verify(operator.health<=old_health and operator.bandage_time>0,"Treatment is not an instant heal")
	verify(operator.medical_rig.visible,"Treatment displays animated medical kit and hands")
	for i in range(245):operator._physics_process(1.0/60)
	verify(operator.health==100 and operator.arm_injury==0 and operator.bleeding==0 and operator.bandages==1,"Completed kit restores wounds and consumes one kit")
	operator.cooldown=0
	operator.shoot()
	verify(operator.recoil_velocity.length()>0.1 and operator.gun_kick>0,"Shot produces angular recoil and weapon kick")
	var initial_velocity := operator.recoil_velocity.length()
	for i in range(100):operator._physics_process(1.0/60)
	verify(operator.recoil_velocity.length()<initial_velocity*0.1,"Recoil settles between shots")
	game.start_match()
	await frames(2)
	verify(game.bots.size()==10,"Restart removes old corpses and resets actors")
	game.queue_free()
	await process_frame
	print("PASS: %d wound, ragdoll, hearing, reload and cover checks"%checks)
	quit()
