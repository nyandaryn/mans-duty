extends SceneTree

# «Навчання» for the machine gunner, the grenadier and the UAV operator: the
# training screen has nine courses; each new course starts with its class's
# kit on the range, its steps pass on the real state (the PKM's bipod, sight
# and bursts, the box and the belt; the RPG-7's draw, load and the PG-7VL's
# flight onto a hulk, the RPG-22 armed; the FPV out of the pack, its take-off,
# a dive onto the BMP, a frag burst over the position), F6 walks every course
# to the end and the player's own loadout comes back. Run with --fixed-fps 60.
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

func action(name: String) -> void:
 var event:=InputEventAction.new();event.action=name;event.pressed=true
 Input.parse_input_event(event)
 await process_frame
 var up:=InputEventAction.new();up.action=name;up.pressed=false
 Input.parse_input_event(up)
 await process_frame

# A real bullet from the soldier's eyes at a target, lifted for the drop.
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

# Shoots with growing lift until the target counts a hit.
func shoot_at_range(id: String, lifts: Array) -> bool:
 for lift in lifts:
  if await shoot(id,"pkm",lift):return true
 return false

# The trigger held for a number of frames: a burst from the PKM itself.
func burst(hold: int) -> int:
 var before: int=game.player.shots
 Input.action_press("fire")
 await frames(hold)
 Input.action_release("fire")
 await frames(30)
 return game.player.shots-before

# A grenade from the launcher's muzzle at a hulk, the bore raised by the
# round's own elevation for the range (as its sight lays it).
func launch_at(hulk: String, round: String) -> void:
 var p: Operator=game.player
 var muzzle: Vector3=p.launcher.muzzle_point()
 var target: Vector3=TrainingRange.HULKS[hulk]+Vector3(0,1.0,0)
 var direction:=(target-muzzle).normalized()
 var axis:=direction.cross(Vector3.UP).normalized()
 direction=direction.rotated(axis,BlastSystem.rocket_elevation(round,TrainingRange.distance(muzzle,target)))
 game.blasts.launch(muzzle,direction,p,round)

func finish_course() -> int:
 var n:=0
 for i in range(80):
  if not t.running:return n
  t.skip();n+=1
  await frames(3)
 return n

