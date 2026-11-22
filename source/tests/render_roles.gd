extends SceneTree

# Screenshots of the roles and the quiet before the great assault: their
# BMP-2 parked by a strongpoint with its crew idling, the marks on theirs and
# ours (the flags on the turret whips), our squad and its gunner waiting by
# the vehicle, the flag on its staff behind the cab of a «Grad», a machine gunner behind the PKM's bipod, the RPG-7 and the
# RPG-22 on the shoulder, and the three vests side by side.
# KVARTAL_PREVIEW_DIR=<dir> godot --path source --script res://tests/render_roles.gd
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

func look(from: Vector3, at: Vector3, fov: float=55.0) -> void:
 eye.global_position=from
 eye.look_at(at,Vector3.UP)
 eye.fov=fov
 eye.current=true

# The first of the spots with nothing between it and the subject.
func clear_spot(spots: Array, at: Vector3) -> Vector3:
 var space: PhysicsDirectSpaceState3D=eye.get_world_3d().direct_space_state
 for spot in spots:
  var query:=PhysicsRayQueryParameters3D.create(spot,at,0x7FFF)
  var hit:=space.intersect_ray(query)
  if hit.is_empty() or hit.position.distance_to(at)<3.0:return spot
 return spots[0]

func near_report(label: String, radius: float=14.0) -> void:
 for actor in game.allies+game.bots:
  if not is_instance_valid(actor) or actor.global_position.distance_to(eye.global_position)>radius:continue
  var shown:=0
  for mesh in actor.model.get_node("CarriedRifle").find_children("*","MeshInstance3D",true,false):
   if mesh.is_inside_tree() and mesh.is_visible_in_tree():shown+=1
  print("%s %s kit=%s far=%s idle=%s rifle_meshes=%d crew=%s" % [label,"ours" if actor.friendly else "theirs",actor.kit_id(),str(actor.render_far),str(actor.idle.get("activity","-")),shown,str(actor.get_meta("bmp_role",""))])
 if is_instance_valid(game.player):print("%s player at %.1f m" % [label,game.player.global_position.distance_to(eye.global_position)])

func ground(p: Vector3) -> Vector3:
 return Vector3(p.x,game.district.ground_height(p),p.z)

func soldier(friendly: bool, at: Vector3, kit: String, vest: String="") -> Hostile:
 var actor: Hostile=game.battle.spawn_soldier(friendly,ground(at),0)
 Idle.stop(actor)
 actor.set_kit(kit)
 if vest!="":actor.wear_vest(vest)
 actor.set_physics_process(false)
 return actor

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class("rifleman")
 game.battle_size=18
 game.selected_map=BattleMap.ID
 game.start_match()
 eye=Camera3D.new();eye.far=900;game.world_root.add_child(eye)
 for layer in game.find_children("*","CanvasLayer",true,false):layer.visible=false
 if game.hud!=null:game.hud.visible=false
 var battle: BattleMode=game.battle
 await frames(240)
 # Their BMP and its crew.
 var unit: Dictionary=battle.armour.units[0]
 var v: BmpVehicle=unit.vehicle
 game.district.operation_area.stream(v.global_position,60)
 await frames(30)
 look(v.to_global(Vector3(-7.5,2.4,-7.0)),v.to_global(Vector3(0,1.0,0)))
 await snap("enemy-bmp-front",40)
 var centre: Vector3=v.to_global(Vector3(0,1.2,0))
 look(clear_spot([v.to_global(Vector3(8.0,2.0,1.5)),v.to_global(Vector3(-8.0,2.0,1.5)),v.to_global(Vector3(8.0,4.5,4.0)),v.to_global(Vector3(-8.0,4.5,4.0))],centre),centre)
 await snap("enemy-bmp-side",10)
 # Defenders at their quiet post.
 var defender: Hostile=null
 for actor in game.bots:
  if Idle.active(actor) and not actor.get_meta("armour_crew",false):defender=actor;break
 if defender!=null:
  look(defender.global_position+Vector3(7,3,7),defender.global_position+Vector3.UP)
  await snap("enemy-idle",10)
 # Ours by the vehicle.
 var lead: MechSquad=battle.mech[0]
 var ours: BmpVehicle=lead.vehicle
 game.district.operation_area.stream(ours.global_position,60)
 await frames(30)
 look(ours.to_global(Vector3(11,3.2,9)),ours.to_global(Vector3(0,0.8,4)))
 await snap("our-squad-idle",20)
 near_report("squad")
 look(ours.to_global(Vector3(6.5,3.4,5.0)),ours.to_global(Vector3(0.75,3.4,0.4)),45)
 await snap("our-bmp-flag",10)
 if battle.battery!=null and not battle.battery.launchers.is_empty():
  var grad: GradVehicle=battle.battery.launchers[0]
  game.district.operation_area.stream(grad.global_position,60)
  await frames(30)
  look(grad.to_global(Vector3(6.0,3.6,2.0)),grad.to_global(Vector3(0.9,3.0,-0.6)),45)
  await snap("grad-flag",20)
 # The roles, on open ground by the column.
 var base: Vector3=ours.to_global(Vector3(-25,0,10))
 var forward: Vector3=-ours.global_basis.z
 var side: Vector3=ours.global_basis.x
 var mg:=soldier(true,base,"mg")
 mg.look_at(mg.global_position+forward,Vector3.UP)
 mg.alerted=true;mg.tactical_prone=1.0;mg.stance=0.0;mg.contact_age=0.0
 mg.set_bipod(true)
 mg.animate_pose(0.016,false)
 var rpg7:=soldier(true,base+side*4.0,"rpg7")
 rpg7.look_at(rpg7.global_position+forward,Vector3.UP)
 rpg7.stance=0.8
 rpg7.animate_pose(0.016,false)
 rpg7.kit.begin("rpg7",null,rpg7.global_position+forward*150.0+Vector3.UP*1.5)
 rpg7.kit.phase="aim";rpg7.kit.clock=0.0
 rpg7.kit.pose_launcher()
 var rpg22:=soldier(true,base+side*8.0,"rpg22")
 rpg22.look_at(rpg22.global_position+forward,Vector3.UP)
 rpg22.animate_pose(0.016,false)
 rpg22.kit.begin("rpg22",null,rpg22.global_position+forward*100.0+Vector3.UP*1.4)
 rpg22.kit.phase="aim";rpg22.kit.clock=0.0
 rpg22.kit.pose_launcher()
 game.district.operation_area.stream(base,60)
 await frames(20)
 look(base+side*4.0+forward*6.5+Vector3.UP*1.8-side*3.0,base+side*4.0+Vector3.UP*0.9)
 await snap("roles-front",20)
 look(base+side*10.5+forward*0.5+Vector3.UP*1.7,base+side*4.0+Vector3.UP*1.1)
 await snap("roles-side",10)
 look(mg.global_position+forward*2.2+side*1.4+Vector3.UP*0.9,mg.global_position+forward*0.8+Vector3.UP*0.25,50)
 await snap("mg-bipod",10)
 # The vests.
 var row: Vector3=base-forward*12.0
 var kinds:=["korsar","ratnik","carrier"]
 for i in range(3):
  var man:=soldier(i!=1,row+side*(i*1.4),"rifle",kinds[i])
  man.look_at(man.global_position-forward,Vector3.UP)
  man.animate_pose(0.016,false)
 look(row+side*1.4-forward*4.2+Vector3.UP*1.4,row+side*1.4+Vector3.UP*1.1,50)
 await snap("vests",20)
 quit()
