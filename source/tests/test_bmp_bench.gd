extends SceneTree
# The passenger's work and the squad's rides in the great assault:
# - a magazine filled from a cartridge packet on the bench: the pack, the
#   packet and the hands in the lap, drawn in the compartment's layer, the view
#   lowered to them, the rig back on the player when done, the work stopped
#   by the way out;
# - only packets and the medkit from the pack inside;
# - «По машинах!» after a strongpoint: the vehicle waits for the player, then
#   carries the squad to the next objective and puts it down (it used to
#   drive about with the men inside);
# - the vehicle of the player's squad marked while he is out of it;
# - the player down on foot while his men ride: a man in the compartment
#   takes over there.
# Run with --fixed-fps 60.
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

func layered(node: Node, layer: int) -> bool:
 var found:=false
 for child in node.find_children("*","VisualInstance3D",true,false):
  if not child.is_visible_in_tree() or child.get_parent() is ReconDrone:continue
  found=true
  if child.layers!=layer:return false
 return found

func run():
 seed(4711)
 await bench()
 await rides()
 print("PASS" if not failed else "FAILED"," checks=",checks)
 quit(1 if failed else 0)

func bench() -> void:
 var game=await new_game()
 game.loadout_bag.equipped=true
 for kind in ["recon_drone","ammo_ak74","ammo_ak74","medkit"]:game.loadout_bag.add(kind)
 game.set_player_class("rifleman");game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 game.battle.skip_field()
 await frames(30)
 var bmp: BmpCommand=game.bmp
 var rig: FieldRig=game.player.field_rig
 var tx: MagazineTransfer=game.inventory.transfer
 check(bmp.seat=="troop","The player rides in the troop compartment (%s)" % bmp.seat)
 # The pack inside: packets and the medkit only.
 game.inventory.toggle();await frames(5)
 check(game.player.backpack.first("recon_drone")>=0,"The drone is in the pack")
 game.inventory.select_pack_item(game.player.backpack.first("recon_drone"))
 game.inventory.use_pack_item()
 check(not rig.active() and game.inventory.message.text.contains("лише пачки"),"No drone out of the pack in the compartment (%s)" % game.inventory.message.text)
 var w: WeaponState=game.player.weapons[0]
 w.pouches[0].rounds=4
 game.inventory.select_pack_item(game.player.backpack.first("ammo_ak74"))
 game.inventory.select_magazine(Vector2i(0,1))
 game.inventory.begin_transfer()
 check(tx.active,"Filling a magazine starts on the bench")
 await frames(20)
 var lap: Node3D=rig.get_parent()
 var cabin=bmp.vehicle.cabin()
 check(rig.seated and lap.name=="PassengerLap" and lap.get_parent()==cabin.holder("troop"),"The rig sits in the lap on the bench (%s under %s)" % [lap.name,lap.get_parent().name])
 check(rig.visible and layered(rig,BmpArt.INTERIOR_LAYER),"The hands and the pack are drawn in the compartment's layer")
 check(bmp.vehicle.seat_camera.current and bmp.vehicle.seat_camera.cull_mask & BmpArt.INTERIOR_LAYER,"Seen by the seat camera")
 await frames(100)
 check(bmp.look.y<-0.7,"The view goes down to the hands (pitch %.2f)" % bmp.look.y)
 check(bmp.work_text().contains("НАПЛІЧНИК") or bmp.work_text().contains("СПОРЯДЖЕННЯ"),"The hint names the work (%s)" % bmp.work_text())
 var waited:=0
 while tx.active and tx.destination.rounds<10 and waited<900:await frames(1);waited+=1
 check(tx.destination.rounds>=10,"Rounds go in one by one (%d)" % tx.destination.rounds)
 check(bmp.work_text().contains("/ 30"),"…counted in the hint (%s)" % bmp.work_text())
 waited=0
 while tx.active and waited<2400:await frames(1);waited+=1
 await frames(5)
 check(w.pouches[0].rounds==30,"The magazine is full (%d)" % w.pouches[0].rounds)
 check(not rig.seated and rig.get_parent()==game.player.camera,"The rig goes back to the player when done")
 check(layered(rig,ScopeSight.FIRST_PERSON_LAYER) or not rig.visible,"…in the first-person layer again")
 # The way out stops the work.
 w.pouches[1].rounds=0
 if not game.inventory_open:game.inventory.toggle();await frames(5)
 game.inventory.select_pack_item(game.player.backpack.first("ammo_ak74"))
 game.inventory.select_magazine(Vector2i(0,2))
 game.inventory.begin_transfer()
 waited=0
 while tx.active and tx.destination.rounds<2 and waited<900:await frames(1);waited+=1
 check(tx.active and rig.seated,"A second magazine on the bench (active %s, seated %s, rounds %d, waited %d)" % [str(tx.active),str(rig.seated),int(tx.destination.get("rounds",-1)),waited])
 bmp.vehicle.troops.unload_player()
 await frames(20)
 check(not tx.active,"Getting up for the door stops the filling")
 check(not rig.seated,"…and the hands go with the player")
 waited=0
 while bmp.seat!="" and waited<900:await frames(1);waited+=1
 check(bmp.seat=="" and rig.get_parent()==game.player.camera,"Out of the vehicle with the rig on the player")
 game.queue_free();await frames(5)

