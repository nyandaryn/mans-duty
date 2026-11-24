extends ReconDrone

# FPV kamikaze quadcopter: a 7-inch racing frame carrying a warhead, flown
# through analog goggles, of the kind both sides have used in Ukraine since
# 2023. The numbers used here, from open sources (vendor sheets are claims,
# not test data):
# - Frame and load: 7-inch strike frames lift 1.5–2 kg; with a PG-7VL warhead
#   (the 93 mm RPG-7 grenade, 2.6 kg as a round, its warhead and nose fuse on
#   a printed adaptor less) and a 6S pack the drone weighs some 1.5–2.3 kg.
#   https://dronexl.co/2023/02/01/ukraine-fpv-drones-rpg-7/
#   https://www.suasnews.com/2024/02/from-mortar-to-menace-loitering-munitions-take-new-form-with-pg-7vl-anti-tank-weapon/
#   https://www.vsdmotor.com/drone/7inch-fpv-drone.html (6S, 1.5–2 kg, 6–10 min)
# - Speed: ~80 km/h cruise loaded, 100–130 km/h flat out (here ~22 m/s at
#   35° of pitch, ~28 m/s at 50°).
#   https://flasharmy.com.ua/en/fpv-strike-drone-7-inch-daylight-camera
# - Flight time 6–10 minutes loaded: here 7 minutes at cruise, less with the
#   throttle open.
# - Links: ExpressLRS control on 868/915 MHz, analog video on 5.8 GHz; a few
#   kilometres with a clear line of sight from the pilot's antennas (here
#   the picture is usable to ~2500 m, the control to ~3500 m). The 5.8 GHz
#   picture dies behind a house or a ridge and fades close to the ground far
#   out, where the soil fills the Fresnel zone; 900 MHz bends round more.
#   The picture is a link budget: the margin over the noise that distance
#   leaves (free-space loss, 6 dB per doubling: 22 dB at 200 m, 0 at 2.5 km),
#   less what the worst edge in the way takes by knife-edge diffraction
#   (ITU-R P.526): a parapet just over the line near the pilot ~10 dB, a
#   house or a ridge 20–35 dB. Close in, a low edge only adds snow.
#   https://www.itu.int/rec/R-REC-P.526/en
#   https://www.blue-bird.tech/en/products/quadrocopter-for-kamikade-or-reconnaissancefpv-7/
# - Flight controller in angle (self-levelling) mode: the sticks set the lean,
#   the lean and the throttle make the thrust; momentum, gravity and drag do
#   the rest. Failsafe as in Betaflight: the last command is held a moment
#   (stage 1), then the motors stop (stage 2: drop) — there is no return home
#   on a kamikaze.
# - The warhead is armed by the initiation board after take-off; it goes off
#   on the first hard impact or on the pilot's switch (air burst). Falling
#   unpowered, a PG-7VL piezo fuse usually still fires; a frag charge on an
#   improvised fuse often does not.
# The flight and the link are shared by the player (goggles, OSD) and by bot
# pilots (autopilot: attack run on a target or a point, or a search pattern
# over an area that picks a target itself).

signal finished(drone: Node3D)

const FPV := preload("res://scripts/fpv_drone.gd")
const G := 9.80665
const FPV_FLIGHT_SECONDS := 420.0
const VIDEO_RANGE := 2500.0
const CONTROL_RANGE := 3500.0
# The pilot's antennas, held up or on a short mast.
const ANTENNA_HEIGHT := 1.5
# 5.8 GHz.
const WAVELENGTH := 0.0517
# Higher than this over the line an edge counts as no higher.
const EDGE_PROBE := 30.0
const CRUISE_TILT := 0.61
const BOOST_TILT := 0.87
# Loaded thrust to weight of about 2.4.
const MAX_THRUST := 2.4*G
# Quadratic drag per metre: 22 m/s at 35° of lean, 29 m/s at 50°.
const DRAG := 0.0135
const CRUISE_SPEED := 20.0
const TOP_SPEED := 28.0
const IMPACT_SPEED := 4.0
# The initiation board arms the warhead this far from the take-off point.
const ARM_DISTANCE := 5.0
const FAILSAFE_HOLD := 1.0
# Goggles off: nobody flies it, it goes on a moment, then the motors stop.
const COAST_TIME := 1.3
const SEARCH_RANGE := 250.0
# The search pilot tilts the view forward and down: a cone of ~70° around a
# line 40° below the nose.
const SEARCH_LOOK_DOWN := 0.70
const SEARCH_CONE_COS := 0.82
const SEARCH_RESERVE := 0.12
const CAMERA_MOUNT := Vector3(0,0.016,-0.085)
const CAMERA_UPTILT := 0.52
const WRECK_SECONDS := 45.0
# fuse: odds the warhead goes off when the drone falls on something without
# power; the title is shown on the OSD.
const WARHEADS := {"heat":{"title":"ПГ-7ВЛ","fuse":0.85},"frag":{"title":"ОСКОЛКОВА","fuse":0.5}}

var game: Node3D
var warhead := "heat"
# The bot flying it (a Hostile); null for the player's own FPV.
var pilot: Node3D
var pilot_given := false
var home := Vector3.ZERO
# "ground" before take-off, "manual" in the player's hands; for bot pilots
# "transit", "search", "attack" (the terminal dive); "falling" with nobody
# flying it or the motors stopped; "gone" once it went off or broke up.
var state := "ground"
# Called (kind, point, direction, collider, source) when the warhead goes
# off; by default BlastSystem.warhead().
var impact_handler := Callable()
# Called once when the drone is gone (blown up, broken, freed); with the
# drone as the argument if it takes one. The signal finished goes with it.
var on_finished := Callable()
# Where on the target the attacker aims, in the target's own frame; INF —
# the attacker's choice (for a vehicle a random spot of the engine deck,
# rear, side or turret ring).
var aim_offset := Vector3.INF
# Odds that a bot pilot misses; below zero: 10–25 % by the target's speed.
var miss_chance := -1.0
# The backpack entry the player took it from: gone with the take-off.
var pack_uid := -1
var manual := false
var hide_hud := true
var rest_y := INF
var launched_at := Vector3.INF
var flight_time := 0.0
var warhead_armed := false
var over := false
var uptilt := CAMERA_UPTILT
# The airframe's attitude in the yaw frame and the one asked of it. Turned
# as a rotation, so a flip into the dive takes the short way round instead
# of swinging through upright; pitch and roll read back from it.
var frame := Basis()
var cmd_frame := Basis()
var att_pitch := 0.0
var att_roll := 0.0
var cmd_pitch := 0.0
var cmd_roll := 0.0
var cmd_throttle := 0.0
var cmd_thrust := 0.0
var thrust := 0.0
var boost := false
var video := 1.0
var control := 1.0
var failsafe := false
var coast_left := 0.0
var video_lost_time := 0.0
var grounded := true
var wreck_left := 0.0
var rng := RandomNumberGenerator.new()
var noise_rng := RandomNumberGenerator.new()
# Autopilot.
var goal := ""
var target: Node3D
var goal_point := Vector3.INF
var diving := false
var cruise_alt := 30.0
var dive_angle := 0.45
var miss_offset := Vector3.ZERO
var search_center := Vector3.ZERO
var search_radius := 100.0
var picker := Callable()
var search_speed := 17.0
var pattern_phase := 0.0
var pattern_axis := 0.0
var look_clock := 0.0
var probe_clock := 0.0
var avoid_left := 0.0
# Goggles picture and OSD (while the player flies it).
var goggles: CanvasLayer
var picture: ColorRect
var osd: Control
var hud_hidden := false
# The pilot has pushed his goggles up: the sticks are let go to the centre,
# the flight controller holds it level and the throttle hand stays where it
# was (FieldRig "fpv_up").
var hands_off := false
var picture_clock := 0.0
static var buzz: AudioStreamWAV
static var picture_shader: Shader

