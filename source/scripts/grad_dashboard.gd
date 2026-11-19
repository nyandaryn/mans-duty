class_name GradDashboard
extends Control

# The instrument cluster of the Ural-375D on the cab's dashboard, in front of
# the driver: speedometer, tachometer, the air and the tyre pressure gauges
# and the warning lamps. It is painted into a small viewport that textures the
# face of the cluster, and repainted while someone sits in the cab. Holding
# the right mouse button in the driver's seat shows the same readings large
# on the screen (GradHud).
const SIZE := Vector2i(704,260)
const PAINT := Color("1d1f19")
const FACE := Color("0c0d0b")
const BEZEL := Color("7d8077")
const MARK := Color("ebe8da")
const NEEDLE := Color("f4f1e4")
const RED := Color("d2452f")
const AMBER := Color("e8a33a")
const GREEN := Color("6fcf4f")
var vehicle: GradVehicle
var viewport: SubViewport
var screen: MeshInstance3D
var live := false

func setup(owner: GradVehicle) -> void:
 vehicle=owner;name="Dashboard"
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 viewport=SubViewport.new();viewport.name="DashboardView"
 viewport.size=SIZE;viewport.disable_3d=true;viewport.transparent_bg=false
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 viewport.add_child(self)
 size=Vector2(SIZE)
 owner.add_child(viewport)
 # Painted faces behind glass, lit like the rest of the cab. The viewport
 # holds sRGB colours: the material converts them as it would an image.
 var face:=StandardMaterial3D.new()
 face.albedo_texture=viewport.get_texture()
 face.albedo_texture_force_srgb=true
 face.roughness=0.3
 face.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
 var quad:=QuadMesh.new();quad.size=GradArt.DASHBOARD_SIZE;quad.material=face
 screen=MeshInstance3D.new();screen.name="Instruments";screen.mesh=quad
 screen.position=GradArt.DASHBOARD
 screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 owner.art.root.add_child(screen)

func _process(_delta: float) -> void:
 if not is_instance_valid(vehicle):return
 var seated: bool=vehicle.seat in ["driver","commander"]
 if seated!=live:
  live=seated
  # Out of the cab the face keeps the last readings and costs nothing.
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE
 if live:queue_redraw()

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),PAINT)
 if not is_instance_valid(vehicle):return
 var v:=vehicle
 # Speedometer and tachometer in front of the driver, then the manometers.
 dial(Vector2(112,128),94,absf(v.speed())*3.6,0,100,10,20,"км/год")
 dial(Vector2(328,128),94,v.steady_rpm()/1000.0,0,4,0.25,1,"об/хв ×1000",3.2)
 dial(Vector2(502,92),60,v.air,0,10,1,2,"ПОВІТРЯ")
 dial(Vector2(636,92),60,v.tyre,0,4,0.5,1,"ШИНИ")
 # Warning lamps light with the ignition on.
 var lamps:=[[true,"ЗАПАЛ.",AMBER],[v.handbrake,"СТОЯНК.",RED],[v.air<4.5,"ТИСК",RED],[v.power_takeoff,"КВП",GREEN],[v.springs_locked,"БОЙОВЕ",AMBER],[v.shields_down,"ЩИТКИ",GREEN]]
 for i in range(lamps.size()):
  var entry: Array=lamps[i]
  lamp(Vector2(452+(i%3)*86,196+(i/3)*40),v.ignition and bool(entry[0]),str(entry[1]),entry[2])

# A round gauge: 270° scale from the lower left, numbers on the major marks.
func dial(c: Vector2, r: float, value: float, low: float, high: float, step: float, label_step: float, title: String, red: float=INF) -> void:
 var font:=ThemeDB.fallback_font
 draw_circle(c,r+7,BEZEL)
 draw_circle(c,r+3,Color("2a2c27"))
 draw_circle(c,r,FACE)
 if red<high:draw_arc(c,r*0.92,deg_to_rad(135+270*(red-low)/(high-low)),deg_to_rad(405),16,RED,5)
 var count:=roundi((high-low)/step)
 var number_size:=int(r*0.25)
 for k in range(count+1):
  var mark:=low+step*k
  var a:=deg_to_rad(135+270.0*k/count)
  var dir:=Vector2(cos(a),sin(a))
  var major:=absf(mark/label_step-roundf(mark/label_step))<0.001
  draw_line(c+dir*r*(0.78 if major else 0.87),c+dir*r*0.97,RED if mark>=red-0.001 else MARK,3.0 if major else 2.0)
  if major:
   var label:="%d" % roundi(mark)
   var w:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size).x
   draw_string(font,c+dir*r*0.58+Vector2(-w*0.5,number_size*0.36),label,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size,MARK)
 draw_string(font,c+Vector2(-r,r*0.56),title,HORIZONTAL_ALIGNMENT_CENTER,r*2,int(r*0.17),Color(MARK,0.75))
 var t:=clampf((value-low)/(high-low),0,1)
 var a:=deg_to_rad(135+270*t)
 var dir:=Vector2(cos(a),sin(a))
 draw_line(c-dir*r*0.18,c+dir*r*0.86,NEEDLE,4.0)
 draw_circle(c,r*0.10,Color("3a3c36"))

func lamp(at: Vector2, on: bool, title: String, color: Color) -> void:
 if on:draw_circle(at,18,Color(color,0.3))
 draw_circle(at,13,Color("101110"))
 draw_circle(at,10,color.lightened(0.15) if on else color.darkened(0.78))
 draw_string(ThemeDB.fallback_font,at+Vector2(16,5),title,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(MARK,0.8))
