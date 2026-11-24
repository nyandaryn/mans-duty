extends SceneTree

# Screenshots of the TOS-1A: the vehicle on the march and laid on its
# jacks, a launch, every phase of a thermobaric burst (the fireball, the
# condensation bubble, the dust ring, the fires, the white clouds), a
# salvo of twelve from afar and the package going up. Run in a window:
# KVARTAL_PREVIEW_DIR=<dir> godot --path source --fixed-fps 60 -s tests/render_tos.gd
var game: Node3D
var out := ""
var camera: Camera3D
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=0):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("SNAP ",name," FPS=",Engine.get_frames_per_second())

func ground(at: Vector3) -> Vector3:
 return Vector3(at.x,AvdiivkaData.shared().height(at.x,at.z),at.z)

func look(eye: Vector3, target: Vector3, fov: float=60.0) -> void:
 camera.current=true;camera.fov=fov
 camera.global_position=eye;camera.look_at(target,Vector3.UP)

func sequence(label: String, moments: Array) -> void:
 var done:=0
 for m in moments:
  await frames(int(m)-done);done=int(m)
  await snap("%s-%04d" % [label,int(m)])

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class("mortarman")
 game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 await frames(5)
 game.player.set_process_unhandled_input(false)
 game.player.set_physics_process(false)
 game.hud.hide()
 # The wrist display with the battery's fire would cover a third of the frame.
 game.drone_feed.set_process(false);game.drone_feed.visible=false
 camera=game.menu_camera
 var tos: EnemyTos=game.battle.tos
 tos.set_physics_process(false)
 var vehicle: TosVehicle=tos.vehicle
 # Out of the tree line onto open ground for the pictures.
 var spot:=ground(tos.fire_point)
 var aim:=BmpRoutes.flat(BmpRoutes.PARK_ROAD,game.district)
 var toward:=aim-spot;toward.y=0;toward=toward.normalized()
 vehicle.place(spot,toward)
 game.district.operation_area.stream(spot,60)
 await frames(10)
 var side:=toward.cross(Vector3.UP)
 look(spot+side*11.0-toward*6.0+Vector3.UP*3.0,spot+Vector3.UP*1.4)
 await snap("tos-march",30)
 look(spot-side*9.0+toward*9.0+Vector3.UP*2.2,spot+Vector3.UP*1.6)
 await snap("tos-march-front",10)
 # Laid on the column's start: jacks down, the package up.
 var from:=vehicle.global_position+Vector3.UP*2.4
 var flat:=Vector2(aim.x-from.x,aim.z-from.z)
 vehicle.lay(GradBallistics.bearing(Vector3(flat.x,0,flat.y)),TosBallistics.elevation_to(flat.length(),from.y-aim.y))
 vehicle.jacks=1.0;vehicle.platform_yaw=vehicle.want_yaw;vehicle.elevation=vehicle.want_elevation;vehicle.pose()
 look(spot+side*12.0+toward*2.0+Vector3.UP*2.5,spot+Vector3.UP*2.0)
 await snap("tos-laid",20)
 look(spot-side*7.0-toward*9.0+Vector3.UP*2.0,spot+Vector3.UP*1.5)
 await snap("tos-laid-rear",10)
 # A salvo of twelve from 45 m off its side.
 look(spot+side*38.0-toward*16.0+Vector3.UP*3.0,spot+toward*8.0+Vector3.UP*5.0,62.0)
 await frames(20)
 vehicle.fire_salvo(12)
 await sequence("tos-launch",[2,8,20,40,90,180,300])
 vehicle.salvo_left=0
 # One burst on open ground, from 120 m, phase by phase.
 var field:=ground(Vector3(700,0,1300))
 game.district.operation_area.stream(field,60)
 look(field+Vector3(-110,12,40),field+Vector3(0,8,0),55.0)
 await frames(30)
 await snap("tos-burst-before")
 game.blasts.detonate(field+Vector3.UP*0.2,"tos")
 await sequence("tos-burst",[1,3,6,10,20,40,90,240,600,1200,1800])
 # From 60 m, the first second.
 var field2:=ground(Vector3(760,0,1150))
 look(field2+Vector3(-55,4,20),field2+Vector3(0,5,0),60.0)
 await frames(20)
 game.blasts.detonate(field2+Vector3.UP*0.2,"tos")
 await sequence("tos-close",[1,2,4,8,15,30,60])
 # Twelve over a few hundred metres from 650 m: the wall of cloud (from
 # farther the overcast's haze takes most of it).
 var area:=ground(Vector3(400,0,1500))
 look(area+Vector3(-520,45,390),area+Vector3(0,20,0),45.0)
 await frames(20)
 for k in range(12):
  var p:=ground(area+Vector3(randf_range(-140,140),0,randf_range(-70,70)))
  game.blasts.detonate(p+Vector3.UP*0.2,"tos")
  await frames(15)
 await sequence("tos-salvo",[1,60,240,600,1200])
 # The package going up.
 look(spot+side*60.0+toward*10.0+Vector3.UP*8.0,spot+Vector3.UP*4.0,55.0)
 await frames(20)
 vehicle.hull.explode()
 await sequence("tos-cookoff",[1,4,10,30,90,300])
 game.queue_free()
 await frames(3)
 quit()
