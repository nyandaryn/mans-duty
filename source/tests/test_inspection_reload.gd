extends SceneTree
var checks := 0
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  printerr("FAIL: ",message)
  quit(1)
  assert(ok,message)
func unique_magazines(w: WeaponState) -> bool:
 var seen := {}
 var count := 0
 for mag in [w.magazine,w.held_old,w.held_new]+w.pouches:
  if mag.is_empty():continue
  if seen.has(mag.serial):return false
  seen[mag.serial]=true
  count+=1
 return count==w.pouches.size()+1
func _initialize():call_deferred("run")
func run():
 for id in WeaponState.DATA:
  for slot in range(2 if id in ["pm","m9"] else 3):
   for interruption in [0.1,0.6,1.2]:
    var w := WeaponState.new(id)
    for i in range(3):w.fire()
    var initial := w.ammunition_total()
    var old_rounds := w.rounds()
    w.inspect_magazine(slot)
    check(w.phase_duration()==2.1,"Shortened inspection duration")
    check(not w.reload(),"Cannot reload before magazine is reached")
    w.update(0.8)
    check(w.reload(),"Held pouch magazine starts immediate reload")
    check(w.phase=="ready_remove" and w.held_new.serial==slot+2 and w.pouches[slot].is_empty(),"Held magazine has one actual inventory owner")
    w.update(interruption)
    w.cancel()
    check(unique_magazines(w) and w.ammunition_total()==initial,"Interruption preserves all magazines and rounds")
    check(w.reload(),"Interrupted prepared reload resumes")
    w.update(10)
    check(w.magazine.serial==slot+2 and w.pouches[slot].serial==1 and w.pouches[slot].rounds==old_rounds,"Selected held magazine loaded and partial old one returned to its pouch")
    check(unique_magazines(w) and w.ammunition_total()==initial,"Completed fast reload conserves inventory")
   var loaded := WeaponState.new(id)
   loaded.inspect_magazine()
   loaded.update(0.9)
   var initial := loaded.ammunition_total()
   check(loaded.reload(slot) and loaded.phase=="stow" and loaded.magazine.is_empty(),"Loaded inspection skips repeated removal")
   loaded.update(2.25)
   check(loaded.phase=="" and loaded.magazine.serial==slot+2 and loaded.ammunition_total()==initial,"Loaded inspection reload finishes in 2.25 s")
  var rig: WeaponRig=Models.weapon(id)
  check(rig.inspection_pose(-1,0.18).origin.distance_to(rig.inspection_pose(0,0.18).origin)>0.3,"Weapon and pouch retrieval start in different locations")
  check(rig.inspection_pose(0,0.18).origin.distance_to(rig.inspection_pose(1,0.18).origin)>0.1,"Each pouch uses its own retrieval location")
  var round: Node3D=rig.magazine.get_node("AmmoEvidence/TopRound")
  var low := Vector3(INF,INF,INF)
  var high := Vector3(-INF,-INF,-INF)
  for child in round.get_children():
   var box: AABB=child.transform*child.get_aabb()
   low=low.min(box.position+round.position)
   high=high.max(box.end+round.position)
  var z_min := 0.008 if id in ["pm","m9"] else (-0.086 if id=="ak74" else -0.095)
  var z_max := 0.037 if id in ["pm","m9"] else (-0.028 if id=="ak74" else -0.043)
  if id=="svd":z_min=-0.112;z_max=-0.031
  var half_width := 0.015 if id=="svd" else 0.01
  check(low.z>=z_min and high.z<=z_max and maxf(absf(low.x),absf(high.x))<half_width,"Cartridge fits inside magazine feed-lip footprint: "+id)
  var mouth_y := -0.026 if id in ["pm","m9"] else (-0.042 if id=="ak74" else -0.05)
  if id=="svd":mouth_y=-0.043
  check(high.y-mouth_y<0.006 and high.y>mouth_y,"Only upper cartridge surface protrudes above magazine mouth: "+id)
  rig.free()
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 game.player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 game.player.current().inspect_magazine(1)
 game.player.current().update(0.8)
 var key := InputEventKey.new()
 key.physical_keycode=KEY_R
 key.pressed=true
 game.player._unhandled_input(key)
 check(game.player.current().prepared_reload and game.player.current().pending_slot==1,"R input uses the magazine currently held from pouch two")
 game.queue_free()
 await create_timer(0.2).timeout
 print("PASS: %d inspection handoff, conservation, geometry and input checks" % checks)
 quit()
