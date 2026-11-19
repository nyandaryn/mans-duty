extends SceneTree
# The BMP-2: transmission figures, the driver bot on the highway, the yoke
# (no neutral turn, the first-stage radius), the radio, the squad commands of
# the player-driver, and the mechanized deployment of the great assault; the
# driver's panel and prisms, the passenger inside and in the hatch with his
# rifle, the receiver a bot driver keeps on, fences under the hull.
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
 seed(190311)
 # Road speeds at the governed 2600 rpm after the manual.
 var expected:=[10.6,19.6,29.1,43.3,65.0]
 for i in range(5):
  var kmh:=BmpVehicle.gear_speed(2+i,2600.0)*3.6
  check(absf(kmh-expected[i])<1.0,"Gear %d: %.1f km/h at 2600 rpm (manual %.1f)" % [i+1,kmh,expected[i]])
 check(BattleMode.SIZES.all(func(n):return n%BattleMode.SQUAD==0),"Battle sizes are whole BMP crews")
 await great_assault()
 await player_driver()
 print("PASS" if not failed else "FAILED"," checks=",checks)
 quit(1 if failed else 0)

# --- The column of the great assault, the player riding in the lead ----------
func great_assault() -> void:
 var game=await new_game()
 game.set_player_class("rifleman");game.battle_size=27;game.selected_map=BattleMap.ID;game.start_match()
 var battle: BattleMode=game.battle
 check(battle.mech.size()==3,"27 attackers: three BMPs (%d)" % battle.mech.size())
 var full:=true
 for squad in battle.mech:
  full=full and squad.vehicle.crew.size()==2 and squad.vehicle.aboard.size()==BmpVehicle.SEATS and squad.state=="wait"
  var out:=squad.vehicle.global_position.distance_to(Vector3.ZERO)
  full=full and out>1500.0 and out<2100.0
 check(full,"Each BMP waits 1.5–2 km out under the tree belt with the driver, the gunner and seven men")
 check(game.bmp.seat=="commander" and game.player_vehicle()==battle.mech[0].vehicle,"The player rides in the commander's hatch of the lead vehicle")
 await process_frame;await process_frame
 var ride: BmpVehicle=battle.mech[0].vehicle
 check(game.bmp.cockpit.visible and game.bmp.cockpit.view()=="commander" and game.player_sheltered(),"The passenger looks out through the TKN-3B and the prisms, inside the armour")
 check(ride.radio_on and ride.radio_player.playing,"With a bot at the levers the receiver plays")
 var managed: Array=game.allies.filter(func(a):return a.get_meta("battle_managed",false))
 check(managed.size()==27,"Every attacker is in a vehicle (%d)" % managed.size())
 # The march: the lead vehicle takes the highway at a march pace and stays on it.
 var lead: MechSquad=battle.mech[0]
 var fastest:=0.0;var off:=0.0
 # Halfway the passenger stands up in the hatch with his rifle.
 var pinned_error:=0.0;var pinned_speed:=0.0
 while game.elapsed<75.0:
  await process_frame
  fastest=maxf(fastest,lead.vehicle.speed()*3.6)
  if lead.state=="march" and lead.driver.progress>40.0:
   off=maxf(off,lead.driver.locate(lead.vehicle.global_position,lead.driver.progress-20.0,lead.driver.progress+20.0).y)
  if game.elapsed>45.0 and not game.bmp.head_out:game.bmp.set_head_out(true)
  elif game.bmp.head_out:
   pinned_error=maxf(pinned_error,game.player.camera.global_position.distance_to(game.bmp.hatch_point()))
   pinned_speed=maxf(pinned_speed,lead.vehicle.speed()*3.6)
 var head_hitbox: Area3D=game.player.head_area
 check(game.bmp.head_out and game.player.anchor.is_valid() and root.get_camera_3d()==game.player.camera and not game.player_sheltered() and head_hitbox.collision_layer!=0 and game.bmp.cockpit.view()=="","V: head and shoulders out of the hatch with the rifle, exposed")
 check(pinned_error<0.05 and pinned_speed>20.0,"The eyes stay in the hatch on the march (%.3f m at %.0f km/h)" % [pinned_error,pinned_speed])
 game.bmp.set_head_out(false)
 check(not game.bmp.head_out and not game.player.anchor.is_valid() and game.player_sheltered() and head_hitbox.collision_layer==0,"V again: back inside under armour")
 print("MARCH fastest=",snappedf(fastest,0.1)," km/h off_route=",snappedf(off,0.1)," lead=",lead.state," second=",battle.mech[1].state," left=",roundi(lead.driver.remaining()))
 check(lead.state=="march" and fastest>35.0,"The column leaves on the order and marches on the highway (%.0f km/h)" % fastest)
 check(off<4.0,"The driver bot keeps to the road (%.1f m off)" % off)
 check(battle.mech[1].state=="march","The next vehicle follows in column")
 var gap:=lead.vehicle.global_position.distance_to(battle.mech[1].vehicle.global_position)
 check(gap>25.0,"Column interval kept (%.0f m)" % gap)
 check(lead.aboard().size()==BmpVehicle.SEATS,"The troops stay aboard on the march")
 # A fence of the village yards gives under the bow.
 var fence: DestructibleSurface=null
 for body in game.district.find_children("*","StaticBody3D",true,false):
  if body.has_meta("fence_mesh"):fence=body;break
 check(fence!=null and BmpVehicle.crushable(fence),"The village yards have fences a BMP flattens")
 if fence!=null:
  var instance: MeshInstance3D=fence.get_meta("fence_mesh")
  var mesh: ColorMesh=instance.get_meta("color_mesh")
  var span: Vector2i=fence.get_meta("fence_range")
  var ram:=BmpVehicle.new();game.world_root.add_child(ram);ram.setup(game,"9")
  var at:=fence.global_position+Vector3(0,0,BmpArt.HALF+0.3)
  at.y=game.district.ground_height(at)
  ram.global_transform=Transform3D(Basis.IDENTITY,at);ram.freeze=true
  await physics_frame;await physics_frame
  ram.linear_velocity=Vector3(0,0,-4.0);ram.ram_clock=0.0;ram.ram()
  check(fence.breaking and fence.collision_layer==0 and mesh.vertices[span.y-1]==mesh.vertices[span.x],"Rammed at 15 km/h the fence falls: no collider, its panels gone from the mesh")
 game.queue_free();await process_frame

