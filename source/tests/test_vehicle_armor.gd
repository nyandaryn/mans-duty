extends SceneTree
# Armour and damage of vehicles: the BMP-2 plates against the PG-7VL, the
# RPG-22, the 30 mm armour-piercing and bullets; a grenade fired at a BMP in
# the great assault goes through its side and works behind it; fire makes
# the crew bail out and ends in the ammunition going up; an FPV warhead on
# the rocket package of a «Grad» cooks off the rockets and the vehicle
# goes up in a big explosion and burns.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func geometry() -> void:
 var a:=VehicleArmor.bmp2()
 # Level shots (vehicle frame: -Z forward, +X right).
 var front:=a.resolve(Vector3(0,1.25,-2.9),Vector3(0,0,1),"ap30",35.0,0.0)
 check(not front.penetrated and float(front.los)>30.0,"30 mm AP at 500 m does not go through the upper glacis laid back at 80° (%.0f mm in line)" % float(front.los))
 var side:=a.resolve(Vector3(1.64,1.30,0.3),Vector3(-1,0,0),"ap30",35.0,0.0)
 check(side.penetrated,"…it goes through the 16 mm side")
 var bullet:=a.resolve(Vector3(1.64,1.30,0.3),Vector3(-1,0,0),"bullet",8.0,0.0)
 check(not bullet.penetrated,"A rifle bullet does not")
 var heat:=a.resolve(Vector3(1.64,1.20,1.2),Vector3(-1,0,0),"pg7vl",500.0,0.0)
 var kinds:=[]
 for hit in heat.hits:kinds.append(hit.part.kind)
 check(heat.penetrated and "troop" in kinds,"PG-7VL into the troop compartment: through, among the benches (%s)" % str(kinds))
 var rear:=a.resolve(Vector3(0.5,0.95,3.40),Vector3(0,0,-1),"rpg22",390.0,0.0)
 kinds=[]
 for hit in rear.hits:kinds.append(hit.part.kind)
 check(rear.penetrated and "fuel" in kinds,"RPG-22 into a rear door: the door tank (%s)" % str(kinds))
 var turret:=a.resolve(Vector3(0,1.9,-1.15),Vector3(0,0,1),"ap30",35.0,0.0)
 check(turret.plate.get("turret",false),"A shot at the turret front meets the turret (%s)" % turret.plate.get("title",""))
 var glance:=a.resolve(Vector3(0,1.63,1.0),Vector3(0,-0.05,1).normalized(),"pg7vl",500.0,0.0)
 check(glance.get("glanced",false) and not glance.penetrated,"Along the roof the grenade skids off")
 var b:=VehicleArmor.bm21()
 var pack:=b.resolve(Vector3(0,2.69,1.3),Vector3(0,-1,0),"bullet",6.0,0.0)
 kinds=[]
 for hit in pack.hits:kinds.append(hit.part.kind)
 check(pack.penetrated and "rockets" in kinds,"BM-21: a bullet goes through the tubes into the rockets (%s)" % str(kinds))
 # Sight tables of the grenades from their flight.
 var t300:=BlastSystem.rocket_time("pg7vl",300.0)
 check(t300>1.25 and t300<1.55,"PG-7VL reaches 300 m in about 1.3–1.4 s (%.2f)" % t300)
 var e22:=BlastSystem.rocket_elevation("rpg22",150.0)
 check(e22>0.02 and e22<0.07,"RPG-22 at 150 m needs %.1f mrad" % (e22*1000.0))

