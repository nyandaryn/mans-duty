class_name ImpactEffects
extends Node3D

# What a bullet throws up where it strikes, after slow-motion footage of
# rifle rounds into the materials of a town and a field:
# - soil: a spurt of earth and grit along the line of fire, a column of dust
#   that hangs a second or two (the fall of shot an observer watches for);
# - concrete and brick: a burst of powder off the face and chips flying,
#   brick red; now and then a spark from a steel core; a round through a wall
#   blows a wider cone of spall out of the far side;
# - wood: splinters, light inside the weathered board, little dust;
# - steel: a flash and a spray of sparks thrown off along the ricochet;
# - glass: a shower of glittering shards on along the bullet;
# - a man: a puff of dust and fibres off his clothes at the entry, and where
#   a rifle round goes through, a mist of blood behind him.
# Three multimeshes (dust, fragments, sparks), one draw call each. A particle
# is written once when it is thrown, its start in the instance transform
# (velocity, birth and life, size, position: 32-bit floats), and the shader
# flies it on from there; the CPU never touches it again. Its own random
# numbers: the battle's global ones stay as they were.
const DUST_CAPACITY := 2048
const CHIP_CAPACITY := 2048
const SPARK_CAPACITY := 512
const G := 9.81
# From the eye: all of it near, fewer pieces further out, only the cloud of
# the strike (and the sparks off steel) far off, nothing beyond.
const NEAR := 35.0
const MIDDLE := 120.0
const FAR := 400.0
const MARK_RANGE := 150.0
# Holes kept in the world, the oldest go first.
const MARKS_KEPT := 120
const RIFLES := ["ak74","m16","svd","pkm"]
# Hole left in the surface: texture, colour of the material inside (fresh
# concrete is lighter than its weathered face, a brick redder), diameter.
const MARKS := {
	"concrete":["crater","cfc9bd",0.05],"brick":["crater","b8694a",0.06],"wood":["splinter","cdb27f",0.03],
	"steel":["splash","b4b7ba",0.032],"glass":["star","eef3f4",0.15],"earth":["soil","3a3127",0.07],
	"rubber":["hole","151515",0.022],"fabric":["hole","1d1c19",0.022]}
const COLORS := {"concrete":"8f8c84","brick":"8a4a35","wood":"6d5a43","steel":"4c5248","glass":"c9d6da","earth":"6b5b45","rubber":"222222","fabric":"6b6a55"}

const DUST_SHADER := """shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, depth_draw_never, diffuse_lambert_wrap, specular_disabled, shadows_disabled;
uniform float now;
uniform vec3 wind;
uniform sampler2D puff_texture : source_color, filter_linear_mipmap, repeat_disable;
varying float fade;
varying float above;
varying float soften;
void vertex() {
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec3 timing = MODEL_MATRIX[1].xyz;
	vec3 shape = MODEL_MATRIX[2].xyz;
	vec3 p0 = MODEL_MATRIX[3].xyz;
	float age = now - timing.x;
	float life = max(timing.y, 0.0001);
	float alive = step(0.0, age) * step(age, timing.y);
	float t = clamp(age, 0.0, life);
	float k = max(INSTANCE_CUSTOM.x, 0.05);
	vec3 c = p0 + v0 * ((1.0 - exp(-k * t)) / k) + vec3(0.0, INSTANCE_CUSTOM.y * t, 0.0) + wind * (t * INSTANCE_CUSTOM.z);
	float u = t / life;
	float grown = 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u);
	float size = mix(shape.x, shape.y, grown) * alive;
	// The cloud rests on the ground and thins out into it: a facing quad
	// through the ground would show a straight edge.
	c.y = max(c.y, timing.z + size * 0.2);
	float angle = shape.z * 6.2831853 + INSTANCE_CUSTOM.w * t;
	vec2 corner = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * VERTEX.xy;
	VERTEX = (VIEW_MATRIX * vec4(c, 1.0)).xyz + vec3(corner * size, 0.0);
	above = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y - timing.z;
	soften = max(size * 0.3, 0.01);
	NORMAL = normalize(mix(mat3(VIEW_MATRIX) * vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), 0.55));
	fade = smoothstep(0.0, 0.06, u) * (1.0 - u) * (1.0 - 0.5 * u);
}
void fragment() {
	vec4 puff = texture(puff_texture, UV);
	ALBEDO = COLOR.rgb * mix(0.82, 1.08, puff.r);
	ALPHA = clamp(puff.a * COLOR.a * fade * smoothstep(0.0, soften, above), 0.0, 1.0);
}
"""

