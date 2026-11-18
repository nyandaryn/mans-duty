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
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 game.player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 # Real PM projectiles at the face and upper helmet, standing and kneeling,
 # front and side. Each shot uses a fresh actor and full-health head.
 var index := 0
 for stance in [0.0,1.0]:
  for direction in [Vector3.BACK,Vector3.LEFT]:
   for height in [0.1453,0.268]:
    var bot: Hostile=game.bots[index]
    index+=1
    bot.position=Vector3(0,0,25)
    bot.rotation=Vector3.ZERO
    bot.stance=stance
    bot.alerted=true
    bot.aim_weight=1
    bot.target=Vector3(0,0,10)
    bot.animate_pose(1,false)
    await frames(2)
    var point: Vector3=bot.model.get_node("Head").to_global(Vector3(0,height,-0.045))
    game.ballistics.launch(point-direction*2,direction,"pm",40,game.player)
    await frames(3)
    verify(bot.dead,"Single real PM head hit, stance %s direction %s height %s" % [stance,direction,height])
    bot.position=Vector3(40,0,-40)
 var patient: Hostile=game.bots[8]
 patient.position=Vector3(0,0,25)
 patient.rotation=Vector3.ZERO
 patient.stance=1
 patient.animate_pose(1,false)
 var knee_l: Node3D=patient.model.get_node("LeftLeg/Knee")
 var knee_r: Node3D=patient.model.get_node("RightLeg/Knee")
 verify(knee_l.global_position.z<patient.position.z-0.3,"Front knee points forward")
 verify(knee_r.global_position.y<0.13,"Rear knee rests near ground")
 verify(patient.model.get_node("RightLeg/Knee/Foot").global_position.z>patient.position.z+0.3,"Rear shin folds backward rather than forward")
 for side in ["Left","Right"]:
  var foot: Node3D=patient.model.get_node(side+"Leg/Knee/Foot")
  verify(absf(foot.global_position.y-0.10)<0.025,"Kneeling boot remains grounded")
 patient.stance=0
 patient.animate_pose(1,false)
 await frames(2)
 var thigh: Area3D=patient.model.get_node("LeftLeg/Hit_leg")
 var center := thigh.global_position
 # A lateral through-shot used to be classified as a 7-damage graze.
 game.ballistics.launch(center+Vector3.LEFT*2,Vector3.RIGHT,"ak74",68,game.player)
 await frames(3)
 verify(patient.health<60 and patient.leg_wound>=0.5,"Lateral thigh hit causes substantial damage and disability")
 verify(patient.last_wound=="arterial" and patient.bleeding>3,"Central thigh trajectory causes severe bleeding")
 verify(patient.collapse_time>0 and patient.wound_timer>=1.9,"Leg injury triggers collapse and interrupts combat")
 var rounds := patient.weapon.rounds()
 for i in range(30):patient._physics_process(1.0/60)
 verify(patient.weapon.rounds()==rounds and patient.collapse>0.9,"Injured bot falls and cannot continue firing")
 for i in range(130):patient._physics_process(1.0/60)
 verify(patient.treatment_time>0 and patient.medical_prop.visible,"Bot begins visible timed treatment")
 var timer := patient.treatment_time
 game.paused=true
 patient._physics_process(1)
 verify(patient.treatment_time==timer,"Pause freezes treatment")
 game.paused=false
 patient.apply_wound(DamageModel.wound("leg","pm",1,Vector2(1,0),1),"leg",Vector3.RIGHT,center)
 verify(patient.treatment_time==0 and patient.medical_kits==2,"New hit interrupts treatment without consuming kit")
 # Allow enough health for this deliberate second-wound interruption scenario.
 patient.health=100
 for i in range(510):patient._physics_process(1.0/60)
 verify(patient.medical_kits==1 and patient.bleeding==0 and patient.leg_wound==0,"Completed kit stops bleeding and restores temporary game limb function")
 verify(patient.plate_integrity==1,"Treatment does not change armor")
 # Same trajectory classifier is used for both player and NPC wounds.
 for direction in [Vector3.RIGHT,Vector3.BACK,Vector3(1,0,1).normalized()]:
  var location := DamageModel.trajectory_location(thigh,thigh.global_position,direction)
  verify(DamageModel.wound("leg","ak74",1,location,1).kind=="arterial","Central track remains severe independently of entry face")
 var shin: Area3D=patient.model.get_node("LeftLeg/Knee/Hit_leg")
 var shin_location := DamageModel.trajectory_location(shin,shin.global_position,Vector3.RIGHT)
 verify(DamageModel.wound("leg","ak74",1,shin_location,1).kind!="arterial","Lower leg does not inherit upper-leg vessel proxy")
 var player: Operator=game.player
 player.position=Vector3(0,0.2,35)
 player.rotation=Vector3.ZERO
 await frames(2)
 player.apply_wound(DamageModel.wound("leg","pm",1,Vector2(0,0.5),1),"leg",Vector3.RIGHT,player.position)
 player.update_cover(1)
 verify(player.prone and player.leg_injury>=0.5,"Player with disabling leg wound falls prone")
 player.prone_requested=false
 player.update_cover(1)
 verify(player.prone,"Disabled leg prevents standing before treatment")
 player.blood_loss=0.7
 player.injury_time=0
 verify(not player.shoot(),"Critical blood loss prevents firing")
 game.set_debug_invulnerable(true)
 verify(player.leg_injury==0 and player.blood_loss==0,"Debug recovery restores injury state")
 # Regression: arm injury outlives the old 1.2-second fall timer.
 patient.health=100
 patient.bleeding=0
 patient.blood_loss=0
 patient.medical_kits=0
 patient.receive_hit(8,"arm",Vector3.RIGHT,patient.position)
 patient.sprinting=true
 patient.peek_side=1
 for i in range(660):patient._physics_process(1.0/60)
 verify(patient.collapse>0.99,"Untreated arm wound remains prone beyond initial shock and fall timers")
 verify(not patient.sprinting and patient.peek_side==0,"Wounded bot cancels sprinting and peeking")
 verify(not patient.shoot(game.player,20.0),"Prone injured bot cannot resume shooting")
 patient.medical_kits=1
 patient._physics_process(1.0/60)
 verify(patient.treatment_time>0,"Persistent arm injury starts first aid when kit available")
 for i in range(240):patient._physics_process(1.0/60)
 verify(patient.collapse>0.99 and patient.treatment_time>0,"First aid remains fully prone after collapse timer expires")
 for i in range(180):patient._physics_process(1.0/60)
 verify(patient.arm_wound==0 and patient.medical_kits==0,"Completed treatment allows recovery from arm injury")
 patient.apply_wound({"kind":"graze","plate_loss":0.0,"damage":1.0,"bleeding":0.0},"arm",Vector3.RIGHT,patient.position)
 for i in range(30):patient._physics_process(1.0/60)
 verify(patient.collapse>0.99,"Graze triggers quick protective drop rather than kneeling")
 # Flinch remains bounded at every frame rate; no per-frame accumulated roll.
 for rate in [30,60,120]:
  patient.lean_roll=0;patient.model.rotation.z=0;patient.peek_side=0
  var maximum_roll := 0.0
  for frame in range(rate*3):
   patient.injury_age=float(frame)/rate
   patient.wound_timer=3-patient.injury_age
   patient.animate_pose(1.0/rate,false)
   maximum_roll=maxf(maximum_roll,absf(patient.model.rotation.z))
  verify(maximum_roll<0.026,"Wound flinch is bounded independently of FPS: "+str(rate))
 patient.wound_timer=0;patient.animate_pose(1.0/60,false)
 verify(absf(patient.model.rotation.z)<0.001,"No accumulated roll remains after wound reaction")
 game.queue_free()
 await frames(3)
 print("PASS: %d real projectile, kneeling, wound and treatment checks" % checks)
 quit()