# --- Making one -------------------------------------------------------------------
# The common part: airframe, camera, hitbox, motors. No operator needed.
func setup_fpv(owner_game: Node3D, kind: String) -> void:
 game=owner_game
 warhead=kind if WARHEADS.has(kind) else "heat"
 rng.seed=randi()
 noise_rng.seed=rng.randi()
 top_level=true
 add_to_group("drones")
 collision_layer=32
 collision_mask=1|2|4|8
 motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
 wall_min_slide_angle=0.0
 battery=1.0;health=1.0;armed=false;landed=true
 link_range=VIDEO_RANGE
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size=Vector3(0.34,0.15,0.52 if warhead=="heat" else 0.40)
 shape.shape=box;shape.position=Vector3(0,-0.04,-0.08 if warhead=="heat" else -0.03)
 add_child(shape)
 model=DroneArt.build_fpv(warhead);add_child(model)
 for child in model.get_children():
  if child is Node3D and child.has_meta("rotor"):rotors.append(child)
 camera=Camera3D.new();camera.fov=100;camera.near=0.04;camera.far=1600
 camera.cull_mask=1|OperatorBody.WORLD_BODY_LAYER;add_child(camera)
 DamageModel.hitbox(self,self,"drone",Vector3(0,-0.03,-0.07),Vector3(0.44,0.18,0.62))
 motor_sound=AudioStreamPlayer3D.new();motor_sound.stream=buzz_audio()
 motor_sound.unit_size=12;motor_sound.max_distance=170;motor_sound.volume_db=-1
 if game.get("hearing")!=null:motor_sound.bus=game.hearing.bus_name
 add_child(motor_sound)
 impact_handler=default_impact
 place_visuals()

# The player's own, set on the ground in front of him from the backpack.
func setup_player(owner_operator: Operator, entry: Dictionary) -> void:
 operator=owner_operator
 setup_fpv(owner_operator.game,warhead_of(entry))
 pack_uid=int(entry.get("uid",-1))
 friendly=true;manual=true
 home=owner_operator.global_position
 add_collision_exception_with(owner_operator)

static func warhead_of(entry: Dictionary) -> String:
 var kind := str(entry.get("kind",""))
 var chosen := str(entry.get("warhead","frag" if kind=="fpv_frag" else "heat"))
 return chosen if WARHEADS.has(chosen) else "heat"

static func is_fpv_kind(kind: String) -> bool:return kind in ["fpv_heat","fpv_frag","fpv_drone"]

# A drone flown by a bot (pilot: a Hostile, or null). It waits on the ground
# at from until it is given autopilot(), autopilot_point() or search_area().
static func launch(owner_game: Node3D, bot: Node3D, side_friendly: bool, kind: String, from: Vector3) -> FPV:
 var drone: FPV=FPV.new()
 owner_game.world_root.add_child(drone)
 drone.setup_fpv(owner_game,kind)
 drone.friendly=side_friendly
 drone.pilot=bot
 drone.pilot_given=bot!=null
 drone.home=bot.global_position if bot!=null else from
 if bot is CollisionObject3D:drone.add_collision_exception_with(bot)
 drone.yaw=bot.global_rotation.y if bot!=null else 0.0
 drone.global_transform=Transform3D(Basis(Vector3.UP,drone.yaw),from+Vector3.UP*0.13)
 drone.place_visuals()
 return drone

# Still a threat: not gone off, not broken up, not freed.
func alive() -> bool:return not over and is_inside_tree()

func launched() -> bool:return launched_at!=Vector3.INF

# An analog FPV gives the wrist display nothing.
func shows_on_wrist() -> bool:return false

func can_recover() -> bool:return false

# --- Sound ------------------------------------------------------------------------
# Four 7-inch three-blade props near 9600 rpm: blade passing at ~480 Hz with
# its harmonics, two props a little off each other (the beat), the motors'
# electric whine and the hiss of the air; harsh and high, heard far off.
static func buzz_audio() -> AudioStreamWAV:
 if buzz!=null:return buzz
 var rate := 22050
 var data := PackedByteArray();data.resize(rate*2)
 var noise := RandomNumberGenerator.new();noise.seed=7
 var hiss := 0.0
 for i in range(rate):
  var t := float(i)/rate
  var blades := 0.0
  for h in range(1,8):blades+=(sin(TAU*480*h*t)+0.8*sin(TAU*471*h*t))/h
  var whine := sin(TAU*1920*t)*0.22+sin(TAU*2880*t)*0.12
  hiss=hiss*0.55+noise.randf_range(-1,1)*0.45
  var wave := blades*(0.8+0.2*sin(TAU*9*t))*0.45+whine+hiss*0.28
  wave=wave/(1.0+absf(wave)*0.35)
  data.encode_s16(i*2,int(clampf(wave*9000,-32000,32000)))
 buzz=AudioStreamWAV.new();buzz.format=AudioStreamWAV.FORMAT_16_BITS
 buzz.mix_rate=rate;buzz.data=data;buzz.loop_mode=AudioStreamWAV.LOOP_FORWARD;buzz.loop_end=rate
 return buzz

# --- Goggles ----------------------------------------------------------------------
func begin_control() -> bool:
 if over or health<=0 or battery<=0:return false
 piloting=true;hands_off=false;camera.make_current();open_goggles()
 notice="" if launched() else "SPACE — ГАЗ, ЗЛІТ"
 return true

func end_control() -> void:
 super.end_control()
 close_goggles()

# Goggles up in the air: the pilot lets the sticks go. In angle mode it levels
# out and holds its height, its momentum dying away in the drag; the battery
# runs down. It does not hold its place: it drifts on until it stops.
func hover() -> void:
 if over:return
 if piloting:end_control()
 cmd_pitch=0.0;cmd_roll=0.0;cmd_throttle=0.0;boost=false
 hands_off=true

