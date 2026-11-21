extends SceneTree
# Heavy fire brings the village of the great assault down:
# - every house is registered with its footprint, the closed ones drawn whole
#   into one block of the merged scenery;
# - one mortar bomb does not bring a house down, three do: the walls leave
#   the scene and the collision, a heap of rubble takes the footprint;
# - one «Grad» rocket collapses a brick house of a strongpoint, and the man
#   inside is buried;
# - a rifle bullet goes through a fence of sheet steel (and on into what is
#   behind), a soldier behind it is hidden but not covered;
# - a burst puts the nearest fence panels over.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):await physics_frame

func ray(game: Node, a: Vector3, b: Vector3) -> Dictionary:
 return game.district.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))

func run():
 seed(321)
 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 game.set_player_class("rifleman");game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 var battle: BattleMode=game.battle
 battle.skip_approach()
 game.player.set_physics_process(false)
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 for squad in battle.mech:squad.set_physics_process(false);squad.vehicle.gunner.allowed=false
 await frames(5)
 var houses: Array=game.district.get_meta("houses",[])
 var full: Array=houses.filter(func(h):return h.full)
 check(houses.size()>150,"The houses of the village are registered (%d)" % houses.size())
 check(full.size()>=6 and full.size()<=9,"…the brick houses of the strongpoints among them (%d)" % full.size())
 # A closed house well away from the player.
 var target: Dictionary={}
 for house in houses:
  if house.full or not is_instance_valid(house.body) or Vector2(house.half).x<2.5 or Vector2(house.half).y<2.5:continue
  if Vector3(house.center).distance_to(game.player.global_position)<40.0:continue
  target=house;break
 check(not target.is_empty(),"A closed house to shell")
 var block: MeshInstance3D=target.block
 check(is_instance_valid(block) and block.get_meta("color_mesh").vertices.size()>=target.range.y and target.range.y>target.range.x,"…drawn into one block (%s)" % str(target.range))
 var basis:=Basis(Vector3.UP,float(target.yaw))
 var center: Vector3=target.center
 var half: Vector2=target.half
 var wall:=center+basis*Vector3(half.x+0.03,1.6,0)
 var across_a:=center+basis*Vector3(-half.x-3.0,2.0,0)+Vector3.UP*0.6
 var across_b:=center+basis*Vector3(half.x+3.0,2.0,0)+Vector3.UP*0.6
 check(not ray(game,across_a,across_b).is_empty() and ray(game,across_a,across_b).collider==target.body,"The house stops a line through it")
 var body: Node=target.body
 game.blasts.detonate(wall,"mine")
 await frames(3)
 check(not target.down and is_instance_valid(body),"One mortar bomb on the wall does not bring it down (%.0f left)" % target.hp)
 game.blasts.detonate(wall,"mine");game.blasts.detonate(wall,"mine")
 await frames(5)
 check(target.down,"Three bring it down")
 check(not is_instance_valid(body),"The house's body has left the scene")
 var mesh: ColorMesh=block.get_meta("color_mesh")
 var flat:=true
 for i in range(target.range.x,target.range.y):
  if mesh.vertices[i]!=mesh.vertices[target.range.x]:flat=false;break
 check(flat,"…and its block")
 var down:=ray(game,center+Vector3.UP*12,center+Vector3.DOWN*2)
 check(not down.is_empty() and down.collider.has_meta("rubble") and down.position.y<center.y+1.8,"A heap of rubble lies in its footprint (%s)" % (str(down.position.y-center.y) if not down.is_empty() else "nothing"))
 var high:=ray(game,across_a+Vector3.UP*1.5,across_b+Vector3.UP*1.5)
 check(high.is_empty() or not high.collider==down.get("collider"),"Above the heap the line is open")
 check(game.district.find_children("Rubble","MeshInstance3D",false,false).size()>=1,"The heap is drawn")
 # A Grad rocket on a strongpoint house with a man inside.
 var keep: Dictionary=full[0]
 var kb:=Basis(Vector3.UP,float(keep.yaw))
 var kc: Vector3=keep.center
 var man: Hostile=null
 for bot in game.bots:
  if is_instance_valid(bot) and not bot.dead:man=bot;break
 man.global_position=kc+kb*Vector3(0,0.1,-Vector2(keep.half).y*0.23)
 check(Demolition.inside(keep,man.global_position+Vector3.UP*0.3,0.2),"A defender inside the brick house")
 var line_a:=kc+kb*Vector3(-Vector2(keep.half).x-2.0,2.2,0);var line_b:=kc+kb*Vector3(Vector2(keep.half).x+2.0,2.2,0)
 check(not ray(game,line_a,line_b).is_empty(),"Its walls stand")
 game.blasts.detonate(kc+Vector3.UP*(float(keep.height)-1.2),"grad")
 await frames(5)
 check(keep.down,"One Grad rocket brings the brick house down")
 check(man.dead and man.get_meta("buried",false),"The man inside is buried")
 await frames(2)
 check(not man.visible,"…under the rubble, out of sight")
 check(ray(game,line_a,line_b).is_empty(),"The walls are gone above the heap")
 # Fences: sheet steel and boards, both shot through.
 var steel: Array=[];var boards: Array=[]
 for child in game.district.get_children():
  if child is DestructibleSurface and child.has_meta("crushable") and not child.breaking:
   if child.has_meta("sheet_scale"):steel.append(child)
   else:boards.append(child)
 check(steel.size()>100 and boards.size()>20,"Fences of sheet steel and of boards (%d / %d)" % [steel.size(),boards.size()])
 check(Penetration.remaining("ak74",880,"steel",BattleMap.SHEET)>1000.0,"A 5.45 round keeps most of its energy through the sheet")
 var panel: DestructibleSurface=null
 var front:=Vector3.ZERO;var normal:=Vector3.ZERO
 for candidate in steel:
  var n: Vector3=candidate.global_basis.z;n.y=0;n=n.normalized()
  var p: Vector3=candidate.global_position+n*3.0
  var hit:=ray(game,p,candidate.global_position)
  var back:=ray(game,candidate.global_position-n*0.1,candidate.global_position-n*2.6)
  if not hit.is_empty() and hit.collider==candidate and back.is_empty():panel=candidate;front=p;normal=n;break
 check(panel!=null,"A clear panel of sheet steel to shoot through")
 game.district.surface_piece(panel.global_position-normal*2.2,Vector3(2,2,2),Color.GRAY,"concrete")
 await frames(2)
 var before: int=game.ballistics.hit_count
 game.ballistics.launch(front,-normal,"ak74",30,game.player)
 await frames(8)
 check(game.ballistics.hit_count-before==2,"The round goes through the fence into the block behind (%d hits)" % (game.ballistics.hit_count-before))
 var guard: Hostile=game.allies[0]
 check(not guard.line_clear(front,panel.global_position-normal*0.5) and guard.cover_clear(front,panel.global_position-normal*0.5),"Behind the fence a man is hidden, not covered")
 # A burst beside the fence puts it over.
 var near: Array=[]
 for other in steel+boards:
  if is_instance_valid(other) and not other.breaking and other.global_position.distance_to(panel.global_position)<3.0:near.append(other)
 game.blasts.detonate(panel.global_position+normal*1.0+Vector3.DOWN*0.6,"grad")
 await frames(5)
 var standing:=0
 for other in near:
  if is_instance_valid(other) and not other.breaking:standing+=1
 check(standing==0,"A rocket beside the fence puts the nearest panels over (%d of %d stand)" % [standing,near.size()])
 game.queue_free();await frames(5)
 print("PASS" if not failed else "FAILED"," checks=",checks)
 quit(1 if failed else 0)
