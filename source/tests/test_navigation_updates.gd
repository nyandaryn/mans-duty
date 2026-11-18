extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame
func grid_snapshot(world: District) -> PackedByteArray:
 var snapshot := PackedByteArray()
 snapshot.resize(world.grid.region.size.x*world.grid.region.size.y)
 var index := 0
 for y in range(world.grid.region.position.y,world.grid.region.end.y):
  for x in range(world.grid.region.position.x,world.grid.region.end.x):
   snapshot[index]=1 if world.grid.is_point_solid(Vector2i(x,y)) else 0
   index+=1
 return snapshot
func run():
 var grid := AStarGrid2D.new()
 grid.region=Rect2i(-10,-10,21,21);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
 for y in range(-10,11):grid.set_point_solid(Vector2i(0,y))
 var regions := NavigationRegions.new();regions.build(grid)
 check(not regions.connected(Vector2i(-4,0),Vector2i(4,0)),"Disconnected regions reject impossible routes")
 grid.set_point_solid(Vector2i(0,0),false);regions.open_cell(Vector2i(0,0))
 check(regions.connected(Vector2i(-4,0),Vector2i(4,0)),"Opening a gap joins regions incrementally")
 grid.set_point_solid(Vector2i(0,0));regions.build(grid)
 check(not regions.connected(Vector2i(-4,0),Vector2i(4,0)),"A full rebuild handles newly closed passages")
 grid.fill_solid_region(grid.region,true)
 grid.set_point_solid(Vector2i(0,0),false);grid.set_point_solid(Vector2i(1,1),false)
 regions.build(grid)
 check(not regions.connected(Vector2i(0,0),Vector2i(1,1)),"Diagonal corner contact cannot bypass solid walls")
 var world := District.new();root.add_child(world);world.build("village_01")
 await frames(2)
 var start := Vector3(160,0,120);start.y=world.ground_height(start)
 var walls: Array[StaticBody3D]=[]
 for sign_x in [-1,1]:walls.append(world.surface_piece(start+Vector3(sign_x*4,1.2,0),Vector3(0.2,3,8.2),Color.GRAY,"wood"))
 for sign_z in [-1,1]:walls.append(world.surface_piece(start+Vector3(0,1.2,sign_z*4),Vector3(8.2,3,0.2),Color.GRAY,"wood"))
 world.rebuild_campaign_grid()
 var outside := start+Vector3(7,0,0)
 var rejected := world.navigation_rejected_paths
 var before := Time.get_ticks_usec()
 var all_rejected := true
 for i in range(1000):all_rejected=world.path(start,outside).is_empty() and all_rejected
 var elapsed := float(Time.get_ticks_usec()-before)/1000
 check(all_rejected,"Sealed enclosure has no route")
 check(world.navigation_rejected_paths-rejected==1000,"All unreachable searches stop before A*")
 check(elapsed<100,"One thousand unreachable probes stay below 100 ms")
 print("UNREACHABLE_1000_MS ",elapsed)
 var gate: StaticBody3D=walls[1]
 var collision: CollisionShape3D=gate.get_child(0)
 var bounds: AABB=collision.global_transform*AABB(-collision.shape.size/2,collision.shape.size)
 var full := world.navigation_full_rebuilds
 var local := world.navigation_local_updates
 world.refresh_navigation(bounds,gate.get_instance_id(),[]);gate.queue_free()
 await process_frame
 await process_frame
 await frames(3)
 check(world.navigation_full_rebuilds==full and world.navigation_local_updates==local+1,"Opening wall updates only the dirty patch")
 check(world.navigation_last_cells<500,"Wall opening touches hundreds of cells, not the entire village")
 check(world.path(start,outside).size()>1,"Bots can use newly opened passage")
 var local_snapshot := grid_snapshot(world)
 world.rebuild_campaign_grid()
 check(local_snapshot==grid_snapshot(world),"Local obstacle raster exactly matches a full rebuild")
 var boards: Array[StaticBody3D]=[]
 for i in range(3):boards.append(world.surface_piece(start+Vector3(i-1,1,1.0),Vector3(0.7,1.2,0.04),Color.BROWN,"wood",Basis(Vector3.UP,0.4)))
 world.rebuild_campaign_grid()
 full=world.navigation_full_rebuilds;local=world.navigation_local_updates
 var sample := world.navigation_cell(start+Vector3(10,0,5))
 var weight := world.grid.get_point_weight_scale(sample)
 for board in boards:board.strike(board.global_position,Vector3.FORWARD,1000,true)
 await frames(5)
 check(world.fracture_count==3,"Real impacts break all three boards")
 check(world.navigation_full_rebuilds==full,"Gunfire does not rebuild whole campaign grid")
 check(world.navigation_local_updates==local+1,"Same-frame fractures coalesce into one update")
 check(world.navigation_last_cells<200,"Tiny fractures update a bounded number of cells")
 check(is_equal_approx(world.grid.get_point_weight_scale(sample),weight),"Local updates preserve terrain traversal costs")
 local_snapshot=grid_snapshot(world)
 world.rebuild_campaign_grid()
 check(local_snapshot==grid_snapshot(world),"Rotated fracture chunks preserve exact navigation raster")
 check(is_equal_approx(world.grid.get_point_weight_scale(sample),weight),"Full rebuild also preserves terrain costs")
 world.queue_free();await frames(3)
 print("FAIL: " if failed else "PASS: ",checks," connectivity, local destruction, coalescing and route correctness checks")
 quit(1 if failed else 0)
