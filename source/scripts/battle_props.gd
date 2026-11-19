class_name BattleProps
extends RefCounted

# War-damaged scenery for the large assault: burnt-out armour and trucks,
# sandbag emplacements, gabion walls, anti-tank hedgehogs and shell craters.
# Visible pieces are batched boxes and instanced details. Each object has a
# few matching colliders: hull armour stops rifle fire, sandbags are earth.
const SOOT := "2a2723"
const CHAR := "38322c"
const RUST := "654832"
const RUST_DARK := "4d3829"
const OLIVE := "4f5541"
const OLIVE_BURNT := "47493b"
const TRACK := "1f1d1a"
const RUBBER := "1c1b19"
const RIM := "514c44"
const BAGS := ["9b8e6a","8e8262","a59873"]
const GABION := ["a0937a","978b70","a69a80"]
const EARTH := ["5b4d3c","675843","51463a"]

var world: District
var origin := Vector3.ZERO
var basis := Basis.IDENTITY
var rng := RandomNumberGenerator.new()

func _init(owner: District, seed_value: int) -> void:
 world=owner
 rng.seed=seed_value

func place(point: Vector2, yaw: float) -> void:
 origin=Vector3(point.x,world.ground_height(Vector3(point.x,0,point.y))-0.04,point.y)
 basis=Basis(Vector3.UP,yaw)

# Visible box in the world batches, oriented with the current object.
func block(local: Vector3, size: Vector3, color: String, rot: Vector3=Vector3.ZERO) -> void:
 var position := origin+basis*local
 world.box(position,size,Color(color))
 var key := Color(color).to_html()+"|"+world.cell_key(position)
 var batch: Dictionary=world.batches[key]
 batch.transforms[batch.transforms.size()-1]=Transform3D((basis*Basis.from_euler(rot)).scaled_local(size),position)

# Collision volume; it also blocks navigation like any other static body.
func solid(local: Vector3, size: Vector3, substance: String, color: String, rot: Vector3=Vector3.ZERO) -> DestructibleSurface:
 var body := world.collider(origin+basis*local,size,substance) as DestructibleSurface
 body.basis=basis*Basis.from_euler(rot)
 body.tint=Color(color)
 body.set_meta("surface_color",Color(color))
 body.set_meta("indestructible",true)
 return body

func deco(shape: String, local: Vector3, size: Vector3, color: String, rot: Vector3=Vector3.ZERO) -> void:
 world.detail(shape,origin+basis*local,size,color,(basis*Basis.from_euler(rot)).get_euler())

func wheel(local: Vector3, radius: float, width: float, color: String) -> void:
 deco("drum",local,Vector3(radius,width,radius),color,Vector3(0,0,PI/2))

func rod(a: Vector3, b: Vector3, radius: float, color: String) -> void:
 world.rod(origin+basis*a,origin+basis*b,radius,color)

func debris(radius: float, count: int) -> void:
 for i in range(count):
  var angle := rng.randf()*TAU
  var r := radius*sqrt(rng.randf())
  var size := Vector3(rng.randf_range(0.1,0.45),rng.randf_range(0.03,0.09),rng.randf_range(0.1,0.35))
  deco("box",Vector3(cos(angle)*r,size.y*0.5,sin(angle)*r),size,[SOOT,RUST_DARK,CHAR][i%3],Vector3(0,rng.randf()*TAU,0))

func tracks(length: float, x: float, wheels: int, radius: float) -> void:
 for side in [-1,1]:
  var sx: float=side*x
  block(Vector3(sx,radius*2+0.06,0),Vector3(0.46,0.07,length-0.7),TRACK)
  block(Vector3(sx,0.04,0),Vector3(0.46,0.07,length-1.5),TRACK)
  for end in [-1,1]:
   block(Vector3(sx,radius+0.06,end*(length/2-0.45)),Vector3(0.46,0.07,0.95),TRACK,Vector3(end*0.95,0,0))
   wheel(Vector3(sx,radius+0.1,end*(length/2-0.4)),0.27,0.42,TRACK)
  for i in range(wheels):
   wheel(Vector3(sx,radius,-(length-1.9)/2+i*(length-1.9)/(wheels-1)),radius,0.36,CHAR)

