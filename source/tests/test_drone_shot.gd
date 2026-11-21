extends SceneTree

# Drones are brought down by rifle fire and by bursts, and an enemy who sees
# or hears one of ours in the air turns his rifle on it.
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame

var game: Node3D

func hover(at: Vector3, side_friendly: bool=true) -> ReconDrone:
 var drone:=ReconDrone.new()
 game.world_root.add_child(drone)
 drone.setup(game.player,{"battery":1.0,"condition":1.0})
 drone.friendly=side_friendly
 drone.global_position=at
 drone.armed=true;drone.landed=false
 return drone

func tilt(drone: ReconDrone) -> float:return drone.global_basis.y.normalized().angle_to(Vector3.UP)

func run():
 seed(int(OS.get_environment("DRONE_SEED")) if OS.get_environment("DRONE_SEED")!="" else 404)
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 var player: Operator=game.player
 var bot: Hostile=game.bots[0]
 # The enemy looks north, the player is behind him: only the drone is in front.
 bot.position=Vector3(0,0.1,27);bot.rotation.y=0.0
 player.position=Vector3(0,0.1,35)
 bot.animate_pose(1,false)
 await frames(2)

 # A rifle round from our side through a hovering drone.
 var drone:=hover(Vector3(-3,6,24))
 await frames(10)
 check(drone.flying() and drone.is_in_group("drones"),"A hovering drone is in the air under power")
 var muzzle:=player.camera.global_position
 game.ballistics.launch(muzzle,muzzle.direction_to(drone.global_position),"ak74",68,player)
 var top_tilt:=0.0
 for i in range(30):
  await physics_frame
  if drone.health<=0:break
 check(drone.health<=0 and drone.downed>0 and not drone.armed,"One 5.45 round brings a quadcopter down")
 check(drone.notice=="ДРОН ЗБИТО" and drone.alarm()=="ДРОН ЗБИТО","The goggles say it was shot down")
 var height:=drone.global_position.y
 for i in range(240):
  await physics_frame
  top_tilt=maxf(top_tilt,tilt(drone))
  if drone.landed:break
 check(drone.landed and drone.global_position.y<height-4.0,"Shot down, it falls to the ground (%.1f → %.1f m)" % [height,drone.global_position.y])
 check(top_tilt>0.6,"It turns over as it falls (%.0f°)" % rad_to_deg(top_tilt))
 check(not drone.flying() and not drone.armed,"On the ground it stays down")
 drone.queue_free()

 # The pilot sees the fall a moment before the picture is gone (high
 # enough not to hit the ground first: the impact ends the picture too).
 drone=hover(Vector3(-3,16,24))
 await frames(5)
 var lost := {"at":-1.0}
 var clock := {"t":0.0}
 drone.piloting=true
 drone.on_lost=func():
  lost.at=clock.t
  drone.piloting=false
 drone.receive_hit(68.0,"drone",Vector3.FORWARD,drone.global_position)
 for i in range(150):
  await physics_frame
  clock.t+=1.0/60.0
  if lost.at>=0:break
 check(lost.at>=ReconDrone.FALL_SHOWN-0.1 and lost.at<ReconDrone.FALL_SHOWN+0.4,"Goggles show the fall, then lose the picture (%.2f s)" % float(lost.at))
 drone.queue_free()

 # Which drones an enemy pays attention to.
 var eye: Vector3=bot.n_head.to_global(CharacterArt.EYE)
 var landed:=hover(Vector3(2,0.2,18))
 landed.armed=false
 var theirs:=hover(Vector3(-4,9,12),false)
 var far:=hover(Vector3(10,30,27-130))
 await frames(40)
 check(landed.landed and not landed.flying(),"A drone on the ground is not flying")
 for i in range(8):bot.spot_drone(eye,0.35)
 check(bot.drone_target==null and not bot.drone_engaged(),"Ignored: one on the ground, his own side's, one beyond sight (%s)" % str(bot.drone_target))
 for d in [landed,theirs,far]:d.queue_free()
 await frames(2)

 # An enemy sees one of ours over him and shoots it down.
 drone=hover(Vector3(5,12,7))
 await frames(5)
 check(bot.line_clear(eye,drone.global_position),"Clear sky between the enemy and the drone")
 bot.set_physics_process(true)
 var noticed := -1.0
 var first_shot := -1.0
 var warned := false
 var down_at := -1.0
 var t := 0.0
 var rounds: int=bot.weapon.rounds()
 while t<25.0:
  await physics_frame
  t+=1.0/60.0
  if noticed<0 and bot.drone_engaged():noticed=t
  if first_shot<0 and bot.weapon.rounds()<rounds:first_shot=t
  if drone.alarm()=="ПО ДРОНУ ВЕДУТЬ ВОГОНЬ":warned=true
  if drone.health<=0:
   down_at=t
   break
 print("DRONE noticed=%.2f first_shot=%.2f down=%.2f fired=%d" % [noticed,first_shot,down_at,rounds-bot.weapon.rounds()])
 check(noticed>0.2 and noticed<3.0,"The enemy notices the drone after a moment (%.2f s)" % noticed)
 check(first_shot>noticed and first_shot<noticed+3.0,"He raises his rifle and opens fire (%.2f s)" % first_shot)
 check(warned,"Our pilot is warned that the drone is under fire")
 check(down_at>0,"He shoots it down (%.2f s, %d rounds)" % [down_at,rounds-bot.weapon.rounds()])
 var after: int=bot.weapon.rounds()
 await frames(150)
 check(bot.weapon.rounds()>=after-1 and not bot.drone_engaged(),"He stops firing at a drone that is down")
 bot.set_physics_process(false)
 drone.queue_free()

 # A burst close by brings one down.
 drone=hover(Vector3(40,7,-20))
 await frames(5)
 game.blasts.detonate(drone.global_position+Vector3(3,-4,0),"rpo")
 await frames(2)
 check(drone.health<=0 and drone.downed>0,"Fragments of a burst nearby bring it down")

 print("FAIL: " if failed else "PASS: ",checks," drone shot-down and anti-drone fire checks")
 game.queue_free()
 await process_frame
 quit(1 if failed else 0)
