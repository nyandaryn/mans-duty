class_name CartridgeDebris
extends Node3D

var game: Node3D
var active: Array[Dictionary] = []
var batches: Dictionary = {}
var meshes: Dictionary = {}
var emitted_cases := 0
var emitted_live := 0
var settled_count := 0

func cartridge_mesh(pistol: bool, live: bool) -> Mesh:
 var key := str(pistol)+str(live)
 if meshes.has(key):return meshes[key]
 var root := Node3D.new()
 Models.tube(root,Vector3.ZERO,0.0045,0.018 if pistol else 0.037,"brass",Vector3.FORWARD)
 if live:Models.tube(root,Vector3(0,0,-0.013 if pistol else -0.023),0.004,0.009,"brass",Vector3.FORWARD,0.001)
 else:Models.tube(root,Vector3(0,0,-0.009 if pistol else -0.019),0.003,0.0005,"brass",Vector3.FORWARD)
 Models.merge_rigid(root)
 var mesh: Mesh=root.get_child(0).mesh
 meshes[key]=mesh
 root.free()
 return mesh

func eject(point: Vector3, basis: Basis, weapon_id: String, live: bool=false) -> void:
 var pistol := weapon_id in ["pm","m9"]
 var body := RigidBody3D.new()
 body.mass=0.012 if live else 0.005
 body.collision_layer=8
 body.collision_mask=1
 body.continuous_cd=true
 var shape := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.radius=0.0045
 capsule.height=0.026 if pistol else 0.046
 shape.shape=capsule
 shape.rotation.x=PI/2
 body.add_child(shape)
 var visual := MeshInstance3D.new()
 visual.mesh=cartridge_mesh(pistol,live)
 visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 body.add_child(visual)
 var physics_material := PhysicsMaterial.new()
 physics_material.friction=0.7
 physics_material.bounce=0.18
 body.physics_material_override=physics_material
 add_child(body)
 body.global_transform=Transform3D(basis,point)
 body.linear_velocity=basis.x*randf_range(1.3,2.0)+Vector3.UP*randf_range(0.65,1.1)
 body.angular_velocity=Vector3(9,13,7)
 active.append({"body":body,"age":0.0,"pistol":pistol,"live":live,"paused":false})
 if live:emitted_live+=1
 else:emitted_cases+=1

func settle(entry: Dictionary) -> void:
 var body: RigidBody3D=entry.body
 var point := body.global_position
 var key := str(entry.pistol)+str(entry.live)+":"+str(floori(point.x/16))+":"+str(floori(point.z/16))
 if not batches.has(key):
  var multi := MultiMesh.new()
  multi.transform_format=MultiMesh.TRANSFORM_3D
  multi.mesh=cartridge_mesh(entry.pistol,entry.live)
  multi.instance_count=32
  multi.visible_instance_count=0
  var node := MultiMeshInstance3D.new()
  node.multimesh=multi
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(node)
  batches[key]={"multi":multi,"poses":[]}
 var batch: Dictionary=batches[key]
 batch.poses.append(body.global_transform)
 var multi: MultiMesh=batch.multi
 if batch.poses.size()>multi.instance_count:
  multi.instance_count*=2
  for i in range(batch.poses.size()):multi.set_instance_transform(i,batch.poses[i])
 else:multi.set_instance_transform(batch.poses.size()-1,body.global_transform)
 multi.visible_instance_count=batch.poses.size()
 settled_count+=1
 body.queue_free()

func clear() -> void:
 for child in get_children():child.queue_free()
 active.clear()
 batches.clear()
 emitted_cases=0
 emitted_live=0
 settled_count=0

func _physics_process(delta: float) -> void:
 for i in range(active.size()-1,-1,-1):
  var entry: Dictionary=active[i]
  var body: RigidBody3D=entry.body
  var stop: bool=game.paused or not game.running
  if stop!=bool(entry.paused):
   if stop:
    entry.velocity=body.linear_velocity
    entry.spin=body.angular_velocity
    body.freeze=true
   else:
    body.freeze=false
    body.linear_velocity=entry.velocity
    body.angular_velocity=entry.spin
   entry.paused=stop
  if stop:continue
  entry.age+=delta
  if body.global_position.y< -10:
   body.queue_free()
   active.remove_at(i)
  elif (body.sleeping and float(entry.age)>0.4) or float(entry.age)>10:
   settle(entry)
   active.remove_at(i)
