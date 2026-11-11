class_name WeaponArt
extends RefCounted

# Original game-ready geometry. Dimensions in metres; muzzle points along -Z.
# Cross-section lofts retain smooth machined curves and hard end caps.
static func loft(parent: Node3D, stations: Array[Vector4], material: String, exponent: float=0.55) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var rings: Array[PackedVector3Array]=[]
	for station in stations:
		var ring := PackedVector3Array()
		for i in range(32):
			var angle := TAU*i/32
			var x := cos(angle)
			var y := sin(angle)
			ring.append(Vector3(signf(x)*pow(absf(x),exponent)*station.z*0.5,station.x+signf(y)*pow(absf(y),exponent)*station.w*0.5,station.y))
		rings.append(ring)
	for r in range(rings.size()-1):
		for i in range(32):
			var j := (i+1)%32
			for v in [rings[r][i],rings[r+1][i],rings[r][j],rings[r][j],rings[r+1][i],rings[r+1][j]]:st.add_vertex(v)
	st.set_smooth_group(-1)
	for i in range(1,31):
		for v in [rings[0][0],rings[0][i],rings[0][i+1],rings[-1][0],rings[-1][i+1],rings[-1][i]]:st.add_vertex(v)
	st.generate_normals()
	st.index()
	return Models.mesh_node(parent,st.commit(),Vector3.ZERO,material)

static func pin(parent: Node3D, side: float, y: float, z: float, radius: float=0.0024) -> void:
	Models.tube(parent,Vector3(side,y,z),radius,0.0012,"gun_edge",Vector3.RIGHT)

