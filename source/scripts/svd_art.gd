class_name SvdArt
extends RefCounted

# Original metre-scale mesh: wooden SVD furniture and side-mounted PSO-1.
const OCULAR := Vector3(-0.018,0.093,0.135)
const EYE_RELIEF := 0.0682
const LENS_RADIUS := EYE_RELIEF*4.0*tan(PI/60.0)

static func cartridge(parent: Node3D, live: bool, tip_material: String="brass") -> void:
 # Tapered body, shoulder, neck and projecting rim of 7.62x54R.
 Models.tube(parent,Vector3(0,0,0.005),0.0062,0.044,"brass",Vector3.FORWARD,0.00565)
 Models.tube(parent,Vector3(0,0,-0.0195),0.00565,0.005,"brass",Vector3.FORWARD,0.00425)
 Models.tube(parent,Vector3(0,0,-0.0245),0.00425,0.005,"brass",Vector3.FORWARD)
 Models.tube(parent,Vector3(0,0,0.027),0.0072,0.0016,"brass",Vector3.FORWARD)
 if live:Models.tube(parent,Vector3(0,0,-0.037),0.00392,0.020,tip_material,Vector3.FORWARD,0.0006)

static func build(root: Node3D, mag: Node3D, bolt: Node3D) -> void:
 root.set_meta("sight_height",0.053)
 root.set_meta("rear_z",-0.15)
 root.set_meta("front_z",-0.72)
 root.set_meta("muzzle_z",-0.80)
 root.set_meta("eye_relief",0.30)
 root.set_meta("magwell",Vector3(0,-0.085,-0.073))
 root.set_meta("optic","pso1")
 root.set_meta("scope_ocular",OCULAR)
 Models.bevel(root,Vector3(0,-0.015,-0.025),Vector3(0.041,0.065,0.31),"gun_metal",0.002)
 WeaponArt.loft(root,[Vector4(0.018,-0.18,0.037,0.018),Vector4(0.022,-0.15,0.044,0.026),Vector4(0.022,0.11,0.041,0.025),Vector4(0.012,0.13,0.034,0.019)],"gun_metal",0.8)
 Models.bevel(root,Vector3(0.022,0.002,-0.07),Vector3(0.001,0.022,0.09),"gun_recess",0.001)
 Models.bevel(bolt,Vector3(0.023,0.003,-0.065),Vector3(0.004,0.018,0.076),"gun_edge",0.001)
 Models.tube(bolt,Vector3(0.039,0.006,-0.025),0.004,0.034,"gun_metal",Vector3.RIGHT)
 Models.bevel(bolt,Vector3(0.056,0.006,-0.025),Vector3(0.009,0.011,0.019),"gun_edge",0.002)
 for side in [-1,1]:
  for z in [-0.16,-0.12,0.085]:WeaponArt.pin(root,side*0.021,-0.022,z)
 Models.bevel(root,Vector3(0.023,-0.02,0.037),Vector3(0.003,0.009,0.12),"gun_metal",0.001).rotation.x=-0.18
 # Skeletal butt: four separate wooden rails leave a real thumbhole opening.
 Models.profile(root,PackedVector2Array([Vector2(0.12,0.005),Vector2(0.40,-0.013),Vector2(0.405,-0.049),Vector2(0.165,-0.032)]),0.038,"wood")
 Models.profile(root,PackedVector2Array([Vector2(0.15,-0.122),Vector2(0.40,-0.132),Vector2(0.405,-0.105),Vector2(0.145,-0.094)]),0.033,"wood")
 Models.profile(root,PackedVector2Array([Vector2(0.11,-0.027),Vector2(0.166,-0.032),Vector2(0.175,-0.126),Vector2(0.14,-0.128),Vector2(0.105,-0.063)]),0.033,"wood")
 Models.bevel(root,Vector3(0,-0.073,0.397),Vector3(0.038,0.13,0.032),"wood",0.006)
 Models.bevel(root,Vector3(0,-0.073,0.419),Vector3(0.042,0.134,0.012),"gun_rubber",0.005)
 Models.bevel(root,Vector3(0,0.015,0.291),Vector3(0.052,0.036,0.145),"gun_rubber",0.009)
 for z in [0.24,0.34]:Models.bevel(root,Vector3(0,-0.009,z),Vector3(0.055,0.005,0.012),"gun_metal",0.001)
 Models.trigger_guard(root,0.055,-0.063)
 # Long vented handguard: open gaps between the ribs, not a solid painted box.
 for side in [-1,1]:
  Models.bevel(root,Vector3(side*0.022,-0.047,-0.334),Vector3(0.011,0.027,0.296),"wood",0.004)
  Models.bevel(root,Vector3(side*0.023,0.013,-0.334),Vector3(0.011,0.015,0.296),"wood",0.004)
  for i in range(7):
   Models.bevel(root,Vector3(side*0.024,-0.016,-0.207-i*0.041),Vector3(0.012,0.05,0.017),"wood",0.003)
 for z in [-0.189,-0.482]:Models.bevel(root,Vector3(0,-0.019,z),Vector3(0.057,0.082,0.012),"gun_metal",0.002)
 Models.tube(root,Vector3(0,0,-0.473),0.009,0.58,"gun_metal")
 Models.tube(root,Vector3(0,0.031,-0.401),0.011,0.27,"gun_metal")
 Models.bevel(root,Vector3(0,0.017,-0.535),Vector3(0.026,0.047,0.037),"gun_metal",0.003)
 Models.tube(root,Vector3(0,0.033,-0.548),0.008,0.022,"gun_edge")
 Models.bevel(root,Vector3(0,0.022,-0.72),Vector3(0.018,0.048,0.027),"gun_metal",0.002)
 Models.ring(root,Vector3(0,0.053,-0.72),0.010,0.007,"gun_metal")
 Models.bevel(root,Vector3(0,0.05,-0.72),Vector3(0.002,0.012,0.003),"gun_metal",0.0004)
 Models.notch(root,0.053,-0.15)
 Models.bevel(root,Vector3(0,0.035,-0.171),Vector3(0.023,0.013,0.065),"gun_edge",0.001)
 # Slotted flash hider, with a visible bore at its end.
 Models.tube(root,Vector3(0,0,-0.752),0.012,0.028,"gun_metal")
 for i in range(5):
  var angle := TAU*i/5
  Models.tube(root,Vector3(cos(angle)*0.009,sin(angle)*0.009,-0.782),0.0026,0.034,"gun_metal")
 Models.ring(root,Vector3(0,0,-0.801),0.011,0.004,"gun_edge")
 Models.tube(root,Vector3(0,0,-0.764),0.0038,0.001,"gun_recess")
 # Short, curved steel 10-round magazine; rimmed cartridges have a wider body.
 Models.profile(mag,PackedVector2Array([Vector2(-0.031,-0.043),Vector2(-0.112,-0.043),Vector2(-0.132,-0.151),Vector2(-0.052,-0.151)]),0.030,"gun_metal")
 for side in [-1,1]:
  for z in [-0.052,-0.074,-0.096]:
   Models.bevel(mag,Vector3(side*0.0155,-0.098,z-0.009),Vector3(0.002,0.078,0.006),"gun_edge",0.001).rotation.x=-0.17
 Models.bevel(mag,Vector3(0,-0.153,-0.092),Vector3(0.035,0.006,0.085),"gun_metal",0.001)
 Models.bevel(root,Vector3(0,-0.055,-0.024),Vector3(0.012,0.02,0.015),"gun_edge",0.001)
 build_scope(root)

