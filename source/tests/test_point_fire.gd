extends SceneTree
var checks := 0
var failed := false
var game: Node3D
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func wall_at(player: Operator, distance: float) -> StaticBody3D:
 var body := StaticBody3D.new();var collision := CollisionShape3D.new();var shape := BoxShape3D.new()
 shape.size=Vector3(5,5,0.30);collision.shape=shape;body.add_child(collision)
 game.add_child(body);body.transform=player.camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-distance))
 body.set_meta("ballistic_material","concrete")
 return body
func frames():await physics_frame;await physics_frame
func run():
 seed(7413)
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0;game.ally_count=0;game.start_match();game.set_physics_process(false);game.set_process(false)
 game.ballistics.set_physics_process(false);game.blasts.set_physics_process(false)
 game.debug_invulnerable=true
 var p: Operator=game.player;p.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false);bot.position=Vector3(200,30,200)
 p.position=Vector3(100,30,100);p.rotation=Vector3.ZERO;p.velocity=Vector3.ZERO
 for id in WeaponState.DATA:
  p.slot=1 if id in ["pm","m9"] else 0;p.weapons[p.slot]=WeaponState.new(id);p.make_viewmodel();p.switch_delay=0
  for distance in [1.5,2.5,7.0]:
   p.pitch=-1.15 if distance==1.5 else (0.0 if distance==2.5 else -0.65)
   p.camera.rotation=Vector3(p.pitch,0,0)
   game.bullet_marks.clear()
   var wall := wall_at(p,distance);await frames()
   var target: Vector3=p.camera.to_global(Vector3(0,0,-distance+0.15))
   var average := Vector3.ZERO
   for shot in range(6):
    p.cooldown=0;p.gun_kick=0;p.recoil=0;p.aim=false;p.ads_weight=0;p.sway=Vector2.ZERO
    p.current().magazine.rounds=int(p.current().data.capacity);p.current().chambered=true
    p.update_pose(1)
    if shot==0:check((-p.viewmodel.global_basis.z).angle_to(p.muzzle.global_position.direction_to(target))<0.02,id+" hip model points along intended close shot")
    var before: int=game.bullet_marks.size()
    check(p.shoot(),id+" actual hip-fire shot")
    for step in range(25):
     game.ballistics._physics_process(0.002)
     if game.bullet_marks.size()>before:break
    if game.bullet_marks.size()>before:average+=game.bullet_marks[-1].global_position-target
    else:check(false,id+" projectile must hit crosshair surface")
    game.ballistics.clear()
   average/=6
   check(average.length()<0.09,id+" close group has no systematic right/down offset at "+str(distance)+" m: "+str(average))
   wall.free();await frames()
 # Convergence must not erase physical recoil or alter blind-fire direction.
 p.camera.rotation=Vector3.ZERO;p.pitch=0
 var recoil_wall := wall_at(p,7);await frames()
 p.gun_kick=0.12;p.update_pose(0)
 var recoil_axis := -p.viewmodel.global_basis.z
 check(recoil_axis.angle_to(p.point_fire_direction(p.viewmodel.global_position))>0.1,"Hip convergence retains muzzle climb")
 p.cooldown=0;p.shoot()
 check(not game.ballistics.projectiles.is_empty(),"Recoiling shot has physical projectile")
 if not game.ballistics.projectiles.is_empty():
  check(game.ballistics.projectiles[-1].velocity.normalized().angle_to(recoil_axis)<0.025,"Recoil affects live hip-fire trajectory")
 game.ballistics.clear();p.gun_kick=0;p.blind_mode=1;p.update_pose(1)
 check((-p.viewmodel.global_basis.z).dot(-p.camera.global_basis.z)>0.999,"Blind fire does not converge through crosshair")
 p.blind_mode=0;recoil_wall.free();await frames()
 p.slot=0;p.weapons[0]=WeaponState.new("ak74");p.make_viewmodel();p.switch_delay=0
 p.backpack.equipped=true;p.backpack.add("rpo_a")
 for distance in [2.5,7.0]:
  p.pitch=-0.35;p.camera.rotation=Vector3(p.pitch,0,0)
  var wall := wall_at(p,distance);await frames()
  var target: Vector3=p.camera.to_global(Vector3(0,0,-distance+0.15))
  check(p.launcher.equip(),"Ready RPO for point fire");p.launcher.tick(3.81)
  check(p.launcher.fire(),"RPO fires from hip")
  for step in range(40):
   game.blasts._physics_process(0.002)
   if game.blasts.rockets.is_empty():break
  check(game.blasts.rockets.is_empty(),"RPO reaches nearby surface")
  var effect := game.blasts.get_child(game.blasts.get_child_count()-1) as BlastEffect
  check(effect!=null and effect.global_position.distance_to(target)<0.07,"RPO hip impact converges on crosshair, retaining physical flight")
  p.launcher.cancel();wall.free();game.blasts.clear();await frames()
 p.camera.rotation=Vector3.ZERO;p.pitch=0;p.update_pose(1)
 var blocked := wall_at(p,0.50);await frames()
 check(p.point_fire_direction(p.muzzle.global_position).dot(-p.camera.global_basis.z)>0.99,"Surface behind muzzle never reverses projectile")
 p.cooldown=0;p.shoot()
 check(game.ballistics.projectiles.is_empty(),"Physical obstruction still prevents shooting through cover")
 blocked.free();game.queue_free();await process_frame;await process_frame
 print("FAIL: " if failed else "PASS: ",checks," hip-fire convergence / actual projectile / close cover checks")
 quit(1 if failed else 0)
