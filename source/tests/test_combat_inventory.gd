extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 for id in WeaponState.DATA:
  var w := WeaponState.new(id)
  # The PKM's belts are changed whole from a can (test_equipment).
  if id=="pkm":
   check(not MagazineTransfer.new().begin(w,0,1),"PKM boxes are not repacked round by round")
   continue
  w.pouches[0].rounds=2
  var total := w.ammunition_total()
  var serial: int=w.magazine.serial
  var task := MagazineTransfer.new()
  check(task.begin(w,0,1),"Loaded magazine can be detached for "+id)
  check(w.magazine.is_empty() and w.chambered,"Detaching magazine preserves chamber "+id)
  check(w.ammunition_total()==total,"Detached ammo is still counted "+id)
  check(not w.fire() and not w.reload() and not w.rack(),"Busy hands block weapon operations "+id)
  task.update(1.95)
  check(task.moved==1 and int(w.pouches[0].rounds)==3,"Timed operation transfers exactly one cartridge "+id)
  check(w.ammunition_total()==total,"Per-round transfer conserves ammo "+id)
  task.cancel()
  check(int(w.magazine.serial)==serial and w.packed_magazine.is_empty() and w.phase=="","Cancellation restores exact magazine "+id)
  check(w.ammunition_total()==total,"Cancel neither duplicates nor discards ammo "+id)
  check(not task.begin(w,1,1),"Cannot transfer into same magazine "+id)
  check(task.begin(w,2,1),"Pouch to pouch transfer starts "+id)
  # A belt of 100 takes longer to fill by hand than a magazine of 30.
  for i in range(maxi(100,int(w.data.capacity)*5)):task.update(0.5)
  check(not task.active and int(w.pouches[0].rounds)==int(w.data.capacity),"Transfer stops at receiver capacity "+id)
  check(w.ammunition_total()==total,"Full transfer conserves ammo "+id)
  check(not task.begin(w,2,1),"Full receiver rejected "+id)
 var game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.start_match()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for bot in game.bots:bot.set_physics_process(false)
 var inv: CombatInventory=game.inventory
 inv.toggle()
 check(game.inventory_open and not game.paused and inv.visible,"Inventory opens during live battle")
 check(inv.tiles.size()==7,"Both loaded magazines and five pouch magazines visible")
 check(not game.player.shoot(),"Inventory cannot accidentally fire weapon")
 inv.select_magazine(Vector2i(0,1))
 inv.select_magazine(Vector2i(1,1))
 check(inv.destination.x<0,"Incompatible rifle and pistol magazines rejected")
 var w: WeaponState=game.player.weapons[0]
 w.pouches[1].rounds=0
 inv.select_magazine(Vector2i(0,2))
 inv.begin_transfer()
 check(inv.transfer.active,"Selected compatible magazines begin transfer")
 inv._process(2.0)
 var total := w.ammunition_total()
 game.paused=true
 var before := inv.transfer.moved
 inv._process(10)
 check(inv.transfer.moved==before,"Pause freezes transfer")
 game.paused=false
 game.player.apply_wound({"kind":"blunt","plate_loss":0.0,"damage":1.0,"bleeding":0.0,"pain":0.4},"plate",Vector3.FORWARD,game.player.position)
 inv._process(0.02)
 check(not inv.transfer.active and w.phase=="","New wound interrupts transfer")
 check(w.ammunition_total()==total,"Interrupted transfer preserves all rounds")
 game.player.injury_time=0
 inv.use_medicine()
 check(game.player.bandage_time==6 and game.player.bandages==2,"Inventory starts normal six-second medical action")
 for i in range(361):game.player._physics_process(1.0/60)
 check(game.player.health==100 and game.player.bandages==1,"Medical action consumes one kit on completion")
 check(game.medkit_tiles.size()==Operator.BELT_MEDKITS,"Loadout shows both belt medkits")
 var bag: BackpackState=game.player.backpack
 bag.equipped=true
 var kit:=bag.add("medkit");bag.add("medkit")
 var mass_before:float=game.player.carried_mass()
 var rig: FieldRig=game.player.field_rig
 inv.refresh()
 check(inv.belt_tiles.size()==2 and inv.belt_tiles[0].preview.visible and not inv.belt_tiles[1].preview.visible,"Belt shows the remaining kit and one empty pouch")
 inv.attach_medkit(0)
 check(rig.mode=="","Occupied belt pouch takes no kit")
 inv.select_pack_item(kit)
 inv.attach_medkit(1)
 check(rig.mode=="access" and rig.to_belt and not inv.visible,"Empty belt pouch takes the selected kit from the backpack")
 check(game.player.bandages==1 and bag.count("medkit")==2,"Kit stays in the backpack until it is in hand")
 rig.tick(FieldRig.ACCESS_TIME+0.01)
 check(game.player.bandages==2 and bag.count("medkit")==1 and bag.item(kit).is_empty() and rig.mode=="belt","Selected kit moves from backpack to belt")
 rig.tick(FieldRig.BELT_TIME+0.01)
 check(rig.mode=="" and not rig.busy(),"Clipping the kit to the belt ends the action")
 check(is_equal_approx(mass_before,game.player.carried_mass()),"Moving a kit to the belt keeps the carried mass")
 inv.toggle()
 inv.attach_medkit(1)
 check(rig.mode=="" and bag.count("medkit")==1,"Full belt takes no more kits")
 inv.close()
 check(not game.inventory_open and not inv.visible,"Closing restores game input")
 inv.toggle()
 inv.select_magazine(Vector2i(0,1))
 inv.select_magazine(Vector2i(0,2))
 inv.begin_transfer()
 inv._process(2.0)
 game.to_menu()
 check(not inv.transfer.active and not game.inventory_open,"Returning to menu cancels transfer safely")
 game.queue_free()
 for i in range(4):await process_frame
 print("FAIL: " if failed else "PASS: ",checks," ammunition conservation, inventory and medical checks")
 quit(1 if failed else 0)
