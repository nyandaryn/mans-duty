extends SceneTree
# Renders the three vests (scripts/vest_art.gd) on the soldier model: front,
# back, 3/4, side, a raised-rifle pose for the shoulder pads, the bots' aiming
# pose and the prone pose. PNGs go to $KVARTAL_PREVIEW_DIR.
const VestArt = preload("res://scripts/vest_art.gd")
var scene: Node3D
var camera: Camera3D

func _initialize():call_deferred("run")

func frames(n: int):
	for i in range(n):await process_frame

func snap(title: String, from: Vector3, at: Vector3, fov: float=24.0):
	camera.fov=fov
	camera.position=from
	camera.look_at(at)
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/"+title+".png")

func triangles(node: Node) -> Vector2i:
	var count := 0
	var surfaces := 0
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count()):
			surfaces+=1
			var arrays: Array=mesh.mesh.surface_get_arrays(i)
			var index=arrays[Mesh.ARRAY_INDEX]
			count+=(index.size() if index!=null and index.size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
	return Vector2i(count,surfaces)

# Same rifle/arm/head kinematics as Hostile.animate_pose.
func pose(model: Node3D, rifle_at: Vector3, pitch: float, head_at: Vector3, head_rot: Vector3) -> void:
	var rifle: Node3D=model.get_node("CarriedRifle")
	rifle.position=rifle_at
	rifle.rotation=Vector3(pitch,0,0)
	CharacterArt.pose_arm(model,"Left",rifle.position+rifle.basis*Vector3(-0.035,-0.045,-0.265))
	CharacterArt.pose_arm(model,"Right",rifle.position+rifle.basis*Vector3(0.012,-0.09,0.085))
	var head: Node3D=model.get_node("Head")
	head.position=head_at
	head.rotation=head_rot

func run():
	root.msaa_3d=Viewport.MSAA_4X
	scene=Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("2a2e33")
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("899bad")
	sky_material.sky_horizon_color=Color("c4c3bc")
	sky_material.ground_bottom_color=Color("22262c")
	sky_material.ground_horizon_color=Color("80878e")
	sky.sky_material=sky_material
	env.sky=sky
	env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("a8b7c8")
	env.ambient_light_energy=0.42
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment=env
	scene.add_child(environment)
	for spec in [[Vector3(-38,-35,0),1.3,Color(1,0.96,0.88),true],[Vector3(25,150,0),0.45,Color(0.65,0.8,1),false],[Vector3(-55,80,0),0.35,Color.WHITE,false]]:
		var lamp := DirectionalLight3D.new()
		lamp.rotation_degrees=spec[0]
		lamp.light_energy=spec[1]
		lamp.light_color=spec[2]
		lamp.shadow_enabled=spec[3]
		scene.add_child(lamp)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size=Vector2(8,8)
	ground.mesh=plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color=Color("34352f")
	ground.material_override=ground_material
	scene.add_child(ground)
	camera=Camera3D.new()
	scene.add_child(camera)
	camera.current=true
	var probe := Node3D.new()
	scene.add_child(probe)
	var bare := CharacterArt.build(probe,true)
	print("VESTS bot soldier without vest: tris/surfaces ",triangles(bare))
	probe.free()
	for kind in VestArt.KINDS:
		var holder := Node3D.new()
		scene.add_child(holder)
		var model: Node3D=CharacterArt.build(holder)
		Wardrobe.dress(model,"rf_digital" if kind=="ratnik" else "ua_pixel")
		var started := Time.get_ticks_usec()
		var vest: Node3D=VestArt.attach(model,kind)
		var built := Time.get_ticks_usec()-started
		started=Time.get_ticks_usec()
		VestArt.attach(model,kind)
		var again := Time.get_ticks_usec()-started
		vest=model.get_node("Vest")
		var total := triangles(vest)
		var report := "VESTS %s: Vest %s" % [kind,triangles(vest)]
		for path in ["VestGroin","LeftArm/VestShoulder","RightArm/VestShoulder"]:
			var node := model.get_node_or_null(path)
			if node!=null:
				report+=" %s %s" % [path,triangles(node)]
				total+=triangles(node)
		print(report," | total tris/surfaces ",total," | first attach %d us, cached %d us" % [built,again])
		# A uniform change must not recolour the vest; another kind replaces it.
		Wardrobe.dress(model,"urban_grey")
		var keys := {}
		for path in ["Vest","VestGroin","LeftArm/VestShoulder","RightArm/VestShoulder"]:
			var node := model.get_node_or_null(path)
			if node==null:continue
			for mesh in node.find_children("*","MeshInstance3D",true,false):
				for i in range(mesh.mesh.get_surface_count()):keys[mesh.get_active_material(i).resource_name]=true
		print("VESTS %s materials after re-dress: %s" % [kind,keys.keys()])
		Wardrobe.dress(model,"rf_digital" if kind=="ratnik" else "ua_pixel")
		for other in VestArt.KINDS:
			VestArt.attach(model,other)
			var count := 0
			for path in ["Vest","VestGroin","LeftArm/VestShoulder","RightArm/VestShoulder"]:
				if model.get_node_or_null(path)!=null:count+=1
			if count!=(1 if other=="carrier" else 4) or model.get_node("Vest").get_meta("vest")!=other:printerr("VESTS switching to ",other," left ",count," parts")
		VestArt.attach(model,kind)
		await snap(kind+"-front",Vector3(0,1.3,-2.3),Vector3(0,1.17,0),30)
		await snap(kind+"-back",Vector3(0,1.3,2.3),Vector3(0,1.17,0),30)
		await snap(kind+"-34",Vector3(-1.55,1.45,-1.75),Vector3(0,1.17,0),30)
		await snap(kind+"-side",Vector3(2.3,1.3,0),Vector3(0,1.17,0),30)
		await snap(kind+"-closeup",Vector3(0.95,1.62,-1.05),Vector3(0,1.3,-0.05),22)
		# Rifle raised high (shooting up a slope / at a drone): shoulder pads.
		pose(model,Vector3(0.11,1.62,-0.30),0.75,Vector3(0.04,1.47,-0.02),Vector3(0.45,0,-0.12))
		await snap(kind+"-raise",Vector3(-1.4,1.55,-1.6),Vector3(0,1.3,0))
		await snap(kind+"-raise-side",Vector3(1.9,1.45,-0.5),Vector3(0,1.3,-0.1))
		# Bot aiming pose: rifle up at the cheek, head dropped onto the stock.
		pose(model,Vector3(0.11,1.52,-0.34),0.0,Vector3(0.04,1.43,-0.02),Vector3(-0.06,0,-0.14))
		await snap(kind+"-aim",Vector3(-1.2,1.6,-1.5),Vector3(0.05,1.38,-0.1))
		# Prone, as Hostile.animate_pose with tactical_prone=1.
		model.position=Vector3(0,0.20,0.65)
		model.rotation.x=-PI*0.5
		pose(model,Vector3(0.14,1.34,-0.16),PI*0.5,Vector3(0,1.5,0),Vector3(1.25,0,0))
		await snap(kind+"-prone",Vector3(-1.3,0.75,-1.9),Vector3(0,0.25,-0.3))
		holder.free()
	scene.queue_free()
	await frames(3)
	quit()
