class_name CharacterArt
extends RefCounted

const UPPER_LEFT := Vector3(-0.045,-0.295,-0.045)
const UPPER_RIGHT := Vector3(0.065,-0.285,-0.04)
const LOWER_LEFT := Vector3(0.12,0.09,-0.265)
const LOWER_RIGHT := Vector3(-0.11,0.10,-0.26)
const EYE := Vector3(0.030778,0.158277,-0.121957)
static var head_mesh: ArrayMesh
static var cached: PackedScene
static var cached_bot: PackedScene
static var family_materials: Dictionary = {}

# Smooth, irregular garment cross-sections retain shoulders, waist and folds.
# Stations contain height, full width, full depth and forward/backward offset.
static func shell(parent: Node3D, stations: Array[Vector4], material: String, folds: float=0.0, segments: int=24, square: float=1.0, open_top: bool=false) -> MeshInstance3D:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(0)
 var rings: Array[PackedVector3Array]=[]
 var ordered := stations.duplicate()
 ordered.sort_custom(func(a,b):return a.x<b.x)
 for station in ordered:
  var ring := PackedVector3Array()
  for i in range(segments):
   var angle := TAU*i/segments
   var wrinkle := 1+folds*(sin(station.x*81+angle*5)+sin(station.x*139-angle*3)*0.4)
   var x := signf(cos(angle))*pow(absf(cos(angle)),square)
   var z := signf(sin(angle))*pow(absf(sin(angle)),square)
   ring.append(Vector3(x*station.y*0.5*wrinkle,station.x,z*station.z*0.5*wrinkle+station.w))
  rings.append(ring)
 for r in range(rings.size()-1):
  for i in range(segments):
   var j := (i+1)%segments
   for vertex in [rings[r][i],rings[r][j],rings[r+1][i],rings[r][j],rings[r+1][j],rings[r+1][i]]:st.add_vertex(vertex)
 for i in range(1,segments-1):
  for vertex in [rings[0][0],rings[0][i+1],rings[0][i]]:st.add_vertex(vertex)
  if not open_top:
   for vertex in [rings[-1][0],rings[-1][i],rings[-1][i+1]]:st.add_vertex(vertex)
 st.generate_normals()
 st.index()
 return Models.mesh_node(parent,st.commit(),Vector3.ZERO,material)

static func sleeve(parent: Node3D, end: Vector3, upper: bool) -> void:
 var length := end.length()
 var radius := 0.083 if upper else 0.064
 var stations: Array[Vector4]=[]
 for i in range(9):
  var t := float(i)/8
  var taper := lerpf(1.0,0.72 if upper else 0.64,t)
  var bulge := sin(t*PI)*0.08
  stations.append(Vector4(t*length,radius*2*(taper+bulge),radius*1.8*(taper+bulge),0))
 var mesh := shell(parent,stations,"uniform",0.035)
 mesh.quaternion=Quaternion(Vector3.UP,end.normalized())
 # A stitched cuff sits at the wrist; it follows the forearm's actual axis.
 if not upper:Models.tube(parent,end*0.96,0.043,0.022,"uniform",end.normalized(),0.041)

# The anatomical head (assets/characters/head.json), smooth-shaded; the
# balaclava is cut from the same surface (FaceCover).
static func anatomical_head() -> ArrayMesh:
 if head_mesh==null:
  var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/head.json"))
  var st := SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  st.set_smooth_group(0)
  for index in data.indices:
   var p: Array=data.positions[int(index)]
   var uv: Array=data.uvs[int(index)]
   st.set_uv(Vector2(uv[0],uv[1]))
   st.add_vertex(Vector3(p[0],p[1],p[2]))
  st.generate_normals()
  st.index()
  head_mesh=st.commit()
 return head_mesh

