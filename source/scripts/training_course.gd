class_name TrainingCourse
extends Control

# «Навчання»: what every course shares. A card names the step and its keys and
# shows a live readout, a banner marks the end of a chapter, a marker on the
# scene shows where to go, F6 does the step for the player, finished chapters
# are kept per course. A course says what its chapters and steps are, how a
# step is checked and done, and how the field looks when a chapter is started
# on its own.
const CARD_WIDTH := 410.0
var card_box: VBoxContainer
var game: Node3D
var running := false
var chapter := 0
var step := 0
var start_chapter := 0
var skipped := 0
var clock := 0.0
var step_clock := 0.0
var preparing := 0.0
var acked := false
var flash := 0.0
var done_title := ""
# "full" at the top right; "console" without the chapter line and footer;
# "compact" (title, keys, readout) at the bottom right, "compact_left" at the
# bottom left, over panels the player has to read.
var layout := ""
var banner_left := 0.0
var finished_chapters: Array[int]=[]
var card: PanelContainer
var card_style: StyleBoxFlat
var head: Label
var chapter_label: Label
var title: Label
var body: Label
var keys_holder: VBoxContainer
var readout: Label
var progress_bar: Control
var footer: Label
var banner: VBoxContainer
var banner_title: Label
var banner_sub: Label

# --- What a course defines -------------------------------------------------
func course_id() -> String:return ""
func course_title() -> String:return ""
func course_role() -> String:return ""
func chapters() -> Array:return []
func steps() -> Array:return []
# Class, weapons, backpack and map the course borrows for its run.
func loadout() -> Dictionary:return {}
func loading_tip() -> String:return "Противника немає. Картка кроку — праворуч угорі; F6 — виконати крок автоматично."
func death_text() -> String:return "Боєць вибув. Почни розділ знову."
func preparing_text() -> String:return "Готуємо місце розділу."
func prepare(_index: int) -> void:pass
func on_begin() -> void:pass
func on_stop() -> void:pass
func on_finish() -> void:pass
func on_prepared() -> void:pass
func on_enter(_id: String) -> void:pass
func before_advance(_id: String) -> void:pass
func tick(_delta: float) -> void:pass
func check(_id: String) -> bool:return false
func auto(_id: String) -> void:pass
func readout_text(_id: String) -> String:return ""
func body_text(s: Dictionary) -> String:return s.get("text","")
func can_skip(_id: String) -> bool:return true
func refuse_skip(_id: String) -> void:pass
func marker() -> Dictionary:return {}
func markers_hidden() -> bool:return false
func layout_mode() -> String:return "full"
func result_lines() -> Array[String]:return []
func objective_text() -> String:
 return "НАВЧАННЯ · %s\n%s · РОЗДІЛ %d / %d" % [course_title(),game.district.map_title,chapter+1,chapters().size()]
func ground(point: Vector3) -> Vector3:return Vector3(point.x,game.district.ground_height(point),point.z)

# --- Progress ------------------------------------------------------------------
static func progress(owner_game: Node3D, id: String) -> Array:
 return owner_game.settings.get_value("training",id,[])

func done_chapters() -> Array:return progress(game,course_id())

func record(index: int) -> void:
 var list:Array=done_chapters().duplicate()
 if index not in list:list.append(index);list.sort()
 game.settings.set_value("training",course_id(),list)
 if not game.get_meta("automated_preview",false):game.settings.save("user://settings.cfg")

