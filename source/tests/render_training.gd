extends SceneTree

# Screenshots of the new front end and of the BM-21 training: the main menu
# and its screens, the step card with its markers, pause, loading, results.
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
 await snap("menu-home",90)
 game.main_menu.items[2].grab_focus()
 await snap("menu-home-focus",20)
 for id in ["campaign","battle","training","loadout","settings"]:
  game.main_menu.show_screen(id)
  await snap("menu-"+id)
 game.main_menu.show_screen("home")
 # Loading screen of a training chapter.
 game.training="grad";game.training_chapter=0
 game.loading_sub.text="НАВЧАННЯ · БМ-21 «ГРАД» · РОЗДІЛ 1"
 game.loading_title.text=GradTraining.CHAPTERS[0].title
 game.loading_tip.text="Полігон під Авдіївкою, противника немає. Картка кроку — праворуч угорі; F6 — виконати крок автоматично."
 game.loading_panel.show()
 await snap("training-loading",5)
 game.loading_panel.hide();game.training=""
 await game.begin_training(0)
 var grad: GradCommand=game.grad
 var t: GradTraining=game.grad_training
 for actor in game.allies+game.bots:actor.set_physics_process(false)
 await snap("training-start",120)
 game.player.global_position=grad.vehicle.to_global(Vector3(-1.6,0.2,-1.35))
 grad.interact()
 await snap("training-cab",30)
 t.skip();t.skip();t.skip();t.skip();t.skip();t.skip()
 await snap("training-orient",90)
 await game.begin_training(2)
 await frames(60)
 await snap("training-commander-marker",30)
 grad.enter("commander")
 grad.spawn_drone();grad.drone_eta=-1
 await frames(20)
 grad.begin_piloting()
 await frames(30)
 grad.drone.global_position=t.target_point()+Vector3(-60,90,200)
 grad.drone.yaw=0.25;grad.drone.camera_pitch=-0.45
 await snap("training-drone",60)
 await game.begin_training(3)
 await frames(120)
 grad.hud.toggle("tablet")
 await snap("training-tablet",30)
 grad.hud.close_all();t.skip();t.skip()
 grad.enter("gunner")
 grad.vehicle.boussole=true
 await snap("training-sight",30)
 game.set_pause(true)
 await snap("training-pause",10)
 game.set_pause(false)
 t.chapter=4;t.step=t.STEPS[4].size()-1;t.enter_step()
 t.finish()
 await snap("training-result",20)
 quit()
