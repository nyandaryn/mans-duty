extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  failed=true
  printerr("FAIL: ",message)
  quit(1)
  assert(ok,message)
func _initialize():call_deferred("run")
func run():
 var progress := Campaign.new()
 check(Campaign.IDS.size()==10,"Ten authored missions")
 for id in Campaign.IDS:
  check(progress.unlocked(id)==(id in ["forest_01","village_01"]),"Only each branch's entry is open")
 check(not progress.complete("district_02"),"Cannot complete a locked mission")
 for id in Campaign.IDS:
  check(progress.complete(id),"Sequential completion unlocks the next stage")
 check(progress.completed.size()==10,"Both branches can be completed")
 var save := "user://campaign_test.cfg"
 check(progress.save_progress(save)==OK,"Progress saves")
 var restored := Campaign.new()
 restored.load_progress(save)
 check(restored.completed==progress.completed,"Progress round trip")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
 var signatures: Array[float]=[]
 for id in Campaign.IDS:
  var mission := Campaign.mission(id)
  check(mission.size==400,"Every mission is 400 by 400 metres")
  var terrain := CampaignTerrain.new()
  root.add_child(terrain)
  terrain.configure(mission)
  check(terrain.maximum-terrain.minimum>3,"Each map has meaningful relief")
  check(terrain.heights.size()==401*401,"Terrain samples cover the entire playable square")
  signatures.append(terrain.height_at(Vector2(77,33)))
  for building in mission.buildings:
   var p: Vector2=building.point
   check(absf(terrain.height_at(p)-terrain.height_at(p+Vector2(2,2)))<0.1,"Habitable building pads remain level")
  if mission.kind=="forest":
   check(mission.trenches.size()>=2 and mission.belts.size()>=2,"Forest layouts have distinct belts and trench networks")
   var trench: Array=mission.trenches[0]
   var middle: Vector2=(Vector2(trench[0])+Vector2(trench[1]))*0.5
   var depth := 0.0
   for step in range(10,90):
    var sample: Vector2=Vector2(trench[0]).lerp(trench[1],step/100.0)
    depth=maxf(depth,terrain.base_height(sample)-terrain.sculpt(sample))
   check(depth>1.4,"Trenches are excavated below terrain between firing steps")
  if id=="forest_01":
   terrain.build_geometry()
   for i in range(2):await physics_frame
   var space := terrain.get_world_3d().direct_space_state
   for p in [Vector2(0,175),Vector2(77.3,33.7),Vector2(-60,-27.5),Vector2(199,199)]:
    var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,50,p.y),Vector3(p.x,-50,p.y),1))
    check(not hit.is_empty(),"Terrain collision exists across the playable square")
    check(absf(hit.position.y-terrain.height_at(p))<0.02,"Sampled height matches actual collision, including slopes")
  terrain.free()
 check(signatures.size()==10,"All ten terrain definitions exercised")
 for i in range(1,10):check(not is_equal_approx(signatures[i],signatures[i-1]),"Maps do not reuse the same height field")
 print("FAIL: " if failed else "PASS: ",checks," campaign catalog, progression, relief, trenches and collision checks")
 quit(1 if failed else 0)