const CHIP_SHADER := """shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, shadows_disabled;
uniform float now;
varying float shine;
vec3 turn(vec3 v, vec3 axis, float angle) {
	return v * cos(angle) + cross(axis, v) * sin(angle) + axis * dot(axis, v) * (1.0 - cos(angle));
}
void vertex() {
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec3 timing = MODEL_MATRIX[1].xyz;
	vec3 dims = MODEL_MATRIX[2].xyz;
	vec3 p0 = MODEL_MATRIX[3].xyz;
	float age = now - timing.x;
	float alive = step(0.0, age) * step(age, timing.y);
	float t = clamp(age, 0.0, timing.z);
	float k = max(INSTANCE_CUSTOM.x, 0.05);
	float kt = k * t;
	float f = kt < 0.02 ? t * (1.0 - 0.5 * kt + kt * kt / 6.0) : (1.0 - exp(-kt)) / k;
	float h = kt < 0.02 ? t * t * (0.5 - kt / 6.0 + kt * kt / 24.0) : (t - f) / k;
	vec3 p = p0 + v0 * f - vec3(0.0, 9.81, 0.0) * h;
	float a = INSTANCE_CUSTOM.z * 6.2831853;
	float b = INSTANCE_CUSTOM.w * 3.1415927;
	vec3 axis = vec3(sin(b) * cos(a), cos(b), sin(b) * sin(a));
	float angle = a * 1.7 + INSTANCE_CUSTOM.y * t;
	float shrink = clamp((timing.y - age) / 0.25, 0.0, 1.0);
	vec3 local = turn(VERTEX * dims, axis, angle) * (alive * shrink);
	VERTEX = (VIEW_MATRIX * vec4(p + local, 1.0)).xyz;
	NORMAL = normalize(mat3(VIEW_MATRIX) * turn(NORMAL, axis, angle));
	shine = COLOR.a;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = mix(0.92, 0.1, shine);
	SPECULAR = mix(0.3, 1.0, shine);
}
"""

const SPARK_SHADER := """shader_type spatial;
render_mode skip_vertex_transform, unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float now;
varying float heat;
varying float blob;
void vertex() {
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec3 timing = MODEL_MATRIX[1].xyz;
	vec3 shape = MODEL_MATRIX[2].xyz;
	vec3 p0 = MODEL_MATRIX[3].xyz;
	float age = now - timing.x;
	float life = max(timing.y, 0.0001);
	float alive = step(0.0, age) * step(age, timing.y);
	float t = clamp(age, 0.0, life);
	float k = max(INSTANCE_CUSTOM.x, 0.05);
	float kt = k * t;
	float e = exp(-kt);
	float f = kt < 0.02 ? t * (1.0 - 0.5 * kt + kt * kt / 6.0) : (1.0 - e) / k;
	float h = kt < 0.02 ? t * t * (0.5 - kt / 6.0 + kt * kt / 24.0) : (t - f) / k;
	vec3 g = vec3(0.0, -9.81, 0.0);
	vec3 p = p0 + v0 * f + g * h;
	p.y = max(p.y, timing.z + 0.01);
	vec3 v = v0 * e + g * f;
	vec3 pv = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	vec3 vv = mat3(VIEW_MATRIX) * v;
	vec2 along = length(vv.xy) > 0.001 ? normalize(vv.xy) : vec2(1.0, 0.0);
	vec2 across = vec2(-along.y, along.x);
	float u = t / life;
	if (shape.z > 0.0) {
		float s = shape.z * (0.6 + 0.8 * u) * alive;
		VERTEX = pv + vec3(VERTEX.xy * s, 0.0);
		blob = 1.0;
	} else {
		float streak = length(vv.xy) * shape.y + shape.x;
		VERTEX = pv + vec3(along * ((VERTEX.x - 0.5) * streak * alive) + across * (VERTEX.y * shape.x * alive), 0.0);
		blob = 0.0;
	}
	heat = (1.0 - u) * COLOR.a;
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float edge = blob > 0.5 ? max(0.0, 1.0 - dot(q, q)) : (1.0 - q.y * q.y) * mix(0.25, 1.0, UV.x);
	vec3 hot = mix(vec3(1.0, 0.3, 0.05), vec3(1.0, 0.62, 0.26), clamp(heat * 1.2, 0.0, 1.0));
	ALBEDO = hot * COLOR.rgb * 1.15;
	ALPHA = clamp(edge * heat * 1.4, 0.0, 1.0);
}
"""

var game: Node3D
var clock := 0.0
var rng := RandomNumberGenerator.new()
var dust: MultiMeshInstance3D
var chips: MultiMeshInstance3D
var sparks: MultiMeshInstance3D
var cursor := {"dust":0,"chip":0,"spark":0}
var spawned := {"dust":0,"chip":0,"spark":0}
# The last strike (for tests): material, detail level, what was thrown.
var last: Dictionary={}
# Tests switch it on: every particle thrown is written down.
var record := false
var thrown: Array[Dictionary]=[]
static var mark_mesh: QuadMesh
static var dust_texture: ImageTexture
static var mark_materials: Dictionary={}
static var tones: Dictionary={}

func _ready() -> void:
	rng.seed=7151
	BlastEffect.prepare_textures()
	var quad := QuadMesh.new()
	dust=layer("ImpactDust",quad,DUST_CAPACITY,DUST_SHADER)
	(dust.material_override as ShaderMaterial).set_shader_parameter("puff_texture",soft_texture())
	chips=layer("ImpactChips",BoxMesh.new(),CHIP_CAPACITY,CHIP_SHADER)
	sparks=layer("ImpactSparks",QuadMesh.new(),SPARK_CAPACITY,SPARK_SHADER)

func layer(label: String, mesh: Mesh, capacity: int, code: String) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name=label
	var shader := Shader.new()
	shader.code=code
	var material := ShaderMaterial.new()
	material.shader=shader
	var multimesh := MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_colors=true
	multimesh.use_custom_data=true
	multimesh.mesh=mesh
	multimesh.instance_count=capacity
	var bounds := AABB(Vector3(-8000,-1000,-8000),Vector3(16000,9000,16000))
	multimesh.custom_aabb=bounds
	node.multimesh=multimesh
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb=bounds
	node.top_level=true
	add_child(node)
	blank(multimesh)
	return node

