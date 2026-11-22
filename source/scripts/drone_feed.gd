class_name DroneFeed
extends Control

# Wrist display of the recon drone: the drone camera's picture while the
# operator is not wearing the goggles (hovering over a target, adjusting mortar
# fire from the sight). A second, small render of the same world at a reduced
# frame rate; nothing is rendered while the display is hidden.
# In the great assault the same tablet shows the battery's fire before the
# assault: two live pictures, the three «Grads» on their firing position and
# the whole village from the observation post's drone with the strongpoints
# marked. They go when the order «По машинах!» comes; then the tablet is the
# drone's display again, if a drone is up. While the battery is on the screen
# its small speaker gives the sound from the camera by the launchers: the
# engines idling and every launch, a little after the picture (the camera is
# some ninety metres off), narrow, clipped and compressed.
const FEED_SIZE := Vector2i(400,250)
const FEED_RATE := 15.0
const SMALL := [0.012,0.44,0.305,0.855]
const LARGE := [0.012,0.30,0.345,0.865]
# In the driver's seat the instruments take the lower left: the tablet goes right.
const LARGE_RIGHT := [0.655,0.30,0.988,0.865]
const BARRAGE_WIDTH := 560
var game: Node3D
var enabled := true
# The battery whose fire the tablet last opened for: a new battle's barrage
# opens it again even if it was switched off (U) in an earlier match.
var announced: GradBattery
var feed: SubViewport
var eye: Camera3D
var screen: TextureRect
var header: Label
var telemetry: Label
var static_noise: ColorRect
var village_feed: SubViewport
var village_eye: Camera3D
var village_screen: TextureRect
var village_header: Label
var village_frame: Control
var marks: Control
var clock := 0.0
var turn := 0
var speaker_bus := ""
var speakers: Array[AudioStreamPlayer]=[]
var speaker_index := 0
var engine_speaker: AudioStreamPlayer
var relay_clock := 0.0
var last_relay := -10.0
# Launches the speaker has given in this match (the tests read it).
var relayed := 0
# "" (hidden), "drone" or "barrage".
var mode := ""
var on_right := false

func setup(owner_game: Node3D, parent: Control) -> void:
 game=owner_game
 game.place(self,parent,SMALL[0],SMALL[1],SMALL[2],SMALL[3])
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
 var frame := picture(rows)
 feed=SubViewport.new();feed.size=FEED_SIZE;feed.own_world_3d=false
 feed.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(feed)
 eye=Camera3D.new();eye.fov=95;eye.near=0.03;eye.far=650;eye.current=true
 feed.add_child(eye)
 screen=screen_for(feed,frame)
 static_noise=ColorRect.new();static_noise.mouse_filter=Control.MOUSE_FILTER_IGNORE
 frame.add_child(static_noise);static_noise.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 village_header=game.label("",12,Color("9fc29a"));rows.add_child(village_header)
 village_frame=picture(rows)
 village_feed=SubViewport.new();village_feed.size=FEED_SIZE;village_feed.own_world_3d=false
 village_feed.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(village_feed)
 village_eye=Camera3D.new();village_eye.fov=30;village_eye.near=1.0;village_eye.far=2500;village_eye.current=true;village_eye.cull_mask=1
 village_feed.add_child(village_eye)
 village_screen=screen_for(village_feed,village_frame)
 marks=Control.new();marks.mouse_filter=Control.MOUSE_FILTER_IGNORE
 village_frame.add_child(marks);marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 marks.draw.connect(draw_marks)
 telemetry=game.label("",12,Color("c9d4bd"));rows.add_child(telemetry)
 village_header.hide();village_frame.hide()
 setup_speaker()
 hide()

func setup_speaker() -> void:
 speaker_bus="Tablet_%d" % get_instance_id()
 AudioServer.add_bus()
 var bus:=AudioServer.bus_count-1
 AudioServer.set_bus_name(bus,speaker_bus)
 var low:=AudioEffectHighPassFilter.new();low.cutoff_hz=380
 var high:=AudioEffectLowPassFilter.new();high.cutoff_hz=4300
 var drive:=AudioEffectDistortion.new();drive.mode=AudioEffectDistortion.MODE_OVERDRIVE
 drive.drive=0.3;drive.pre_gain=-2.0;drive.post_gain=-3.0;drive.keep_hf_hz=7000
 var squeeze:=AudioEffectCompressor.new();squeeze.threshold=-20.0;squeeze.ratio=6.0;squeeze.gain=9.0;squeeze.attack_us=200;squeeze.release_ms=120
 for effect in [low,high,drive,squeeze]:AudioServer.add_bus_effect(bus,effect)
 # The player's own ears come after the speaker: deafened by a burst, he
 # hears it dulled too.
 AudioServer.set_bus_send(bus,game.hearing.bus_name)
 for i in range(8):
  var output:=AudioStreamPlayer.new();output.bus=speaker_bus;add_child(output);speakers.append(output)
 engine_speaker=AudioStreamPlayer.new();engine_speaker.bus=speaker_bus;engine_speaker.stream=GradAudio.engine()
 add_child(engine_speaker)

