class_name BloodSystem
extends Node3D

var game: Node3D
var wounds: Array[Dictionary]=[]
var ground_marks: Array[MeshInstance3D]=[]
var material: StandardMaterial3D
var stain_shader: Shader
var shape: QuadMesh

func _ready() -> void:
	material=StandardMaterial3D.new()
	material.albedo_texture=load("res://assets/textures/blood.png")
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold=0.2
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.roughness=1
	shape=QuadMesh.new()
	shape.size=Vector2.ONE
	# The stain reuses the clothing surface itself: it cannot float above a limb.
	stain_shader=Shader.new()
	stain_shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform sampler2D stain_texture : source_color;
uniform vec3 hit;
uniform vec3 hit_normal;
uniform vec3 tangent;
uniform vec3 bitangent;
uniform float radius=0.02;
varying vec3 local_position;
varying vec3 local_normal;
void vertex(){ local_position=VERTEX; local_normal=NORMAL; VERTEX+=NORMAL*0.0015; }
void fragment(){
 vec3 delta=local_position-hit;
 if(abs(dot(delta,hit_normal))>0.16 || dot(local_normal,hit_normal)<0.15) discard;
 vec2 uv=vec2(dot(delta,tangent),dot(delta,bitangent))/(radius*2.0)+vec2(0.5);
 if(uv.x<0.0 || uv.x>1.0 || uv.y<0.0 || uv.y>1.0) discard;
 vec4 stain=texture(stain_texture,uv);
 if(stain.a<0.2) discard;
 ALBEDO=stain.rgb; ROUGHNESS=1.0;
}"""

func mark(pos: Vector3, normal: Vector3, radius: float) -> MeshInstance3D:
	var patch := MeshInstance3D.new()
	patch.mesh=shape
	patch.material_override=material
	patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(patch)
	patch.position=pos
	patch.quaternion=Quaternion(Vector3.BACK,normal.normalized())
	patch.scale=Vector3(radius*2,radius*1.6,1)
	return patch

func add_wound(actor: Node3D, area: Area3D, point: Vector3, normal: Vector3, wound: Dictionary) -> void:
	if wound.kind=="blunt":return
	impact_spray(point,normal,wound.kind=="fatal_head")
	var anchor := Node3D.new()
	area.add_child(anchor)
	anchor.global_position=point
	var materials: Array[ShaderMaterial]=[]
	for source in area.get_parent().get_children():
		if not source is MeshInstance3D:continue
		if not source.get_aabb().grow(0.16).has_point(source.to_local(point)):continue
		var overlay := MeshInstance3D.new()
		overlay.mesh=source.mesh
		overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anchor.add_child(overlay)
		overlay.global_transform=source.global_transform
		var mat := ShaderMaterial.new()
		mat.shader=stain_shader
		var local_normal: Vector3=(source.global_basis.inverse()*normal).normalized()
		var tangent := local_normal.cross(Vector3.UP).normalized()
		if tangent.length()<0.1:tangent=Vector3.RIGHT
		mat.set_shader_parameter("hit",source.to_local(point))
		mat.set_shader_parameter("hit_normal",local_normal)
		mat.set_shader_parameter("tangent",tangent)
		mat.set_shader_parameter("bitangent",local_normal.cross(tangent).normalized())
		mat.set_shader_parameter("stain_texture",material.albedo_texture)
		overlay.material_override=mat
		materials.append(mat)
	wounds.append({"actor":weakref(actor),"patch":weakref(anchor),"materials":materials,"flow":float(wound.bleeding),"age":0.0,"timer":0.0,"dead_age":0.0,"internal":wound.kind=="internal"})

func clear() -> void:
	wounds.clear()
	for node in ground_marks:
		if is_instance_valid(node):node.queue_free()
	ground_marks.clear()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or game.paused or game.menu.visible:return
	for i in range(wounds.size()-1,-1,-1):
		var wound: Dictionary=wounds[i]
		var patch: Node3D=wound.patch.get_ref()
		var actor: Node3D=wound.actor.get_ref()
		if not is_instance_valid(patch) or not is_instance_valid(actor):
			wounds.remove_at(i)
			continue
		var dead: bool=actor.dead if actor is Hostile else actor.health<=0
		if dead:wound.dead_age+=delta
		var flowing: bool=(actor.bleeding>0 or dead) and float(wound.dead_age)<20
		if not flowing:continue
		wound.age+=delta
		var growth := minf(0.16,float(wound.age)*float(wound.flow)*0.004)
		for mat in wound.materials:mat.set_shader_parameter("radius",0.028+growth)
		wound.timer-=delta
		if wound.timer>0:continue
		wound.timer=clampf(1.4/maxf(0.15,float(wound.flow)),0.3,5.0)
		if wound.internal:wound.timer*=3.0
		var start := patch.global_position+Vector3(randf_range(-0.13,0.13),0.025,randf_range(-0.13,0.13))
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start+Vector3.DOWN*3,1))
		if hit.is_empty():continue
		var radius := randf_range(0.018,0.035)+minf(0.12,float(wound.age)*0.004)*minf(1,float(wound.flow))
		ground_marks.append(mark(hit.position+hit.normal*0.004,hit.normal,radius))
		if ground_marks.size()>220:ground_marks.pop_front().queue_free()

func impact_spray(point: Vector3, normal: Vector3, head: bool=false) -> void:
	# Short visible droplets and nearby surface stains, never a HUD hit confirmation.
	var outward := normal.normalized() if normal.length_squared()>0.1 else Vector3.UP
	var far: bool=game.battle.active and Models.view_distance(self,point)>45
	for i in range(10 if head else 6):
		var direction := (outward+Vector3(randf_range(-0.9,0.9),randf_range(-0.3,0.9),randf_range(-0.9,0.9))).normalized()
		# Distant droplets are sub-pixel; their ground stains below are kept.
		if far:
			var hit_far := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+outward*0.02,point+direction*2.2+Vector3.DOWN,1))
			if not hit_far.is_empty() and hit_far.normal.length_squared()>0.1:
				ground_marks.append(mark(hit_far.position+hit_far.normal*0.004,hit_far.normal,randf_range(0.018,0.055)))
				if ground_marks.size()>220:ground_marks.pop_front().queue_free()
			continue
		var drop := Models.particle(game.world_root,point+outward*0.015,randf_range(0.008,0.016),"6b1716")
		game.effects.append({"node":drop,"velocity":direction*randf_range(0.8,2.2),"life":0.25,"spin":Vector3.ZERO,"type":"blood"})
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+outward*0.02,point+direction*2.2+Vector3.DOWN,1))
		if not hit.is_empty() and hit.normal.length_squared()>0.1:
			ground_marks.append(mark(hit.position+hit.normal*0.004,hit.normal,randf_range(0.018,0.055)))
			if ground_marks.size()>220:ground_marks.pop_front().queue_free()