# The picture of the analog link over the whole view (fisheye of the wide
# lens, a cheap camera's washed colour, interlaced lines, the snow of a weak
# signal) and the flight controller's OSD on it. Under the game's interface:
# the pause menu still comes up over the goggles.
func open_goggles() -> void:
 if is_instance_valid(goggles):return
 goggles=CanvasLayer.new();goggles.name="FpvGoggles";goggles.layer=0
 add_child(goggles)
 picture=ColorRect.new();picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var material := ShaderMaterial.new();material.shader=goggles_shader();picture.material=material
 goggles.add_child(picture);picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 osd=Control.new();osd.mouse_filter=Control.MOUSE_FILTER_IGNORE
 goggles.add_child(osd);osd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 osd.draw.connect(draw_osd)
 # The soldier's own HUD (and the recon drone's overlay on it) goes while
 # the goggles are on.
 var hud: Control=game.get("hud")
 if hide_hud and hud!=null and hud.visible:
  hud.visible=false;hud_hidden=true
 set_process(true)

func close_goggles() -> void:
 if is_instance_valid(goggles):goggles.queue_free()
 goggles=null;picture=null;osd=null
 set_process(false)
 if hud_hidden:
  hud_hidden=false
  if is_instance_valid(game) and game.running:
   var hud: Control=game.get("hud")
   if hud!=null:hud.visible=true

static func goggles_shader() -> Shader:
 if picture_shader!=null:return picture_shader
 picture_shader=Shader.new()
 picture_shader.code="""shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float snow = 0.0;
uniform float lost = 0.0;
uniform float clock = 0.0;
uniform float aspect = 1.7778;
uniform float fisheye = 0.24;
float hash(vec2 p){
	p = fract(p*vec2(123.34, 456.21));
	p += dot(p, p+45.32);
	return fract(p.x*p.y);
}
void fragment(){
	vec2 uv = SCREEN_UV;
	vec2 p = (uv-0.5)*vec2(aspect, 1.0);
	vec2 corner = vec2(aspect, 1.0)*0.5;
	vec2 q = p*(1.0+fisheye*dot(p, p))/(1.0+fisheye*dot(corner, corner));
	float row = floor(uv.y*288.0);
	float field = floor(clock*25.0);
	float tear = (hash(vec2(row, field))-0.5)*snow*snow*0.05;
	vec2 s = q/vec2(aspect, 1.0)+0.5+vec2(tear, 0.0);
	float bleed = 0.0012+snow*0.004;
	vec3 c = vec3(texture(screen_tex, s+vec2(bleed, 0.0)).r, texture(screen_tex, s).g, texture(screen_tex, s-vec2(bleed, 0.0)).b);
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, 0.6)*0.84+0.06;
	c *= 0.9+0.1*step(0.5, fract(uv.y*288.0));
	float grain = hash(floor(uv*vec2(420.0, 288.0))+vec2(field*0.137, field*0.731));
	c = mix(c, vec3(grain), clamp(0.04+snow*0.8+lost, 0.0, 1.0));
	float streak = step(1.0-snow*0.08, hash(vec2(row*0.71, field+3.0)));
	c = mix(c, vec3(0.92), streak*0.7*(1.0-lost));
	float edge = length(p)/length(corner);
	c *= 1.0-smoothstep(0.55, 1.02, edge)*0.8;
	COLOR = vec4(c, 1.0);
}
"""
 return picture_shader

func _process(delta: float) -> void:
 if not is_instance_valid(picture):return
 if not game.paused:picture_clock+=delta
 var view := get_viewport().get_visible_rect().size
 var material: ShaderMaterial=picture.material
 material.set_shader_parameter("aspect",view.x/maxf(view.y,1.0))
 material.set_shader_parameter("snow",snow())
 material.set_shader_parameter("lost",1.0 if video<0.04 else 0.0)
 material.set_shader_parameter("clock",picture_clock)
 osd.queue_redraw()

func snow() -> float:return clampf(1.0-video/0.45,0.0,1.0)

# 6S Li-ion: 4.2 V a cell full, ~3.0 V empty, sagging under throttle.
func volts() -> float:
 var cell := 3.0+1.2*pow(battery,0.7)-0.28*clampf(thrust/MAX_THRUST,0,1)
 return 6.0*maxf(cell,2.7)

# Point on the goggles' picture where a world point shows, through the same
# fisheye as the shader (its inverse, by a few fixed-point steps).
func picture_point(world: Vector3) -> Vector2:
 var view := osd.size
 var flat := camera.unproject_position(world)
 var aspect := view.x/maxf(view.y,1.0)
 var q := (flat/view-Vector2(0.5,0.5))*Vector2(aspect,1.0)
 var corner := Vector2(aspect,1.0)*0.5
 var p := q
 for i in range(4):p=q*(1.0+0.24*corner.length_squared())/(1.0+0.24*p.length_squared())
 return (p/Vector2(aspect,1.0)+Vector2(0.5,0.5))*view

func osd_text(at: Vector2, text: String, size: int, ink: Color, align: int=HORIZONTAL_ALIGNMENT_LEFT, width: float=-1.0) -> void:
 var font := UiKit.font("head")
 osd.draw_string_outline(font,at,text,align,width,size,maxi(3,size/6),Color(0,0,0,ink.a*0.85))
 osd.draw_string(font,at,text,align,width,size,ink)

