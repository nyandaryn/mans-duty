class_name CombatInventory
extends Control

# Left edge of the gear column, a share of the width; the soldier's column is
# left of it.
const GEAR_LEFT := 0.31
var game: Node3D
var portrait: ModelPreview
var gear_box: VBoxContainer
var medicine: Button
var summary: Label
var message: Label
var progress_bar: ProgressBar
var transfer_button: Button
var stop_button: Button
var tiles: Array[Dictionary]=[]
var source := Vector2i(-1,-1)
var destination := Vector2i(-1,-1)
var transfer := MagazineTransfer.new()
var refresh_left := 0.0
var pack_grid: PackGrid
var source_box := -1
var item_button: Button
var pack_summary: Label
var belt_tiles: Array[Dictionary]=[]

func setup(owner_game: Node3D, parent: Control) -> void:
 game=owner_game
 game.place(self,parent,0,0,1,1)
 mouse_filter=Control.MOUSE_FILTER_STOP
 var backdrop := ColorRect.new()
 backdrop.color=Color(0.025,0.035,0.032,0.97)
 game.place(backdrop,self,0,0,1,1)
 game.bleed(backdrop)
 game.place(game.label("ПОЛЬОВИЙ ІНВЕНТАР",30,game.GOLD),self,0.04,0.045,0.65,0.11)
 game.place(game.label("TAB / ESC · ЗАКРИТИ     БІЙ ТРИВАЄ",13,game.CREAM),self,0.64,0.065,0.97,0.11)
 game.place(game.label("01 / БОЄЦЬ",14,game.GOLD),self,0.04,0.15,0.27,0.20)
 portrait=ModelPreview.new()
 game.place(portrait,self,0.035,0.22,0.28,0.80)
 summary=game.label("",14)
 summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 game.place(summary,self,0.04,0.82,0.28,0.94)
 game.place(game.label("02 / СПОРЯДЖЕННЯ",14,game.GOLD),self,GEAR_LEFT,0.15,0.66,0.20)
 gear_box=VBoxContainer.new()
 gear_box.add_theme_constant_override("separation",8)
 game.place(gear_box,self,GEAR_LEFT,0.22,0.66,0.71)
 # Belt pouches with the first-aid kits; an empty one takes a kit from the pack.
 belt_tiles.clear()
 for i in range(Operator.BELT_MEDKITS):
  var tile: Button=game.button("",attach_medkit.bind(i))
  game.place(tile,self,0.31+i*0.09,0.72,0.395+i*0.09,0.79)
  var preview := ModelPreview.new()
  game.place(preview,tile,0.03,0.06,0.45,0.94)
  preview.show_item("medkit")
  var caption: Label=game.label("",11)
  caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
  game.place(caption,tile,0.46,0.08,0.98,0.95)
  belt_tiles.append({"button":tile,"preview":preview,"caption":caption})
 medicine=game.button("",use_medicine)
 medicine.add_theme_font_size_override("font_size",14)
 game.place(medicine,self,0.495,0.72,0.66,0.79)
 game.place(game.label("03 / НАПЛІЧНИК",14,game.GOLD),self,0.70,0.15,0.96,0.20)
 pack_grid=PackGrid.new()
 game.place(pack_grid,self,0.70,0.23,0.96,0.55)
 pack_grid.selected.connect(select_pack_item)
 pack_summary=game.label("",13,game.GOLD)
 pack_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 game.place(pack_summary,self,0.70,0.57,0.96,0.66)
 item_button=game.button("ДІСТАТИ ПРЕДМЕТ",use_pack_item)
 item_button.add_theme_font_size_override("font_size",13)
 game.place(item_button,self,0.70,0.68,0.96,0.75)
 message=game.label("Обери магазин-джерело, потім магазин-приймач.",13,game.GOLD)
 message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 game.place(message,self,0.31,0.805,0.96,0.855)
 progress_bar=ProgressBar.new()
 progress_bar.max_value=1
 progress_bar.show_percentage=false
 game.place(progress_bar,self,0.31,0.86,0.96,0.88)
 transfer_button=game.button("ПЕРЕКЛАСТИ НАБОЇ",begin_transfer,true)
 transfer_button.add_theme_font_size_override("font_size",15)
 game.place(transfer_button,self,0.31,0.90,0.64,0.965)
 stop_button=game.button("ЗУПИНИТИ / СКИНУТИ",stop_transfer)
 stop_button.add_theme_font_size_override("font_size",14)
 game.place(stop_button,self,0.68,0.90,0.96,0.965)
 hide()

