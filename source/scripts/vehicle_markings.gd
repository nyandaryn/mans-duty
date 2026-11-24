class_name VehicleMarkings
extends RefCounted

# Identification marks of the vehicles. The Russian side: the white «Z»
# painted on the hull sides and on the folded trim vane of the glacis
# (hand-painted, a little dulled by dust, a few millimetres off the plate).
# The flags are not painted: a cloth flies from the vehicle, tied to the
# radio whip at the back of the BMP's turret (it turns with the turret) and
# on a staff clamped to the back of the BM-21's cab. Ours: the flag of
# Ukraine; theirs: the Russian tricolour.
const WHITE := Color("e4e2d6")
# Cloth colours (the flags' own, dulled a little in cloth_mesh).
const RUSSIA := [Color("f4f3ee"),Color("0039a6"),Color("d52b1e")]
const UKRAINE := [Color("0057b7"),Color("ffd700")]
const PAINT := 0.004
# The cloth, 2:3, and where its hoist is tied: on the whip of the BMP's
# turret (BmpArt: the aerial at (0.75, 0.70…2.70, 0.70) of the turret), on the
# staff behind the BM-21's cab.
const FLAG_SIZE := Vector2(0.60,0.40)
const BMP_FLAG := Vector3(0.75,2.27,0.70)
const GRAD_STAFF := Vector3(0.98,2.02,-0.60)
const GRAD_STAFF_TOP := 3.62
const GRAD_FLAG := Vector3(0.98,3.34,-0.60)
# On the TOS-1A's aerial (platform frame), its top 2.55 m over the ring.
const TOS_FLAG := Vector3(1.0,2.28,1.20)
const HEM := Color("c9c6b6")
static var cloths := {}
static var cloth_material: ShaderMaterial

# The cloth streams along the air over it: the wind over the field less the
# vehicle's own travel (VehicleMarkings.flutter). In a light air the fly end
# droops and the waves are slow; in a stream it flies flatter and quicker.
# The hoist (x = 0) stays on the staff; the shadow pass waves the same way.
const CLOTH_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 wind = vec3(2.4, 0.0, 1.9);
uniform float width = 0.6;
instance uniform vec3 travel = vec3(0.0);