# Betaflight-style OSD, white on the picture: it is mixed into the drone's
# own video, so it shakes and drowns with the picture and is gone with it.
func draw_osd() -> void:
 if not is_instance_valid(osd) or video<0.04:return
 var view := osd.size
 var u := view.y/720.0
 var big := int(24*u)
 var small := int(18*u)
 var jitter := Vector2(noise_rng.randf_range(-3,3),noise_rng.randf_range(-1.5,1.5))*snow()*u
 var ink := Color(0.97,0.98,0.95,clampf(video/0.2,0.35,0.95))
 var left := view.x*0.07
 var right := view.x*0.93
 osd_text(Vector2(left,view.y*0.10)+jitter,"%.1fV" % volts(),big,ink)
 osd_text(Vector2(left,view.y*0.10+big*1.2)+jitter,"АКБ %d %%" % roundi(battery*100),small,ink)
 osd_text(Vector2(view.x*0.5-100*u,view.y*0.10)+jitter,"%02d:%02d" % [floori(flight_time/60.0),floori(fmod(flight_time,60.0))],big,ink,HORIZONTAL_ALIGNMENT_CENTER,200*u)
 osd_text(Vector2(right-320*u,view.y*0.10)+jitter,"ЗВ’ЯЗОК %d %%" % roundi(control*100),big,ink,HORIZONTAL_ALIGNMENT_RIGHT,320*u)
 osd_text(Vector2(right-320*u,view.y*0.10+big*1.2)+jitter,"ВІДЕО %d %%" % roundi(video*100),small,ink,HORIZONTAL_ALIGNMENT_RIGHT,320*u)
 osd_text(Vector2(left,view.y*0.52)+jitter,"%d км/год" % roundi(velocity.length()*3.6),big,ink)
 var height := global_position.y-(launched_at.y if launched() else global_position.y)
 osd_text(Vector2(right-260*u,view.y*0.52)+jitter,"ВИС %d м" % roundi(height),big,ink,HORIZONTAL_ALIGNMENT_RIGHT,260*u)
 osd_text(Vector2(right-260*u,view.y*0.52+big*1.2)+jitter,"ДО ПІЛОТА %.2f км" % (global_position.distance_to(antenna())/1000.0),small,ink,HORIZONTAL_ALIGNMENT_RIGHT,260*u)
 osd_text(Vector2(left,view.y*0.84)+jitter,"ГАЗ %d %%" % roundi(clampf(thrust/MAX_THRUST,0,1)*100),small,ink)
 osd_text(Vector2(view.x*0.5-260*u,view.y*0.84)+jitter,"БЧ %s · %s" % [WARHEADS[warhead].title,"ВЗВЕДЕНО" if warhead_armed else "ЗАПОБІЖНИК"],big,ink,HORIZONTAL_ALIGNMENT_CENTER,520*u)
 # Crosshair and the artificial horizon (lean of the frame, not the view).
 var center := view*0.5+jitter
 for side in [-1,1]:osd.draw_line(center+Vector2(side*7,0)*u,center+Vector2(side*22,0)*u,ink,2*u)
 osd.draw_line(center+Vector2(0,-6)*u,center+Vector2(0,6)*u,ink,2*u)
 var tilt := Vector2.from_angle(-att_roll)
 var horizon := center+Vector2(0,clampf(att_pitch*240*u,-200*u,200*u))
 for i in range(-4,5):
  if absi(i)<=1:continue
  var a := horizon+tilt*i*34*u
  osd.draw_line(a-tilt*9*u,a+tilt*9*u,Color(ink,ink.a*0.8),2*u)
 # Where it is actually going: a small ring with wings.
 if velocity.length()>2.0 and not camera.is_position_behind(camera.global_position+velocity):
  var mark := picture_point(camera.global_position+velocity*10.0)
  if Rect2(Vector2.ZERO,view).grow(-30*u).has_point(mark):
   osd.draw_arc(mark,7*u,0,TAU,16,Color(ink,ink.a*0.8),2*u)
   for side in [-1,1]:osd.draw_line(mark+Vector2(side*7,0)*u,mark+Vector2(side*16,0)*u,Color(ink,ink.a*0.8),2*u)
 var warnings: Array[String]=[]
 var alarm_text := alarm()
 if alarm_text!="":warnings.append(alarm_text)
 if failsafe:warnings.append("ВТРАТА КЕРУВАННЯ")
 elif control<0.25:warnings.append("СЛАБКИЙ СИГНАЛ")
 if battery<0.15:warnings.append("НИЗЬКА НАПРУГА")
 if not armed and not launched() and health>0:warnings.append("МОТОРИ ВИМКНЕНО")
 var blink := fmod(picture_clock,0.8)<0.5
 for i in range(warnings.size()):
  if blink or i>0:osd_text(Vector2(0,view.y*0.30+i*big*1.3)+jitter,warnings[i],big,ink,HORIZONTAL_ALIGNMENT_CENTER,view.x)
 if notice!="":osd_text(Vector2(left,view.y*0.79)+jitter,notice,small,ink)
 osd_text(Vector2(0,view.y*0.955),"W/S — ТАНГАЖ · A/D — КРЕН · МИША — КУРС / НАХИЛ КАМЕРИ · SPACE / CTRL — ГАЗ · SHIFT — ФОРСАЖ · ЛКМ — ПІДРИВ · "+("Y — ПІДНЯТИ ОКУЛЯРИ (ДРОН ЗАВИСНЕ)" if launched() else "Y — ЗНЯТИ ОКУЛЯРИ"),int(14*u),Color(0.85,0.88,0.82,0.55),HORIZONTAL_ALIGNMENT_CENTER,view.x)

# --- The player's sticks ----------------------------------------------------------
func handle_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion:
  var sensitivity: float=operator.sensitivity if is_instance_valid(operator) else 0.0022
  yaw-=event.relative.x*sensitivity*0.8
  # The camera's mount: 10–55° up, as the pilot sets it before flight.
  uptilt=clampf(uptilt-event.relative.y*sensitivity*0.6,0.17,0.95)
 elif event.is_action_pressed("fire"):trigger()
 elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_Y:
  if is_instance_valid(operator) and operator.field_rig!=null:operator.field_rig.toggle_fpv()

# Angle mode: W/S lean forward/back, A/D bank, Shift leans further; the
# throttle hand holds the height unless Space or Ctrl moves it.
func pilot_input() -> void:
 var forward := Input.get_axis("back","forward")
 var side := Input.get_axis("left","right")
 boost=Input.is_action_pressed("sprint")
 var lean := BOOST_TILT if boost else CRUISE_TILT
 cmd_pitch=forward*lean;cmd_roll=side*lean*0.85
 cmd_throttle=float(Input.is_action_pressed("jump"))-float(Input.is_action_pressed("crouch"))

func throttle_thrust() -> float:
 var level := G/maxf(cos(att_pitch)*cos(att_roll),0.4)
 var wanted := level*(1.0+cmd_throttle*0.9) if cmd_throttle>=0 else level*(1.0+cmd_throttle*0.85)
 return clampf(wanted,0.0,MAX_THRUST*(1.08 if boost else 1.0))

# The pilot's detonation switch: an air burst where it is.
func trigger() -> void:
 if over:return
 if not warhead_armed:
  notice="БЧ НЕ ВЗВЕДЕНА: ВІДЛЕТИ %d м ВІД ТОЧКИ ЗЛЬОТУ" % roundi(ARM_DISTANCE)
  return
 detonate(global_position,velocity,null)

# --- Link -------------------------------------------------------------------------
func antenna() -> Vector3:
 if relay!=Vector3.INF:return relay
 if is_instance_valid(operator):home=operator.global_position
 elif is_instance_valid(pilot):home=pilot.global_position
 return home+Vector3.UP*ANTENNA_HEIGHT

func update_link(delta: float) -> void:
 link_timer-=delta
 if link_timer>0:return
 link_timer=0.1
 floor_height=ground_clearance()
 if battery<=0:
  video=0.0;control=0.0;signal_strength=0.0
  return
 var station := antenna()
 var distance := station.distance_to(global_position)
 var open_control := clampf(1.0-pow(distance/CONTROL_RANGE,2.0),0.0,1.0)
 var hit := ray(station,global_position,1)
 var shade := terrain_shadow(station,distance)
 var margin := 20.0*log(VIDEO_RANGE/maxf(distance,1.0))/log(10.0)
 var loss := maxf(terrain_loss(station,distance),obstacle_loss(station,hit))
 video=picture_left(margin-loss)
 control=open_control*lerpf(0.4,1.0,shade)*(0.5 if not hit.is_empty() else 1.0)
 signal_strength=video

# The picture for the margin left over the noise (dB): 1 − 10^(−margin/10),
# so with nothing in the way it falls as 1 − (d/2500)².
static func picture_left(margin: float) -> float:
 return clampf(1.0-pow(10.0,-margin/10.0),0.0,1.0)

# Knife-edge diffraction loss in dB (ITU-R P.526, eq. 31) for v = √2·h/r₁:
# h how far the edge stands into the line, r₁ the first Fresnel zone's
# radius there. Nothing with the zone clear, 6 dB grazing, ~25 dB with the
# edge four zone radii up.
static func edge_loss(h: float, zone: float) -> float:
 var v := sqrt(2.0)*h/maxf(zone,0.05)
 if v<= -0.78:return 0.0
 return 6.9+20.0*log(sqrt(pow(v-0.1,2.0)+1.0)+v-0.1)/log(10.0)