static func head(parent: Node3D) -> void:
 var face := MeshInstance3D.new()
 face.name="AnatomicalHead"
 face.mesh=anatomical_head()
 var skin := StandardMaterial3D.new()
 skin.resource_name="character_skin"
 skin.albedo_texture=load("res://assets/characters/young_caucasian_male_diffuse.png")
 skin.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 skin.roughness=0.76
 skin.cull_mode=BaseMaterial3D.CULL_DISABLED
 face.material_override=skin
 parent.add_child(face)
 for side in [-1,1]:
  var eye := Vector3(side*EYE.x,EYE.y,EYE.z)
  Models.ellipsoid(parent,eye,Vector3(0.023,0.023,0.023),"#c3b9a8")
  Models.ellipsoid(parent,eye+Vector3(0,0,-0.0105),Vector3(0.009,0.009,0.003),"#465047")
  Models.ellipsoid(parent,eye+Vector3(0,0,-0.012),Vector3(0.0038,0.0038,0.0015),"#141817")
 # Anatomical face stays visible; no opaque rectangular glasses hide it.
 var helmet := Models.group(parent,"Helmet")
 helmet.position.z=-0.05
 shell(helmet,[Vector4(0.170,0.228,0.259,0.009),Vector4(0.195,0.240,0.269,0.006),Vector4(0.235,0.220,0.249,0.009),Vector4(0.268,0.164,0.191,0.01),Vector4(0.283,0.080,0.101,0.013),Vector4(0.287,0.012,0.014,0.013)],"uniform",0.006,32)
 for side in [-1,1]:
  Models.bevel(helmet,Vector3(side*0.113,0.199,0.025),Vector3(0.014,0.026,0.115),"#464a3e",0.005)
  Models.limb(parent,Vector3(side*0.10,0.17,0.01),Vector3(side*0.055,0.045,-0.075),0.004,"#3a3e35")
  Models.limb(parent,Vector3(side*0.088,0.132,0.057),Vector3(side*0.055,0.045,-0.075),0.0035,"#3a3e35")
  Models.bevel(parent,Vector3(side*0.055,0.048,-0.077),Vector3(0.014,0.018,0.008),"#252a24",0.003)
 Models.limb(parent,Vector3(-0.055,0.045,-0.075),Vector3(0.055,0.045,-0.075),0.005,"#3a3e35")
 Models.bevel(helmet,Vector3(0,0.225,-0.122),Vector3(0.047,0.045,0.010),"#45493f",0.005)
 Models.bevel(helmet,Vector3(0,0.225,-0.128),Vector3(0.024,0.028,0.004),"#252b26",0.002)

static func pouch(parent: Node3D, position: Vector3, size: Vector3) -> void:
 var bag := Models.group(parent,"Pouch",position)
 var s := size
 shell(bag,[Vector4(-s.y*0.5,s.x*0.86,s.z*0.86,0),Vector4(-s.y*0.38,s.x,s.z,0),Vector4(s.y*0.32,s.x,s.z,0),Vector4(s.y*0.5,s.x*0.94,s.z*0.92,0)],"gear_#62674e",0.016,24,0.48)
 Models.bevel(bag,Vector3(0,s.y*0.32,-s.z*0.48),Vector3(s.x*0.89,s.y*0.21,0.008),"gear_#555e49",0.003)
 Models.bevel(bag,Vector3(0,s.y*0.16,-s.z*0.53),Vector3(0.018,s.y*0.20,0.004),"gear_#444d3c",0.001)
 for side in [-1,1]:Models.limb(bag,Vector3(side*s.x*0.39,-s.y*0.38,-s.z*0.46),Vector3(side*s.x*0.39,s.y*0.3,-s.z*0.46),0.0007,"#83856c")
 Models.merge_rigid(bag)

static func glove(parent: Node3D, wrist: Vector3) -> void:
 var hand := Models.group(parent,"Hand",wrist)
 Models.ellipsoid(hand,Vector3(0,-0.006,-0.012),Vector3(0.072,0.034,0.085),"glove")
 # Distinct curled fingers and knuckles, with tapered distal segments.
 for i in range(4):
  var x := -0.026+i*0.017
  var z: float= -0.047+(0.009 if i==3 else 0)
  Models.limb(hand,Vector3(x,0,z),Vector3(x,-0.026,z-0.011),0.008,"glove",0.007)
  Models.limb(hand,Vector3(x,-0.026,z-0.011),Vector3(x,-0.038,z+0.01),0.007,"glove",0.0058)
  Models.ellipsoid(hand,Vector3(x,0.012,z+0.015),Vector3(0.013,0.006,0.015),"#525747")
 Models.limb(hand,Vector3(-0.032,-0.006,0.012),Vector3(-0.041,-0.029,-0.018),0.010,"glove",0.008)
 Models.limb(hand,Vector3(-0.041,-0.029,-0.018),Vector3(-0.020,-0.039,-0.028),0.008,"glove",0.007)
 Models.merge_rigid(hand)

