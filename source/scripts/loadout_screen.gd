class_name LoadoutScreen
extends Control

# The loadout as a gear screen. Classes along the top. On the left the man,
# with what he wears in slots round him (face, uniform, armour, pack) and
# his two weapons under him; in the middle his rig, belt and the pack's grid;
# on the right an examine panel for whatever the cursor is on and the stores
# the pack is filled from. Weight, presets and the operation below.

var game: Node3D
var portrait: ModelPreview
var pack_grid: PackGrid
var pack_select: OptionButton
var load_label: Label
var notice: Label
var preset_name: LineEdit
var preset_select: OptionButton
var store := LoadoutPresets.new()
var launch: Button
var picker: WeaponPicker
var class_buttons: Dictionary={}
var class_brief: Label
var catalog_tiles: Dictionary={}
var operation_label: Label
var vest_buttons: Dictionary={}
var vest_label: Label
var face_buttons: Dictionary={}
# The doll's slots: "face", "outfit", "vest", "pack" -> {button, preview, caption}.
var slots: Dictionary={}
# What is worn is changed in a list over the middle column.
var chooser: Control
var chooser_title: Label
var chooser_pages: Dictionary={}
var chooser_kind := ""
# The examine panel: what the cursor is on, or else what was picked last,
# or else the class.
var examine_preview: ModelPreview
var examine_title: Label
var examine_kicker: Label
var examine_bars: VBoxContainer
var examined := ""
var pinned := ""

const LEFT := [0.035,0.375]
const MIDDLE := [0.39,0.645]
const RIGHT := [0.66,0.965]
const TOP := 0.255
const BOTTOM := 0.835

func setup(owner_game: Node3D, parent: Control) -> void:
 game=owner_game
 game.place(self,parent,0,0,1,1)
 UiKit.sheet(game,self,0.86)
 UiKit.header(game,self,"ГОЛОВНЕ МЕНЮ   /   СПОРЯДЖЕННЯ","СПОРЯДЖЕННЯ","",func():game.main_menu.back())
 build_class_tabs()
 build_doll()
 build_rig()
 build_examine()
 build_stores()
 build_chooser()
 build_footer()
 game.map_description=game.label("",12);game.map_description.hide();add_child(game.map_description)
 picker=WeaponPicker.new();add_child(picker);picker.setup(game)
 store.read();refresh_presets()
 refresh()

# --- Building -----------------------------------------------------------------
static func tab_style(selected: bool, hovered: bool=false) -> StyleBoxFlat:
 var style := UiKit.tab_style(selected,hovered)
 style.content_margin_left=6;style.content_margin_right=6
 return style

func build_class_tabs() -> void:
 var row := HBoxContainer.new()
 row.add_theme_constant_override("separation",2)
 game.place(row,self,0.035,0.195,0.965,0.238)
 for id in PlayerClass.IDS:
  var tab := Button.new()
  tab.text=PlayerClass.TITLES[id]
  tab.toggle_mode=true;tab.clip_text=true
  tab.size_flags_horizontal=SIZE_EXPAND_FILL
  tab.add_theme_font_override("font",UiKit.font("head"))
  tab.add_theme_font_size_override("font_size",13)
  tab.add_theme_stylebox_override("normal",tab_style(false))
  tab.add_theme_stylebox_override("hover",tab_style(false,true))
  tab.add_theme_stylebox_override("pressed",tab_style(true))
  tab.add_theme_stylebox_override("hover_pressed",tab_style(true,true))
  tab.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
  tab.add_theme_color_override("font_color",UiKit.MUTED)
  tab.add_theme_color_override("font_hover_color",UiKit.INK)
  tab.add_theme_color_override("font_pressed_color",UiKit.ACCENT)
  tab.add_theme_color_override("font_hover_pressed_color",UiKit.ACCENT)
  tab.pressed.connect(choose_class.bind(id))
  tab.mouse_entered.connect(inspect.bind("class:"+id))
  tab.mouse_exited.connect(inspect_rest)
  row.add_child(tab);class_buttons[id]=tab
 game.place(UiKit.rule(),self,0.035,0.238,0.965,0.24)

# A section's heading: its number and name, as over the menu's columns.
func heading(text: String, left: float, top: float, right: float) -> Label:
 var label := UiKit.text(text,13,UiKit.ACCENT,"head")
 game.place(label,self,left,top,right,top+0.028)
 return label

