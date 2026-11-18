extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame
func obstacle(parent: Node, center: Vector3, size: Vector3) -> StaticBody3D:
 var body := StaticBody3D.new()
 var collision := CollisionShape3D.new();var box := BoxShape3D.new();box.size=size;collision.shape=box
 body.add_child(collision);parent.add_child(body);body.position=center
 return body
func run():
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 await process_frame
 game.volume=0;game.loadout_bag.equipped=true;game.loadout_bag.add("recon_drone")
 game.start_match();game.set_physics_process(false);game.player.set_physics_process(false)
 for bot in game.bots+game.allies:bot.set_physics_process(false)
 var player: Operator=game.player
 var platform := obstacle(game,Vector3(100,15,100),Vector3(9,0.4,9))
 for slope in [0.0,12.0,25.0,35.0,-30.0]:
  platform.rotation.x=deg_to_rad(slope)
  await frames(2)
  for heading in [0.0,PI/2,PI]:
   player.position=platform.to_global(Vector3(0,0.2,0))+Vector3.UP*0.03
   player.rotation=Vector3(0,heading,0)
   player.prone=false;player.prone_requested=true;player.field_rig.mode=""
   player.update_cover(1)
   var context := " slope %s heading %s" % [slope,heading]
   check(player.prone,"Can lie on actual sloping collision geometry"+context)
   check((player.global_basis*player.prone_surface.basis.y).dot(platform.global_basis.y)>0.98,"Prone body follows support plane"+context)
   var previous := player.chest_area.transform
   for i in range(20):player.update_cover(0.016)
   check(player.chest_area.transform.is_equal_approx(previous),"Hitboxes cannot accumulate slope rotation"+context)
   check(player.prone_turn_clear(0.10),"Prone turn follows slope"+context)
   var deployment: Variant=player.field_rig.deployment_point()
   check(deployment!=null,"Drone can be deployed while prone on slope"+context)
   if deployment!=null:
    check(deployment.basis.y.dot(platform.global_basis.y)>0.98,"Drone placement follows ground"+context)
   player.prone_requested=false;player.update_cover(1)
   check(not player.prone,"Can rise from slope"+context)
 platform.rotation=Vector3.ZERO;await frames(2)
 player.position=Vector3(100,15.23,100);player.rotation=Vector3.ZERO
 var bump := obstacle(game,Vector3(100,15.24,100.8),Vector3(0.8,0.08,0.35))
 await frames(2)
 player.prone_requested=true;player.update_cover(1)
 check(player.prone,"Small uneven steps do not prevent lying down")
 bump.free()
 # A blocked centre patch must not reject reachable patches to either side.
 var block := obstacle(game,player.position+Vector3(0,0.30,-1.05),Vector3(0.20,0.60,0.20))
 await frames(2)
 var alternate: Variant=player.field_rig.deployment_point()
 check(alternate!=null and absf(alternate.origin.x-player.position.x)>0.3,"Placement finds a free side patch")
 block.free()
 var wall := obstacle(game,player.position+Vector3(0,0.9,-0.45),Vector3(3,2,0.15))
 await frames(2)
 check(player.field_rig.deployment_point()==null,"Cannot deploy through wall")
 wall.free()
 player.position=Vector3(120,15,100)
 check(player.field_rig.deployment_point()==null,"Cannot deploy without supporting ground")
 # The support fit must not repeatedly lift the collider while letting its
 # CharacterBody parent sink, including after movement changes the slope.
 platform.rotation.x=deg_to_rad(25);await frames(2)
 player.position=platform.to_global(Vector3(0,0.2,0))+Vector3.UP*0.06
 player.prone_requested=true;player.update_cover(1)
 player.set_physics_process(true)
 await frames(100)
 check(absf(platform.to_local(player.global_position).y-0.2)<0.20,"Prone physics does not sink into ground over time")
 Input.action_press("forward");await frames(60);Input.action_release("forward")
 await frames(20);player.set_physics_process(false)
 check(player.prone and absf(platform.to_local(player.global_position).y-0.2)<0.20,"Crawling remains supported on uneven ground")
 # A real flight/landing/pickup cycle on a 25-degree slope.
 player.prone_requested=false;player.update_cover(1)
 var rig: FieldRig=player.field_rig
 check(rig.request(player.backpack.first("recon_drone")),"Start sloped deployment")
 rig.tick(3.5);rig.tick(1.3)
 check(is_instance_valid(rig.drone),"Actual deployment on slope succeeds")
 if is_instance_valid(rig.drone):
  var drone: ReconDrone=rig.drone
  await frames(80)
  check(drone.landed and drone.health==1,"Sloped placement settles without impact damage")
  Input.action_press("jump");await frames(65);Input.action_release("jump")
  check(not drone.landed and drone.global_basis.y.dot(Vector3.UP)>0.99,"Drone levels after takeoff")
  Input.action_press("crouch");await frames(180);Input.action_release("crouch")
  check(drone.landed and not drone.armed,"Drone lands and disarms on slope")
  rig.toggle_drone();await frames(30)
  check(drone.can_recover(),"Sloped landing remains recoverable")
 game.queue_free();await frames(3)
 print("FAIL: " if failed else "PASS: ",checks," uneven-ground posture, placement, obstruction and sloped flight checks")
 quit(1 if failed else 0)
