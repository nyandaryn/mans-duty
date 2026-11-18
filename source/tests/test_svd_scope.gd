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
 var gun := WeaponState.new("svd")
 check(gun.data.capacity==10 and gun.ammunition_total()==40,"SVD has four real 10-round magazines including the loaded magazine")
 check(gun.chambered and gun.rounds()==9,"Initial chamber is counted separately from magazine")
 check(gun.mode()=="ОДИН" and gun.data.modes.size()==1,"SVD is semi-automatic only")
 for i in range(10):check(gun.fire(),"Loaded SVD fires exactly ten rounds")
 check(gun.bolt_open and not gun.chambered and not gun.fire(),"Empty SVD locks open")
 gun.reload(1)
 gun.update(10)
 check(not gun.bolt_open and gun.chambered and gun.rounds()==9,"Empty reload releases bolt and feeds one round")
 # Integrate physical projectiles independently at 240 Hz. Compare the optical
 # line against the impact plane, including the real scope-to-muzzle offset.
 var muzzle := Vector3(0,0,-0.80)
 for distance in [100,200,400,600,800,1000,1300]:
  var point := muzzle
  var velocity := Vector3(0,0,-830)
  var plane: float=SvdArt.OCULAR.z-distance
  while point.z>plane:
   var next := FlightModel.advance(point,velocity,float(FlightModel.BC.svd),1.0/240)
   if next[0].z<=plane:
    point=point.lerp(next[0],(point.z-plane)/(point.z-next[0].z))
    break
   point=next[0]
   velocity=next[1]
  var ray := ScopeSight.sight_direction(distance)
  var reticle_hit := SvdArt.OCULAR+ray*((SvdArt.OCULAR.z-plane)/-ray.z)
  check(point.distance_to(reticle_hit)<maxf(0.025,distance*0.00003),"Physical bullet intersects reticle at %s m" % distance)
 check(is_equal_approx(ScopeSight.reticle_angles(100,2).x-ScopeSight.reticle_angles(100).x,-0.001),"Two windage clicks move reticle by one milliradian")
 var ratio := SvdArt.LENS_RADIUS/(SvdArt.EYE_RELIEF*tan(deg_to_rad(ScopeSight.FIELD_OF_VIEW)*0.5))
 check(is_equal_approx(ratio,4.0),"Optical magnification relative to unzoomed periphery is four")
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.primary_tile.pressed.emit()
 game.loadout_screen.picker.select("svd")
 check(game.primary!="svd","Rifleman cannot take the SVD")
 game.set_player_class("sniper")
 game.loadout_screen.picker.open(false)
 game.loadout_screen.picker.select("svd")
 check(game.primary=="svd" and game.primary_tile.preview.content_key=="svdfalse","Loadout selection includes actual SVD model")
 for tile in game.rifle_mag_tiles:check(tile.preview.content_key=="svdtrue","Selected SVD magazines appear in pouches")
 game.start_match()
 var player: Operator=game.player
 player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 player.position=Vector3(0,100,0)
 player.rotation=Vector3.ZERO
 player.camera.position=Vector3(0,1.65,0)
 player.camera.rotation=Vector3.ZERO
 player.aim=true
 player.ads_weight=1
 player.viewmodel.transform=Transform3D(Basis.IDENTITY,player.ads_position())
 await frames(2)
 var scope: ScopeSight=player.scope_sight
 scope.update()
 check(scope.enabled and not scope.occluded,"Aimed optic is active in open space")
 check(scope.viewport.world_3d==player.get_world_3d() and scope.camera.cull_mask==1,"Optic renders the actual world but excludes first-person weapon geometry")
 check(scope.eye_offset.distance_to(Vector3(0,0,SvdArt.EYE_RELIEF))<0.00001,"ADS eye reaches physical relief and centered exit pupil")
 var optical_basis := scope.camera.global_basis
 var before := ScopeSight.reticle_angles(player.current().scope_zero)
 var elevation := InputEventKey.new()
 elevation.pressed=true
 elevation.physical_keycode=KEY_PAGEUP
 player._unhandled_input(elevation)
 scope.update()
 check(player.current().scope_zero==200 and ScopeSight.reticle_angles(200)!=before,"Elevation dial moves etched reticle")
 check(scope.camera.global_basis.is_equal_approx(optical_basis),"Dial adjustment does not silently rotate camera or snap to a target")
 check(not player.shoot(),"Adjusting scope occupies support hand and prevents firing")
 player.scope_adjust_time=0
 player.viewmodel.position.x+=0.004
 scope.update()
 var pupil: Vector2=scope.lens_material.get_shader_parameter("pupil")
 check(absf(pupil.x)>1.3,"Four millimetres of lateral eye displacement drives exit-pupil shadow")
 player.viewmodel.position=player.ads_position()
 var blocker := StaticBody3D.new()
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size=Vector3(1,1,0.025)
 shape.shape=box
 blocker.add_child(shape)
 game.add_child(blocker)
 blocker.global_position=player.camera.global_position+Vector3(0,0,-0.17)
 await frames(2)
 scope.update()
 check(scope.occluded,"Cover between eye and objective blacks out optic instead of seeing through it")
 blocker.queue_free()
 await frames(2)
 player.aim=false
 player.ads_weight=0
 scope.update()
 check(not scope.enabled and scope.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Hip fire disables secondary scene rendering")
 player.aim=true
 player.ads_weight=1
 Input.action_press("sprint")
 player.update_breath(0.01,false)
 check(player.holding_breath,"Shift while stationary ADS steadies aim")
 for i in range(250):player.update_breath(1.0/60,false)
 check(not player.holding_breath and player.breath_recovery>0 and player.scope_fatigue>0.4,"Breath hold exhausts and creates a recovery penalty")
 Input.action_release("sprint")
 player.scope_fatigue=1
 player.update_breath(0.01,false)
 check(not player.holding_breath,"Exhausted player cannot immediately steady again")
 player.cooldown=0
 Input.action_press("fire")
 var shots := player.shots
 player.update_trigger()
 check(player.shots==shots,"Holding trigger does not automatically fire SVD")
 Input.action_release("fire")
 player.ads_weight=1
 game.paused=true
 scope.update()
 check(not scope.enabled,"Pause stops optic rendering")
 game.paused=false
 player.slot=1
 player.make_viewmodel()
 scope.update()
 check(not scope.enabled and scope.lens==null,"Changing to pistol removes optic")
 # The reported empty-rifle -> sidearm -> reload -> inventory/repack cycle.
 var retained_texture := scope.view_texture
 var retained_material := scope.lens_material
 player.current().reload(0);player.current().update(10)
 player.slot=0;player.make_viewmodel()
 player.current().cancel()
 while player.current().fire():pass
 player.current().reload(0);player.current().update(10)
 player.current().pouches[0].rounds=0
 game.inventory.toggle()
 game.inventory.select_magazine(Vector2i(0,2))
 game.inventory.select_magazine(Vector2i(0,1))
 game.inventory.begin_transfer()
 check(game.inventory.transfer.active,"Reloaded SVD magazines can be repacked after sidearm swap")
 for i in range(700):
  game.inventory._process(1.0/60)
  player.update_pose(1.0/60)
 game.inventory.close()
 player.aim=true;player.switch_delay=0;player.gun_kick=0;player.sway=Vector2.ZERO
 for i in range(90):player.update_pose(1.0/60)
 scope.update()
 check(scope.enabled and not scope.occluded,"PSO returns after complete weapon and magazine sequence")
 check(scope.view_texture==retained_texture and scope.lens_material==retained_material,"Scope render resources survive weapon rebuilds")
 check(scope.camera.current and scope.viewport.size==Vector2i(768,768),"Recovered optic has an active full-resolution render camera")
 check(scope.eye_offset.distance_to(Vector3(0,0,SvdArt.EYE_RELIEF))<0.0001,"Eye returns to optical exit pupil after magazine work")
 var displayed := Models.weapon("svd")
 root.add_child(displayed)
 var top_round: Node3D=displayed.get_node("Magazine/AmmoEvidence/TopRound")
 for part in top_round.get_children():
  if not part is MeshInstance3D:continue
  var bounds: AABB=part.get_aabb()
  for i in range(8):
   var p: Vector3=displayed.get_node("Magazine").to_local(part.to_global(bounds.get_endpoint(i)))
   check(p.z>=-0.1121 and p.z<=-0.0309,"Inspected 7.62x54R cartridge fits between actual magazine front and rear walls")
 displayed.free()
 var spent: AABB= game.debris.cartridge_mesh(false,false,true).get_aabb()
 var live: AABB= game.debris.cartridge_mesh(false,true,true).get_aabb()
 check(spent.size.z>=0.054 and live.size.z>0.073,"SVD ejects correct-size rimmed case and visible live cartridge")
 game.queue_free()
 await frames(3)
 print("PASS: %d SVD, ballistics, optical geometry and interaction checks" % checks)
 quit()
