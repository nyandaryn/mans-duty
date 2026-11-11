extends SceneTree
var checks := 0
func verify(ok: bool, message: String):
 checks+=1
 if not ok:
  printerr("FAIL: ",message)
  quit(1)
  assert(ok,message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame
func run():
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 game.player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 var player: Operator=game.player
 player.position=Vector3(0,0.1,35)
 player.rotation=Vector3.ZERO
 player.update_cover(1)
 await frames(2)
 verify(player.shoot(),"Loaded weapon fires")
 verify(game.debris.emitted_cases==1,"Actual shot emits physical spent case")
 player.cooldown=0
 player.current().rack()
 for i in range(30):player._physics_process(1.0/60)
 verify(game.debris.emitted_live==1,"Manual bolt pull emits a visible live cartridge")
 player.current().update(1)
 var total := player.current().ammunition_total()
 player.current().inspect_chamber()
 for i in range(60):player._physics_process(1.0/60)
 verify(player.viewmodel.chamber_round.visible,"Chamber check shows cartridge geometry when loaded")
 verify(game.debris.emitted_live==1 and player.current().ammunition_total()==total,"Chamber check does not eject or consume cartridge")
 player.current().update(4)
 player.current().inspect_magazine(1)
 player.current().clock=1.0
 player.viewmodel.animate(player.current(),1)
 verify(player.viewmodel.inspection_mag.visible and player.viewmodel.magazine.visible,"Pouch inspection preserves loaded magazine and shows separate magazine in hand")
 verify(player.viewmodel.inspection_mag.get_node("AmmoEvidence/TopRound").visible,"Loaded pouch magazine shows top cartridge")
 player.current().pouches[1].rounds=0
 player.viewmodel.animate(player.current(),1)
 verify(not player.viewmodel.inspection_mag.get_node("AmmoEvidence/TopRound").visible and player.viewmodel.inspection_mag.get_node("AmmoEvidence/Follower").visible,"Empty magazine shows follower instead of fake top round")
 player.current().cancel()
 Input.action_press("reload")
 var key := InputEventKey.new()
 key.physical_keycode=KEY_2
 key.pressed=true
 player._unhandled_input(key)
 Input.action_release("reload")
 verify(player.slot==0 and player.current().pending_slot==1,"R+2 chooses pouch two instead of switching to pistol")
 player.current().update(10)
 verify(player.current().rounds()==0 and player.current().chambered,"Empty magazine swap retains existing chambered cartridge")
 game._process(0)
 verify(not game.hud_text.text.contains("∞") and not game.hud_text.text.contains("ПОРОЖНІЙ"),"Combat HUD does not reveal ammunition or chamber contents")
 verify(not game.objective.text.contains("цілей"),"Objective does not reveal remaining enemies")
 game.set_debug_invulnerable(true)
 verify(player.current().debug_infinite and game.bots[0].weapon.debug_infinite,"F8 controls debug ammunition for combatants")
 game.set_debug_invulnerable(false)
 game.set_pause(true)
 await frames(2)
 var body: RigidBody3D=game.debris.active[0].body
 var paused_position := body.position
 await frames(5)
 verify(body.position.is_equal_approx(paused_position),"Pause freezes flying cases")
 game.set_pause(false)
 await frames(670)
 verify(game.debris.settled_count>=2 and game.debris.active.is_empty(),"Cases and live rounds settle and remain on map beyond old deletion timer")
 var count: int = game.debris.settled_count
 await frames(60)
 verify(game.debris.settled_count==count,"Settled debris persists")
 game.start_match()
 verify(game.debris.settled_count==0,"New mission clears prior mission debris")
 game.queue_free()
 await frames(4)
 print("PASS: %d input, inspection, HUD and persistent cartridge checks" % checks)
 quit()
