extends SceneTree

# Screenshots of the infantry training: the training screen with its class
# tabs, the training range, the step cards and markers of the rifleman, the
# sniper and the mortarman courses, the map and the mortar sight.
var game: Node3D
var out := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=30):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 printerr("SNAP ",name," FPS=",Engine.get_frames_per_second())

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 game.volume=0
 game.set_player_class("rifleman")
 game.main_menu.show_screen("training")
 await snap("range-menu-rifleman",60)
 game.main_menu.select_course("mortarman")
 await snap("range-menu-mortarman",20)

 # Rifleman.
 await game.begin_training(0,"rifleman")
 var t: RangeCourse=game.courses.rifleman
 await snap("range-rifleman-start",120)
 t.place(TrainingRange.LINE+Vector3(-3,0,0.6),TrainingRange.TARGETS.t50.point)
 game.player.pitch=-0.03
 t.skip()
 await snap("range-rifleman-line",60)
 await game.begin_training(1,"rifleman")
 t.skip()
 await frames(30)
 t.face(TrainingRange.TARGETS.t25.point)
 await snap("range-rifleman-hit25",60)
 t.targets.t25.hit(t.targets.t25.global_position)
 await snap("range-rifleman-knocked",20)
 await game.begin_training(4,"rifleman")
 await frames(60)
 t.skip()
 await frames(20)
 t.face(TrainingRange.BUNKER)
 await snap("range-rifleman-bunker",60)

 # Sniper.
 await game.begin_training(1,"sniper")
 t=game.courses.sniper
 await snap("range-sniper-mat",120)
 Input.action_press("aim")
 game.player.current().scope_zero=300
 await snap("range-sniper-scope",60)
 Input.action_release("aim")
 await game.begin_training(2,"sniper")
 await frames(60)
 Input.action_press("aim")
 await snap("range-sniper-500",60)
 Input.action_release("aim")

 # Mortarman.
 await game.begin_training(0,"mortarman")
 t=game.courses.mortarman
 await snap("range-mortar-start",120)
 await game.begin_training(1,"mortarman")
 await frames(60)
 t.skip()
 await frames(5)
 t.auto("ruler")
 await snap("range-mortar-map",40)
 t.skip()
 await frames(5)
 game.topo_map.close()
 game.crew.sight.open()
 await snap("range-mortar-sight",40)
 game.crew.sight.close()
 await game.begin_training(2,"mortarman")
 await frames(60)
 t.face(TrainingRange.POSITION)
 game.player.pitch=0.02
 await snap("range-mortar-position",40)
 quit()
