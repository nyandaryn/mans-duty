class_name TosEffects
extends Node3D

# What the TOS-1A's rockets look like where they land (VEHICLE-REFERENCES,
# «ТОС-1А», from the Ministry of Defence films on Wikimedia Commons and the
# Zvezda footage): at each burst a fireball near the ground, yellow-white
# with an orange rim, much wider than high, gone in about a second; sparks,
# splinters and clods thrown out; the shock wave seen as a white bubble of
# condensation and a ring of dust running out along the ground; low red-
# orange fires left burning in the grass for several seconds; then
# white-grey heaps of cloud that hang for tens of seconds — a salvo leaves a
# wall of them. Sizes are the game's estimate (the published figures give
# no cloud size; about 20 m of effect per rocket).
#
# Every burst borrows a rig from a pool: particle emitters run in the
# engine (CPUParticles3D, their own random numbers — the game's seeded
# random sequence is not touched), one bubble mesh, and one of four shared
# lights. No node is made per burst.
const RIGS := 24
const LIGHTS := 4
# Fires left in the grass hurt a man standing in them (game units a second).
const FIRE_REACH := 2.2
const FIRE_DAMAGE := 9.0
var game: Node3D
var rigs: Array[Dictionary]=[]
var lights: Array[Dictionary]=[]
var next_rig := 0
var next_light := 0
var clock := 0.0
var hazard_clock := 0.0
var frozen := false
var rng := RandomNumberGenerator.new()
static var materials: Dictionary={}
static var shell_shader: Shader
static var spark_texture: Texture2D

static func shared(owner_game: Node3D) -> TosEffects:
 var node:=owner_game.world_root.get_node_or_null("TosEffects") as TosEffects
 if node==null:
  node=TosEffects.new();node.name="TosEffects";node.game=owner_game
  owner_game.world_root.add_child(node);node.prepare()
 return node

# --- Materials and ramps ------------------------------------------------------
static func spark_image() -> Texture2D:
 if spark_texture!=null:return spark_texture
 var image:=Image.create(32,32,false,Image.FORMAT_RGBA8)
 for y in range(32):
  for x in range(32):
   var r:=Vector2((x-15.5)/15.5,(y-15.5)/15.5).length()
   var a:=clampf(1.0-r,0,1)
   image.set_pixel(x,y,Color(1,1,1,a*a))
 spark_texture=ImageTexture.create_from_image(image)
 return spark_texture

# "fire" and "spark": additive glow; "flame": the fireball's opaque body
# (additive goes white over a grey sky, the films show yellow and orange);
# "smoke": alpha-blended clouds; "debris": solid lit chips.
static func material(kind: String) -> Material:
 if materials.has(kind):return materials[kind]
 BlastEffect.prepare_textures()
 var m:=StandardMaterial3D.new()
 m.vertex_color_use_as_albedo=true
 m.cull_mode=BaseMaterial3D.CULL_DISABLED
 match kind:
  "fire","spark":
   m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
   m.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
   m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
   m.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;m.billboard_keep_scale=true
   m.albedo_texture=BlastEffect.fire_texture if kind=="fire" else spark_image()
  "flame","smoke":
   m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
   m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
   m.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;m.billboard_keep_scale=true
   m.albedo_texture=BlastEffect.fire_texture if kind=="flame" else BlastEffect.smoke_texture
  "debris":
   m.roughness=0.95
 materials[kind]=m
 return m

# The condensation shell: bright where it is seen edge-on, clear in the
# middle, as the shock front shows on the films.
static func shell_material() -> ShaderMaterial:
 if shell_shader==null:
  shell_shader=Shader.new()
  shell_shader.code="""shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
uniform float fade = 0.0;
void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = vec3(0.97, 0.97, 0.95);
	ALPHA = fade * (0.08 + 0.92 * pow(rim, 2.2));
}
"""
 var m:=ShaderMaterial.new();m.shader=shell_shader
 return m

static func ramp(points: Array) -> Gradient:
 var offsets:=PackedFloat32Array()
 var colors:=PackedColorArray()
 for p in points:offsets.append(float(p[0]));colors.append(p[1])
 var g:=Gradient.new()
 g.offsets=offsets;g.colors=colors
 return g

