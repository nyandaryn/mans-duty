extends SceneTree
# Preview renders of the PKM model: profiles, details, bipod, feed cover and
# the first-person sight picture. PNGs go to $KVARTAL_PREVIEW_DIR.
const PkmArt = preload("res://scripts/pkm_art.gd")
var scene: Node3D
var camera: Camera3D
func _initialize():call_deferred("run")
func frames(n: int):
	for i in range(n):await process_frame

func triangles(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and node.visible and node.mesh:
		for s in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(s)
			var indices=arrays[Mesh.ARRAY_INDEX]
			total+=(indices.size() if indices!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
	for child in node.get_children():total+=triangles(child)
	return total

func meshes(node: Node) -> int:
	var total := 1 if node is MeshInstance3D else 0
	for child in node.get_children():total+=meshes(child)
	return total

func build() -> Node3D:
	var gun := Node3D.new()
	var mag := Models.group(gun,"Magazine")
	var bolt := Models.group(gun,"Bolt")
	PkmArt.build(gun,mag,bolt)
	WeaponArt.finish(gun)
	return gun

func ortho(size: float, position: Vector3, basis: Basis) -> void:
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=size
	camera.transform=Transform3D(basis,position)

func perspective(fov: float, position: Vector3, target: Vector3) -> void:
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=fov
	camera.position=position
	camera.look_at(target,Vector3.UP)

func shot(name: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/pkm-"+name+".png")
	print("RENDER ",name," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

func run():
	root.msaa_3d=Viewport.MSAA_4X
	scene=Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("1c2024")
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
	env.ambient_light_energy=0.5
	environment.environment=env
	scene.add_child(environment)
	for spec in [[Vector3(-35,-45,0),2.2,Color(1,0.96,0.88)],[Vector3(30,140,0),1.8,Color(0.65,0.8,1)],[Vector3(-60,70,0),1.4,Color.WHITE]]:
		var lamp := DirectionalLight3D.new()
		lamp.rotation_degrees=spec[0]
		lamp.light_energy=spec[1]
		lamp.light_color=spec[2]
		scene.add_child(lamp)
	camera=Camera3D.new()
	camera.near=0.01
	scene.add_child(camera)
	camera.current=true
	# Budget against the AK-74M built the same way.
	var ak := Node3D.new()
	WeaponArt.build_ak(ak,Models.group(ak,"Magazine"),Models.group(ak,"Bolt"))
	WeaponArt.finish(ak)
	var gun := build()
	print("BUDGET pkm triangles=",triangles(gun)," meshes=",meshes(gun)," | ak74 triangles=",triangles(ak)," meshes=",meshes(ak))
	ak.free()
	scene.add_child(gun)
	var sight_height: float=gun.get_meta("sight_height")
	var rear_z: float=gun.get_meta("rear_z")
	var eye_relief: float=gun.get_meta("eye_relief")
	for key in gun.get_meta_list():print("META ",key,"=",gun.get_meta(key))
	var right := Basis(Vector3(0,0,-1),Vector3.UP,Vector3.RIGHT)
	var left := Basis(Vector3(0,0,1),Vector3.UP,Vector3.LEFT)
	var top := Basis(Vector3(0,0,-1),Vector3(-1,0,0),Vector3.UP)
	var center := Vector3(0,-0.045,-0.176)
	ortho(0.72,center+Vector3(1.5,0,0),right)
	await shot("right")
	ortho(0.72,center+Vector3(-1.5,0,0),left)
	await shot("left")
	ortho(0.72,center+Vector3(0,1.5,0),top)
	await shot("top")
	ortho(0.30,Vector3(1.5,-0.04,-0.06),right)
	await shot("receiver-right")
	ortho(0.30,Vector3(-1.5,-0.04,-0.06),left)
	await shot("receiver-left")
	ortho(0.22,Vector3(1.5,0.02,-0.66),right)
	await shot("muzzle-right")
	perspective(30,Vector3(0.75,0.32,-1.25),Vector3(0,-0.04,-0.22))
	await shot("front-34")
	perspective(30,Vector3(0.85,0.45,0.75),Vector3(0,-0.03,-0.12))
	await shot("rear-34")
	perspective(22,Vector3(0.28,0.16,0.20),Vector3(0,0.03,-0.06))
	await shot("feed-closeup")
	perspective(18,Vector3(0.12,0.12,0.18),Vector3(0,0.06,0.0))
	await shot("rear-sight")
	perspective(18,Vector3(0.16,0.10,-0.52),Vector3(0,0.035,-0.67))
	await shot("front-sight")
	# First-person: eye on the sight line behind the notch, 65 degree lens.
	perspective(65,Vector3(0,sight_height,rear_z+eye_relief),Vector3(0,sight_height,-10))
	await shot("first-person")
	camera.fov=6
	await shot("sight-picture")
	var slider: Node3D=gun.get_node("RearSightSlider")
	slider.position.y+=0.016
	camera.fov=65
	await shot("first-person-1500m")
	perspective(18,Vector3(0.12,0.12,0.18),Vector3(0,0.06,0.0))
	await shot("rear-sight-1500m")
	slider.position.y-=0.016
	# Feed cover open: front hinge, rear lifts with negative rotation.x.
	var cover: Node3D=gun.get_node("FeedCover")
	cover.rotation.x=-1.15
	perspective(30,Vector3(0.55,0.45,0.45),Vector3(0,0.0,-0.10))
	await shot("cover-open")
	ortho(0.40,Vector3(1.5,0.03,-0.08),right)
	await shot("cover-open-right")
	cover.rotation.x=0
	# Bipod deployed: legs down and a little forward, splayed outward.
	var bipod: Node3D=gun.get_node("Bipod")
	bipod.get_node("LegLeft").rotation=Vector3(0.30,0,-0.22)
	bipod.get_node("LegRight").rotation=Vector3(0.30,0,0.22)
	ortho(0.72,center+Vector3(1.5,-0.06,0),right)
	await shot("bipod-deployed-right")
	perspective(30,Vector3(0.9,0.25,-1.5),Vector3(0,-0.12,-0.3))
	await shot("bipod-deployed-front")
	bipod.get_node("LegLeft").rotation=Vector3(-PI/2,0,0)
	bipod.get_node("LegRight").rotation=Vector3(-PI/2,0,0)
	perspective(26,Vector3(0.55,-0.45,-0.75),Vector3(0,-0.05,-0.30))
	await shot("bipod-folded-under")
	var handle: Node3D=gun.get_node("CarryHandle")
	handle.rotation.z=0
	ortho(0.72,center+Vector3(1.5,0,0),right)
	await shot("handle-up-right")
	scene.queue_free()
	await frames(3)
	quit()
