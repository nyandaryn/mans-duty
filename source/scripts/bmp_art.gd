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
# Driver's eyes in the seat lowered under the shut hatch, and with the head
# out. The commander's eyes in his seat, in turret coordinates.
const DRIVER_EYE := Vector3(-0.78,1.33,-1.24)
const DRIVER_HEAD_OUT := Vector3(-0.78,2.02,-1.22)
const COMMANDER_EYE := Vector3(0.42,0.48,0.12)
# The troop compartment: the seats along the benches from the rear (their
# firing ports in the sides), the eyes of the passenger in the right row,
# middle seat, and the roof hatch over him (hinge on its outer edge).
const TROOP_Z := [2.35,1.62,0.89]
const TROOP_EYE := Vector3(0.62,1.42,1.62)
const TROOP_HATCH := Vector3(0.52,1.606,1.15)
# Visual layer of the compartments: only the seat camera draws them.
const INTERIOR_LAYER := 16
const GUNNER_EYE := Vector3(-0.42,2.30,-0.55)
# Rear doors: hinges on the outer edges, the doors are the fuel tanks.
const DOOR_HINGE_X := 0.90
const DOOR_WIDTH := 0.78
const DOOR_BOTTOM := 0.50
const DOOR_TOP := 1.42
# Where the troops step down behind the open doors, and the receiver
# beside the driver.
const EXITS := [Vector3(-0.75,0,4.25),Vector3(0.75,0,4.25)]
const RADIO := Vector3(-1.38,1.24,-1.02)
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

# --- Vision devices -------------------------------------------------------------
# A periscope shows the world as an eye `rise` higher and `reach` further
# along its line of sight would see it through a window there. Each device:
# the eyepiece window inside (centre, yaw, size) on an arc in front of the
# seated eyes, and the head window outside on the roof.
static func device(eye: Vector3, yaw: float, distance: float, drop: float, size: Vector2, rise: float, reach: float, kind: String, title: String) -> Dictionary:
 var turn:=Basis(Vector3.UP,yaw)
 var glass:=eye+turn*Vector3(0,-drop,-distance)
 var lift:=Vector3.UP*rise+turn*Vector3(0,0,-reach)
 return {"kind":kind,"title":title,"yaw":yaw,"glass":glass,"size":size,"lift":lift,"head":glass+lift}

# The driver's three TNPO-170A in front of the hatch, left to right.
static func driver_devices() -> Array:
 var list:=[]
 for k in [-1,0,1]:list.append(device(DRIVER_EYE,-k*0.68,0.30,0.02,Vector2(0.14,0.045),0.23,0.08,"prism","ТНПО-170А"))
 return list

# The commander's TKN-3B in the front of his hatch ring between two
# TNPO-170A (turret coordinates).
static func commander_devices() -> Array:
 return [device(COMMANDER_EYE,0.95,0.23,0.02,Vector2(0.12,0.04),0.27,0.05,"prism","ТНПО-170А"),
  device(COMMANDER_EYE,0.0,0.24,0.01,Vector2(0.20,0.06),0.30,0.08,"tkn","ТКН-3Б"),
  device(COMMANDER_EYE,-0.95,0.23,0.02,Vector2(0.12,0.04),0.27,0.05,"prism","ТНПО-170А")]

# The TNPO-170A over a firing port of the troop compartment, side `s`, seat
# at `z`: the eyepiece high on the side wall, the head outside over the port.
static func troop_device(s: float, z: float) -> Dictionary:
 var eye:=Vector3(s*TROOP_EYE.x,TROOP_EYE.y,z)
 return device(eye,-PI/2 if s>0.0 else PI/2,0.78,0.02,Vector2(0.14,0.045),0.04,0.16,"prism","ТНПО-170А")

