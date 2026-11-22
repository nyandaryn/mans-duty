extends SceneTree
# Direct fire (дальність прямого пострілу) against the manuals, through the
# game's own flight code:
# - each rifle's and the PKM's round, from the sight height of its model,
#   gives the direct-fire range of the chest (0.5 m) and running (1.5 m)
#   figure within 3 % (FlightModel.DIRECT_FIRE: AK-74 440 / 625, SVD
#   430 / 640, PKM 420 / 640). The range is the setting at which the round,
#   aimed at a target's lower edge, rises no higher than the target on its
#   way and comes down on the edge at that range (Soviet definition);
# - the sights the weapons are carried on: the AK-74's «П» (400 m) keeps the
#   round under 0.5 m over the line to 400 m and puts it about 0.2–0.3 m
#   high at 100 m (russianoptics.net: 22–24 cm); the PKM's 4 under 0.5 m to
#   400 m, its 6 under 1.5 m to 600 m; the M16A2's 300 m battlesight;
# - the player's shot, end to end: aimed through the sight on a setting, the
#   round comes down on the line of sight at that range (AK-74 «П» and 6,
#   M16A2 300 and 600, PKM 4 and 8);
# - bots and the BMP's coaxial gun lay the bore by the sight for the range:
#   inside the direct-fire range the round passes through the point, beyond
#   it within the soldier's range-judging error;
# - the launchers: the PG-7VL's direct-fire range on a 2 m target lies
#   between the 250 m of its Bulgarian maker and the PG-7VM's 310 m (the VL
#   is heavier), its times of flight a little longer than the PG-7V's in the
#   RPG-7 manual; the RPG-22's is 160 m.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
 else:print("  ok: ",message)
func _initialize():call_deferred("run")

# The flight of a round from the bore at `angle`, the line of sight `above`
# the bore and level: the greatest height over the line up to `zero`, and
# the height at `zero`.
func ordinate(id: String, above: float, zero: float) -> Vector2:
 var angle:=FlightModel.zero_angle(id,above,zero)
 var p:=Vector3.ZERO
 var v:=Vector3(0,sin(angle),-cos(angle))*float(Ballistics.PROFILES[id].speed)
 var best:=-1.0
 var at_zero:=0.0
 while -p.z<zero:
  var n:=FlightModel.advance(p,v,float(FlightModel.BC[id]),FlightModel.MAX_STEP)
  if -n[0].z>=zero:at_zero=lerpf(p.y,n[0].y,(zero+p.z)/(p.z-n[0].z))-above
  p=n[0];v=n[1]
  best=maxf(best,p.y-above)
 return Vector2(best,at_zero)

# Height over the line of sight at a range for a sight set on `zero`.
func height_at(id: String, above: float, zero: float, distance: float) -> float:
 var angle:=FlightModel.zero_angle(id,above,zero)
 return FlightModel.range_state(id,distance,angle).x-above

# The setting whose greatest ordinate is the target's height.
func direct_fire(id: String, above: float, target: float) -> float:
 var low:=50.0;var high:=1200.0
 for i in range(20):
  var mid:=(low+high)*0.5
  if ordinate(id,above,mid).x<target:low=mid
  else:high=mid
 return (low+high)*0.5

func rocket_ordinate(kind: String, above: float, zero: float) -> float:
 var angle:=BlastSystem.rocket_elevation(kind,zero)+above/zero
 var spec: Dictionary=BlastSystem.ROCKETS[kind]
 var r:={"kind":kind,"position":Vector3.ZERO,"velocity":Vector3(0,sin(angle),-cos(angle))*float(spec.speed),"age":0.0,"travel":0.0,"lit":-1.0}
 var best:=-1.0
 while -Vector3(r.position).z<zero and float(r.age)<12.0:
  BlastSystem.rocket_step(r,1.0/240.0)
  best=maxf(best,Vector3(r.position).y-above)
 return best

func rocket_direct_fire(kind: String, above: float) -> float:
 var low:=30.0;var high:=900.0
 for i in range(20):
  var mid:=(low+high)*0.5
  if rocket_ordinate(kind,above,mid)<2.0:low=mid
  else:high=mid
 return (low+high)*0.5

func sight_height(id: String) -> float:
 var model:=Models.weapon(id)
 var height:=float(model.get_meta("sight_height"))
 model.free()
 return height

