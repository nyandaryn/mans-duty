extends SceneTree

# BM-21 «Grad» class: firing tables, the vehicle in Jolt physics, the drill
# from travel to action, laying through the sight, a full salvo at a
# strongpoint and the observer's report. Run with --fixed-fps 60.
var checks := 0
var failed := false
var bursts: Array[Vector3]=[]
var seen := 0
var game: Node3D

func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
 else:print("ok   ",message)

func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):
  await physics_frame
  if game.blasts.detonations!=seen:
   seen=game.blasts.detonations
   bursts.append(game.blasts.last_detonation)

func place(vehicle: GradVehicle, x: float, z: float, heading_degrees: float) -> void:
 var data:=AvdiivkaData.shared()
 var spot:=Vector3(x,data.height(x,z)+0.3,z)
 var h:=deg_to_rad(heading_degrees)
 vehicle.release_parking()
 vehicle.linear_velocity=Vector3.ZERO;vehicle.angular_velocity=Vector3.ZERO
 vehicle.global_transform=Transform3D(Basis(Vector3.UP,-h),spot)
 game.district.operation_area.stream(spot,40)

func run():
 seed(52210)
 # --- Firing tables -------------------------------------------------------
 var large: float=GradBallistics.max_range(0)
 check(absf(large-GradBallistics.RING_SPAN[0].y)<400,"Large brake ring tops out near 11.7 km (%.0f m)" % large)
 var bare: float=GradBallistics.max_range(2)
 check(absf(bare-20100)<300,"Rocket without rings reaches about 20.1 km (%.0f m)" % bare)
 var e54: float=GradBallistics.elevation_for(0,5400)
 check(e54>100 and e54<200 and absf(GradBallistics.range_for(0,e54)-5400)<1,"Table inverts 5.4 km to a sight setting (%.1f)" % e54)
 var rows: Array=GradBallistics.firing_rows(0)
 check(rows.size()>40 and rows[0].elevation<rows[-1].elevation and rows[0].time<rows[-1].time,"Printed table for the large ring grows in setting and time")

 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.selected_map="training"
 game.set_player_class("grad")
 check(game.player_class=="grad" and game.selected_map==BattleMap.ID,"Choosing the BM-21 selects the great assault")
 game.battle_size=12
 game.start_match()
 for actor in game.allies+game.bots:actor.set_physics_process(false)
 game.squad.set_physics_process(false)
 var grad: GradCommand=game.grad
 var vehicle: GradVehicle=grad.vehicle
 check(grad.active() and is_instance_valid(vehicle),"The launcher stands at its waiting position")
 check(Vector2(vehicle.global_position.x-GradCommand.START.x,vehicle.global_position.z-GradCommand.START.z).length()<3,"Vehicle spawned at the tree line south-west of the battle")
 check(grad.strongpoints.size()==9,"Nine strongpoints tracked")
 var garrisoned:=0
 for item in grad.strongpoints:garrisoned+=item.garrison.size()
 check(garrisoned==game.bots.size(),"Every defender belongs to a strongpoint (%d/%d)" % [garrisoned,game.bots.size()])
 check(game.battle.awaiting and game.battle.halted,"The assault waits for the commander's order")
 check(vehicle.remaining()==40 and vehicle.cover_on and vehicle.travel_lock and not vehicle.springs_locked,"Loaded, covered and locked for the march")
 check(game.player.global_position.distance_to(vehicle.global_position)<6,"Commander stands next to the vehicle")
 var to_cab: Vector3=(vehicle.global_position-game.player.global_position)*Vector3(1,0,1)
 var facing: Vector3=-game.player.global_basis.z*Vector3(1,0,1)
 check(facing.normalized().dot(to_cab.normalized())>0.5,"…and faces it")
 await frames(180)
 check(vehicle.linear_velocity.length()<0.25,"Vehicle at rest on the ground (%.2f m/s)" % vehicle.linear_velocity.length())
 check(vehicle.global_basis.y.dot(Vector3.UP)>0.97,"Vehicle stands upright")
 var ground:=AvdiivkaData.shared().height(vehicle.global_position.x,vehicle.global_position.z)
 check(absf(vehicle.global_position.y-ground)<1.2,"Wheels on the relief (body %.2f m above the ground)" % (vehicle.global_position.y-ground))

 # --- Seats ---------------------------------------------------------------
 game.player.global_position=vehicle.to_global(Vector3(-1.6,0.2,-1.35))
 var station:=grad.nearest_station()
 check(station.get("id","")=="driver","F at the driver's door offers the cab")
 grad.enter("driver")
 check(grad.seat=="driver" and not game.player.is_physics_processing() and game.player.collision_layer==0,"Driver seated, the operator body parked")
 check(vehicle.seat_camera.current,"View from the driver's seat")
 grad.set_process(false)

 # --- Engine and march ----------------------------------------------------
 vehicle.begin_crank()
 await frames(30)
 check(not vehicle.running,"Starter without ignition does nothing")
 vehicle.starter=false
 vehicle.toggle_ignition()
 vehicle.begin_crank()
 await frames(120)
 vehicle.starter=false
 check(vehicle.running and vehicle.rpm()>500 and vehicle.rpm()<800,"Engine starts and idles (%.0f rpm)" % vehicle.rpm())
 vehicle.shift(1)
 check(vehicle.gear==GradVehicle.NEUTRAL,"Gears do not engage without the clutch")
 vehicle.clutch_pedal=1.0
 vehicle.shift(1)
 check(vehicle.gear==GradVehicle.NEUTRAL+1,"First gear with the clutch down")
 vehicle.toggle_handbrake()
 vehicle.throttle=0.35
 for i in range(90):
  vehicle.clutch_pedal=1.0-i/90.0
  await frames(1)
 vehicle.throttle=0.6
 await frames(360)
 check(vehicle.rpm()<GradVehicle.MAX_RPM+300,"Governor holds the engine near 3200 rpm (%.0f)" % vehicle.rpm())
 check(vehicle.running,"Engine did not stall on a gentle start")
 check(vehicle.speed()>1.5 and vehicle.speed()<4.0,"Vehicle drives off in first gear at walking pace (%.1f m/s)" % vehicle.speed())
 var travelled:=Vector2(vehicle.global_position.x-GradCommand.START.x,vehicle.global_position.z-GradCommand.START.z).length()
 check(travelled>5,"Vehicle covered ground (%.1f m)" % travelled)
 vehicle.throttle=0;vehicle.clutch_pedal=1;vehicle.brake_pedal=1
 await frames(240)
 check(absf(vehicle.speed())<0.3,"Service brakes stop the vehicle")
 vehicle.shift(-1)
 vehicle.toggle_handbrake()
 vehicle.brake_pedal=0
 check(vehicle.gear==GradVehicle.NEUTRAL and vehicle.handbrake,"Neutral and parking brake")

 # --- Firing position ----------------------------------------------------
 var target: Dictionary=grad.strongpoints[1]
 var aim: Vector3=target.point
 var fp:=GradCommand.FIRING_AREA
 var bearing:=GradBallistics.bearing(Vector3(aim.x-fp.x,0,aim.z-fp.z))
 # Broadside to the target, launcher to the left: clear of the cab zone.
 place(vehicle,fp.x,fp.z,bearing*0.06+75.0)
 await frames(150)
 check(vehicle.linear_velocity.length()<0.3,"Vehicle settled at the firing position")
 check(vehicle.is_parked(),"Hand brake holds the parked vehicle still")
 vehicle.toggle_power_takeoff()
 check(vehicle.power_takeoff,"Power take-off engaged in neutral with the clutch down")
 vehicle.clutch_pedal=0
 vehicle.hand_throttle=0.35
 await frames(120)
 check(vehicle.drive_power()>0.5,"Generator drives the laying motors (%.0f rpm)" % vehicle.rpm())
 check(vehicle.toggle_springs() and vehicle.springs_locked,"Springs of the rear axles locked out")
 vehicle.set_cover(false);vehicle.toggle_lock();vehicle.set_bracket(true);vehicle.toggle_shields()
 await frames(60)
 var ready:=true
 for item in grad.checklist().slice(0,-1):
  if not item[1]:ready=false;printerr("  not ready: ",item[0])
 check(ready,"Travel-to-action checklist complete")

 # --- Firing data and laying ---------------------------------------------
 var data:=grad.firing_data(aim)
 var distance: float=data.distance
 check(distance>5000 and distance<6200,"Target is %.0f m from the firing position" % distance)
 check(data.relative<-40 and data.relative>-102,"Target in the left sector (%.0f°)" % data.relative)
 vehicle.deflection=fposmod(float(data.bearing)-GradVehicle.BOUSSOLE_CORRECTION+3000.0,6000.0)
 vehicle.sight_setting=snappedf(GradBallistics.elevation_for(0,distance),0.5)
 vehicle.level_setting=3000.0+roundf(data.site)
 # The gunner drives the package until the needle and the bubble stand at
 # their indices.
 for i in range(8):
  var off:=wrapf(vehicle.sight_bearing()-GradVehicle.BOUSSOLE_CORRECTION,-3000.0,3000.0)
  vehicle.azimuth-=off*0.06
  vehicle.elevation-=vehicle.bubble_mils()*0.06
  vehicle.apply_launcher()
 check(absf(wrapf(vehicle.package_bearing()-data.bearing,-3000,3000))<1.0,"Boussole laying puts the package on the target bearing")
 # The tablet computes the same settings by itself and sees the package laid.
 grad.targets.append({"name":"Ц-А","point":aim});grad.selected_target=0
 var auto:=grad.solution(grad.targets[0])
 check(absf(wrapf(auto.deflection-vehicle.deflection,-3000,3000))<0.5 and absf(auto.sight-vehicle.sight_setting)<0.3 and absf(auto.level-vehicle.level_setting)<0.5,"Tablet auto-computes deflection %s, sight %s, level %s" % [GradBallistics.mils_text(auto.deflection),GradHud.sight_text(auto.sight),GradBallistics.mils_text(auto.level)])
 check(auto.in_sector and auto.time>10.0 and auto.time<40.0 and absf(wrapf(auto.heading_left-auto.heading,-180,180))<25.0,"…the sector, the flight time (%.0f s) and the vehicle heading (%.0f° vs %.0f°)" % [auto.time,auto.heading_left,auto.heading])
 var auto_text: String=grad.hud.tablet.solution_lines(grad.targets[0])
 check("+ Пакет на цілі" in auto_text and "× " not in auto_text,"Tablet: every setting matches, package on the target")
 vehicle.sight_setting+=10.0
 check("× Приціл" in grad.hud.tablet.solution_lines(grad.targets[0]),"Tablet flags a wrong sight")
 vehicle.sight_setting-=10.0
 grad.targets.clear();grad.selected_target=-1
 var wanted: float=vehicle.sight_setting+float(data.site)
 check(absf(vehicle.absolute_elevation_mils()-wanted)<1.0,"Level bubble centred at sight + angle of site")
 check(not vehicle.in_cab_zone(),"Package outside the cab zone")

 # The electric drive moves the package in real time and stops at the limits.
 var before:=vehicle.azimuth
 vehicle.traverse_input=1.0
 await frames(60)
 vehicle.traverse_input=0.0
 var moved:=vehicle.azimuth-before
 check(moved>0.3 and moved<7.5,"Electric traverse ramps up under the handwheel (%.2f° in 1 s)" % moved)
 for i in range(8):
  var off:=wrapf(vehicle.sight_bearing()-GradVehicle.BOUSSOLE_CORRECTION,-3000.0,3000.0)
  vehicle.azimuth-=off*0.06
  vehicle.elevation-=vehicle.bubble_mils()*0.06
  vehicle.apply_launcher()

 # --- Salvo ----------------------------------------------------------------
 var laid:=vehicle.package_bearing()
 await frames(600)
 check(absf(vehicle.package_bearing()-laid)<0.5,"Laying holds while the vehicle stands on the hand brake")
 grad.enter("commander")
 grad.set_process(false)
 vehicle.set_lever(true);await frames(2);vehicle.set_lever(false)
 check(vehicle.fired==0,"No launch with the panel switched off")
 vehicle.toggle_battery();vehicle.test_lamp();vehicle.set_mode(1)
 vehicle.set_lever(true);await frames(2);vehicle.set_lever(false)
 check(vehicle.fired==0,"No launch before the programme is wound")
 vehicle.wind_program()
 bursts.clear();seen=game.blasts.detonations
 vehicle.set_lever(true)
 await frames(60*6)
 vehicle.set_lever(false)
 var partial:=vehicle.fired
 check(partial>=10 and partial<=13,"Automatic fire: a rocket every half second while the lever is held (%d in 6 s)" % partial)
 await frames(60)
 check(vehicle.fired==partial,"Releasing the lever stops the series")
 vehicle.set_lever(true)
 await frames(60*16)
 vehicle.set_lever(false)
 check(vehicle.fired==40 and vehicle.remaining()==0,"Full salvo of 40 rockets")
 check(vehicle.global_basis.y.dot(Vector3.UP)>0.95,"Launcher stays on its wheels through the salvo")
 grad.set_process(true)
 await frames(60*26)
 check(bursts.size()>=36,"Rockets burst at the target area (%d)" % bursts.size())
 var near:=0
 var mean:=Vector3.ZERO
 for p in bursts:
  mean+=p
  if Vector2(p.x-aim.x,p.z-aim.z).length()<150:near+=1
 mean/=maxi(1,bursts.size())
 var origin:=vehicle.global_position
 var line:=Vector2(aim.x-origin.x,aim.z-origin.z).normalized()
 var spread_along:=0.0;var spread_across:=0.0
 for p in bursts:
  var m:=Vector2(p.x-mean.x,p.z-mean.z)
  spread_along+=absf(m.dot(line));spread_across+=absf(line.x*m.y-line.y*m.x)
 spread_along/=maxi(1,bursts.size());spread_across/=maxi(1,bursts.size())
 # Mean absolute deviation ≈ 1.18 probable errors: Вд = Д/326, Вб = Д/278.
 print("  mean deviation in range %.0f m, in direction %.0f m" % [spread_along,spread_across])
 check(spread_along>distance/326.0*0.5 and spread_along<distance/326.0*3.0,"Spread in range of the order of Д/326")
 check(spread_across>distance/278.0*0.5 and spread_across<distance/278.0*3.0,"Spread in direction of the order of Д/278")
 check(vehicle.package_bearing()-laid<1.0,"Package did not wander during the salvo")
 var miss:=Vector2(mean.x-aim.x,mean.z-aim.z).length()
 print("  centre of bursts %.0f m from the target, %d within 150 m" % [miss,near])
 check(miss<120,"Centre of the salvo within 120 m of the strongpoint (%.0f m)" % miss)
 check(near>=24,"Most rockets within 150 m (%d)" % near)
 check(target.destroyed,"Strongpoint %s destroyed by the salvo" % target.title)
 check(grad.destroyed>=1,"Destroyed strongpoints counted (%d)" % grad.destroyed)
 check(not grad.counter_fire.is_empty(),"Enemy plans counter-battery fire on the position")
 var reported:=false
 for entry in grad.radio_log:
  if "розрив" in entry:reported=true
 check(reported,"Observation post reports the bursts")
 # Bursts 60 m beyond and 80 m right of the target, as seen from the launcher.
 var right_hand:=Vector3(-line.y,0,line.x)
 var forward_hand:=Vector3(line.x,0,line.y)
 var kept:=grad.strongpoints.duplicate()
 grad.strongpoints.clear()
 grad.targets.append({"name":"Ц-Т","point":aim})
 grad.impacts.clear()
 for k in range(4):grad.impacts.append(aim+forward_hand*60.0+right_hand*80.0)
 grad.last_impact=grad.clock-20.0
 grad.report_bursts()
 check("праворуч" in grad.radio_log[0] and "переліт 60" in grad.radio_log[0],"Report: overshoot and to the right (%s)" % grad.radio_log[0])
 var fixed:=grad.solution(grad.targets[-1])
 var base: Dictionary=vehicle.last_launch
 check(fixed.has("correction") and fixed.correction.needed,"Tablet computes the correction from the report")
 if fixed.has("correction"):
  check(fixed.correction.sight<float(base.sight)-1.0 and absf(wrapf(fixed.correction.deflection-(float(base.deflection)-float(fixed.correction.mils)),-3000,3000))<1.0,"…smaller sight for the overshoot (%s → %s), smaller deflection for right (%s → %s)" % [GradHud.sight_text(base.sight),GradHud.sight_text(fixed.correction.sight),GradBallistics.mils_text(base.deflection),GradBallistics.mils_text(fixed.correction.deflection)])
 for k in range(4):grad.impacts.append(aim-forward_hand*40.0-right_hand*50.0)
 grad.last_impact=grad.clock-20.0
 grad.report_bursts()
 check("ліворуч" in grad.radio_log[0] and "недоліт 40" in grad.radio_log[0],"Report: short and to the left (%s)" % grad.radio_log[0])
 grad.strongpoints.assign(kept)
 grad.targets.clear()
 # Applying the report as the drill card says moves the package back on.
 var before_bearing:=vehicle.package_bearing()
 vehicle.deflection-=80.0/(0.001*distance)
 for i in range(8):
  var off:=wrapf(vehicle.sight_bearing()-GradVehicle.BOUSSOLE_CORRECTION,-3000.0,3000.0)
  vehicle.azimuth-=off*0.06
  vehicle.apply_launcher()
 var turned:=wrapf(vehicle.package_bearing()-before_bearing,-3000,3000)
 check(turned<-10.0,"Smaller deflection turns the package left (%.1f mils)" % turned)

 # --- Drone and tablet ------------------------------------------------------
 grad.request_drone()
 check(grad.drone_eta>0,"Observation post prepares its drone")
 grad.drone_eta=0.01
 await frames(5)
 check(is_instance_valid(grad.drone) and grad.drone.relay!=Vector3.INF,"Drone up over the observation post with a relay link")
 grad.begin_piloting()
 check(grad.piloting and grad.drone.piloting,"Commander flies the drone from the cab terminal")
 grad.drone.camera_pitch=-1.3
 grad.drone.camera.rotation.x=-1.3
 await frames(3)
 grad.mark_target()
 check(grad.targets.size()==1 and grad.targets[0].name=="Ц-1","Laser rangefinder marks a target")
 grad.end_piloting()
 check(not grad.piloting and vehicle.seat_camera.current,"Back to the cab")
 grad.hud.toggle("tablet")
 await process_frame;await process_frame
 check(grad.hud.open_panel()=="tablet" and grad.hud.tablet.layer.built,"Tablet map built")
 grad.hud.toggle("radio")
 await process_frame
 grad.hud.toggle("console")
 await process_frame
 check(grad.hud.open_panel()=="console","Fire-control panel opens from the commander's seat")
 grad.hud.close_all()
 grad.order_assault(true)
 check(not game.battle.halted and grad.assault_ordered,"Assault ordered by radio")
 grad.leave()
 check(game.player.is_physics_processing() and game.player.collision_layer==2,"Commander steps out of the cab")
 print("checks: %d" % checks)
 print("PASS" if not failed else "FAILED")
 quit(1 if failed else 0)