# --- Card ------------------------------------------------------------------------
func setup(owner_game: Node3D, ui_root: Control) -> void:
 game=owner_game
 name=course_id().capitalize()+"Training"
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 game.place(self,ui_root,0,0,1,1)
 theme=UiKit.theme()
 card=PanelContainer.new()
 card_style=UiKit.flat(Color(0.03,0.045,0.038,0.9),UiKit.ACCENT,0,4)
 card_style.content_margin_left=20;card_style.content_margin_right=18
 card_style.content_margin_top=14;card_style.content_margin_bottom=14
 card.add_theme_stylebox_override("panel",card_style)
 card.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(card)
 card.anchor_left=1;card.anchor_right=1;card.anchor_top=0;card.anchor_bottom=0
 card.offset_left=-470;card.offset_right=-22;card.offset_top=22;card.offset_bottom=22
 card.grow_horizontal=Control.GROW_DIRECTION_BEGIN
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",5)
 box.custom_minimum_size.x=CARD_WIDTH;card.add_child(box);card_box=box
 head=UiKit.text("",13,UiKit.ACCENT,"head");box.add_child(head)
 head.clip_text=true;head.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;head.custom_minimum_size.x=10
 chapter_label=UiKit.text("",12,UiKit.MUTED,"head");box.add_child(chapter_label)
 title=UiKit.text("",27,UiKit.INK,"display");title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(title)
 body=UiKit.wrapped("",15,UiKit.SOFT);box.add_child(body)
 keys_holder=VBoxContainer.new();box.add_child(keys_holder)
 readout=UiKit.wrapped("",16,UiKit.ACCENT);readout.add_theme_font_override("font",UiKit.font("head"));box.add_child(readout)
 progress_bar=Control.new();progress_bar.custom_minimum_size.y=12;box.add_child(progress_bar)
 progress_bar.draw.connect(draw_progress)
 footer=UiKit.text("F6 — ПРОПУСТИТИ КРОК   ·   ESC — ПАУЗА",11,UiKit.FAINT,"head");box.add_child(footer)
 banner=VBoxContainer.new();banner.alignment=BoxContainer.ALIGNMENT_CENTER
 banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
 game.place(banner,self,0.1,0.36,0.9,0.56)
 banner_title=UiKit.text("",64,UiKit.INK,"display");banner_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;banner.add_child(banner_title)
 banner_sub=UiKit.text("",18,UiKit.ACCENT,"head");banner_sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;banner.add_child(banner_sub)
 banner.hide()
 hide()

# --- Course -----------------------------------------------------------------
func begin(index: int) -> void:
 start_chapter=clampi(index,0,chapters().size()-1)
 chapter=start_chapter;step=0;skipped=0;clock=0;flash=0;banner_left=0;banner.hide()
 acked=false;preparing=0;finished_chapters.clear()
 on_begin()
 running=true
 prepare(chapter)
 enter_step()
 show()

# Also after a finished course: its targets stay up on the results screen.
func stop() -> void:
 running=false;banner_left=0;banner.hide()
 on_stop()
 hide()

func current() -> Dictionary:
 return steps()[chapter][step] if running and chapter<steps().size() and step<steps()[chapter].size() else {}

func flat_distance(a: Vector3, b: Vector3) -> float:return Vector2(a.x-b.x,a.z-b.z).length()

# --- Steps ---------------------------------------------------------------
func enter_step() -> void:
 step_clock=0;acked=false
 var s:=current()
 if s.is_empty():return
 on_enter(s.id)
 refresh_card(true)

func skip() -> void:
 var s:=current()
 if s.is_empty() or preparing>0:return
 if not can_skip(s.id):refuse_skip(s.id);return
 skipped+=1
 auto(s.id)
 after_auto(s.id)

# After F6 has done the step; a course may wait for what it started.
func after_auto(_id: String) -> void:advance(false)

func advance(by_player: bool=true) -> void:
 var s:=current()
 if s.is_empty():return
 before_advance(s.id)
 flash=0.9 if by_player else 0.4
 done_title=s.title
 if by_player:game.sound("click",-10)
 step+=1
 if step>=steps()[chapter].size():
  finished_chapters.append(chapter);record(chapter)
  if chapter+1>=chapters().size():finish();return
  chapter+=1;step=0;game.training_chapter=chapter
  banner_title.text="РОЗДІЛ %d ЗАВЕРШЕНО" % chapter
  banner_sub.text="ДАЛІ: %s" % chapters()[chapter].title
  banner_left=3.5
 enter_step()