func rides() -> void:
 var game=await new_game()
 game.set_player_class("rifleman");game.battle_size=27;game.selected_map=BattleMap.ID;game.start_match()
 var battle: BattleMode=game.battle
 battle.skip_approach()
 game.player.set_physics_process(false)
 var lead: MechSquad=battle.mech[0]
 # The bench is about the rides: the enemy's grenades and drones may not
 # set his vehicle burning on the way (a roof hit through the fuel doors did).
 lead.vehicle.hull.invulnerable=true
 check(game.bmp.squad==lead and is_instance_valid(battle.vehicle_mark),"The player's squad has its vehicle marked")
 await frames(10)
 check(battle.vehicle_mark.visible and battle.vehicle_mark.text.contains("БМП-1"),"The mark shows over his BMP while he is out (%s)" % battle.vehicle_mark.text)
 check(battle.vehicle_mark.get_parent()==lead.vehicle,"…on his own vehicle")
 # The strongpoint falls: «По машинах!».
 await frames(600)
 var sector:=battle.sector
 for b in game.bots:
  if is_instance_valid(b) and not b.dead and b.get_meta("battle_sector",-1)==sector:b.take_damage(10000)
 var t:=0
 while lead.state!="pickup" and t<1200:game.player.health=100000;await frames(1);t+=1
 check(lead.state=="pickup","«По машинах!» after the strongpoint (%s)" % lead.state)
 t=0
 while not ((lead.player_called or lead.state_time>MechSquad.PICKUP_PATIENCE+5.0) and lead.vehicle.doors>0.8) and t<7200:game.player.health=100000;await frames(1);t+=1
 check(lead.aboard().size()>0,"The squad is in (%d/%d after %.0f s)" % [lead.aboard().size(),lead.living(),lead.state_time])
 check(battle.vehicle_mark.visible and battle.vehicle_mark.text.contains("ПО МАШИНАХ"),"The mark calls the player to his vehicle (%s)" % battle.vehicle_mark.text)
 await frames(300)
 game.player.health=100000
 check(lead.state=="pickup" and lead.vehicle.doors>0.8,"The vehicle waits for the player with open doors (%s, doors %.1f)" % [lead.state,lead.vehicle.doors])
 var door:=lead.vehicle.exit_point(1);door.y=game.district.ground_height(door)+0.05
 game.player.global_position=door
 game.bmp.enter("troop")
 t=0
 while lead.state=="pickup" and t<1200:await frames(1);t+=1
 check(lead.state=="transfer","With the player in, off to the next objective (%s)" % lead.state)
 check(not battle.vehicle_mark.visible,"No mark while he rides in it")
 t=0
 while lead.state=="transfer" and t<60*200:await frames(1);t+=1
 check(lead.state=="dismount","Put down at the next objective (%s after %d s)" % [lead.state,t/60])
 check(game.radio_voice.heard.has("dismount"),"«До машини!» on the radio (%s)" % str(game.radio_voice.heard))
 t=0
 while game.bmp.seat!="" and t<1200:await frames(1);t+=1
 check(game.bmp.seat=="","The player gets out with his squad")
 t=0
 while lead.state=="dismount" and t<1200:await frames(1);t+=1
 check(lead.state in ["file","assault"],"The squad goes on on foot (%s)" % lead.state)
 # Back in: the player stays out, then falls with nobody else on foot.
 lead.set_state("pickup");lead.leg=""
 t=0
 while not (lead.aboard().size()>=lead.living() and not lead.vehicle.troops.busy()) and t<6000:await frames(1);t+=1
 for actor in game.allies.duplicate():
  if is_instance_valid(actor) and actor.vehicle==null and not actor.dead:actor.take_damage(10000)
 # The vehicles hold where they are (as under the mortarman's halt): the
 # handover is checked in place, not at the next objective.
 battle.halted=true
 await frames(2)
 var riders:=lead.aboard().size()
 check(riders>0,"Men are still in the vehicle (%d)" % riders)
 check(battle.successor()!=null and battle.successor().vehicle==lead.vehicle,"The successor is a man in the compartment")
 game.player.health=0
 battle.player_fell()
 t=0
 # Nobody on foot until the handover: men of the other squads getting out
 # meanwhile would be nearer successors.
 while battle.respawn_left>0 and t<1200:
  for actor in game.allies.duplicate():
   if is_instance_valid(actor) and actor.vehicle==null and not actor.dead:actor.take_damage(10000)
  await frames(1);t+=1
 await frames(5)
 check(not battle.finished,"Not «all fighters out» with men in the vehicle (%s)" % battle.result_reason)
 check(game.bmp.seat=="troop" and game.bmp.vehicle==lead.vehicle,"The player takes over in the compartment of his BMP (seat «%s»)" % game.bmp.seat)
 check(lead.aboard().size()==riders-1,"The man he replaced has left the compartment (%d of %d)" % [lead.aboard().size(),riders])
 game.queue_free();await frames(5)