# The player's shot through the sight on a setting: the mean of a few shots
# (the aiming spread is random), flown from the muzzle in the camera's frame;
# the height over the line of sight where it reaches the setting's range.
func shot_height(game: Node3D, setting: int, shots: int=30) -> float:
 var p: Operator=game.player
 var w: WeaponState=p.current()
 w.scope_zero=setting
 var sum_direction:=Vector3.ZERO
 var muzzle:=Vector3.ZERO
 for i in range(shots):
  p.pitch=0.0;p.recoil_velocity=Vector2.ZERO;p.gun_kick=0.0;p.recoil=0.0;p.sway=Vector2.ZERO
  p.symptom_clock=0.0;p.recoil_sequence=0;p.cooldown=0.0;p.scope_adjust_time=0.0
  p.aim=true;p.ads_weight=1.0;p.velocity=Vector3.ZERO;p.rotation=Vector3.ZERO;p.camera.rotation=Vector3.ZERO
  w.magazine.rounds=int(w.data.capacity);w.chambered=true
  if "cocked" in w:w.set("cocked",true)
  p.update_pose(0.0)
  p.camera.force_update_transform()
  var before: int=game.ballistics.projectiles.size()
  if not p.shoot() or game.ballistics.projectiles.size()!=before+1:return INF
  var bullet: Dictionary=game.ballistics.projectiles[-1]
  var frame: Transform3D=p.camera.global_transform
  muzzle=frame.affine_inverse()*Vector3(bullet.position)
  # Less the shooter's own motion (still settling on the ground here).
  sum_direction+=(frame.basis.inverse()*(Vector3(bullet.velocity)-p.get_real_velocity())).normalized()
  game.ballistics.clear()
 # The camera looks level (pitch 0): its frame differs from the world's by
 # the yaw only, gravity stays down.
 var v:=sum_direction.normalized()*float(Ballistics.PROFILES[w.id].speed)
 var pos:=muzzle
 for i in range(20000):
  var n:=FlightModel.advance(pos,v,float(FlightModel.BC[w.id]),FlightModel.MAX_STEP)
  if -n[0].z>=float(setting):return lerpf(pos.y,n[0].y,(float(setting)+pos.z)/(pos.z-n[0].z))
  pos=n[0];v=n[1]
 return INF

func start(game_class: String) -> Node3D:
 var game: Node3D=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class(game_class)
 game.selected_map=TrainingRange.ID
 game.start_match()
 game.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 for i in range(3):await physics_frame
 var p: Operator=game.player
 p.set_physics_process(false)
 p.position=Vector3(0,0.2,175);p.rotation=Vector3.ZERO;p.pitch=0.0
 return game

