class_name BmpPeriscope
extends Node

# The eyepiece of a periscope in the BMP-2. A prism block is a window moved
# up and forward: through the lower window the eye sees what it would see
# from `lift` higher and further on, through the head window on the roof. A
# small viewport renders the world from the eye shifted by `lift`, through an
# off-axis frustum whose near rectangle is the head window, and the eyepiece
# glass shows it. Lean closer and the field widens, as in a real prism. It
# renders every frame while the glass is on the screen of the seat camera,
# at the resolution the glass takes there.
const FAR := 3000.0
const TINT := Color(0.86,0.93,0.88)
var viewport: SubViewport
var camera: Camera3D
var glass: MeshInstance3D
var size := Vector2.ONE
var lift := Vector3.ZERO
var live := false
var pixels := Vector2i.ZERO

func setup(parent: Node3D, item: Dictionary, index: int) -> void:
 name="Periscope%d" % index
 process_priority=1000
 size=item.size;lift=item.lift
 viewport=SubViewport.new();viewport.name="View";viewport.size=Vector2i(64,maxi(8,roundi(64*size.y/size.x)))
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 viewport.positional_shadow_atlas_size=0
 viewport.mesh_lod_threshold=2.0
 add_child(viewport)
 camera=Camera3D.new();camera.name="Head";camera.projection=Camera3D.PROJECTION_FRUSTUM
 camera.cull_mask=1|OperatorBody.WORLD_BODY_LAYER;camera.current=true
 viewport.add_child(camera)
 # Prism glass: a little green and darker than the day outside.
 var face:=StandardMaterial3D.new()
 face.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 face.albedo_texture=viewport.get_texture()
 face.albedo_color=TINT
 face.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
 var quad:=QuadMesh.new();quad.size=size;quad.material=face
 glass=MeshInstance3D.new();glass.name="Eyepiece%d" % index;glass.mesh=quad
 glass.transform=Transform3D(Basis(Vector3.UP,float(item.yaw)),Vector3(item.glass)+Basis(Vector3.UP,float(item.yaw))*Vector3(0,0,0.001))
 glass.layers=BmpArt.INTERIOR_LAYER
 glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(glass)

# The world through the glass for the seat camera, or nothing.
func update(viewer: Camera3D, on: bool) -> void:
 var screen:=on_screen(viewer) if on else Rect2()
 var show:=screen.has_area()
 if show!=live:
  live=show
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
 if not live:return
 # As many pixels as the glass covers, in steps of 32 so that the leaning
 # in and out does not resize the viewport every frame.
 var wide:=clampi(int(ceilf(screen.size.x/32.0))*32,64,2048)
 var want:=Vector2i(wide,maxi(16,roundi(wide*size.y/size.x)))
 if want!=pixels:pixels=want;viewport.size=want
 aim(viewer.global_position)

# The glass on the viewer's screen (empty when it is behind, edge-on or out
# of the picture).
func on_screen(viewer: Camera3D) -> Rect2:
 if viewer==null:return Rect2()
 var frame:=glass.global_transform
 if (viewer.global_position-frame.origin).dot(frame.basis.z)<0.01:return Rect2()
 var half:=size*0.5
 var box:=Rect2()
 var first:=true
 for corner: Vector3 in [Vector3(-half.x,-half.y,0),Vector3(half.x,-half.y,0),Vector3(-half.x,half.y,0),Vector3(half.x,half.y,0)]:
  var p:=frame*corner
  if viewer.is_position_behind(p):return Rect2(Vector2.ZERO,viewer.get_viewport().get_visible_rect().size)
  var q:=viewer.unproject_position(p)
  if first:box=Rect2(q,Vector2.ZERO);first=false
  else:box=box.expand(q)
 var view:=Rect2(Vector2.ZERO,viewer.get_viewport().get_visible_rect().size)
 return box if box.intersects(view) else Rect2()

func aim(eye: Vector3) -> void:
 var frame:=glass.global_transform
 var facing:=frame.basis.z.normalized()
 var up:=frame.basis.y.normalized()
 var right:=frame.basis.x.normalized()
 var depth:=maxf((eye-frame.origin).dot(facing),0.01)
 var parent: Node3D=glass.get_parent()
 var from:=eye+parent.global_basis*lift
 camera.global_transform=Transform3D(Basis(right,up,facing),from)
 var to_glass:=frame.origin-eye
 # The near plane a few millimetres past the head window: the head block and
 # the roof around it never show in their own image.
 var near:=depth+0.004
 var grow:=near/depth
 camera.set_frustum(size.y*grow,Vector2(to_glass.dot(right),to_glass.dot(up))*grow,near,FAR)
