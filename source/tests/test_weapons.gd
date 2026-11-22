extends SceneTree
var checks := 0
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  printerr("FAIL: ",message)
  quit(1)
  assert(ok,message)
func complete(w: WeaponState):w.update(10)
func identities(w: WeaponState) -> Array:
 var result: Array=[]
 for mag in [w.magazine,w.held_old,w.held_new]+w.pouches:
  if not mag.is_empty():result.append(mag.serial)
 return result
func _initialize():
 for id in WeaponState.DATA:
  var w := WeaponState.new(id)
  # The pistols and the PKM (two spare boxes of 100) carry one pouch less.
  var count := 3 if id in ["pm","m9","pkm"] else 4
  var capacity := int(w.data.capacity)
  var initial := capacity*count
  check(w.ammunition_total()==initial,id+": finite starting ammunition")
  check(w.pouches.size()==count-1,id+": physical pouch count")
  for i in range(3):check(w.fire(),id+": shot consumes loaded round")
  var partial := w.rounds()
  check(w.reload(1),id+": selected pouch swap")
  complete(w)
  # The PKM's round on the feed tray goes back into the belt it came from.
  check(w.pouches[1].serial==1 and w.pouches[1].rounds==partial+(1 if id=="pkm" else 0),id+": partial magazine returns to selected pouch")
  check(w.magazine.serial==3,id+": chosen magazine is inserted")
  check(w.ammunition_total()+w.shots_fired==initial,id+": no rounds created by reload")
  w.reload(1)
  complete(w)
  check(w.magazine.serial==1 and w.rounds()==partial,id+": same partial magazine can be retrieved")
  var total := w.ammunition_total()
  w.inspect_chamber()
  complete(w)
  w.inspect_magazine(0)
  complete(w)
  check(w.ammunition_total()==total and w.live_ejections==0,id+": inspection neither consumes nor ejects ammunition")
  w.rack()
  w.update(0.4)
  if id=="pkm":
   # Open bolt: the chamber is empty, recocking throws nothing out.
   check(w.live_ejections==0,id+": recocking the open bolt ejects nothing")
   complete(w)
   check(w.chambered and w.cocked and w.ammunition_total()==total,id+": recocked, nothing lost")
  else:
   check(w.live_ejections==1 and not w.chambered,id+": live cartridge ejects at bolt pull")
   complete(w)
   check(w.chambered and w.ammunition_total()==total-1,id+": manual rack ejects one cartridge and chambers another")
  # Interrupt every reload checkpoint; resume cannot duplicate or lose a magazine.
  for elapsed in [0.2,0.8,1.8,2.5]:
   w.reload(0)
   w.update(elapsed)
   w.cancel()
   var serials := identities(w)
   var unique := {}
   for serial in serials:unique[serial]=true
   check(serials.size()==count and serials.size()==unique.size(),id+": magazine identities survive interruption")
   check(w.ammunition_total()+w.shots_fired+w.discarded_rounds==initial,id+": round conservation at interrupted checkpoint")
   w.reload(0)
   complete(w)
  var exhausted := WeaponState.new(id)
  for m in range(count):
   while exhausted.fire():pass
   if m<count-1:
    exhausted.reload(m)
    complete(exhausted)
  check(exhausted.ammunition_total()==0 and exhausted.shots_fired==initial,id+": all carried ammunition can be exhausted")
  exhausted.reload(0)
  complete(exhausted)
  check(not exhausted.fire(),id+": empty pouch swap cannot generate ammunition")
  exhausted.debug_infinite=true
  exhausted.reload(0)
  complete(exhausted)
  check(exhausted.fire(),id+": debug replenishes retrieved magazine")
  exhausted.debug_infinite=false
  var debug_total := exhausted.ammunition_total()
  exhausted.reload(1)
  complete(exhausted)
  check(exhausted.ammunition_total()==debug_total,id+": disabling debug stops creation")
 # The player racks the bolt himself after a magazine change; bots by drill.
 for auto in [false,true]:
  var w := WeaponState.new("ak74")
  w.auto_rack=auto
  while w.chambered or w.rounds()>0:w.fire()
  check(not w.chambered,"Empty after the last shot")
  w.reload(0);complete(w)
  check(w.rounds()>0 and w.chambered==auto,"Reload chambers a round: %s" % ("bot drill" if auto else "never for the player"))
  if not auto:
   check(not w.fire(),"Empty chamber: the trigger only clicks")
   check(w.rack(),"V racks the bolt");complete(w)
   check(w.chambered,"Racked: a round in the chamber")
 # A tactical reload keeps the chambered round without any rack.
 var tactical := WeaponState.new("ak74");tactical.auto_rack=false
 tactical.fire();tactical.reload(0);complete(tactical)
 check(tactical.chambered,"Tactical reload keeps the round in the chamber")
 print("PASS: %d magazine inventory, conservation and inspection checks" % checks)
 quit()
