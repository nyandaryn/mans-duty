extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  failed=true
  printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 for id in Campaign.IDS:
  var world := District.new()
  root.add_child(world)
  var start := Time.get_ticks_msec()
  world.build(id)
  for i in range(2):await physics_frame
  check(world.map_id==id,id+" distinct mission identity")
  check(world.terrain!=null and world.grid_limit==199,id+" 400 metre terrain and navigation")
  check(world.spawn_points.size()==int(world.campaign_definition.defender_count),id+" defender positions")
  var connected := 0
  for point in world.spawn_points:
   if world.path(world.player_spawn,point).size()>1:connected+=1
   else:print("UNREACHABLE ",id," point=",point," cell=",world.nearest_cell(Vector2i(roundi(point.x),roundi(point.z))))
  check(connected==world.spawn_points.size(),id+" every defender reachable")
  var rooms := 0
  for point in world.interior_points:
   if world.path(world.player_spawn,point).size()>1:rooms+=1
  check(rooms==world.interior_points.size(),id+" house interiors reachable")
  if id.begins_with("forest"):
   check(world.canopy_centers.size()>100,id+" tree belts present")
   check(world.concealment_patches.size()<world.canopy_centers.size(),id+" undergrowth limited to belts")
  else:check(world.interior_points.size()>=6,id+" inhabited buildings with actual entrances")
  print(id," build_ms=",Time.get_ticks_msec()-start," trees=",world.canopy_centers.size()," buildings=",world.interior_points.size()," reachable=",connected,"/",world.spawn_points.size()," rooms=",rooms)
  world.free()
 print("FAIL: " if failed else "PASS: ",checks," full campaign map construction and route checks")
 quit(1 if failed else 0)
