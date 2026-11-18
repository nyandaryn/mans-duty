extends SceneTree
var checks := 0
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  printerr("FAIL: ",message)
  quit(1)
  assert(ok,message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 game.volume=0
 for i in range(3):await process_frame
 check(game.primary_tile.preview.content_key=="ak74false" and game.secondary_tile.preview.content_key=="pmfalse","Initial weapon cards display selected actual models")
 game.primary_tile.pressed.emit()
 check(game.primary=="ak74" and game.loadout_screen.picker.visible,"Click opens grid without changing selected weapon")
 game.loadout_screen.picker.select("m16")
 game.secondary_tile.pressed.emit()
 game.loadout_screen.picker.select("m9")
 check(game.primary=="m16" and game.secondary=="m9","Model overlays preserve clickable weapon switching")
 check(game.primary_tile.preview.content_key=="m16false" and game.secondary_tile.preview.content_key=="m9false","Weapon thumbnails update immediately with selection")
 for tile in game.rifle_mag_tiles:check(tile.preview.content_key=="m16true","Vest shows selected rifle magazine")
 for tile in game.pistol_mag_tiles:check(tile.preview.content_key=="m9true","Belt shows selected pistol magazine")
 check(game.outfit_buttons.size()==7,"All seven outfits have cards")
 for i in range(7):
  var item: Button=game.outfit_buttons[i]
  var preview: ModelPreview=item.get_child(0)
  check(preview.content_key==Wardrobe.IDS[i] and preview.model!=null,"Outfit can be seen before selecting it")
  item.pressed.emit()
  check(game.player_outfit==Wardrobe.IDS[i] and item.button_pressed,"Outfit card selects and highlights its uniform")
  check(game.loadout_screen.portrait.content_key.begins_with(Wardrobe.IDS[i]),"Main character updates from outfit card")
 check(game.outfit_preview.msaa_3d==Viewport.MSAA_4X and game.outfit_preview.size.x>=500,"Main portrait uses supersampled antialiased viewport")
 check(game.primary_tile.preview.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Model display does not intercept menu clicks")
 game.start_match()
 check(game.player.current().id=="m16" and game.player.outfit_id=="ghillie_dry","Selected preview equipment is used by the real player")
 game.queue_free()
 await create_timer(0.2).timeout
 print("PASS: %d loadout preview and selection checks" % checks)
 quit()
