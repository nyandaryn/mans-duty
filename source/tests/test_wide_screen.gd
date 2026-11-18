extends SceneTree

# Wide monitors: the picture fills any screen (stretch aspect "expand", cameras
# keep the height so 21:9 and 32:9 see wider, Hor+), the interface sits in a
# centred frame no wider than the chosen aspect, and backdrops, shades and
# screen effects still reach both edges.
var checks := 0
var failed := false
var game: Node3D

func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
 else:print("ok   ",message)

func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await process_frame

func frame_at(screen: Vector2) -> void:
 game.set_meta("screen_override",screen)
 game.update_frame()

func run() -> void:
 check(ProjectSettings.get_setting("display/window/stretch/aspect")=="expand","Stretch aspect expands to the screen instead of black bars")
 var camera:=Camera3D.new()
 check(camera.keep_aspect==Camera3D.KEEP_HEIGHT,"Cameras keep the vertical field of view (Hor+)")
 camera.free()
 var aspect_21: float=preload("res://scripts/game.gd").UI_WIDTHS[1]
 check(is_equal_approx(aspect_21,2.4),"21:9 frame also takes 2560×1080 and 3440×1440 whole")
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 await frames(10)
 check(game.ui_width==1 and game.frame_margin==0.0,"16:9 window: no margins (%.0f)" % game.frame_margin)
 # 32:9 (3840×1080 is 2560×720 in interface pixels).
 frame_at(Vector2(2560,720))
 check(game.frame_margin==416.0 and game.ui_root.offset_left==416.0 and game.ui_root.offset_right==-416.0,"32:9 with the 21:9 frame: 416 px margins")
 var backdrop: Control=game.main_menu.backdrop
 check(backdrop.offset_left==-416.0 and backdrop.offset_right==416.0,"Menu backdrop reaches both edges")
 var shade: Control=game.pause_panel.get_child(0)
 var side: Control=game.pause_panel.get_child(1)
 check(shade.offset_left==-416.0 and shade.offset_right==416.0 and side.offset_left==-416.0 and side.offset_right==0.0,"Pause shade covers the screen, its side gradient starts at the left edge")
 check(game.concussion_overlay.offset_left==-416.0 and game.topo_map.offset_right==416.0,"Concussion overlay and the map sheet cover the screen")
 var sheets:=0
 for node in game.bleeds:if node is ColorRect and node.mouse_filter==Control.MOUSE_FILTER_STOP and node.offset_left==-416.0:sheets+=1
 check(sheets>=5,"Menu screen sheets bleed too (%d)" % sheets)
 await frames(2)
 var whole: Rect2=game.screen_rect(game.hud)
 check(is_equal_approx(whole.position.x,-416.0),"HUD effects draw over the whole screen (%s)" % whole)
 game.set_ui_width(2)
 check(game.frame_margin==640.0,"16:9 frame on 32:9: 640 px margins")
 game.set_ui_width(0)
 check(game.frame_margin==0.0 and game.ui_root.offset_left==0.0 and backdrop.offset_left==0.0,"Whole width: no frame")
 game.set_ui_width(1)
 frame_at(Vector2(1706,720))
 check(game.frame_margin==0.0,"2560×1080 fullscreen with the 21:9 frame: the whole width")
 frame_at(Vector2(1280,960))
 check(game.frame_margin==0.0,"4:3: no margins")
 for mode in range(3):
  check(game.frame_margin_for(Vector2(1280,720),game.UI_WIDTHS[mode])==0.0,"16:9 never gets a frame (%s)" % game.UI_WIDTH_LABELS[mode])
 game.remove_meta("screen_override");game.update_frame()
 check(game.frame_margin==0.0,"Back to the window size")
 print("checks: ",checks)
 print("PASS" if not failed else "FAILED")
 quit(1 if failed else 0)
