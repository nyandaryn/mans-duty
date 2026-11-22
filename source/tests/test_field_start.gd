extends SceneTree
# The rifleman's start of the great assault: the enemy three to one (the menu
# names only our strength), the squads dismounted on the field by their
# BMPs, the marks over the player's squad, three allied «Grads» on the firing
# position laid by their crews one on each strongpoint, the soldier's tablet
# with the battery and the village, the salvo on the order, «По машинах!»
# on the radio, the squads and the player boarding, the column moving off.
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

func run():
 seed(4711)
 var game=await new_game()
 # The menu: our men and vehicles only.
 check(BattleMode.size_text(27)=="27 · 3 БМП" and not BattleMode.size_text(54).contains("×"),"Menu names our strength only (%s)" % BattleMode.size_text(27))
 game.selected_map=BattleMap.ID;game.battle_size=27;game.update_map_description()
 check(game.map_description.text.contains("27 бійців") and not game.map_description.text.contains("×"),"Map description names our strength only (%s)" % game.map_description.text)
 game.set_player_class("rifleman");game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 var battle: BattleMode=game.battle
 var attackers:=0
 for actor in game.allies:
  if actor.get_meta("battle_managed",false):attackers+=1
 check(attackers==18 and game.bots.size()==54,"Three enemies for each of ours: %d attackers, %d defenders" % [attackers,game.bots.size()])
 check(battle.prep=="barrage" and not battle.column_go,"The battle starts with the battery's fire, the column holds")
 var lead: MechSquad=battle.mech[0]
 check(game.bmp.seat=="" and game.bmp.squad==lead,"The player is on foot, of the first squad")
 check(game.player.global_position.distance_to(lead.vehicle.global_position)<12.0,"…by his BMP in the column's place (%.1f m)" % game.player.global_position.distance_to(lead.vehicle.global_position))
 var afoot:=true
 for squad in battle.mech:
  afoot=afoot and squad.state=="field" and squad.on_foot().size()==BmpVehicle.SEATS and squad.aboard().is_empty() and squad.vehicle.crew.size()==1 and is_instance_valid(squad.gunner_out) and squad.gunner_out.vehicle==null
 check(afoot,"Every squad is out of its vehicle, the driver inside, the gunner waiting by it")
 # The battery on its firing position.
 var grads: GradBattery=battle.battery
 check(grads!=null and grads.launchers.size()==3,"Three allied BM-21")
 var sectors: Array=[]
 var placed:=true
 for crew in grads.crews:
  sectors.append(crew.sector)
  placed=placed and crew.vehicle.global_position.distance_to(GradCommand.FIRING_AREA)<120.0 and crew.vehicle.loaded.count(true)==40
 sectors.sort()
 check(placed and sectors==[0,1,2],"…on the firing position, loaded, one strongpoint each (%s)" % str(sectors))
 await frames(4)
 check(game.drone_feed.mode=="barrage" and game.drone_feed.visible and game.drone_feed.village_frame.visible,"The tablet shows the battery and the village")
 var marked:=0
 for actor in lead.members:
  var mark:=actor.get_node_or_null("SquadMark") as Sprite3D
  if mark!=null and mark.visible and mark.no_depth_test:marked+=1
 check(marked==BmpVehicle.SEATS,"Marks over the seven men of his squad (%d)" % marked)
 var other:=battle.mech[1].members[0]
 check(other.get_node_or_null("SquadMark")==null,"…and not over the other squad")
 # Off the village grid the men walk straight to where they are sent.
 var way: PackedVector2Array=game.district.path(lead.vehicle.global_position,lead.vehicle.global_position+Vector3(12,0,5))
 check(way.size()==2,"A straight way across the field (%d points)" % way.size())
 # The crews lay; the commander orders fire when all three are ready.
 var start: float=battle.prep_time
 var laid:=-1.0
 for i in range(60*90):
  await physics_frame
  if laid<0.0 and grads.all_ready():laid=battle.prep_time
  if grads.ordered:break
 check(laid>10.0 and laid<70.0,"The crews bring the launchers into action and lay them (%.1f s)" % laid)
 var exact:=true
 for crew in grads.crews:
  var goal:=grads.aim(crew)
  var vehicle: GradVehicle=crew.vehicle
  exact=exact and absf(wrapf(goal.x-vehicle.package_bearing(),-3000,3000))<1.0 and absf(goal.y-vehicle.absolute_elevation_mils())<1.0 and not vehicle.cover_on and not vehicle.travel_lock
 check(exact,"Each laid within a thousandth on its strongpoint, cover off, package unlocked")
 var crew_in:=true
 for body in grads.figures:crew_in=crew_in and not body.visible
 check(crew_in,"The crews in the cabs before the salvo")
 check(grads.ordered and "hold" in game.radio_voice.heard and "grad_fire" in game.radio_voice.heard,"Radio: «wait», then «Grads, fire!» (%s)" % str(game.radio_voice.heard))
 # Follow the rockets down.
 var seen: Dictionary={}
 var hits: Dictionary={0:[],1:[],2:[]}
 var serial:=0
 for i in range(60*120):
  await physics_frame
  var present: Dictionary={}
  for shot in game.blasts.grads:
   if not shot.has("probe"):
    serial+=1;shot.probe=serial
    var nearest:=0
    for k in range(3):
     if Vector3(shot.origin).distance_to(grads.launchers[k].global_position)<Vector3(shot.origin).distance_to(grads.launchers[nearest].global_position):nearest=k
    seen[shot.probe]={"launcher":nearest,"at":shot.position}
   seen[shot.probe].at=shot.position
   present[shot.probe]=true
  for id in seen.keys():
   if not present.has(id):
    hits[seen[id].launcher].append(seen[id].at);seen.erase(id)
  if battle.prep=="mount":break
 var total:=0
 var close:=true
 var misses: Array=[]
 for k in range(3):
  var list: Array=hits[k]
  total+=list.size()
  if list.is_empty():close=false;continue
  var mean:=Vector3.ZERO
  for p in list:mean+=p
  mean/=list.size()
  var target: Vector3=grads.crews[k].target
  var miss:=Vector2(mean.x-target.x,mean.z-target.z).length()
  misses.append(roundi(miss))
  close=close and miss<90.0
 print("laid at %.1f s, fire ordered at %.1f s, %d rockets down, mean misses %s m" % [laid,battle.fire_at,total,str(misses)])
 check(total>=110,"The full packages land (%d of 120)" % total)
 check(game.drone_feed.relayed>=30,"The launches heard from the tablet's speaker (%d)" % game.drone_feed.relayed)
 check(close,"Each launcher's bursts centre on its strongpoint (%s m)" % str(misses))
 check(battle.prep=="mount","After the salvo the squads are sent to their vehicles")
 # The order is queued in the physics step and starts in the next frame.
 await frames(30)
 check("mount_up" in game.radio_voice.heard,"…on the radio: «По машинах!» (%s)" % str(game.radio_voice.heard))
 await frames(2)
 check(game.drone_feed.mode!="barrage","The tablet's pictures are gone")
 # The player walks up to the open doors and gets in.
 for i in range(60*6):
  await physics_frame
  if lead.vehicle.doors>0.8:break
 var door:=lead.vehicle.exit_point(1)
 door.y=game.district.ground_height(door)+0.05
 game.player.global_position=door
 await frames(2)
 check(game.bmp.troop_prompt()!="","At the open doors: «F — сісти в десант» (%s)" % game.bmp.troop_prompt())
 var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_F;key.keycode=KEY_F
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 game.bmp._input(key)
 check(game.bmp.seat=="troop" and game.player_vehicle()==lead.vehicle,"F: the player in the troop compartment")
 var went:=-1.0
 for i in range(60*60):
  await physics_frame
  if battle.prep=="":went=battle.prep_time;break
 print("column off %.1f s after «По машинах!»" % went)
 check(went>0.0 and battle.column_go and "column" in game.radio_voice.heard,"All aboard: «Колона — вперед!» (%.1f s)" % went)
 await frames(90)
 var all_in:=true
 var state: Array=[]
 for squad in battle.mech:
  all_in=all_in and squad.on_foot().is_empty() and squad.aboard().size()==BmpVehicle.SEATS and squad.vehicle.doors<0.5
  state.append("%d/%d %.2f" % [squad.aboard().size(),squad.on_foot().size(),squad.vehicle.doors])
 check(all_in,"Every man aboard, the doors shut (%s)" % str(state))
 await frames(60*20)
 check(lead.state=="march" and lead.driver.progress>20.0,"The column on the march (%s, %.0f m)" % [lead.state,lead.driver.progress])
 var hidden:=true
 for mark in battle.marks:hidden=hidden and not mark.visible
 check(hidden,"Marks hidden while he rides inside")
 # A test of the village fight skips all of it.
 game.start_match()
 battle.skip_approach()
 var at_line:=true
 for actor in battle.mech[0].on_foot():at_line=at_line and actor.global_position.length()<260.0
 check(battle.prep=="" and battle.battery==null and battle.column_go and at_line and game.player.global_position.length()<260.0,"skip_approach puts everybody at the start line in the village")
 game.queue_free();await frames(5)
 for s in [11,22,33]:await mortarman(s)
 print("PASS" if not failed else "FAILED"," checks=",checks)
 quit(1 if failed else 0)

