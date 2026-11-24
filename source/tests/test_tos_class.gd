extends SceneTree

# TOS-1A commander's class: the BM-1 on its T-72A tracks (the start drill,
# the gears and the speeds, the levers and the radius of each gear),
# readiness from the stop to the first rocket, the 1D14 rangefinder and the
# ballistic computer on a tilted hull, a salvo at a strongpoint with the
# observer's report and the enemy's answer, and the «Навчання» course walked
# with F6. Run with --fixed-fps 60.
var checks := 0
var failed := false
var game: Node3D
var tos: TosCommand

func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
 else:print("ok   ",message)

func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func place(at: Vector3, yaw: float) -> void:
 var v:=tos.vehicle
 v.freeze=false;v.parked_time=0.0
 tos.place_vehicle(tos.ground(at),yaw)

func yaw_now() -> float:
 var f:=-tos.vehicle.global_basis.z
 return atan2(f.x,-f.z)

func heading_to(from: Vector3, point: Vector3) -> float:return atan2(point.x-from.x,-(point.z-from.z))

func run_engine() -> void:
 var v:=tos.vehicle
 v.master=true;v.running=true;v.omega=TosVehicle.IDLE_RPM/60.0*TAU;v.starter=false

# Drives in a gear with a lever held: the radius about the hull's centre
# from the speed and the turn rate, once the turn is steady.
func turn_radius(gear: int, lever: float, throttle: float) -> float:
 var v:=tos.vehicle
 place(TosCommand.FIRING_AREA,heading_to(TosCommand.FIRING_AREA,Vector3.ZERO))
 await frames(60)
 run_engine()
 # Off in 2nd (1st for a turn in 1st), then up to the gear of the turn.
 v.parking=false;v.clutch_pedal=1.0;v.gear=mini(gear,TosVehicle.NEUTRAL+2);v.brake_pedal=0.0
 for i in range(60):
  v.clutch_pedal=1.0-i/60.0;v.throttle=throttle
  await frames(1)
 await frames(150)
 if gear>v.gear:
  v.clutch_pedal=1.0;v.throttle=0.0
  await frames(6)
  v.gear=gear
  for i in range(30):
   v.clutch_pedal=1.0-i/30.0;v.throttle=throttle
   await frames(1)
  await frames(120)
 var turned:=0.0;var travelled:=0.0
 var last:=yaw_now()
 for i in range(240):
  if lever>=1.0:v.lever_input=Vector2(1,0)
  else:v.lever_input=Vector2.ZERO;v.levers=Vector2(lever,0)
  v.throttle=throttle
  await frames(1)
  if i>=90:
   turned+=absf(angle_difference(last,yaw_now()))
   travelled+=Vector2(v.linear_velocity.x,v.linear_velocity.z).length()/60.0
  last=yaw_now()
 v.lever_input=Vector2.ZERO;v.levers=Vector2.ZERO;v.throttle=0.0;v.clutch_pedal=1.0;v.brake_pedal=1.0
 await frames(90)
 v.gear=TosVehicle.NEUTRAL;v.brake_pedal=0.0
 return travelled/maxf(turned,0.0001)

