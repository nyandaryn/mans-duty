class_name FieldRig
extends Node3D

const ACCESS_TIME := 3.4
var operator: Operator
var mode := ""
var timer := 0.0
var item_uid := -1
var kind := ""
# The medkit being taken out goes to an empty belt pouch, not to treatment.
var to_belt := false
const BELT_TIME := 0.7
# The rangefinder rides in a chest pouch on the plate carrier: flap open,
# out and up to the eyes in under a second, back in as quickly.
const POUCH_TIME := 0.8
const POUCH_STOW := 0.6
var reading := "— — — м"
var sample_left := 0.0
# Optical zoom 6–12× on the wheel, as in the Maven RFZ.1 6–12×21 (≈300 g, a
# hand rangefinder of this size). Fixed-power ones are 6× or 7×. The power
# set stays for the next time the rangefinder comes out.
const ZOOM_MIN := 6
const ZOOM_MAX := 12
var zoom := ZOOM_MIN
var sampled_direction := Vector3.FORWARD
var pack: Node3D
var item_prop: Node3D
var source_mag: Node3D
var target_mag: Node3D
var cartridge: Node3D
# The PKM's belt between its box and the can, a run of linked rounds.
var belt_train: Node3D
const BELT_ROUNDS := 28
const BELT_PITCH := 0.0145
var left: Node3D
var right: Node3D
var forearms: Array[Node3D]=[]
var visual_key := ""
var drone: ReconDrone
var drone_notice := ""
# FPV kamikaze drones (fpv_heat, fpv_frag; fpv_drone with a "warhead" key):
# out of the pack, set on the ground in front, goggles on. While one is up
# the recon drone, if out, waits here and comes back to the rig after.
const FPV_DRONE := preload("res://scripts/fpv_drone.gd")
const FPV_PLACE_TIME := 1.0
const FPV_FOOTPRINT := Vector3(0.46,0.17,0.62)
const FPV_LIFTS := [0.12,0.15,0.20]
var fpv_warhead := "heat"
var parked_drone: ReconDrone
# Hands-on work in place: mortar deployment, taking a mine out of the box.
var work_title := ""
var work_time := 0.0
var work_done := Callable()
var work_origin := Vector3.ZERO
var work_notice := ""
# World point the hands work at (the mortar part being fitted); INF — none.
var work_target := Vector3.INF
var work_notice_left := 0.0
# On a vehicle's bench the hands work in the lap, under a pivot of the seat
# (BmpCommand), drawn with the compartment; the pack comes up from the floor
# between the feet instead of off the back.
var seated := false
var draw_layer := ScopeSight.FIRST_PERSON_LAYER

func setup(owner_operator: Operator) -> void:
 operator=owner_operator
 pack=PackArt.build();add_child(pack)
 left=Models.hand(self,"FieldLeft",Vector3.ZERO)
 right=Models.hand(self,"FieldRight",Vector3.ZERO)
 for side in range(2):
  var sleeve := CharacterArt.shell(self,[Vector4(-0.13,0.095,0.085,0),Vector4(-0.06,0.092,0.083,0),Vector4(0.02,0.080,0.072,0),Vector4(0.13,0.064,0.060,0)],"cloth",0.025)
  forearms.append(sleeve)
 ScopeSight.set_first_person(self)
 Wardrobe.dress(self,operator.outfit_id,true)
 visible=false

func transfer() -> MagazineTransfer:return operator.game.inventory.transfer

func seat_in(holder: Node3D, layer: int) -> void:
 if get_parent()!=holder:
  get_parent().remove_child(self)
  holder.add_child(self)
 transform=Transform3D.IDENTITY
 seated=true
 if draw_layer!=layer:draw_layer=layer;paint(self)

func stand_up() -> void:
 if not seated:return
 seated=false
 get_parent().remove_child(self)
 operator.camera.add_child(self)
 transform=Transform3D.IDENTITY
 draw_layer=ScopeSight.FIRST_PERSON_LAYER
 paint(self)

func paint(node: Node) -> void:
 if node is VisualInstance3D:node.layers=draw_layer
 for child in node.get_children():
  if child is ReconDrone:continue
  paint(child)
func active() -> bool:return mode!="" or transfer().active or (operator.launcher!=null and operator.launcher.active())
func busy() -> bool:
 return (mode!="" and mode not in ["rangefinder","pouch","pouch_stow"]) or transfer().active or (operator.launcher!=null and operator.launcher.active() and operator.launcher.mode!="ready")

