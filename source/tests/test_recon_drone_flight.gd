extends SceneTree
# The recon drone flies as a Mavic 3 class quadcopter: it holds its place
# with the sticks centred (in calm air, in a steady wind and its gusts, in
# the goggles and on the wrist display, far out on the map), reaches 15 m/s
# (N) and 21 m/s (S) leaning 30° / 35°, brakes by leaning back, climbs at
# 6 / 8 m/s, descends at 6 m/s, sets down gently, turns at up to 200°/s and
# stops at the geofence.
var checks := 0
var failed := false
var game: Node3D
var drone: ReconDrone
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
 elif OS.get_environment("FLIGHT_VERBOSE")!="":print("ok: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame

func planar(v: Vector3) -> float:return Vector2(v.x,v.z).length()
func pitch() -> float:return rad_to_deg(atan2(-drone.airframe.y.z,drone.airframe.y.y))
func lean() -> float:return rad_to_deg(drone.airframe.y.angle_to(Vector3.UP))

# Hovering where it is put, its heading north, the sticks centred.
func place(at: Vector3, flown: bool=true) -> void:
 for action in ["forward","back","left","right","jump","crouch","sprint"]:Input.action_release(action)
 drone.global_position=at;drone.velocity=Vector3.ZERO;drone.yaw=0.0
 drone.armed=true;drone.landed=false;drone.battery=1.0;drone.health=1.0
 drone.airframe=Basis();drone.wind_trim=Vector3.ZERO;drone.climb_trim=0.0
 if flown and not drone.piloting:drone.begin_control()
 elif not flown and drone.piloting:drone.end_control()
 await frames(2)

# Largest distance from where it was over n frames, horizontally and up/down.
func drift(n: int) -> Vector2:
 var start:=drone.global_position
 var most:=Vector2.ZERO
 for i in range(n):
  await physics_frame
  var off:=drone.global_position-start
  most=Vector2(maxf(most.x,planar(off)),maxf(most.y,absf(off.y)))
 return most

func block(size: Vector3, at: Vector3) -> StaticBody3D:
 var body := StaticBody3D.new()
 var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape)
 game.world_root.add_child(body);body.global_position=at
 return body

