class_name District
extends Node3D

var navigation_scale := 1.0
var navigation_base := PackedByteArray()
var navigation_weights := PackedFloat32Array()
var navigation_regions := NavigationRegions.new()
var navigation_obstacles := NavigationObstacles.new()
var navigation_dirty: Array[Rect2i]=[]
var navigation_full_pending := false
var navigation_full_rebuilds := 0
var navigation_local_updates := 0
var navigation_last_cells := 0
var navigation_rejected_paths := 0
var terrain: CampaignTerrain
var campaign_definition: Dictionary = {}
# Real ground around the battlefield (BattleMap on the Avdiivka data).
var operation_area: OperationArea
var foliage_cells: Dictionary = {}
# 4 m cells whose 3x3 neighbourhood holds foliage, and canopies by 8 m cell.
# Rebuilt lazily when the world adds foliage or trees; queries skip open ground.
var foliage_near: Dictionary = {}
var foliage_count := 0
var foliage_indexed := -1
var canopy_cells: Dictionary = {}
var canopy_indexed := -1
var foliage_alpha: Image
var fracture_count := 0
var fragments: Array[RigidBody3D] = []
var navigation_pending := false
var grid_limit := 47
var canopy_centers: Array[Vector3] = []
# Street lamp posts: thin rods with no collider, kept so a vehicle never
# parks with one standing through its hull.
var posts: Array[Vector3] = []
# Extra outlines for the 1:10 000 sheet (the training range draws its works).
var map_marks: Array[PackedVector2Array] = []
var map_id := "city"
var map_title := "МІСТО / КВАРТАЛ"
var interior_points: Array[Vector3] = []
var entrances: Array[Vector3] = []
var concealment_patches: Array[Vector3] = []
var player_spawn := Vector3(28,0.2,43)
var player_spawn_yaw := PI/2
var batches: Dictionary = {}
# Side of the square that groups static boxes and details into one batch.
# Large open maps use wider cells: fewer draw calls, coarser culling.
var batch_cell := 24.0
var obstacles: Array[Rect2] = []
var grid := AStarGrid2D.new()
var spawn_points: Array[Vector3] = [Vector3(-8, 0.1, 14), Vector3(8, 0.1, 4), Vector3(-11, 0.1, -12), Vector3(9, 0.1, -30), Vector3(25, 0.1, 14), Vector3(-24, 0.1, -11), Vector3(40, 0.1, 9), Vector3(-40, 0.1, -7), Vector3(0, 0.1, -40), Vector3(38, 0.1, -38)]

var detail_batches: Dictionary = {}
var merged: Dictionary = {}
var environment_materials: Dictionary = {}
var random := RandomNumberGenerator.new()
var instance_total := 0

func material(color: Color, kind: String="plaster") -> StandardMaterial3D:
	var key := color.to_html()+kind
	if environment_materials.has(key):return environment_materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=0.92
	if kind=="glass":
		mat.roughness=0.24
		mat.metallic=0.35
	elif kind!="leaf":
		var noise := FastNoiseLite.new()
		noise.seed=31
		noise.frequency=0.26
		var texture := NoiseTexture2D.new()
		texture.width=128
		texture.height=128
		texture.seamless=true
		texture.noise=noise
		var ramp := Gradient.new()
		ramp.set_color(0,Color(0.73,0.73,0.73))
		ramp.set_color(1,Color(1,1,1))
		texture.color_ramp=ramp
		mat.albedo_texture=texture
		mat.uv1_triplanar=true
		mat.uv1_world_triplanar=true
		mat.uv1_scale=Vector3.ONE*(1.25 if kind=="plaster" else 1.5)
	environment_materials[key]=mat
	return mat

func collider(pos: Vector3, size: Vector3, substance: String="concrete") -> StaticBody3D:
	var body := DestructibleSurface.new()
	body.district=self
	body.set_meta("ballistic_material",substance)
	body.position=pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)
	add_child(body)
	if pos.y+size.y/2>0.5 and pos.y-size.y/2<1.9:obstacles.append(Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z)))

	return body

func cell_key(pos: Vector3) -> String:
	return str(floori(pos.x/batch_cell))+":"+str(floori(pos.z/batch_cell))

func detail(shape: String, pos: Vector3, size: Vector3, color: String, rotation: Vector3=Vector3.ZERO) -> void:
	if shape=="foliage":
		var cell := Vector2i(floori(pos.x/4),floori(pos.z/4))
		if not foliage_cells.has(cell):foliage_cells[cell]=[]
		foliage_cells[cell].append(Transform3D(Basis.from_euler(rotation).scaled_local(size),pos).affine_inverse())
		foliage_count+=1
	var key := shape+"|"+color+"|"+cell_key(pos)
	if not detail_batches.has(key):detail_batches[key]={"shape":shape,"color":color,"transforms":[]}
	detail_batches[key].transforms.append(Transform3D(Basis.from_euler(rotation).scaled_local(size),pos))
	instance_total+=1

func rod(a: Vector3, b: Vector3, radius: float, color: String) -> void:
	var rotation := Quaternion(Vector3.UP,a.direction_to(b)).get_euler()
	detail("cylinder",(a+b)/2,Vector3(radius,a.distance_to(b),radius),color,rotation)

func bake_model(root: Node3D) -> void:
	for child in root.find_children("*","MeshInstance3D",true,false):
		var node := child as MeshInstance3D
		var mat: Material=node.material_override
		if mat==null:mat=node.mesh.surface_get_material(0)
		var key := str(mat.get_instance_id())+":"+cell_key(root.position)
		if not merged.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			merged[key]={"tool":tool,"material":mat}
		var tool: SurfaceTool=merged[key].tool
		var transform := root.transform*node.transform
		var ancestor := node.get_parent()
		while ancestor!=root:
			transform=root.transform*ancestor.transform*root.transform.affine_inverse()*transform
			ancestor=ancestor.get_parent()
		var normal_matrix := transform.basis.inverse().transposed()
		for surface_index in range(node.mesh.get_surface_count()):
			var arrays := node.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for i in range(count):
				var index := indices[i] if not indices.is_empty() else i
				tool.set_normal((normal_matrix*normals[index]).normalized())
				tool.set_uv(Vector2.ZERO)
				tool.add_vertex(transform*vertices[index])
	root.free()