# BMP-type infantry fighting vehicle, burnt out with the turret traversed.
func ifv(point: Vector2, yaw: float, turret: float) -> void:
 place(point,yaw)
 tracks(6.6,1.32,6,0.33)
 block(Vector3(0,0.98,0.25),Vector3(2.5,0.72,5.9),RUST_DARK)
 block(Vector3(0,0.98,-3.0),Vector3(2.5,0.08,1.6),CHAR,Vector3(0.62,0,0))
 block(Vector3(0,1.40,0.55),Vector3(3.0,0.10,5.0),CHAR)
 for side in [-1,1]:
  block(Vector3(side*1.5,1.12,0.3),Vector3(0.06,0.45,6.0),OLIVE_BURNT)
  block(Vector3(side*0.55,1.0,3.24),Vector3(0.78,0.82,0.08),OLIVE)
 block(Vector3(0.5,1.46,1.6),Vector3(1.1,0.02,1.6),SOOT)
 var mount := Vector3(0,1.72,-0.35)
 var aim := Basis(Vector3.UP,turret)
 block(mount,Vector3(1.55,0.5,1.6),SOOT,Vector3(0,turret,0))
 block(mount+aim*Vector3(0,0.02,-0.95),Vector3(1.2,0.36,0.4),CHAR,Vector3(-0.5,turret,0))
 rod(mount+aim*Vector3(0,0.05,-1.0),mount+aim*Vector3(0,-0.12,-3.4),0.05,SOOT)
 # A hatch blown open on the roof.
 block(Vector3(-0.5,1.62,1.2),Vector3(0.6,0.05,0.6),OLIVE_BURNT,Vector3(-1.1,0,0))
 solid(Vector3(0,0.8,0),Vector3(3.0,1.5,6.6),"steel",RUST_DARK)
 solid(mount,Vector3(1.55,0.5,1.6),"steel",SOOT,Vector3(0,turret,0))
 debris(5.0,18)

# Main battle tank whose turret was thrown off by an ammunition fire.
func tank(point: Vector2, yaw: float) -> void:
 place(point,yaw)
 tracks(6.9,1.55,6,0.38)
 block(Vector3(0,1.0,0.25),Vector3(2.9,0.76,6.2),CHAR)
 block(Vector3(0,1.02,-3.05),Vector3(2.9,0.09,1.35),SOOT,Vector3(0.95,0,0))
 block(Vector3(0,1.42,0.2),Vector3(3.5,0.08,6.4),RUST_DARK)
 deco("drum",Vector3(0,1.47,-0.3),Vector3(0.95,0.04,0.95),"141210")
 for side in [-1,1]:deco("drum",Vector3(side*0.75,1.68,3.1),Vector3(0.3,1.1,0.3),RUST,Vector3(0,0,PI/2))
 var lying := Vector3(3.3,0.55,-1.4)
 var spin := Vector3(PI*0.93,0.7,0.12)
 var thrown := Basis.from_euler(spin)
 block(lying,Vector3(2.2,0.72,2.5),SOOT,spin)
 block(lying+thrown*Vector3(0,0.05,-1.2),Vector3(1.7,0.5,0.6),CHAR,spin)
 rod(lying+thrown*Vector3(0,0.1,-1.3),lying+thrown*Vector3(0,0.1,-1.3)+Basis(Vector3.UP,0.9)*Vector3(0,0.35,-4.4),0.08,SOOT)
 solid(Vector3(0,0.78,0),Vector3(3.5,1.46,6.9),"steel",CHAR)
 solid(lying,Vector3(2.2,0.72,2.5),"steel",SOOT,spin)
 debris(6.0,24)

