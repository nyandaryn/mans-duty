extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 seed(891)
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.ally_count=4
 game.start_match()
 game.set_physics_process(false)
 game.ballistics.set_physics_process(false)
 game.player.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 game.district.free()
 var d := District.new()
 game.world_root.add_child(d)
 game.district=d
 d.box(Vector3(0,-0.5,0),Vector3(95,1,95),Color.GRAY,true,"earth")
 d.flush()
 d.build_grid()
 for actor in game.bots:actor.position=Vector3(44,0,44)
 game.player.position=Vector3(0,0.1,10)
 game.player.rotation.y=0
 var ally: Hostile=game.allies[0]
 ally.position=Vector3(-1,0.1,20)
 game.player.crouched=true
 for i in range(80):
  ally._physics_process(1.0/60)
  if i%4==0:await physics_frame
 check(ally.stance>0.9 and ally.follow_crouch,"Following soldier copies commander's crouch")
 check(Vector2(ally.velocity.x,ally.velocity.z).length()<=2.2 and not ally.sprinting,"Stealth following does not sprint out of concealment")
 check(ally.get_child(0).shape.height<1.4,"Crouched collision capsule is actually lower")
 game.player.prone=true
 for i in range(30):ally._physics_process(1.0/60)
 check(ally.tactical_prone>0.95 and ally.collapse==0 and ally.treatment_time==0,"Healthy follower goes prone without invoking injury logic")
 check(ally.model.rotation.x< -1.4 and ally.get_child(0).rotation.x>1.4,"Prone visual and collision agree")
 game.player.prone=false
 game.player.crouched=false
 game.player.velocity=Vector3(0,0,-6.3)
 ally.position=Vector3(-2,0.1,30)
 ally.has_cover=false
 for i in range(60):ally._physics_process(1.0/60)
 check(ally.sprinting and Vector2(ally.velocity.x,ally.velocity.z).length()>6.3,"Follower runs fast enough to keep up with sprinting commander")
 game.squad.trail=PackedVector3Array([Vector3(0,0,20),Vector3(0,0,15),Vector3(5,0,15),Vector3(5,0,10)])
 game.player.position=Vector3(5,0.1,10)
 game.player.crouched=true
 var file: Vector3=game.squad.formation_point(0)
 check(file.x>4 and file.z>12,"Stealth formation follows actual bent trail rather than facing offset")
 # Nearby low cover, plus separate high cover positions for a live opposing team.
 game.player.position=Vector3(16,0.1,23)
 game.player.crouched=false
 game.player.velocity=Vector3.ZERO
 d.surface_piece(Vector3(16,1.5,21),Vector3(0.6,3,0.6),Color.GRAY,"wood")
 for i in range(3):await physics_frame
 game.squad.commander_cover=game.squad.commander_uses_cover()
 check(game.squad.commander_cover and game.squad.stealth_follow(),"Standing behind a trunk also requests concealed following")
 game.squad.commander_cover=false
 game.player.crouched=true
 game.player.position=Vector3(0,0.1,22)
 game.player.velocity=Vector3.ZERO
 for x in [-7.0,-2.0,3.0,8.0]:d.surface_piece(Vector3(x,0.65,10),Vector3(2.6,1.3,0.8),Color.GRAY,"concrete")
 d.refresh_navigation()
 for i in range(3):await physics_frame
 ally.position=Vector3(-7,0.1,14)
 ally.target=Vector3(-7,0.1,-18)
 ally.alerted=true
 ally.contact_age=0
 ally.under_fire_time=5
 game.squad.prepare_actor(ally)
 ally.find_cover()
 check(ally.has_cover,"Finds physical cover near contact")
 check(game.squad.protection(ally,ally.cover_point,0.6)>=0.65,"Selected cover screens the low body")
 check(ally.cover_requires_prone,"Cover below a crouched head requires going prone")
 ally.sees_player=true
 ally.tactical_prone=0
 var speed: float=game.squad.movement(ally,Vector3.FORWARD,ally.position+Vector3.FORWARD*3)
 check(ally.sprinting and speed>=6,"Enemy visibility does not cancel a short dash to cover")
 var retained := ally.cover_point
 game.player.position.x=20
 game.squad.prepare_actor(ally)
 check(game.squad.destination(ally)==retained,"Incoming fire keeps cover despite formation slot moving away")
 game.player.position=Vector3(0,0.1,22)
 # Actual live fire: four allies seek the low barriers while two opponents fire.
 for i in range(game.allies.size()):
  var a: Hostile=game.allies[i]
  a.position=Vector3(-4.5+i*5,0.1,15)
  a.rotation.y=0
  a.target=Vector3(a.position.x,0.1,-18)
  a.alerted=true
  a.contact_age=0
  a.under_fire_time=5
  a.cover_timer=0
  a.has_cover=false
  a.tactical_prone=0
  a.think_timer=0
  a.recognition=0
  a.weapon=WeaponState.new("ak74")
 for i in range(2):
  var enemy: Hostile=game.bots[i]
  enemy.position=Vector3(-4.5+i*10,0.1,-18)
  enemy.home=enemy.position
  enemy.defensive=true
  enemy.rotation.y=PI
  enemy.cover_timer=100
  enemy.target=game.allies[i].position
  enemy.alerted=true
  enemy.recognition=1
  enemy.think_timer=0
  enemy.combat_target=game.allies[i]
 var covered := {}
 var dashes := {}
 for frame in range(720):
  var delta := 1.0/60
  game.elapsed=frame*delta
  for enemy in game.bots.slice(0,2):enemy._physics_process(delta)
  for a in game.allies:
   a._physics_process(delta)
   if a.sprinting:dashes[a.formation_index]=true
   if a.has_cover and a.position.distance_to(a.cover_point)<1.2:covered[a.formation_index]=true
  if frame%20==0:game.squad.coordinate()
  game.ballistics._physics_process(delta)
  if frame%4==0:await physics_frame
 var alive := 0
 var rounds := 0
 for a in game.allies:
  if not a.dead:alive+=1
 for enemy in game.bots.slice(0,2):rounds+=enemy.weapon.shots_fired
 print("LIVE_SQUAD alive=",alive," reached_cover=",covered.size()," sprinted=",dashes.size()," enemy_shots=",rounds)
 check(game.running,"Commander survives so the live scenario runs to completion")
 check(rounds>0,"Live enemies actually fire during cover scenario")
 check(covered.size()>=3 and dashes.size()>=3,"Group physically reaches cover using short runs")
 check(alive>=2,"Group is not wiped out in the covered-contact fixture")
 # Protected, healthy soldiers can take overwatch; not everyone charges at once.
 for a in game.allies:
  a.dead=false
  a.collapse=0
  a.order="follow"
  a.fire_at_will=true
  a.weapon=WeaponState.new("ak74")
  a.contact_age=0
  a.has_cover=true
  a.cover_point=a.position
 game.squad.coordinate()
 var overwatch := 0
 for a in game.allies:
  if a.auto_cover:overwatch+=1
 check(overwatch==1,"One protected soldier covers the other members")
 game.queue_free()
 for i in range(4):await process_frame
 print("FAIL: " if failed else "PASS: ",checks," stealth, posture, speed, cover and live-contact checks")
 quit(1 if failed else 0)
