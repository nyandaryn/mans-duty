extends SceneTree
# A BMP-2 drives over the ruins of the village of the great assault:
# - a «Grad» rocket leaves a low mound of rubble (about a metre, sides no
#   steeper than the hull clears), solid to bullets;
# - on the walking map the heap keeps to the footprint of the house; on the
#   vehicles' map it opens, dear to cross, and nobody stops on it;
# - the driver bot runs straight over the heap, slowing to a crawl on it,
#   the hull rising on the mound and coming down level on the far side;
# - the same at road speed, as a player who does not slow down: over it,
#   not stuck, not thrown over;
# - a corner of wall left on the heap goes over under the bow.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
 else:print("ok: ",message)
func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func ray(game: Node, a: Vector3, b: Vector3, exclude: Array[RID]=[]) -> Dictionary:
 return game.district.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1,exclude))

# A lane for the hull straight across the house: nothing in it but the
# heap, the corners of its walls, fences a hull flattens and the ground.
func lane_clear(game: Node, from: Vector3, to: Vector3) -> bool:
 var district: Node3D=game.district
 var box:=BoxShape3D.new()
 var along:=Vector3(to.x-from.x,0,to.z-from.z)
 # The hull standing at either end too.
 box.size=Vector3(4.2,2.6,along.length()+(BmpArt.HALF+1.5)*2.0)
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=box;query.collision_mask=1
 query.exclude=Demolition.ground(district)
 var middle:=(from+to)*0.5
 query.transform=Transform3D(Basis.looking_at(along.normalized(),Vector3.UP),middle+Vector3.UP*1.7)
 for contact in district.get_world_3d().direct_space_state.intersect_shape(query,64):
  var body: Object=contact.collider
  if body.has_meta("rubble") or body.has_meta("crushable") or body.has_meta("terrain"):continue
  return false
 for end in [from,to]:
  var down:=ray(game,end+Vector3.UP*4.0,end+Vector3.DOWN*4.0)
  if down.is_empty() or not down.collider.has_meta("terrain"):return false
 # The ground along it is open country: no ditch, no bank.
 for k in range(21):
  var p:=from.lerp(to,k/20.0)
  if absf(district.ground_height(p)-district.ground_height(from))>1.2:return false
 return true

func drive(game: Node, from: Vector3, to: Vector3, cruise: float, keep_rubble: bool, house: Dictionary) -> Dictionary:
 var district: Node3D=game.district
 var heaps=district.get_meta("rubble_cells")
 if not keep_rubble:district.remove_meta("rubble_cells")
 var v:=BmpVehicle.new();game.world_root.add_child(v);v.setup(game,"9")
 var heading:=Vector3(to.x-from.x,0,to.z-from.z).normalized()
 var start:=from;start.y=district.ground_height(start)+0.05
 v.global_transform=Transform3D(Basis.looking_at(heading,Vector3.UP),start)
 v.driver_ai=BmpDriver.new();v.driver_ai.setup(v)
 # A fence where the hull is put down is flattened first (a driver runs it
 # over; dropped into it, the hull would be thrown up).
 var probe:=PhysicsShapeQueryParameters3D.new();var box:=BoxShape3D.new();box.size=Vector3(3.6,2.5,7.4);probe.shape=box
 probe.collision_mask=1;probe.exclude=Demolition.ground(district)+[v.get_rid()];probe.transform=Transform3D(v.global_basis,start+Vector3.UP*1.3)
 for contact in district.get_world_3d().direct_space_state.intersect_shape(probe,32):
  if contact.collider is DestructibleSurface and BmpVehicle.crushable(contact.collider):Demolition.flatten(game,contact.collider,heading)
 await frames(2)
 var route:=PackedVector3Array([start,to])
 v.driver_ai.set_route(route,cruise,2.5)
 var top:=-INF;var tilt:=0.0;var fastest_on:=0.0;var jams:=0;var t:=0.0
 var center: Vector3=house.center
 while t<60.0 and not v.driver_ai.arrived:
  await physics_frame
  t+=1.0/60.0
  var lift: float=v.global_position.y-district.ground_height(v.global_position)
  if Demolition.inside(house,v.global_position+Vector3.UP,0.0):
   top=maxf(top,lift)
   fastest_on=maxf(fastest_on,absf(v.speed()))
  var up:=v.global_basis.y
  var now:=rad_to_deg(acos(clampf(up.dot(Vector3.UP),-1,1)))
  if OS.has_environment("RUBBLE_TRACE") and Engine.get_physics_frames()%6==0:
   var local:=Basis(Vector3.UP,float(house.yaw)).inverse()*(v.global_position-center)
   print("t=%.1f local=(%.1f,%.1f) lift=%.2f tilt=%.1f pitch=%.1f roll=%.1f v=%.2f gear=%d rpm=%d load=%.0f" % [t,local.x,local.z,lift,now,rad_to_deg(v.rotation.x),rad_to_deg(v.rotation.z),v.speed(),v.gear,v.rpm(),v.load_total])
  tilt=maxf(tilt,now)
  jams=maxi(jams,v.driver_ai.jams)
 var past:=(v.global_position-center).dot(heading)
 var result:={"arrived":v.driver_ai.arrived,"time":t,"top":top,"tilt":tilt,"fastest_on":fastest_on,"jams":jams,"past":past,"rest_tilt":rad_to_deg(acos(clampf(v.global_basis.y.dot(Vector3.UP),-1,1))),"end":v.global_position}
 v.queue_free()
 if not keep_rubble:district.set_meta("rubble_cells",heaps)
 await frames(2)
 return result

