extends SceneTree
# One grenade-launcher hit through a BMP's thin armour puts it out of action
# nearly always: the PG-7VL's and the RPG-22's jets and spall set the fuel,
# the hydraulics and the ammunition going — an explosion at once or a fire
# the crew bails out of, ending in the ammunition going up.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

class Hull extends Node3D:
 var game: Node3D
 var hull: VehicleDamage
 func occupants() -> Array:return []
 func turret_yaw() -> float:return 0.0

func trial(game: Node3D, round: String, pen: float, point: Vector3, direction: Vector3) -> Dictionary:
 var body:=Hull.new()
 body.game=game
 game.world_root.add_child(body)
 body.hull=VehicleDamage.new()
 body.hull.setup(body,VehicleArmor.bmp2())
 var result:=body.hull.strike(body.to_global(point),body.global_basis*direction,round,pen)
 var lost:=body.hull.burning or body.hull.destroyed
 var outcome:={"penetrated":result.get("penetrated",false),"lost":lost,"blown":body.hull.destroyed}
 body.queue_free()
 return outcome

func run():
 seed(7301)
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.selected_map=TrainingRange.ID
 game.start_match()
 for i in range(5):await physics_frame
 # Level shots at the hull side and the turret, front and rear of the
 # troop compartment, from either side.
 for round in ["pg7vl","rpg22"]:
  var pen: float=VehicleArmor.penetration(round)
  var through:=0;var lost:=0;var blown:=0;var count:=0
  for k in range(60):
   var side:=1.0 if k%2==0 else -1.0
   var point:=Vector3(side*1.64,randf_range(0.9,1.45),randf_range(-2.0,2.6))
   if k%5==0:point=Vector3(side*0.95,1.9,randf_range(-1.2,-0.3))
   var outcome:=trial(game,round,pen,point,Vector3(-side,0,0))
   count+=1
   if outcome.penetrated:through+=1
   if outcome.lost:lost+=1
   if outcome.blown:blown+=1
  check(through==count,"%s goes through the BMP's side every time (%d / %d)" % [round,through,count])
  var floor_share:=0.88 if round=="pg7vl" else 0.78
  check(float(lost)/count>=floor_share,"%s: one hit puts the BMP out of action (%d / %d burning or blown up)" % [round,lost,count])
  check(blown>0 and blown<count,"%s: some blow up at once, the rest burn (%d / %d)" % [round,blown,count])
 # A 30 mm round through the side is not such a sure kill.
 var ap_lost:=0
 for k in range(40):
  var outcome:=trial(game,"ap30",35.0,Vector3(1.64,randf_range(0.9,1.45),randf_range(-2.0,2.6)),Vector3(-1,0,0))
  if outcome.lost:ap_lost+=1
 check(ap_lost<30,"A 30 mm AP round does not set it going as surely (%d / 40)" % ap_lost)
 print("%s: %d rpg lethality checks" % ["FAILED" if failed else "PASS",checks])
 quit(1 if failed else 0)