static func fresnel(d1: float, distance: float) -> float:
 return sqrt(WAVELENGTH*clampf(d1,0.0,distance)*maxf(distance-d1,0.0)/maxf(distance,0.01))

# The ground under the line, its worst point as a knife edge.
func terrain_loss(station: Vector3, distance: float) -> float:
 if distance<30.0 or not is_instance_valid(game.district):return 0.0
 var worst := 0.0
 for i in range(1,13):
  var t := i/13.0
  var point := station.lerp(global_position,t)
  worst=maxf(worst,edge_loss(float(game.district.ground_height(point))-point.y,maxf(fresnel(distance*t,distance),0.3)))
 return worst

# A wall, a house, a parapet across the line (hit, from the pilot's side, and
# the one nearest the drone): how high it stands over the line where the line
# meets it, as a knife edge.
func obstacle_loss(station: Vector3, hit: Dictionary) -> float:
 if hit.is_empty():return 0.0
 var distance := station.distance_to(global_position)
 var worst := edge_over(hit,station,distance)
 var back := ray(global_position,station,1)
 if not back.is_empty() and back.collider!=hit.collider:
  worst=maxf(worst,edge_over(back,global_position,distance))
 return worst

# How far over the line the top of what it hit stands: short rays along the
# line raised step by step (the first to pass is over it), then one down to
# find the top itself. Walls built as one-sided surfaces are found too.
const EDGE_STEPS := [0.25,0.5,1.0,2.0,3.5,6.0,10.0,16.0,25.0]
func edge_over(hit: Dictionary, from: Vector3, distance: float) -> float:
 if hit.collider.has_meta("terrain"):return 0.0
 var at: Vector3=hit.position
 var along := (at-from).normalized()
 var d1 := from.distance_to(at)
 if from!=antenna():d1=distance-d1
 var space := get_world_3d().direct_space_state
 var clear := EDGE_PROBE
 for step in EDGE_STEPS:
  var lifted := at+Vector3.UP*float(step)
  var probe := PhysicsRayQueryParameters3D.create(lifted-along*0.3,lifted+along*1.5,1,[get_rid()])
  if space.intersect_ray(probe).is_empty():
   clear=float(step)
   break
 var top := at.y+clear
 # A little inside it, so the ray down does not slip past its face.
 var inside := at+along*0.05
 var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(inside+Vector3.UP*clear,inside+Vector3.UP*0.01,1,[get_rid()]))
 if not down.is_empty():top=float(down.position.y)
 return edge_loss(top-at.y,fresnel(d1,distance))

# The ground under the line between the antennas, against the first Fresnel
# zone: for the control link (900 MHz bends round more), 0.4 of it at worst.
func terrain_shadow(station: Vector3, distance: float) -> float:
 if distance<30.0 or not is_instance_valid(game.district):return 1.0
 var worst := INF
 for i in range(1,7):
  var t := i/7.0
  var point := station.lerp(global_position,t)
  var d1 := distance*t
  var zone := sqrt(WAVELENGTH*d1*(distance-d1)/distance)
  worst=minf(worst,(point.y-float(game.district.ground_height(point)))/maxf(zone,0.3))
 return clampf(0.35+0.65*worst,0.03,1.0)

# A ray past this drone, its pilot and the invisible edge of the map.
func ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
 var excluded: Array[RID]=[get_rid()]
 if is_instance_valid(operator):excluded.append(operator.get_rid())
 if is_instance_valid(pilot) and pilot is CollisionObject3D:excluded.append(pilot.get_rid())
 var space := get_world_3d().direct_space_state
 for attempt in range(3):
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,mask,excluded))
  if hit.is_empty() or not hit.collider.has_meta("boundary"):return hit
  excluded.append(hit.rid)
 return {}

# --- Flight -----------------------------------------------------------------------
func _physics_process(delta: float) -> void:
 if not is_instance_valid(game):return
 if pilot_given and not is_instance_valid(pilot):
  # Its pilot is gone with the match it was launched in.
  queue_free();return
 if not game.running:
  motor_sound.stop();return
 if game.paused:
  motor_sound.stream_paused=true;return
 motor_sound.stream_paused=false
 if over:
  wreck_left-=delta
  if wreck_left<=0:queue_free()
  return
 if rest_y==INF:rest_y=global_position.y
 update_link(delta)
 fired_on=maxf(0.0,fired_on-delta);hit_notice=maxf(0.0,hit_notice-delta)
 if downed>0.0:downed+=delta
 if pilot_given and armed and coast_left<=0 and state!="falling" and pilot.get("dead")==true:abandon()
 steer_controls(delta)
 if fly(delta):return
 after_flight(delta)

func steer_controls(delta: float) -> void:
 var blind := control<0.03 or (goal!="" and video<0.04)
 lost_link_time=lost_link_time+delta if blind and launched() and not piloting_gone() else 0.0
 if armed and lost_link_time>FAILSAFE_HOLD:
  armed=false;failsafe=true;state="falling"
  notice="ВТРАТА КЕРУВАННЯ · ДРОН ПАДАЄ"
 if armed and (battery<=0 or health<=0):armed=false;state="falling"
 if piloting and not armed and not launched() and not failsafe and health>0 and battery>0 and Input.is_action_pressed("jump"):
  armed=true;state="manual";notice=""
 if coast_left>0:
  coast_left-=delta
  if coast_left<=0:armed=false
 elif armed and lost_link_time<=0:
  if piloting:pilot_input()
  elif goal!="":steer(guide(delta),delta)
 if armed:thrust=throttle_thrust() if manual else cmd_thrust
 else:thrust=0.0
 if armed:battery=maxf(0.0,battery-delta/FPV_FLIGHT_SECONDS*(0.3+0.7*thrust/(G*1.22)))

# Nobody to fly it: the failsafe clock does not run for a drone already let go.
func piloting_gone() -> bool:return coast_left>0 or state=="falling"

