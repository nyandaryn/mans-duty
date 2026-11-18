class_name CartridgeDebris
extends Node3D

var game: Node3D
var active: Array[Dictionary] = []
var batches: Dictionary = {}
var meshes: Dictionary = {}
var emitted_cases := 0
var emitted_live := 0
var settled_count := 0

func cartridge_mesh(pistol: bool, live: bool, svd: bool=false) -> Mesh:
 var key := str(pistol)+str(live)+str(svd)
 if meshes.has(key):return meshes[key]
 var root := Node3D.new()
 var case_length := 0.054 if svd else (0.018 if pistol else 0.037)
 var radius := 0.006 if svd else 0.0045
 if svd:SvdArt.cartridge(root,live)
 else:
  Models.tube(root,Vector3.ZERO,radius,case_length,"brass",Vector3.FORWARD)
  if live:Models.tube(root,Vector3(0,0,-case_length/2-0.0045),0.004,0.009,"brass",Vector3.FORWARD,0.001)
  else:Models.tube(root,Vector3(0,0,-case_length/2),0.003,0.0005,"brass",Vector3.FORWARD)
 Models.merge_rigid(root)
 var mesh: Mesh=root.get_child(0).mesh
 meshes[key]=mesh
 root.free()
 return mesh

var case_material: PhysicsMaterial

func eject(point: Vector3, basis: Basis, weapon_id: String, live: bool=false) -> void:
 var pistol := weapon_id in ["pm","m9"]
 var svd := weapon_id=="svd"
 # Out of sight in a large battle, a case in flight is invisible; it still
 # lands on the ground beside the shooter and stays there like any other.
 if game.battle.active and Models.view_distance(self,point)>30:
  var landing := point+basis.x*randf_range(1.0,1.9)+basis.z*randf_range(-0.3,0.4)
  var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(landing+Vector3.UP*0.5,landing+Vector3.DOWN*3,1))
  if not hit.is_empty():
   var lying := Basis(Vector3.UP,randf()*TAU)
   place(Transform3D(lying,Vector3(hit.position)+Vector3.UP*0.0045),pistol,live,svd)
   if live:emitted_live+=1
   else:emitted_cases+=1
   settled_count+=1
   return
 var body := RigidBody3D.new()
 body.mass=0.012 if live else 0.005
 body.collision_layer=8
 body.collision_mask=1
 body.continuous_cd=true
 var shape := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.radius=0.0045
 capsule.height=(0.078 if live else 0.056) if svd else (0.026 if pistol else 0.046)
 shape.shape=capsule
 shape.rotation.x=PI/2
 body.add_child(shape)
 var visual := MeshInstance3D.new()
 visual.mesh=cartridge_mesh(pistol,live,svd)
 visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 body.add_child(visual)
 if case_material==null:
  case_material=PhysicsMaterial.new()
  case_material.friction=0.7
  case_material.bounce=0.18
 body.physics_material_override=case_material
 add_child(body)
 body.global_transform=Transform3D(basis,point)
 body.linear_velocity=basis.x*randf_range(1.3,2.0)+Vector3.UP*randf_range(0.65,1.1)
 body.angular_velocity=Vector3(9,13,7)
 active.append({"body":body,"age":0.0,"pistol":pistol,"svd":svd,"live":live,"paused":false})
 if live:emitted_live+=1
 else:emitted_cases+=1

func settle(entry: Dictionary) -> void:
 var body: RigidBody3D=entry.body
 place(body.global_transform,entry.pistol,entry.live,entry.svd)
 settled_count+=1
 body.queue_free()

func place(pose: Transform3D, pistol: bool, live: bool, svd: bool) -> void:
 var point := pose.origin
 var key := str(pistol)+str(live)+str(svd)+":"+str(floori(point.x/16))+":"+str(floori(point.z/16))
 if not batches.has(key):
  var multi := MultiMesh.new()
  multi.transform_format=MultiMesh.TRANSFORM_3D
  multi.mesh=cartridge_mesh(pistol,live,svd)
  multi.instance_count=32
  multi.visible_instance_count=0
  var node := MultiMeshInstance3D.new()
  node.multimesh=multi
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(node)
  batches[key]={"multi":multi,"poses":[]}
 var batch: Dictionary=batches[key]
 batch.poses.append(pose)
 var multi: MultiMesh=batch.multi
 if batch.poses.size()>multi.instance_count:
  multi.instance_count*=2
  for i in range(batch.poses.size()):multi.set_instance_transform(i,batch.poses[i])
 else:multi.set_instance_transform(batch.poses.size()-1,pose)
 multi.visible_instance_count=batch.poses.size()

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
