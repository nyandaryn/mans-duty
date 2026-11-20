class_name BmpInterior
extends Node3D

# The compartments of the BMP-2 as the player sees them from the seats. The
# driver sits low in the front left under his hatch: three TNPO-170A prism
# blocks on an arc in front of his eyes under a rubber brow pad, the
# instrument panel on the left side, the yoke in front, the gear lever on
# the right by the engine bulkhead, the pedals of the main clutch, the brake
# and the fuel. A passenger sits in the troop compartment behind the turret
# basket, in the right row, among his squad (BmpTroops seats them): two
# benches back to back on the fuel tank in the middle, the firing ports and
# their TNPO-170A in the sides, four roof hatches, the two rear doors that
# are fuel tanks too. Look around with the mouse; the right button on a
# prism puts the face to its eyepiece (BmpPeriscope shows the world through
# it). The meshes sit on their own visual layer: only the seat camera draws
# them, lit by the dome lamps and the daylight from the prisms and the open
# doors, not by the sun.
const PAINT := Color("7f8a76")
const PAINT_LOW := Color("626a5a")
const FLOOR := Color("383c33")
const STEEL := Color("3a3f35")
const DARK := Color("22251f")
const RUBBER := Color("131411")
const SEAT := Color("2e2f27")
const OLIVE := Color("4a5236")
const RED := Color("9b2c20")
const BRASS := Color("8d7a45")
const LAMP := Color("ffd9a6")
const DAYLIGHT := Color("d5e2ee")
# The face at the eyepiece: this far from the glass, a little above its
# middle, looking a little down.
const LEAN := 0.075
const PANEL_SIZE := Vector2(0.40,0.1745)
const PANEL_CENTER := Vector3(-1.28,1.05,-1.52)
const YOKE := Vector3(-0.78,0.99,-1.52)
const YOKE_BASE := Vector3(-0.78,0.74,-1.98)
const LEVER := Vector3(-0.40,0.886,-1.30)
var vehicle: BmpVehicle
var driver: Node3D
var troop: Node3D
var door_insides: Array[Node3D]=[]
var hatch_inside: Node3D
var door_light: OmniLight3D
var station := ""
# The prism the face is pressed to (BmpCommand), or -1.
var leaning := -1
var devices := {"driver":BmpArt.driver_devices(),"troop":[BmpArt.troop_device(1.0,float(BmpArt.TROOP_Z[1]))]}
var periscopes := {"driver":[],"troop":[]}
var yoke: Node3D
var pedals: Array[Node3D]=[]
var lever: Node3D
var knob := Vector2(1,1)
var panel_view: SubViewport
var plate: BmpCockpit
var panel_frame: Transform3D

func setup(owner: BmpVehicle) -> void:
 vehicle=owner;name="Interior"
 process_priority=1000
 owner.add_child(self)
 driver=Node3D.new();driver.name="DriverCompartment";owner.add_child(driver)
 troop=Node3D.new();troop.name="TroopCompartment";owner.add_child(troop)
 # The sun does not shine inside the armour.
 var sun: DirectionalLight3D=owner.game.sunlight
 if sun!=null:sun.light_cull_mask=sun.light_cull_mask & ~BmpArt.INTERIOR_LAYER
 build_driver()
 build_troop()
 for part in ["driver","troop"]:
  var list: Array=devices[part]
  for i in range(list.size()):
   var item: Dictionary=list[i]
   if item.kind!="prism":periscopes[part].append(null);continue
   var scope:=BmpPeriscope.new();add_child(scope)
   scope.setup(holder(part),item,i)
   periscopes[part].append(scope)
 set_station("")

func panel_seen(viewer: Camera3D) -> bool:
 var frame:=driver.global_transform*panel_frame
 for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
  if viewer.is_position_in_frustum(frame*Vector3(corner.x*PANEL_SIZE.x*0.5,corner.y*PANEL_SIZE.y*0.5,0)):return true
 return false

func holder(part: String) -> Node3D:return driver if part=="driver" else troop

func eye(part: String) -> Vector3:return BmpArt.DRIVER_EYE if part=="driver" else BmpArt.TROOP_EYE

# The way the seat faces: the driver ahead, the passenger to the right side.
func facing(part: String) -> float:return 0.0 if part=="driver" else -PI/2

func set_station(part: String) -> void:
 station=part
 driver.visible=part=="driver"
 troop.visible=part=="troop"
 for door in door_insides:door.visible=part=="troop"
 hatch_inside.visible=part=="troop"
 panel_view.render_target_update_mode=SubViewport.UPDATE_DISABLED

