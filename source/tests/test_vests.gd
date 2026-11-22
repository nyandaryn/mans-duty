extends SceneTree
# Body armour: the Korsar M3s, the 6B45 and a plate carrier.
# - Plates hold rifle rounds up to their class and give way when broken up;
#   soft armour round the torso stops a PM round, the carrier has none;
# - the vest keeps off a share of a burst's fragments by what it covers;
# - its weight slows the run (Equipment.run_multiplier, Hunt et al. 2016);
# - the loadout chooses it, the player and the bots wear it (model, plates).
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func run():
 seed(3302)
 # --- The tables ------------------------------------------------------------------
 var k:=VestKind.blast_factor("korsar")
 var r:=VestKind.blast_factor("ratnik")
 var c:=VestKind.blast_factor("carrier")
 check(k<0.65 and r<0.65 and c>0.72 and c<0.85,"Fragments through: Korsar %.2f, 6B45 %.2f, carrier %.2f" % [k,r,c])
 check(VestKind.plate_holds("korsar",1.0,1.0) and VestKind.plate_holds("ratnik",1.0,1.0) and VestKind.plate_holds("carrier",1.0,1.0),"Whole plates of every class hold a rifle round at the muzzle")
 check(not VestKind.plate_holds("korsar",1.0,0.1) and VestKind.plate_holds("ratnik",1.0,0.1) and VestKind.plate_holds("carrier",1.1,0.1) and not VestKind.plate_holds("carrier",0.5,0.0),"Broken up, the class 4 plate gives way first, the class 6 last")
 var w:=DamageModel.wound("plate","pkm",1.0,Vector2.ZERO,1.0,"korsar")
 check(w.kind=="blunt","PKM into the Korsar's plate: a blow, not a wound (%s)" % w.kind)
 var pm_soft:=DamageModel.wound("chest","pm",1.0,Vector2.ZERO,1.0,"korsar")
 var pm_bare:=DamageModel.wound("chest","pm",1.0,Vector2.ZERO,1.0,"carrier")
 check(pm_soft.kind=="blunt" and pm_bare.kind=="thoracic","A PM round on the Korsar's soft armour bruises, beside a carrier's plate it wounds (%s / %s)" % [pm_soft.kind,pm_bare.kind])
 var rifle_soft:=DamageModel.wound("abdomen","ak74",1.0,Vector2.ZERO,1.0,"ratnik")
 check(rifle_soft.kind=="internal","A rifle round goes through the soft armour")
 # --- Weight and the run -------------------------------------------------------------
 var bag:=BackpackState.new()
 var weapons:=[WeaponState.new("ak74"),WeaponState.new("pm")]
 var mk:=Equipment.carried_mass(weapons,bag,2,"korsar")
 var mr:=Equipment.carried_mass(weapons,bag,2,"ratnik")
 var mc:=Equipment.carried_mass(weapons,bag,2,"carrier")
 check(is_equal_approx(mk-mc,VestKind.mass("korsar")-VestKind.mass("carrier")) and mk>mr and mr>mc,"The vest's mass is carried (%.1f / %.1f / %.1f kg)" % [mk,mr,mc])
 var vk:=Equipment.run_multiplier(mk)
 var vc:=Equipment.run_multiplier(mc)
 check(vc>vk and absf(vc/vk-(1.0+0.008*(mk-10.0))/(1.0+0.008*(mc-10.0)))<0.0001,"…and slows the run by the Hunt formula (%.1f vs %.1f km/h)" % [6.3*3.6*vk,6.3*3.6*vc])
 # --- In the game -----------------------------------------------------------------
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.choose_vest("ratnik")
 check(game.player_vest=="ratnik" and game.loadout_screen.vest_buttons["ratnik"].button_pressed,"The loadout chooses the 6B45")
 check(game.loadout_screen.load_label.text.contains("%.1f" % Equipment.carried_mass([WeaponState.new(game.primary),WeaponState.new(game.secondary)],game.loadout_bag,2,"ratnik")),"…the load shown counts it (%s)" % game.loadout_screen.load_label.text)
 game.choose_vest("carrier")
 game.set_player_class("rifleman");game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 game.battle.skip_approach()
 await frames(3)
 var p: Operator=game.player
 check(p.vest=="carrier" and is_equal_approx(p.plates[0].get_child(0).shape.size.x,0.25),"The player wears the carrier, its plates 25 × 30 cm")
 check(p.world_body.model.get_node_or_null("Vest")!=null,"…its model on his body")
 var ours:={}
 var theirs:={}
 for actor in game.allies:
  if actor.get_meta("battle_managed",false):ours[actor.vest]=int(ours.get(actor.vest,0))+1
 for actor in game.bots:theirs[actor.vest]=int(theirs.get(actor.vest,0))+1
 check(int(ours.get("korsar",0))>int(ours.get("carrier",0)) and int(ours.get("carrier",0))>0 and not ours.has("ratnik"),"Our men wear the Korsar, a few a carrier (%s)" % str(ours))
 check(int(theirs.get("ratnik",0))>int(theirs.get("carrier",0)) and int(theirs.get("carrier",0))>0 and not theirs.has("korsar"),"Theirs the 6B45, a few a carrier (%s)" % str(theirs))
 var sample: Hostile=game.bots[0]
 var plate: Area3D=null
 for area in sample.hitboxes:
  if area.get_meta("zone","")=="plate":plate=area;break
 check(sample.model.get_node_or_null("Vest")!=null and plate!=null and Vector3(plate.get_child(0).shape.size).is_equal_approx(VestKind.plate_box(sample.vest)),"A bot's vest is on him, its plates of their size")
 # The same burst on a man in the Korsar and in a carrier.
 for actor in game.allies+game.bots:actor.set_physics_process(false)
 # One man, the same place, the same burst: first in the 6B45, then in a
 # carrier.
 var a: Hostile=null
 for actor in game.bots:
  if not actor.dead and actor.vehicle==null:a=actor;break
 var spot: Vector3=game.player.global_position+Vector3(60,0,60)
 spot.y=game.district.ground_height(spot)
 a.global_position=spot
 a.wear_vest("ratnik");a.health=1000.0
 await frames(2)
 game.blasts.detonate(spot+Vector3(3.5,0.2,0),"mine")
 var lost_a:=1000.0-a.health
 a.wear_vest("carrier");a.health=1000.0
 await frames(2)
 game.blasts.detonate(spot+Vector3(3.5,0.2,0),"mine")
 var lost_b:=1000.0-a.health
 check(lost_a>0.0 and lost_b>lost_a*1.15,"A burst hurts the man in the 6B45 less than the one in a carrier (%.0f vs %.0f)" % [lost_a,lost_b])
 print("vests: %d checks, %s" % [checks,"FAILED" if failed else "ok"])
 quit(1 if failed else 0)
