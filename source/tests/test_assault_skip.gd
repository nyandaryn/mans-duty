extends SceneTree
# The skipped start of the great assault (F6 twice): the battery's salvo
# fired off and flown down unseen — every rocket launched, every burst in the
# village — the squads boarded at once and each vehicle put at its drop point
# in the village, the doors opening, the player getting out with his squad.
# A single F6 only warns. A new start in the middle calls the skip off. The
# march alone can be skipped once the column is on its way. The mortarman's
# halted column boards and waits for his word, then its march can be skipped;
# the BMP driver finds himself at a drop of his own with his men aboard.
# Run with --fixed-fps 60.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func new_game() -> Node:
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 return game

func f6(battle: BattleMode) -> void:
 var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_F6;key.keycode=KEY_F6
 battle._input(key)

func start(game: Node, id: String, size: int) -> BattleMode:
 game.set_player_class(id);game.battle_size=size;game.selected_map=BattleMap.ID;game.start_match()
 await frames(4)
 return game.battle

# Until the black screen is gone; the frames it took.
func through(battle: BattleMode) -> int:
 for i in range(60*30):
  await physics_frame
  if not battle.skipping:return i
 return -1

func flat(a: Vector3, b: Vector3) -> float:return Vector2(a.x-b.x,a.z-b.z).length()

func in_village(p: Vector3) -> bool:return absf(p.x)<200.0 and absf(p.z)<200.0

# Every squad but `skip` getting out at its drop: dismounting or already in
# file behind its vehicle, 95…175 m from its objective, in the village.
func at_drops(battle: BattleMode, label: String, skip: MechSquad=null) -> void:
 var ok:=true
 var seen: Array=[]
 for squad in battle.mech:
  if squad==skip:continue
  var v:=squad.vehicle.global_position
  var range_m:=flat(squad.drop,battle.objective_point(squad.index))
  seen.append("%s %.0f m %.1f off" % [squad.state,range_m,flat(v,squad.drop)])
  ok=ok and squad.state in ["dismount","file"] and range_m>90.0 and range_m<180.0 and flat(v,squad.drop)<3.0 and in_village(v)
 check(ok,"%s: every squad at its drop in the village, getting out (%s)" % [label,str(seen)])
 var apart:=true
 for a in battle.mech:
  for b in battle.mech:
   if a!=b and a.vehicle.global_position.distance_to(b.vehicle.global_position)<8.0:apart=false
 check(apart,"%s: no two vehicles on one spot" % label)