# Every slot empty: zero size, never drawn.
func blank(multimesh: MultiMesh) -> void:
	var data := PackedFloat32Array()
	data.resize(multimesh.instance_count*20)
	multimesh.buffer=data

func clear() -> void:
	for node in [dust,chips,sparks]:
		if is_instance_valid(node):blank(node.multimesh)
	cursor={"dust":0,"chip":0,"spark":0}
	thrown.clear()
	last={}

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not game.running or game.paused:return
	clock+=delta
	for node in [dust,chips,sparks]:(node.material_override as ShaderMaterial).set_shader_parameter("now",clock)
	if is_instance_valid(game.ballistics):(dust.material_override as ShaderMaterial).set_shader_parameter("wind",game.ballistics.wind)

# --- what the shaders do, for the CPU (landing, tests) ----------------------
# Position after t seconds: thrown at `velocity`, slowed by air (drag, 1/s)
# and falling.
static func travel(at: Vector3, velocity: Vector3, drag: float, t: float) -> Vector3:
	var k := maxf(drag,0.05)
	var kt := k*t
	var f := t*(1.0-0.5*kt+kt*kt/6.0) if kt<0.02 else (1.0-exp(-kt))/k
	var h := t*t*(0.5-kt/6.0+kt*kt/24.0) if kt<0.02 else (t-f)/k
	return at+velocity*f-Vector3(0,G,0)*h

# When it comes down to `bottom` (at most `limit`).
static func fall(y: float, rise: float, drag: float, bottom: float, limit: float) -> float:
	if y<=bottom and rise<=0.0:return 0.0
	var k := maxf(drag,0.05)
	var apex := log(1.0+maxf(rise,0.0)*k/G)/k
	if travel(Vector3(0,y,0),Vector3(0,rise,0),drag,limit).y>bottom:return limit
	var low := apex
	var high := limit
	for i in range(28):
		var middle := (low+high)*0.5
		if travel(Vector3(0,y,0),Vector3(0,rise,0),drag,middle).y>bottom:low=middle
		else:high=middle
	return high

# --- throwing -----------------------------------------------------------------
func slot(kind: String, capacity: int) -> int:
	var i: int=cursor[kind]
	cursor[kind]=(i+1)%capacity
	spawned[kind]+=1
	return i

func puff(at: Vector3, velocity: Vector3, sizes: Vector2, life: float, color: Color, drag: float, rise: float, bottom: float, drift: float=0.7) -> void:
	var i := slot("dust",DUST_CAPACITY)
	dust.multimesh.set_instance_transform(i,Transform3D(Basis(velocity,Vector3(clock,life,bottom),Vector3(sizes.x,sizes.y,rng.randf())),at))
	dust.multimesh.set_instance_color(i,color)
	dust.multimesh.set_instance_custom_data(i,Color(drag,rise,drift,rng.randf_range(-1.2,1.2)))
	if record:thrown.append({"layer":"dust","at":at,"velocity":velocity,"sizes":sizes,"life":life,"color":color,"drag":drag,"rise":rise,"bottom":bottom})

func chip(at: Vector3, velocity: Vector3, dims: Vector3, life: float, color: Color, drag: float, spin: float, bottom: float, shine: float=0.0, on_ground: bool=false) -> void:
	var land := fall(at.y,velocity.y,drag,bottom,life)
	# Thrown off the ground: it comes down on the ground where it lands.
	if on_ground and is_instance_valid(game) and is_instance_valid(game.district) and land<life:
		var ground: float=game.district.ground_height(travel(at,velocity,drag,land))
		land=fall(at.y,velocity.y,drag,ground,life)
	var i := slot("chip",CHIP_CAPACITY)
	chips.multimesh.set_instance_transform(i,Transform3D(Basis(velocity,Vector3(clock,life,land),dims),at))
	chips.multimesh.set_instance_color(i,Color(color.r,color.g,color.b,shine))
	chips.multimesh.set_instance_custom_data(i,Color(drag,spin,rng.randf(),rng.randf()))
	if record:thrown.append({"layer":"chip","at":at,"velocity":velocity,"dims":dims,"life":life,"land":land,"color":color,"drag":drag})

func spark(at: Vector3, velocity: Vector3, life: float, width: float, drag: float, bottom: float) -> void:
	var i := slot("spark",SPARK_CAPACITY)
	sparks.multimesh.set_instance_transform(i,Transform3D(Basis(velocity,Vector3(clock,life,bottom),Vector3(width,rng.randf_range(0.008,0.014),0.0)),at))
	sparks.multimesh.set_instance_color(i,Color(1,1,1,1))
	sparks.multimesh.set_instance_custom_data(i,Color(drag,0,0,0))
	if record:thrown.append({"layer":"spark","at":at,"velocity":velocity,"life":life})