static func build_scope(root: Node3D) -> void:
 var scope := Models.group(root,"PSO1")
 var x := OCULAR.x
 var y := OCULAR.y
 Models.bevel(scope,Vector3(-0.029,-0.005,-0.007),Vector3(0.014,0.026,0.14),"gun_metal",0.002)
 for z in [-0.07,0.035]:
  Models.bevel(scope,Vector3(-0.033,0.034,z),Vector3(0.012,0.065,0.018),"gun_metal",0.002)
  Models.bevel(scope,Vector3(-0.022,0.064,z),Vector3(0.037,0.013,0.022),"gun_metal",0.002)
 Models.bevel(scope,Vector3(-0.043,-0.006,0.013),Vector3(0.009,0.011,0.072),"gun_edge",0.001).rotation.x=-0.25
 Models.tube(scope,Vector3(x,y,-0.035),0.016,0.29,"gun_metal")
 Models.tube(scope,Vector3(x,y,-0.196),0.019,0.042,"gun_metal")
 Models.ring(scope,Vector3(x,y,-0.22),0.0195,0.012,"gun_edge")
 Models.tube(scope,Vector3(x,y,-0.219),0.012,0.001,"#374c47")
 Models.tube(scope,Vector3(x,y,0.109),0.018,0.025,"gun_metal")
 # The ocular opening is clear. The live optical image is fitted by ScopeSight.
 Models.ring(scope,Vector3(x,y,0.134),0.019,LENS_RADIUS,"gun_rubber")
 eyecup(scope,Vector3(x,y,0))
 var elevation := Models.group(scope,"Elevation",Vector3(x,y+0.019,-0.03))
 Models.tube(elevation,Vector3(0,0.009,0),0.014,0.018,"gun_metal",Vector3.UP)
 Models.tube(elevation,Vector3(0,0.019,0),0.015,0.003,"gun_edge",Vector3.UP)
 var windage := Models.group(scope,"Windage",Vector3(x+0.018,y,-0.03))
 Models.tube(windage,Vector3(0.009,0,0),0.013,0.018,"gun_metal",Vector3.RIGHT)
 for i in range(20):
  var angle := TAU*i/20
  Models.tube(elevation,Vector3(cos(angle)*0.014,0.01,sin(angle)*0.014),0.0008,0.012,"gun_edge",Vector3.UP)
  Models.bevel(elevation,Vector3(cos(angle)*0.011,0.021,sin(angle)*0.011),Vector3(0.001,0.0004,0.002),"white",0.0001).rotation.y=-angle
 Models.tube(scope,Vector3(x-0.023,y-0.008,0.04),0.012,0.037,"gun_metal",Vector3.UP)
 Models.tube(scope,Vector3(x-0.023,y+0.013,0.04),0.013,0.005,"gun_edge",Vector3.UP)
 Models.bevel(scope,Vector3(x-0.025,y+0.023,0.04),Vector3(0.004,0.013,0.018),"gun_metal",0.001)
 Models.marker(root,"ScopeOcular",OCULAR)
 Models.marker(root,"ScopeObjective",Vector3(x,y,-0.22))

