class_name Models
extends RefCounted

static func part(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.8
	mesh.material = mat
	node.mesh = mesh
	node.position = pos
	parent.add_child(node)
	return node

# Weapon dimensions are in metres, with the bore along -Z and Y=0.
# Sight markers describe the actual iron-sight plane, not a UI crosshair.
static var materials: Dictionary = {}
# Set while building the bots' soldier model: fewer segments on tiny parts.
static var lite := false

static func surface(key: String) -> StandardMaterial3D:
	if materials.has(key):return materials[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name=key
	if key.begins_with("gun_"):
		var palette := {"gun_metal":"444a4e","gun_edge":"626a70","gun_polymer":"303333","gun_grip":"282c2c","gun_rubber":"191c1d","gun_recess":"0c1012"}
		var metal := key in ["gun_metal","gun_edge"]
		var family := "metal" if metal else ("grip" if key=="gun_grip" else "polymer")
		mat.albedo_color=Color(palette.get(key,"444444"))
		mat.metallic=0.82 if metal else 0.0
		mat.roughness=0.70 if key=="gun_edge" else 1.0
		mat.albedo_texture=load("res://assets/textures/weapons/"+family+"-albedo.png")
		mat.roughness_texture=load("res://assets/textures/weapons/"+family+"-roughness.png")
		mat.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.normal_enabled=true
		mat.normal_texture=load("res://assets/textures/weapons/"+family+"-normal.png")
		mat.normal_scale=0.35 if metal else 0.55
		mat.uv1_triplanar=true
		mat.uv1_scale=Vector3.ONE*(24 if key=="gun_grip" else 9)
		materials[key]=mat
		return mat
	if key.begins_with("gear_#"):
		mat=surface("cloth").duplicate()
		mat.resource_name=key
		mat.albedo_color=Color(key.trim_prefix("gear_"))
		materials[key]=mat
		return mat
	var colors := {"steel":"42494d","black":"242a2e","edge":"60686d","wood":"895027","bakelite":"713620","polymer":"303433","rubber":"242721","glove":"777962","cloth":"525d4a","brass":"ba9148","copper":"a77347","white":"d7d3b8"}
	mat.albedo_color=Color(colors.get(key,key))
	mat.metallic=0.72 if key in ["steel","black","edge","brass"] else 0.0
	mat.roughness=0.62 if mat.metallic>0 else 0.86
	if key in ["wood","bakelite","polymer","steel","black","glove","cloth"]:
		var noise := FastNoiseLite.new()
		noise.seed=key.hash()
		noise.frequency=0.045 if key=="wood" else 0.22
		var texture := NoiseTexture2D.new()
		texture.width=128
		texture.height=128
		texture.seamless=true
		texture.noise=noise
		var gradient := Gradient.new()
		gradient.set_color(0,Color(0.55,0.55,0.55))
		gradient.set_color(1,Color(1,1,1))
		texture.color_ramp=gradient
		mat.albedo_texture=texture
		mat.uv1_triplanar=true
		mat.uv1_scale=Vector3(8,40,3) if key=="wood" else Vector3.ONE*55
	materials[key]=mat
	return mat

static func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, key: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=surface(key)
	node.position=pos
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func bevel(parent: Node3D, pos: Vector3, size: Vector3, key: String, edge: float=0.002) -> MeshInstance3D:
	var b := minf(edge,minf(size.x,minf(size.y,size.z))*0.3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var rings: Array[PackedVector3Array] = []
	for r in range(4):
		var inset := b if r==0 or r==3 else 0.0
		var x := size.x/2-inset
		var y := size.y/2-inset
		var corner := b*0.5 if inset>0 else b
		var z: float = [-size.z/2,-size.z/2+b,size.z/2-b,size.z/2][r]
		var points := PackedVector3Array()
		for v in [Vector2(-x+corner,-y),Vector2(x-corner,-y),Vector2(x,-y+corner),Vector2(x,y-corner),Vector2(x-corner,y),Vector2(-x+corner,y),Vector2(-x,y-corner),Vector2(-x,-y+corner)]:points.append(Vector3(v.x,v.y,z))
		rings.append(points)
	for r in range(3):
		for i in range(8):
			var j := (i+1)%8
			for v in [rings[r][i],rings[r+1][i],rings[r][j],rings[r][j],rings[r+1][i],rings[r+1][j]]:st.add_vertex(v)
	for i in range(1,7):
		for v in [rings[0][0],rings[0][i],rings[0][i+1],rings[3][0],rings[3][i+1],rings[3][i]]:st.add_vertex(v)
	st.generate_normals()
	st.index()
	return mesh_node(parent,st.commit(),pos,key)

static func tube(parent: Node3D, pos: Vector3, radius: float, length: float, key: String, axis: Vector3=Vector3.FORWARD, top: float=-1) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius if top<0 else top
	mesh.bottom_radius=radius
	mesh.height=length
	# Soldier bodies for bots use fewer facets on centimetre-scale parts.
	mesh.radial_segments=clampi(roundi(maxf(mesh.top_radius,radius)*500),6,20) if lite else 20
	mesh.rings=1
	var node := mesh_node(parent,mesh,pos,key)
	node.quaternion=Quaternion(Vector3.UP,axis.normalized())
	return node

static func profile(parent: Node3D, polygon: PackedVector2Array, width: float, key: String) -> MeshInstance3D:
	# Extrusion along X; profile coordinates are (Z,Y).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var indices := Geometry2D.triangulate_polygon(polygon)
	for side in [-1,1]:
		for i in range(0,indices.size(),3):
			var triangle := [indices[i],indices[i+1],indices[i+2]]
			if side>0:triangle.reverse()
			for index in triangle:st.add_vertex(Vector3(side*width/2,polygon[index].y,polygon[index].x))
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		for v in [Vector3(-width/2,a.y,a.x),Vector3(width/2,a.y,a.x),Vector3(-width/2,b.y,b.x),Vector3(-width/2,b.y,b.x),Vector3(width/2,a.y,a.x),Vector3(width/2,b.y,b.x)]:st.add_vertex(v)
	st.generate_normals()
	st.index()
	var node := mesh_node(parent,st.commit(),Vector3.ZERO,key)
	# Profiles include concave guard outlines; render both sides of the thin shell.
	var mat := surface(key).duplicate() as StandardMaterial3D
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=mat
	return node

static func ring(parent: Node3D, pos: Vector3, outer: float, inner: float, key: String) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius=inner
	mesh.outer_radius=outer
	mesh.rings=32
	mesh.ring_segments=8
	var node := mesh_node(parent,mesh,pos,key)
	node.rotation.x=PI/2
	return node

static func marker(parent: Node3D, name: String, pos: Vector3) -> Marker3D:
	var node := parent.get_node_or_null(name) as Marker3D
	if node:
		node.position=pos
		return node
	node=Marker3D.new()
	node.name=name
	node.position=pos
	parent.add_child(node)
	return node

static func group(parent: Node3D, name: String, pos: Vector3=Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name=name
	node.position=pos
	parent.add_child(node)
	return node

static func screw(parent: Node3D, pos: Vector3) -> void:
	tube(parent,pos,0.003,0.0015,"edge",Vector3.RIGHT)
	bevel(parent,pos+Vector3(0.001,0,0),Vector3(0.0008,0.001,0.004),"black",0.0001)

static func hand(parent: Node3D, name: String, pos: Vector3) -> Node3D:
	var root := group(parent,name,pos)
	ellipsoid(root,Vector3.ZERO,Vector3(0.067,0.083,0.036),"glove")
	bevel(root,Vector3(0,0.01,0.019),Vector3(0.052,0.055,0.012),"cloth",0.004)
	for i in range(4):
		var x := -0.024+0.016*i
		tube(root,Vector3(x,0.043,-0.013),0.007,0.032,"glove",Vector3(0,0.6,-0.8))
		tube(root,Vector3(x,0.047,-0.036),0.0065,0.025,"glove",Vector3.FORWARD)
		bevel(root,Vector3(x,0.035,0.012),Vector3(0.011,0.016,0.007),"polymer",0.003)
	tube(root,Vector3(0.038,0.005,-0.008),0.009,0.048,"glove",Vector3(0,-0.5,-0.5))
	tube(root,Vector3(0,-0.066,0.022),0.034,0.058,"cloth",Vector3(0,-0.8,0.6),0.029)
	return root

static func pistol_hand(parent: Node3D, support: bool) -> Node3D:
	# Separate mirrored grips: palms flank the grip, three fingers wrap the front.
	# Coordinates keep both thumbs below the slide's swept volume.
	var origin := Vector3(-0.035,-0.086,0.035) if support else Vector3(0.008,-0.084,0.078)
	var root := group(parent,"LeftHand" if support else "RightHand",origin)
	ellipsoid(root,Vector3.ZERO,Vector3(0.026,0.072,0.047) if support else Vector3(0.055,0.074,0.032),"glove")
	bevel(root,Vector3(-0.012 if support else 0.012,0.005,0.002),Vector3(0.007,0.049,0.035),"cloth",0.003)
	for i in range(3):
		var y := 0.016-i*0.019
		var across := Vector3(0.028,y,-0.049) if support else Vector3(-0.009,y,-0.065)
		tube(root,across,0.0085,0.047,"glove",Vector3.RIGHT)
		tube(root,Vector3(0.006 if support else 0.019,y,-0.027 if support else -0.043),0.0085,0.035,"glove",Vector3.FORWARD)
		tube(root,Vector3(0.047 if support else -0.031,y,-0.038 if support else -0.055),0.007,0.024,"glove",Vector3.BACK)
	# Support thumb points forward along the frame; firing thumb rests outside it.
	if support:
		tube(root,Vector3(0.011,0.044,-0.043),0.008,0.066,"glove",Vector3.FORWARD)
		tube(root,Vector3(0.005,0.027,-0.01),0.011,0.037,"glove",Vector3(0,0.7,-0.7))
	else:
		tube(root,Vector3(-0.035,0.037,-0.035),0.009,0.048,"glove",Vector3.FORWARD)
		var finger := group(root,"TriggerFinger",Vector3(0.023,0.042,-0.068))
		tube(finger,Vector3.ZERO,0.007,0.050,"glove",Vector3.FORWARD)
	# Sleeves follow the wrists down/back, leaving magazine floorplate accessible.
	tube(root,Vector3(-0.008 if support else 0.009,-0.05,0.028),0.029,0.055,"cloth",Vector3(0,-0.6,0.8),0.024)
	return root

static func notch(parent: Node3D, height: float, z: float, width: float=0.023, gap: float=0.0048) -> void:
	# Actual open U notch: no polygon intersects the line of sight.
	var wing := (width-gap)/2
	for side in [-1,1]:
		bevel(parent,Vector3(side*(gap/2+wing/2),height-0.004,z),Vector3(wing,0.008,0.007),"black",0.00045)
	bevel(parent,Vector3(0,height-0.010,z),Vector3(width,0.004,0.007),"black",0.0005)

static func weapon(id: String, rebuild: bool=false) -> Node3D:
	var root := WeaponRig.new()
	root.name="WeaponRig"
	var path := "res://assets/models/"+("ak74m" if id=="ak74" else id)+".scn"
	if not rebuild and ResourceLoader.exists(path):
		var baked: Node3D=load(path).instantiate()
		clear_owners(baked)
		for child in baked.get_children():
			baked.remove_child(child)
			root.add_child(child)
		for key in baked.get_meta_list():root.set_meta(key,baked.get_meta(key))
		baked.free()
	else:
		var magazine := group(root,"Magazine")
		var bolt := group(root,"Bolt")
		if id=="ak74":build_ak(root,magazine,bolt)
		elif id=="m16":build_m16(root,magazine,bolt)
		elif id=="svd":SvdArt.build(root,magazine,bolt)
		elif id=="pkm":PkmArt.build(root,magazine,bolt)
		else:build_pistol(root,magazine,bolt,id)
		WeaponArt.finish(root)
	var height: float=root.get_meta("sight_height")
	var rear_z: float=root.get_meta("rear_z")
	var front_z: float=root.get_meta("front_z")
	marker(root,"RearSight",Vector3(0,height,rear_z))
	marker(root,"FrontSight",Vector3(0,height,front_z))
	marker(root,"Muzzle",Vector3(0,0,float(root.get_meta("muzzle_z"))))
	# The PKM throws its cases out to the left.
	marker(root,"EjectionPort",root.get_meta("ejection_port",Vector3(0.036,0.009,-0.015)))
	var pistol := id in ["pm","m9"]
	var left: Node3D
	if pistol:
		pistol_hand(root,false)
		left=pistol_hand(root,true)
	else:
		hand(root,"RightHand",Vector3(0.017,-0.095,0.145 if id=="svd" else 0.085)).rotation.z=-0.13
		left=hand(root,"LeftHand",root.get_meta("support_hand",Vector3(-0.02,-0.075,-0.32 if id=="svd" else -0.27)))
		left.rotation=Vector3(0.0,0.1,-0.55)
	root.set_meta("left_rest",left.position)
	root.set_meta("left_rotation",left.rotation)
	for side in ["Left","Right"]:
		var arm := CharacterArt.shell(root,[Vector4(-0.13,0.097,0.087,0),Vector4(-0.08,0.093,0.085,0),Vector4(-0.03,0.085,0.079,0),Vector4(0.02,0.078,0.073,0),Vector4(0.08,0.071,0.067,0),Vector4(0.13,0.064,0.060,0)],"cloth",0.025)
		arm.name=side+"Forearm"
	root.configure(id)
	return root

static func build_ak(root: Node3D, mag: Node3D, bolt: Node3D) -> void:
	WeaponArt.build_ak(root,mag,bolt)

static func trigger_guard(root: Node3D, z: float, y: float) -> void:
	bevel(root,Vector3(0,y-0.024,z),Vector3(0.013,0.004,0.045),"steel",0.001)
	for dz in [-0.024,0.024]:bevel(root,Vector3(0,y-0.008,z+dz),Vector3(0.013,0.032,0.004),"steel",0.001)
	bevel(root,Vector3(0,y-0.009,z),Vector3(0.005,0.025,0.004),"black",0.001).rotation.x=-0.4

static func build_m16(root: Node3D, mag: Node3D, bolt: Node3D) -> void:
	root.set_meta("sight_height",0.068)
	root.set_meta("rear_z",0.072)
	root.set_meta("front_z",-0.485)
	root.set_meta("muzzle_z",-0.66)
	root.set_meta("eye_relief",0.145)
	root.set_meta("magwell",Vector3(0,-0.077,-0.07))
	bevel(root,Vector3(0,-0.008,0),Vector3(0.039,0.06,0.23),"black",0.004)
	tube(root,Vector3(0,0.017,-0.005),0.019,0.24,"steel")
	bevel(root,Vector3(0,-0.05,-0.063),Vector3(0.036,0.054,0.065),"black",0.003)
	WeaponArt.loft(root,[Vector4(-0.017,0.13,0.033,0.07),Vector4(-0.03,0.19,0.037,0.09),Vector4(-0.05,0.39,0.038,0.122),Vector4(-0.048,0.425,0.038,0.110)],"gun_polymer",0.25)
	bevel(root,Vector3(0,-0.046,0.42),Vector3(0.04,0.116,0.009),"rubber",0.003)
	bevel(root,Vector3(0,-0.092,0.083),Vector3(0.03,0.106,0.046),"polymer",0.005).rotation.x=-0.3
	for i in range(9):bevel(root,Vector3(0,-0.07-i*0.007,0.104),Vector3(0.029,0.002,0.002),"black",0.0003)
	tube(root,Vector3(0,0,-0.30),0.025,0.29,"polymer",Vector3.FORWARD,0.019)
	for i in range(13):tube(root,Vector3(0,0,-0.17-i*0.021),0.025-i*0.0004,0.003,"black")
	for side in [-1,1]:
		for z in [-0.20,-0.25,-0.30,-0.35,-0.40]:bevel(root,Vector3(side*0.015,0.018,z),Vector3(0.006,0.003,0.009),"black",0.001)
	tube(root,Vector3(0,0,-0.543),0.008,0.20,"steel")
	tube(root,Vector3(0,0,-0.64),0.011,0.04,"black")
	for side in [-1,1]:
		bevel(root,Vector3(side*0.009,0,-0.642),Vector3(0.003,0.013,0.023),"black",0.001)
		# Open triangular front sight tower, not a solid rectangle.
		bevel(root,Vector3(side*0.009,0.028,-0.485),Vector3(0.006,0.056,0.016),"steel",0.001).rotation.z=side*0.30
		bevel(root,Vector3(side*0.009,0.067,-0.485),Vector3(0.002,0.022,0.012),"steel",0.0004).rotation.z=-side*0.15
	bevel(root,Vector3(0,0.062,-0.485),Vector3(0.0028,0.012,0.004),"black",0.0003)
	bevel(root,Vector3(0,0.049,-0.485),Vector3(0.024,0.009,0.018),"steel",0.001)
	# Carry handle has a real opening under the rail; aperture itself is a torus.
	for z in [-0.10,0.07]:bevel(root,Vector3(0,0.04,z),Vector3(0.024,0.035,0.018),"steel",0.002)
	bevel(root,Vector3(0,0.053,-0.015),Vector3(0.023,0.008,0.19),"steel",0.002)
	ring(root,Vector3(0,0.068,0.072),0.0068,0.0045,"black")
	for side in [-1,1]:bevel(root,Vector3(side*0.012,0.067,0.072),Vector3(0.004,0.026,0.022),"steel",0.001)
	tube(root,Vector3(0.020,0.06,0.072),0.009,0.009,"black",Vector3.RIGHT)
	profile(mag,PackedVector2Array([Vector2(-0.095,-0.05),Vector2(-0.043,-0.05),Vector2(-0.042,-0.14),Vector2(-0.063,-0.199),Vector2(-0.119,-0.188),Vector2(-0.102,-0.13)]),0.024,"edge")
	for side in [-1,1]:
		for z in [-0.052,-0.071,-0.09]:bevel(mag,Vector3(side*0.0125,-0.13,z),Vector3(0.002,0.105,0.003),"steel",0.0004)
	bevel(root,Vector3(0.021,0.004,0.004),Vector3(0.003,0.024,0.065),"black",0.001)
	bevel(bolt,Vector3(0.023,0.013,-0.006),Vector3(0.003,0.015,0.048),"edge",0.001)
	var handle := group(root,"ChargingHandle",Vector3(0,0.027,0.113))
	bevel(handle,Vector3.ZERO,Vector3(0.052,0.01,0.016),"steel",0.002)
	for z in [-0.08,0.06]:screw(root,Vector3(0.021,-0.026,z))
	bevel(root,Vector3(0.025,0.009,0.041),Vector3(0.014,0.020,0.022),"gun_metal",0.003).rotation.y=0.45
	tube(root,Vector3(0.029,0.011,0.069),0.006,0.025,"gun_metal",Vector3(0.65,0,0.75))
	tube(root,Vector3(0.039,0.011,0.080),0.008,0.005,"gun_edge",Vector3(0.65,0,0.75))
	bevel(root,Vector3(0.022,-0.024,-0.025),Vector3(0.003,0.009,0.014),"gun_metal",0.001)
	bevel(root,Vector3(-0.022,-0.013,-0.017),Vector3(0.004,0.022,0.010),"gun_metal",0.002)
	for side in [-1,1]:
		for z in [-0.092,0.079]:WeaponArt.pin(root,side*0.021,-0.031,z,0.003)
	bevel(root,Vector3(-0.023,-0.028,0.051),Vector3(0.003,0.006,0.025),"gun_metal",0.001).rotation.x=-0.35
	trigger_guard(root,0.025,-0.058)

static func build_pistol(root: Node3D, mag: Node3D, slide: Node3D, id: String) -> void:
	var pm := id=="pm"
	var length := 0.165 if pm else 0.215
	var rear := 0.058 if pm else 0.078
	var front := -0.085 if pm else -0.119
	var height := 0.029 if pm else 0.034
	root.set_meta("sight_height",height)
	root.set_meta("rear_z",rear)
	root.set_meta("front_z",front)
	root.set_meta("muzzle_z",-length*0.63)
	root.set_meta("eye_relief",0.50)
	root.set_meta("magwell",Vector3(0,-0.115,0.035))
	bevel(root,Vector3(0,-0.014,-0.005),Vector3(0.026,0.014,length*0.8),"steel",0.002)
	bevel(root,Vector3(0,-0.026,0.037),Vector3(0.028,0.033,0.047),"steel",0.003)
	bevel(root,Vector3(0,-0.087,0.039),Vector3(0.031,0.105,0.047),"steel",0.005).rotation.x=-0.22
	for side in [-1,1]:
		bevel(root,Vector3(side*0.018,-0.084,0.041),Vector3(0.007,0.087,0.039),"bakelite" if pm else "polymer",0.004).rotation.x=-0.22
		for row in range(10):bevel(root,Vector3(side*0.022,-0.051-row*0.006,0.040),Vector3(0.001,0.001,0.027),"black",0.0002)
		screw(root,Vector3(side*0.022,-0.075,0.042))
	tube(root,Vector3(0,0,-length*0.34),0.006,length*0.58,"edge")
	tube(root,Vector3(0,0,-length*0.631),0.004,0.001,"black")
	if pm:
		WeaponArt.loft(slide,[Vector4(0.007,-0.0985,0.025,0.026),Vector4(0.008,-0.090,0.029,0.029),Vector4(0.008,0.059,0.029,0.029),Vector4(0.007,0.0665,0.026,0.026)],"gun_metal",0.55)
		bevel(slide,Vector3(0.0142,0.013,-0.015),Vector3(0.001,0.014,0.026),"242927",0.001)
		bevel(slide,Vector3(0.0148,0.008,-0.016),Vector3(0.001,0.003,0.022),"edge",0.0004)
	else:
		# M9 open-top slide exposes the barrel between the rails.
		for side in [-1,1]:bevel(slide,Vector3(side*0.013,0.006,-0.02),Vector3(0.009,0.028,length),"steel",0.003)
		bevel(slide,Vector3(0,0.01,0.041),Vector3(0.033,0.026,0.074),"steel",0.005)
		bevel(slide,Vector3(0,0.008,-0.12),Vector3(0.033,0.023,0.025),"steel",0.003)
	for side in [-1,1]:
		for i in range(7):bevel(slide,Vector3(side*0.016,0.008,rear-0.006-i*0.004),Vector3(0.0015,0.020,0.0017),"edge",0.0003)
		tube(slide,Vector3(side*0.019,0.011,rear-0.012),0.004,0.005,"black",Vector3.RIGHT)
		bevel(slide,Vector3(side*0.02,0.011,rear-0.002),Vector3(0.003,0.004,0.022),"black",0.001)
	notch(slide,height,rear,0.023,0.005)
	bevel(slide,Vector3(0,height-0.0028,front),Vector3(0.0032,0.0056,0.007),"black",0.0004)
	if not pm:
		for x in [-0.005,0.005]:tube(slide,Vector3(x,height-0.003,rear+0.0038),0.001,0.0003,"white",Vector3.BACK)
		tube(slide,Vector3(0,height-0.0027,front+0.0038),0.001,0.0003,"white",Vector3.BACK)
	bevel(root,Vector3(0,0.011,rear+0.012),Vector3(0.009,0.019,0.013),"steel",0.002).rotation.x=0.4
	bevel(mag,Vector3(0,-0.083,0.034),Vector3(0.020,0.112,0.03),"edge",0.002).rotation.x=-0.22
	bevel(mag,Vector3(0,-0.139,0.022),Vector3(0.032,0.007,0.042),"bakelite" if pm else "polymer",0.002)
	for side in [-1,1]:
		bevel(root,Vector3(side*0.0145,-0.008,-0.012),Vector3(0.001,0.0015,length*0.75),"gun_recess",0.0002)
	bevel(root,Vector3(-0.018,-0.022,0.016),Vector3(0.004,0.005,0.033),"gun_metal",0.001)
	WeaponArt.pin(root,-0.018,-0.031,0.036,0.003)
	if not pm:
		tube(root,Vector3(-0.021,-0.043,0.033),0.004,0.003,"gun_edge",Vector3.RIGHT)
		bevel(root,Vector3(-0.020,-0.019,-0.045),Vector3(0.005,0.011,0.020),"gun_metal",0.001)
	WeaponArt.pistol_guard(root)
	bevel(root,Vector3(0,-0.031,-0.005),Vector3(0.004,0.023,0.005),"gun_metal",0.001).rotation.x=-0.3

# Low-poly anatomy stays in separate rigid groups only at animated joints.
static func ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius=0.5
	mesh.height=1.0
	mesh.radial_segments=16
	mesh.rings=8
	if lite:
		mesh.radial_segments=clampi(roundi(maxf(size.x,maxf(size.y,size.z))*160),6,16)
		mesh.rings=clampi(mesh.radial_segments/2,3,8)
	var node := mesh_node(parent,mesh,pos,key)
	node.scale=size
	return node

static func limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, key: String, end_radius: float=-1) -> void:
	tube(parent,(a+b)*0.5,radius,a.distance_to(b),key,a.direction_to(b),end_radius)
	ellipsoid(parent,a,Vector3.ONE*radius*1.9,key)
	ellipsoid(parent,b,Vector3.ONE*(radius if end_radius<0 else end_radius)*1.9,key)

static func merge_rigid(root: Node3D) -> void:
	# Reduce each rigid body part to one mesh per material, preserving child joints.
	var surfaces: Dictionary={}
	for child in root.get_children():
		if not child is MeshInstance3D:continue
		var mat: Material=child.get_active_material(0)
		var key := mat.get_instance_id()
		if not surfaces.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(mat)
			surfaces[key]=st
		var st: SurfaceTool=surfaces[key]
		st.append_from(child.mesh,0,child.transform)
		child.free()
	for st in surfaces.values():
		st.index()
		var node := MeshInstance3D.new()
		node.mesh=st.commit()
		root.add_child(node)

# Short-lived effect particles share one unit cube and one material per colour;
# a fresh mesh and material per particle cost a draw state and an allocation each.
static var particle_mesh: BoxMesh
static func particle(parent: Node3D, pos: Vector3, size: float, color: String) -> MeshInstance3D:
	if particle_mesh==null:
		particle_mesh=BoxMesh.new()
		particle_mesh.size=Vector3.ONE
	var key := "particle_"+color
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color=Color(color)
		mat.roughness=0.8
		materials[key]=mat
	var node := MeshInstance3D.new()
	node.mesh=particle_mesh
	node.material_override=materials[key]
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position=pos
	node.scale=Vector3.ONE*size
	parent.add_child(node)
	return node

# Distance from the active camera; cosmetic detail is skipped far from the viewer.
static func view_distance(node: Node, point: Vector3) -> float:
	var camera := node.get_viewport().get_camera_3d()
	return INF if camera==null else camera.global_position.distance_to(point)

static func soldier(parent: Node3D, for_bot: bool=false) -> Node3D:
	return CharacterArt.build(parent,for_bot)

static func clear_owners(node: Node) -> void:
	for child in node.get_children():
		child.owner=null
		clear_owners(child)