func flush_details() -> void:
	for key in detail_batches:
		var batch: Dictionary=detail_batches[key]
		var mesh: PrimitiveMesh
		if batch.shape=="foliage":
			var quad := QuadMesh.new()
			quad.size=Vector2.ONE
			mesh=quad
		elif batch.shape=="sphere":
			var sphere := SphereMesh.new()
			sphere.radius=1
			sphere.height=2
			sphere.radial_segments=12
			sphere.rings=6
			mesh=sphere
		elif batch.shape=="drum":
			# Straight cylinder (wheels, drums, discs); "cylinder" tapers like a trunk.
			var drum := CylinderMesh.new()
			drum.top_radius=1
			drum.bottom_radius=1
			drum.height=1
			drum.radial_segments=14
			drum.rings=1
			mesh=drum
		elif batch.shape=="prism":
			# Gable roof: ridge along the local Z axis.
			var prism := PrismMesh.new()
			prism.size=Vector3.ONE
			mesh=prism
		elif batch.shape=="cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius=0.8
			cylinder.bottom_radius=1
			cylinder.height=1
			cylinder.radial_segments=12
			cylinder.rings=1
			mesh=cylinder
		else:mesh=BoxMesh.new()
		if batch.shape=="foliage":
			var foliage := StandardMaterial3D.new()
			foliage.albedo_texture=load("res://assets/textures/foliage.png")
			foliage.albedo_color=Color(batch.color)
			foliage.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			foliage.alpha_scissor_threshold=0.5
			foliage.cull_mode=BaseMaterial3D.CULL_DISABLED
			foliage.roughness=1.0
			mesh.material=foliage
		else:mesh.material=material(Color(batch.color),"leaf" if batch.shape=="sphere" else "plaster")
		var multi := MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=mesh
		multi.instance_count=batch.transforms.size()
		for i in range(multi.instance_count):multi.set_instance_transform(i,batch.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh=multi
		add_child(instance)
	for key in merged:
		var tool: SurfaceTool=merged[key].tool
		tool.index()
		var instance := MeshInstance3D.new()
		instance.mesh=tool.commit()
		instance.material_override=merged[key].material
		add_child(instance)
	detail_batches.clear()
	merged.clear()

func box(pos: Vector3, size: Vector3, color: Color, solid: bool = false, substance: String="concrete") -> void:
	var key := color.to_html()+"|"+cell_key(pos)
	if not batches.has(key):batches[key]={"color":color,"transforms":[],"shadow":false,"bodies":{}}
	batches[key].transforms.append(Transform3D(Basis.from_scale(size),pos))
	if minf(size.x,minf(size.y,size.z))>0.12 and pos.y>0.35:batches[key].shadow=true
	instance_total+=1
	if solid:
		var body := collider(pos,size,substance)
		body.set_meta("surface_color",color)
		body.tint=color
		batches[key].bodies[batches[key].transforms.size()-1]=body

func build(selected_map: String="city") -> void:
	if selected_map==BattleMap.ID:
		BattleMap.build(self)
		return
	if selected_map in Campaign.IDS:
		campaign_definition=Campaign.mission(selected_map)
		CampaignWorld.new().build(self,campaign_definition)
		return
	if selected_map==TrainingRange.ID:
		TrainingRange.build(self)
		flush()
		flush_details()
		build_grid()
		return
	map_id=selected_map if selected_map in ["city","shelterbelt"] else "city"
	random.seed=7003 if map_id=="city" else 23051
	if map_id=="shelterbelt":
		build_shelterbelt()
		flush()
		flush_details()
		build_grid()
		return
	box(Vector3(0,-0.3,0), Vector3(100,0.6,100), Color("69705a"), true,"earth")
	box(Vector3(0,0.015,0), Vector3(18,0.03,94), Color("383c3d"))
	for z in [-14.0,14.0]:
		box(Vector3(0,0.02,z), Vector3(94,0.04,8), Color("383c3d"))
	for z in range(-44,45,8):
		box(Vector3(0,0.043,z), Vector3(0.13,0.02,3), Color("b5b4a0"))
	for x in [-11.0,11.0]:
		box(Vector3(x,0.08,0), Vector3(3.2,0.16,94), Color("92958a"))
	for x in [-28.0,28.0]:
		for zi in range(3):
			building(Vector3(x,0, float(zi-1)*28), zi+int(x>0)*3+1)
	for x in [-48.0,48.0]:
		box(Vector3(x,1.2,0),Vector3(0.4,2.4,96),Color("92978e"),true)
		for z in range(-48,49,4):box(Vector3(x,1.3,z),Vector3(0.65,2.6,0.65),Color("777f77"))
	for z in [-48.0,48.0]:
		box(Vector3(0,1.2,z),Vector3(96,2.4,0.4),Color("92978e"),true)
		for x in range(-48,49,4):box(Vector3(x,1.3,z),Vector3(0.65,2.6,0.65),Color("777f77"))
	for data in [[-7,25,"787b61"],[7,-3,"6f8582"],[-7,-24,"965d48"],[22,14,"9a9d91"],[-24,-14,"586b79"],[39,25,"a49e83"]]:
		car(Vector3(data[0],0,data[1]),Color(data[2]))
	for z in [-38,-18,2,22,42]:
		for x in [-13,13]:
			rod(Vector3(x,0,z),Vector3(x,5.4,z),0.065,"59615e")
			posts.append(Vector3(x,0,z))
			rod(Vector3(x,5.2,z),Vector3(x+(-0.8 if x>0 else 0.8),5.5,z),0.04,"59615e")
			var lamp := Node3D.new()
			lamp.position=Vector3(x+(-0.75 if x>0 else 0.75),5.46,z)
			Models.bevel(lamp,Vector3.ZERO,Vector3(0.65,0.15,0.25),"6a716d",0.05)
			Models.bevel(lamp,Vector3(0,-0.08,0),Vector3(0.52,0.015,0.18),"d2d0b1",0.005)
			bake_model(lamp)
	for x in [-41,41]:
		for z in [-33,-20,0,20,36]:
			tree(Vector3(x,0,z))
	for x in [-16,16]:
		for z in [-40,-9,20,40]: tree(Vector3(x,0,z))
	# Sheltered rear courtyard behind the south-east apartment building.
	# Two routes lead around the building; neither starts in the street's fire lane.
	box(Vector3(28,0.035,42.5),Vector3(17,0.07,8.5),Color("858b82"))
	for x in [21,35]:
		box(Vector3(x,0.48,42),Vector3(1.8,0.96,0.8),Color("687469"),true)
		box(Vector3(x,0.99,42),Vector3(1.85,0.08,0.85),Color("444f48"))
	street_details()
	war_damage()
	for z in [-40,40]:
		for x in [-14,14]:bench(Vector3(x,0,z))
	for x in [-7,7]:concrete_barrier(Vector3(x,0,38))
	flush()
	flush_details()
	build_grid()

func concrete_barrier(pos: Vector3) -> void:
	var barrier := Node3D.new()
	barrier.position=pos
	var outline := PackedVector2Array([Vector2(-0.45,0),Vector2(-0.45,0.20),Vector2(-0.19,0.65),Vector2(-0.15,1.1),Vector2(0.15,1.1),Vector2(0.19,0.65),Vector2(0.45,0.20),Vector2(0.45,0)])
	var surface := Models.profile(barrier,outline,3,"9b9c8e")
	# Normalize the prism's winding before boolean cuts (rendering was two-sided).
	var faces: PackedVector3Array=surface.mesh.get_faces()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,faces.size(),3):
		var a := faces[i]
		var b := faces[i+1]
		var c := faces[i+2]
		if (c-a).cross(b-a).dot((a+b+c)/3-Vector3(0,0.45,0))<0:
			var swap := b
			b=c
			c=swap
		for point in [a,b,c]:tool.add_vertex(point)
	tool.generate_normals()
	tool.index()
	surface.mesh=tool.commit()
	# Use the exact static mesh: a bounding box (or a single convex hull) fills
	# the empty air around this tapered, concave cross-section.
	var body := DestructibleSurface.new()
	body.district=self
	body.tint=Color("9b9c8e")
	body.set_meta("ballistic_material","concrete")
	body.name="ConcreteBarrier"
	body.position=pos
	var collision := CollisionShape3D.new()
	collision.shape=surface.mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)
	obstacles.append(Rect2(Vector2(pos.x-1.5,pos.z-0.45),Vector2(3,0.9)))
	barrier.remove_child(surface)
	surface.name="SurfaceMesh"
	body.add_child(surface)
	barrier.free()

func facade_box(base: Vector3, u: Vector3, n: Vector3, local: Vector3, size: Vector3, color: String) -> void:
	var dimensions := Vector3(size.x if absf(n.z)>0.5 else size.z,size.y,size.z if absf(n.z)>0.5 else size.x)
	box(base+u*local.x+Vector3.UP*local.y+n*local.z,dimensions,Color(color))

