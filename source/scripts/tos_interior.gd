class_name TosInterior
extends Node3D

# The driver's compartment of the BM-1's T-72A hull as the driver sees it
# closed down (ТО и ИЭ Т-72А, 1986, рис. 3). He sits on the axis of the hull
# under his hatch, the seat lowered and tilted back, and leans to the lower
# window of the TNPO-168V just under the roof. Before his knees the two
# steering levers in their rubber boots, at his feet the pedals of the main
# clutch, the brake and the fuel; the instrument panel on the left wall, the
# gear selector in its gate by the right hand, the front fuel tank-rack on
# the right. Look round with the mouse; the right button on the prism puts
# the face to it (BmpPeriscope shows the world through it), anywhere else it
# brings the panel up large. The meshes sit on the interior layer: only the
# seat camera draws them, lit by a dome lamp and the daylight from the
# prism. Hull frame.
const PAINT := Color("d3d7c9")
const PAINT_LOW := Color("aeb4a5")
const LINING := Color("6d7068")
const FLOOR := Color("43473d")
const STEEL := Color("3a3f35")
const DARK := Color("22251f")
const RUBBER := Color("131411")
const SEAT := Color("3b3a2e")
const OLIVE := Color("4f573c")
const RED := Color("9b2c20")
const LAMP := Color("ffd9a6")
const DAYLIGHT := Color("d5e2ee")
# The eyes of the driver leaning to the prism (the seat's H-point 0.70 m
# below and 0.15 m behind), and the face at the eyepiece.
const EYE := Vector3(0,1.37,-2.18)
const LEAN := 0.065
# The compartment: the tub of the floor, the roof under the anti-radiation
# lining, the inner face of the upper glacis from the nose up to the prism,
# the side walls, the bulkhead behind the seat.
const FLOOR_Y := 0.49
const ROOF_Y := 1.46
const GLACIS_LOW := Vector2(-3.25,0.85)
const GLACIS_TOP := Vector2(-2.36,ROOF_Y)
const NOSE_Z := -3.05
const SIDE := 0.58
const BACK_Z := -1.40
const HATCH := Vector3(0,ROOF_Y,-2.10)
const PANEL_SIZE := Vector2(0.38,0.166)
const PANEL_CENTER := Vector3(-0.42,1.13,-2.36)
const LEVERS := [Vector3(-0.20,0.55,-2.80),Vector3(0.20,0.55,-2.80)]
const LEVER_GRIP := Vector3(0,0.52,0.27)
const SELECTOR := Vector3(0.31,0.80,-2.33)
var vehicle: TosVehicle
var prism: Dictionary
var scope: BmpPeriscope
var levers: Array[Node3D]=[]
var pedals: Array[Node3D]=[]
var selector: Node3D
var panel_view: SubViewport
var plate: BmpCockpit
var panel_frame: Transform3D
var shown := false

# The TNPO-168V: its lower window 0.22 m before the eyes, the head window
# 173 mm higher on the glacis in front of the hatch (TosArt).
static func device() -> Dictionary:
 return BmpArt.device(EYE,0.0,0.22,-0.01,Vector2(0.25,0.05),0.17,0.078,"prism","ТНПО-168В")

func setup(owner: TosVehicle) -> void:
 vehicle=owner;name="DriverCompartment"
 process_priority=1000
 (owner.art.root as Node3D).add_child(self)
 var sun: DirectionalLight3D=owner.game.sunlight
 if sun!=null:sun.light_cull_mask=sun.light_cull_mask & ~BmpArt.INTERIOR_LAYER
 prism=device()
 build()
 scope=BmpPeriscope.new();add_child(scope)
 scope.setup(self,prism,0)
 show_cabin(false)

func show_cabin(on: bool) -> void:
 shown=on;visible=on
 if not on:
  panel_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
  scope.update(null,false)

func panel_seen(viewer: Camera3D) -> bool:
 var frame:=global_transform*panel_frame
 for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
  if viewer.is_position_in_frustum(frame*Vector3(corner.x*PANEL_SIZE.x*0.5,corner.y*PANEL_SIZE.y*0.5,0)):return true
 return false

