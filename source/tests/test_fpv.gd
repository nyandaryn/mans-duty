extends SceneTree

# FPV kamikaze drones on the open training range: bot-flown attack runs on a
# point, on a moving target with lead, on a target that is gone mid-flight,
# a search that finds a vehicle and dives steeply on it, a drone shot down,
# a bot pilot killed, the radio link against distance, ground and cover,
# and the player's own FPV from the backpack through the goggles.
const FPV := preload("res://scripts/fpv_drone.gd")
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame

var game: Node3D
var strikes: Array[Dictionary]=[]
var gone: Dictionary={}

func record(kind: String, point: Vector3, direction: Vector3, collider: Object, source: Node3D) -> void:
 strikes.append({"kind":kind,"point":point,"direction":direction,"collider":collider,"id":source.get_instance_id()})

# By instance id: the drone itself is freed after it went off.
func strike_of(id: int) -> Dictionary:
 for entry in strikes:
  if entry.id==id:return entry
 return {}

func ground(x: float, z: float) -> Vector3:
 return Vector3(x,game.district.ground_height(Vector3(x,0,z)),z)

func dummy(at: Vector3, field: String, body: bool=false) -> Node3D:
 var script := GDScript.new()
 script.source_code="extends %s\nvar %s := false\n" % ["StaticBody3D" if body else "CharacterBody3D",field]
 script.reload()
 var node: Node3D=script.new()
 game.world_root.add_child(node)
 node.global_position=at
 return node

func bot_fpv(from: Vector3, kind: String="heat", pilot: Node3D=null) -> Node3D:
 var drone: Node3D=FPV.launch(game,pilot,false,kind,from)
 drone.impact_handler=record
 drone.miss_chance=0.0
 drone.on_finished=func(d: Node3D):gone[d.get_instance_id()]=true
 return drone