func request(uid: int) -> bool:
 if operator.concussion.blackout_left>0 or operator.concussion.incapacitated():return false
 if operator.is_vaulting():return false
 var entry := operator.backpack.item(uid)
 if entry.is_empty() or active() or operator.bandage_time>0 or operator.current().phase!="" or (operator.current().pending_slot>=0 and entry.kind!="medkit") or (operator.arm_injury>=0.5 and entry.kind!="medkit") or operator.injury_time>0:return false
 if entry.kind not in ["rangefinder","medkit","recon_drone"] and not FPV_DRONE.is_fpv_kind(entry.kind):return false
 if FPV_DRONE.is_fpv_kind(entry.kind) and is_instance_valid(drone) and drone is FPV_DRONE:return false
 if FPV_DRONE.is_fpv_kind(entry.kind):fpv_warhead=FPV_DRONE.warhead_of(entry)
 if entry.kind=="recon_drone" and (is_instance_valid(drone) or float(entry.get("battery",1.0))<=0 or float(entry.get("condition",1.0))<=0):return false
 if entry.kind=="medkit" and not operator.needs_bandage():return false
 item_uid=uid;kind=entry.kind;mode="access";timer=0;reading="— — — м";sample_left=0;to_belt=false
 operator.burst=0;operator.aim=false
 operator.game.inventory.hide_for_action()
 return true

# Reach into the backpack as for any item, then clip the kit to the belt.
func attach_medkit(uid: int) -> bool:
 if operator.concussion.blackout_left>0 or operator.concussion.incapacitated() or operator.is_vaulting():return false
 var entry := operator.backpack.item(uid)
 if entry.is_empty() or entry.kind!="medkit" or operator.bandages>=Operator.BELT_MEDKITS:return false
 if active() or operator.bandage_time>0 or operator.current().phase!="" or operator.current().pending_slot>=0 or operator.arm_injury>=0.5 or operator.injury_time>0:return false
 item_uid=uid;kind="medkit";mode="access";timer=0;to_belt=true
 operator.burst=0;operator.aim=false
 operator.game.inventory.hide_for_action()
 return true

func work(title: String, duration: float, done: Callable) -> bool:
 if active() or operator.is_vaulting() or operator.bandage_time>0 or operator.current().phase!="" or operator.current().pending_slot>=0:return false
 if operator.arm_injury>=0.5 or operator.injury_time>0 or operator.concussion.blackout_left>0 or operator.concussion.incapacitated():return false
 mode="work";kind="work";timer=0;work_title=title;work_time=duration;work_done=done;work_origin=operator.global_position;work_notice=""
 operator.burst=0;operator.aim=false
 operator.game.inventory.hide_for_action()
 return true

func toggle_rangefinder() -> void:
 if mode=="rangefinder":mode="pouch_stow";timer=0;return
 if mode!="":cancel();return
 if active() or operator.is_vaulting() or operator.concussion.blackout_left>0 or operator.concussion.incapacitated():return
 if operator.bandage_time>0 or operator.current().phase!="" or operator.current().pending_slot>=0 or operator.arm_injury>=0.5 or operator.injury_time>0:return
 kind="rangefinder";mode="pouch";timer=0;reading="— — — м";sample_left=0;item_uid=-1
 operator.burst=0;operator.aim=false
 operator.game.inventory.hide_for_action()

func cancel() -> void:
 if operator.launcher!=null:operator.launcher.cancel()
 # An FPV still on the ground goes back into the pack, hands first.
 var stow := FPV_DRONE.is_fpv_kind(kind) and mode=="fpv_place"
 if is_instance_valid(drone) and drone is FPV_DRONE:stow=release_fpv() or stow
 elif is_instance_valid(drone) and drone.piloting:drone.end_control()
 mode="";timer=0;sample_left=0;visible=false;to_belt=false;work_done=Callable();work_target=Vector3.INF
 transfer().cancel()
 if stow and operator.game.running and operator.arm_injury<0.5 and operator.injury_time<=0:mode="stow";timer=0

# The universal cancel (Operator.cancel_action): whatever the hands are
# doing with the pack, the pouch or the drone stops, and nothing is lost. An
# item reached for stays in the pack (it leaves it only once out); an FPV set
# on the ground goes back in; the goggles come off a drone that has not yet
# been flown, which stays where it stands; a drone being folded stays
# unfolded; the rangefinder coming out goes back into its pouch; a magazine or belt
# keeps the rounds already moved; hands-on work (the mortar, the Grad's
# mounts) stops undone. (Looking through it, K puts the rangefinder away.)
func interrupt() -> bool:
 match mode:
  "":
   if not transfer().active:return false
   transfer().cancel()
  "access","goggles","recover_drone","fpv_place":cancel()
  "stow","belt","pouch_stow":mode="";timer=0;visible=false
  "pouch":mode="pouch_stow";timer=POUCH_STOW*(1.0-clampf(timer/POUCH_TIME,0,1))
  "work":interrupt_work("СКАСОВАНО")
  _:return false
 return true

# Hands-on work stops as soon as the soldier moves or calls it off.
func interrupt_work(reason: String) -> void:
 if mode!="work":return
 work_notice=work_title+" "+reason;work_notice_left=4
 cancel()

func step_zoom(by: int) -> void:
 if mode!="rangefinder":return
 zoom=clampi(zoom+by,ZOOM_MIN,ZOOM_MAX)

