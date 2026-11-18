extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.ally_count=8
 game.selected_map="forest_01"
 game.start_match()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 game.player.position.z-=32
 game.player.position.y=game.district.ground_height(game.player.position)+0.1
 for i in range(1500):
  for actor in game.allies:actor._physics_process(1.0/60)
  if i%4==0:await physics_frame
 var failed := false
 for actor in game.allies:
  var distance: float=actor.position.distance_to(game.squad.formation_point(actor.formation_index))
  print("SQUAD_ROUTE ",actor.formation_index," distance=",distance)
  if distance>9:failed=true
 game.queue_free()
 for i in range(3):await process_frame
 quit(1 if failed else 0)