func _process(delta: float) -> void:
 var viewer:=vehicle.seat_camera if vehicle.seat_camera.current else null
 # Every prism on the screen, every frame: the view outside stays smooth.
 # With the face at an eyepiece only that prism: the others are slivers at
 # the edge of the screen and keep their last picture.
 for part in ["driver","troop"]:
  var list: Array=periscopes[part]
  for i in range(list.size()):
   var scope: BmpPeriscope=list[i]
   if scope!=null:scope.update(viewer,part==station and viewer!=null and (leaning<0 or i==leaning))
 # The day comes in through the open doors.
 if station=="troop":door_light.light_energy=smoothstep(0.0,1.0,vehicle.doors)*1.5
 if station!="driver":return
 # The needles of the panel, only while it is on screen.
 if viewer!=null and panel_seen(viewer):
  plate.queue_redraw()
  panel_view.render_target_update_mode=SubViewport.UPDATE_ONCE
 yoke.basis=Basis.looking_at(YOKE_BASE-YOKE,Vector3.UP)*Basis(Vector3.BACK,-vehicle.yoke*0.6)
 var amounts:=[vehicle.clutch_pedal,vehicle.brake_pedal,vehicle.throttle]
 for i in range(pedals.size()):pedals[i].rotation.x=float(amounts[i])*0.35
 # The lever goes through neutral: across first, then along the slot.
 var slot: Vector2={0:Vector2(0,0),1:Vector2(1,1),2:Vector2(0,2),3:Vector2(1,0),4:Vector2(1,2),5:Vector2(2,0),6:Vector2(2,2)}.get(vehicle.gear,Vector2(1,1))
 if absf(knob.x-slot.x)>0.01 and absf(knob.y-1.0)>0.01:knob.y=move_toward(knob.y,1.0,delta*12.0)
 else:
  knob.x=move_toward(knob.x,slot.x,delta*12.0)
  if absf(knob.x-slot.x)<=0.01:knob.y=move_toward(knob.y,slot.y,delta*12.0)
 lever.rotation=Vector3((knob.y-1.0)*0.22,0,(1.0-knob.x)*0.17)

# --- Where the eyes are -------------------------------------------------------
# The device or the panel the middle of the view rests on.
func pick(viewer: Camera3D) -> Dictionary:
 if station=="" or viewer==null:return {}
 var from:=viewer.global_position
 var along:=-viewer.global_basis.z
 var part:=holder(station)
 var list: Array=devices[station]
 for i in range(list.size()):
  var item: Dictionary=list[i]
  var frame:=part.global_transform*Transform3D(Basis(Vector3.UP,float(item.yaw)),item.glass)
  var hit=on_plane(frame,from,along)
  if hit==null:continue
  var half: Vector2=Vector2(item.size)*0.5+Vector2(0.025,0.035)
  if absf(hit.x)<=half.x and hit.y>=-half.y and hit.y<=half.y+0.05:return {"kind":item.kind,"index":i,"title":item.title}
 if station=="driver":
  var hit=on_plane(driver.global_transform*panel_frame,from,along)
  if hit!=null and absf(hit.x)<=PANEL_SIZE.x*0.5+0.02 and absf(hit.y)<=PANEL_SIZE.y*0.5+0.02:return {"kind":"panel","index":-1,"title":"ЩИТОК ПРИЛАДІВ"}
 return {}

# Where a ray meets the face of a frame (its +Z side), in the frame's x, y.
static func on_plane(frame: Transform3D, from: Vector3, along: Vector3):
 var normal:=frame.basis.z.normalized()
 var facing:=along.dot(normal)
 if facing>-0.0001:return null
 var t:=(frame.origin-from).dot(normal)/facing
 if t<0.0:return null
 var local:=frame.affine_inverse()*(from+along*t)
 return Vector2(local.x,local.y)

# The eyes at the eyepiece of a device, in the station's coordinates.
func lean_frame(part: String, index: int) -> Transform3D:
 var item: Dictionary=devices[part][index]
 var turn:=Basis(Vector3.UP,float(item.yaw))
 return Transform3D(turn*Basis(Vector3.RIGHT,-0.10),Vector3(item.glass)+turn*Vector3(0,0.012,LEAN))

# --- Building -----------------------------------------------------------------
func mesh_node(parent: Node3D, title: String, mesh: ColorMesh) -> MeshInstance3D:
 var instance:=MeshInstance3D.new();instance.name=title
 instance.mesh=mesh.build(BmpArt.material())
 instance.layers=BmpArt.INTERIOR_LAYER
 instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(instance)
 return instance

