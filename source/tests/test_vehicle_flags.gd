extends SceneTree

# Flags on the vehicles fly from staffs, not painted on the plates:
# - a BMP of ours: the flag of Ukraine tied to the turret's whip (it turns
#   with the turret), above the heads of the men in the hatches, clear of the
#   doors; nothing painted on ours;
# - theirs: the tricolour on the whip, the «Z» painted on the hull and vane;
# - a BM-21: the flag of Ukraine on a staff behind the cab, over the roof,
#   clear of the mirrors and the package in travel;
# - one cloth mesh per flag kind, one material for all, a shadow, no
#   collider; the cloth's bounds hold the waving cloth; the travel of the
#   vehicle reaches the shader only when it changes.
var checks := 0
var failed := false
var game: Node3D
func check(ok: bool, message: String):
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await physics_frame

func bands_in(node: MeshInstance3D) -> Array:
 var found: Array=[]
 var arrays:=node.mesh.surface_get_arrays(0)
 for c in arrays[Mesh.ARRAY_COLOR]:
  var srgb: Color=(c as Color).linear_to_srgb()
  var known:=false
  for f in found:known=known or (f as Color).is_equal_approx(srgb)
  if not known:found.append(srgb)
 return found

func run():
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.selected_map=TrainingRange.ID
 game.start_match()
 await frames(5)
 var ours:=BmpVehicle.new();ours.friendly=true;game.world_root.add_child(ours);ours.setup(game)
 var theirs:=BmpVehicle.new();theirs.friendly=false;game.world_root.add_child(theirs);theirs.setup(game)
 theirs.global_position=Vector3(12,0,0)
 var grad:=GradVehicle.new();grad.friendly=true;game.world_root.add_child(grad);grad.setup(game)
 grad.global_position=Vector3(-14,0,0)
 await frames(3)
 # --- BMP, ours -------------------------------------------------------------
 var flag: MeshInstance3D=ours.art.turret.get_node_or_null("Flag")
 check(flag!=null,"Our BMP flies a flag")
 check(flag!=null and flag.get_parent()==ours.art.turret,"…from the turret (it turns with it)")
 check(flag!=null and flag.get_meta("bands")==VehicleMarkings.UKRAINE,"…the flag of Ukraine")
 check(ours.art.root.get_node_or_null("Markings")==null and ours.art.turret.get_node_or_null("Markings")==null,"Nothing painted on ours")
 # Tied to the whip (BmpArt: x 0.75, z 0.70 of the turret, 0.70…2.70 up).
 check(flag!=null and is_equal_approx(flag.position.x,0.75) and is_equal_approx(flag.position.z,0.70) and flag.position.y-VehicleMarkings.FLAG_SIZE.y*0.5>0.70+1.0 and flag.position.y+VehicleMarkings.FLAG_SIZE.y*0.5<2.70,"The hoist on the whip, under its tip and well over the turret roof")
 var world_low: float=ours.art.turret.to_global(flag.position).y-VehicleMarkings.FLAG_SIZE.y*1.2-ours.global_position.y
 check(world_low>BmpArt.TROOP_EYE.y+1.0 and world_low>BmpArt.DRIVER_HEAD_OUT.y+0.6,"The cloth flies over the heads in the hatches (%.2f m low edge)" % world_low)
 var colours:=bands_in(flag)
 check(colours.size()==3,"Two bands and the hem (%d colours)" % colours.size())
 var blue:=false;var yellow:=false
 for c in colours:
  blue=blue or (c.b>c.r+0.25 and c.b>c.g)
  yellow=yellow or (c.r>0.6 and c.g>0.55 and c.b<0.35)
 check(blue and yellow,"Blue over yellow")
 var top_blue:=true
 var arrays:=flag.mesh.surface_get_arrays(0)
 for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
  var v: Vector3=arrays[Mesh.ARRAY_VERTEX][i]
  var c: Color=(arrays[Mesh.ARRAY_COLOR][i] as Color).linear_to_srgb()
  if v.x>0.05 and v.y>0.01:top_blue=top_blue and c.b>c.r
 check(top_blue,"Blue on top")
 var size: Vector3=(flag.mesh as ArrayMesh).custom_aabb.size
 check(absf(size.x*0.5-VehicleMarkings.FLAG_SIZE.x)<0.01 and size.y>=VehicleMarkings.FLAG_SIZE.y*1.5,"Bounds hold the cloth swung round the staff and drooping")
 check(flag.get_parent().find_children("*","CollisionShape3D",false,false).is_empty() and flag.get_child_count()==0,"No collider on the cloth")
 check(flag.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"The cloth casts its shadow")
 # --- BMP, theirs -----------------------------------------------------------
 var red_flag: MeshInstance3D=theirs.art.turret.get_node_or_null("Flag")
 check(red_flag!=null and red_flag.get_meta("bands")==VehicleMarkings.RUSSIA,"Theirs: the tricolour on the whip")
 check(red_flag!=null and bands_in(red_flag).size()==4,"…three bands and the hem")
 check(theirs.art.root.get_node_or_null("Markings")!=null,"…the «Z» painted on the hull")
 check(theirs.art.turret.get_node_or_null("Markings")==null,"…no tricolour painted on the turret")
 # --- BM-21 -----------------------------------------------------------------
 var cloth: MeshInstance3D=grad.art.root.get_node_or_null("Flag")
 check(cloth!=null and cloth.get_meta("bands")==VehicleMarkings.UKRAINE,"Our BM-21 flies the flag of Ukraine")
 check(grad.art.root.get_node_or_null("FlagStaff")!=null and grad.art.root.get_node_or_null("Markings")==null,"…on its staff, nothing painted on the cab doors")
 check(cloth!=null and cloth.position.y-VehicleMarkings.FLAG_SIZE.y*1.2>2.72 and cloth.position.y+VehicleMarkings.FLAG_SIZE.y*0.5<VehicleMarkings.GRAD_STAFF_TOP,"…over the canvas roof, under the staff's top")
 check(cloth!=null and cloth.position.z>-0.68 and absf(cloth.position.x)<GradArt.MIRRORS[1].x-0.3,"…behind the cab, inboard of the mirrors")
 # --- Shared resources ------------------------------------------------------
 check(flag.mesh==ours.art.turret.get_node("Flag").mesh and flag.mesh==cloth.mesh,"One cloth mesh per flag kind")
 check(flag.mesh!=red_flag.mesh,"…the tricolour its own")
 check(flag.material_override==red_flag.material_override and flag.material_override==cloth.material_override,"One material for every flag")
 check(flag.material_override is ShaderMaterial and (flag.material_override as ShaderMaterial).shader.code.contains("instance uniform vec3 travel"),"The cloth waves in its shader")
 # --- Travel to the shader ----------------------------------------------------
 ours.art["flag_travel"]=Vector3.ZERO
 VehicleMarkings.flutter(ours,ours.art)
 check(ours.art["flag_travel"]==Vector3.ZERO,"Standing: nothing sent")
 ours.freeze=false
 ours.linear_velocity=Vector3(0,0,-8)
 VehicleMarkings.flutter(ours,ours.art)
 check((ours.art["flag_travel"] as Vector3).is_equal_approx(Vector3(0,0,-8)) and (flag.get_instance_shader_parameter("travel") as Vector3).is_equal_approx(Vector3(0,0,-8)),"Under way: the travel goes to the cloth")
 ours.linear_velocity=Vector3(0,0,-8.3)
 VehicleMarkings.flutter(ours,ours.art)
 check((ours.art["flag_travel"] as Vector3).is_equal_approx(Vector3(0,0,-8)),"…not again for a small change")
 print("vehicle flags: %d checks, %s" % [checks,"FAILED" if failed else "ok"])
 quit(1 if failed else 0)