func flash(at: Vector3, size: float, life: float) -> void:
	var i := slot("spark",SPARK_CAPACITY)
	sparks.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.ZERO,Vector3(clock,life,at.y-40.0),Vector3(0.0,0.0,size)),at))
	sparks.multimesh.set_instance_color(i,Color(1,0.95,0.85,1))
	sparks.multimesh.set_instance_custom_data(i,Color(1,0,0,0))
	if record:thrown.append({"layer":"flash","at":at,"size":size,"life":life})

# A direction within `angle` (radians) of `axis`.
func cone(axis: Vector3, angle: float) -> Vector3:
	var a := axis.normalized()
	var side := a.cross(Vector3.UP if absf(a.y)<0.95 else Vector3.RIGHT).normalized()
	var up := a.cross(side)
	var spread := angle*sqrt(rng.randf())
	var around := rng.randf()*TAU
	return (a*cos(spread)+(side*cos(around)+up*sin(around))*sin(spread)).normalized()

func many(base: float, s: float) -> int:
	return maxi(0,roundi(base*s))

# --- what was hit ---------------------------------------------------------------
static func substance(surface: Object) -> String:
	if surface==null or not is_instance_valid(surface):return "concrete"
	if surface.has_meta("terrain"):return "earth"
	var kind: String=surface.get_meta("ballistic_material","concrete")
	return kind if COLORS.has(kind) else "concrete"

func surface_color(surface: Object, where: Vector3, kind: String) -> Color:
	if surface!=null and is_instance_valid(surface):
		if surface.has_meta("terrain") and is_instance_valid(game) and is_instance_valid(game.district):
			var terrain: Object=game.district.terrain
			if terrain!=null and terrain.has_method("surface_color"):return terrain.surface_color(Vector2(where.x,where.z))
		if surface.has_meta("surface_color"):return surface.get_meta("surface_color")
	return Color(COLORS[kind])

# The energy of the round on the surface, as a size: an AK round at short
# range is 1, a pistol round half that, a PKM or SVD round half as much again.
static func strength(energy: float) -> float:
	if energy<0.0:return 1.0
	return clampf(pow(energy/1400.0,0.4),0.45,3.0)

func detail_at(where: Vector3) -> int:
	var seen := Models.view_distance(self,where)
	if not is_finite(seen):return 3
	return 3 if seen<=NEAR else (2 if seen<=MIDDLE else (1 if seen<=FAR else 0))

func ground_below(where: Vector3) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(where,where+Vector3.DOWN*40,1))
	return float(hit.position.y) if not hit.is_empty() else where.y-40.0

# A bullet on a surface: `normal` out of it, `direction` the bullet's way,
# `energy` its energy there (J), `exit` where it comes out of the far side.
func strike(where: Vector3, normal: Vector3, surface: Object, direction: Vector3=Vector3.ZERO, energy: float=-1.0, exit: bool=false, weapon: String="") -> void:
	var n := normal.normalized()
	if n.length_squared()<0.5:return
	var d := direction.normalized() if direction.length_squared()>0.01 else -n
	var kind := substance(surface)
	var detail := detail_at(where)
	var s := strength(energy)
	var before := spawned.duplicate()
	if detail>0:
		var tone := surface_color(surface,where,kind)
		var bottom := ground_below(where+n*0.05) if detail>=2 else where.y-2.0
		var on_ground: bool=surface!=null and is_instance_valid(surface) and surface.has_meta("terrain")
		# Off the face, then the way a ricochet would go.
		var bounce := (d-2.0*d.dot(n)*n).normalized()
		var grazing := 1.0-absf(d.dot(n))
		var at := where+n*0.01
		match kind:
			"earth":earth(at,n,bounce,grazing,tone,s,detail,bottom,on_ground)
			"concrete","brick":masonry(at,n,d,bounce,tone,s,detail,bottom,exit,kind=="brick",weapon)
			"wood":wood(at,n,d,tone,s,detail,bottom,exit)
			"steel":steel(at,n,bounce,grazing,tone,s,detail,bottom)
			"glass":glass(at,n,d,s,detail,bottom)
			_:soft(at,n,tone,s,detail,bottom,kind=="rubber")
	last={"material":kind,"detail":detail,"strength":s,"exit":exit,"puffs":spawned.dust-before.dust,"chips":spawned.chip-before.chip,"sparks":spawned.spark-before.spark}

