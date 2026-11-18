class_name LoadoutScreen
extends Control

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

func setup(owner_game: Node3D, parent: Control) -> void:
 game=owner_game
 game.place(self,parent,0,0,1,1)
 UiKit.sheet(game,self,0.84)
 UiKit.header(game,self,"ГОЛОВНЕ МЕНЮ   /   СПОРЯДЖЕННЯ","СПОРЯДЖЕННЯ","",func():game.main_menu.back())
 var preset_row := HBoxContainer.new()
 preset_row.add_theme_constant_override("separation",10)
 game.place(preset_row,self,0.035,0.2,0.965,0.25)
 var preset_caption:=UiKit.text("КОМПЛЕКТ",14,UiKit.ACCENT,"head");preset_caption.size_flags_vertical=SIZE_SHRINK_CENTER
 preset_row.add_child(preset_caption)
 preset_select=OptionButton.new();preset_select.custom_minimum_size.x=200
 preset_select.size_flags_horizontal=SIZE_EXPAND_FILL
 preset_select.item_selected.connect(load_selected)
 preset_row.add_child(preset_select)
 preset_name=LineEdit.new();preset_name.placeholder_text="Назва комплекту";preset_name.max_length=32
 preset_name.size_flags_horizontal=SIZE_EXPAND_FILL;preset_row.add_child(preset_name)
 preset_row.add_child(small_button("ЗБЕРЕГТИ / ОНОВИТИ",save_preset))
 store.read();refresh_presets()
 game.place(UiKit.text("01 / БОЄЦЬ",14,UiKit.ACCENT,"head"),self,0.035,0.27,0.26,0.3)
 portrait=ModelPreview.new()
 game.place(portrait,self,0.035,0.3,0.26,0.7)
 game.outfit_preview=portrait.viewport
 game.place(small_button("↶   ПОВЕРНУТИ БІЙЦЯ",func():portrait.rear_view=not portrait.rear_view;portrait.fit()),self,0.045,0.705,0.25,0.75)
 game.outfit_caption=UiKit.text("",14,UiKit.ACCENT,"head")
 game.outfit_caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 game.place(game.outfit_caption,self,0.035,0.765,0.27,0.8)
 load_label=UiKit.wrapped("",15,UiKit.SOFT)
 game.place(load_label,self,0.035,0.805,0.28,0.88)
 var tabs := TabContainer.new()
 game.place(tabs,self,0.285,0.27,0.615,0.855)
 var weapons_page := ScrollContainer.new();weapons_page.name="КЛАС І ЗБРОЯ";tabs.add_child(weapons_page)
 weapons_page.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var weapons := VBoxContainer.new();weapons.size_flags_horizontal=SIZE_EXPAND_FILL;weapons_page.add_child(weapons)
 weapons.add_theme_constant_override("separation",5)
 var classes := GridContainer.new();classes.columns=2
 classes.add_theme_constant_override("h_separation",6);classes.add_theme_constant_override("v_separation",6);weapons.add_child(classes)
 for id in PlayerClass.IDS:
  var choice := small_button(PlayerClass.TITLES[id],choose_class.bind(id))
  choice.toggle_mode=true;choice.size_flags_horizontal=SIZE_EXPAND_FILL;choice.custom_minimum_size.y=40
  choice.alignment=HORIZONTAL_ALIGNMENT_CENTER
  classes.add_child(choice);class_buttons[id]=choice
 class_brief=UiKit.wrapped("",13,UiKit.SOFT)
 weapons.add_child(class_brief)
 game.primary_tile=game.inventory_slot("rifle","ОСНОВНА ЗБРОЯ","",84)
 weapons.add_child(game.primary_tile)
 game.primary_tile.pressed.connect(func():picker.open(false))
 game.secondary_tile=game.inventory_slot("pistol","ПІСТОЛЕТ","",64)
 weapons.add_child(game.secondary_tile)
 game.secondary_tile.pressed.connect(func():picker.open(true))
 weapons.add_child(UiKit.text("ПЛИТОНОСКА · R + 1 / 2 / 3",12,UiKit.ACCENT,"head"))
 var vest := HBoxContainer.new();weapons.add_child(vest)
 for i in range(3):
  var tile: Button=game.inventory_slot("magazine",str(i+1),"",46)
  tile.mouse_filter=MOUSE_FILTER_IGNORE;vest.add_child(tile);game.rifle_mag_tiles.append(tile)
 weapons.add_child(UiKit.text("ПОЯС · 2 МАГАЗИНИ ДО ПІСТОЛЕТА · 2 АПТЕЧКИ (H) · БРОНЯ · ДАЛЕКОМІР (K)",12,UiKit.ACCENT,"head"))
 var belt := HBoxContainer.new();weapons.add_child(belt)
 for i in range(2):
  var tile: Button=game.inventory_slot("magazine",str(i+1),"",42)
  tile.mouse_filter=MOUSE_FILTER_IGNORE;belt.add_child(tile);game.pistol_mag_tiles.append(tile)
 for i in range(Operator.BELT_MEDKITS):
  var tile: Button=game.inventory_slot("medkit","✚","",42)
  tile.mouse_filter=MOUSE_FILTER_IGNORE;belt.add_child(tile);game.medkit_tiles.append(tile)
  tile.tooltip_text="Аптечка на поясі. Після використання в бою на її місце можна прикріпити аптечку з наплічника (TAB)."
 var finder: Button=game.inventory_slot("rangefinder","K","",42)
 finder.mouse_filter=MOUSE_FILTER_IGNORE;belt.add_child(finder);finder.show_item("rangefinder")
 finder.tooltip_text="Лазерний далекомір у підсумку на броні: K — дістати за секунду, ще раз K — прибрати."
 var outfits := ScrollContainer.new();outfits.name="ОДЯГ";tabs.add_child(outfits)
 outfits.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var wardrobe := GridContainer.new();wardrobe.columns=2;wardrobe.size_flags_horizontal=SIZE_EXPAND_FILL
 outfits.add_child(wardrobe)
 for i in range(Wardrobe.IDS.size()):
  var tile: Button=small_button("",game.choose_outfit.bind(i))
  tile.custom_minimum_size=Vector2(0,102);tile.size_flags_horizontal=SIZE_EXPAND_FILL;tile.toggle_mode=true
  wardrobe.add_child(tile);game.outfit_buttons.append(tile)
  var thumbnail := ModelPreview.new();game.place(thumbnail,tile,0,0,0.43,1)
  thumbnail.show_outfit(Wardrobe.IDS[i])
  var caption: Label=UiKit.text(Wardrobe.LABELS[i].replace(" / ","\n").replace(" — ","\n"),12,UiKit.SOFT,"head")
  caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.mouse_filter=MOUSE_FILTER_IGNORE
  game.place(caption,tile,0.43,0.07,0.97,0.95)
 game.place(UiKit.text("03 / НАПЛІЧНИК",14,UiKit.ACCENT,"head"),self,0.64,0.27,0.965,0.3)
 pack_select=OptionButton.new();pack_select.add_item("Без наплічника");pack_select.add_item("Штурмовий 30 л · 24 клітинки · 1,35 кг")
 pack_select.add_theme_font_size_override("font_size",14)
 game.place(pack_select,self,0.64,0.305,0.965,0.355)
 pack_select.item_selected.connect(select_pack)
 pack_grid=PackGrid.new();pack_grid.editable=true
 game.place(pack_grid,self,0.64,0.365,0.965,0.59)
 pack_grid.changed.connect(changed)
 pack_grid.selected.connect(func(uid: int):var e: Dictionary=game.loadout_bag.item(uid);notice.text=Equipment.ITEMS[e.kind].name+" · ПКМ — прибрати · перетягни, щоб перемістити")
 game.place(UiKit.text("ДОДАТИ · ЛКМ   /   ПРИБРАТИ · ПКМ",12,UiKit.ACCENT,"head"),self,0.64,0.595,0.965,0.625)
 var scroll := ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 game.place(scroll,self,0.64,0.63,0.965,0.855)
 var catalog := GridContainer.new();catalog.columns=2;catalog.size_flags_horizontal=SIZE_EXPAND_FILL
 scroll.add_child(catalog)
 for kind in Equipment.ITEMS:
  var entry: Dictionary=Equipment.ITEMS[kind]
  var tile := small_button("",add_item.bind(kind));tile.custom_minimum_size=Vector2(0,36);tile.size_flags_horizontal=SIZE_EXPAND_FILL
  catalog.add_child(tile);catalog_tiles[kind]=tile
  var thumbnail := ModelPreview.new();game.place(thumbnail,tile,0,0,0.36,1);thumbnail.show_item(kind)
  var caption: Label=UiKit.text(entry.name+"\n%d × %d" % [entry.size.x,entry.size.y],11,UiKit.SOFT,"head")
  caption.mouse_filter=MOUSE_FILTER_IGNORE;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  game.place(caption,tile,0.36,0.08,0.98,0.95)
  tile.tooltip_text="Додати до наплічника: "+entry.name+"\n"+str(entry.get("description",""))
 notice=UiKit.wrapped("Обери наплічник і додай речі. Магазини та 2 аптечки на поясі вже споряджені. Що можна взяти, визначає клас.",13,UiKit.ACCENT)
 game.place(notice,self,0.285,0.865,0.965,0.905)
 # The operation this loadout goes to, and the way to start it.
 var operation := VBoxContainer.new();operation.add_theme_constant_override("separation",0)
 game.place(operation,self,0.035,0.915,0.45,0.99)
 operation.add_child(UiKit.text("ОПЕРАЦІЯ",12,UiKit.MUTED,"head"))
 operation_label=UiKit.text("",26,UiKit.INK,"display");operation.add_child(operation_label)
 var change := HBoxContainer.new();change.add_theme_constant_override("separation",8)
 game.place(change,self,0.45,0.925,0.7,0.98)
 change.add_child(small_button("КАМПАНІЯ",func():game.main_menu.show_screen("campaign")))
 change.add_child(small_button("ВЕЛИКИЙ ШТУРМ",func():game.main_menu.show_screen("battle")))
 launch=UiKit.cta("ПОЧАТИ ОПЕРАЦІЮ   →",game.begin_operation)
 game.place(launch,self,0.715,0.915,0.965,0.985)
 game.map_description=game.label("",12);game.map_description.hide();add_child(game.map_description)
 picker=WeaponPicker.new();add_child(picker);picker.setup(game)
 refresh()