static func curve(points: Array) -> Curve:
 var c:=Curve.new()
 c.max_value=4.0
 for p in points:c.add_point(Vector2(p[0],p[1]))
 return c

static func quad(kind: String) -> QuadMesh:
 var q:=QuadMesh.new();q.size=Vector2.ONE;q.material=material(kind)
 return q

# One emitter of a rig, set up once; impact() places and restarts it.
func emitter(parent: Node3D, kind: String, amount: int, lifetime: float, one_shot: bool) -> CPUParticles3D:
 var p:=CPUParticles3D.new()
 p.amount=amount;p.lifetime=lifetime;p.one_shot=one_shot
 p.emitting=false;p.local_coords=false
 p.mesh=quad(kind) if kind!="debris" else debris_mesh()
 p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 # A fixed seed, changed from our own generator before every start: the
 # emitter then never draws on the engine's global random numbers.
 p.use_fixed_seed=true;p.seed=rng.randi()
 parent.add_child(p)
 return p

static func debris_mesh() -> Mesh:
 var box:=BoxMesh.new();box.size=Vector3(0.12,0.05,0.45);box.material=material("debris")
 return box

# The engine compiles a material's shader the first time it is drawn: the
# first burst of a battle used to stall 100–150 ms (more under load). At
# deployment each material is drawn once, invisibly, in front of the camera,
# the way the emitters draw them (a multimesh with colours and custom data).
# No CPUParticles3D is made here: that would draw on the seeded random
# numbers (see emitter()).
static func warm_up(owner_game: Node3D) -> void:
 var camera:=owner_game.get_viewport().get_camera_3d()
 if camera==null:return
 var node:=Node3D.new();node.name="TosWarmUp"
 owner_game.world_root.add_child(node)
 var place:=camera.global_transform*Transform3D(Basis.from_scale(Vector3.ONE*0.001),Vector3(0,0,-2.0))
 var meshes: Array[Mesh]=[quad("flame"),quad("fire"),quad("spark"),quad("smoke"),debris_mesh()]
 for mesh in meshes:
  var multi:=MultiMesh.new()
  multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.use_custom_data=true
  multi.mesh=mesh;multi.instance_count=1
  multi.set_instance_transform(0,Transform3D.IDENTITY);multi.set_instance_color(0,Color(1,1,1,0))
  var instance:=MultiMeshInstance3D.new();instance.multimesh=multi
  instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  node.add_child(instance);instance.global_transform=place
 var shell:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=1.0;sphere.height=2.0
 sphere.material=shell_material();shell.mesh=sphere;shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.add_child(shell);shell.global_transform=place
 owner_game.get_tree().create_timer(0.25,true,false,true).timeout.connect(node.queue_free)

func prepare() -> void:
 rng.seed=0x7051A
 for i in range(RIGS):rigs.append(build_rig(i))
 for i in range(LIGHTS):
  var light:=OmniLight3D.new();light.name="BurstLight%d" % i;light.shadow_enabled=false
  light.light_color=Color(1,0.62,0.28);light.light_energy=0.0;light.visible=false
  add_child(light)
  lights.append({"light":light,"rig":-1})

