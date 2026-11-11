class_name Wardrobe
extends RefCounted

const IDS = ["ua_pixel","rf_digital","british_mtp","urban_grey","urban_dust","ghillie_green","ghillie_dry"]
const LABELS = ["ЗСУ / ММ-14 — піксель","РФ / цифровий лісовий","Британська / MTP","Міський / бетон","Міський / пил і цегла","Снайперський / зелена посадка","Снайперський / суха трава"]
const PALETTES = {
 "ua_pixel":["aaa17a","817f55","626747","434b36"],
 "rf_digital":["71794c","535f35","394a2b","262e22"],
 "british_mtp":["aba17b","797d55","555e3d","574b37"],
 "urban_grey":["989b93","747b76","515956","b4b1a2"],
 "urban_dust":["a1957e","827664","69675d","b2a38b"],
 "ghillie_green":["7c8255","626f42","465733","959063"],
 "ghillie_dry":["a29560","8d8051","716a43","b1a271"]
}
static var cached: Dictionary = {}

static func valid(id: String) -> String:
 return id if id in IDS else "ua_pixel"

static func fabric(id: String) -> StandardMaterial3D:
 id=valid(id)
 if cached.has(id):return cached[id]
 var image := Image.create(128,128,false,Image.FORMAT_RGB8)
 var noise := FastNoiseLite.new()
 noise.seed=absi(id.hash())%10000
 noise.frequency=0.035
 noise.fractal_octaves=3
 for y in range(128):
  for x in range(128):
   var digital := id in ["ua_pixel","rf_digital","urban_grey"]
   var px := float((x/4)*4) if digital else float(x)
   var py := float((y/4)*4) if digital else float(y)
   var n := noise.get_noise_2d(px,py)
   var index := 0 if n< -0.20 else (1 if n<0 else (2 if n<0.22 else 3))
   image.set_pixel(x,y,Color(PALETTES[id][index]))
 var mat := StandardMaterial3D.new()
 mat.resource_name="uniform_"+id
 mat.albedo_texture=ImageTexture.create_from_image(image)
 mat.roughness=0.98
 mat.uv1_triplanar=true
 mat.uv1_scale=Vector3.ONE*3
 mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 cached[id]=mat
 return mat

static func match_color(id: String, background: Color) -> float:
 var average := Vector3.ZERO
 for value in PALETTES[valid(id)]:
  var color := Color(value)
  average+=Vector3(color.r,color.g,color.b)*0.25
 var difference := average.distance_to(Vector3(background.r,background.g,background.b))
 return clampf(1.0-difference*2.7,0.0,1.0)

static func dress(root: Node3D, id: String, first_person: bool=false) -> void:
 id=valid(id)
 root.set_meta("outfit",id)
 var mat := fabric(id)
 for node in root.find_children("*","MeshInstance3D",true,false):
  for surface in range(node.mesh.get_surface_count()):
   var old: Material=node.get_active_material(surface)
   if old is StandardMaterial3D and (old.resource_name.begins_with("uniform") or old.resource_name=="cloth"):
    node.set_surface_override_material(surface,mat)
    if node.material_override!=null:node.material_override=mat
 for old in root.find_children("GhillieTufts","MultiMeshInstance3D",true,false):
  old.get_parent().remove_child(old)
  old.queue_free()
 if first_person or not id.begins_with("ghillie"):return
 var random := RandomNumberGenerator.new()
 random.seed=abs(id.hash())
 for bone_name in ["Head","LeftArm","RightArm","LeftLeg","RightLeg"]:
  var bone: Node3D=root.get_node_or_null(bone_name)
  if bone==null:continue
  var quad := QuadMesh.new()
  quad.size=Vector2(0.12,0.21)
  quad.material=mat
  var multi := MultiMesh.new()
  multi.transform_format=MultiMesh.TRANSFORM_3D
  multi.mesh=quad
  multi.instance_count=32
  for i in range(32):
   var angle := random.randf()*TAU
   var head: bool=bone_name=="Head"
   var pos := Vector3(cos(angle)*(0.15 if head else 0.11),random.randf_range(0.22,0.34) if head else random.randf_range(-0.3,0),sin(angle)*(0.14 if head else 0.12))
   multi.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(random.randf_range(-0.5,0.5),angle,random.randf_range(-0.5,0.5))),pos))
  var tufts := MultiMeshInstance3D.new()
  tufts.name="GhillieTufts"
  tufts.multimesh=multi
  bone.add_child(tufts)