func wall_section(pos: Vector3, normal: Vector3, offset: float, width: float, bottom: float, top: float, color: String) -> void:
	if top<=bottom or width<=0:return
	var u := Vector3(normal.z,0,-normal.x)
	var size := Vector3(width,top-bottom,0.32) if absf(normal.z)>0.5 else Vector3(0.32,top-bottom,width)
	box(pos+u*offset+Vector3.UP*((bottom+top)/2),size,Color(color),true,"brick")

func building(pos: Vector3, number: int) -> void:
	# A shell built from actual wall sections and slabs, not a solid building-sized box.
	var colors := ["a4a091","979f98","aaa18d"]
	var plaster: String=colors[number%3]
	var floors := 3 if number in [2,5] else 5
	var height := floors*2.8
	box(pos+Vector3(0,-0.025,0),Vector3(18,0.05,18),Color("77736a"),true)
	for floor_index in range(1,floors+1):
		box(pos+Vector3(0,floor_index*2.8,0),Vector3(18.3,0.18,18.3),Color("777c75"),true)
	for normal in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
		var u := Vector3(normal.z,0,-normal.x)
		var base: Vector3=pos+normal*9
		for f in range(floors):
			for column in range(6):
				var x := -7.5+column*3
				var door := f==0 and column in [2,3] and absf(normal.x)>0.5
				if door:
					# Two adjacent modules form a generous 3 m opening with side jambs.
					wall_section(base,normal,x+(-0.75 if column==2 else 0.75),1.5,0,2.8,plaster)
					wall_section(base,normal,x+(0.75 if column==2 else -0.75),1.5,2.35,2.8,plaster)
					continue
				var broken := (column+f*3+number)%5==0
				var bottom := f*2.8
				wall_section(base,normal,x-1.23,0.54,bottom,bottom+2.8,plaster)
				wall_section(base,normal,x+1.23,0.54,bottom,bottom+2.8,plaster)
				wall_section(base,normal,x,1.92,bottom,bottom+(0.65 if broken else 0.95),plaster)
				wall_section(base,normal,x,1.92,bottom+2.25,bottom+2.8,"5c6059" if broken else plaster)
				# Empty frames let light, bullets and the view pass through.
				for dx in [-0.95,0.95]:facade_box(base,u,normal,Vector3(x+dx,bottom+1.60,0),Vector3(0.055,1.3,0.12),"848780")
				facade_box(base,u,normal,Vector3(x,bottom+0.94,0.04),Vector3(2.05,0.07,0.32),"a4a396")
				if not broken:facade_box(base,u,normal,Vector3(x,bottom+1.62,0),Vector3(0.04,1.28,0.06),"747c76")
				if (column+number+f)%4==0:
					facade_box(base,u,normal,Vector3(x-0.58,bottom+0.40,0.17),Vector3(0.74,0.58,0.025),"6f7063")
				if broken:
					facade_box(base,u,normal,Vector3(x,bottom+2.50,0.17),Vector3(1.8,0.45,0.025),"454942")
					for chip in range(4):
						facade_box(base,u,normal,Vector3(x+random.randf_range(-1,1),bottom+random.randf_range(0.2,0.7),0.18),Vector3(0.22,0.09,0.025),"8e6650")
		rod(base+u*8.6+normal*0.23,base+u*8.6+normal*0.23+Vector3.UP*(height-1),0.045,"5e665f")
		if absf(normal.x)>0.5:
			entrances.append(base)
			box(base+normal*1.1+Vector3.UP*2.55,Vector3(2.4,0.12,3.8),Color("61685f"),true)
			var sign := Label3D.new()
			sign.text="КВАРТАЛЬНА, %02d" % number
			sign.font_size=32
			sign.pixel_size=0.004
			sign.position=base+normal*0.19+Vector3.UP*2.63
			sign.rotation.y=PI/2 if normal.x>0 else -PI/2
			add_child(sign)
	# Cross-building corridor and four furnished apartments, all on the ground floor.
	for z in [-2.0,2.0]:
		for x in [-7.5,0.0,7.5]:
			box(pos+Vector3(x,1.35,z),Vector3(3 if x!=0 else 6,2.7,0.20),Color("7b8c81"),true)
		for x in [-4.5,4.5]:box(pos+Vector3(x,2.5,z),Vector3(3,0.4,0.20),Color("b1b1a0"),true)
		box(pos+Vector3(0,0.55,z),Vector3(6,1.1,0.23),Color("657b70"))
	for z in [-5.5,5.5]:
		box(pos+Vector3(0,1.35,z),Vector3(0.20,2.7,7),Color("aea997"),true)
		for x in [-4.5,4.5]:
			var room := pos+Vector3(x,0,z)
			interior_points.append(room)
			furnish(room,number+int(x>0)+int(z>0)*2)
	# Interior partition silhouettes upstairs, with solid floor slabs between levels.
	for f in range(1,floors):
		box(pos+Vector3(0,f*2.8+1.35,0),Vector3(0.18,2.7,18),Color("8a8d80"),true)
		for z in [-3,3]:box(pos+Vector3(0,f*2.8+1.35,z),Vector3(18,2.7,0.18),Color("8e9284"),true)
	# Service stairwell is blocked by collapsed masonry; upper storeys are not playable yet.
	box(pos+Vector3(7.7,0.45,7.8),Vector3(1.7,0.9,1.5),Color("65695e"),true)
	for i in range(8):detail("box",pos+Vector3(random.randf_range(6.7,8.6),random.randf_range(0.3,1),random.randf_range(7,8.5)),Vector3(0.5,0.2,0.4),"8e826f",Vector3(random.randf(),random.randf(),0))
	box(pos+Vector3(2,height+0.6,3),Vector3(2,1.2,2),Color("777c70"),true)

func furnish(pos: Vector3, variant: int) -> void:
	# Solid furniture stays along room edges, clear of the wide doors and firing lanes.
	var wood := Color("746450")
	box(pos+Vector3(-1.9,0.38,1.1),Vector3(1.6,0.76,2.5),Color("575e50"),true,"fabric")
	box(pos+Vector3(-1.9,0.81,1.1),Vector3(1.55,0.10,2.35),Color("8d927d"))
	box(pos+Vector3(-1.9,0.92,1.8),Vector3(1.1,0.15,0.45),Color("b1b0a1"))
	box(pos+Vector3(2.7,1.0,1.8),Vector3(0.8,2.0,1.6),wood,true,"wood")
	for z in [1.4,2.2]:box(pos+Vector3(2.28,1,z),Vector3(0.04,1.8,0.7),Color("8b795f"))
	box(pos+Vector3(1.6,0.78,-1.6),Vector3(1.6,0.12,0.85),wood,true,"wood")
	for x in [1,2.2]:
		for z in [-1.9,-1.3]:box(pos+Vector3(x,0.37,z),Vector3(0.08,0.74,0.08),wood,true,"wood")
	box(pos+Vector3(1.6,0.88,-1.6),Vector3(0.35,0.04,0.25),Color("c6bfa6"))
	if variant%2==0:
		box(pos+Vector3(2.6,0.45,-2.7),Vector3(1.0,0.9,0.6),Color("9d9f8c"),true)
		box(pos+Vector3(2.6,0.93,-2.7),Vector3(1.05,0.06,0.65),Color("535d58"))
	# Skirting, ceiling light, radiator and visible floorboards add scale indoors.
	for z in range(-3,4):box(pos+Vector3(0,0.054,z),Vector3(8.5,0.012,0.025),Color("5e6057"))
	box(pos+Vector3(0,2.58,0),Vector3(0.7,0.08,0.3),Color("b3b09b"))
	for i in range(8):box(pos+Vector3(-0.7+i*0.18,0.45,3.15),Vector3(0.11,0.65,0.13),Color("a3a593"))