# Camera field of view through the eyepiece: the naked eye's 78° over the power.
func view_fov() -> float:return rad_to_deg(2*atan(tan(deg_to_rad(78.0)*0.5)/zoom))

func measure() -> void:
 if mode!="rangefinder" or sample_left>0:return
 sample_left=0.35
 sampled_direction=-operator.camera.global_basis.z
 reading="ВИМІРЮВАННЯ…"

func tick(delta: float) -> void:
 if work_notice_left>0:
  work_notice_left-=delta
  if work_notice_left<=0:work_notice=""
 if mode!="":
  if (operator.arm_injury>=0.5 and kind!="medkit") or operator.injury_time>0 or not operator.game.running:cancel();return
  timer+=delta
  if mode=="access" and timer>=ACCESS_TIME:
   if operator.backpack.item(item_uid).is_empty():cancel();return
   if kind=="medkit" and to_belt:
    operator.backpack.remove(item_uid)
    operator.bandages=mini(Operator.BELT_MEDKITS,operator.bandages+1)
    mode="belt";timer=0;to_belt=false
   elif kind=="medkit":
    mode="";operator.start_medical(item_uid)
   elif kind=="recon_drone":
    if deploy_drone():mode="goggles";timer=0
    else:cancel()
   elif FPV_DRONE.is_fpv_kind(kind):mode="fpv_place";timer=0
   else:mode="rangefinder";timer=0
  elif mode=="fpv_place" and timer>=FPV_PLACE_TIME:
   if deploy_fpv():mode="goggles";timer=0
   else:cancel()
  elif mode=="pouch" and timer>=POUCH_TIME:mode="rangefinder";timer=0
  elif mode=="pouch_stow" and timer>=POUCH_STOW:mode=""
  elif mode=="stow" and timer>=2.2:mode=""
  elif mode=="belt" and timer>=BELT_TIME:mode=""
  elif mode=="work":
   if Vector2(operator.global_position.x-work_origin.x,operator.global_position.z-work_origin.z).length()>0.8:
    interrupt_work("ПЕРЕРВАНО: БОЄЦЬ ЗРУШИВ З МІСЦЯ");return
   if timer>=work_time:
    var done := work_done
    mode="";work_done=Callable();work_target=Vector3.INF
    if done.is_valid():done.call()
  elif mode=="goggles" and timer>=1.2:
   if is_instance_valid(drone) and drone.begin_control():mode="drone";timer=0
   else:cancel()
  elif mode=="recover_drone" and timer>=2.2:
   finish_drone_recovery();cancel()
 if sample_left>0:
  sample_left=maxf(0,sample_left-delta)
  if sample_left==0:
   if sampled_direction.dot(-operator.camera.global_basis.z)<cos(0.008):reading="НЕСТІЙКИЙ ВИМІР"
   else:reading=measure_scene()
 animate()

# The laser spot is not a line: the beam diverges about 2.4 mrad (0.6 m
# across at 250 m). Like a real device in first-target mode the reading is
# the nearest reflection inside the spot, so a soldier is ranged, not the
# slope behind him through the gap between his arm and body.
const BEAM_RADIUS := 0.0012
func beam_offsets() -> Array[Vector2]:
 var offsets: Array[Vector2]=[Vector2.ZERO]
 for i in range(4):offsets.append(Vector2.from_angle(TAU*i/4.0+PI/4)*BEAM_RADIUS*0.5)
 for i in range(8):offsets.append(Vector2.from_angle(TAU*i/8.0)*BEAM_RADIUS)
 return offsets

func measure_scene() -> String:
 var start := operator.camera.global_position
 var ignored: Array[RID]=[operator.get_rid()]
 for area in operator.find_children("Hit_*","Area3D",true,false):ignored.append(area.get_rid())
 var view := operator.camera.global_basis
 var space := operator.get_world_3d().direct_space_state
 var hit: Dictionary={}
 var nearest := INF
 for offset in beam_offsets():
  var direction := (-view.z+view.x*offset.x+view.y*offset.y).normalized()
  var ray := PhysicsRayQueryParameters3D.create(start,start+direction*1200,1|16,ignored)
  ray.collide_with_areas=true
  var echo := space.intersect_ray(ray)
  if echo.is_empty():continue
  var range_to := start.distance_to(echo.position)
  if range_to<nearest:
   nearest=range_to
   hit=echo
 if hit.is_empty():return "НЕМАЄ ВІДБИТТЯ"
 if operator.game.district.foliage_visibility(start,hit.position)<=0:return "РОСЛИННІСТЬ ПЕРЕКРИВАЄ ПРОМІНЬ"
 var distance := start.distance_to(hit.position)
 if distance<5:return "БЛИЖЧЕ 5 м"
 # 1 m display resolution; first physical surface, no actor lookup. The grid
 # bearing is given in thousandths, as the mortar sight is laid.
 return "%d м · АЗ %s" % [roundi(distance),MortarBallistics.mils_text(MortarBallistics.azimuth(-operator.camera.global_basis.z))]