func build_rig(index: int) -> Dictionary:
 var root:=Node3D.new();root.name="Burst%d" % index;root.visible=false
 add_child(root)
 # The fireball: a flattened heap of glowing blobs that swells, goes from
 # white-yellow through orange to dull red and rises as it cools.
 var fireball:=emitter(root,"flame",24,1.7,true)
 fireball.explosiveness=0.95;fireball.randomness=0.25
 fireball.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
 fireball.direction=Vector3.UP;fireball.spread=180.0;fireball.flatness=0.6
 fireball.initial_velocity_min=3.0;fireball.initial_velocity_max=9.0
 fireball.damping_min=4.0;fireball.damping_max=6.0
 fireball.gravity=Vector3(0,4.0,0)
 fireball.scale_amount_curve=curve([[0.0,0.3],[0.1,1.0],[0.5,1.25],[1.0,1.5]])
 fireball.color_ramp=ramp([[0.0,Color(1,0.97,0.82,1)],[0.12,Color(1,0.86,0.45,1)],[0.3,Color(1,0.58,0.16,0.95)],[0.55,Color(0.8,0.28,0.06,0.85)],[0.8,Color(0.34,0.22,0.16,0.6)],[1.0,Color(0.46,0.43,0.4,0)]])
 # Its glow: a few additive blobs in the heart of it for the first instant.
 var glow:=emitter(root,"fire",8,0.55,true)
 glow.explosiveness=1.0;glow.randomness=0.2
 glow.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
 glow.direction=Vector3.UP;glow.spread=180.0;glow.flatness=0.6
 glow.initial_velocity_min=1.0;glow.initial_velocity_max=4.0
 glow.damping_min=3.0;glow.damping_max=5.0
 glow.scale_amount_curve=curve([[0.0,0.5],[0.2,1.0],[1.0,1.2]])
 glow.color_ramp=ramp([[0.0,Color(1,0.9,0.6,0.9)],[0.4,Color(1,0.6,0.2,0.6)],[1.0,Color(0.6,0.2,0.05,0)]])
 # Sparks and burning bits thrown out on long arcs.
 var sparks:=emitter(root,"spark",72,2.1,true)
 sparks.explosiveness=1.0;sparks.randomness=0.5
 sparks.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;sparks.emission_sphere_radius=1.6
 sparks.direction=Vector3.UP;sparks.spread=80.0
 sparks.initial_velocity_min=9.0;sparks.initial_velocity_max=34.0
 sparks.gravity=Vector3(0,-9.8,0);sparks.damping_min=0.3;sparks.damping_max=1.2
 sparks.scale_amount_min=0.22;sparks.scale_amount_max=0.55
 sparks.color_ramp=ramp([[0.0,Color(1,0.95,0.75,1)],[0.35,Color(1,0.66,0.25,1)],[0.8,Color(0.85,0.25,0.05,0.7)],[1.0,Color(0.4,0.08,0.02,0)]])
 # Splinters, clods and stones.
 var debris:=emitter(root,"debris",28,2.6,true)
 debris.explosiveness=1.0;debris.randomness=0.4
 debris.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;debris.emission_sphere_radius=1.2
 debris.direction=Vector3.UP;debris.spread=70.0
 debris.initial_velocity_min=7.0;debris.initial_velocity_max=24.0
 debris.gravity=Vector3(0,-9.8,0)
 debris.scale_amount_min=0.5;debris.scale_amount_max=1.6
 debris.angular_velocity_min=-540.0;debris.angular_velocity_max=540.0
 debris.particle_flag_rotate_y=true
 debris.color=Color("2b2419")
 # The shock wave raising a ring of dust that runs out along the ground.
 var dust:=emitter(root,"smoke",28,7.0,true)
 dust.explosiveness=1.0;dust.randomness=0.3
 dust.emission_shape=CPUParticles3D.EMISSION_SHAPE_RING
 dust.emission_ring_axis=Vector3.UP;dust.emission_ring_radius=3.0;dust.emission_ring_inner_radius=2.0;dust.emission_ring_height=0.3
 dust.direction=Vector3.RIGHT;dust.spread=180.0;dust.flatness=1.0
 dust.initial_velocity_min=14.0;dust.initial_velocity_max=24.0
 dust.damping_min=5.0;dust.damping_max=8.0
 dust.gravity=Vector3(0.15,0.45,0.05)
 dust.scale_amount_min=6.0;dust.scale_amount_max=10.0
 dust.scale_amount_curve=curve([[0.0,0.5],[0.2,1.0],[1.0,2.2]])
 dust.color_ramp=ramp([[0.0,Color(0.52,0.47,0.39,0.0)],[0.03,Color(0.6,0.55,0.46,0.85)],[0.5,Color(0.66,0.62,0.55,0.5)],[1.0,Color(0.7,0.68,0.64,0)]])
 # The white-grey heaps of cloud that hang over the place.
 var cloud:=emitter(root,"smoke",24,42.0,true)
 cloud.explosiveness=0.9;cloud.randomness=0.3
 cloud.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;cloud.emission_sphere_radius=6.0
 cloud.direction=Vector3.UP;cloud.spread=70.0;cloud.flatness=0.35
 cloud.initial_velocity_min=2.0;cloud.initial_velocity_max=6.0
 cloud.damping_min=0.8;cloud.damping_max=1.3
 cloud.gravity=Vector3(0.25,0.22,0.08)
 cloud.scale_amount_min=11.0;cloud.scale_amount_max=17.0
 cloud.scale_amount_curve=curve([[0.0,0.35],[0.03,0.9],[0.15,1.1],[1.0,2.2]])
 cloud.color_ramp=ramp([[0.0,Color(0.62,0.52,0.42,0.0)],[0.015,Color(0.78,0.72,0.65,0.85)],[0.08,Color(0.9,0.89,0.86,0.92)],[0.7,Color(0.92,0.92,0.9,0.6)],[1.0,Color(0.93,0.93,0.92,0)]])
 # Low fires left in the grass, and their dark smoke.
 var fire:=emitter(root,"fire",30,0.9,false)
 fire.randomness=0.4
 fire.emission_shape=CPUParticles3D.EMISSION_SHAPE_POINTS
 fire.direction=Vector3.UP;fire.spread=25.0
 fire.initial_velocity_min=0.8;fire.initial_velocity_max=2.6
 fire.gravity=Vector3(0,1.2,0)
 fire.scale_amount_min=1.0;fire.scale_amount_max=2.4
 fire.scale_amount_curve=curve([[0.0,0.6],[0.3,1.0],[1.0,0.4]])
 fire.color_ramp=ramp([[0.0,Color(1,0.8,0.4,0.9)],[0.4,Color(1,0.45,0.12,0.8)],[1.0,Color(0.4,0.08,0.02,0)]])
 var soot:=emitter(root,"smoke",14,5.0,false)
 soot.randomness=0.3
 soot.emission_shape=CPUParticles3D.EMISSION_SHAPE_POINTS
 soot.direction=Vector3.UP;soot.spread=20.0
 soot.initial_velocity_min=1.0;soot.initial_velocity_max=2.2
 soot.gravity=Vector3(0.25,0.35,0.05)
 soot.scale_amount_min=1.8;soot.scale_amount_max=3.0
 soot.scale_amount_curve=curve([[0.0,0.5],[1.0,2.4]])
 soot.color_ramp=ramp([[0.0,Color(0.16,0.15,0.14,0.0)],[0.1,Color(0.18,0.17,0.16,0.55)],[1.0,Color(0.35,0.34,0.33,0)]])
 # The condensation bubble of the shock wave.
 var bubble:=MeshInstance3D.new();bubble.name="Bubble"
 var sphere:=SphereMesh.new();sphere.radius=1.0;sphere.height=2.0;sphere.radial_segments=20;sphere.rings=10
 var shell:=shell_material()
 sphere.material=shell;bubble.mesh=sphere;bubble.visible=false
 bubble.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(bubble)
 return {"root":root,"fireball":fireball,"glow":glow,"sparks":sparks,"debris":debris,"dust":dust,"cloud":cloud,"fire":fire,"soot":soot,
  "bubble":bubble,"shell":shell,"age":INF,"size":1.0,"fires":PackedVector3Array(),"fire_time":0.0,"light":-1}

