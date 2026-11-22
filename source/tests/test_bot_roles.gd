extends SceneTree
# Roles in the great assault and the quiet before it:
# - both sides field machine gunners, grenadiers with the RPG-7, riflemen
#   with RPG-22, snipers and drone pilots, each armed for the role;
# - the defenders and our dismounted squads idle (look out, stroll, sit,
#   talk) until the alarm or «По машинах!»; the gunner of our BMP waits
#   outside with the squad and climbs into the turret when they board;
# - a BMP-2 of theirs at each strongpoint, engine off, its driver and gunner
#   beside it; on the alarm they run to it, get in, start it, man the gun;
# - the marks: the painted «Z» and the tricolour on the whip on theirs, the
#   Ukrainian flag on the whip of ours and on the staff of the BM-21;
# - a grenadier brings the RPG-7 up and fires on an enemy vehicle in reach;
# - a shaped charge on a thin wall hits the man behind it, a thick wall
#   stops it.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func kits(team: Array) -> Dictionary:
 var count:={}
 for actor in team:
  if not actor.get_meta("battle_managed",false):continue
  var id: String=actor.kit_id()
  count[id]=int(count.get(id,0))+1
 return count

func run():
 seed(8812)
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("rifleman");game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 var battle: BattleMode=game.battle
 # --- Roles ---------------------------------------------------------------
 var ours:=kits(game.allies)
 var theirs:=kits(game.bots)
 check(int(ours.get("mg",0))>=2 and int(ours.get("rpg7",0))>=2 and int(ours.get("rpg22",0))>=4 and int(ours.get("sniper",0))>=2 and int(ours.get("uav",0))>=1,"Our squads have every role (%s)" % str(ours))
 check(int(theirs.get("mg",0))>=3 and int(theirs.get("rpg7",0))>=3 and int(theirs.get("sniper",0))>=3 and int(theirs.get("uav",0))>=1 and int(theirs.get("rpg22",0))>=3,"So do the defenders (%s)" % str(theirs))
 var armed:=true
 for actor in game.allies+game.bots:
  if actor.kit==null:continue
  armed=armed and actor.weapon.id==BotKit.WEAPON[actor.kit.kind]
 check(armed,"Each carries the weapon of his role (PKM, SVD, AK-74)")
 check(game.bots.size()==BattleMode.enemies(18),"Still three of them for each of ours, the vehicle crews counted (%d)" % game.bots.size())
 # --- The quiet before ------------------------------------------------------
 var idle_enemy:=0
 for actor in game.bots:if Idle.active(actor):idle_enemy+=1
 check(idle_enemy>=game.bots.size()-2,"The defenders live their quiet day (%d of %d idle)" % [idle_enemy,game.bots.size()])
 await frames(240)
 var idle_ours:=0
 var activities:={}
 for squad in battle.mech:
  for actor in squad.on_foot():
   if Idle.active(actor):idle_ours+=1;activities[actor.idle.activity]=true
 for actor in game.bots:
  if Idle.active(actor):activities[actor.idle.activity]=true
 check(idle_ours>=BmpVehicle.SEATS*battle.mech.size()-2,"Our dismounted men wait as men wait (%d idle)" % idle_ours)
 check(activities.size()>=3,"…doing different things (%s)" % str(activities.keys()))
 var moved:=0
 for actor in game.bots:
  if Idle.active(actor) and actor.velocity.length()>0.3:moved+=1
 check(moved>=1,"Some of them walk about (%d)" % moved)
 # Our gunner outside, by the vehicle.
 var lead: MechSquad=battle.mech[0]
 check(is_instance_valid(lead.gunner_out) and lead.gunner_out.vehicle==null and not lead.vehicle.gunner.manned,"The gunner of our BMP waits outside with the squad")
 check(lead.gunner_out.global_position.distance_to(lead.vehicle.global_position)<9.0,"…beside his vehicle (%.1f m)" % lead.gunner_out.global_position.distance_to(lead.vehicle.global_position))
 # --- Their vehicles ---------------------------------------------------------
 var armour: EnemyArmour=battle.armour
 check(armour!=null and armour.vehicles.size()==3,"A BMP-2 at each strongpoint (%d)" % (armour.vehicles.size() if armour else 0))
 var parked:=true
 var crews_by:=true
 for unit in armour.units:
  var v: BmpVehicle=unit.vehicle
  parked=parked and not v.running and not v.friendly and not v.gunner.manned and v.crew.is_empty()
  var center: Vector2=BattleMap.CENTERS[int(unit.sector)]
  parked=parked and Vector2(v.global_position.x,v.global_position.z).distance_to(center)<45.0
  for role in unit.crew:
   var actor: Hostile=unit.crew[role]
   crews_by=crews_by and actor.vehicle==null and actor.global_position.distance_to(v.global_position)<10.0 and Idle.active(actor)
 check(parked,"…parked by the strongpoint, engine off, nobody aboard")
 check(crews_by,"…the driver and the gunner idling beside it")
 # Marks.
 var enemy_bmp: BmpVehicle=armour.vehicles[0]
 var enemy_flag: Node=enemy_bmp.art.turret.get_node_or_null("Flag")
 check(enemy_bmp.art.root.get_node_or_null("Markings")!=null and enemy_flag!=null and enemy_flag.get_meta("bands")==VehicleMarkings.RUSSIA,"«Z» painted on their BMP, the tricolour on its whip")
 var our_flag: Node=lead.vehicle.art.turret.get_node_or_null("Flag")
 check(our_flag!=null and our_flag.get_meta("bands")==VehicleMarkings.UKRAINE and lead.vehicle.art.turret.get_node_or_null("Markings")==null,"The flag of Ukraine on the whip of ours, nothing painted")
 var grad_flag: Node=battle.battery.launchers[0].art.root.get_node_or_null("Flag") if battle.battery!=null and not battle.battery.launchers.is_empty() else null
 check(grad_flag!=null and grad_flag.get_meta("bands")==VehicleMarkings.UKRAINE,"…and on the staff of our BM-21")
 # --- «По машинах!»: the gunner climbs in -----------------------------------------
 battle.skip_field()
 await frames(5)
 var gunners:=true
 for squad in battle.mech:
  var has:=false
  for actor in squad.vehicle.crew:has=has or actor.get_meta("bmp_role","")=="gunner"
  gunners=gunners and has and squad.vehicle.gunner.manned and squad.gunner_out==null
 check(gunners,"On boarding the gunners are in their turrets")
 var still_idle:=0
 for squad in battle.mech:
  for actor in squad.members:if Idle.active(actor):still_idle+=1
 check(still_idle==0,"…and nobody of ours idles any more")
 # --- The alarm at a strongpoint: the crew man their vehicle ------------------
 var unit: Dictionary=armour.units[0]
 var v0: BmpVehicle=unit.vehicle
 for role in unit.crew:
  var actor: Hostile=unit.crew[role]
  # Close by already, for the sake of time.
  actor.global_position=armour.board_spot(v0,role)+Vector3(0.6,0,0.6)
 var alerted: Hostile=unit.crew["driver"]
 alerted.alerted=true
 var t:=0.0
 while String(unit.state)!="manned" and t<12.0:
  await physics_frame;t+=1.0/60.0
 check(String(unit.state)=="manned" and v0.crew.size()==2,"On the alarm the crew get in (%s after %.1f s)" % [String(unit.state),t])
 check(not Idle.active(unit.crew["gunner"]),"…the alarm ends the idling")
 t=0.0
 while not v0.running and t<12.0:
  await physics_frame;t+=1.0/60.0
 check(v0.running and v0.gunner.manned,"The driver starts the engine, the gunner is on the gun (%.1f s)" % t)
 # --- A grenadier and an enemy vehicle ---------------------------------------
 var target: BmpVehicle=armour.vehicles[1]
 var space: PhysicsDirectSpaceState3D=target.get_world_3d().direct_space_state
 var aim:=target.to_global(Vector3(0,1.1,0))
 var spot:=Vector3.INF
 for k in range(24):
  var dir:=Vector3.FORWARD.rotated(Vector3.UP,TAU*k/24.0)
  var p:=aim+dir*110.0
  p.y=game.district.ground_height(p)
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.6,aim,1))
  if not hit.is_empty() and BlastSystem.strike_target(hit.collider)==target:spot=p;break
 check(spot!=Vector3.INF,"A clear line to their vehicle from 110 m")
 if spot!=Vector3.INF:
  var grenadier: Hostile=null
  for actor in game.allies:
   if actor.kit!=null and actor.kit.kind=="rpg7" and not actor.dead and actor.vehicle!=null:grenadier=actor;break
  # Out of the vehicle at the spot, alone with the target.
  grenadier.vehicle.aboard.erase(grenadier);grenadier.vehicle.troops.forget(grenadier)
  grenadier.disembark(spot+Vector3.UP*0.1,spot.direction_to(aim))
  grenadier.set_meta("mech_control",false)
  for actor in game.allies+game.bots:
   if actor!=grenadier:actor.set_physics_process(false)
  grenadier.look_at(Vector3(aim.x,grenadier.global_position.y,aim.z),Vector3.UP)
  grenadier.alerted=true
  var hits_before: int=target.hull.hits
  var fired_before: int=grenadier.kit.fired
  t=0.0
  while grenadier.kit.fired==fired_before and t<14.0:
   grenadier.kit.think(1.0/60.0)
   await physics_frame;t+=1.0/60.0
  check(grenadier.kit.fired>fired_before,"The grenadier brings up the RPG-7 and fires (%.1f s, phase %s)" % [t,grenadier.kit.phase])
  check(t>3.0,"…after bringing it up and aiming, not at once (%.1f s)" % t)
  var t2:=0.0
  while target.hull.hits==hits_before and t2<3.0:
   await physics_frame;t2+=1.0/60.0
  # A grenade at 110 m with the range judged by eye may miss; it must at
  # least have gone off near the vehicle.
  var burst: Vector3=game.blasts.last_detonation
  check(target.hull.hits>hits_before or burst.distance_to(aim)<12.0,"…the grenade strikes the vehicle or bursts by it (%.1f m off, %s)" % [burst.distance_to(aim),str(target.hull.history)])
  t=0.0
  while grenadier.kit.phase!="" and t<12.0:
   await physics_frame;t+=1.0/60.0
  check(grenadier.kit.loaded or grenadier.kit.grenades==1,"He reloads from the bag (%d left, loaded %s)" % [grenadier.kit.grenades,str(grenadier.kit.loaded)])
 # --- Through a wall ----------------------------------------------------------------
 var base: Vector3=game.player.global_position+Vector3(40,0,-40)
 base.y=game.district.ground_height(base)
 for thickness in [0.4,2.6]:
  var wall:=StaticBody3D.new()
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4,3,thickness);shape.shape=box
  wall.add_child(shape);game.world_root.add_child(wall)
  wall.global_position=base+Vector3(0,1.5,0)
  var victim: Hostile=null
  for actor in game.bots:
   if not actor.dead and actor.vehicle==null and actor!=unit.crew["driver"] and actor!=unit.crew["gunner"]:victim=actor;break
  victim.global_position=base+Vector3(0,0,thickness*0.5+1.6)
  await frames(2)
  var health_before: float=victim.health
  var struck: int=game.blasts.behind_wall(base+Vector3(0,1.2,-thickness*0.5),Vector3.BACK,"pg7vl",wall)
  if thickness<1.0:check(struck>=1 and (victim.dead or victim.health<health_before),"PG-7VL through 0.4 m of wall hits the man behind it")
  else:check(struck==0,"…2.6 m of it stops the jet")
  wall.queue_free()
  base+=Vector3(12,0,0)
 print("bot roles: %d checks, %s" % [checks,"FAILED" if failed else "ok"])
 quit(1 if failed else 0)
