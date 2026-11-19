class_name MainMenu
extends Control

# Front end: the live district behind a graded, vignetted backdrop; the title
# and a large menu on the left; screens for the campaign, the great assault,
# the training, the loadout and the settings, each with a way back on ESC.
const GRADE := """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float blur = 0.0;
uniform float shade = 0.9;
uniform float fade = 0.0;
vec3 sample_blur(vec2 uv, vec2 px){
 if (blur < 0.01) return texture(screen_tex, uv).rgb;
 vec3 sum = vec3(0.0);
 float r = blur * 5.0;
 for (int i = 0; i < 12; i++){
  float a = float(i) * 0.5236;
  vec2 o = vec2(cos(a), sin(a)) * px * r * (1.0 + float(i % 3));
  sum += texture(screen_tex, uv + o).rgb;
 }
 return sum / 12.0;
}
void fragment(){
 vec2 px = SCREEN_PIXEL_SIZE;
 vec3 c = sample_blur(SCREEN_UV, px);
 float luma = dot(c, vec3(0.299, 0.587, 0.114));
 c = mix(vec3(luma), c, 0.5) * vec3(0.93, 0.99, 0.95);
 c = mix(c, c * c * (3.0 - 2.0 * c), 0.4);
 c *= 0.82;
 float vignette = smoothstep(1.2, 0.3, length((SCREEN_UV - 0.5) * vec2(1.35, 1.0)));
 c *= mix(0.35, 1.0, vignette);
 float left = smoothstep(0.66, 0.0, SCREEN_UV.x);
 c = mix(c, vec3(0.018, 0.026, 0.022), left * shade);
 c = mix(c, vec3(0.018, 0.026, 0.022), smoothstep(0.72, 1.0, SCREEN_UV.y) * 0.65);
 float n = fract(sin(dot(SCREEN_UV * vec2(1931.0, 1093.0) + fract(TIME) * 71.0, vec2(12.9898, 78.233))) * 43758.5453);
 c += (n - 0.5) * 0.03;
 c = mix(c, vec3(0.0), fade);
 COLOR = vec4(c, 1.0);
}"""
var game: Node3D
var backdrop: ColorRect
var grade: ShaderMaterial
var home: Control
var nav: VBoxContainer
var items: Array[MenuItem]=[]
var screens: Dictionary={}
var history: Array[String]=[]
var current := "home"
var continue_title: Label
var continue_detail: Label
var training_screen: Control
var chapter_cards: Array[Button]=[]
var chapter_pick := 0
var course_pick := ""
var course_tabs: Array[Button]=[]
var chapter_list: VBoxContainer
var chapter_title: Label
var chapter_about: Label
var chapter_steps: GridContainer
var chapter_state: Label
var settings_screen: Control
var volume_value: Label
var mouse_value: Label
var intro_left := 0.0

func setup(owner_game: Node3D, menu_root: Control) -> void:
 game=owner_game
 game.place(self,menu_root,0,0,1,1)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 backdrop=ColorRect.new()
 backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
 grade=ShaderMaterial.new()
 var shader:=Shader.new();shader.code=GRADE;grade.shader=shader
 backdrop.material=grade
 grade.set_shader_parameter("blur",0.0);grade.set_shader_parameter("fade",0.0);grade.set_shader_parameter("shade",0.9)
 game.place(backdrop,self,0,0,1,1)
 game.bleed(backdrop)
 home=Control.new();home.mouse_filter=Control.MOUSE_FILTER_IGNORE
 game.place(home,self,0,0,1,1)
 build_home()

# The other screens exist once the game has built its own.
func finish_setup() -> void:
 screens.home=home
 screens.loadout=game.loadout_screen
 screens.campaign=game.campaign_panel
 screens.battle=game.battle.panel
 training_screen=build_training()
 settings_screen=build_settings()
 screens.training=training_screen
 screens.settings=settings_screen
 show_screen("home",false)
 play_intro()

