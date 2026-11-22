extends SceneTree
# The player's PKM, RPG-7 and RPG-22:
# - the PKM's bipod goes down only lying or on a support, folds when he
#   moves, and takes two thirds of the recoil off;
# - its frame sight (PgUp / PgDn, 1–15) raises the slider and the gun at the
#   eye by the elevation of the range;
# - the RPG-7 comes off the mount, will not fire empty, takes a PG-7VL from
#   the pack (R), fires it and stays in the hands; 5 takes the next launcher;
# - the RPG-22 comes off the mount folded and will not fire or aim so; R
#   brings it into the firing position, which cannot be undone: put back on
#   the mount it stays drawn out and comes off it ready; fired, it is thrown
#   away;
# - the PGO-7's chevrons and the RPG-22's frame bars are laid off the
#   grenades' own flight: on the mark of the range they hit at that range;
# - the grenadier's pack holds the RPG-7 and three rounds.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func tick(p: Operator, seconds: float) -> void:
 var steps:=int(ceil(seconds*60.0))
 for i in range(steps):p.launcher.tick(1.0/60.0)

func key(p: Operator, code: Key) -> void:
 var event:=InputEventKey.new()
 event.physical_keycode=code;event.pressed=true
 p._unhandled_input(event)

# Pitch climbed by a burst of the PKM.
func climb(p: Operator, shots: int) -> float:
 var start: float=p.pitch
 p.recoil_sequence=0
 for i in range(shots):
  p.cooldown=0.0
  p.shoot()
 return p.pitch-start