func light(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> void:
 var lamp:=OmniLight3D.new();lamp.position=at
 lamp.light_color=color;lamp.light_energy=energy;lamp.omni_range=reach;lamp.omni_attenuation=1.2
 # On the interior layer itself: the seat camera sees only that layer and
 # would cull a lamp left on layer 1, lighting the cabin only in frames
 # where a prism camera happened to see the lamp.
 lamp.layers=BmpArt.INTERIOR_LAYER
 lamp.light_cull_mask=BmpArt.INTERIOR_LAYER;lamp.shadow_enabled=false
 parent.add_child(lamp)

# A dome lamp: a steel cup and a warm glass, with its light.
func dome(parent: Node3D, mesh: ColorMesh, at: Vector3) -> void:
 mesh.cylinder(BmpArt.at(at),0.055,0.03,10,STEEL)
 var glow:=StandardMaterial3D.new()
 glow.albedo_color=LAMP;glow.emission_enabled=true;glow.emission=LAMP;glow.emission_energy_multiplier=1.6
 var lens:=CylinderMesh.new();lens.top_radius=0.04;lens.bottom_radius=0.04;lens.height=0.012;lens.radial_segments=10;lens.material=glow
 var shine:=MeshInstance3D.new();shine.mesh=lens;shine.position=at+Vector3.DOWN*0.018
 shine.layers=BmpArt.INTERIOR_LAYER;shine.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(shine)
 light(parent,at+Vector3.DOWN*0.10,LAMP,0.4,1.5)

# A flat polygon seen from the side `facing` points to.
static func wall(mesh: ColorMesh, points: Array, color: Color, facing: Vector3) -> void:
 var normal:=facing.normalized()
 var u:=normal.cross(Vector3.UP if absf(normal.y)<0.9 else Vector3.RIGHT).normalized()
 var w:=normal.cross(u)
 var flat:=PackedVector2Array()
 for p in points:flat.append(Vector2(Vector3(p).dot(u),Vector3(p).dot(w)))
 var triangles:=Geometry2D.triangulate_polygon(flat)
 for k in range(0,triangles.size(),3):mesh.triangle(points[triangles[k]],points[triangles[k+1]],points[triangles[k+2]],color,normal)

static func rod(mesh: ColorMesh, from: Vector3, to: Vector3, radius: float, color: Color, sides: int=6) -> void:
 BmpArt.rod(mesh,from,to,radius,color,sides)

# The housing of a device hanging from the roof, its glass at the back face,
# a rubber gasket round the glass and the brow pad above.
func housing(mesh: ColorMesh, item: Dictionary, roof: float) -> void:
 var turn:=Basis(Vector3.UP,float(item.yaw))
 var glass: Vector3=item.glass
 var size: Vector2=item.size
 var tkn:bool=item.kind=="tkn"
 var wide:=size.x+(0.06 if tkn else 0.03)
 var deep:=0.22 if tkn else 0.12
 var bottom:=glass.y-size.y*0.5-(0.07 if tkn else 0.035)
 var top:=roof+0.01
 var middle:=Vector3(glass.x,(top+bottom)*0.5,glass.z)+turn*Vector3(0,0,-deep*0.5)
 # The TKN-3B is painted like the walls; the prism blocks are bare steel.
 mesh.box(Transform3D(turn,middle),Vector3(wide,top-bottom,deep),PAINT_LOW if tkn else DARK)
 # Clamps that hold the block in its well.
 for side in [-1.0,1.0]:
  mesh.box(Transform3D(turn,Vector3(glass.x,top-0.03,glass.z)+turn*Vector3(side*(wide*0.5+0.008),0,-deep*0.5)),Vector3(0.016,0.05,deep*0.6),STEEL)
 var pad_at:=glass+turn*Vector3(0,size.y*0.5+(0.05 if tkn else 0.065),0.035)
 if tkn:
  # The binocular eyepiece: two rubber eyecups and the dark lenses.
  for side in [-1.0,1.0]:
   mesh.cylinder(Transform3D(turn*Basis(Vector3.RIGHT,PI/2),glass+turn*Vector3(side*0.034,0,0.022)),0.025,0.044,12,RUBBER,Color("0c1210"))
  mesh.box(Transform3D(turn,glass+turn*Vector3(0,0,0.002)),Vector3(size.x,size.y,0.004),Color("1a1c18"))
  # The handles that turn the device.
  for side in [-1.0,1.0]:
   var root:=glass+turn*Vector3(side*(wide*0.5),-0.03,-0.05)
   var grip:=glass+turn*Vector3(side*(wide*0.5+0.03),-0.13,0.03)
   rod(mesh,root,grip,0.012,STEEL)
   rod(mesh,grip,grip+turn*Vector3(0,-0.09,0.02),0.018,RUBBER,8)
 else:
  for y in [-1.0,1.0]:mesh.box(Transform3D(turn,glass+turn*Vector3(0,y*(size.y*0.5+0.005),0.006)),Vector3(size.x+0.02,0.01,0.012),RUBBER)
  for x in [-1.0,1.0]:mesh.box(Transform3D(turn,glass+turn*Vector3(x*(size.x*0.5+0.005),0,0.006)),Vector3(0.01,size.y,0.012),RUBBER)
 var pad_axis:=turn*Vector3.RIGHT
 mesh.cylinder(Transform3D(Basis(Quaternion(Vector3.UP,pad_axis)),pad_at),0.022,wide,10,RUBBER)
 for side in [-1.0,1.0]:mesh.box(Transform3D(turn,glass+turn*Vector3(side*(wide*0.5-0.01),size.y*0.5+0.04,0.012)),Vector3(0.012,0.05,0.04),STEEL)

func build_driver() -> void:
 var m:=ColorMesh.new()
 var xl:=-1.46;var xs:=-1.08;var xr:=-0.22
 var yf:=0.50;var ys:=0.96;var yr:=1.56;var yk:=1.05
 var zf:=-2.15;var zb:=-0.70;var zs:=-1.70
 # Floor, the shelf over the left track, the walls, the underside of the
 # upper glacis and the roof: painted steel seen from inside.
 wall(m,[Vector3(xs,yf,zf),Vector3(xr,yf,zf),Vector3(xr,yf,zb),Vector3(xs,yf,zb)],FLOOR,Vector3.UP)
 wall(m,[Vector3(xl,ys,zf),Vector3(xs,ys,zf),Vector3(xs,ys,zb),Vector3(xl,ys,zb)],PAINT_LOW,Vector3.UP)
 wall(m,[Vector3(xs,yf,zf),Vector3(xs,ys,zf),Vector3(xs,ys,zb),Vector3(xs,yf,zb)],PAINT_LOW,Vector3.RIGHT)
 wall(m,[Vector3(xl,ys,zf),Vector3(xl,ys,zb),Vector3(xl,yr,zb),Vector3(xl,yr,zs),Vector3(xl,yk,zf)],PAINT,Vector3.RIGHT)
 wall(m,[Vector3(xr,yf,zf),Vector3(xr,yf,zb),Vector3(xr,yr,zb),Vector3(xr,yr,zs),Vector3(xr,yk,zf)],PAINT,Vector3.LEFT)
 wall(m,[Vector3(xs,yf,zf),Vector3(xr,yf,zf),Vector3(xr,yk,zf),Vector3(xs,yk,zf)],PAINT_LOW,Vector3.BACK)
 wall(m,[Vector3(xl,ys,zf),Vector3(xs,ys,zf),Vector3(xs,yk,zf),Vector3(xl,yk,zf)],PAINT_LOW,Vector3.BACK)
 wall(m,[Vector3(xl,yk,zf),Vector3(xr,yk,zf),Vector3(xr,yr,zs),Vector3(xl,yr,zs)],PAINT,Vector3(0,-(zs-zf),yr-yk))
 wall(m,[Vector3(xl,yr,zs),Vector3(xr,yr,zs),Vector3(xr,yr,zb),Vector3(xl,yr,zb)],PAINT,Vector3.DOWN)
 wall(m,[Vector3(xs,yf,zb),Vector3(xr,yf,zb),Vector3(xr,yr,zb),Vector3(xl,yr,zb),Vector3(xl,ys,zb),Vector3(xs,ys,zb)],PAINT_LOW,Vector3.FORWARD)
 # Welds and stiffeners; the quilted insulation of the engine bulkhead.
 m.box(BmpArt.at(Vector3(xl+0.01,1.30,(zf+zb)*0.5)),Vector3(0.02,0.04,zb-zf),PAINT_LOW)
 m.box(BmpArt.at(Vector3((xl+xr)*0.5,yr-0.012,-1.0)),Vector3(xr-xl,0.024,0.05),PAINT_LOW)
 m.box(BmpArt.at(Vector3(xr-0.012,1.0,-1.35)),Vector3(0.024,0.80,1.10),Color("596050"))
 for k in range(5):
  m.box(BmpArt.at(Vector3(xr-0.026,0.62+k*0.18,-1.35)),Vector3(0.006,0.008,1.06),Color("474c40"))
 for z in [-1.88,-1.62,-1.36,-1.10,-0.84]:
  m.box(BmpArt.at(Vector3(xr-0.026,1.0,z)),Vector3(0.006,0.78,0.008),Color("474c40"))
 # Cables along the roof edge and down the left wall.
 rod(m,Vector3(xl+0.03,yr-0.03,zs+0.05),Vector3(xl+0.03,yr-0.03,zb+0.05),0.012,Color("1b1c18"))
 rod(m,Vector3(xl+0.05,yr-0.05,zs+0.10),Vector3(xl+0.05,yr-0.05,zb+0.05),0.009,Color("3d2b1c"))
 rod(m,Vector3(xl+0.03,yr-0.03,-0.95),Vector3(xl+0.03,ys+0.02,-0.95),0.011,Color("1b1c18"))
 # The hatch from below: the lid in its ring, the handle, the lock lever.
 var hatch:=Vector3(BmpArt.DRIVER_HATCH.x,yr,-1.28)
 m.cylinder(BmpArt.at(hatch+Vector3.DOWN*0.012),0.30,0.024,18,PAINT_LOW)
 m.cylinder(BmpArt.at(hatch+Vector3.DOWN*0.022),0.26,0.02,18,Color("6f7966"))
 m.box(BmpArt.at(hatch+Vector3(0,-0.06,0)),Vector3(0.22,0.022,0.028),STEEL)
 for x in [-0.10,0.10]:m.box(BmpArt.at(hatch+Vector3(x,-0.045,0)),Vector3(0.02,0.04,0.02),STEEL)
 m.box(Transform3D(Basis(Vector3.UP,0.5),hatch+Vector3(0.08,-0.04,0.10)),Vector3(0.022,0.018,0.22),STEEL)
 m.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),hatch+Vector3(0.15,-0.04,0.17)),0.018,0.04,8,RUBBER)
 # The three prism blocks under the brow pad.
 for item in devices["driver"]:housing(m,item,yr)
 # The instrument panel on the left, turned to the eyes, on its brackets.
 var turn:=Basis.looking_at(PANEL_CENTER-BmpArt.DRIVER_EYE,Vector3.UP)
 panel_frame=Transform3D(turn,PANEL_CENTER)
 m.box(Transform3D(turn,PANEL_CENTER+turn*Vector3(0,0,-0.032)),Vector3(PANEL_SIZE.x+0.03,PANEL_SIZE.y+0.03,0.06),STEEL)
 for side in [-1.0,1.0]:
  var from:=PANEL_CENTER+turn*Vector3(side*PANEL_SIZE.x*0.35,0,-0.06)
  rod(m,from,Vector3(xl+0.005,from.y,from.z),0.014,STEEL)
 # The yoke on its column; the column itself stays.
 rod(m,YOKE+(YOKE_BASE-YOKE).normalized()*0.05,YOKE_BASE,0.024,STEEL,8)
 m.box(BmpArt.at(YOKE_BASE+Vector3(0,-0.02,-0.04)),Vector3(0.14,0.12,0.10),DARK)
 yoke=Node3D.new();yoke.name="Yoke";yoke.position=YOKE;driver.add_child(yoke)
 var bar:=ColorMesh.new()
 bar.box(BmpArt.at(Vector3.ZERO),Vector3(0.42,0.034,0.034),STEEL)
 bar.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.02)),0.045,0.05,12,DARK,STEEL)
 for x in [-0.21,0.21]:
  bar.cylinder(BmpArt.at(Vector3(x,0.05,0.0)),0.02,0.12,8,RUBBER)
  bar.box(BmpArt.at(Vector3(x,-0.005,0)),Vector3(0.05,0.03,0.04),STEEL)
 mesh_node(yoke,"Bar",bar)
 # Pedals: the main clutch on the left, the brake, the fuel on the right.
 for x in [-0.93,-0.72,-0.58]:
  var pivot:=Node3D.new();pivot.position=Vector3(x,0.80,-2.06);driver.add_child(pivot)
  var pedal:=ColorMesh.new()
  rod(pedal,Vector3.ZERO,Vector3(0,-0.20,0.07),0.012,STEEL)
  pedal.box(Transform3D(Basis(Vector3.RIGHT,0.5),Vector3(0,-0.21,0.08)),Vector3(0.09 if x>-0.6 else 0.10,0.13 if x>-0.6 else 0.09,0.02),RUBBER)
  mesh_node(pivot,"Pedal",pedal)
  pedals.append(pivot)
 m.box(BmpArt.at(Vector3(-0.76,0.80,-2.08)),Vector3(0.48,0.04,0.04),STEEL)
 # The gear gate on its pedestal by the bulkhead, the lever in it.
 m.box(BmpArt.at(Vector3(LEVER.x,0.69,LEVER.z)),Vector3(0.16,0.38,0.24),DARK)
 m.box(BmpArt.at(LEVER+Vector3(0,-0.004,0)),Vector3(0.15,0.012,0.22),STEEL)
 for column in [-1.0,0.0,1.0]:m.box(BmpArt.at(LEVER+Vector3(column*0.045,0.003,0)),Vector3(0.012,0.004,0.15),Color("0d0e0c"))
 m.box(BmpArt.at(LEVER+Vector3(0,0.003,0)),Vector3(0.10,0.004,0.012),Color("0d0e0c"))
 lever=Node3D.new();lever.name="GearLever";lever.position=LEVER;driver.add_child(lever)
 var stick:=ColorMesh.new()
 rod(stick,Vector3.ZERO,Vector3(0,0.28,0),0.011,STEEL)
 stick.cylinder(BmpArt.at(Vector3(0,0.30,0)),0.028,0.05,10,Color("2a2a26"),Color("8a8a80"))
 stick.box(BmpArt.at(Vector3(0,0.03,0)),Vector3(0.05,0.04,0.05),RUBBER)
 mesh_node(lever,"Stick",stick)
 # The seat lowered for the shut hatch, and the seat of the man behind.
 m.box(BmpArt.at(Vector3(-0.78,0.74,-1.02)),Vector3(0.44,0.10,0.40),SEAT)
 m.box(BmpArt.at(Vector3(-0.78,0.62,-1.02)),Vector3(0.10,0.20,0.10),STEEL)
 m.box(Transform3D(Basis(Vector3.RIGHT,0.12),Vector3(-0.78,1.04,-0.80)),Vector3(0.44,0.50,0.08),SEAT)
 m.box(BmpArt.at(Vector3(-0.78,0.70,-0.76)),Vector3(0.40,0.06,0.08),STEEL)
 # The intercom box of the radio on the left wall beside the head.
 m.box(BmpArt.at(BmpArt.RADIO),Vector3(0.10,0.16,0.24),Color("1b1c18"))
 for k in range(3):m.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),BmpArt.RADIO+Vector3(0.055,-0.03,-0.07+k*0.07)),0.014,0.02,8,Color("4a4b44"),Color("8a8a80"))
 m.box(BmpArt.at(BmpArt.RADIO+Vector3(0.051,0.045,0)),Vector3(0.004,0.04,0.14),Color("2d3a2a"))
 # The fire extinguisher on the bulkhead.
 m.cylinder(BmpArt.at(Vector3(-0.29,0.86,-0.95)),0.055,0.34,10,RED,Color("6e1f17"))
 m.box(BmpArt.at(Vector3(-0.29,1.06,-0.95)),Vector3(0.05,0.06,0.04),Color("1b1c18"))
 for y in [0.76,0.96]:m.box(BmpArt.at(Vector3(-0.26,y,-0.95)),Vector3(0.03,0.02,0.13),STEEL)
 # A grab handle on the roof by the hatch.
 rod(m,Vector3(-0.42,yr-0.005,-1.50),Vector3(-0.42,yr-0.05,-1.46),0.01,STEEL)
 rod(m,Vector3(-0.42,yr-0.05,-1.46),Vector3(-0.42,yr-0.05,-1.18),0.012,STEEL)
 rod(m,Vector3(-0.42,yr-0.005,-1.14),Vector3(-0.42,yr-0.05,-1.18),0.01,STEEL)
 dome(driver,m,Vector3(-0.62,yr-0.016,-0.80))
 mesh_node(driver,"Compartment",m)
 # The daylight that comes down through the prisms.
 light(driver,BmpArt.DRIVER_EYE+Vector3(0,-0.04,-0.16),DAYLIGHT,0.3,0.9)
 build_panel()

