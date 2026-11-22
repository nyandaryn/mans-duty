extends SceneTree

# The player's launchers and machine gun through their sights: the RPG-7 on
# the shoulder and through the PGO-7, the RPG-22's peep and frame, the PKM on
# its bipod at 3 and 8 on the frame sight, and the operator's body with the
# RPG-7 from outside.
# KVARTAL_PREVIEW_DIR=<dir> godot --path source --script res://tests/render_player_weapons.gd
var game: Node3D
var out := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=30):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("SNAP ",name," fov=",game.player.camera.fov)

func start(id: String, bag: Array) -> Operator:
 if game!=null:
  game.queue_free()
  await frames(2)
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class(id)
 game.loadout_bag=BackpackState.new();game.loadout_bag.equipped=true
 for kind in bag:game.loadout_bag.add(kind)
 game.selected_map=TrainingRange.ID
 game.start_match()
 var p: Operator=game.player
 p.position=Vector3(0,0.2,175);p.rotation=Vector3.ZERO;p.pitch=-0.01
 await frames(20)
 return p

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 var p:=await start("grenadier",["rpg7","pg7vl","pg7vl","rpg22"])
 p.launcher.equip(-1,"rpg7")
 await frames(200)
 print("rpg7 mode=",p.launcher.mode," load=",p.launcher.load_round())
 await frames(150)
 await snap("rpg7-loading",1)
 await frames(250)
 print("rpg7 loaded=",p.launcher.loaded())
 await snap("rpg7-shoulder",30)
 Input.action_press("aim")
 await snap("rpg7-pgo7",60)
 Input.action_release("aim")
 # From outside.
 var eye:=Camera3D.new();game.world_root.add_child(eye)
 eye.cull_mask=0xFFFFF & ~ScopeSight.FIRST_PERSON_LAYER
 eye.global_position=p.global_position+Vector3(2.2,1.6,-1.6)
 eye.look_at(p.global_position+Vector3(0,1.3,0),Vector3.UP)
 eye.current=true
 await snap("rpg7-body",20)
 eye.queue_free();p.camera.current=true
 p.launcher.cycle()
 await frames(300)
 await snap("rpg22-folded",10)
 print("rpg22 arm=",p.launcher.arm())
 await frames(150)
 await snap("rpg22-arming",1)
 eye=Camera3D.new();game.world_root.add_child(eye)
 eye.cull_mask=0xFFFFF & ~ScopeSight.FIRST_PERSON_LAYER
 eye.global_position=p.global_position+Vector3(1.8,1.5,-2.2)
 eye.look_at(p.global_position+Vector3(0,1.2,0),Vector3.UP)
 eye.current=true
 await snap("rpg22-arming-body",1)
 eye.queue_free();p.camera.current=true
 await frames(260)
 print("rpg22 armed=",p.launcher.armed())
 Input.action_press("aim")
 await snap("rpg22-sight",60)
 Input.action_release("aim")
 p=await start("machinegunner",[])
 p.prone_requested=true
 await frames(80)
 p.toggle_bipod()
 Input.action_press("aim")
 await snap("pkm-sight-3",60)
 p.current().scope_zero=800
 await snap("pkm-sight-8",30)
 Input.action_release("aim")
 p.current().magazine.rounds=5
 p.current().reload(0)
 await snap("pkm-cover-open",50)
 quit()