# --- Home ---------------------------------------------------------------
func build_home() -> void:
 var logo:=VBoxContainer.new();logo.add_theme_constant_override("separation",-6)
 logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
 game.place(logo,home,0.045,0.06,0.6,0.34)
 logo.add_child(UiKit.text("ТАКТИЧНИЙ СИМУЛЯТОР ПІХОТИ",15,UiKit.ACCENT,"head"))
 logo.add_child(UiKit.text("MANS DUTY",116,UiKit.INK,"display"))
 var tag:=HBoxContainer.new();tag.add_theme_constant_override("separation",14);logo.add_child(tag)
 var bar:=UiKit.rule(UiKit.ACCENT,3);bar.custom_minimum_size=Vector2(56,3);bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER;tag.add_child(bar)
 tag.add_child(UiKit.text("КВАРТАЛ — ЗАЧИСТКА",20,UiKit.SOFT,"head"))
 nav=VBoxContainer.new();nav.add_theme_constant_override("separation",2)
 game.place(nav,home,0.035,0.37,0.42,0.93)
 var entries:=[
  ["01","КАМПАНІЯ","Дві гілки, десять операцій: лісосмуги, села й міські квартали",func():show_screen("campaign"),""],
  ["02","ВЕЛИКИЙ ШТУРМ","Авдіївка: БМП-2 з десантом, зачистка села, три ОП, до 54 бійців на сторону",func():show_screen("battle"),""],
  ["03","НАВЧАННЯ","Стрілець, снайпер, мінометник, «Град» і БМП: крок за кроком",func():show_screen("training"),"НОВЕ"],
  ["04","СПОРЯДЖЕННЯ","Клас, зброя, одяг і наплічник",func():show_screen("loadout"),""],
  ["05","НАЛАШТУВАННЯ","Звук, миша, екран і керування",func():show_screen("settings"),""],
  ["06","ВИЙТИ","",func():get_tree().quit(),""]]
 for entry in entries:
  var item:=MenuItem.new()
  item.configure(game,entry[0],entry[1],entry[2],entry[3],36)
  item.badge=entry[4]
  nav.add_child(item);items.append(item)
 # Continue: the selected operation with the current loadout.
 var resume:=PanelContainer.new()
 var style:=UiKit.flat(UiKit.PANEL,UiKit.LINE,1,4);style.border_color=UiKit.ACCENT
 style.content_margin_left=22;style.content_margin_right=22;style.content_margin_top=16;style.content_margin_bottom=18
 resume.add_theme_stylebox_override("panel",style)
 game.place(resume,home,0.655,0.665,0.955,0.905)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",4);resume.add_child(column)
 column.add_child(UiKit.text("ПРОДОВЖИТИ",13,UiKit.ACCENT,"head"))
 continue_title=UiKit.text("",30,UiKit.INK,"display");column.add_child(continue_title)
 continue_title.clip_text=true;continue_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 continue_title.custom_minimum_size.x=10
 continue_detail=UiKit.text("",14,UiKit.MUTED);column.add_child(continue_detail)
 continue_detail.clip_text=true;continue_detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 continue_detail.custom_minimum_size.x=10
 var spacer:=Control.new();spacer.custom_minimum_size.y=6;column.add_child(spacer)
 column.add_child(UiKit.cta("ДО БОЮ   →",game.begin_operation))
 # What is new.
 var news:=PanelContainer.new()
 var news_style:=UiKit.flat(Color(0.03,0.045,0.04,0.72),UiKit.LINE,1)
 news_style.content_margin_left=22;news_style.content_margin_right=22;news_style.content_margin_top=16;news_style.content_margin_bottom=16
 news.add_theme_stylebox_override("panel",news_style)
 game.place(news,home,0.655,0.075,0.955,0.36)
 var page:=VBoxContainer.new();page.add_theme_constant_override("separation",6);news.add_child(page)
 var tags:=HBoxContainer.new();tags.add_theme_constant_override("separation",10);page.add_child(tags)
 var badge:=PanelContainer.new();badge.add_theme_stylebox_override("panel",UiKit.flat(UiKit.ACCENT))
 var badge_style: StyleBoxFlat=badge.get_theme_stylebox("panel");badge_style.content_margin_top=1;badge_style.content_margin_bottom=1;badge_style.content_margin_left=8;badge_style.content_margin_right=8
 badge.add_child(UiKit.text("НОВЕ",12,UiKit.DARK_TEXT,"head"));tags.add_child(badge)
 tags.add_child(UiKit.text("ВЕРСІЯ %s" % ProjectSettings.get_setting("application/config/version","—"),12,UiKit.MUTED,"head"))
 page.add_child(UiKit.text("НАВЧАННЯ ДЛЯ ВСІХ КЛАСІВ",30,UiKit.INK,"display"))
 page.add_child(UiKit.wrapped("Новий полігон: стрілець, снайпер і мінометник крок за кроком — рух, стрільба, магазини, ПСО-1, міномет від розгортання до ураження. Широкі монітори 21:9 і 32:9, авторозрахунок у планшеті «Града».",14,UiKit.SOFT))
 var go:=UiKit.ghost("ПОЧАТИ НАВЧАННЯ   →",func():show_screen("training"),15)
 go.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;page.add_child(go)
 # Footer: version and the keys of the menu.
 var foot:=HBoxContainer.new();foot.add_theme_constant_override("separation",8);foot.mouse_filter=Control.MOUSE_FILTER_IGNORE
 game.place(foot,home,0.045,0.945,0.955,0.985)
 foot.add_child(UiKit.text("MANS DUTY %s · GODOT %s" % [ProjectSettings.get_setting("application/config/version",""),Engine.get_version_info().string.get_slice("-",0)],12,UiKit.FAINT,"head"))
 var fill:=Control.new();fill.size_flags_horizontal=Control.SIZE_EXPAND_FILL;fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;foot.add_child(fill)
 for pair in [[["↑","/","↓"],"НАВІГАЦІЯ"],[["ENTER"],"ВИБРАТИ"],[["ESC"],"НАЗАД"]]:
  foot.add_child(UiKit.keys_row(pair[0],pair[1]))
  var gap:=Control.new();gap.custom_minimum_size.x=14;foot.add_child(gap)