func car(pos: Vector3, color: Color, yaw: float=0.0, burnt: bool=false) -> void:
	var root := Node3D.new()
	root.position=pos
	root.rotation.y=yaw
	var paint := color.to_html(false)
	var body := Models.profile(root,PackedVector2Array([Vector2(-2.03,0.4),Vector2(-2.03,0.78),Vector2(-1.7,0.92),Vector2(-0.8,0.96),Vector2(1.15,0.93),Vector2(2.03,0.83),Vector2(2.03,0.40),Vector2(1.68,0.40),Vector2(1.63,0.57),Vector2(1.49,0.70),Vector2(1.29,0.75),Vector2(1.09,0.70),Vector2(0.95,0.57),Vector2(0.90,0.40),Vector2(-0.88,0.40),Vector2(-0.93,0.57),Vector2(-1.07,0.70),Vector2(-1.27,0.75),Vector2(-1.47,0.70),Vector2(-1.61,0.57),Vector2(-1.66,0.40)]),1.82,paint)
	body.material_override.metallic=0.28
	body.material_override.roughness=0.38
	# A burnt-out car has lost its glazing: only a sooted cabin remains.
	Models.profile(root,PackedVector2Array([Vector2(-0.91,0.97),Vector2(-0.46,1.49),Vector2(0.70,1.49),Vector2(1.22,0.96)]),1.61,"1e1c1a" if burnt else "344a53")
	Models.bevel(root,Vector3(0,1.51,0.10),Vector3(1.68,0.07,1.28),paint,0.035)
	Models.bevel(root,Vector3(0,0.94,-1.42),Vector3(1.78,0.04,1.13),paint,0.02)
	Models.bevel(root,Vector3(0,0.91,1.60),Vector3(1.78,0.04,0.78),paint,0.02)
	for side in [-1,1]:
		for z in [-1.27,1.29]:
			Models.tube(root,Vector3(side*0.9,0.35,z),0.33,0.22,"rubber",Vector3.RIGHT)
			Models.tube(root,Vector3(side*1.015,0.35,z),0.23,0.02,"edge",Vector3.RIGHT)
			Models.tube(root,Vector3(side*1.03,0.35,z),0.07,0.025,"black",Vector3.RIGHT)
			for i in range(8):
				var angle := i*TAU/8
				Models.tube(root,Vector3(side*1.03,0.35+cos(angle)*0.15,z+sin(angle)*0.15),0.033,0.023,"black",Vector3.RIGHT)
		for z in [-0.9,0.25,1.15]:Models.bevel(root,Vector3(side*0.919,0.68,z),Vector3(0.012,0.43,0.012),"3a4546",0.002)
		Models.bevel(root,Vector3(side*0.92,0.51,0),Vector3(0.015,0.045,3.6),"black",0.004)
		for z in [-0.1,0.9]:Models.bevel(root,Vector3(side*0.937,0.86,z),Vector3(0.03,0.025,0.15),"edge",0.007)
		Models.bevel(root,Vector3(side*0.81,1.21,-0.68),Vector3(0.05,0.70,0.06),paint,0.01).rotation.x=0.68
		Models.bevel(root,Vector3(side*0.81,1.22,0.97),Vector3(0.06,0.67,0.07),paint,0.012).rotation.x=-0.72
		Models.bevel(root,Vector3(side*0.82,1.23,0.18),Vector3(0.045,0.52,0.065),"black",0.007)
		Models.bevel(root,Vector3(side*1.0,1.03,-0.68),Vector3(0.22,0.12,0.19),paint,0.035)
		Models.bevel(root,Vector3(side*0.63,0.76,-2.045),Vector3(0.48,0.21,0.06),"c6c8b7",0.025)
		Models.bevel(root,Vector3(side*0.67,0.74,2.043),Vector3(0.43,0.19,0.045),"873e31",0.025)
	for z in [-2.05,2.05]:Models.bevel(root,Vector3(0,0.46,z),Vector3(1.84,0.12,0.13),"black",0.035)
	for y in [0.64,0.70,0.76]:Models.bevel(root,Vector3(0,y,-2.06),Vector3(0.62,0.018,0.025),"black",0.004)
	Models.bevel(root,Vector3(0,0.55,-2.13),Vector3(0.46,0.105,0.016),"b8bbac",0.01)
	Models.bevel(root,Vector3(0,0.57,2.13),Vector3(0.46,0.105,0.016),"b8bbac",0.01)
	for side in [-1,1]:Models.bevel(root,Vector3(side*0.3,1.01,-0.84),Vector3(0.02,0.025,0.42),"black",0.003).rotation.y=side*0.6
	car_surfaces(root)

func tree(pos: Vector3) -> void:
	canopy_centers.append(pos+Vector3.UP*4.8)
	solid_trunk(pos,3.7,0.19)
	for i in range(6):
		var angle := float(i)*TAU/6+random.randf_range(-0.2,0.2)
		var end := pos+Vector3(cos(angle)*1.4,3.6+random.randf()*1.5,sin(angle)*1.4)
		rod(pos+Vector3(0,2.3,0),end,0.067,"6b6352")
		for j in range(3):
			var tip := end+Vector3(random.randf_range(-0.7,0.7),random.randf_range(0.1,1.0),random.randf_range(-0.7,0.7))
			rod(end,tip,0.026,"766c52")
	for i in range(180):
		var angle := random.randf()*TAU
		var height := random.randf_range(-1.5,1.5)
		var distance := sqrt(random.randf())*2.1*sqrt(maxf(0.05,1.0-pow(height/1.7,2)))
		var point := pos+Vector3(cos(angle)*distance,4.8+height,sin(angle)*distance)
		var size := random.randf_range(1.05,1.6)
		detail("foliage",point,Vector3.ONE*size,"b4bb9a",Vector3(random.randf_range(-1,1),random.randf()*TAU,random.randf_range(-1,1)))
	for i in range(7):
		var angle := i*TAU/7
		rod(pos+Vector3(0,0.10,0),pos+Vector3(cos(angle)*0.55,0.02,sin(angle)*0.55),0.055,"6b6352")

func bench(pos: Vector3) -> void:
	for z in [-0.24,-0.08,0.08,0.24]:box(pos+Vector3(0,0.5,z),Vector3(2.25,0.065,0.13),Color("8d7754"),true,"wood")
	for y in [0.76,0.92,1.08]:box(pos+Vector3(0,y,0.31),Vector3(2.25,0.13,0.055),Color("8d7754"),true,"wood")
	for x in [-0.85,0.85]:
		for z in [-0.24,0.31]:box(pos+Vector3(x,0.26,z),Vector3(0.045,0.52,0.045),Color("414e47"),true,"steel")
		box(pos+Vector3(x,0.80,0.31),Vector3(0.045,0.6,0.045),Color("414e47"),true,"steel")

