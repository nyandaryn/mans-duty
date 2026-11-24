class_name TosArt
extends RefCounted

# BM-1 of the TOS-1A «Солнцепёк» (object 634B) on the T-72A chassis: hull
# 6.86 m long and 3.46 m wide, 0.47 m off the ground; six 750-mm road wheels
# a side on torsion bars, the idler in front, the drive sprocket at the rear,
# three return rollers; 580-mm tracks 2.79 m apart. In the place of the
# turret a traversing platform with the armoured launcher: a box of 24 tubes
# of 220 mm (3 rows of 8, 3725 mm long) on a trunnion at the rear of the
# platform, the muzzles forward over the driver on the march; 3.07 m high
# over the package. The commander and the gunner sit in the platform under
# the package, the driver in the nose; the gunner's 1D14 sight-rangefinder
# and the commander's TKN-3A stand on the platform roof. Two hydraulic jacks
# at the rear corners steady the vehicle for firing; four 902G smoke
# dischargers on the front corners; the dozer blade under the nose.
# Vehicle frame: -Z forward, +X right, origin on the ground under the middle
# of the hull. Static parts are merged into vertex-coloured meshes.
const OLIVE := Color("4b5235")
const OLIVE_DARK := Color("383e27")
const OLIVE_LIGHT := Color("5b6342")
const RUBBER := Color("1d1d1a")
const STEEL := Color("3b3c37")
const TRACK_STEEL := Color("33302b")
const BLACK := Color("121311")
const GLASS := Color("2b3a3c")
const CAP := Color("9a9c94")
const HALF := 3.43
const WIDTH := 3.46
const ROOF := 1.50
const FENDER := 1.12
const TRACK_X := 1.395
const TRACK_WIDTH := 0.58
const WHEEL_RADIUS := 0.375
const WHEELS_Z := [-2.08,-1.25,-0.42,0.42,1.25,2.08]
const IDLER := Vector3(0,0.66,-3.02)
const SPROCKET := Vector3(0,0.76,3.06)
const SPROCKET_RADIUS := 0.33
const RETURN_Z := [-1.65,-0.05,1.55]
# The traversing platform on the turret ring, and the trunnion of the
# package at its rear (platform frame).
const RING := Vector3(0,ROOF,-0.25)
const TRUNNION := Vector3(0,0.58,1.15)
# Package (cradle frame: origin on the trunnion, -Z along the tubes).
const ROWS := 3
const COLUMNS := 8
const PITCH := 0.265
const TUBE_LENGTH := 3.725
const TUBE_REAR := 0.10
const TUBE_BOTTOM := 0.22
# Crew: the driver's eyes under his hatch, the gunner (left) and the
# commander (right) in the platform (platform frame).
const DRIVER_EYE := Vector3(0,1.22,-2.30)
const GUNNER_EYE := Vector3(-0.62,0.30,-0.55)
const COMMANDER_EYE := Vector3(0.62,0.30,-0.55)
const SIGHT := Vector3(-0.62,0.62,-0.82)
# The foot of the elevating ram on the platform, and the bracket it lifts
# under the package floor (cradle frame).
const RAM_FOOT := Vector3(0,0.45,-1.55)
const RAM_BRACKET := Vector3(0,-0.02,-0.60)
# Hydraulic jacks at the rear corners (vehicle frame) and their stroke.
const JACKS := [Vector3(-1.18,0.95,3.32),Vector3(1.18,0.95,3.32)]
const JACK_STROKE := 0.62

static func at(p: Vector3) -> Transform3D:return Transform3D(Basis.IDENTITY,p)
static func solid() -> ColorMesh:return BmpArt.solid()
static func node(parent: Node3D, name: String, mesh: ColorMesh, position: Vector3=Vector3.ZERO) -> MeshInstance3D:
 return BmpArt.node(parent,name,mesh,position)

static func tube_axis(index: int) -> Vector3:
 var row:=index/COLUMNS;var column:=index%COLUMNS
 return Vector3((column-3.5)*PITCH,TUBE_BOTTOM+row*PITCH,0)

