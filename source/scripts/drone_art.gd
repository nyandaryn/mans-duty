class_name DroneArt
extends RefCounted

static func build(folded: bool=false) -> Node3D:
 var model := Node3D.new()
 model.name="ReconQuadcopter"
 Models.bevel(model,Vector3(0,0.045,0),Vector3(0.115,0.075,0.18),"#555e55",0.018)
 Models.bevel(model,Vector3(0,0.087,0.018),Vector3(0.082,0.012,0.12),"#313a34",0.005)
 for side in [-1,1]:
  for end in [-1,1]:
   var motor := Vector3(side*(0.065 if folded else 0.19),0.045,end*(0.075 if folded else 0.15))
   Models.limb(model,Vector3(side*0.04,0.04,end*0.06),motor,0.014,"#414a43")
   Models.tube(model,motor,0.023,0.035,"#202a24",Vector3.UP)
   Models.limb(model,motor-Vector3.UP*0.018,motor+Vector3(0,-0.045,0.016),0.006,"#303a32")
   var rotor := Models.group(model,"Rotor",motor+Vector3.UP*0.023)
   Models.bevel(rotor,Vector3.ZERO,Vector3(0.20,0.003,0.017),"#222922",0.004)
   Models.tube(rotor,Vector3.ZERO,0.007,0.012,"#92958a",Vector3.UP)
   rotor.set_meta("rotor",true)
 Models.bevel(model,Vector3(0,0.012,-0.095),Vector3(0.046,0.038,0.036),"#292f2a",0.009)
 Models.tube(model,Vector3(0,0.012,-0.119),0.014,0.006,"#314d53",Vector3.FORWARD)
 Models.limb(model,Vector3(0,0.08,0.07),Vector3(0,0.17,0.10),0.003,"#202a24")
 Models.bevel(model,Vector3(0,0.047,0.092),Vector3(0.025,0.009,0.003),"#b2a776",0.002)
 return model

static func goggles() -> Node3D:
 var model := Node3D.new()
 Models.bevel(model,Vector3.ZERO,Vector3(0.18,0.085,0.095),"#353c35",0.017)
 for x in [-0.04,0.04]:
  Models.tube(model,Vector3(x,0,0.055),0.028,0.025,"#181f1a",Vector3.BACK)
  Models.limb(model,Vector3(x,0.045,0),Vector3(x,0.11,-0.025),0.003,"#282e27")
 return model