# The head of a device on the roof: a block behind its window, the glass
# flush with the window, a base down to the armour.
static func device_head(mesh: ColorMesh, item: Dictionary) -> void:
 var turn:=Basis(Vector3.UP,float(item.yaw))
 var head: Vector3=item.head
 var size: Vector2=item.size
 var deep:=0.16 if item.kind=="tkn" else 0.07
 var block:=Vector3(size.x+0.03,size.y+0.03,deep)
 mesh.box(Transform3D(turn,head+turn*Vector3(0,0,deep*0.5)),block,OLIVE_DARK)
 mesh.box(Transform3D(turn,head+turn*Vector3(0,-block.y*0.5-0.03,deep*0.5)),Vector3(block.x-0.02,0.06,deep-0.01),OLIVE_DARK)
 mesh.box(Transform3D(turn,head+turn*Vector3(0,0,0.002)),Vector3(size.x,size.y,0.004),GLASS)
 # The brow over the window keeps off the rain and the glare.
 mesh.box(Transform3D(turn,head+turn*Vector3(0,block.y*0.5+0.006,-0.012)),Vector3(block.x,0.012,0.03),OLIVE_DARK)

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
  # Firing ports: three in each side of the troop compartment, a prism
  # head over each.
  for z in TROOP_Z:
   hull.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3(s*1.525,1.24,z)),0.075,0.05,8,OLIVE_DARK,BLACK)
   hull.box(at(Vector3(s*1.535,1.46,z)),Vector3(0.03,0.07,0.16),GLASS)
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
 for item in driver_devices():device_head(hull,item)
 hull.cylinder(at(Vector3(-0.78,ROOF+0.02,-0.55)),0.30,0.05,12,OLIVE_DARK)
 # Troop compartment: four roof hatches, rear plate.
 for x in [-0.52,0.52]:
  for z in [1.15,2.25]:
   hull.box(at(Vector3(x*1.55,ROOF+0.02-z*0.012,z)),Vector3(0.06,0.05,0.18),STEEL)
   if x>0.0 and z<2.0:continue
   hull.box(at(Vector3(x,ROOF+0.0-z*0.012,z)),Vector3(0.86,0.04,1.0),OLIVE_LIGHT)
 hull.box(at(Vector3(0,0.98,HALF-0.01)),Vector3(0.20,0.92,0.06),OLIVE_DARK)
 # The doorways behind the doors: dark inside, seen only from behind.
 for s in [-1.0,1.0]:
  var x0:float=s*(DOOR_HINGE_X-DOOR_WIDTH);var x1:float=s*DOOR_HINGE_X
  hull.quad(Vector3(x0,DOOR_BOTTOM,HALF+0.004),Vector3(x1,DOOR_BOTTOM,HALF+0.004),Vector3(x1,DOOR_TOP,HALF+0.004),Vector3(x0,DOOR_TOP,HALF+0.004),Color("15170f"),Vector3.BACK)
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
 # The roof hatch over the passenger's seat opens on its outer hinge.
 var troop_hatch:=Node3D.new();troop_hatch.name="TroopHatch";troop_hatch.position=TROOP_HATCH+Vector3(0.43,0,0)
 root.add_child(troop_hatch)
 var leaf:=solid()
 leaf.box(at(Vector3(-0.43,0,0)),Vector3(0.86,0.04,1.0),OLIVE_LIGHT)
 leaf.box(at(Vector3(-0.43,0.03,0)),Vector3(0.10,0.03,0.40),STEEL)
 node(troop_hatch,"Leaf",leaf)
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
 # The gunner's sight head; the commander's TKN-3B and periscopes.
 shell.box(at(Vector3(-0.42,0.86,-0.32)),Vector3(0.26,0.22,0.22),OLIVE_DARK)
 shell.box(at(Vector3(-0.42,0.88,-0.44)),Vector3(0.20,0.14,0.02),GLASS)
 for item in commander_devices():device_head(shell,item)
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
 return {"root":root,"wheels":wheels,"drive":drive,"turret":turret,"gun":mount,"doors":doors,"hatch":hatch_pivot,"troop_hatch":troop_hatch,"muzzle":muzzle,"coax":coax}

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
