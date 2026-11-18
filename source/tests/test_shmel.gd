extends SceneTree
var checks := 0
var failed := false
var game: Node3D
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func box(pos: Vector3, size: Vector3, material: String="concrete") -> StaticBody3D:
 var body := StaticBody3D.new();var shape := BoxShape3D.new();shape.size=size
 var collision := CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
 game.add_child(body);body.position=pos;body.set_meta("ballistic_material",material)
 return body
func frames():await physics_frame;await physics_frame
func movement_speed(p: Operator, actions: Array, prone: bool=false) -> float:
 for action in ["forward","sprint","aim"]:Input.action_release(action)
 p.position=Vector3(100,30.02,100);p.velocity=Vector3.ZERO;p.prone_requested=prone
 # Crouch is a toggled stance, not a held key.
 p.crouch_requested="crouch" in actions
 for action in actions:
  if action!="crouch":Input.action_press(action)
 for i in range(35):
  p._physics_process(1.0/60)
  if i%7==0:await physics_frame
 var speed := Vector2(p.velocity.x,p.velocity.z).length()
 for action in ["forward","sprint","aim"]:Input.action_release(action)
 p.crouch_requested=false
 return speed
func run():
 var bag := BackpackState.new()
 check(bag.add("rpo_a")==-1,"Launcher requires carrying equipment")
 bag.equipped=true;var uid := bag.add("rpo_a")
 check(uid>0 and bag.used_slots()==12,"Launcher reserves its carrying footprint")
 check(is_equal_approx(bag.mass()-Equipment.PACK_MASS,11),"Loaded launcher adds public 11 kg mass")
 check(bag.add("rpo_a")==-1,"Second launcher exceeds pack payload limit")
 var restored := BackpackState.restore(bag.serialize())
 check(restored.count("rpo_a")==1 and restored.item(restored.first("rpo_a")).rounds==0,"Preset stores one whole launcher, not reload ammunition")
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0;game.ally_count=1;game.loadout_bag=bag;game.start_match();game.set_process(false);game.set_physics_process(false);game.blasts.set_physics_process(false)
 var p: Operator=game.player;p.set_physics_process(false)
 for bot in game.bots+game.allies:bot.set_physics_process(false);bot.position=Vector3(200,30,200)
 p.position=Vector3(100,30,100);p.rotation=Vector3.ZERO;p.pitch=0;p.update_cover(1);p.switch_delay=0
 var rig: LauncherRig=p.launcher
 var ammunition := p.current().ammunition_total()
 var mass := p.carried_mass()
 var floor := box(Vector3(100,29.8,100),Vector3(24,0.4,24))
 await frames()
 # Compare real movement with the same carried load, swapping only the held weapon.
 for actions in [["forward"],["forward","sprint"],["forward","crouch"],["forward","aim"],["forward","sprint","aim"]]:
  var rifle_speed := await movement_speed(p,actions)
  check(rig.equip(),"Retrieve launcher for movement comparison "+str(actions));rig.tick(3.81)
  var launcher_speed := await movement_speed(p,actions)
  check(absf(rifle_speed-launcher_speed)<0.01,"Launcher uses ordinary movement speed "+str(actions))
  check(not p.field_rig.busy() and not p.shoot(),"Ready launcher allows locomotion while keeping rifle fire blocked")
  if "sprint" in actions and "aim" not in actions:check(launcher_speed>4.5,"Shift actually sprints with launcher")
  rig.cancel()
 var prone_speed := await movement_speed(p,["forward"],true)
 rig.equip();rig.tick(3.81)
 check(absf(prone_speed-await movement_speed(p,["forward"],true))<0.01,"Launcher uses ordinary crawling speed")
 p.blood_loss=0.7
 check(await movement_speed(p,["forward","sprint"])<0.01,"Launcher no longer overrides immobilizing blood loss")
 p.blood_loss=0;rig.cancel()
 await movement_speed(p,[])
 p.position=Vector3(100,30,100);p.velocity=Vector3.ZERO
 floor.free();await frames()
 var hotkey := InputEventKey.new();hotkey.physical_keycode=KEY_4;hotkey.pressed=true
 p._unhandled_input(hotkey)
 check(rig.mode=="draw","Key 4 equips dedicated launcher from selected bag")
 check(not rig.fire() and not p.shoot(),"Draw animation blocks launcher and rifle fire")
 check(not p.vault.eligible() and not p.begin_bandage(),"Two handed launcher blocks vault and treatment")
 rig.tick(3.7);check(rig.mode=="draw","Cannot bypass full retrieval duration")
 rig.tick(0.11);check(rig.mode=="ready" and rig.visible,"Ready after timed retrieval")
 check(p.carried_mass()==mass,"Holding launcher does not duplicate or remove its weight")
 p.switch_weapon(1);check(p.slot==0,"Cannot swap rifle through active launcher")
 rig.ads=1;rig.animate()
 var sight: Vector3=rig.tube.to_global(Vector3(ShmelArt.SIGHT_X,ShmelArt.SIGHT_Y,-0.40))
 var rear: Vector3=rig.tube.to_global(Vector3(ShmelArt.SIGHT_X,ShmelArt.SIGHT_Y,ShmelArt.REAR_SIGHT_Z))
 check(absf(p.camera.to_local(sight).x)<0.0001 and absf(p.camera.to_local(sight).y)<0.0001,"Front sight aligns with camera")
 check(absf(p.camera.to_local(rear).x)<0.0001 and absf(p.camera.to_local(rear).y)<0.0001,"Rear notch shares physical sight line")
 Input.action_press("aim")
 for i in range(40):p.velocity=Vector3.ZERO;p._physics_process(1.0/60)
 Input.action_release("aim")
 check(rig.ads>0.99 and absf(p.camera.fov-60)<0.2,"Aim input converges to launcher's FOV without rifle camera overriding it")
 var muzzle: Vector3=rig.tube.get_node("Muzzle").global_position
 var obstruction := box(muzzle+Vector3(0,0,0.10),Vector3(2,2,0.05));await frames()
 check(not rig.fire() and p.backpack.count("rpo_a")==1,"Muzzle obstruction does not spend launcher")
 obstruction.free();await frames()
 rig.toggle();rig.tick(2.01)
 check(not rig.active() and p.backpack.count("rpo_a")==1,"Stowing an unfired tube preserves inventory")
 check(rig.equip(),"Can retrieve stowed launcher again");rig.tick(3.81)
 check(rig.fire(),"Unobstructed ready tube fires")
 check(p.backpack.count("rpo_a")==0 and game.blasts.rockets.size()==1,"Exactly one tube consumed for one projectile")
 check(not rig.fire() and p.current().ammunition_total()==ammunition,"Spent launcher cannot refire or consume rifle ammunition")
 check(absf(mass-p.carried_mass()-11)<0.001,"Discarded launcher removes its carried weight")
 check(game.loadout_bag.count("rpo_a")==1,"Mission shot does not mutate saved loadout")
 rig.tick(1.11);check(not rig.active() and not rig.equip(),"No launcher remains after discard")
 p.backpack.add("rpo_a");game.debug_invulnerable=true
 check(rig.equip(),"Debug still requires an equipped tube");rig.tick(3.81);rig.fire();rig.tick(1.11)
 check(p.backpack.count("rpo_a")==1,"F8 alone retains a reusable debug tube")
 game.debug_invulnerable=false;game.blasts.clear()
 check(rig.equip(),"Begin interrupted draw");rig.tick(1)
 p.receive_blast(1,0.3,Vector3.FORWARD)
 check(not rig.active() and p.backpack.count("rpo_a")==1,"Blast interrupts handling without consuming unfired item")
 p.concussion=ConcussionState.new();p.health=100;p.injury_time=0
 # Continuous segment sweep catches a thin obstacle at different simulation rates.
 var wall := box(Vector3(100,31,90),Vector3(5,5,0.05))
 p.position=Vector3(150,30,100);await frames()
 for step in [1.0/120,1.0/30,0.2]:
  var before: int=game.blasts.detonations
  game.blasts.launch(Vector3(100,31,100),Vector3.FORWARD,p)
  for i in range(100):
   game.blasts._physics_process(step)
   if game.blasts.rockets.is_empty():break
  check(game.blasts.detonations==before+1 and game.blasts.rockets.is_empty(),"Thin wall collision at step "+str(step))
 game.blasts.launch(Vector3(120,31,100),Vector3.FORWARD,p)
 var start: Vector3=game.blasts.rockets[0].position
 game.paused=true;game.blasts._physics_process(1)
 check(game.blasts.rockets[0].position==start,"Pause freezes projectile")
 game.paused=false;game.blasts.clear()
 check(game.blasts.rockets.is_empty(),"Restart clear removes live projectiles")
 var a := Vector3(100,31,91);var b := Vector3(100,31,89)
 check(game.blasts.transmission(a,b)==0,"Concrete blocks direct blast exposure")
 wall.set_meta("ballistic_material","wood")
 check(is_equal_approx(game.blasts.transmission(a,b),0.35),"Wood attenuates exposure")
 wall.set_meta("ballistic_material","glass")
 check(is_equal_approx(game.blasts.transmission(a,b),0.75),"Glass transmits more than wood")
 wall.free();await frames()
 check(game.blasts.transmission(a,b)==1,"An actual opening permits exposure")
 var near: Hostile=game.bots[0];var survivor: Hostile=game.bots[1];var shielded: Hostile=game.bots[2];var ally: Hostile=game.allies[0]
 var center := Vector3(100,31,100)
 near.position=Vector3(100,30,102);survivor.position=Vector3(108,30,100)
 shielded.position=Vector3(100,30,94);ally.position=Vector3(108,30,102)
 wall=box(Vector3(100,31,97),Vector3(5,5,0.2));await frames()
 game.blasts.detonate(center)
 check(near.dead,"Exposed nearby actor receives fatal game damage")
 check(not survivor.dead and survivor.health<100 and survivor.concussion.active(),"More distant exposed survivor receives persistent concussion")
 check(not shielded.dead and shielded.health==100 and not shielded.concussion.active(),"Solid wall protects a closer actor")
 check(ally.health<100 and ally.concussion.active(),"Friendlies are not immune to area damage")
 check(game.blasts.get_child_count()<12,"Effects remain bounded after repeated fixture blasts")
 game.queue_free();await process_frame;await process_frame
 print("FAIL: " if failed else "PASS: ",checks," RPO-A inventory / handling / projectile / obstruction checks")
 quit(1 if failed else 0)