static func assign_owner(node: Node, owner: Node) -> void:
 for child in node.get_children():
  child.owner=owner
  assign_owner(child,owner)

static func pose_arm(model: Node3D, side: String, wrist: Vector3) -> void:
 var arm: Node3D=model.get_node(side+"Arm")
 var forearm: Node3D=arm.get_node("Forearm")
 var shoulder := arm.position
 var rest_elbow := UPPER_RIGHT if side=="Right" else UPPER_LEFT
 var rest_forearm := LOWER_RIGHT if side=="Right" else LOWER_LEFT
 var direction := shoulder.direction_to(wrist)
 var length_a := rest_elbow.length()
 var length_b := rest_forearm.length()
 var distance := clampf(shoulder.distance_to(wrist),0.08,length_a+length_b-0.001)
 var along := (length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
 var pole := Vector3(1 if side=="Right" else -1,-1,0.2)
 pole=(pole-direction*pole.dot(direction)).normalized()
 var elbow := shoulder+direction*along+pole*sqrt(maxf(0,length_a*length_a-along*along))
 arm.quaternion=Quaternion(rest_elbow.normalized(),shoulder.direction_to(elbow))
 forearm.position=arm.basis.inverse()*(elbow-shoulder)
 forearm.basis=arm.basis.inverse()*Basis(Quaternion(rest_forearm.normalized(),elbow.direction_to(wrist)))

# Body armour over the uniform (VestArt), the uniform's plate bags hidden
# under it.
static func wear_vest(model: Node3D, id: String) -> void:
 VestArt.attach(model,VestKind.valid(id))
 for bag in ["FrontPlate","BackPlate"]:
  var node:=model.get_node_or_null(bag)
  if node!=null:node.visible=false

static func equip_display(model: Node3D, id: String) -> void:
 var rifle: Node3D=model.get_node("CarriedRifle")
 for child in rifle.get_children():child.free()
 var baked: Node3D=load("res://assets/models/"+("ak74m" if id=="ak74" else id)+".scn").instantiate()
 Models.clear_owners(baked)
 for child in baked.get_children():
  baked.remove_child(child)
  rifle.add_child(child)
 Models.marker(rifle,"BotMuzzle",Vector3(0,0,float(baked.get_meta("muzzle_z"))))
 # The support hand where the weapon is held (the PKM: on the bipod legs
 # folded under the gas tube).
 var support: Vector3=baked.get_meta("support_hand",Vector3(-0.035,-0.045,-0.30 if id=="svd" else -0.265))
 baked.free()
 rifle.get_node("Magazine").set_meta("rest",Vector3.ZERO)
 rifle.position=Vector3(0.14,1.27,-0.25 if id=="svd" else -0.28)
 rifle.rotation=Vector3.ZERO
 pose_arm(model,"Left",rifle.position+support)
 pose_arm(model,"Right",rifle.position+Vector3(0.012,-0.09,0.145 if id=="svd" else 0.085))

# Bots use a lighter variant: centimetre-scale details (fingers, laces, eyes)
# get fewer facets, and colour-only material variants share one surface.
static func build(parent: Node3D, for_bot: bool=false) -> Node3D:
 var scene: PackedScene=cached_bot if for_bot else cached
 if scene!=null:
  var instance: Node3D=scene.instantiate()
  parent.add_child(instance)
  return instance
 Models.lite=for_bot
 var root := build_model(parent)
 Models.lite=false
 if for_bot:consolidate(root)
 assign_owner(root,root)
 var packed := PackedScene.new()
 packed.pack(root)
 if for_bot:cached_bot=packed
 else:cached=packed
 return root

# Weapon, glove and sole materials carry fine triplanar detail that a bot's
# rifle a few metres away cannot show: they become their mean colour.
const VERTEX_COLOURED := ["glove","gun_metal","gun_edge","gun_polymer","gun_grip","gun_rubber","gun_recess","polymer","steel","black","wood","bakelite","rubber"]
const PLAIN := "plain|0.860|0.000"
# Static groups that never move against their bone: their meshes merge into
# the bone. Named groups stay as empty markers (the wrist, for grip checks).
const STATIC_GROUPS := ["Pouch","Helmet","Hand"]
static var texture_means: Dictionary = {}

static func material_family(material: Material) -> String:
 if not material is StandardMaterial3D:return ""
 var m: StandardMaterial3D=material
 if m.resource_name.begins_with("gear_#"):return "gear"
 if m.resource_name.begins_with("uniform") or m.resource_name in ["cloth","character_skin"]:return ""
 if m.resource_name in VERTEX_COLOURED:return PLAIN
 if m.albedo_texture!=null or m.normal_enabled or m.roughness_texture!=null or m.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return ""
 return "plain|%.3f|%.3f" % [m.roughness,m.metallic]

static func texture_mean(texture: Texture2D) -> Color:
 # Noise ramps run from 0.55 to 1.0; imported textures are sampled once.
 var mean := Color(0.775,0.775,0.775)
 if texture==null:return Color.WHITE
 if texture is NoiseTexture2D:return mean
 var key := texture.resource_path
 if texture_means.has(key):return texture_means[key]
 var image := texture.get_image()
 if image!=null and not image.is_empty():
  if image.is_compressed():image.decompress()
  if not image.is_compressed():
   var sum := Vector3.ZERO
   for y in range(16):
    for x in range(16):
     var c := image.get_pixel((x*2+1)*image.get_width()/32,(y*2+1)*image.get_height()/32)
     sum+=Vector3(c.r,c.g,c.b)
   sum/=256.0
   mean=Color(sum.x,sum.y,sum.z)
 texture_means[key]=mean
 return mean

static func flat_colour(material: StandardMaterial3D) -> Color:
 var color := material.albedo_color
 if material.resource_name in VERTEX_COLOURED:color*=texture_mean(material.albedo_texture)
 color.a=1
 return color

static func flatten_static(part: Node3D) -> void:
 for child in part.get_children():
  if child.get_class()!="Node3D" or child.get_child_count()==0:continue
  var label := String(child.name)
  if not (label.begins_with("@") or label in STATIC_GROUPS):continue
  var leaves := true
  for item in child.get_children():
   if not item is MeshInstance3D or item.get_child_count()>0:leaves=false
  if not leaves:continue
  for item in child.get_children():
   var pose: Transform3D=child.transform*item.transform
   child.remove_child(item)
   part.add_child(item)
   item.transform=pose
  if label.begins_with("@"):child.free()

# Per bone, materials that differ only in albedo colour become one material
# with vertex colours: the same shading in one draw call instead of several.
static func consolidate(part: Node3D) -> void:
 flatten_static(part)
 var groups: Dictionary={}
 for child in part.get_children():
  if child is MeshInstance3D and child.get_child_count()==0 and child.mesh!=null and child.mesh.get_surface_count()==1:
   var family := material_family(child.get_active_material(0))
   if family!="":
    if not groups.has(family):groups[family]=[]
    groups[family].append(child)
  elif child is Node3D:consolidate(child)
 for family in groups:
  var members: Array=groups[family]
  var vertices := PackedVector3Array()
  var normals := PackedVector3Array()
  var colors := PackedColorArray()
  var indices := PackedInt32Array()
  for node in members:
   var arrays: Array=node.mesh.surface_get_arrays(0)
   var xf: Transform3D=node.transform
   var base := vertices.size()
   var source: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var source_normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var color: Color=flat_colour(node.get_active_material(0))
   for i in range(source.size()):
    vertices.append(xf*source[i])
    normals.append((xf.basis*source_normals[i]).normalized())
    colors.append(color)
   var source_indices=arrays[Mesh.ARRAY_INDEX]
   if source_indices!=null and source_indices.size()>0:
    for index in source_indices:indices.append(base+index)
   else:
    for i in range(source.size()):indices.append(base+i)
  var key: String=family
  if not family_materials.has(key):
   var shared: StandardMaterial3D
   if family=="gear":shared=members[0].get_active_material(0).duplicate()
   else:
    var values: PackedStringArray=family.split("|")
    shared=StandardMaterial3D.new()
    shared.roughness=float(values[1])
    shared.metallic=float(values[2])
   shared.resource_name="soldier_"+family
   shared.albedo_color=Color.WHITE
   shared.vertex_color_use_as_albedo=true
   family_materials[key]=shared
  var arrays := []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices
  arrays[Mesh.ARRAY_NORMAL]=normals
  arrays[Mesh.ARRAY_COLOR]=colors
  arrays[Mesh.ARRAY_INDEX]=indices
  var mesh := ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var merged := MeshInstance3D.new()
  merged.mesh=mesh
  merged.material_override=family_materials[key]
  merged.cast_shadow=members[0].cast_shadow
  for node in members:node.free()
  part.add_child(merged)
 # Centimetre details (hands, bolt, magazine) cast no visible shadow.
 for child in part.get_children():
  if child is MeshInstance3D and child.mesh!=null and child.mesh.get_aabb().get_longest_axis_size()<0.16:
   child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func build_model(parent: Node3D) -> Node3D:
 for color in ["#62674e","#555e49","#444d3c","#555f49","#59644e","#747c60"]:
  var key: String="gear_"+color
  if not Models.materials.has(key):
   var material := Models.surface("cloth").duplicate() as StandardMaterial3D
   material.resource_name=key
   material.albedo_color=Color(color)
   material.roughness=0.96
   Models.materials[key]=material
 if not Models.materials.has("uniform"):Models.materials["uniform"]=Wardrobe.fabric("rf_digital")
 var root := Models.group(parent,"Soldier")
 shell(root,[Vector4(0.83,0.32,0.24,0.028),Vector4(0.90,0.37,0.285,0.027),Vector4(1.00,0.34,0.26,0.023),Vector4(1.11,0.345,0.25,0.018),Vector4(1.24,0.40,0.28,0.018),Vector4(1.36,0.44,0.27,0.017),Vector4(1.43,0.42,0.23,0.012),Vector4(1.49,0.15,0.14,0.01)],"uniform",0.025)
 # Collar, shirt placket, belt and separate contoured front/back plate bags.
 for side in [-1,1]:Models.bevel(root,Vector3(side*0.062,1.47,-0.035),Vector3(0.025,0.068,0.092),"uniform",0.008).rotation.z=side*0.28
 Models.bevel(root,Vector3(0,1.26,-0.13),Vector3(0.027,0.37,0.008),"uniform",0.002)
 shell(root,[Vector4(0.937,0.365,0.29,0.018),Vector4(0.981,0.365,0.29,0.018)],"#3e4537",0,24)
 Models.bevel(root,Vector3(0,0.959,-0.132),Vector3(0.055,0.037,0.011),"#777965",0.004)
 for side in [-1,1]:
  var plate := shell(root,[Vector4(1.045,0.30,0.065,side*0.145),Vector4(1.09,0.34,0.085,side*0.145),Vector4(1.34,0.32,0.071,side*0.145),Vector4(1.42,0.235,0.055,side*0.135)],"gear_#555f49",0.008)
  plate.name="FrontPlate" if side<0 else "BackPlate"
 for x in [-0.13,0.13]:
  Models.bevel(root,Vector3(x,1.437,0.013),Vector3(0.052,0.038,0.276),"gear_#59644e",0.014)
  Models.bevel(root,Vector3(x,1.39,-0.161),Vector3(0.036,0.032,0.009),"#303a30",0.003)
 for x in [-0.109,0,0.109]:pouch(root,Vector3(x,1.115,-0.207),Vector3(0.096,0.181,0.068))
 for y in [1.275,1.312,1.349]:
  for x in [-0.10,0,0.10]:Models.bevel(root,Vector3(x,y,-0.184),Vector3(0.079,0.015,0.006),"gear_#747c60",0.002)
 pouch(root,Vector3(0.22,1.015,0.018),Vector3(0.105,0.16,0.13))
 for z in [-0.06,0.025]:pouch(root,Vector3(-0.218,0.99,z),Vector3(0.06,0.14,0.06))
 var head_root := Models.group(root,"Head",Vector3(0,1.5,0))
 head(head_root)
 Models.merge_rigid(head_root)
 for side in [-1,1]:
  var leg := Models.group(root,"LeftLeg" if side<0 else "RightLeg",Vector3(side*0.115,0.89,0))
  shell(leg,[Vector4(0.03,0.185,0.224,0.015),Vector4(-0.07,0.188,0.216,0.012),Vector4(-0.18,0.176,0.196,0.014),Vector4(-0.27,0.155,0.173,0.015),Vector4(-0.36,0.14,0.156,0.015)],"uniform",0.025)
  Models.bevel(leg,Vector3(side*0.082,-0.18,0.02),Vector3(0.026,0.15,0.12),"uniform",0.01)
  var knee := Models.group(leg,"Knee",Vector3(0,-0.36,0.015))
  shell(knee,[Vector4(0.025,0.145,0.154,0),Vector4(-0.08,0.15,0.16,0.012),Vector4(-0.18,0.136,0.144,0.015),Vector4(-0.27,0.113,0.121,0.008),Vector4(-0.355,0.103,0.110,0)],"uniform",0.035)
  Models.ellipsoid(knee,Vector3(0,-0.018,-0.075),Vector3(0.126,0.143,0.038),"#555e4d")
  Models.ellipsoid(knee,Vector3(0,-0.021,-0.092),Vector3(0.094,0.106,0.020),"#353d34")
  var foot := Models.group(knee,"Foot",Vector3(0,-0.36,0))
  shell(foot,[Vector4(-0.07,0.118,0.145,0.012),Vector4(-0.02,0.118,0.155,0.008),Vector4(0.07,0.108,0.137,0.008),Vector4(0.13,0.106,0.130,0.008)],"#4c4b40",0.015,24,0.72)
  # Separate rounded toe/vamp and ankle; a boot does not taper to a wedge.
  Models.ellipsoid(foot,Vector3(0,-0.048,-0.068),Vector3(0.132,0.087,0.235),"#4c4b40")
  shell(foot,[Vector4(-0.073,0.138,0.265,-0.047),Vector4(-0.09,0.139,0.266,-0.047)],"gun_rubber",0,24,0.7)
  Models.bevel(foot,Vector3(0,0.025,-0.065),Vector3(0.059,0.16,0.012),"#44483d",0.006).rotation.x=-0.20
  for i in range(5):
   var y := 0.086-i*0.025
   var z := -0.061-i*0.006
   Models.limb(foot,Vector3(-0.034,y,z),Vector3(0.034,y-0.008,z-0.008),0.0015,"#898875")
   Models.limb(foot,Vector3(0.034,y,z),Vector3(-0.034,y-0.008,z-0.008),0.0015,"#898875")
  Models.merge_rigid(foot)
  Models.merge_rigid(knee)
  Models.merge_rigid(leg)
 for side in [-1,1]:
  var arm := Models.group(root,"LeftArm" if side<0 else "RightArm",Vector3(side*0.218,1.38,-0.065 if side<0 else 0.015))
  var elbow := UPPER_LEFT if side<0 else UPPER_RIGHT
  var wrist := LOWER_LEFT if side<0 else LOWER_RIGHT
  sleeve(arm,elbow,true)
  var forearm := Models.group(arm,"Forearm",elbow)
  sleeve(forearm,wrist,false)
  glove(forearm,wrist)
  Models.merge_rigid(forearm)
  Models.merge_rigid(arm)
 var rifle := Models.group(root,"CarriedRifle")
 var baked: Node3D=load("res://assets/models/ak74m.scn").instantiate()
 Models.clear_owners(baked)
 for child in baked.get_children():
  baked.remove_child(child)
  rifle.add_child(child)
 baked.free()
 Models.marker(rifle,"BotMuzzle",Vector3(0,0,-0.635))
 rifle.position=Vector3(0.14,1.27,-0.28)
 rifle.get_node("Magazine").set_meta("rest",Vector3.ZERO)
 pose_arm(root,"Left",rifle.position+Vector3(-0.035,-0.045,-0.265))
 pose_arm(root,"Right",rifle.position+Vector3(0.012,-0.09,0.085))
 Models.merge_rigid(root)
 return root

static func team_markings(model: Node3D, friendly: bool) -> void:
 # Team identity is independent of camouflage choice. Bands follow arm joints.
 for side in ["Left","Right"]:
  var arm := model.get_node_or_null(side+"Arm") as Node3D
  if arm==null:continue
  var old := arm.get_node_or_null("TeamTape")
  if old!=null:old.free()
  var band := Models.group(arm,"TeamTape")
  var direction := UPPER_LEFT if side=="Left" else UPPER_RIGHT
  var color := "#c2a331" if friendly else "#a83e32"
  var axis := direction.normalized()
  for offset in [-0.017,0.017]:
   Models.tube(band,direction*0.48+axis*offset,0.077,0.029,color,axis,0.076)
  Models.merge_rigid(band)
  band.set_meta("team","ua" if friendly else "rf")
