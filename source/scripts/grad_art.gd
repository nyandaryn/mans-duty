class_name GradArt
extends RefCounted

# BM-21 «Grad» on the Ural-375D chassis: 6×6, bonneted cab with a canvas
# top, launcher with a package of 40 tubes (4 rows of 10) behind the cab.
# Overall 7.35 × 2.40 × 3.09 m in travel. Vehicle frame: -Z forward, +X right,
# origin on the ground under the middle of the vehicle. Static parts are
# merged into a few vertex-coloured meshes.
const OLIVE := Color("4f5537")
const OLIVE_DARK := Color("3c4129")
const OLIVE_LIGHT := Color("5d6443")
const CANVAS := Color("5c5b42")
const RUBBER := Color("1f1f1c")
const STEEL := Color("3a3b36")
const BLACK := Color("141513")
const FRONT_AXLE := -2.45
const REAR_AXLES := [1.08,2.48]
const TRACK := 1.0
const WHEEL_RADIUS := 0.635
const WHEEL_WIDTH := 0.37
# Turntable centre and the trunnion of the package in vehicle coordinates.
const TURNTABLE := Vector3(0,1.45,1.75)
const TRUNNION := Vector3(0,0.55,0.6)
const TUBE_LENGTH := 3.0
const TUBE_REAR := 0.62
const ROWS := 4
const COLUMNS := 10
const DRIVER_EYE := Vector3(-0.48,2.27,-1.08)
const COMMANDER_EYE := Vector3(0.50,2.27,-1.08)
const STEERING_WHEEL := Vector3(-0.48,1.99,-1.62)
static var shared_material: StandardMaterial3D

static func material() -> StandardMaterial3D:
 if shared_material==null:
  shared_material=StandardMaterial3D.new()
  shared_material.vertex_color_use_as_albedo=true
  shared_material.vertex_color_is_srgb=true
  shared_material.roughness=0.82
  shared_material.metallic=0.05
 return shared_material

static func glass_material() -> StandardMaterial3D:
 var glass:=StandardMaterial3D.new()
 glass.albedo_color=Color(0.30,0.38,0.40,0.30)
 glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 glass.roughness=0.08;glass.metallic=0.2
 glass.cull_mode=BaseMaterial3D.CULL_DISABLED
 return glass

# Every box of the vehicle is closed: the chassis is seen from below.
static func solid() -> ColorMesh:
 var mesh:=ColorMesh.new();mesh.closed=true
 return mesh

static func at(p: Vector3) -> Transform3D:return Transform3D(Basis.IDENTITY,p)

static func node(parent: Node3D, name: String, mesh: ColorMesh) -> MeshInstance3D:
 var instance:=MeshInstance3D.new();instance.name=name
 instance.mesh=mesh.build(material())
 parent.add_child(instance)
 return instance

# Position of a tube's axis in cradle coordinates (rear end z = TUBE_REAR).
static func tube_axis(index: int) -> Vector3:
 var row:=index/COLUMNS;var column:=index%COLUMNS
 return Vector3((column-4.5)*0.155,0.14+row*0.16,0)

# Firing order of the pulse distributor: alternating sides, top row first,
# so the package rocks as little as possible.
static func firing_order() -> PackedInt32Array:
 var order:=PackedInt32Array()
 for row in range(ROWS-1,-1,-1):
  for k in range(COLUMNS/2):
   order.append(row*COLUMNS+k)
   order.append(row*COLUMNS+COLUMNS-1-k)
 return order

