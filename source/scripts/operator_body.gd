class_name OperatorBody
extends Node3D

# Separate from weapon/hands and excluded by the first-person cameras.
const WORLD_BODY_LAYER := 4
var operator: Operator
var model: Node3D
var goggles: Node3D
var controller: Node3D
var weapon_id := ""
var launcher_model: Node3D

func setup(owner_operator: Operator) -> void:
 operator=owner_operator
 name="WorldBody"
 model=Models.soldier(self)
 Wardrobe.dress(model,operator.outfit_id)
 CharacterArt.team_markings(model,true)
 PackArt.equip(model,operator.backpack.equipped)
 launcher_model=PackArt.attach_launcher(model)
 goggles=DroneArt.goggles()
 goggles.name="PilotGoggles"
 model.get_node("Head").add_child(goggles)
 goggles.position=Vector3(0,CharacterArt.EYE.y,-0.195)
 controller=Models.group(model,"Controller")
 Models.bevel(controller,Vector3.ZERO,Vector3(0.17,0.055,0.10),"#343d36",0.014)
 for x in [-0.052,0.052]:
  Models.tube(controller,Vector3(x,0.031,0),0.018,0.004,"#171f1b",Vector3.UP)
  Models.limb(controller,Vector3(x,0.031,0),Vector3(x,0.047,0),0.004,"#9a9e92")
 Models.limb(controller,Vector3(0,0.018,-0.045),Vector3(0,0.07,-0.095),0.004,"#202923")
 refresh_weapon()
 update_pose()

func refresh_weapon() -> void:
 if weapon_id==operator.current().id:return
 weapon_id=operator.current().id
 CharacterArt.equip_display(model,weapon_id)
 for mesh in model.find_children("*","VisualInstance3D",true,false):mesh.layers=WORLD_BODY_LAYER