# Obstacle sensing (N mode only): full forward at a wall it stops short and
# hovers there; in sport the sensors are off and it flies into it; beside a
# wall and under a roof it is not thrown off.
func obstacles() -> void:
 var wall:=block(Vector3(40,40,1),Vector3(0,40,89.5))
 await frames(2)
 await place(Vector3(0,40,150))
 Input.action_press("forward")
 var bumped:=false;var warned:="";var nearest:=INF;var fastest:=0.0
 for i in range(720):
  await physics_frame
  bumped=bumped or drone.touching
  if warned=="" and drone.obstacle_text()!="":warned=drone.obstacle_text()
  nearest=minf(nearest,drone.global_position.z-0.17-90.0)
  fastest=maxf(fastest,planar(drone.velocity))
 var halted:=planar(drone.velocity)
 var gap:=drone.global_position.z-0.17-90.0
 var stopped_text:=drone.obstacle_text()
 Input.action_release("forward")
 check(fastest>13.0 and not bumped and nearest>0.8,"N: full forward (%.1f m/s) at a wall, it stops short: closest %.1f m" % [fastest,nearest])
 check(halted<0.3 and gap>1.5 and gap<4.0,"N: hovers %.1f m before the wall (%.2f m/s), the stick still forward" % [gap,halted])
 check(warned.contains("ГАЛЬМУЮ") and stopped_text.contains("ПЕРЕШКОДА"),"Goggles warn: «%s», then «%s»" % [warned,stopped_text])
 # Sport: no sensing.
 drone.on_lost=func():pass
 await place(Vector3(0,40,150))
 Input.action_press("forward");Input.action_press("sprint")
 bumped=false;var impact:=0.0
 for i in range(720):
  var speed:=planar(drone.velocity)
  await physics_frame
  if drone.touching:bumped=true;impact=speed;break
 Input.action_release("forward");Input.action_release("sprint")
 check(bumped and impact>12.0 and drone.health<1.0,"S: sensors off, it flies into the wall at %.0f m/s and breaks (health %.2f)" % [impact,drone.health])
 drone.on_lost=Callable()
 wall.queue_free()
 # Beside a wall a metre off: it hovers and flies along it untroubled.
 var side:=block(Vector3(0.4,40,200),Vector3(1.2,40,60))
 await frames(2)
 await place(Vector3(0,40,150))
 var braked:=false
 var start:=drone.global_position
 for i in range(600):
  await physics_frame
  braked=braked or drone.obstacle_braking
 check(not braked and planar(drone.global_position-start)<0.5,"Hovering a metre from a wall, it is not pushed off")
 Input.action_press("forward")
 bumped=false
 for i in range(180):
  await physics_frame
  braked=braked or drone.obstacle_braking
  bumped=bumped or drone.touching
 Input.action_release("forward")
 check(not braked and not bumped and planar(drone.velocity)>9.0,"Flying along the wall it is not braked (%.1f m/s)" % planar(drone.velocity))
 side.queue_free()
 # A roof above: climbing, it stops under it.
 var roof:=block(Vector3(20,1,20),Vector3(0,52.5,150))
 await frames(2)
 await place(Vector3(0,40,150))
 Input.action_press("jump")
 bumped=false
 for i in range(300):
  await physics_frame
  bumped=bumped or drone.touching
 Input.action_release("jump")
 var under:=52.0-(drone.global_position.y+0.065)
 check(not bumped and under>0.5 and under<2.5 and absf(drone.velocity.y)<0.3,"Climbing under a roof, it stops %.1f m below it" % under)
 roof.queue_free()
 await frames(2)