func toggle() -> void:
 if not game.running or game.paused:return
 if game.player.launcher.active():game.player.launcher.toggle();return
 if game.player.is_vaulting():return
 if game.player.field_rig.mode=="drone":game.player.field_rig.cancel()
 # Goggles up, the radio in both hands: no reaching into the pack.
 if game.player.field_rig.mode=="fpv_up" and not visible:game.player.field_rig.drone_notice="Руки зайняті пультом FPV: Y — окуляри, ~ — відпустити дрон.";return
 if visible:close();return
 game.squad.close()
 game.inventory_open=true
 game.player.burst=0
 game.player.firing_sequence_active=false
 game.player.field_rig.cancel()
 source_box=-1
 pack_grid.bag=game.player.backpack
 source=Vector2i(-1,-1)
 destination=source
 show()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 portrait.show_outfit(game.player.outfit_id,game.player.weapons[0].id,game.player.backpack.equipped,game.player.backpack.count("rpo_a")>0)
 build_gear()
 refresh()

func close() -> void:
 transfer.cancel()
 hide()
 game.inventory_open=false
 if game.running and not game.paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func build_gear() -> void:
 tiles.clear()
 for child in gear_box.get_children():
  gear_box.remove_child(child)
  child.queue_free()
 for wi in range(game.player.weapons.size()):
  var w: WeaponState=game.player.weapons[wi]
  gear_box.add_child(game.label(w.data.name+" / "+w.data.caliber+"  ·  "+("ПЛИТОНОСКА" if wi==0 else "ПОЯС"),14,game.GOLD))
  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation",5)
  gear_box.add_child(row)
  for slot in range(w.pouches.size()+1):
   var tile: Button=game.button("",select_magazine.bind(Vector2i(wi,slot)))
   tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   tile.custom_minimum_size=Vector2(0,122)
   row.add_child(tile)
   var preview := ModelPreview.new()
   game.place(preview,tile,0.08,0.04,0.92,0.65)
   preview.show_weapon(w.id,true)
   var caption: Label=game.label("",11)
   caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
   caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   game.place(caption,tile,0.03,0.66,0.97,0.98)
   tiles.append({"key":Vector2i(wi,slot),"button":tile,"caption":caption})

func select_magazine(key: Vector2i) -> void:
 if transfer.active:return
 if source_box>=0:
  var entry: Dictionary=game.player.backpack.item(source_box)
  if not entry.is_empty() and Equipment.ITEMS[entry.kind].get("weapon","")==game.player.weapons[key.x].id:
   destination=key
   if entry.kind=="ammo_pkm":message.text="Дістати цинк і замінити стрічку в коробці цілком (≈%.0f с) · залишок старої стрічки — у цинк." % (FieldRig.ACCESS_TIME+MagazineTransfer.BELT_TIME+2.2)
   else:message.text="Дістати пачку з наплічника та спорядити обраний магазин."
  else:message.text="Калібр пачки не підходить до цього магазину."
  refresh();return
 if source.x<0 or destination.x>=0 or source==key:
  source=key
  destination=Vector2i(-1,-1)
  message.text="Обери магазин-приймач того самого калібру."
  if game.player.weapons[key.x].id=="pkm":message.text="Коробку ПКМ не переспоряджають по набою: обери в наплічнику цинк зі стрічкою, потім цю коробку · у бою R — змінити коробку."
 elif source.x!=key.x:
  message.text="Ці магазини несумісні: різні калібри."
 else:
  destination=key
  message.text="Перенесення по одному набою: 0,9 с на набій + час на магазини."
 refresh()