func update_pose() -> void:
 refresh_weapon()
 launcher_model.visible=operator.backpack.count("rpo_a")>0 or operator.launcher.mode=="spent"
 launcher_model.position=Vector3(0.26,1.21,0.31);launcher_model.rotation=Vector3(PI/2,0,-0.12)
 if operator.is_vaulting():
  vault_pose()
  return
 var pilot := operator.field_rig!=null and operator.field_rig.mode in ["drone","goggles"]
 var low := operator.prone
 var knee := operator.crouched and not low
 # The body's anatomical neck matches the player's existing head hitbox.
 var frame := operator.prone_surface if low else Transform3D.IDENTITY
 model.transform=frame*Transform3D(Basis(Vector3.RIGHT,-PI/2) if low else Basis.IDENTITY,Vector3(0,0.23,1.5) if low else Vector3(0,-0.71 if knee else -0.075,0))
 var head: Node3D=model.get_node("Head")
 head.rotation.x=PI/2 if low else (0.08 if pilot else operator.pitch*0.5)
 goggles.visible=pilot
 controller.visible=pilot
 var moving := minf(Vector2(operator.velocity.x,operator.velocity.z).length(),1)
 for side in ["Left","Right"]:
  var leg: Node3D=model.get_node(side+"Leg")
  var shin: Node3D=leg.get_node("Knee")
  var foot: Node3D=shin.get_node("Foot")
  var left: bool=side=="Left"
  leg.rotation.x=(PI/2 if left else 0.0) if knee else sin(operator.step_time)*(1 if left else -1)*moving*0.35 if not low else 0.0
  shin.rotation.x=-PI/2 if knee else maxf(0,-leg.rotation.x)*1.5
  foot.rotation.x=-leg.rotation.x-shin.rotation.x if not low else -0.5
  # One knee on the ground, opposite shin vertical, both feet supported.
  leg.position.y=0.89+(0.27 if knee else 0.0)
 var rifle: Node3D=model.get_node("CarriedRifle")
 if operator.launcher.active():
  rifle.position=Vector3(0.25,1.05,-0.13);rifle.rotation=Vector3(0,0,-0.8)
  launcher_model.position=Vector3(0.19,1.46,-0.08)
  launcher_model.rotation=Vector3(PI/2 if low else operator.pitch,0,0)
  if operator.launcher.mode in ["draw","stow"]:
   var progress := clampf(operator.launcher.timer/(LauncherRig.ACCESS_TIME if operator.launcher.mode=="draw" else 2.0),0,1)
   var reach := smoothstep(0.15,0.92,progress) if operator.launcher.mode=="draw" else 1-smoothstep(0,1,progress)
   launcher_model.position=Vector3(0.26,1.21,0.31).lerp(launcher_model.position,reach)
   launcher_model.rotation=Vector3(PI/2,0,-0.12).lerp(launcher_model.rotation,reach)
  elif operator.launcher.mode=="spent":
   var discard := smoothstep(0,1,clampf(operator.launcher.timer/1.1,0,1))
   launcher_model.position+=Vector3(0.35,-0.7,0.1)*discard;launcher_model.rotation.z=discard*0.65
  CharacterArt.pose_arm(model,"Left",launcher_model.position+launcher_model.basis*Vector3(-0.055,-0.10,-0.20))
  CharacterArt.pose_arm(model,"Right",launcher_model.position+launcher_model.basis*Vector3(-0.035,-0.10,0.16))
 elif pilot:
  rifle.position=Vector3(0.30,1.30,0.06) if low else Vector3(0.25,1.10,-0.16)
  rifle.rotation=Vector3(PI/2 if low else 0.0,0,-0.75)
  controller.position=Vector3(0,1.55,0.06) if low else Vector3(0,1.18,-0.36)
  controller.rotation.x=PI/2 if low else 0.18
  for side in ["Left","Right"]:
   CharacterArt.pose_arm(model,side,controller.position+Vector3(-0.085 if side=="Left" else 0.085,0,0.015))
 else:
  rifle.position=Vector3(0.14,1.28,-0.28)
  rifle.rotation=Vector3(PI/2 if low else operator.pitch,0,0)
  CharacterArt.pose_arm(model,"Left",rifle.position+rifle.basis*Vector3(-0.035,-0.045,-0.30 if weapon_id=="svd" else -0.265))
  CharacterArt.pose_arm(model,"Right",rifle.position+rifle.basis*Vector3(0.012,-0.09,0.145 if weapon_id=="svd" else 0.085))

func vault_pose() -> void:
 var p := operator.vault.progress
 var tuck := smoothstep(0.02,0.18,p)*(1-smoothstep(0.82,1,p))
 model.transform=Transform3D(Basis(Vector3.RIGHT,-0.08*tuck),Vector3(0,-0.58*tuck-0.075,0.06*tuck))
 model.get_node("Head").rotation.x=0.08*tuck
 goggles.visible=false;controller.visible=false
 var rifle: Node3D=model.get_node("CarriedRifle")
 rifle.position=Vector3(0.26,1.04,-0.20)
 rifle.rotation=Vector3(0,0,-0.85)
 for i in range(2):
  var side := "Left" if i==0 else "Right"
  var leg: Node3D=model.get_node(side+"Leg")
  var shin: Node3D=leg.get_node("Knee")
  leg.position.y=0.89
  leg.rotation.x=(1.35 if i==0 else 1.12)*tuck
  shin.rotation.x=-2.65*tuck
  shin.get_node("Foot").rotation.x=-leg.rotation.x-shin.rotation.x
  var reach := smoothstep(0.10+i*0.025,0.28+i*0.025,p)*(1-smoothstep(0.52+i*0.025,0.72+i*0.025,p))
  var rest := Vector3(-0.30 if i==0 else 0.30,1.12,-0.25)
  CharacterArt.pose_arm(model,side,rest.lerp(model.to_local(operator.vault.grips[i]),reach))
