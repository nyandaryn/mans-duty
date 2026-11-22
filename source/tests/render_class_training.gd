extends SceneTree

# The training screen with its eight course tabs, and a shot from each new
# course: the machine gunner on his bipod at the 300 m group, the grenadier
# with the RPG-7 at the BMP hulk on 200 m, the FPV over the checkpoint.
# KVARTAL_PREVIEW_DIR=<dir> godot --fixed-fps 60 --path source --resolution 1280x720 --script res://tests/render_class_training.gd
var game: Node3D
var out := ""
var tag := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=30):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+tag+".png")
 print("SNAP ",name)

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 tag="-%d" % DisplayServer.window_get_size().y
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 game.volume=0
 await frames(30)
 await snap("menu-home",30)
 game.set_player_class("machinegunner")
 game.main_menu.show_screen("training")
 await snap("training-machinegunner",30)
 game.main_menu.select_course("grad")
 game.main_menu.select_chapter(4)
 await snap("training-grad",20)
 game.main_menu.select_course("uav")
 await snap("training-uav",20)
 if tag!="-720":quit();return
 # Machine gunner: prone on the bipod, the sight on 3, at the group.
 await game.begin_training(1,"machinegunner")
 var t=game.courses.machinegunner
 await frames(60)
 t.skip()
 await frames(30)
 t.skip()
 game.player.current().scope_zero=300
 t.face(TrainingRange.TARGETS.g300b.point)
 game.player.pitch=0.004
 await snap("course-machinegunner",60)
 Input.action_press("aim")
 await snap("course-machinegunner-sight",50)
 Input.action_release("aim")
 game.to_menu("training")
 # Grenadier: the RPG-7 loaded on the shoulder, the hulk at 200 m.
 await game.begin_training(1,"grenadier")
 t=game.courses.grenadier
 await frames(60)
 t.face(TrainingRange.HULKS.h200+Vector3(0,1.0,0))
 game.player.pitch=0.0
 await snap("course-grenadier",60)
 Input.action_press("aim")
 await snap("course-grenadier-pgo",60)
 Input.action_release("aim")
 game.to_menu("training")
 # UAV: the FPV near the checkpoint, the hulk ahead.
 await game.begin_training(0,"uav")
 t=game.courses.uav
 await frames(30)
 t.skip();t.skip();t.skip()
 await frames(10)
 var d=t.drone()
 if d!=null:
  d.global_position=TrainingRange.WAYPOINT+Vector3(10,game.district.ground_height(TrainingRange.WAYPOINT)+24.0,40)
  d.velocity=Vector3.ZERO
  d.yaw=atan2(-(TrainingRange.WAYPOINT.x-d.global_position.x),-(TrainingRange.WAYPOINT.z-d.global_position.z))
 await snap("course-uav",40)
 quit()
