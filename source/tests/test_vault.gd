extends SceneTree
var checks := 0
var failed := false
var game: Node3D
var player: Operator
var fixture: Node3D
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame
func box(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
 var body := StaticBody3D.new();var collision := CollisionShape3D.new();var shape := BoxShape3D.new()
 shape.size=size;collision.shape=shape;body.add_child(collision);parent.add_child(body);body.position=pos
 return body
func window_fixture(yaw: float=0, width: float=1.3, height: float=0.87, ceiling: float=2.22):
 if is_instance_valid(fixture):fixture.free()
 fixture=Node3D.new();game.add_child(fixture);fixture.position=Vector3(100,15,100);fixture.rotation.y=yaw
 box(fixture,Vector3(0,-0.2,0),Vector3(12,0.4,12))
 box(fixture,Vector3(0,height/2,0),Vector3(4,height,0.30))
 box(fixture,Vector3(0,(3+ceiling)/2,0),Vector3(4,3-ceiling,0.30))
 for side in [-1,1]:box(fixture,Vector3(side*(width/2+0.5),1.5,0),Vector3(1,3,0.3))
 await frames(2)
 await reset_player()
func reset_player():
 Input.action_release("jump");Input.action_release("crouch")
 if player.is_vaulting():player.vault.cancel()
 player.health=100;player.arm_injury=0;player.leg_injury=0;player.injury_time=0;player.blood_loss=0;player.bleeding=0
 player.prone=false;player.prone_requested=false;player.bandage_time=0;player.switch_delay=0;player.field_rig.cancel();player.current().cancel()
 game.inventory.close();game.squad.close();game.paused=false
 player.rotation=fixture.rotation;player.position=fixture.to_global(Vector3(0,0.03,0.80));player.velocity=Vector3.ZERO
 player.pitch=0;player.update_cover(1)
 for i in range(5):player._physics_process(1.0/60);await physics_frame
func tick_vault():
 for i in range(110):
  player._physics_process(1.0/60)
  if i%4==0:await physics_frame
func run():
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0;game.ally_count=0;game.start_match();game.set_physics_process(false)
 player=game.player;player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 for yaw in [0.0,0.63,PI]:
  await window_fixture(yaw)
  check(player.is_on_floor(),"Grounded before vault")
  var plan := player.vault.probe()
  check(not plan.is_empty(),"Detect rotated real window: %s" % yaw)
  if plan.is_empty():continue
  player.set_physics_process(true);Input.action_press("jump");await frames(2)
  Input.action_release("jump");player.set_physics_process(false)
  check(player.is_vaulting(),"Space starts contextual window vault")
  check(player.body_shape.shape.height<1.2 and player.collision_mask==(1|4|OperationArea.BOUNDARY_LAYER),"Tuck capsule, preserve physical collisions")
  var rounds := player.current().rounds()
  check(not player.shoot() and player.current().rounds()==rounds,"Cannot fire while using hands to climb")
  player.switch_weapon(1);check(player.slot==0,"Weapon swap blocked while climbing")
  game.inventory.toggle();check(not game.inventory_open,"Inventory cannot interrupt planted hands")
  player.health=90;check(not player.begin_bandage(),"Medical action cannot overlap vault");player.health=100
  for i in range(27):player._physics_process(1.0/60)
  check(player.vault.rig.visible and not player.viewmodel.visible,"Dedicated arms replace lowered weapon during pull")
  for i in range(2):
   check(player.vault.rig.hands[i].global_position.distance_to(player.vault.grips[i])<0.015,"Hand stays attached to actual sill")
  var before := player.global_position;var time := player.vault.elapsed
  game.paused=true;player._physics_process(0.2)
  check(player.global_position.is_equal_approx(before) and player.vault.elapsed==time,"Pause freezes traversal")
  game.paused=false
  await tick_vault()
  check(not player.is_vaulting() and fixture.to_local(player.position).z< -0.4,"Vault finishes behind window wall")
  check(player.is_on_floor() and player.body_shape.shape.height>1.7,"Normal grounded stance restored after landing")
  check(not player.vault.rig.visible and player.viewmodel.visible,"Weapon returns and vault arms disappear")
  # Reverse direction through the same opening.
  player.rotation.y+=PI
  check(player.vault.try_start(),"Window also traversable from inside")
  await tick_vault()
  check(fixture.to_local(player.position).z>0.4,"Reverse vault returns outside")
 await window_fixture()
 Input.action_press("forward")
 for i in range(30):player._physics_process(1.0/60);await physics_frame
 check(fixture.to_local(player.position).z<0.46,"Walk until body actually touches the sill")
 player.set_physics_process(true);Input.action_press("jump");await frames(2)
 Input.action_release("jump");Input.action_release("forward");player.set_physics_process(false)
 check(player.is_vaulting(),"Space while pressed against sill vaults instead of ordinary jumping")
 await tick_vault()
 check(fixture.to_local(player.position).z< -0.4 and player.is_on_floor(),"Contact-start traversal physically reaches the room")
 await window_fixture()
 player.position=fixture.to_global(Vector3(0,0.02,1.30));player.velocity=Vector3.ZERO
 for i in range(5):player._physics_process(1.0/60);await physics_frame
 check(player.vault.try_start(),"Recognize window from a natural approach distance")
 await tick_vault();check(fixture.to_local(player.position).z< -0.4,"Approach step ends inside window")
 for side in [-1,1]:
  await window_fixture(0.63)
  player.position=fixture.to_global(Vector3(side*0.48,0.02,0.80));player.velocity=Vector3.ZERO
  Input.action_press("forward")
  for i in range(30):player._physics_process(1.0/60);await physics_frame
  Input.action_release("forward")
  check(player.vault.try_start(),"Align shoulders with opening when approaching beside a jamb")
  await tick_vault()
  check(fixture.to_local(player.position).z< -0.4 and player.is_on_floor(),"Side alignment reaches room with physical collisions")
 await window_fixture(0,0.48)
 check(player.vault.probe().is_empty(),"Reject window narrower than shoulders")
 await window_fixture(0,1.3,0.87,1.72)
 check(player.vault.probe().is_empty(),"Reject opening without tucked headroom")
 await window_fixture(0,1.3,1.65,2.9)
 check(player.vault.probe().is_empty(),"Reject unreachable high sill")
 await window_fixture(0,1.3,0.18,1.52)
 check(player.vault.try_start(),"Low sill below a lintel supports crouched passage")
 await tick_vault();check(fixture.to_local(player.position).z< -0.4,"Passes low sill under a lintel")
 await window_fixture(0,1.3,0.18,1.52)
 var low_roof := box(fixture,Vector3(0,1.52,-1.1),Vector3(3,0.12,2.0));await frames(2)
 Input.action_press("crouch");player.update_cover(1)
 check(player.vault.try_start(),"Can start traversal while crouching")
 Input.action_release("crouch");await tick_vault()
 check(not player.is_vaulting() and player.crouched and player.body_shape.shape.height<1.2,"Low landing ceiling prevents forced standing")
 low_roof.free();await frames(2);player.update_cover(1)
 check(not player.crouched,"Can stand again after headroom clears")
 await window_fixture()
 var block := box(fixture,Vector3(0,1.2,-1),Vector3(3,2.4,1.5));await frames(2)
 check(player.vault.probe().is_empty(),"Reject blocked landing and crossing")
 block.free();await frames(2)
 player.arm_injury=0.6;check(not player.vault.try_start(),"Injured arm cannot pull body up");player.arm_injury=0
 player.leg_injury=0.6;check(not player.vault.try_start(),"Injured leg cannot vault");player.leg_injury=0
 player.prone_requested=true;player.update_cover(1);check(not player.vault.try_start(),"No vault while lying down")
 await reset_player()
 player.current().reload(0);check(not player.vault.try_start(),"Reload cannot overlap traversal")
 player.current().update(5.0)
 player.field_rig.mode="access";check(not player.vault.try_start(),"Backpack action blocks vault");player.field_rig.cancel()
 game.inventory_open=true;check(not player.vault.try_start(),"Inventory space does not vault");game.inventory_open=false
 game.commands_open=true;check(not player.vault.try_start(),"Command menu space does not vault");game.commands_open=false
 check(player.vault.try_start(),"Start dynamic obstruction test")
 for i in range(26):player._physics_process(1.0/60)
 block=box(fixture,Vector3(0,1.5,-0.7),Vector3(2,3,0.3));await frames(2)
 await tick_vault()
 check(not player.is_vaulting() and fixture.to_local(player.position).z> -0.25,"New obstruction stops vault without crossing it")
 block.free();await frames(2);await reset_player()
 check(player.vault.try_start(),"Start wound interruption test")
 for i in range(18):player._physics_process(1.0/60)
 player.receive_hit(10,"arm",Vector3.FORWARD,player.position)
 check(not player.is_vaulting() and not player.vault.rig.visible,"Wounding releases hands and cancels traversal")
 await reset_player();check(player.vault.try_start(),"Start destructible support test")
 for i in range(30):player._physics_process(1.0/60)
 fixture.get_child(1).free();await frames(2);player._physics_process(1.0/60)
 check(not player.is_vaulting(),"Destroyed sill releases planted hands instead of levitating")
 await window_fixture()
 check(player.vault.try_start(),"Start delayed frame traversal")
 for i in range(18):player._physics_process(0.3);await physics_frame
 check(not player.is_vaulting() and fixture.to_local(player.position).z< -0.4,"Delayed frames preserve collision-checked bends in trajectory")
 await reset_player()
 # Low fence and a wide solid ledge, independent of any window tags.
 for node in fixture.get_children():node.free()
 box(fixture,Vector3(0,-0.2,0),Vector3(12,0.4,12))
 box(fixture,Vector3(0,0.30,0),Vector3(4,0.6,0.24));await frames(2);await reset_player()
 check(player.vault.try_start(),"Low fence can be vaulted")
 await tick_vault();check(fixture.to_local(player.position).z< -0.4,"Low fence traversal lands on far side")
 for node in fixture.get_children():node.free()
 box(fixture,Vector3(0,-0.2,0),Vector3(12,0.4,12))
 box(fixture,Vector3(0,0.55,-1),Vector3(4,1.1,2.3));await frames(2);await reset_player()
 check(player.vault.try_start(),"Wide ledge can be climbed onto")
 await tick_vault();check(fixture.to_local(player.position).y>1.05,"Ledge traversal ends on top")
 await window_fixture()
 fixture.get_child(0).free()
 box(fixture,Vector3(0,-0.2,2),Vector3(4,0.4,3.5));await frames(2);await reset_player()
 check(player.vault.probe().is_empty(),"Reject unsupported landing beyond a drop")
 # The village's fences: a board as thin as the steel sheet's collider.
 for height in [1.36,1.55]:
  for node in fixture.get_children():node.free()
  box(fixture,Vector3(0,-0.2,0),Vector3(12,0.4,12))
  box(fixture,Vector3(0,height*0.5,0),Vector3(2.5,height,0.08));await frames(2);await reset_player()
  check(player.vault.try_start(),"A %.2f m board fence can be climbed over" % height)
  await tick_vault()
  check(not player.is_vaulting() and fixture.to_local(player.position).z< -0.4 and player.is_on_floor(),"…down on its far side")
  player.rotation.y+=PI
  check(player.vault.try_start(),"…and back over it")
  await tick_vault();check(fixture.to_local(player.position).z>0.4,"…landing where it began")
 for node in fixture.get_children():node.free()
 box(fixture,Vector3(0,-0.2,0),Vector3(12,0.4,12))
 box(fixture,Vector3(0,0.95,0),Vector3(4,1.9,0.08));await frames(2);await reset_player()
 check(player.vault.probe().is_empty(),"A 1.9 m wall is too high to climb")
 for node in fixture.get_children():node.free()
 box(fixture,Vector3(0,-0.2,0),Vector3(12,0.4,12))
 box(fixture,Vector3(0,0.75,-1.15),Vector3(4,1.5,2.3));await frames(2);await reset_player()
 check(player.vault.probe().is_empty(),"A 1.5 m ledge is not climbed onto")
 await window_fixture()
 # Plain ground still jumps using the original movement action.
 await reset_player();player.position=fixture.to_global(Vector3(4,0.03,3))
 for i in range(5):player._physics_process(1.0/60);await physics_frame
 player.set_physics_process(true);Input.action_press("jump");await frames(2)
 Input.action_release("jump");player.set_physics_process(false)
 check(not player.is_vaulting() and player.velocity.y>4,"Space on open ground remains a normal jump")
 await reset_player();check(player.vault.try_start(),"Start lethal interruption test")
 player.take_damage(100)
 check(not game.running and not player.is_vaulting() and not player.vault.rig.visible,"Death clears traversal immediately")
 game.queue_free();await frames(3)
 print("FAIL: " if failed else "PASS: ",checks," contextual vault, animation, obstruction and interruption checks")
 quit(1 if failed else 0)