func street_details() -> void:
	for x in [-9.35,12.65,-12.65,9.35]:
		for z in range(-46,47):box(Vector3(x,0.12,z),Vector3(0.17,0.24,0.95),Color("a5a99a"))
	for x in [-11,11]:
		for z in range(-46,47,2):box(Vector3(x,0.166,z),Vector3(3.05,0.009,0.025),Color("767f76"))
		for dx in [-0.5,0.5]:box(Vector3(x+dx,0.168,0),Vector3(0.02,0.009,93),Color("767f76"))
	for z in [-18,18]:
		for x in range(-7,8,2):box(Vector3(x,0.046,z),Vector3(1.05,0.018,2.3),Color("b5b6a0"))
	for z in [-34,-7,23,34]:
		detail("cylinder",Vector3(0,0.05,z),Vector3(0.4,0.015,0.4),"555e58")
		for x in [-0.24,-0.12,0,0.12,0.24]:box(Vector3(x,0.061,z),Vector3(0.025,0.012,0.55),Color("313c39"))
		for x in [-8.8,8.8]:
			box(Vector3(x,0.05,z),Vector3(0.45,0.03,0.72),Color("353e3d"))
			for dz in range(6):box(Vector3(x,0.071,z-0.28+dz*0.11),Vector3(0.39,0.02,0.035),Color("738078"))
	# Asphalt repairs and narrow cracks, deterministic and kept below the feet.
	for i in range(24):
		var x := random.randf_range(-8,8)
		var z := random.randf_range(-44,44)
		box(Vector3(x,0.039,z),Vector3(random.randf_range(0.3,1.4),0.009,random.randf_range(0.4,1.8)),Color("424746"))
		var a := Vector3(x,0.053,z)
		for j in range(3):
			var b := a+Vector3(random.randf_range(-0.2,0.2),0,random.randf_range(0.2,0.5))
			rod(a,b,0.008,"303737")
			a=b
	# Sparse grass and shrub borders outside roads, using instanced geometry.
	for i in range(450):
		var x := random.randf_range(13.5,17.7)*(1 if i%2==0 else -1)
		var z := random.randf_range(-45,45)
		if absf(absf(z)-14)<4:continue
		detail("box",Vector3(x,0.12,z),Vector3(0.035,random.randf_range(0.12,0.26),0.015),"76805a",Vector3(0,random.randf()*TAU,random.randf_range(-0.4,0.4)))
	for x in [-43,43]:
		for z in [-40,-12,12,40]:
			for j in range(5):detail("sphere",Vector3(x+j*0.4,0.5,z),Vector3(0.55,0.55,0.55),"667348")
	# A-frame swings, segmented chains and plank seats.
	box(Vector3(-28,0.025,42),Vector3(11,0.05,5.5),Color("a39673"))
	for x in [-31,-25]:
		rod(Vector3(x,0,40.8),Vector3(x,2.8,42),0.055,"7f5140")
		rod(Vector3(x,0,43.2),Vector3(x,2.8,42),0.055,"7f5140")
	rod(Vector3(-31.2,2.8,42),Vector3(-24.8,2.8,42),0.065,"7f5140")
	for x in [-29,-27]:
		for dx in [-0.24,0.24]:rod(Vector3(x+dx,0.65,42),Vector3(x+dx,2.78,42),0.012,"6c7875")
		box(Vector3(x,0.65,42),Vector3(0.64,0.075,0.32),Color("6a7f82"))
	# Bins are small but solid; placed away from spawn/navigation choke points.
	for x in [-14,14]:
		for z in [-42,42]:
			for side in [-1,1]:
				box(Vector3(x+side*0.24,0.45,z),Vector3(0.005,0.9,0.48),Color("4c6256"),true,"steel")
				box(Vector3(x,0.45,z+side*0.24),Vector3(0.48,0.9,0.005),Color("4c6256"),true,"steel")
			box(Vector3(x,0.03,z),Vector3(0.48,0.03,0.48),Color("344b43"),true,"steel")
	# Background blocks beyond the closed playable district establish city scale.
	for x in [-65,-40,-15,15,40,65]:
		var height := random.randf_range(18,28)
		box(Vector3(x,height/2,-67),Vector3(16,height,15),Color("899995"))
		for y in range(3,int(height)-1,3):
			for dx in [-5,-2,1,4]:box(Vector3(x+dx,y,-59.45),Vector3(1.3,1.45,0.03),Color("536f79"))

func flush() -> void:
	for key in batches:
		var batch: Dictionary=batches[key]
		var multi := MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		var mesh := BoxMesh.new()
		mesh.material=material(batch.color)
		multi.mesh=mesh
		multi.instance_count=batch.transforms.size()
		for i in range(multi.instance_count):multi.set_instance_transform(i,batch.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh=multi
		for i in batch.bodies:
			batch.bodies[i].batch=multi
			batch.bodies[i].batch_index=i
		if not batch.shadow:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	batches.clear()


func build_grid() -> void:
	grid.region = Rect2i(-grid_limit,-grid_limit,grid_limit*2+1,grid_limit*2+1)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	# Rasterize only each obstacle's footprint; upper slabs must not seal room navigation.
	for obstacle in obstacles:
		var bounds := obstacle.grow(0.40)
		for x in range(maxi(-grid_limit,ceili(bounds.position.x)),mini(grid_limit,floori(bounds.end.x))+1):
			for z in range(maxi(-grid_limit,ceili(bounds.position.y)),mini(grid_limit,floori(bounds.end.y))+1):
				if bounds.has_point(Vector2(x,z)):grid.set_point_solid(Vector2i(x,z))
	navigation_regions.build(grid)

# Out on the fields round the great assault's village (the column's place)
# there is no navigation grid: the ground is open and the way is straight.
func off_grid(point: Vector3) -> bool:
	return is_instance_valid(operation_area) and (absf(point.x)>199 or absf(point.z)>199)

func path(from: Vector3, to: Vector3) -> PackedVector2Array:
	if off_grid(from) and off_grid(to):return PackedVector2Array([Vector2(from.x,from.z),Vector2(to.x,to.z)])
	var a := navigation_cell(from)
	var b := navigation_cell(to)
	a = nearest_cell(a)
	b = nearest_cell(b)
	if not grid.is_in_boundsv(a) or not grid.is_in_boundsv(b): return PackedVector2Array()
	if not navigation_regions.connected(a,b):
		navigation_rejected_paths+=1
		return PackedVector2Array()
	return grid.get_point_path(a,b)

func nearest_cell(cell: Vector2i) -> Vector2i:
	cell = cell.clamp(grid.region.position+Vector2i.ONE,grid.region.end-Vector2i.ONE*2)
	if not grid.is_point_solid(cell): return cell
	for radius in range(1,6):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				var candidate := cell+Vector2i(dx,dz)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate): return candidate
	return cell

func rubble(pos: Vector3, radius: float, count: int) -> void:
	# Low loose rubble is visual; larger cover has a matching collision volume.
	for i in range(count):
		var angle := random.randf()*TAU
		var r := sqrt(random.randf())*radius
		var size := Vector3(random.randf_range(0.12,0.5),random.randf_range(0.06,0.16),random.randf_range(0.12,0.4))
		detail("box",pos+Vector3(cos(angle)*r,size.y*0.5+0.03,sin(angle)*r),size,["877d6b","8c6d55","676c63"][i%3],Vector3(0,random.randf()*TAU,0))

