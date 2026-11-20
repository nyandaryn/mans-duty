extends SceneTree

# «Навчання» for the BMP-2 driver: the course runs on the route of the column
# with nobody on the field. Start-up, moving off and the closed hatch are done
# with the real keys, the long drives with F6; the squad gets out and back in
# on the real commands. A chapter started on its own puts the vehicle where it
# begins. Run with --fixed-fps 60.
var checks := 0
var failed := false
var game: Node3D

func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
 else:print("ok   ",message)

func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func course() -> BmpTraining:return game.courses["bmp"]
func step_id() -> String:return course().current().get("id","")

# Waits until the course leaves the step, up to a time limit.
func passes(id: String, seconds: float=3.0) -> bool:
 if step_id()!=id:
  printerr("  expected step ",id,", the course is at ",step_id());return false
 for i in range(int(seconds*60)):
  if step_id()!=id:return true
  await physics_frame
 return step_id()!=id

func hold(code: Key, down: bool) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down
 Input.parse_input_event(event)
 await process_frame

func key(code: Key) -> void:
 await hold(code,true);await hold(code,false)

func skip() -> void:
 await key(KEY_F6)
 await frames(2)

func started() -> void:
 for i in range(1200):
  if game.running and course().running and not game.launching:break
  await process_frame
 await frames(30)

func run():
 seed(5151)
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("rifleman")
 check(game.COURSE_IDS.has("bmp") and game.courses.has("bmp"),"The BMP course is in «Навчання»")
 check(BmpTraining.STEPS.size()==BmpTraining.CHAPTERS.size(),"Every chapter has its steps")
 game.begin_training(0,"bmp")
 await started()
 var cmd: BmpCommand=game.bmp
 var v: BmpVehicle=cmd.vehicle
 check(game.player_class=="bmp" and game.selected_map==BattleMap.ID,"The course borrows the driver class and the Avdiivka map")
 check(is_instance_valid(v) and v.crew.size()==1 and v.aboard.size()==7 and not v.running,"A cold BMP with the gunner and seven men aboard")
 check(v.global_position.distance_to(Vector3.ZERO)>1500.0 and game.bots.is_empty(),"It waits at the column's parking, nobody on the field")
 # Chapter 1 with the real controls.
 check(cmd.station_prompt()!="","Beside the hatch: F takes the driver's seat")
 await key(KEY_F)
 check(await passes("seat"),"F — the driver's seat")
 await key(KEY_I)
 check(await passes("master"),"I — the battery switch")
 Input.action_press("aim")
 check(await passes("panel",2.0),"RMB — the panel up close")
 Input.action_release("aim")
 await hold(KEY_SHIFT,true);await hold(KEY_X,true)
 check(await passes("start",4.0),"SHIFT + X — the engine starts")
 await hold(KEY_X,false);await hold(KEY_SHIFT,false)
 check(await passes("gauges",8.0),"Oil pressure up, the generator charging (%.1f kgf/cm², %.1f V)" % [v.oil_pressure,v.volts])
 # Chapter 2: moving off for real, the drive with F6.
 check(course().chapter==1,"Chapter 2 follows")
 await key(KEY_SPACE)
 check(await passes("release"),"SPACE — the parking brake off")
 await hold(KEY_SHIFT,true);await frames(30)
 await key(KEY_E)
 check(await passes("first"),"SHIFT + E — first gear")
 await hold(KEY_W,true)
 await hold(KEY_SHIFT,false)
 check(await passes("move",6.0),"W and the clutch let go — it moves off (%.1f km/h)" % (v.speed()*3.6))
 await hold(KEY_W,false)
 for id in ["second","junction","highway","stop"]:
  check(step_id()==id,"F6 on «%s»" % id)
  await skip()
  if id=="highway":check(course().near(BmpTraining.HIGHWAY,5.0),"F6 carries the vehicle up the highway")
 # Chapter 3: the closed hatch for real.
 check(course().chapter==2,"Chapter 3 follows")
 await key(KEY_V)
 check(await passes("hatch"),"V — the hatch shut")
 await frames(2)
 check(cmd.cockpit.view()=="driver" and cmd.vehicle.interior.station=="driver","Inside the compartment: three TNPO-170A, the panel on the left")
 cmd.look=Vector2(0,-0.05);await frames(2)
 Input.action_press("aim")
 check(await passes("prism",3.0),"RMB on the middle prism — the face at its eyepiece")
 Input.action_release("aim")
 await skip()
 check(await passes("halt",2.0),"F6 puts it on the dismount line, standing")
 await key(KEY_1)
 check(await passes("dismount",40.0),"1 — «Десант»: all seven out (%d aboard)" % cmd.squad.aboard().size())
 await key(KEY_2)
 check(await passes("mount",60.0),"2 — «По місцях»: all back aboard, doors shut")

 await frames(5)
 check(not course().running and game.result_panel.visible,"The course ends on the results screen")
 # A chapter on its own: the vehicle on the highway, engine running.
 game.begin_training(2,"bmp")
 await started()
 v=game.bmp.vehicle
 var at:=Vector2(v.global_position.x,v.global_position.z)
 check(step_id()=="hatch" and at.distance_to(BmpTraining.ROAD_START)<6.0 and v.running and game.bmp.seat=="driver","Chapter 3 alone: on the highway, engine running, at the levers")
 game.to_menu()
 await frames(2)
 check(game.player_class=="rifleman","After the course the player's own class is back")
 print("PASS" if not failed else "FAILED"," checks=",checks)
 quit(1 if failed else 0)
