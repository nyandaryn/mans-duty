extends SceneTree
func assign_owner(node: Node, owner: Node):
	for child in node.get_children():
		child.owner=owner
		assign_owner(child,owner)
func _initialize():call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute("res://assets/models")
	for id in ["ak74","m16","svd","pm","m9"]:
		if not OS.get_cmdline_user_args().is_empty() and id not in OS.get_cmdline_user_args():continue
		# Force rebuild from the original authored geometry rather than baked assets.
		var model: Node3D=Models.weapon(id,true)
		root.add_child(model)
		for part in ["LeftHand","RightHand","LeftForearm","RightForearm"]:model.get_node(part).free()
		model.flash_node.free()
		model.set_script(null)
		model.name=id
		assign_owner(model,model)
		var packed := PackedScene.new()
		assert(packed.pack(model)==OK)
		var filename: String= "ak74m" if id=="ak74" else id
		assert(ResourceSaver.save(packed,"res://assets/models/"+filename+".scn")==OK)
		print("BAKED ",filename)
		model.free()
	quit()
