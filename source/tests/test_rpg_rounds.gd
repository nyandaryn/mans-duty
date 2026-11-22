extends SceneTree
# The RPG-7's three rounds (0.32.1):
# - the TBG-7V flies to its 150 m direct-fire range, the PGO-7 hint for it
#   matches the flights, it is an item of the grenadier's pack, it loads
#   (the round shows in the muzzle, first and third person) and flies;
# - the OG-7V's fragments do not get through a BMP-2's plates nor tear its
#   track, but crack the sight head on the turret roof; they riddle a
#   BM-21's cab and set off its rockets;
# - the TBG-7V burns through the 16 mm side of a BMP (not its glacis) and
#   fills it with its blast; in a closed house it kills round a partition
#   where the OG-7V's fragments do not reach, and not the man outside;
# - the bot grenadier's bag is a mix picked by a hash, not the global RNG,
#   and he changes the round in the tube for the target.
var checks := 0
var failed := false
var game: Node3D
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int) -> void:
 for i in range(n):await physics_frame

# Stands in for a vehicle in the plain armour checks: the men inside.
class Hull extends Node3D:
 var game: Node3D
 var hull: VehicleDamage
 var inside: Array=[]
 func occupants() -> Array:return inside
 func turret_yaw() -> float:return 0.0

# Highest rise of a rocket over the line of sight on its way to `zero`.
func rocket_ordinate(kind: String, above: float, zero: float) -> float:
 var angle:=BlastSystem.rocket_elevation(kind,zero)+above/zero
 var spec: Dictionary=BlastSystem.ROCKETS[kind]
 var r:={"kind":kind,"position":Vector3.ZERO,"velocity":Vector3(0,sin(angle),-cos(angle))*float(spec.speed),"age":0.0,"travel":0.0,"lit":-1.0}
 var best:=-1.0
 while -Vector3(r.position).z<zero and float(r.age)<12.0:
  BlastSystem.rocket_step(r,1.0/240.0)
  best=maxf(best,Vector3(r.position).y-above)
 return best

func direct_fire(kind: String, above: float) -> float:
 var low:=30.0;var high:=900.0
 for i in range(20):
  var mid:=(low+high)*0.5
  if rocket_ordinate(kind,above,mid)<2.0:low=mid
  else:high=mid
 return (low+high)*0.5

# A clear patch of level ground near a point: nothing in a box of this size.
func free_spot(near: Vector3, size: Vector3) -> Vector3:
 var space:=game.get_world_3d().direct_space_state
 for k in range(40):
  var p:=near+Vector3(float(k%8)*14.0-49.0,0,float(k/8)*14.0)
  p.y=game.district.ground_height(p)
  var probe:=PhysicsShapeQueryParameters3D.new();var box:=BoxShape3D.new();box.size=size;probe.shape=box
  probe.collision_mask=1;probe.exclude=Demolition.ground(game.district)
  probe.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*(size.y*0.5+0.2))
  if not space.intersect_shape(probe,4).is_empty():continue
  var flat:=true
  for corner in [Vector3(-size.x,0,-size.z),Vector3(size.x,0,-size.z),Vector3(-size.x,0,size.z),Vector3(size.x,0,size.z)]:
   if absf(game.district.ground_height(p+corner*0.5)-p.y)>0.4:flat=false
  if flat:return p
 return near

func wall(center: Vector3, size: Vector3) -> StaticBody3D:
 var body:=StaticBody3D.new()
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box
 body.add_child(shape);game.world_root.add_child(body)
 body.global_position=center
 return body

func soldier(at: Vector3, friendly: bool=false) -> Hostile:
 var bot:=Hostile.new();bot.friendly=friendly
 game.add_child(bot);bot.setup(game,at)
 bot.set_physics_process(false);bot.set_process(false)
 return bot

