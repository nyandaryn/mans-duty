extends SceneTree
# The ring of choices (scripts/radial_menu.gd, driven from Operator):
# - a key that takes something from the pack with one kind there acts on the
#   press, as before;
# - with two kinds or more a tap acts on the release with the kind taken last
#   (at first the usual order), and held it opens the ring: the mouse leans
#   into a sector or 1…n picks, letting the key go or the left button takes
#   it, Esc / the right button / ~ closes it with nothing taken;
# - while it is up the rifle neither fires nor comes to the eye, nor on the
#   press that closed it;
# - 4 / 5 choose the launcher (5 held with one in the hands: the one to change
#   to), R with the RPG-7 the round (PG-7VL or OG-7V), J / Y the drone
#   (recon, FPV with the PG-7VL head, FPV fragmentation);
# - the OG-7V: its flight fits the maker's 170 m direct-fire range, it flies
#   from the RPG-7 as an OG-7V and weighs as one seated; the PGO-7 hint's
#   chevrons agree with the two flights.
var checks := 0
var failed := false
var game: Node3D
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func press(p: Operator, code: Key) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
 p._unhandled_input(event)

func release(p: Operator, code: Key) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=false
 p._unhandled_input(event)

func tap(p: Operator, code: Key) -> void:
 press(p,code);release(p,code)

# Held past the threshold: the ring comes up.
func hold(p: Operator, code: Key) -> void:
 press(p,code)
 p.radial._process(p.radial.HOLD+0.05)

func ring_key(p: Operator, code: Key) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
 p.radial._input(event)

func lean(p: Operator, offset: Vector2) -> void:
 var motion:=InputEventMouseMotion.new();motion.relative=offset
 p.radial._input(motion)

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

func ids(options: Array) -> Array:
 var list:=[]
 for option in options:list.append(option.id)
 return list

