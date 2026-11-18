extends SceneTree
var checks := 0
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  printerr("FAIL: ",message)
  quit(1)
  assert(ok,message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 game.player.set_physics_process(false)
 for enemy in game.bots:enemy.set_physics_process(false)
 var actor: Hostile=game.bots[0]
 actor.position=Vector3(0,0,25)
 actor.rotation=Vector3.ZERO
 var textured_head := false
 for mesh in actor.model.get_node("Head").find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var material: Material=mesh.get_active_material(i)
   if material is StandardMaterial3D and material.resource_name=="character_skin":
    textured_head=material.albedo_texture!=null and mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV].size()>1000
 check(textured_head,"Game model has anatomical UV-mapped textured head, not the former box head")
 for id in Wardrobe.IDS:
  Wardrobe.dress(actor.model,id)
  check(actor.model.get_meta("outfit")==id,"New rig accepts outfit "+id)
 for stance in [0.0,1.0]:
  for aim in [0.0,1.0]:
   actor.stance=stance
   actor.aim_weight=aim
   actor.animate_pose(1,false)
   var rifle: Node3D=actor.model.get_node("CarriedRifle")
   for side in ["Left","Right"]:
    var hand: Node3D=actor.model.get_node(side+"Arm/Forearm/Hand")
    var offset := Vector3(-0.035,-0.045,-0.265) if side=="Left" else Vector3(0.012,-0.09,0.085)
    var error := hand.global_position.distance_to(rifle.to_global(offset))
    check(error<0.04,"Hand reaches rifle grip without stretched forearm: %s stance %s aim %s error %s" % [side,stance,aim,error])
 for weapon in ["ak74","m16","svd"]:
  var holder := Node3D.new()
  root.add_child(holder)
  var model := Models.soldier(holder)
  CharacterArt.equip_display(model,weapon)
  var rifle: Node3D=model.get_node("CarriedRifle")
  var offset := Vector3(0.012,-0.09,0.145 if weapon=="svd" else 0.085)
  check(model.get_node("RightArm/Forearm/Hand").global_position.distance_to(rifle.to_global(offset))<0.015,"Portrait firing hand fits selected "+weapon)
  holder.free()
 actor.stance=0
 actor.aim_weight=0
 actor.animate_pose(1,false)
 actor.last_incoming=Vector3.FORWARD
 actor.die()
 for i in range(90):await physics_frame
 var corpse: Corpse=actor.get_node("Corpse")
 check(corpse.bodies.size()==11,"All articulated parts transfer to corpse")
 var low := Vector3(INF,INF,INF)
 var high := -low
 for body in corpse.bodies:
  check(body.global_position.is_finite(),"Ragdoll part remains finite")
  low=low.min(body.global_position)
  high=high.max(body.global_position)
 check((high-low).length()<3.2,"Constrained new corpse does not explode or detach limbs")
 game.queue_free()
 await process_frame
 print("PASS: %d character texture, outfit, grip and ragdoll checks" % checks)
 quit()
