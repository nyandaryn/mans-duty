class_name FaceCover
extends RefCounted

# What covers the face under the helmet: a knitted balaclava with a slot for
# the eyes, or a neck gaiter pulled up over the nose. Cut from the head's own
# surface (CharacterArt.anatomical_head) and lifted 4.5 mm off it, so it fits
# the face it is on; a short tube carries it down into the collar.
const IDS := ["none","black","olive","coyote","camo","gaiter"]
const DATA := {
 "none":{"name":"Без балаклави","short":"НЕМАЄ","mass":0.0,"brief":"Обличчя й шия відкриті."},
 "black":{"name":"Балаклава чорна","short":"ЧОРНА","mass":0.08,"color":"1e1f1e","brief":"В'язана балаклава з прорізом для очей. Закриває світлу шкіру обличчя, вуха й шию; під шоломом не заважає."},
 "olive":{"name":"Балаклава олива","short":"ОЛИВА","mass":0.08,"color":"4a4e37","brief":"В'язана балаклава кольору олива з прорізом для очей. Закриває обличчя, вуха й шию."},
 "coyote":{"name":"Балаклава койот","short":"КОЙОТ","mass":0.08,"color":"85704f","brief":"В'язана балаклава пісочного кольору (койот) з прорізом для очей. Закриває обличчя, вуха й шию."},
 "camo":{"name":"Балаклава в камуфляжі форми","short":"КАМУФЛЯЖ","mass":0.07,"camo":true,"brief":"Тонка балаклава з тієї ж тканини, що й форма: обличчя зливається з одягом."},
 "gaiter":{"name":"Бафф олива","short":"БАФФ","mass":0.05,"color":"4f5440","gaiter":true,"brief":"Трубка-горловик, натягнута на ніс: шия й низ обличчя закриті, очі, лоб і вуха відкриті."}
}
# Which of the bots wear one, by their place in the formation: about half.
const ISSUE := {
 "ua":["none","black","none","olive","none","gaiter","none","coyote"],
 "rf":["none","black","none","none","olive","none","gaiter","none"]
}
# The head mesh's eye slot (head-local metres): an ellipse round both eyes
# (CharacterArt.EYE at y 0.158), on the face only.
const SLOT_HALF_WIDTH := 0.085
const SLOT_HALF_HEIGHT := 0.031
const SLOT_Y := 0.157
const LIFT := 0.0045
static var meshes: Dictionary = {}
static var materials: Dictionary = {}
static var knit_texture: ImageTexture

static func valid(id: String) -> String:return id if id in IDS else "none"
static func label(id: String) -> String:return String(DATA[valid(id)].name)
static func mass(id: String) -> float:return float(DATA[valid(id)].mass)

static func issue(friendly: bool, index: int) -> String:
 var list: Array=ISSUE["ua" if friendly else "rf"]
 return list[absi(index)%list.size()]

# How far a point of the head is inside the knit (> 0) or out of it (< 0):
# the edge of the eye slot or the gaiter's top runs where this is zero.
static func coverage(v: Vector3, gaiter: bool) -> float:
 if gaiter:
  # Over the bridge of the nose in front, lower at the back of the head.
  return lerpf(0.128,0.085,clampf((v.z+0.06)/0.1,0.0,1.0))-v.y
 var slot := pow(v.x/SLOT_HALF_WIDTH,2.0)+pow((v.y-SLOT_Y)/SLOT_HALF_HEIGHT,2.0)-1.0
 # Only on the face: further back the knit stays whole.
 return slot+maxf(0.0,v.z+0.075)*40.0

