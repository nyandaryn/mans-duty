extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var bag := BackpackState.new()
 check(bag.add("medkit")==-1,"Cannot store equipment without pack")
 bag.equipped=true
 var med := bag.add("medkit",Vector2i(0,0))
 check(med>0 and bag.used_slots()==4,"Item footprint consumes four cells")
 check(bag.add("ammo_pm",Vector2i(1,0))==-1,"Overlapping items rejected")
 check(bag.add("rangefinder",Vector2i(5,3))==-1,"Out of bounds rejected")
 check(bag.move_item(med,Vector2i(4,2)),"Items can be repositioned")
 for i in range(10):check(bag.add("ammo_ak74")>0,"Fill free slots")
 check(bag.used_slots()==24 and bag.add("ammo_m9")==-1,"Full pack rejects overflow")
 var saved := bag.serialize()
 var clone := BackpackState.restore(saved)
 clone.items[0].kind="rangefinder"
 check(bag.items[0].kind=="medkit","Mission pack and loadout do not alias")
 var invalid := BackpackState.restore({"equipped":true,"items":[{"kind":"bogus"},{"kind":"medkit","x":-9,"y":0},{"kind":"ammo_pm","x":0,"y":0,"rounds":9999},{"kind":"medkit","x":0,"y":0}]})
 check(invalid.items.size()==1 and invalid.items[0].rounds==30,"Malformed saves reject unknowns, overlaps, bounds and excess rounds")
 var presets := LoadoutPresets.new();presets.path="user://equipment-test.cfg"
 check(presets.save_preset("Patrol",{"class":"rifleman","primary":"m16","secondary":"m9","outfit":"ua_pixel","backpack":saved})==OK,"Save equipment preset")
 check(presets.save_preset("Marksman",{"primary":"svd","secondary":"m9","outfit":"ua_pixel","backpack":saved})==OK,"Save legacy preset without a class")
 var loaded := LoadoutPresets.new();loaded.path=presets.path;loaded.read()
 check(loaded.presets.Patrol.primary=="m16" and loaded.presets.Patrol["class"]=="rifleman" and loaded.presets.Patrol.backpack.items.size()==11,"Preset survives disk reload")
 check(loaded.presets.Marksman["class"]=="sniper" and loaded.presets.Marksman.primary=="svd" and loaded.presets.Marksman.backpack.items.size()==1,"Legacy SVD preset becomes a sniper without other calibres")
 check(LoadoutPresets.validate({"class":"mortarman","primary":"svd"}).primary=="ak74","Class restricts the rifle of a preset")
 check(presets.save_preset(" ",{})==ERR_INVALID_PARAMETER,"Empty preset name rejected")
 check(is_equal_approx(Equipment.run_multiplier(10),1.0),"Sprint reference at 10 kg")
 check(absf(Equipment.run_multiplier(30)-1/1.16)<0.00001,"Time penalty inverted into velocity, not subtracted")
 for id in WeaponState.DATA:
  var box_bag := BackpackState.new();box_bag.equipped=true
  var uid := box_bag.add("ammo_"+id)
  var w := WeaponState.new(id);w.magazine.rounds=0
  var total := w.ammunition_total()+int(box_bag.item(uid).rounds)
  var weight := Equipment.carried_mass([w],box_bag)
  var transfer := MagazineTransfer.new()
  check(transfer.begin_box(w,box_bag,uid,0),"Load box into removed magazine "+id)
  transfer.update(3.39)
  check(transfer.moved==0,"Pack access delay before first round "+id)
  transfer.update(1.01)
  check(transfer.moved==1 and w.chambered,"One cartridge transferred and chamber preserved "+id)
  check(w.ammunition_total()+int(box_bag.item(uid).rounds)==total,"Box-to-mag conservation "+id)
  check(absf(Equipment.carried_mass([w],box_bag)-weight)<0.00001,"Transfer does not change carried mass "+id)
  transfer.cancel()
  check(w.rounds()==1 and w.phase=="","Interruption restores partially filled magazine "+id)
  transfer.begin_box(w,box_bag,uid,1)
  check(not transfer.active,"Full pouch receiver rejected "+id)
  w.inspect_magazine();w.clock=1.0
  var estimate := w.inspection_estimate()
  w.cancel();w.inspect_magazine();w.clock=1.0
  check(estimate==w.inspection_estimate() and not estimate.is_empty(),"Stable coarse estimate across repeated inspections "+id)
  w.cancel();check(w.inspection_estimate().is_empty(),"No ammo estimate without physical inspection "+id)
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true);root.add_child(game)
 await process_frame
 game.volume=0;game.loadout_bag=BackpackState.new();game.loadout_bag.equipped=true
 game.loadout_bag.add("medkit")
 game.loadout_bag.add("ammo_ak74")
 game.ally_count=1;game.start_match();game.set_physics_process(false)
 var player: Operator=game.player;player.set_physics_process(false)
 for bot in game.bots+game.allies:bot.set_physics_process(false)
 check(player.backpack.items.size()==2,"Selected backpack reaches mission")
 check(game.allies[0].model.get_node("LeftArm/TeamTape").get_meta("team")=="ua","Allies wear yellow tape")
 check(game.bots[0].model.get_node("LeftArm/TeamTape").get_meta("team")=="rf","Enemies wear red tape")
 check(not PlayerClass.allows(game.player_class,"rangefinder"),"Rangefinder is no pack item: it rides on the plate carrier")
 player.field_rig.toggle_rangefinder()
 check(player.field_rig.mode=="pouch","K reaches for the chest pouch")
 check(not player.shoot(),"Retrieving equipment blocks firing")
 check(not player.field_rig.busy(),"The pouch is reached on the move")
 player.field_rig.tick(0.79);check(player.field_rig.mode=="pouch","Drawing from the pouch takes 0.8 s")
 player.field_rig.tick(0.02);check(player.field_rig.mode=="rangefinder","Rangefinder at the eyes in under a second")
 var old_transform := player.transform
 player.position=Vector3(0,100,0);player.rotation=Vector3.ZERO;player.camera.rotation=Vector3.ZERO
 var wall := StaticBody3D.new()
 var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(4,4,0.2);shape.shape=box;wall.add_child(shape)
 game.add_child(wall);wall.position=player.camera.global_position+Vector3(0,0,-20)
 await physics_frame;await physics_frame
 var reading: String=player.field_rig.measure_scene();print("RANGE ",reading)
 check(reading=="20 м · АЗ 00-00","Rangefinder measures first obstructing surface and its grid bearing")
 wall.position=player.camera.global_position+Vector3(0,0,-2)
 await physics_frame;await physics_frame
 check(player.field_rig.measure_scene()=="БЛИЖЧЕ 5 м","Rangefinder enforces minimum distance")
 # A soldier far away in front of a wall: the beam spot ranges him, even
 # when the cross sits a little beside his body.
 var soldier: Hostile=game.bots[0]
 soldier.global_position=player.camera.global_position+Vector3(0,-1.25,-220)
 soldier.rotation=Vector3.ZERO
 wall.position=player.camera.global_position+Vector3(0,0,-300)
 box.size=Vector3(80,80,0.2)
 await physics_frame;await physics_frame
 var chest: Vector3=soldier.model.to_global(Vector3(0,1.25,0))
 player.camera.look_at(chest)
 await physics_frame
 var on_body: String=player.field_rig.measure_scene()
 player.camera.look_at(chest+Vector3(0.26,0,0))
 await physics_frame
 var beside: String=player.field_rig.measure_scene()
 print("RANGE soldier ",on_body," / beside ",beside)
 check(on_body.split(" ")[0].to_int()>=217 and on_body.split(" ")[0].to_int()<=221,"Rangefinder ranges a soldier at 220 m, not the wall behind him")
 check(beside.split(" ")[0].to_int()>=217 and beside.split(" ")[0].to_int()<=221,"The beam spot still catches him 0.26 m off his chest")
 player.camera.look_at(chest+Vector3(2.0,0,0))
 await physics_frame
 check(player.field_rig.measure_scene().begins_with("29") or player.field_rig.measure_scene().begins_with("30"),"Two metres beside him the wall is ranged")
 box.size=Vector3(4,4,0.2);player.camera.rotation=Vector3.ZERO
 player.camera.rotation.x=PI/2
 check(player.field_rig.measure_scene()=="НЕМАЄ ВІДБИТТЯ","Sky produces no fabricated range")
 wall.free();player.transform=old_transform;player.camera.rotation=Vector3.ZERO
 player.field_rig.toggle_rangefinder()
 check(player.field_rig.mode=="pouch_stow","K puts it back into the pouch")
 player.field_rig.tick(0.61)
 check(not player.field_rig.active(),"Back in the pouch in 0.6 s")
 player.field_rig.toggle_rangefinder();player.field_rig.tick(0.81)
 check(player.field_rig.mode=="rangefinder","The rangefinder is reusable")
 player.field_rig.toggle_rangefinder();player.field_rig.tick(0.61)
 player.bandages=0;player.health=80;player.arm_injury=0.6
 player.current().reload(0);player.current().update(0.6);player.current().cancel()
 check(player.begin_bandage(),"Pack medkit accessible with an injured arm when belt exhausted")
 check(player.bandage_time==0,"Treatment cannot start before retrieval")
 player.field_rig.tick(3.5)
 check(player.bandage_time==6 and player.backpack.count("medkit")==1,"Retrieved medkit reserved until treatment completes")
 for i in range(361):player._physics_process(1.0/60)
 check(player.health==100 and player.backpack.count("medkit")==0,"Treatment consumes exactly one pack medkit")
 check(game.loadout_bag.count("medkit")==1,"Mission consumption leaves preset intact")
 game.queue_free();await process_frame
 print("FAIL: " if failed else "PASS: ",checks," equipment / presets / field actions checks")
 quit(1 if failed else 0)