func run():
 seed(4401)
 # --- The sights against the flight -----------------------------------------------
 for distance in [200.0,300.0,400.0,500.0]:
  # The chevron of the range on a target at the eye's height: the bore stands
  # above that line by the tilt of the PGO-7 and the chevron's depression.
  var bore:=LauncherRig.pgo_tilt()+LauncherRig.pgo_chevron(distance)
  var height:=BlastSystem.rocket_drop("pg7vl",distance,bore)
  check(absf(height-Rpg7Art.EYEPIECE.y)<0.25,"PGO-7 chevron %d: the PG-7VL arrives %.2f m off the point of aim" % [int(distance),height-Rpg7Art.EYEPIECE.y])
 check(absf(LauncherRig.pgo_chevron(200.0))<0.0001 and LauncherRig.pgo_chevron(500.0)>LauncherRig.pgo_chevron(300.0),"The top chevron is the optical axis, the farther ones lower")
 for mark in LauncherRig.frame_marks():
  var height:=BlastSystem.rocket_drop("rpg22",float(mark[0]),float(mark[1]))
  check(absf(height-Rpg22Art.APERTURE.y)<0.25,"RPG-22 frame bar %d: the rocket arrives %.2f m off the point of aim" % [int(mark[0]),height-Rpg22Art.APERTURE.y])
 # --- The grenadier's pack ---------------------------------------------------------
 var bag:=BackpackState.new();bag.equipped=true
 var placed:=0
 for kind in ["rpg7","pg7vl","pg7vl","pg7vl"]:if bag.add(kind)>=0:placed+=1
 check(placed==4,"The RPG-7 and three PG-7VL fit in the pack (%d placed)" % placed)
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("grenadier")
 game.loadout_bag=BackpackState.new();game.loadout_bag.equipped=true
 for kind in ["rpg7","pg7vl","pg7vl","rpg22"]:game.loadout_bag.add(kind)
 game.selected_map=TrainingRange.ID
 game.start_match()
 game.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 await frames(3)
 var p: Operator=game.player
 check(p.backpack.count("rpg7")==1 and p.backpack.count("pg7vl")==2 and p.backpack.count("rpg22")==1,"The grenadier carries the RPG-7, two rounds and an RPG-22")
 # --- RPG-7 --------------------------------------------------------------------------
 key(p,KEY_4)
 check(p.launcher.active() and p.launcher.kind=="rpg7" and p.launcher.mode=="draw","4 takes the RPG-7 off the mount first")
 tick(p,3.05)
 check(p.launcher.mode=="ready" and not p.launcher.loaded(),"…after 3 s it is on the shoulder, empty")
 p.update_pose(0.016)
 check(not p.viewmodel.visible,"The rifle is slung meanwhile")
 var before: int=game.blasts.rockets.size()
 check(not p.launcher.fire() and game.blasts.rockets.size()==before,"Empty, it does not fire")
 check(p.launcher.load_round() and p.launcher.mode=="load","R: a PG-7VL from the pack")
 tick(p,3.0)
 check(p.backpack.count("pg7vl")==2,"…the round leaves the pack only once seated")
 tick(p,3.1)
 check(p.launcher.mode=="ready" and p.launcher.loaded() and p.backpack.count("pg7vl")==1,"…6 s later it is loaded, one round left in the pack")
 var mass_loaded:=p.backpack.mass()
 check(is_equal_approx(mass_loaded-Equipment.PACK_MASS,7.2+2.6+2.6+2.7),"The seated round still weighs on the man (%.1f kg)" % (mass_loaded-Equipment.PACK_MASS))
 check(p.launcher.fire(),"It fires")
 var rocket: Dictionary=game.blasts.rockets[-1]
 check(game.blasts.rockets.size()==before+1 and rocket.kind=="pg7vl","…a PG-7VL")
 check(p.launcher.mode=="ready" and not p.launcher.loaded() and p.backpack.count("rpg7")==1,"…and the launcher stays in the hands, empty")
 # Aimed through the PGO-7 the bore rises over the optical axis by its tilt.
 p.launcher.ads=1.0;p.launcher.animate()
 var axis: Vector3=-p.camera.global_basis.z
 var bore: Vector3=-p.launcher.tube.global_basis.z
 var tilt:=asin(clampf(bore.dot(p.camera.global_basis.y),-1,1))
 check(absf(tilt-LauncherRig.pgo_tilt())<0.002 and axis.dot(bore)>0.99,"At the PGO-7 the tube is tilted %.4f rad over the line of sight (%.4f)" % [tilt,LauncherRig.pgo_tilt()])
 check(p.launcher.through_scope() and not p.launcher.tube.visible,"…and the scope fills the view")
 p.launcher.ads=0.0
 # --- 5: the RPG-22 ----------------------------------------------------------------
 key(p,KEY_5)
 check(p.launcher.mode=="stow" and p.launcher.queued=="rpg22","5 puts the RPG-7 back to take the RPG-22")
 tick(p,2.5)
 check(p.launcher.kind=="rpg22" and p.launcher.mode=="draw","…then takes the RPG-22 off the mount")
 check(p.launcher.tube==p.launcher.models.get("rpg22/folded",null),"…folded")
 tick(p,2.3)
 check(p.launcher.mode=="ready" and not p.launcher.armed() and p.launcher.tube==p.launcher.models.get("rpg22/folded",null),"…in the hands after 2.2 s, still folded")
 before=game.blasts.rockets.size()
 check(not p.launcher.fire() and game.blasts.rockets.size()==before and p.launcher.notice.contains("ПОХІДНОМУ"),"Folded, it does not fire")
 check(p.launcher.arm() and p.launcher.mode=="arm","R: into the firing position")
 tick(p,3.0)
 check(not p.launcher.armed(),"…the sleeve still going out at 3 s")
 tick(p,0.8)
 var tube_uid: int=p.launcher.item_uid
 check(p.launcher.armed() and p.backpack.item(tube_uid).get("extended",false)==true and p.launcher.tube==p.launcher.models.get("rpg22",null),"…locked out at 3.6 s, the sights up")
 tick(p,2.3)
 check(p.launcher.mode=="ready","…ready after 6 s")
 check(not p.launcher.arm(),"Once armed there is nothing more to arm")
 # Back on the mount it stays drawn out.
 key(p,KEY_4)
 check(p.launcher.mode=="stow","4 puts it back on the mount")
 p.update_pose(0.016)
 tick(p,2.3)
 check(not p.launcher.active() and p.backpack.item(tube_uid).get("extended",false)==true,"…drawn out as it is: it cannot be folded")
 p.update_pose(0.016)
 var body: OperatorBody=p.world_body
 var mounted: Node3D=body.launcher_models.get("rpg22/ready",null)
 check(mounted!=null and mounted.visible and not body.launcher_models["rpg22"].visible,"On the pack it shows drawn out")
 key(p,KEY_4)
 check(p.launcher.kind=="rpg7","4 takes the first launcher, the RPG-7")
 key(p,KEY_5)
 tick(p,2.5)
 check(p.launcher.kind=="rpg22" and p.launcher.mode=="draw" and p.launcher.tube==p.launcher.models.get("rpg22",null),"5: the armed RPG-22 comes off the mount drawn out")
 tick(p,2.3)
 check(p.launcher.mode=="ready" and p.launcher.armed(),"…and is ready with no second arming")
 p.update_pose(0.016)
 var drawn: Node3D=body.launcher_models.get("rpg22/ready/hands",null)
 check(drawn!=null and drawn.visible and body.launcher_models.has("rpg7") and body.launcher_models["rpg7"].visible and not mounted.visible,"His body shows the RPG-22 in the hands, the RPG-7 back on the mount")
 before=game.blasts.rockets.size()
 check(p.launcher.fire() and game.blasts.rockets[-1].kind=="rpg22","The RPG-22 fires")
 check(p.backpack.count("rpg22")==0 and p.launcher.mode=="spent","…and the tube is thrown away")
 tick(p,1.2)
 check(not p.launcher.active(),"…the hands are free again")
 await frames(2)
 game.queue_free();await process_frame
 # --- The PKM -------------------------------------------------------------------
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("machinegunner")
 game.selected_map=TrainingRange.ID
 game.start_match()
 game.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 await frames(3)
 p=game.player
 check(p.current().id=="pkm","The machine gunner carries the PKM")
 p.position=Vector3(0,0.2,175);p.rotation=Vector3.ZERO;p.pitch=0.0
 await frames(10)
 key(p,KEY_X)
 check(not p.bipod and p.bipod_notice!="","Standing in the open the bipod has nothing to stand on")
 var free:=climb(p,8)
 p.pitch=0.0
 p.prone_requested=true
 await frames(60)
 check(p.prone,"He lies down")
 key(p,KEY_X)
 check(p.bipod,"Lying, X puts the bipod down")
 await frames(2)
 var legs: Node3D=p.viewmodel.get_node("Bipod/LegRight")
 check(absf(legs.rotation.x-0.30)<0.01,"…its legs swing down on the gun")
 for w in [p.current()]:w.magazine.rounds=100
 var lying_free:=0.0
 var braced:=climb(p,8)
 p.bipod=false;p.pitch=0.0
 lying_free=climb(p,8)
 check(braced<lying_free*0.4,"On the bipod a burst climbs a third as much (%.4f vs %.4f lying, %.4f standing)" % [braced,lying_free,free])
 key(p,KEY_X)
 check(p.bipod,"…down again")
 p.velocity=Vector3(1.5,0,0)
 p.update_bipod(0.016)
 check(not p.bipod,"Moving off folds it")
 p.velocity=Vector3.ZERO
 # The frame sight.
 var w: WeaponState=p.current()
 check(w.scope_zero==300,"The PKM's sight is on 3 (300 m)")
 var slider: Node3D=p.viewmodel.get_node("RearSightSlider")
 p.ads_weight=1.0;p.aim=true;p.update_pose(0.016)
 var low_slider: float=slider.position.y
 var low_tilt: float=p.sight_tilt
 for i in range(5):
  p.scope_adjust_time=0.0
  key(p,KEY_PAGEUP)
 check(w.scope_zero==800,"PgUp five times: 8 (800 m)")
 p.ads_weight=1.0;p.aim=true;p.update_pose(0.016)
 var expected:=FlightModel.zero_angle("pkm",PkmArt.SIGHT_HEIGHT,800.0)
 check(slider.position.y>low_slider+0.004 and absf(p.sight_tilt-expected)<0.0005 and p.sight_tilt>low_tilt,"The slider rises %.1f mm and the gun tilts %.4f rad (%.4f)" % [(slider.position.y-low_slider)*1000,p.sight_tilt,expected])
 for i in range(20):
  p.scope_adjust_time=0.0
  key(p,KEY_PAGEUP)
 check(w.scope_zero==1500,"…up to 15")
 # The feed cover lifts for a new belt.
 w.magazine.rounds=10
 check(w.reload(0),"A new box")
 w.update(0.9);p.viewmodel.animate(w,0.016)
 var cover: Node3D=p.viewmodel.get_node("FeedCover")
 check(cover.rotation.x<-1.0,"…the feed cover is up (%.2f)" % cover.rotation.x)
 w.update(20.0);p.viewmodel.animate(w,0.016)
 check(cover.rotation.x>-0.05 and w.rounds()==100,"…and shut on the new belt")
 game.queue_free();await process_frame;await process_frame
 print("player weapons: %d checks, %s" % [checks,"FAILED" if failed else "ok"])
 quit(1 if failed else 0)