# A slot of the doll: what it is over it, the thing itself, its name under it.
func doll_slot(kind: String, title: String, box: Array, on_press: Callable) -> Button:
 var button := Button.new()
 button.add_theme_stylebox_override("normal",game.panel_style(Color("141d19"),Color("3c463b")))
 button.add_theme_stylebox_override("hover",game.panel_style(Color("1f2b24"),UiKit.ACCENT))
 button.add_theme_stylebox_override("pressed",game.panel_style(Color("1f2b24"),UiKit.ACCENT))
 button.add_theme_stylebox_override("focus",game.panel_style(Color(0,0,0,0),UiKit.ACCENT_DIM))
 game.place(button,self,box[0],box[1],box[2],box[3])
 var preview := ModelPreview.new()
 button.add_child(preview)
 preview.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 preview.offset_top=20;preview.offset_bottom=-22;preview.offset_left=4;preview.offset_right=-4
 var top := UiKit.text(title,11,UiKit.MUTED,"head")
 top.mouse_filter=MOUSE_FILTER_IGNORE
 button.add_child(top);top.position=Vector2(7,3)
 var caption := UiKit.text("",11,UiKit.ACCENT,"head")
 caption.mouse_filter=MOUSE_FILTER_IGNORE;caption.clip_text=true
 caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 button.add_child(caption)
 caption.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
 caption.offset_top=-20;caption.offset_bottom=-3;caption.offset_left=4;caption.offset_right=-4
 button.pressed.connect(on_press)
 button.mouse_entered.connect(func():inspect(slot_subject(kind)))
 button.mouse_exited.connect(inspect_rest)
 slots[kind]={"button":button,"preview":preview,"caption":caption}
 return button

func build_doll() -> void:
 heading("01 / БОЄЦЬ",LEFT[0],TOP,LEFT[1])
 var side := 0.08
 var gap := 0.005
 doll_slot("face","ОБЛИЧЧЯ",[LEFT[0],0.29,LEFT[0]+side,0.47],open_chooser.bind("face")).tooltip_text="Балаклава чи бафф під шоломом. ЛКМ — обрати."
 doll_slot("outfit","ФОРМА",[LEFT[0],0.48,LEFT[0]+side,0.68],open_chooser.bind("outfit")).tooltip_text="Камуфляж форми й шолома. ЛКМ — обрати."
 doll_slot("vest","БРОНЕЖИЛЕТ",[LEFT[1]-side,0.29,LEFT[1],0.47],open_chooser.bind("vest")).tooltip_text="Бронежилет: плити, м'яка броня, маса. ЛКМ — обрати."
 doll_slot("pack","НАПЛІЧНИК",[LEFT[1]-side,0.48,LEFT[1],0.68],toggle_pack).tooltip_text="Штурмовий наплічник 30 л. ЛКМ — одягти чи зняти (порожній)."
 portrait=ModelPreview.new()
 portrait.supersample=3.0
 game.place(portrait,self,LEFT[0]+side+gap,0.29,LEFT[1]-side-gap,0.685)
 game.outfit_preview=portrait.viewport
 # Turned round to see the pack: a small flat button in the heading's row.
 var turn := Button.new();turn.text="↶  ПОВЕРНУТИ";turn.flat=true
 turn.add_theme_font_override("font",UiKit.font("head"));turn.add_theme_font_size_override("font_size",12)
 turn.add_theme_color_override("font_color",UiKit.MUTED);turn.add_theme_color_override("font_hover_color",UiKit.ACCENT)
 turn.alignment=HORIZONTAL_ALIGNMENT_RIGHT
 turn.pressed.connect(func():portrait.rear_view=not portrait.rear_view;portrait.fit())
 game.place(turn,self,LEFT[1]-0.12,TOP-0.004,LEFT[1],TOP+0.03)
 # The line the uniform and armour are named in (kept for the rest of the game).
 game.outfit_caption=UiKit.text("",12,UiKit.ACCENT,"head");game.outfit_caption.hide();add_child(game.outfit_caption)
 game.primary_tile=game.inventory_slot("rifle","ОСНОВНА ЗБРОЯ","",84)
 game.place(game.primary_tile,self,LEFT[0],0.695,0.25,BOTTOM)
 game.primary_tile.pressed.connect(func():picker.open(false))
 game.primary_tile.mouse_entered.connect(func():inspect("weapon:"+game.primary))
 game.primary_tile.mouse_exited.connect(inspect_rest)
 game.secondary_tile=game.inventory_slot("pistol","ПІСТОЛЕТ","",64)
 game.place(game.secondary_tile,self,0.255,0.695,LEFT[1],BOTTOM)
 game.secondary_tile.pressed.connect(func():picker.open(true))
 game.secondary_tile.mouse_entered.connect(func():inspect("weapon:"+game.secondary))
 game.secondary_tile.mouse_exited.connect(inspect_rest)

