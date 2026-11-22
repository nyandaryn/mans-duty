extends SceneTree

# The skipped start of the great assault: the black screen with its line,
# the troop compartment at the drop as the picture comes back, the player
# out by his vehicle, and the drop from above with the squad getting out.
# KVARTAL_PREVIEW_DIR=<dir> godot --fixed-fps 60 --path source --resolution 1600x900 --script res://tests/render_assault_skip.gd
var game: Node3D
var out := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame
func snap(name: String):
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("SNAP ",name)

func f6() -> void:
 var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_F6;key.keycode=KEY_F6
 game.battle._input(key)

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 seed(2026)
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class("rifleman");game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 await frames(120)
 await snap("skip-0-start")
 f6();f6()
 await frames(30)
 await snap("skip-1-black")
 for i in range(600):
  await physics_frame
  if game.battle.skip_shade!=null and game.battle.skip_shade.modulate.a<0.5:break
 await snap("skip-2-fading")
 while game.battle.skipping:await physics_frame
 await frames(20)
 await snap("skip-3-aboard")
 for i in range(60*20):
  await physics_frame
  if game.bmp.seat=="":break
 await frames(90)
 var lead: MechSquad=game.battle.mech[0]
 var p: Operator=game.player
 var to:=lead.vehicle.global_position-p.global_position
 p.rotation.y=atan2(-to.x,-to.z);p.pitch=-0.05
 await frames(10)
 await snap("skip-4-out")
 var eye:=Camera3D.new();game.world_root.add_child(eye)
 eye.cull_mask=0xFFFFF & ~ScopeSight.FIRST_PERSON_LAYER
 var v:=lead.vehicle
 eye.global_position=v.global_position+v.global_basis.z*16.0+Vector3.UP*11.0+v.global_basis.x*6.0
 eye.look_at(v.global_position-v.global_basis.z*4.0,Vector3.UP)
 eye.current=true
 await frames(4)
 await snap("skip-5-drop")
 quit()