func _process(_delta: float) -> void:
 if not shown:return
 var viewer:=vehicle.seat_camera if vehicle.seat_camera.current else null
 scope.update(viewer,viewer!=null)
 if viewer!=null and panel_seen(viewer):
  plate.queue_redraw()
  panel_view.render_target_update_mode=SubViewport.UPDATE_ONCE
 # The levers come back as they are pulled; the pedals go down.
 for i in range(levers.size()):levers[i].rotation.x=float(vehicle.levers[i])*0.42
 var amounts:=[vehicle.clutch_pedal,vehicle.brake_pedal,maxf(vehicle.throttle,vehicle.hand_throttle)]
 for i in range(pedals.size()):pedals[i].rotation.x=float(amounts[i])*0.35
 # The selector: reverse at the back of its gate, seventh at the front.
 var slot:=float(vehicle.gear-TosVehicle.NEUTRAL)/7.0
 selector.rotation.x=lerpf(selector.rotation.x,-slot*0.42 if vehicle.gear!=0 else 0.30,0.35)

# --- Where the eyes are -------------------------------------------------------
func pick(viewer: Camera3D) -> Dictionary:
 if not shown or viewer==null:return {}
 var from:=viewer.global_position
 var along:=-viewer.global_basis.z
 var hit=BmpInterior.on_plane(global_transform*Transform3D(Basis.IDENTITY,prism.glass),from,along)
 var half: Vector2=Vector2(prism.size)*0.5+Vector2(0.03,0.04)
 if hit!=null and absf(hit.x)<=half.x and absf(hit.y)<=half.y+0.04:return {"kind":"prism","index":0,"title":"ТНПО-168В"}
 hit=BmpInterior.on_plane(global_transform*panel_frame,from,along)
 if hit!=null and absf(hit.x)<=PANEL_SIZE.x*0.5+0.02 and absf(hit.y)<=PANEL_SIZE.y*0.5+0.02:return {"kind":"panel","index":-1,"title":"ЩИТОК ПРИЛАДІВ"}
 return {}

# The face at the eyepiece, a little above its middle, looking a little down.
func lean_frame() -> Transform3D:
 return Transform3D(Basis(Vector3.RIGHT,-0.06),Vector3(prism.glass)+Vector3(0,0.008,LEAN))

# --- Building -----------------------------------------------------------------
func mesh_node(parent: Node3D, title: String, mesh: ColorMesh) -> MeshInstance3D:
 var instance:=MeshInstance3D.new();instance.name=title
 instance.mesh=mesh.build(BmpArt.material())
 instance.layers=BmpArt.INTERIOR_LAYER
 instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(instance)
 return instance

func light(where: Vector3, color: Color, energy: float, reach: float) -> void:
 var lamp:=OmniLight3D.new();lamp.position=where
 lamp.light_color=color;lamp.light_energy=energy;lamp.omni_range=reach;lamp.omni_attenuation=1.2
 lamp.layers=BmpArt.INTERIOR_LAYER
 lamp.light_cull_mask=BmpArt.INTERIOR_LAYER;lamp.shadow_enabled=false
 add_child(lamp)

static func wall(mesh: ColorMesh, points: Array, color: Color, facing: Vector3) -> void:BmpInterior.wall(mesh,points,color,facing)
static func rod(mesh: ColorMesh, from: Vector3, to: Vector3, radius: float, color: Color, sides: int=6) -> void:BmpArt.rod(mesh,from,to,radius,color,sides)
static func at(p: Vector3) -> Transform3D:return Transform3D(Basis.IDENTITY,p)
# A cylinder along a direction instead of up.
static func along(direction: Vector3, p: Vector3) -> Transform3D:return Transform3D(Basis(Quaternion(Vector3.UP,direction.normalized())),p)