func run():
 seed(5521)
 geometry()
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("rifleman");game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 var battle: BattleMode=game.battle
 battle.skip_approach()
 game.set_debug_invulnerable(true)
 for actor in game.bots:actor.set_physics_process(false)
 await frames(5)
 # A BMP of ours, its crew aboard, the squad out: a PG-7VL into its side
 # from 120 m.
 var squad: MechSquad=battle.mech[0]
 var v: BmpVehicle=squad.vehicle
 var crew_before:=v.crew.size()
 var side:=v.global_basis.x
 var aim:=v.to_global(Vector3(0,1.25,0.6))
 var origin:=aim+side*120.0
 # From whichever side the line to it is clear.
 var space: PhysicsDirectSpaceState3D=v.get_world_3d().direct_space_state
 for k in range(16):
  var away:=(side if k%2==0 else -side).rotated(Vector3.UP,float(k/2)*0.12*(1 if k%4<2 else -1))
  var p:=aim+away*120.0
  p.y=game.district.ground_height(p)+1.6
  var first:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p,aim,1|16))
  if first.get("collider")==v:origin=p;side=away;break
 # Laid with the elevation of the sight for the range.
 var line:=origin.direction_to(aim)
 var lift:=BlastSystem.rocket_elevation("pg7vl",origin.distance_to(aim))
 line=line.rotated(line.cross(Vector3.UP).normalized(),lift)
 game.blasts.launch(origin,line,game.player,"pg7vl")
 var t:=0.0
 var detonations_before: int=game.blasts.detonations
 while v.hull.hits==0 and t<3.0:
  await physics_frame;t+=1.0/60.0
 if v.hull.hits==0:
  var probe:=space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,aim,1|16))
  printerr("debug: last burst %s, vehicle %s, origin %s, first on the line %s" % [str(game.blasts.last_detonation),str(v.global_position),str(origin),str(probe.get("collider"))+" at "+str(probe.get("position"))])
 check(v.hull.hits==1 and v.hull.penetrations==1,"The grenade struck the side and went through (%s)" % str(v.hull.history))
 check(t>0.3 and t<0.9,"…after %.2f s of flight for 120 m" % t)
 # Until it burns.
 var shots:=1
 while not v.hull.burning and not v.destroyed and shots<6:
  var spot:=v.to_global(Vector3(0,1.2,randf_range(-0.6,2.4)))
  game.blasts.warhead("heat",spot+side*1.6,-side,v,null)
  shots+=1
 check(v.hull.burning or v.destroyed,"A few hits set it on fire (%d, %s)" % [shots,str(v.hull.history)])
 await frames(30)
 check(v.crew.size()<crew_before or v.crew.is_empty(),"The crew are out of the burning vehicle or dead")
 if not v.destroyed:v.hull.fire_left=0.2
 await frames(30)
 check(v.destroyed and v.hull.catastrophic,"The fire set off the ammunition")
 check(v.gunner.target==null or not v.gunner.manned,"Its gun is silent")
 # The «Grad»: an FPV on its rocket package.
 var grad:=GradVehicle.new();game.world_root.add_child(grad);grad.setup(game)
 var spot2: Vector3=game.player.global_position+Vector3(30,0,30)
 spot2.y=game.district.ground_height(spot2)+0.3
 grad.global_position=spot2
 await frames(20)
 var package:=grad.to_global(GradArt.TURNTABLE+Vector3(0,0.95,0))
 var before:int=game.blasts.detonations
 game.blasts.warhead("heat",package,Vector3(0,-0.8,0.6).normalized(),grad,null)
 check(grad.cooking or grad.hull.burning,"An FPV on the package lights the rockets (%s)" % str(grad.hull.history))
 grad.hull.fire_left=minf(grad.hull.fire_left,1.0)
 await frames(120)
 check(grad.destroyed and grad.remaining()==0,"The package went up (%d left)" % grad.remaining())
 check(game.blasts.detonations>=before+2,"…in a big explosion (%d bursts)" % (game.blasts.detonations-before))
 check(grad.hull.burning and is_instance_valid(grad.hull.flames),"The wreck burns and smokes")
 # A Grad hit in the cab by a bullet does not blow up.
 var grad2:=GradVehicle.new();game.world_root.add_child(grad2);grad2.setup(game)
 grad2.global_position=spot2+Vector3(12,0,0)
 await frames(5)
 grad2.vehicle_hit(grad2.to_global(Vector3(0,2.0,-2.2)),grad2.global_basis.z,"bullet",6.0)
 check(not grad2.destroyed and grad2.remaining()==40,"A bullet through the cab leaves the package alone")
 print("vehicle armor: %d checks, %s" % [checks,"FAILED" if failed else "ok"])
 quit(1 if failed else 0)
