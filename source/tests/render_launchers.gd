extends SceneTree
# Preview renders of the RPG-7V/PGO-7/PG-7VL and RPG-22 models.
# KVARTAL_PREVIEW_DIR=<dir> godot --path source --resolution 1600x900 --script res://tests/render_launchers.gd
const Rpg7Art = preload("res://scripts/rpg7_art.gd")
const Rpg22Art = preload("res://scripts/rpg22_art.gd")
var scene: Node3D
var camera: Camera3D
var env: Environment
var out := ""

func _initialize():call_deferred("run")

func frames(n: int):
	for i in range(n):await process_frame

func run():
	out=OS.get_environment("KVARTAL_PREVIEW_DIR")
	root.msaa_3d=Viewport.MSAA_4X
	scene=Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("1c2024")
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("899bad")
	sky_material.sky_horizon_color=Color("c4c3bc")
	sky_material.ground_bottom_color=Color("4a4d40")
	sky_material.ground_horizon_color=Color("8a8b80")
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
	camera.near=0.004
	scene.add_child(camera)
	camera.current=true

	var rpg7: Node3D=Rpg7Art.build(true)
	scene.add_child(rpg7)
	report("rpg7 loaded",rpg7)
	var c := Vector3(0,-0.035,-0.04)
	await ortho("rpg7-right",0.85,c+Vector3(3,0,0),c)
	await ortho("rpg7-left",0.85,c+Vector3(-3,0,0),c)
	await persp("rpg7-front34",30,Vector3(-0.85,0.40,-1.20),c+Vector3(0,0,-0.06))
	await persp("rpg7-rear34",30,Vector3(0.72,0.36,1.05),c)
	await ortho("rpg7-top",0.85,c+Vector3(0,3,0),c,Vector3.LEFT)
	await ortho("rpg7-grips-right",0.24,Vector3(3,-0.06,-0.12),Vector3(0,-0.06,-0.12))
	await persp("rpg7-pgo",34,Vector3(-0.42,0.22,0.36),Vector3(-0.045,0.03,-0.03))
	var hammer: Node3D=rpg7.get_node("Hammer")
	hammer.rotation.x=Rpg7Art.HAMMER_COCKED
	await ortho("rpg7-hammer-cocked",0.13,Vector3(3,-0.05,-0.15),Vector3(0,-0.05,-0.15))
	hammer.rotation.x=0
	await ortho("rpg7-hammer-down",0.13,Vector3(3,-0.05,-0.15),Vector3(0,-0.05,-0.15))
	env.background_mode=Environment.BG_SKY
	await persp("rpg7-eye",70,Rpg7Art.EYEPIECE+Vector3(0,0,0.04),Rpg7Art.EYEPIECE+Vector3(0,0,-1))
	env.background_mode=Environment.BG_COLOR
	rpg7.queue_free()
	var empty: Node3D=Rpg7Art.build(false)
	scene.add_child(empty)
	await ortho("rpg7-unloaded-left",0.62,Vector3(-3,-0.035,0.155),Vector3(0,-0.035,0.155))
	await persp("rpg7-muzzle",30,Vector3(-0.25,0.12,-0.75),Vector3(0,0,-0.32))
	empty.queue_free()

	var round_full: Node3D=Rpg7Art.grenade(true,false)
	scene.add_child(round_full)
	report("pg7vl charge",round_full)
	await ortho("pg7vl-charge",0.60,Vector3(3,0,0.11),Vector3(0,0,0.11))
	round_full.queue_free()
	var flying: Node3D=Rpg7Art.grenade(false,true)
	scene.add_child(flying)
	report("pg7vl flight",flying)
	await ortho("pg7vl-flight-side",0.56,Vector3(3,0,0.08),Vector3(0,0,0.08))
	await persp("pg7vl-flight34",30,Vector3(0.62,0.34,0.95),Vector3(0,0,0.06))
	flying.queue_free()

	var rpg22: Node3D=Rpg22Art.build(true)
	scene.add_child(rpg22)
	report("rpg22 extended",rpg22)
	var d := Vector3(0,0.0,-0.02)
	await ortho("rpg22-right",0.52,d+Vector3(3,0,0),d)
	await ortho("rpg22-left",0.52,d+Vector3(-3,0,0),d)
	await persp("rpg22-front34",30,Vector3(-0.65,0.32,-0.92),d)
	await persp("rpg22-rear34",30,Vector3(0.6,0.36,0.86),d)
	await ortho("rpg22-top",0.52,d+Vector3(0,3,0),d,Vector3.LEFT)
	await persp("rpg22-sights",32,Vector3(0.22,0.24,0.32),Vector3(0,0.07,-0.14))
	env.background_mode=Environment.BG_SKY
	await persp("rpg22-eye",50,Rpg22Art.APERTURE+Vector3(0,0,0.06),Rpg22Art.APERTURE+Vector3(0,0,-Rpg22Art.SIGHT_RADIUS))
	await persp("rpg22-frame",14,Rpg22Art.APERTURE+Vector3(0,0,0.06),Rpg22Art.APERTURE+Vector3(0,-0.012,-Rpg22Art.SIGHT_RADIUS))
	env.background_mode=Environment.BG_COLOR
	rpg22.queue_free()
	var packed: Node3D=Rpg22Art.build(false)
	scene.add_child(packed)
	report("rpg22 transport",packed)
	await ortho("rpg22-transport-right",0.52,d+Vector3(3,0,0),d)
	await persp("rpg22-transport-front34",30,Vector3(-0.65,0.32,-0.92),d)
	packed.queue_free()
	var rocket: Node3D=Rpg22Art.grenade()
	scene.add_child(rocket)
	report("pg22 flight",rocket)
	await ortho("rpg22-grenade-side",0.36,Vector3(3,0,0.08),Vector3(0,0,0.08))
	await persp("rpg22-grenade34",30,Vector3(0.45,0.26,0.62),Vector3(0,0,0.06))
	rocket.queue_free()
	scene.queue_free()
	await frames(3)
	quit()

func ortho(name: String, size: float, pos: Vector3, target: Vector3, up: Vector3=Vector3.UP) -> void:
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=size
	camera.position=pos
	camera.look_at(target,up)
	await shot(name)

func persp(name: String, fov: float, pos: Vector3, target: Vector3) -> void:
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=fov
	camera.position=pos
	camera.look_at(target,Vector3.UP)
	await shot(name)

func shot(name: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+name+".png")
	print("RENDER ",name," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

func report(label: String, node: Node3D) -> void:
	var tally := [0,0]
	count(node,tally)
	var names := []
	for child in node.get_children():
		if not child is MeshInstance3D:names.append(str(child.name)+":"+child.get_class()+str(child.position))
	print("MODEL ",label," triangles=",tally[0]," surfaces=",tally[1]," nodes=",names)

func count(node: Node, tally: Array) -> void:
	if node is MeshInstance3D and node.mesh:
		for s in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(s)
			var index: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			tally[0]+=(index.size() if index.size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
			tally[1]+=1
	for child in node.get_children():count(child,tally)