func build() -> void:
 var m:=ColorMesh.new()
 var l:=-SIDE;var r:=SIDE
 var gl:=GLACIS_LOW;var gt:=GLACIS_TOP
 # The tub, the roof, the glacis from inside, the nose below it, the side
 # walls and the bulkhead behind: white enamel, the lining overhead.
 wall(m,[Vector3(l,FLOOR_Y,NOSE_Z),Vector3(r,FLOOR_Y,NOSE_Z),Vector3(r,FLOOR_Y,BACK_Z),Vector3(l,FLOOR_Y,BACK_Z)],FLOOR,Vector3.UP)
 wall(m,[Vector3(l,ROOF_Y,gt.x),Vector3(r,ROOF_Y,gt.x),Vector3(r,ROOF_Y,BACK_Z),Vector3(l,ROOF_Y,BACK_Z)],LINING,Vector3.DOWN)
 wall(m,[Vector3(l,gl.y,gl.x),Vector3(r,gl.y,gl.x),Vector3(r,gt.y,gt.x),Vector3(l,gt.y,gt.x)],PAINT,Vector3(0,-(gt.x-gl.x),gt.y-gl.y))
 wall(m,[Vector3(l,FLOOR_Y,NOSE_Z),Vector3(r,FLOOR_Y,NOSE_Z),Vector3(r,gl.y,gl.x),Vector3(l,gl.y,gl.x)],PAINT_LOW,Vector3(0,NOSE_Z-gl.x,gl.y-FLOOR_Y))
 for side in [-1.0,1.0]:
  var x:float=side*SIDE
  wall(m,[Vector3(x,FLOOR_Y,NOSE_Z),Vector3(x,gl.y,gl.x),Vector3(x,gt.y,gt.x),Vector3(x,ROOF_Y,BACK_Z),Vector3(x,FLOOR_Y,BACK_Z)],PAINT_LOW,Vector3(-side,0,0))
 wall(m,[Vector3(l,FLOOR_Y,BACK_Z),Vector3(r,FLOOR_Y,BACK_Z),Vector3(r,ROOF_Y,BACK_Z),Vector3(l,ROOF_Y,BACK_Z)],DARK,Vector3.FORWARD)
 # Quilting of the lining; the weld along the glacis' upper edge.
 for z in [-2.20,-1.95,-1.70]:m.box(at(Vector3(0,ROOF_Y-0.006,z)),Vector3(SIDE*2,0.006,0.012),Color("55584f"))
 m.box(at(Vector3(0,ROOF_Y-0.015,gt.x+0.02)),Vector3(SIDE*2,0.03,0.05),PAINT_LOW)
 # The front fuel tank-rack along the right wall, and the spare TNPO-168V
 # in its case on it.
 m.box(at(Vector3(SIDE-0.08,0.96,-2.06)),Vector3(0.16,0.94,1.28),OLIVE)
 for z in [-2.55,-2.06,-1.57]:m.box(at(Vector3(SIDE-0.165,0.96,z)),Vector3(0.012,0.90,0.04),Color("3f4630"))
 m.box(at(Vector3(SIDE-0.22,1.04,-1.90)),Vector3(0.10,0.30,0.32),Color("6a6f5d"))
 m.box(at(Vector3(SIDE-0.22,1.20,-1.90)),Vector3(0.06,0.02,0.10),STEEL)
 # The left front fuel tank under the panel, the batteries behind it under
 # their lid, the master switch on the battery rack.
 m.box(at(Vector3(-SIDE+0.09,0.745,-2.74)),Vector3(0.18,0.51,0.46),OLIVE)
 m.box(at(Vector3(-SIDE+0.17,0.72,-1.75)),Vector3(0.34,0.46,0.60),Color("2b2e27"))
 m.box(at(Vector3(-SIDE+0.17,0.96,-1.75)),Vector3(0.36,0.02,0.62),PAINT_LOW)
 m.box(at(Vector3(-SIDE+0.17,0.985,-1.62)),Vector3(0.20,0.03,0.16),Color("8a2a1e"))
 m.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),Vector3(-SIDE+0.02,1.10,-1.62)),0.035,0.03,10,STEEL,Color("8a8a80"))
 # Cables along the roof edges and down to the panel.
 rod(m,Vector3(l+0.03,ROOF_Y-0.03,gt.x+0.06),Vector3(l+0.03,ROOF_Y-0.03,BACK_Z+0.05),0.012,Color("1b1c18"))
 rod(m,Vector3(r-0.03,ROOF_Y-0.03,gt.x+0.06),Vector3(r-0.03,ROOF_Y-0.03,BACK_Z+0.05),0.011,Color("1b1c18"))
 rod(m,Vector3(l+0.03,ROOF_Y-0.03,-2.30),PANEL_CENTER+Vector3(-0.08,0.10,0.04),0.010,Color("1b1c18"))
 # The hatch from below: an oval 530 by 390 mm in its ring, the lid with
 # its lining, the handle; the screw column at its front right.
 m.box(at(HATCH+Vector3.DOWN*0.012),Vector3(0.60,0.024,0.46),PAINT_LOW)
 m.box(at(HATCH+Vector3.DOWN*0.026),Vector3(0.50,0.02,0.36),LINING)
 m.box(at(HATCH+Vector3(0,-0.07,0.04)),Vector3(0.22,0.022,0.028),STEEL)
 for x in [-0.10,0.10]:m.box(at(HATCH+Vector3(x,-0.05,0.04)),Vector3(0.02,0.045,0.02),STEEL)
 rod(m,HATCH+Vector3(0.26,-0.02,-0.18),HATCH+Vector3(0.26,-0.30,-0.18),0.016,STEEL,8)
 m.cylinder(Transform3D(Basis(Vector3.BACK,PI/2),HATCH+Vector3(0.22,-0.26,-0.18)),0.05,0.02,10,STEEL)
 m.cylinder(at(HATCH+Vector3(0.18,-0.26,-0.18)),0.012,0.06,8,RUBBER)
 # The TNPO-168V in its shaft at the top of the glacis: the body, the
 # rubber round the lower window, the handlebar that locks it, the lamps of
 # the gun over the hull's width at the corners of the cut-out.
 var glass: Vector3=prism.glass
 var size: Vector2=prism.size
 var bottom:=glass.y-size.y*0.5-0.035
 m.box(at(Vector3(0,(ROOF_Y+0.01+bottom)*0.5,glass.z-0.07)),Vector3(size.x+0.05,ROOF_Y+0.01-bottom,0.14),DARK)
 for y in [-1.0,1.0]:m.box(at(glass+Vector3(0,y*(size.y*0.5+0.006),0.006)),Vector3(size.x+0.024,0.012,0.014),RUBBER)
 for x in [-1.0,1.0]:m.box(at(glass+Vector3(x*(size.x*0.5+0.006),0,0.006)),Vector3(0.012,size.y,0.014),RUBBER)
 rod(m,Vector3(-0.17,bottom-0.02,glass.z+0.02),Vector3(0.17,bottom-0.02,glass.z+0.02),0.011,STEEL,8)
 for x in [-0.17,0.17]:
  rod(m,Vector3(x,bottom-0.02,glass.z+0.02),Vector3(x,bottom+0.02,glass.z-0.04),0.008,STEEL)
  m.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(x*1.25,glass.y-0.01,glass.z-0.005)),0.014,0.02,8,STEEL,Color("7a5a20"))
 # Over the prism: the intercom box A-3 on the left, the lamp unit PV-82
 # (coolant, revs, brake) on the right; the air-start valve with its gauge
 # and the fire bottle at the upper right.
 m.box(at(Vector3(-0.24,ROOF_Y-0.05,-2.30)),Vector3(0.16,0.09,0.10),Color("1b1c18"))
 for k in range(2):m.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(-0.27+k*0.06,ROOF_Y-0.06,-2.248)),0.013,0.02,8,Color("4a4b44"),Color("8a8a80"))
 var unit:=Vector3(0.24,ROOF_Y-0.045,-2.33)
 m.box(at(unit),Vector3(0.18,0.05,0.05),Color("2a2c27"))
 for k in range(4):m.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),unit+Vector3(-0.06+k*0.04,0,0.026)),0.012,0.01,8,STEEL,Color("6a2a1e") if k%2==1 else Color("6a5020"))
 m.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0.34,1.27,-2.48)),0.045,0.025,12,STEEL,Color("e6e2d2"))
 m.box(at(Vector3(0.34,1.20,-2.49)),Vector3(0.05,0.08,0.03),STEEL)
 m.cylinder(at(Vector3(0.44,1.22,-2.62)),0.07,0.34,12,RED,Color("6e1f17"))
 m.box(at(Vector3(0.44,1.41,-2.62)),Vector3(0.06,0.05,0.05),Color("1b1c18"))
 # The fan in the middle under the prism, the compressed-air bottle at the
 # left beside the panel.
 var fan:=Vector3(0,1.08,-2.80)
 m.cylinder(Transform3D(Basis(Vector3.RIGHT,PI/2),fan),0.10,0.05,14,STEEL,Color("1b1c18"))
 for k in range(3):m.box(Transform3D(Basis(Vector3.BACK,PI*k/3.0),fan+Vector3(0,0,0.03)),Vector3(0.19,0.008,0.006),Color("8a8a80"))
 m.cylinder(Transform3D(Basis(Vector3.RIGHT,0.25),Vector3(-0.49,1.17,-2.74)),0.055,0.30,10,Color("2c3a2c"),STEEL)
 # The instrument panel on the left wall, turned to the eyes, and its lower
 # part with the start switches and handles.
 var turn:=Basis.looking_at(PANEL_CENTER-EYE,Vector3.UP)
 panel_frame=Transform3D(turn,PANEL_CENTER)
 m.box(Transform3D(turn,PANEL_CENTER+turn*Vector3(0,0,-0.03)),Vector3(PANEL_SIZE.x+0.03,PANEL_SIZE.y+0.03,0.05),STEEL)
 var lower:=PANEL_CENTER+turn*Vector3(0,-PANEL_SIZE.y*0.5-0.12,-0.04)
 m.box(Transform3D(turn,lower),Vector3(PANEL_SIZE.x,0.20,0.05),Color("394034"))
 for k in range(4):
  m.box(Transform3D(turn,lower+turn*Vector3(-0.13+k*0.085,0.04,0.03)),Vector3(0.012,0.04,0.02),Color("8a8a80"))
  m.box(Transform3D(turn,lower+turn*Vector3(-0.13+k*0.085,-0.05,0.03)),Vector3(0.04,0.016,0.016),RUBBER)
 for side in [-1.0,1.0]:
  var from:=PANEL_CENTER+turn*Vector3(side*PANEL_SIZE.x*0.35,0,-0.05)
  rod(m,from,Vector3(-SIDE+0.005,from.y,from.z),0.013,STEEL)
 # The hand throttle under the panel; the GPK-59 low at the left front by
 # the clutch pedal.
 rod(m,Vector3(-0.36,0.86,-2.30),Vector3(-0.30,0.93,-2.24),0.009,STEEL)
 m.cylinder(at(Vector3(-0.30,0.95,-2.24)),0.016,0.03,8,RUBBER)
 var gyro:=Vector3(-0.34,0.72,-2.70)
 m.cylinder(at(gyro),0.075,0.14,14,Color("2a2c27"))
 m.cylinder(Transform3D(Basis(Vector3.RIGHT,-0.6),gyro+Vector3(0,0.07,0.02)),0.055,0.01,14,Color("e6e2d2"))
 # The steering levers: their shafts come up from the floor before the
 # knees through corrugated rubber boots, the grips at chest height; the
 # left one with the button of the air brake.
 for i in range(LEVERS.size()):
  var pivot:=Node3D.new();pivot.name="Lever%d" % i;pivot.position=LEVERS[i];add_child(pivot)
  var arm:=ColorMesh.new()
  rod(arm,Vector3.ZERO,LEVER_GRIP,0.016,STEEL,8)
  for k in range(7):arm.cylinder(along(LEVER_GRIP,LEVER_GRIP*(0.48+k*0.055)),0.034 if k%2==0 else 0.027,0.03,10,RUBBER)
  arm.cylinder(along(LEVER_GRIP,LEVER_GRIP*1.06),0.022,0.09,10,Color("2a2a26"))
  if i==0:arm.cylinder(along(LEVER_GRIP,LEVER_GRIP*1.13),0.012,0.02,8,RED)
  arm.box(at(Vector3.ZERO),Vector3(0.08,0.06,0.08),DARK)
  mesh_node(pivot,"Arm",arm)
  levers.append(pivot)
  m.box(at(Vector3(LEVERS[i].x,FLOOR_Y+0.03,LEVERS[i].z)),Vector3(0.12,0.06,0.16),DARK)
 # Pedals: the main clutch on the left, the brake, the fuel on the right.
 for x in [-0.16,0.0,0.16]:
  var pivot:=Node3D.new();pivot.position=Vector3(x,0.74,-2.96);add_child(pivot)
  var pedal:=ColorMesh.new()
  rod(pedal,Vector3.ZERO,Vector3(0,-0.17,0.08),0.012,STEEL)
  pedal.box(Transform3D(Basis(Vector3.RIGHT,0.5),Vector3(0,-0.18,0.09)),Vector3(0.07 if x>0.1 else 0.10,0.13 if x>0.1 else 0.09,0.02),RUBBER)
  mesh_node(pivot,"Pedal",pedal)
  pedals.append(pivot)
 m.box(at(Vector3(0,0.74,-2.98)),Vector3(0.44,0.04,0.04),STEEL)
 # The latch of the parking brake: its handle in the nose at the upper left
 # of the prism, its rack by the brake pedal.
 rod(m,Vector3(-0.27,1.40,-2.50),Vector3(-0.24,1.32,-2.47),0.009,STEEL)
 m.cylinder(at(Vector3(-0.24,1.31,-2.47)),0.014,0.025,8,RED)
 m.box(at(Vector3(0.06,0.62,-2.90)),Vector3(0.02,0.14,0.02),STEEL)
 # The gear selector by the right hand: the notched comb of its gate (ЗХ, Н,
 # 1–7) on a pedestal, the lever with its ball.
 m.box(at(Vector3(SELECTOR.x,(FLOOR_Y+SELECTOR.y)*0.5,SELECTOR.z)),Vector3(0.12,SELECTOR.y-FLOOR_Y,0.30),DARK)
 m.box(at(SELECTOR+Vector3(0,0.004,0)),Vector3(0.11,0.012,0.28),STEEL)
 for k in range(9):m.box(at(SELECTOR+Vector3(0.03,0.016,-0.12+k*0.03)),Vector3(0.03,0.012,0.012),Color("0d0e0c"))
 selector=Node3D.new();selector.name="Selector";selector.position=SELECTOR;add_child(selector)
 var stick:=ColorMesh.new()
 rod(stick,Vector3.ZERO,Vector3(0,0.20,0),0.011,STEEL)
 stick.cylinder(at(Vector3(0,0.22,0)),0.025,0.045,10,Color("2a2a26"),Color("8a8a80"))
 stick.box(at(Vector3(0,0.03,0)),Vector3(0.05,0.04,0.05),RUBBER)
 mesh_node(selector,"Stick",stick)
 # The bucket seat lowered and tilted back; the escape hatch in the floor
 # behind it.
 m.box(Transform3D(Basis(Vector3.RIGHT,0.10),Vector3(0,0.63,-2.03)),Vector3(0.42,0.08,0.40),SEAT)
 for x in [-0.15,0.15]:m.box(at(Vector3(x,0.55,-2.03)),Vector3(0.04,0.12,0.30),STEEL)
 m.box(Transform3D(Basis(Vector3.RIGHT,0.50),Vector3(0,0.88,-1.73)),Vector3(0.42,0.48,0.08),SEAT)
 m.box(at(Vector3(0,FLOOR_Y+0.006,-1.58)),Vector3(0.53,0.012,0.39),STEEL)
 m.box(at(Vector3(0,FLOOR_Y+0.02,-1.58)),Vector3(0.16,0.02,0.03),Color("8a8a80"))
 # The dome lamp on the roof behind the hatch.
 var dome:=Vector3(0.20,ROOF_Y-0.016,-1.78)
 m.cylinder(at(dome),0.05,0.03,10,STEEL)
 var glow:=StandardMaterial3D.new()
 glow.albedo_color=LAMP;glow.emission_enabled=true;glow.emission=LAMP;glow.emission_energy_multiplier=1.6
 var lens:=CylinderMesh.new();lens.top_radius=0.036;lens.bottom_radius=0.036;lens.height=0.012;lens.radial_segments=10;lens.material=glow
 var shine:=MeshInstance3D.new();shine.mesh=lens;shine.position=dome+Vector3.DOWN*0.018
 shine.layers=BmpArt.INTERIOR_LAYER;shine.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(shine)
 light(dome+Vector3.DOWN*0.10,LAMP,0.5,1.8)
 mesh_node(self,"Compartment",m)
 # The daylight that comes down through the prism.
 light(EYE+Vector3(0,-0.05,-0.12),DAYLIGHT,0.35,1.0)
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
 add_child(screen)
