class_name WeaponPicker
extends Control
var game: Node3D
var sidearm := false
var details: Label
var choices: GridContainer

func setup(owner_game: Node3D) -> void:
 game=owner_game
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade := ColorRect.new()
 shade.color=Color(0.01,0.02,0.015,0.97)
 game.place(shade,self,0,0,1,1)
 game.bleed(shade)
 game.place(game.label("АРСЕНАЛ / ОБЕРИ ЗБРОЮ",26,game.GOLD),self,0.08,0.12,0.8,0.20)
 game.place(game.button("ЗАКРИТИ ×",hide),self,0.76,0.12,0.92,0.19)
 choices=GridContainer.new();choices.columns=3
 choices.add_theme_constant_override("h_separation",14)
 game.place(choices,self,0.08,0.27,0.92,0.64)
 details=game.label("Наведи курсор або обери картку клавіатурою — тут з’являться характеристики.",17)
 details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 game.place(details,self,0.08,0.69,0.92,0.88)
 hide()

func options() -> Array:
 return PlayerClass.SECONDARY[game.player_class] if sidearm else PlayerClass.PRIMARY[game.player_class]

func open(pistol: bool) -> void:
 sidearm=pistol
 for child in choices.get_children():choices.remove_child(child);child.queue_free()
 for id in options():
  var tile: Button=game.inventory_slot("pistol" if sidearm else "rifle",WeaponState.DATA[id].name,"ОБРАТИ",230)
  choices.add_child(tile)
  tile.show_weapon(id)
  tile.pressed.connect(select.bind(id))
  tile.mouse_entered.connect(describe.bind(id))
  tile.focus_entered.connect(describe.bind(id))
 describe(game.secondary if sidearm else game.primary)
 show()
 choices.get_child(0).grab_focus()

func describe(id: String) -> void:
 var weapon: Dictionary=WeaponState.DATA[id]
 details.text="%s  ·  %s\nМагазин: %d    Маса без магазину: %.2f кг    Початкова швидкість: %d м/с\nРежими: %s    %s" % [weapon.name,weapon.caliber,weapon.capacity,Equipment.WEAPON_MASS[id],Ballistics.PROFILES[id].speed," / ".join(weapon.modes),"Оптика ПСО-1 · 4× · барабан 100–1000 м" if id=="svd" else "Механічні прицільні пристрої"]
 if id in ["ak74","m16"]:details.text+="\nЦиклічний темп: %d постр./хв" % roundi(60/float(weapon.interval))
 else:details.text+="\nСамозарядна: один постріл на натискання"

func select(id: String) -> void:
 if id not in options():return
 if sidearm:game.secondary=id
 else:game.primary=id
 game.refresh_inventory();game.save_settings();hide()

func _unhandled_key_input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):hide();get_viewport().set_input_as_handled()
