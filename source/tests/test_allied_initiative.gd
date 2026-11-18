extends SceneTree
var checks:=0
var failed:=false
func check(ok:bool,message:String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0;game.ally_count=4;game.start_match();game.set_physics_process(false);game.squad.set_physics_process(false);game.player.set_physics_process(false)
 for actor in game.allies+game.bots:actor.set_physics_process(false);actor.position=Vector3(40,0,40)
 game.district.free();var d:=District.new();game.world_root.add_child(d);game.district=d
 d.box(Vector3(0,-.5,0),Vector3(95,1,95),Color.GRAY,true,"earth");d.flush();d.build_grid()
 game.player.position=Vector3(10,.1,10);game.player.rotation=Vector3.ZERO
 var actor:Hostile=game.allies[0];actor.position=Vector3(0,.1,0);actor.order="move";actor.order_point=Vector3(0,.1,-20);actor.has_cover=false;actor.under_fire_time=5
 game.squad.prepare_actor(actor,.5)
 check(game.squad.destination(actor)==actor.position,"Initial incoming fire triggers protective pause")
 game.squad.prepare_actor(actor,1)
 check(game.squad.destination(actor).distance_to(actor.position)>10,"Exposed ally does not freeze indefinitely under sustained fire")
 check(game.squad.posture(actor,true)==1,"Exposed movement retains prone silhouette")
 actor.under_fire_time=0;actor.alerted=false;actor.order="follow"
 check(game.squad.look_direction(actor,Vector3.ZERO).dot(Vector3.FORWARD)>.85,"Idle follower watches commander's front")
 var buddy:Hostile=game.allies[1];buddy.position=Vector3(0,.1,-4)
 actor.order="move";actor.flank_timer=0;actor.follow_prone=false
 var origin:=actor.position+Vector3.UP;var endpoint:=Vector3(0,1.1,-20)
 await physics_frame;await physics_frame
 check(not actor.safe_fire_lane(origin,endpoint),"Nearby ally blocks live firing lane")
 game.squad.clear_fire_lane(actor,origin,endpoint)
 check(actor.flank_timer>0 and actor.path.size()>1,"Blocked shooter chooses physically reachable side step")
 check(actor.safe_fire_lane(actor.flank_point+Vector3.UP,endpoint),"Side step opens lane without firing through ally")
 # A large map has cover gaps wider than the old fourteen-metre search.
 d.box(Vector3(0,1,-2),Vector3(8,2,.6),Color.GRAY,true,"concrete")
 d.box(Vector3(0,1,-18),Vector3(8,2,.6),Color.GRAY,true,"concrete")
 d.flush();await d.refresh_navigation();await physics_frame;await physics_frame
 game.battle.active=true
 game.battle.set_physics_process(false);game.battle.budget_frame=-1
 for unit in game.allies:unit.position=Vector3(40,0,40);unit.has_cover=false
 actor.position=Vector3(0,.1,0);actor.order="assault";actor.home=Vector3(0,0,-40);actor.order_point=actor.home
 actor.assault_arrived=false;actor.auto_cover=false;actor.cover_dwell=8;actor.has_cover=true;actor.cover_point=actor.position
 actor.suppress_point=Vector3(0,1.5,-60);actor.suppress_age=0;actor.under_fire_time=2;actor.flank_timer=0
 game.squad.find_cover(actor)
 check(actor.has_cover and actor.cover_point.z< -12,"Battle assault finds the next protected bound across a wider cover gap")
 check(actor.path.size()>1,"Wide cover bound includes a physical reachable route")
 for i in range(4):
  var unit:Hostile=game.allies[i];unit.position=Vector3(i*4,0,4);unit.set_meta("battle_group",i/2);unit.set_meta("battle_managed",true);unit.has_cover=true;unit.cover_point=unit.position;unit.order="assault";unit.contact_age=0;unit.cover_dwell=9
 game.squad.coordinate()
 var covers:=0
 for unit in game.allies:
  if unit.auto_cover:covers+=1
 check(covers==2,"Independent groups each retain a covering soldier")
 game.battle.budget_frame=-1
 for i in range(4):check(game.battle.budget("path"),"Path budget grants bounded work")
 check(not game.battle.budget("path"),"Excess path work waits for later frame")
 check(game.battle.budget("cover") and game.battle.budget("cover") and not game.battle.budget("cover"),"Cover work is bounded per frame")
 game.battle.active=false;game.queue_free()
 for i in range(4):await process_frame
 print("FAIL: " if failed else "PASS: ",checks," allied initiative / fire lanes / group roles / budgets checks")
 quit(1 if failed else 0)