static func eyecup(parent: Node3D, offset: Vector3) -> void:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(0)
 var stations := [Vector3(0.133,0.019,0.0143),Vector3(0.138,0.0195,0.016),Vector3(0.144,0.020,0.0175),Vector3(0.150,0.021,0.0185)]
 for side in [0,1]:
  for j in range(stations.size()-1):
   for i in range(48):
    var a := TAU*i/48
    var b := TAU*(i+1)/48
    var first: Vector3=stations[j]
    var second: Vector3=stations[j+1]
    var r: float=first.y if side==0 else first.z
    var s: float=second.y if side==0 else second.z
    var points := [Vector3(cos(a)*r,sin(a)*r,first.x),Vector3(cos(b)*r,sin(b)*r,first.x),Vector3(cos(a)*s,sin(a)*s,second.x),Vector3(cos(b)*r,sin(b)*r,first.x),Vector3(cos(b)*s,sin(b)*s,second.x),Vector3(cos(a)*s,sin(a)*s,second.x)]
    if side==1:points.reverse()
    for point in points:st.add_vertex(point+offset)
 st.generate_normals()
 st.index()
 var node := Models.mesh_node(parent,st.commit(),Vector3.ZERO,"gun_rubber")
 var rubber := Models.surface("gun_rubber").duplicate() as StandardMaterial3D
 rubber.cull_mode=BaseMaterial3D.CULL_DISABLED
 node.material_override=rubber
 Models.ring(parent,offset+Vector3(0,0,0.150),0.021,0.0185,"gun_rubber")