# --- Bursts -------------------------------------------------------------------
# A thermobaric burst at a point on the ground. `size` 1 for one rocket;
# the package of a vehicle going up is bigger.
func impact(at: Vector3, size: float=1.0) -> void:
 var rig: Dictionary=rigs[next_rig]
 var index:=next_rig
 next_rig=(next_rig+1)%RIGS
 rig.age=0.0;rig.size=size
 var root: Node3D=rig.root
 root.visible=true
 var fireball: CPUParticles3D=rig.fireball
 fireball.global_position=at+Vector3.UP*(2.5*size)
 fireball.emission_box_extents=Vector3(6.5,1.8,6.5)*size
 fireball.scale_amount_min=9.0*size;fireball.scale_amount_max=14.0*size
 var glow: CPUParticles3D=rig.glow
 glow.global_position=at+Vector3.UP*(2.0*size)
 glow.emission_box_extents=Vector3(4.0,1.0,4.0)*size
 glow.scale_amount_min=8.0*size;glow.scale_amount_max=12.0*size
 for key in ["sparks","debris","dust","cloud"]:
  var p: CPUParticles3D=rig[key]
  p.global_position=at+Vector3.UP*(0.5 if key!="cloud" else 3.0*size)
 (rig.cloud as CPUParticles3D).scale_amount_min=11.0*size;(rig.cloud as CPUParticles3D).scale_amount_max=17.0*size
 (rig.cloud as CPUParticles3D).emission_sphere_radius=6.0*size
 (rig.dust as CPUParticles3D).initial_velocity_max=24.0*sqrt(size)
 for key in ["fireball","glow","sparks","debris","dust","cloud"]:
  var p: CPUParticles3D=rig[key]
  p.seed=rng.randi();p.restart(true)
 # Patches of fire in the grass round the burst, each followed to the
 # ground.
 var spots:=PackedVector3Array()
 var count:=rng.randi_range(4,8)
 for k in range(count):
  var angle:=rng.randf()*TAU
  var distance:=rng.randf_range(2.0,12.0)*size
  var p:=at+Vector3(cos(angle)*distance,0,sin(angle)*distance)
  if is_instance_valid(game.district):p.y=game.district.ground_height(p)+0.3
  spots.append(p)
 rig.fires=spots
 rig.fire_time=rng.randf_range(4.0,12.0)*clampf(size,1.0,2.0)
 for key in ["fire","soot"]:
  var p: CPUParticles3D=rig[key]
  p.global_position=Vector3.ZERO
  p.emission_points=spots
  p.seed=rng.randi();p.emitting=true
 var bubble: MeshInstance3D=rig.bubble
 bubble.global_position=at+Vector3.UP*1.0;bubble.visible=true;bubble.scale=Vector3.ONE*0.5
 # The flash lights the ground for a moment, the fires after it.
 var slot: Dictionary=lights[next_light]
 next_light=(next_light+1)%LIGHTS
 if int(slot.rig)>=0 and int(slot.rig)<rigs.size():rigs[int(slot.rig)].light=-1
 slot.rig=index
 rig.light=lights.find(slot)
 var light: OmniLight3D=slot.light
 light.global_position=at+Vector3.UP*3.0;light.visible=true
 tick_rig(rig,0.0)

