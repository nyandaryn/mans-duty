extends SceneTree

# Screenshots of filling a magazine from a cartridge packet on the BMP's
# bench: the pack lifted from the floor, the packet open in the lap, the
# rounds pressed one by one into the magazine, the view turned away and back.
var game: Node3D
var out := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=1):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 var tx: MagazineTransfer=game.inventory.transfer
 print("SNAP ",name," FPS=",Engine.get_frames_per_second()," elapsed=",snappedf(tx.elapsed,0.1)," rounds=",tx.destination.get("rounds",-1)," look=",game.bmp.look)

func wait(seconds: float) -> void:
 var tx: MagazineTransfer=game.inventory.transfer
 var until: float=tx.elapsed+seconds
 while tx.active and tx.elapsed<until:await process_frame

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.loadout_bag.equipped=true
 for kind in ["ammo_ak74","ammo_ak74","medkit"]:game.loadout_bag.add(kind)
 game.set_player_class("rifleman")
 game.battle_size=18
 game.selected_map=BattleMap.ID
 game.start_match()
 game.battle.skip_field()
 await frames(30)
 var w: WeaponState=game.player.weapons[0]
 w.pouches[0].rounds=4
 game.inventory.toggle()
 await frames(10)
 await snap("bench-inventory",20)
 game.inventory.select_pack_item(game.player.backpack.first("ammo_ak74"))
 game.inventory.select_magazine(Vector2i(0,1))
 game.inventory.begin_transfer()
 await snap("bench-pack-floor",12)
 await wait(1.6)
 await snap("bench-pack-knees")
 await wait(1.6)
 await snap("bench-packet-out")
 await wait(1.2)
 await snap("bench-round-1")
 await wait(0.45)
 await snap("bench-round-2")
 await wait(6.0)
 await snap("bench-rounds")
 game.bmp.look=Vector2(-0.9,-0.05)
 await snap("bench-look-away",3)
 game.bmp.look=Vector2(0.3,-0.75)
 await snap("bench-look-down",3)
 var tx: MagazineTransfer=game.inventory.transfer
 while tx.active and tx.moved<tx.planned:await process_frame
 await snap("bench-stow",30)
 quit()