func run():
 seed(5101)
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("grenadier")
 game.loadout_bag=BackpackState.new();game.loadout_bag.equipped=true
 for kind in ["rpg7","pg7vl","og7v","tbg7v"]:game.loadout_bag.add(kind)
 game.selected_map=TrainingRange.ID
 game.start_match()
 await frames(5)
 var p: Operator=game.player
 # --- The TBG-7V: flight, sight, item -----------------------------------------
 var df:=direct_fire("tbg7v",Rpg7Art.EYEPIECE.y)
 check(df>=142.0 and df<=158.0,"TBG-7V: direct fire on a 2 m target %.0f m (150 m)" % df)
 var t150:=BlastSystem.rocket_time("tbg7v",150.0)
 check(t150>1.2 and t150<1.45,"…1.2–1.45 s to 150 m (%.2f s at 100 m/s and a weak sustainer)" % t150)
 check(is_equal_approx(df,direct_fire("tbg7v",Rpg7Art.EYEPIECE.y)) and direct_fire("pg7vl",Rpg7Art.EYEPIECE.y)>295.0,"The PG-7VL's flight is as before (%.0f m)" % direct_fire("pg7vl",Rpg7Art.EYEPIECE.y))
 var eye:=Rpg7Art.EYEPIECE.y
 for row in LauncherRig.TBG7V_PGO:
  var want:=LauncherRig.elevation("tbg7v",float(row[0]),eye)
  var low:=10.0;var high:=1200.0
  for i in range(22):
   var mid:=(low+high)*0.5
   if BlastSystem.rocket_elevation("pg7vl",mid)+eye/mid<want:low=mid
   else:high=mid
  var mark:=(low+high)*0.5
  check(absf(mark-float(row[1])*100.0)<60.0,"TBG-7V at %d m: the PG-7VL's %d m — chevron «%d»" % [row[0],roundi(mark),row[1]])
 check(LauncherRig.round_hint("tbg7v").contains("100 м — «3»") and LauncherRig.round_hint("tbg7v").begins_with("ТБГ-7В") and LauncherRig.round_hint("pg7vl")=="" and LauncherRig.og7v_hint().contains("150 м — «3»"),"The HUD hints: the TBG-7V's chevrons, none for the PG-7VL")
 check(Equipment.ITEMS.has("tbg7v") and is_equal_approx(float(Equipment.ITEMS.tbg7v.mass),4.5) and "tbg7v" in PlayerClass.ITEMS.grenadier,"The TBG-7V (4.5 kg) is an item of the grenadier's pack")
 check(p.backpack.count("tbg7v")==1 and p.backpack.count("og7v")==1 and p.backpack.count("pg7vl")==1 and p.backpack.mass()-Equipment.PACK_MASS<BackpackState.MAX_PAYLOAD,"The RPG-7 and one of each round fit the pack (%.2f kg)" % (p.backpack.mass()-Equipment.PACK_MASS))
 var choices: Array=p.round_choices()
 check(choices.size()==3 and choices[2].id=="tbg7v" and choices[2].detail=="ТЕРМОБАРИЧНИЙ","The ring for R: PG-7VL, OG-7V, TBG-7V (thermobaric)")
 # Loaded: the round shows in the muzzle, in the hands and on the body.
 var l: LauncherRig=p.launcher
 check(l.equip(-1,"rpg7"),"The RPG-7 comes off the mount")
 for i in range(200):l.tick(1.0/60.0)
 check(l.mode=="ready" and l.load_round("tbg7v"),"R with the TBG-7V chosen begins the loading")
 for i in range(380):l.tick(1.0/60.0)
 check(l.loaded() and l.loaded_round()=="tbg7v" and p.backpack.count("tbg7v")==0,"Seated: the TBG-7V is in the tube")
 var tube: Node3D=l.tube
 check(tube.get_node("GrenadeTBG").visible and not tube.get_node("Grenade").visible and not tube.get_node("GrenadeOG").visible,"…the 105 mm head shows in the muzzle (first person)")
 p.world_body.update_pose()
 var held: Node3D=p.world_body.launcher_models.get("rpg7/hands")
 check(held!=null and held.get_node("GrenadeTBG").visible and not held.get_node("Grenade").visible,"…and on the body in the hands (third person)")
 var before: int=game.blasts.rockets.size()
 check(l.fire() and game.blasts.rockets.size()==before+1 and game.blasts.rockets[-1].kind=="tbg7v","It flies as a TBG-7V")
 game.blasts.clear()
 # On the mount, loaded with an OG-7V: that round shows, not a PG-7VL.
 l.cancel()
 var item: Dictionary=p.backpack.item(p.backpack.first("rpg7"))
 item["loaded"]=true;item["round"]="og7v"
 p.world_body.update_pose()
 var mounted: Node3D=p.world_body.launcher_models.get("rpg7")
 check(mounted!=null and mounted.visible and mounted.get_node("GrenadeOG").visible and not mounted.get_node("Grenade").visible,"On the mount the OG-7V shows in the muzzle (third person)")
 item["round"]="pg7vl"
 p.world_body.update_pose()
 check(mounted.get_node("Grenade").visible and not mounted.get_node("GrenadeOG").visible,"…and the PG-7VL when it is that")
 # --- The OG-7V on a BMP-2 -----------------------------------------------------
 game.set_debug_invulnerable(true)
 var spot:=free_spot(p.global_position+Vector3(0,0,-60),Vector3(5,3.5,9))
 var v:=BmpVehicle.new();game.world_root.add_child(v);v.setup(game,"7")
 v.global_transform=Transform3D(Basis.IDENTITY,spot+Vector3.UP*0.05)
 v.freeze=true
 await frames(5)
 for k in range(60):
  var side:=1.0 if k%2==0 else -1.0
  var at:=Vector3(side*randf_range(2.0,3.6),randf_range(0.6,1.8),randf_range(-3.0,3.0))
  # Over the roof, behind the turret: more than 2.5 m from the sight head.
  if k%3==0:at=Vector3(randf_range(-1.2,1.2),randf_range(2.0,2.8),randf_range(1.7,3.0))
  v.hull.blast(v.to_global(at),"og7")
 check(v.hull.penetrations==0 and not v.hull.burning,"60 OG-7V bursts round a BMP-2: no fragment through its plates (%s)" % str(v.hull.history))
 for k in range(30):v.hull.blast(v.to_global(Vector3((1.0 if k%2==0 else -1.0)*randf_range(1.8,2.4),randf_range(0.3,0.7),randf_range(-2.5,2.5))),"og7")
 check(not v.hull.immobile,"…nor do they tear its tracks (30 by the running gear)")
 check(not v.hull.weapon_out,"…bursts away from the turret leave the sight alone")
 # The sight head on the turret roof by the gun.
 var head:=v.to_global(BmpArt.TURRET+Vector3(-0.05,0.80,-0.75))
 var bursts:=0
 while not v.hull.weapon_out and bursts<20:
  v.hull.blast(head+Vector3(randf_range(-0.5,0.5),randf_range(0.3,0.7),randf_range(-0.6,0.2)),"og7");bursts+=1
 check(v.hull.weapon_out and v.hull.history.has("приціл розбито уламками"),"An OG-7V on the turret roof cracks the sight: the gun is out (%d bursts)" % bursts)
 check(v.hull.penetrations==0,"…still without a hole in the roof")
 # The whole way: a grenade at its side from 60 m does no harm through the armour.
 var aim:=v.to_global(Vector3(0,1.2,0.6))
 var origin:=aim+v.global_basis.x*60.0
 origin.y=game.district.ground_height(origin)+1.6
 var space:=game.get_world_3d().direct_space_state
 var first:=space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,aim,1))
 if first.get("collider")!=v:origin=aim-v.global_basis.x*60.0;origin.y=game.district.ground_height(origin)+1.6
 var line:=origin.direction_to(aim).rotated(origin.direction_to(aim).cross(Vector3.UP).normalized(),BlastSystem.rocket_elevation("og7v",origin.distance_to(aim)))
 var count_before: int=game.blasts.detonations
 game.blasts.launch(origin,line,p,"og7v")
 var t:=0.0
 while game.blasts.detonations==count_before and t<3.0:
  await physics_frame;t+=1.0/60.0
 check(game.blasts.detonations>count_before and game.blasts.last_detonation.distance_to(aim)<3.0,"An OG-7V fired at its side bursts on it (%.1f m off)" % game.blasts.last_detonation.distance_to(aim))
 check(v.hull.penetrations==0 and not v.hull.burning and not v.destroyed,"…and does not get through (%s)" % str(v.hull.history))
 # --- The TBG-7V on a BMP-2 -----------------------------------------------------
 var a:=VehicleArmor.bmp2()
 var side_hit:=a.resolve(Vector3(1.64,1.30,0.3),Vector3(-1,0,0),"tbg7v",VehicleArmor.penetration("tbg7v"),0.0)
 var glacis:=a.resolve(Vector3(0,1.40,-2.2),Vector3(0,-0.05,1).normalized(),"tbg7v",VehicleArmor.penetration("tbg7v"),0.0)
 var turret:=a.resolve(VehicleArmor.turret_frame(Vector3(0,2.05,-1.05),a.turret_pivot,0.0)+a.turret_pivot,Vector3(0,0,1),"tbg7v",VehicleArmor.penetration("tbg7v"),0.0)
 check(side_hit.penetrated and not glacis.penetrated and not turret.penetrated,"TBG-7V: through the 16 mm side, not the glacis (%.0f mm in line) nor the turret front (%.0f mm)" % [float(glacis.los),float(turret.los)])
 var stub:=Hull.new();stub.game=game;game.world_root.add_child(stub)
 stub.hull=VehicleDamage.new();stub.hull.setup(stub,VehicleArmor.bmp2())
 var aboard:=[soldier(spot+Vector3(30,0,0)),soldier(spot+Vector3(31,0,0))]
 stub.inside=[[aboard[0],Vector3(-0.62,1.4,1.0)],[aboard[1],Vector3(0.62,1.4,2.6)]]
 stub.hull.strike(stub.to_global(Vector3(1.64,1.30,0.3)),stub.global_basis*Vector3(-1,0,0),"tbg7v")
 check(stub.hull.penetrations==1 and stub.hull.history.has("термобаричний вибух усередині"),"A TBG-7V into its side: through, the blast inside (%s)" % str(stub.hull.history))
 check(aboard[0].health<15.0 and aboard[1].health<15.0,"…both men in the troop compartment are dead or dying (%.0f, %.0f)" % [aboard[0].health,aboard[1].health])
 # Through a real hull, the whole way, from 70 m.
 var v2:=BmpVehicle.new();game.world_root.add_child(v2);v2.setup(game,"8")
 var spot2:=free_spot(spot+Vector3(0,0,-30),Vector3(5,3.5,9))
 v2.global_transform=Transform3D(Basis.IDENTITY,spot2+Vector3.UP*0.05)
 v2.freeze=true
 await frames(5)
 aim=v2.to_global(Vector3(0,1.25,0.6))
 origin=aim+v2.global_basis.x*70.0;origin.y=game.district.ground_height(origin)+1.6
 first=space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,aim,1))
 if first.get("collider")!=v2:origin=aim-v2.global_basis.x*70.0;origin.y=game.district.ground_height(origin)+1.6
 line=origin.direction_to(aim).rotated(origin.direction_to(aim).cross(Vector3.UP).normalized(),BlastSystem.rocket_elevation("tbg7v",origin.distance_to(aim)))
 game.blasts.launch(origin,line,p,"tbg7v")
 t=0.0
 while v2.hull.hits==0 and t<3.0:
  await physics_frame;t+=1.0/60.0
 check(v2.hull.penetrations==1 and v2.hull.history.has("термобаричний вибух усередині"),"A TBG-7V fired at a BMP's side from 70 m burns through (%.2f s, %s)" % [t,str(v2.hull.history)])
 # --- The OG-7V on a BM-21 -----------------------------------------------------
 var grad:=GradVehicle.new();game.world_root.add_child(grad);grad.setup(game)
 grad.global_position=free_spot(spot+Vector3(0,0,30),Vector3(4,4,9))+Vector3.UP*0.3
 await frames(20)
 for k in range(8):grad.hull.blast(grad.to_global(Vector3((1.0 if k%2==0 else -1.0)*2.3,2.0,-1.4+randf_range(-0.5,0.5))),"og7")
 check(grad.hull.penetrations>0,"OG-7V fragments go through the BM-21's cab (%d holes)" % grad.hull.penetrations)
 var tries:=0
 while not grad.hull.burning and not grad.hull.destroyed and tries<20:
  grad.hull.blast(grad.to_global(Vector3((1.0 if tries%2==0 else -1.0)*2.0,2.3,1.25+randf_range(-1.0,1.0))),"og7");tries+=1
 check(grad.hull.burning or grad.hull.destroyed,"…and set the rockets in its package going (%d bursts, %s)" % [tries,str(grad.hull.history)])
 # --- The TBG-7V in a house ------------------------------------------------------
 var house:=free_spot(spot+Vector3(0,0,60),Vector3(10,4,8))
 var floor_y:=house.y
 # Outer walls (8 × 6 m inside), a ceiling at 2.7 m, a partition across the
 # middle with a doorway at one end.
 wall(house+Vector3(0,1.35,-3.15),Vector3(8.6,2.7,0.3))
 wall(house+Vector3(0,1.35,3.15),Vector3(8.6,2.7,0.3))
 wall(house+Vector3(-4.15,1.35,0),Vector3(0.3,2.7,6.6))
 wall(house+Vector3(4.15,1.35,0),Vector3(0.3,2.7,6.6))
 wall(house+Vector3(0,2.85,0),Vector3(8.6,0.3,6.6))
 wall(house+Vector3(0,1.35,0.5),Vector3(0.2,2.7,5.0))
 await frames(2)
 var inner:=soldier(Vector3(house.x-2.2,floor_y,house.z+0.5))
 var outer:=soldier(Vector3(house.x+6.2,floor_y,house.z+0.5))
 game.bots.append(inner);game.bots.append(outer)
 var burst:=Vector3(house.x+2.0,floor_y+1.0,house.z+0.8)
 check(game.blasts.enclosed(burst),"A point in the closed room counts as inside a house")
 check(not game.blasts.enclosed(Vector3(house.x+6.0,floor_y+1.0,house.z)),"…one outside its wall does not")
 game.blasts.detonate(burst,"og7")
 check(inner.health>=99.0 and outer.health>=99.0,"An OG-7V in the next room: the partition stops its fragments (%.0f / %.0f)" % [inner.health,outer.health])
 game.blasts.detonate(burst,"tbg")
 check(inner.dead or inner.health<40.0,"A TBG-7V there: the pressure goes round the partition (%.0f)" % inner.health)
 check(outer.health>=99.0,"…the man outside the house is not hurt (%.0f)" % outer.health)
 # --- The bot grenadier ------------------------------------------------------------
 var mixes:={}
 var grenadier: Hostile=null
 for k in range(9):
  var bot:=soldier(spot+Vector3(-40.0-k*7.0,0,k*3.0))
  seed(77);var expected:=randf()
  seed(77);bot.set_kit("rpg7");var got:=randf()
  check(expected==got,"Grenadier %d: his kit does not draw from the global RNG" % k)
  var kit: BotKit=bot.kit
  var again:=BotKit.make(bot,"rpg7")
  check(kit.rounds==again.rounds,"…the same mix for the same place")
  check(kit.loaded and kit.loaded_round=="pg7vl" and kit.grenades==3 and kit.rounds in BotKit.ROUND_MIX,"…a PG-7VL in the tube and three in the bag (%s)" % str(kit.rounds))
  mixes[str(kit.rounds)]=true
  if grenadier==null and int(kit.rounds.og7v)>=1:grenadier=bot
 check(mixes.size()>=2,"Not every grenadier carries the same (%d mixes over 9)" % mixes.size())
 var kit: BotKit=grenadier.kit
 check(kit.pick_round(["pg7vl","tbg7v"],"armour",120.0)=="pg7vl","Against armour: the PG-7VL in the tube")
 check(kit.pick_round(["og7v","tbg7v","pg7vl"],"soft",150.0)=="og7v","Against men in the open: the OG-7V")
 check(kit.pick_round(["pg7vl","tbg7v"],"armour",340.0)=="","Nothing at armour past 330 m")
 # The round in the tube changed for the target: off the back, the PG-7VL
 # out into the bag, the OG-7V in, then aimed.
 var pg_before: int=int(kit.rounds.pg7vl)
 var og_before: int=int(kit.rounds.og7v)
 kit.begin("rpg7",null,grenadier.global_position-grenadier.global_basis.z*80.0+Vector3.UP,"og7v")
 t=0.0
 while kit.phase!="aim" and t<14.0:
  kit.act(1.0/60.0);t+=1.0/60.0
 check(kit.phase=="aim" and kit.loaded_round=="og7v","He changes the round and aims (%s in the tube after %.1f s)" % [kit.loaded_round,t])
 check(t>float(BotKit.LAUNCHER.rpg7.reload)+BotKit.UNLOAD,"…which takes the unloading and the reload (%.1f s)" % t)
 check(int(kit.rounds.pg7vl)==pg_before+1 and int(kit.rounds.og7v)==og_before-1,"…the PG-7VL went back into the bag")
 check(is_instance_valid(kit.launcher_node) and kit.launcher_node.get_node("GrenadeOG").visible and not kit.launcher_node.get_node("Grenade").visible,"…and the OG-7V shows in his launcher's muzzle")
 # The enemy BMP about (ours, he is theirs): the next reload is for armour.
 kit.loaded=false;kit.loaded_round=""
 check(kit.reload_choice()=="pg7vl","With an enemy vehicle about he reloads a PG-7VL")
 kit.clear()
 game.queue_free();await process_frame
 print("%s: %d rpg rounds checks" % ["FAILED" if failed else "PASS",checks])
 quit(1 if failed else 0)
