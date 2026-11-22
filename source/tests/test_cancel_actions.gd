extends SceneTree
# The universal cancel: ~ (the key left of 1) or the mouse's back button
# stops whatever the soldier is doing that takes time, and nothing is lost or
# made (Operator.cancel_action):
# - a reload before the magazine leaves the weapon: it stays on; once it is
#   in the hand: it stays there and R carries on; a prepared reload: the new
#   magazine back into its pouch; the PKM's box the same;
# - a rack: before the round is out nothing changes, after it the bolt runs
#   home on the next; the PKM's handle cocks only once back past the sear;
# - an inspection stops; a magazine being filled keeps the rounds moved, a
#   belt being changed stays as it was;
# - from the pack: the item reached for stays in it, an FPV set down goes
#   back, goggles come off a drone that stays out, a drone being folded
#   stays out; the rangefinder goes back into its pouch; hands-on work stops
#   undone; a first-aid kit is not spent (H again does the same);
# - the launchers: a draw turns into putting it back from where it got to and
#   back again; a round half pushed in stays in the pack; the RPG-22's sleeve
#   slides back unless locked, locked it stays out and the tube is ready;
# - the mortar's bipod being moved stays where it was;
# - every such action shows "~ — СКАСУВАТИ"; with nothing going on the key
#   does nothing.
var checks := 0
var failed := false
var game: Node3D
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func cancel(p: Operator, mouse: bool=false) -> void:
 if mouse:
  var button:=InputEventMouseButton.new();button.button_index=MOUSE_BUTTON_XBUTTON1;button.pressed=true
  p._unhandled_input(button)
 else:
  var event:=InputEventKey.new();event.physical_keycode=Operator.CANCEL_KEY;event.pressed=true
  p._unhandled_input(event)

func weapon_ticks(w: WeaponState, seconds: float) -> void:
 for i in range(int(ceil(seconds*60.0))):w.update(1.0/60.0)

func launcher_ticks(p: Operator, seconds: float) -> void:
 for i in range(int(ceil(seconds*60.0))):p.launcher.tick(1.0/60.0)

func rig_ticks(p: Operator, seconds: float) -> void:
 for i in range(int(ceil(seconds*60.0))):p.field_rig.tick(1.0/60.0)

func start(id: String, bag: Array) -> Operator:
 if game!=null:
  game.queue_free()
  await frames(2)
 game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class(id)
 game.loadout_bag=BackpackState.new();game.loadout_bag.equipped=true
 for kind in bag:game.loadout_bag.add(kind)
 game.selected_map=TrainingRange.ID
 game.start_match()
 game.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 await frames(3)
 var p: Operator=game.player
 p.set_physics_process(false)
 return p

