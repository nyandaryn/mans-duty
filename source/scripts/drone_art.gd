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

# FPV strike quadcopter on a 7-inch racing frame, as flown at the front:
# a true-X carbon frame (some 31 cm motor to motor), four 2806-class motors
# under three-blade 7-inch props, a 6S Li-ion pack strapped on top, the
# analog camera in the nose at a 30° uptilt, the VTX antenna over the tail
# and the ELRS dipole under it. The warhead rides on a printed saddle under
# the frame, its nose ahead of the props so that it meets the target first:
# "heat" — the 93 mm PG-7VL grenade without its motor, with the piezo nose
# fuse and its stand-off probe; "frag" — a cylindrical fragmentation charge
# (a printed case with a steel-ball liner over the explosive) with an
# impact fuse in its nose. Frame: -Z forward, Y up, origin in the middle of
# the arms.
static func build_fpv(kind: String) -> Node3D:
 var model := Node3D.new()
 model.name="FpvQuadcopter"
 var body := Models.group(model,"Frame")
 var carbon := "#1c1e1f"
 for side in [-1,1]:
  var arm := Models.bevel(body,Vector3.ZERO,Vector3(0.024,0.006,0.318),carbon,0.003)
  arm.rotation.y=side*PI/4
 Models.bevel(body,Vector3(0,0,0.004),Vector3(0.088,0.004,0.13),carbon,0.004)
 Models.bevel(body,Vector3(0,0.032,0.004),Vector3(0.078,0.003,0.12),carbon,0.004)
 for x in [-0.032,0.032]:
  for z in [-0.045,0.05]:Models.tube(body,Vector3(x,0.016,z),0.0035,0.03,"#6d6f70",Vector3.UP)
 # Flight controller and ESC stack, the capacitor on the battery lead.
 Models.bevel(body,Vector3(0,0.014,0.005),Vector3(0.036,0.016,0.036),"#24302a",0.002)
 Models.tube(body,Vector3(0.026,0.012,0.045),0.005,0.022,"#202020",Vector3.RIGHT)
 for side in [-1,1]:
  for end in [-1,1]:
   var motor := Vector3(side*0.112,0.004,end*0.112)
   Models.tube(body,motor,0.019,0.006,"#262829",Vector3.UP)
   Models.tube(body,motor+Vector3(0,0.013,0),0.0185,0.016,"#3c4046",Vector3.UP)
   Models.tube(body,motor+Vector3(0,0.023,0),0.006,0.006,"#8a8d8f",Vector3.UP)
 # 6S Li-ion pack in blue shrink, the velcro strap round it and the frame,
 # the yellow XT60 at its tail.
 Models.bevel(body,Vector3(0,0.0575,0.012),Vector3(0.072,0.047,0.145),"#25415f",0.008)
 Models.bevel(body,Vector3(0,0.0585,0.0),Vector3(0.022,0.005,0.08),"#c8c6b8",0.001)
 for z in [-0.035,0.055]:Models.bevel(body,Vector3(0,0.045,z),Vector3(0.078,0.068,0.02),"#3b4630",0.004)
 Models.bevel(body,Vector3(0,0.046,0.092),Vector3(0.016,0.008,0.016),"#c9a227",0.002)
 Models.limb(body,Vector3(0,0.046,0.1),Vector3(0.012,0.02,0.07),0.0028,"#151515")
 # VTX antenna over the tail (a lollipop on a stiff lead), ELRS dipole under.
 Models.limb(body,Vector3(0,0.034,0.06),Vector3(0,0.10,0.115),0.0025,"#181818")
 Models.ellipsoid(body,Vector3(0,0.108,0.12),Vector3(0.024,0.018,0.024),"#7c2420")
 for side in [-1,1]:Models.limb(body,Vector3(0,-0.004,0.07),Vector3(side*0.05,-0.006,0.1),0.0012,"#2a2a2a")
 # The warhead on its printed saddle, strapped to the bottom plate.
 if kind=="frag":
  var y := -0.050
  Models.bevel(body,Vector3(0,-0.01,0.0),Vector3(0.05,0.016,0.12),"#2e3330",0.004)
  Models.tube(body,Vector3(0,y,-0.02),0.038,0.20,"#5a5c4c",Vector3.FORWARD)
  for z in [-0.09,-0.06,-0.03,0.0,0.03]:Models.tube(body,Vector3(0,y,z),0.0395,0.006,"#3f413a",Vector3.FORWARD)
  Models.tube(body,Vector3(0,y,0.088),0.038,0.016,"#2b2d29",Vector3.BACK,0.03)
  Models.tube(body,Vector3(0,y,-0.13),0.022,0.02,"#6d6a58",Vector3.FORWARD,0.016)
  Models.tube(body,Vector3(0,y,-0.152),0.014,0.025,"#8f8a6c",Vector3.FORWARD,0.011)
  Models.tube(body,Vector3(0,y,-0.168),0.006,0.01,"#a19268",Vector3.FORWARD)
  for z in [-0.045,0.04]:Models.ring(body,Vector3(0,y+0.01,z),0.05,0.046,"#2f3a24")
 else:
  var y := -0.062
  Models.bevel(body,Vector3(0,-0.012,0.03),Vector3(0.05,0.02,0.13),"#2e3330",0.004)
  # PG-7VL: 93 mm body, the long ogive to the nose fuse, the probe ahead.
  Models.tube(body,Vector3(0,y,0.02),0.0465,0.13,"#55603f",Vector3.FORWARD)
  Models.tube(body,Vector3(0,y,-0.155),0.0465,0.22,"#4c5738",Vector3.FORWARD,0.013)
  Models.tube(body,Vector3(0,y,-0.282),0.012,0.035,"#1f2220",Vector3.FORWARD,0.009)
  Models.tube(body,Vector3(0,y,-0.312),0.005,0.03,"#8a8c86",Vector3.FORWARD)
  Models.tube(body,Vector3(0,y,0.12),0.0465,0.07,"#3f4732",Vector3.BACK,0.024)
  # Printed tail adaptor with the initiation board's lead where the motor was.
  Models.tube(body,Vector3(0,y,0.185),0.025,0.06,"#30332d",Vector3.BACK)
  Models.bevel(body,Vector3(0,y+0.03,0.19),Vector3(0.022,0.012,0.03),"#1b2a1f",0.002)
  Models.limb(body,Vector3(0,y+0.036,0.19),Vector3(0.0,0.0,0.07),0.0018,"#b23a2a")
  Models.bevel(body,Vector3(0,y,-0.06),Vector3(0.012,0.003,0.05),"#d2cdb0",0.001)
  for z in [-0.02,0.07]:Models.ring(body,Vector3(0,y+0.012,z),0.06,0.056,"#2f3a24")
 Models.merge_rigid(body)
 # Analog camera in its TPU mount, tilted up so that it looks ahead when the
 # frame leans into fast flight.
 var cam := Models.group(model,"FpvCamera",Vector3(0,0.016,-0.082))
 cam.rotation.x=0.52
 Models.bevel(cam,Vector3.ZERO,Vector3(0.019,0.019,0.02),"#1a1c1c",0.003)
 Models.tube(cam,Vector3(0,0,-0.013),0.0075,0.01,"#0e0f10",Vector3.FORWARD)
 Models.tube(cam,Vector3(0,0,-0.0185),0.006,0.001,"#243c48",Vector3.FORWARD)
 for x in [-0.014,0.014]:Models.bevel(cam,Vector3(x,0,0.002),Vector3(0.004,0.03,0.03),"#2a2c2b",0.002)
 for side in [-1,1]:
  for end in [-1,1]:
   var rotor := Models.group(model,"Rotor",Vector3(side*0.112,0.03,end*0.112))
   Models.tube(rotor,Vector3.ZERO,0.008,0.012,"#2b2d2f",Vector3.UP)
   for i in range(3):
    var a := TAU*i/3.0
    var blade := Models.bevel(rotor,Basis(Vector3.UP,a)*Vector3(0.048,0,0),Vector3(0.08,0.0022,0.016),"#2b2d2f",0.001)
    blade.basis=Basis(Vector3.UP,a)*Basis(Vector3.RIGHT,0.24*side*end)
   Models.merge_rigid(rotor)
   rotor.set_meta("rotor",true)
 return model

