class_name BmpArt
extends RefCounted

# BMP-2: amphibious tracked infantry fighting vehicle. Hull 6.72 × 3.15 m,
# 2.45 m over the turret, ground clearance 0.42 m. Long ribbed upper glacis
# with the folded trim vane, driver's hatch front left, the engine front
# right, the two-man turret (gunner left, commander right) with the 30 mm
# 2A42, the coaxial PKT and the 9P135M launcher of the Konkurs on the roof;
# the troop compartment behind with four roof hatches, firing ports in the
# sides and two rear doors that are fuel tanks. Six rubber-tyred road wheels
# a side, the drive sprocket in front, the idler at the rear, three return
# rollers. Vehicle frame: -Z forward, +X right, origin on the ground under
# the middle of the hull. Static parts are merged into vertex-coloured meshes.
const OLIVE := Color("4a5236")
const OLIVE_DARK := Color("373d27")
const OLIVE_LIGHT := Color("596243")
const RUBBER := Color("1d1d1a")
const STEEL := Color("3b3c37")
const TRACK_STEEL := Color("33302b")
const BLACK := Color("121311")
const GLASS := Color("2b3a3c")
const LENGTH := 6.72
const WIDTH := 3.15
const HALF := 3.36
const ROOF := 1.62
const FENDER := 0.96
const TRACK_X := 1.275
const TRACK_WIDTH := 0.30
const WHEEL_RADIUS := 0.27
const WHEELS_Z := [-1.86,-1.13,-0.39,0.35,1.09,1.83]
const SPROCKET := Vector3(0,0.66,-2.92)
const IDLER := Vector3(0,0.60,2.95)
const SPROCKET_RADIUS := 0.27
const RETURN_Z := [-1.45,-0.05,1.35]
const TURRET := Vector3(0,ROOF,-0.30)
# Gun trunnion in turret coordinates.
const TRUNNION := Vector3(-0.05,0.40,-0.80)
const BARREL := 2.95
const DRIVER_HATCH := Vector3(-0.78,1.50,-1.30)
# Driver's eye at the three periscopes (hatch closed) and with the head out.
const DRIVER_EYE := Vector3(-0.78,1.36,-1.42)
# The heads of the three TNPO-170A on the roof in front of the hatch (the
# glacis there is at 1.46 m): what the prisms see, they see from here.
const DRIVER_PRISM := Vector3(-0.78,1.63,-1.66)
const DRIVER_HEAD_OUT := Vector3(-0.78,2.02,-1.22)
const GUNNER_EYE := Vector3(-0.42,2.30,-0.55)
# Rear doors: hinges on the outer edges, the doors are the fuel tanks.
const DOOR_HINGE_X := 0.90
const DOOR_WIDTH := 0.78
const DOOR_BOTTOM := 0.50
const DOOR_TOP := 1.42
# Where the troops step down behind the open doors, and the receiver
# beside the driver.
const EXITS := [Vector3(-0.75,0,4.25),Vector3(0.75,0,4.25)]
const RADIO := Vector3(-1.18,1.15,-1.62)
static var shared_material: StandardMaterial3D

static func material() -> StandardMaterial3D:
 if shared_material==null:
  shared_material=StandardMaterial3D.new()
  shared_material.vertex_color_use_as_albedo=true
  shared_material.vertex_color_is_srgb=true
  shared_material.roughness=0.86
  shared_material.metallic=0.06
 return shared_material

static func solid() -> ColorMesh:
 var mesh:=ColorMesh.new();mesh.closed=true
 return mesh

static func at(p: Vector3) -> Transform3D:return Transform3D(Basis.IDENTITY,p)

static func node(parent: Node3D, name: String, mesh: ColorMesh, position: Vector3=Vector3.ZERO) -> MeshInstance3D:
 var instance:=MeshInstance3D.new();instance.name=name
 instance.mesh=mesh.build(material());instance.position=position
 parent.add_child(instance)
 return instance

static func rod(mesh: ColorMesh, from: Vector3, to: Vector3, radius: float, color: Color, sides: int=6) -> void:
 var along:=to-from
 mesh.cylinder(Transform3D(Basis(Quaternion(Vector3.UP,along.normalized())),(from+to)*0.5),radius,along.length(),sides,color)