# The mortarman's start: his crew on the firing position 0.7–1 km south of
# the village, standing still through the whole opening salvo. Rocket
# artillery keeps its targets at least 600 m from its own men; nothing of the
# salvo lands near ours, and nobody in the village can reach him.
func mortarman(s: int) -> void:
 seed(s)
 var game=await new_game()
 game.set_player_class("mortarman");game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 await frames(4)
 var battle: BattleMode=game.battle
 var spot:=battle.mortar_position()
 var helper: Hostile=game.crew.assistant
 check(battle.prep=="barrage" and game.player.global_position.distance_to(spot)<1.0 and is_instance_valid(helper) and helper.global_position.distance_to(spot)<4.0,"Seed %d: the mortarman and his assistant on the firing position" % s)
 var reach:=true
 var nearest_aim:=INF
 for i in range(3):
  var d:=Vector2(spot.x,spot.z).distance_to(BattleMap.CENTERS[i])
  nearest_aim=minf(nearest_aim,d)
  var covered:=false
  for charge in range(MortarBallistics.CHARGES.size()):
   var limits:=MortarBallistics.range_limits(charge)
   covered=covered or (d>=limits.x and d<=limits.y)
  reach=reach and covered
 check(nearest_aim>=600.0 and reach,"Seed %d: every strongpoint 600+ m away (%.0f m) and in the 2B14's range" % [s,nearest_aim])
 # Our men during the salvo: the mortar crew and the squads by the column.
 var ours: Array=[game.player,helper]
 for squad in battle.mech:ours.append_array(squad.on_foot())
 var last:={}
 var impacts: Array=[]
 var seen:=0
 var tagged:=0
 for f in range(60*150):
  await physics_frame
  if battle.prep!="barrage":break
  var now:={}
  for shot in game.blasts.grads:
   # A rocket's own tag: the dictionary changes in flight, so it is no key.
   if not shot.has("probe_id"):shot["probe_id"]=tagged;tagged+=1
   now[int(shot.probe_id)]=Vector3(shot.position)
  for shot in last:
   if not now.has(shot):impacts.append(last[shot])
  last=now
  for b in game.bots:if is_instance_valid(b) and b.combat_target==game.player and b.sees_player:seen+=1
 var closest:=INF
 for p in impacts:
  for actor in ours:
   if is_instance_valid(actor):closest=minf(closest,Vector2(p.x-actor.global_position.x,p.z-actor.global_position.z).length())
 check(battle.prep!="barrage" and impacts.size()>=100,"Seed %d: the salvo over (%d rockets came down)" % [s,impacts.size()])
 check(closest>=300.0,"Seed %d: no rocket within 300 m of our men (closest %.0f m)" % [s,closest])
 check(game.player.health>=100.0 and is_instance_valid(helper) and not helper.dead and helper.health>=100.0,"Seed %d: the mortarman and his assistant unhurt (%.0f / %.0f)" % [s,game.player.health,helper.health if is_instance_valid(helper) else -1.0])
 check(seen==0,"Seed %d: no defender ever had him in sight" % s)
 game.queue_free();await frames(5)
