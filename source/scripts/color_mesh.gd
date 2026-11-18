class_name ColorMesh
extends RefCounted

# Static scenery merged into one vertex-coloured mesh: a whole street block of
# houses and fences in a single draw call instead of one per colour.
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
# Vehicles are seen from below too (from a ditch, from the side at a low
# angle, when one tips): their boxes keep the bottom face.
var closed := false

func arrays() -> Array:
 return [vertices,normals,colors,indices]

func is_empty() -> bool:
 return indices.is_empty()

# A face a-b-d-e seen from the side `facing` points to.
func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, color: Color, facing: Vector3) -> void:
 var normal:=-(d-a).cross(e-b).normalized()
 if normal.dot(facing)<0:
  var swap:=b;b=e;e=swap;normal=-normal
 var base:=vertices.size()
 for p in [a,b,d,e]:
  vertices.append(p);normals.append(normal);colors.append(color)
 indices.append_array([base,base+1,base+2,base,base+2,base+3])

func triangle(a: Vector3, b: Vector3, d: Vector3, color: Color, facing: Vector3) -> void:
 var normal:=-(b-a).cross(d-a).normalized()
 if normal.dot(facing)<0:
  var swap:=b;b=d;d=swap;normal=-normal
 var base:=vertices.size()
 for p in [a,b,d]:
  vertices.append(p);normals.append(normal);colors.append(color)
 indices.append_array([base,base+1,base+2])

# Box of `size` centred at `transform` (its basis may rotate it); the bottom
# face is left out unless `bottom` or `closed`: nobody sees it on scenery.
func box(transform: Transform3D, size: Vector3, color: Color, bottom: bool=false) -> void:
 var h:=size*0.5
 var b:=transform.basis;var o:=transform.origin
 var corner:=func(x: float, y: float, z: float) -> Vector3:return o+b*Vector3(x*h.x,y*h.y,z*h.z)
 var faces:=[[Vector3.RIGHT,[1,-1,-1],[1,-1,1],[1,1,1],[1,1,-1]],[Vector3.LEFT,[-1,-1,-1],[-1,-1,1],[-1,1,1],[-1,1,-1]],
  [Vector3.UP,[-1,1,-1],[1,1,-1],[1,1,1],[-1,1,1]],[Vector3.BACK,[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]],[Vector3.FORWARD,[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1]]]
 if bottom or closed:faces.append([Vector3.DOWN,[-1,-1,-1],[1,-1,-1],[1,-1,1],[-1,-1,1]])
 for face in faces:
  var p: Array=[]
  for k in range(1,5):p.append(corner.call(float(face[k][0]),float(face[k][1]),float(face[k][2])))
  quad(p[0],p[1],p[2],p[3],color,b*Vector3(face[0]))

# Gable roof like a PrismMesh of `size`: base `size.x` wide, apex at the top,
# ridge along the local Z axis.
func prism(transform: Transform3D, size: Vector3, color: Color, gable_color: Color) -> void:
 var h:=size*0.5
 var b:=transform.basis;var o:=transform.origin
 var l0:=o+b*Vector3(-h.x,-h.y,-h.z);var r0:=o+b*Vector3(h.x,-h.y,-h.z)
 var l1:=o+b*Vector3(-h.x,-h.y,h.z);var r1:=o+b*Vector3(h.x,-h.y,h.z)
 var t0:=o+b*Vector3(0,h.y,-h.z);var t1:=o+b*Vector3(0,h.y,h.z)
 quad(l0,l1,t1,t0,color,b*Vector3(-h.y,h.x,0))
 quad(r0,r1,t1,t0,color.darkened(0.08),b*Vector3(h.y,h.x,0))
 triangle(l0,r0,t0,gable_color,b*Vector3.FORWARD)
 triangle(l1,r1,t1,gable_color,b*Vector3.BACK)

# Cylinder along the local Y axis of `transform`, centred on its origin.
func cylinder(transform: Transform3D, radius: float, length: float, sides: int, color: Color, cap_color: Color=Color(0,0,0,0), caps: bool=true) -> void:
 var b:=transform.basis;var o:=transform.origin
 var top:=o+b*Vector3(0,length*0.5,0);var bottom:=o-b*Vector3(0,length*0.5,0)
 var cap:=color if cap_color.a==0 else cap_color
 for i in range(sides):
  var a0:=TAU*i/sides;var a1:=TAU*(i+1)/sides
  var r0:=b*Vector3(cos(a0)*radius,0,sin(a0)*radius);var r1:=b*Vector3(cos(a1)*radius,0,sin(a1)*radius)
  var mid:=(r0+r1).normalized()
  quad(bottom+r0,bottom+r1,top+r1,top+r0,color,mid)
  if caps:
   triangle(top,top+r0,top+r1,cap,b*Vector3.UP)
   triangle(bottom,bottom+r0,bottom+r1,cap,b*Vector3.DOWN)

# Tube: an open cylinder with an inner wall, seen from both ends.
func pipe(transform: Transform3D, outer: float, inner: float, length: float, sides: int, color: Color, bore: Color) -> void:
 var b:=transform.basis;var o:=transform.origin
 var h:=b*Vector3(0,length*0.5,0)
 for i in range(sides):
  var a0:=TAU*i/sides;var a1:=TAU*(i+1)/sides
  var d0:=b*Vector3(cos(a0),0,sin(a0));var d1:=b*Vector3(cos(a1),0,sin(a1))
  var mid:=(d0+d1).normalized()
  quad(o-h+d0*outer,o-h+d1*outer,o+h+d1*outer,o+h+d0*outer,color,mid)
  quad(o-h+d0*inner,o-h+d1*inner,o+h+d1*inner,o+h+d0*inner,bore,-mid)
  for end in [-1.0,1.0]:
   quad(o+h*end+d0*inner,o+h*end+d1*inner,o+h*end+d1*outer,o+h*end+d0*outer,color,b*Vector3.UP*end)

func build(material: Material) -> ArrayMesh:
 return OperationArea.mesh_from(vertices,normals,colors,indices,material)

# Material for merged scenery: vertex colours with the plaster grain.
static func material(world: District) -> StandardMaterial3D:
 var base:=world.material(Color.WHITE)
 var mat:=base.duplicate() as StandardMaterial3D
 mat.vertex_color_use_as_albedo=true
 mat.vertex_color_is_srgb=true
 return mat