# Soil: a spurt of earth up and on along the line of fire, a column of dust
# over it and a low cloud round the hole.
func earth(at: Vector3, n: Vector3, bounce: Vector3, grazing: float, tone: Color, s: float, detail: int, bottom: float, on_ground: bool) -> void:
	var soil := tone.lerp(Color("5a4936"),0.55)
	var dusty := soil.lerp(Color("a39a86"),0.45)
	var axis := (n*1.3+bounce*0.9*grazing).normalized()
	var reach := sqrt(s)
	var column: int=[0,2,4,many(7,s)][detail]
	for k in range(1 if detail==1 else 2):
		puff(at,axis*rng.randf_range(0.4,1.2)*reach,Vector2(0.15,rng.randf_range(0.55,0.75))*reach,rng.randf_range(1.4,2.2),Color(dusty.r,dusty.g,dusty.b,0.9),3.0,-0.03,bottom)
	for k in range(column):
		puff(at,cone(axis,0.34)*rng.randf_range(1.0,4.6)*reach,Vector2(0.15,rng.randf_range(0.4,0.65))*reach,rng.randf_range(0.9,1.7),Color(dusty.r,dusty.g,dusty.b,rng.randf_range(0.7,0.9)),3.2,-0.05,bottom)
	if detail>=2:
		for k in range(2):
			var side := Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized()
			puff(at,(n*0.3+side)*rng.randf_range(0.4,1.1),Vector2(0.12,rng.randf_range(0.45,0.65))*reach,rng.randf_range(1.6,2.4),Color(dusty.r,dusty.g,dusty.b,0.38),2.5,0.02,bottom)
		for k in range(many(4.0 if detail==2 else 10.0,s)):
			var size := rng.randf_range(0.006,0.02)
			chip(at,cone(axis,0.45)*rng.randf_range(2.0,5.0)*reach,Vector3(size,size*rng.randf_range(0.6,1.0),size*rng.randf_range(0.6,1.0)),2.2,soil.darkened(rng.randf_range(0.0,0.25)),0.25,rng.randf_range(6,22),bottom,0.0,on_ground)
	if detail==3:
		for k in range(many(8,s)):
			var grit := rng.randf_range(0.003,0.006)
			chip(at,cone(axis,0.35)*rng.randf_range(4.0,8.0)*reach,Vector3.ONE*grit,1.8,soil.darkened(rng.randf_range(0.0,0.3)),0.4,rng.randf_range(10,30),bottom,0.0,on_ground)

# Concrete and brick: powder off the face, chips, and now and then a spark
# from a steel core. Out of the far side the spall comes in a wider cone.
func masonry(at: Vector3, n: Vector3, d: Vector3, bounce: Vector3, tone: Color, s: float, detail: int, bottom: float, exit: bool, brick: bool, weapon: String) -> void:
	var powder := tone.lerp(Color("b4745a") if brick else Color("d3cec3"),0.55)
	var stone := tone.lerp(Color("a5553b") if brick else Color("c4beb2"),0.45)
	var axis := d if exit else (n+bounce*0.35).normalized()
	var more := 1.6 if exit else 1.0
	var reach := sqrt(s)
	# The body of the cloud where it struck, then puffs bursting out of it.
	for k in range(1 if detail==1 else 2):
		puff(at,axis*rng.randf_range(0.3,0.9)*reach,Vector2(0.14,rng.randf_range(0.5,0.7))*reach*more,rng.randf_range(1.2,1.8),Color(powder.r,powder.g,powder.b,0.95),3.0,-0.06,bottom)
	for k in range([0,2,5,many(9.0 if brick else 8.0,s*more)][detail]):
		puff(at,cone(axis,0.8)*rng.randf_range(1.4,5.5)*reach,Vector2(0.1,rng.randf_range(0.34,0.55))*reach,rng.randf_range(0.7,1.4),Color(powder.r,powder.g,powder.b,rng.randf_range(0.75,0.95)),5.0,-0.12,bottom)
	if detail>=2:
		for k in range(many(3.0 if detail==2 else 9.0,s*more)):
			chip(at,cone(axis,0.65)*rng.randf_range(4.0,12.0)*reach,Vector3(rng.randf_range(0.004,0.014),rng.randf_range(0.003,0.01),rng.randf_range(0.004,0.012)),2.4,stone.darkened(rng.randf_range(0.0,0.22)),0.3,rng.randf_range(10,35),bottom)
	if detail>=2 and not exit and weapon in RIFLES and rng.randf()<(0.12 if brick else 0.3):
		for k in range(rng.randi_range(1,3)):
			spark(at,cone(bounce,0.4)*rng.randf_range(8,16),rng.randf_range(0.06,0.14),0.006,2.5,bottom)

# Wood: splinters, light inside the board, and a little dust; longer ones
# torn out of the far side.
func wood(at: Vector3, n: Vector3, d: Vector3, tone: Color, s: float, detail: int, bottom: float, exit: bool) -> void:
	var fresh := Color("c9a874")
	var axis := d if exit else (n-d*0.4).normalized()
	var longer := 1.6 if exit else 1.0
	for k in range([0,1,2,3][detail]):
		puff(at,cone(axis,0.6)*rng.randf_range(0.8,2.5),Vector2(0.04,rng.randf_range(0.12,0.18)),rng.randf_range(0.5,0.8),Color(fresh.r,fresh.g,fresh.b,0.4),6.0,-0.05,bottom)
	if detail>=2:
		for k in range(many((3.0 if detail==2 else 7.0)*(2.0 if exit else 1.0),s)):
			chip(at,cone(axis,0.55)*rng.randf_range(3.0,8.0),Vector3(rng.randf_range(0.002,0.004),rng.randf_range(0.0015,0.003),rng.randf_range(0.02,0.06)*longer),2.0,fresh.lerp(tone,rng.randf_range(0.0,0.4)),1.2,rng.randf_range(15,40),bottom)