# The instruments drawn by BmpCockpit into a texture on the panel.
func build_panel() -> void:
 panel_view=SubViewport.new();panel_view.name="PanelView"
 panel_view.size=Vector2i(BmpCockpit.PANEL);panel_view.disable_3d=true
 panel_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(panel_view)
 plate=BmpCockpit.new();plate.plate_only=true;plate.game=vehicle.game;plate.source=vehicle
 plate.size=BmpCockpit.PANEL
 panel_view.add_child(plate)
 var face:=StandardMaterial3D.new()
 face.albedo_texture=panel_view.get_texture();face.albedo_texture_force_srgb=true
 face.emission_enabled=true;face.emission_texture=panel_view.get_texture();face.emission_energy_multiplier=0.35
 face.roughness=0.6
 face.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
 var quad:=QuadMesh.new();quad.size=PANEL_SIZE;quad.material=face
 var screen:=MeshInstance3D.new();screen.name="Panel";screen.mesh=quad
 screen.transform=panel_frame*Transform3D(Basis.IDENTITY,Vector3(0,0,0.002))
 screen.layers=BmpArt.INTERIOR_LAYER;screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 driver.add_child(screen)

# --- The troop compartment -------------------------------------------------------
func build_troop() -> void:
 # Seen from below too: the boxes keep their bottom faces.
 var m:=ColorMesh.new();m.closed=true
 var xs:=1.08;var xw:=1.48;var yf:=BmpTroops.FLOOR;var ys:=0.96;var yr:=1.60
 var zf:=-0.10;var zb:=3.30;var zs:=2.85;var yb:=1.46
 var door_top:=BmpArt.DOOR_TOP;var inner:=BmpArt.DOOR_HINGE_X-BmpArt.DOOR_WIDTH;var outer:=BmpArt.DOOR_HINGE_X
 # The floor with its tread plates, out to the sills.
 wall(m,[Vector3(-xs,yf,zf),Vector3(xs,yf,zf),Vector3(xs,yf,BmpArt.HALF),Vector3(-xs,yf,BmpArt.HALF)],FLOOR,Vector3.UP)
 for z in [0.9,1.6,2.3,3.0]:
  for x in [-0.62,0.62]:m.box(BmpArt.at(Vector3(x,yf+0.003,z)),Vector3(0.40,0.006,0.55),Color("41463b"))
 for s in [-1.0,1.0]:
  # The sponsons over the tracks, the side walls above them, the ports.
  wall(m,[Vector3(s*xs,yf,zf),Vector3(s*xs,ys,zf),Vector3(s*xs,ys,zb),Vector3(s*xs,yf,zb)],PAINT_LOW,Vector3(-s,0,0))
  wall(m,[Vector3(s*xs,ys,zf),Vector3(s*xw,ys,zf),Vector3(s*xw,ys,zb),Vector3(s*xs,ys,zb)],PAINT_LOW,Vector3.UP)
  wall(m,[Vector3(s*xw,ys,zf),Vector3(s*xw,yr,zf),Vector3(s*xw,yr,zs),Vector3(s*xw,yb,zb),Vector3(s*xw,ys,zb)],PAINT,Vector3(-s,0,0))
  m.box(BmpArt.at(Vector3(s*(xw-0.01),1.12,(zf+zb)*0.5)),Vector3(0.02,0.03,zb-zf),PAINT_LOW)
  # Stowage on the sponsons: rifle magazines, a bag, the water can.
  m.box(BmpArt.at(Vector3(s*1.28,ys+0.09,0.45)),Vector3(0.30,0.18,0.42),OLIVE)
  m.box(BmpArt.at(Vector3(s*1.30,ys+0.07,2.85)),Vector3(0.26,0.14,0.50),Color("3d3a2c"))
  for k in range(3):
   var z: float=BmpArt.TROOP_Z[k]
   var port:=Vector3(s*(xw-0.03),1.24,z)
   m.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),port),0.085,0.06,12,DARK,Color("0c0d0b"))
   m.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),port+Vector3(-s*0.03,0,0)),0.045,0.03,10,STEEL,Color("050505"))
   rod(m,port+Vector3(-s*0.04,-0.05,0.06),port+Vector3(-s*0.10,-0.11,0.06),0.009,STEEL)
   # A prism over each port; the passenger's own shows the world.
   var item:=BmpArt.troop_device(s,z)
   housing(m,item,yr)
   if not (s>0.0 and k==1):
    var turn:=Basis(Vector3.UP,float(item.yaw))
    m.box(Transform3D(turn,Vector3(item.glass)+turn*Vector3(0,0,0.002)),Vector3(item.size.x,item.size.y,0.004),Color("1b2422"))
 # The roof, open over the passenger where his hatch is.
 var hx0:=BmpArt.TROOP_HATCH.x-0.43;var hx1:=BmpArt.TROOP_HATCH.x+0.43
 var hz0:=BmpArt.TROOP_HATCH.z-0.50;var hz1:=BmpArt.TROOP_HATCH.z+0.50
 for r in [[-xw,xw,zf,hz0],[-xw,xw,hz1,zs],[-xw,hx0,hz0,hz1],[hx1,xw,hz0,hz1]]:
  wall(m,[Vector3(r[0],yr,r[2]),Vector3(r[1],yr,r[2]),Vector3(r[1],yr,r[3]),Vector3(r[0],yr,r[3])],PAINT,Vector3.DOWN)
 wall(m,[Vector3(-xw,yr,zs),Vector3(xw,yr,zs),Vector3(xw,yb,zb),Vector3(-xw,yb,zb)],PAINT,Vector3(0,-(zb-zs),-(yr-yb)))
 # The well of the open hatch and its rim.
 for r in [[hx0,hx1,hz0,hz0,Vector3.BACK],[hx0,hx1,hz1,hz1,Vector3.FORWARD]]:
  wall(m,[Vector3(r[0],yr,r[2]),Vector3(r[1],yr,r[3]),Vector3(r[1],yr+0.05,r[3]),Vector3(r[0],yr+0.05,r[2])],PAINT_LOW,r[4])
 for r in [[hx0,Vector3.RIGHT],[hx1,Vector3.LEFT]]:
  wall(m,[Vector3(r[0],yr,hz0),Vector3(r[0],yr,hz1),Vector3(r[0],yr+0.05,hz1),Vector3(r[0],yr+0.05,hz0)],PAINT_LOW,r[1])
 for r in [[hx0,hx1,hz0-0.02,hz0+0.0],[hx0,hx1,hz1,hz1+0.02]]:m.box(BmpArt.at(Vector3((r[0]+r[1])*0.5,yr-0.01,(r[2]+r[3])*0.5)),Vector3(r[1]-r[0]+0.04,0.02,0.02),STEEL)
 # The other three hatches from below: the lid in its frame, the handle.
 for h in [Vector2(-0.52,1.15),Vector2(-0.52,2.25),Vector2(0.52,2.25)]:
  var c:=Vector3(h.x,yr-0.012,h.y)
  m.box(BmpArt.at(c),Vector3(0.80,0.02,0.94),Color("6f7966"))
  m.box(BmpArt.at(c+Vector3(0,-0.035,0)),Vector3(0.05,0.03,0.30),STEEL)
  m.box(BmpArt.at(c+Vector3(signf(h.x)*0.36,-0.02,0)),Vector3(0.04,0.03,0.20),STEEL)
 # The rear wall round the two doorways, and the jambs out to the hull.
 for s in [-1.0,1.0]:
  wall(m,[Vector3(s*outer,yf,zb),Vector3(s*xs,yf,zb),Vector3(s*xs,yb,zb),Vector3(s*outer,yb,zb)],PAINT_LOW,Vector3.FORWARD)
  wall(m,[Vector3(s*xs,ys,zb),Vector3(s*xw,ys,zb),Vector3(s*xw,yb,zb),Vector3(s*xs,yb,zb)],PAINT_LOW,Vector3.FORWARD)
  wall(m,[Vector3(s*inner,door_top,zb),Vector3(s*outer,door_top,zb),Vector3(s*outer,yb,zb),Vector3(s*inner,yb,zb)],PAINT_LOW,Vector3.FORWARD)
  wall(m,[Vector3(s*inner,yf,zb),Vector3(s*inner,door_top,zb),Vector3(s*inner,door_top,BmpArt.HALF),Vector3(s*inner,yf,BmpArt.HALF)],PAINT_LOW,Vector3(s,0,0))
  wall(m,[Vector3(s*outer,yf,zb),Vector3(s*outer,door_top,zb),Vector3(s*outer,door_top,BmpArt.HALF),Vector3(s*outer,yf,BmpArt.HALF)],PAINT_LOW,Vector3(-s,0,0))
  wall(m,[Vector3(s*inner,door_top,zb),Vector3(s*outer,door_top,zb),Vector3(s*outer,door_top,BmpArt.HALF),Vector3(s*inner,door_top,BmpArt.HALF)],PAINT_LOW,Vector3.DOWN)
 wall(m,[Vector3(-inner,yf,zb),Vector3(inner,yf,zb),Vector3(inner,yb,zb),Vector3(-inner,yb,zb)],PAINT_LOW,Vector3.FORWARD)
 # The turret basket in front, the dark passages beside it to the driver
 # and into the turret.
 m.cylinder(BmpArt.at(Vector3(0,(yf+yr)*0.5,-0.30)),0.86,yr-yf,20,Color("33372f"),Color(0,0,0,0),false)
 for y in [0.82,1.24]:m.cylinder(BmpArt.at(Vector3(0,y,-0.30)),0.872,0.03,20,STEEL,Color(0,0,0,0),false)
 for a in [-0.9,-0.45,0.0,0.45,0.9]:
  var at:=Vector3(sin(a)*0.875,(yf+yr)*0.5,-0.30+cos(a)*0.875)
  m.box(Transform3D(Basis(Vector3.UP,a),at),Vector3(0.03,yr-yf,0.02),STEEL)
 wall(m,[Vector3(-xw,yf,zf),Vector3(xw,yf,zf),Vector3(xw,yr,zf),Vector3(-xw,yr,zf)],Color("15160f"),Vector3.BACK)
 # The fuel tank between the benches; the seats on it back to back.
 m.box(BmpArt.at(Vector3(0,(yf+1.18)*0.5,(0.62+2.85)*0.5)),Vector3(0.32,1.18-yf,2.23),PAINT_LOW)
 m.box(BmpArt.at(Vector3(0,1.18,(0.62+2.85)*0.5)),Vector3(0.34,0.02,2.25),STEEL)
 m.cylinder(BmpArt.at(Vector3(0,1.20,2.62)),0.05,0.04,10,STEEL,Color("6a6a60"))
 for s in [-1.0,1.0]:
  for z in BmpArt.TROOP_Z:
   m.box(BmpArt.at(Vector3(s*0.35,0.67,z)),Vector3(0.38,0.06,0.50),SEAT)
   m.box(BmpArt.at(Vector3(s*0.27,0.57,z)),Vector3(0.22,0.14,0.44),STEEL)
   m.box(BmpArt.at(Vector3(s*0.19,0.98,z)),Vector3(0.05,0.34,0.46),SEAT)
 # Cables along the roof edges; the domes; the radio speaker box.
 for s in [-1.0,1.0]:rod(m,Vector3(s*(xw-0.04),yr-0.04,zf+0.1),Vector3(s*(xw-0.04),yr-0.04,zs),0.011,Color("1b1c18"))
 m.box(BmpArt.at(Vector3(-1.30,1.40,1.95)),Vector3(0.10,0.14,0.20),Color("1b1c18"))
 dome(troop,m,Vector3(0,yr-0.016,1.12))
 dome(troop,m,Vector3(0,yr-0.016,2.40))
 mesh_node(troop,"Compartment",m)
 # The daylight from the prism by the passenger, and through the doors.
 light(troop,Vector3(1.20,1.36,float(BmpArt.TROOP_Z[1])),DAYLIGHT,0.15,0.9)
 door_light=OmniLight3D.new();door_light.position=Vector3(0,1.05,3.80)
 door_light.light_color=DAYLIGHT;door_light.light_energy=0.0;door_light.omni_range=4.2;door_light.omni_attenuation=0.9
 door_light.layers=BmpArt.INTERIOR_LAYER;door_light.light_cull_mask=BmpArt.INTERIOR_LAYER;door_light.shadow_enabled=false
 troop.add_child(door_light)
 build_doors()
 build_hatch()

