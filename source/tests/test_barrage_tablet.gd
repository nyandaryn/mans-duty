extends SceneTree
# The tablet with the «Grads»' fire before the great assault opens for every
# field class, the grenadier among them, and again in a new battle even when
# the wrist display was switched off (U) in the last one. Meanwhile the
# squads wait by their vehicles.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame

func run():
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 for cls in ["grenadier","machinegunner","uav","rifleman"]:
  game.set_player_class(cls)
  game.battle_size=18
  game.selected_map=BattleMap.ID
  game.start_match()
  await frames(90)
  check(game.battle.prep=="barrage" and game.drone_feed.mode=="barrage" and game.drone_feed.visible,"%s: the tablet shows the battery (%s / %s)" % [cls,game.battle.prep,game.drone_feed.mode])
  # Switched off with U in this battle: off until the next one.
  game.drone_feed.toggle()
  await frames(5)
  check(game.drone_feed.mode=="","%s: U switches it off" % cls)
  game.to_menu()
  await frames(5)
 # While they wait for the barrage to end the men idle by their vehicles:
 # off the village's walking grid an idle spot stays where it was picked,
 # it is not pulled to the grid's edge a kilometre and a half away.
 game.set_player_class("machinegunner")
 game.battle_size=27
 game.selected_map=BattleMap.ID
 game.start_match()
 var farthest:=0.0
 for second in range(45):
  await frames(60)
  if game.battle.prep!="barrage":break
  for squad in game.battle.mech:
   for actor in squad.on_foot():farthest=maxf(farthest,actor.global_position.distance_to(squad.vehicle.global_position))
 check(farthest>3.0 and farthest<22.0,"Waiting for the barrage the squads stay by their BMPs (farthest %.1f m)" % farthest)
 game.to_menu()
 await frames(5)
 game.queue_free();await process_frame
 print("%s: %d barrage tablet checks" % ["FAILED" if failed else "PASS",checks])
 quit(1 if failed else 0)
