class_name DroneFeed
extends Control

# Wrist display of the recon drone: the drone camera's picture while the
# operator is not wearing the goggles (hovering over a target, adjusting mortar
# fire from the sight). A second, small render of the same world at a reduced
# frame rate; nothing is rendered while the display is hidden.
const FEED_SIZE := Vector2i(400,250)
const FEED_RATE := 15.0
var game: Node3D
var enabled := true
var feed: SubViewport
var eye: Camera3D
var screen: TextureRect
var header: Label
var telemetry: Label
var static_noise: ColorRect
var clock := 0.0

func setup(owner_game: Node3D, parent: Control) -> void:
 game=owner_game
 game.place(self,parent,0.012,0.44,0.305,0.855)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 # The rugged case with its strap, as worn on the forearm.
 for y in [0.0,1.0]:
  var strap := ColorRect.new();strap.color=Color("2b2f25");strap.mouse_filter=Control.MOUSE_FILTER_IGNORE
  add_child(strap)
  strap.anchor_left=0.30;strap.anchor_right=0.70;strap.anchor_top=y;strap.anchor_bottom=y
  strap.offset_top=-12 if y==0.0 else 0;strap.offset_bottom=0 if y==0.0 else 12
 var case := PanelContainer.new();case.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style := StyleBoxFlat.new();style.bg_color=Color("1a1d17");style.border_color=Color("4a5040")
 style.set_border_width_all(3);style.set_corner_radius_all(9)
 style.content_margin_left=9;style.content_margin_right=9;style.content_margin_top=6;style.content_margin_bottom=7
 case.add_theme_stylebox_override("panel",style)
 add_child(case);case.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var rows := VBoxContainer.new();rows.add_theme_constant_override("separation",3);case.add_child(rows)
 header=game.label("",12,Color("9fc29a"));rows.add_child(header)
 var frame := Control.new();frame.size_flags_vertical=Control.SIZE_EXPAND_FILL;frame.clip_contents=true
 frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;rows.add_child(frame)
 feed=SubViewport.new();feed.size=FEED_SIZE;feed.own_world_3d=false
 feed.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(feed)
 eye=Camera3D.new();eye.fov=95;eye.near=0.03;eye.far=650;eye.current=true
 feed.add_child(eye)
 screen=TextureRect.new();screen.texture=feed.get_texture()
 screen.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;screen.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
 frame.add_child(screen);screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 static_noise=ColorRect.new();static_noise.mouse_filter=Control.MOUSE_FILTER_IGNORE
 frame.add_child(static_noise);static_noise.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 telemetry=game.label("",12,Color("c9d4bd"));rows.add_child(telemetry)
 hide()

func drone() -> ReconDrone:
 if not is_instance_valid(game.player):return null
 var rig: FieldRig=game.player.field_rig
 if rig==null or not is_instance_valid(rig.drone):return null
 return rig.drone

func toggle() -> void:
 enabled=not enabled
 var unit := drone()
 if unit!=null and is_instance_valid(game.player):
  game.player.field_rig.drone_notice="Наручний екран: %s." % ("увімкнено" if enabled else "вимкнено")

# Shown while a drone is out and the operator sees with his own eyes.
func wanted() -> bool:
 var unit := drone()
 return enabled and unit!=null and not unit.piloting and game.running and not game.paused and unit.health>0 and game.player.field_rig.mode!="goggles"

func _process(delta: float) -> void:
 if not is_instance_valid(game):return
 var show_feed := wanted()
 if visible!=show_feed:
  visible=show_feed
  feed.render_target_update_mode=SubViewport.UPDATE_ONCE if show_feed else SubViewport.UPDATE_DISABLED
 if not show_feed:return
 var unit := drone()
 eye.global_transform=unit.camera.global_transform
 eye.cull_mask=unit.camera.cull_mask
 # A reduced frame rate keeps the second render cheap in a large battle.
 clock-=delta
 if clock<=0:
  clock=1.0/FEED_RATE
  feed.render_target_update_mode=SubViewport.UPDATE_ONCE
 var lost := unit.signal_strength<0.04
 var weak := clampf(1-unit.signal_strength/0.3,0,1)
 static_noise.color=Color(0.55,0.58,0.52,1.0 if lost else weak*0.45*(0.6+0.4*randf()))
 header.text="РОЗВІДДРОН · КАНАЛ 1%s · U — СХОВАТИ" % ("" if unit.armed else " · НА ЗЕМЛІ")
 var minutes := unit.battery*ReconDrone.FLIGHT_SECONDS/60.0
 var bearing := MortarBallistics.mils_text(MortarBallistics.azimuth(-unit.camera.global_basis.z))
 telemetry.text="АКБ %d %% ≈%d хв · ЗВ’ЯЗОК %d %% · %s\nВИСОТА %.0f м · АЗ %s · ДО ДРОНА %.0f м" % [roundi(unit.battery*100),floori(minutes),roundi(unit.signal_strength*100),"НЕМАЄ СИГНАЛУ" if lost else ("ПОСАДКА" if unit.battery<=0.04 else "ЗАВИС"),unit.floor_height,bearing,unit.global_position.distance_to(game.player.global_position)]
