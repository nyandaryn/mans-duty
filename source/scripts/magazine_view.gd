class_name MagazineView
extends RefCounted

static func decorate(mag: Node3D, id: String) -> void:
 # The PKM's box shows its belt already.
 if id=="pkm":return
 if mag.has_node("AmmoEvidence"):
  if id=="svd":
   mag.get_node("AmmoEvidence/TopRound").position.y=-0.046
   mag.get_node("AmmoEvidence/SecondRound").position.y=-0.055
   mag.get_node("AmmoEvidence/Follower").position.y=-0.0475
  return
 var pistol := id in ["pm","m9"]
 if pistol:
  # Match the inclined grip: the mouth is forward of the floorplate.
  # The previous baked box and floorplate disagreed about that inclination.
  for child in mag.get_children():child.free()
  var half_depth := 0.013 if id=="pm" else 0.015
  var outline := PackedVector2Array([Vector2(0.022-half_depth,-0.027),Vector2(0.022+half_depth,-0.027),Vector2(0.046+half_depth,-0.139),Vector2(0.046-half_depth,-0.139)])
  Models.profile(mag,outline,0.018 if id=="pm" else 0.022,"gun_metal")
  Models.bevel(mag,Vector3(0,-0.141,0.046),Vector3(0.029,0.006,0.035),"gun_polymer",0.001)
 var evidence := Models.group(mag,"AmmoEvidence")
 # Cartridge axes follow the feed lips. Only the upper part protrudes above
 # the body; the old AK round floated about 20 mm above its magazine mouth.
 var top := Vector3(0,-0.028,0.024) if pistol else (Vector3(0,-0.041,-0.055) if id=="ak74" else Vector3(0,-0.049,-0.067))
 if id=="svd":top=Vector3(0,-0.046,-0.064)
 var case_length := 0.017 if pistol else (0.036 if id=="ak74" else 0.033)
 if id=="svd":case_length=0.054
 var tip_length := 0.006 if pistol else 0.010
 if id=="svd":tip_length=0.020
 var radius := 0.0046 if pistol else 0.0042
 if id=="svd":radius=0.0058
 var follower := Models.bevel(evidence,top-Vector3.UP*0.0015,Vector3(0.015,0.003,0.023 if pistol else 0.046),"gun_recess",0.0006)
 follower.name="Follower"
 var round := Models.group(evidence,"TopRound",top)
 if id=="svd":
  SvdArt.cartridge(round,true,"#b27c50")
  var second: Node3D=round.duplicate()
  second.name="SecondRound"
  second.position.y-=0.009
  evidence.add_child(second)
  evidence.set_meta("staggered",true)
 else:
  Models.tube(round,Vector3.ZERO,radius,case_length,"brass",Vector3.FORWARD)
  Models.tube(round,Vector3(0,0,-(case_length+tip_length)/2),radius*0.88,tip_length,"bakelite",Vector3.FORWARD,0.0015 if pistol else 0.0008)
  Models.tube(round,Vector3(0,0,case_length/2),radius*1.05,0.001,"brass",Vector3.FORWARD)
 # Thin steel retaining lips at the mouth keep the top cartridge seated.
 for side in [-1,1]:
  Models.bevel(evidence,top+Vector3(side*(0.013 if id=="svd" else 0.0075),0.002,0.002),Vector3(0.003,0.004,0.018 if pistol else 0.030),"gun_metal",0.0005)
 # AK full-load witness; pistol magazines have staged witness apertures.
 # Standard M16 box magazines are inspected at the feed lips, with no invented counter.
 var levels: Array=[] if id in ["m16","svd"] else ([int(WeaponState.DATA[id].capacity)] if id=="ak74" else ([4,8] if id=="pm" else [5,10,15]))
 for i in range(levels.size()):
  var point := Vector3(0.014,-0.205,-0.09) if id=="ak74" else Vector3(0.0095 if id=="pm" else 0.0115,-0.055-i*0.027,0.028+i*0.0058)
  var aperture := Models.tube(evidence,point,0.0035,0.001,"gun_recess",Vector3.RIGHT)
  aperture.name="Witness"+str(levels[i])
  var brass := Models.tube(evidence,point+Vector3.RIGHT*0.0008,0.0024,0.001,"brass",Vector3.RIGHT)
  brass.name="WitnessRound"+str(levels[i])
  brass.set_meta("threshold",levels[i])

static func update(mag: Node3D, rounds: int) -> void:
 var evidence := mag.get_node_or_null("AmmoEvidence")
 if evidence==null:return
 evidence.get_node("TopRound").visible=rounds>0
 evidence.get_node("Follower").visible=rounds==0
 if evidence.has_meta("staggered"):
  evidence.get_node("TopRound").position.x=0.006 if rounds%2 else -0.006
  evidence.get_node("SecondRound").position.x=-evidence.get_node("TopRound").position.x
  evidence.get_node("SecondRound").visible=rounds>1
 for node in evidence.get_children():
  if node.has_meta("threshold"):node.visible=rounds>=int(node.get_meta("threshold"))
