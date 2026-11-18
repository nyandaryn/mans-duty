extends SceneTree
var failed := false
var checks := 0
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  failed=true
  printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 for id in Campaign.IDS:game.campaign.complete(id)
 for id in Campaign.IDS:
  game.selected_map=id
  game.start_match()
  game.set_debug_invulnerable(true)
  game.set_physics_process(false)
  for bot in game.bots:
   bot.set_physics_process(false)
   bot.collision_layer=0 # Test terrain traversal, not pushing stationary enemies.
  var player: Operator=game.player
  var d: District=game.district
  player.set_physics_process(false)
  var from: Vector3
  var destination: Vector3
  if id.begins_with("forest"):
   var trench: Array=d.campaign_definition.trenches[0]
   var a: Vector2=trench[0]
   var b: Vector2=trench[1]
   var start := a-a.direction_to(b)*3
   var end := a+a.direction_to(b)*16
   from=Vector3(start.x,d.terrain.height_at(start)+0.15,start.y)
   destination=Vector3(end.x,d.terrain.height_at(end),end.y)
  else:
   var spec: Dictionary=d.campaign_definition.buildings[0]
   var turn := Basis(Vector3.UP,float(spec.yaw))
   var center := Vector3(spec.point.x,d.terrain.height_at(spec.point),spec.point.y)
   # Bay-centered front door, including even bay counts.
   var count := maxi(3,int(float(spec.size.x)/3.0))
   var unit: float=spec.size.x/count
   var u: float=-spec.size.x/2+(int(count/2)+0.5)*unit
   from=center+turn*Vector3(u,0.15,-spec.size.y/2-3)
   destination=center+turn*Vector3(u,0.12,-spec.size.y/2+2)
  player.position=from
  player.velocity=Vector3.ZERO
  var route: PackedVector2Array=d.path(from,destination)
  check(route.size()>1,id+" local walking route exists")
  var cursor := 1
  var traveled := 0.0
  var previous := player.position
  for tick in range(720):
   if cursor<route.size():
    var target: Vector2=route[cursor]
    var offset := Vector3(target.x-player.position.x,0,target.y-player.position.z)
    if offset.length()<0.4:cursor+=1
    else:player.rotation.y=atan2(-offset.x,-offset.z)
   if cursor>=route.size():break
   Input.action_press("forward")
   # Exercise the real movement controller and physics collision; do not teleport.
   player._physics_process(1.0/60)
   traveled+=previous.distance_to(player.position)
   previous=player.position
   if tick%4==0:await physics_frame
  Input.action_release("forward")
  var remaining := Vector2(player.position.x-destination.x,player.position.z-destination.z).length()
  check(remaining<1.2,id+" real capsule reaches trench / house interior without jumping")
  check(player.health>0 and game.running,id+" terrain below sea level is not a kill plane")
  print(id," walk_m=",snappedf(traveled,0.1)," remaining=",snappedf(remaining,0.1)," y=",snappedf(player.position.y,0.1))
 game.queue_free()
 await process_frame
 await create_timer(0.15).timeout
 print("FAIL: " if failed else "PASS: ",checks," real campaign movement and terrain survival checks")
 quit(1 if failed else 0)
