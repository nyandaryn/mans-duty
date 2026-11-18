class_name CrowdArt
extends RefCounted

# Low-detail soldier for distant crowds in the large battle: about 1.5k
# triangles in five rigid parts that follow the detailed skeleton nodes.
# Vertex colours replace materials (sRGB); alpha 1 marks camouflage
# fabric, which the shader samples from the faction's own uniform texture.
# The silhouette uses the same garment cross-sections as CharacterArt.
const PARTS := ["upper","thigh_left","thigh_right","shin_left","shin_right"]
const AIM_WEIGHT := 0.6
static var cache: Dictionary = {}
static var shader: Shader
static var materials: Dictionary = {}

const SHADER_CODE := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D camo : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 tri_pos;
varying vec3 tri_weight;
void vertex() {
	tri_pos = VERTEX * 3.0;
	vec3 w = pow(abs(NORMAL), vec3(4.0));
	tri_weight = w / max(w.x + w.y + w.z, 0.0001);
}
void fragment() {
	vec3 fabric = texture(camo, tri_pos.zy).rgb * tri_weight.x
		+ texture(camo, tri_pos.xz).rgb * tri_weight.y
		+ texture(camo, tri_pos.xy).rgb * tri_weight.z;
	ALBEDO = mix(COLOR.rgb, fabric, COLOR.a);
	ROUGHNESS = 0.93;
}
"""

static func material(outfit: String) -> ShaderMaterial:
	if materials.has(outfit):return materials[outfit]
	if shader==null:
		shader=Shader.new()
		shader.code=SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("camo",Wardrobe.fabric(outfit).albedo_texture)
	materials[outfit]=mat
	return mat

static func tint(hex: String) -> Color:
	# Stored as authored (sRGB): the Compatibility renderer linearises vertex colours.
	var color := Color(hex)
	color.a=0
	return color

const CAMO := Color(1,1,1,1)

class Builder:
	var st := SurfaceTool.new()
	var group := 1
	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rings of (height, full width, full depth, forward offset), as CharacterArt.shell.
	func shell(xf: Transform3D, stations: Array, color: Color, segments: int=8, square: float=1.0, phase: float=0.0, smooth: bool=true) -> void:
		st.set_smooth_group(group if smooth else -1)
		group+=1
		st.set_color(color)
		var ordered := stations.duplicate()
		ordered.sort_custom(func(a,b):return a.x<b.x)
		var rings: Array[PackedVector3Array]=[]
		for station in ordered:
			var ring := PackedVector3Array()
			for i in range(segments):
				var angle := TAU*(i+phase)/segments
				var x := signf(cos(angle))*pow(absf(cos(angle)),square)
				var z := signf(sin(angle))*pow(absf(sin(angle)),square)
				ring.append(xf*Vector3(x*station.y*0.5,station.x,z*station.z*0.5+station.w))
			rings.append(ring)
		for r in range(rings.size()-1):
			for i in range(segments):
				var j := (i+1)%segments
				for vertex in [rings[r][i],rings[r][j],rings[r+1][i],rings[r][j],rings[r+1][j],rings[r+1][i]]:st.add_vertex(vertex)
		for i in range(1,segments-1):
			for vertex in [rings[0][0],rings[0][i+1],rings[0][i]]:st.add_vertex(vertex)
			for vertex in [rings[-1][0],rings[-1][i],rings[-1][i+1]]:st.add_vertex(vertex)
	func box(xf: Transform3D, center: Vector3, size: Vector3, color: Color) -> void:
		# A four-sided ring rotated 45 degrees and widened by sqrt(2) is a box.
		var k := sqrt(2.0)
		shell(xf*Transform3D(Basis.IDENTITY,center),[Vector4(-size.y*0.5,size.x*k,size.z*k,0),Vector4(size.y*0.5,size.x*k,size.z*k,0)],color,4,1.0,0.5,false)
	func ellipsoid(xf: Transform3D, center: Vector3, size: Vector3, color: Color, segments: int=8, rings: int=5) -> void:
		var stations: Array=[]
		for k in range(rings+1):
			var t := -0.5+float(k)/rings
			var r := sqrt(maxf(0,1-4*t*t))
			stations.append(Vector4(t*size.y,size.x*r,size.z*r,0))
		shell(xf*Transform3D(Basis.IDENTITY,center),stations,color,segments)
	# A tapered tube from a to b.
	func tube(xf: Transform3D, a: Vector3, b: Vector3, radius_a: float, radius_b: float, color: Color, segments: int=6) -> void:
		var axis := Basis(Quaternion(Vector3.UP,a.direction_to(b)))
		var length := a.distance_to(b)
		shell(xf*Transform3D(axis,a),[Vector4(0,radius_a*2,radius_a*2,0),Vector4(length,radius_b*2,radius_b*2,0)],color,segments)
	func commit() -> ArrayMesh:
		st.generate_normals()
		st.index()
		return st.commit()

static func sleeve(b: Builder, xf: Transform3D, end: Vector3, upper: bool) -> void:
	var length := end.length()
	var radius := 0.083 if upper else 0.064
	var stations: Array=[]
	for i in range(4):
		var t := float(i)/3
		var taper := lerpf(1.0,0.72 if upper else 0.64,t)
		var bulge := sin(t*PI)*0.08
		stations.append(Vector4(t*length,radius*2*(taper+bulge),radius*1.8*(taper+bulge),0))
	b.shell(xf*Transform3D(Basis(Quaternion(Vector3.UP,end.normalized())),Vector3.ZERO),stations,CAMO,6)

# Parts for one faction: friendly soldiers carry yellow tape, enemies red.
static func parts(friendly: bool) -> Array[ArrayMesh]:
	var key := "ua" if friendly else "rf"
	if cache.has(key):return cache[key]
	var result: Array[ArrayMesh]=[upper(friendly)]
	for side in [-1,1]:result.append(thigh(side))
	for side in [-1,1]:result.append(shin(side))
	cache[key]=result
	return result

static func upper(friendly: bool) -> ArrayMesh:
	var b := Builder.new()
	var root := Transform3D.IDENTITY
	var gear := tint("#555f49")
	b.shell(root,[Vector4(0.83,0.32,0.24,0.028),Vector4(0.90,0.37,0.285,0.027),Vector4(1.00,0.34,0.26,0.023),Vector4(1.11,0.345,0.25,0.018),Vector4(1.24,0.40,0.28,0.018),Vector4(1.36,0.44,0.27,0.017),Vector4(1.43,0.42,0.23,0.012),Vector4(1.49,0.15,0.14,0.01)],CAMO,10)
	b.shell(root,[Vector4(0.937,0.365,0.29,0.018),Vector4(0.981,0.365,0.29,0.018)],tint("#3e4537"),10)
	for side in [-1,1]:
		b.shell(root,[Vector4(1.045,0.30,0.065,side*0.145),Vector4(1.09,0.34,0.085,side*0.145),Vector4(1.34,0.32,0.071,side*0.145),Vector4(1.42,0.235,0.055,side*0.135)],gear,8)
	for x in [-0.13,0.13]:b.box(root,Vector3(x,1.437,0.013),Vector3(0.052,0.038,0.276),tint("#59644e"))
	for x in [-0.109,0.0,0.109]:b.box(root,Vector3(x,1.115,-0.207),Vector3(0.096,0.181,0.068),tint("#62674e"))
	b.box(root,Vector3(0.22,1.015,0.018),Vector3(0.105,0.16,0.13),tint("#62674e"))
	b.box(root,Vector3(-0.218,0.99,-0.018),Vector3(0.06,0.14,0.15),tint("#62674e"))
	# Head and helmet at the average ready pose of an alerted soldier.
	var head := Transform3D(Basis.from_euler(Vector3(-0.036,0,-0.14*AIM_WEIGHT)),Vector3(0.04*AIM_WEIGHT,1.50-0.07*AIM_WEIGHT,-0.02*AIM_WEIGHT))
	b.ellipsoid(head,Vector3(0,0.125,-0.055),Vector3(0.18,0.27,0.215),tint("#bf9274"),8,5)
	b.shell(head*Transform3D(Basis.IDENTITY,Vector3(0,0,-0.05)),[Vector4(0.150,0.226,0.257,0.009),Vector4(0.195,0.240,0.269,0.006),Vector4(0.235,0.220,0.249,0.009),Vector4(0.268,0.164,0.191,0.01),Vector4(0.287,0.03,0.04,0.013)],CAMO,8)
	# Rifle and both arms reaching it, posed with the same two-bone solver.
	var rifle_position := Vector3(lerpf(0.14,0.11,AIM_WEIGHT),1.27+AIM_WEIGHT*0.25,lerpf(-0.28,-0.34,AIM_WEIGHT))
	var rifle := Transform3D(Basis.IDENTITY,rifle_position)
	var metal := tint("#444a4e")
	var polymer := tint("#303333")
	b.box(rifle,Vector3(0,0.0,-0.06),Vector3(0.046,0.07,0.30),metal)
	b.box(rifle,Vector3(0,0.002,-0.30),Vector3(0.052,0.058,0.19),polymer)
	b.box(rifle,Vector3(0,0.012,-0.50),Vector3(0.02,0.026,0.27),metal)
	b.box(rifle,Vector3(0,-0.025,0.24),Vector3(0.04,0.085,0.30),polymer)
	b.box(rifle,Vector3(0,-0.075,0.055),Vector3(0.03,0.095,0.04),polymer)
	b.box(rifle*Transform3D(Basis(Vector3.RIGHT,-0.25),Vector3(0,-0.11,-0.15)),Vector3.ZERO,Vector3(0.03,0.17,0.07),tint("#3b3b36"))
	var model := Node3D.new()
	var tape := tint("#c2a331" if friendly else "#a83e32")
	for side in ["Left","Right"]:
		var arm := Node3D.new()
		arm.name=side+"Arm"
		arm.position=Vector3(-0.218,1.38,-0.065) if side=="Left" else Vector3(0.218,1.38,0.015)
		var forearm := Node3D.new()
		forearm.name="Forearm"
		arm.add_child(forearm)
		model.add_child(arm)
		var elbow: Vector3=CharacterArt.UPPER_LEFT if side=="Left" else CharacterArt.UPPER_RIGHT
		var wrist: Vector3=CharacterArt.LOWER_LEFT if side=="Left" else CharacterArt.LOWER_RIGHT
		forearm.position=elbow
		var target := rifle_position+(Vector3(-0.035,-0.045,-0.265) if side=="Left" else Vector3(0.012,-0.09,0.085))
		CharacterArt.pose_arm(model,side,target)
		var arm_xf := arm.transform
		var fore_xf := arm_xf*forearm.transform
		sleeve(b,arm_xf,elbow,true)
		sleeve(b,fore_xf,wrist,false)
		b.ellipsoid(fore_xf,wrist+Vector3(0,-0.012,-0.02),Vector3(0.08,0.062,0.11),tint("#777962"),6,4)
		var axis := elbow.normalized()
		b.tube(arm_xf,elbow*0.48-axis*0.032,elbow*0.48+axis*0.032,0.079,0.079,tape,8)
	model.free()
	return b.commit()

static func thigh(side: int) -> ArrayMesh:
	var b := Builder.new()
	var root := Transform3D.IDENTITY
	b.shell(root,[Vector4(0.03,0.185,0.224,0.015),Vector4(-0.07,0.188,0.216,0.012),Vector4(-0.18,0.176,0.196,0.014),Vector4(-0.27,0.155,0.173,0.015),Vector4(-0.36,0.14,0.156,0.015)],CAMO,8)
	b.box(root,Vector3(side*0.082,-0.18,0.02),Vector3(0.026,0.15,0.12),CAMO)
	return b.commit()

static func shin(_side: int) -> ArrayMesh:
	var b := Builder.new()
	var root := Transform3D.IDENTITY
	var boot := tint("#4c4b40")
	b.shell(root,[Vector4(0.025,0.145,0.154,0),Vector4(-0.08,0.15,0.16,0.012),Vector4(-0.18,0.136,0.144,0.015),Vector4(-0.27,0.113,0.121,0.008),Vector4(-0.355,0.103,0.110,0)],CAMO,8)
	b.ellipsoid(root,Vector3(0,-0.018,-0.075),Vector3(0.126,0.143,0.038),tint("#555e4d"),6,3)
	# The boot at the knee's rest angle: the detailed foot only counter-rotates
	# a few degrees to stay level, invisible at crowd distances.
	var foot := Transform3D(Basis.IDENTITY,Vector3(0,-0.36,0))
	b.shell(foot,[Vector4(-0.07,0.118,0.145,0.012),Vector4(0.13,0.106,0.130,0.008)],boot,8,0.72)
	b.ellipsoid(foot,Vector3(0,-0.048,-0.068),Vector3(0.132,0.087,0.235),boot,6,4)
	b.shell(foot,[Vector4(-0.073,0.138,0.265,-0.047),Vector4(-0.09,0.139,0.266,-0.047)],tint("#191c1d"),6,0.7)
	return b.commit()