func refresh_home() -> void:
 if not is_instance_valid(continue_title):return
 var info: Dictionary=game.operation_info()
 continue_title.text=info.title
 continue_detail.text="%s · %s · %s" % [info.kind,PlayerClass.TITLES[game.player_class],WeaponState.DATA[game.primary].name]

# --- Screens --------------------------------------------------------------
func show_screen(id: String, remember: bool=true) -> void:
 if not screens.has(id):return
 if remember and id!=current:
  if id=="home":history.clear()
  else:history.append(current)
 current=id
 for key in screens:
  var screen: Control=screens[key]
  if is_instance_valid(screen):screen.visible=key==id
 if id=="home":refresh_home()
 if id=="training":refresh_training()
 if id=="loadout" and is_instance_valid(game.loadout_screen):game.loadout_screen.refresh()
 if id=="campaign":game.refresh_campaign()
 var screen: Control=screens[id]
 screen.modulate.a=0.0
 var tween:=create_tween();tween.tween_property(screen,"modulate:a",1.0,0.18)
 var from_blur: float=grade.get_shader_parameter("blur") if grade.get_shader_parameter("blur")!=null else 0.0
 var blur:=create_tween();blur.tween_method(func(v: float):grade.set_shader_parameter("blur",v),from_blur,0.0 if id=="home" else 1.0,0.25)
 grade.set_shader_parameter("shade",0.9 if id=="home" else 0.0)
 if id=="home" and not items.is_empty():items[0].call_deferred("focus_quietly")

func back() -> void:
 if current=="home":return
 var previous: String=history.pop_back() if not history.is_empty() else "home"
 show_screen(previous,false)

