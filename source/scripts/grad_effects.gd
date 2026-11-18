class_name GradEffects
extends MultiMeshInstance3D

# Smoke of the 9M22U motor (it burns 1.9 s, so the trail ends a few hundred
# metres from the launcher), the launch blast and the 122-mm burst. All the
# puffs of a salvo are one multimesh: one draw call.
const CAPACITY := 1600
const LIFE := 9.0
var game: Node3D
var cursor := 0
var born := PackedFloat32Array()
var sizes := PackedFloat32Array()
var spots := PackedVector3Array()
var drift := PackedVector3Array()
var shade := PackedFloat32Array()
var alive: Dictionary={}
var clock := 0.0

static func shared(owner_game: Node3D) -> GradEffects:
 var node:=owner_game.world_root.get_node_or_null("GradEffects") as GradEffects
 if node==null:
  node=GradEffects.new();node.name="GradEffects";node.game=owner_game
  owner_game.world_root.add_child(node);node.prepare()
 return node

func prepare() -> void:
 BlastEffect.prepare_textures()
 var quad:=QuadMesh.new();quad.size=Vector2(2,2)
 var material:=StandardMaterial3D.new()
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.billboard_keep_scale=true
 material.albedo_texture=BlastEffect.smoke_texture
 material.vertex_color_use_as_albedo=true
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 quad.material=material
 multimesh=MultiMesh.new()
 multimesh.transform_format=MultiMesh.TRANSFORM_3D
 multimesh.use_colors=true
 multimesh.mesh=quad
 multimesh.instance_count=CAPACITY
 multimesh.visible_instance_count=CAPACITY
 born.resize(CAPACITY);sizes.resize(CAPACITY);spots.resize(CAPACITY);drift.resize(CAPACITY);shade.resize(CAPACITY)
 for i in range(CAPACITY):
  multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3.ZERO))
  multimesh.set_instance_color(i,Color(1,1,1,0))
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 custom_aabb=AABB(Vector3(-7000,-500,-7000),Vector3(14000,6000,14000))

func puff(at: Vector3, size: float, tone: float=0.8, wind: Vector3=Vector3.ZERO) -> void:
 var i:=cursor;cursor=(cursor+1)%CAPACITY
 born[i]=clock;sizes[i]=size;spots[i]=at;shade[i]=tone
 drift[i]=wind+Vector3(randf_range(-0.4,0.4),randf_range(0.2,0.7),randf_range(-0.4,0.4))
 alive[i]=true

func _process(delta: float) -> void:
 if not game.running:return
 if game.paused:return
 clock+=delta
 for i in alive.keys():
  var age:=clock-born[i]
  if age>LIFE:
   alive.erase(i)
   multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3.ZERO))
   multimesh.set_instance_color(i,Color(1,1,1,0))
   continue
  var radius:=sizes[i]*(1.0+age*0.55)
  multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*radius),spots[i]+drift[i]*age))
  var tone:=shade[i]
  multimesh.set_instance_color(i,Color(tone,tone*0.97,tone*0.92,0.62*(1.0-age/LIFE)*smoothstep(0.0,0.12,age)))

# Smoke left behind a rocket between two points of its path.
func trail(from: Vector3, to: Vector3, age: float) -> void:
 if age>GradBallistics.BURN+0.15:return
 var length:=from.distance_to(to)
 var steps:=maxi(1,int(length/7.0))
 for k in range(steps):
  puff(from.lerp(to,(k+0.5)/steps),1.0+age*0.9,0.86)

static func launch(owner_game: Node3D, front: Vector3, rear: Vector3, direction: Vector3) -> void:
 var flash:=BlastEffect.new();owner_game.world_root.add_child(flash);flash.setup(owner_game,front,0.55)
 var effects:=shared(owner_game)
 # The jet hits the ground behind the vehicle and raises a cloud of dust.
 for k in range(5):
  var spot:=rear-direction*(2.0+k*2.5)
  spot.y=owner_game.district.ground_height(spot)+1.0
  effects.puff(spot,2.2+k*0.5,0.66,-direction*1.5)
 effects.puff(front+direction*1.5,1.4,0.9)

static func burn(owner_game: Node3D, at: Vector3) -> void:
 var fire:=BlastEffect.new();owner_game.world_root.add_child(fire);fire.setup(owner_game,at,0.9)

static func impact(owner_game: Node3D, at: Vector3) -> void:
 var blast:=BlastEffect.new();owner_game.world_root.add_child(blast);blast.setup(owner_game,at,2.6)
 var effects:=shared(owner_game)
 for k in range(6):
  effects.puff(at+Vector3(randf_range(-4,4),1.5+k*1.2,randf_range(-4,4)),3.0+k*0.6,0.5)

# The rocket itself: a dark body with a bright tail while the motor burns.
static func rocket_node(owner_game: Node3D) -> Node3D:
 var root:=Node3D.new()
 var body:=MeshInstance3D.new()
 var mesh:=CylinderMesh.new();mesh.top_radius=0.061;mesh.bottom_radius=0.061;mesh.height=2.87;mesh.radial_segments=8;mesh.rings=1
 var paint:=StandardMaterial3D.new();paint.albedo_color=Color("4a4e3c");mesh.material=paint
 body.mesh=mesh;body.rotation.x=PI/2;root.add_child(body)
 var flame:=MeshInstance3D.new();flame.name="Flame"
 var quad:=QuadMesh.new();quad.size=Vector2(1.6,1.6)
 var glow:=StandardMaterial3D.new();glow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 glow.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;glow.albedo_texture=BlastEffect.fire_texture;glow.albedo_color=Color(1,0.9,0.7,1)
 quad.material=glow;flame.mesh=quad;flame.position=Vector3(0,0,1.7);root.add_child(flame)
 owner_game.world_root.add_child(root)
 return root
