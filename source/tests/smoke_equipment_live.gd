extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 game.volume=0;game.selected_map="forest_01";game.ally_count=8
 game.loadout_bag.equipped=true
 game.loadout_bag.add("rangefinder");game.loadout_bag.add("ammo_ak74");game.loadout_bag.add("medkit")
 game.start_match();game.debug_invulnerable=true
 await create_timer(2).timeout
 var frames_before := Engine.get_frames_drawn()
 var start := Time.get_ticks_msec()
 # Actual scene simulation, continuous projectiles and eight allies.
 for i in range(30):
  game.ballistics.launch(game.player.camera.global_position,Vector3(0,0.4,-1),"ak74",36,game.player)
  await create_timer(0.1).timeout
 var fps := (Engine.get_frames_drawn()-frames_before)*1000.0/(Time.get_ticks_msec()-start)
 game.player.field_rig.toggle_rangefinder()
 await create_timer(3.6).timeout
 game.player.field_rig.measure();await create_timer(0.5).timeout
 print("LIVE_EQUIPMENT FPS=%.1f allies=%d range=%s state=%s pack=%d" % [fps,game.allies.size(),game.player.field_rig.reading,game.player.field_rig.mode,game.player.backpack.items.size()])
 game.player.field_rig.toggle_rangefinder();await create_timer(2.4).timeout
 print("PASS: live forest, 8 allies, projectile flight, timed pack retrieval, rangefinder and stow")
 game.queue_free();for i in range(5):await process_frame
 quit()
