extends SceneTree

# TOS-1A «Солнцепёк» (0.33.0): the MO.1.01.04M's firing table and spread,
# the enemy's vehicle behind the village and its whole salvo — the report,
# the drive out, the laying, twelve rockets in pairs, the warning on the
# radio, the squads boarding — the thermobaric burst on men in the open,
# lying, behind a wall and indoors, Monte-Carlo of bursts round a BMP-2,
# a BM-21 and the TOS itself, and the package going up. Run with
# --fixed-fps 60.
var checks := 0
var failed := false
var game: Node3D
var seen := 0
var bursts: Array=[]

# A vehicle for the armour's sums: no hull to hit, only its layout.
class Stub extends Node3D:
 var game: Node3D
 var rockets := false
 var cooked := 0
 func has_rockets() -> bool:return rockets
 func cook_off_rockets() -> void:cooked+=1

func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
 else:print("ok   ",message)

func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):
  await physics_frame
  watch()

func watch() -> void:
 if game.blasts.detonations!=seen:
  seen=game.blasts.detonations
  bursts.append([game.elapsed,game.blasts.last_detonation])

func run_until(condition: Callable, limit: float) -> bool:
 var until: float=game.elapsed+limit
 var started:=Time.get_ticks_msec()
 while game.running and game.elapsed<until:
  if condition.call():return true
  await physics_frame
  watch()
  if Time.get_ticks_msec()-started>600000:printerr("FAIL: run timeout");return false
 return condition.call()

func run():
 check_table()
 check_dispersion()
 check_vehicle_damage()
 seed(11)
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("mortarman")
 game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 await frames(5)
 game.player.set_physics_process(false)
 var tos: EnemyTos=game.battle.tos
 check(tos!=null and is_instance_valid(tos.vehicle),"The enemy's TOS is on the field of the great assault")
 if tos==null:quit(1);return
 check_placement(tos)
 check_safety(tos)
 await check_boarding()
 await check_salvo(tos)
 await check_destroyed(tos)
 await check_men()
 print("checks: ",checks)
 quit(1 if failed else 0)

# --- Firing table ------------------------------------------------------------
func check_table() -> void:
 check(TosBallistics.elevation_for(600.0)>0.0 and TosBallistics.elevation_for(5980.0)>0.0,"The table covers 600–6000 m")
 check(TosBallistics.elevation_for(6200.0)<0.0,"Nothing past 6 km")
 check(absf(TosBallistics.max_range()-6000.0)<60.0,"Maximum range about 6000 m (%.0f)" % TosBallistics.max_range())
 var time:=TosBallistics.time_for(4500.0)
 check(time>18.0 and time<26.0,"About 20 s to 4.5 km (%.1f s)" % time)
 # A target 120 m below the launcher wants less elevation than a level one.
 var level:=TosBallistics.elevation_to(4000.0,0.0)
 var below:=TosBallistics.elevation_to(4000.0,120.0)
 check(below<level and level>0.0,"The computer takes the height of the target (%.0f vs %.0f mils)" % [below,level])
 check(float(TosBallistics.simulate(TosBallistics.elevation_for(3000.0)).range)-3000.0<5.0,"Table and flight agree at 3 km")

# Probable spread of 200 rockets at 4.5 and 6 km.
func check_dispersion() -> void:
 seed(7)
 for distance in [4500.0,5900.0]:
  var elevation:=TosBallistics.elevation_for(distance)
  var ranges: Array[float]=[];var sides: Array[float]=[]
  for i in range(200):
   var shot:=TosBallistics.spread_state(Vector3.ZERO,0,elevation)
   var last: Vector3=shot.position
   while float(shot.age)<120.0:
    last=shot.position
    TosBallistics.advance(shot,1.0/60.0 if float(shot.age)<2.0 else 0.05)
    if Vector3(shot.position).y<0.0 and Vector3(shot.velocity).y<0.0:break
   var p: Vector3=shot.position
   ranges.append(-p.z);sides.append(p.x)
  var spread_range:=deviation(ranges)*4.0
  var spread_side:=deviation(sides)*4.0
  print("dispersion %.0f m: 4σ range %.0f, 4σ deflection %.0f" % [distance,spread_range,spread_side])
  if distance<5000.0:
   check(spread_range>250.0 and spread_range<380.0 and spread_side>110.0 and spread_side<190.0,"Ellipse at 4.5 km about 300 × 150 m (%.0f × %.0f)" % [spread_range,spread_side])
  else:
   check(spread_range>280.0 and spread_range<450.0 and spread_side>150.0 and spread_side<250.0,"Ellipse at 6 km about 330 × 190 m (%.0f × %.0f)" % [spread_range,spread_side])

