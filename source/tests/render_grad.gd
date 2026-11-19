extends SceneTree

# Screenshots of the BM-21 class: the vehicle outside in both positions, the
# cab, the sight, the panel, the tablet, the drone and a salvo.
var game: Node3D
var out := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=30):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("SNAP ",name," FPS=",Engine.get_frames_per_second())

func outside(camera: Camera3D, vehicle: GradVehicle, local_eye: Vector3, local_target: Vector3) -> void:
 camera.current=true
 camera.global_position=vehicle.to_global(local_eye)
 camera.look_at(vehicle.to_global(local_target),Vector3.UP)

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class("grad")
 game.battle_size=18
 game.start_match()
 for actor in game.allies+game.bots:actor.set_physics_process(false)
 var grad: GradCommand=game.grad
 var v: GradVehicle=grad.vehicle
 await frames(120)
 var camera:=Camera3D.new();camera.far=6000;camera.fov=50;game.world_root.add_child(camera)
 game.hud.hide()
 outside(camera,v,Vector3(-9,2.6,-7),Vector3(0,1.6,0))
 await snap("grad-travel-front")
 outside(camera,v,Vector3(-8.5,2.0,4.5),Vector3(0,1.7,0.5))
 await snap("grad-travel-rear")
 # Into action.
 v.set_cover(false);v.toggle_lock();v.set_bracket(true);v.shields_down=true;v.apply_shields(true)
 v.azimuth=-80;v.elevation=12;v.apply_launcher()
 outside(camera,v,Vector3(-10,3.2,5),Vector3(-1,2.2,0))
 await snap("grad-action")
 outside(camera,v,Vector3(-4.5,2.6,-0.5),Vector3(-1.2,1.8,0.8))
 await snap("grad-gunner-station")
 game.hud.show()
 game.player.global_position=v.to_global(Vector3(-1.6,0.2,-1.35))
 grad.enter("driver")
 grad.look=Vector2(0.15,-0.12)
 v.ignition=true;v.running=true;v.omega=700.0/60.0*TAU
 await snap("grad-driver")
 grad.enter("commander")
 grad.hud.toggle("console")
 await snap("grad-console")
 grad.hud.close_all()
 v.boussole=true;v.deflection=1234;v.sight_setting=152;v.level_setting=3004
 grad.enter("gunner")
 await snap("grad-sight")
 grad.enter("commander")
 grad.request_drone();grad.drone_eta=0.01
 await frames(5)
 grad.drone.global_position=Vector3(-30,140,120)
 grad.drone.yaw=BattleMap.facing(true)
 grad.begin_piloting()
 grad.drone.camera_pitch=-0.75
 await snap("grad-drone",60)
 grad.mark_target()
 grad.end_piloting()
 grad.hud.toggle("tablet")
 await snap("grad-tablet")
 grad.hud.close_all()
 grad.leave()
 # A salvo seen from the side.
 v.battery_on=true;v.fire_mode=1;v.program_wound=true
 v.azimuth=-80;v.elevation=9;v.apply_launcher()
 game.hud.hide()
 outside(camera,v,Vector3(-30,5,-34),Vector3(-6,6,0))
 v.set_lever(true)
 await frames(150)
 await snap("grad-salvo",1)
 outside(camera,v,Vector3(-60,12,40),Vector3(-40,20,-20))
 await snap("grad-salvo-wide",40)
 v.set_lever(false)
 camera.current=false
 game.hud.show()
 game.topo_map.open()
 await snap("battle-topo-map")
 quit()
