extends SceneTree

# «Навчання» for the BM-21: the course runs on the Avdiivka map with nobody on
# the field, every step is completed by the real controls of the vehicle,
# chapters start on their own in the right state, the player's loadout comes
# back afterwards. Run with --fixed-fps 60.
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

func step_id() -> String:
 return game.grad_training.current().get("id","")

# Waits until the training leaves the step, up to a time limit.
# Position of a step in the whole course; past steps count as done.
func order(id: String) -> int:
 var n:=0
 for chapter in GradTraining.STEPS:
  for item in chapter:
   if item.id==id:return n
   n+=1
 return -1

func position() -> int:
 var t: GradTraining=game.grad_training
 if not t.running:return 1000
 var n:=0
 for c in range(t.chapter):n+=GradTraining.STEPS[c].size()
 return n+t.step

func passes(id: String, seconds: float=3.0) -> bool:
 if position()>order(id):return true
 if step_id()!=id:
  printerr("  expected step ",id,", the training is at ",step_id());return false
 var limit:=int(seconds*60)
 for i in range(limit):
  if step_id()!=id:return true
  await physics_frame
 return step_id()!=id

func key(code: Key) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
 Input.parse_input_event(event)
 await process_frame
 var up:=InputEventKey.new();up.physical_keycode=code;up.pressed=false
 Input.parse_input_event(up)
 await process_frame