# The package of a TOS going up: the same burst, bigger.
func cookoff(at: Vector3) -> void:impact(at,1.8)

func _process(delta: float) -> void:
 if game==null or not game.running:return
 var still: bool=game.paused
 if still!=frozen:
  frozen=still
  for rig in rigs:
   for key in ["fireball","glow","sparks","debris","dust","cloud","fire","soot"]:
    (rig[key] as CPUParticles3D).speed_scale=0.0 if still else 1.0
 if still:return
 clock+=delta
 for rig in rigs:
  if float(rig.age)==INF:continue
  rig.age=float(rig.age)+delta
  tick_rig(rig,delta)
 hazard_clock-=delta
 if hazard_clock<=0.0:
  hazard_clock=0.5
  burn_men()

func tick_rig(rig: Dictionary, _delta: float) -> void:
 var age: float=rig.age
 var size: float=rig.size
 var bubble: MeshInstance3D=rig.bubble
 if bubble.visible:
  var t:=age/0.16
  if t>=1.0:bubble.visible=false
  else:
   var r:=lerpf(2.0,24.0,sqrt(t))*size
   bubble.scale=Vector3(r,r*0.62,r)
   (rig.shell as ShaderMaterial).set_shader_parameter("fade",0.4*(1.0-t))
 if age>float(rig.fire_time):
  for key in ["fire","soot"]:(rig[key] as CPUParticles3D).emitting=false
 var index: int=rig.light
 if index>=0:
  var light: OmniLight3D=lights[index].light
  var energy:=0.0
  var reach:=20.0
  if age<0.09:energy=16.0*size;reach=75.0*size
  elif age<1.0:energy=lerpf(7.0,1.6,(age-0.09)/0.91)*size;reach=lerpf(55.0,26.0,(age-0.09)/0.91)*size
  elif age<float(rig.fire_time):energy=1.3*(0.8+0.4*sin(age*17.0)*sin(age*11.0));reach=22.0
  light.light_energy=energy;light.omni_range=reach
  if energy<=0.0:
   light.visible=false;lights[index].rig=-1;rig.light=-1
 # All done: the clouds have thinned out.
 if age>float(rig.fire_time)+6.0 and age>44.0:
  rig.age=INF
  (rig.root as Node3D).visible=false