# Called when a match ends: back to the screen it was started from.
func open(id: String="home") -> void:
 history.clear()
 if id!="home":history.append("home")
 show_screen(id,false)
 play_intro()

func play_intro() -> void:
 intro_left=0.7
 grade.set_shader_parameter("fade",1.0)
 var tween:=create_tween()
 tween.tween_method(func(v: float):grade.set_shader_parameter("fade",v),1.0,0.0,0.7)
 if current!="home":return
 for i in range(items.size()):
  items[i].modulate.a=0.0
  var t:=create_tween();t.tween_interval(0.15+i*0.06);t.tween_property(items[i],"modulate:a",1.0,0.25)

func _input(event: InputEvent) -> void:
 if game.running or not game.menu.visible:return
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
  var picker: Control=game.loadout_screen.picker if is_instance_valid(game.loadout_screen) else null
  if current=="loadout" and is_instance_valid(picker) and picker.visible:picker.hide()
  else:back()
  get_viewport().set_input_as_handled()

# --- Training ---------------------------------------------------------------
func build_training() -> Control:
 var screen:=Control.new()
 game.place(screen,game.menu,0,0,1,1)
 UiKit.sheet(game,screen,0.78)
 UiKit.header(game,screen,"ГОЛОВНЕ МЕНЮ   /   НАВЧАННЯ","НАВЧАННЯ","П’ЯТЬ КУРСІВ · БЕЗ ПРОТИВНИКА · БУДЬ-ЯКИЙ РОЗДІЛ ОКРЕМО",back)
 # One tab per class.
 var tabs:=HBoxContainer.new();tabs.add_theme_constant_override("separation",8)
 game.place(tabs,screen,0.035,0.215,0.965,0.285)
 for id in game.COURSE_IDS:
  var tab:=CourseTab.new()
  tab.setup(game,id,select_course.bind(id))
  tabs.add_child(tab);course_tabs.append(tab)
 chapter_list=VBoxContainer.new();chapter_list.add_theme_constant_override("separation",8)
 game.place(chapter_list,screen,0.035,0.31,0.47,0.87)
 var detail:=PanelContainer.new()
 var style:=UiKit.flat(UiKit.PANEL,UiKit.LINE,1)
 style.content_margin_left=28;style.content_margin_right=28;style.content_margin_top=22;style.content_margin_bottom=22
 detail.add_theme_stylebox_override("panel",style)
 game.place(detail,screen,0.5,0.31,0.965,0.87)
 var page:=VBoxContainer.new();page.add_theme_constant_override("separation",10);detail.add_child(page)
 chapter_state=UiKit.text("",13,UiKit.ACCENT,"head");page.add_child(chapter_state)
 chapter_title=UiKit.text("",34,UiKit.INK,"display");chapter_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(chapter_title)
 chapter_about=UiKit.wrapped("",16,UiKit.SOFT);page.add_child(chapter_about)
 page.add_child(UiKit.rule())
 page.add_child(UiKit.text("КРОКИ",13,UiKit.MUTED,"head"))
 chapter_steps=GridContainer.new();chapter_steps.columns=2
 chapter_steps.add_theme_constant_override("h_separation",24);chapter_steps.add_theme_constant_override("v_separation",4)
 chapter_steps.size_flags_vertical=Control.SIZE_EXPAND_FILL;page.add_child(chapter_steps)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);page.add_child(row)
 var start:=UiKit.cta("ПОЧАТИ РОЗДІЛ   →",func():game.begin_training(chapter_pick,course_pick))
 start.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(start)
 var full:=UiKit.ghost("УВЕСЬ КУРС З ПОЧАТКУ",func():game.begin_training(0,course_pick),15)
 full.custom_minimum_size=Vector2(0,58);row.add_child(full)
 var note:=UiKit.wrapped("Противника немає: піхота вчиться на полігоні, «Град» — у полі під Авдіївкою, БМП — на маршруті колони. Картка кроку — праворуч угорі, маркер показує, куди йти. Застряг — F6 виконає крок за тебе. ESC — пауза й вихід. Пройдені розділи зберігаються.",13,UiKit.MUTED)
 game.place(note,screen,0.035,0.9,0.965,0.98)
 return screen

