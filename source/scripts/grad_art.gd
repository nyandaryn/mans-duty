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
# Hub of the steering wheel. The column rises from the floor at the bulkhead
# and leans back 40° toward the driver; the wheel turns about it, and its rim
# stays below the driver's line of sight to the instrument cluster.
const STEERING_WHEEL := Vector3(-0.48,1.80,-1.55)
const STEERING_TILT := 0.70
const STEERING_RADIUS := 0.235
# Face of the instrument cluster before the driver (GradDashboard paints it).
const DASHBOARD := Vector3(-0.48,2.03,-1.833)
const DASHBOARD_SIZE := Vector2(0.54,0.20)
# Rear-view mirrors on brackets off the windscreen pillars, set for the
# driver: each glass looks back along its side of the vehicle (GradMirror).
const MIRROR_SIZE := Vector2(0.17,0.25)
const MIRRORS := [Vector3(-1.36,2.28,-2.02),Vector3(1.36,2.28,-2.02)]
# The receiver in the middle of the dashboard (GradVehicle.toggle_radio).
const RADIO := Vector3(0.04,1.93,-1.848)
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

# A round bar between two points.
static func rod(mesh: ColorMesh, from: Vector3, to: Vector3, radius: float, color: Color, sides: int=6) -> void:
 var along:=to-from
 mesh.cylinder(Transform3D(Basis(Quaternion(Vector3.UP,along.normalized())),(from+to)*0.5),radius,along.length(),sides,color)

