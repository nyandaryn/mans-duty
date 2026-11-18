extends SceneTree
var peak := [0.0,0.0,0.0]
var late_speed := [0.0,0.0,0.0]
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 await process_frame
 game.volume=0;game.start_match();game.player.set_physics_process(false)
 for actor in game.bots:actor.set_physics_process(false)
 for i in range(3):
  var actor: Hostile=game.bots[i]
  actor.position=Vector3(i*3,0,25);actor.rotation=Vector3.ZERO
  actor.stance=1.0 if i==1 else 0.0
  actor.collapse=1.0 if i==2 else 0.0
  actor.animate_pose(1,false);actor.die()
 for frame in range(480):
  await physics_frame
  if true:
   for i in range(3):
    var corpse: Corpse=game.bots[i].get_node("Corpse")
    var spin := 0.0;var speed := 0.0;var sleeping := 0
    for body in corpse.bodies:
     spin=maxf(spin,body.angular_velocity.length());speed=maxf(speed,body.linear_velocity.length())
     if body.sleeping:sleeping+=1
    peak[i]=maxf(peak[i],spin)
    if frame>360:late_speed[i]=maxf(late_speed[i],speed)
 var failed := false
 for i in range(3):
  if peak[i]>(30 if i==2 else 75) or late_speed[i]>0.45:
   failed=true;printerr("FAIL: corpse stability pose ",i," peak ",peak[i]," late speed ",late_speed[i])
 print("FAIL: " if failed else "PASS: ","standing / kneeling / prone corpses settle without explosive rotation; peaks=",peak)
 game.queue_free();await process_frame;quit(1 if failed else 0)