# Steel: a flash where it strikes and sparks thrown off along the ricochet;
# a puff of the jacket and the paint, flakes of the paint.
func steel(at: Vector3, n: Vector3, bounce: Vector3, grazing: float, tone: Color, s: float, detail: int, bottom: float) -> void:
	var axis := (bounce+n*0.3).normalized()
	var spread := lerpf(1.0,0.35,grazing)
	flash(at,rng.randf_range(0.12,0.2)*sqrt(s),0.05)
	for k in range([0,2,6,many(12,s)][detail]):
		var fast := rng.randf()<0.35
		spark(at,cone(axis,spread)*(rng.randf_range(12,20) if fast else rng.randf_range(4,10)),rng.randf_range(0.15,0.45) if fast else rng.randf_range(0.08,0.22),rng.randf_range(0.004,0.008),2.2,bottom)
	if detail>=2:
		for k in range(2):
			puff(at,cone(n,0.6)*rng.randf_range(0.6,1.8),Vector2(0.03,0.14),0.35,Color(0.54,0.54,0.52,0.45),7.0,0.0,bottom)
	if detail==3:
		for k in range(3):
			chip(at,cone(n,0.8)*rng.randf_range(1.5,4.0),Vector3(0.004,0.004,0.0008),1.2,tone,3.0,30.0,bottom)

# Glass: shards on along the bullet, some back off the pane, glittering.
func glass(at: Vector3, n: Vector3, d: Vector3, s: float, detail: int, bottom: float) -> void:
	if detail>=2:
		for k in range(many(5.0 if detail==2 else 12.0,s)):
			var way := cone(d,0.5)*rng.randf_range(2.0,6.0) if rng.randf()<0.7 else cone(n,0.7)*rng.randf_range(1.0,3.0)
			chip(at,way,Vector3(rng.randf_range(0.008,0.03),0.002,rng.randf_range(0.008,0.025)),2.5,Color("dfe8ea"),0.6,rng.randf_range(10,30),bottom,1.0)
	puff(at,n*0.6,Vector2(0.04,0.12),0.4,Color(0.9,0.93,0.94,0.25),6.0,0.0,bottom)

# Rubber, cloth and the rest: a small puff and a few bits.
func soft(at: Vector3, n: Vector3, tone: Color, s: float, detail: int, bottom: float, rubber: bool) -> void:
	var color := Color("2d2b29") if rubber else tone.lightened(0.15)
	for k in range([0,1,2,3][detail]):
		puff(at,cone(n,0.6)*rng.randf_range(0.8,2.0),Vector2(0.04,0.15),rng.randf_range(0.4,0.7),Color(color.r,color.g,color.b,0.5),6.0,0.0,bottom)
	if detail==3:
		for k in range(3):
			chip(at,cone(n,0.7)*rng.randf_range(1.0,3.0),Vector3(0.006,0.004,0.002) if rubber else Vector3(0.01,0.0012,0.008),1.0,Color("181818") if rubber else tone,2.5 if rubber else 5.0,25.0,bottom)

# A drone hit: bits of its plastic shell and a spark off the board.
func drone_hit(at: Vector3, direction: Vector3) -> void:
	var detail := detail_at(at)
	if detail<2:return
	var d := direction.normalized() if direction.length_squared()>0.01 else Vector3.DOWN
	for k in range(4):
		chip(at,cone(d,0.8)*rng.randf_range(2.0,6.0),Vector3(rng.randf_range(0.006,0.018),0.002,rng.randf_range(0.006,0.014)),2.0,Color("3a3c3d"),0.8,25.0,at.y-40.0)
	puff(at,d*0.8,Vector2(0.04,0.18),0.4,Color(0.45,0.45,0.44,0.4),6.0,0.0,at.y-40.0)
	for k in range(2):spark(at,cone(d,0.7)*rng.randf_range(4,9),0.12,0.006,2.0,at.y-40.0)

