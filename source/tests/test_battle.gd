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
 var team_size:=28 if OS.get_environment("BATTLE_LARGE")=="1" else 12
 game.volume=0;game.ally_count=3;game.battle_size=team_size;game.selected_map=BattleMap.ID;game.start_match()
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
 check(game.allies.size()==team_size and game.bots.size()==team_size,"Both armies are on the field at once")
 var sectors:Array[int]=[0,0,0];var held:=true
 for actor in game.bots:
  var index:int=actor.get_meta("battle_sector",-1)
  if index<0:held=false;continue
  sectors[index]+=1
  if actor.position.distance_to(battle.center(index))>50:held=false
 check(held and sectors==BattleMode.defence_counts(team_size) and sectors[2]>0,"Defenders hold all three sectors from the start")
 var staged:=true
 for actor in game.allies:
  if actor.get_meta("battle_managed",false) and actor.position.distance_to(battle.formation_base(true,0))>45:staged=false
 check(staged,"Attackers form up together in front of the insertion")
 for i in range(20):
  battle._physics_process(.16)
  for actor in game.allies+game.bots:actor.set_physics_process(false)
  if i%5==0:await physics_frame
 check(game.squad.targets().size()==3,"Commands only address personal squad")
 var managed:Hostile=game.allies[-1]
 check(managed.order=="assault" and managed.get_meta("battle_managed"),"Independent allied squads receive assault goals")
 check(not managed.alerted and managed.contact_age>10,"Strategic orders do not grant enemy sight or live coordinates")
 game.squad.issue("hold")
 check(managed.order=="assault" and game.allies[0].order=="hold","Player orders do not redirect entire army")
 var groups:Dictionary={}
 for actor in game.allies:
  if actor.get_meta("battle_managed",false):groups[actor.get_meta("battle_group")]=true
 check(groups.size()==3,"Autonomous soldiers cover all three approaches")
 for actor in game.allies+game.bots:actor.position=Vector3(170,1,-170)
 game.player.position=Vector3(-170,1,170)
 var ally:Hostile=game.allies[0];var enemy:Hostile=game.bots[0]
 ally.position=battle.center();enemy.position=battle.center()+Vector3(2,0,0)
 battle.progress=.2;battle.update_objective(10)
 check(battle.contested and is_equal_approx(battle.progress,.2),"Contested sector cannot be captured")
 enemy.position=Vector3(170,1,-170);battle.update_objective(10)
 check(battle.progress>.5,"Allies can secure sector without player")
 ally.collapse=1;battle.progress=.2;battle.update_objective(10)
 check(is_equal_approx(battle.progress,.2),"Downed wounded soldier cannot capture")
 ally.collapse=0;battle.progress=.99;battle.update_objective(1)
 check(battle.sector==1 and battle.progress==0,"Capture advances sequential objective")
 check(battle.depot(true).distance_to(battle.center(0)+BattleMap.offset(0,24))<.1,"Captured sector advances resupply point")
 var bots_before:int=game.bots.size()
 managed.die();await process_frame;battle.retire_casualties()
 check(not game.allies.has(managed) and battle.corpses.has(managed),"Dead soldier remains a separate casualty")
 for i in range(30):
  battle._physics_process(.2)
  for actor in game.allies+game.bots:actor.set_physics_process(false)
  await physics_frame
 check(game.allies.size()==team_size-1 and game.bots.size()==bots_before and managed.dead,"No reinforcements: a casualty is never replaced or revived")
 var rear:Hostile=null
 for actor in game.bots:
  if actor.get_meta("battle_sector",-1)==0:rear=actor;break
 battle.assign(rear)
 check(battle.defended_sector(rear)==1 and rear.home.distance_to(battle.center(1))<40,"Defenders of a lost sector fall back to the next line")
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
 check(game.player.global_position.distance_to(heir_point)<1 and not is_instance_id_valid(heir_id) and game.allies.size()==allies_before-1 and game.bots.size()==bots_before,"Successor is the nearest soldier already on the field; nobody new arrives")
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
 battle.sector=2;battle.progress=.99;game.player.position=battle.center()
 for actor in game.allies+game.bots:actor.position=Vector3(170,1,170)
 battle.update_objective(1)
 check(battle.finished and not game.running and battle.sector==3,"Three captured sectors win battle")
 check(game.campaign.completed.is_empty(),"Battle victory does not unlock campaign missions")
 battle.finished=false;game.running=true;game.allies.clear();game.player.health=0;game.finish(false)
 check(battle.finished and not game.running and battle.respawn_left==0 and battle.result_reason.contains("Живих"),"Death with nobody left to take over ends the assault")
 game.to_menu();check(not battle.active,"Menu cancels battle")
 game.queue_free();await process_frame;await process_frame
 print("FAIL: " if failed else "PASS: ",checks," battle lifecycle / objectives / squads / handover checks")
 quit(1 if failed else 0)