func small_button(title: String, callback: Callable) -> Button:
 var result: Button=game.button(title,callback)
 result.add_theme_font_size_override("font_size",14)
 return result

func refresh() -> void:
 if not is_instance_valid(portrait):return
 portrait.show_outfit(game.player_outfit,game.primary,game.loadout_bag.equipped,game.loadout_bag.count("rpo_a")>0)
 game.outfit_caption.text=Wardrobe.LABELS[Wardrobe.IDS.find(game.player_outfit)]
 for i in range(game.outfit_buttons.size()):game.outfit_buttons[i].button_pressed=Wardrobe.IDS[i]==game.player_outfit
 pack_select.select(1 if game.loadout_bag.equipped else 0)
 pack_grid.bag=game.loadout_bag;pack_grid.refresh()
 for id in class_buttons:class_buttons[id].set_pressed_no_signal(id==game.player_class)
 class_brief.text=PlayerClass.BRIEF[game.player_class]
 for kind in catalog_tiles:catalog_tiles[kind].visible=PlayerClass.allows(game.player_class,kind)
 var weight := Equipment.carried_mass([WeaponState.new(game.primary),WeaponState.new(game.secondary)],game.loadout_bag)
 if game.player_class=="mortarman":weight+=PlayerClass.BARREL_AND_BIPOD
 load_label.text="СПОРЯДЖЕННЯ  %.1f кг\nБіг: %.1f км/год · наплічник %d / 24" % [weight,6.3*3.6*Equipment.run_multiplier(weight),game.loadout_bag.used_slots()]