# Firing order: pairs from the two halves, the top row first, the outer
# tubes before the inner, so the package swings as little as possible.
static func firing_order() -> PackedInt32Array:
 var order:=PackedInt32Array()
 for row in range(ROWS-1,-1,-1):
  for k in range(COLUMNS/2):
   order.append(row*COLUMNS+k)
   order.append(row*COLUMNS+COLUMNS-1-k)
 return order

# The cap over the muzzle of a loaded tube (cradle frame).
static func cap_transform(index: int) -> Transform3D:
 var axis:=tube_axis(index)
 return Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(axis.x,axis.y,TUBE_REAR-TUBE_LENGTH-0.01))

static func build() -> Dictionary:
 var root:=Node3D.new();root.name="TosArt"
 var hull:=solid()
 # Lower hull between the tracks: the lower glacis behind the dozer blade.
 BmpArt.extrude(hull,PackedVector2Array([Vector2(-HALF,1.00),Vector2(-3.16,0.47),Vector2(3.20,0.47),Vector2(HALF,0.62),Vector2(HALF,FENDER),Vector2(-HALF+0.08,FENDER)]),-1.10,1.10,OLIVE_DARK)
 # Upper hull: the long upper glacis at 68°, the flat roof, the engine
 # deck sloping a little to the rear plate.
 BmpArt.extrude(hull,PackedVector2Array([Vector2(-HALF,1.00),Vector2(-2.06,ROOF),Vector2(1.10,ROOF),Vector2(3.30,ROOF-0.12),Vector2(HALF,1.26),Vector2(HALF,FENDER-0.04),Vector2(-HALF+0.02,FENDER-0.04)]),-1.58,1.58,OLIVE)
 # The V-shaped splash board and the tow hooks on the glacis.
 for s in [-1.0,1.0]:
  hull.box(Transform3D(Basis(Vector3.UP,s*0.5)*Basis(Vector3.RIGHT,-0.38),Vector3(s*0.55,1.30,-2.72)),Vector3(1.0,0.08,0.05),OLIVE_DARK)
  hull.box(at(Vector3(s*0.95,0.80,-3.45)),Vector3(0.12,0.16,0.16),STEEL)
  hull.box(at(Vector3(s*0.95,0.70,HALF+0.04)),Vector3(0.12,0.16,0.12),STEEL)
 # Headlights by the splash board.
 for s in [-1.0,1.0]:hull.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(s*1.25,1.12,-3.16)),0.08,0.12,8,STEEL,Color("d9d6c2"))
 # The driver's hatch and his TNPO-168 in front of it.
 hull.cylinder(at(Vector3(0,ROOF+0.02,-2.10)),0.30,0.05,12,OLIVE_LIGHT)
 hull.box(at(Vector3(0,ROOF+0.05,-2.42)),Vector3(0.30,0.07,0.10),OLIVE_DARK)
 hull.box(at(Vector3(0,ROOF+0.05,-2.473)),Vector3(0.24,0.04,0.004),GLASS)
 # Engine deck: louvres, the exhaust on the left fender.
 for k in range(5):hull.box(at(Vector3(0,ROOF-0.04-k*0.02+0.03,1.45+k*0.32)),Vector3(2.0,0.03,0.14),BLACK)
 hull.box(at(Vector3(-1.62,1.04,2.55)),Vector3(0.06,0.24,0.60),BLACK)
 # Fenders with the rubber side skirts over the upper track run, stowage
 # boxes on the fenders.
 for s in [-1.0,1.0]:
  hull.box(at(Vector3(s*1.68,FENDER+0.01,0.0)),Vector3(0.44,0.04,6.84),OLIVE_DARK)
  hull.box(at(Vector3(s*1.90,0.92,-0.10)),Vector3(0.03,0.42,5.40),Color("2a2b25"))
  for z in [-0.9,0.4,1.7]:hull.box(at(Vector3(s*1.68,FENDER+0.18,z)),Vector3(0.40,0.32,0.95),OLIVE_DARK)
 # Four 902G smoke dischargers on the front corners of the roof.
 for s in [-1.0,1.0]:
  for k in range(2):
   hull.cylinder(Transform3D(Basis(Vector3.RIGHT,0.75)*Basis(Vector3.UP,s*0.4),Vector3(s*(1.28+k*0.16),ROOF+0.12,-1.85)),0.045,0.28,8,OLIVE_DARK,BLACK)
 # The dozer blade folded under the nose.
 hull.box(Transform3D(Basis(Vector3.RIGHT,-0.25),Vector3(0,0.62,-3.50)),Vector3(2.2,0.38,0.06),OLIVE_DARK)
 # Rear plate and the brackets of the jacks.
 hull.box(at(Vector3(0,0.92,HALF-0.02)),Vector3(2.2,0.60,0.05),OLIVE_DARK)
 for jack in JACKS:hull.box(at(jack+Vector3(0,0.10,-0.05)),Vector3(0.26,0.30,0.30),OLIVE_DARK)
 node(root,"Hull",hull)
 # Running gear.
 var gear:=running_gear(root)
 # The jacks' rams: lowered to the ground for firing (TosVehicle moves them).
 var jacks: Array[Node3D]=[]
 for jack in JACKS:
  var ram:=Node3D.new();ram.name="Jack";ram.position=jack;root.add_child(ram)
  var piston:=solid()
  piston.cylinder(at(Vector3(0,-0.25,0)),0.07,0.50,8,STEEL)
  piston.box(at(Vector3(0,-0.52,0)),Vector3(0.36,0.05,0.36),STEEL)
  node(ram,"Ram",piston)
  jacks.append(ram)
 # The traversing platform.
 var platform:=Node3D.new();platform.name="Platform";platform.position=RING;root.add_child(platform)
 var base:=solid()
 base.cylinder(at(Vector3(0,0.05,0)),1.12,0.10,16,OLIVE_DARK)
 BmpArt.extrude_z(base,PackedVector2Array([Vector2(-1.22,0.08),Vector2(1.22,0.08),Vector2(1.10,0.50),Vector2(-1.10,0.50)]),-1.10,1.35,OLIVE,Vector3.ZERO)
 # Trunnion brackets at the rear of the platform, the elevating ram's foot.
 for s in [-1.0,1.0]:base.box(at(Vector3(s*0.70,0.55,TRUNNION.z)),Vector3(0.16,0.30,0.40),OLIVE_DARK)
 base.box(at(RAM_FOOT+Vector3(0,0.02,0)),Vector3(0.36,0.12,0.30),OLIVE_DARK)
 # The crew's hatches and devices: the gunner's 1D14 left, the commander's
 # TKN-3A right.
 for s in [-1.0,1.0]:base.cylinder(at(Vector3(s*0.62,0.52,0.05)),0.30,0.05,12,OLIVE_LIGHT)
 base.box(at(SIGHT),Vector3(0.30,0.24,0.26),OLIVE_DARK)
 base.box(at(SIGHT+Vector3(0,0.02,-0.135)),Vector3(0.22,0.12,0.01),GLASS)
 base.box(at(Vector3(0.62,0.60,-0.80)),Vector3(0.22,0.14,0.18),OLIVE_DARK)
 base.box(at(Vector3(0.62,0.61,-0.895)),Vector3(0.16,0.07,0.01),GLASS)
 # Whip aerial at the rear right of the platform.
 base.cylinder(at(Vector3(1.0,1.55,1.20)),0.008,2.0,4,BLACK)
 node(platform,"Base",base)
 # The elevating ram from the platform's front to the package floor: the
 # cylinder points at the bracket (TosVehicle aims it), the rod is
 # stretched to reach it.
 var ram:=Node3D.new();ram.name="ElevatingRam";ram.position=RAM_FOOT;platform.add_child(ram)
 var sleeve:=solid()
 sleeve.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.30)),0.11,0.60,10,OLIVE_DARK)
 node(ram,"Sleeve",sleeve)
 var rod_mesh:=solid()
 rod_mesh.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.5)),0.075,1.0,10,STEEL)
 node(ram,"Rod",rod_mesh)
 # The package: the tubes in an armoured box on the trunnion.
 var cradle:=Node3D.new();cradle.name="Cradle";cradle.position=TRUNNION;platform.add_child(cradle)
 var package:=solid()
 var middle:=TUBE_REAR-TUBE_LENGTH*0.5
 for i in range(ROWS*COLUMNS):
  var axis:=tube_axis(i)
  package.pipe(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(axis.x,axis.y,middle)),0.124,0.110,TUBE_LENGTH,10,OLIVE_DARK,Color("161713"))
 var box_bottom:=TUBE_BOTTOM-PITCH*0.5-0.03
 var box_top:=TUBE_BOTTOM+(ROWS-0.5)*PITCH+0.04
 var box_half:=COLUMNS*PITCH*0.5+0.04
 var box_middle:=(box_bottom+box_top)*0.5
 var box_height:=box_top-box_bottom
 # Side, top and bottom armour; the front frame round the muzzles and the
 # rear frame round the breeches.
 for s in [-1.0,1.0]:package.box(at(Vector3(s*box_half,box_middle,middle)),Vector3(0.04,box_height,TUBE_LENGTH+0.08),OLIVE)
 package.box(at(Vector3(0,box_top,middle)),Vector3(box_half*2+0.04,0.04,TUBE_LENGTH+0.08),OLIVE)
 package.box(at(Vector3(0,box_bottom,middle)),Vector3(box_half*2+0.04,0.05,TUBE_LENGTH+0.08),OLIVE_DARK)
 for z in [TUBE_REAR-TUBE_LENGTH-0.02,TUBE_REAR+0.02]:
  for y in [box_bottom+0.03,box_top-0.03]:package.box(at(Vector3(0,y,z)),Vector3(box_half*2+0.06,0.07,0.06),OLIVE_DARK)
  for s in [-1.0,1.0]:package.box(at(Vector3(s*(box_half-0.01),box_middle,z)),Vector3(0.07,box_height,0.06),OLIVE_DARK)
 # Ribs and lifting eyes along the sides; the cable trough on the right.
 for z in [-2.9,-1.9,-0.9]:
  for s in [-1.0,1.0]:package.box(at(Vector3(s*(box_half+0.03),box_middle,z)),Vector3(0.03,box_height+0.02,0.08),OLIVE_DARK)
  package.box(at(Vector3(0,box_top+0.03,z)),Vector3(box_half*2,0.03,0.08),OLIVE_DARK)
 package.box(at(Vector3(box_half+0.07,box_bottom+0.18,-1.6)),Vector3(0.08,0.10,2.6),OLIVE_DARK)
 # The bracket under the floor where the elevating ram takes hold.
 package.box(at(RAM_BRACKET+Vector3(0,-0.02,0)),Vector3(0.36,0.12,0.30),OLIVE_DARK)
 node(cradle,"Package",package)
 # The caps over the muzzles of the loaded tubes: they fly off at launch.
 var cap:=CylinderMesh.new();cap.top_radius=0.112;cap.bottom_radius=0.112;cap.height=0.02;cap.radial_segments=12;cap.rings=1
 var cap_material:=StandardMaterial3D.new();cap_material.albedo_color=CAP;cap_material.roughness=0.45;cap_material.metallic=0.5
 cap.material=cap_material
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=cap;multi.instance_count=ROWS*COLUMNS
 for i in range(ROWS*COLUMNS):multi.set_instance_transform(i,cap_transform(i))
 var caps:=MultiMeshInstance3D.new();caps.name="Caps";caps.multimesh=multi;cradle.add_child(caps)
 return {"root":root,"wheels":gear.wheels,"drive":gear.drive,"turret":platform,"platform":platform,"cradle":cradle,"caps":multi,"jacks":jacks,"ram":ram}