func run():
 seed(70511)
 # --- The drive's numbers ---------------------------------------------------
 var top:=0.0
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.selected_map="training"
 game.set_player_class("tos")
 check(game.player_class=="tos" and game.selected_map==BattleMap.ID,"Choosing the TOS-1A selects the great assault")
 check(PlayerClass.TITLES.tos=="КОМАНДИР ТОС-1А" and PlayerClass.allies("tos")==0,"The class: the TOS-1A commander, nobody of his own on foot")
 game.battle_size=18
 game.start_match()
 for actor in game.allies+game.bots:actor.set_physics_process(false)
 game.squad.set_physics_process(false)
 tos=game.tos
 var v:=tos.vehicle
 check(tos.active() and is_instance_valid(v) and not v.scripted,"The player's BM-1 stands at its start, on its own tracks")
 check(Vector2(v.global_position.x-TosCommand.START.x,v.global_position.z-TosCommand.START.z).length()<3,"…in the tree line south-west of the battle")
 check(v.remaining()==24 and v.stops_locked and v.jacks==0.0 and v.parking and not v.running,"24 rockets, locked for the march, brakes on the latch, engine cold")
 check(game.battle.awaiting and game.battle.halted,"The assault waits for the commander's order")
 check(game.player.global_position.distance_to(v.global_position)<7,"The commander stands next to the vehicle")
 for i in range(TosVehicle.GEARS.size()):top=maxf(top,v.speed_in(i,TosVehicle.GOVERNED_RPM))
 check(absf(top*3.6-60.0)<1.5,"7th gear at 2000 rpm: %.1f km/h (the manual: 60)" % (top*3.6))
 var first:=v.speed_in(TosVehicle.NEUTRAL+1,TosVehicle.GOVERNED_RPM)*3.6
 var back:=absf(v.speed_in(0,TosVehicle.GOVERNED_RPM))*3.6
 check(absf(first-7.32)<0.15 and absf(back-4.18)<0.15,"1st gear %.2f km/h, reverse %.2f km/h (the manual: 7.32 and 4.18)" % [first,back])
 await frames(180)
 check(v.linear_velocity.length()<0.25 and v.global_basis.y.dot(Vector3.UP)>0.97,"At rest and upright on the relief (%.2f m/s)" % v.linear_velocity.length())
 var ground:=AvdiivkaData.shared().height(v.global_position.x,v.global_position.z)
 check(absf(v.global_position.y-ground)<1.2,"Tracks on the ground (body %.2f m above it)" % (v.global_position.y-ground))

 # --- Seats and the start drill ----------------------------------------------
 game.player.global_position=v.to_global(Vector3(-1.9,0.2,-2.1))
 check(tos.nearest_station().get("id","")=="driver","F at the bow's left hatch offers the driver's seat")
 tos.enter("driver")
 check(tos.seat=="driver" and v.seat_camera.current and not game.player.is_physics_processing(),"Driver seated, the view from his hatch")
 check(game.player_sheltered()==false,"…his head out of the hatch is not under armour")
 v.toggle_hatch()
 check(game.player_sheltered(),"Hatch closed: under armour")
 tos.set_process(false)
 v.begin_crank()
 await frames(30)
 check(not v.running and not v.starter or not v.master,"No start without the battery switch")
 v.starter=false
 v.toggle_master()
 v.begin_crank()
 check(not v.starter and "МЗН" in v.notice,"A dry engine: the starter waits for the oil pump")
 v.priming=true
 var pumped:=0
 while v.primed<=0.0 and pumped<900:
  await frames(1);pumped+=1
 v.priming=false
 check(v.primed>0.0 and pumped>=120 and pumped<=720,"МЗН brings the oil to 2 kgf/cm² in %.1f s (the cards: 2–12 s)" % (pumped/60.0))
 v.clutch_pedal=1.0;v.toggle_parking()
 check(v.parking==false,"The brake latch comes off")
 v.shift(1)
 check(v.gear==TosVehicle.NEUTRAL+1,"…a gear goes in with the clutch pedal down")
 v.begin_crank()
 check(not v.starter and "нейтрал" in v.notice,"The neutral sensor keeps the starter off with a gear in")
 v.toggle_parking()
 check(not v.parking and "нейтрал" in v.notice,"The latch goes on in neutral only")
 v.shift(-1)
 v.toggle_parking()
 check(v.parking,"Neutral: the latch on")
 v.shift(1)
 check(v.gear==TosVehicle.NEUTRAL,"No gear with the brake latched")
 v.clutch_pedal=0.0
 v.shift(1)
 check(v.gear==TosVehicle.NEUTRAL and v.grind>0.0,"No gear without the clutch pedal")
 v.begin_crank()
 await frames(150)
 v.starter=false
 check(v.running and v.rpm()>650 and v.rpm()<950,"The V-84 starts and idles (%.0f rpm)" % v.rpm())
 check(v.oil_pressure>=1.0,"Oil pressure on the running engine (%.1f)" % v.oil_pressure)

 # --- Moving off, the speeds and the BA-20 -------------------------------------
 v.clutch_pedal=1.0;v.toggle_parking();v.shift(1);v.shift(1)
 check(v.gear==TosVehicle.NEUTRAL+2,"2nd gear for moving off")
 for i in range(90):
  v.clutch_pedal=1.0-i/90.0;v.throttle=0.5
  await frames(1)
 v.throttle=0.8
 await frames(300)
 check(v.running and v.speed()>2.0 and v.speed()<4.2,"Moves off in 2nd on the field (%.1f km/h, the gear tops at 13.6)" % (v.speed()*3.6))
 v.throttle=0;v.clutch_pedal=1;v.brake_pedal=1
 await frames(180)
 check(absf(v.speed())<0.3,"The brakes stop 44 t")
 v.brake_pedal=0
 # Flat out in 7th on the open field toward the village.
 place(TosCommand.FIRING_AREA,heading_to(TosCommand.FIRING_AREA,Vector3.ZERO))
 await frames(60)
 v.parking=false;v.gear=TosVehicle.NEUTRAL+7;v.clutch_pedal=0.0;v.throttle=1.0
 v.linear_velocity=-v.global_basis.z*16.0
 v.omega=16.0/TosVehicle.SPROCKET*v.gear_ratio()
 await frames(240)
 var cruise:=v.speed()*3.6
 check(cruise>52.0 and cruise<63.0,"7th gear flat out on the field: %.0f km/h (60 on a road)" % cruise)
 v.clutch_pedal=1.0
 v.shift(-1)
 check(v.gear==TosVehicle.NEUTRAL+7 and "БА-20" in v.notice,"BA-20 keeps 7→6 out at %.0f km/h (6th tops at 40.8)" % (v.speed()*3.6))
 v.throttle=0;v.brake_pedal=1
 await frames(400)
 v.brake_pedal=0;v.gear=TosVehicle.NEUTRAL

 # --- Levers: the radius of each gear -----------------------------------------
 var r2:float=await turn_radius(TosVehicle.NEUTRAL+2,1.0,0.7)
 var r3:float=await turn_radius(TosVehicle.NEUTRAL+3,1.0,0.7)
 var r1:float=await turn_radius(TosVehicle.NEUTRAL+1,1.0,1.0)
 var half:float=await turn_radius(TosVehicle.NEUTRAL+2,0.5,0.7)
 check(r2>3.2 and r2<6.5,"2nd, lever at its stop: radius %.1f m about the centre (the manual: 6.04 to the outer track, 4.6 to the centre)" % r2)
 check(r3>8.5 and r3<16.0 and r3>r2*1.8,"3rd: %.1f m (13.42 − 1.40 = 12.0)" % r3)
 check(r1<2.6,"1st: the lagging track brakes, the hull turns about it (%.1f m)" % r1)
 check(half>r2*1.3,"Half a pull slips the clutches: a wider turn than at the stop (%.1f m)" % half)
 # No neutral turn.
 place(TosCommand.FIRING_AREA,0.0)
 await frames(60)
 run_engine();v.parking=false;v.gear=TosVehicle.NEUTRAL;v.clutch_pedal=0.0
 var before:=yaw_now()
 for i in range(180):
  v.lever_input=Vector2(1,0);v.throttle=1.0
  await frames(1)
 v.lever_input=Vector2.ZERO;v.throttle=0.0
 check(absf(angle_difference(before,yaw_now()))<deg_to_rad(1.0),"In neutral the levers do nothing: no turn on the spot")

 # --- Readiness: 90 s from the stop ----------------------------------------------
 var aim: Vector3=tos.strongpoints[1].point
 place(TosCommand.FIRING_AREA,heading_to(TosCommand.FIRING_AREA,aim))
 await frames(90)
 run_engine();v.gear=TosVehicle.NEUTRAL;v.parking=true;v.throttle=0.0;v.clutch_pedal=0.0;v.brake_pedal=0.0
 await frames(60)
 tos.enter("commander")
 tos.set_process(true)
 check(game.player_sheltered(),"The commander's seat is under armour")
 var start_clock:=0
 v.toggle_fcs();v.toggle_jacks();v.toggle_stops()
 var loaded:=false
 tos.targets.append({"name":"Ц-1","point":aim});tos.selected_target=0
 while start_clock<6000:
  await frames(1);start_clock+=1
  if not loaded and v.fcs_ready():loaded=tos.load_target()
  if loaded and v.laid() and v.elevation>=1.0:break
 v.toggle_armed()
 var ready_s:=start_clock/60.0
 check(v.ready_to_fire()=="","Ready to fire: %s" % (v.ready_to_fire() if v.ready_to_fire()!="" else "laid, armed"))
 check(ready_s>=TosVehicle.FCS_WARMUP and ready_s<=90.0,"From the stop to the first rocket in %.0f s (the maker: 90)" % ready_s)
 var done:=true
 for item in tos.checklist():
  if not item[1]:done=false;printerr("  not ready: ",item[0])
 check(done,"The commander's list all ticked")
 var s: Dictionary=v.solution
 var d:=tos.firing_data(aim)
 check(absf(float(s.distance)-float(d.distance))<5.0 and s.time>15.0 and s.time<35.0,"Computer: %.0f m, flight %.0f s" % [s.distance,s.time])
 var dir:=v.launch_direction()
 var want:=GradBallistics.direction(float(s.bearing))*cos(GradBallistics.radians(float(s.elevation)))+Vector3.UP*sin(GradBallistics.radians(float(s.elevation)))
 check(rad_to_deg(dir.angle_to(want))<0.5,"The package points where the computer says (%.2f° off)" % rad_to_deg(dir.angle_to(want)))

 # --- The 1D14 and the computer on a tilted hull -----------------------------------
 var saved:=v.global_transform
 v.freeze=true
 v.global_transform=Transform3D(saved.basis*Basis(Vector3.FORWARD,deg_to_rad(4.0))*Basis(Vector3.RIGHT,deg_to_rad(2.0)),saved.origin)
 var tilted:=v.compute(aim,"Ц-1")
 v.platform_yaw=v.want_yaw;v.elevation=v.want_elevation
 v.lay_solution();v.platform_yaw=v.want_yaw;v.elevation=v.want_elevation
 v.pose()
 var dir2:=v.launch_direction()
 var want2:=GradBallistics.direction(float(tilted.bearing))*cos(GradBallistics.radians(float(tilted.elevation)))+Vector3.UP*sin(GradBallistics.radians(float(tilted.elevation)))
 check(rad_to_deg(dir2.angle_to(want2))<0.3,"Rolled 4° and pitched 2°: the roll sensor keeps the laying true (%.2f° off)" % rad_to_deg(dir2.angle_to(want2)))
 v.global_transform=saved;v.freeze=false
 v.compute(aim,"Ц-1");v.lay_solution();v.platform_yaw=v.want_yaw;v.elevation=v.want_elevation
 tos.enter("gunner")
 v.sight_pitch=-8.0
 var near:=v.range_target()
 check(float(near.get("distance",0))==-2.0,"Closer than 400 m the 1D14 gives no range")
 # The sight's head down until its line meets the field 0.8–2.5 km out.
 var eye:=v.sight_transform()
 var truth: Dictionary={}
 var space:=v.get_world_3d().direct_space_state
 v.sight_pitch=0.0
 while v.sight_pitch>-6.0:
  eye=v.sight_transform()
  truth=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye.origin,eye.origin-eye.basis.z*10000.0,1,[v.get_rid()]))
  if not truth.is_empty() and eye.origin.distance_to(truth.position)<2500.0:break
  v.sight_pitch-=0.1
 var reading:=v.range_target()
 if not truth.is_empty() and float(reading.get("distance",-1))>0.0:
  var real:=eye.origin.distance_to(truth.position)
  check(absf(float(reading.distance)-real)<=10.0 and fmod(float(reading.distance),5.0)==0.0,"1D14: %.0f m for %.1f m — within ±10 m, read to 5 m" % [reading.distance,real])
  check(tos.lay_by_laser() and v.solution.source=="1Д14","ENTER: the reading into the computer and laid")
 else:check(false,"The 1D14 got an echo from the ground ahead (%s)" % str(reading))
 v.compute(aim,"Ц-1");v.lay_solution()
 await frames(600)

 # --- Salvo, the observer, the enemy's answer -----------------------------------
 tos.enter("commander")
 var before_fire:=v.fired
 v.series=12;v.pairs=true
 tos.fire()
 await frames(60*4)
 check(v.fired-before_fire==12 and v.remaining()==12,"12 rockets in pairs within 3 s (%d)" % (v.fired-before_fire))
 check(not tos.counter_fire.is_empty() and float(tos.counter_fire[0].time)-tos.clock>=140.0,"The enemy will answer at the position in 2.5–4 min")
 await frames(60*40)
 check(tos.burst_log.size()>=10,"The bursts reach the commander's map (%d)" % tos.burst_log.size())
 var centre:=Vector3.ZERO
 for p in tos.burst_log:centre+=p
 centre/=maxi(1,tos.burst_log.size())
 var miss:=Vector2(centre.x-aim.x,centre.z-aim.z).length()
 check(miss<160.0,"The centre of the bursts %.0f m from the target at %.1f km" % [miss,d.distance/1000.0])
 var reported:=false
 for line in tos.radio_log:if "СП" in line and ("розрив" in line or "знищено" in line):reported=true
 check(reported,"The observer reports the bursts or the strongpoint gone")
 check(tos.status_text().begins_with("ТОС-1А"),"The objective line tells the commander's state")
 tos.order_assault(true)
 check(not game.battle.halted and tos.assault_ordered,"G — the assault groups go")

 # --- «Навчання» -----------------------------------------------------------------
 game.to_menu()
 check(game.COURSE_IDS.has("tos") and game.courses.has("tos") and TosTraining.STEPS.size()==TosTraining.CHAPTERS.size(),"The TOS-1A course is in «Навчання», a step list per chapter")
 game.begin_training(0,"tos")
 var t: TosTraining=game.courses["tos"]
 for i in range(1200):
  if game.running and t.running and not game.launching:break
  await process_frame
 await frames(30)
 v=tos.vehicle
 check(tos.training and is_instance_valid(v) and not v.running and game.bots.is_empty(),"A cold vehicle at the start, nobody on the field")
 check(is_instance_valid(t.board) and t.board.global_position.distance_to(t.board_point())<1.0,"The target board stands in the field")
 var walked:=0
 while t.running and walked<80:
  var id:String=t.current().get("id","")
  if id=="observe":
   for i in range(60*20):
    if t.current().get("id","")!="observe":break
    await frames(1)
  else:
   t.skip()
   await frames(20 if id!="fire" else 60)
  walked+=1
 check(not t.running and t.done_chapters().size()>=5,"F6 walks all five chapters to the end (%d steps)" % walked)
 check(tos.strongpoints[1].destroyed,"…OP-2 down")
 game.to_menu()
 check(game.training=="" and game.player_class=="tos","Out of the course: the class as it was")
 print("checks: ",checks)
 print("PASS" if not failed else "FAILED")
 quit(1 if failed else 0)