# One step of flight. True when the drone struck something and is gone.
func fly(delta: float) -> bool:
 if armed:
  if manual:cmd_frame=Basis(Vector3.RIGHT,-cmd_pitch)*Basis(Vector3.BACK,-cmd_roll)
  frame=frame.slerp(cmd_frame,1.0-exp(-delta*7.0)).orthonormalized()
  att_pitch=atan2(-frame.y.z,frame.y.y);att_roll=asin(clampf(frame.y.x,-1.0,1.0))
 var attitude := Basis(Vector3.UP,yaw)*frame
 var force := attitude.y*thrust+Vector3.DOWN*G-velocity*velocity.length()*DRAG
 if armed and manual and (piloting or hands_off) and cmd_throttle==0.0:force.y-=velocity.y*1.2
 velocity+=force*delta
 if not launched():
  # On its warhead in the grass: it only goes up, when the motors lift it.
  velocity.x=0.0;velocity.z=0.0
 var speed := velocity.length()
 if speed>IMPACT_SPEED and launched():
  # The nose (the fuse probe) meets things first.
  var hit := ray(global_position,global_position+velocity/speed*(speed*delta+0.34),1|2|4|8)
  if not hit.is_empty():
   strike(hit.position,velocity/speed,hit.collider)
   return true
 var before := velocity
 move_and_slide()
 grounded=false
 for i in range(get_slide_collision_count()):
  var contact := get_slide_collision(i)
  var collider := contact.get_collider()
  if collider!=null and collider.has_meta("boundary"):continue
  var normal := contact.get_normal()
  var impact := -before.dot(normal)
  if before.length()>IMPACT_SPEED and impact>1.5 and launched():
   strike(contact.get_position(),before.normalized(),collider)
   return true
  if impact>2.2 and launched() and health>0:
   # Props into a wall below the fuse's speed: they break, it drops.
   health=0.0;armed=false;state="falling";notice="ПРОПЕЛЕРИ ЗЛАМАНО"
  if normal.y>0.6:grounded=true
  # Floating mode leaves the velocity as it was: off whatever it rests on.
  if velocity.dot(normal)<0.0:velocity=velocity.slide(normal)
 if grounded and launched():
  velocity.x*=0.85;velocity.z*=0.85
 landed=grounded and velocity.length()<0.5
 return false

func after_flight(delta: float) -> void:
 if not launched() and armed and global_position.y>rest_y+0.5:
  launched_at=global_position
  # Off the ground: the drone is spent, out of the pack for good.
  if pack_uid>=0 and is_instance_valid(operator):operator.backpack.remove(pack_uid)
  pack_uid=-1
 if launched():
  flight_time+=delta
  if not warhead_armed and global_position.distance_to(launched_at)>ARM_DISTANCE:
   warhead_armed=true
   if piloting:notice="БЧ ВЗВЕДЕНО"
 if landed and launched() and not armed:
  # Down without a blast (no power over soft ground): a dud lying there.
  break_up()
  return
 if global_position.y<-200.0:
  finish("");queue_free();return
 # With the motors stopped and the picture gone there is nothing to watch.
 if piloting and not armed and launched() and video<0.04:
  video_lost_time+=delta
  if video_lost_time>1.5:release_from_rig("FPV-дрон втрачено: немає відео.")
 else:video_lost_time=0.0
 place_visuals()
 for i in range(rotors.size()):rotors[i].rotation.y+=delta*(70.0+thrust*7.0 if armed else 0.0)*(1 if i%2==0 else -1)
 if armed and not motor_sound.playing:motor_sound.play()
 elif not armed and motor_sound.playing:motor_sound.stop()
 motor_sound.pitch_scale=0.72+0.75*clampf(thrust/MAX_THRUST,0,1)+velocity.length()*0.004
 motor_sound.volume_db=-1.0+linear_to_db(maxf(game.volume,0.0001))-(9.0 if piloting else 0.0)

# The body turns only about the vertical; the airframe leans in it, the
# camera rides on the airframe at its uptilt. Unpowered in the air it turns
# over, faster with a motor or a prop shot away.
func place_visuals() -> void:
 if not is_inside_tree():return
 global_basis=Basis(Vector3.UP,yaw)
 if (downed>0.0 or (not armed and launched())) and not grounded and is_physics_processing():
  model.rotate(spin_axis,get_physics_process_delta_time()*(7.0 if downed>0.0 else 2.5))
 else:model.basis=frame
 camera.transform=Transform3D(model.basis*Basis(Vector3.RIGHT,uptilt),model.basis*CAMERA_MOUNT)

# --- The end ----------------------------------------------------------------------
# Something met at speed: the warhead goes off if the initiation board armed
# it (under power it always does; falling, by the fuse's odds), or the drone
# breaks up there.
func strike(point: Vector3, direction: Vector3, collider: Object) -> void:
 if over:return
 if warhead_armed and (armed or rng.randf()<float(WARHEADS[warhead].fuse)):detonate(point,direction,collider)
 else:break_up()

func detonate(point: Vector3, direction: Vector3=Vector3.ZERO, collider: Object=null) -> void:
 if over:return
 if direction.length()<0.1:direction=velocity if velocity.length()>0.5 else -model.global_basis.z
 health=0.0;armed=false
 remove_from_group("drones")
 visible=false
 if impact_handler.is_valid():impact_handler.call(warhead,point,direction.normalized(),collider,self)
 finish("FPV-дрон: підрив боєголовки.")
 queue_free()

func default_impact(kind: String, point: Vector3, direction: Vector3, collider: Object, source: Node3D) -> void:
 var blasts: Node=game.get("blasts")
 if blasts==null:return
 if blasts.has_method("warhead"):blasts.warhead(kind,point,direction,collider,source)
 else:blasts.detonate(point,"rpo" if kind=="heat" else "mine")

# A dud or an unarmed warhead: the wreck lies where it came down a while.
func break_up() -> void:
 if over:return
 game.spatial_shot("bolt",global_position,-8)
 finish("FPV-дрон розбився, боєголовка не спрацювала.")
 velocity=Vector3.ZERO
 collision_layer=0
 wreck_left=WRECK_SECONDS

func finish(message: String) -> void:
 if over:return
 over=true;armed=false;health=0.0;state="gone";goal="";target=null;picker=Callable()
 remove_from_group("drones")
 if motor_sound!=null:motor_sound.stop()
 # Wrecked before it took off: out of the pack all the same.
 if pack_uid>=0 and is_instance_valid(operator):operator.backpack.remove(pack_uid)
 pack_uid=-1
 release_from_rig(message)
 announce()

# The player's goggles come off: the field rig takes its recon drone back.
func release_from_rig(message: String) -> void:
 if piloting:end_control()
 if is_instance_valid(operator) and operator.field_rig!=null and operator.field_rig.drone==self:
  operator.field_rig.fpv_gone(self,message)

var announced := false
func announce() -> void:
 if announced:return
 announced=true
 finished.emit(self)
 if on_finished.is_valid():
  if on_finished.get_argument_count()>=1:on_finished.call(self)
  else:on_finished.call()

func _exit_tree() -> void:
 close_goggles()
 if not over:
  over=true;state="gone"
  announce()

# The pilot took the goggles off or fell: the last attitude and throttle
# hold a moment, then the motors stop and it falls (no hover of its own).
func abandon() -> void:
 if over:return
 if piloting:end_control()
 hands_off=false
 goal="";target=null;picker=Callable()
 if armed and launched():coast_left=COAST_TIME
 state="falling"

# A 7-inch frame: the stack and the 6S pack on top, motors on 7-inch props
# at the ends of the arms, the warhead slung under it.
func airframe_parts() -> Dictionary:
 var motors: Array[Vector3]=[Vector3(-0.112,0.012,-0.112),Vector3(0.112,0.012,-0.112),Vector3(-0.112,0.012,0.112),Vector3(0.112,0.012,0.112)]
 var roots: Array[Vector3]=[]
 for motor in motors:roots.append(motor*0.25)
 var charge: Array=[Vector3(0,-0.062,-0.05),0.047,0.21] if warhead=="heat" else [Vector3(0,-0.05,-0.04),0.039,0.13]
 return {"body":[Vector3(0,0.03,0.005),Vector3(0.04,0.035,0.075)],"camera":[Vector3(0,0.016,-0.085),Vector3(0.015,0.015,0.012)],
  "motors":motors,"roots":roots,"motor_radius":0.019,"motor_height":0.016,"arm_radius":0.013,"prop_up":0.03,"prop_radius":0.089,"warhead":charge}