# Eight-wheeled armoured personnel carrier, tyres burnt down to the rims.
func apc(point: Vector2, yaw: float) -> void:
 place(point,yaw)
 for side in [-1,1]:
  for z in [-2.55,-1.15,0.75,2.15]:
   wheel(Vector3(side*1.28,0.5,z),0.5,0.36,RUBBER)
   wheel(Vector3(side*1.47,0.5,z),0.3,0.04,RIM)
  block(Vector3(side*1.18,1.82,0.3),Vector3(0.08,0.62,5.9),OLIVE_BURNT,Vector3(0,0,side*0.38))
 block(Vector3(0,1.17,0.1),Vector3(2.5,0.9,6.5),OLIVE_BURNT)
 block(Vector3(0,0.98,-3.4),Vector3(2.3,0.08,1.0),CHAR,Vector3(-0.75,0,0))
 block(Vector3(0,1.62,-3.15),Vector3(2.3,0.08,1.1),CHAR,Vector3(0.45,0,0))
 block(Vector3(0,2.08,0.3),Vector3(1.95,0.08,5.8),CHAR)
 block(Vector3(0.35,2.13,0.9),Vector3(1.1,0.02,2.2),SOOT)
 block(Vector3(0,2.36,-1.1),Vector3(0.95,0.45,0.95),SOOT,Vector3(0,0.4,0))
 rod(Vector3(0,2.42,-1.1)+Basis(Vector3.UP,0.4)*Vector3(0,0,-0.45),Vector3(0,2.42,-1.1)+Basis(Vector3.UP,0.4)*Vector3(0,0.2,-2.0),0.04,SOOT)
 solid(Vector3(0,1.3,0),Vector3(2.9,1.7,7.2),"steel",OLIVE_BURNT)
 debris(5.0,16)

# Army truck with a burnt cargo bed: the cab and engine stop fire, the boards do not.
func truck(point: Vector2, yaw: float) -> void:
 place(point,yaw)
 for side in [-1,1]:
  for z in [-2.75,1.1,2.45]:
   wheel(Vector3(side*1.0,0.55,z),0.55,0.4,RUBBER)
   wheel(Vector3(side*1.21,0.55,z),0.3,0.04,RIM)
  block(Vector3(side*1.0,1.3,-2.75),Vector3(0.48,0.08,1.1),RUST_DARK)
  block(Vector3(side*1.16,2.15,-2.15),Vector3(0.03,0.45,0.9),SOOT)
  for i in range(3):
   if (i+int(side>0))%3==1:continue
   block(Vector3(side*1.18,1.72,-0.3+i*1.5),Vector3(0.06,0.72,1.2),"4a3a2c")
 block(Vector3(0,0.95,0.2),Vector3(0.95,0.22,6.6),SOOT)
 block(Vector3(0,1.35,-3.35),Vector3(1.7,0.75,1.2),RUST,Vector3(0.12,0,0))
 block(Vector3(0,0.95,-4.0),Vector3(2.3,0.25,0.2),SOOT)
 block(Vector3(0,1.85,-2.15),Vector3(2.3,1.25,1.5),RUST_DARK)
 block(Vector3(0,2.15,-2.91),Vector3(1.9,0.5,0.03),SOOT)
 block(Vector3(0,1.32,1.2),Vector3(2.4,0.1,4.2),"3d3027")
 block(Vector3(0,1.72,-0.9),Vector3(2.4,0.72,0.06),"4a3a2c")
 for z in [-0.6,0.8,2.2]:
  for side in [-1,1]:rod(Vector3(side*1.15,1.7,z),Vector3(side*1.1,2.6,z),0.025,SOOT)
  rod(Vector3(-1.1,2.6,z),Vector3(1.1,2.6,z),0.025,SOOT)
 solid(Vector3(0,1.5,-2.9),Vector3(2.3,1.9,2.4),"steel",RUST_DARK)
 solid(Vector3(0,1.0,1.2),Vector3(2.4,0.75,4.2),"steel",SOOT)
 for side in [-1,1]:solid(Vector3(side*1.18,1.72,1.2),Vector3(0.06,0.72,4.2),"wood","4a3a2c")
 debris(4.5,14)