func war_damage() -> void:
	# Protected insertion courtyard; open ends connect back to both flanks.
	box(Vector3(28,1.3,39.3),Vector3(12,2.6,0.4),Color("777a6d"),true)
	for x in [22,34]:box(Vector3(x,1.3,41),Vector3(0.4,2.6,3.8),Color("777a6d"),true)
	for pos in [Vector3(-15,0,-25),Vector3(15,0,7),Vector3(-38,0,30),Vector3(39,0,-28)]:
		rubble(pos,3.0,65)
		box(pos+Vector3(0,0.48,0),Vector3(1.7,0.96,1.2),Color("828276"),true)
		for i in range(4):rod(pos+Vector3(-0.5+i*0.3,0.9,0),pos+Vector3(-0.7+i*0.3,1.4,-0.15),0.012,"514e44")
	# Burnt road patches, loose brick debris and interrupted utility lines.
	for z in [-32,-9,18]:
		box(Vector3(4,0.045,z),Vector3(3.8,0.015,2.5),Color("30352f"))
		rubble(Vector3(5,0,z),2.3,45)
	for x in [-44,44]:
		for z in [-36,-12,12,36]:
			rod(Vector3(x,0,z),Vector3(x+0.3,5.7,z),0.12,"69685a")
			rod(Vector3(x-0.8,5.3,z),Vector3(x+0.9,5.3,z),0.04,"575b51")
			if z<36:
				rod(Vector3(x,5.4,z),Vector3(x,4.5,z+12),0.012,"393e37")
				rod(Vector3(x,4.5,z+12),Vector3(x,5.4,z+24),0.012,"393e37")
	# Broken trunks and abandoned bus stop outside the insertion lane.
	for pos in [Vector3(-15,0,-32),Vector3(40,0,32),Vector3(15,0,-20)]:
		rod(pos,pos+Vector3(0.2,2.8,0),0.20,"4c4d3c")
		rod(pos+Vector3(0,1.8,0),pos+Vector3(1.2,2.3,0),0.08,"5d5b48")
	box(Vector3(-13,2.3,12),Vector3(3.4,0.12,5),Color("626e64"),true)
	for z in [10,14]:box(Vector3(-14,1.1,z),Vector3(0.10,2.2,0.10),Color("59645a"),true)
	# Move several defenders inside furnished rooms, all reachable through real doors.
	spawn_points[4]=Vector3(23.5,0.1,5.5)
	spawn_points[5]=Vector3(-23.5,0.1,-5.5)
	spawn_points[9]=Vector3(32.5,0.1,-33.5)

func earth_cover(pos: Vector3, length: float, along_z: bool=false) -> void:
	var size := Vector3(1.4,1.05,length) if along_z else Vector3(length,1.05,1.4)
	box(pos+Vector3.UP*0.525,size,Color("62563e"),true,"earth")
	# Earth bank and timber face share the same dimensions as their colliders.
	for y in [0.18,0.42,0.66,0.90]:
		if along_z:rod(pos+Vector3(-0.74,y,-length/2),pos+Vector3(-0.74,y,length/2),0.12,"695c42")
		else:rod(pos+Vector3(-length/2,y,0.74),pos+Vector3(length/2,y,0.74),0.12,"695c42")
	for i in range(int(length*3)):
		var along := -length/2+float(i)/3
		var point := Vector3(0,1.10,along) if along_z else Vector3(along,1.10,0)
		detail("sphere",pos+point,Vector3(0.30,0.10,0.29),"716247")

func field_shelter(pos: Vector3) -> void:
	# Walk-in farm outbuilding / covered rest position, 3 m clear doorway.
	box(pos+Vector3(0,-0.02,0),Vector3(10,0.04,6),Color("706750"),true)
	box(pos+Vector3(0,1.3,3),Vector3(10,2.6,0.3),Color("726e57"),true)
	for x in [-5,5]:box(pos+Vector3(x,1.3,0),Vector3(0.3,2.6,6),Color("716d54"),true)
	for x in [-3.25,3.25]:box(pos+Vector3(x,1.3,-3),Vector3(3.5,2.6,0.3),Color("716d54"),true)
	box(pos+Vector3(0,2.45,-3),Vector3(3,0.3,0.3),Color("716d54"),true)
	box(pos+Vector3(0,2.75,0),Vector3(10.6,0.3,6.6),Color("555d49"),true)
	for x in range(-5,6):rod(pos+Vector3(x,2.55,-3.2),pos+Vector3(x,2.55,3.2),0.11,"625c45")
	for x in [-3,3]:
		box(pos+Vector3(x,0.38,0.5),Vector3(1.6,0.76,3),Color("505e44"),true,"fabric")
		box(pos+Vector3(x,0.83,0.5),Vector3(1.5,0.14,2.8),Color("7d8061"))
		box(pos+Vector3(x,0.96,1.4),Vector3(0.9,0.14,0.4),Color("a49e80"))
	box(pos+Vector3(0,0.4,2),Vector3(1.5,0.8,0.8),Color("6d634b"),true,"wood")
	entrances.append(pos+Vector3(0,0,-3))
	interior_points.append(pos)

func build_shelterbelt() -> void:
	grid_limit=95
	map_title="ПОСАДКА / ГУСТИЙ ЛІС"
	player_spawn=Vector3(0,0.2,87)
	player_spawn_yaw=0
	spawn_points.assign([Vector3(-10,0.1,17),Vector3(10,0.1,10),Vector3(-26,0.1,2),Vector3(29,0.1,-8),Vector3(0,0.1,-12),Vector3(-10,0.1,-20),Vector3(23,0.1,-29),Vector3(-30,0.1,-70),Vector3(5,0.1,-78),Vector3(32,0.1,18)])
	box(Vector3(0,-0.3,0),Vector3(320,0.6,320),Color("51523b"),true)
	# A narrow winding footpath, not a straight firing lane through open fields.
	for z in range(-94,95,2):
		var x := sin(float(z)/22.0)*9.0
		box(Vector3(x,0.018,z),Vector3(2.6,0.036,2.5),Color("665b43"))
	# Irregular dense woodland across the entire playable area and beyond its edge.
	for x in range(-112,113,7):
		for z in range(-112,113,7):
			var point := Vector3(x+random.randf_range(-2,2),0,z+random.randf_range(-2,2))
			if forest_clearance(point,1.2):continue
			forest_tree(point)
	# Waist- to head-high undergrowth breaks ground-level visibility independently of canopy.
	for i in range(2200):
		var point := Vector3(random.randf_range(-94,94),0,random.randf_range(-94,94))
		if forest_clearance(point,1.0):continue
		concealment_patches.append(point+Vector3.UP*1.25)
		for j in range(24):
			var offset := Vector3(random.randf_range(-0.85,0.85),random.randf_range(0.4,2.0),random.randf_range(-0.85,0.85))
			detail("foliage",point+offset,Vector3.ONE*random.randf_range(1.1,1.6),"9aaa7c",Vector3(random.randf_range(-0.6,0.6),random.randf()*TAU,0))
		for j in range(3):rod(point,point+Vector3(random.randf_range(-0.6,0.6),1.7,random.randf_range(-0.6,0.6)),0.018,"766e4a")
	for i in range(4000):
		var point := Vector3(random.randf_range(-95,95),0,random.randf_range(-95,95))
		detail("foliage",point+Vector3.UP*0.18,Vector3(0.8,0.6,0.8),"8b9369",Vector3(0,random.randf()*TAU,0))
	# Traversable revetted lanes, staggered cross walls and firing bays.
	for z in [-27,-9,9]:
		earth_cover(Vector3(-4,0,z),9,true)
		earth_cover(Vector3(6,0,z+3),7,true)
		earth_cover(Vector3(-9,0,z-4),8)
		earth_cover(Vector3(16,0,z+6),9)
	field_shelter(Vector3(0,0,80))
	field_shelter(Vector3(-34,0,-15))
	# Short front bank hides the insertion area from diagonal field sightlines.
	for x in [-7,7]:earth_cover(Vector3(x,0,82),5)
	for z in [-40,-18,4]:
		rubble(Vector3(35,0,z),2.5,25)
		box(Vector3(35,0.025,z),Vector3(4,0.05,3),Color("4f503b"))
	# Visible wire fence marks the playable limit; distant fields remain scenery.
	for side in [-1,1]:
		collider(Vector3(side*96,1.5,0),Vector3(0.15,3,192))
		collider(Vector3(0,1.5,side*96),Vector3(192,3,0.15))
		for a in range(-96,97,6):
			rod(Vector3(side*96,0,a),Vector3(side*96,1.5,a),0.055,"6d6751")
			rod(Vector3(a,0,side*96),Vector3(a,1.5,side*96),0.055,"6d6751")
		for height in [0.5,1.0,1.4]:
			rod(Vector3(side*96,height,-96),Vector3(side*96,height,96),0.009,"626753")
			rod(Vector3(-96,height,side*96),Vector3(96,height,side*96),0.009,"626753")