# Fires burning: a man standing in one is burned a little each half second.
func burn_men() -> void:
 var spots:=PackedVector3Array()
 for rig in rigs:
  if float(rig.age)!=INF and float(rig.age)<float(rig.fire_time):spots.append_array(rig.fires)
 if spots.is_empty():return
 for actor in [game.player]+game.bots+game.allies:
  if not is_instance_valid(actor) or (actor is Hostile and (actor.dead or actor.vehicle!=null)):continue
  if actor is Operator and (actor.get_meta("battle_out",false) or game.player_sheltered()):continue
  var feet: Vector3=actor.global_position
  for spot in spots:
   if Vector2(feet.x-spot.x,feet.z-spot.z).length()<FIRE_REACH and absf(feet.y-spot.y)<2.0:
    actor.receive_blast(FIRE_DAMAGE,0.05,Vector3.UP)
    break

func clear() -> void:
 for rig in rigs:
  rig.age=INF;(rig.root as Node3D).visible=false
  for key in ["fire","soot"]:(rig[key] as CPUParticles3D).emitting=false
  (rig.bubble as MeshInstance3D).visible=false
 for slot in lights:(slot.light as OmniLight3D).visible=false;slot.rig=-1

# --- Launch ---------------------------------------------------------------------
# The launch of one rocket: the flash and the flame at the breech, the jet
# splashing on the ground behind and the dust it throws up. The cloud round
# the vehicle itself is the vehicle's own emitter (TosVehicle).
static func launch(owner_game: Node3D, front: Vector3, rear: Vector3, direction: Vector3) -> void:
 var flash:=BlastEffect.new();owner_game.world_root.add_child(flash);flash.setup(owner_game,rear,0.7)
 var effects:=GradEffects.shared(owner_game)
 for k in range(6):
  var spot:=rear-direction*(2.0+k*2.2)
  spot.y=owner_game.district.ground_height(spot)+1.0
  effects.puff(spot,2.6+k*0.6,0.62,-direction*1.8)
 effects.puff(front+direction*2.0,1.6,0.72)

# The rocket in flight: a dark green body with the fuse pin sticking out of
# its nose, and a short bright flame while the motor burns.
static func rocket_node(owner_game: Node3D) -> Node3D:
 var root:=Node3D.new()
 var body:=MeshInstance3D.new()
 var mesh:=CylinderMesh.new();mesh.top_radius=0.11;mesh.bottom_radius=0.11;mesh.height=3.723;mesh.radial_segments=10;mesh.rings=1
 var paint:=StandardMaterial3D.new();paint.albedo_color=Color("45503a");mesh.material=paint
 body.mesh=mesh;body.rotation.x=PI/2;root.add_child(body)
 var pin:=MeshInstance3D.new()
 var pin_mesh:=CylinderMesh.new();pin_mesh.top_radius=0.025;pin_mesh.bottom_radius=0.04;pin_mesh.height=0.42;pin_mesh.radial_segments=6;pin_mesh.rings=1
 pin_mesh.material=paint;pin.mesh=pin_mesh;pin.rotation.x=PI/2;pin.position=Vector3(0,0,-2.07);root.add_child(pin)
 var flame:=MeshInstance3D.new();flame.name="Flame"
 var quad_mesh:=QuadMesh.new();quad_mesh.size=Vector2(2.6,2.6)
 var glow:=StandardMaterial3D.new();glow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 glow.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 glow.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;glow.albedo_texture=BlastEffect.fire_texture;glow.albedo_color=Color(1,0.9,0.7,1)
 quad_mesh.material=glow;flame.mesh=quad_mesh;flame.position=Vector3(0,0,2.3);root.add_child(flame)
 owner_game.world_root.add_child(root)
 return root

# Smoke behind a rocket between two points of its path while the motor
# burns, and thinly a little after.
static func trail(owner_game: Node3D, from: Vector3, to: Vector3, age: float) -> void:
 if age>TosBallistics.BURN+0.4:return
 var effects:=GradEffects.shared(owner_game)
 var length:=from.distance_to(to)
 var steps:=maxi(1,int(length/6.0))
 for k in range(steps):
  effects.puff(from.lerp(to,(k+0.5)/steps),1.3+age*1.1,0.42 if age<TosBallistics.BURN else 0.55)
