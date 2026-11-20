extends SceneTree
var failed:=false
var checks:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 seed(161126)
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.battle.panel.show()
 for button in game.battle.panel.find_children("*","Button",true,false):
  if button.text=="ОБРАТИ ШТУРМ →":button.pressed.emit()
 check(game.selected_map==BattleMap.ID and not game.battle.panel.visible,"Menu selection chooses battle and returns to loadout")
 var team_size:=36 if OS.get_environment("BATTLE_LARGE")=="1" else 18
 game.volume=0;game.ally_count=3;game.battle_size=team_size;game.selected_map=BattleMap.ID;game.start_match()
 var squads:=BattleMode.squad_count(team_size)
 # The rifleman's squads start on the field by their vehicles (test_field_start).
 check(game.battle.mech.size()==squads and game.battle.mech.all(func(s):return s.on_foot().size()+s.aboard().size()==BmpVehicle.SEATS and s.vehicle.crew.size()==2),"The attackers come in %d BMPs, a full crew and squad to each" % squads)
 # The infantry assault from the start line: the column is taken as arrived.
 game.battle.skip_approach()
 # The vehicles hold still and silent: the checks below count every shot.
 for squad in game.battle.mech:squad.vehicle.set_physics_process(false);squad.vehicle.gunner.manned=false
 game.set_process(false);game.set_physics_process(false);game.squad.set_physics_process(false);game.battle.set_physics_process(false);game.player.set_physics_process(false)
 var battle:BattleMode=game.battle
 check(game.running and battle.active,"Battle starts independently of campaign unlocks")
 check(game.district.grid.region.size==Vector2i(399,399),"400 m battlefield uses bounded one-metre navigation")
 await physics_frame;await physics_frame
 var spawn_eye:Vector3=game.district.player_spawn+Vector3.UP*1.65
 var spawn_ray:=PhysicsRayQueryParameters3D.create(spawn_eye,spawn_eye+Vector3.FORWARD*40,1)
 check(not game.get_world_3d().direct_space_state.intersect_ray(spawn_ray).is_empty(),"Insertion has physical frontal cover")
 for i in range(3):
  check(game.district.path(game.player.position,battle.center(i)).size()>1,"Each objective reachable from insertion")
 check(game.allies.size()==team_size+game.ally_count and game.bots.size()==BattleMode.enemies(team_size),"Both armies are on the field at once, the enemy three to one (%d : %d)" % [team_size,game.bots.size()])
 var apart:=INF
 for i in range(3):
  for j in range(i+1,3):apart=minf(apart,Vector2(BattleMap.CENTERS[i]).distance_to(BattleMap.CENTERS[j]))
 check(apart>140,"Strongpoints stand in different parts of the village (%.0f m apart at least)" % apart)
 var counts:=BattleMode.defence_counts(BattleMode.enemies(team_size))
 var sectors:Array[int]=[0,0,0,0];var held:=true;var posted:=true
 var slots:Array[Dictionary]=[{},{},{}];var reach:Array[float]=[0.0,0.0,0.0]
 for actor in game.bots:
  var index:int=actor.get_meta("battle_sector",-1)
  if actor.position.distance_to(battle.post_of(actor))>1:posted=false
  if index<0:
   sectors[3]+=1
   for c in BattleMap.CENTERS:
    if Vector2(actor.position.x,actor.position.z).distance_to(c)<40:held=false
   if Vector2(actor.position.x,actor.position.z).distance_to(BattleMap.FORMATION)<BattleMode.POST_STANDOFF-15:held=false
   continue
  sectors[index]+=1
  slots[index][actor.get_meta("battle_position")]=true
  if actor.position.distance_to(battle.center(index))>62:held=false
  for other in game.bots:
   if other.get_meta("battle_sector",-1)==index:reach[index]=maxf(reach[index],actor.position.distance_to(other.position))
 check(held and posted and sectors==counts and counts[3]>0,"Defenders hold three strongpoints and posts over the village (%s)" % str(sectors))
 check(slots[0].size()==3 and slots[1].size()==3 and slots[2].size()>=2 and reach.min()>25,"Each garrison spreads over the firing positions (%s m across)" % str(reach))
 check(battle.sector==0,"The assault starts with the strongpoint nearest to the forest strip")
 var staged:=true
 for actor in game.allies:
  if actor.get_meta("battle_managed",false) and actor.vehicle==null and actor.position.distance_to(battle.formation_base(true,0))>45:staged=false
 check(staged,"Attackers form up together in front of the insertion")
 for i in range(20):
  battle._physics_process(.16)
  for actor in game.allies+game.bots:actor.set_physics_process(false)
  if i%5==0:await physics_frame
 check(game.squad.targets().size()==3,"Commands only address personal squad")
 var managed:Hostile=game.allies.filter(func(a):return a.vehicle==null)[-1]
 check(managed.order=="assault" and managed.get_meta("battle_managed"),"Independent allied squads receive assault goals")
 check(not managed.alerted and managed.contact_age>10,"Strategic orders do not grant enemy sight or live coordinates")
 game.squad.issue("hold")
 check(managed.order=="assault" and game.allies[0].order=="hold","Player orders do not redirect entire army")
 var groups:Dictionary={}
 for actor in game.allies:
  if actor.get_meta("battle_managed",false):groups[actor.get_meta("battle_group")]=true
 check(groups.size()==squads,"Every squad is its own attack group (%d)" % groups.size())
 game.player.position=Vector3(-170,1,170)
 var garrison:=func(index:int)->Array:return game.bots.filter(func(a):return a.get_meta("battle_sector",-1)==index)
 for actor in garrison.call(0):actor.collapse=1
 battle.update_objective(1.0)
 check(not battle.cleared[0] and battle.sector==0,"A strongpoint is not destroyed while its men may still get up")
 garrison.call(0)[0].collapse=0;battle.update_objective(1.0)
 check(battle.clear_timers[0]==0,"A defender back on his feet keeps the strongpoint in the fight")
 garrison.call(0)[0].collapse=1
 for i in range(3):battle.update_objective(1.1)
 check(battle.cleared[0] and battle.sector==1 and battle.last_cleared==0 and not battle.finished,"A destroyed strongpoint passes the assault to the nearest one left")
 check(battle.depot(true).distance_to(battle.center(0))<.1,"The destroyed strongpoint becomes the attackers' ammunition point")
 var aims:Dictionary={}
 for g in range(3):
  var aim:Vector3=battle.objective_point(g)
  if aim.distance_to(battle.center(1))<60:aims[aim]=true
 check(aims.size()==3,"Attack groups storm different firing positions of the strongpoint")
 var bots_before:int=game.bots.size()
 managed.die();await process_frame;battle.retire_casualties()
 check(not game.allies.has(managed) and battle.corpses.has(managed),"Dead soldier remains a separate casualty")
 for i in range(30):
  battle._physics_process(.2)
  for actor in game.allies+game.bots:actor.set_physics_process(false)
  await physics_frame
 check(game.allies.size()==team_size+game.ally_count-1 and game.bots.size()==bots_before and managed.dead,"No reinforcements: a casualty is never replaced or revived")
 var keep:=true
 for actor in game.bots:
  if not battle.operational(actor):continue
  battle.assign(actor)
  if actor.home.distance_to(battle.post_of(actor))>4:keep=false
 check(keep,"Defenders hold their own posts")
 game.paused=true;battle.command_left=.5;battle._physics_process(10)
 check(battle.command_left==.5,"Pause freezes the battle")
 game.paused=false
 var old_player:Operator=game.player;var identity:=old_player.get_instance_id()
 var heir:Hostile=battle.successor();var heir_id:=heir.get_instance_id();var heir_point:Vector3=heir.global_position;var allies_before:int=game.allies.size()
 game.player.health=0;game.finish(false)
 check(game.running and is_equal_approx(battle.respawn_left,BattleMode.TAKEOVER_TIME),"Player death keeps battlefield running during the handover")
 check(game.player.collision_layer==0 and game.player.get_meta("battle_out",false),"Departed operator cannot block fire or count as a contact")
 for i in range(30):
  battle._physics_process(.2)
  game.player.set_physics_process(false)
  for actor in game.allies+game.bots:actor.set_physics_process(false)
  await physics_frame
 check(game.player.get_instance_id()!=identity and game.player.health==100,"Command passes to a fresh, unwounded operator")
 check(game.player.global_position.distance_to(heir_point)<1 and not is_instance_id_valid(heir_id) and game.allies.size()==allies_before-1 and game.bots.size()==bots_before,"Successor is the nearest soldier already on the field; nobody new arrives (%.1f m, heir %s, allies %d/%d, bots %d/%d)" % [game.player.global_position.distance_to(heir_point),str(is_instance_id_valid(heir_id)),game.allies.size(),allies_before-1,game.bots.size(),bots_before])
 check(not game.player.current().debug_infinite,"Normal battle preserves finite ammunition")
 game.player.concussion.severity=.8;allies_before=game.allies.size()
 battle._physics_process(.1)
 check(battle.respawn_left>0,"Permanent incapacity hands command over rather than healing concussion")
 battle.respawn_player();battle.respawn_left=0;game.player.set_physics_process(false)
 check(game.player.concussion.severity==0 and game.allies.size()==allies_before-1,"Successor is a different soldier with a new concussion state")
 var stash:Array=game.allies.duplicate();game.allies.clear()
 game.player.concussion.severity=.8
 battle._physics_process(.1)
 check(game.running and not battle.finished and battle.respawn_left==0 and game.player.health>0,"Living concussed commander with nobody to take over keeps the assault running")
 game.player.concussion.severity=0;game.elapsed=1900
 battle._physics_process(.1)
 check(game.running and not battle.finished,"Assault has no time limit while the commander lives")
 for actor in stash:game.allies.append(actor)
 for index in range(3):
  for actor in garrison.call(index):actor.collapse=1
 for i in range(8):battle.update_objective(1.1)
 battle.refresh_sweep()
 var scattered:Array=garrison.call(-1)
 var posts:=true
 for g in range(3):
  var aim:Vector3=battle.objective_point(g)
  if scattered.filter(func(a):return battle.post_of(a)==aim).is_empty():posts=false
 check(battle.cleared_count()==3 and battle.sector==-1 and not battle.finished,"All strongpoints destroyed: the assault goes on while posts hold out")
 check(posts and battle.sweep.size()==scattered.size(),"Mopping up: the attack groups head for the posts left in the village")
 for actor in scattered:actor.collapse=1
 for i in range(4):battle.update_objective(1.1)
 check(battle.finished and not game.running and battle.result_reason.contains("знищено"),"Nobody left to fight in the village wins the assault")
 check(game.campaign.completed.is_empty(),"Battle victory does not unlock campaign missions")
 battle.finished=false;game.running=true;game.allies.clear();game.player.health=0;game.finish(false)
 check(battle.finished and not game.running and battle.respawn_left==0 and battle.result_reason.contains("Живих"),"Death with nobody left to take over ends the assault")
 game.to_menu();check(not battle.active,"Menu cancels battle")
 game.queue_free();await process_frame;await process_frame
 print("FAIL: " if failed else "PASS: ",checks," battle lifecycle / objectives / squads / handover checks")
 quit(1 if failed else 0)
