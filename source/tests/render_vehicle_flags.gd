extends SceneTree

# The flags on the vehicles: ours and theirs on the turret whips of their
# BMPs, the flag on its staff behind the cab of a BM-21; standing in the
# wind and, for ours, under way (the travel set on the cloth), and the turret
# turned to the side.
# KVARTAL_PREVIEW_DIR=<dir> godot --fixed-fps 60 --path source --resolution 1600x900 --script res://tests/render_vehicle_flags.gd
var game: Node3D
var out := ""
var eye: Camera3D
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=20):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("SNAP ",name)
func look(from: Vector3, at: Vector3, fov: float=50.0) -> void:
 eye.global_position=from;eye.look_at(at,Vector3.UP);eye.fov=fov;eye.current=true

func vehicle(kind: String, friendly: bool, at: Vector3) -> Node3D:
 var v: Node3D=BmpVehicle.new() if kind=="bmp" else GradVehicle.new()
 v.friendly=friendly
 game.world_root.add_child(v)
 v.setup(game)
 v.global_position=Vector3(at.x,game.district.ground_height(at),at.z)
 return v

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.selected_map=TrainingRange.ID
 game.start_match()
 eye=Camera3D.new();eye.far=900;game.world_root.add_child(eye)
 for layer in game.find_children("*","CanvasLayer",true,false):layer.visible=false
 var base:=Vector3(40,0,60)
 var ours:=vehicle("bmp",true,base)
 var theirs:=vehicle("bmp",false,base+Vector3(14,0,0))
 var grad:=vehicle("grad",true,base+Vector3(-14,0,0))
 await frames(60)
 for v in [ours,theirs]:v.freeze=true
 look(ours.to_global(Vector3(-6.0,3.4,5.0)),ours.to_global(Vector3(0.6,2.9,0.4)),45)
 await snap("flag-ours-standing",30)
 look(theirs.to_global(Vector3(6.0,3.4,-5.5)),theirs.to_global(Vector3(0.5,2.6,0.2)),45)
 await snap("flag-theirs",10)
 look(grad.to_global(Vector3(6.0,3.6,2.0)),grad.to_global(Vector3(0.9,3.0,-0.6)),45)
 await snap("flag-grad",10)
 look(grad.to_global(Vector3(-1.5,2.6,-7.0)),grad.to_global(Vector3(0.3,2.6,-0.5)),55)
 await snap("flag-grad-front",10)
 # Ours under way at 30 km/h, the turret to the right.
 var cloth: MeshInstance3D=ours.art.flag
 cloth.set_instance_shader_parameter("travel",-ours.global_basis.z*8.3)
 ours.art.turret.rotation.y=-PI/2
 look(ours.to_global(Vector3(-6.5,3.4,4.0)),ours.to_global(Vector3(0.3,2.8,0.3)),45)
 await snap("flag-ours-moving",30)
 # From the troop hatch, looking back over the roof.
 ours.art.turret.rotation.y=0
 look(ours.to_global(BmpArt.TROOP_HATCH+Vector3(0,0.85,0.3)),ours.to_global(Vector3(0.6,3.2,-0.4)),70)
 await snap("flag-from-hatch",20)
 quit()
