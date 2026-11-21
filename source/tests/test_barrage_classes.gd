extends SceneTree
# The great assault starts with the «Grads» for every class but the BM-21
# commander, the column moves only after them:
# - the sniper on foot by the first BMP, as the rifleman;
# - the BMP driver in the seat of the leading vehicle, his own men dismounted
#   behind its stern; the tablet shows the battery and the village in the
#   seat; after the salvo «По машинах!» his men climb in, «Колона — вперед!»,
#   and the column follows once he drives off;
# - the mortarman at the mortar: after the salvo the squads board and the
#   column waits for his order;
# - the BM-21 commander: no battery of ours, his own launcher is the fire.
# Run with --fixed-fps 60.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func new_game(id: String, size: int) -> Node:
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class(id);game.battle_size=size;game.selected_map=BattleMap.ID;game.start_match()
 return game

func until(game: Node, condition: Callable, seconds: float) -> bool:
 var t:=0
 while not condition.call() and t<int(seconds*60):
  if is_instance_valid(game.player):game.player.health=maxf(game.player.health,90.0)
  await frames(1);t+=1
 return condition.call()

func run():
 seed(5150)
 await sniper()
 await driver()
 await mortarman()
 await commander()
 print("PASS" if not failed else "FAILED"," checks=",checks)
 quit(1 if failed else 0)

func sniper() -> void:
 var game=await new_game("sniper",18)
 var battle: BattleMode=game.battle
 check(battle.prep=="barrage" and is_instance_valid(battle.battery) and not battle.column_go,"Sniper: the battery's fire first, the column holds")
 check(game.bmp.seat=="" and game.player.global_position.distance_to(battle.mech[0].vehicle.global_position)<12.0,"…on foot by the first BMP")
 game.queue_free();await frames(5)

func driver() -> void:
 var game=await new_game("bmp",27)
 var battle: BattleMode=game.battle
 var own: MechSquad=game.bmp.squad
 check(battle.prep=="barrage" and is_instance_valid(battle.battery) and not battle.column_go,"Driver: the battery's fire first, the column holds")
 check(game.bmp.seat=="driver" and own.player_led and own==battle.mech[0],"…the player in the seat of the leading BMP")
 check(own.state=="field" and own.aboard().is_empty() and own.on_foot().size()>=4,"…his men dismounted (%s, %d on foot)" % [own.state,own.on_foot().size()])
 var behind:=true
 for actor in own.on_foot():
  var local: Vector3=own.vehicle.to_local(actor.global_position)
  if local.z<BmpArt.HALF or actor.global_position.distance_to(own.vehicle.global_position)>14.0:behind=false
 check(behind,"…behind its stern")
 var others:=true
 for squad in battle.mech:
  if squad!=own and squad.state!="field":others=false
 check(others,"The other squads dismounted by their vehicles")
 await frames(30)
 check(game.drone_feed.mode=="barrage" and game.drone_feed.visible,"The tablet shows the battery and the village in the driver's seat")
 check(await until(game,func():return battle.prep!="barrage",150.0),"The salvo, then «По машинах!» (%s)" % battle.prep)
 check(battle.battery==null or battle.battery.ordered,"…after the battery fired")
 check(await until(game,func():return own.state=="mounted",90.0),"His men climb into his vehicle (%s, %d in)" % [own.state,own.aboard().size()])
 check(await until(game,func():return battle.prep=="",90.0),"Everyone in: the field start is over")
 check(battle.column_go and game.radio_voice.heard.has("column"),"«Колона — вперед!» (%s)" % str(game.radio_voice.heard))
 var second: MechSquad=battle.mech[1]
 await frames(120)
 check(second.state=="wait","The column waits for its head to move off (%s)" % second.state)
 own.vehicle.global_position+=-own.vehicle.global_basis.z*(BmpRoutes.COLUMN_GAP+6.0)
 check(await until(game,func():return second.state=="march",10.0),"…and follows it (%s)" % second.state)
 game.queue_free();await frames(5)

func mortarman() -> void:
 var game=await new_game("mortarman",18)
 var battle: BattleMode=game.battle
 check(battle.prep=="barrage" and is_instance_valid(battle.battery) and battle.awaiting,"Mortarman: the battery's fire first, the assault waits for his order")
 check(game.bmp.seat=="" and game.crew.active(),"…the player with his mortar, on foot")
 check(battle.mech[0].state=="field","…the squads dismounted by their vehicles")
 await frames(30)
 check(game.drone_feed.mode=="barrage","…the tablet shows the battery")
 check(await until(game,func():return battle.prep=="",240.0),"The salvo, «По машинах!», the squads in (%s)" % battle.prep)
 var waiting:=true
 for squad in battle.mech:
  if squad.state!="wait":waiting=false
 check(waiting and not battle.column_go,"The column waits for the mortarman's order")
 await frames(120)
 check(battle.mech[0].state=="wait","…and keeps waiting")
 game.crew.command("resume")
 check(await until(game,func():return battle.mech[0].state=="march",10.0),"His order sends the column (%s)" % battle.mech[0].state)
 check(game.radio_voice.heard.has("column"),"«Колона — вперед!» on the radio")
 game.queue_free();await frames(5)

func commander() -> void:
 var game=await new_game("grad",18)
 var battle: BattleMode=game.battle
 check(battle.prep=="" and battle.battery==null,"BM-21 commander: no battery of ours, he is the fire")
 game.queue_free();await frames(5)