func forest_clearance(point: Vector3, margin: float) -> bool:
	if absf(point.x-sin(point.z/22.0)*9.0)<1.4+margin:return true
	for z in [-27,-9,9]:
		if absf(point.x+4)<0.7+margin and absf(point.z-z)<4.5+margin:return true
		if absf(point.x-6)<0.7+margin and absf(point.z-z-3)<3.5+margin:return true
		if absf(point.x+9)<4+margin and absf(point.z-z+4)<0.7+margin:return true
		if absf(point.x-16)<4.5+margin and absf(point.z-z-6)<0.7+margin:return true
	if absf(point.x)<10+margin and point.z>74-margin and point.z<92:return true
	if absf(point.x+34)<7+margin and absf(point.z+15)<7+margin:return true
	for spawn in spawn_points:
		if Vector2(point.x-spawn.x,point.z-spawn.z).length()<1.5+margin:return true
	return false

func forest_tree(pos: Vector3) -> void:
	var height := random.randf_range(6.0,9.0)
	var radius := random.randf_range(0.18,0.32)
	canopy_centers.append(pos+Vector3.UP*(height-1))
	solid_trunk(pos,height-1,radius)
	for i in range(5):
		var angle := i*TAU/5+random.randf_range(-0.3,0.3)
		var end := pos+Vector3(cos(angle)*2.1,height-1.2+random.randf(),sin(angle)*2.1)
		rod(pos+Vector3.UP*(height*0.52),end,0.075,"6b6352")
	for i in range(80):
		var angle := random.randf()*TAU
		var r := sqrt(random.randf())*3.6
		var point := pos+Vector3(cos(angle)*r,height-1+random.randf_range(-1.6,1.5),sin(angle)*r)
		detail("foliage",point,Vector3.ONE*random.randf_range(1.8,2.5),"a7b28c",Vector3(random.randf_range(-1,1),random.randf()*TAU,random.randf_range(-1,1)))

func foliage_visibility(a: Vector3, b: Vector3) -> float:
	# The same quads and alpha cutout as the visible foliage, tested from the eye.
	# Transparent texels are gaps; opaque texels block that anatomical sample.
	if foliage_alpha==null:
		foliage_alpha=load("res://assets/textures/foliage.png").get_image()
		if foliage_alpha.is_compressed():foliage_alpha.decompress()
	if foliage_cells.is_empty():return 1.0
	if foliage_indexed!=foliage_count:
		foliage_indexed=foliage_count
		foliage_near.clear()
		for key in foliage_cells:
			for x in range(-1,2):
				for z in range(-1,2):foliage_near[key+Vector2i(x,z)]=true
	var visited: Dictionary={}
	var length := a.distance_to(b)
	var steps := maxi(1,ceili(length/2))
	for step in range(steps+1):
		var point := a.lerp(b,float(step)/steps)
		var cell := Vector2i(floori(point.x/4),floori(point.z/4))
		# Same 3x3 search as before, skipped where no foliage is within reach.
		if not foliage_near.has(cell):continue
		for x in range(-1,2):
			for z in range(-1,2):
				var key := cell+Vector2i(x,z)
				if visited.has(key):continue
				visited[key]=true
				for inverse in foliage_cells.get(key,[]):
					var start: Vector3=inverse*a
					var finish: Vector3=inverse*b
					var dz := finish.z-start.z
					if absf(dz)<0.000001:continue
					var t := -start.z/dz
					if t<=0.001 or t>=0.999:continue
					var local := start.lerp(finish,t)
					if absf(local.x)>0.5 or absf(local.y)>0.5:continue
					var px := clampi(int((local.x+0.5)*foliage_alpha.get_width()),0,foliage_alpha.get_width()-1)
					var py := clampi(int((0.5-local.y)*foliage_alpha.get_height()),0,foliage_alpha.get_height()-1)
					if foliage_alpha.get_pixel(px,py).a>=0.5:return 0.0
	return 1.0

func background_color(observer: Vector3, target: Vector3) -> Color:
	var direction := observer.direction_to(target)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target+direction*0.5,target+direction*18,1))
	if not hit.is_empty():
		if hit.collider.has_meta("terrain") and terrain!=null:return terrain.surface_color(Vector2(hit.position.x,hit.position.z))
		return hit.collider.get_meta("surface_color",Color("66684e"))
	return Color("74786b") if map_id=="city" else Color("515b3e")

func light_at(point: Vector3, toward_sun: Vector3) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point,point+toward_sun*80,1))
	if not hit.is_empty():return 0.32
	if canopy_indexed!=canopy_centers.size():
		canopy_indexed=canopy_centers.size()
		canopy_cells.clear()
		for canopy in canopy_centers:
			var key := Vector2i(floori(canopy.x/8),floori(canopy.z/8))
			if not canopy_cells.has(key):canopy_cells[key]=[]
			canopy_cells[key].append(canopy)
	var radius := 3.6 if map_id=="shelterbelt" else 2.1
	var cell := Vector2i(floori(point.x/8),floori(point.z/8))
	for x in range(-1,2):
		for z in range(-1,2):
			for canopy in canopy_cells.get(cell+Vector2i(x,z),[]):
				if point.y<canopy.y and Vector2(point.x-canopy.x,point.z-canopy.z).length()<radius:return 0.45 if map_id=="shelterbelt" else 0.55
	return 1.0

func surface_piece(pos: Vector3, size: Vector3, color: Color, substance: String, basis: Basis=Basis.IDENTITY) -> DestructibleSurface:
	var body: DestructibleSurface=collider(pos,size,substance)
	body.basis=basis
	body.tint=color
	body.set_meta("surface_color",color)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	visual.material_override=material(color)
	body.add_child(visual)
	return body

func fragment(pos: Vector3, size: Vector3, color: Color, substance: String, direction: Vector3, basis: Basis) -> void:
	var body := RigidBody3D.new()
	body.mass=clampf(size.x*size.y*size.z*float(Penetration.MATERIALS[substance].density),0.02,30)
	body.collision_layer=32 # Debris must not create invisible bullet/AI shields.
	body.collision_mask=1
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size=size
	shape.shape=box_shape
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	visual.material_override=material(color)
	body.add_child(visual)
	add_child(body)
	body.global_transform=Transform3D(basis,pos)
	body.linear_velocity=direction*1.5+Vector3.UP*0.4
	body.angular_velocity=Vector3(2,1,3)
	fragments.append(body)
	if fragments.size()>96:
		var oldest: RigidBody3D=fragments.pop_front()
		if is_instance_valid(oldest):oldest.queue_free()

func solid_trunk(pos: Vector3, height: float, radius: float) -> void:
	var body: DestructibleSurface=collider(pos+Vector3.UP*height/2,Vector3(radius*2,height,radius*2),"wood")
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius*0.8
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=12
	mesh.rings=1
	var collision: CollisionShape3D=body.get_child(0)
	collision.shape=mesh.create_trimesh_shape()
	var visual := MeshInstance3D.new()
	visual.name="SurfaceMesh"
	visual.mesh=mesh
	visual.material_override=material(Color("6b6352"))
	body.tint=Color("6b6352")
	body.add_child(visual)

