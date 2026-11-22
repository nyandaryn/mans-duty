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
# Every launcher the operator carries, on the pack's mount or in his hands
# (the RPG-22 folded on the pack, drawn out in the hands).
var launcher_models := {}

func setup(owner_operator: Operator) -> void:
 operator=owner_operator
 name="WorldBody"
 model=Models.soldier(self)
 Wardrobe.dress(model,operator.outfit_id)
 CharacterArt.team_markings(model,true)
 CharacterArt.wear_vest(model,operator.vest)
 PackArt.equip(model,operator.backpack.equipped)
 launcher_model=PackArt.attach_launcher(model)
 launcher_models["rpo_a"]=launcher_model
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

# A launcher on the body: on the pack's mount (one per kind and state) or in
# the hands (a copy of its own, so a second tube of the kind stays on the
# mount). An armed RPG-22 is drawn out wherever it is.
func launcher_for(kind: String, ready: bool=false, hands: bool=false) -> Node3D:
 var key:=kind+("/ready" if ready and kind=="rpg22" else "")+("/hands" if hands else "")
 if not launcher_models.has(key):
  var built: Node3D
  if kind=="rpg22" and ready:
   built=BotKit.launcher_model("rpg22",true)
   model.add_child(built)
  else:built=PackArt.attach_launcher(model,kind)
  built.name="Carried_"+key.replace("/","_")
  for mesh in built.find_children("*","VisualInstance3D",true,false):mesh.layers=WORLD_BODY_LAYER
  launcher_models[key]=built
 return launcher_models[key]

func update_pose() -> void:
 refresh_weapon()
 var drawn: LauncherRig=operator.launcher
 var in_hands: Node3D=null
 if drawn.active():in_hands=launcher_for(drawn.kind,drawn.kind=="rpg22" and (drawn.armed() or drawn.mode=="spent"),true)
 # What is left on the mount, and the state of the first of each kind there.
 var mounted := {}
 for entry in operator.backpack.items:
  var kind: String=entry.kind
  if kind not in LauncherRig.KINDS or (drawn.active() and int(entry.uid)==drawn.item_uid):continue
  if not mounted.has(kind):mounted[kind]=entry
 for kind in mounted:launcher_for(kind,mounted[kind].get("extended",false)==true)
 for key in launcher_models:
  var m: Node3D=launcher_models[key]
  var kind: String=String(key).get_slice("/",0)
  var hands:=String(key).ends_with("/hands")
  var ready:=String(key).contains("/ready")
  m.visible=m==in_hands or (not hands and mounted.has(kind) and ready==(mounted.get(kind,{}).get("extended",false)==true))
  m.transform=PackArt.mount(kind)
  if kind=="rpg7":
   # The round actually in the tube: the PG-7VL, the OG-7V or the TBG-7V.
   var seated:=""
   if m==in_hands:seated=drawn.seated_round()
   elif mounted.get("rpg7",{}).get("loaded",false)==true:seated=str(mounted.rpg7.get("round","pg7vl"))
   LauncherRig.seat_round(m,seated)
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
 if in_hands!=null:
  rifle.position=Vector3(0.25,1.05,-0.13);rifle.rotation=Vector3(0,0,-0.8)
  var kind: String=drawn.kind
  # The tube on the right shoulder (the Shmel's capsule as before).
  var basis:=Basis.from_euler(Vector3(PI/2 if low else operator.pitch,0,0))
  var seat:=Transform3D(basis,Vector3(0.19,1.46,-0.08))
  if kind!="rpo_a":seat.origin=BotKit.SHOULDER_TOP-basis*drawn.shoulder_point()
  in_hands.transform=seat
  if drawn.mode in ["draw","stow"]:
   var progress := clampf(drawn.timer/float(LauncherRig.DRAW[kind] if drawn.mode=="draw" else LauncherRig.STOW[kind]),0,1)
   var reach := smoothstep(0.15,0.92,progress) if drawn.mode=="draw" else 1-smoothstep(0,1,progress)
   in_hands.transform=PackArt.mount(kind).interpolate_with(seat,reach)
  elif drawn.mode=="arm":
   # Across the chest while the covers come off and the sleeve is drawn out.
   var p := clampf(drawn.timer/LauncherRig.ARM_TIME,0,1)
   var down := smoothstep(0,0.12,p)*(1-smoothstep(0.88,1,p))
   var chest:=Transform3D(Basis.from_euler(Vector3(0,PI/2-0.25,0)),Vector3(0.02,1.22,-0.28))
   in_hands.transform=seat.interpolate_with(chest,down)
  elif drawn.mode=="spent":
   var discard := smoothstep(0,1,clampf(drawn.timer/1.1,0,1))
   in_hands.position+=Vector3(0.35,-0.7,0.1)*discard;in_hands.rotation.z=discard*0.65
  var grip:=Vector3(-0.035,-0.10,0.16)
  var support:=Vector3(-0.055,-0.10,-0.20)
  if kind=="rpg7":grip=Rpg7Art.GRIP;support=Rpg7Art.SUPPORT
  elif kind=="rpg22":grip=Rpg22Art.GRIP;support=Rpg22Art.SUPPORT
  CharacterArt.pose_arm(model,"Left",in_hands.transform*support)
  CharacterArt.pose_arm(model,"Right",in_hands.transform*grip)
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