func hide_for_action() -> void:
 hide()
 game.inventory_open=false
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func select_pack_item(uid: int) -> void:
 if transfer.active:return
 source_box=uid;source=Vector2i(-1,-1);destination=source
 var entry: Dictionary=game.player.backpack.item(uid)
 if entry.kind=="ammo_pkm":message.text="Цинк зі стрічкою на %d · обери коробку ПКМ, потім «ЗАМІНИТИ СТРІЧКУ»: стрічка міняється цілком, залишок старої — у цинк." % int(entry.rounds)
 elif str(entry.kind).begins_with("ammo_"):message.text="Обери магазин відповідного калібру, потім натисни «ПЕРЕКЛАСТИ НАБОЇ»."
 elif entry.kind=="recon_drone":message.text="Дістати й розкласти дрон · J — FPV-окуляри · після посадки F поруч — забрати."
 elif entry.kind=="rpo_a":message.text="Одноразовий РПО-А · 4 — дістати / прибрати · ПКМ — приціл · ЛКМ — постріл."
 elif entry.kind=="rpg7":message.text="РПГ-7В1 з ПГО-7В3 · 4 — дістати / прибрати · R — зарядити (6 с; утримай — вибір пострілу) · ПКМ — приціл · ЛКМ — постріл."
 elif entry.kind=="pg7vl":message.text="Постріл ПГ-7ВЛ · з РПГ-7 у руках R — зарядити (утримай R — вибір пострілу). Шеврони ПГО-7: 2…5 — 200…500 м."
 elif entry.kind=="og7v":message.text="Постріл ОГ-7В · осколковий, по піхоті · з РПГ-7 у руках утримай R — вибір пострілу. ПГО-7 розмічений під ПГ-7ВЛ: бери поправку з підказки."
 elif entry.kind=="tbg7v":message.text="Постріл ТБГ-7В · термобаричний, по будівлях, окопах і легкій броні · з РПГ-7 у руках утримай R — вибір пострілу. Прямий постріл 150 м: поправка ПГО-7 — у підказці."
 elif entry.kind=="rpg22" and entry.get("extended",false)==true:message.text="РПГ-22 уже в бойовому положенні (скласти назад не можна) · 4 / 5 — зняти з кріплення й стріляти."
 elif entry.kind=="rpg22":message.text="Одноразовий РПГ-22 у похідному положенні · 4 / 5 — зняти з кріплення · R — привести в бойове (6 с, назад не складається) · рамка 5 / 15 / 25 — 50 / 150 / 250 м."
 elif entry.kind in Equipment.FPV:message.text="FPV-дрон · Y — дістати, поставити й надіти окуляри · ЛКМ у польоті — підрив."
 elif entry.kind=="medkit":message.text="Аптечка · порожнє місце на поясі — прикріпити (3,4 с) · «ДІСТАТИ ПРЕДМЕТ» — одразу лікуватися."
 else:message.text="Діставання займає 3,4 с. ЛКМ — виміряти; K — прибрати далекомір."
 refresh()

# Inside a vehicle (the BMP's seats, not the hatch): the magazines and the
# first-aid kit only; the driver keeps his hands on the levers.
func inside_vehicle() -> bool:
 return is_instance_valid(game.bmp) and game.bmp.seat!="" and not game.bmp.head_out

func use_pack_item() -> void:
 if inside_vehicle() and game.player.backpack.item(source_box).get("kind","")!="medkit":
  message.text="У машині з наплічника — лише пачки з набоями й аптечка. Дрон, далекомір і гранатомети — назовні або з люка."
  return
 if game.player.backpack.item(source_box).get("kind","") in LauncherRig.KINDS:
  if game.player.launcher.equip(source_box):hide_for_action()
  else:message.text="Гранатомет недоступний: руки зайняті, поранення або контузія."
  return
 if game.player.field_rig.request(source_box):hide_for_action()
 else:message.text="Предмет зараз недоступний: перевір поранення, стан зброї та потребу в лікуванні."

func begin_transfer() -> void:
 if destination.x<0 or not can_handle():return
 if inside_vehicle() and game.bmp.seat=="driver":
  message.text="Механік-водій тримає важелі: магазини споряджають у десанті або на зупинці, вийшовши з місця."
  return
 var w: WeaponState=game.player.weapons[destination.x]
 var started := false
 if source_box>=0:started=transfer.begin_box(w,game.player.backpack,source_box,destination.y)
 elif source.x==destination.x:started=transfer.begin(w,source.y,destination.y)
 if not started:
  message.text="Порожнє джерело, повний приймач, несумісний калібр або зброя зайнята."
  if w.id=="pkm":message.text="Стрічку ПКМ міняють цілком: лише на стрічку, довшу за ту, що в коробці (цинк із наплічника)." if source_box>=0 else "Коробку ПКМ не переспоряджають по набою: обери в наплічнику цинк зі стрічкою."
  return
 game.player.burst=0
 hide_for_action()

func can_handle() -> bool:
 return game.player.arm_injury<0.5 and game.player.injury_time<=0 and game.player.bandage_time<=0 and game.player.concussion.blackout_left<=0 and not game.player.concussion.incapacitated()

func stop_transfer() -> void:
 transfer.cancel()
 source=Vector2i(-1,-1)
 source_box=-1
 destination=source
 message.text="Обери магазин-джерело, потім магазин-приймач."
 refresh()

# Replaces a used belt kit with one from the backpack: the selected kit, or
# the first one found. The reach into the pack takes as long as for any item.
func attach_medkit(slot: int) -> void:
 if transfer.active:return
 if slot<game.player.bandages:
  message.text="Аптечка вже на поясі · H або «ЛІКУВАННЯ» — використати."
  return
 var uid: int=source_box if game.player.backpack.item(source_box).get("kind","")=="medkit" else game.player.backpack.first("medkit")
 if uid<0:
  message.text="У наплічнику немає аптечок."
  return
 if game.player.field_rig.attach_medkit(uid):return
 message.text="Зараз неможливо: руки зайняті, поранення, лікування або контузія."
 refresh()

