class_name VehicleMarkings
extends RefCounted

# Identification marks painted on the vehicles. The Russian side: the white
# «Z» on the hull sides and on the folded trim vane of the glacis, the
# tricolour on the turret sides. Ours: the Ukrainian flag on the turret and
# the hull sides of a BMP and on the cab doors of a BM-21. Hand-painted,
# a little dulled by dust; a few millimetres off the surface they are on.
const WHITE := Color("e4e2d6")
const RUSSIA := [Color("e8e7e0"),Color("244193"),Color("b52b27")]
const UKRAINE := [Color("2a5aa8"),Color("e8c21c")]
const PAINT := 0.004

static func apply(vehicle: Node3D, friendly: bool) -> void:
 if vehicle is BmpVehicle:bmp(vehicle.art,friendly)
 elif vehicle is GradVehicle:grad(vehicle.art)

# A frame on a surface: x to the right and y up as a man in front of it
# sees them, z out of the surface.
static func frame(origin: Vector3, right: Vector3, up: Vector3) -> Transform3D:
 var x:=right.normalized()
 var y:=up.normalized()
 var z:=x.cross(y).normalized()
 return Transform3D(Basis(x,y,z),origin+z*PAINT)

static func stroke(mesh: ColorMesh, at: Transform3D, center: Vector2, length: float, width: float, angle: float, color: Color) -> void:
 mesh.box(at*Transform3D(Basis(Vector3.BACK,angle),Vector3(center.x,center.y,0)),Vector3(length,width,PAINT),color)

# The letter: two bars and the diagonal from the top right to the bottom
# left, brush-wide strokes.
static func letter_z(mesh: ColorMesh, at: Transform3D, height: float, color: Color) -> void:
 var w:=height*0.78
 var t:=height*0.15
 stroke(mesh,at,Vector2(0,(height-t)*0.5),w,t,0.0,color)
 stroke(mesh,at,Vector2(0,-(height-t)*0.5),w,t,0.0,color)
 var run:=Vector2(w-t,height-t*2.0)
 stroke(mesh,at,Vector2.ZERO,run.length()+t*0.5,t,run.angle(),color)

# A flag of horizontal bands, 2:3.
static func flag(mesh: ColorMesh, at: Transform3D, width: float, bands: Array) -> void:
 var height:=width*2.0/3.0
 var band:=height/bands.size()
 for i in range(bands.size()):
  mesh.box(at*Transform3D(Basis.IDENTITY,Vector3(0,height*0.5-band*(i+0.5),0)),Vector3(width,band,PAINT),bands[i])

static func bmp(art: Dictionary, friendly: bool) -> void:
 var hull:=ColorMesh.new()
 var turret:=ColorMesh.new()
 for s in [-1.0,1.0]:
  # Turret side: the plate leans in from (0.98, 0.10) to (0.78, 0.55).
  var up:=Vector3(-s*0.20,0.45,0)
  var on_turret:=frame(Vector3(s*0.88,0.33,-0.15),Vector3(0,0,-s),up)
  # Hull side between the exhaust and the firing ports.
  var on_side:=frame(Vector3(s*1.52,1.27,0.02),Vector3(0,0,-s),Vector3.UP)
  if friendly:
   flag(turret,on_turret,0.36,UKRAINE)
   flag(hull,on_side,0.42,UKRAINE)
  else:
   flag(turret,on_turret,0.36,RUSSIA)
   letter_z(hull,on_side,0.46,WHITE)
 if not friendly:
  # On the folded trim vane, seen from ahead.
  var slope:=Vector3(0,sin(0.30),cos(0.30))
  var vane:=Vector3(-0.62,BmpArt.glacis_height(-2.55)+0.06+0.02,-2.55)
  letter_z(hull,frame(vane,Vector3.LEFT,slope),0.44,WHITE)
 BmpArt.node(art.root,"Markings",hull)
 BmpArt.node(art.turret,"Markings",turret)

static func grad(art: Dictionary) -> void:
 var cab:=ColorMesh.new()
 for s in [-1.0,1.0]:
  flag(cab,frame(Vector3(s*1.136,1.60,-1.42),Vector3(0,0,-s),Vector3.UP),0.36,UKRAINE)
 GradArt.node(art.root,"Markings",cab)
