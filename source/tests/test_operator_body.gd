extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 await process_frame
 game.volume=0;game.primary="svd";game.player_outfit="british_mtp";game.loadout_bag.equipped=true
 game.start_match();game.set_physics_process(false);game.player.set_physics_process(false)
 for bot in game.bots+game.allies:bot.set_physics_process(false)
 var player: Operator=game.player
 var body: OperatorBody=player.world_body
 check(body.model.get_meta("outfit")=="british_mtp","World body wears selected camouflage")
 check(body.model.has_node("Backpack"),"World body wears equipped backpack")
 check(body.model.get_node("LeftArm/TeamTape").get_meta("team")=="ua","World body has friendly team markings")
 check(body.weapon_id=="svd","World body carries selected rifle")
 check(body.find_children("*","CollisionObject3D",true,false).is_empty(),"Visual body does not duplicate damage hitboxes")
 var drone := ReconDrone.new();player.add_child(drone);drone.setup(player,{})
 var all_visible := true
 var first_person_hidden := true
 for mesh in body.find_children("*","VisualInstance3D",true,false):
  all_visible=all_visible and (mesh.layers&drone.camera.cull_mask)!=0
  first_person_hidden=first_person_hidden and (mesh.layers&player.camera.cull_mask)==0
 check(all_visible,"Drone sees every world-body mesh")
 check(first_person_hidden,"Soldier camera excludes own world-body meshes")
 check((player.scope_sight.camera.cull_mask&OperatorBody.WORLD_BODY_LAYER)==0,"Scope cannot be blocked by own body")
 player.position=Vector3(0,0.03,35);player.rotation=Vector3.ZERO
 for stance in ["standing","kneeling","prone"]:
  player.prone_requested=stance=="prone"
  if stance=="kneeling":Input.action_press("crouch")
  else:Input.action_release("crouch")
  player.update_cover(1)
  player.field_rig.mode="drone";body.update_pose()
  check(body.goggles.visible and body.controller.visible,"FPV equipment visible while "+stance)
  var eyes: Vector3=body.model.get_node("Head").to_global(Vector3(0,CharacterArt.EYE.y,CharacterArt.EYE.z))
  check(eyes.distance_to(player.camera.global_position)<0.22,"World eyes follow physical stance: "+stance)
  var feet: Node3D=body.model.get_node("RightLeg/Knee/Foot")
  check(feet.global_position.y>=player.global_position.y+0.04,"Feet stay above ground: "+stance)
  check(body.controller.global_position.y>player.global_position.y+0.10,"Pilot controller stays above ground: "+stance)
  player.field_rig.mode=""
 Input.action_release("crouch")
 body.update_pose()
 check(not body.goggles.visible and not body.controller.visible,"Removing goggles restores ordinary world pose")
 player.switch_weapon(1);body.update_pose()
 check(body.weapon_id==player.current().id,"World weapon follows switching")
 game.queue_free();await process_frame;await process_frame
 print("FAIL: " if failed else "PASS: ",checks," operator world body, equipment, stance and camera checks")
 quit(1 if failed else 0)
