extends SceneTree
var checks := 0
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  printerr("FAIL: ",message)
  quit(1)
  assert(ok,message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame
func run():
 seed(300)
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 var bot: Hostile=game.bots[0]
 var player: Operator=game.player
 bot.position=Vector3(0,0.1,27)
 bot.rotation.y=PI
 player.position=Vector3(0,0.1,35)
 player.update_cover(1)
 bot.target=player.position
 bot.animate_pose(1,false)
 await frames(2)
 var eye := bot.position+Vector3.UP*1.6
 var open := Perception.observe(bot,player,game,eye)
 check(open.exposure>0.8,"Eye sees exposed anatomy")
 var foliage: Dictionary= game.district.foliage_cells.duplicate(true)
 var alpha: Image=game.district.foliage_alpha
 var opaque := Image.create(4,4,false,Image.FORMAT_RGBA8)
 opaque.fill(Color.WHITE)
 game.district.foliage_alpha=opaque
 game.district.detail("foliage",Vector3(0,1,31),Vector3(3,3,3),"ffffff")
 var hidden := Perception.observe(bot,player,game,eye)
 check(hidden.exposure==0 and hidden.rate==0,"Opaque leaf quad blocks all body samples at 8 metres")
 check(Perception.rate(3,1,0,1,2,0,0,false,false)==0,"Near-distance rule never bypasses foliage")
 opaque.fill(Color(1,1,1,0))
 check(Perception.observe(bot,player,game,eye).exposure>0.8,"Transparent texels are real sight gaps")
 game.district.foliage_cells=foliage
 game.district.foliage_alpha=alpha
 bot.recognition=1
 bot.think_timer=0
 bot._physics_process(0.016)
 check(bot.sees_player and bot.reaction_left>=0.28,"New contact imposes reaction delay")
 check(not bot.shoot(player,8),"Reaction delay prevents an immediate shot")
 var memory := bot.last_visual_point
 var wall: DestructibleSurface= game.district.surface_piece(Vector3(0,1.5,31),Vector3(6,3,0.2),Color.GRAY,"concrete")
 await frames(2)
 player.position.x=1.5
 bot.think_timer=0
 bot._physics_process(0.016)
 check(not bot.sees_player,"Occlusion cancels confirmed sight")
 check(bot.last_visual_point==memory,"Hidden movement does not update remembered sighting")
 check(not bot.shoot(player,8),"No accurate shooting at concealed current position")
 wall.queue_free()
 await frames(2)
 # Face away: alertness cannot provide a 360-degree camera.
 bot.rotation.y=0
 bot.think_timer=0
 bot._physics_process(0.016)
 check(not bot.sees_player,"Alerted bot still respects field of view")
 bot.rotation.y=PI
 bot.position=Vector3(0,0.1,27)
 player.position=Vector3(0,0.1,35)
 bot.target=player.position
 bot.suppress_point=Vector3(0,1.2,35)
 bot.suppress_age=0
 var cover: DestructibleSurface= game.district.surface_piece(Vector3(0,0.7,28),Vector3(3,1.4,0.25),Color.GRAY,"concrete")
 await frames(2)
 bot.choose_peek()
 check(bot.peek_top,"Low cover offers an overhead peek")
 bot.blind_fire=true
 bot.stance=1
 bot.aim_weight=0
 bot.reaction_left=0
 bot.sprinting=false
 bot.sees_player=false
 bot.animate_pose(1,false)
 check(bot.model.get_node("CarriedRifle").position.y>1.8,"Blind overhead fire visibly raises rifle")
 check(bot.shoot(player,8),"Exposed muzzle can fire blindly at remembered cover")
 var buddy: Hostile=game.bots[1]
 buddy.position=Vector3(3,0.1,27)
 buddy.alerted=true
 bot.alerted=true
 game.elapsed=12
 game.coordinate_squad()
 check(bot.squad_partner==buddy and buddy.squad_partner==bot,"Nearby allies form reciprocal pairs")
 check(bot.squad_role!=buddy.squad_role,"One covers while the other moves")
 var role := bot.squad_role
 game.elapsed+=6
 game.coordinate_squad()
 check(bot.squad_role!=role,"Cover and movement roles alternate")
 game.volume=0.5
 game.cover_voice(bot)
 var voice: AudioStreamPlayer3D=bot.get_node_or_null("CoverVoice")
 check(voice!=null and voice.max_distance==110 and voice.stream!=null,"Cover callout is real spatial audio with finite range")
 game.volume=0
 bot.apply_wound(DamageModel.wound("plate","ak74",1,Vector2.ZERO,1),"plate",Vector3.FORWARD,bot.position)
 check(bot.collapse_time>=3,"Plate impact triggers a drop instead of just crouching")
 for i in range(30):bot._physics_process(1.0/60)
 check(bot.collapse>0.9 and bot.model.rotation.x< -1.4,"Wounded actor lies forward on ground")
 check(bot.get_child(0).position.y<0.4,"Prone movement collision is lowered too")
 game.queue_free()
 await frames(3)
 await create_timer(0.15).timeout
 print("PASS: ",checks," sight, reaction, memory, peeking, squad and injury checks")
 quit()