func select_chapter(index: int) -> void:
 chapter_pick=index
 refresh_training()

func picked_course() -> TrainingCourse:return game.courses[course_pick]

func select_course(id: String) -> void:
 if id==course_pick and not chapter_cards.is_empty():return
 course_pick=id;chapter_pick=0
 for card in chapter_cards:card.queue_free()
 chapter_cards.clear()
 for i in range(picked_course().chapters().size()):
  var card:=ChapterCard.new()
  card.setup(game,picked_course(),i,select_chapter.bind(i))
  chapter_list.add_child(card);chapter_cards.append(card)
 refresh_training()

func refresh_training() -> void:
 # First visit: the course of the player's own class.
 if course_pick=="":select_course(game.player_class if game.courses.has(game.player_class) else "rifleman");return
 if chapter_cards.is_empty():return
 var course:=picked_course()
 for tab in course_tabs:tab.selected=tab.id==course_pick;tab.queue_redraw()
 var done:Array=course.done_chapters()
 for i in range(chapter_cards.size()):
  var card: ChapterCard=chapter_cards[i]
  card.selected=i==chapter_pick;card.done=i in done;card.queue_redraw()
 var data: Dictionary=course.chapters()[chapter_pick]
 chapter_state.text="%s · РОЗДІЛ %d / %d · ≈ %d ХВ%s" % [course.course_title(),chapter_pick+1,course.chapters().size(),data.minutes,"  ·  ПРОЙДЕНО" if chapter_pick in done else ""]
 chapter_title.text=data.title
 chapter_about.text=data.about
 for child in chapter_steps.get_children():child.queue_free()
 var steps: Array=course.steps()[chapter_pick]
 var half:=ceili(steps.size()/2.0)
 # Column-major: the first half on the left, the rest on the right.
 for row in range(half):
  for column in range(2):
   var i:=row+column*half
   var cell:=UiKit.text("%02d   %s" % [i+1,steps[i].title] if i<steps.size() else "",14,UiKit.SOFT)
   cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   chapter_steps.add_child(cell)