# --- a man hit ------------------------------------------------------------------
# The cloth the round goes into first: dust and fibres off it, and blood
# where a rifle round comes out of his back or his limb. Not his own body on
# the player's screen.
func body_hit(actor: Node3D, area: Area3D, point: Vector3, normal: Vector3, direction: Vector3, wound: Dictionary, weapon: String, energy: float, exit_at: Variant=null) -> void:
	if is_instance_valid(game) and actor==game.player:return
	var detail := detail_at(point)
	if detail==0:return
	var d := direction.normalized() if direction.length_squared()>0.01 else -normal
	var n := normal.normalized() if normal.length_squared()>0.1 else -d
	var kind: String=wound.get("kind","penetrating")
	var plate: bool=area!=null and String(area.get_meta("zone",""))=="plate"
	var cloth := clothing(area,point,d)
	var bottom := ground_below(point) if detail>=2 else point.y-2.0
	var s := clampf(energy,0.3,1.0)*(1.3 if weapon in ["svd","pkm"] else 1.0)
	var before := spawned.duplicate()
	var at := point+n*0.01
	if not cloth.skin:
		var tone: Color=cloth.tone
		var dusty := tone.lerp(Color("bdb6a5"),0.5)
		var axis := (n*0.8-d*0.6).normalized()
		var bigger := 1.4 if plate else 1.0
		for k in range([0,1,3,6][detail]+(2 if plate and detail>=2 else 0)):
			puff(at,cone(axis,0.6)*rng.randf_range(1.2,3.5)*s,Vector2(0.06,rng.randf_range(0.22,0.32))*bigger,rng.randf_range(0.35,0.6),Color(dusty.r,dusty.g,dusty.b,1.0),9.0,0.0,bottom)
		if plate and detail>=2:
			for k in range(2):puff(at,cone(axis,0.5)*rng.randf_range(1.0,2.5),Vector2(0.04,0.2),0.5,Color(0.72,0.71,0.67,0.5),8.0,0.0,bottom)
		if detail==3:
			for k in range(3):
				chip(at,cone(axis,0.8)*rng.randf_range(1.0,3.0),Vector3(rng.randf_range(0.006,0.012),0.0012,rng.randf_range(0.006,0.012)),0.7,tone,5.0,25.0,bottom)
	var blood := Color("5a0d0b")
	if kind!="blunt":
		# A little back spatter at the entry.
		if detail>=2:
			for k in range(2):
				chip(at,cone(n,0.6)*rng.randf_range(0.8,2.0),Vector3.ONE*rng.randf_range(0.003,0.005),1.0,blood,1.0,0.0,bottom,0.6)
		var through: bool=weapon in RIFLES and energy>0.3 and kind not in ["graze","blunt"]
		if through:
			var out: Vector3=(exit_at if exit_at is Vector3 else point+d*0.22)+d*0.03
			var head := 1.5 if kind=="fatal_head" else 1.0
			# Fine drops in the light: a pinkish red mist.
			for k in range(roundi([0,1,3,6][detail]*head)):
				puff(out,cone(d,0.35)*rng.randf_range(2.0,5.5),Vector2(0.05,rng.randf_range(0.24,0.36)),rng.randf_range(0.35,0.6),Color(0.62,0.13,0.11,0.75),7.0,-0.25,bottom)
			if detail>=2:
				for k in range(roundi((4 if detail==2 else 9)*head)):
					chip(out,cone(d,0.45)*rng.randf_range(2.0,6.0),Vector3.ONE*rng.randf_range(0.003,0.007),1.2,blood,1.0,0.0,bottom,0.7)
		elif kind=="graze" and detail>=2:
			puff(at,cone(d,0.5)*rng.randf_range(1.0,2.5),Vector2(0.04,0.16),0.4,Color(0.62,0.13,0.11,0.55),7.0,-0.2,bottom)
	last={"material":"body","detail":detail,"cloth":cloth,"kind":kind,"puffs":spawned.dust-before.dust,"chips":spawned.chip-before.chip,"sparks":spawned.spark-before.spark}

# Where a round that went in at `point` comes out of him: on through every
# hit box along its way that touches the last (an arm, then the chest), out
# of the far side of the last one.
static func exit_through(actor: Object, area: Area3D, point: Vector3, d: Vector3) -> Variant:
	var areas: Array=[area]
	if actor!=null and is_instance_valid(actor) and actor.get("hitboxes") is Array:areas=actor.hitboxes
	var spans: Array=[]
	for box in areas:
		if not is_instance_valid(box) or box.get_child_count()==0:continue
		var holder := box.get_child(0) as CollisionShape3D
		if holder==null or not holder.shape is BoxShape3D:continue
		var to_box := holder.global_transform.affine_inverse()
		var half: Vector3=(holder.shape as BoxShape3D).size*0.5
		var bounds := AABB(-half,half*2.0)
		var from := point-d*0.6
		var beyond := point+d*1.6
		var entry: Variant=bounds.intersects_segment(to_box*from,to_box*beyond)
		var leave: Variant=bounds.intersects_segment(to_box*beyond,to_box*from)
		if entry==null or leave==null:continue
		spans.append([(holder.global_transform*Vector3(entry)-point).dot(d),(holder.global_transform*Vector3(leave)-point).dot(d)])
	if spans.is_empty():return null
	spans.sort_custom(func(a,b):return a[0]<b[0])
	var far := -INF
	for span in spans:
		if float(span[1])<0.0:continue
		if far==-INF:
			if float(span[0])>0.05:break
			far=span[1]
		elif float(span[0])<=far+0.08:far=maxf(far,span[1])
	return point+d*far if far>0.0 else null

# The first piece of his clothing, kit or skin along the bullet's way into
# the hit box, and its colour.
func clothing(area: Area3D, point: Vector3, d: Vector3) -> Dictionary:
	var result := {"tone":Color("6b6a55"),"skin":false,"material":""}
	if area==null or not is_instance_valid(area) or area.get_parent()==null:return result
	var from := point-d*0.3
	var to := point+d*0.06
	var best := INF
	for mesh: MeshInstance3D in area.get_parent().find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or not mesh.is_visible_in_tree():continue
		var material := mesh.get_active_material(0)
		if material==null or not wearable(material.resource_name):continue
		var inverse := mesh.global_transform.affine_inverse()
		var entry: Variant=mesh.get_aabb().intersects_segment(inverse*from,inverse*to)
		if entry==null:continue
		var distance := (mesh.global_transform*Vector3(entry)).distance_to(from)
		if distance<best:
			best=distance
			result={"tone":tone_of(material),"skin":material.resource_name=="character_skin","material":material.resource_name}
	return result

static func wearable(label: String) -> bool:
	return label.begins_with("uniform") or (label.begins_with("vest_") and label!="vest_hardware") or label.begins_with("gear_#") or label in ["cloth","character_skin"]