func rebuild(key: String, weapon_id: String) -> void:
 if visual_key==key:return
 visual_key=key
 for node in [item_prop,source_mag,target_mag,cartridge,belt_train]:
  if is_instance_valid(node):node.free()
 item_prop=null;source_mag=null;target_mag=null;cartridge=null;belt_train=null
 if key.begins_with("transfer"):
  target_mag=make_magazine(weapon_id);add_child(target_mag)
  if transfer().box_bag!=null:
   item_prop=PackArt.item_model(transfer().source.kind);add_child(item_prop)
  else:source_mag=make_magazine(weapon_id);add_child(source_mag)
  if weapon_id=="pkm":belt_train=make_belt()
  else:
   cartridge=Models.group(self,"LooseCartridge")
   var debris := CartridgeDebris.new()
   var round_mesh := MeshInstance3D.new()
   round_mesh.mesh=debris.cartridge_mesh(weapon_id in ["pm","m9"],true,weapon_id=="svd")
   cartridge.add_child(round_mesh)
   debris.free()
 elif FPV_DRONE.is_fpv_kind(kind):item_prop=DroneArt.build_fpv(fpv_warhead);add_child(item_prop)
 else:item_prop=PackArt.item_model(kind);add_child(item_prop)
 paint(self)

# Rounds of 7.62 × 54R in their steel links, placed along the belt's way
# every frame (animate_belt).
func make_belt() -> Node3D:
 var strip := Models.group(self,"LooseBelt")
 var debris := CartridgeDebris.new()
 var round_mesh: Mesh=debris.cartridge_mesh(false,true,true)
 debris.free()
 var link := BoxMesh.new()
 link.size=Vector3(0.0136,0.004,0.0135)
 var steel := StandardMaterial3D.new()
 steel.albedo_color=Color("3b3f38");steel.metallic=0.6;steel.roughness=0.55
 link.material=steel
 for k in range(BELT_ROUNDS):
  var holder := Node3D.new()
  strip.add_child(holder)
  var mesh := MeshInstance3D.new()
  mesh.mesh=round_mesh
  holder.add_child(mesh)
  # Two link loops round the case, the joint between them.
  for z in [0.012,-0.008]:
   var band := MeshInstance3D.new()
   band.mesh=link;band.position=Vector3(0,0,z)
   holder.add_child(band)
 return strip

func make_magazine(id: String) -> Node3D:
 var baked: Node3D=load("res://assets/models/"+("ak74m" if id=="ak74" else id)+".scn").instantiate()
 var mag: Node3D=baked.get_node("Magazine");baked.remove_child(mag);baked.free()
 mag.position=Vector3.ZERO;mag.rotation=Vector3.ZERO
 MagazineView.decorate(mag,id)
 return mag

# The PKM's box in the left hand, mouth toward the open can held up out of
# the pack: the rest of the old belt runs out of the box into the can, then
# the new belt of 100 runs from the can into the box, the right hand drawing
# it over in loops; its end left in the mouth.
func animate_belt(tx: MagazineTransfer) -> void:
 var p:=1.0 if tx.moved>0 else clampf(tx.clock/MagazineTransfer.BELT_TIME,0,1)
 target_mag.visible=true
 target_mag.rotation=Vector3(0.12,PI-0.35,0.08)
 const BOX_CENTER := Vector3(0.037,-0.141,-0.1085)
 target_mag.position=Vector3(0.0,-0.33,-0.46)-target_mag.basis*BOX_CENTER
 var box_belt:=target_mag.get_node_or_null("Belt")
 if box_belt!=null:box_belt.visible=p>=0.97 and int(tx.destination.rounds)>0
 pack.visible=true;pack.position=Vector3(-0.18,-0.46,-0.64);pack.rotation=Vector3(-0.25,0.2,0)
 pack.get_node("Lid").rotation.x=-1.8
 item_prop.visible=true
 item_prop.position=Vector3(-0.21,-0.36,-0.58);item_prop.rotation=Vector3(0.30,0.25,0)
 var box_mouth: Vector3=target_mag.transform*Vector3(0.047,-0.058,-0.1085)
 var can_mouth: Vector3=item_prop.transform*Vector3(0,0.085,0)
 # Out of the box (the rest of the old belt), then in (the new one).
 var old:=int(tx.destination.rounds) if tx.moved==0 else 0
 var fresh:=int(tx.source.rounds) if tx.moved==0 else int(tx.destination.rounds)
 var run:=0.0
 var count:=0
 var from:=box_mouth;var to:=can_mouth
 if p<0.46 and old>0:
  run=smoothstep(0.04,0.44,p);count=old
 elif p>=0.50:
  run=smoothstep(0.52,0.95,p);count=fresh;from=can_mouth;to=box_mouth
 var apex:=(from+to)*0.5+Vector3(0.02,0.11,0.03)
 var arc:=from.distance_to(apex)+apex.distance_to(to)
 var head:=run*(arc+count*BELT_PITCH)
 var first:=maxi(0,ceili((head-arc)/BELT_PITCH))
 for k in range(BELT_ROUNDS):
  var holder: Node3D=belt_train.get_child(k)
  var index:=first+k
  var s:=head-index*BELT_PITCH
  holder.visible=count>0 and index<count and s>=0.0 and s<=arc and run>0.0 and run<1.0
  if not holder.visible:continue
  var u:=s/arc
  var at:=from.lerp(apex,u).lerp(apex.lerp(to,u),u)
  var along:=(apex-from).lerp(to-apex,u).normalized()
  var side:=along.cross(Vector3.UP)
  side=Vector3.RIGHT if side.length()<0.01 else side.normalized()
  holder.transform=Transform3D(Basis(along.cross(side),along,side).orthonormalized(),at)
 belt_train.visible=true
 # The left hand under the box, the right on the belt at the top of its loop,
 # going over hand by hand.
 left.position=target_mag.transform*BOX_CENTER+Vector3(0.05,-0.06,0.02)
 left.rotation=Vector3(-0.3,0,-0.6)
 var working:=run>0.0 and run<1.0 and count>0
 var pull:=sin(tx.clock*9.0)*0.025 if working else 0.0
 right.position=(apex+Vector3(0.02,-0.01+pull,0.04)) if working else box_mouth+Vector3(0.07,0.03,0.05)
 right.rotation=Vector3(-0.3,0.0,1.1)
 if tx.stow_left>0:
  var down := 1-tx.stow_left/2.2
  target_mag.position.y-=down*0.45;left.position.y-=down*0.45
  animate_access(1-clampf(down,0,1))

