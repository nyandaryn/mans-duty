extends SceneTree
var checks := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  printerr("FAIL: ",message)
  quit(1)
  assert(ok,message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame
func run():
 var world := District.new()
 root.add_child(world)
 var slab := world.surface_piece(Vector3(0,2,0),Vector3(3,3,0.04),Color.BROWN,"wood")
 await frames(2)
 var front := Vector3(0,2,0.02)
 var straight: Vector3=Penetration.exit_point(slab,0,front,Vector3.FORWARD)
 var oblique: Vector3=Penetration.exit_point(slab,0,front,Vector3(0.866,0,-0.5).normalized())
 check(is_equal_approx(front.distance_to(straight),0.04),"Actual box thickness")
 check(absf(front.distance_to(oblique)-0.08)<0.001,"Oblique path is twice as thick")
 for id in Ballistics.PROFILES:
  var speed: float=Ballistics.PROFILES[id].speed
  check(Penetration.remaining(id,speed,"wood",0.04)>0,id+" penetrates thin board")
  check(Penetration.remaining(id,speed,"concrete",0.35)==0,id+" stopped by structural concrete")
  check(Penetration.remaining(id,speed,"steel",0.08)==0,id+" stopped by thick steel")
 check(Penetration.remaining("ak74",880,"wood",0.20)>0 and Penetration.remaining("pm",315,"wood",0.20)==0,"Calibres differ on same geometry")
 world.concrete_barrier(Vector3(10,0,0))
 await frames(2)
 var barrier: StaticBody3D=world.get_node("ConcreteBarrier")
 var space := world.get_world_3d().direct_space_state
 var widths: Array[float]=[]
 for height in [0.1,1.0]:
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(10,height,2),Vector3(10,height,-2),1))
  check(not hit.is_empty(),"Ray hits tapered concrete mesh")
  var exit: Variant=Penetration.exit_point(barrier,hit.shape,hit.position,Vector3.FORWARD)
  check(exit!=null,"Find exit through actual triangle mesh")
  widths.append(hit.position.distance_to(exit))
 check(widths[0]>widths[1]*2,"Taper is measured at actual impact height")
 # Concentrated damage opens a real gap in both visible and collision geometry.
 for i in range(6):slab.strike(front,Vector3.FORWARD,150,true)
 await frames(5)
 check(not is_instance_valid(slab),"Fractured original replaced, not hidden collision")
 check(world.fragments.size()==1,"Wood fragment becomes a rigid body")
 var hole := space.intersect_ray(PhysicsRayQueryParameters3D.create(front+Vector3.BACK,front+Vector3.FORWARD,1))
 check(hole.is_empty(),"Bullet and vision pass through destroyed section")
 var beside := space.intersect_ray(PhysicsRayQueryParameters3D.create(front+Vector3(0.4,0,1),front+Vector3(0.4,0,-1),1))
 check(not beside.is_empty(),"Adjacent wood remains solid")
 barrier.strike(Vector3(10,1,0.155),Vector3.FORWARD,7000,false)
 await frames(12)
 check(world.fracture_count==2,"CSG mesh crater updates exact mesh collider")
 world.queue_free()
 await frames(3)
 # Full projectile loop: multiple layers, residual energy, and downstream target.
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 game.player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 var d: District=game.district
 d.surface_piece(Vector3(0,20,35),Vector3(3,3,0.03),Color.BROWN,"wood")
 d.surface_piece(Vector3(0,20,33),Vector3(3,3,0.03),Color.BROWN,"wood")
 d.surface_piece(Vector3(0,20,30),Vector3(3,3,0.3),Color.GRAY,"concrete")
 await frames(2)
 var count: int=game.ballistics.hit_count
 game.ballistics.launch(Vector3(0,20,40),Vector3.FORWARD,"ak74",30,game.player)
 await frames(6)
 check(game.ballistics.hit_count-count==3,"One projectile hits both boards and stops in concrete")
 check(game.ballistics.projectiles.is_empty(),"Stopped projectile removed")
 # Marks parented to a destroyed object must not leave stale typed references.
 var temporary_surface := Node3D.new()
 game.add_child(temporary_surface)
 for i in range(ImpactEffects.MARKS_KEPT):game.impact(Vector3(i*0.04,10,0),Vector3.UP,temporary_surface)
 temporary_surface.free()
 game.impact(Vector3(0,10,1),Vector3.UP)
 check(game.bullet_marks.size()==1 and is_instance_valid(game.bullet_marks[0]),"Destroyed-surface decals are pruned before enforcing impact budget")
 game.queue_free()
 await frames(3)
 print("PASS: ",checks," penetration, taper, local fracture and layered flight checks")
 quit()
