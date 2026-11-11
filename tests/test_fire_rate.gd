extends SceneTree
var checks := 0
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  printerr("FAIL: ",message)
  quit(1)
  assert(ok,message)
func _initialize():call_deferred("run")
func reset_weapon(player: Operator,id: String):
 player.weapons[0]=WeaponState.new(id)
 player.slot=0
 player.cooldown=0
 player.switch_delay=0
 player.burst=0
 player.firing_sequence_active=false
 player.shots=0
 player.make_viewmodel()
func run():
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 game.set_process(false)
 var player: Operator=game.player
 player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 for fps in [4,20,30,60,120]:
  var dt := 1.0/float(fps)
  reset_weapon(player,"ak74")
  Input.action_press("fire")
  var last := 0.0
  for tick in range(ceili(3.5/dt)):
   var before := player.shots
   player._physics_process(dt)
   if player.shots>before:last=tick*dt
  Input.action_release("fire")
  check(player.shots==30,"AK fires exactly loaded 30 rounds at %d Hz" % fps)
  check(absf(last-2.9)<=dt+0.00001,"AK last shot at 2.9 s within one tick, %d Hz: %.4f" % [fps,last])
  print("AK ",fps," Hz: 30 rounds, last shot ",last," s")
  reset_weapon(player,"m16")
  player.current().mode_index=1
  player.burst=3
  last=0
  for tick in range(ceili(0.7/dt)):
   var before := player.shots
   player._physics_process(dt)
   if player.shots>before:last=tick*dt
  check(player.shots==3,"M16 stops at three shots")
  check(absf(last-0.15)<=dt+0.00001,"M16 800 rpm burst timing, %d Hz: %.4f" % [fps,last])
  await process_frame
 for id in ["pm","m9","m16","ak74"]:
  reset_weapon(player,id)
  if id=="ak74":player.current().mode_index=1
  Input.action_press("fire")
  for i in range(30):player._physics_process(1.0/60)
  check(player.shots==0,id+": holding trigger cannot turn semi mode into auto")
  Input.action_release("fire")
  check(player.shoot(),id+": fresh trigger pull fires")
  check(not player.shoot(),id+": impossible same-time second shot blocked")
  player._physics_process(float(player.current().data.interval))
  check(player.shoot(),id+": next shot permitted at cycle boundary without extra tick")
  player._physics_process(10)
  player.current().mode_index=0
  if id=="ak74":
   var before := player.shots
   Input.action_press("fire")
   player._physics_process(1.0/60)
   Input.action_release("fire")
   check(player.shots==before+1,"Idle time cannot accumulate a burst of overdue shots")
 game.queue_free()
 await create_timer(0.2).timeout
 print("PASS: %d fire rate and trigger checks" % checks)
 quit()