func rig_tile(kind: String, title: String, row: HBoxContainer, subject: Callable) -> Button:
 var tile: Button=game.inventory_slot(kind,title,"",46)
 row.add_child(tile)
 tile.mouse_entered.connect(func():inspect(subject.call()))
 tile.mouse_exited.connect(inspect_rest)
 return tile

func build_rig() -> void:
 heading("02 / РОЗВАНТАЖЕННЯ",MIDDLE[0],TOP,MIDDLE[1])
 vest_label=UiKit.text("",11,UiKit.MUTED,"head")
 game.place(vest_label,self,MIDDLE[0],0.285,MIDDLE[1],0.31)
 var rig := HBoxContainer.new();rig.add_theme_constant_override("separation",4)
 game.place(rig,self,MIDDLE[0],0.312,MIDDLE[1],0.39)
 for i in range(3):game.rifle_mag_tiles.append(rig_tile("magazine",str(i+1),rig,func():return "weapon:"+game.primary))
 var finder: Button=rig_tile("rangefinder","K",rig,func():return "item:rangefinder")
 finder.show_item("rangefinder")
 finder.tooltip_text="Лазерний далекомір 6–12× у підсумку на броні: K — дістати за секунду, коліщатко — кратність, ще раз K — прибрати."
 game.place(UiKit.text("ПОЯС · МАГАЗИНИ ДО ПІСТОЛЕТА · АПТЕЧКИ (H)",11,UiKit.MUTED,"head"),self,MIDDLE[0],0.396,MIDDLE[1],0.42)
 var belt := HBoxContainer.new();belt.add_theme_constant_override("separation",4)
 game.place(belt,self,MIDDLE[0],0.422,MIDDLE[1],0.50)
 for i in range(2):game.pistol_mag_tiles.append(rig_tile("magazine",str(i+1),belt,func():return "weapon:"+game.secondary))
 for i in range(Operator.BELT_MEDKITS):
  var tile: Button=rig_tile("medkit","✚",belt,func():return "item:medkit")
  tile.tooltip_text="Аптечка на поясі. Після використання в бою на її місце можна прикріпити аптечку з наплічника (TAB)."
  game.medkit_tiles.append(tile)
 for tile in game.rifle_mag_tiles+game.pistol_mag_tiles+game.medkit_tiles+[finder]:tile.mouse_filter=MOUSE_FILTER_PASS
 heading("03 / НАПЛІЧНИК",MIDDLE[0],0.512,MIDDLE[1])
 pack_select=OptionButton.new();pack_select.add_item("Без наплічника");pack_select.add_item("Штурмовий 30 л · 24 клітинки · 1,35 кг")
 pack_select.add_theme_font_size_override("font_size",13)
 game.place(pack_select,self,MIDDLE[0],0.542,MIDDLE[1],0.585)
 pack_select.item_selected.connect(select_pack)
 pack_grid=PackGrid.new();pack_grid.editable=true
 game.place(pack_grid,self,MIDDLE[0],0.592,MIDDLE[1],BOTTOM)
 pack_grid.changed.connect(changed)
 pack_grid.selected.connect(func(uid: int):
  var e: Dictionary=game.loadout_bag.item(uid)
  notice.text=Equipment.ITEMS[e.kind].name+" · ПКМ — прибрати · перетягни, щоб перемістити"
  pinned="item:"+str(e.kind);inspect(pinned))

func build_examine() -> void:
 var frame := Panel.new()
 frame.add_theme_stylebox_override("panel",UiKit.flat(Color(0.03,0.045,0.04,0.9),UiKit.LINE,1))
 frame.mouse_filter=MOUSE_FILTER_IGNORE
 game.place(frame,self,RIGHT[0],TOP,RIGHT[1],0.6)
 game.place(UiKit.text("04 / ОГЛЯД",13,UiKit.ACCENT,"head"),self,RIGHT[0]+0.008,TOP+0.004,RIGHT[1],TOP+0.03)
 examine_preview=ModelPreview.new()
 game.place(examine_preview,self,RIGHT[0]+0.004,0.29,RIGHT[0]+0.115,0.595)
 examine_kicker=UiKit.text("",11,UiKit.ACCENT,"head")
 game.place(examine_kicker,self,RIGHT[0]+0.12,0.262,RIGHT[1]-0.006,0.285)
 examine_title=UiKit.text("",17,UiKit.INK,"head");examine_title.clip_text=true
 game.place(examine_title,self,RIGHT[0]+0.12,0.284,RIGHT[1]-0.006,0.32)
 class_brief=UiKit.wrapped("",12,UiKit.SOFT)
 class_brief.clip_text=true
 game.place(class_brief,self,RIGHT[0]+0.12,0.322,RIGHT[1]-0.006,0.462)
 examine_bars=VBoxContainer.new();examine_bars.add_theme_constant_override("separation",1)
 game.place(examine_bars,self,RIGHT[0]+0.12,0.466,RIGHT[1]-0.006,0.597)