func deviation(values: Array[float]) -> float:
 var mean:=0.0
 for v in values:mean+=v
 mean/=values.size()
 var sum:=0.0
 for v in values:sum+=(v-mean)*(v-mean)
 return sqrt(sum/values.size())

# --- Bursts round vehicles ---------------------------------------------------
# Fractions of 200 bursts at a distance from the side of the hull: out of
# action (immobile, burning or destroyed), the sight broken, fire.
func bursts_round(layout: VehicleArmor, distance: float, rockets: bool) -> Dictionary:
 var out:=0;var sight:=0;var fire:=0;var cooked:=0
 var host:=Node3D.new();root.add_child(host)
 for i in range(200):
  var stub:=Stub.new();stub.game=host;stub.rockets=rockets
  host.add_child(stub)
  var hull:=VehicleDamage.new();hull.armor=layout;hull.vehicle=stub
  var box:=layout.frag_box
  var side:=1.0 if i%2==0 else -1.0
  var z:=box.position.z+randf()*box.size.z
  var at:=Vector3(side*(box.end.x+distance) if side>0 else box.position.x-distance,box.position.y+box.size.y*0.5,z)
  hull.thermobaric_outside(stub.to_global(at))
  if hull.out_of_action():out+=1
  if hull.weapon_out:sight+=1
  if hull.burning:fire+=1
  if stub.cooked>0:cooked+=1
  if is_instance_valid(hull.flames):hull.flames.free()
  stub.free()
 host.free()
 return {"out":out/200.0,"sight":sight/200.0,"fire":fire/200.0,"cooked":cooked/200.0}

func check_vehicle_damage() -> void:
 seed(5)
 BlastEffect.prepare_textures()
 var bmp:={}
 for d in [2.0,6.0,12.0,20.0]:
  bmp[d]=bursts_round(VehicleArmor.bmp2(),d,false)
  print("BMP-2 at %.0f m: out %.2f sight %.2f fire %.2f" % [d,bmp[d].out,bmp[d].sight,bmp[d].fire])
 check(bmp[2.0].out>=0.95 and bmp[2.0].fire>0.5,"A burst 2 m from a BMP-2 puts it out of action (%.2f), sets it on fire often (%.2f)" % [bmp[2.0].out,bmp[2.0].fire])
 check(bmp[6.0].out>0.3 and bmp[6.0].out<0.65 and bmp[6.0].sight>0.65,"At 6 m: track or fire about half the time (%.2f), the sight mostly broken (%.2f)" % [bmp[6.0].out,bmp[6.0].sight])
 check(bmp[12.0].out<0.05 and bmp[12.0].sight>0.15 and bmp[12.0].sight<0.45,"At 12 m: the vehicle keeps going (%.2f), the sight now and then (%.2f)" % [bmp[12.0].out,bmp[12.0].sight])
 check(bmp[20.0].out==0.0 and bmp[20.0].sight==0.0,"At 20 m: nothing")
 var grad:=bursts_round(VehicleArmor.bm21(),10.0,true)
 print("BM-21 at 10 m: out %.2f fire %.2f package %.2f" % [grad.out,grad.fire,grad.cooked])
 check(grad.out>=0.95 and grad.cooked>0.2 and grad.cooked<0.5,"A BM-21 10 m off: the cab crushed (%.2f), the package catches about a third of the time (%.2f)" % [grad.out,grad.cooked])
 var tos_close:=bursts_round(VehicleArmor.t72_tos(),1.5,true)
 var tos_far:=bursts_round(VehicleArmor.t72_tos(),6.0,true)
 print("TOS at 1.5 m: out %.2f sight %.2f package %.2f; at 6 m: out %.2f sight %.2f" % [tos_close.out,tos_close.sight,tos_close.cooked,tos_far.out,tos_far.sight])
 check(tos_close.out>0.25 and tos_close.out<0.6 and tos_close.cooked<0.2,"The TOS's T-72 hull: a close burst takes a track now and then (%.2f), seldom the package (%.2f)" % [tos_close.out,tos_close.cooked])
 check(tos_far.out==0.0 and tos_far.sight<0.15,"…and one 6 m off hardly anything (%.2f, sight %.2f)" % [tos_far.out,tos_far.sight])

