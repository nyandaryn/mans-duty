extends SceneTree

# «Навчання» for the rifleman, the sniper and the mortarman: the training
# range is built, knock-down targets count real bullets, the steps follow the
# real controls (stance keys, the fire selector, the magazine, the map, the
# mortar), F6 finishes any step, progress is recorded per course and the
# player's loadout comes back. Run with --fixed-fps 60.
var checks := 0
var failed := false
var game: Node3D
var t: RangeCourse

func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
 else:print("ok   ",message)

func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func step_id() -> String:return t.current().get("id","") if t.running else ""

func order(id: String) -> int:
 var n:=0
 for chapter in t.steps():
  for item in chapter:
   if item.id==id:return n
   n+=1
 return -1

func position() -> int:
 if not t.running:return 1000
 var n:=0
 for c in range(t.chapter):n+=t.steps()[c].size()
 return n+t.step

# Waits until the course leaves the step, up to a time limit.
func passes(id: String, seconds: float=3.0) -> bool:
 if position()>order(id):return true
 if step_id()!=id:
  printerr("  expected step ",id,", the course is at ",step_id());return false
 for i in range(int(seconds*60)):
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

# F6 until the course reaches the step (or the chapter ends).
func skip_to(id: String) -> void:
 for i in range(40):
  if not t.running or step_id()==id or position()>order(id):return
  t.skip()
  await frames(2)

# A real bullet from the soldier's eyes at a target; lift aims above the
# centre for the drop at long range. True when the target counted it.
func shoot(id: String, weapon: String, lift: float=0.0) -> bool:
 var target: RangeTarget=t.targets[id]
 for i in range(200):
  if target.up() and target.pivot.rotation.x>-0.05:break
  await physics_frame
 var before:=target.hits
 var size: Vector2=RangeTarget.SIZES[target.kind]
 var aim: Vector3=target.body.global_position+Vector3.UP*(size.y*0.5+lift)
 var origin: Vector3=game.player.global_position+Vector3.UP*(0.3 if game.player.prone else 1.5)
 game.ballistics.launch(origin,aim-origin,weapon,40.0,game.player)
 for i in range(90):
  if target.hits>before:return true
  await physics_frame
 return false

func finish_course() -> void:
 for i in range(60):
  if not t.running:return
  t.skip()
  await frames(2)