func run():
 seed(4417)
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("rifleman");game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 var battle: BattleMode=game.battle
 battle.skip_approach()
 game.player.set_physics_process(false)
 game.set_debug_invulnerable(true)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 for squad in battle.mech:squad.set_physics_process(false);squad.vehicle.gunner.allowed=false
 await frames(5)
 var district: Node3D=game.district
 var houses: Array=district.get_meta("houses",[])
 # A closed house in open ground, a lane across it for the hull.
 var target: Dictionary={}
 var from:=Vector3.ZERO;var to:=Vector3.ZERO
 var tried:=0
 for house in houses:
  if house.full or house.down or Vector2(house.half).x<3.0 or Vector2(house.half).y<3.0:continue
  var center: Vector3=house.center
  if center.distance_to(game.player.global_position)<40.0 or absf(center.x)>170 or absf(center.z)>170:continue
  tried+=1
  if tried>40:break
  game.blasts.detonate(center+Vector3.UP*(float(house.height)-0.8),"grad")
  await frames(4)
  if not house.down:continue
  var basis:=Basis(Vector3.UP,float(house.yaw))
  var base: Vector2=Demolition.mound(house).base
  for axis in [Vector3(1,0,0),Vector3(0,0,1)]:
   var reach:=(base.x if axis.x>0 else base.y)+12.0
   var a: Vector3=center+basis*(-axis*reach);var b: Vector3=center+basis*(axis*reach)
   if lane_clear(game,a,b):target=house;from=a;to=b;break
  if not target.is_empty():break
 check(not target.is_empty(),"A fallen house with an open lane across it (%d tried)" % tried)
 if target.is_empty():
  game.queue_free();await frames(5)
  print("FAILED checks=",checks);quit(1);return
 var center: Vector3=target.center
 var shape:=Demolition.mound(target)
 var heap: DestructibleSurface=null
 var down:=ray(game,center+Vector3.UP*12,center+Vector3.DOWN*3)
 if not down.is_empty() and down.collider.has_meta("rubble"):heap=down.collider
 var ground: float=district.ground_height(center)
 check(heap!=null and heap.get_child(0).shape is ConvexPolygonShape3D,"The house leaves a mound of rubble")
 check(not down.is_empty() and down.position.y-ground>0.5 and down.position.y-ground<1.3,"…about a metre high (%.2f m)" % (down.position.y-ground if not down.is_empty() else -1.0))
 var slope:=rad_to_deg(atan((float(shape.height)+Demolition.BURY)/float(shape.run)))
 check(slope<16.0,"…its sides at %.1f°: the hull overhang clears them" % slope)
 # Bullets stop in it.
 var basis:=Basis(Vector3.UP,float(target.yaw))
 var side:=center+basis*Vector3(-Vector2(shape.base).x-3.0,0,0);side.y=district.ground_height(side)+0.55
 var aim:=center+Vector3.UP*0.55;aim.y=ground+0.55
 var before: int=game.ballistics.hit_count
 var behind: DestructibleSurface=district.surface_piece(center+basis*Vector3(Vector2(shape.base).x+2.0,0.8,0),Vector3(0.3,2,3),Color.GRAY,"wood",basis)
 await frames(2)
 game.ballistics.launch(side,(aim-side).normalized(),"ak74",30,game.player)
 await frames(10)
 check(game.ballistics.hit_count-before==1,"A rifle round stops in the heap (%d hits)" % (game.ballistics.hit_count-before))
 behind.queue_free()
 # The maps.
 var cell: Vector2i=district.navigation_cell(center)
 check(district.grid.is_point_solid(cell),"On the walking map the heap is closed")
 var foot:=center+basis*Vector3(Vector2(target.half).x+1.0,0,0)
 var foot_cell: Vector2i=district.navigation_cell(foot)
 var spill_closed: bool=district.grid.is_point_solid(foot_cell)
 var record_free:=true
 for record in district.navigation_obstacles.near(AABB(foot-Vector3.ONE,Vector3.ONE*2)):
  if record.get("rubble",false) and NavigationObstacles.blocks(record,Vector3(foot.x,district.ground_height(foot),foot.z),foot_cell):record_free=false
 check(record_free,"…the spill a metre past the walls does not close it (cell solid for other reasons: %s)" % str(spill_closed))
 var vgrid: AStarGrid2D=battle.vehicle_grid
 check(not vgrid.is_point_solid(cell) and vgrid.get_point_weight_scale(cell)>=BmpRoutes.RUBBLE_COST,"On the vehicles' map it is open, dear to cross (%.1f)" % vgrid.get_point_weight_scale(cell))
 check(not BmpRoutes.roomy(vgrid,district,center),"…and no place to stop")
 var route:=BmpRoutes.path(district,vgrid,from,to)
 var direct:=Vector2(to.x-from.x,to.z-from.z).length()
 check(not route.is_empty() and BmpRoutes.length_of(route)<direct*1.3,"A route across the ruins: %.0f m for %.0f m straight" % [BmpRoutes.length_of(route) if not route.is_empty() else -1.0,direct])
 # The driver over the heap at a crawl.
 var crawl:=await drive(game,from,to,6.0,true,target)
 print("crawl ",crawl)
 check(crawl.arrived and crawl.past>Vector2(shape.base).length(),"The driver takes the BMP over the heap to the far side (%.0f s)" % crawl.time)
 check(crawl.top>float(shape.height)*0.6,"…the hull rising on the mound (%.2f m over the ground)" % crawl.top)
 check(crawl.fastest_on<BmpDriver.RUBBLE_SPEED+0.8,"…at a crawl over it (%.1f m/s)" % crawl.fastest_on)
 check(crawl.jams==0 and crawl.tilt<25.0 and crawl.rest_tilt<6.0,"…without backing off, tilting %.0f° at most, level after (%.1f°)" % [crawl.tilt,crawl.rest_tilt])
 # At speed, nobody slowing down.
 var fast:=await drive(game,to,from,7.0,false,target)
 print("fast ",fast)
 check(fast.arrived and fast.jams==0,"At %.0f km/h too it goes over (%.0f s)" % [fast.fastest_on*3.6,fast.time])
 check(fast.tilt<35.0 and fast.rest_tilt<6.0,"…not thrown over (%.0f° at most)" % fast.tilt)
 # Every heap: sides the hull clears, small or large.
 var steepest:=0.0
 for house in houses:
  var m:=Demolition.mound(house)
  steepest=maxf(steepest,rad_to_deg(atan((float(m.height)+Demolition.BURY)/float(m.run))))
 check(steepest<=Demolition.SLOPE+0.01,"No heap in the village steeper than %.1f° (%.1f°)" % [Demolition.SLOPE,steepest])
 # A corner of wall on a heap goes over under the bow.
 var corner: DestructibleSurface=null
 for child in district.get_children():
  if child is DestructibleSurface and child.has_meta("merged_mesh") and not child.breaking:corner=child;break
 check(corner!=null and BmpVehicle.crushable(corner),"Corners of the walls stand on the heaps, a hull can put them over")
 if corner!=null:
  var instance: MeshInstance3D=corner.get_meta("merged_mesh")
  var span: Vector2i=corner.get_meta("merged_range")
  var mesh: ColorMesh=instance.get_meta("color_mesh")
  var ram:=BmpVehicle.new();game.world_root.add_child(ram);ram.setup(game,"8")
  var at:=corner.global_position+Vector3(0,0,BmpArt.HALF+0.3)
  at.y=district.ground_height(at)
  ram.global_transform=Transform3D(Basis.IDENTITY,at);ram.freeze=true
  await physics_frame;await physics_frame
  ram.linear_velocity=Vector3(0,0,-2.0);ram.ram_clock=0.0;ram.ram()
  check(corner.breaking and corner.collision_layer==0 and mesh.vertices[span.y-1]==mesh.vertices[span.x],"Rammed, the corner falls: no collider, gone from the heap's mesh")
  ram.queue_free()
 game.queue_free();await frames(5)
 print("PASS" if not failed else "FAILED"," checks=",checks)
 quit(1 if failed else 0)
