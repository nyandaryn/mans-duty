extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var injury := ConcussionState.new()
 injury.apply(0.10)
 check(not injury.active(),"Small exposure does not automatically become brain injury")
 injury.apply(0.45)
 check(injury.active() and not injury.can_aim() and not injury.can_fire(),"Acute concussion blocks combat actions")
 injury.tick(60)
 check(injury.severity==0.45 and not injury.can_aim(),"A minute does not restore aiming")
 injury.tick(3600)
 check(injury.severity==0.45 and injury.movement_multiplier()<0.8,"An hour does not erase mission injury")
 check(injury.view_sway(10).length()>0 and injury.darkness(10)>0,"Residual visual and balance symptoms persist")
 injury.apply(0.45)
 check(injury.severity>0.45 and not injury.can_fire(),"Repeated exposure worsens rather than resets injury")
 var mild := ConcussionState.new();mild.apply(0.2);mild.tick(600)
 check(mild.can_fire() and mild.movement_multiplier()<1 and mild.view_sway(9).length()>0,"Mild survivor retains movement and sight penalties")
 var severe := ConcussionState.new();severe.apply(0.8);severe.tick(3600)
 check(severe.incapacitated() and not severe.can_fire() and severe.movement_multiplier()==0,"Severe casualty cannot return to combat after blackout expires")
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0;game.ally_count=1;game.start_match();game.set_process(false);game.set_physics_process(false)
 var player: Operator=game.player;player.set_physics_process(false)
 for bot in game.bots+game.allies:bot.set_physics_process(false)
 player.receive_blast(20,0.45,Vector3.FORWARD)
 check(player.health==80 and player.concussion.severity==0.45,"Blast independently injures body and brain")
 var age := player.concussion.acute_left
 game.paused=true;player._physics_process(60)
 check(player.concussion.acute_left==age,"Pause freezes injury time")
 game.paused=false;player.injury_time=0;player.current().cancel();player.switch_delay=0
 check(player.begin_bandage(),"Concussed survivor can treat accompanying physical wound")
 var medkits := player.bandages
 for i in range(365):player._physics_process(1.0/60)
 check(player.health==100 and player.bandages==medkits-1,"First aid consumes a kit and heals body")
 check(player.concussion.severity==0.45 and not player.concussion.can_aim(),"First aid leaves brain injury intact")
 player.concussion.tick(3600);player.injury_time=0;player.pain=0
 Input.action_press("aim");player._physics_process(1.0/60);Input.action_release("aim")
 check(not player.aim and game.pain_darkness()>0.05,"Healed health does not restore ADS or remove darkening")
 var hearing: CombatHearing=game.hearing
 hearing.reset();hearing.injury_floor=player.concussion.severity*0.78
 for i in range(100):hearing.update(1,true,0)
 check(hearing.exposure==0 and hearing.intensity>0.3 and hearing.filter.cutoff_hz<15000,"Persistent tinnitus survives acoustic-exposure decay")
 var bot: Hostile=game.bots[0]
 bot.receive_blast(20,0.6,Vector3.FORWARD);bot.bleeding=0.5;bot.injury_age=10;bot.wound_timer=0
 bot.concussion.tick(120);bot.collapse_time=0;bot.treatment_wait=0
 bot.update_medical(0.1)
 check(bot.treatment_time>0,"Bot can treat associated bleeding")
 bot.update_medical(6)
 check(bot.health==100 and bot.bleeding==0 and bot.medical_kits==1,"Bot kit treats physical injuries")
 check(bot.concussion.severity==0.6 and not bot.shoot(player,10) and not bot.dead,"Treated bot remains alive and unable to shoot")
 bot.update_medical(60)
 check(bot.collapse>0.99 and bot.aim_weight==0 and not bot.blind_fire,"Concussed bot stays down without blind or aimed fire")
 var ally: Hostile=game.allies[0];ally.receive_blast(10,0.8,Vector3.FORWARD)
 ally.concussion.tick(120);ally.wound_timer=0;ally.update_medical(0.1)
 check(ally.concussion.incapacitated() and not ally.shoot(player,10) and not ally.dead,"Severe friendly casualty follows the same rules")
 var kills: int=game.killed
 for enemy in game.bots:enemy.concussion.apply(0.8)
 check(game.combat_cleared() and game.killed==kills,"Incapacitated enemies permit completion without fabricating kills")
 var previous := player.concussion.severity
 game.debug_invulnerable=true;player.receive_blast(999,1,Vector3.FORWARD)
 check(player.health==100 and player.concussion.severity==previous,"Debug immunity prevents new injury, not a hidden medkit cure")
 game.debug_invulnerable=false;game.start_match()
 check(not game.player.concussion.active() and game.hearing.injury_floor==0,"New operation resets mission injury and hearing")
 game.queue_free();await process_frame;await process_frame
 print("FAIL: " if failed else "PASS: ",checks," persistent concussion / treatment / bot impairment checks")
 quit(1 if failed else 0)
