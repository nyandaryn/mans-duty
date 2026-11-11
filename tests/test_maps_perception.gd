extends SceneTree
var checks := 0
func verify(ok: bool, message: String):
 checks+=1
 if not ok:
  printerr("FAIL: ",message)
  quit(1)
  assert(ok,message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame
func run():
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 for map_id in ["city","shelterbelt","city"]:
  game.selected_map=map_id
  game.start_match()
  game.player.set_physics_process(false)
  for bot in game.bots:bot.set_physics_process(false)
  await frames(2)
  verify(game.district.map_id==map_id,"Selected map is built on mission start")
  verify(game.bots.size()==10,"Map switch does not duplicate opponents")
  for bot in game.bots:
   verify(game.district.path(bot.position,game.player.position).size()>1,"Every defender is connected to insertion")
   verify(not bot.line_clear(bot.position+Vector3.UP*1.6,game.player.camera.global_position),"Insertion starts out of enemy sight")
  for point in game.district.interior_points:verify(game.district.path(game.player.position,point).size()>1,"Furnished room connects to outdoor navigation")
  if map_id=="shelterbelt":
   verify(game.district.canopy_centers.size()>700,"Forest canopy covers the whole map rather than six sparse rows")
   verify(game.district.concealment_patches.size()>1500,"Head-high undergrowth is present across woodland")
   var concealed := 0
   var sampled := 0
   for x in [-70,-35,0,35,70]:
    for z in [-65,-20,25]:
     var a := Vector3(x,1.65,z)
     var b := a+Vector3(24,0,32)
     sampled+=1
     if game.district.foliage_visibility(a,b)<0.3:concealed+=1
   verify(concealed>=sampled*0.65,"Most 40 m forest sightlines are broken by visible undergrowth")
   print("Forest: ",game.district.canopy_centers.size()," trees; ",game.district.concealment_patches.size()," bushes; ",concealed,"/",sampled," screened sightlines")
  game.to_menu()
 game.selected_map="city"
 game.start_match()
 for bot in game.bots:bot.set_physics_process(false)
 var player: Operator=game.player
 player.position=Vector3(16,0.1,0)
 player.rotation.y=-PI/2
 player.set_physics_process(true)
 Input.action_press("forward")
 await frames(160)
 Input.action_release("forward")
 player.set_physics_process(false)
 verify(player.position.x>23 and player.position.x<35,"Actual player capsule walks through doorway and corridor without jumping a threshold")
 var far := Perception.rate(150,0.18,0.95,0.32,0,10,1,false,true)
 var exposed := Perception.rate(150,1,0.2,1,0,10,1,false,false)
 var near := Perception.rate(8,0.18,0.95,0.32,0,10,1,false,true)
 verify(far<exposed*0.2 and near>far*30,"150 m shaded partial camouflage is difficult; 8 m remains conspicuous")
 verify(Perception.rate(80,1,0.9,0.4,0,0,1,false,true)>Perception.rate(80,1,0.9,0.4,0,10,1,false,true)*4,"Gunfire breaks camouflage advantage")
 verify(Perception.rate(80,1,0.9,0.4,3,10,1,false,true)>Perception.rate(80,1,0.9,0.4,0,10,1,false,true),"Movement increases recognition")
 verify(Perception.rate(8,0,0,1,3,0,1,false,false)==0,"No recognition through opaque cover even at close range")
 verify(Wardrobe.match_color("urban_grey",Color("888c86"))>Wardrobe.match_color("rf_digital",Color("888c86")),"Urban palette matches concrete better than dark forest uniform")
 var enemy: Hostile=game.bots[0]
 enemy.position=Vector3(0,0.1,27)
 enemy.rotation.y=PI
 player.position=Vector3(0,0.1,35)
 player.rotation=Vector3.ZERO
 player.update_cover(1)
 await frames(2)
 var eye := enemy.position+Vector3.UP*1.6
 var open := Perception.observe(enemy,player,game,eye)
 verify(open.exposure>0.8,"Open body exposes multiple actual anatomical samples")
 var wall := StaticBody3D.new()
 var collision := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size=Vector3(3,3,0.2)
 collision.shape=shape
 wall.add_child(collision)
 game.add_child(wall)
 wall.position=Vector3(0,1.5,31)
 await frames(2)
 var hidden := Perception.observe(enemy,player,game,eye)
 verify(hidden.exposure==0 and hidden.rate==0,"Real wall occludes all body samples")
 wall.free()
 game.player_outfit="urban_grey"
 player.outfit_id=game.player_outfit
 player.make_viewmodel()
 var cloth_found := false
 for mesh in player.viewmodel.find_children("*","MeshInstance3D",true,false):
  for surface in range(mesh.mesh.get_surface_count()):
   if mesh.get_active_material(surface).resource_name=="uniform_urban_grey":cloth_found=true
 verify(cloth_found,"Selected uniform appears on first-person sleeves")
 game.player_outfit="ghillie_green"
 game.refresh_outfit_preview()
 verify(game.preview_actor.model.find_children("GhillieTufts","MultiMeshInstance3D",true,false).size()==5,"Ghillie adds silhouette-breaking geometry")
 game.queue_free()
 await frames(4)
 print("PASS: %d map, collision, outfit and recognition checks" % checks)
 quit()
