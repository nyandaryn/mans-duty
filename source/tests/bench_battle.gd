extends SceneTree
# Performance benchmark of the large assault (not part of the test suite).
# BENCH_SIZE=50 (bots per side), BENCH_SECONDS=40. Run without --headless to
# include rendering: godot --path source --script res://tests/bench_battle.gd
class Stamp extends Node:
 # First and last node of the physics tick: the cost of all game scripts.
 var first := true
 static var start := 0
 static var total := 0
 static var ticks := 0
 func _physics_process(_delta):
  if first:start=Time.get_ticks_usec()
  else:
   total+=Time.get_ticks_usec()-start
   ticks+=1

func _initialize():call_deferred("run")

func run():
 seed(int(OS.get_environment("BENCH_SEED")) if OS.get_environment("BENCH_SEED")!="" else 161126)
 var size:=int(OS.get_environment("BENCH_SIZE")) if OS.get_environment("BENCH_SIZE")!="" else 50
 var seconds:=float(OS.get_environment("BENCH_SECONDS")) if OS.get_environment("BENCH_SECONDS")!="" else 40.0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0;game.ally_count=3;game.battle_size=size;game.selected_map=BattleMap.ID;game.start_match()
 game.player.set_physics_process(false)
 # Commander stands behind the allied line looking at the first objective: worst-case view.
 var stand:=Vector3(0,0,118);stand.y=game.district.ground_height(stand)+0.1
 game.player.position=stand
 game.player.look_at(Vector3(0,stand.y,0))
 game.player.rotation.x=0;game.player.rotation.z=0
 while game.running and game.elapsed<8.0:await process_frame
 var s0:=Stamp.new();s0.process_physics_priority=-1000000;root.add_child(s0)
 var s1:=Stamp.new();s1.first=false;s1.process_physics_priority=1000000;root.add_child(s1)
 var frames:Array[float]=[]
 var viewport_rid:=root.get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(viewport_rid,true)
 var gpu:=0.0;var cpu_render:=0.0
 var draws:=0.0;var prims:=0.0;var max_alive:=0
 var last:=Time.get_ticks_usec();var end_time:float=game.elapsed+seconds;var count:=0
 var physics_frames:=Engine.get_physics_frames()
 while game.running and game.elapsed<end_time:
  await process_frame
  var now:=Time.get_ticks_usec();frames.append(float(now-last)/1000.0);last=now
  gpu+=RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
  cpu_render+=RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
  draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
  prims+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
  var alive:=0
  for actor in game.allies+game.bots:
   if is_instance_valid(actor) and not actor.dead:alive+=1
  max_alive=maxi(max_alive,alive)
  count+=1
 var sorted:=frames.duplicate();sorted.sort()
 var avg:=0.0
 for f in frames:avg+=f
 avg/=maxf(1,frames.size())
 print("BENCH size=",size," frames=",count," physics_ticks=",Engine.get_physics_frames()-physics_frames," max_alive=",max_alive," casualties=",game.killed)
 print("BENCH fps_avg=%.1f frame_avg=%.2fms p50=%.2f p95=%.2f p99=%.2f worst=%.2f" % [1000.0/avg,avg,sorted[int(sorted.size()*.5)],sorted[int(sorted.size()*.95)],sorted[int(sorted.size()*.99)],sorted[-1]])
 print("BENCH scripts_per_tick=%.2fms render_cpu=%.2fms render_gpu=%.2fms draws=%.0f prims=%.0f" % [float(Stamp.total)/1000.0/maxf(1,Stamp.ticks),cpu_render/maxf(1,count),gpu/maxf(1,count),draws/maxf(1,count),prims/maxf(1,count)])
 if is_instance_valid(game.battle.crowd):print("BENCH crowd near=",game.battle.crowd.near_count," far=",game.battle.crowd.far_count)
 game.queue_free();await process_frame;await process_frame
 quit(0)
