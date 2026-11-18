class_name NavigationObstacles
extends RefCounted

const TILE_SIZE := 8.0
var shapes: Dictionary={}
var buckets: Dictionary={}
var bodies: Dictionary={}
var navigation_scale := 1.0

func tiles(bounds: AABB) -> Array[Vector2i]:
 var result: Array[Vector2i]=[]
 for z in range(floori((bounds.position.z-0.4)/TILE_SIZE),floori((bounds.end.z+0.4)/TILE_SIZE)+1):
  for x in range(floori((bounds.position.x-0.4)/TILE_SIZE),floori((bounds.end.x+0.4)/TILE_SIZE)+1):result.append(Vector2i(x,z))
 return result

func remove_body(id: int) -> void:
 for key in bodies.get(id,[]):
  for tile in shapes[key].tiles:
   buckets[tile].erase(key)
   if buckets[tile].is_empty():buckets.erase(tile)
  shapes.erase(key)
 bodies.erase(id)

func add_body(body: StaticBody3D) -> void:
 var id := body.get_instance_id()
 remove_body(id)
 if body.is_queued_for_deletion() or body.has_meta("boundary") or (body.collision_layer&1)==0:return
 var keys: Array[int]=[]
 for collision in body.get_children():
  if not collision is CollisionShape3D or collision.disabled:continue
  var local: AABB=AABB(-collision.shape.size/2,collision.shape.size) if collision.shape is BoxShape3D else collision.shape.get_debug_mesh().get_aabb()
  var bounds: AABB=collision.global_transform*local
  var key: int=collision.get_instance_id()
  var occupied := tiles(bounds)
  var low := Vector2i(floori((bounds.position.x-0.4)*navigation_scale),floori((bounds.position.z-0.4)*navigation_scale))
  var high := Vector2i(ceili((bounds.end.x+0.4)*navigation_scale),ceili((bounds.end.z+0.4)*navigation_scale))
  shapes[key]={"local":local,"bounds":bounds,"cells":Rect2i(low,high-low+Vector2i.ONE),"inverse":collision.global_transform.affine_inverse(),"tiles":occupied}
  keys.append(key)
  for tile in occupied:
   if not buckets.has(tile):buckets[tile]={}
   buckets[tile][key]=true
 bodies[id]=keys

func build(world: Node3D) -> void:
 shapes.clear();buckets.clear();bodies.clear()
 navigation_scale=world.navigation_scale
 for body in world.get_children():
  if body is StaticBody3D:add_body(body)

func near(bounds: AABB) -> Array[Dictionary]:
 var found: Dictionary={}
 for tile in tiles(bounds):
  for key in buckets.get(tile,{}):found[key]=true
 var result: Array[Dictionary]=[]
 for key in found:result.append(shapes[key])
 return result

static func blocks(record: Dictionary, point: Vector3, cell: Vector2i) -> bool:
 if not Rect2i(record.cells).has_point(cell):return false
 var bounds: AABB=record.bounds
 if bounds.end.y<point.y+0.22 or bounds.position.y>point.y+1.8:return false
 var local: Vector3=record.inverse*Vector3(point.x,clampf(point.y+0.8,bounds.position.y,bounds.end.y),point.z)
 var box: AABB=record.local
 return local.x>=box.position.x-0.37 and local.x<=box.end.x+0.37 and local.z>=box.position.z-0.37 and local.z<=box.end.z+0.37
