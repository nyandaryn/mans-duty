class_name PackArt
extends RefCounted

static func build() -> Node3D:
 var root := Node3D.new()
 root.name="AssaultPack"
 var cloth := "gear_#62684e"
 # A soft 30 L body, not a rigid rectangular crate. Front points towards +Z.
 CharacterArt.shell(root,[Vector4(-0.225,0.22,0.13,0),Vector4(-0.19,0.29,0.18,0),Vector4(-0.08,0.30,0.185,0),Vector4(0.08,0.28,0.175,0),Vector4(0.175,0.25,0.15,0)],cloth,0.014,32,0.48,true)
 Models.bevel(root,Vector3(0,0.14,0),Vector3(0.23,0.003,0.13),"#222b20",0.002)
 var pocket := Models.group(root,"FrontPocket",Vector3(0,-0.06,0.105))
 CharacterArt.shell(pocket,[Vector4(-0.125,0.22,0.045,0),Vector4(-0.09,0.25,0.065,0),Vector4(0.085,0.24,0.055,0),Vector4(0.125,0.19,0.02,0)],"gear_#596047",0.015,24,0.5)
 for y in [-0.13,-0.08,-0.03,0.02]:
  for x in [-0.073,0,0.073]:
   Models.bevel(root,Vector3(x,y,0.142),Vector3(0.065,0.018,0.005),"gear_#75795c",0.002)
   for dx in [-0.029,0.029]:Models.limb(root,Vector3(x+dx,y-0.008,0.146),Vector3(x+dx,y+0.008,0.146),0.0007,"#b0a78a")
 var lid := Models.group(root,"Lid",Vector3(0,0.16,-0.06))
 Models.bevel(lid,Vector3(0,0.018,0.07),Vector3(0.24,0.035,0.16),cloth,0.016)
 # Zipper tracks, metal pulls, compression straps and side pockets.
 for side in [-1,1]:
  Models.limb(root,Vector3(side*0.132,-0.18,0.085),Vector3(side*0.115,0.16,0.075),0.0025,"#30362d")
  Models.bevel(root,Vector3(side*0.113,0.15,0.086),Vector3(0.009,0.026,0.004),"#6c7067",0.002)
  for y in [-0.13,0.065]:
   Models.bevel(root,Vector3(side*0.146,y,0),Vector3(0.009,0.022,0.16),"gear_#3d4939",0.002)
   Models.bevel(root,Vector3(side*0.15,y,0.04),Vector3(0.014,0.031,0.027),"#292e28",0.004)
  var side_pocket := Models.group(root,"SidePocket",Vector3(side*0.15,-0.11,0.008))
  CharacterArt.shell(side_pocket,[Vector4(-0.085,0.035,0.105,0),Vector4(-0.05,0.06,0.13,0),Vector4(0.065,0.055,0.12,0)],"gear_#535c44",0.018,16,0.55)
  var strap := Models.group(root,"ShoulderStrap",Vector3(side*0.085,0.15,-0.09))
  Models.limb(strap,Vector3.ZERO,Vector3(side*0.018,-0.09,-0.085),0.025,cloth,0.021)
  Models.limb(strap,Vector3(side*0.018,-0.09,-0.085),Vector3(side*0.025,-0.30,-0.07),0.020,cloth,0.013)
  Models.limb(strap,Vector3(side*0.025,-0.30,-0.07),Vector3(side*0.035,-0.35,0),0.009,"gear_#3d4939")
  Models.bevel(root,Vector3(side*0.060,-0.005,-0.097),Vector3(0.080,0.28,0.028),"#353d32",0.012)
 Models.limb(root,Vector3(-0.045,0.20,-0.02),Vector3(-0.033,0.26,-0.02),0.009,"gear_#3d4939")
 Models.limb(root,Vector3(-0.033,0.26,-0.02),Vector3(0.033,0.26,-0.02),0.009,"gear_#3d4939")
 Models.limb(root,Vector3(0.033,0.26,-0.02),Vector3(0.045,0.20,-0.02),0.009,"gear_#3d4939")
 for child in root.get_children():
  if child is Node3D and not child is MeshInstance3D:Models.merge_rigid(child)
 Models.merge_rigid(root)
 return root

const ON_BACK := Vector3(0,1.2,0.265)

static func equip(model: Node3D, equipped: bool, lite: bool=false) -> void:
 var previous := model.get_node_or_null("Backpack")
 if previous!=null:previous.free()
 if not equipped:return
 var pack := build_lite() if lite else build()
 pack.name="Backpack"
 pack.position=ON_BACK
 model.add_child(pack)

# A soldier of the battle carries the same pack with its colours merged into
# vertex colours (CharacterArt.consolidate): three draw calls, not seventeen.
# Built once; every copy shares the meshes.
static var lite_pack: PackedScene
static func build_lite() -> Node3D:
 if lite_pack==null:
  var root := build()
  for mesh in root.find_children("*","MeshInstance3D",true,false):
   if mesh.get_parent()==root:continue
   var pose: Transform3D=mesh.transform
   var parent: Node=mesh.get_parent()
   while parent!=root:
    pose=parent.transform*pose
    parent=parent.get_parent()
   mesh.get_parent().remove_child(mesh)
   root.add_child(mesh)
   mesh.transform=pose
  for child in root.get_children():
   if not child is MeshInstance3D:child.free()
  CharacterArt.consolidate(root)
  CharacterArt.assign_owner(root,root)
  lite_pack=PackedScene.new()
  lite_pack.pack(root)
  root.free()
 return lite_pack.instantiate()