func run():
 seed(4411)
 # --- One kind: the key acts on the press --------------------------------------
 var p:=await start("rifleman",["rpo_a"])
 press(p,KEY_4)
 check(p.launcher.mode=="draw" and p.launcher.kind=="rpo_a" and not p.radial.engaged(),"One launcher in the pack: 4 takes it at the press, no ring")
 release(p,KEY_4)
 p.launcher.cancel()
 # --- The grenadier's launchers --------------------------------------------------
 p=await start("grenadier",["rpg7","pg7vl","og7v","rpg22"])
 check(ids(p.launcher_choices())==["rpg7","rpg22"],"The ring for 4 lists the RPG-7 and the RPG-22 (%s)" % str(ids(p.launcher_choices())))
 press(p,KEY_4)
 check(p.radial.engaged() and not p.radial.is_open() and not p.launcher.active(),"Two launchers: the press waits for the release or the hold")
 release(p,KEY_4)
 check(p.launcher.mode=="draw" and p.launcher.kind=="rpg7" and not p.radial.engaged(),"A tap takes the first in the usual order, the RPG-7")
 p.launcher.cancel()
 hold(p,KEY_4)
 check(p.radial.is_open() and p.radial.options.size()==2 and not p.launcher.active(),"Held, the ring opens with two sectors")
 check(p.hands_held(),"…the rifle waits while it is up")
 var labels:=[]
 for option in p.radial.options:labels.append("%s/%s/%s" % [option.title,option.count,option.detail])
 check(labels==["РПГ-7/1/НЕ ЗАРЯДЖЕНО","РПГ-22/1/СКЛАДЕНИЙ"],"Each sector: short name, count, state (%s)" % str(labels))
 check(p.radial.selected==0,"…the one a tap would take is lit first")
 lean(p,Vector2(0,90))
 check(p.radial.selected==1,"The mouse leaned down lights the RPG-22's sector")
 lean(p,Vector2(0,-200))
 check(p.radial.selected==0,"…and up again the RPG-7's")
 lean(p,Vector2(0,200))
 release(p,KEY_4)
 check(p.launcher.mode=="draw" and p.launcher.kind=="rpg22" and not p.radial.engaged(),"Letting 4 go takes the lit one: the RPG-22 comes off the mount")
 check(p.preferred("launcher")=="rpg22","…and is remembered")
 p.launcher.cancel()
 tap(p,KEY_4)
 check(p.launcher.kind=="rpg22" and p.launcher.mode=="draw","A tap now takes the RPG-22, the one taken last")
 p.launcher.cancel()
 # Esc and the right button: nothing taken.
 hold(p,KEY_4)
 ring_key(p,KEY_ESCAPE)
 check(not p.radial.engaged() and not p.launcher.active(),"Esc closes the ring with nothing taken")
 release(p,KEY_4)
 check(not p.launcher.active(),"…and the late release does nothing")
 hold(p,KEY_4)
 var right:=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true
 p.radial._input(right)
 check(not p.radial.is_open() and not p.launcher.active(),"The right button closes it too")
 release(p,KEY_4)
 hold(p,KEY_4)
 var cancel_key:=InputEventKey.new();cancel_key.physical_keycode=Operator.CANCEL_KEY;cancel_key.pressed=true
 p._unhandled_input(cancel_key)
 check(not p.radial.engaged() and not p.launcher.active(),"…and so does the cancel key ~")
 release(p,KEY_4)
 # A number key picks and takes at once; the left button confirms and latches.
 hold(p,KEY_4)
 ring_key(p,KEY_1)
 check(p.launcher.kind=="rpg7" and p.launcher.mode=="draw" and not p.radial.engaged(),"1 in the ring takes the RPG-7")
 release(p,KEY_4)
 launcher_ticks(p,3.1)
 check(p.launcher.mode=="ready","…on the shoulder after 3 s")
 # In the hands: 4 still puts it back at once; 5 held — the one to change to.
 hold(p,KEY_5)
 check(p.radial.is_open(),"5 held with the RPG-7 in the hands opens the ring")
 var in_hands: Dictionary=p.radial.options[0]
 check(in_hands.id=="rpg7" and not in_hands.enabled and in_hands.detail=="У РУКАХ" and p.radial.selected==1,"…the one in the hands greyed out, the other lit")
 var left:=InputEventMouseButton.new();left.button_index=MOUSE_BUTTON_LEFT;left.pressed=true
 p.radial._input(left)
 check(p.launcher.mode=="stow" and p.launcher.queued=="rpg22","The left button takes it: the RPG-7 goes back for the RPG-22")
 check(p.radial.latch==MOUSE_BUTTON_LEFT,"…and that press does not reach the rifle")
 release(p,KEY_5)
 p.radial._process(0.016)
 check(p.radial.latch==MOUSE_BUTTON_NONE and not p.hands_held(),"…until the button is up")
 launcher_ticks(p,2.5)
 check(p.launcher.kind=="rpg22" and p.launcher.mode=="draw","…then the RPG-22 comes off the mount")
 p.launcher.cancel()
 tap(p,KEY_4)
 launcher_ticks(p,0.1)
 check(p.launcher.kind=="rpg22","4 tapped takes the one picked last")
 p.launcher.cancel()
 # --- R: the round for the RPG-7 -----------------------------------------------
 p.launcher.equip(-1,"rpg7")
 launcher_ticks(p,3.1)
 check(ids(p.round_choices())==["pg7vl","og7v"],"The ring for R lists the PG-7VL and the OG-7V")
 hold(p,KEY_R)
 check(p.radial.is_open() and p.launcher.mode=="ready","R held with the RPG-7 empty opens the ring")
 ring_key(p,KEY_2)
 release(p,KEY_R)
 check(p.launcher.mode=="load" and p.launcher.loading=="og7v","2 takes the OG-7V: the loading begins")
 launcher_ticks(p,3.6)
 p.launcher.animate()
 var og: Node3D=p.launcher.tube.get_node("GrenadeOG")
 var pg: Node3D=p.launcher.tube.get_node("Grenade")
 check(og.visible and not pg.visible,"…the OG-7V shows in the muzzle, not a PG-7VL")
 launcher_ticks(p,2.6)
 check(p.launcher.loaded() and p.launcher.loaded_round()=="og7v" and p.backpack.count("og7v")==0 and p.backpack.count("pg7vl")==1,"Seated: the OG-7V left the pack, the PG-7VL stayed")
 var mass: float=p.backpack.mass()-Equipment.PACK_MASS
 check(is_equal_approx(mass,7.2+1.73+2.6+2.7),"The seated OG-7V weighs as itself (%.2f kg)" % mass)
 check(p.launcher_choices()[0].detail=="У РУКАХ","In the hands its sector says so")
 p.launcher.cancel()
 check(p.launcher_choices()[0].detail=="ОГ-7В У ТРУБІ","On the mount the launcher ring tells which round is in the tube")
 p.launcher.equip(-1,"rpg7")
 launcher_ticks(p,3.1)
 var before: int=game.blasts.rockets.size()
 check(p.launcher.fire() and game.blasts.rockets.size()==before+1 and game.blasts.rockets[-1].kind=="og7v","It flies as an OG-7V")
 check(not p.launcher.loaded() and not p.backpack.item(p.launcher.item_uid).has("round"),"…and the tube is empty after it")
 game.blasts.clear()
 # One kind left: R loads at the press.
 press(p,KEY_R)
 check(p.launcher.mode=="load" and p.launcher.loading=="pg7vl" and not p.radial.engaged(),"With only PG-7VL left R loads it at once")
 release(p,KEY_R)
 p.launcher.cancel()
 # --- The OG-7V's flight and the PGO-7 hint ---------------------------------------
 var e:=BlastSystem.rocket_elevation("og7v",170.0)
 var r:={"kind":"og7v","position":Vector3.ZERO,"velocity":Vector3(0,sin(e),-cos(e))*152.0,"age":0.0,"travel":0.0,"lit":-1.0}
 var top:=0.0
 while -Vector3(r.position).z<170.0:
  BlastSystem.rocket_step(r,1.0/240.0);top=maxf(top,Vector3(r.position).y)
 check(absf(top-2.0)<0.1,"Laid for 170 m the OG-7V rises %.2f m: the 2 m target's direct-fire range" % top)
 var eye:=Rpg7Art.EYEPIECE.y
 for row in LauncherRig.OG7V_PGO:
  var want:=LauncherRig.elevation("og7v",float(row[0]),eye)
  var low:=10.0;var high:=1200.0
  for i in range(22):
   var mid:=(low+high)*0.5
   if BlastSystem.rocket_elevation("pg7vl",mid)+eye/mid<want:low=mid
   else:high=mid
  var mark:=(low+high)*0.5
  check(absf(mark-float(row[1])*100.0)<60.0,"OG-7V at %d m: the PG-7VL's %d m — chevron «%d»" % [row[0],roundi(mark),row[1]])
 check(LauncherRig.og7v_hint().contains("150 м — «3»"),"The HUD hint lists the chevrons")
 # --- Drones (J / Y) -------------------------------------------------------------
 p=await start("uav",["recon_drone","fpv_heat","fpv_frag"])
 check(ids(p.drone_choices())==["recon_drone","fpv_heat","fpv_frag"],"The drone ring: recon, FPV with the PG-7VL head, FPV fragmentation")
 hold(p,KEY_Y)
 check(p.radial.is_open() and p.radial.options[p.radial.selected].id=="fpv_heat","Y held: the ring, the first FPV lit")
 ring_key(p,KEY_3)
 release(p,KEY_Y)
 check(p.field_rig.mode=="access" and p.field_rig.kind=="fpv_frag","3 takes the fragmentation FPV from the pack")
 p.field_rig.cancel()
 check(p.backpack.count("fpv_frag")==1,"…called off, it is still in the pack")
 tap(p,KEY_Y)
 check(p.field_rig.mode=="access" and p.field_rig.kind=="fpv_frag","Y tapped takes the kind picked last")
 p.field_rig.cancel()
 tap(p,KEY_J)
 check(p.field_rig.mode=="access" and p.field_rig.kind=="recon_drone","J tapped takes the recon drone")
 p.field_rig.cancel()
 hold(p,KEY_J)
 check(p.radial.is_open() and p.radial.options[p.radial.selected].id=="recon_drone","J held: the same ring, the recon drone lit")
 lean(p,Vector2(80,40))
 release(p,KEY_J)
 check(p.field_rig.mode=="access" and p.field_rig.kind=="fpv_heat","…leaned right and down, the PG-7VL FPV")
 p.field_rig.cancel()
 # Busy hands: the keys work as before, no ring.
 p.field_rig.toggle_rangefinder()
 press(p,KEY_Y)
 check(not p.radial.engaged(),"With the hands busy the drone keys open no ring")
 release(p,KEY_Y)
 p.field_rig.cancel()
 # The machine gunner has only the recon drone: J at the press.
 p=await start("machinegunner",["recon_drone"])
 press(p,KEY_J)
 check(p.field_rig.mode=="access" and not p.radial.engaged(),"One drone kind: J takes it at the press")
 release(p,KEY_J)
 print("%s: %d radial menu checks" % ["FAILED" if failed else "PASS",checks])
 game.queue_free()
 await frames(2)
 quit(1 if failed else 0)