# --- The enemy's vehicle -----------------------------------------------------
func check_placement(tos: EnemyTos) -> void:
 var hide:=Vector2(tos.hide.x,tos.hide.z)
 var north:=BattleMap.north()
 check(hide.length()>2900.0 and hide.length()<3700.0 and hide.normalized().dot(north)>0.9,"It waits 3–3.6 km north of the village (%.0f m)" % hide.length())
 var to_fire:=tos.hide.distance_to(tos.fire_point)
 check(to_fire>120.0 and to_fire<340.0,"Its firing position 150–300 m ahead of the tree line (%.0f m)" % to_fire)
 var park:=BmpRoutes.flat(BmpRoutes.PARK_ROAD,game.district)
 check(tos.reachable(park),"The column's start is within its range (%.0f m)" % Vector2(park.x-tos.fire_point.x,park.z-tos.fire_point.z).length())
 check(tos.vehicle.remaining()==24 and tos.vehicle.art.caps.instance_count==24,"A full package of 24")

func check_safety(tos: EnemyTos) -> void:
 check(not tos.safe(game.battle.center(1)),"No salvo on a strongpoint of its own")
 var near: Vector3=game.battle.center(0)+Vector3(0,0,380)
 check(not tos.safe(near),"Nor 380 m from one")
 check(tos.safe(BmpRoutes.flat(BmpRoutes.PARK_ROAD,game.district)),"The column's start is fair game")

# The squads by their vehicles at the start take the warning and climb in.
func check_boarding() -> void:
 await frames(60)
 var squads: Array=[]
 for squad in game.battle.mech:
  if squad.state=="field":squads.append(squad)
 check(not squads.is_empty(),"Squads stand by their vehicles at the start (%d)" % squads.size())
 if squads.is_empty():return
 game.battle.incoming_salvo(squads[0].vehicle.global_position,22.0)
 var boarded:=func():
  for squad in squads:
   if not squad.on_foot().is_empty():return false
  return true
 var done: bool=await run_until(boarded,20.0)
 check(done,"Warned, they are all aboard within 20 s")

# A whole salvo with the waits shortened: the column waits for the mortar
# man's order on its start, the TOS's observer finds it standing.
func check_salvo(tos: EnemyTos) -> void:
 tos.first_look=0.0;tos.delay_range=Vector2(20.0,25.0);tos.ready_time=20.0
 tos.look_clock=0.0
 var reported:=func():return not tos.plan.is_empty()
 check(await run_until(reported,120.0),"The observer reports the column standing still")
 if tos.plan.is_empty():return
 var aim: Vector3=tos.plan.aim
 var nearest:=INF
 for squad in game.battle.mech:nearest=minf(nearest,squad.vehicle.global_position.distance_to(aim))
 check(nearest<90.0,"The report is on the column (%.0f m from a vehicle)" % nearest)
 check(tos.plan.kind=="group","…as a group of vehicles and men")
 var firing:=func():return tos.state=="firing"
 var fired: bool=await run_until(firing,180.0)
 check(fired,"It drives out, comes into action and fires")
 if not fired:
  print("TOS events: ",tos.events," state ",tos.state," at ",tos.vehicle.global_position," moving ",tos.vehicle.moving()," speed ",tos.vehicle.speed," jacks ",tos.vehicle.jacks," yaw ",tos.vehicle.platform_yaw,"/",tos.vehicle.want_yaw," elev ",tos.vehicle.elevation,"/",tos.vehicle.want_elevation)
  return
 var launched_at: float=game.elapsed
 var laid_after: float=tos.salvo_started-tos.arrived_at
 check(laid_after>=tos.ready_time-0.5,"Not before its readiness time after the stop (%.0f s)" % laid_after)
 var twelve:=func():return tos.vehicle.fired>=12
 await run_until(twelve,8.0)
 var span: float=game.elapsed-launched_at
 check(tos.vehicle.fired==12 and span<3.6,"Twelve rockets in pairs within 3.5 s (%d in %.1f s)" % [tos.vehicle.fired,span])
 check("tos_launch" in game.radio_voice.heard or game.radio_voice.queue.has("tos_launch") or game.radio_voice.current=="tos_launch","The launch is called on the radio")
 for squad in game.battle.mech:
  if squad.state=="wait":check(not squad.vehicle.doors_wanted,"A boarded squad shuts its doors (%s)" % squad.name)
 var first:=bursts.size()
 var landed:=func():return game.blasts.toses.is_empty() and tos.vehicle.fired>=12
 await run_until(landed,60.0)
 var hits: Array=bursts.slice(first)
 check(hits.size()>=12,"All twelve came down (%d bursts)" % hits.size())
 if hits.is_empty():return
 var delay: float=float(hits[0][0])-launched_at
 check(delay>=15.0,"The first burst comes %.0f s after the warning (≥15)" % delay)
 var mean:=Vector3.ZERO
 for h in hits.slice(0,12):mean+=h[1]
 mean/=mini(12,hits.size())
 check(Vector2(mean.x-aim.x,mean.z-aim.z).length()<120.0,"The salvo is centred on the aim point (%.0f m off)" % Vector2(mean.x-aim.x,mean.z-aim.z).length())
 var back:=func():return tos.state=="hidden" or tos.state=="spent"
 check(await run_until(back,90.0),"It drives back into cover")
 var located:=func():return tos.located!=Vector3.INF
 check(await run_until(located,70.0),"Our radio intelligence fixes the launch")
 if tos.located!=Vector3.INF:check(tos.located.distance_to(tos.fire_point)<450.0,"…within a few hundred metres (%.0f m)" % tos.located.distance_to(tos.fire_point))
 var lost:=0
 for squad in game.battle.mech:
  if squad.vehicle.destroyed or squad.vehicle.hull.burning:lost+=1
 print("salvo on the column: vehicles lost ",lost," of ",game.battle.mech.size())

