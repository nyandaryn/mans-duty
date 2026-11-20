extends SceneTree

# Screenshots of the rifleman's start of the great assault: the squad on the
# field with its marks, the tablet with the battery and the village while
# the crews lay, during the salvo and as the rockets land, then «По машинах!».
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

func face(point: Vector3, pitch: float=-0.05) -> void:
 var d: Vector3=point-game.player.global_position
 game.player.rotation.y=atan2(-d.x,-d.z)
 game.player.pitch=pitch

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class("rifleman")
 game.battle_size=27
 game.selected_map=BattleMap.ID
 game.start_match()
 var battle: BattleMode=game.battle
 var lead: MechSquad=battle.mech[0]
 face(lead.vehicle.global_position+Vector3.UP*1.2)
 await snap("field-start",90)
 var grads: GradBattery=battle.battery
 while battle.prep_time<17.0:await process_frame
 face(lead.members[3].global_position+Vector3.UP)
 await snap("field-laying",20)
 while not grads.ordered:await process_frame
 await snap("field-salvo",150)
 while grads.in_flight()>0 and game.blasts.grads.size()>60:await process_frame
 await snap("field-salvo-2",10)
 while game.blasts.grads.size()>25:await process_frame
 await snap("field-impacts",30)
 var shown:=0.0
 while battle.prep!="mount":
  await process_frame
  if battle.prep_time-shown>3.0:
   shown=battle.prep_time
   var states: Array=[]
   for crew in grads.crews:states.append("%s %d" % [crew.state,crew.vehicle.remaining()])
   print("wait t=%.1f in flight %d crews %s" % [battle.prep_time,game.blasts.grads.size(),str(states)])
 face(lead.vehicle.global_position+Vector3.UP*1.5)
 await snap("field-mount",120)
 quit()