# Curved sandbag emplacement opening towards +Z; six layers, about 1.25 m.
func sandbags(point: Vector2, yaw: float, radius: float=1.9, arc: float=2.2) -> void:
 place(point,yaw)
 for layer in range(6):
  var r := radius-layer*0.035
  var count := int(arc*r/0.56)
  for i in range(count+1):
   var a := -arc/2+(i+(0.5 if layer%2==1 else 0.0))*arc/count
   if a>arc/2+0.01:continue
   deco("sphere",Vector3(sin(a)*r,0.11+layer*0.205,-cos(a)*r),Vector3(0.30,0.115,0.17),BAGS[(i+layer)%3],Vector3(rng.randf_range(-0.06,0.06),-a,rng.randf_range(-0.05,0.05)))
 var segments := 5
 for s in range(segments):
  var a := -arc/2+(s+0.5)*arc/segments
  solid(Vector3(sin(a)*radius,0.62,-cos(a)*radius),Vector3(arc*radius/segments+0.12,1.24,0.42),"earth",BAGS[0],Vector3(0,-a,0))

# Earth-filled wire-mesh gabions, two cells high.
func gabions(point: Vector2, yaw: float, cells: int, rows: int=2) -> void:
 place(point,yaw)
 var width := cells*1.06
 for row in range(rows):
  for i in range(cells):block(Vector3(-width/2+(i+0.5)*1.06,0.53+row*1.06,0),Vector3(1.02,1.04,1.02),GABION[(i+row)%3])
 for face in [-0.53,0.53]:
  for i in range(cells+1):rod(Vector3(-width/2+i*1.06,0,face),Vector3(-width/2+i*1.06,rows*1.06,face),0.018,"57554e")
  for row in range(1,rows+1):rod(Vector3(-width/2,row*1.06,face),Vector3(width/2,row*1.06,face),0.016,"57554e")
 solid(Vector3(0,rows*0.53,0),Vector3(width,rows*1.06,1.06),"earth",GABION[0])

# Three welded beams crossing at the centre: an anti-tank obstacle that
# offers little more than partial concealment.
func hedgehogs(point: Vector2, yaw: float, count: int=3) -> void:
 var tilt := Basis(Quaternion(Vector3(1,1,1).normalized(),Vector3.UP))
 for i in range(count):
  place(point+Vector2(i*2.6-(count-1)*1.3,rng.randf_range(-0.8,0.8)).rotated(-yaw),yaw+rng.randf_range(-0.6,0.6))
  var center := Vector3(0,0.56,0)
  for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
   var beam: Vector3=tilt*axis*0.97
   rod(center-beam,center+beam,0.065,RUST)
  solid(center,Vector3(0.7,1.1,0.7),"steel",RUST)

# Shell crater: scorched floor and a broken rim of thrown-up soil (visual).
func crater(point: Vector2, radius: float) -> void:
 place(point,rng.randf()*TAU)
 deco("drum",Vector3(0,0.015,0),Vector3(radius*1.25,0.02,radius*1.25),"4a4337")
 deco("drum",Vector3(0,0.025,0),Vector3(radius*0.8,0.02,radius*0.8),"2b2722")
 for i in range(12):
  var angle := i*TAU/12+rng.randf_range(-0.15,0.15)
  var size := Vector3(radius*0.42,radius*0.14,radius*0.28)*rng.randf_range(0.8,1.2)
  deco("sphere",Vector3(cos(angle),0,sin(angle))*radius,size,EARTH[i%3],Vector3(0,-angle+PI/2,0))
 for i in range(10):
  var angle := rng.randf()*TAU
  var r := radius*rng.randf_range(1.1,1.9)
  deco("box",Vector3(cos(angle)*r,0.04,sin(angle)*r),Vector3.ONE*rng.randf_range(0.08,0.2),EARTH[i%3],Vector3(rng.randf(),rng.randf()*TAU,0))