# Its whine is heard far over the battle.
func heard_within() -> float:return 150.0

# A rifle round through it, or fragments of a burst nearby: a 7-inch frame
# does not fly on with a motor or the pack hit; a broken arm or blade often
# brings it down too. A round into the warhead sets it off now and then
# once the board has armed it. It falls, and the warhead may still go off
# where it lands.
func receive_hit(amount: float, zone: String, incoming: Vector3, point: Vector3) -> void:
 if over or health<=0:return
 if zone=="drone":
  var part := struck_part(point,incoming)
  if part=="" or amount<4.0:return
  if part=="warhead":
   if warhead_armed and rng.randf()<0.25:detonate(global_position,velocity,null)
   return
  var fatal := part=="body" or part=="motor" or (part=="arm" and rng.randf()<0.5) or (part=="prop" and rng.randf()<0.4)
  health=0.0 if fatal else maxf(0.0,health-0.5)
  if health>0:
   hit_part=part;hit_notice=3.0
   notice="FPV УРАЖЕНО: %s" % PART_NAMES.get(part,part)
   return
 else:
  health=maxf(0,health-amount/25.0)
  if health>0:return
 armed=false;coast_left=0.0
 if launched() and not grounded:
  downed=0.001;state="falling";goal=""
  spin_axis=Vector3(rng.randf_range(-1,1),rng.randf_range(-0.3,0.3),rng.randf_range(-1,1)).normalized()
  notice="ДРОН ЗБИТО"
  if is_instance_valid(operator) and operator.field_rig!=null and operator.field_rig.drone==self:operator.field_rig.drone_notice="FPV-дрон збито."
  game.spatial_shot("bolt",global_position,-4)
  GradEffects.shared(game).puff(global_position,0.6,0.35,Vector3(0,-0.4,0))
 else:break_up()

# --- Bot pilot --------------------------------------------------------------------
# An attack run: climb to 25–40 m (35–55 m on a vehicle), cruise toward the
# target, slow down near the dive point, then a terminal dive with lead on a
# moving target — steep (30–60°) on a vehicle, onto the top and the rear.
func autopilot(on: Node3D) -> void:
 if over or on==null or not is_instance_valid(on):return
 target=on;goal="target"
 var vehicle := on.is_in_group("vehicles")
 if aim_offset==Vector3.INF:aim_offset=choose_aim(on)
 if not diving:
  cruise_alt=rng.randf_range(35.0,55.0) if vehicle else rng.randf_range(25.0,40.0)
  dive_angle=deg_to_rad(rng.randf_range(32.0,58.0) if vehicle else rng.randf_range(18.0,28.0))
 goal_point=target_point()
 take_off()

# The same at a point (a position, the last place of a target that is gone).
func autopilot_point(point: Vector3) -> void:
 if over:return
 target=null;goal="point";goal_point=point
 if not diving:
  cruise_alt=rng.randf_range(25.0,40.0)
  dive_angle=deg_to_rad(rng.randf_range(18.0,28.0))
 take_off()

# Find a target in an area: fly there at 30–60 m, then lazy figure-eights over
# it at 15–20 m/s, looking ahead and down through the camera every 0.4 s:
# pick.call(drone_position, max_range) -> Node3D names the best target seen
# from there (or null); one in the camera's cone and in sight gets the attack
# run. With the battery near its reserve it dives on the centre of the area.
func search_area(center: Vector3, radius: float, pick: Callable) -> void:
 if over:return
 goal="search";target=null;diving=false
 search_center=center;search_radius=maxf(radius,20.0);picker=pick
 cruise_alt=rng.randf_range(30.0,60.0)
 search_speed=rng.randf_range(15.0,20.0)
 pattern_axis=rng.randf_range(0,TAU);pattern_phase=rng.randf_range(0,TAU)
 state="transit"
 take_off()

func take_off() -> void:
 if not armed and not launched() and battery>0 and health>0 and not failsafe:armed=true
 if state in ["ground","manual"]:state="transit"

# Spots a crew aims an FPV at on a vehicle (frame: -Z forward, ground at 0).
func choose_aim(on: Node3D) -> Vector3:
 if not on.is_in_group("vehicles"):return Vector3(0,0.9,0) if on is CharacterBody3D else Vector3.ZERO
 var spots: Array[Vector3]
 if on is GradVehicle:
  # Rocket package, cab roof, engine under the bonnet, fuel tanks by the cab.
  spots=[Vector3(0,2.5,1.25),Vector3(0,2.55,-1.4),Vector3(0,1.95,-2.85),Vector3(1.1,1.35,-1.0),Vector3(-1.1,1.35,-1.0)]
 elif on is BmpVehicle:
  # Engine deck (front right), rear doors, side over the track, turret ring
  # from behind, roof over the troop compartment.
  spots=[Vector3(0.5,1.3,-1.9),Vector3(0.45,1.2,3.25),Vector3(1.48,1.3,0.8),Vector3(-1.48,1.3,0.8),Vector3(0,1.75,0.55),Vector3(0,1.58,1.8)]
 elif on is TosVehicle:
  # TOS-1A: the package's sides and breech end, the engine deck at the
  # rear, the platform roof by the sights.
  spots=[Vector3(1.15,2.4,-0.6),Vector3(-1.15,2.4,-0.6),Vector3(0,2.3,1.3),Vector3(0,1.55,2.0),Vector3(-0.6,2.1,-0.7)]
 else:spots=[Vector3(0,1.2,0)]
 return spots[rng.randi()%spots.size()]

func target_point() -> Vector3:
 if is_instance_valid(target):return target.global_transform*(aim_offset if aim_offset!=Vector3.INF else Vector3.ZERO)
 return goal_point

func target_velocity() -> Vector3:
 if not is_instance_valid(target):return Vector3.ZERO
 var moving: Variant=target.get("linear_velocity")
 if moving is Vector3:return moving
 moving=target.get("velocity")
 return moving if moving is Vector3 else Vector3.ZERO

func is_target(collider: Object) -> bool:
 return is_instance_valid(target) and collider is Node and (collider==target or target.is_ancestor_of(collider))

# Desired velocity for this step.
func guide(delta: float) -> Vector3:
 if goal=="target":
  if not is_instance_valid(target) or target.get("destroyed")==true or target.get("dead")==true:
   var last := goal_point
   aim_offset=Vector3.INF
   autopilot_point(last)
  else:goal_point=target_point()
 if goal=="search":return search_guide(delta)
 return attack_guide(delta)

