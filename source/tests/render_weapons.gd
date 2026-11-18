extends SceneTree
var scene: Node3D
func _initialize():call_deferred("run")
func frames(n: int):
	for i in range(n):await process_frame
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
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.23
	scene.add_child(camera)
	camera.current=true
	for id in ["ak74","m16","pm","m9"]:
		var model: Node3D=Models.weapon(id)
		scene.add_child(model)
		for part in ["LeftHand","RightHand","LeftForearm","RightForearm"]:model.get_node(part).hide()
		var pistol: bool=id in ["pm","m9"]
		camera.size=0.29 if pistol else 0.70
		camera.position=Vector3(0.9,0.48,0.30) if not pistol else Vector3(0.9,0.3,0.25)
		camera.look_at(Vector3(0,-0.04,-0.10 if not pistol else -0.015))
		await frames(60)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("KVARTAL_PREVIEW_DIR")+"/"+id+"-model.png")
		print("RENDER ",id," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		model.queue_free()
		await frames(2)
	scene.queue_free()
	await frames(3)
	quit()
