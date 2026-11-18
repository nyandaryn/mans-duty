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
 game.show_campaign()
 check(game.mission_cards.size()==10,"All ten missions shown in selector")
 var available := 0
 for card in game.mission_cards:
  if not card.disabled:available+=1
 check(available==2,"Two branch entries unlocked initially")
 game.select_mission("forest_03")
 check(game.selected_map!="forest_03","Locked UI selection rejected")
 game.select_mission("forest_01")
 await game.begin_operation()
 check(not game.loading_panel.visible and not game.launching,"Loading overlay closes when operation is ready")
 check(game.district.map_id=="forest_01" and game.bots.size()==12,"Campaign selection builds actual mission")
 game.player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 for i in range(2):await physics_frame
 for bot in game.bots:
  check(bot.defensive and bot.has_cover,"Campaign bot starts assigned to defense")
  bot.target=game.player.position
  bot.alerted=true
  bot.has_cover=false
  bot.find_cover()
  check(not bot.has_cover or Vector2(bot.cover_point.x-bot.home.x,bot.cover_point.z-bot.home.z).length()<=bot.defense_radius+0.01,"Cover search stays within defense sector")
 game.finish(false)
 check(not game.campaign.unlocked("forest_02"),"Defeat does not unlock next mission")
 game.finish(true)
 check(game.campaign.unlocked("forest_02") and not game.campaign.unlocked("forest_03"),"Victory unlocks only next mission")
 check(game.campaign.unlocked("village_01") and not game.campaign.unlocked("village_02"),"Branches progress independently")
 game.to_menu()
 game.select_mission("village_01")
 game.start_match()
 check(game.district.map_id=="village_01" and game.district.interior_points.size()>=6,"Village branch builds distinct settlement")
 game.player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 var previous: District=game.district
 game.start_match()
 check(game.district!=previous,"Restart rebuilds destroyed campaign geometry")
 game.queue_free()
 for i in range(3):await process_frame
 await create_timer(0.15).timeout
 print("FAIL: " if failed else "PASS: ",checks," campaign UI, mission lifecycle, unlock and defensive-sector checks")
 quit(1 if failed else 0)
