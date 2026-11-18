class_name ScopeSight
extends Node

const FIELD_OF_VIEW := 6.0
const MAGNIFICATION := 4.0
const EXIT_PUPIL := 0.006
const FIRST_PERSON_LAYER := 2
var operator: Operator
var viewport: SubViewport
var camera: Camera3D
var reticle: Control
var lens: MeshInstance3D
var lens_material: ShaderMaterial
var view_texture: ViewportTexture
var enabled := false
var eye_offset := Vector3.ZERO
var occluded := false
static var drops: Dictionary={}

# Calibrate to the game's actual gravity/drag integrator, not an ideal vacuum
# parabola or a target raycast. No target position is used by the optic.
static func trajectory_drop(distance: float) -> float:
 var key := snappedf(distance,0.01)
 if drops.has(key):return drops[key]
 var position := Vector3.ZERO
 var velocity := Vector3(0,0,-float(Ballistics.PROFILES.svd.speed))
 for i in range(7200):
  var next := FlightModel.advance(position,velocity,float(FlightModel.BC.svd),1.0/240)
  if -next[0].z>=distance:
   var fraction := (distance+position.z)/(position.z-next[0].z)
   drops[key]=lerpf(position.y,next[0].y,fraction)
   return drops[key]
  position=next[0]
  velocity=next[1]
 return position.y

static func sight_direction(distance: float) -> Vector3:
 var range := maxf(distance,25)
 return Vector3(-SvdArt.OCULAR.x,trajectory_drop(range-(SvdArt.OCULAR.z+0.80))-SvdArt.OCULAR.y,-range).normalized()

static func optical_basis() -> Basis:
 return Basis.looking_at(sight_direction(100),Vector3.UP)

static func reticle_angles(distance: float, windage_clicks: int=0) -> Vector2:
 var direction := optical_basis().inverse()*sight_direction(distance)
 return Vector2(atan2(direction.x,-direction.z)-windage_clicks*0.0005,atan2(-direction.y,-direction.z))

static func set_first_person(root: Node) -> void:
 if root is VisualInstance3D:root.layers=FIRST_PERSON_LAYER
 for child in root.get_children():set_first_person(child)

func setup(owner_operator: Operator) -> void:
 operator=owner_operator
 viewport=SubViewport.new()
 viewport.size=Vector2i(768,768)
 viewport.world_3d=operator.get_world_3d()
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 viewport.msaa_3d=Viewport.MSAA_2X
 add_child(viewport)
 camera=Camera3D.new()
 camera.near=0.025
 camera.far=1500
 camera.fov=FIELD_OF_VIEW
 camera.cull_mask=1
 viewport.add_child(camera)
 camera.current=true
 reticle=Control.new()
 reticle.set_script(load("res://scripts/scope_reticle.gd"))
 reticle.sight=self
 viewport.add_child(reticle)
 reticle.size=Vector2(viewport.size)
 # Keep the render texture and its material alive across weapon and UI rebuilds.
 view_texture=viewport.get_texture()
 lens_material=ShaderMaterial.new()
 lens_material.shader=load("res://scripts/scope_lens.gdshader")
 lens_material.set_shader_parameter("view",view_texture)

func attach(rig: WeaponRig) -> void:
 enabled=false
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 lens_material.set_shader_parameter("active",0.0)
 lens=null
 if not rig.has_meta("optic"):return
 lens=MeshInstance3D.new()
 lens.name="OpticalImage"
 var quad := QuadMesh.new()
 quad.size=Vector2.ONE*SvdArt.LENS_RADIUS*2
 lens.mesh=quad
 lens.position=SvdArt.OCULAR+Vector3(0,0,0.001)
 lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 lens.layers=FIRST_PERSON_LAYER
 lens_material.set_shader_parameter("view",view_texture)
 lens.material_override=lens_material
 rig.add_child(lens)

func update() -> void:
 var active: bool= is_instance_valid(lens) and operator.viewmodel.visible and operator.current().id=="svd" and operator.ads_weight>0.45 and operator.current().phase=="" and operator.bandage_time<=0 and operator.arm_injury<0.5 and operator.blind_mode==0 and operator.game.running and not operator.game.paused and not operator.game.commands_open and not operator.game.inventory_open
 if active and not enabled:
  # Restore the complete optical render state after reload, inventory or swap.
  viewport.world_3d=operator.get_world_3d()
  viewport.size=Vector2i(768,768)
  camera.fov=FIELD_OF_VIEW
  camera.make_current()
  lens_material.set_shader_parameter("view",view_texture)
  reticle.size=Vector2(viewport.size)
 enabled=active
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
 if not is_instance_valid(lens):return
 lens_material.set_shader_parameter("active",1.0 if active else 0.0)
 if not active:return
 var rig: WeaponRig=operator.viewmodel
 eye_offset=rig.to_local(operator.camera.global_position)-SvdArt.OCULAR
 camera.global_transform=Transform3D(rig.global_basis*optical_basis(),rig.to_global(SvdArt.OCULAR))
 var query := PhysicsRayQueryParameters3D.create(operator.camera.global_position,rig.get_node("ScopeObjective").global_position,1,[operator.get_rid()])
 query.hit_from_inside=true
 occluded=not operator.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
 lens_material.set_shader_parameter("pupil",Vector2(eye_offset.x,-eye_offset.y)/(EXIT_PUPIL*0.5))
 lens_material.set_shader_parameter("relief_error",absf(eye_offset.z-SvdArt.EYE_RELIEF)/0.04)
 lens_material.set_shader_parameter("blocked",1.0 if occluded else 0.0)
 reticle.queue_redraw()
 rig.get_node("PSO1/Elevation").rotation.y=-float(operator.current().scope_zero-100)/100*TAU/10
 rig.get_node("PSO1/Windage").rotation.x=operator.current().scope_windage*TAU/60