# A side profile in (z, y) extruded across x0..x1: closed faces on both
# sides and the strips around the outline.
static func extrude(mesh: ColorMesh, outline: PackedVector2Array, x0: float, x1: float, color: Color) -> void:
 var triangles:=Geometry2D.triangulate_polygon(outline)
 for k in range(0,triangles.size(),3):
  for x in [x0,x1]:
   var a:=outline[triangles[k]];var b:=outline[triangles[k+1]];var c:=outline[triangles[k+2]]
   mesh.triangle(Vector3(x,a.y,a.x),Vector3(x,b.y,b.x),Vector3(x,c.y,c.x),color.darkened(0.06),Vector3(signf(x-(x0+x1)*0.5),0,0))
 var middle:=Vector2.ZERO
 for p in outline:middle+=p
 middle/=outline.size()
 for i in range(outline.size()):
  var a:=outline[i];var b:=outline[(i+1)%outline.size()]
  var edge:=b-a
  var normal:=Vector2(edge.y,-edge.x).normalized()
  if normal.dot((a+b)*0.5-middle)<0:normal=-normal
  mesh.quad(Vector3(x0,a.y,a.x),Vector3(x1,a.y,a.x),Vector3(x1,b.y,b.x),Vector3(x0,b.y,b.x),color,Vector3(0,normal.y,normal.x))

# A front profile in (x, y) extruded along z0..z1 (the turret).
static func extrude_z(mesh: ColorMesh, outline: PackedVector2Array, z0: float, z1: float, color: Color, origin: Vector3) -> void:
 var triangles:=Geometry2D.triangulate_polygon(outline)
 for k in range(0,triangles.size(),3):
  for z in [z0,z1]:
   var a:=outline[triangles[k]];var b:=outline[triangles[k+1]];var c:=outline[triangles[k+2]]
   mesh.triangle(origin+Vector3(a.x,a.y,z),origin+Vector3(b.x,b.y,z),origin+Vector3(c.x,c.y,z),color.darkened(0.05),Vector3(0,0,signf(z-(z0+z1)*0.5)))
 for i in range(outline.size()):
  var a:=outline[i];var b:=outline[(i+1)%outline.size()]
  var edge:=b-a
  var normal:=Vector2(edge.y,-edge.x).normalized()
  if normal.dot((a+b)*0.5)<0:normal=-normal
  mesh.quad(origin+Vector3(a.x,a.y,z0),origin+Vector3(b.x,b.y,z0),origin+Vector3(b.x,b.y,z1),origin+Vector3(a.x,a.y,z1),color,Vector3(normal.x,normal.y,0))

# Height of the upper glacis over a point along the hull (for parts laid on it).
static func glacis_height(z: float) -> float:
 return lerpf(0.94,ROOF,clampf((z+HALF)/(HALF-1.12),0,1))