func _exit_tree() -> void:
 var bus:=AudioServer.get_bus_index(speaker_bus)
 if bus>0:AudioServer.remove_bus(bus)

func picture(rows: Control) -> Control:
 var frame := Control.new();frame.size_flags_vertical=Control.SIZE_EXPAND_FILL;frame.clip_contents=true
 frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;rows.add_child(frame)
 return frame

func screen_for(viewport: SubViewport, frame: Control) -> TextureRect:
 var rect := TextureRect.new();rect.texture=viewport.get_texture()
 rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
 frame.add_child(rect);rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 return rect

func drone() -> ReconDrone:
 if not is_instance_valid(game.player):return null
 var rig: FieldRig=game.player.field_rig
 if rig==null or not is_instance_valid(rig.drone):return null
 return rig.drone

func battery() -> GradBattery:
 var battle: BattleMode=game.battle
 return battle.battery if battle.active and battle.barrage_shown() else null

func toggle() -> void:
 enabled=not enabled
 var unit := drone()
 if unit!=null and is_instance_valid(game.player):
  game.player.field_rig.drone_notice="Наручний екран: %s." % ("увімкнено" if enabled else "вимкнено")

# What the display shows now: the battery's fire before the assault, or the
# drone's picture while it is out and the operator sees with his own eyes.
func wanted_mode() -> String:
 var unit_battery := battery()
 if unit_battery!=null and unit_battery!=announced:
  announced=unit_battery
  enabled=true
 if not enabled or not game.running or game.paused or not is_instance_valid(game.player):return ""
 var goggles: bool=game.player.field_rig.mode=="goggles"
 # The driver sees it in his seat too; a passenger is not in the vehicle yet.
 if battery()!=null and not goggles and game.bmp.seat!="troop":return "barrage"
 var unit := drone()
 if unit!=null and unit.shows_on_wrist() and not unit.piloting and unit.health>0 and not goggles:return "drone"
 return ""

func wanted() -> bool:return wanted_mode()!=""

func switch(next: String) -> void:
 mode=next
 if next!="barrage":
  engine_speaker.stop()
  for output in speakers:output.stop()
 visible=next!=""
 place_box()
 village_header.visible=next=="barrage";village_frame.visible=next=="barrage"
 static_noise.visible=next=="drone"
 if next=="barrage":
  eye.fov=34;eye.near=0.5;eye.far=4000;eye.cull_mask=1
  screen.stretch_mode=TextureRect.STRETCH_SCALE
  village_screen.stretch_mode=TextureRect.STRETCH_SCALE
 else:
  feed.size=FEED_SIZE
  eye.fov=95;eye.near=0.03;eye.far=650
  screen.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 feed.render_target_update_mode=SubViewport.UPDATE_ONCE if next!="" else SubViewport.UPDATE_DISABLED
 village_feed.render_target_update_mode=SubViewport.UPDATE_ONCE if next=="barrage" else SubViewport.UPDATE_DISABLED
 clock=0.0

# A picture of the frame's own shape, so the strongpoint marks fall where the
# render shows them.
static func fit(frame: Vector2) -> Vector2i:
 if frame.x<8 or frame.y<8:return FEED_SIZE
 var width:=mini(BARRAGE_WIDTH,int(frame.x))
 return Vector2i(width,maxi(8,int(width*frame.y/frame.x)))

func _process(delta: float) -> void:
 if not is_instance_valid(game):return
 relay_clock+=delta
 if not game.running:relayed=0
 for output in speakers:output.stream_paused=game.paused
 engine_speaker.stream_paused=game.paused
 var next := wanted_mode()
 if next!=mode:switch(next)
 if mode=="":return
 if mode=="barrage":
  if (game.bmp.seat=="driver")!=on_right:place_box()
  show_barrage(delta)
  return
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

func place_box() -> void:
 on_right=mode=="barrage" and game.bmp.seat=="driver"
 var box: Array=(LARGE_RIGHT if on_right else LARGE) if mode=="barrage" else SMALL
 anchor_left=box[0];anchor_top=box[1];anchor_right=box[2];anchor_bottom=box[3]

