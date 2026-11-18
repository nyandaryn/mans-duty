class_name VaultRig
extends Node3D

var traversal: VaultTraversal
var hands: Array[Node3D]=[]
var sleeves: Array[Node3D]=[]

func setup(owner_traversal: VaultTraversal) -> void:
 traversal=owner_traversal
 for i in range(2):
  var hand := Models.hand(self,"VaultLeft" if i==0 else "VaultRight",Vector3.ZERO)
  if i==0:hand.scale.x=-1
  hands.append(hand)
  sleeves.append(CharacterArt.shell(self,[Vector4(-0.13,0.095,0.085,0),Vector4(-0.06,0.092,0.083,0),Vector4(0.02,0.080,0.072,0),Vector4(0.13,0.064,0.060,0)],"cloth",0.025))
 ScopeSight.set_first_person(self)
 Wardrobe.dress(self,traversal.operator.outfit_id,true)
 visible=false

func animate() -> void:
 visible=traversal.active
 if not visible:return
 var p := traversal.progress
 var player := traversal.operator
 # Hands reach at different times, stay on the physical sill through the pull,
 # then release before the torso passes them. Wrists remain in world space.
 for i in range(2):
  var rest := Vector3(-0.28 if i==0 else 0.30,-0.59,-0.26)
  var reach := smoothstep(0.10+i*0.025,0.28+i*0.025,p)
  var release := smoothstep(0.52+i*0.025,0.72+i*0.025,p)
  var contact := to_local(traversal.grips[i])
  var hand := hands[i]
  hand.position=rest.lerp(contact,reach*(1-release))
  var planted := global_basis.inverse()*player.global_basis*Basis(Vector3.RIGHT,-PI/2)
  hand.quaternion=Quaternion.IDENTITY.slerp(planted.get_rotation_quaternion(),reach*(1-release))
  var wrist := hand.position+hand.basis*Vector3(0,-0.065,0.02)
  var elbow := Vector3(-0.34 if i==0 else 0.37,-0.50,0.16)
  var arm := sleeves[i]
  arm.position=(wrist+elbow)*0.5
  arm.quaternion=Quaternion(Vector3.UP,elbow.direction_to(wrist))
  arm.scale=Vector3(1,elbow.distance_to(wrist)/0.26,1)
 var lower := smoothstep(0,0.10,p)*(1-smoothstep(0.90,1,p))
 player.viewmodel.position+=Vector3(0.14,-0.70,0.14)*lower
 player.viewmodel.rotation+=Vector3(0.15,0,-0.55)*lower
 player.viewmodel.visible=p<0.12 or p>0.90
 # Stow the vault arms completely before the weapon returns to the shoulder.
 if p>0.82:
  position.y=-smoothstep(0.82,0.91,p)*0.50
 else:position=Vector3.ZERO