# Frame of a mirror glass: +Z is the reflecting side. It halves the angle
# between the driver's eye and a point 12 m behind, just outside the side of
# the vehicle: the driver sees the flank along the inner edge of the glass,
# the road behind and the horizon.
static func mirror_frame(center: Vector3) -> Transform3D:
 var side:=signf(center.x)
 var to_eye:=(DRIVER_EYE-center).normalized()
 var back:=(Vector3(side*1.25,1.6,10.0)-center).normalized()
 var facing:=(to_eye+back).normalized()
 var right:=Vector3.UP.cross(facing).normalized()
 return Transform3D(Basis(right,facing.cross(right),facing),center)

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
 body.box(at(Vector3(0,1.66,-0.68)),Vector3(2.25,0.92,0.06),OLIVE)
 body.box(at(Vector3(0,2.50,-0.68)),Vector3(2.25,0.20,0.06),OLIVE)
 for piece in [[-0.9175,0.415],[0.0,0.50],[0.9175,0.415]]:body.box(at(Vector3(piece[0],2.26,-0.68)),Vector3(piece[1],0.28,0.06),OLIVE)
 for x in [-0.48,0.48]:
  glass.box(at(Vector3(x,2.26,-0.68)),Vector3(0.46,0.28,0.01),Color.WHITE)
 for x in [-1.1,1.1]:
  body.box(at(Vector3(x,1.66,-1.40)),Vector3(0.06,0.90,1.46),OLIVE)
  body.box(at(Vector3(x*1.005,1.80,-1.28)),Vector3(0.02,0.04,0.18),STEEL)
  body.box(at(Vector3(x,2.34,-0.71)),Vector3(0.06,0.46,0.06),OLIVE)
  body.box(at(Vector3(x,2.56,-1.40)),Vector3(0.06,0.05,1.44),OLIVE)
  body.box(at(Vector3(x,2.34,-2.12)),Vector3(0.07,0.46,0.07),OLIVE)
  glass.box(at(Vector3(x,2.33,-1.40)),Vector3(0.01,0.40,1.30),Color.WHITE)
  glass.box(at(Vector3(x*0.5,2.33,-2.115)),Vector3(1.0,0.40,0.01),Color.WHITE)
  # Door: seams, hinges and the outer handle; the step below it.
  for z in [-1.96,-0.86]:body.box(at(Vector3(x*1.132,1.69,z)),Vector3(0.006,0.86,0.014),Color("2a2d20"))
  for y in [1.48,1.92]:body.box(at(Vector3(x*1.135,y,-1.93)),Vector3(0.03,0.09,0.05),OLIVE_DARK)
  body.box(at(Vector3(x*1.142,1.98,-1.02)),Vector3(0.03,0.035,0.15),STEEL)
 body.box(at(Vector3(0,2.34,-2.12)),Vector3(0.06,0.46,0.06),OLIVE)
 body.box(at(Vector3(0,2.56,-2.12)),Vector3(2.25,0.05,0.07),OLIVE)
 body.box(at(Vector3(0,2.65,-1.40)),Vector3(2.32,0.14,1.58),CANVAS,true)
 # Rear-view mirrors: framed glass on an upper and a lower arm from the
 # windscreen pillar.
 for center in MIRRORS:
  var frame:=mirror_frame(center)
  var side:=signf(center.x)
  body.box(frame*at(Vector3(0,0,-0.021)),Vector3(MIRROR_SIZE.x+0.024,MIRROR_SIZE.y+0.024,0.036),BLACK)
  var inner:=frame*Vector3(-side*(MIRROR_SIZE.x*0.5-0.01),0,-0.03)
  rod(body,Vector3(side*1.13,2.47,-2.09),inner+Vector3(0,0.10,0),0.012,STEEL)
  rod(body,Vector3(side*1.13,2.10,-2.06),inner-Vector3(0,0.10,0),0.012,STEEL)
 # Windscreen wipers hanging from the top of each pane.
 for x in [-0.62,0.38]:
  var wiper:=Transform3D(Basis(Vector3.BACK,0.30),Vector3(x+0.05,2.36,-2.128))
  body.box(wiper,Vector3(0.012,0.34,0.008),BLACK)
  body.box(wiper*at(Vector3(0.012,-0.02,0.0)),Vector3(0.018,0.30,0.012),RUBBER)
  body.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(x,2.52,-2.135)),0.018,0.03,6,STEEL)
 # Interior: floor, engine hump, dashboard, seats, levers, fire-control panel.
 body.box(at(Vector3(0,1.22,-1.40)),Vector3(2.15,0.05,1.40),OLIVE_DARK)
 body.box(at(Vector3(0,1.40,-1.80)),Vector3(0.55,0.32,0.60),OLIVE_DARK)
 body.box(at(Vector3(0,1.99,-1.98)),Vector3(2.12,0.28,0.24),Color("2f3326"))
 body.box(at(Vector3(-0.48,2.03,-1.86)),Vector3(0.56,0.22,0.05),BLACK)
 # Dashboard: defroster slot, toggle switches and the ignition lock, the
 # receiver in the middle.
 body.box(at(Vector3(0,2.134,-1.95)),Vector3(1.90,0.006,0.05),BLACK)
 for k in range(5):
  body.box(at(Vector3(-0.17+k*0.045,2.08,-1.858)),Vector3(0.03,0.03,0.008),Color("1b1c18"))
  body.box(Transform3D(Basis(Vector3.RIGHT,-0.5),Vector3(-0.17+k*0.045,2.085,-1.845)),Vector3(0.008,0.008,0.03),STEEL)
 body.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(-0.16,1.95,-1.855)),0.018,0.012,8,STEEL,BLACK)
 body.box(at(RADIO+Vector3(0,0,-0.012)),Vector3(0.22,0.07,0.04),Color("1b1c18"))
 for x in [-0.085,0.085]:body.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),RADIO+Vector3(x,0,0.012)),0.014,0.018,8,STEEL,BLACK)
 for k in range(4):body.box(at(RADIO+Vector3(-0.045+k*0.03,-0.024,0.008)),Vector3(0.02,0.012,0.008),Color("4a4b44"))
 # Steering column from the floor at the bulkhead up to the hub.
 var column:=Basis(Vector3.RIGHT,STEERING_TILT)
 body.cylinder(Transform3D(column,STEERING_WHEEL+column*Vector3(0,-0.36,0)),0.028,0.62,8,STEEL)
 body.cylinder(Transform3D(column,STEERING_WHEEL+column*Vector3(0,-0.14,0)),0.045,0.16,8,BLACK)
 # Pedals: clutch, brake and the throttle by the engine hump.
 for x in [-0.68,-0.48]:
  body.box(Transform3D(Basis(Vector3.RIGHT,0.75),Vector3(x,1.40,-1.80)),Vector3(0.08,0.11,0.018),BLACK)
  rod(body,Vector3(x,1.43,-1.83),Vector3(x,1.62,-2.08),0.012,STEEL)
 body.box(Transform3D(Basis(Vector3.RIGHT,1.0),Vector3(-0.32,1.31,-1.82)),Vector3(0.07,0.20,0.014),BLACK)
 # Floor mats.
 body.box(at(Vector3(-0.58,1.248,-1.45)),Vector3(0.80,0.008,0.80),RUBBER)
 body.box(at(Vector3(0.62,1.248,-1.40)),Vector3(0.80,0.008,0.90),RUBBER)
 # Door trim inside: panel, armrest, window crank and the opening lever.
 for x in [-1.0,1.0]:
  body.box(at(Vector3(x*1.064,1.78,-1.40)),Vector3(0.012,0.56,0.96),Color("454934"))
  body.box(at(Vector3(x*1.045,1.86,-1.12)),Vector3(0.04,0.05,0.32),Color("2e3124"))
  body.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3(x*1.05,1.92,-1.62)),0.035,0.012,10,STEEL)
  rod(body,Vector3(x*1.045,1.92,-1.62),Vector3(x*1.035,1.92,-1.585),0.008,BLACK)
  body.box(at(Vector3(x*1.05,2.00,-0.96)),Vector3(0.02,0.03,0.12),STEEL)
 # Roof bows under the canvas and the sun visors over the windscreen.
 for z in [-1.98,-1.40,-0.82]:body.box(at(Vector3(0,2.565,z)),Vector3(2.18,0.025,0.035),OLIVE_DARK)
 for x in [-0.50,0.50]:body.box(Transform3D(Basis(Vector3.RIGHT,0.28),Vector3(x,2.515,-2.02)),Vector3(0.44,0.012,0.16),Color("4b4e3b"))
 # Fire extinguisher in its bracket by the commander's door.
 body.cylinder(at(Vector3(0.93,1.45,-1.96)),0.055,0.38,10,Color("8a2a20"),BLACK)
 body.box(at(Vector3(0.93,1.68,-1.96)),Vector3(0.05,0.07,0.05),BLACK)
 body.box(at(Vector3(0.93,1.45,-2.02)),Vector3(0.13,0.03,0.02),STEEL)
 # Seats: a frame on the floor, cushion and backrest with a top roll.
 for x in [-0.50,0.45]:
  var wide:=0.50 if x<0 else 0.95
  body.box(at(Vector3(x,1.39,-1.00)),Vector3(wide*0.86,0.30,0.40),OLIVE_DARK)
  body.box(at(Vector3(x,1.60,-1.00)),Vector3(wide,0.12,0.50),Color("3b3d2c"))
  body.box(at(Vector3(x,1.665,-1.00)),Vector3(wide-0.06,0.012,0.44),Color("33352a"))
  body.box(Transform3D(Basis(Vector3.RIGHT,-0.12),Vector3(x,1.95,-0.76)),Vector3(wide,0.60,0.10),Color("3b3d2c"))
  body.box(Transform3D(Basis(Vector3.RIGHT,-0.12),Vector3(x,2.25,-0.72)),Vector3(wide,0.07,0.13),Color("33352a"))
 for lever in [[Vector3(-0.17,1.55,-1.42),0.20,0.45],[Vector3(-0.05,1.52,-1.30),0.0,0.32],[Vector3(0.06,1.52,-1.34),-0.15,0.30]]:
  body.cylinder(Transform3D(Basis(Vector3.RIGHT,float(lever[1])),lever[0]),0.012,float(lever[2]),5,STEEL)
  body.box(at(Vector3(lever[0])+Vector3(0,float(lever[2])*0.5,0)),Vector3(0.04,0.04,0.04),BLACK)
 # Fire-control panel in front of the commander and the radio behind him.
 body.box(Transform3D(Basis(Vector3.RIGHT,-0.35),Vector3(0.58,2.08,-1.90)),Vector3(0.46,0.30,0.10),Color("3a4030"))
 for k in range(6):body.box(at(Vector3(0.40+k*0.07,2.12,-1.83)),Vector3(0.025,0.04,0.03),BLACK)
 body.box(at(Vector3(0.70,2.28,-0.82)),Vector3(0.42,0.26,0.24),Color("3e4433"))
 for k in range(3):body.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0.58+k*0.09,2.30,-0.945)),0.02,0.02,8,BLACK)
 body.box(at(Vector3(0.58,2.22,-0.946)),Vector3(0.06,0.04,0.008),Color("2a2d20"))
 body.box(Transform3D(Basis(Vector3.BACK,0.15),Vector3(0.96,2.20,-0.80)),Vector3(0.05,0.20,0.06),BLACK)
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
 # The column frame is tilted; the wheel (its +Y is the column axis toward
 # the driver, -Z the top of the rim) spins about +Y inside it.
 var column_frame:=Node3D.new();column_frame.name="SteeringColumn";column_frame.position=STEERING_WHEEL
 column_frame.rotation.x=STEERING_TILT;root.add_child(column_frame)
 var steering:=Node3D.new();steering.name="SteeringWheel";column_frame.add_child(steering)
 var rim:=solid()
 for k in range(24):
  var a0:=TAU*k/24;var a1:=TAU*(k+1)/24
  var p0:=Vector3(cos(a0),0,sin(a0))*STEERING_RADIUS;var p1:=Vector3(cos(a1),0,sin(a1))*STEERING_RADIUS
  rim.box(Transform3D(Basis.looking_at((p1-p0).normalized(),Vector3.UP),(p0+p1)*0.5),Vector3(0.03,0.03,p0.distance_to(p1)+0.004),BLACK)
 # Three spokes: to 3, 9 and 6 o'clock, the side ones dipping a little.
 for a in [-0.22,PI+0.22,PI*0.5]:
  rim.box(Transform3D(Basis(Vector3.UP,-a),Vector3.ZERO).translated_local(Vector3(0.14,-0.012,0)),Vector3(0.19,0.014,0.036),BLACK)
 rim.cylinder(at(Vector3(0,-0.01,0)),0.06,0.05,12,BLACK)
 rim.cylinder(at(Vector3(0,0.02,0)),0.038,0.012,12,Color("5b3a2a"))
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
 # Display of the receiver: lit while it plays.
 var display:=MeshInstance3D.new();display.name="RadioDisplay"
 var display_mesh:=QuadMesh.new();display_mesh.size=Vector2(0.09,0.022)
 var lamp:=StandardMaterial3D.new();lamp.albedo_color=Color("141410");lamp.emission_enabled=true;lamp.emission=Color("ff9a3c");lamp.emission_energy_multiplier=0.0
 display_mesh.material=lamp;display.mesh=display_mesh
 display.position=RADIO+Vector3(0,0.012,0.0095);display.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(display)
 return {"root":root,"steering":steering,"radio_display":display,"shields":shields,"turret":turret,"cradle":cradle,"rockets":multi,"cover":cover,"bracket":bracket,"panorama":panorama}

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