func run():
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 await process_frame
 game.volume=0
 game.selected_map=TrainingRange.ID
 game.start_match();game.set_physics_process(false);game.player.set_physics_process(false)
 for bot in game.bots+game.allies:bot.set_physics_process(false)
 await frames(5)
 drone=ReconDrone.new()
 game.world_root.add_child(drone)
 drone.setup(game.player,{"battery":1.0,"condition":1.0})
 # The radio link is another test's; here it never runs out.
 drone.link_range=5000.0
 # Hover: the sticks centred for 30 s, it stays put.
 await place(Vector3(0,40,150))
 await frames(60)
 var calm:=await drift(1800)
 check(calm.x<1.0 and calm.y<0.5,"Sticks centred: it hovers in place for 30 s (%.2f m across, %.2f m up/down)" % [calm.x,calm.y])
 var gusts:=0.0
 for i in range(120):
  await physics_frame
  gusts=maxf(gusts,(drone.air()-drone.wind).length())
 check(gusts>0.5 and planar(drone.velocity)<0.2,"The air is gusty (%.1f m/s) and it holds against it" % gusts)
 # Goggles off: the same, flown by nobody, the picture on the wrist display.
 await place(Vector3(20,40,140),false)
 var alone:=await drift(1800)
 check(not drone.piloting and alone.x<1.0 and alone.y<0.5,"Nobody at the sticks: it hovers in place (%.2f m)" % alone.x)
 # Far down the range, past the 400 m square of the old maps that pushed it
 # off at 2 m/s (7.2 km/h): it stays.
 check(drone.fence().has_point(Vector2(0,-400)) and drone.fence().has_point(Vector2(-150,-300)),"Geofence takes in the whole range")
 await place(Vector3(-150,40,-300),false)
 var far:=await drift(1200)
 check(far.x<1.0,"Far out on the map it does not drift (%.2f m in 20 s)" % far.x)
 # A steady 8 m/s wind from the east: it leans into it and holds.
 drone.wind=Vector3(-8,0,0)
 await place(Vector3(0,40,150))
 var start:=drone.global_position
 await frames(300)
 var settled:=planar(drone.global_position-start)
 var windy:=await drift(1800)
 var into:=drone.airframe.y.x
 check(settled<3.0 and windy.x<1.0,"8 m/s wind: blown %.2f m at first, then holds within %.2f m for 30 s" % [settled,windy.x])
 check(lean()>8.0 and into>0.0,"It leans into the wind (%.1f°)" % lean())
 drone.wind=Vector3(0,0,12)
 await place(Vector3(0,40,150))
 await frames(300)
 var gale:=await drift(1200)
 check(gale.x<2.0,"12 m/s, its rated wind: holds within %.2f m" % gale.x)
 drone.wind=Vector3.ZERO
 # N mode, the stick full forward: 15 m/s in a few seconds at 30° of lean.
 await place(Vector3(0,40,150))
 Input.action_press("forward")
 var reach:=-1.0;var top_lean:=0.0
 for i in range(480):
  await physics_frame
  top_lean=maxf(top_lean,lean())
  if reach<0 and planar(drone.velocity)>=14.0:reach=(i+1)/60.0
 var cruise:=planar(drone.velocity)
 check(reach>2.5 and reach<6.0,"N: 14 m/s in %.1f s" % reach)
 check(cruise>14.0 and cruise<15.5,"N: top speed %.1f m/s (15)" % cruise)
 check(top_lean>27.0 and top_lean<31.0,"N: leans at most 30° (%.1f°)" % top_lean)
 check(absf(drone.velocity.y)<0.5,"Height held in level flight (%.2f m/s)" % drone.velocity.y)
 # Let go: it brakes by leaning back, then holds where it stopped.
 Input.action_release("forward")
 var from:=drone.global_position
 var back:=0.0;var stopped:=-1.0
 for i in range(300):
  await physics_frame
  back=minf(back,pitch())
  if stopped<0 and planar(drone.velocity)<0.3:stopped=(i+1)/60.0;break
 var run_out:=planar(drone.global_position-from)
 check(stopped>0 and stopped<4.0,"N: stops from 15 m/s in %.1f s" % stopped)
 check(run_out>8.0 and run_out<30.0,"N: braking distance %.1f m" % run_out)
 check(back<-15.0,"Brakes leaning back (%.1f°)" % back)
 var after:=await drift(300)
 check(after.x<1.5,"Holds where it stopped (%.2f m)" % after.x)
 # S mode: 21 m/s at up to 35°.
 await place(Vector3(0,40,150))
 Input.action_press("forward");Input.action_press("sprint")
 reach=-1.0;top_lean=0.0
 for i in range(600):
  await physics_frame
  top_lean=maxf(top_lean,lean())
  if reach<0 and planar(drone.velocity)>=20.0:reach=(i+1)/60.0
 cruise=planar(drone.velocity)
 check(reach>3.5 and reach<9.0,"S: 20 m/s in %.1f s" % reach)
 check(cruise>20.0 and cruise<21.5,"S: top speed %.1f m/s (21)" % cruise)
 check(top_lean>31.0 and top_lean<36.0,"S: leans at most 35° (%.1f°)" % top_lean)
 # Battery: flat out in sport it drains faster than in a hover.
 var charge:=drone.battery
 await frames(300)
 var fast:=charge-drone.battery
 Input.action_release("forward");Input.action_release("sprint")
 from=drone.global_position;stopped=-1.0
 for i in range(360):
  await physics_frame
  if planar(drone.velocity)<0.3:stopped=(i+1)/60.0;break
 run_out=planar(drone.global_position-from)
 check(stopped>0 and run_out>12.0 and run_out<45.0,"S: stops from 21 m/s in %.1f s over %.1f m" % [stopped,run_out])
 await place(Vector3(0,40,150))
 await frames(60)
 charge=drone.battery
 await frames(300)
 var still:=charge-drone.battery
 check(absf(still*ReconDrone.FLIGHT_SECONDS/5.0-1.0)<0.1,"A hover drains the pack in about 40 minutes (%.0f min)" % (5.0/still/60.0))
 check(fast/still>1.1 and fast/still<1.5,"Flat out drains it %.2f× as fast" % (fast/still))
 var full:=drone.max_lift()
 drone.battery=0.08
 check(drone.max_lift()<full*0.9 and drone.max_lift()>ReconDrone.GRAVITY*1.4,"The pack's voltage sags near empty (%.1f → %.1f m/s²)" % [full,drone.max_lift()])
 drone.battery=1.0
 # Climb and descent.
 await place(Vector3(0,20,150))
 Input.action_press("jump");await frames(240)
 var rise:=drone.velocity.y
 Input.action_press("sprint");await frames(180)
 var sport_rise:=drone.velocity.y
 Input.action_release("jump");Input.action_release("sprint")
 check(rise>5.5 and rise<6.3,"N: climbs at %.1f m/s (6)" % rise)
 check(sport_rise>7.4 and sport_rise<8.3,"S: climbs at %.1f m/s (8)" % sport_rise)
 await frames(120)
 var level:=await drift(300)
 check(level.y<0.5,"Throttle centred: holds the height (%.2f m)" % level.y)
 await place(Vector3(0,80,150))
 Input.action_press("crouch");await frames(180)
 var sink:=drone.velocity.y
 check(sink<-5.5 and sink>-6.3,"Descends at %.1f m/s (6)" % sink)
 var touchdown:=0.0
 for i in range(1200):
  var falling:=drone.velocity.y
  await physics_frame
  if drone.landed or not drone.armed:touchdown=falling;break
 Input.action_release("crouch")
 await frames(5)
 check(not drone.armed and drone.landed,"Holding Ctrl it lands and the motors stop")
 check(touchdown>-1.6 and drone.health==1.0,"It eases off near the ground: down at %.1f m/s, undamaged" % touchdown)
 # Yaw: the mouse turns the heading, the airframe follows at 200°/s.
 await place(Vector3(0,40,150))
 await frames(30)
 var turn:=InputEventMouseMotion.new()
 turn.relative=Vector2(-(PI*0.5)/(game.player.sensitivity*0.7),0)
 drone.handle_input(turn)
 var spot:=drone.global_position
 await frames(15)
 var quarter:=rad_to_deg(drone.yaw)
 check(quarter>30.0 and quarter<=51.0,"Yaw rate is limited: %.0f° in 0.25 s (200°/s)" % quarter)
 await frames(45)
 check(absf(rad_to_deg(drone.yaw)-90.0)<2.0,"It comes round to the new heading in a second (%.1f°)" % rad_to_deg(drone.yaw))
 check(planar(drone.global_position-spot)<0.5,"It turns on the spot")
 # Put elsewhere (the observation post's drone, a render): it holds there.
 drone.global_position+=Vector3(30,0,0)
 spot=drone.global_position
 await frames(180)
 check(planar(drone.global_position-spot)<1.0,"Moved from outside, it holds the new place")
 # The geofence at the range's side: it slows to a stop at the edge.
 await place(Vector3(185,40,0))
 Input.action_press("right");Input.action_press("sprint")
 var widest:=0.0
 for i in range(420):
  await physics_frame
  widest=maxf(widest,drone.global_position.x)
 Input.action_release("right");Input.action_release("sprint")
 check(widest<200.5 and widest>197.0 and absf(drone.velocity.x)<0.5,"Geofence: it stops at the edge (x %.1f)" % widest)
 await place(Vector3(215,40,0),false)
 await frames(900)
 check(drone.global_position.x<200.5,"Past the edge, it comes back inside (x %.1f)" % drone.global_position.x)
 await obstacles()
 drone.end_control();drone.queue_free()
 game.queue_free();await frames(3)
 print("FAIL: " if failed else "PASS: ",checks," recon drone flight checks")
 quit(1 if failed else 0)