func finish() -> void:
 running=false
 on_finish()
 var lines: Array[String]=[]
 # "З" of the condensed head font reads as a "3" next to the digits.
 lines.append("РОЗДІЛИ  %d–%d / %d" % [start_chapter+1,chapters().size(),chapters().size()])
 lines.append("ЧАС  %02d:%02d" % [int(clock)/60,int(clock)%60])
 lines.append_array(result_lines())
 if skipped>0:lines.append("ПРОПУЩЕНО КРОКІВ  %d" % skipped)
 hide()
 game.training_result("КУРС ЗАВЕРШЕНО" if start_chapter==0 and skipped==0 else "НАВЧАННЯ ЗАВЕРШЕНО","\n".join(lines))

# --- Frame ---------------------------------------------------------------
func _process(delta: float) -> void:
 visible=running and game.running and not game.paused and game.training==course_id()
 if not visible:return
 clock+=delta;step_clock+=delta
 flash=maxf(0,flash-delta)
 if banner_left>0:
  banner_left-=delta
  banner.visible=banner_left>0
  banner.modulate.a=clampf(banner_left/0.6,0,1)*clampf((3.5-banner_left)/0.3,0,1)
 apply_layout(layout_mode())
 fit_width()
 if preparing>0:
  preparing-=delta
  if preparing<=0:
   on_prepared()
   refresh_card(true)
  else:refresh_card(false)
  queue_redraw();return
 var s:=current()
 if s.is_empty():return
 tick(delta)
 if not running:return
 if step_clock>0.35 and check(s.id):advance(true);return
 refresh_card(false)
 queue_redraw()

func refresh_card(rebuild: bool) -> void:
 var s:=current()
 if preparing>0:
  head.text="НАВЧАННЯ · РОЗДІЛ %d / %d" % [chapter+1,chapters().size()]
  chapter_label.text=chapters()[chapter].title
  title.text="Підготовка позиції…";body.text=preparing_text();readout.text=""
  return
 if s.is_empty():return
 if rebuild:
  head.text=step_head()
  chapter_label.text=chapters()[chapter].title
  title.text=s.title
  for child in keys_holder.get_children():child.queue_free()
  var keys: Array=s.get("keys",[])
  if not keys.is_empty():keys_holder.add_child(UiKit.keys_row(keys,s.get("caption","")))
  footer.text="F6 — ПРОПУСТИТИ КРОК   ·   ESC — ПАУЗА" if can_skip(s.id) else "ESC — ПАУЗА"
 body.text=body_text(s)
 var live:=readout_text(s.id)
 readout.text=live;readout.visible=live!=""
 if flash>0:
  head.text="ВИКОНАНО · "+done_title.to_upper();head.add_theme_color_override("font_color",UiKit.GOOD);card_style.border_color=UiKit.GOOD
 else:
  head.text=step_head()
  head.add_theme_color_override("font_color",UiKit.ACCENT);card_style.border_color=UiKit.ACCENT
 progress_bar.queue_redraw()

func step_head() -> String:
 return "НАВЧАННЯ · РОЗДІЛ %d / %d · КРОК %d / %d" % [chapter+1,chapters().size(),step+1,steps()[chapter].size()]

func draw_progress() -> void:
 if not running:return
 var count: int=steps()[chapter].size()
 var w:=progress_bar.size.x;var gap:=4.0
 var cell:=(w-gap*(count-1))/count
 for i in range(count):
  var colour:=UiKit.ACCENT if i<step else (Color(UiKit.ACCENT,0.45) if i==step else Color(1,1,1,0.12))
  progress_bar.draw_rect(Rect2(i*(cell+gap),4,cell,4),colour)

func apply_layout(mode: String) -> void:
 if mode==layout:return
 layout=mode
 chapter_label.visible=mode=="full"
 footer.visible=mode=="full"
 body.visible=mode=="full" or mode=="console"
 var bottom:=mode!="full" and mode!="console"
 var left:=mode=="compact_left"
 card.anchor_left=0.0 if left else 1.0;card.anchor_right=card.anchor_left
 card.offset_left=22.0 if left else -470.0;card.offset_right=470.0 if left else -22.0
 card.grow_horizontal=Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
 card.anchor_top=1.0 if bottom else 0.0;card.anchor_bottom=card.anchor_top
 card.offset_top=-22.0 if bottom else 22.0;card.offset_bottom=card.offset_top
 card.grow_vertical=Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
 card.reset_size()