func use_medicine() -> void:
 transfer.cancel()
 if game.player.begin_bandage():
  message.text="Накладання пов’язки · 6 секунд. Нове поранення перерве дію."
 refresh()

func refresh() -> void:
 if not is_instance_valid(game.player):return
 for tile in tiles:
  var key: Vector2i=tile.key
  var w: WeaponState=game.player.weapons[key.x]
  var mag := MagazineTransfer.magazine_at(w,key.y)
  tile.caption.text=("У ЗБРОЇ" if key.y==0 else "ПІДСУМОК %d" % key.y)+("\nМАГАЗИН ВИЙНЯТО" if mag.is_empty() else "")
  var color: Color=game.GOLD if key==source else (Color("81b49c") if key==destination else Color("465043"))
  tile.button.add_theme_stylebox_override("normal",game.panel_style(Color("1c2822"),color))
 var spare: int=game.player.backpack.count("medkit")
 var picked: bool=game.player.backpack.item(source_box).get("kind","")=="medkit"
 for i in range(belt_tiles.size()):
  var tile: Dictionary=belt_tiles[i]
  var filled: bool=i<game.player.bandages
  tile.preview.visible=filled
  tile.caption.anchor_left=0.46 if filled else 0.08
  tile.caption.text="ПОЯС %d\n%s" % [i+1,"АПТЕЧКА" if filled else ("ПРИКРІПИТИ" if spare>0 else "ПОРОЖНЬО")]
  var edge: Color=Color("81b49c") if not filled and spare>0 and picked else Color("465043")
  tile.button.add_theme_stylebox_override("normal",game.panel_style(Color("1c2822") if filled else Color("141b17"),edge))
 medicine.text="%s\nпояс %d · наплічник %d" % ["✚ ЛІКУВАННЯ %.1f с" % game.player.bandage_time if game.player.bandage_time>0 else "✚ ЛІКУВАТИСЯ · 6 с",game.player.bandages,spare]
 medicine.disabled=game.player.medical_count()<=0 or game.player.bandage_time>0 or not game.player.needs_bandage()
 pack_grid.refresh()
 pack_summary.text="Вантаж: %.1f кг · %d / 24 клітинки\nK — дістати / прибрати далекомір" % [game.player.backpack.mass(),game.player.backpack.used_slots()]
 var selected: Dictionary=game.player.backpack.item(source_box)
 item_button.disabled=selected.is_empty() or selected.get("kind","") not in ["medkit","rangefinder","recon_drone","rpo_a","rpg7","rpg22","fpv_heat","fpv_frag"] or game.player.injury_time>0 or game.player.bandage_time>0 or game.player.concussion.incapacitated() or game.player.concussion.blackout_left>0 or (game.player.arm_injury>=0.5 and selected.get("kind","")!="medkit")
 summary.text=Wardrobe.LABELS[Wardrobe.IDS.find(game.player.outfit_id)]+"\nСпорядження: %.1f кг\nБіг: %.1f км/год" % [game.player.carried_mass(),6.3*3.6*Equipment.run_multiplier(game.player.carried_mass())]
 transfer_button.disabled=(source.x<0 and source_box<0) or destination.x<0 or transfer.active or not can_handle()
 var belt: bool=selected.get("kind","")=="ammo_pkm" or (source.x>=0 and game.player.weapons[source.x].id=="pkm") or (destination.x>=0 and game.player.weapons[destination.x].id=="pkm")
 transfer_button.text="ЗАМІНИТИ СТРІЧКУ" if belt else "ПЕРЕКЛАСТИ НАБОЇ"
 progress_bar.visible=game.player.bandage_time>0
 progress_bar.value=1-game.player.bandage_time/6.0 if game.player.bandage_time>0 else 0

func _process(delta: float) -> void:
 if (not visible and not transfer.active) or not is_instance_valid(game.player) or not game.running or game.paused:return
 if transfer.active:
  if not can_handle():
   transfer.cancel()
   message.text="Роботу з магазинами перервано пораненням або лікуванням."
  else:
   transfer.update(delta)
   if not transfer.active:game.player.field_rig.visible=false
   message.text="ПЕРЕКЛАДАННЯ НАБОЇВ" if transfer.active else "ГОТОВО"
 refresh_left-=delta
 if refresh_left<=0:
  refresh_left=0.15
  refresh()