void vertex() {
	float x = VERTEX.x;
	float y = VERTEX.y;
	vec3 air_world = wind - travel;
	air_world.y = 0.0;
	float speed = length(air_world);
	vec3 air = transpose(mat3(MODEL_MATRIX)) * air_world;
	vec2 dir = length(air.xz) > 0.001 ? normalize(air.xz) : vec2(1.0, 0.0);
	float lift = clamp(speed / 10.0, 0.15, 1.0);
	float phase = dot(MODEL_MATRIX[3].xz, vec2(1.7, 2.3));
	float t = TIME * (3.0 + 6.0 * lift) + phase;
	float u = x / width;
	float amp = u * (0.06 + 0.05 * lift);
	float k = 9.5;
	float wave = sin(x * k - t) * amp + sin(x * 21.0 - t * 1.7 + y * 8.0) * amp * 0.22;
	float slope = cos(x * k - t) * k * amp;
	float droop = mix(0.22, 0.03, lift) * (1.0 + 0.15 * sin(t * 0.31));
	vec3 along = vec3(dir.x, 0.0, dir.y);
	vec3 side = vec3(-dir.y, 0.0, dir.x);
	float reach = x * mix(0.86, 0.99, lift);
	VERTEX = along * reach + vec3(0.0, y - droop * u * u * width, 0.0) + side * wave;
	NORMAL = normalize(side - along * slope);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.93;
	SPECULAR = 0.15;
	BACKLIGHT = COLOR.rgb * 0.35;
}
"""

static func apply(vehicle: Node3D, friendly: bool) -> void:
 if vehicle is BmpVehicle:bmp(vehicle.art,friendly)
 elif vehicle is GradVehicle:grad(vehicle.art)
 elif vehicle is TosVehicle:tos(vehicle.art,friendly)

# A flag on its hoist at `at` (the middle of the hoist edge): one mesh per
# flag kind and one material for all of them.
static func flag_node(parent: Node3D, at: Vector3, bands: Array) -> MeshInstance3D:
 if cloth_material==null:
  var shader:=Shader.new();shader.code=CLOTH_SHADER
  cloth_material=ShaderMaterial.new();cloth_material.shader=shader
  cloth_material.set_shader_parameter("width",FLAG_SIZE.x)
 var cloth:=MeshInstance3D.new();cloth.name="Flag"
 cloth.mesh=cloth_mesh(bands);cloth.material_override=cloth_material
 cloth.position=at
 cloth.visibility_range_end=600.0
 cloth.set_meta("bands",bands)
 parent.add_child(cloth)
 return cloth

# Bands of the flag on a 12 × 6 grid (the vertex shader bends it), a hem of
# grey tape along the hoist; the colours a little dulled by dust and sun.
static func cloth_mesh(bands: Array) -> ArrayMesh:
 var key:=str(bands)
 if cloths.has(key):return cloths[key]
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 const COLUMNS := 12
 const HEM_WIDTH := 0.025
 var rows:=6/bands.size()
 var band_height:=FLAG_SIZE.y/bands.size()
 for b in range(bands.size()):
  var top:=FLAG_SIZE.y*0.5-band_height*b
  for r in range(rows):
   var y0:=top-band_height*r/rows
   var y1:=top-band_height*(r+1)/rows
   for c in range(COLUMNS+1):
    # The hem first, then the cloth in equal columns.
    var x0:=0.0 if c==0 else HEM_WIDTH+(FLAG_SIZE.x-HEM_WIDTH)*(c-1)/COLUMNS
    var x1:=HEM_WIDTH if c==0 else HEM_WIDTH+(FLAG_SIZE.x-HEM_WIDTH)*c/COLUMNS
    var color: Color=HEM if c==0 else (bands[b] as Color).lerp(Color("8c8873"),0.10)
    color=color.srgb_to_linear()
    for corner in [Vector2(x0,y0),Vector2(x1,y0),Vector2(x1,y1),Vector2(x0,y0),Vector2(x1,y1),Vector2(x0,y1)]:
     st.set_color(color);st.set_normal(Vector3.BACK)
     st.set_uv(Vector2(corner.x/FLAG_SIZE.x,0.5-corner.y/FLAG_SIZE.y))
     st.add_vertex(Vector3(corner.x,corner.y,0))
 st.index()
 var mesh:=st.commit()
 # The shader swings the cloth round its staff and lets it droop.
 mesh.custom_aabb=AABB(Vector3(-FLAG_SIZE.x,-FLAG_SIZE.y*1.2,-FLAG_SIZE.x),Vector3(FLAG_SIZE.x*2,FLAG_SIZE.y*1.8,FLAG_SIZE.x*2))
 cloths[key]=mesh
 return mesh

# The air the cloth feels moves with the vehicle: its travel goes to the
# shader when it has changed by more than half a metre a second.
static func flutter(vehicle: PhysicsBody3D, art: Dictionary) -> void:
 var cloth: MeshInstance3D=art.get("flag")
 if cloth==null:return
 var travel: Vector3=vehicle.linear_velocity if vehicle is RigidBody3D else Vector3.ZERO
 var last: Vector3=art.get("flag_travel",Vector3.ZERO)
 if travel.distance_squared_to(last)<0.25:return
 art["flag_travel"]=travel
 cloth.set_instance_shader_parameter("travel",travel)

# A frame on a surface: x to the right and y up as a man in front of it
# sees them, z out of the surface.
static func frame(origin: Vector3, right: Vector3, up: Vector3) -> Transform3D:
 var x:=right.normalized()
 var y:=up.normalized()
 var z:=x.cross(y).normalized()
 return Transform3D(Basis(x,y,z),origin+z*PAINT)

static func stroke(mesh: ColorMesh, at: Transform3D, center: Vector2, length: float, width: float, angle: float, color: Color) -> void:
 mesh.box(at*Transform3D(Basis(Vector3.BACK,angle),Vector3(center.x,center.y,0)),Vector3(length,width,PAINT),color)

# The letter: two bars and the diagonal from the top right to the bottom
# left, brush-wide strokes.
static func letter_z(mesh: ColorMesh, at: Transform3D, height: float, color: Color) -> void:
 var w:=height*0.78
 var t:=height*0.15
 stroke(mesh,at,Vector2(0,(height-t)*0.5),w,t,0.0,color)
 stroke(mesh,at,Vector2(0,-(height-t)*0.5),w,t,0.0,color)
 var run:=Vector2(w-t,height-t*2.0)
 stroke(mesh,at,Vector2.ZERO,run.length()+t*0.5,t,run.angle(),color)

static func bmp(art: Dictionary, friendly: bool) -> void:
 art["flag"]=flag_node(art.turret,BMP_FLAG,UKRAINE if friendly else RUSSIA)
 if friendly:return
 var hull:=ColorMesh.new()
 for s in [-1.0,1.0]:
  # Hull side between the exhaust and the firing ports.
  letter_z(hull,frame(Vector3(s*1.52,1.27,0.02),Vector3(0,0,-s),Vector3.UP),0.46,WHITE)
 # On the folded trim vane, seen from ahead.
 var slope:=Vector3(0,sin(0.30),cos(0.30))
 var vane:=Vector3(-0.62,BmpArt.glacis_height(-2.55)+0.06+0.02,-2.55)
 letter_z(hull,frame(vane,Vector3.LEFT,slope),0.44,WHITE)
 BmpArt.node(art.root,"Markings",hull)

# A steel staff clamped to the right rear corner of the cab, its foot on the
# frame behind the cab wall, its top a metre over the canvas roof.
static func grad(art: Dictionary) -> void:
 var staff:=ColorMesh.new()
 GradArt.rod(staff,GRAD_STAFF,Vector3(GRAD_STAFF.x,GRAD_STAFF_TOP,GRAD_STAFF.z),0.012,GradArt.STEEL)
 staff.cylinder(GradArt.at(Vector3(GRAD_STAFF.x,GRAD_STAFF_TOP+0.012,GRAD_STAFF.z)),0.018,0.024,6,GradArt.STEEL)
 for y in [2.20,2.55]:
  staff.box(GradArt.at(Vector3(GRAD_STAFF.x,y,-0.635)),Vector3(0.05,0.05,0.07),GradArt.OLIVE_DARK)
 GradArt.node(art.root,"FlagStaff",staff)
 art["flag"]=flag_node(art.root,GRAD_FLAG,UKRAINE)

# TOS-1A: the flag on the whip aerial at the rear right of the platform; on
# the enemy's vehicle white Z on both sides of the package, between the
# first and second ribs, clear of the cable trough.
static func tos(art: Dictionary, friendly: bool) -> void:
 art["flag"]=flag_node(art.platform,TOS_FLAG,UKRAINE if friendly else RUSSIA)
 if friendly:return
 var paint:=ColorMesh.new()
 var half:=TosArt.COLUMNS*TosArt.PITCH*0.5+0.08
 for s in [-1.0,1.0]:letter_z(paint,frame(Vector3(s*half,0.58,-2.4),Vector3(0,0,-s),Vector3.UP),0.42,WHITE)
 BmpArt.node(art.cradle,"Markings",paint)