static func item_model(kind: String) -> Node3D:
 if kind=="rpo_a":return ShmelArt.build()
 if kind=="recon_drone":return DroneArt.build(true)
 if kind=="mortar_mine":return MineBox.mine_model()
 if kind in ["rpg7","rpg22"]:return BotKit.launcher_model(kind,kind=="rpg22")
 if kind=="pg7vl":return grenade_model()
 if kind=="og7v":return LauncherRig.og7v_model(true)
 if kind=="tbg7v":return LauncherRig.tbg7v_model(true)
 if kind in Equipment.FPV:return fpv_model(kind)
 var root := Node3D.new()
 root.name="EquipmentItem"
 if kind=="ammo_pkm":
  # The steel box of a 100-round belt: lid with its catch, carrying handle.
  Models.bevel(root,Vector3.ZERO,Vector3(0.11,0.155,0.19),"#4a5139",0.006)
  Models.bevel(root,Vector3(0,0.080,0),Vector3(0.114,0.008,0.194),"#3f4631",0.003)
  Models.bevel(root,Vector3(0,0.092,0.02),Vector3(0.02,0.012,0.09),"#2b2f24",0.003)
  Models.bevel(root,Vector3(0.057,0.05,-0.07),Vector3(0.006,0.03,0.025),"#6d6f62",0.002)
  Models.merge_rigid(root)
  return root
 if kind=="rangefinder":
  Models.bevel(root,Vector3.ZERO,Vector3(0.105,0.075,0.13),"#454f43",0.015)
  for x in [-0.027,0.027]:
   Models.tube(root,Vector3(x,0.005,-0.073),0.023,0.025,"#242d28",Vector3.FORWARD)
   Models.tube(root,Vector3(x,0.005,-0.087),0.018,0.002,"#234d54",Vector3.FORWARD)
   Models.tube(root,Vector3(x,0.005,0.074),0.020,0.025,"#202723",Vector3.FORWARD)
  Models.bevel(root,Vector3(0.018,0.04,-0.01),Vector3(0.022,0.007,0.028),"#a4aa8e",0.004)
  for x in [-0.048,0.048]:
   for z in [-0.035,-0.015,0.005,0.025]:Models.bevel(root,Vector3(x,0,z),Vector3(0.008,0.045,0.004),"#303b31",0.002)
 elif kind=="medkit":
  CharacterArt.pouch(root,Vector3.ZERO,Vector3(0.14,0.12,0.065))
  Models.bevel(root,Vector3(0,0,-0.039),Vector3(0.052,0.014,0.003),"#c5bda1",0.001)
  Models.bevel(root,Vector3(0,0,-0.040),Vector3(0.014,0.052,0.003),"#c5bda1",0.001)
 else:
  root.free()
  return AmmoPacketArt.build(kind)
 Models.merge_rigid(root)
 return root

# PG-7VL: the art of the launcher's agent when it is there, else a plain
# warhead on its motor.
static func grenade_model() -> Node3D:
 var path:="res://scripts/rpg7_art.gd"
 if ResourceLoader.exists(path):
  var art: Script=load(path)
  if art.has_method("grenade"):
   var built=art.grenade()
   if built is Node3D:return built
 var root:=Node3D.new();root.name="Grenade"
 Models.tube(root,Vector3(0,0,-0.18),0.0465,0.30,"#4b4f3a",Vector3.FORWARD)
 Models.tube(root,Vector3(0,0,0.14),0.020,0.40,"#3a3d31",Vector3.FORWARD)
 return root

static func fpv_model(kind: String) -> Node3D:
 return DroneArt.build_fpv("heat" if kind=="fpv_heat" else "frag")

# Where each launcher rides on the pack's outer mount, muzzle up: position
# and rotation.
const MOUNTS := {
 "rpo_a":[Vector3(0.26,1.21,0.31),Vector3(PI/2,0,-0.12)],
 "rpg7":[Vector3(-0.20,1.12,0.33),Vector3(PI/2,0,0.16)],
 "rpg22":[Vector3(0.05,1.02,0.36),Vector3(PI/2,0,-0.04)],
}

static func mount(kind: String) -> Transform3D:
 var at: Array=MOUNTS.get(kind,MOUNTS.rpo_a)
 return Transform3D(Basis.from_euler(at[1]),at[0])

static func attach_launcher(model: Node3D, kind: String="rpo_a") -> Node3D:
 var launcher: Node3D
 match kind:
  "rpg7":launcher=BotKit.launcher_model("rpg7",false)
  "rpg22":launcher=BotKit.launcher_model("rpg22",false)
  _:launcher=ShmelArt.build()
 launcher.name="Carried_"+kind
 launcher.transform=mount(kind)
 model.add_child(launcher)
 return launcher