static func build_ak(root: Node3D, mag: Node3D, bolt: Node3D) -> void:
	root.set_meta("sight_height",0.055)
	root.set_meta("rear_z",-0.115)
	root.set_meta("front_z",-0.53)
	root.set_meta("muzzle_z",-0.635)
	root.set_meta("eye_relief",0.30)
	root.set_meta("magwell",Vector3(0,-0.095,-0.06))
	# Stamped receiver, folded lower seam, machined trunnions and rounded cover.
	Models.bevel(root,Vector3(0,-0.012,0.004),Vector3(0.038,0.060,0.25),"gun_metal",0.0012)
	Models.bevel(root,Vector3(0,-0.042,0.006),Vector3(0.040,0.003,0.246),"gun_edge",0.0005)
	loft(root,[Vector4(0.014,-0.118,0.035,0.020),Vector4(0.018,-0.108,0.040,0.029),Vector4(0.018,0.105,0.040,0.029),Vector4(0.012,0.126,0.032,0.020)],"gun_metal",0.85)
	for z in [-0.065,0.012,0.088]:
		loft(root,[Vector4(0.018,z-0.001,0.0406,0.0296),Vector4(0.018,z+0.001,0.0406,0.0296)],"gun_edge",0.85)
	Models.bevel(root,Vector3(0,0.019,0.129),Vector3(0.014,0.011,0.009),"gun_edge",0.001)
	# Ejection-port recess, moving bolt carrier and charging handle.
	Models.bevel(root,Vector3(0.0195,0.006,-0.020),Vector3(0.001,0.019,0.077),"gun_recess",0.001)
	Models.bevel(bolt,Vector3(0.0205,0.004,-0.010),Vector3(0.004,0.013,0.056),"gun_edge",0.001)
	Models.tube(bolt,Vector3(0.032,0.005,0.014),0.0037,0.025,"gun_metal",Vector3.RIGHT)
	Models.bevel(bolt,Vector3(0.045,0.005,0.014),Vector3(0.008,0.009,0.013),"gun_edge",0.002)
	for side in [-1,1]:
		for yz in [Vector2(-0.022,-0.105),Vector2(-0.026,-0.085),Vector2(-0.017,0.088),Vector2(-0.027,0.112),Vector2(-0.003,0.10)]:pin(root,side*0.0197,yz.x,yz.y)
		Models.bevel(root,Vector3(side*0.0196,-0.018,-0.057),Vector3(0.001,0.014,0.027),"gun_recess",0.003)
		Models.bevel(root,Vector3(side*0.0202,-0.018,-0.057),Vector3(0.001,0.010,0.023),"gun_metal",0.002)
	# Safety lever follows the right side, with an offset thumb shelf.
	Models.bevel(root,Vector3(0.021,-0.008,0.036),Vector3(0.0025,0.009,0.095),"gun_metal",0.001).rotation.x=-0.24
	pin(root,0.023,0.003,0.084,0.005)
	Models.bevel(root,Vector3(0.024,-0.018,-0.012),Vector3(0.007,0.006,0.012),"gun_edge",0.001)
	# Optics mounting rail on the left receiver.
	Models.bevel(root,Vector3(-0.022,-0.014,0.004),Vector3(0.006,0.015,0.112),"gun_metal",0.001)
	for z in [-0.038,0.045]:pin(root,-0.026,-0.014,z,0.003)
	# Folding polymer stock, hinge, inset strengthening panel, butt plate.
	Models.tube(root,Vector3(0,0,0.136),0.009,0.065,"gun_metal",Vector3.UP)
	loft(root,[Vector4(-0.015,0.14,0.028,0.063),Vector4(-0.022,0.17,0.031,0.079),Vector4(-0.057,0.39,0.033,0.130),Vector4(-0.057,0.414,0.032,0.116)],"gun_polymer",0.25)
	for side in [-1,1]:
		Models.bevel(root,Vector3(side*0.016,-0.043,0.303),Vector3(0.001,0.019,0.118),"gun_recess",0.004).rotation.x=-0.14
		Models.bevel(root,Vector3(side*0.0168,-0.044,0.303),Vector3(0.001,0.013,0.111),"gun_polymer",0.003).rotation.x=-0.14
	Models.bevel(root,Vector3(0,-0.055,0.417),Vector3(0.035,0.119,0.008),"gun_rubber",0.003)
	for y in range(16):Models.bevel(root,Vector3(0,-0.107+y*0.007,0.422),Vector3(0.027,0.0018,0.001),"gun_polymer",0.0002)
	var swivel := Models.ring(root,Vector3(-0.024,-0.035,0.174),0.012,0.008,"gun_edge")
	swivel.rotation.y=PI/2
	# Pistol grip: tapered silhouette and recessed textured side panels.
	Models.profile(root,PackedVector2Array([Vector2(0.057,-0.04),Vector2(0.089,-0.04),Vector2(0.124,-0.138),Vector2(0.116,-0.150),Vector2(0.078,-0.144)]),0.028,"gun_polymer")
	for side in [-1,1]:
		Models.bevel(root,Vector3(side*0.0145,-0.101,0.091),Vector3(0.001,0.067,0.024),"gun_grip",0.001).rotation.x=-0.25
	# Lower and upper ribbed handguards, retaining ferrules and vents.
	loft(root,[Vector4(-0.012,-0.325,0.036,0.038),Vector4(-0.017,-0.306,0.046,0.049),Vector4(-0.017,-0.172,0.047,0.050),Vector4(-0.012,-0.151,0.038,0.040)],"gun_polymer",0.62)
	loft(root,[Vector4(0.025,-0.303,0.029,0.025),Vector4(0.025,-0.285,0.033,0.029),Vector4(0.025,-0.168,0.034,0.030)],"gun_polymer",0.85)
	for side in [-1,1]:
		for y in [-0.027,-0.019,-0.011]:Models.bevel(root,Vector3(side*0.0235,y,-0.235),Vector3(0.0015,0.002,0.105),"gun_recess",0.0003)
		for z in [-0.18,-0.195,-0.21,-0.225,-0.24,-0.255]:Models.bevel(root,Vector3(side*0.019,0.009,z),Vector3(0.005,0.006,0.007),"gun_recess",0.001)
	for z in [-0.318,-0.156]:Models.bevel(root,Vector3(0,-0.002,z),Vector3(0.048,0.066,0.006),"gun_metal",0.002)
	# Barrel, gas tube, gas block, cleaning rod and front sight pedestal.
	Models.tube(root,Vector3(0,0,-0.447),0.0077,0.267,"gun_metal")
	Models.tube(root,Vector3(0,0.027,-0.332),0.0085,0.066,"gun_metal")
	for z in [-0.31,-0.346]:Models.tube(root,Vector3(0,0.027,z),0.0093,0.006,"gun_edge")
	Models.profile(root,PackedVector2Array([Vector2(-0.368,-0.008),Vector2(-0.344,-0.008),Vector2(-0.344,0.028),Vector2(-0.357,0.033),Vector2(-0.369,0.009)]),0.022,"gun_metal")
	Models.tube(root,Vector3(0,-0.018,-0.435),0.0022,0.264,"gun_edge")
	Models.bevel(root,Vector3(0,-0.016,-0.527),Vector3(0.012,0.010,0.034),"gun_metal",0.001)
	Models.tube(root,Vector3(0,0,-0.534),0.011,0.027,"gun_metal")
	# Open sight pedestal; space between uprights stays empty.
	for side in [-1,1]:Models.bevel(root,Vector3(side*0.0075,0.021,-0.53),Vector3(0.004,0.031,0.016),"gun_metal",0.001).rotation.z=side*0.12
	Models.bevel(root,Vector3(0,0.035,-0.53),Vector3(0.019,0.006,0.017),"gun_metal",0.001)
	for side in [-1,1]:Models.bevel(root,Vector3(side*0.009,0.049,-0.53),Vector3(0.0025,0.029,0.013),"gun_metal",0.0005).rotation.z=side*-0.22
	Models.bevel(root,Vector3(0,0.048,-0.53),Vector3(0.0026,0.014,0.004),"gun_metal",0.0002)
	pin(root,0.012,0.025,-0.53,0.0028)
	# Two-chamber brake, discrete side ports, open bore at the muzzle.
	Models.tube(root,Vector3(0,0,-0.582),0.0102,0.022,"gun_metal")
	Models.tube(root,Vector3(0,0,-0.609),0.012,0.035,"gun_metal")
	for side in [-1,1]:
		for z in [-0.601,-0.619]:Models.bevel(root,Vector3(side*0.0118,0,z),Vector3(0.001,0.012,0.009),"gun_recess",0.002)
	Models.ring(root,Vector3(0,0,-0.635),0.0105,0.0032,"gun_edge")
	Models.tube(root,Vector3(0,0,-0.631),0.0033,0.001,"gun_recess")
	# Rear tangent sight, slider and individual graduation marks.
	Models.bevel(root,Vector3(0,0.032,-0.125),Vector3(0.021,0.014,0.061),"gun_metal",0.001)
	Models.bevel(root,Vector3(0,0.042,-0.13),Vector3(0.014,0.003,0.049),"gun_edge",0.0005)
	for z in [-0.146,-0.141,-0.136,-0.131]:Models.bevel(root,Vector3(-0.004,0.044,z),Vector3(0.006,0.0003,0.0006),"gun_recess",0.0001)
	Models.notch(root,0.055,-0.115)
	Models.bevel(root,Vector3(0,0.041,-0.143),Vector3(0.026,0.008,0.009),"gun_metal",0.001)
	# Curved polymer 30-round magazine with pressed ribs and floor plate.
	var shape := PackedVector2Array()
	for i in range(13):
		var t := i/12.0
		shape.append(Vector2(-0.028-0.048*t*t,-0.042-0.185*t))
	for i in range(12,-1,-1):
		var t := i/12.0
		shape.append(Vector2(-0.086-0.048*t*t,-0.042-0.185*t))
	Models.profile(mag,shape,0.025,"gun_polymer")
	for side in [-1,1]:
		for i in range(9):
			var t := (i+1)/10.0
			Models.bevel(mag,Vector3(side*0.013,-0.042-0.185*t,-0.057-0.048*t*t),Vector3(0.002,0.0025,0.048),"gun_polymer",0.0006).rotation.x=-0.35*t
	Models.bevel(mag,Vector3(0,-0.227,-0.105),Vector3(0.029,0.006,0.062),"gun_metal",0.001).rotation.x=-0.30
	Models.bevel(root,Vector3(0,-0.051,-0.026),Vector3(0.013,0.016,0.014),"gun_metal",0.001).rotation.x=-0.15
	Models.trigger_guard(root,0.03,-0.058)

static func finish(root: Node3D) -> void:
	# Uniform dark phosphate/bluing, machined edges and textured polymer across guns.
	for child in root.get_children():
		if child is MeshInstance3D:
			var current: Material=child.material_override
			for pair in [["steel","gun_metal"],["black","gun_metal"],["edge","gun_edge"],["polymer","gun_polymer"],["rubber","gun_rubber"]]:
				if current!=null and current.resource_name==pair[0]:child.material_override=Models.surface(pair[1])
		elif child is Node3D and child.name not in ["LeftHand","RightHand"]:finish(child)
	Models.merge_rigid(root)

static func pistol_guard(root: Node3D) -> void:
	var points := [Vector3(0,-0.020,0.010),Vector3(0,-0.025,-0.020),Vector3(0,-0.031,-0.035),Vector3(0,-0.044,-0.038),Vector3(0,-0.056,-0.030),Vector3(0,-0.059,-0.010),Vector3(0,-0.055,0.010),Vector3(0,-0.044,0.020)]
	for i in range(points.size()-1):
		var a: Vector3=points[i]
		var b: Vector3=points[i+1]
		Models.tube(root,(a+b)*0.5,0.0028,a.distance_to(b)+0.001,"gun_metal",a.direction_to(b))