func run():
 seed(4242)
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 check(game.menu.visible and game.main_menu.current=="home","Game opens on the main menu")
 check(game.main_menu.items.size()==6 and game.main_menu.items[2].title=="НАВЧАННЯ","Main menu offers the training")
 game.main_menu.show_screen("training")
 check(game.main_menu.training_screen.visible and game.main_menu.chapter_cards.size()==5,"Training screen lists five chapters")
 # A rifleman with something in the backpack: the training must give it back.
 game.set_player_class("rifleman")
 game.loadout_bag.equipped=true
 game.loadout_bag.add("medkit")
 var bag_before: Dictionary=game.loadout_bag.serialize()
 game.selected_map="forest_01"
 await game.begin_training(0)
 var grad: GradCommand=game.grad
 var t: GradTraining=game.grad_training
 var v: GradVehicle=grad.vehicle
 check(game.running and game.training=="grad" and game.player_class=="grad","Training runs as the BM-21 commander")
 check(game.bots.is_empty() and game.allies.is_empty() and not game.battle.active,"Nobody else on the training ground")
 check(grad.training and is_instance_valid(v) and v.remaining()==40,"Loaded launcher at the tree line")
 await frames(30)
 check(t.visible and step_id()=="cab","Training card shows the first step")
 check(not t.marker().is_empty(),"Marker leads to the driver's door")

 # --- Chapter 1: march ------------------------------------------------------
 game.player.global_position=v.to_global(Vector3(-1.6,0.2,-1.35))
 check(grad.interact() and grad.seat=="driver","F at the door: in the cab")
 check(await passes("cab"),"Step done when the driver sits down")
 await key(KEY_I)
 check(v.ignition and await passes("ignition"),"I — ignition")
 v.begin_crank()
 for i in range(120):
  v.starter=true;await physics_frame
 v.starter=false
 check(v.running and await passes("start"),"X — the engine runs")
 await key(KEY_SPACE)
 check(not v.handbrake and await passes("release"),"SPACE — parking brake off")
 v.clutch_pedal=1.0;v.shift(1)
 check(await passes("first"),"First gear with the clutch down")
 v.throttle=0.4
 for i in range(120):
  v.clutch_pedal=1.0-i/120.0;await physics_frame
 v.throttle=0.7
 check(await passes("move",6.0),"The launcher moves off (%.1f m/s)" % v.speed())
 v.throttle=0;v.brake_pedal=1
 await frames(120)
 v.brake_pedal=0
 check(step_id()=="drive" and t.readout_text("drive").begins_with("До ВП"),"Card counts the distance to the firing position")
 t.skip()
 check(step_id()=="park","F6 drives to the position and stops side-on to the target")
 await frames(120)
 check(t.in_sector(t.ideal().relative),"Target in the left sector (%.0f°)" % t.ideal().relative)
 check(await passes("park"),"Parked on the brake: the chapter is complete")
 check(t.chapter==1 and t.banner.visible,"Banner announces the next chapter")
 check(0 in GradTraining.completed(game),"Chapter progress is recorded")

 # --- Chapter 2: travel to action ---------------------------------------------
 v.clutch_pedal=1.0;v.toggle_power_takeoff();v.clutch_pedal=0
 check(await passes("pto"),"Power take-off engaged")
 v.hand_throttle=0.35
 check(await passes("throttle",5.0),"Hand throttle feeds the laying drive (%.0f rpm)" % v.rpm())
 v.toggle_shields()
 check(await passes("shields"),"Shields down")
 grad.leave()
 check(await passes("exit"),"Out of the cab")
 for id in ["valve","lock","cover","gunner"]:
  for item in grad.stations():
   if item.id==id:game.player.global_position=item.point-Vector3.UP*1.0
  check(grad.nearest_station().get("id","")==id,"Standing at the %s station" % id)
  check(grad.interact(),"F starts the work at the %s station" % id)
  if id=="cover":
   # The tablet, not the infantry map of the assault area, during the work.
   await key(KEY_M)
   check(grad.hud.open_panel()=="tablet" and not game.topo_map.visible,"M during the work opens the tablet")
   check(game.player.field_rig.mode=="work","…and the work goes on")
   await key(KEY_M)
   check(grad.hud.open_panel()=="" and not game.topo_map.visible,"M again closes it")
  await frames(60*21)
 check(t.chapter==2,"Valve, lock, cover and sight bracket: the chapter is complete (%s)" % step_id())

 # --- Chapter 3: drone recon --------------------------------------------------
 for item in grad.stations():
  if item.id=="commander":game.player.global_position=item.point-Vector3.UP*1.0
 check(not t.marker().is_empty(),"Marker shows the commander's door")
 grad.interact()
 check(await passes("commander"),"Commander seated")
 grad.request_drone()
 check(await passes("drone"),"The observer prepares the drone")
 await frames(60*13)
 grad.begin_piloting()
 check(await passes("pilot"),"Flying the drone")
 var aim:=t.target_point()
 grad.drone.global_position=aim+Vector3(0,70,0)
 grad.drone.camera_pitch=-1.5
 check(await passes("find"),"Drone over the target area")
 await frames(10)
 grad.mark_target()
 check(await passes("mark"),"Laser rangefinder marks the target (%s)" % t.readout_text("mark"))
 grad.end_piloting()
 check(await passes("back"),"Back at the panel: chapter complete")
 check(t.chapter==3,"Fourth chapter begins")

 # --- Chapter 4: firing data and laying ------------------------------------------
 grad.hud.toggle("tablet")
 check(await passes("tablet"),"Tablet open")
 await key(KEY_ENTER)
 check(await passes("read"),"ENTER: data written down")
 grad.hud.close_all();grad.enter("gunner")
 check(await passes("gunner"),"At the sight")
 var want:=t.ideal()
 v.deflection=3000.0
 var deflection_steps:=0
 while absf(wrapf(v.deflection-roundf(want.deflection),-3000,3000))>0.5 and deflection_steps<200:
  var diff:=wrapf(roundf(want.deflection)-v.deflection,-3000,3000)
  var step:=100.0 if absf(diff)>=100 else (10.0 if absf(diff)>=10 else 1.0)
  v.deflection=fposmod(v.deflection+signf(diff)*step,6000.0);deflection_steps+=1
 check(await passes("deflection"),"Deflection set (%s)" % GradBallistics.mils_text(v.deflection))
 v.sight_setting=want.sight
 check(await passes("sight"),"Sight set from the table")
 v.level_setting=want.level
 check(await passes("level"),"Level set from the angle of site")
 v.boussole=true
 for i in range(8):
  v.azimuth-=t.needle()*0.06;v.apply_launcher()
 check(await passes("boussole"),"Needle on the index")
 for i in range(8):
  v.elevation-=v.bubble_mils()*0.06;v.azimuth-=t.needle()*0.06;v.apply_launcher()
 check(await passes("bubble"),"Bubble centred: chapter complete")
 check(t.chapter==4 and absf(wrapf(v.package_bearing()-want.bearing,-3000,3000))<2.0,"Package on the target bearing")

 # --- Chapter 5: launch, correction, march order ----------------------------
 grad.leave()
 grad.enter("commander")
 v.toggle_battery()
 check(await passes("console"),"Panel powered")
 v.set_mode(1);v.wind_program()
 check(await passes("arm"),"АВТ and the programme wound")
 grad.lever_key=true
 await frames(110)
 grad.lever_key=false
 await frames(5)
 var sighting:=v.fired
 check(sighting>=3 and sighting<=6 and await passes("sighting"),"Sighting series of %d rockets" % sighting)
 check(await passes("report",60.0),"Observer reports the bursts (%s)" % (grad.radio_log[0] if not grad.radio_log.is_empty() else ""))
 check("Ц-1" in grad.radio_log[0],"The report refers to the marked target Ц-1")
 var fix:=t.corrected()
 check(fix.has("sight") and fix.has("deflection"),"Correction computed from the report")
 grad.leave();grad.enter("gunner")
 v.sight_setting=fix.sight;v.deflection=fix.deflection
 for i in range(10):
  v.azimuth-=t.needle()*0.06;v.elevation-=v.bubble_mils()*0.06;v.apply_launcher()
 check(await passes("correct"),"Corrections applied and laid again")
 grad.leave();grad.enter("commander")
 v.wind_program()
 grad.lever_key=true
 await frames(60*20)
 grad.lever_key=false
 check(await passes("salvo",40.0),"Salvo: %d rockets left, ОП-2 %s" % [v.remaining(),"destroyed" if grad.strongpoints[1].destroyed else "standing"])
 check(grad.counter_fire.is_empty(),"No counter-battery fire on the training ground")
 grad.leave();grad.enter("gunner")
 v.azimuth=0;v.elevation=0;v.apply_launcher()
 grad.leave()
 v.toggle_lock();v.toggle_springs()
 check(await passes("stow"),"Package stowed, springs in travel")
 t.skip()
 await frames(5)
 check(not t.running and game.result_panel.visible and not game.running,"Course finished: results on the screen")
 check("ЗАВЕРШЕНО" in game.result_title.text and "ЦЕНТР РОЗРИВІВ" in game.result_stats.text,"Results name the course and the burst centre")
 check(GradTraining.completed(game)==[0,1,2,3,4],"All five chapters recorded")
 print(game.result_stats.text.replace("\n"," | "))
 game.to_menu("training")
 check(game.training=="" and game.player_class=="rifleman" and game.selected_map=="forest_01","Loadout and operation come back after the training")
 check(game.loadout_bag.serialize()==bag_before,"Backpack is the same as before")
 check(game.main_menu.current=="training" and game.main_menu.training_screen.visible,"Back on the training screen")

 # --- Chapters on their own --------------------------------------------------
 await game.begin_training(3)
 v=grad.vehicle
 check(step_id()=="tablet" and grad.seat=="commander","Chapter 4 starts in the commander's seat")
 check(not v.travel_lock and not v.cover_on and v.springs_locked and v.bracket_up and v.power_takeoff,"Chapter 4: launcher already in action")
 check(t.marked(),"Chapter 4: target already marked")
 check(t.flat_distance(v.global_position,GradCommand.FIRING_AREA)<5.0,"Chapter 4: on the firing position")
 game.set_pause(true)
 await process_frame
 check(game.pause_panel.visible and not t.visible,"Pause hides the training card")
 check("НАВЧАННЯ" in game.pause_note.text,"Pause says the training is paused")
 game.set_pause(false)
 await game.begin_training(4)
 v=grad.vehicle
 await frames(150)
 check(step_id()=="console" and t.laid(),"Chapter 5 starts laid on the target")
 check(t.title.text==t.current().title and t.keys_holder.get_child_count()>0,"Card shows the first step once the position is ready")
 grad.hud.toggle("tablet")
 await frames(3)
 check(t.layout=="compact_left" and t.card.get_rect().end.y>t.size.y-30 and t.card.get_rect().position.x<40 and t.body.visible and not t.footer.visible,"Over the tablet the card is compact at the bottom left, off the data column, with the step's text")
 grad.hud.toggle("console")
 await frames(3)
 check(t.layout=="console" and t.card.get_rect().position.y<40 and t.body.visible,"With the fire control panel it stays on top")
 check(t.card.get_rect().end.y<=grad.hud.panels.console.get_rect().position.y+4,"…above the panel (%d / %d)" % [t.card.get_rect().end.y,grad.hud.panels.console.get_rect().position.y])
 grad.hud.close_all()
 await frames(3)
 check(t.layout=="full" and t.footer.visible,"Full card again with the panels closed")
 check(absf(wrapf(v.package_bearing()-t.ideal().bearing,-3000,3000))<2.5,"Chapter 5: package on the target bearing")
 t.skip();t.skip()
 check(step_id()=="sighting","F6 powers and arms the panel")
 t.skip()
 await frames(150)
 check(step_id()=="report" and v.fired>=4,"F6 fires the sighting series (%d)" % v.fired)
 t.skip()
 check(step_id()=="report","The observer's report cannot be skipped")
 game.to_menu()
 check(game.training=="" and game.player_class=="rifleman" and game.main_menu.current=="training","Pause menu exit returns the loadout")

 # --- Front end ----------------------------------------------------------------
 game.main_menu.show_screen("home")
 game.main_menu.show_screen("campaign")
 game.main_menu.show_screen("loadout")
 game.main_menu.back()
 check(game.main_menu.current=="campaign","ESC goes back one screen")
 game.main_menu.back()
 check(game.main_menu.current=="home","…and then home")
 game.select_mission("forest_01")
 check(game.main_menu.current=="loadout" and game.selected_map=="forest_01","Choosing a mission opens the loadout")
 print("checks: ",checks)
 print("PASS" if not failed else "FAILED")
 quit(1 if failed else 0)