static func build() -> Dictionary:
 var root:=Node3D.new();root.name="BmpArt"
 var hull:=solid()
 # Lower hull between the tracks: the steep lower glacis below the nose.
 extrude(hull,PackedVector2Array([Vector2(-HALF,0.94),Vector2(-2.86,0.42),Vector2(3.18,0.42),Vector2(HALF,0.56),Vector2(HALF,FENDER),Vector2(-HALF+0.1,FENDER)]),-1.10,1.10,OLIVE_DARK)
 # Upper hull over the tracks: long upper glacis, roof, sloping rear.
 extrude(hull,PackedVector2Array([Vector2(-HALF,0.94),Vector2(-1.12,ROOF),Vector2(2.9,ROOF-0.04),Vector2(HALF,1.48),Vector2(HALF,FENDER-0.04),Vector2(-HALF+0.02,FENDER-0.04)]),-1.52,1.52,OLIVE)
 # Fender edges and the side skirts over the upper track run.
 for s in [-1.0,1.0]:
  hull.box(at(Vector3(s*1.535,FENDER-0.06,0.05)),Vector3(0.05,0.10,6.5),OLIVE_DARK)
  # Firing ports: three in each side of the troop compartment.
  for z in [0.65,1.45,2.25]:
   hull.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3(s*1.525,1.30,z)),0.075,0.05,8,OLIVE_DARK,BLACK)
   hull.box(at(Vector3(s*1.535,1.42,z)),Vector3(0.03,0.08,0.10),GLASS)
 # Ribs of the upper glacis and the folded trim vane.
 for k in range(5):
  var z:=-3.05+k*0.34
  hull.box(Transform3D(Basis(Vector3.RIGHT,-0.30),Vector3(0,glacis_height(z)+0.03,z)),Vector3(2.7,0.05,0.07),OLIVE_DARK)
 hull.box(Transform3D(Basis(Vector3.RIGHT,-0.30),Vector3(0,glacis_height(-2.55)+0.06,-2.55)),Vector3(2.55,0.04,0.62),OLIVE_LIGHT)
 # Engine louvres front right, exhaust on the right side.
 for k in range(6):
  var z:=-2.35+k*0.14
  hull.box(Transform3D(Basis(Vector3.RIGHT,-0.30),Vector3(0.62,glacis_height(z)+0.025,z)),Vector3(0.95,0.02,0.07),BLACK)
 hull.box(at(Vector3(1.56,1.12,-1.05)),Vector3(0.06,0.22,0.48),BLACK)
 # Headlights and the infrared lamp on the nose.
 for x in [-1.05,1.05]:
  hull.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(x,1.06,-3.08)),0.08,0.12,8,STEEL,Color("d9d6c2"))
 hull.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(-1.05,1.24,-2.95)),0.10,0.14,8,STEEL,Color("2a1414"))
 # Towing eyes and hooks.
 for x in [-0.95,0.95]:
  hull.box(at(Vector3(x,0.72,-3.22)),Vector3(0.10,0.14,0.16),STEEL)
  hull.box(at(Vector3(x,0.66,3.38)),Vector3(0.10,0.14,0.12),STEEL)
 # Driver's hatch with three periscopes in front of it; the troop seat hatch
 # behind it.
 var hatch_y:=glacis_height(DRIVER_HATCH.z)
 for k in range(3):
  hull.box(Transform3D(Basis(Vector3.UP,(k-1)*0.35),Vector3(DRIVER_HATCH.x+(k-1)*0.16,hatch_y+0.05,DRIVER_HATCH.z-0.30)),Vector3(0.13,0.08,0.06),BLACK)
 hull.cylinder(at(Vector3(-0.78,ROOF+0.02,-0.55)),0.30,0.05,12,OLIVE_DARK)
 # Troop compartment: four roof hatches, rear plate.
 for x in [-0.52,0.52]:
  for z in [1.15,2.25]:
   hull.box(at(Vector3(x,ROOF+0.0-z*0.012,z)),Vector3(0.86,0.04,1.0),OLIVE_LIGHT)
   hull.box(at(Vector3(x*1.55,ROOF+0.02-z*0.012,z)),Vector3(0.06,0.05,0.18),STEEL)
 hull.box(at(Vector3(0,0.98,HALF-0.01)),Vector3(0.20,0.92,0.06),OLIVE_DARK)
 # Stowage boxes on the rear fenders.
 for s in [-1.0,1.0]:hull.box(at(Vector3(s*1.32,FENDER+0.16,2.85)),Vector3(0.36,0.32,0.70),OLIVE_DARK)
 node(root,"Hull",hull)
 # Running gear: the tracks are drawn with their runs and pads; road
 # wheels, sprocket and idler turn and the wheels ride on their arms.
 var track:=solid()
 var wheels: Array[MeshInstance3D]=[]
 var drive: Array[MeshInstance3D]=[]
 var wheel_mesh:=road_wheel_mesh()
 for s in [-1.0,1.0]:
  var x:float=s*TRACK_X
  var front:=Vector3(x,SPROCKET.y,SPROCKET.z);var rear:=Vector3(x,IDLER.y,IDLER.z)
  var ground_front:=Vector3(x,0.035,WHEELS_Z[0]-0.15);var ground_rear:=Vector3(x,0.035,WHEELS_Z[-1]+0.15)
  slab(track,ground_front,ground_rear,TRACK_WIDTH,0.07,TRACK_STEEL)
  slab(track,ground_front,front+Vector3(0,-SPROCKET_RADIUS,0),TRACK_WIDTH,0.07,TRACK_STEEL)
  slab(track,ground_rear,rear+Vector3(0,-SPROCKET_RADIUS,0),TRACK_WIDTH,0.07,TRACK_STEEL)
  var top:=SPROCKET_RADIUS+0.035
  var sag:=[front+Vector3(0,top,0)]
  for z in RETURN_Z:sag.append(Vector3(x,0.92+0.04,z))
  sag.append(rear+Vector3(0,top,0))
  for k in range(sag.size()-1):slab(track,sag[k],sag[k+1],TRACK_WIDTH,0.07,TRACK_STEEL)
  for end in [front,rear]:track.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),end),SPROCKET_RADIUS+0.035,TRACK_WIDTH,12,TRACK_STEEL,RUBBER)
  var z:=WHEELS_Z[0]-0.1
  while z<WHEELS_Z[-1]+0.1:
   track.box(at(Vector3(x,0.075,z)),Vector3(TRACK_WIDTH+0.02,0.02,0.05),Color("2a2824"))
   z+=0.17
  for rz in RETURN_Z:track.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3(x-s*0.02,0.86,rz)),0.08,0.16,8,STEEL)
  for wz in WHEELS_Z:
   var wheel:=MeshInstance3D.new();wheel.mesh=wheel_mesh;wheel.position=Vector3(x,WHEEL_RADIUS+0.07,wz)
   root.add_child(wheel);wheels.append(wheel)
  for end in [front,rear]:
   var hub:=solid()
   for k in range(6):
    var a:=TAU*k/6.0
    hub.box(Transform3D(Basis(Vector3.RIGHT,a),Vector3.ZERO)*at(Vector3(0,SPROCKET_RADIUS*0.82,0)),Vector3(TRACK_WIDTH+0.04,0.07,0.09),STEEL)
   hub.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3.ZERO),0.12,TRACK_WIDTH+0.06,8,STEEL)
   drive.append(node(root,"Sprocket" if end==front else "Idler",hub,end))
 node(root,"Tracks",track)
 # Rear doors on their outer hinges.
 var doors: Array[Node3D]=[]
 for s in [-1.0,1.0]:
  var pivot:=Node3D.new();pivot.name="Door"+("L" if s<0 else "R");pivot.position=Vector3(s*DOOR_HINGE_X,0,HALF)
  root.add_child(pivot)
  var door:=solid()
  var middle:=Vector3(-s*DOOR_WIDTH*0.5,(DOOR_BOTTOM+DOOR_TOP)*0.5,0.10)
  door.box(at(middle),Vector3(DOOR_WIDTH,DOOR_TOP-DOOR_BOTTOM,0.20),OLIVE)
  door.box(at(middle+Vector3(0,0,0.12)),Vector3(DOOR_WIDTH-0.12,DOOR_TOP-DOOR_BOTTOM-0.14,0.06),OLIVE_LIGHT)
  door.box(at(middle+Vector3(s*0.22,-0.05,0.17)),Vector3(0.04,0.18,0.05),STEEL)
  if s<0:door.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),middle+Vector3(0.05,0.15,0.16)),0.065,0.04,8,OLIVE_DARK,BLACK)
  for y in [DOOR_BOTTOM+0.15,DOOR_TOP-0.15]:door.cylinder(at(Vector3(0,y,0.03)),0.035,0.14,6,STEEL)
  node(pivot,"Leaf",door)
  doors.append(pivot)
 var hatch_pivot:=Node3D.new();hatch_pivot.name="DriverHatch";hatch_pivot.position=Vector3(DRIVER_HATCH.x+0.30,hatch_y+0.04,DRIVER_HATCH.z)
 root.add_child(hatch_pivot)
 var lid:=solid()
 lid.cylinder(at(Vector3(-0.30,0,0)),0.28,0.05,12,OLIVE_LIGHT)
 lid.box(at(Vector3(-0.30,0.04,0)),Vector3(0.10,0.04,0.30),STEEL)
 node(hatch_pivot,"Lid",lid)
 # Turret: gunner left, commander right; 2A42 with the coaxial PKT on the
 # trunnions; the Konkurs launcher on the roof; smoke dischargers.
 var turret:=Node3D.new();turret.name="Turret";turret.position=TURRET
 root.add_child(turret)
 var shell:=solid()
 shell.cylinder(at(Vector3(0,0.06,0)),0.98,0.12,16,OLIVE_DARK)
 extrude_z(shell,PackedVector2Array([Vector2(-0.98,0.10),Vector2(0.98,0.10),Vector2(0.78,0.55),Vector2(0.62,0.70),Vector2(-0.62,0.70),Vector2(-0.78,0.55)]),-0.70,0.95,OLIVE,Vector3.ZERO)
 # Sloped front plate and the mantlet slot.
 shell.box(Transform3D(Basis(Vector3.RIGHT,0.55),Vector3(0,0.42,-0.86)),Vector3(1.5,0.55,0.08),OLIVE)
 for x in [-0.42,0.42]:
  shell.cylinder(at(Vector3(x,0.74,0.25)),0.28,0.06,12,OLIVE_LIGHT)
  shell.box(at(Vector3(x,0.80,-0.10)),Vector3(0.14,0.10,0.10),BLACK)
 # Commander's periscopes and the gunner's sight head.
 shell.box(at(Vector3(-0.42,0.86,-0.32)),Vector3(0.26,0.22,0.22),OLIVE_DARK)
 shell.box(at(Vector3(-0.42,0.88,-0.44)),Vector3(0.20,0.14,0.02),GLASS)
 for k in range(3):shell.box(at(Vector3(0.20+k*0.20,0.80,-0.22)),Vector3(0.10,0.08,0.05),BLACK)
 # Smoke grenade dischargers on the turret sides.
 for s in [-1.0,1.0]:
  for k in range(3):
   shell.cylinder(Transform3D(Basis(Vector3.RIGHT,0.9),Vector3(s*0.86,0.55,0.20+k*0.17)),0.045,0.26,8,OLIVE_DARK,BLACK)
 # Konkurs launcher on the roof.
 shell.box(at(Vector3(0,0.86,0.10)),Vector3(0.18,0.20,0.18),OLIVE_DARK)
 shell.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,1.02,-0.05)),0.085,1.25,10,OLIVE_LIGHT,BLACK)
 # Aerials.
 shell.cylinder(at(Vector3(0.75,1.70,0.70)),0.008,2.0,4,BLACK)
 node(turret,"Shell",shell)
 var mount:=Node3D.new();mount.name="Gun";mount.position=TRUNNION
 turret.add_child(mount)
 var gun:=solid()
 gun.box(at(Vector3(0,0,-0.10)),Vector3(0.30,0.24,0.36),OLIVE_DARK)
 gun.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.28-BARREL*0.5)),0.034,BARREL,8,STEEL)
 gun.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.30-BARREL+0.10)),0.048,0.22,8,STEEL,BLACK)
 gun.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.50)),0.060,0.45,8,OLIVE_DARK)
 gun.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0.20,-0.03,-0.55)),0.016,0.60,6,STEEL,BLACK)
 node(mount,"Barrel",gun)
 var muzzle:=Marker3D.new();muzzle.name="Muzzle";muzzle.position=Vector3(0,0,-0.32-BARREL);mount.add_child(muzzle)
 var coax:=Marker3D.new();coax.name="Coax";coax.position=Vector3(0.20,-0.03,-0.86);mount.add_child(coax)
 # Interior seen from the driver's seat: the dark compartment, the yoke
 # (штурвал), the gear lever and the instrument panel.
 var inside:=solid()
 inside.box(at(Vector3(-0.78,1.02,-1.72)),Vector3(0.62,0.30,0.20),Color("2c2f25"))
 for k in range(4):inside.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(-0.98+k*0.13,1.10,-1.616)),0.035,0.01,10,BLACK,Color("cfc9a8"))
 var yoke:=Node3D.new();yoke.name="Yoke";yoke.position=Vector3(-0.78,1.05,-1.58)
 root.add_child(yoke)
 var bar:=solid()
 bar.box(at(Vector3(0,0,0)),Vector3(0.46,0.04,0.04),BLACK)
 for x in [-0.23,0.23]:bar.box(at(Vector3(x,0.06,0)),Vector3(0.05,0.14,0.05),RUBBER)
 bar.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.10)),0.025,0.20,6,STEEL)
 node(yoke,"Bar",bar)
 inside.box(at(Vector3(-0.42,0.80,-1.38)),Vector3(0.03,0.36,0.03),STEEL)
 inside.box(at(Vector3(-0.42,0.99,-1.38)),Vector3(0.06,0.06,0.06),BLACK)
 inside.box(at(RADIO),Vector3(0.10,0.18,0.24),Color("1b1c18"))
 inside.box(at(RADIO+Vector3(0.051,0.04,0)),Vector3(0.004,0.04,0.12),Color("4a4b44"))
 node(root,"Inside",inside)
 return {"root":root,"wheels":wheels,"drive":drive,"turret":turret,"gun":mount,"doors":doors,"hatch":hatch_pivot,"yoke":yoke,"muzzle":muzzle,"coax":coax}

# A plate between two points across the track width (track runs).
static func slab(mesh: ColorMesh, a: Vector3, b: Vector3, width: float, thick: float, color: Color) -> void:
 var along:=b-a
 if along.length()<0.01:return
 var forward:=along.normalized()
 var side:=Vector3.RIGHT
 var up:=forward.cross(side).normalized()
 if up.y<0:up=-up
 var basis:=Basis(side,up,-forward)
 mesh.box(Transform3D(basis.orthonormalized(),(a+b)*0.5),Vector3(width,thick,along.length()),color)

static func road_wheel_mesh() -> ArrayMesh:
 var mesh:=solid()
 mesh.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3.ZERO),WHEEL_RADIUS,0.24,14,RUBBER)
 mesh.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3.ZERO),WHEEL_RADIUS*0.78,0.27,12,OLIVE_DARK)
 for k in range(4):
  var a:=TAU*k/4.0
  mesh.box(Transform3D(Basis(Vector3.RIGHT,a),Vector3.ZERO)*at(Vector3(0,WHEEL_RADIUS*0.45,0)),Vector3(0.29,0.06,0.05),OLIVE)
 mesh.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3.ZERO),0.07,0.30,8,STEEL)
 return mesh.build(material())
