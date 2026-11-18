extends SceneTree
var checks := 0
func verify(ok: bool, message: String):
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
 await process_frame
 game.start_match()
 game.player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 game.set_process(false)
 var hearing: CombatHearing=game.hearing
 hearing.shot(0,true)
 hearing.update(0.1,true,0.5)
 verify(hearing.intensity==0,"Single shot does not immediately cause full tinnitus")
 for i in range(20):
  hearing.shot(0,true)
  hearing.update(0.1,true,0.5)
 verify(hearing.intensity>0.8 and hearing.filter.cutoff_hz<6000,"Sustained firing builds ringing and muffling")
 var exposure := hearing.exposure
 hearing.update(10,false,0.5)
 verify(hearing.exposure==exposure and hearing.ring.stream_paused,"Pause freezes recovery and silences ringing")
 hearing.update(0,true,0)
 verify(hearing.ring.stream_paused,"Master mute silences ringing")
 for i in range(400):hearing.update(0.1,true,0.5)
 verify(hearing.intensity==0 and hearing.exposure==0,"Hearing recovers gradually without permanent filter")
 hearing.shot(100)
 var far := hearing.exposure
 hearing.reset()
 hearing.shot(3)
 verify(hearing.exposure>far*100,"Distant shots cause much less acoustic exposure")
 verify(game.spatial_pool[0].max_distance>=220 and game.spatial_pool[0].unit_size==3,"Gunshot spatial falloff spans map engagement distances")
 game.player.receive_hit(15,"arm",Vector3.FORWARD,Vector3.ZERO)
 var voice: AudioStreamPlayer3D=game.player.get_node_or_null("PainVoice")
 verify(voice!=null and voice.playing,"Player impact triggers recorded voice")
 verify(game.pain_darkness()>0.7,"Fresh injury strongly darkens center and periphery")
 var old_stream: AudioStream=voice.stream
 game.pain_voice(game.player)
 verify(voice.stream==old_stream,"Repeated hits respect voice cooldown")
 var bot: Hostile=game.bots[0]
 bot.receive_hit(15,"arm",Vector3.FORWARD,Vector3.ZERO)
 verify(bot.has_node("PainVoice") and bot.get_node("PainVoice").playing,"Bot impact triggers positional cry")
 bot.take_damage(999)
 verify(not bot.get_node("PainVoice").playing,"Death stops ongoing voice")
 var other: Hostile=game.bots[1]
 other.receive_hit(999,"head",Vector3.FORWARD,Vector3.ZERO)
 verify(not other.has_node("PainVoice"),"Immediately fatal hit does not start a pain scream")
 game.queue_free()
 for i in range(4):await process_frame
 await create_timer(0.15).timeout # Let the audio mix thread release stopped playback resources.
 print("PASS: %d pain, voice and hearing checks" % checks)
 quit()