func attack_guide(delta: float) -> Vector3:
 var moving := target_velocity()
 var closing := maxf(10.0,velocity.length())
 var predicted := goal_point
 for i in range(2):predicted=goal_point+moving*(global_position.distance_to(predicted)/closing)
 var flat := Vector2(predicted.x-global_position.x,predicted.z-global_position.z)
 var height := global_position.y-predicted.y
 var vehicle := is_instance_valid(target) and target.is_in_group("vehicles")
 var start := maxf(height,1.0)/tan(dive_angle)
 if not vehicle:start=clampf(start,60.0,100.0)
 if not diving and launched() and flight_time>2.0 and (flat.length()<=start+2.0 or flat.length()<6.0) and height>2.0:begin_dive(moving)
 if diving:
  state="attack"
  var aim := predicted+miss_offset
  if global_position.distance_to(aim)<0.7:
   # Right on it and nothing met: the pilot sets it off.
   var hit := ray(global_position,global_position+velocity.normalized()*3.0,1|2|4|8)
   if not hit.is_empty():strike(hit.position,velocity.normalized(),hit.collider)
   else:detonate(global_position,velocity,null)
   return Vector3.ZERO
  return global_position.direction_to(aim)*TOP_SPEED
 state="transit"
 var direction := Vector3(flat.x,0,flat.y).normalized() if flat.length()>0.5 else Vector3.ZERO
 # Slow down coming up to the dive point to tip over into it.
 var speed := lerpf(9.0,CRUISE_SPEED,clampf((flat.length()-start)/70.0,0.0,1.0))
 return cruise(direction,speed,maxf(float(game.district.ground_height(global_position)),predicted.y),delta)

func begin_dive(moving: Vector3) -> void:
 diving=true;state="attack"
 var chance := miss_chance if miss_chance>=0.0 else 0.10+0.15*clampf(moving.length()/10.0,0.0,1.0)
 var side := Vector2.from_angle(rng.randf_range(0,TAU))
 var off := side*(rng.randf_range(2.5,6.0) if rng.randf()<chance else rng.randf_range(0.0,0.3))
 miss_offset=Vector3(off.x,0,off.y)

# Level flight at the cruise height over the ground (and over the roofs),
# with a climb away from whatever stands ahead.
func cruise(direction: Vector3, speed: float, base_y: float, delta: float) -> Vector3:
 var wanted := direction*speed
 wanted.y=clampf((base_y+cruise_alt-global_position.y)*0.6,-5.0,7.0)
 if floor_height<minf(12.0,cruise_alt*0.5):wanted.y=maxf(wanted.y,5.0)
 if flight_time<4.0 and floor_height<8.0:wanted=direction*1.5+Vector3.UP*7.0
 probe_clock-=delta
 if probe_clock<=0.0 and direction!=Vector3.ZERO:
  probe_clock=0.15
  var reach := maxf(14.0,velocity.length()*2.5)
  for down in [0.0,0.35]:
   var hit := ray(global_position,global_position+(direction+Vector3.DOWN*down).normalized()*reach,1)
   if not hit.is_empty() and not is_target(hit.collider):avoid_left=0.7
 avoid_left-=delta
 if avoid_left>0.0:wanted=Vector3(wanted.x*0.25,9.0,wanted.z*0.25)
 return wanted

func search_guide(delta: float) -> Vector3:
 if battery<SEARCH_RESERVE:
  autopilot_point(Vector3(search_center.x,float(game.district.ground_height(search_center)),search_center.z))
  return attack_guide(delta)
 var ground := float(game.district.ground_height(search_center))
 var to_center := Vector2(search_center.x-global_position.x,search_center.z-global_position.z)
 if state=="transit" and to_center.length()>search_radius*0.6+20.0:
  return cruise(Vector3(to_center.x,0,to_center.y).normalized(),CRUISE_SPEED,ground,delta)
 state="search"
 var size := clampf(search_radius*0.7,25.0,160.0)
 pattern_phase+=delta*search_speed/(size*1.25)
 pattern_axis+=delta*0.02
 var lead := Vector2(size*sin(pattern_phase+0.45),size*0.5*sin(2.0*(pattern_phase+0.45))).rotated(pattern_axis)
 var carrot := Vector2(search_center.x,search_center.z)+lead
 var toward := carrot-Vector2(global_position.x,global_position.z)
 var wanted := cruise(Vector3(toward.x,0,toward.y).normalized(),search_speed,ground,delta)
 look_clock-=delta
 if look_clock<=0.0:
  look_clock=0.4
  look()
 return wanted

func look() -> void:
 if not picker.is_valid():return
 var found: Variant=picker.call(global_position,SEARCH_RANGE)
 if typeof(found)!=TYPE_OBJECT or not is_instance_valid(found) or not (found is Node3D):return
 var candidate: Node3D=found
 if candidate.get("destroyed")==true or candidate.get("dead")==true:return
 var offset := aim_offset if aim_offset!=Vector3.INF else choose_aim(candidate)
 if not sees(candidate.global_transform*offset,candidate):return
 aim_offset=offset
 autopilot(candidate)

# In the search camera's cone, in range and in sight from the drone.
func sees(point: Vector3, who: Node3D=null) -> bool:
 var eye := camera.global_position
 var to := point-eye
 if to.length()>SEARCH_RANGE or to.length()<0.5:return false
 var axis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-SEARCH_LOOK_DOWN)*Vector3.FORWARD
 if axis.dot(to.normalized())<SEARCH_CONE_COS:return false
 var hit := ray(eye,point,1)
 if not hit.is_empty() and not (who!=null and hit.collider is Node and (hit.collider==who or who.is_ancestor_of(hit.collider))):return false
 if game.district.has_method("foliage_visibility") and float(game.district.foliage_visibility(eye,point))<=0.0:return false
 return true

# Desired velocity into attitude and thrust: thrust only along the frame.
# Cruising, the same angle-mode lean of 50° at most as the player's; in the
# terminal dive the pilot flips it over (acro), as far as inverted, thrust
# driving it down the line instead of the drone just falling under it.
func steer(wanted: Vector3, delta: float) -> void:
 var need := (wanted-velocity)*1.8+velocity*velocity.length()*DRAG+Vector3.UP*G
 if not diving:
  need.y=maxf(need.y,0.15*G)
  var level := Vector2(need.x,need.z)
  var most := need.y*tan(BOOST_TILT)
  if level.length()>most:level=level.normalized()*most
  need=Vector3(level.x,need.y,level.y)
 cmd_thrust=minf(need.length(),MAX_THRUST)
 # The nose along the way it goes: braking it pitches back, diving it
 # points down the line at the target.
 var heading := Vector2(wanted.x,wanted.z)
 if heading.length()<1.0 and not diving:heading=Vector2(need.x,need.z)
 if heading.length()>0.5:
  var turn := wrapf(atan2(-heading.x,-heading.y)-yaw,-PI,PI)
  yaw+=clampf(turn,-3.0*delta,3.0*delta)
 var local := Basis(Vector3.UP,yaw).inverse()*need.normalized()
 cmd_frame=Basis(Vector3.RIGHT,PI) if local.y<-0.9999 else Basis(Quaternion(Vector3.UP,local))
 cmd_pitch=atan2(-local.z,local.y);cmd_roll=asin(clampf(local.x,-1.0,1.0))