# A class tab of the training screen: its name, its kit, chapters done.
class CourseTab extends Button:
 var id := ""
 var selected := false
 var game: Node3D
 func setup(owner_game: Node3D, course_id: String, on_press: Callable) -> void:
  game=owner_game;id=course_id;flat=true;text=""
  custom_minimum_size=Vector2(0,50);size_flags_horizontal=Control.SIZE_EXPAND_FILL
  mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  add_theme_stylebox_override("focus",StyleBoxEmpty.new())
  mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
  focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw)
  pressed.connect(func():game.sound("click",-12);on_press.call())
 func _draw() -> void:
  var course: TrainingCourse=game.courses[id]
  var hot:=is_hovered() or has_focus()
  draw_rect(Rect2(Vector2.ZERO,size),Color(UiKit.ACCENT,0.14) if selected else (Color(1,1,1,0.07) if hot else Color(0.03,0.045,0.04,0.7)))
  draw_rect(Rect2(0,size.y-3,size.x,3),UiKit.ACCENT if selected else UiKit.LINE)
  draw_string(UiKit.font("head"),Vector2(16,22),course.course_title(),HORIZONTAL_ALIGNMENT_LEFT,size.x-80,19,UiKit.INK if selected or hot else UiKit.SOFT)
  draw_string(UiKit.font("body"),Vector2(16,40),course.course_role(),HORIZONTAL_ALIGNMENT_LEFT,size.x-80,12,UiKit.MUTED)
  var count:="%d / %d" % [course.done_chapters().size(),course.chapters().size()]
  var font:=UiKit.font("head")
  var w:=font.get_string_size(count,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
  draw_string(font,Vector2(size.x-w-14,30),count,HORIZONTAL_ALIGNMENT_LEFT,-1,14,UiKit.GOOD if course.done_chapters().size()==course.chapters().size() else UiKit.FAINT)

class ChapterCard extends Button:
 var index := 0
 var selected := false
 var done := false
 var game: Node3D
 var course: TrainingCourse
 func setup(owner_game: Node3D, owner_course: TrainingCourse, i: int, on_press: Callable) -> void:
  game=owner_game;course=owner_course;index=i;flat=true;text=""
  custom_minimum_size=Vector2(0,72)
  size_flags_vertical=Control.SIZE_SHRINK_BEGIN
  mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  add_theme_stylebox_override("focus",StyleBoxEmpty.new())
  mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
  focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw)
  pressed.connect(func():game.sound("click",-12);on_press.call())
 func _draw() -> void:
  var hot:=is_hovered() or has_focus()
  var bg:=Color(UiKit.ACCENT,0.16) if selected else (Color(1,1,1,0.07) if hot else Color(0.03,0.045,0.04,0.78))
  draw_rect(Rect2(Vector2.ZERO,size),bg)
  draw_rect(Rect2(Vector2.ZERO,size),UiKit.ACCENT if selected else UiKit.LINE,false,1.0)
  draw_rect(Rect2(0,0,4,size.y),UiKit.ACCENT if selected else (UiKit.GOOD if done else UiKit.FAINT))
  var data: Dictionary=course.chapters()[index]
  draw_string(UiKit.font("display"),Vector2(24,size.y*0.5+15),"%02d" % (index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,40,UiKit.ACCENT if selected else UiKit.MUTED)
  draw_string(UiKit.font("head"),Vector2(86,size.y*0.5-6),data.title,HORIZONTAL_ALIGNMENT_LEFT,size.x-220,20,UiKit.INK)
  draw_string(UiKit.font("body"),Vector2(86,size.y*0.5+19),"%d %s · ≈ %d хв" % [course.steps()[index].size(),UiKit.plural(course.steps()[index].size(),"крок","кроки","кроків"),data.minutes],HORIZONTAL_ALIGNMENT_LEFT,-1,14,UiKit.MUTED)
  var state:="ПРОЙДЕНО" if done else "НЕ ПРОЙДЕНО"
  var font:=UiKit.font("head")
  var w:=font.get_string_size(state,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
  draw_string(font,Vector2(size.x-w-20,size.y*0.5+5),state,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UiKit.GOOD if done else UiKit.FAINT)

# --- Settings -----------------------------------------------------------------
func build_settings() -> Control:
 var screen:=Control.new()
 game.place(screen,game.menu,0,0,1,1)
 UiKit.sheet(game,screen,0.8)
 UiKit.header(game,screen,"ГОЛОВНЕ МЕНЮ   /   НАЛАШТУВАННЯ","НАЛАШТУВАННЯ","",back)
 var left:=VBoxContainer.new();left.add_theme_constant_override("separation",12)
 game.place(left,screen,0.045,0.24,0.46,0.92)
 left.add_child(section("ЗВУК І КЕРУВАННЯ"))
 volume_value=UiKit.text("",15,UiKit.ACCENT,"head")
 left.add_child(slider_row("Гучність",0.0,1.0,0.05,game.volume,volume_value,func(v: float):game.volume=v;volume_value.text="%d %%" % roundi(v*100);game.save_settings()))
 volume_value.text="%d %%" % roundi(game.volume*100)
 mouse_value=UiKit.text("",15,UiKit.ACCENT,"head")
 left.add_child(slider_row("Чутливість миші",0.0008,0.005,0.0001,game.sensitivity,mouse_value,func(v: float):game.sensitivity=v;mouse_value.text="%.1f" % (v*1000.0);game.save_settings()))
 mouse_value.text="%.1f" % (game.sensitivity*1000.0)
 left.add_child(section("ЕКРАН"))
 var full:=CheckButton.new();full.text="Повноекранний режим   (F11)"
 full.button_pressed=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
 full.toggled.connect(func(on: bool):game.set_fullscreen(on))
 left.add_child(full)
 var shadows:=CheckButton.new();shadows.text="Тіні від сонця"
 shadows.button_pressed=game.sunlight.shadow_enabled
 shadows.toggled.connect(func(on: bool):game.sunlight.shadow_enabled=on;game.save_settings())
 left.add_child(shadows)
 # Wide monitors: how far the interface reaches; the picture is always full.
 var width_row:=HBoxContainer.new();width_row.add_theme_constant_override("separation",12)
 var width_caption:=UiKit.text("Ширина інтерфейсу",15,UiKit.INK)
 width_caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;width_row.add_child(width_caption)
 var widths:=OptionButton.new()
 for title in game.UI_WIDTH_LABELS:widths.add_item(title)
 widths.selected=game.ui_width
 widths.custom_minimum_size=Vector2(200,40)
 widths.item_selected.connect(func(i: int):game.set_ui_width(i))
 width_row.add_child(widths)
 left.add_child(width_row)
 left.add_child(section("ПРОТИВНИК"))
 var enemies:=OptionButton.new()
 for title in Wardrobe.LABELS:enemies.add_item(title)
 enemies.selected=Wardrobe.IDS.find(game.enemy_outfit)
 enemies.item_selected.connect(func(i: int):game.enemy_outfit=Wardrobe.IDS[i];game.save_settings())
 enemies.custom_minimum_size.y=46
 left.add_child(enemies)
 var right:=VBoxContainer.new();right.add_theme_constant_override("separation",8)
 game.place(right,screen,0.52,0.24,0.965,0.92)
 right.add_child(section("КЕРУВАННЯ · БОЄЦЬ"))
 right.add_child(controls_grid([["W A S D","рух"],["SHIFT","біг"],["ЛКМ / ПКМ","вогонь / приціл"],["R","перезарядити"],["Q / E","нахил"],["Z / CTRL","лягти / присісти"],["H","аптечка"],["TAB","інвентар"],["M","карта"],["K","далекомір"]]))
 right.add_child(section("КЕРУВАННЯ · БМ-21 «ГРАД»"))
 right.add_child(controls_grid([["F","кабіна, приціл, роботи біля машини"],["I / X","запалювання / стартер"],["SHIFT + Q / E","передачі"],["SPACE","стоянкове гальмо · пуск"],["SHIFT + P","КВП"],["E","пульт (командир)"],["J","дрон СП"],["M / G","планшет / радіо"]]))
 return screen

func section(title: String) -> Control:
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",4)
 var spacer:=Control.new();spacer.custom_minimum_size.y=6;box.add_child(spacer)
 box.add_child(UiKit.text(title,14,UiKit.ACCENT,"head"))
 box.add_child(UiKit.rule())
 return box

func slider_row(title: String, low: float, high: float, step: float, value: float, readout: Label, changed: Callable) -> Control:
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",2)
 var top:=HBoxContainer.new();box.add_child(top)
 var name:=UiKit.text(title,17,UiKit.INK,"head");name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(name)
 top.add_child(readout)
 var slider:=HSlider.new();slider.min_value=low;slider.max_value=high;slider.step=step;slider.value=value
 slider.custom_minimum_size.y=26
 slider.value_changed.connect(changed)
 box.add_child(slider)
 return box

func controls_grid(rows: Array) -> GridContainer:
 var grid:=GridContainer.new();grid.columns=2
 grid.add_theme_constant_override("h_separation",18);grid.add_theme_constant_override("v_separation",1)
 for row in rows:
  var key:=UiKit.text(row[0],14,UiKit.INK,"head");key.custom_minimum_size.x=150;grid.add_child(key)
  grid.add_child(UiKit.text(row[1],14,UiKit.SOFT))
 return grid