static func build() -> Dictionary:
 var root:=Node3D.new();root.name="GradArt"
 var body:=solid()
 var glass:=solid()
 # Frame and running gear.
 for x in [-0.48,0.48]:body.box(at(Vector3(x,1.05,-0.1)),Vector3(0.12,0.26,6.9),OLIVE_DARK)
 body.box(at(Vector3(0,0.88,-3.62)),Vector3(2.25,0.22,0.18),OLIVE_DARK,true)
 for x in [-0.75,0.75]:body.box(at(Vector3(x,0.82,-3.76)),Vector3(0.1,0.08,0.12),STEEL)
 for z in [FRONT_AXLE]+REAR_AXLES:body.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3(0,WHEEL_RADIUS,z)),0.09,1.75,8,STEEL)
 # Underside between the rails: engine sump and gearbox under the bonnet and
 # the cab, the transfer case, drive shafts to the three axles, differential
 # housings, fuel tank and battery box, exhaust.
 body.box(at(Vector3(0,1.02,-2.75)),Vector3(0.70,0.36,1.05),STEEL)
 body.box(at(Vector3(0,1.00,-1.75)),Vector3(0.42,0.32,0.80),STEEL)
 var transfer:=Vector3(0,0.86,-0.55)
 body.box(at(transfer),Vector3(0.52,0.34,0.42),STEEL)
 for z in [FRONT_AXLE]+REAR_AXLES:
  body.box(at(Vector3(0,WHEEL_RADIUS,z)),Vector3(0.36,0.30,0.34),STEEL)
  var to:=Vector3(0,WHEEL_RADIUS,z);var from:=transfer if z<0 or z<2.0 else Vector3(0,WHEEL_RADIUS,REAR_AXLES[0])
  var along:=to-from
  body.cylinder(Transform3D(Basis(Quaternion(Vector3.UP,along.normalized())),(from+to)*0.5),0.045,along.length(),6,STEEL)
 body.box(at(Vector3(-1.02,0.98,-0.95)),Vector3(0.40,0.40,0.62),OLIVE_DARK)
 body.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3(0.62,0.80,-0.10)),0.06,0.10,8,STEEL)
 body.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0.62,0.80,-1.4)),0.05,2.6,8,BLACK)
 # Bonnet with the radiator grille; the fenders carry the headlights.
 body.box(at(Vector3(0,1.57,-2.85)),Vector3(1.16,0.86,1.4),OLIVE)
 body.box(at(Vector3(0,1.55,-3.565)),Vector3(1.02,0.74,0.04),BLACK)
 for k in range(9):body.box(at(Vector3(-0.44+k*0.11,1.55,-3.59)),Vector3(0.035,0.70,0.03),OLIVE_DARK)
 for x in [-0.88,0.88]:
  body.box(at(Vector3(x,1.42,-2.78)),Vector3(0.62,0.07,1.38),OLIVE)
  body.box(Transform3D(Basis(Vector3.RIGHT,-0.55),Vector3(x,1.24,-3.55)),Vector3(0.62,0.07,0.42),OLIVE)
  body.box(at(Vector3(x*1.13,1.2,-2.15)),Vector3(0.08,0.45,0.25),OLIVE)
  body.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(x*0.92,1.58,-3.3)),0.11,0.16,10,STEEL,Color("d8d7c4"))
  body.box(at(Vector3(x*1.18,0.78,-1.40)),Vector3(0.25,0.05,0.42),STEEL)
 # Cab: steel lower body, window frames, canvas top.
 body.box(at(Vector3(0,1.66,-2.11)),Vector3(2.25,0.90,0.08),OLIVE)
 body.box(at(Vector3(0,1.90,-0.68)),Vector3(2.25,1.40,0.06),OLIVE)
 for x in [-1.1,1.1]:
  body.box(at(Vector3(x,1.66,-1.40)),Vector3(0.06,0.90,1.46),OLIVE)
  body.box(at(Vector3(x*1.005,1.80,-1.28)),Vector3(0.02,0.04,0.18),STEEL)
  body.box(at(Vector3(x,2.34,-0.71)),Vector3(0.06,0.46,0.06),OLIVE)
  body.box(at(Vector3(x,2.56,-1.40)),Vector3(0.06,0.05,1.44),OLIVE)
  body.box(at(Vector3(x,2.34,-2.12)),Vector3(0.07,0.46,0.07),OLIVE)
  glass.box(at(Vector3(x,2.33,-1.40)),Vector3(0.01,0.40,1.30),Color.WHITE)
  glass.box(at(Vector3(x*0.5,2.33,-2.115)),Vector3(1.0,0.40,0.01),Color.WHITE)
  # Rear-view mirrors on brackets.
  body.box(at(Vector3(x*1.32,2.30,-2.05)),Vector3(0.04,0.22,0.14),BLACK)
  body.box(at(Vector3(x*1.21,2.30,-2.08)),Vector3(0.22,0.02,0.02),STEEL)
 body.box(at(Vector3(0,2.34,-2.12)),Vector3(0.06,0.46,0.06),OLIVE)
 body.box(at(Vector3(0,2.56,-2.12)),Vector3(2.25,0.05,0.07),OLIVE)
 body.box(at(Vector3(0,2.65,-1.40)),Vector3(2.32,0.14,1.58),CANVAS,true)
 # Interior: floor, engine hump, dashboard, seats, levers, fire-control panel.
 body.box(at(Vector3(0,1.22,-1.40)),Vector3(2.15,0.05,1.40),OLIVE_DARK)
 body.box(at(Vector3(0,1.40,-1.80)),Vector3(0.55,0.32,0.60),OLIVE_DARK)
 body.box(at(Vector3(0,1.99,-1.98)),Vector3(2.12,0.28,0.24),Color("2f3326"))
 body.box(at(Vector3(-0.48,2.03,-1.86)),Vector3(0.56,0.22,0.05),BLACK)
 for k in range(4):body.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(-0.68+k*0.135,2.03,-1.835)),0.045,0.012,12,Color("d6d3c3"),Color("101010"))
 body.cylinder(Transform3D(Basis(Vector3.RIGHT,-0.95),Vector3(-0.48,1.72,-1.78)),0.03,0.55,6,STEEL)
 for x in [-0.50,0.45]:
  var wide:=0.50 if x<0 else 0.95
  body.box(at(Vector3(x,1.60,-1.00)),Vector3(wide,0.12,0.50),Color("3b3d2c"))
  body.box(Transform3D(Basis(Vector3.RIGHT,-0.12),Vector3(x,1.95,-0.76)),Vector3(wide,0.60,0.10),Color("3b3d2c"))
 for lever in [[Vector3(-0.17,1.55,-1.42),0.20,0.45],[Vector3(-0.05,1.52,-1.30),0.0,0.32],[Vector3(0.06,1.52,-1.34),-0.15,0.30]]:
  body.cylinder(Transform3D(Basis(Vector3.RIGHT,float(lever[1])),lever[0]),0.012,float(lever[2]),5,STEEL)
  body.box(at(Vector3(lever[0])+Vector3(0,float(lever[2])*0.5,0)),Vector3(0.04,0.04,0.04),BLACK)
 # Fire-control panel in front of the commander and the radio behind him.
 body.box(Transform3D(Basis(Vector3.RIGHT,-0.35),Vector3(0.58,2.08,-1.90)),Vector3(0.46,0.30,0.10),Color("3a4030"))
 for k in range(6):body.box(at(Vector3(0.40+k*0.07,2.12,-1.83)),Vector3(0.025,0.04,0.03),BLACK)
 body.box(at(Vector3(0.70,2.28,-0.82)),Vector3(0.42,0.26,0.24),Color("3e4433"))
 # Spare wheel behind the cab, the travel rest of the package.
 body.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,1.78,-0.42)),WHEEL_RADIUS,WHEEL_WIDTH,14,RUBBER,OLIVE_DARK)
 body.box(at(Vector3(0,1.62,0.18)),Vector3(0.30,0.86,0.14),OLIVE_DARK)
 # Launcher subframe, mudguards over the bogie, tanks and boxes.
 body.box(at(Vector3(0,1.22,1.40)),Vector3(2.20,0.22,3.70),OLIVE)
 for x in [-1.02,1.02]:
  body.box(at(Vector3(x,1.36,1.78)),Vector3(0.44,0.05,2.45),OLIVE_DARK)
  body.box(at(Vector3(x*1.05,0.95,-0.15)),Vector3(0.38,0.48,0.95),OLIVE)
 body.cylinder(Transform3D(Basis.IDENTITY,TURNTABLE-Vector3(0,0.10,0)),0.78,0.20,16,OLIVE_DARK)
 for z in [0.6,3.0]:body.box(at(Vector3(0,1.36,z)),Vector3(2.2,0.06,0.06),OLIVE_DARK)
 # The «БОЙОВЕ/ПОХІД» air valve on the left side, ahead of the bogie.
 body.box(at(Vector3(-1.16,1.18,0.55)),Vector3(0.10,0.18,0.16),Color("2e3324"))
 body.box(at(Vector3(-1.23,1.24,0.55)),Vector3(0.05,0.03,0.14),Color("8a2a20"))
 node(root,"Body",body)
 var panes:=MeshInstance3D.new();panes.name="Glass";panes.mesh=glass.build(glass_material())
 panes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(panes)
 # Steering wheel on its column.
 var steering:=Node3D.new();steering.name="SteeringWheel";steering.position=STEERING_WHEEL
 steering.rotation.x=-0.62;root.add_child(steering)
 var rim:=solid()
 for k in range(18):
  var a0:=TAU*k/18;var a1:=TAU*(k+1)/18
  var p0:=Vector3(cos(a0),0,sin(a0))*0.235;var p1:=Vector3(cos(a1),0,sin(a1))*0.235
  rim.box(Transform3D(Basis.looking_at((p1-p0).normalized(),Vector3.UP),(p0+p1)*0.5),Vector3(0.028,0.028,p0.distance_to(p1)+0.004),BLACK)
 for a in [0.0,PI*2/3,PI*4/3]:rim.box(Transform3D(Basis(Vector3.UP,a),Vector3(0,0,0)).translated_local(Vector3(0.11,0,0)),Vector3(0.22,0.015,0.03),BLACK)
 node(steering,"Rim",rim)
 # Armoured windscreen shields: hinged at the top of the windscreen; up
 # like a visor on the march, down over the glass in action.
 var shields: Array[Node3D]=[]
 for x in [-0.53,0.53]:
  var hinge:=Node3D.new();hinge.name="Shield";hinge.position=Vector3(x,2.60,-2.17);root.add_child(hinge)
  var plate:=solid()
  plate.box(at(Vector3(0,-0.22,0)),Vector3(1.0,0.44,0.012),OLIVE,true)
  for k in range(2):plate.box(at(Vector3(-0.25+k*0.5,-0.24,-0.008)),Vector3(0.36,0.035,0.01),BLACK)
  node(hinge,"Plate",plate)
  shields.append(hinge)
 # Turntable (traverse), cradle (elevation) with the package of 40 tubes.
 var turret:=Node3D.new();turret.name="Turret";turret.position=TURNTABLE;root.add_child(turret)
 var carriage:=solid()
 for x in [-0.86,0.86]:
  carriage.box(at(Vector3(x,0.30,0.35)),Vector3(0.08,0.62,1.30),OLIVE)
  carriage.box(at(Vector3(x,0.55,0.60)),Vector3(0.12,0.16,0.16),OLIVE_DARK)
 carriage.box(at(Vector3(0,0.06,0.35)),Vector3(1.80,0.12,1.40),OLIVE_DARK)
 carriage.box(at(Vector3(0.45,0.25,-0.25)),Vector3(0.40,0.30,0.35),Color("394029"))
 # Gunner's side: handwheels of traverse and elevation under the sight.
 for wheel in [Vector3(-1.02,0.42,0.30),Vector3(-1.02,0.62,0.85)]:
  carriage.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),wheel),0.13,0.03,12,STEEL)
 carriage.box(at(Vector3(-1.10,-0.05,0.55)),Vector3(0.45,0.05,0.70),OLIVE_DARK)
 node(turret,"Carriage",carriage)
 var cradle:=Node3D.new();cradle.name="Cradle";cradle.position=TRUNNION;turret.add_child(cradle)
 var package:=solid()
 var middle:=TUBE_REAR-TUBE_LENGTH*0.5
 for i in range(ROWS*COLUMNS):
  var axis:=tube_axis(i)
  package.pipe(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(axis.x,axis.y,middle)),0.071,0.061,TUBE_LENGTH,8,OLIVE,Color("1d1e19"))
 for x in [-0.80,0.80]:package.box(at(Vector3(x,0.38,middle)),Vector3(0.04,0.62,TUBE_LENGTH-0.1),OLIVE_DARK)
 package.box(at(Vector3(0,0.05,middle)),Vector3(1.62,0.04,TUBE_LENGTH-0.1),OLIVE_DARK)
 for z in [-2.05,-1.1,-0.15,0.45]:
  package.box(at(Vector3(0,0.70,z)),Vector3(1.64,0.035,0.07),OLIVE_DARK)
  package.box(at(Vector3(0,0.05,z)),Vector3(1.64,0.05,0.09),OLIVE_DARK)
 package.box(at(Vector3(0,-0.12,-0.2)),Vector3(0.9,0.22,0.5),OLIVE_DARK)
 node(cradle,"Package",package)
 # Rockets seen from behind: the nozzle block of each loaded rocket.
 var nozzle:=CylinderMesh.new();nozzle.top_radius=0.056;nozzle.bottom_radius=0.058;nozzle.height=0.05;nozzle.radial_segments=10;nozzle.rings=1
 var nozzle_material:=StandardMaterial3D.new();nozzle_material.albedo_color=Color("4a4a42");nozzle_material.roughness=0.6;nozzle_material.metallic=0.4
 nozzle.material=nozzle_material
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=nozzle;multi.instance_count=ROWS*COLUMNS
 for i in range(ROWS*COLUMNS):multi.set_instance_transform(i,rocket_transform(i))
 var rockets:=MultiMeshInstance3D.new();rockets.name="Rockets";rockets.multimesh=multi;cradle.add_child(rockets)
 # Canvas cover of the package on the march.
 var cover_mesh:=solid()
 cover_mesh.box(at(Vector3(0,0.38,middle)),Vector3(1.74,0.80,TUBE_LENGTH+0.12),CANVAS,true)
 for z in [-1.9,-0.9,0.1]:cover_mesh.box(at(Vector3(0,0.38,z)),Vector3(1.76,0.82,0.05),Color("4a4934"))
 var cover:=node(cradle,"Cover",cover_mesh)
 # Sight bracket on the left of the cradle trunnion: the D726-45 sight with
 # the PG-1M panorama. Folded down on the march.
 var bracket:=Node3D.new();bracket.name="SightBracket";bracket.position=Vector3(-0.98,0.55,0.60);turret.add_child(bracket)
 var sight:=solid()
 sight.box(at(Vector3(0,0.10,0)),Vector3(0.06,0.22,0.06),OLIVE_DARK)
 sight.box(at(Vector3(0,0.26,0)),Vector3(0.14,0.14,0.20),Color("373c2a"))
 sight.cylinder(at(Vector3(0,0.40,0)),0.055,0.14,10,Color("2c3022"))
 sight.box(at(Vector3(0,0.46,-0.07)),Vector3(0.07,0.06,0.06),BLACK)
 sight.box(at(Vector3(-0.09,0.27,0.04)),Vector3(0.05,0.07,0.07),Color("2a2a22"))
 node(bracket,"Sight",sight)
 var panorama:=Node3D.new();panorama.name="Panorama";panorama.position=Vector3(0,0.46,0);bracket.add_child(panorama)
 return {"root":root,"steering":steering,"shields":shields,"turret":turret,"cradle":cradle,"rockets":multi,"cover":cover,"bracket":bracket,"panorama":panorama}