# Tracks with their runs and pads; road wheels, idler and sprocket turn.
static func running_gear(root: Node3D) -> Dictionary:
 var track:=solid()
 var wheels: Array[MeshInstance3D]=[]
 var drive: Array[MeshInstance3D]=[]
 var wheel_mesh:=road_wheel_mesh()
 for s in [-1.0,1.0]:
  var x:float=s*TRACK_X
  var front:=Vector3(x,IDLER.y,IDLER.z);var rear:=Vector3(x,SPROCKET.y,SPROCKET.z)
  var ground_front:=Vector3(x,0.04,WHEELS_Z[0]-0.2);var ground_rear:=Vector3(x,0.04,WHEELS_Z[-1]+0.2)
  BmpArt.slab(track,ground_front,ground_rear,TRACK_WIDTH,0.08,TRACK_STEEL)
  BmpArt.slab(track,ground_front,front+Vector3(0,-SPROCKET_RADIUS,0),TRACK_WIDTH,0.08,TRACK_STEEL)
  BmpArt.slab(track,ground_rear,rear+Vector3(0,-SPROCKET_RADIUS,0),TRACK_WIDTH,0.08,TRACK_STEEL)
  var top:=SPROCKET_RADIUS+0.04
  var sag:=[front+Vector3(0,top,0)]
  for z in RETURN_Z:sag.append(Vector3(x,1.02,z))
  sag.append(rear+Vector3(0,top,0))
  for k in range(sag.size()-1):BmpArt.slab(track,sag[k],sag[k+1],TRACK_WIDTH,0.08,TRACK_STEEL)
  for end in [front,rear]:track.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),end),SPROCKET_RADIUS+0.04,TRACK_WIDTH,12,TRACK_STEEL,RUBBER)
  var z:=WHEELS_Z[0]-0.15
  while z<WHEELS_Z[-1]+0.15:
   track.box(at(Vector3(x,0.09,z)),Vector3(TRACK_WIDTH+0.02,0.02,0.06),Color("2a2824"))
   z+=0.16
  for rz in RETURN_Z:track.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3(x-s*0.06,0.94,rz)),0.10,0.20,8,STEEL)
  for wz in WHEELS_Z:
   var wheel:=MeshInstance3D.new();wheel.mesh=wheel_mesh;wheel.position=Vector3(x,WHEEL_RADIUS+0.08,wz)
   root.add_child(wheel);wheels.append(wheel)
  for end in [front,rear]:
   var hub:=solid()
   for k in range(8 if end==rear else 6):
    var a:=TAU*k/(8.0 if end==rear else 6.0)
    hub.box(Transform3D(Basis(Vector3.RIGHT,a),Vector3.ZERO)*at(Vector3(0,SPROCKET_RADIUS*0.84,0)),Vector3(TRACK_WIDTH+0.04,0.07,0.10),STEEL)
   hub.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3.ZERO),0.14,TRACK_WIDTH+0.06,8,STEEL)
   drive.append(node(root,"Sprocket" if end==rear else "Idler",hub,end))
 node(root,"Tracks",track)
 return {"wheels":wheels,"drive":drive}

static func road_wheel_mesh() -> ArrayMesh:
 var mesh:=solid()
 # Twin road wheels with rubber tyres either side of the track's guide horns.
 for side in [-0.17,0.17]:
  mesh.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3(side,0,0)),WHEEL_RADIUS,0.20,16,RUBBER)
  mesh.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3(side*1.08,0,0)),WHEEL_RADIUS*0.80,0.19,14,OLIVE_DARK)
 for k in range(6):
  var a:=TAU*k/6.0
  mesh.box(Transform3D(Basis(Vector3.RIGHT,a),Vector3.ZERO)*at(Vector3(0,WHEEL_RADIUS*0.48,0)),Vector3(0.52,0.05,0.05),OLIVE)
 mesh.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3.ZERO),0.09,0.58,8,STEEL)
 return mesh.build(BmpArt.material())