func build_stores() -> void:
 heading("05 / СКЛАД · ЛКМ — У НАПЛІЧНИК",RIGHT[0],0.607,RIGHT[1])
 var scroll := ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 game.place(scroll,self,RIGHT[0],0.637,RIGHT[1],BOTTOM)
 var catalog := GridContainer.new();catalog.columns=2;catalog.size_flags_horizontal=SIZE_EXPAND_FILL
 catalog.add_theme_constant_override("h_separation",4);catalog.add_theme_constant_override("v_separation",4)
 scroll.add_child(catalog)
 for kind in Equipment.ITEMS:
  var entry: Dictionary=Equipment.ITEMS[kind]
  var tile := small_button("",add_item.bind(kind));tile.custom_minimum_size=Vector2(0,38);tile.size_flags_horizontal=SIZE_EXPAND_FILL
  tile.add_theme_stylebox_override("normal",game.panel_style(Color("131b17"),Color("33402f")))
  catalog.add_child(tile);catalog_tiles[kind]=tile
  var thumbnail := ModelPreview.new();game.place(thumbnail,tile,0,0,0.34,1);thumbnail.show_item(kind)
  var caption: Label=UiKit.text(entry.name+"\n%d × %d · %.2f кг" % [entry.size.x,entry.size.y,float(entry.mass)],10,UiKit.SOFT,"head")
  caption.mouse_filter=MOUSE_FILTER_IGNORE;caption.clip_text=true
  game.place(caption,tile,0.35,0.06,0.98,0.96)
  tile.tooltip_text="Додати до наплічника: "+entry.name+"\n"+str(entry.get("description",""))
  tile.mouse_entered.connect(inspect.bind("item:"+kind))
  tile.mouse_exited.connect(inspect_rest)

# A tile of the list: the thing on the left, what it is on the right.
func choice_tile(height: float, thumb: float, on_press: Callable, subject: String) -> Button:
 var tile: Button=small_button("",on_press)
 tile.custom_minimum_size=Vector2(0,height);tile.size_flags_horizontal=SIZE_EXPAND_FILL;tile.toggle_mode=true
 tile.mouse_entered.connect(inspect.bind(subject))
 tile.mouse_exited.connect(inspect_rest)
 var thumbnail := ModelPreview.new();game.place(thumbnail,tile,0,0,thumb,1)
 return tile

func tile_caption(tile: Button, text: String, from: float) -> void:
 var caption: Label=UiKit.wrapped(text,11,UiKit.SOFT)
 caption.mouse_filter=MOUSE_FILTER_IGNORE;caption.clip_text=true
 game.place(caption,tile,from,0.07,0.98,0.95)

func chooser_page(kind: String, columns: int) -> GridContainer:
 var scroll := ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 scroll.offset_top=34;scroll.offset_left=6;scroll.offset_right=-6;scroll.offset_bottom=-6
 chooser.add_child(scroll)
 var grid := GridContainer.new();grid.columns=columns;grid.size_flags_horizontal=SIZE_EXPAND_FILL
 grid.add_theme_constant_override("h_separation",4);grid.add_theme_constant_override("v_separation",4)
 scroll.add_child(grid)
 chooser_pages[kind]=scroll
 return grid

