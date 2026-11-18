extends SceneTree
var game: Node3D
func _initialize():call_deferred("run")
func capture(title: String) -> void:
 for i in range(6):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("MANS_CAPTURE_DIR")+"/"+title+".png")
func run():
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 root.size=Vector2i(1280,720)
 game.volume=0;game.loadout_bag.equipped=true
 for kind in ["ammo_ak74","ammo_ak74","ammo_pm","medkit","rangefinder"]:game.loadout_bag.add(kind)
 game.refresh_inventory()
 await capture("loadout")
 game.loadout_screen.portrait.rear_view=true;game.loadout_screen.portrait.fit()
 await capture("backpack")
 game.primary_tile.pressed.emit();game.loadout_screen.picker.describe("svd")
 await capture("weapon-grid")
 game.loadout_screen.picker.hide()
 game.start_match();game.set_physics_process(false);game.player.set_physics_process(false)
 for bot in game.bots+game.allies:bot.set_physics_process(false)
 game.inventory.toggle();await capture("inventory")
 game.inventory.close()
 game.player.field_rig.toggle_rangefinder()
 game.player.field_rig.timer=0.3;game.player.field_rig.animate();game.player.update_pose(0)
 await capture("pouch-reach")
 game.player.field_rig.timer=0.6;game.player.field_rig.animate();game.player.update_pose(0)
 await capture("device-retrieval")
 game.player.field_rig.tick(0.6);game.player.camera.fov=13;game.player.field_rig.measure();game.player.field_rig.tick(0.4);game.hud.queue_redraw()
 await capture("rangefinder")
 game.player.field_rig.cancel();game.player.camera.fov=78
 var w: WeaponState=game.player.current();w.pouches[1].rounds=0
 game.inventory.transfer.begin(w,1,2);game.inventory.transfer.update(1.45);game.inventory.set_process(false)
 game.player.field_rig.animate();game.player.update_pose(0)
 await capture("magazine-transfer")
 game.inventory.transfer.cancel()
 game.inventory.transfer.begin_box(w,game.player.backpack,game.player.backpack.first("ammo_ak74"),2)
 game.inventory.transfer.update(4.0);game.player.field_rig.animate();game.player.update_pose(0)
 await capture("box-loading")
 game.inventory.transfer.cancel();game.player.field_rig.animate()
 w.inspect_magazine(0);w.clock=1;game.player.update_pose(0);game.hud.queue_redraw()
 await capture("weight-estimate")
 game.queue_free();for i in range(4):await process_frame
 quit()