func run():
 seed(5521)
 # --- The rifle ----------------------------------------------------------------
 var p:=await start("rifleman",["medkit","recon_drone"])
 var w: WeaponState=p.current()
 var total:=w.ammunition_total()
 var full:=w.rounds()
 check(not p.cancel_action() and p.cancel_hint()=="" and p.cancel_notice=="","Nothing going on: the cancel key does nothing")
 check(w.reload() and w.phase=="remove","R: the magazine starts off")
 check(p.cancel_hint()=="~ — СКАСУВАТИ · ВИЙМАННЯ МАГАЗИНА","The HUD line: %s" % p.cancel_hint())
 weapon_ticks(w,0.35)
 cancel(p)
 check(w.phase=="" and w.pending_slot<0 and w.rounds()==full and w.chambered,"Called off before it is out: the magazine stays on, the round in the chamber")
 check(w.ammunition_total()==total and p.cancel_notice.begins_with("СКАСОВАНО"),"…nothing lost (%d) and the HUD says so" % w.ammunition_total())
 check(w.rack(),"…and the rifle is free again: the bolt can be worked")
 weapon_ticks(w,0.2)
 cancel(p)
 check(w.phase=="" and w.chambered and w.discarded_rounds==0,"A rack called off before the round is out changes nothing")
 w.rack();weapon_ticks(w,0.45)
 check(not w.chambered and w.bolt_open,"…past it the round is out, the bolt held back")
 cancel(p)
 check(w.phase=="" and w.chambered and not w.bolt_open and w.rounds()==full-1,"…let go, it runs home on the next round")
 check(w.ammunition_total()==total-1,"…the ejected round is the only one gone")
 total=w.ammunition_total()
 w.reload(2);weapon_ticks(w,0.75)
 check(w.phase=="stow" and w.magazine.is_empty() and not w.held_old.is_empty(),"Past the removal the old magazine is in the hand")
 cancel(p,true)
 check(w.phase=="" and w.reload_interrupted() and w.held_old.rounds==full-1 and w.ammunition_total()==total,"The mouse's back button: it stops there, the magazine kept in the hand")
 check(w.status().contains("R — ПРОДОВЖИТИ"),"…the weapon panel tells R carries on (%s)" % w.status())
 check(w.chambered and p.current().fire(),"…the round in the chamber still fires")
 total-=1
 check(w.reload(),"R takes it up again")
 weapon_ticks(w,3.0)
 check(w.phase=="" and w.pending_slot<0 and w.rounds()==30 and w.pouches[2].rounds==full-1 and w.ammunition_total()==total,"…to the end: the full one in, the old one in the pouch")
 # A prepared reload: the new magazine back where it came from.
 w.inspect_magazine(0);weapon_ticks(w,0.6)
 check(w.reload(0) and w.phase=="ready_remove" and w.pouches[0].is_empty(),"A reload from the pouch inspection: the new one already in the hand")
 cancel(p)
 check(w.phase=="" and w.pending_slot<0 and w.pouches[0].rounds==30 and w.ammunition_total()==total,"…called off, it goes back into its pouch")
 w.inspect_chamber();weapon_ticks(w,0.5)
 cancel(p)
 check(w.phase=="","An inspection just stops")
 # A magazine being filled from another keeps what was moved.
 w.pouches[0].rounds=12
 total=w.ammunition_total()
 var inv=game.inventory
 check(inv.transfer.begin(w,2,1),"Filling one pouch magazine from another")
 check(p.cancel_hint()=="~ — СКАСУВАТИ","…shows the cancel line")
 for i in range(int(1.0*60)+int(0.9*4*60)+6):inv.transfer.update(1.0/60.0)
 var moved: int=inv.transfer.moved
 cancel(p)
 check(not inv.transfer.active and w.phase=="" and moved>=4 and w.pouches[0].rounds==12+moved and w.ammunition_total()==total,"…called off: %d rounds moved stay moved, none lost" % moved)
 # --- From the pack ------------------------------------------------------------------
 p.health=70.0;p.bandages=0
 check(p.begin_bandage() and p.field_rig.mode=="access","A first-aid kit from the pack")
 rig_ticks(p,1.5)
 cancel(p)
 check(p.field_rig.mode=="" and p.backpack.count("medkit")==1 and p.bandage_time<=0,"…called off: the kit is still in the pack")
 p.bandages=1
 check(p.begin_bandage() and p.bandage_time>0,"The belt kit: treatment begins")
 cancel(p)
 check(p.bandage_time<=0 and p.bandages==1 and p.health<100,"…called off: the kit is not spent")
 p.begin_bandage()
 var h:=InputEventKey.new();h.physical_keycode=KEY_H;h.pressed=true
 p._unhandled_input(h)
 check(p.bandage_time<=0 and p.bandages==1,"H again during the treatment calls it off too")
 p.health=100.0
 # The recon drone.
 p.field_rig.toggle_drone()
 rig_ticks(p,1.0)
 cancel(p)
 check(p.field_rig.mode=="" and p.backpack.count("recon_drone")==1 and not is_instance_valid(p.field_rig.drone),"The drone reached for stays in the pack")
 p.field_rig.toggle_drone()
 rig_ticks(p,3.5)
 check(p.field_rig.mode=="goggles" and is_instance_valid(p.field_rig.drone),"Set out, the goggles go on")
 check(p.cancel_hint()=="~ — СКАСУВАТИ","…which can be called off")
 rig_ticks(p,0.5)
 cancel(p)
 check(p.field_rig.mode=="" and is_instance_valid(p.field_rig.drone) and not p.field_rig.drone.piloting,"Goggles off: the drone stays where it stands")
 p.field_rig.drone.landed=true
 check(p.field_rig.recover_drone(),"Folding it back begins")
 rig_ticks(p,1.0)
 cancel(p)
 check(p.field_rig.mode=="" and is_instance_valid(p.field_rig.drone) and p.backpack.count("recon_drone")==0,"…called off, it stays out")
 var f:=InputEventKey.new();f.physical_keycode=KEY_F;f.pressed=true
 p._unhandled_input(f)
 check(p.field_rig.mode=="recover_drone","F begins folding it again")
 rig_ticks(p,0.5)
 p._unhandled_input(f)
 check(p.field_rig.mode=="" and is_instance_valid(p.field_rig.drone),"…F again calls it off")
 p.field_rig.recover_drone();rig_ticks(p,2.3)
 check(p.backpack.count("recon_drone")==1 and not is_instance_valid(p.field_rig.drone),"…let finish, the drone is back in the pack")
 p.field_rig.toggle_drone();rig_ticks(p,0.5)
 p.field_rig.toggle_drone()
 check(p.field_rig.mode=="" and p.backpack.count("recon_drone")==1,"J again while reaching for it: it stays in the pack")
 # The rangefinder from its pouch.
 p.field_rig.toggle_rangefinder();rig_ticks(p,0.4)
 cancel(p)
 check(p.field_rig.mode=="pouch_stow" and is_equal_approx(p.field_rig.timer,FieldRig.POUCH_STOW*(1.0-0.4/FieldRig.POUCH_TIME)) ,"The rangefinder coming out goes back from where it got to")
 rig_ticks(p,0.4)
 check(p.field_rig.mode=="","…into its pouch")
 # Hands-on work.
 var done:=[false]
 check(p.field_rig.work("ТЕСТОВА РОБОТА",5.0,func():done[0]=true),"Hands-on work begins")
 check(p.cancel_hint()=="~ АБО КРОК — СКАСУВАТИ","…the line: %s" % p.cancel_hint())
 rig_ticks(p,2.0)
 cancel(p)
 rig_ticks(p,4.0)
 check(p.field_rig.mode=="" and not done[0] and p.field_rig.work_notice.contains("СКАСОВАНО"),"…called off it stops undone")
 # --- The machine gun ------------------------------------------------------------------
 p=await start("machinegunner",["ammo_pkm"])
 w=p.current()
 w.fire();w.fire()
 total=w.ammunition_total()
 check(w.reload() and w.phase=="remove","The PKM: cover up, belt off, box off")
 weapon_ticks(w,1.2)
 cancel(p)
 check(w.phase=="" and w.pending_slot<0 and w.rounds()==97 and w.chambered and w.ammunition_total()==total,"Called off before the box is off: the belt stays in, nothing lost")
 w.cocked=false;w.chambered=false;w.magazine.rounds+=1
 w.rack();weapon_ticks(w,0.5)
 cancel(p)
 check(not w.cocked and not w.chambered,"The handle let go before the sear: the carrier rides forward with it")
 w.rack();weapon_ticks(w,1.0)
 cancel(p)
 check(w.cocked and w.chambered,"…past the sear it stays cocked, the belt ready")
 # The belt change from a can in the pack.
 w.magazine.rounds=20
 total=w.ammunition_total()
 var can: int=p.backpack.first("ammo_pkm")
 check(game.inventory.transfer.begin_box(w,p.backpack,can,0),"A belt change from the can")
 for i in range(int(5.0*60)):game.inventory.transfer.update(1.0/60.0)
 check(p.timed_action()=="ЗАМІНА СТРІЧКИ","…it is the belt change going on")
 cancel(p)
 check(not game.inventory.transfer.active and w.rounds()==20 and int(p.backpack.item(can).rounds)==100 and w.phase=="","…called off mid-way: the belts as they were")
 # --- The launchers --------------------------------------------------------------------
 p=await start("grenadier",["rpg7","pg7vl","rpg22"])
 var l: LauncherRig=p.launcher
 check(l.equip(-1,"rpg7") and l.mode=="draw","The RPG-7 comes off the mount")
 check(p.cancel_hint()=="~ — СКАСУВАТИ","…which can be called off")
 launcher_ticks(p,1.5)
 cancel(p)
 check(l.mode=="stow" and absf(l.timer-1.2)<0.05,"Called off half way: it goes back from there (%.2f of 2.4 s)" % l.timer)
 cancel(p)
 check(l.mode=="draw" and absf(l.timer-1.5)<0.05,"…and called off again it comes back up from there")
 launcher_ticks(p,1.6)
 check(l.mode=="ready","…on the shoulder")
 check(l.load_round() and l.mode=="load","R: a PG-7VL into the muzzle")
 launcher_ticks(p,4.0)
 cancel(p)
 check(l.mode=="ready" and not l.loaded() and p.backpack.count("pg7vl")==1 and l.notice.contains("У НАПЛІЧНИКУ"),"Called off half pushed in: the round stays in the pack")
 l.cancel()
 l.equip(-1,"rpg22");launcher_ticks(p,2.3)
 check(l.arm() and l.mode=="arm","The RPG-22: into the firing position")
 launcher_ticks(p,2.0)
 cancel(p)
 check(l.mode=="ready" and not l.armed(),"Called off before the sleeve locks: still folded")
 l.arm();launcher_ticks(p,4.0)
 cancel(p)
 check(l.mode=="ready" and l.armed() and l.notice.contains("РОЗКЛАДЕНИМ"),"…after the lock it stays drawn out, ready")
 check(l.fire() and l.mode=="spent","It fires and is thrown away")
 cancel(p)
 check(not l.active(),"…called off, the spent tube is gone at once")
 game.blasts.clear()
 # --- The mortar's bipod ---------------------------------------------------------------
 var mortar:=Mortar.new()
 game.add_child(mortar);mortar.setup(game)
 mortar.global_position=p.global_position+Vector3(2,0,0)
 mortar.state="deployed";mortar.lay_bipod()
 mortar.set_azimuth(30)
 check(mortar.relay_left<=0,"A small turn needs no relay")
 mortar.set_azimuth(900)
 check(mortar.relay_left>0 and mortar.bipod_azimuth==900,"A big one moves the bipod: 6 s")
 var crew_mortar=game.crew.mortar
 game.crew.mortar=mortar
 check(p.timed_action()=="ПЕРЕНЕСЕННЯ ДВОНОГИ МІНОМЕТА","…a timed action")
 cancel(p)
 check(mortar.relay_left<=0 and mortar.bipod_azimuth==0 and mortar.azimuth==30,"Called off: the bipod stays, the barrel back on its last direction")
 game.crew.mortar=crew_mortar
 mortar.queue_free()
 print("%s: %d cancel checks" % ["FAILED" if failed else "PASS",checks])
 game.queue_free()
 await frames(2)
 quit(1 if failed else 0)