func build_chooser() -> void:
 chooser=Panel.new()
 chooser.add_theme_stylebox_override("panel",UiKit.flat(Color(0.025,0.037,0.032,0.985),UiKit.ACCENT_DIM,1))
 game.place(chooser,self,MIDDLE[0],TOP,MIDDLE[1],BOTTOM)
 chooser_title=UiKit.text("",14,UiKit.ACCENT,"head")
 chooser.add_child(chooser_title);chooser_title.position=Vector2(10,7)
 var close := small_button("×",close_chooser)
 close.custom_minimum_size=Vector2(34,28)
 chooser.add_child(close)
 close.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
 close.offset_left=-40;close.offset_right=-4;close.offset_top=3;close.offset_bottom=31
 var faces := chooser_page("face",2)
 for id in FaceCover.IDS:
  var tile := choice_tile(96,0.46,func():game.choose_face(id);pinned="face:"+id,"face:"+id)
  faces.add_child(tile);face_buttons[id]=tile
  tile_caption(tile,"%s\n%s" % [FaceCover.DATA[id].short,"%d г" % roundi(FaceCover.mass(id)*1000) if FaceCover.mass(id)>0 else "обличчя відкрите"],0.48)
 var outfits := chooser_page("outfit",2)
 for i in range(Wardrobe.IDS.size()):
  var tile := choice_tile(104,0.42,game.choose_outfit.bind(i),"outfit:"+Wardrobe.IDS[i])
  tile.pressed.connect(func():pinned="outfit:"+Wardrobe.IDS[i])
  outfits.add_child(tile);game.outfit_buttons.append(tile)
  tile.get_child(0).show_outfit(Wardrobe.IDS[i])
  tile_caption(tile,Wardrobe.LABELS[i].replace(" / ","\n").replace(" — ","\n"),0.43)
 var vests := chooser_page("vest",1)
 for id in VestKind.KINDS:
  var data: Dictionary=VestKind.DATA[id]
  var tile := choice_tile(118,0.3,func():game.choose_vest(id);pinned="vest:"+id,"vest:"+id)
  vests.add_child(tile);vest_buttons[id]=tile
  tile.get_child(0).show_outfit("ua_pixel" if id!="ratnik" else "rf_digital","",false,false,id)
  tile_caption(tile,"%s\n%.1f кг · плити %s\nВід уламків: %d %% шкоди проходить" % [data.name,float(data.mass),data["class"],roundi(VestKind.blast_factor(id)*100.0)],0.31)
 chooser.hide()

func build_footer() -> void:
 load_label=UiKit.text("",13,UiKit.INK,"head")
 load_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 game.place(load_label,self,LEFT[0],0.848,LEFT[1],0.898)
 notice=UiKit.wrapped("Наведи на річ — опис праворуч. Клітинки бійця — змінити спорядження; ЛКМ у складі — у наплічник, ПКМ у наплічнику — прибрати.",11,UiKit.ACCENT)
 notice.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 game.place(notice,self,MIDDLE[0],0.845,MIDDLE[1],0.9)
 var presets := HBoxContainer.new();presets.add_theme_constant_override("separation",4)
 game.place(presets,self,RIGHT[0],0.85,RIGHT[1],0.895)
 preset_select=OptionButton.new();preset_select.size_flags_horizontal=SIZE_EXPAND_FILL;preset_select.clip_text=true
 preset_select.add_theme_font_size_override("font_size",12)
 preset_select.item_selected.connect(load_selected)
 presets.add_child(preset_select)
 preset_name=LineEdit.new();preset_name.placeholder_text="Назва комплекту";preset_name.max_length=32
 preset_name.add_theme_font_size_override("font_size",12)
 preset_name.size_flags_horizontal=SIZE_EXPAND_FILL;presets.add_child(preset_name)
 var save := small_button("ЗБЕРЕГТИ",save_preset);save.custom_minimum_size.y=0;save.add_theme_font_size_override("font_size",12)
 presets.add_child(save)
 # The operation this loadout goes to, and the way to start it.
 var operation := VBoxContainer.new();operation.add_theme_constant_override("separation",0)
 game.place(operation,self,0.035,0.91,0.45,0.99)
 operation.add_child(UiKit.text("ОПЕРАЦІЯ",12,UiKit.MUTED,"head"))
 operation_label=UiKit.text("",26,UiKit.INK,"display");operation.add_child(operation_label)
 var change := HBoxContainer.new();change.add_theme_constant_override("separation",8)
 game.place(change,self,0.45,0.92,0.7,0.98)
 change.add_child(small_button("КАМПАНІЯ",func():game.main_menu.show_screen("campaign")))
 change.add_child(small_button("ВЕЛИКИЙ ШТУРМ",func():game.main_menu.show_screen("battle")))
 launch=UiKit.cta("ПОЧАТИ ОПЕРАЦІЮ   →",game.begin_operation)
 game.place(launch,self,0.715,0.91,0.965,0.985)

func small_button(title: String, callback: Callable) -> Button:
 var result: Button=game.button(title,callback)
 result.add_theme_font_size_override("font_size",14)
 return result