func run():
 seed(2026)
 var game=await new_game()
 # --- The rifleman, the salvo still to come ------------------------------
 var battle:=await start(game,"rifleman",18)
 check(battle.prep=="barrage" and battle.can_skip(),"At the start the skip is offered")
 check(battle.prep_status().contains("F6 — ПРОПУСТИТИ ОБСТРІЛ І МАРШ ДО ВИСАДКИ"),"…named in the battle status (%s)" % battle.prep_status())
 # One press only warns; the warning runs out.
 f6(battle)
 check(battle.skip_armed>0.0 and not battle.skipping and game.squad.notice.text.contains("F6 ще раз"),"One F6: a warning (%s)" % game.squad.notice.text)
 await frames(60*5)
 check(battle.skip_armed==0.0 and not battle.skipping and battle.prep=="barrage" and not battle.battery.ordered,"…and nothing else; the warning runs out")
 var lead: MechSquad=battle.mech[0]
 var blasts_before: int=game.blasts.detonations
 f6(battle);f6(battle)
 check(battle.skipping and is_instance_valid(battle.skip_screen),"F6 twice: the black screen")
 var took:=await through(battle)
 print("skip took %d frames" % took)
 check(took>0 and took<60*8,"…for a few seconds (%d frames)" % took)
 var grads:=battle.battery
 var fired:=0
 for vehicle in grads.launchers:fired+=vehicle.fired
 check(fired==120 and game.blasts.grads.is_empty(),"Every rocket fired and down (%d fired, %d in the air)" % [fired,game.blasts.grads.size()])
 var bursts: int=game.blasts.detonations-blasts_before
 check(bursts>=110,"…the bursts in the village (%d)" % bursts)
 var still:=grads.process_mode==Node.PROCESS_MODE_DISABLED
 for vehicle in grads.launchers:still=still and vehicle.process_mode==Node.PROCESS_MODE_DISABLED and vehicle.remaining()==0
 check(still,"The battery stands still, its packages empty")
 var hidden:=true
 for body in grads.figures:hidden=hidden and not body.visible
 check(hidden,"The crews in the cabs")
 check(battle.prep=="" and battle.column_go and not is_instance_valid(battle.skip_screen),"The start is over, the column has gone, the screen is gone")
 await at_drops(battle,"Rifleman")
 var gunners:=true
 for squad in battle.mech:gunners=gunners and squad.vehicle.gunner.manned
 check(gunners,"The gunners in their turrets")
 check(not battle.can_skip() and not battle.status().contains("F6"),"Nothing left to skip (%s)" % battle.status())
 # The driver keeps to the spot he was put on: no old route to drive back on.
 var spots: Array=[]
 for squad in battle.mech:spots.append(squad.vehicle.global_position)
 var out:=-1.0
 for i in range(60*25):
  await physics_frame
  if out<0.0 and game.bmp.seat=="" and game.player.global_position.distance_to(lead.vehicle.global_position)<14.0:out=i/60.0
  if out>=0.0 and i>60*8:break
 print("player out %.1f s after the skip" % out)
 check(out>=0.0,"The player gets out with his squad by his vehicle (%.1f s)" % out)
 check(in_village(game.player.global_position) and game.player.health>0,"…in the village, unhurt")
 var afoot:=0
 for actor in lead.members:
  if not actor.dead and actor.vehicle==null and actor.global_position.distance_to(lead.vehicle.global_position)<40.0:afoot+=1
 check(afoot>=BmpVehicle.SEATS-1,"…with his men around him (%d)" % afoot)
 var stayed:=true
 var moved: Array=[]
 for k in range(battle.mech.size()):
  var squad: MechSquad=battle.mech[k]
  var goal:=battle.objective_point(squad.index)
  moved.append("%.0f→%.0f" % [flat(spots[k],goal),flat(squad.vehicle.global_position,goal)])
  stayed=stayed and flat(squad.vehicle.global_position,goal)<flat(spots[k],goal)+6.0
 check(stayed,"No vehicle drives off back the way it would have come (%s)" % str(moved))
 check("dismount" in game.radio_voice.heard,"On the radio: «Десант — до машини!» (%s)" % str(game.radio_voice.heard))
 # --- A new start in the middle of the skip ------------------------------
 battle=await start(game,"rifleman",18)
 f6(battle);f6(battle)
 await frames(3)
 var screen:=battle.skip_screen
 game.start_match()
 await frames(30)
 check(not battle.skipping and not is_instance_valid(screen) and battle.prep=="barrage" and not battle.battery.ordered,"A new start calls the skip off")
 # --- The march alone -----------------------------------------------------
 battle.skip_field()
 await frames(60)
 lead=battle.mech[0]
 check(lead.state=="march" and battle.can_skip() and battle.status().contains("F6 — ДО ВИСАДКИ"),"On the march the skip is offered (%s, %s)" % [lead.state,battle.status()])
 f6(battle);f6(battle)
 took=await through(battle)
 check(took>0 and game.blasts.grads.is_empty(),"The march skipped (%d frames)" % took)
 await at_drops(battle,"March")
 for i in range(60*25):
  await physics_frame
  if game.bmp.seat=="":break
 check(game.bmp.seat=="" and in_village(game.player.global_position),"The player out in the village")
 # --- The mortarman: the column boards and waits for his word ------------
 battle=await start(game,"mortarman",18)
 check(battle.halted and battle.awaiting and battle.can_skip() and battle.prep_status().contains("F6 — ПРОПУСТИТИ ОБСТРІЛ І ПОСАДКУ"),"The mortarman may skip the salvo and the boarding (%s)" % battle.prep_status())
 # This time the salvo is already under way: the rest of it is rushed, the
 # rockets in the air flown on unseen.
 for i in range(60*120):
  await physics_frame
  if battle.battery.in_flight()>=6:break
 var seen_before:=0
 for shot in game.blasts.grads:
  if not shot.get("quiet",false):seen_before+=1
 check(seen_before>=6 and battle.can_skip(),"Mortarman: the salvo under way (%d in the air)" % seen_before)
 f6(battle);f6(battle)
 await frames(30)
 var shown:=0
 for shot in game.blasts.grads:
  if not shot.get("quiet",false) or (is_instance_valid(shot.node) and shot.node.visible):shown+=1
 check(shown==0,"…every rocket in the air unseen now (%d shown)" % shown)
 took=await through(battle)
 var waiting:=true
 var parked:=true
 for squad in battle.mech:
  # Every living man (the mortarman's start can lose one before the salvo
  # ends, skipped or not).
  waiting=waiting and squad.state=="wait" and squad.aboard().size()>=BmpVehicle.SEATS-1 and squad.on_foot().is_empty()
  parked=parked and squad.vehicle.global_position.distance_to(BmpRoutes.parking(squad.index,game.district).origin)<15.0
 fired=0
 for vehicle in battle.battery.launchers:fired+=vehicle.fired
 check(took>0 and battle.prep=="" and not battle.column_go and waiting and parked and fired==120,"Mortarman: the salvo fired, the squads aboard, the column waiting at its parking (%d fired, took %d, prep «%s», go %s, waiting %s, parked %s)" % [fired,took,battle.prep,battle.column_go,waiting,parked])
 check(not battle.can_skip() and game.squad.notice.text.contains("колона чекає"),"…for his command (%s)" % game.squad.notice.text)
 battle.set_halt(false)
 await frames(10)
 check(battle.column_go and battle.can_skip(),"His word sends the column; the march can be skipped")
 f6(battle);f6(battle)
 took=await through(battle)
 check(took>0,"Mortarman: the march skipped")
 await at_drops(battle,"Mortarman")
 # --- The BMP driver --------------------------------------------------------
 battle=await start(game,"bmp",27)
 check(battle.can_skip() and game.bmp.seat=="driver","The driver may skip the start")
 f6(battle);f6(battle)
 took=await through(battle)
 var own: MechSquad=game.bmp.squad
 var range_own:=flat(own.drop,battle.objective_point(own.index))
 check(took>0 and game.bmp.seat=="driver" and own.state=="mounted" and own.aboard().size()==BmpVehicle.SEATS,"Driver: still at the controls, his men aboard (%s, %d aboard)" % [own.state,own.aboard().size()])
 check(in_village(own.vehicle.global_position) and range_own>90.0 and range_own<180.0 and flat(own.vehicle.global_position,own.drop)<3.0,"…his vehicle at a drop of its own (%.0f m from the objective)" % range_own)
 await at_drops(battle,"Driver",own)
 check(not battle.can_skip() and game.squad.notice.text.contains("1 — «Десант»"),"…told to dismount them himself (%s)" % game.squad.notice.text)
 print("PASS" if not failed else "FAILED"," checks=",checks)
 quit(1 if failed else 0)