func show_barrage(delta: float) -> void:
 var unit:=battery()
 eye.global_transform=unit.battery_view()
 village_eye.global_transform=unit.village_view()
 var size:=fit(screen.size)
 if feed.size!=size:feed.size=size
 size=fit(village_screen.size)
 if village_feed.size!=size:village_feed.size=size
 # The two pictures take turns: each at the drone display's rate.
 clock-=delta
 if clock<=0:
  clock=0.5/FEED_RATE
  turn=(turn+1)%2
  var target: SubViewport=feed if turn==0 else village_feed
  target.render_target_update_mode=SubViewport.UPDATE_ONCE
 engine_hum(unit)
 header.text="КПК · «ГРАДИ» НА ВОГНЕВІЙ ПОЗИЦІЇ · НАЖИВО · U — СХОВАТИ"
 village_header.text="СЕЛО · ДРОН СПОСТЕРЕЖНОГО ПУНКТУ · ОП-1…3"
 var fired:=unit.fired()
 if not unit.ordered:
  telemetry.text="«ГРАДИ»: ГОТОВІ %d/3 · НАВОДЯТЬСЯ %d\nЦІЛІ: ОП-1, ОП-2, ОП-3 — ПО ОДНІЙ МАШИНІ НА ОП" % [unit.ready_count(),unit.laying_count()]
 elif not unit.finished():
  telemetry.text="ЗАЛП · ПУЩЕНО РАКЕТ %d/%d · У ПОВІТРІ %d\nЧЕКАЙ КОМАНДИ" % [fired,unit.launchers.size()*40,unit.in_flight()]
 else:
  telemetry.text="ЗАЛП ЗАВЕРШЕНО · ПУЩЕНО %d РАКЕТ\nЧЕКАЙ КОМАНДИ" % fired
 marks.queue_redraw()

# --- The speaker ---------------------------------------------------------------
# The engines of the battery at idle, as loud as the number running.
func engine_hum(unit: GradBattery) -> void:
 var running:=0
 for vehicle in unit.launchers:
  if is_instance_valid(vehicle) and vehicle.running:running+=1
 if running==0 or game.volume<=0:
  engine_speaker.stop()
  return
 engine_speaker.volume_db=linear_to_db(game.volume)-17.0+linear_to_db(float(running)/3.0)
 if not engine_speaker.playing:engine_speaker.play()

# A launch of a battery vehicle (GradVehicle.play_launch) while the tablet
# shows it.
func relay_launch(vehicle: GradVehicle, at: Vector3, last: bool) -> void:
 if mode!="barrage":return
 var unit:=battery()
 if unit==null or not vehicle in unit.launchers:return
 # Three launchers ripple two rockets a second each: one speaker voice in
 # a tenth of a second is the most the little speaker makes out.
 if relay_clock-last_relay<0.1 and not last:return
 last_relay=relay_clock
 relayed+=1
 if game.volume<=0:return
 var distance:=eye.global_position.distance_to(at)
 var clip:=GradAudio.clip("launch_tail" if last else "launch_close")
 var db:=linear_to_db(game.volume)+2.0-20.0*log(maxf(distance,30.0)/90.0)/log(10.0)
 var pitch:=randf_range(0.95,1.05)
 get_tree().create_timer(distance/343.0,false).timeout.connect(func():
  if mode!="barrage":return
  var output:=speakers[speaker_index]
  speaker_index=(speaker_index+1)%speakers.size()
  output.stream=clip
  output.volume_db=db
  output.pitch_scale=pitch
  output.play())

# The strongpoints over the village picture; a destroyed one struck through.
func draw_marks() -> void:
 if mode!="barrage" or not game.battle.active:return
 var font:=ThemeDB.fallback_font
 var scale:=marks.size/Vector2(village_feed.size)
 for i in range(3):
  var point: Vector3=game.battle.center(i)+Vector3.UP*6.0
  if village_eye.is_position_behind(point):continue
  var at:=village_eye.unproject_position(point)*scale
  var cleared: bool=game.battle.cleared[i]
  var tint:=Color(0.75,0.75,0.7,0.9) if cleared else Color(1.0,0.32,0.25,0.95)
  marks.draw_arc(at,9.0,0,TAU,20,tint,2.0)
  marks.draw_string(font,at+Vector2(11,5),"ОП-%d" % (i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,tint)
  if cleared:marks.draw_line(at+Vector2(-10,-10),at+Vector2(10,10),tint,2.0)