# --- The player's own vehicle on a regular map --------------------------------
func player_driver() -> void:
 var game=await new_game()
 game.selected_map="city";game.set_player_class("bmp");game.start_match()
 # The drills, not a fight: the enemy of the map stays out of it.
 for bot in game.bots:bot.process_mode=Node.PROCESS_MODE_DISABLED;bot.global_position+=Vector3(0,-300,0)
 await physics_frame
 var cmd: BmpCommand=game.bmp
 var v: BmpVehicle=cmd.vehicle;var squad: MechSquad=cmd.squad
 check(PlayerClass.allies("bmp")==8 and game.allies.size()==8,"The driver's squad: a gunner and seven men")
 check(cmd.seat=="driver" and v.crew.size()==1 and v.aboard.size()==7,"The player starts in the driver's seat, the squad aboard")
 check(not v.running and not v.master,"The engine is cold until the driver starts it")
 await process_frame
 check(cmd.cockpit.view()=="driver_open" and cmd.instruments.visible,"Hatch open: head out, a line of the main readings")
 v.toggle_hatch();await process_frame;await process_frame
 check(cmd.cockpit.visible and cmd.cockpit.view()=="driver" and not cmd.instruments.visible and absf(v.seat_camera.fov-BmpCommand.PRISM_FOV)<0.1,"Hatch shut: the three TNPO-170A and the instrument panel")
 v.toggle_hatch()
 # Radio: no power without the battery switch.
 v.toggle_radio()
 check(not v.radio_on,"No radio without the battery switch")
 v.toggle_master();v.toggle_radio()
 check(v.radio_on and v.radio_player.playing and v.radio_player.stream!=null,"The receiver plays «%s»" % BmpVehicle.RADIO_TRACKS[0][1])
 v.toggle_radio()
 # The yoke in neutral: the BMP-2 has no neutral turn.
 cmd.seat="";v.seat="driver"
 game.player.global_position=v.global_position+Vector3(40,5,0)
 v.clutch_pedal=1.0;v.begin_crank()
 await frames(150)
 v.starter=false
 check(v.running,"The engine starts on the starter")
 check(v.engine_sound.stream==GradAudio.cache.get("bmp_engine") and v.engine_sound.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"The engine sound is the recorded UTD-20, looped")
 await frames(30)
 check(v.volts>26.0 and v.oil_pressure>1.5 and absf(v.steady_rpm()-v.rpm())<120.0,"The panel: generator %.1f V, oil %.1f kgf/cm², tachometer %d rpm" % [v.volts,v.oil_pressure,roundi(v.steady_rpm())])
 v.parking=false;v.clutch_pedal=0.0;v.gear=BmpVehicle.NEUTRAL;v.throttle=1.0
 var yaw:=v.rotation.y
 for i in range(180):
  v.yoke_input=1.0
  await physics_frame
 check(absf(angle_difference(yaw,v.rotation.y))<0.05,"No turn on the spot in neutral (%.1f°)" % rad_to_deg(absf(angle_difference(yaw,v.rotation.y))))
 # First gear, the yoke held in the first stage: about a 7 m radius.
 v.throttle=0.0;v.yoke_input=0.0
 await frames(60)
 v.clutch_pedal=1.0;await frames(20);v.gear=2;await frames(10)
 v.throttle=0.7
 while v.clutch_pedal>0.0:
  v.clutch_pedal=maxf(0.0,v.clutch_pedal-0.015);await physics_frame
 await frames(90)
 yaw=v.rotation.y
 var travelled:=0.0
 for i in range(120):
  v.yoke=0.7;v.yoke_input=0.0
  var before:=v.global_position
  await physics_frame
  travelled+=Vector2(v.global_position.x-before.x,v.global_position.z-before.z).length()
 var turned:=absf(angle_difference(yaw,v.rotation.y))
 var radius:=travelled/maxf(turned,0.001)
 print("TURN radius=",snappedf(radius,0.1)," turned=",snappedf(rad_to_deg(turned),0.1))
 check(radius>4.0 and radius<12.0,"First stage of the steering: radius %.1f m (about 7)" % radius)
 # Back to standing, then the squad commands.
 v.throttle=0.0;v.clutch_pedal=1.0;v.brake_pedal=1.0
 await frames(180)
 v.gear=BmpVehicle.NEUTRAL;v.clutch_pedal=0.0
 cmd.seat="driver"
 squad.order_dismount()
 await frames(60*8)
 check(squad.state=="guard" and squad.aboard().is_empty() and squad.on_foot().size()==7,"«Десант»: seven men out through the rear doors")
 var behind:=0
 for actor in squad.on_foot():
  if v.to_local(actor.global_position).z>0.0:behind+=1
 check(behind>=5,"They take up the defence behind the stern (%d of 7)" % behind)
 squad.order_mount()
 await frames(60*12)
 check(squad.state=="mounted" and squad.aboard().size()==7,"«По місцях»: all seven back aboard")
 # Out one by one through the doors (0.7 s each), then into the file.
 squad.order_file()
 await frames(60*15)
 var near:=0
 var men:=squad.on_foot()
 for i in range(men.size()):
  if men[i].global_position.distance_to(squad.file_slot(i))<5.0:near+=1
 check(squad.state=="file" and near>=5,"«За БМП»: the file forms behind the hull (%d of %d in place)" % [near,men.size()])
 squad.order_assault(v.global_position-v.global_basis.z*40.0,-v.global_basis.z)
 await frames(30)
 check(squad.on_foot().all(func(a):return a.order=="assault" and not a.get_meta("mech_control",false)),"«Штурм розсипом»: every man storms his own point")
 # Leaving and taking the seat again.
 cmd.leave()
 check(cmd.seat=="" and game.player.collision_layer==2 and game.player_vehicle()==null,"The driver gets out")
 game.player.global_position=v.to_global(Vector3(-1.6,0.4,-1.3))
 check(cmd.station_prompt()!="","At the hatch: F takes the driver's seat")
 # A fence in the way gives under the hull.
 var posts:=0
 for body in game.district.find_children("*","StaticBody3D",true,false):
  if body is DestructibleSurface and BmpVehicle.crushable(body):posts+=1
 check(posts>0,"The yards have pieces a BMP can flatten (%d)" % posts)
 game.queue_free();await process_frame
