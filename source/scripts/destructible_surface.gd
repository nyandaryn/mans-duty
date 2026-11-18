class_name DestructibleSurface
extends StaticBody3D

var district: Node3D
var batch: MultiMesh
var batch_index := -1
var tint := Color.GRAY
var damage_cells: Dictionary = {}
var breaking := false

func strike(point: Vector3, direction: Vector3, deposited: float, perforated: bool) -> void:
	# Armour hulks and filled sandbags absorb rifle fire without breaking up.
	if breaking or not is_instance_valid(district) or has_meta("indestructible"):return
	var material: String=get_meta("ballistic_material","concrete")
	var local := to_local(point-direction*0.001)
	var cell := Vector3i(floori(local.x/0.18),floori(local.y/0.18),floori(local.z/0.18))
	# Energy transmitted through a board still splits fibres along the hole.
	var work := deposited+(180.0 if perforated and material=="wood" else 0.0)
	damage_cells[cell]=float(damage_cells.get(cell,0.0))+work
	if float(damage_cells[cell])<float(Penetration.MATERIALS[material].fracture):return
	damage_cells[cell]=0.0
	if district.fracture_count>=1200:return
	var shape_node: CollisionShape3D=get_child(0)
	if not shape_node.shape is BoxShape3D:
		# Exact mesh subtraction is deferred, outside the physics query loop.
		breaking=true
		cut_mesh.call_deferred(local,direction,material)
		return
	breaking=true
	fracture_box.call_deferred(local,direction,material)

func fracture_box(point: Vector3, direction: Vector3, material: String) -> void:
	if not is_instance_valid(district):return
	var shape_node: CollisionShape3D=get_child(0)
	var size: Vector3=shape_node.shape.size
	var bounds := AABB(-size/2,size)
	var radius := 0.085 if material in ["wood","glass","fabric"] else 0.055
	var hole := AABB(point-Vector3.ONE*radius,Vector3.ONE*radius*2).intersection(bounds)
	# Thin boards lose a short section, not an entire bench. Thick masonry loses
	# a shallow crater; repeated hits must excavate the remaining material.
	for axis in range(3):
		if size[axis]<radius*2.2:
			hole.position[axis]=-size[axis]/2
			hole.size[axis]=size[axis]
	if hole.get_volume()<0.000001:
		breaking=false
		return
	var remainder := bounds
	var replacements: Array[StaticBody3D]=[]
	for axis in range(3):
		for upper in [false,true]:
			var part := remainder
			if upper:
				part.position[axis]=hole.end[axis]
				part.size[axis]=remainder.end[axis]-hole.end[axis]
				remainder.size[axis]=hole.end[axis]-remainder.position[axis]
			else:
				part.size[axis]=hole.position[axis]-remainder.position[axis]
				remainder.size[axis]-=part.size[axis]
				remainder.position[axis]=hole.position[axis]
			if part.size[axis]>0.002:
				replacements.append(district.surface_piece(global_transform*part.get_center(),part.size,tint,material,global_basis))
	district.fragment(global_transform*hole.get_center(),hole.size,tint,material,direction,global_basis)
	district.fracture_count+=1
	if batch!=null and batch_index>=0:batch.set_instance_transform(batch_index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	collision_layer=0
	collision_mask=0
	district.refresh_navigation(global_transform*bounds,get_instance_id(),replacements)
	queue_free()

func cut_mesh(point: Vector3, direction: Vector3, material: String) -> void:
	var visual: MeshInstance3D=get_node_or_null("SurfaceMesh")
	if visual==null:
		breaking=false
		return
	var csg := CSGCombiner3D.new()
	add_child(csg)
	var source := CSGMesh3D.new()
	source.mesh=visual.mesh
	csg.add_child(source)
	var cutter := CSGBox3D.new()
	cutter.operation=CSGShape3D.OPERATION_SUBTRACTION
	cutter.size=Vector3.ONE*0.14
	cutter.position=point
	cutter.material=visual.material_override
	csg.add_child(cutter)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(district):return
	var generated := csg.get_meshes()
	if generated.size()==2:
		var mesh: ArrayMesh=generated[1]
		if mesh.get_surface_count()>0:
			var changed_bounds: AABB=visual.global_transform*visual.mesh.get_aabb()
			visual.mesh=mesh
			var shape: CollisionShape3D=get_child(0)
			shape.shape=mesh.create_trimesh_shape()
			district.fragment(to_global(point),Vector3.ONE*0.06,tint,material,direction,global_basis)
			district.fracture_count+=1
			district.refresh_navigation(changed_bounds.merge(visual.global_transform*mesh.get_aabb()),get_instance_id(),[self])
			for child in get_children():
				if child is MeshInstance3D and child!=visual:child.queue_free()
	csg.queue_free()
	breaking=false