# The cloth's own colour: a camouflage by the mean of its palette.
static func tone_of(material: Material) -> Color:
	if tones.has(material):return tones[material]
	var color := Color("6b6a55")
	if material is StandardMaterial3D:
		var m: StandardMaterial3D=material
		color=m.albedo_color
		var pattern := ""
		if m.resource_name.begins_with("uniform_"):pattern=m.resource_name.substr(8)
		elif m.resource_name=="vest_mm14":pattern="ua_pixel"
		elif m.resource_name=="vest_emr":pattern="rf_digital"
		if Wardrobe.PALETTES.has(pattern):
			var mean := Vector3.ZERO
			var weights := [0.2,0.3,0.3,0.2]
			for i in range(4):
				var c := Color(Wardrobe.PALETTES[pattern][i])
				mean+=Vector3(c.r,c.g,c.b)*weights[i]
			color=Color(color.r*mean.x*0.97,color.g*mean.y*0.97,color.b*mean.z*0.97)
		elif m.albedo_texture!=null:color=color*Color(0.775,0.775,0.775)
	color.a=1.0
	tones[material]=color
	return color

# A soft cloud of dust: thick in the middle, thinning out to nothing, lumpy.
static func soft_texture() -> ImageTexture:
	if dust_texture!=null:return dust_texture
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed=2903
	noise.frequency=0.06
	noise.fractal_octaves=4
	for y in range(64):
		for x in range(64):
			var u := (float(x)+0.5)/32.0-1.0
			var v := (float(y)+0.5)/32.0-1.0
			var r := sqrt(u*u+v*v)
			var lump := noise.get_noise_2d(float(x),float(y))*0.5+0.5
			var alpha := exp(-r*r*3.0)*(0.35+0.65*lump)*(1.0-smoothstep(0.75,1.0,r))
			var shade := 0.8+0.2*lump
			image.set_pixel(x,y,Color(shade,shade,shade,clampf(alpha*1.25,0.0,1.0)))
	image.generate_mipmaps()
	dust_texture=ImageTexture.create_from_image(image)
	return dust_texture

# --- the hole -------------------------------------------------------------------
static func mark_size(kind: String, exit: bool, energy: float) -> float:
	var spec: Array=MARKS.get(kind,MARKS.concrete)
	var size: float=spec[2]
	if exit:size*=2.0 if kind in ["concrete","brick"] else (1.8 if kind=="wood" else (0.5 if kind=="steel" else 1.0))
	return size*clampf(strength(energy),0.6,2.5)

static func mark_material(kind: String, exit: bool) -> StandardMaterial3D:
	var spec: Array=MARKS.get(kind,MARKS.concrete)
	var pattern: String=spec[0]
	var tint: String=spec[1]
	if kind=="steel" and exit:
		pattern="hole"
		tint="2a2b2c"
	var key := pattern+tint
	if mark_materials.has(key):return mark_materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_texture=mark_texture(pattern)
	material.albedo_color=Color(tint)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold=0.5
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.roughness=0.35 if pattern=="splash" else 0.95
	material.metallic=0.6 if pattern=="splash" else 0.0
	mark_materials[key]=material
	return material

static func mark_texture(pattern: String) -> ImageTexture:
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed=4417+pattern.length()
	noise.frequency=0.09
	var cracks: Array[float]=[]
	var crack_rng := RandomNumberGenerator.new()
	crack_rng.seed=91
	for i in range(9):cracks.append(crack_rng.randf()*TAU)
	for y in range(64):
		for x in range(64):
			var u := (float(x)+0.5)/32.0-1.0
			var v := (float(y)+0.5)/32.0-1.0
			var r := sqrt(u*u+v*v)
			var angle := atan2(v,u)
			var ragged := noise.get_noise_2d(cos(angle)*24.0,sin(angle)*24.0)
			var grain := noise.get_noise_2d(float(x)*1.7,float(y)*1.7)
			var value := 0.0
			var alpha := 0.0
			match pattern:
				"crater":
					if r<0.2+0.05*ragged:
						value=0.1;alpha=1.0
					elif r<0.72+0.26*ragged:
						value=(0.85+0.15*grain)*(0.6+0.4*smoothstep(0.2,0.5,r));alpha=1.0
				"splinter":
					var e := sqrt(u*u/0.81+v*v/0.12)
					if r<0.2:
						value=0.12;alpha=1.0
					elif e<0.85+0.3*ragged:
						value=0.75+0.25*noise.get_noise_2d(float(x)*0.4,float(y)*6.0);alpha=1.0
				"splash":
					if r<0.24:
						value=0.42+0.08*grain;alpha=1.0
					elif r<0.55+0.15*ragged:
						value=1.0;alpha=1.0
					elif r<0.95 and ragged>0.25:
						value=0.7;alpha=1.0
				"hole":
					if r<0.35:
						value=0.06;alpha=1.0
					elif r<0.5+0.08*ragged:
						value=0.5;alpha=1.0
				"star":
					if r<0.08:
						value=0.25;alpha=1.0
					else:
						for i in range(cracks.size()):
							var off := absf(wrapf(angle-cracks[i],-PI,PI))
							if off*r<0.018 and r<0.55+0.45*float(i%3)/2.0:
								value=1.0;alpha=1.0
						if absf(r-0.3-0.03*ragged)<0.014 and ragged>-0.1:
							value=1.0;alpha=1.0
				"soil":
					if r<0.25+0.1*ragged:
						value=0.25;alpha=1.0
					elif r<0.95 and grain+0.6-r>0.0:
						value=0.6;alpha=1.0
			image.set_pixel(x,y,Color(value,value,value,alpha))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
