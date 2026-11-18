extends SceneTree
func _initialize():call_deferred("run")
func run():
 seed(161126)
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 if OS.get_environment("BATTLE_GPU")=="1":
  game.battle.panel.show()
  for i in range(8):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/battle-menu.png")
  game.battle.panel.hide()
 game.volume=0;game.ally_count=3;game.battle_size=20;game.selected_map=BattleMap.ID;game.start_match()
 game.player.set_physics_process(false)
 game.player.position=Vector3(130,game.district.ground_height(Vector3(130,0,130))+.1,130)
 game.player.camera.far=700
 var count:=0;var shots:=0;var travel:=0.0;var max_actors:=0
 var previous:Dictionary={};var times:Array[float]=[]
 var duration:=45.0 if OS.get_environment("BATTLE_GPU")=="1" else 65.0
 if OS.get_environment("BATTLE_DURATION")!="":duration=float(OS.get_environment("BATTLE_DURATION"))
 var started:=Time.get_ticks_msec();var last:=Time.get_ticks_usec()
 while game.running and game.elapsed<duration:
  await physics_frame
  var now:=Time.get_ticks_usec();times.append(float(now-last)/1000);last=now
  max_actors=maxi(max_actors,game.allies.size()+game.bots.size())
  for actor in game.allies+game.bots:
   if actor.dead:continue
   if actor.since_shot<.035:shots+=1
   var id:int=actor.get_instance_id()
   if previous.has(id) and actor.friendly:travel+=actor.position.distance_to(previous[id])
   previous[id]=actor.position
  count+=1
  if Time.get_ticks_msec()-started>maxf(180000,duration*3000):printerr("FAIL: battle run timeout");quit(1);return
 times.sort()
 print("BATTLE LIVE actors=",max_actors," fire_frames=",shots," allied_travel=",travel," sectors=",game.battle.sector," progress=",game.battle.progress," casualties=",game.killed," p95_ms=",times[int(times.size()*.95)]," worst_ms=",times[-1]," cover_budget=",game.battle.peak_cover_queries," path_budget=",game.battle.peak_path_queries)
 for team in [game.allies,game.bots]:
  var alive:=0;var nearest:=INF;var rounds:=0
  for actor in team:
   if not game.battle.operational(actor):continue
   alive+=1;nearest=minf(nearest,actor.position.distance_to(game.battle.center()));rounds+=actor.weapon.ammunition_total()
  print("TEAM alive=",alive," nearest_sector=",nearest," rounds=",rounds)
 if OS.get_environment("BATTLE_DIAG")=="1":
  for actor in game.allies:
   if not game.battle.operational(actor) or not actor.get_meta("battle_managed",false):continue
   print("ALLY pos=",actor.position," home=",actor.home," cover=",actor.has_cover," dwell=",actor.cover_dwell," suppress=",actor.suppression," role=",actor.squad_role," arrived=",actor.assault_arrived," wound=",actor.collapse," state=",actor.state," path=",actor.path_index,"/",actor.path.size())
 var ok:bool=max_actors>=40 and shots>20 and travel>200 and game.battle.peak_cover_queries<=2 and game.battle.peak_path_queries<=4
 if OS.get_environment("BATTLE_GPU")=="1":
  game.player.camera.global_position=Vector3(42,17,105);game.player.camera.look_at(game.battle.center()+Vector3.UP)
  for i in range(5):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/battle-live.png")
 game.queue_free();await process_frame;await process_frame
 print("PASS: live autonomous battle" if ok else "FAIL: live autonomous battle")
 quit(0 if ok else 1)
