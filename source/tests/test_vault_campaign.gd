extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0;game.ally_count=0
 for id in Campaign.IDS:game.campaign.complete(id)
 for id in ["village_01","village_02","village_03","district_01","district_02"]:
  game.selected_map=id;game.start_match();game.set_physics_process(false)
  for bot in game.bots:bot.set_physics_process(false);bot.collision_layer=0
  var player: Operator=game.player;player.set_physics_process(false)
  var district: District=game.district
  var spec: Dictionary=district.campaign_definition.buildings[0]
  var center := Vector3(spec.point.x,district.terrain.height_at(spec.point),spec.point.y)
  var turn := Basis(Vector3.UP,float(spec.yaw))
  var bays := maxi(3,int(float(spec.size.x)/3.0))
  var unit: float=spec.size.x/bays
  var x: float=-spec.size.x/2+0.5*unit
  # First ground-floor front bay is a real open window (centre bay is the door).
  player.position=center+turn*Vector3(x,0.15,-spec.size.y/2-0.78)
  player.rotation.y=float(spec.yaw)+PI
  player.velocity=Vector3.ZERO
  for i in range(25):player._physics_process(1.0/60);await physics_frame
  check(not player.vault.probe().is_empty(),id+" real window detected on approach")
  Input.action_press("forward")
  for i in range(30):player._physics_process(1.0/60);await physics_frame
  Input.action_release("forward")
  check(player.vault.try_start(),id+" real window can be climbed while touching projecting sill")
  for i in range(120):
   player._physics_process(1.0/60)
   if i%4==0:await physics_frame
  var local: Vector3=turn.inverse()*(player.position-center)
  check(local.z> -spec.size.y/2+0.4,id+" capsule passes through masonry and wood frame opening")
  check(not player.is_vaulting() and player.is_on_floor(),id+" safely lands on interior floor")
  player.rotation.y=float(spec.yaw)
  check(player.vault.try_start(),id+" window is usable to exit too")
  for i in range(120):
   player._physics_process(1.0/60)
   if i%4==0:await physics_frame
  local=turn.inverse()*(player.position-center)
  check(local.z< -spec.size.y/2-0.4 and player.is_on_floor(),id+" lands outside on terrain")
 game.queue_free();await process_frame
 print("FAIL: " if failed else "PASS: ",checks," campaign window entry and exit checks")
 quit(1 if failed else 0)