func refresh_navigation(changed_bounds: AABB=AABB(), removed_id: int=0, additions: Array=[]) -> void:
	if terrain!=null:
		if changed_bounds.has_volume():
			navigation_obstacles.remove_body(removed_id)
			for body in additions:
				if is_instance_valid(body):navigation_obstacles.add_body(body)
			navigation_dirty.append(navigation_rect(changed_bounds))
		else:navigation_full_pending=true
	if navigation_pending:return
	navigation_pending=true
	await get_tree().process_frame
	if terrain!=null:
		if navigation_full_pending:rebuild_campaign_grid()
		else:refresh_campaign_cells()
		navigation_full_pending=false
		navigation_dirty.clear()
		navigation_pending=false
		return
	obstacles.clear()
	for child in get_children():
		if not child is StaticBody3D or child.is_queued_for_deletion():continue
		for shape in child.get_children():
			if not shape is CollisionShape3D:continue
			var bounds: AABB=shape.shape.get_debug_mesh().get_aabb()
			bounds=shape.global_transform*bounds
			if bounds.end.y>0.5 and bounds.position.y<1.9:obstacles.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)))
	build_grid()
	navigation_pending=false

func car_surfaces(model: Node3D) -> void:
	# Body and glazing are shells, not a car-sized block of steel. Other parts
	# retain their own mesh and collider (wheels, pillars, bumpers, lights).
	var parts := model.get_children()
	for i in range(parts.size()):
		var visual: MeshInstance3D=parts[i]
		var body := DestructibleSurface.new()
		body.district=self
		var substance := "steel"
		if i==1:substance="glass"
		elif visual.material_override.albedo_color.r<0.08:substance="rubber"
		body.set_meta("ballistic_material",substance)
		body.tint=visual.material_override.albedo_color
		body.set_meta("surface_color",body.tint)
		var collision := CollisionShape3D.new()
		collision.shape=visual.mesh.create_trimesh_shape()
		body.add_child(collision)
		add_child(body)
		body.transform=model.transform*visual.transform
		model.remove_child(visual)
		visual.transform=Transform3D.IDENTITY
		visual.name="SurfaceMesh"
		body.add_child(visual)
		if i<2:
			# Make a closed thin shell using an inset copy of the same shape.
			# Two nested watertight surfaces provide real entry/exit intervals.
			var faces: PackedVector3Array=visual.mesh.get_faces()
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var center := visual.mesh.get_aabb().get_center()
			for j in range(0,faces.size(),3):
				for k in range(3):tool.add_vertex(faces[j+k])
				for k in [2,1,0]:tool.add_vertex(center+(faces[j+k]-center)*Vector3(0.985,0.96,0.985))
			tool.generate_normals()
			tool.index()
			visual.mesh=tool.commit()
			collision.shape=visual.mesh.create_trimesh_shape()
			collision.shape.backface_collision=true
	# Dense mechanical components protect the engine bay even behind sheet metal.
	surface_piece(model.transform*Vector3(0,0.65,-1.35),Vector3(0.85,0.40,0.65),Color("45494a"),"steel",model.basis)
	model.free()

func ground_height(point: Vector3) -> float:
	return terrain.height_at(Vector2(point.x,point.z)) if terrain!=null else 0.0

func rebuild_campaign_grid() -> void:
	navigation_full_rebuilds+=1
	navigation_scale=1.0 if campaign_definition.get("kind","") in ["forest","battle"] else 2.0
	var limit := int(199*navigation_scale)
	grid.region=Rect2i(-limit,-limit,limit*2+1,limit*2+1)
	grid.cell_size=Vector2.ONE/navigation_scale
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var width := limit*2+1
	if navigation_base.size()!=width*width:
		navigation_base.resize(width*width)
		navigation_weights.resize(width*width)
		for z in range(-limit,limit+1):
			for x in range(-limit,limit+1):
				var point := Vector2(x,z)/navigation_scale
				var h := terrain.height_at(point)
				var slope := 0.0
				for offset in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:slope=maxf(slope,absf(terrain.height_at(point+offset/navigation_scale)-h))
				var blocked := slope*navigation_scale>0.72
				navigation_base[(z+limit)*width+x+limit]=1 if blocked else 0
				navigation_weights[(z+limit)*width+x+limit]=1+slope*3
				grid.set_point_solid(Vector2i(x,z),blocked)
				grid.set_point_weight_scale(Vector2i(x,z),1+slope*3)
	else:
		for z in range(-limit,limit+1):
			for x in range(-limit,limit+1):
				grid.set_point_solid(Vector2i(x,z),navigation_base[(z+limit)*width+x+limit]==1)
				grid.set_point_weight_scale(Vector2i(x,z),navigation_weights[(z+limit)*width+x+limit])
	for child in get_children():
		if not child is StaticBody3D or child.is_queued_for_deletion() or child.has_meta("boundary"):continue
		for collision in child.get_children():
			if not collision is CollisionShape3D:continue
			var local_bounds: AABB=AABB(-collision.shape.size/2,collision.shape.size) if collision.shape is BoxShape3D else collision.shape.get_debug_mesh().get_aabb()
			var bounds: AABB=collision.global_transform*local_bounds
			var inverse: Transform3D=collision.global_transform.affine_inverse()
			for z in range(maxi(-limit,floori((bounds.position.z-0.6)*navigation_scale)),mini(limit,ceili((bounds.end.z+0.6)*navigation_scale))+1):
				for x in range(maxi(-limit,floori((bounds.position.x-0.6)*navigation_scale)),mini(limit,ceili((bounds.end.x+0.6)*navigation_scale))+1):
					var h := terrain.height_at(Vector2(x,z)/navigation_scale)
					if bounds.end.y<h+0.22 or bounds.position.y>h+1.8:continue
					var local: Vector3=inverse*Vector3(x/navigation_scale,clampf(h+0.8,bounds.position.y,bounds.end.y),z/navigation_scale)
					if NavigationObstacles.inside(local,local_bounds,navigation_scale):grid.set_point_solid(Vector2i(x,z),true)
	navigation_obstacles.build(self)
	navigation_regions.build(grid)
	navigation_last_cells=width*width

func navigation_rect(bounds: AABB) -> Rect2i:
	var low := Vector2i(floori((bounds.position.x-0.6)*navigation_scale),floori((bounds.position.z-0.6)*navigation_scale))
	var high := Vector2i(ceili((bounds.end.x+0.6)*navigation_scale),ceili((bounds.end.z+0.6)*navigation_scale))
	return Rect2i(low,high-low+Vector2i.ONE).intersection(grid.region)

func refresh_campaign_cells() -> void:
	var visited: Dictionary={}
	var closed := false
	for rect in navigation_dirty:
		var bounds := AABB(Vector3(rect.position.x/navigation_scale,-100,rect.position.y/navigation_scale),Vector3(rect.size.x/navigation_scale,200,rect.size.y/navigation_scale))
		var nearby := navigation_obstacles.near(bounds)
		for z in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var cell := Vector2i(x,z)
				if visited.has(cell):continue
				visited[cell]=true
				var index := (z-grid.region.position.y)*grid.region.size.x+x-grid.region.position.x
				var blocked := navigation_base[index]==1
				var point := Vector3(x/navigation_scale,0,z/navigation_scale)
				point.y=ground_height(point)
				if not blocked:
					for record in nearby:
						if NavigationObstacles.blocks(record,point,cell):blocked=true;break
				var previous := grid.is_point_solid(cell)
				if blocked==previous:continue
				grid.set_point_solid(cell,blocked)
				if blocked:closed=true
				else:navigation_regions.open_cell(cell)
	# Destruction only opens space. Explicitly added obstacles may split a
	# region, so that exceptional case needs fresh connectivity information.
	if closed:navigation_regions.build(grid)
	navigation_local_updates+=1
	navigation_last_cells=visited.size()

func navigation_cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x*navigation_scale),roundi(point.z*navigation_scale))

func navigation_position(cell: Vector2i) -> Vector3:
	var point := Vector3(cell.x/navigation_scale,0,cell.y/navigation_scale)
	point.y=ground_height(point)+0.1
	return point