func run():
 seed(5150)
 # --- The rounds against the manuals ------------------------------------------------
 var table:=[]
 for id in ["ak74","svd","pkm","m16"]:
  var above:=sight_height(id)
  var reference: Array=FlightModel.DIRECT_FIRE[id]
  var chest:=direct_fire(id,above,0.5)
  var running:=direct_fire(id,above,1.5)
  table.append("%s %.0f m/s: %.0f / %.0f m (manual %.0f / %.0f)" % [id,Ballistics.PROFILES[id].speed,chest,running,reference[0],reference[1]])
  check(absf(chest/float(reference[0])-1.0)<0.03,"%s: direct fire on a chest figure %.0f m (%.0f m)" % [id,chest,reference[0]])
  check(absf(running/float(reference[1])-1.0)<0.03,"%s: direct fire on a running figure %.0f m (%.0f m)" % [id,running,reference[1]])
 for line in table:print("  ",line)
 # --- The settings the weapons are carried on ---------------------------------------
 var ak:=sight_height("ak74")
 var on_p:=ordinate("ak74",ak,400.0)
 var at100:=height_at("ak74",ak,400.0,100.0)
 check(WeaponState.new("ak74").scope_zero==400 and WeaponState.new("ak74").sight_label()=="П","The AK-74 is carried on «П» (400 m)")
 check(on_p.x<0.5 and on_p.x>0.3,"On «П» the round rises %.2f m over the line by 400 m, under a chest figure" % on_p.x)
 check(at100>0.18 and at100<0.30,"…and strikes %.2f m high at 100 m (22–24 cm in the zeroing data)" % at100)
 var pk:=PkmArt.SIGHT_HEIGHT
 check(WeaponState.new("pkm").scope_zero==400,"The PKM is carried on 4")
 check(ordinate("pkm",pk,400.0).x<0.5,"PKM on 4: %.2f m at most to 400 m, a chest figure's direct fire" % ordinate("pkm",pk,400.0).x)
 check(ordinate("pkm",pk,600.0).x<1.5,"PKM on 6: %.2f m at most to 600 m, a running figure's direct fire" % ordinate("pkm",pk,600.0).x)
 check(ordinate("pkm",pk,500.0).x>0.5,"…and 5 is already over a chest figure (%.2f m)" % ordinate("pkm",pk,500.0).x)
 var m16:=sight_height("m16")
 check(WeaponState.new("m16").scope_zero==300,"The M16A2 is carried on its 300 m battlesight")
 check(ordinate("m16",m16,300.0).x<0.18,"…on which the round rises %.2f m at most" % ordinate("m16",m16,300.0).x)
 check(WeaponState.new("svd").scope_zero==100,"The PSO-1 starts on 1")
 # The scales.
 var w:=WeaponState.new("ak74")
 for i in range(10):w.step_sight(true)
 check(w.scope_zero==1000 and not w.step_sight(true),"The AK-74's leaf ends on 10")
 for i in range(12):w.step_sight(false)
 check(w.scope_zero==100 and w.sight_label()=="1","…and starts on 1")
 w=WeaponState.new("m16")
 check(not w.step_sight(false) and w.scope_zero==300,"The M16A2's knob does not go under 300 m")
 # --- Bots: the bore laid by the sight ------------------------------------------------
 for id in ["ak74","pkm","svd"]:
  var bot:=Hostile.new()
  bot.weapon=WeaponState.new(id)
  for distance in [100.0,300.0,400.0]:
   var target:=Vector3(0,1.3,-distance)
   var line:=bot.sighted(Vector3(0,1.5,0),target,"rifleman")
   var arrive:=FlightModel.range_state(id,distance,asin(line.y)).x+1.5
   check(absf(arrive-target.y)<0.03,"Bot with %s at %.0f m: the round passes %.3f m from the point" % [id,distance,arrive-target.y])
  var target:=Vector3(0,0,-700.0)
  var line:=bot.sighted(Vector3.ZERO,target,"rifleman")
  var arrive:=FlightModel.range_state(id,700.0,asin(line.y)).x
  var low:=FlightModel.range_state(id,700.0,FlightModel.aim_angle(id,700.0*0.88)).x
  var high:=FlightModel.range_state(id,700.0,FlightModel.aim_angle(id,700.0*1.12)).x
  check(arrive>=low-0.01 and arrive<=high+0.01,"…at 700 m %.2f m off, within his range judging (%.2f…%.2f)" % [arrive,low,high])
  check(absf(asin(bot.sighted(Vector3.ZERO,target,"rifleman").y)-asin(line.y))<0.000001,"…the same judgement for the same band")
  bot.free()
 for id in ["ak74","pkm","svd","m16","pm"]:
  var worst:=0.0
  for distance in [50.0,150.0,300.0,500.0,800.0]:
   if id=="pm" and distance>150.0:continue
   worst=maxf(worst,absf(FlightModel.aim_angle(id,distance)-FlightModel.zero_angle(id,0.0,distance)))
  check(worst<0.00008,"%s: the bots' sight table agrees with the zeroing to %.3f thousandths" % [id,worst*1000.0])
 # --- The launchers -------------------------------------------------------------------
 var pg:=rocket_direct_fire("pg7vl",Rpg7Art.EYEPIECE.y)
 check(pg>=250.0 and pg<=315.0,"PG-7VL: direct fire on a 2 m target %.0f m (VMZ 250 m; PG-7VM 310 m, PG-7V 330 m)" % pg)
 var manual:={100:0.5,200:0.9,300:1.3,400:1.8,500:2.3}
 for distance in manual:
  var t:=BlastSystem.rocket_time("pg7vl",float(distance))
  check(t>=float(manual[distance])*0.98 and t<=float(manual[distance])*1.15,"PG-7VL to %d m in %.2f s (PG-7V %.1f s)" % [distance,t,manual[distance]])
 var rpg22:=rocket_direct_fire("rpg22",Rpg22Art.APERTURE.y)
 check(absf(rpg22/160.0-1.0)<0.05,"RPG-22: direct fire on a 2 m target %.0f m (160 m)" % rpg22)
 # --- The player's shot through the sight ---------------------------------------------
 var game: Node3D=await start("rifleman")
 check(game.player.current().id=="ak74" and game.player.current().scope_zero==400,"The rifleman's AK-74 is on «П»")
 for setting in [400,600]:
  var h:=shot_height(game,setting)
  check(absf(h)<0.05,"AK-74 on %s: the round comes down %.3f m from the line of sight at %d m" % ["П" if setting==400 else str(setting/100),h,setting])
 game.player.current().scope_zero=400
 var event:=InputEventKey.new();event.physical_keycode=KEY_PAGEUP;event.pressed=true
 game.player.scope_adjust_time=0.0
 game.player._unhandled_input(event)
 check(game.player.current().scope_zero==500,"PgUp: the AK-74's sight on 5")
 # The machine gun and the other side's rifle, fitted in turn on the same
 # man (one game: a second one would register the input actions again).
 game.player.weapons[0]=WeaponState.new("pkm")
 game.player.make_viewmodel()
 await process_frame
 check(game.player.current().id=="pkm" and game.player.current().scope_zero==400,"The PKM comes on 4")
 # On its bipod, the spread of the aimed burst small.
 game.player.prone=true;game.player.bipod=true
 for setting in [400,800]:
  var h:=shot_height(game,setting,120)
  check(absf(h)<0.06,"PKM on %d: the round comes down %.3f m from the line of sight at %d m" % [setting/100,h,setting])
 game.player.prone=false;game.player.bipod=false
 game.player.weapons[0]=WeaponState.new("m16")
 game.player.make_viewmodel()
 await process_frame
 for setting in [300,600]:
  var h:=shot_height(game,setting)
  check(absf(h)<0.05,"M16A2 on %d m: the round comes down %.3f m from the line of sight" % [setting,h])
 game.queue_free();await process_frame;await process_frame
 print("direct fire: %d checks, %s" % [checks,"FAILED" if failed else "ok"])
 quit(1 if failed else 0)
