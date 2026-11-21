extends SceneTree

# Screenshots of an enemy turning his rifle up at one of our drones: from the
# side as he fires, and through the goggles with the warning on the picture.
var game: Node3D
var out := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=1):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("SNAP ",name)

func look(from: Vector3, at: Vector3) -> void:
 game.player.global_position=from
 var d:=at-(from+Vector3.UP*1.6)
 game.player.rotation.y=atan2(-d.x,-d.z)
 game.player.pitch=atan2(d.y,Vector2(d.x,d.z).length())

func run():
 seed(22)
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 game.player.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 game.set_debug_invulnerable(true)
 var bot: Hostile=game.bots[0]
 bot.position=Vector3(0,0.1,27);bot.rotation.y=0.0
 game.player.position=Vector3(0,0.1,35)
 await frames(5)
 var drone:=ReconDrone.new()
 game.world_root.add_child(drone)
 drone.setup(game.player,{"battery":1.0,"condition":1.0})
 drone.global_position=Vector3(5,12,7);drone.armed=true;drone.landed=false
 await frames(5)
 # The side view, the drone kept out of reach until he has fired a few.
 drone.health=1000.0
 bot.set_physics_process(true)
 var rounds: int=bot.weapon.rounds()
 var t:=0.0
 while t<8.0 and bot.weapon.rounds()>rounds-3:
  await process_frame
  t+=1.0/60.0
  var at: Vector3=bot.global_position
  var eye:=at+Vector3(-6.5,0,1.5);eye.y=game.district.ground_height(eye)+0.05
  look(eye,at.lerp(drone.global_position,0.25)+Vector3.UP*1.0)
 print("AIM t=%.2f fired=%d engaged=%s state=%s pos=%s" % [t,rounds-bot.weapon.rounds(),str(bot.drone_engaged()),bot.state,str(bot.global_position)])
 await snap("drone-aim",1)
 # Through the goggles, rounds going past.
 var rig: FieldRig=game.player.field_rig
 rig.drone=drone;rig.mode="drone";drone.begin_control()
 drone.yaw=atan2(drone.global_position.x-bot.global_position.x,drone.global_position.z-bot.global_position.z)
 drone.camera_pitch=-0.75
 await frames(20)
 await snap("drone-warning",2)
 # Shot down: the picture tumbles.
 drone.health=1.0
 drone.receive_hit(68.0,"drone",Vector3.FORWARD,drone.global_position)
 await frames(24)
 await snap("drone-down",1)
 quit()