func animate_access(progress: float) -> void:
 # Reach over shoulder, slide the pack forward, undo the lid, reach into it.
 # Seated, the pack stands on the floor between the feet: lift it onto the
 # knees.
 pack.visible=true
 var pull := smoothstep(0,0.32,progress)
 pack.position=(Vector3(0.02,-0.78,-0.32) if seated else Vector3(0.48,-0.8,0.18)).lerp(Vector3(-0.17,-0.42,-0.67),pull)
 pack.rotation=Vector3(-0.25,0.3*pull if seated else 0.3,-0.3*(1-pull))
 pack.get_node("Lid").rotation.x=-smoothstep(0.35,0.60,progress)*1.8
 left.position=pack.position+Vector3(-0.14,0.13,0.08)
 right.position=Vector3(0.25,-0.12,0.02).lerp(pack.position+Vector3(0.05,0.20,0),smoothstep(0.08,0.55,progress))
 right.rotation=Vector3(-0.4,0,-0.2)
 if is_instance_valid(item_prop):
  var retrieve := smoothstep(0.63,0.92,progress)
  item_prop.visible=progress>0.60
  var end := Vector3(0.09,-0.19,-0.43) if kind=="rangefinder" else (Vector3(0.02,-0.23,-0.48) if kind=="medkit" else Vector3(-0.17,-0.25,-0.48))
  item_prop.position=(pack.position+Vector3(0,0.09,0)).lerp(end,retrieve)
  item_prop.rotation=Vector3(-0.25,0.2*retrieve,0.12*retrieve)
  if progress>0.63:right.position=item_prop.position+Vector3(0.055,-0.02,0.055)