# Analog box goggles of a strike-drone pilot: one screen behind a Fresnel
# lens, a cooling grille in the front, a patch and a whip antenna on the
# receiver module and the head strap.
static func fpv_goggles() -> Node3D:
 var model := Node3D.new()
 Models.bevel(model,Vector3.ZERO,Vector3(0.17,0.10,0.12),"#2b2e2c",0.02)
 Models.bevel(model,Vector3(0,0,0.066),Vector3(0.15,0.075,0.02),"#191b1a",0.012)
 for x in [-0.045,0.045]:Models.tube(model,Vector3(x,0,0.078),0.025,0.006,"#0f1211",Vector3.BACK)
 for y in [-0.025,-0.01,0.005,0.02]:Models.bevel(model,Vector3(0,y,-0.061),Vector3(0.11,0.005,0.004),"#151716",0.001)
 Models.bevel(model,Vector3(0.0,0.056,0.0),Vector3(0.07,0.014,0.06),"#323733",0.004)
 Models.bevel(model,Vector3(0.022,0.075,-0.01),Vector3(0.04,0.04,0.008),"#1d201e",0.004)
 Models.limb(model,Vector3(-0.022,0.064,0.0),Vector3(-0.035,0.13,0.01),0.004,"#161616")
 for side in [-1,1]:Models.limb(model,Vector3(side*0.085,0,0.04),Vector3(side*0.095,0,0.12),0.006,"#2c3127")
 return model
