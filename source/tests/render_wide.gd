extends SceneTree

# Screenshots of every screen and overlay at the current window size: the
# front end, the infantry HUD and its panels, the mortar sight, the BM-21 cab,
# sight, tablet and console. Run with --resolution 2560x1080 / 3840x1080.
var game: Node3D
var out := ""
var tag := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=30):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+tag+"-"+name+".png")
 printerr("SNAP ",name," ",root.get_visible_rect().size)

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 tag=OS.get_environment("WIDE_TAG")
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 game.volume=0
 if OS.get_environment("UI_WIDTH")!="":game.set_ui_width(int(OS.get_environment("UI_WIDTH")))
 await snap("menu-home",90)
 for id in ["campaign","battle","training","loadout","settings"]:
  game.main_menu.show_screen(id)
  await snap("menu-"+id)
 game.main_menu.show_screen("home")
 game.set_player_class("rifleman")
 game.selected_map="city"
 game.start_match()
 await frames(120)
 for b in game.bots:b.set_physics_process(false)
 game.player.position=Vector3(1,0.1,34);game.player.pitch=0.06
 await snap("hud",30)
 game.set_pause(true)
 await snap("pause",10)
 game.set_pause(false)
 game.topo_map.toggle()
 await snap("map",20)
 game.topo_map.toggle()
 game.inventory.toggle()
 await snap("inventory",20)
 game.inventory.toggle()
 game.show_result("ЗАВДАННЯ ВИКОНАНО","Знешкоджено 10 з 10 · час 04:12 · влучань 38 %",[["ЩЕ РАЗ",func():pass],["ГОЛОВНЕ МЕНЮ",func():pass]])
 await snap("result",10)
 game.result_panel.hide()
 game.set_player_class("mortarman")
 game.start_match()
 await frames(120)
 for b in game.bots:b.set_physics_process(false)
 game.crew.deploy();game.player.field_rig.tick(MortarCrew.DEPLOY_ALONE+0.1)
 await frames(20)
 game.crew.sight.open()
 await snap("mortar-sight",30)
 game.crew.sight.close()
 await game.begin_training(3)
 await frames(150)
 var grad: GradCommand=game.grad
 grad.hud.toggle("tablet")
 await snap("grad-tablet",30)
 grad.hud.close_all()
 grad.hud.toggle("console")
 await snap("grad-console",20)
 grad.hud.close_all()
 await snap("grad-cab",20)
 quit()