static func rocket_transform(index: int) -> Transform3D:
 var axis:=tube_axis(index)
 return Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(axis.x,axis.y,TUBE_REAR-0.10))

static func wheel_mesh() -> ArrayMesh:
 var wheel:=solid()
 var axis:=Basis(Vector3.BACK,PI/2)
 wheel.cylinder(Transform3D(axis,Vector3.ZERO),WHEEL_RADIUS,WHEEL_WIDTH,18,RUBBER)
 # Tread blocks of the 14.00-20 cross-country tyre.
 for k in range(18):
  var a:=TAU*(k+0.5)/18
  var r:=Vector3(0,cos(a),sin(a))
  wheel.box(Transform3D(Basis(Vector3.RIGHT,a),r*(WHEEL_RADIUS+0.012)),Vector3(WHEEL_WIDTH*0.86,0.03,0.09),RUBBER)
 for side in [-1.0,1.0]:
  wheel.cylinder(Transform3D(axis,Vector3(side*(WHEEL_WIDTH*0.5+0.005),0,0)),0.36,0.02,14,OLIVE_DARK)
  wheel.cylinder(Transform3D(axis,Vector3(side*(WHEEL_WIDTH*0.5+0.035),0,0)),0.13,0.06,10,OLIVE)
 return wheel.build(material())
