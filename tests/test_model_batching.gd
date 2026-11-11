extends SceneTree
func triangle_count(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			count+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
	for child in node.get_children():count+=triangle_count(child)
	return count
func _initialize():
	var model := Node3D.new()
	Models.bevel(model,Vector3.ZERO,Vector3.ONE,"gun_metal")
	Models.tube(model,Vector3.UP,0.2,1,"gun_metal")
	Models.profile(model,PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1)]),0.2,"gun_metal")
	var before := triangle_count(model)
	Models.merge_rigid(model)
	assert(triangle_count(model)==before,"Batching must preserve bevel, cylinder and profile triangles together")
	Models.merge_rigid(model)
	assert(triangle_count(model)==before,"Rebatching must preserve existing mesh materials and geometry")
	model.free()
	for id in ["ak74","m16","pm","m9"]:
		var weapon := Models.weapon(id)
		assert(weapon.get_node("Magazine").get_child_count()>0,"Separate reload magazine")
		assert(weapon.get_node("Bolt").get_child_count()>0,"Separate bolt/slide")
		assert(weapon.get_node("RearSight").position.y==weapon.get_node("FrontSight").position.y,"Physical sight heights align")
		assert(weapon.get_node_or_null("LeftForearm")!=null,"Batching must preserve animated hands/forearms")
		weapon.free()
	print("PASS: 18 batching, moving-part and sight checks")
	quit()