func animate() -> void:
 if operator.launcher!=null and operator.launcher.active():visible=false;return
 visible=active()
 if mode=="drone":visible=false;return
 if not visible:return
 left.visible=true;right.visible=true;pack.visible=false
 var tx := transfer()
 if tx.active:
  var item_kind: String=tx.source.get("kind","")
  rebuild("transfer:"+tx.weapon.id+":"+item_kind,tx.weapon.id)
  if tx.box_bag!=null and tx.draw_left>0:
   kind=item_kind;target_mag.visible=false
   if is_instance_valid(cartridge):cartridge.visible=false
   if is_instance_valid(belt_train):belt_train.visible=false
   var box_belt:=target_mag.get_node_or_null("Belt")
   if box_belt!=null:box_belt.visible=false
   animate_access(clampf(tx.elapsed/ACCESS_TIME,0,1));pose_arms();return
  if tx.belt:animate_belt(tx);pose_arms();return
  target_mag.visible=true
  var cycle := clampf(tx.clock/MagazineTransfer.ROUND_TIME,0,1)
  var picking := smoothstep(0,0.40,cycle)
  var pressing := smoothstep(0.45,0.92,cycle)
  var draw := smoothstep(0,1,tx.elapsed) if tx.box_bag==null else 1.0
  target_mag.position=Vector3(-0.03,-0.17,-0.48)+Vector3(0,-0.5*(1-draw),0)
  target_mag.rotation=Vector3(0.18,0.35,-0.16)
  MagazineView.update(target_mag,int(tx.destination.rounds))
  var source_position := target_mag.position+Vector3(-0.066,0.008,0.014) if tx.box_bag==null else Vector3(-0.18,-0.25,-0.60)
  if is_instance_valid(source_mag):
   source_mag.position=source_position+Vector3(0,-0.5*(1-draw),0);source_mag.rotation=Vector3(-0.2,-0.3,0.25)
   MagazineView.update(source_mag,int(tx.source.rounds))
  if is_instance_valid(item_prop):
   pack.visible=true;pack.position=Vector3(-0.18,-0.46,-0.64);pack.rotation=Vector3(-0.25,0.2,0)
   pack.get_node("Lid").rotation.x=-1.8
   item_prop.visible=true;item_prop.position=source_position;item_prop.rotation=Vector3(0.35,0.1,0)
   AmmoPacketArt.show_contents(item_prop,int(tx.source.rounds),smoothstep(0,0.35,tx.elapsed-tx.access_duration))
  left.position=target_mag.position+Vector3(-0.035,-0.10,0.025)
  left.rotation=Vector3(-0.15,0.0,-0.6)
  # Extract one cartridge, cross between the magazines, press under feed lips.
  var pickup := source_position+Vector3(0,0.03,0)
  if is_instance_valid(source_mag):pickup=source_mag.transform*source_mag.get_node("AmmoEvidence/TopRound").position
  var insert: Vector3=target_mag.transform*target_mag.get_node("AmmoEvidence/TopRound").position
  var round_position := pickup.lerp(insert,picking)+Vector3(0,0.035*sin(cycle*PI)+0.012*(1-pressing),0)
  right.rotation=Vector3(-0.3,0.0,1.3)
  right.position=round_position-right.basis*Vector3(0,0.045,-0.035)
  cartridge.position=round_position
  cartridge.rotation=Vector3.ZERO
  cartridge.visible=tx.draw_left<=0 and tx.moved<tx.planned and cycle>0.15 and cycle<0.94
  if tx.stow_left>0:
   var down := 1-tx.stow_left/(2.2 if tx.box_bag!=null else 0.8)
   target_mag.position.y-=down*0.45;right.position.y-=down*0.45;left.position.y-=down*0.45
   if tx.box_bag!=null:animate_access(1-clampf(down,0,1))
 elif mode=="recover_drone":
  rebuild("recover_drone",operator.current().id)
  animate_access(1-clampf(timer/2.2,0,1))
 elif mode=="work":
  pack.visible=false
  for node in [item_prop,source_mag,target_mag,cartridge,belt_train]:
   if is_instance_valid(node):node.visible=false
  var swing := sin(timer*5.0)*0.04
  if work_target.is_finite():
   # Both hands reach for the part being fitted; seen when looking down at it.
   var shoulder := Vector3(0,-0.28,0.05)
   var local := to_local(work_target)
   var reach := shoulder+(local-shoulder).limit_length(0.64)
   var lift := sin(timer*3.4)*0.035
   left.position=reach+Vector3(-0.12,lift,0.02);right.position=reach+Vector3(0.12,-lift,0.02)
   var tilt := -0.9-clampf(-local.y,0,1.2)*0.45
   left.rotation=Vector3(tilt,0,0.4);right.rotation=Vector3(tilt,0,-0.4)
  else:
   left.position=Vector3(-0.16,-0.52+swing,-0.42);right.position=Vector3(0.17,-0.50-swing,-0.40)
   left.rotation=Vector3(-0.9,0,0.3);right.rotation=Vector3(-0.9,0,-0.3)
 elif mode=="goggles":
  var fpv := FPV_DRONE.is_fpv_kind(kind)
  if visual_key!=("fpv_goggles" if fpv else "goggles"):
   visual_key="fpv_goggles" if fpv else "goggles"
   if is_instance_valid(item_prop):item_prop.free()
   item_prop=DroneArt.fpv_goggles() if fpv else DroneArt.goggles();add_child(item_prop);paint(self)
  pack.visible=false
  if is_instance_valid(target_mag):target_mag.visible=false
  if is_instance_valid(source_mag):source_mag.visible=false
  if is_instance_valid(cartridge):cartridge.visible=false
  if is_instance_valid(belt_train):belt_train.visible=false
  item_prop.position=Vector3(0,-0.28,-0.42).lerp(Vector3(0,-0.01,-0.08),smoothstep(0,1.2,timer))
  item_prop.rotation=Vector3.ZERO;item_prop.visible=true
  left.position=item_prop.position+Vector3(-0.09,0,0);right.position=item_prop.position+Vector3(0.09,0,0)
 else:
  rebuild("item:"+kind+(":"+fpv_warhead if FPV_DRONE.is_fpv_kind(kind) else ""),operator.current().id)
  if mode=="access":animate_access(clampf(timer/ACCESS_TIME,0,1))
  elif mode=="fpv_place":
   # Both hands set the drone down on the ground a pace ahead.
   var down := smoothstep(0,1,clampf(timer/FPV_PLACE_TIME,0,1))
   pack.visible=false
   item_prop.visible=down<0.97
   item_prop.position=Vector3(-0.17,-0.25,-0.48).lerp(Vector3(0,-1.05,-0.85),down)
   item_prop.rotation=Vector3(-0.25*(1-down),0,0.12*(1-down))
   left.position=item_prop.position+Vector3(-0.15,0.0,0.06);right.position=item_prop.position+Vector3(0.15,0.0,0.06)
   left.rotation=Vector3(-0.6,0,0.5);right.rotation=Vector3(-0.6,0,-0.5)
  elif mode=="stow":animate_access(1-clampf(timer/2.2,0,1))
  elif mode=="belt":
   # The kit leaves the view downwards to the belt pouch on the hip.
   var down := smoothstep(0,1,clampf(timer/BELT_TIME,0,1))
   item_prop.visible=true
   item_prop.position=Vector3(0.02,-0.23,-0.48).lerp(Vector3(0.24,-0.66,-0.26),down)
   item_prop.rotation=Vector3(-0.25+0.6*down,0.2,0.12)
   right.position=item_prop.position+Vector3(0.055,-0.02,0.055)
   left.position=Vector3(-0.28,-0.62,-0.30)
  elif mode=="rangefinder":
   item_prop.visible=true;item_prop.position=Vector3(0.02,-0.14,-0.22);item_prop.rotation=Vector3.ZERO
   left.position=Vector3(-0.05,-0.16,-0.15);right.position=Vector3(0.08,-0.16,-0.15)
  elif mode in ["pouch","pouch_stow"]:
   # Right hand to the chest pouch on the carrier, out, up to the eyes.
   var t := clampf(timer/(POUCH_TIME if mode=="pouch" else POUCH_STOW),0,1)
   var up := smoothstep(0.30,1.0,t) if mode=="pouch" else 1.0-smoothstep(0,0.70,t)
   var pouch := Vector3(-0.07,-0.42,-0.16)
   item_prop.visible=t>0.18 if mode=="pouch" else t<0.82
   item_prop.position=pouch.lerp(Vector3(0.02,-0.14,-0.22),up)
   item_prop.rotation=Vector3(-0.9*(1-up),0.3*(1-up),0)
   var reach := smoothstep(0,0.30,t) if mode=="pouch" else 1.0-smoothstep(0.70,1.0,t)
   right.position=Vector3(0.25,-0.40,-0.30).lerp(item_prop.position+Vector3(0.06,-0.02,0.07),reach)
   right.rotation=Vector3(-0.5*(1-up),0,-0.2)
   left.position=Vector3(-0.30,-0.56,-0.26).lerp(Vector3(-0.05,-0.16,-0.15),up)

 pose_arms()

