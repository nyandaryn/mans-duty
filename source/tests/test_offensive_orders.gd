extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func reset_actor(actor: Hostile, position: Vector3):
 actor.position=position
 actor.velocity=Vector3.ZERO
 actor.rotation.y=0
 actor.alerted=false
 actor.combat_target=null
 actor.sees_player=false
 actor.recognition=0
 actor.contact_age=100
 actor.suppress_age=100
 actor.last_visual_age=100
 actor.under_fire_time=0
 actor.suppression=0
 actor.has_cover=false
 actor.cover_requires_prone=false
 actor.tactical_prone=0
 actor.stance=0
 actor.pending_delay=-1
 actor.weapon=WeaponState.new("ak74")
 actor.animate_pose(1,false)
func run():
 seed(882)
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.ally_count=3
 game.start_match()
 game.set_physics_process(false)
 game.squad.set_physics_process(false)
 game.player.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 game.district.free()
 var district := District.new()
 game.world_root.add_child(district)
 game.district=district
 district.box(Vector3(0,-0.5,0),Vector3(95,1,95),Color.GRAY,true,"earth")
 district.flush()
 district.build_grid()
 for actor in game.bots:actor.position=Vector3(44,0,44)
 for i in range(3):reset_actor(game.allies[i],Vector3(-15+i*4,0.1,20))
 game.player.position=Vector3(0,0.1,20)
 game.player.rotation.y=0
 game.player.camera.rotation.x=0.2
 game.player.update_cover(1)
 for i in range(3):await physics_frame
 game.squad.aim_point()
 check(not game.squad.point_valid,"Horizon sector does not require a surface hit")
 game.squad.issue("cease")
 game.squad.issue("engage")
 check(game.allies.all(func(a):return a.order=="engage" and a.fire_at_will),"Group combat order overrides previous ceasefire")
 check(game.allies.all(func(a):return not a.alerted and a.contact_age>90),"Command does not manufacture enemy knowledge")
 var ally: Hostile=game.allies[0]
 var heading := ally.order_direction
 game.player.rotation.y=PI/2
 check(heading.dot(Vector3.FORWARD)>0.99 and ally.order_direction==heading,"Order keeps original heading when commander turns")
 ally.has_cover=true
 ally.cover_point=ally.position
 ally.cover_requires_prone=true
 ally.peek_top=true
 ally.peek_clock=4
 check(game.squad.posture(ally,false)==0,"Sector combat can briefly peek from low cover even without overwatch duty")
 ally.peek_clock=1
 check(game.squad.posture(ally,false)==1,"Sector combat conceals again between low-cover peeks")
 ally.has_cover=false
 ally.cover_requires_prone=false
 game.squad.choose(1)
 game.squad.issue("assault")
 check(game.allies[1].order=="engage","Assault without surface is rejected")
 game.squad.point_valid=true
 game.squad.point=Vector3(0,0,-18)
 game.squad.issue("assault")
 check(game.allies[1].order=="assault" and ally.order=="engage","Individual assault does not replace the group order")
 game.squad.point=Vector3(0,15,-18)
 var old_point: Vector3=game.allies[1].order_point
 game.squad.issue("assault")
 check(game.allies[1].order_point==old_point,"Unreachable roof is not silently projected to the ground")
 game.squad.point=Vector3(200,0,-200)
 game.squad.issue("assault")
 check(game.allies[1].order_point==old_point,"Unreachable point preserves previous valid order")
 # Visible sector targets take priority; neither sector nor assault grants sight.
 reset_actor(ally,Vector3(0,0.1,20))
 game.player.position=Vector3(20,0.1,30)
 game.player.update_cover(1)
 var enemy: Hostile=game.bots[0]
 var flank: Hostile=game.bots[1]
 reset_actor(enemy,Vector3(0,0.1,0))
 reset_actor(flank,Vector3(12,0.1,12))
 ally.combat_target=flank
 for i in range(3):await physics_frame
 check(ally.select_contact(ally.position+Vector3.UP*1.6)==enemy,"Observed enemy in sector replaces a previous out-of-sector target")
 enemy.position=Vector3(44,0,44)
 ally.combat_target=null
 ally.select_contact(ally.position+Vector3.UP*1.6)
 check(ally.observation.exposure==0,"Sector order excludes distant visible flank distractions")
 flank.position=Vector3(4,0.1,17)
 for i in range(3):await physics_frame
 check(ally.select_contact(ally.position+Vector3.UP*1.6)==flank,"Nearby visible flank threat still permits self-defence")
 flank.position=Vector3(44,0,44)
 enemy.position=Vector3(0,0.1,0)
 var wall=district.surface_piece(Vector3(0,1.8,10),Vector3(8,3.6,0.6),Color.GRAY,"concrete")
 for i in range(3):await physics_frame
 ally.combat_target=null
 ally.select_contact(ally.position+Vector3.UP*1.6)
 check(ally.observation.exposure==0,"Sector command cannot see through the wall")
 for i in range(90):
  ally._physics_process(1.0/60)
  if i%4==0:await physics_frame
 check(not ally.sees_player and ally.weapon.shots_fired==0,"No automatic fire at an unseen enemy merely because a sector was ordered")
 wall.queue_free()
 for i in range(3):await physics_frame
 ally.cover_timer=100
 ally.has_cover=false
 for i in range(600):
  ally._physics_process(1.0/60)
  if i%2==0:await physics_frame
  if enemy.health<100:break
 check(ally.weapon.shots_fired>0 and enemy.health<100,"Sector order acquires, aims and hits a genuinely visible opponent")
 game.ballistics.clear()
 for actor in game.bots:actor.position=Vector3(44,0,44)
 # Actual movement through several separated cover lines, without contact cheats.
 for z in [12.0,2.0,-8.0]:district.surface_piece(Vector3(0,1.1,z),Vector3(4,2.2,0.8),Color.GRAY,"concrete")
 district.refresh_navigation()
 game.squad.choose(0)
 reset_actor(ally,Vector3(0,0.1,17))
 game.squad.point=Vector3(0,0,-18)
 game.squad.issue("assault")
 var reached_cover := false
 var ran := false
 var cover_positions: Array[Vector3]=[]
 for i in range(2400):
  game.elapsed+=1.0/60
  ally._physics_process(1.0/60)
  ran=ran or ally.sprinting
  if ally.has_cover and ally.position.distance_to(ally.cover_point)<1.1:
   reached_cover=true
   if cover_positions.is_empty() or cover_positions[-1].distance_to(ally.cover_point)>3:cover_positions.append(ally.cover_point)
  if i%3==0:await physics_frame
  if ally.assault_arrived:break
 print("ASSAULT_ROUTE position=",ally.position," cover_stops=",cover_positions.size()," arrived=",ally.assault_arrived)
 check(ran and reached_cover,"Assault uses running bounds and protected stops")
 check(cover_positions.size()>=2,"Assault leaves first cover and progresses through successive positions")
 check(ally.assault_arrived and ally.position.distance_to(ally.order_point)<3,"Real capsule reaches commanded assault point around barriers")
 for i in range(180):
  ally._physics_process(1.0/60)
  if i%4==0:await physics_frame
 check(ally.position.distance_to(ally.order_point)<6.5,"Arrival secures the point instead of chasing commander")
 # Cover handoff is bounded so the sole protected member cannot freeze forever.
 for i in range(3):
  var actor: Hostile=game.allies[i]
  reset_actor(actor,Vector3(-10+i*4,0.1,18))
  actor.order="assault"
  actor.order_point=Vector3(actor.position.x,0,-18)
  actor.assault_arrived=false
  actor.contact_age=0
  actor.alerted=true
  actor.has_cover=true
  actor.cover_point=actor.position
  actor.cover_dwell=3
 game.squad.coordinate()
 check(game.allies.filter(func(a):return a.auto_cover).size()==1,"One assault soldier covers while others can advance")
 for actor in game.allies:
  if actor.auto_cover:actor.cover_dwell=7
 var previous=game.allies.filter(func(a):return a.auto_cover)[0]
 game.squad.coordinate()
 check(not previous.auto_cover and game.allies.any(func(a):return a.auto_cover),"Cover duty transfers so the previous covering soldier can move")
 game.squad.choose(0)
 game.squad.issue("hold")
 check(ally.order=="hold" and not ally.assault_arrived and not ally.auto_cover,"New order cancels assault movement and cover duty")
 game.queue_free()
 for i in range(4):await process_frame
 print("FAIL: " if failed else "PASS: ",checks," offensive order, perception, navigation and handoff checks")
 quit(1 if failed else 0)
