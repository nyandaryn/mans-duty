extends SceneTree
# «По машинах!» at the start of the great assault, waited out rather than
# skipped: a gunner who ends up behind the stern goes round the hull to his
# turret hatch (straight at it he stood against the stern, and the column
# waited for him for ever); a man who cannot get to the doors at all climbs
# in once the squad has boarded for 45 s. Run with --fixed-fps 60.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(count: int) -> void:
 for i in range(count):await physics_frame

func run():
 seed(4711)
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("rifleman");game.battle_size=27;game.selected_map=BattleMap.ID;game.start_match()
 await frames(5)
 var battle: BattleMode=game.battle
 check(battle.prep=="barrage" and battle.mech.size()==3,"The start: the battery's fire, three squads on the field")
 # The gunner of the second squad behind the stern, by the right door: where
 # he stood stuck at size 54.
 var squad: MechSquad=battle.mech[1]
 var gunner: Hostile=squad.gunner_out
 check(is_instance_valid(gunner) and gunner.vehicle==null,"The gunner waits outside his vehicle")
 var behind: Vector3=squad.vehicle.to_global(Vector3(1.19,0,3.62))
 behind.y=game.district.ground_height(behind)+0.1
 gunner.global_position=behind
 # A man of the third squad who cannot walk to the doors.
 var held: MechSquad=battle.mech[2]
 var stuck: Hostile=held.on_foot()[3]
 var away: Vector3=held.vehicle.to_global(Vector3(-15,0,8))
 away.y=game.district.ground_height(away)+0.1
 stuck.global_position=away
 stuck.set_physics_process(false)
 await frames(2)
 battle.begin_mount()
 var gunner_in:=-1.0
 var held_in:=-1.0
 var held_out_at_40:=false
 for i in range(60*60):
  await physics_frame
  if gunner_in<0.0 and gunner.vehicle==squad.vehicle:gunner_in=i/60.0
  if i==60*40:held_out_at_40=stuck.vehicle==null and held.state=="board"
  if held_in<0.0 and stuck.vehicle==held.vehicle:held_in=i/60.0
  if gunner_in>=0.0 and held_in>=0.0 and squad.state=="wait" and held.state=="wait":break
 print("gunner in at %.1f s, the held man in at %.1f s" % [gunner_in,held_in])
 check(gunner_in>=0.0 and gunner_in<25.0,"From behind the stern the gunner goes round the hull and in (%.1f s)" % gunner_in)
 check(squad.state=="wait" and squad.vehicle.gunner.manned,"…his squad is boarded and waits for the column (%s)" % squad.state)
 check(not squad.vehicle.doors_wanted,"…its rear doors shut")
 check(held_out_at_40,"A man who cannot reach the doors keeps his squad boarding for a while")
 check(held_in>=MechSquad.BOARD_PATIENCE-1.0 and held_in<MechSquad.BOARD_PATIENCE+3.0,"…and climbs in once it has boarded for %d s (%.1f s)" % [roundi(MechSquad.BOARD_PATIENCE),held_in])
 check(held.state=="wait","…and the squad waits for the column (%s)" % held.state)
 game.queue_free()
 await process_frame
 if checks<8:check(false,"Every step ran (%d checks)" % checks)
 print("%s: %d boarding checks" % ["FAILED" if failed else "PASS",checks])
 quit(1 if failed else 0)
