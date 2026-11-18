class_name BlastEffect
extends Node3D

var game: Node3D
var age := 0.0
# 1 for a warhead, smaller for the muzzle smoke of a mortar.
var size := 1.0
var clouds: Array[MeshInstance3D]=[]
var light: OmniLight3D
static var smoke_texture: Texture2D
static var fire_texture: Texture2D

static func prepare_textures() -> void:
 if smoke_texture!=null:return
 var smoke := Image.create(96,96,false,Image.FORMAT_RGBA8)
 var fire := Image.create(96,96,false,Image.FORMAT_RGBA8)
 var noise := FastNoiseLite.new();noise.seed=81314;noise.frequency=0.055;noise.fractal_octaves=4
 for y in range(96):
  for x in range(96):
   var radius := Vector2((x-47.5)/47.5,(y-47.5)/47.5).length()
   var grain := noise.get_noise_2d(x,y)*0.5+0.5
   var alpha := (1-smoothstep(0.30,0.98,radius+(grain-0.5)*0.35))*(0.45+grain*0.55)
   var shade := 0.52+grain*0.48
   smoke.set_pixel(x,y,Color(shade,shade,shade,alpha))
   var heat := clampf((1-radius)*0.85+grain*0.35,0,1)
   var flame := Color(0.6,0.15,0.025).lerp(Color(1.0,0.91,0.65),heat)
   flame.a=alpha
   fire.set_pixel(x,y,flame)
 smoke_texture=ImageTexture.create_from_image(smoke)
 fire_texture=ImageTexture.create_from_image(fire)

func setup(owner_game: Node3D, where: Vector3, scale_factor: float=1.0) -> void:
 game=owner_game;position=where;size=scale_factor
 prepare_textures()
 var quad := QuadMesh.new();quad.size=Vector2(2,2)
 for i in range(14):
  var mesh := MeshInstance3D.new();mesh.mesh=quad
  var material := StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.billboard_keep_scale=true
  material.albedo_texture=smoke_texture
  material.albedo_color=Color(0.38,0.35,0.30,0.7)
  if i<4:
   material.albedo_texture=fire_texture;material.albedo_color=Color(1,0.9,0.75,0.9)
  mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  mesh.set_meta("offset",Vector3(sin(i*2.4),0.25+float(i%3)*0.32,cos(i*2.4)))
  add_child(mesh);clouds.append(mesh)
 light=OmniLight3D.new();light.omni_range=12;light.light_color=Color(1,0.55,0.24);light.shadow_enabled=false;add_child(light)
 tick_visual()

func _process(delta: float) -> void:
 if not game.running:queue_free();return
 if game.paused:return
 age+=delta
 if age>4:queue_free();return
 tick_visual()

func tick_visual() -> void:
 light.light_energy=maxf(0,1-age/0.24)*4*size
 for i in range(clouds.size()):
  var cloud := clouds[i]
  var fire := i<4
  cloud.visible=age<0.30 if fire else age>0.18
  var radius := (0.35+age*7) if fire else (0.30+age*0.75)
  radius*=size
  cloud.scale=Vector3(radius,radius*(0.8 if fire else 1.2),radius)
  cloud.position=Vector3(cloud.get_meta("offset"))*(0.25+minf(age,2.5)*0.7)+Vector3.UP*age*0.35
  var material: StandardMaterial3D=cloud.material_override
  material.albedo_color.a=maxf(0,0.72*(1-age/4)) if not fire else maxf(0,1-age/0.30)
