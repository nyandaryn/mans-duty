class_name Penetration
extends RefCounted

# Tuned game materials, not certified ammunition/armour performance data.
# Resistance is energy lost per metre of solid material; entry is surface work.
const MATERIALS = {
	"wood":{"resistance":2600.0,"entry":24.0,"fracture":850.0,"density":600.0},
	"glass":{"resistance":4500.0,"entry":12.0,"fracture":90.0,"density":2400.0},
	"steel":{"resistance":260000.0,"entry":100.0,"fracture":14000.0,"density":7800.0},
	"concrete":{"resistance":36000.0,"entry":120.0,"fracture":6500.0,"density":2400.0},
	"brick":{"resistance":15000.0,"entry":70.0,"fracture":2600.0,"density":1700.0},
	"earth":{"resistance":11000.0,"entry":35.0,"fracture":1900.0,"density":1500.0},
	"fabric":{"resistance":750.0,"entry":8.0,"fracture":350.0,"density":140.0},
	"rubber":{"resistance":8000.0,"entry":40.0,"fracture":2200.0,"density":1100.0}
}
const MASS = {"ak74":0.0034,"m16":0.0040,"svd":0.0096,"pm":0.0061,"m9":0.0080}

static func energy(weapon: String, speed: float) -> float:
	return 0.5*float(MASS[weapon])*speed*speed

static func remaining(weapon: String, speed: float, material: String, thickness: float) -> float:
	var data: Dictionary=MATERIALS.get(material,MATERIALS.concrete)
	return maxf(0,energy(weapon,speed)-float(data.entry)-maxf(thickness,0)*float(data.resistance))

# Returns the actual first exit of the hit shape, in world space. This includes
# the taper of triangle meshes and the extra path length of oblique hits.
static func exit_point(body: CollisionObject3D, shape_index: int, entry: Vector3, direction: Vector3) -> Variant:
	var owner: Object=body.shape_owner_get_owner(body.shape_find_owner(shape_index))
	if not owner is CollisionShape3D:return null
	var node: CollisionShape3D=owner
	var inverse := node.global_transform.affine_inverse()
	var start := inverse*entry
	var vector := inverse.basis*direction.normalized()
	if node.shape is BoxShape3D:
		var half: Vector3=node.shape.size*0.5
		var distance := INF
		for axis in range(3):
			if absf(vector[axis])<0.000001:continue
			var boundary: float=half[axis] if vector[axis]>0 else -half[axis]
			var t: float=(boundary-start[axis])/vector[axis]
			if t>0.00001:distance=minf(distance,t)
		if is_finite(distance):return entry+direction.normalized()*distance
		return null
	var faces := PackedVector3Array()
	if node.shape is ConcavePolygonShape3D:faces=node.shape.get_faces()
	else:
		# The debug mesh is the shape's surface, never its enclosing AABB.
		var mesh: ArrayMesh=node.shape.get_debug_mesh()
		if mesh!=null:faces=mesh.get_faces()
	var best := INF
	for i in range(0,faces.size(),3):
		var point: Variant=Geometry3D.segment_intersects_triangle(start+vector*0.0001,start+vector*500,faces[i],faces[i+1],faces[i+2])
		if point==null:continue
		var world: Vector3=node.global_transform*point
		var distance := (world-entry).dot(direction.normalized())
		if distance>0.0001 and distance<best:best=distance
	return entry+direction.normalized()*best if is_finite(best) else null