func run():
 seed(6161)
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0

 # --- Training screen ------------------------------------------------------------
 game.set_player_class("machinegunner")
 game.main_menu.show_screen("training")
 var menu=game.main_menu
 check(game.COURSE_IDS.size()==9 and menu.course_tabs.size()==9,"Nine course tabs")
 for id in PlayerClass.IDS:check(game.courses.has(id),"A course for the class "+id)
 check(menu.course_pick=="machinegunner","The screen opens on the machine gunner's course")
 for id in ["machinegunner","grenadier","uav"]:
  menu.select_course(id)
  check(menu.chapter_cards.size()==game.courses[id].chapters().size() and menu.chapter_title.text==game.courses[id].chapters()[0].title,"%s tab lists its chapters" % id)
 # The tabs in two rows, the chapters below them.
 await process_frame
 var tab_bottom: float=0.0
 for tab in menu.course_tabs:tab_bottom=maxf(tab_bottom,tab.get_global_rect().end.y)
 check(tab_bottom<=menu.chapter_cards[0].get_global_rect().position.y,"Chapter list starts under the tabs")
 check(menu.course_tabs[0].get_global_rect().position.y==menu.course_tabs[4].get_global_rect().position.y and menu.course_tabs[0].get_global_rect().position.y<menu.course_tabs[5].get_global_rect().position.y,"Five tabs to a row, two rows")
 game.set_player_class("rifleman")
 game.loadout_bag.equipped=true
 game.loadout_bag.add("ammo_ak74")
 var bag_before: Dictionary=game.loadout_bag.serialize()
 game.selected_map="forest_01"

 # --- Machine gunner ------------------------------------------------------------
 await game.begin_training(0,"machinegunner")
 t=game.courses.machinegunner
 var p: Operator=game.player
 check(game.training=="machinegunner" and game.player_class=="machinegunner" and p.current().id=="pkm","Machine gunner: ПКМ in hand")
 check(game.district.map_id==TrainingRange.ID and t.targets.size()==8,"On the range with the targets at 100, 300 and 500 m")
 check(p.backpack.count("ammo_pkm")==1,"A can with a belt in the pack")
 await frames(30)
 check(step_id()=="nest" and t.marker().get("caption","")=="КУЛЕМЕТ","Marker on the nest")
 t.place(TrainingRange.MG+Vector3(0.4,0,0.6),TrainingRange.TARGETS.g300b.point)
 check(await passes("nest"),"In the nest")
 await key(KEY_Z)
 check(await passes("prone",3.0),"Z — prone")
 await frames(30)
 await key(KEY_X)
 check(await passes("bipod") and p.bipod,"X — the bipod down")
 Input.action_press("aim")
 check(await passes("aim",2.0),"RMB — aiming")
 for i in range(16):
  if p.current().scope_zero==100:break
  await key(KEY_PAGEDOWN)
  await frames(25)
 check(await passes("sight1") and p.current().scope_zero==100,"PgDn — the sight on 1")
 t.face(TrainingRange.TARGETS.g100a.point)
 var shots:=await burst(20)
 shots+=await burst(16)
 check(t.bursts.size()==2 and t.bursts[0]>=2 and t.bursts[0]<=5 and t.bursts[1]>=2 and t.bursts[1]<=5,"Two short bursts counted (%s, %d shots)" % [str(t.bursts),shots])
 var hit:=await shoot("g100a","pkm") and await shoot("g100b","pkm")
 check(hit and await passes("burst100",3.0),"Two hits at 100 m in short bursts")
 for i in range(2):
  await key(KEY_PAGEUP)
  await frames(25)
 check(await passes("sight3") and p.current().scope_zero==300,"PgUp twice — the sight on 3")
 hit=await shoot_at_range("g300a",[0.6,0.9,1.2])
 check(hit and step_id()=="group300","One figure of the group is not enough")
 hit=await shoot_at_range("g300c",[0.6,0.9,1.2])
 check(hit and await passes("group300",3.0),"Fire moved to a second figure at 300 m")
 for i in range(2):
  await key(KEY_PAGEUP)
  await frames(25)
 check(await passes("sight5"),"The sight on 5")
 t.face(TrainingRange.TARGETS.g500b.point)
 shots=await burst(55)
 check(not t.bursts.is_empty() and t.bursts[-1]>=6,"A long burst counted (%d shots)" % shots)
 hit=await shoot_at_range("g500b",[1.6,2.0,2.4,2.8,3.2,3.6])
 check(hit,"A real 7.62 bullet reaches a figure at 500 m")
 check(await passes("long500",3.0),"Long burst and a hit at 500 m")
 Input.action_release("aim")
 await frames(200)
 check(step_id()=="box" and p.current().rounds()==0 and not p.current().cocked,"Chapter 3: the belt shot out, the carrier home")
 var serial: int=p.current().magazine.get("serial",-1)
 Input.action_press("reload")
 await frames(2)
 await key(KEY_1)
 Input.action_release("reload")
 check(await passes("box",15.0) and p.current().magazine.get("serial",-1)!=serial,"R + 1 — the box changed")
 await frames(30)
 check(step_id()=="cock" and not p.current().chambered,"A new box does not cock the gun")
 await frames(20)
 await key(KEY_V)
 check(await passes("cock",4.0) and p.current().chambered and p.current().cocked,"V — handle back and forward, ready to fire")
 check(step_id()=="belt","The belt from the can next")
 var low: int=t.seen.get("box",0)
 check(int(p.current().pouches[low].rounds)==0,"The box in the pouch is the empty one")
 await key(KEY_TAB)
 check(game.inventory_open,"TAB — the inventory")
 game.inventory.select_pack_item(p.backpack.first("ammo_pkm"))
 game.inventory.select_magazine(Vector2i(0,low+1))
 game.inventory.begin_transfer()
 check(game.inventory.transfer.active and not game.inventory_open,"The belt change begins")
 check(await passes("belt",25.0),"The belt changed whole: the box full again")
 check(int(p.current().pouches[low].rounds)==int(p.current().data.capacity),"%d rounds in the box" % int(p.current().pouches[low].rounds))
 hit=await shoot("g100a","pkm")
 if not hit:hit=await shoot("g100b","pkm")
 check(hit and await passes("control",2.0),"Control shot")
 await frames(5)
 check(not t.running and game.result_panel.visible and "ЧЕРГ" in game.result_stats.text,"Machine gunner course finished with the bursts")
 check(t.done_chapters()==[0,1,2],"All three chapters recorded")
 game.to_menu("training")
 check(t.targets.is_empty() and game.training=="" and game.player_class=="rifleman","Back to the own class")

 # --- Grenadier -------------------------------------------------------------------
 await game.begin_training(0,"grenadier")
 t=game.courses.grenadier
 p=game.player
 check(game.player_class=="grenadier" and p.current().id=="ak74","Grenadier: АК-74М in hand")
 check(p.backpack.count("rpg7")==1 and p.backpack.count("pg7vl")==2 and p.backpack.count("rpg22")==1,"РПГ-7, two ПГ-7ВЛ and an РПГ-22 in the pack")
 await frames(30)
 check(step_id()=="post" and t.marker().get("caption","")=="ГРАНАТОМЕТ","Marker on the grenadier's line")
 t.place(TrainingRange.GRENADIER+Vector3(1,0,0.5),TrainingRange.HULKS.h200+Vector3(0,1.1,0))
 check(await passes("post"),"On the line")
 await key(KEY_4)
 check(await passes("draw",5.0) and p.launcher.kind=="rpg7","4 — the RPG-7 off the mount")
 await key(KEY_R)
 check(await passes("load",8.0) and p.launcher.loaded() and p.backpack.count("pg7vl")==1,"R — a ПГ-7ВЛ loaded")
 await frames(30)
 check(step_id()=="rear","Then the zone behind")
 p.rotate_y(PI)
 await frames(30)
 check(step_id()=="rear" and t.seen.get("back",false),"Looking back is seen, the step waits for the turn back")
 p.rotate_y(PI)
 check(await passes("rear",2.0),"Behind clear, facing the BMP again")
 Input.action_press("aim")
 check(await passes("scope",2.0),"RMB — through the PGO-7")
 Input.action_release("aim")
 await frames(20)
 launch_at("h200","pg7vl")
 p.backpack.item(p.launcher.item_uid)["loaded"]=false
 check(await passes("hit200",5.0),"The PG-7VL laid for 200 m strikes the hull at 200 m")
 await key(KEY_R)
 check(await passes("reload",8.0),"R — reloaded")
 await frames(20)
 launch_at("h300","pg7vl")
 p.backpack.item(p.launcher.item_uid)["loaded"]=false
 check(await passes("hit300",6.0),"…and at 300 m")
 check(t.chapter==2 and step_id()=="swap","Chapter 3: the RPG-22")
 await key(KEY_5)
 check(await passes("swap",7.0) and p.launcher.kind=="rpg22" and not p.launcher.armed(),"5 — the RPG-22 in the hands, folded")
 await key(KEY_R)
 check(await passes("arm",8.0) and p.launcher.armed(),"R — the RPG-22 armed")
 await frames(20)
 launch_at("h150","rpg22")
 check(await passes("hit150",5.0),"The RPG-22's grenade on the hull at 150 m")
 await frames(5)
 check(not t.running and game.result_panel.visible and "ВЛУЧАНЬ У БМП  3" in game.result_stats.text and not "ВИДАНО" in game.result_stats.text,"Grenadier course finished: three hits (%s)" % game.result_stats.text.replace("\n"," / "))
 game.to_menu("training")
 # A miss on chapter 2 on its own: the readout says where, a new round comes.
 await game.begin_training(1,"grenadier")
 t=game.courses.grenadier
 p=game.player
 await frames(30)
 check(step_id()=="scope" and p.launcher.kind=="rpg7" and p.launcher.loaded(),"Chapter 2 on its own: a loaded RPG-7 on the shoulder")
 t.skip()
 await frames(3)
 for uid in range(200):
  if p.backpack.first("pg7vl")<0:break
  p.backpack.remove(p.backpack.first("pg7vl"))
 game.blasts.detonate(TrainingRange.GRENADIER+Vector3(0,0.2,-90),"heat")
 p.backpack.item(p.launcher.item_uid)["loaded"]=false
 await frames(20)
 check(step_id()=="hit200" and "недоліт" in t.readout_text("hit200"),"A short round is called: %s" % t.readout_text("hit200").replace("\n"," / "))
 check(p.backpack.count("pg7vl")==1,"…and the range hands out another")
 game.to_menu("training")

 # --- UAV operator ------------------------------------------------------------------
 await game.begin_training(0,"uav")
 t=game.courses.uav
 p=game.player
 check(game.player_class=="uav" and p.backpack.count("fpv_heat")==1 and p.backpack.count("fpv_frag")==1,"UAV operator: a HEAT and a frag FPV in the pack")
 check(t.targets.size()==3,"Figures at the position")
 await frames(30)
 check(step_id()=="pad" and t.marker().get("caption","")=="БПЛА","Marker on the pad")
 t.place(TrainingRange.UAV+Vector3(0,0,0.5),TrainingRange.WAYPOINT)
 check(await passes("pad"),"On the pad")
 await key(KEY_Y)
 check(await passes("deploy",9.0) and p.field_rig.mode=="drone","Y — the FPV out, on the ground, goggles on")
 var u=t
 check(u.drone()!=null and u.drone().warhead=="heat","The HEAT drone first")
 Input.action_press("jump")
 var up:=await passes("takeoff",6.0)
 Input.action_release("jump")
 check(up and u.height()>=12.0,"SPACE — off the pad and up to %d m" % roundi(u.height()))
 check(p.backpack.count("fpv_heat")==0,"Once off the ground it is out of the pack")
 check(t.marker().get("caption","")=="КТ","Marker on the checkpoint in the goggles")
 var d=u.drone()
 d.global_position=TrainingRange.WAYPOINT+Vector3(3,game.district.ground_height(TrainingRange.WAYPOINT)+20.0,2)
 d.velocity=Vector3.ZERO
 check(await passes("waypoint",2.0),"Over the checkpoint")
 check(await passes("airborne",2.0),"Chapter 2: the drone already up")
 check(step_id()=="strike" and t.marker().get("caption","")=="БМП","Marker on the BMP")
 d=u.drone()
 d.global_position=TrainingRange.HULKS.h300+Vector3(0.3,26.0,0.2)
 d.velocity=Vector3(0,-14,0)
 Input.action_press("crouch")
 var struck:=await passes("strike",5.0)
 Input.action_release("crouch")
 check(struck,"A dive onto the hulk: the PG-7VL warhead goes off on the hull")
 check(TrainingRange.on_hulk("h300",game.blasts.last_detonation,0.8),"…on the hull (%s)" % str(game.blasts.last_detonation))
 await frames(10)
 check(p.field_rig.mode=="" and u.drone()==null,"Goggles off after the strike")
 await key(KEY_Y)
 for i in range(60*7):
  if p.field_rig.mode=="drone":break
  await physics_frame
 check(u.drone()!=null and u.drone().warhead=="frag","Y — the frag drone next")
 Input.action_press("jump")
 up=await passes("frag_up",6.0)
 Input.action_release("jump")
 check(up,"…and up")
 d=u.drone()
 d.global_position=TrainingRange.POSITION+Vector3(1.5,3.0,-1.0)
 d.velocity=Vector3.ZERO
 await frames(5)
 await action("fire")
 check(await passes("frag",2.0),"LMB — an air burst over the position")
 await frames(5)
 check(not t.running and game.result_panel.visible and "УРАЖЕНЬ  2" in game.result_stats.text,"UAV course finished: two strikes")
 game.to_menu("training")

 # --- F6 walks every new course ---------------------------------------------------
 for id in ["machinegunner","grenadier","uav"]:
  await game.begin_training(0,id)
  t=game.courses[id]
  await frames(20)
  var total:=0
  for chapter in t.steps():total+=chapter.size()
  var n:=await finish_course()
  check(not t.running and game.result_panel.visible and n==total,"F6 walks the %s course (%d / %d steps)" % [id,n,total])
  check("ПРОПУЩЕНО КРОКІВ  %d" % total in game.result_stats.text,"…and the results count the skips")
  game.to_menu("training")
 check(game.training=="" and game.player_class=="rifleman" and game.selected_map=="forest_01" and game.loadout_bag.serialize()==bag_before,"Own class, map and pack come back")

 print("checks: ",checks)
 print("FAIL" if failed else "PASS")
 quit(1 if failed else 0)
