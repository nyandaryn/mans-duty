extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame
func run():
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 await process_frame
 game.volume=0;game.primary="svd";game.loadout_bag.equipped=true
 var uid: int=game.loadout_bag.add("recon_drone")
 check(uid>0 and game.loadout_bag.used_slots()==6,"Drone kit occupies six pack cells")
 game.start_match();game.set_physics_process(false);game.player.set_physics_process(false)
 for bot in game.bots+game.allies:bot.set_physics_process(false)
 var player: Operator=game.player
 player.position=Vector3(0,0.03,35);player.rotation=Vector3.ZERO
 await frames(2)
 var rig: FieldRig=player.field_rig
 var mass := player.carried_mass()
 check(rig.request(player.backpack.first("recon_drone")),"Packed drone can be retrieved")
 rig.tick(3.3)
 check(not is_instance_valid(rig.drone) and player.backpack.count("recon_drone")==1,"No drone duplication during access")
 rig.tick(0.2)
 check(is_instance_valid(rig.drone) and player.backpack.count("recon_drone")==0,"Deployment moves item from pack into world")
 if not is_instance_valid(rig.drone):game.queue_free();await process_frame;quit(1);return
 var drone: ReconDrone=rig.drone
 check(absf(player.carried_mass()-(mass-0.8))<0.001,"Controller and goggles remain carried while aircraft flies")
 rig.tick(1.3)
 check(rig.mode=="drone" and drone.piloting and drone.camera.current,"Goggles activate actual drone camera")
 check(not player.shoot(),"Pilot cannot fire firearm")
 var body_position := player.global_position
 Input.action_press("jump");await frames(90);Input.action_release("jump")
 check(drone.global_position.y>2 and drone.armed,"Throttle lifts physical drone")
 check(player.global_position==body_position,"Pilot stays behind while drone flies")
 check(drone.battery<1 and drone.battery>0.9,"Motors consume persistent battery")
 Input.action_press("forward");await frames(50);Input.action_release("forward")
 var speed := drone.velocity.length()
 check(speed>2 and absf(drone.model.rotation.x)>0.02,"Flight has acceleration and model tilt")
 await frames(1)
 check(drone.velocity.length()>0.2,"Releasing sticks does not teleport velocity to zero")
 await frames(100)
 check(drone.velocity.length()<0.3,"Stabilized hover brakes movement")
 check(ReconDrone.FLIGHT_SECONDS>=2400,"A full charge hovers for 40 minutes")
 # Goggles off: the drone hovers on, its picture moves to the wrist display.
 var feed: DroneFeed=game.drone_feed
 check(not feed.visible,"No wrist picture while flying in goggles")
 rig.toggle_drone();await process_frame;await process_frame
 check(rig.mode=="" and drone.armed and not drone.piloting and feed.visible,"Goggles off: drone hovers, wrist display shows its camera")
 check(feed.eye.global_transform.is_equal_approx(drone.camera.global_transform) and feed.feed.render_target_update_mode!=SubViewport.UPDATE_DISABLED,"Wrist display renders from the drone camera")
 check(feed.telemetry.text.contains("АКБ") and feed.telemetry.text.contains("хв") and feed.telemetry.text.contains("АЗ"),"Wrist display shows battery time, bearing and range")
 check(player.current().id=="svd" and not rig.active(),"Rifle stays in hand with the wrist display")
 feed.toggle();await process_frame
 check(not feed.visible and feed.feed.render_target_update_mode==SubViewport.UPDATE_DISABLED,"U hides the wrist display and stops its render")
 feed.toggle();await process_frame
 check(feed.visible,"U shows it again")
 rig.toggle_drone();rig.tick(1.3);await process_frame
 check(rig.mode=="drone" and drone.piloting and not feed.visible,"Goggles back on: piloting again")
 var wall := StaticBody3D.new()
 var obstacle := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(3,4,0.2);obstacle.shape=box;wall.add_child(obstacle)
 game.add_child(wall);wall.global_position=drone.global_position+Vector3.FORWARD*2
 await frames(2)
 Input.action_press("forward");await frames(100);Input.action_release("forward")
 check(drone.global_position.z>wall.global_position.z+0.2,"Drone collides with a wall instead of flying through it")
 wall.queue_free();await frames(2)
 drone.signal_strength=0;drone.link_timer=20;drone.lost_link_time=0
 await frames(100)
 check(drone.velocity.y<0 and drone.notice.contains("АВТОПОСАДКА"),"Sustained radio loss starts physical failsafe descent")
 drone.link_timer=0;await frames(2)
 var pos := drone.global_position;var charge := drone.battery
 game.paused=true;await frames(8)
 check(drone.global_position==pos and drone.battery==charge,"Pause freezes drone and battery")
 game.paused=false
 rig.toggle_drone()
 check(not drone.piloting and player.camera.current,"Removing goggles returns soldier camera")
 check(not rig.recover_drone(),"Airborne drone cannot be packed remotely")
 rig.toggle_drone();rig.tick(1.3)
 Input.action_press("crouch");await frames(210);Input.action_release("crouch")
 check(drone.landed and not drone.armed,"Controlled descent lands and stops motors")
 rig.toggle_drone()
 player.global_position=drone.global_position+Vector3(0,0,1)
 player.global_position.y=0.03
 await frames(2)
 drone.health=0.7
 var retained := drone.battery
 for i in range(12):player.backpack.add("ammo_pm")
 check(rig.recover_drone(),"Recovery begins with the aircraft in reach")
 rig.tick(2.3)
 check(is_instance_valid(rig.drone) and player.backpack.count("recon_drone")==0,"Full pack does not delete or duplicate landed drone")
 player.backpack.items.clear()
 check(rig.recover_drone(),"Pickup can restart after freeing slots")
 rig.tick(0.5);rig.cancel()
 check(is_instance_valid(rig.drone) and player.backpack.count("recon_drone")==0,"Interrupted pickup leaves the original drone on the ground")
 check(rig.recover_drone(),"Landed drone can be picked up nearby")
 rig.tick(1)
 check(is_instance_valid(rig.drone) and player.backpack.count("recon_drone")==0,"Pickup takes time")
 rig.tick(1.3)
 check(not is_instance_valid(rig.drone) and player.backpack.count("recon_drone")==1,"Pickup returns one item")
 var packed: Dictionary=player.backpack.item(player.backpack.first("recon_drone"))
 check(is_equal_approx(packed.battery,retained) and packed.condition==0.7,"Pickup preserves battery and damage")
 var restored := BackpackState.restore(player.backpack.serialize())
 check(restored.items[0].battery==packed.battery and restored.items[0].condition==0.7,"Preset serialization preserves condition")
 await frames(3) # Allow the recovered collider to leave the physics space.
 check(rig.request(int(packed.uid)),"Recovered drone can be retrieved again")
 rig.tick(3.5);rig.tick(1.3)
 check(is_instance_valid(rig.drone) and is_equal_approx(rig.drone.battery,retained),"Redeployment cannot recharge battery")
 if not is_instance_valid(rig.drone):
  printerr("Deployment: ",rig.drone_notice);game.queue_free();await frames(3);quit(1);return
 drone=rig.drone
 game.player.apply_wound({"kind":"graze","plate_loss":0.0,"damage":1.0,"bleeding":0.0,"pain":0.1},"arm",Vector3.RIGHT,player.position)
 check(not drone.piloting and player.camera.current,"Pilot injury tears down FPV view")
 await frames(3)
 var projectile_point := drone.global_position
 game.ballistics.launch(projectile_point+Vector3.UP*2,Vector3.DOWN,"ak74",36,game.bots[0])
 await frames(4)
 check(drone.health<=0,"Real projectile can disable drone without human wound processing")
 game.to_menu()
 check(not drone.piloting,"Menu cannot leave a remote camera active")
 game.queue_free();await frames(3)
 print("FAIL: " if failed else "PASS: ",checks," drone inventory, flight, camera, landing, recovery and damage checks")
 quit(1 if failed else 0)
