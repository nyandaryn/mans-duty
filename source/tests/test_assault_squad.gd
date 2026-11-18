extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 seed(400)
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.ally_count=3
 game.start_match()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 check(game.allies.size()==3,"Configured allies are spawned separately from defenders")
 check(game.allies[0].friendly and game.allies[0].outfit_id==game.player_outfit,"Friendly faction and commander uniform")
 check(game.allies[0].weapon.pouches.size()==3,"Allies carry finite spare magazines")
 check(game.allies[0].position.distance_to(game.allies[1].position)>2,"Formation spawn is separated")
 game.squad.issue("hold")
 check(game.allies.all(func(a):return a.order=="hold"),"Group order reaches everyone")
 game.squad.choose(1)
 game.squad.issue("follow")
 check(game.allies[1].order=="follow" and game.allies[0].order=="hold","Individual order preserves other soldiers' orders")
 game.squad.issue("cease")
 check(not game.allies[1].fire_at_will and game.allies[0].fire_at_will,"Individual ceasefire")
 game.squad.issue("free")
 game.squad.point_valid=false
 game.squad.issue("move")
 check(game.allies[1].order=="follow","No ground target rejects move order")
 var ally: Hostile=game.allies[1]
 var enemy: Hostile=game.bots[0]
 for actor in game.bots+game.allies:
  actor.position=Vector3(40,0,-40)
 ally.position=Vector3(0,0.1,35)
 ally.rotation.y=0
 enemy.position=Vector3(0,0.1,25)
 enemy.rotation.y=PI
 game.player.position=Vector3(20,0.1,35)
 game.player.update_cover(1)
 ally.animate_pose(1,false)
 enemy.animate_pose(1,false)
 for i in range(3):await physics_frame
 var candidate := ally.select_contact(ally.position+Vector3.UP*1.6)
 check(candidate==enemy and ally.observation.exposure>0,"Ally sees enemy anatomy")
 enemy.combat_target=ally
 check(enemy.select_contact(enemy.position+Vector3.UP*1.6)==ally,"Enemy can target ally rather than commander")
 var wall=game.district.surface_piece(Vector3(0,1.5,30),Vector3(5,3,0.2),Color.GRAY,"concrete")
 for i in range(2):await physics_frame
 ally.select_contact(ally.position+Vector3.UP*1.6)
 check(ally.observation.exposure==0,"Ally cannot see through solid cover")
 wall.queue_free()
 for i in range(2):await physics_frame
 game.player.position=Vector3(0,0.1,30)
 game.player.update_cover(1)
 check(not ally.safe_fire_lane(ally.position+Vector3.UP*1.4,enemy.position+Vector3.UP),"Commander in firing lane blocks friendly shot")
 game.player.position=Vector3(15,0.1,35)
 check(ally.safe_fire_lane(ally.position+Vector3.UP*1.4,enemy.position+Vector3.UP),"Clear firing lane permits fire")
 ally.fire_at_will=false
 ally.sees_player=true
 ally.tracked_aim=enemy.position+Vector3.UP*1.3
 check(not ally.shoot(enemy,10),"Ceasefire is enforced at shot time")
 # Exercise the actual aim/burst/projectile path against another NPC.
 ally.fire_at_will=true
 ally.order="hold"
 ally.order_point=ally.position
 ally.home=ally.position
 ally.target=enemy.position
 ally.alerted=true
 ally.combat_target=enemy
 ally.think_timer=0
 ally.recognition=1
 ally.has_cover=false
 ally.cover_timer=100
 ally.reaction_left=0
 ally.suppression=0
 for i in range(360):
  ally._physics_process(1.0/60)
  if i%2==0:await physics_frame
  if enemy.health<100:break
 check(ally.weapon.shots_fired>0,"Ally fires real bursts at visible enemy")
 check(enemy.health<100,"Allied projectile damages enemy through shared wound model")
 game.ballistics.clear()
 ally.weapon=WeaponState.new("ak74")
 # Real capsule motion along a follow route, without invisible targeting knowledge.
 enemy.position=Vector3(40,0,-40)
 game.player.position=Vector3(0,0.1,10)
 game.player.rotation.y=0
 ally.position=Vector3(2.5,0.1,35)
 ally.alerted=false
 ally.combat_target=null
 ally.sees_player=false
 ally.has_cover=false
 ally.order="follow"
 var initial: float=ally.position.distance_to(game.squad.formation_point(1))
 for i in range(420):
  ally._physics_process(1.0/60)
  if i%4==0:await physics_frame
 check(ally.position.distance_to(game.squad.formation_point(1))<initial-10,"Ally actually follows moving commander along navigation")
 game.squad.choose(1)
 game.squad.issue("hold")
 var held := ally.position
 for i in range(120):
  ally._physics_process(1.0/60)
  if i%4==0:await physics_frame
 check(Vector2(ally.position.x-held.x,ally.position.z-held.z).length()<1.3,"Hold order stops following")
 game.squad.point_valid=true
 game.squad.point=Vector3(0,1,0)
 game.squad.issue("free")
 game.squad.issue("cover")
 game.squad.prepare_actor(ally)
 check(ally.squad_role=="cover" and ally.suppress_point==game.squad.point,"Cover sector uses commanded point")
 game.crew.toggle()
 check(not game.commands_open and not game.crew.panel.visible,"Rifleman has no command menu")
 check(game.topo_map.open() and game.commands_open and not game.paused,"Map leaves combat running")
 check(not game.player.shoot(),"Map clicks cannot fire weapon")
 game.set_pause(true)
 check(not game.commands_open and not game.topo_map.visible,"Pause closes the map")
 game.set_pause(false)
 var killed: int=game.killed
 ally.take_damage(1000)
 check(game.killed==killed,"Ally death never advances enemy objective")
 game.ally_count=0
 game.start_match()
 check(game.allies.is_empty(),"Zero allies and restart clear previous group")
 game.ally_count=8
 game.start_match()
 check(game.allies.size()==8,"Maximum group size supported")
 game.queue_free()
 for i in range(4):await process_frame
 print("FAIL: " if failed else "PASS: ",checks," allied group, orders, perception, movement and lifecycle checks")
 quit(1 if failed else 0)
