extends SceneTree

# Screenshots of the BMP driver's start of the great assault: in the seat
# while the «Grads» fire (the tablet beside the instruments), his men
# boarding after «По машинах!».
var game: Node3D
var out := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=30):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("SNAP ",name," FPS=",Engine.get_frames_per_second()," prep=",game.battle.prep," t=",snappedf(game.battle.prep_time,0.1))

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class("bmp")
 game.battle_size=27
 game.selected_map=BattleMap.ID
 game.start_match()
 var battle: BattleMode=game.battle
 await snap("driver-barrage",120)
 while not battle.battery.ordered:await process_frame
 await snap("driver-salvo",150)
 while battle.prep!="mount":await process_frame
 game.bmp.head_out=false
 await snap("driver-mount",240)
 quit()
