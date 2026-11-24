extends SceneTree

# Balance of the enemy's TOS-1A (VALIDATION, 0.33.0): the worst case for us —
# the column boarded on its start, waiting for the mortarman's order, found
# by the observer and hit by a salvo of twelve. The waits before the salvo
# are shortened (they change when it comes, not where), the rest is the game
# as played. Prints what the salvo did to the vehicles and the men.
# BALANCE_SEED=11 BALANCE_SIZE=27 godot --headless --fixed-fps 60 --path source -s tests/balance_tos.gd
var game: Node3D

func _initialize():call_deferred("run")

func run_until(condition: Callable, limit: float) -> bool:
 var until: float=game.elapsed+limit
 while game.running and game.elapsed<until:
  if condition.call():return true
  await physics_frame
 return condition.call()

func run():
 var seed_value:=int(OS.get_environment("BALANCE_SEED")) if OS.get_environment("BALANCE_SEED")!="" else 11
 var size:=int(OS.get_environment("BALANCE_SIZE")) if OS.get_environment("BALANCE_SIZE")!="" else 27
 seed(seed_value)
 EnemyTos.salt=seed_value
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("mortarman")
 game.battle_size=size;game.selected_map=BattleMap.ID;game.start_match()
 await physics_frame
 game.player.set_physics_process(false)
 var tos: EnemyTos=game.battle.tos
 tos.first_look=INF
 var waiting:=func():
  for squad in game.battle.mech:
   if squad.state!="wait":return false
  return true
 if not await run_until(waiting,400.0):print("BALANCE seed=%d size=%d: the column never boarded" % [seed_value,size]);quit(1);return
 var vehicles: Array=[]
 for squad in game.battle.mech:vehicles.append(squad.vehicle)
 var men_before:=0
 var aboard: Dictionary={}
 for actor in game.allies:
  if is_instance_valid(actor) and not actor.dead:men_before+=1;aboard[actor]=actor.vehicle!=null
 tos.first_look=0.0;tos.look_clock=0.0;tos.delay_range=Vector2(20.0,25.0);tos.ready_time=20.0
 var started: float=game.elapsed
 var reported:=func():return not tos.plan.is_empty() or tos.salvos>0
 if not await run_until(reported,120.0):print("BALANCE seed=%d size=%d: no report" % [seed_value,size]);quit(1);return
 var aim: Vector3=tos.plan.aim
 var landed:=func():return tos.vehicle.fired>=12 and game.blasts.toses.is_empty() and tos.state!="firing"
 await run_until(landed,240.0)
 # The fires and the cook-offs they start take their time.
 await run_until(func():return false,40.0)
 var bursts: Array[Vector3]=game.blasts.tos_bursts
 var destroyed:=0;var burning:=0;var immobile:=0;var sight:=0
 var closest: Array[float]=[]
 for vehicle in vehicles:
  if vehicle.destroyed:destroyed+=1
  elif vehicle.hull.burning:burning+=1
  elif vehicle.hull.immobile:immobile+=1
  if vehicle.hull.weapon_out:sight+=1
  var near:=INF
  var box: AABB=vehicle.hull.armor.frag_box
  for b in bursts:near=minf(near,VehicleArmor.box_distance(vehicle.to_local(b),box.get_center(),box.size*0.5))
  closest.append(snappedf(near,0.1))
 var men_after:=0
 var dead_aboard:=0;var dead_outside: Array[float]=[]
 for actor in aboard:
  if is_instance_valid(actor) and not actor.dead:men_after+=1;continue
  if aboard[actor]:dead_aboard+=1;continue
  var near:=INF
  if is_instance_valid(actor):
   for b in bursts:near=minf(near,actor.global_position.distance_to(b))
  dead_outside.append(snappedf(near,0.1))
 print("BALANCE dead aboard=%d outside=%s" % [dead_aboard,str(dead_outside)])
 var spread:=0.0
 for b in bursts:spread=maxf(spread,Vector2(b.x-aim.x,b.z-aim.z).length())
 print("BALANCE seed=%d size=%d vehicles=%d lost=%d (destroyed %d, burning %d) immobile=%d sight=%d men_lost=%d/%d bursts=%d furthest=%.0f closest=%s time=%.0f" % [seed_value,size,vehicles.size(),destroyed+burning,destroyed,burning,immobile,sight,men_before-men_after,men_before,bursts.size(),spread,str(closest),game.elapsed-started])
 quit(0)