# The doors from inside, on their hinges: they swing out with the leaves.
func build_doors() -> void:
 var art_doors: Array=vehicle.art.doors
 for i in range(art_doors.size()):
  var s:=-1.0 if i==0 else 1.0
  var inside:=Node3D.new();inside.name="Inside"
  art_doors[i].add_child(inside)
  var m:=ColorMesh.new();m.closed=true
  var w:=BmpArt.DOOR_WIDTH;var y0:=BmpArt.DOOR_BOTTOM;var y1:=BmpArt.DOOR_TOP
  wall(m,[Vector3(0,y0,-0.004),Vector3(-s*w,y0,-0.004),Vector3(-s*w,y1,-0.004),Vector3(0,y1,-0.004)],PAINT_LOW,Vector3.FORWARD)
  # The tank's inner face, its filler and the lock lever with the handle.
  m.box(BmpArt.at(Vector3(-s*w*0.5,(y0+y1)*0.5,-0.05)),Vector3(w-0.14,y1-y0-0.16,0.09),PAINT)
  m.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(-s*w*0.5,y1-0.16,-0.10)),0.04,0.03,10,STEEL,Color("6a6a60"))
  rod(m,Vector3(-s*(w-0.10),0.80,-0.11),Vector3(-s*(w-0.10),1.12,-0.11),0.014,STEEL)
  rod(m,Vector3(-s*(w-0.10),0.80,-0.11),Vector3(-s*(w-0.10),0.80,-0.04),0.012,STEEL)
  rod(m,Vector3(-s*(w-0.10),1.12,-0.11),Vector3(-s*(w-0.10),1.12,-0.04),0.012,STEEL)
  m.box(Transform3D(Basis(Vector3.BACK,0.5*s),Vector3(-s*(w-0.20),0.66,-0.11)),Vector3(0.20,0.025,0.025),RED)
  # The firing port in the left door.
  if i==0:m.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(-s*w*0.5,1.02,-0.10)),0.07,0.04,12,DARK,Color("0c0d0b"))
  mesh_node(inside,"Door",m)
  door_insides.append(inside)

# The lid of the passenger's hatch from below, on its hinge.
func build_hatch() -> void:
 hatch_inside=Node3D.new();hatch_inside.name="Inside"
 vehicle.art.troop_hatch.add_child(hatch_inside)
 var m:=ColorMesh.new();m.closed=true
 m.box(BmpArt.at(Vector3(-0.43,-0.034,0)),Vector3(0.80,0.02,0.94),Color("6f7966"))
 m.box(BmpArt.at(Vector3(-0.43,-0.06,0)),Vector3(0.05,0.03,0.30),STEEL)
 m.box(BmpArt.at(Vector3(-0.78,-0.05,0)),Vector3(0.04,0.03,0.20),STEEL)
 mesh_node(hatch_inside,"Lid",m)
