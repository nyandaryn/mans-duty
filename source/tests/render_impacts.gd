extends SceneTree

# Bullet strikes frame by frame: concrete, brick, a board, a steel plate,
# the ground and a man, from a few metres and up close.
var game: Node3D
var out := ""
var base := Vector3.ZERO
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 printerr("SNAP ",name)

func ground(x: float, z: float) -> Vector3:
 var p := base+Vector3(x,0,z)
 p.y=game.district.ground_height(p)
 return p

# Flat open ground near the start: nothing but the terrain under 30 m.
func open_ground(start: Vector3) -> Vector3:
 var space: PhysicsDirectSpaceState3D=game.district.get_world_3d().direct_space_state
 for radius in range(0,200,10):
  for k in range(maxi(1,radius/3)):
   var c := start+Vector3(cos(k*TAU/maxi(1,radius/3)),0,sin(k*TAU/maxi(1,radius/3)))*radius
   var h0: float=game.district.ground_height(c)
   var clear := true
   for ox in range(-11,12,2):
    for oz in range(-5,13,2):
     var p := c+Vector3(ox,0,oz)
     var h: float=game.district.ground_height(p)
     if absf(h-h0)>0.5:clear=false;break
     var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,h+30,p.z),Vector3(p.x,h-0.5,p.z),1))
     if hit.is_empty() or absf(float(hit.position.y)-h)>0.3:clear=false;break
    if not clear:break
   # Thin walls and fences slip between the vertical rays: look along.
   for ox in range(-11,12,1):
    if not clear:break
    for up in [0.4,1.2,2.2]:
     var a := c+Vector3(ox,h0+up,13)
     var b := c+Vector3(ox,h0+up,-5)
     if not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(a.x,h0+up,a.z),Vector3(b.x,h0+up,b.z),1)).is_empty():clear=false;break
   if clear:return Vector3(c.x,0,c.z)
 return start

func block(at: Vector3, size: Vector3, color: Color, substance: String) -> void:
 var body: DestructibleSurface=game.district.collider(at,size,substance)
 body.set_meta("surface_color",color);body.tint=color
 var mesh := MeshInstance3D.new()
 var box := BoxMesh.new();box.size=size;mesh.mesh=box
 var paint := StandardMaterial3D.new();paint.albedo_color=color;paint.roughness=0.9
 mesh.material_override=paint
 game.district.add_child(mesh);mesh.position=at

func shoot(from: Vector3, to: Vector3, weapon: String="ak74") -> void:
 game.ballistics.launch(from,from.direction_to(to),weapon,68,game.player)

func sequence(label: String, moments: Array) -> void:
 var done := 0
 for m in moments:
  await frames(int(m)-done);done=int(m)
  await snap("%s-%02d" % [label,int(m)])

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 await frames(5)
 game.player.set_process_unhandled_input(false)
 game.player.set_physics_process(false)
 game.hud.hide()
 for bot in game.bots+game.allies:bot.set_physics_process(false);bot.position=Vector3(0,-200,0)
 base=open_ground(game.district.player_spawn)
 printerr("BASE ",base)
 game.player.global_position=ground(0,30)+Vector3.UP*0.1
 var row: Array=[["concrete","8d8a82",-4.5,0.3],["brick","8a4a35",-1.5,0.25],["wood","6d5a43",1.5,0.04],["steel","4c5248",4.5,0.012]]
 for spec in row:
  var g := ground(float(spec[2]),0)
  block(g+Vector3(0,1.1,0),Vector3(2.4,2.2,float(spec[3])),Color(spec[1]),spec[0])
 var bot: Hostile=game.bots[0]
 bot.global_position=ground(7.5,1.5);bot.rotation.y=PI*0.5
 bot.animate_pose(1,false)
 await frames(10)
 var camera: Camera3D=game.menu_camera
 camera.current=true
 var eye := ground(1.5,9)+Vector3(0,1.6,0)
 camera.global_position=eye;camera.look_at(ground(1.5,0)+Vector3(0,0.9,0))
 camera.fov=60
 await frames(20)
 await snap("impact-scene")
 # All at once from 6 m: walls, the ground in front of them, the man.
 for spec in row:
  var g := ground(float(spec[2]),0)
  shoot(g+Vector3(0.3,1.4,6),g+Vector3(0,1.25,0))
  var soil := ground(float(spec[2]),2.5)
  shoot(soil+Vector3(0.2,1.5,5),soil)
 shoot(bot.global_position+Vector3(-5,1.3,0.5),bot.global_position+Vector3(0,1.28,0))
 await sequence("impact-wide",[1,3,6,12,24,45,90])
 printerr("WIDE bot dead=",bot.dead," health=",bot.health)
 # The holes from half a metre.
 var near_wall := ground(-4.5,0)
 camera.global_position=near_wall+Vector3(0.15,1.3,0.7);camera.look_at(near_wall+Vector3(0,1.25,0.15))
 await frames(3)
 await snap("impact-holes-concrete")
 var near_brick := ground(-1.5,0)
 camera.global_position=near_brick+Vector3(0.15,1.3,0.7);camera.look_at(near_brick+Vector3(0,1.25,0.125))
 await frames(3)
 await snap("impact-holes-brick")
 # Up close: the concrete, the ground, the plate, the man.
 for close in [["concrete",-4.5],["steel",4.5]]:
  var g := ground(float(close[1]),0)
  camera.global_position=g+Vector3(1.4,1.5,2.2);camera.look_at(g+Vector3(0,1.25,0))
  await frames(30)
  shoot(g+Vector3(0.6,1.35,6),g+Vector3(0,1.25,0))
  await sequence("impact-%s" % close[0],[1,3,8,20,45])
 var spot := ground(0,4)
 camera.global_position=spot+Vector3(2.5,1.2,2.5);camera.look_at(spot+Vector3(0,0.4,0))
 await frames(30)
 shoot(spot+Vector3(-1.5,1.6,6),spot)
 await sequence("impact-earth",[1,3,8,20,45,90])
 # A fresh man for the close look, side on: the puff off his clothes in
 # front, the mist behind him.
 var man: Hostile=game.bots[1]
 bot.global_position=Vector3(0,-200,0)
 man.global_position=ground(7.5,1.5);man.rotation.y=0.0
 man.animate_pose(1,false)
 camera.global_position=man.global_position+Vector3(1.3,1.45,-2.0);camera.look_at(man.global_position+Vector3(-0.2,1.2,0))
 await frames(30)
 game.impacts.record=true
 shoot(man.global_position+Vector3(6,1.3,0.03),man.global_position+Vector3(0,1.3,0))
 await frames(1)
 printerr("MAN last=",game.impacts.last," dead=",man.dead," at=",man.global_position)
 await sequence("impact-man",[2,4,7,12,30])
 game.queue_free()
 await frames(3)
 quit()