func pose_arms() -> void:
 for i in range(2):
  var grip: Node3D=left if i==0 else right
  var wrist := grip.position+grip.basis*Vector3(0,-0.055,0.02)
  var elbow := Vector3(-0.32 if i==0 else 0.38,-0.48,0.12)
  var arm := forearms[i]
  arm.position=(wrist+elbow)*0.5
  arm.quaternion=Quaternion(Vector3.UP,elbow.direction_to(wrist))
  arm.scale=Vector3(1,wrist.distance_to(elbow)/0.26,1)

func toggle_drone() -> void:
 if operator.concussion.acute_left>0 or operator.concussion.incapacitated():return
 if operator.is_vaulting():return
 # J again calls off the goggles, the drone being reached for or folded.
 if mode in ["drone","goggles"] or (kind=="recon_drone" and mode in ["access","recover_drone"]):cancel();return
 if active() or operator.current().phase!="" or operator.arm_injury>=0.5 or operator.injury_time>0 or operator.bandage_time>0:return
 if is_instance_valid(drone):
  if drone.health<=0 or drone.battery<=0:drone_notice="Дрон пошкоджений або розряджений.";return
  if drone.signal_strength<0.04:drone_notice="Немає зв’язку з дроном.";return
  kind="recon_drone";mode="goggles";timer=0;operator.aim=false
  operator.game.inventory.hide_for_action()
 else:
  if not request(operator.backpack.first("recon_drone")):drone_notice="Додай розвіддрон до наплічника в лодауті."

func deployment_point(size: Vector3=Vector3(0.44,0.14,0.38), lifts: Array=[0.085,0.12,0.17]) -> Variant:
 var space := operator.get_world_3d().direct_space_state
 var box := BoxShape3D.new();box.size=size
 var query := PhysicsShapeQueryParameters3D.new();query.shape=box
 query.collision_mask=1|2|4|8|32;query.margin=0.003
 query.exclude=[operator.get_rid()]
 # Look within arm's reach instead of requiring one exact patch to be flat.
 for offset in [Vector3(0,0,-1.05),Vector3(-0.45,0,-0.85),Vector3(0.45,0,-0.85),Vector3(0,0,-0.65)]:
  var support := GroundSupport.sample(space,operator.to_global(offset),operator.global_basis,0.23,-0.20,0.20,[operator.get_rid()])
  if support.is_empty():continue
  for lift in lifts:
   var pose: Transform3D=support.frame
   pose.origin+=pose.basis.y*lift
   if pose.origin.distance_to(operator.camera.global_position)>2.2:continue
   var ray := PhysicsRayQueryParameters3D.create(operator.camera.global_position,pose.origin,1,[operator.get_rid()])
   if not space.intersect_ray(ray).is_empty():continue
   query.transform=pose
   if space.intersect_shape(query,1).is_empty():return pose
 return null