# --- The examine panel -----------------------------------------------------------
class StatBar extends Control:
 var caption := ""
 var value := 0.0
 var reading := ""
 func _init(title: String, amount: float, shown: String) -> void:
  caption=title;value=clampf(amount,0.0,1.0);reading=shown
  custom_minimum_size=Vector2(0,17)
  mouse_filter=MOUSE_FILTER_IGNORE
 func _draw() -> void:
  var font := UiKit.font("head")
  var width := size.x
  draw_string(font,Vector2(0,12),caption,HORIZONTAL_ALIGNMENT_LEFT,width*0.36,11,UiKit.MUTED)
  # The reading takes the room it needs at the right; the bar the rest.
  var reading_width := maxf(font.get_string_size(reading,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x,width*0.27)
  var bar := Rect2(width*0.37,6,maxf(width*0.63-reading_width-8.0,10.0),5)
  draw_rect(bar,Color(1,1,1,0.09))
  draw_rect(Rect2(bar.position,Vector2(bar.size.x*value,bar.size.y)),UiKit.ACCENT)
  draw_string(font,Vector2(width-reading_width,12),reading,HORIZONTAL_ALIGNMENT_RIGHT,reading_width,11,UiKit.SOFT)

func bar(title: String, amount: float, shown: String) -> void:
 examine_bars.add_child(StatBar.new(title,amount,shown))

# What a slot of the doll holds, for the examine panel.
func slot_subject(kind: String) -> String:
 match kind:
  "face":return "face:"+game.player_face
  "outfit":return "outfit:"+game.player_outfit
  "vest":return "vest:"+game.player_vest
 return "pack"

func inspect_rest() -> void:
 inspect(pinned if pinned!="" else "class:"+game.player_class)

func inspect(subject: String) -> void:
 if not is_instance_valid(examine_bars):return
 examined=subject
 for child in examine_bars.get_children():child.queue_free()
 var kind := subject.get_slice(":",0)
 var id := subject.get_slice(":",1)
 match kind:
  "class":
   examine_kicker.text="КЛАС"
   examine_title.text=PlayerClass.TITLES[id]
   class_brief.text=PlayerClass.BRIEF[id]
   examine_preview.show_weapon(PlayerClass.PRIMARY[id][0])
   # The kit as it is now: what the man carries and how fast he runs.
   if id==game.player_class:
    var weight:=kit_weight()
    var used: int=game.loadout_bag.used_slots()
    bar("ВАГА КОМПЛЕКТУ",weight/40.0,"%.1f кг" % weight)
    bar("БІГ",Equipment.run_multiplier(weight),"%.1f км/год" % (6.3*3.6*Equipment.run_multiplier(weight)))
    bar("НАПЛІЧНИК",float(used)/24.0,"%d / 24" % used)
  "weapon":
   var weapon: Dictionary=WeaponState.DATA[id]
   examine_kicker.text="ЗБРОЯ · "+weapon.caliber
   examine_title.text=weapon.name
   class_brief.text="Режими: %s. %s" % [" / ".join(weapon.modes),"Оптика ПСО-1, 4×." if id=="svd" else "Механічні прицільні пристрої."]
   examine_preview.show_weapon(id)
   bar("МАГАЗИН",float(weapon.capacity)/100.0,str(weapon.capacity))
   bar("ШВИДКІСТЬ КУЛІ",float(Ballistics.PROFILES[id].speed)/1000.0,"%d м/с" % roundi(float(Ballistics.PROFILES[id].speed)))
   if " / ".join(weapon.modes).contains("АВТО") or weapon.modes.has("3 ПОСТРІЛИ"):bar("ТЕМП",60.0/float(weapon.interval)/1000.0,"%d/хв" % roundi(60.0/float(weapon.interval)))
   bar("ВІДДАЧА",float(weapon.recoil)/0.05,"%.0f %%" % (float(weapon.recoil)/0.05*100.0))
   bar("МАСА",float(Equipment.WEAPON_MASS[id])/8.0,"%.2f кг" % float(Equipment.WEAPON_MASS[id]))
  "item":
   var entry: Dictionary=Equipment.ITEMS[id]
   examine_kicker.text="НАПЛІЧНИК · %d × %d" % [entry.size.x,entry.size.y]
   examine_title.text=entry.name
   class_brief.text=str(entry.get("description",""))
   examine_preview.show_item(id)
   bar("МАСА",float(entry.mass)/BackpackState.MAX_PAYLOAD,"%.2f кг" % float(entry.mass))
   bar("МІСЦЕ",float(entry.size.x*entry.size.y)/24.0,"%d кл." % (entry.size.x*entry.size.y))
   if not PlayerClass.allows(game.player_class,id):examine_kicker.text+=" · НЕ ДЛЯ ЦЬОГО КЛАСУ"
  "vest":
   var data: Dictionary=VestKind.DATA[id]
   var mass: float=VestKind.BODY_GEAR_MASS+float(data.mass)
   examine_kicker.text="БРОНЕЖИЛЕТ · ПЛИТИ "+String(data["class"])
   examine_title.text=data.name
   class_brief.text=data.brief
   examine_preview.show_outfit("ua_pixel" if id!="ratnik" else "rf_digital","",false,false,id)
   bar("ПЛИТИ",float(data.rating)/1.6,String(data["class"]))
   bar("ВІД УЛАМКІВ",1.0-VestKind.blast_factor(id),"%d %%" % roundi((1.0-VestKind.blast_factor(id))*100.0))
   bar("МАСА",float(data.mass)/12.0,"%.1f кг" % float(data.mass))
   bar("БІГ БЕЗ ЗБРОЇ",Equipment.run_multiplier(mass),"%.1f км/год" % (6.3*3.6*Equipment.run_multiplier(mass)))
  "face":
   examine_kicker.text="ОБЛИЧЧЯ"
   examine_title.text=FaceCover.label(id)
   class_brief.text=FaceCover.DATA[FaceCover.valid(id)].brief
   examine_preview.show_head(game.player_outfit,id)
   if FaceCover.mass(id)>0:bar("МАСА",FaceCover.mass(id)/0.2,"%d г" % roundi(FaceCover.mass(id)*1000))
  "outfit":
   var index := Wardrobe.IDS.find(id)
   examine_kicker.text="ФОРМА"
   examine_title.text=Wardrobe.LABELS[index].get_slice(" — ",0)
   class_brief.text=Wardrobe.LABELS[index]+". Форма, шолом і чохли — в одному камуфляжі; камуфляжна балаклава — з тієї ж тканини."
   examine_preview.show_outfit(id)
  "pack":
   var bag: BackpackState=game.loadout_bag
   examine_kicker.text="НАПЛІЧНИК · 6 × 4"
   examine_title.text="Штурмовий 30 л" if bag.equipped else "Без наплічника"
   class_brief.text="Важке — у наплічник: дрони, постріли, міни, запасні магазини. Діставати з нього довше, ніж з розвантаження (TAB у бою). Ліміт вантажу %d кг." % roundi(BackpackState.MAX_PAYLOAD)
   examine_preview.show_item("backpack")
   if bag.equipped:
    bar("МІСЦЕ",bag.used_slots()/24.0,"%d / 24" % bag.used_slots())
    bar("ВАНТАЖ",bag.mass()/BackpackState.MAX_PAYLOAD,"%.1f кг" % bag.mass())

# --- State ---------------------------------------------------------------------
# All the man carries: weapons, the pack and its load, the vest, the face cover
# (and the mortar's barrel and bipod).
func kit_weight() -> float:
 var weight := Equipment.carried_mass([WeaponState.new(game.primary),WeaponState.new(game.secondary)],game.loadout_bag,2,game.player_vest)+FaceCover.mass(game.player_face)
 if game.player_class=="mortarman":weight+=PlayerClass.BARREL_AND_BIPOD
 return weight

func refresh() -> void:
 if not is_instance_valid(portrait):return
 var bag: BackpackState=game.loadout_bag
 portrait.show_outfit(game.player_outfit,game.primary,bag.equipped,bag.count("rpo_a")>0,game.player_vest,game.player_face)
 game.outfit_caption.text=Wardrobe.LABELS[Wardrobe.IDS.find(game.player_outfit)]+" · "+VestKind.label(game.player_vest)
 slots.face.preview.show_head(game.player_outfit,game.player_face)
 slots.face.caption.text=String(FaceCover.DATA[FaceCover.valid(game.player_face)].short)
 slots.outfit.preview.show_outfit(game.player_outfit)
 slots.outfit.caption.text=Wardrobe.LABELS[Wardrobe.IDS.find(game.player_outfit)].get_slice(" — ",0).get_slice(" / ",1).to_upper()
 slots.vest.preview.show_outfit(game.player_outfit,"",false,false,game.player_vest)
 slots.vest.caption.text=VestKind.label(game.player_vest)
 slots.pack.preview.show_item("backpack")
 slots.pack.preview.modulate.a=1.0 if bag.equipped else 0.25
 slots.pack.caption.text="%d / 24" % bag.used_slots() if bag.equipped else "НЕМАЄ"
 for id in vest_buttons:vest_buttons[id].set_pressed_no_signal(id==game.player_vest)
 for id in face_buttons:
  face_buttons[id].set_pressed_no_signal(id==game.player_face)
  face_buttons[id].get_child(0).show_head(game.player_outfit,id)
 vest_label.text="%s · МАГАЗИНИ R + 1 / 2 / 3 · ДАЛЕКОМІР K" % VestKind.label(game.player_vest)
 for i in range(game.outfit_buttons.size()):game.outfit_buttons[i].button_pressed=Wardrobe.IDS[i]==game.player_outfit
 pack_select.select(1 if bag.equipped else 0)
 pack_grid.bag=bag;pack_grid.refresh()
 for id in class_buttons:class_buttons[id].set_pressed_no_signal(id==game.player_class)
 for kind in catalog_tiles:catalog_tiles[kind].visible=PlayerClass.allows(game.player_class,kind)
 var weight := kit_weight()
 load_label.text="ВАГА  %.1f кг   ·   БІГ  %.1f км/год   ·   НАПЛІЧНИК  %d / 24" % [weight,6.3*3.6*Equipment.run_multiplier(weight),bag.used_slots()]
 # The class shown is the one chosen, however it was chosen.
 inspect(examined if examined!="" and not examined.begins_with("class:") else "class:"+game.player_class)

func open_chooser(kind: String) -> void:
 chooser_kind=kind
 for key in chooser_pages:chooser_pages[key].visible=key==kind
 chooser_title.text={"face":"ОБЛИЧЧЯ · ОБЕРИ","outfit":"ФОРМА · ОБЕРИ КАМУФЛЯЖ","vest":"БРОНЕЖИЛЕТ · ОБЕРИ"}[kind]
 chooser.show()
 refresh()

func close_chooser() -> void:
 chooser.hide();chooser_kind=""

# Esc: the topmost list over the screen closes first. False when none was open.
func dismiss() -> bool:
 if is_instance_valid(picker) and picker.visible:picker.hide();return true
 if is_instance_valid(chooser) and chooser.visible:close_chooser();return true
 return false

func toggle_pack() -> void:select_pack(0 if game.loadout_bag.equipped else 1)

func changed() -> void:refresh();game.save_settings()
func choose_class(id: String) -> void:
 var removed: Array=game.set_player_class(id)
 picker.hide();pinned="";examined="class:"+id;refresh()
 notice.text="Клас: %s.%s" % [PlayerClass.TITLES[game.player_class]," Прибрано з наплічника: "+", ".join(removed) if not removed.is_empty() else ""]
func select_pack(index: int) -> void:
 if index==0 and not game.loadout_bag.items.is_empty():
  notice.text="Спершу вийми речі з наплічника (ПКМ по речі).";pack_select.select(1);return
 game.loadout_bag.equipped=index==1;changed()
func add_item(kind: String) -> void:
 if not PlayerClass.allows(game.player_class,kind):return
 if game.loadout_bag.add(kind)<0:notice.text="Спершу одягни наплічник. Для речі потрібне вільне місце; ліміт вантажу — 18 кг."
 else:notice.text="Додано: "+Equipment.ITEMS[kind].name;changed()
func snapshot() -> Dictionary:return {"class":game.player_class,"primary":game.primary,"secondary":game.secondary,"outfit":game.player_outfit,"vest":game.player_vest,"face":game.player_face,"backpack":game.loadout_bag.serialize()}
func refresh_presets() -> void:
 preset_select.clear();preset_select.add_item("Комплекти…")
 for title in store.presets:preset_select.add_item(title)
func save_preset() -> void:
 if game.get_meta("automated_preview",false):store.path="user://test-loadouts.cfg"
 var result := store.save_preset(preset_name.text,snapshot())
 notice.text="Комплект збережено: "+preset_name.text.strip_edges() if result==OK else "Не вдалося зберегти. Вкажи назву (до 32 символів), максимум 24 комплекти."
 if result==OK:refresh_presets();game.save_settings()
func load_selected(index: int) -> void:
 if index<=0:return
 var title := preset_select.get_item_text(index)
 var data: Dictionary=store.presets[title]
 game.primary=data.primary;game.secondary=data.secondary;game.player_outfit=data.outfit
 game.player_vest=VestKind.valid(str(data.get("vest",game.player_vest)))
 game.player_face=FaceCover.valid(str(data.get("face",game.player_face)))
 game.loadout_bag=BackpackState.restore(data.backpack)
 game.set_player_class(data.get("class",PlayerClass.infer(data.primary)))
 preset_name.text=title;game.refresh_inventory();changed();notice.text="Завантажено: "+title

func _process(_delta: float) -> void:
 if not is_visible_in_tree():return
 if is_instance_valid(launch):launch.text="ПОЧАТИ ШТУРМ   →" if game.selected_map==BattleMap.ID else "ПОЧАТИ ОПЕРАЦІЮ   →"
 if is_instance_valid(operation_label):operation_label.text=game.operation_title()