func run():
 seed(int(OS.get_environment("FPV_SEED")) if OS.get_environment("FPV_SEED")!="" else 707)
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.selected_map=TrainingRange.ID
 game.loadout_bag.equipped=true
 for kind in ["fpv_heat","fpv_heat","fpv_frag"]:game.loadout_bag.add(kind)
 game.start_match()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 var player: Operator=game.player
 player.position=Vector3(0,0.2,175);player.rotation=Vector3.ZERO
 await frames(3)

 # --- Bot attack runs, four at once over the range ---------------------------
 var point_target := ground(-120,0)
 var a: Node3D=bot_fpv(ground(-120,150))
 check(a.is_in_group("drones") and not a.friendly and a.find_child("Hit_drone",true,false)!=null,"A bot FPV is a drone of its side with a drone hitbox")
 check(a.state=="ground" and not a.flying(),"Launched, it waits on the ground for its orders")
 a.autopilot_point(point_target)
 var moving: Node3D=dummy(ground(0,10),"dead")
 var b: Node3D=bot_fpv(ground(0,150))
 b.autopilot(moving)
 var fleeing: Node3D=dummy(ground(120,0),"dead")
 var c: Node3D=bot_fpv(ground(120,150))
 c.autopilot(fleeing)
 var hull: Node3D=dummy(ground(-60,-120)+Vector3.UP*0.9,"destroyed",true)
 var box := CollisionShape3D.new();box.shape=BoxShape3D.new();box.shape.size=Vector3(3.0,1.8,6.5);hull.add_child(box)
 hull.add_to_group("vehicles")
 var hunter: Node3D=bot_fpv(ground(-60,110),"frag")
 var picks := {"n":0}
 hunter.search_area(ground(-45,-100),70.0,func(at: Vector3, max_range: float) -> Node3D:
  picks.n+=1
  return hull if at.distance_to(hull.global_position)<=max_range else null)
 var id_a := a.get_instance_id()
 var id_b := b.get_instance_id()
 var id_c := c.get_instance_id()
 var id_d := hunter.get_instance_id()
 var states := {"a":{},"b":{},"c":{},"d":{}}
 var top := {"a":0.0,"d":0.0}
 var fled_from := Vector3.INF
 var caught_at := Vector3.INF
 var t := 0.0
 while t<60.0:
  await physics_frame
  t+=1.0/60.0
  for pair in [["a",a],["b",b],["c",c],["d",hunter]]:
   if is_instance_valid(pair[1]):
    states[pair[0]][pair[1].state]=true
    if top.has(pair[0]):top[pair[0]]=maxf(top[pair[0]],pair[1].global_position.y)
  # The moving target starts off as the drone tips into its dive.
  if is_instance_valid(b) and b.state=="attack":moving.velocity=Vector3(6,0,0)
  if caught_at==Vector3.INF and gone.has(id_b):caught_at=moving.global_position;moving.velocity=Vector3.ZERO
  moving.global_position+=moving.velocity/60.0
  # This one is killed while the drone is on its way and dragged off.
  if fled_from==Vector3.INF and is_instance_valid(c) and c.state=="transit" and c.flight_time>4.0:
   fled_from=fleeing.global_position
   fleeing.dead=true
   fleeing.global_position=ground(160,-60)
  if gone.size()>=4:break
 print("FPV runs: %.1f s, states a=%s b=%s c=%s d=%s, picks %d" % [t,str(states.a.keys()),str(states.b.keys()),str(states.c.keys()),str(states.d.keys()),picks.n])
 for entry in strikes:print("  strike %s at %s, %.0f° down, on %s" % [entry.kind,str(entry.point.snapped(Vector3.ONE*0.1)),rad_to_deg(asin(clampf(-entry.direction.y,-1,1))),str(entry.collider)])
 var sa := strike_of(id_a)
 check(not sa.is_empty() and sa.kind=="heat","The FPV reaches its point and the warhead goes off (impact handler)")
 if not sa.is_empty():
  check(Vector2(sa.point.x-point_target.x,sa.point.z-point_target.z).length()<3.0,"It strikes on the point (%.1f m off)" % Vector2(sa.point.x-point_target.x,sa.point.z-point_target.z).length())
  check(sa.direction.y<-0.2 and sa.collider!=null,"It comes down in a dive onto the ground (dir.y %.2f, %s)" % [sa.direction.y,str(sa.collider)])
 check(top.a>=20.0 and top.a<=48.0,"It cruises at 25–40 m (top %.1f m)" % top.a)
 check(states.a.has("transit") and states.a.has("attack"),"Transit, then the attack dive")
 check(gone.has(id_a) and not is_instance_valid(a),"After the blast the drone is gone and on_finished was called")
 var sb := strike_of(id_b)
 check(not sb.is_empty(),"The FPV catches the moving target")
 if not sb.is_empty() and caught_at!=Vector3.INF:
  var off := Vector2(sb.point.x-caught_at.x,sb.point.z-caught_at.z).length()
  check(off<4.0,"Leading the 6 m/s target, it strikes %.1f m from it" % off)
 var sc := strike_of(id_c)
 check(fled_from!=Vector3.INF and not sc.is_empty(),"A target lost mid-flight: the drone flies on to where it was")
 if not sc.is_empty():
  check(Vector2(sc.point.x-fled_from.x,sc.point.z-fled_from.z).length()<4.0,"It strikes the last position (%.1f m off)" % Vector2(sc.point.x-fled_from.x,sc.point.z-fled_from.z).length())
 var sd := strike_of(id_d)
 check(states.d.has("transit") and states.d.has("search") and states.d.has("attack"),"Search: transit to the area, search pattern, attack")
 check(top.d>=28.0,"It searches high, 30–60 m (top %.1f m)" % top.d)
 check(not sd.is_empty() and sd.collider==hull and sd.kind=="frag","It finds the vehicle and strikes it: the collider is the hull")
 if not sd.is_empty():
  var aim: Vector3=hull.global_position+Vector3(0,0.3,0)
  check(sd.point.distance_to(hull.global_position)<4.0,"The strike point is on the hull (%s)" % str(sd.point-hull.global_position))
  check(rad_to_deg(asin(-sd.direction.y))>=25.0,"A steep dive onto the vehicle: %.0f°" % rad_to_deg(asin(-sd.direction.y)))
 for node in [moving,fleeing,hull]:node.queue_free()
 await frames(2)

 # --- Shot down ---------------------------------------------------------------
 var shot: Node3D=bot_fpv(ground(60,140))
 shot.autopilot_point(ground(60,-150))
 t=0.0
 while t<12.0 and shot.global_position.y<16.0:
  await physics_frame;t+=1.0/60.0
 check(shot.flying(),"In the air under power it is what the enemy shoots at")
 # Head-on from below ahead of it: the round meets it whatever the timing.
 var muzzle: Vector3=shot.global_position+shot.velocity.normalized()*15.0+Vector3.DOWN*1.5
 game.ballistics.launch(muzzle,muzzle.direction_to(shot.global_position),"ak74",68,player)
 for i in range(30):
  await physics_frame
  if shot.health<=0:break
 check(shot.health<=0 and shot.downed>0 and shot.state=="falling" and not shot.flying(),"One 5.45 round brings it down: it falls")
 check(shot.alarm()=="ДРОН ЗБИТО","Shot down: the alarm says so")
 var shot_id := shot.get_instance_id()
 t=0.0
 while t<10.0 and not gone.has(shot_id):
  await physics_frame;t+=1.0/60.0
 var fell := strike_of(shot_id)
 print("Shot-down FPV: %s after %.1f s" % ["warhead went off" if not fell.is_empty() else "broke up, a dud",t])
 check(gone.has(shot_id),"It comes down and is finished (blown up or a dud)")
 if is_instance_valid(shot):shot.queue_free()

 # --- Bot pilot killed ----------------------------------------------------------
 var operator_bot: Node3D=dummy(ground(0,160),"dead")
 var orphan: Node3D=bot_fpv(ground(0,150),"heat",operator_bot)
 orphan.autopilot_point(ground(0,-150))
 await frames(240)
 check(orphan.armed and orphan.flying(),"Flying while its pilot is alive")
 operator_bot.dead=true
 await frames(30)
 check(orphan.state=="falling" and orphan.armed,"Pilot killed: nobody flies it, it goes on a moment")
 await frames(80)
 check(not orphan.armed,"Then its motors stop and it falls")
 operator_bot.queue_free()
 await frames(2)
 check(not is_instance_valid(orphan) or orphan.is_queued_for_deletion(),"Its pilot gone with the match, the drone goes too")

 # --- Link ----------------------------------------------------------------------
 var link: Node3D=bot_fpv(ground(0,150))
 link.home=Vector3(0,game.district.ground_height(Vector3.ZERO),190)
 var samples := {}
 for probe in [["near",Vector3(0,60,-100)],["far",Vector3(0,60,-1800)],["beyond",Vector3(0,60,-2700)],["far_low",Vector3(0,1.5,-1800)]]:
  link.global_position=probe[1]
  link.link_timer=0.0;link.update_link(0.0)
  samples[probe[0]]=[link.video,link.control]
 print("Link video/control: ",samples)
 check(samples.near[0]>0.9 and samples.far[0]<samples.near[0] and samples.far[0]>0.2,"The picture weakens with distance (%.2f → %.2f at 1.9 km)" % [samples.near[0],samples.far[0]])
 check(samples.beyond[0]<0.01 and samples.beyond[1]>0.1,"Past ~2.5 km no picture, the 900 MHz control still there")
 check(samples.far_low[0]<samples.far[0]*0.75,"Low over the ground far out the Fresnel zone is in the soil: %.2f against %.2f" % [samples.far_low[0],samples.far[0]])
 var wall: Node3D=dummy(Vector3(0,10,100),"destroyed",true)
 var slab := CollisionShape3D.new();slab.shape=BoxShape3D.new();slab.shape.size=Vector3(40,20,1);wall.add_child(slab)
 await frames(2)
 link.global_position=Vector3(0,6,-100)
 link.link_timer=0.0;link.update_link(0.0)
 check(link.video<0.15 and link.control>0.3,"Behind a building the 5.8 GHz picture is gone (%.2f), the control link holds (%.2f)" % [link.video,link.control])
 wall.queue_free();link.queue_free()
 await frames(2)

 # --- The player's FPV ----------------------------------------------------------
 var rig: FieldRig=player.field_rig
 check(player.backpack.count("fpv_heat")==2 and player.backpack.count("fpv_frag")==1,"Three FPVs in the pack")
 rig.toggle_fpv()
 check(rig.mode=="access" and rig.kind=="fpv_heat","Y: reach into the pack for the first FPV")
 rig.tick(3.3)
 check(not is_instance_valid(rig.drone) or not (rig.drone is FPV),"Still in the pack while the hands are in it")
 rig.tick(0.2)
 check(rig.mode=="fpv_place","Out of the pack, being set down")
 rig.tick(1.05)
 check(rig.mode=="goggles" and rig.drone is FPV and rig.drone.state=="ground","On the ground in front of him, the goggles go on")
 var mine: Node3D=rig.drone
 check(player.backpack.count("fpv_heat")==2,"Not spent until it takes off")
 await frames(30)
 check(mine.velocity.length()<0.3 and mine.landed,"Set down, it lies still (%.2f m/s)" % mine.velocity.length())
 rig.tick(1.3)
 check(rig.mode=="drone" and mine.piloting and mine.camera.current,"Goggles on: the drone's camera")
 check(is_instance_valid(mine.goggles) and not game.hud.visible,"The goggles' picture and OSD replace the HUD")
 check(not game.drone_feed.visible,"No wrist display for an FPV")
 Input.action_press("jump");await frames(80);Input.action_release("jump")
 await frames(90)
 check(mine.launched() and mine.armed and mine.global_position.y>player.global_position.y+3.0,"Space: it climbs (%.1f m)" % (mine.global_position.y-player.global_position.y))
 check(player.backpack.count("fpv_heat")==1,"Taken off: spent, out of the pack")
 var y0: float=mine.global_position.y
 Input.action_press("forward");await frames(90)
 var forward_speed: float=-(Basis(Vector3.UP,mine.yaw).inverse()*mine.velocity).z
 check(forward_speed>7.0 and mine.att_pitch>0.4,"W: it leans into it and speeds up (%.1f m/s, %.0f°)" % [forward_speed,rad_to_deg(mine.att_pitch)])
 Input.action_release("forward");await frames(30)
 check(mine.velocity.length()>5.0,"Sticks released: momentum carries it on (%.1f m/s)" % mine.velocity.length())
 check(absf(mine.global_position.y-y0)<4.0,"The throttle hand holds the height (%.1f m)" % (mine.global_position.y-y0))
 check(mine.warhead_armed,"Away from the take-off point the warhead is armed")
 rig.toggle_fpv()
 await frames(2)
 check(rig.mode=="" and not is_instance_valid(rig.drone) and not mine.piloting and player.camera.current,"Y again: goggles off, back to his own eyes")
 check(game.hud.visible and not is_instance_valid(mine.goggles),"The HUD is back")
 check(mine.armed and mine.state=="falling","Unflown, it goes on a moment")
 await frames(90)
 check(is_instance_valid(mine) and not mine.armed,"Then the motors stop and it falls")
 var mine_id := mine.get_instance_id()
 mine.impact_handler=record
 mine.on_finished=func():gone[mine_id]=true
 t=0.0
 while t<10.0 and not gone.has(mine_id):
  await physics_frame;t+=1.0/60.0
 check(gone.has(mine_id),"It comes down and is finished")

 # Second one: the switch on the transmitter sets it off in the air, through
 # the real blast system.
 rig.toggle_fpv();rig.tick(3.5);rig.tick(1.05);rig.tick(1.3)
 var second: Node3D=rig.drone
 check(rig.mode=="drone" and second is FPV,"The second FPV in the goggles")
 Input.action_press("jump");await frames(70);Input.action_release("jump")
 Input.action_press("forward");await frames(150);Input.action_release("forward")
 var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 var blasts_before: int=game.blasts.detonations
 rig.drone.handle_input(click)
 await frames(2)
 check(game.blasts.detonations==blasts_before+1 and not is_instance_valid(second),"LMB: air burst through BlastSystem.warhead, the drone is gone")
 check(rig.mode=="" and player.camera.current and game.hud.visible,"The goggles come off by themselves")

 # Third one: goggles off before take-off puts it back in the pack.
 rig.toggle_fpv();rig.tick(3.5);rig.tick(1.05);rig.tick(1.3)
 var third: Node3D=rig.drone
 check(rig.mode=="drone" and third is FPV and third.warhead=="frag","The frag FPV in the goggles, on the ground")
 rig.toggle_fpv()
 await frames(2)
 check(rig.mode=="stow" and not is_instance_valid(third) and player.backpack.count("fpv_frag")==1,"Y before take-off: back into the pack, nothing spent")
 rig.tick(2.3)
 check(rig.mode=="","Stowed")

 print("FAIL: " if failed else "PASS: ",checks," FPV kamikaze drone checks")
 game.queue_free()
 await process_frame
 quit(1 if failed else 0)
