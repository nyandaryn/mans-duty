class_name GradMirror
extends Node

# A rear-view mirror of the BM-21 cab. The glass shows what is really behind:
# a small viewport renders the world from the viewer's eye reflected in the
# plane of the glass, through an off-axis frustum whose near rectangle is the
# glass itself, and the image is turned left to right. It renders only while
# the glass is on screen, close by and seen from its reflecting side.
const TEXTURE := Vector2i(136,200)
const RANGE := 14.0
const FAR := 450.0
var vehicle: Node3D
var viewport: SubViewport
var camera: Camera3D
var glass: MeshInstance3D
var live := false

func setup(owner: Node3D, center: Vector3, index: int) -> void:
 vehicle=owner;name="Mirror%d" % index
 process_priority=1000
 viewport=SubViewport.new();viewport.name="View";viewport.size=TEXTURE
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 viewport.positional_shadow_atlas_size=0
 viewport.mesh_lod_threshold=4.0
 add_child(viewport)
 camera=Camera3D.new();camera.name="Eye";camera.projection=Camera3D.PROJECTION_FRUSTUM
 camera.cull_mask=1|OperatorBody.WORLD_BODY_LAYER;camera.current=true
 viewport.add_child(camera)
 # The viewport holds sRGB colours; slightly darker than the world, as a
 # silvered glass is.
 var face:=StandardMaterial3D.new()
 face.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 face.albedo_texture=viewport.get_texture();face.albedo_texture_force_srgb=true
 face.albedo_color=Color(0.86,0.86,0.86)
 face.uv1_scale=Vector3(-1,1,1);face.uv1_offset=Vector3(1,0,0)
 face.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
 var quad:=QuadMesh.new();quad.size=GradArt.MIRROR_SIZE;quad.material=face
 glass=MeshInstance3D.new();glass.name="MirrorGlass%d" % index;glass.mesh=quad
 glass.transform=GradArt.mirror_frame(center)
 glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 owner.art.root.add_child(glass)
 owner.add_child(self)

func _process(_delta: float) -> void:
 var viewer:=get_viewport().get_camera_3d()
 var show:=viewer!=null and viewer!=camera and sees(viewer)
 if show!=live:
  live=show
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
 if live:aim(viewer.global_position)

func sees(viewer: Camera3D) -> bool:
 var frame:=glass.global_transform
 var offset:=viewer.global_position-frame.origin
 if offset.length()>RANGE or offset.dot(frame.basis.z)<0.05:return false
 var half:=GradArt.MIRROR_SIZE*0.5
 for corner in [Vector3(-half.x,-half.y,0),Vector3(half.x,-half.y,0),Vector3(-half.x,half.y,0),Vector3(half.x,half.y,0)]:
  if viewer.is_position_in_frustum(frame*corner):return true
 return false

# The eye reflected in the glass plane looks out through the glass: its view
# is the mirror image of what the eye sees in the glass.
func aim(eye: Vector3) -> void:
 var frame:=glass.global_transform
 var facing:=frame.basis.z.normalized()
 var up:=frame.basis.y.normalized()
 var right:=frame.basis.x.normalized()
 var depth:=(eye-frame.origin).dot(facing)
 var mirrored:=eye-2.0*depth*facing
 camera.global_transform=Transform3D(Basis(-right,up,-facing),mirrored)
 var to_glass:=frame.origin-mirrored
 # The near plane lies a few millimetres in front of the glass, so the glass
 # and its housing never show in their own image.
 var near:=depth+0.004
 var grow:=near/depth
 camera.set_frustum(GradArt.MIRROR_SIZE.y*grow,Vector2(to_glass.dot(-right),to_glass.dot(up))*grow,near,FAR)