func run():
 seed(5151)
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0

 # --- Training screen ----------------------------------------------------------
 game.set_player_class("sniper")
 game.main_menu.show_screen("training")
 var menu=game.main_menu
 check(menu.course_tabs.size()==game.COURSE_IDS.size() and game.COURSE_IDS.size()==8,"Training screen has a tab for every class")
 check(menu.course_pick=="sniper" and menu.chapter_cards.size()==SniperTraining.CHAPTERS.size(),"It opens on the player's own class")
 menu.select_course("mortarman")
 check(menu.chapter_cards.size()==3 and menu.chapter_title.text==MortarTraining.CHAPTERS[0].title,"Mortarman tab lists its chapters")
 menu.select_course("grad")
 check(menu.chapter_cards.size()==5 and menu.chapter_title.text==GradTraining.CHAPTERS[0].title,"BM-21 course is still there")
 menu.select_course("rifleman")
 menu.select_chapter(2)
 check("СТРІЛЕЦЬ · РОЗДІЛ 3 / 5" in menu.chapter_state.text and menu.chapter_steps.get_child_count()>0,"Chapter details follow the picked course")

 # The player's own loadout, to be given back.
 game.set_player_class("sniper")
 game.loadout_bag.equipped=true
 game.loadout_bag.add("ammo_svd")
 var bag_before: Dictionary=game.loadout_bag.serialize()
 game.selected_map="forest_01"

 # --- Rifleman --------------------------------------------------------------
 menu.select_chapter(0)
 await game.begin_training(0,"rifleman")
 t=game.courses.rifleman
 var p: Operator=game.player
 check(game.running and game.training=="rifleman" and game.player_class=="rifleman" and p.current().id=="ak74","Rifleman course: АК-74М in hand")
 check(game.district.map_id==TrainingRange.ID and game.bots.is_empty() and game.allies.is_empty(),"On the training range, nobody else")
 check(t.targets.size()==3 and t.targets.t25.body.has_meta("range_target"),"Three knock-down targets stand")
 check(p.backpack.count("rpo_a")==1 and p.backpack.count("medkit")==1,"РПО-А and a medkit in the pack")
 await frames(30)
 check(t.visible and step_id()=="line" and not t.marker().is_empty(),"Card and marker lead to the firing line")
 Input.action_press("forward")
 var walked:=await passes("line",10.0)
 Input.action_release("forward")
 check(walked,"W walks to the line")
 await key(KEY_CTRL)
 check(await passes("crouch"),"CTRL — crouch")
 await key(KEY_Z)
 check(await passes("prone",2.0),"Z — prone")
 await key(KEY_Z)
 if p.crouched:await key(KEY_CTRL)
 check(await passes("stand",2.0),"Up again")
 p.global_position=TrainingRange.BLOCK+Vector3(-1.3,0.1,0.8)
 Input.action_press("lean_right")
 var leaned:=await passes("lean",2.0)
 Input.action_release("lean_right")
 check(leaned,"E — leaning out by the block")
 check(t.marker().get("caption","")=="СТІНКА","Marker on the low wall")
 p.global_position=TrainingRange.WALL+Vector3(0,0.1,1.0);t.face(TrainingRange.WALL+Vector3(0,0,-10))
 await frames(5)
 await key(KEY_SPACE)
 check(await passes("vault",3.0),"SPACE — over the wall")
 check(t.chapter==1 and 0 in t.done_chapters(),"Chapter 1 recorded")
 await frames(200)
 check(step_id()=="position" and t.marker().get("caption","")=="РУБІЖ","Chapter 2: back to the line")
 t.place(TrainingRange.LINE+Vector3(-2,0,0.6),TrainingRange.TARGETS.t25.point)
 check(await passes("position",1.0),"On the line again")
 Input.action_press("aim")
 var aimed:=await passes("aim",2.0)
 check(aimed,"RMB — aiming")
 var hit:=true
 for i in range(3):hit=hit and await shoot("t25","ak74")
 Input.action_release("aim")
 check(hit and t.targets.t25.hits>=3,"Real bullets knock the 25 m target down (%d)" % t.targets.t25.hits)
 check(await passes("hit25",4.0),"Three hits at 25 m")
 check(t.targets.t25.down_left>0.0 or t.targets.t25.pivot.rotation.x<0.0,"The hit target lies down")
 await key(KEY_B)
 check(await passes("mode") and p.current().mode()=="ОДИН","B — single fire")
 hit=true
 for i in range(3):hit=hit and await shoot("t100","ak74",-0.2)
 check(hit and await passes("hit100",4.0),"Three hits at 100 m")
 await frames(200)
 await key(KEY_T)
 check(await passes("inspect",3.0),"T — magazine check")
 await frames(240)
 t.skip()
 check(step_id()=="rack","F6 swaps the magazine")
 await frames(30)
 await key(KEY_V)
 check(await passes("rack",3.0),"V — the bolt racked")
 await frames(120)
 await key(KEY_I)
 check(await passes("chamber",3.0),"I — chamber check")
 await frames(90)
 hit=true
 for i in range(2):hit=hit and await shoot("t50","ak74")
 check(hit and await passes("hit50",4.0),"Two hits at 50 m: magazines done")
 await frames(200)
 t.skip()
 check(step_id()=="map","Rangefinder step skipped")
 await key(KEY_K)
 if p.field_rig.mode!="":await key(KEY_K)
 await key(KEY_M)
 check(await passes("map"),"M — the map")
 await frames(3)
 check(t.layout=="compact_left" and t.body.visible,"Card goes small over the map, the step's text stays")
 # Left of the sheet where the screen leaves room; the narrowest card where not.
 var sheet_left: float=game.topo_map.get_global_rect().position.x+game.topo_map.sheet_rect().position.x
 var room: float=sheet_left-t.card.get_global_rect().position.x-16.0-38.0
 check(t.card.get_global_rect().end.x<=sheet_left if room>=250.0 else is_equal_approx(t.card_box.custom_minimum_size.x,250.0),"…left of the map sheet, or as narrow as it goes (%d / %d)" % [t.card.get_global_rect().end.x,sheet_left])
 await key(KEY_M)
 await key(KEY_TAB)
 check(await passes("inventory"),"TAB — inventory")
 await frames(3)
 check(t.layout=="compact_left" and t.body.text.contains("TAB") and t.card.get_global_rect().end.x<=game.inventory.get_global_rect().position.x+game.inventory.size.x*CombatInventory.GEAR_LEFT,"Over the inventory the card says how to close it, left of the gear column")
 await key(KEY_TAB)
 await frames(10)
 check(step_id()=="bandage" and p.needs_bandage(),"A wounded arm to dress")
 await key(KEY_H)
 check(await passes("bandage",9.0),"H — the wound dressed")
 await frames(200)
 await key(KEY_4)
 check(await passes("launcher",7.0) or p.launcher.mode=="ready","4 — РПО-А ready")
 if step_id()=="launcher":t.skip()
 await frames(5)
 check(step_id()=="fire" and t.marker().get("caption","")=="БЛІНДАЖ","Marker on the bunker")
 t.skip()
 await frames(5)
 check(not t.running and game.result_panel.visible and "ЗАВЕРШЕНО" in game.result_title.text,"Rifleman course finished")
 check(t.done_chapters().size()==5,"All five rifleman chapters recorded")
 game.to_menu("training")
 check(t.targets.is_empty(),"Targets cleared on the way back to the menu")
 check(game.training=="" and game.player_class=="sniper" and game.selected_map=="forest_01","Own class and map come back")
 check(game.loadout_bag.serialize()==bag_before,"Own backpack comes back")
 check(menu.current=="training","Back on the training screen")

 # --- Sniper -----------------------------------------------------------------
 await game.begin_training(1,"sniper")
 t=game.courses.sniper
 p=game.player
 await frames(30)
 check(game.player_class=="sniper" and p.current().id=="svd","Sniper course: СВД in hand")
 check(step_id()=="measure" and t.flat_distance(p.global_position,TrainingRange.SNIPER)<1.0 and p.prone_requested,"Chapter 2 starts lying on the mat")
 check(t.marker().get("caption","")=="МІШЕНЬ","Marker on the 300 m figure")
 t.skip()
 await frames(5)
 Input.action_press("aim")
 await frames(40)
 check(p.scope_sight.enabled,"RMB — the PSO-1")
 for i in range(2):
  await key(KEY_PAGEUP)
  await frames(40)
 check(await passes("drum") and p.current().scope_zero==300,"PgUp twice — drum on 3")
 Input.action_release("aim")
 hit=false
 for i in range(4):
  if await shoot("s300","svd",0.75):hit=true
  if not t.running or step_id()!="hit300":break
 check(hit,"A real 7.62 bullet hits the figure at 300 m")
 if step_id()=="hit300":t.skip()
 await frames(5)
 check(step_id()=="estimate","Chapter 3: range from the reticle")
 check(t.readout_text("estimate")=="Барабан: 3","Readout shows the drum")
 p.current().scope_zero=500
 check(await passes("estimate"),"Drum on 5")
 await finish_course()
 check(not t.running and game.result_panel.visible and "НА 500 м" in game.result_stats.text,"Sniper course finished with the score")
 check(t.done_chapters()==[1,2],"Chapters 2 and 3 recorded, not the first")
 game.to_menu("training")

 # --- Mortarman ----------------------------------------------------------------
 await game.begin_training(0,"mortarman")
 t=game.courses.mortarman
 var m: MortarTraining=t
 p=game.player
 await frames(30)
 check(game.player_class=="mortarman" and game.ally_count==0 and m.mortar().state=="carried" and game.crew.player_plate,"Mortarman alone with the 2Б14 and the plate")
 check(step_id()=="pit" and t.marker().get("caption","")=="МІНОМЕТ","Marker on the pit")
 m.auto("pit")
 check(await passes("pit"),"In the pit")
 await key(KEY_N)
 await frames(10)
 check(m.mortar().state=="assembling" and step_id()=="deploy","N — the mortar is being set up")
 t.skip()
 await frames(5)
 check(m.mortar().state=="deployed" and step_id()=="sight","F6 finishes the deployment")
 check(game.crew.box_mines_at_mortar()==10,"Ten mines in the box by the mortar")
 game.crew.sight.open()
 check(await passes("sight"),"The sight is open")
 game.crew.sight.close()
 await key(KEY_M)
 check(await passes("map"),"M — the map")
 var d: Dictionary=m.data()
 check(absf(d.distance-TrainingRange.distance(m.mortar().global_position,TrainingRange.POSITION))<0.5 and d.elevation>0,"Firing data for %d m: charge %d, elevation %d, azimuth %d" % [roundi(d.distance),d.charge,d.elevation,d.azimuth])
 var map: TopoMap=game.topo_map
 map.ruler_from=Vector2(TrainingRange.PIT.x,TrainingRange.PIT.z)
 map.ruler_to=Vector2(TrainingRange.POSITION.x,TrainingRange.POSITION.z)+Vector2(4,-3)
 check(await passes("ruler"),"Ruler from the pit to the position")
 var measure: Dictionary=TopoMap.measure(map.ruler_from,map.ruler_to)
 check(absf(measure.distance-d.distance)<12.0,"The ruler gives the range (%d m)" % roundi(measure.distance))
 await key(KEY_M)
 game.crew.sight.open()
 await frames(3)
 check(t.layout=="compact_left" and t.body.visible and t.card.get_global_rect().end.x<=game.crew.sight.sheet.get_global_rect().position.x,"Card goes small over the sight, left of the panel")
 m.mortar().set_charge(d.charge)
 check(await passes("charge"),"Charge that reaches")
 m.mortar().set_azimuth(int(d.azimuth)+2)
 check(await passes("azimuth"),"Azimuth within 0-03")
 m.mortar().set_elevation(int(d.elevation))
 check(await passes("elevation"),"Elevation from the table")
 check(t.chapter==2 and 1 in t.done_chapters(),"Chapter 2 recorded")
 await frames(200)
 m.mortar().relay_left=0.0;m.mortar().reload_left=0.0
 if not game.crew.sight.visible:game.crew.sight.open()
 await key(KEY_SPACE)
 check(await passes("fire",2.0) and m.mortar().shots==1,"SPACE — the first round away")
 check(game.crew.box_mines_at_mortar()==9,"…from the box")
 t.skip()
 check(step_id()=="observe","F6 cannot drop the mine for you")
 var flight:=0
 while step_id()=="observe" and flight<60*40:
  await physics_frame;flight+=1
 check(step_id()=="adjust","The burst is seen after %.1f s" % (flight/60.0))
 check(t.readout_text("adjust").begins_with("Розрив:"),"Card reads the burst: %s" % t.readout_text("adjust"))
 check(m.burst_offset().length()<60.0,"The laid round falls near the position (%.0f m)" % m.burst_offset().length())
 check(m.body_text(t.current()).contains("Переліт — приціл більше"),"Card explains the corrections")
 t.skip()
 await frames(5)
 check(not t.running and game.result_panel.visible and "МІН ВИПУЩЕНО" in game.result_stats.text,"Mortarman course finished")
 check(t.done_chapters().size()==3,"All mortar chapters recorded")
 game.to_menu("training")
 check(game.player_class=="sniper" and game.ally_count==0 or game.player_class=="sniper","Own class after the mortar course")

 # --- A death on the range ends the chapter, not the game --------------------
 await game.begin_training(2,"rifleman")
 t=game.courses.rifleman
 await frames(20)
 check(t.running and step_id()=="inspect","Rifleman chapter 3 on its own")
 game.player.health=0.0
 game.finish(false)
 await frames(3)
 check(game.result_panel.visible and "НАВЧАННЯ ПЕРЕРВАНО" in game.result_title.text and not t.running,"A death stops the course")
 check(t.targets.is_empty(),"…and clears the targets")
 game.to_menu("training")
 check(game.training=="" and game.player_class=="sniper" and game.loadout_bag.serialize()==bag_before,"Loadout back after the stop")

 print("checks: ",checks)
 print("FAIL" if failed else "PASS")
 quit(1 if failed else 0)