# The head's surface under the knit, cut along a smooth edge: a triangle the
# edge crosses keeps the part on the knit's side, split where the edge runs.
static func mesh(gaiter: bool) -> ArrayMesh:
 var key := "gaiter" if gaiter else "balaclava"
 if meshes.has(key):return meshes[key]
 var arrays: Array=CharacterArt.anatomical_head().surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var points := PackedVector3Array()
 var directions := PackedVector3Array()
 var values := PackedFloat32Array()
 for i in range(vertices.size()):
  points.append(vertices[i]+normals[i]*LIFT)
  directions.append(normals[i])
  values.append(coverage(vertices[i],gaiter))
 var kept := PackedInt32Array()
 for t in range(0,indices.size(),3):
  var corner := [indices[t],indices[t+1],indices[t+2]]
  var inside := 0
  for c in corner:if values[c]>0.0:inside+=1
  if inside==3:kept.append_array(corner);continue
  if inside==0:continue
  # The kept polygon: corners on the knit's side and the edge's crossings.
  var polygon: Array[int]=[]
  for k in range(3):
   var i: int=corner[k]
   var j: int=corner[(k+1)%3]
   if values[i]>0.0:polygon.append(i)
   if (values[i]>0.0)!=(values[j]>0.0):
    var w := values[i]/(values[i]-values[j])
    points.append(points[i].lerp(points[j],w))
    directions.append(directions[i].lerp(directions[j],w).normalized())
    values.append(0.0)
    polygon.append(points.size()-1)
  for k in range(1,polygon.size()-1):kept.append_array([polygon[0],polygon[k],polygon[k+1]])
 var surface := []
 surface.resize(Mesh.ARRAY_MAX)
 surface[Mesh.ARRAY_VERTEX]=points
 surface[Mesh.ARRAY_NORMAL]=directions
 surface[Mesh.ARRAY_INDEX]=kept
 var result := ArrayMesh.new()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface)
 meshes[key]=result
 return result

# Fine ribs of a knit, grey: the colour comes from the material.
static func knit() -> ImageTexture:
 if knit_texture!=null:return knit_texture
 var image := Image.create(32,32,false,Image.FORMAT_RGB8)
 for y in range(32):
  for x in range(32):
   var rib := 0.80+0.20*absf(sin(float(x)*PI/4.0))
   var loop := 0.93+0.07*absf(sin(float(y)*PI/3.0+float(x/4)*1.3))
   var v := rib*loop
   image.set_pixel(x,y,Color(v,v,v))
 image.generate_mipmaps()
 knit_texture=ImageTexture.create_from_image(image)
 return knit_texture

static func material(id: String, outfit: String) -> Material:
 id=valid(id)
 if bool(DATA[id].get("camo",false)):return Wardrobe.fabric(outfit)
 if materials.has(id):return materials[id]
 var knitted := StandardMaterial3D.new()
 knitted.resource_name="gear_#"+String(DATA[id].color)
 knitted.albedo_color=Color(String(DATA[id].color))
 knitted.albedo_texture=knit()
 knitted.uv1_triplanar=true
 knitted.uv1_scale=Vector3.ONE*22.0
 knitted.roughness=1.0
 knitted.cull_mode=BaseMaterial3D.CULL_DISABLED
 knitted.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 materials[id]=knitted
 return knitted

# Puts it on a soldier's model (under his "Head"), replacing any he had.
static func wear(model: Node3D, id: String, outfit: String="ua_pixel") -> void:
 id=valid(id)
 model.set_meta("face_cover",id)
 var head: Node3D=model.get_node_or_null("Head")
 if head==null:return
 var previous := head.get_node_or_null("FaceCover")
 if previous!=null:previous.free()
 if id=="none":return
 var group := Node3D.new()
 group.name="FaceCover"
 head.add_child(group)
 var cloth := material(id,outfit)
 var mask := MeshInstance3D.new()
 mask.name="Mask"
 mask.mesh=mesh(bool(DATA[id].get("gaiter",false)))
 mask.material_override=cloth
 group.add_child(mask)
 # Down the neck into the collar: just inside the mask at its lower edge
 # (the neck there is 0.154 m across, 0.127 m deep, squarish: square 0.7).
 var neck := CharacterArt.shell(group,[Vector4(-0.075,0.172,0.165,-0.015),Vector4(-0.02,0.172,0.156,-0.016),Vector4(0.01,0.164,0.138,-0.018),Vector4(0.03,0.150,0.120,-0.02)],"cloth",0.0,24,0.7,true)
 neck.name="Neck"
 neck.material_override=cloth
