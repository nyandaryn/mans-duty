class_name ModelPreview
extends TextureRect

var viewport: SubViewport
var camera: Camera3D
var model: Node3D
var content_key := ""
var corners: Array[Vector3] = []
var actor_view := false
var rear_view := false

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 stretch_mode=TextureRect.STRETCH_SCALE
 viewport=SubViewport.new()
 viewport.own_world_3d=true
 viewport.transparent_bg=true
 viewport.msaa_3d=Viewport.MSAA_4X
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(viewport)
 texture=viewport.get_texture()
 var world := WorldEnvironment.new()
 var environment := Environment.new()
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color=Color("d6dfeb")
 environment.ambient_light_energy=0.8
 add_studio_reflection(environment)
 world.environment=environment
 viewport.add_child(world)
 for i in range(3):
  var light := DirectionalLight3D.new()
  light.rotation_degrees=[Vector3(-35,-35,0),Vector3(-15,140,0),Vector3(25,35,0)][i]
  light.light_energy=[1.6,0.8,0.5][i]
  viewport.add_child(light)
 camera=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.near=0.01
 viewport.add_child(camera)
 resized.connect(fit)

func show_weapon(id: String, magazine_only: bool=false) -> void:
 var key := id+str(magazine_only)
 if key==content_key:return
 content_key=key
 actor_view=false
 var baked: Node3D=load("res://assets/models/"+("ak74m" if id=="ak74" else id)+".scn").instantiate()
 Models.clear_owners(baked)
 if magazine_only:
  var magazine: Node3D=baked.get_node("Magazine")
  baked.remove_child(magazine)
  baked.free()
  MagazineView.decorate(magazine,id)
  MagazineView.update(magazine,int(WeaponState.DATA[id].capacity))
  replace_model(magazine)
 else:replace_model(baked)

func show_outfit(id: String, weapon_id: String="", backpack: bool=false, launcher: bool=false) -> void:
 var key := id+weapon_id+("pack" if backpack else "")+("launcher" if launcher else "")
 if content_key==key:return
 content_key=key
 actor_view=true
 var holder := Node3D.new()
 var soldier := Models.soldier(holder)
 if weapon_id!="":CharacterArt.equip_display(soldier,weapon_id)
 Wardrobe.dress(soldier,id)
 CharacterArt.team_markings(soldier,true)
 PackArt.equip(soldier,backpack)
 if launcher:PackArt.attach_launcher(soldier)
 replace_model(holder)

func show_item(kind: String) -> void:
 if content_key==kind:return
 content_key=kind
 actor_view=false
 replace_model(PackArt.item_model(kind))

func replace_model(next: Node3D) -> void:
 if is_instance_valid(model):model.free()
 model=next
 polish_fabric(model)
 viewport.add_child(model)
 corners.clear()
 for child in model.find_children("*","MeshInstance3D",true,false):
  var mesh := child as MeshInstance3D
  var box := mesh.get_aabb()
  for i in range(8):corners.append(mesh.global_transform*box.get_endpoint(i))
 fit()

func fit() -> void:
 if not is_instance_valid(viewport) or corners.is_empty():return
 viewport.size=Vector2i(maxi(64,int(size.x*2)),maxi(64,int(size.y*2)))
 var low := corners[0]
 var high := corners[0]
 for point in corners:
  low=low.min(point)
  high=high.max(point)
 var center := (low+high)*0.5
 camera.position=center+((Vector3(1.4,0.3,3) if rear_view else Vector3(0.8,0.25,-3)) if actor_view else (Vector3(3,0.22,0.35) if content_key.ends_with("false") or content_key.ends_with("true") else Vector3(3,2,3)))
 camera.look_at(center)
 var extent := Vector2.ZERO
 for point in corners:
  var projected := camera.global_basis.inverse()*(point-center)
  extent=extent.max(Vector2(absf(projected.x),absf(projected.y)))
 var aspect := float(viewport.size.x)/viewport.size.y
 camera.size=maxf(extent.y*2,extent.x*2/aspect)*1.13
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

static func add_studio_reflection(environment: Environment) -> void:
 var sky := Sky.new()
 var material := ProceduralSkyMaterial.new()
 material.sky_top_color=Color("b6c4d4")
 material.sky_horizon_color=Color("e4e7e9")
 material.ground_horizon_color=Color("bdc5c8")
 material.ground_bottom_color=Color("68727a")
 sky.sky_material=material
 environment.sky=sky
 environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY

static var preview_fabrics: Dictionary = {}
static func polish_fabric(root: Node3D) -> void:
 for node in root.find_children("*","MeshInstance3D",true,false):
  for i in range(node.mesh.get_surface_count()):
   var material: Material=node.get_active_material(i)
   if not material is StandardMaterial3D or not material.resource_name.begins_with("uniform"):continue
   var key := material.resource_name
   if not preview_fabrics.has(key):
    var copy := material.duplicate() as StandardMaterial3D
    var pixels: Image = material.albedo_texture.get_image()
    pixels.generate_mipmaps()
    copy.albedo_texture=ImageTexture.create_from_image(pixels)
    copy.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    preview_fabrics[key]=copy
   node.set_surface_override_material(i,preview_fabrics[key])