# Width of the card's text column; a course narrows it over a panel that
# leaves less room.
func card_width() -> float:return CARD_WIDTH

func fit_width() -> void:
 var want:=card_width()
 if absf(card_box.custom_minimum_size.x-want)<1.0:return
 card_box.custom_minimum_size.x=want
 card.reset_size()

# Room the card takes at the top right, for the other overlays.
func reserved() -> float:
 return card.get_rect().end.y+16 if visible and (layout=="full" or layout=="console") else 0.0

# --- Markers on the scene --------------------------------------------------
func _draw() -> void:
 if not running or not visible or preparing>0:return
 if markers_hidden():return
 var m:=marker()
 if m.is_empty():return
 var camera:=get_viewport().get_camera_3d()
 if camera==null:return
 var point: Vector3=m.point
 # Too close to the eye to project: the station is right here.
 if camera.global_position.distance_to(point)<1.2:return
 var pulse:=0.5+0.5*sin(clock*4.0)
 if m.has("ring") and not camera.is_position_behind(point):
  var ring:=PackedVector2Array()
  for k in range(33):
   var a:=TAU*k/32.0
   var p:=ground(point+Vector3(cos(a),0,sin(a))*float(m.ring))+Vector3.UP*2.0
   if camera.is_position_behind(p) or camera.global_position.distance_to(p)<1.0:ring.clear();break
   ring.append(camera.unproject_position(p)-get_global_rect().position)
  if ring.size()>1:
   for k in range(0,ring.size()-1,2):draw_line(ring[k],ring[k+1],Color(UiKit.ACCENT,0.8),2.0)
 var margin:=48.0
 # Projected points are in screen coordinates; the card lives in the frame.
 var area: Rect2=game.screen_rect(self)
 var screen:=camera.unproject_position(point)+area.position
 var behind:=camera.is_position_behind(point)
 var inside:=not behind and area.grow(-margin).has_point(screen)
 var distance:=camera.global_position.distance_to(point)
 var caption:="%s · %s" % [m.caption,("%d м" % roundi(distance)) if distance<1000 else ("%.1f км" % (distance/1000.0)).replace(".",",")]
 var font:=UiKit.font("head")
 if inside:
  var r:=11.0+pulse*3.0
  var diamond:=PackedVector2Array([screen+Vector2(0,-r),screen+Vector2(r,0),screen+Vector2(0,r),screen+Vector2(-r,0),screen+Vector2(0,-r)])
  draw_colored_polygon(diamond.slice(0,4),Color(UiKit.ACCENT,0.25))
  draw_polyline(diamond,UiKit.ACCENT,2.0)
  var w:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
  draw_rect(Rect2(screen+Vector2(-w*0.5-8,r+6),Vector2(w+16,22)),Color(0,0,0,0.55))
  draw_string(font,screen+Vector2(-w*0.5,r+22),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,UiKit.INK)
  return
 # Off screen: an arrow on the edge pointing the way.
 var centre:=area.get_center()
 var direction:=(screen-centre)
 if behind:direction=-direction
 if direction.length()<1.0:direction=Vector2(0,1)
 direction=direction.normalized()
 var half:=area.size*0.5-Vector2(margin,margin)
 var scale:=minf(half.x/maxf(absf(direction.x),0.001),half.y/maxf(absf(direction.y),0.001))
 var at:=centre+direction*scale
 var tip:=at+direction*14.0;var side:=direction.orthogonal()*9.0
 draw_colored_polygon(PackedVector2Array([tip,at-direction*6.0+side,at-direction*6.0-side]),UiKit.ACCENT)
 var label_at:=at-direction*34.0
 var w2:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
 draw_string(font,label_at-Vector2(w2*0.5,-4),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,UiKit.INK)

func _input(event: InputEvent) -> void:
 if not running or not game.running or game.paused or game.training!=course_id():return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_F6:skip();get_viewport().set_input_as_handled();return
  if event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER] and current().get("ack",false):
   acked=true;get_viewport().set_input_as_handled()