func changed() -> void:refresh();game.save_settings()
func choose_class(id: String) -> void:
 var removed: Array=game.set_player_class(id)
 picker.hide();refresh()
 notice.text="Клас: %s.%s" % [PlayerClass.TITLES[game.player_class]," Прибрано з наплічника: "+", ".join(removed) if not removed.is_empty() else ""]
func select_pack(index: int) -> void:
 if index==0 and not game.loadout_bag.items.is_empty():
  notice.text="Спершу вийми речі з наплічника (ПКМ по речі).";pack_select.select(1);return
 game.loadout_bag.equipped=index==1;changed()
func add_item(kind: String) -> void:
 if not PlayerClass.allows(game.player_class,kind):return
 if game.loadout_bag.add(kind)<0:notice.text="Спершу одягни наплічник. Для речі потрібне вільне місце; ліміт вантажу — 18 кг."
 else:notice.text="Додано: "+Equipment.ITEMS[kind].name;changed()
func snapshot() -> Dictionary:return {"class":game.player_class,"primary":game.primary,"secondary":game.secondary,"outfit":game.player_outfit,"backpack":game.loadout_bag.serialize()}
func refresh_presets() -> void:
 preset_select.clear();preset_select.add_item("Завантажити збережений комплект…")
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
 game.loadout_bag=BackpackState.restore(data.backpack)
 game.set_player_class(data.get("class",PlayerClass.infer(data.primary)))
 preset_name.text=title;game.refresh_inventory();changed();notice.text="Завантажено: "+title

func _process(_delta: float) -> void:
 if not is_visible_in_tree():return
 if is_instance_valid(launch):launch.text="ПОЧАТИ ШТУРМ   →" if game.selected_map==BattleMap.ID else "ПОЧАТИ ОПЕРАЦІЮ   →"
 if is_instance_valid(operation_label):operation_label.text=game.operation_title()
