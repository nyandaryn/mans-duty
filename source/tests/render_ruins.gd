extends SceneTree

# Screenshots of the Avdiivka village under the overcast and a BMP-2 driving
# over the heap of a house a «Grad» rocket brought down: the street, the
# heap, the vehicle climbing it and on top.
var game: Node3D
var out := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=1):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("SNAP ",name," FPS=",Engine.get_frames_per_second())

func look(from: Vector3, at: Vector3) -> void:
 game.player.global_position=from
 var d:=at-(from+Vector3.UP*1.6)
 game.player.rotation.y=atan2(-d.x,-d.z)
 game.player.pitch=atan2(d.y,Vector2(d.x,d.z).length())

func lane_clear(from: Vector3, to: Vector3) -> bool:
 var district: Node3D=game.district
 var box:=BoxShape3D.new()
 var along:=Vector3(to.x-from.x,0,to.z-from.z)
 box.size=Vector3(4.2,2.6,along.length()+(BmpArt.HALF+1.5)*2.0)
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=box;query.collision_mask=1
 query.exclude=Demolition.ground(district)
 query.transform=Transform3D(Basis.looking_at(along.normalized(),Vector3.UP),(from+to)*0.5+Vector3.UP*1.7)
 for contact in district.get_world_3d().direct_space_state.intersect_shape(query,64):
  var body: Object=contact.collider
  if body.has_meta("rubble") or body.has_meta("crushable") or body.has_meta("terrain"):continue
  return false
 return true

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class("rifleman")
 game.battle_size=18
 game.selected_map=BattleMap.ID
 game.start_match()
 game.battle.skip_approach()
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 for squad in game.battle.mech:squad.set_physics_process(false);squad.vehicle.gunner.allowed=false
 game.player.set_physics_process(false)
 game.set_debug_invulnerable(true)
 await frames(30)
 var district: Node3D=game.district
 var houses: Array=district.get_meta("houses",[])
 var target: Dictionary={}
 var from:=Vector3.ZERO;var to:=Vector3.ZERO
 for house in houses:
  if house.full or Vector2(house.half).x<3.5 or Vector2(house.half).y<3.0:continue
  var center: Vector3=house.center
  if center.distance_to(game.player.global_position)<40.0 or absf(center.x)>160 or absf(center.z)>160:continue
  game.blasts.detonate(center+Vector3.UP*(float(house.height)-0.8),"grad")
  await frames(3)
  if not house.down:continue
  var basis:=Basis(Vector3.UP,float(house.yaw))
  var base: Vector2=Demolition.mound(house).base
  for axis in [Vector3(1,0,0),Vector3(0,0,1)]:
   var reach:=(base.x if axis.x>0 else base.y)+12.0
   var a: Vector3=center+basis*(-axis*reach);var b: Vector3=center+basis*(axis*reach)
   if lane_clear(a,b):target=house;from=a;to=b;break
  if not target.is_empty():break
 var center: Vector3=target.center
 var heading:=Vector3(to.x-from.x,0,to.z-from.z).normalized()
 var side:=heading.cross(Vector3.UP)
 # The street of the village under the overcast, the heap in the dust gone.
 var eye:=center-heading*4.0+side*16.0;eye.y=district.ground_height(eye)+0.05
 await frames(600)
 look(eye,center+Vector3.UP*0.6)
 await snap("ruins-heap",30)
 var wide:=center+side*45.0-heading*25.0;wide.y=district.ground_height(wide)+0.05
 look(wide,center+heading*20.0+Vector3.UP*3.0)
 await snap("ruins-street",30)
 # The BMP over it.
 var v:=BmpVehicle.new();game.world_root.add_child(v);v.setup(game,"9")
 await physics_frame
 var start:=from;start.y=district.ground_height(start)+0.05
 v.global_transform=Transform3D(Basis.looking_at(heading,Vector3.UP),start)
 var probe:=PhysicsShapeQueryParameters3D.new();var box:=BoxShape3D.new();box.size=Vector3(3.6,2.5,7.4);probe.shape=box
 probe.collision_mask=1;probe.exclude=Demolition.ground(district)+[v.get_rid()];probe.transform=Transform3D(v.global_basis,start+Vector3.UP*1.3)
 for contact in district.get_world_3d().direct_space_state.intersect_shape(probe,32):
  if contact.collider is DestructibleSurface and BmpVehicle.crushable(contact.collider):Demolition.flatten(game,contact.collider,heading)
 v.driver_ai=BmpDriver.new();v.driver_ai.setup(v)
 await frames(2)
 v.driver_ai.set_route(PackedVector3Array([start,to]),6.0,2.5)
 look(eye,center+Vector3.UP*0.8)
 var shots:={"climb":false,"top":false}
 var t:=0.0
 while t<40.0 and not v.driver_ai.arrived:
  await process_frame
  t+=1.0/60.0
  var along:=(v.global_position-center).dot(heading)
  look(eye,v.global_position+Vector3.UP*1.0)
  if not shots.climb and along>-float(Demolition.mound(target).base.x)-1.0 and v.global_position.y-district.ground_height(v.global_position)>0.25:
   shots.climb=true;await snap("ruins-bmp-climb")
  if not shots.top and absf(along)<0.6:
   shots.top=true;await snap("ruins-bmp-top")
 await snap("ruins-bmp-over",20)
 quit()
