extends SceneTree

# Screenshots of the TOS-1A commander's class: the start by the vehicle, the
# driver's view out of the hatch and through the TNPO-168V with the
# instruments, the commander's TKN-3A and his fire-control panel, the 1D14
# sight with a range, the tablet, the observation post's drone and the
# training card. Run in a window:
# KVARTAL_PREVIEW_DIR=<dir> godot --path source --fixed-fps 60 -s tests/render_tos_class.gd
var game: Node3D
var out := ""
var tos: TosCommand
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=0):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("SNAP ",name," FPS=",Engine.get_frames_per_second())

func place(at: Vector3, yaw: float):
 var v:=tos.vehicle
 # Not straight after a snapshot: a body unfrozen and moved at
 # frame_post_draw is put back by the next physics step (Jolt).
 await process_frame
 v.freeze=false;v.parked_time=0.0
 tos.place_vehicle(tos.ground(at),yaw)

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class("tos")
 game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 await frames(5)
 tos=game.tos
 var v:=tos.vehicle
 await snap("class-start",90)
 tos.enter("driver")
 await snap("class-driver-hatch",30)
 v.toggle_hatch()
 Input.action_press("aim")
 await snap("class-driver-tnpo",30)
 Input.action_release("aim")
 # On the firing position, the drill done, laid on OP-2.
 var aim: Vector3=tos.strongpoints[1].point
 var fa:=TosCommand.FIRING_AREA
 await place(fa,atan2(aim.x-fa.x,-(aim.z-fa.z)))
 await frames(60)
 print("PLACED ",v.global_position," firing area ",fa," target ",aim.distance_to(v.global_position))
 v.master=true;v.running=true;v.omega=TosVehicle.IDLE_RPM/60.0*TAU;v.parking=true
 v.fcs_power=true;v.fcs_warm=1.0;v.jacks_wanted=true;v.jacks=1.0;v.stops_locked=false
 tos.enter("commander")
 tos.targets.append({"name":"Ц-1","point":aim});tos.selected_target=0
 tos.load_target()
 await frames(600)
 await snap("class-commander",10)
 tos.zoomed=true
 await snap("class-commander-tkn",10)
 tos.zoomed=false
 tos.hud.toggle("console")
 await snap("class-console",10)
 tos.hud.close_all()
 tos.hud.toggle("tablet")
 await snap("class-tablet",30)
 tos.hud.close_all()
 tos.enter("gunner")
 v.sight_pitch=-1.2
 v.range_target()
 await snap("class-sight",20)
 v.series=12;v.armed=true
 tos.fire()
 await snap("class-sight-launch",70)
 print("HULL ",v.hull.history," at ",v.global_position)
 tos.enter("commander")
 tos.spawn_drone()
 tos.drone.global_position=aim+Vector3(0,120,180);tos.drone.yaw=0.0;tos.drone.camera_pitch=-0.6
 tos.begin_piloting()
 await snap("class-drone",120)
 tos.end_piloting()
 game.to_menu()
 game.main_menu.show_screen("training")
 await snap("class-menu-training",20)
 game.begin_training(1,"tos")
 for i in range(1200):
  if game.running and game.courses["tos"].running and not game.launching:break
  await process_frame
 await snap("class-training-card",60)
 quit()