func deploy_drone() -> bool:
 var entry := operator.backpack.item(item_uid)
 var point: Variant=deployment_point()
 if entry.is_empty() or is_instance_valid(drone) or point==null:
  drone_notice="Немає місця для дрона в межах досяжності. Відсунься від стіни або краю.";return false
 drone=ReconDrone.new();operator.add_child(drone);drone.setup(operator,entry)
 drone.global_transform=point;drone.yaw=operator.rotation.y
 operator.backpack.remove(item_uid)
 drone_notice="Дрон розкладено · J — окуляри · F поруч — забрати"
 return true

func recover_drone() -> bool:
 if operator.concussion.acute_left>0 or operator.concussion.incapacitated():return false
 if operator.is_vaulting():return false
 if active() or not is_instance_valid(drone) or not drone.can_recover():return false
 kind="recon_drone";mode="recover_drone";timer=0;operator.aim=false
 return true

func finish_drone_recovery() -> bool:
 if not is_instance_valid(drone) or not drone.can_recover():return false
 var uid := operator.backpack.add("recon_drone")
 if uid<0:drone_notice="У наплічнику потрібен вільний прямокутник 3 × 2.";return false
 var entry := operator.backpack.item(uid)
 entry.battery=drone.battery;entry.condition=drone.health
 drone.queue_free();drone=null
 drone_notice="Дрон повернуто в наплічник. Заряд і пошкодження збережено."
 return true

# The recon drone set out on the ground or in the air (not an FPV).
func recon_parked() -> bool:return is_instance_valid(drone) and not (drone is FPV_DRONE)

# --- FPV ----------------------------------------------------------------------
# Y: an FPV from the pack (the kind asked for, else the first), out (3.4 s),
# set down (1 s), goggles on; Y again in its goggles takes them off (in the
# air it flies on a moment and falls; still on the ground it goes back into
# the pack).
func toggle_fpv(which: String="") -> void:
 if operator.concussion.acute_left>0 or operator.concussion.incapacitated():return
 if operator.is_vaulting():return
 if FPV_DRONE.is_fpv_kind(kind) and mode in ["access","fpv_place","goggles","drone"]:cancel();return
 if mode in ["drone","goggles"]:drone_notice="Спершу зніми окуляри розвіддрона (J).";return
 if active() or operator.current().phase!="" or operator.arm_injury>=0.5 or operator.injury_time>0 or operator.bandage_time>0:return
 var uid := operator.backpack.first(which) if which!="" else first_fpv()
 if uid<0:uid=first_fpv()
 if uid<0:drone_notice="Додай FPV-дрон до наплічника в лодауті.";return
 if not request(uid):drone_notice="Зараз не дістати FPV-дрон."

func first_fpv() -> int:
 for entry in operator.backpack.items:
  if FPV_DRONE.is_fpv_kind(str(entry.kind)):return int(entry.uid)
 return -1

func deploy_fpv() -> bool:
 var entry := operator.backpack.item(item_uid)
 var point: Variant=deployment_point(FPV_FOOTPRINT,FPV_LIFTS)
 if entry.is_empty() or point==null:
  drone_notice="Немає місця, щоб поставити FPV-дрон. Відсунься від стіни або краю.";return false
 var fpv: FPV_DRONE=FPV_DRONE.new()
 operator.add_child(fpv)
 fpv.setup_player(operator,entry)
 fpv.global_transform=point;fpv.yaw=operator.rotation.y
 if is_instance_valid(drone):parked_drone=drone
 drone=fpv
 drone_notice="FPV-дрон на землі · Y — зняти окуляри"
 return true

# Goggles off an FPV. In the air nobody flies it now; on the ground it never
# left the pack's inventory and goes back. True when the hands put it back.
func release_fpv() -> bool:
 var fpv=drone
 drone=parked_drone if is_instance_valid(parked_drone) else null
 parked_drone=null
 if fpv.launched():
  fpv.abandon()
  drone_notice="Окуляри знято: FPV-дрон без керування падає."
  return false
 if fpv.piloting:fpv.end_control()
 fpv.queue_free()
 drone_notice="FPV-дрон повернуто в наплічник."
 return true

# The FPV went off, broke up or was lost: goggles off, the recon drone back.
func fpv_gone(fpv: ReconDrone, message: String="") -> void:
 if drone!=fpv:return
 drone=parked_drone if is_instance_valid(parked_drone) else null
 parked_drone=null
 if message!="":drone_notice=message
 if mode in ["drone","goggles"]:mode="";timer=0;visible=false