# Destroyed in its tree line: the package goes up and it fires no more.
func check_destroyed(tos: EnemyTos) -> void:
 var before: int=game.blasts.detonations
 var vehicle: TosVehicle=tos.vehicle
 vehicle.cook_off_rockets()
 var left:=vehicle.remaining()
 await frames(240)
 check(vehicle.remaining()<left and vehicle.remaining()>0,"Rockets in the package go off one by one (%d → %d)" % [left,vehicle.remaining()])
 vehicle.hull.explode()
 await frames(5)
 check(vehicle.destroyed and game.blasts.detonations>before,"Then the package goes up")
 var fired: int=vehicle.fired
 tos.plan={"aim":BmpRoutes.flat(BmpRoutes.PARK_ROAD,game.district),"kind":"group","reported":tos.clock,"fire_at":tos.clock}
 await frames(120)
 check(tos.state=="dead" and vehicle.fired==fired and not vehicle.moving(),"A destroyed TOS gives no second salvo")

# --- Men ---------------------------------------------------------------------
# Defenders' figures taken to an open field and frozen there: standing at
# 15 and 35 m, lying at 15 m; one in a house with the burst outside its wall.
func soldier(at: Vector3, prone: bool) -> Hostile:
 var actor: Hostile=null
 for bot in game.bots:
  if is_instance_valid(bot) and not bot.dead and bot.vehicle==null and not bot.get_meta("tos_used",false):actor=bot;break
 actor.set_meta("tos_used",true)
 actor.set_physics_process(false)
 actor.global_position=Vector3(at.x,AvdiivkaData.shared().height(at.x,at.z)+0.05,at.z)
 actor.velocity=Vector3.ZERO
 actor.health=100.0
 actor.stance=0.0;actor.tactical_prone=1.0 if prone else 0.0
 return actor

func check_men() -> void:
 var field:=Vector3(700,0,1300)
 var burst:=Vector3(field.x,AvdiivkaData.shared().height(field.x,field.z)+0.2,field.z)
 var close:=soldier(field+Vector3(15,0,0),false)
 var far:=soldier(field+Vector3(-35,0,0),false)
 var lying:=soldier(field+Vector3(0,0,15),true)
 var wounded:=soldier(field+Vector3(0,0,-27),false)
 await frames(2)
 game.blasts.detonate(burst,"tos")
 await frames(2)
 check(close.dead,"Standing in the open 15 m away: killed")
 check(lying.dead,"Lying 15 m away: killed too — the wave runs along the ground")
 check(not far.dead and far.health<100.0,"35 m away: alive, hurt (%.0f)" % far.health)
 check(not wounded.dead and wounded.health<85.0,"27 m away: wounded (%.0f)" % wounded.health)
 # In a house: the burst against the outside of its wall.
 var houses: Array=Demolition.houses(game)
 var inside: Hostile=null
 var actor:=soldier(field,false)
 for house in houses:
  if house.down:continue
  var center: Vector3=house.center
  actor.global_position=Vector3(center.x,game.district.ground_height(center)+0.05,center.z)
  if not game.blasts.enclosed(actor.global_position+Vector3.UP*0.2):continue
  inside=actor
  var outward:=Basis(Vector3.UP,float(house.yaw))*Vector3(float(house.half.x)+1.0,0,0)
  var at: Vector3=center+outward
  at.y=game.district.ground_height(at)+0.3
  game.blasts.detonate(at,"tos")
  break
 await frames(2)
 check(inside!=null and inside.dead,"Indoors, the burst outside the wall: killed")
