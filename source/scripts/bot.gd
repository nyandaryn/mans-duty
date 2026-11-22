class_name Hostile
extends CharacterBody3D
var friendly := false
var exposed_time := 0.0
var perception_cursor := 0
var last_path_goal := Vector3.INF
var follow_crouch := false
var follow_concealment := false
var follow_prone := false
var tactical_prone := 0.0
var under_fire_time := 0.0
var shelled := 0.0
var cover_requires_prone := false
var auto_cover := false
var outfit_id := "rf_digital"
var since_shot := 10.0
var combat_target: Node3D
var formation_index := 0
var order := "follow"
var order_point := Vector3.ZERO
var order_origin := Vector3.ZERO
var order_direction := Vector3.FORWARD
var assault_arrived := false
var cover_dwell := 0.0
var fire_at_will := true
var defensive := false
var defense_radius := 18.0
var injury_age := 100.0
var peek_side := 0.0
var peek_top := false
var peek_choice_timer := 0.0
var suppressive_fire := false
var reaction_left := 0.0
var panic_time := 0.0
var tracked_aim := Vector3.ZERO
var squad_role := ""
var squad_partner: Hostile
# The infantry fighting vehicle this soldier rides in, or null on foot.
var vehicle: BmpVehicle
# His role and what he carries for it (BotKit): machine gunner, sniper,
# grenade launchers, drone pilot; null for a plain rifleman of old.
var kit: BotKit
# Magnification of his sight for recognition (a sniper's PSO-1).
var optic := 1.0
# The quiet life before the fight (Idle): empty once he is on alert.
var idle := {}
# His body armour (VestKind) and the share of a burst it lets through.
var vest := "korsar"
var vest_blast := 1.0
# A balaclava or a gaiter (FaceCover), and the assault pack on his back.
var face_cover := "none"
var has_pack := false
var hitbox_layers: Array[int]=[]
var suppress_point := Vector3.ZERO
var suppress_age := 100.0
var last_visual_point := Vector3.ZERO
var last_visual_age := 100.0
var sprinting := false
var recognition := 0.0
var observation: Dictionary = {}
var game: Node3D
var model: Node3D
var health := 100.0
var concussion := ConcussionState.new()
var plate_integrity := 1.0
var last_wound := ""
var target := Vector3.ZERO
var home := Vector3.ZERO
var alerted := false
var sees_player := false
var think_timer := 0.0
var path_timer := 0.0
var shoot_timer := 1.0
var path := PackedVector2Array()
var path_index := 0
var age := 0.0
var dead := false
var weapon := WeaponState.new("ak74")
var state := "patrol"
var suppression := 0.0
var wound_timer := 0.0
var bleeding := 0.0
var leg_wound := 0.0
var arm_wound := 0.0
var contact_age := 100.0
var cover_timer := 0.0
var cover_point := Vector3.ZERO
var has_cover := false
var stance := 0.0
var aim_weight := 0.0
var aim_time := 0.0
var burst_left := 0
var radio_timer := 0.0
var pending_contact := Vector3.ZERO
var pending_delay := -1.0
var hitboxes: Array[Area3D]=[]
var last_incoming := Vector3.FORWARD
var peek_clock := 0.0
var blind_fire := false
var shot_kick := 0.0
var known_height := 1.65
var previous_reload_phase := ""
var no_sight_time := 0.0
var flank_timer := 0.0
var flank_probe_timer := 0.0
var flank_point := Vector3.ZERO
var recoil_offset := Vector2.ZERO
var medical_kits := 2
var treatment_time := 0.0
var treatment_wait := 0.0
var collapse := 0.0
var collapse_time := 0.0
var lean_roll := 0.0
var blood_loss := 0.0
var medical_prop: MeshInstance3D
# Update level of detail: distant soldiers think and move at a lower rate,
# accumulating the skipped time so every timer and speed stays in real seconds.
var lod_accum := 0.0
var lod_slot := 0
var lod_interval := 1
# Cached scene nodes; string lookups every tick dominate large battles.
var n_head: Node3D
var n_rifle: Node3D
var n_bolt: Node3D
var n_mag: Node3D
var n_muzzle: Node3D
var n_legs: Array[Node3D]=[]
var n_knees: Array[Node3D]=[]
var n_feet: Array[Node3D]=[]
var n_arms: Array[Node3D]=[]
var n_forearms: Array[Node3D]=[]
# Distant soldiers are drawn by CrowdRenderer from the animated nodes.
var render_far := false
# Seen while aboard a vehicle: the visual layers of the model in the troop
# compartment or in a doorway (BmpTroops); 0 keeps him out of sight.
var ride_layer := 0
var pose_serial := 0
var shape_dirty := true
var n_shape: CollisionShape3D
var n_capsule: CapsuleShape3D
var sight_points: Array[Node3D]=[]
var shape_down := -1.0
var shape_stance := -1.0
# A drone of the other side: heard close by or seen in the air, noticed after
# a moment, then shot at with a lead when no man of the other side in sight
# nearer than DRONE_FIRST comes first and the shells do not keep heads down.
# A Mavic class quadcopter is heard over the battle only within some 35 m
# (an FPV's whine much further, ReconDrone.heard_within) and seen against
# the sky to about 120 m, slowly further out: high up it is a speck few men
# notice and a rifle rarely hits. Not every man fires at one — some keep
# their heads down, the more so under a diving FPV (drone_shooter), and only
# a few get a clear shot at a time (ReconDrone.take_aim).
const DRONE_SIGHT := 120.0
const DRONE_FIRST := 60.0
var drone_target: ReconDrone
var drone_notice := 0.0
var drone_lost := 0.0
var drone_aim := Vector3.INF
var drone_aim_time := 0.0
var drone_lead := 1.0
var drone_shooter := true

func setup(owner_game: Node3D, spawn: Vector3) -> void:
	game=owner_game
	# About half the men fire at a drone (by where they start: no dice drawn).
	drone_shooter=absi(hash(Vector2i(roundi(spawn.x*7.0),roundi(spawn.z*7.0))))%100<50
	weapon.debug_infinite=game.debug_invulnerable
	position=spawn
	home=spawn
	defensive=not game.district.campaign_definition.is_empty()
	if defensive:
		rotation.y=PI
		has_cover=true
		cover_point=spawn
	target=spawn
	collision_layer=4
	collision_mask=1|2|4|64
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.30
	capsule.height=1.82
	collision.shape=capsule
	collision.position.y=0.91
	add_child(collision)
	model=Models.soldier(self,true)
	outfit_id=game.player_outfit if friendly else game.enemy_outfit
	Wardrobe.dress(model,outfit_id)
	CharacterArt.team_markings(model,friendly)
	wear_vest(VestKind.issue(friendly,formation_index))
	# What he wears by his place in the formation, or (outside one) by his
	# order of spawning.
	var kit_index:=int(get_meta("kit_index",formation_index))
	face_cover=FaceCover.issue(friendly,kit_index)
	FaceCover.wear(model,face_cover,outfit_id)
	# Three men in four carry a pack.
	wear_pack(kit_index%4!=1)
	hitboxes.append(DamageModel.hitbox(self,model.get_node("Head"),"head",Vector3(0,0.156,-0.045),Vector3(0.225,0.27,0.235)))
	hitboxes.append(DamageModel.hitbox(self,model,"chest",Vector3(0,1.29,0),Vector3(0.40,0.36,0.30)))
	hitboxes.append(DamageModel.hitbox(self,model,"abdomen",Vector3(0,1.00,0),Vector3(0.34,0.22,0.28)))
	# The plates of his vest, front and back, of their real size.
	for z in [-0.19,0.19]:hitboxes.append(DamageModel.hitbox(self,model,"plate",Vector3(0,VestKind.plate_center_y(vest),z),VestKind.plate_box(vest)))
	for side in ["Left","Right"]:
		hitboxes.append(DamageModel.limb_hitbox(self,model.get_node(side+"Leg"),"leg",Vector3(0,-0.36,0.015),0.21,true))
		hitboxes.append(DamageModel.limb_hitbox(self,model.get_node(side+"Leg/Knee"),"leg",Vector3(0,-0.36,0),0.16,false))
		hitboxes.append(DamageModel.hitbox(self,model.get_node(side+"Leg/Knee/Foot"),"leg",Vector3(0,-0.02,-0.035),Vector3(0.15,0.16,0.25)))
		hitboxes[-1].set_meta("upper_limb",false)
		var elbow := CharacterArt.UPPER_LEFT if side=="Left" else CharacterArt.UPPER_RIGHT
		hitboxes.append(DamageModel.limb_hitbox(self,model.get_node(side+"Arm"),"arm",elbow,0.17,true))
		var wrist := CharacterArt.LOWER_LEFT if side=="Left" else CharacterArt.LOWER_RIGHT
		hitboxes.append(DamageModel.limb_hitbox(self,model.get_node(side+"Arm/Forearm"),"arm",wrist,0.13,false))
	medical_prop=MeshInstance3D.new()
	var dressing := BoxMesh.new()
	dressing.size=Vector3(0.12,0.06,0.09)
	medical_prop.mesh=dressing
	var material := StandardMaterial3D.new()
	material.albedo_color=Color("dad8bd")
	medical_prop.material_override=material
	medical_prop.visible=false
	model.add_child(medical_prop)
	n_shape=collision
	n_capsule=capsule
	n_head=model.get_node("Head")
	n_rifle=model.get_node("CarriedRifle")
	n_bolt=n_rifle.get_node("Bolt")
	n_mag=n_rifle.get_node("Magazine")
	n_muzzle=n_rifle.get_node("BotMuzzle")
	for side in ["Left","Right"]:
		n_legs.append(model.get_node(side+"Leg"))
		n_knees.append(model.get_node(side+"Leg/Knee"))
		n_feet.append(model.get_node(side+"Leg/Knee/Foot"))
		n_arms.append(model.get_node(side+"Arm"))
		n_forearms.append(model.get_node(side+"Arm/Forearm"))
	for area in hitboxes:
		if area.get_meta("zone") in ["head","chest","abdomen"]:sight_points.append(area.get_child(0))
	sight_points.append_array(n_knees)
	lod_slot=randi()%12
	think_timer=randf()*0.4
	path_timer=randf()*1.5
	rotation.y=randf()*TAU

# Takes up a role: its weapon in his hands and on the model.
func set_kit(id: String) -> void:
	if kit!=null:kit.clear()
	kit=BotKit.make(self,id)
	var weapon_id: String=BotKit.WEAPON.get(id,"ak74")
	if weapon_id!=weapon.id:
		weapon=WeaponState.new(weapon_id)
		weapon.debug_infinite=game.debug_invulnerable
		# The baked model of the weapon (the PKM's comes with its art).
		if ResourceLoader.exists("res://assets/models/"+("ak74m" if weapon_id=="ak74" else weapon_id)+".scn"):
			remodel(func():CharacterArt.equip_display(model,weapon_id))
		n_rifle=model.get_node("CarriedRifle")
		n_bolt=n_rifle.get_node("Bolt")
		n_mag=n_rifle.get_node("Magazine")
		n_muzzle=n_rifle.get_node("BotMuzzle")
	optic=2.5 if id=="sniper" else 1.0
	# A grenadier's rounds and an operator's drones go in a pack.
	if id in ["rpg7","uav"]:wear_pack(true)

func kit_id() -> String:return kit.kind if kit!=null else "rifle"

# Puts on or takes off his pack (PackArt, merged for the battle).
func wear_pack(on: bool) -> void:
	if on==has_pack:return
	has_pack=on
	remodel(func():PackArt.equip(model,on,true))

# Puts on a vest: its model over the plate bags of the uniform.
func wear_vest(id: String) -> void:
	vest=VestKind.valid(id)
	vest_blast=VestKind.blast_factor(vest)
	remodel(func():CharacterArt.wear_vest(model,vest))

# Changes the soldier's own geometry. A distant soldier of the great assault
# is drawn by the crowd with his detailed meshes out of the tree: they are
# put back for the change and recorded anew after it, or the new parts would
# stay drawn beside the crowd's figure and the old ones would leak.
func remodel(change: Callable) -> void:
	var crowd: CrowdRenderer=null
	if game!=null and game.battle!=null and is_instance_valid(game.battle.crowd):crowd=game.battle.crowd
	if crowd!=null:crowd.before_remodel(self)
	change.call()
	if crowd!=null:crowd.after_remodel(self)

# Fragments of a burst: what the vest keeps off (BlastSystem.detonate).
func blast_protection(_where: Vector3) -> float:return vest_blast

func hear(where: Vector3) -> void:
	if dead or global_position.distance_to(where)>180:return
	# A sound gives an approximate bearing, not continuous knowledge through walls.
	if sees_player:return
	var error := clampf(global_position.distance_to(where)*0.08,2.0,9.0)
	pending_contact=where+Vector3(randf_range(-error,error),0,randf_range(-error,error))
	if pending_delay<0:pending_delay=randf_range(0.18,0.65) if not alerted else 0.12

func report_contact(where: Vector3) -> void:
	if dead or sees_player:return
	suppress_point=where+Vector3.UP*1.2
	suppress_age=0
	pending_contact=where
	if pending_delay<0:pending_delay=randf_range(0.4,1.0)

func suppress(source: Vector3, amount: float) -> void:
	if dead:return
	if friendly:
		under_fire_time=5.0
		cover_timer=minf(cover_timer,0.15)
	suppression=minf(3.0,suppression+amount)
	if not alerted:
		alerted=true
		target=Vector3(source.x+randf_range(-6,6),0,source.z+randf_range(-6,6))
		target.y=game.district.ground_height(target)
		contact_age=0
		cover_timer=0

func line_clear(a: Vector3, b: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()

# What lies between: 0 nothing, 1 only fence panels (they hide a man, a
# bullet goes through), 2 something that stops a bullet.
func obstruction(a: Vector3, b: Vector3) -> int:
	var excluded: Array[RID]=[]
	var screened := 0
	for i in range(4):
		var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1,excluded))
		if hit.is_empty():return screened
		if not hit.collider.has_meta("screen"):return 2
		screened=1
		excluded.append(hit.rid)
	return 2

func cover_clear(a: Vector3, b: Vector3) -> bool:return obstruction(a,b)<2

func find_cover(wounded: bool = false) -> void:
	if not game.battle.budget("cover"):
		cover_timer=0.1+randf()*0.15
		return
	if friendly:
		game.squad.find_cover(self,wounded)
		return
	cover_timer=randf_range(2.5,4.5)
	var threat := target+Vector3.UP*1.5
	# Keep a position while it still shields from the current threat: no
	# hopping between spots (and across open ground) as the fight goes on.
	# A spot he cannot reach (stuck short of it) is searched again.
	if has_cover and (global_position.distance_to(cover_point)<0.85 or velocity.length()>0.3) and (not defensive or Vector2(cover_point.x-home.x,cover_point.z-home.z).length()<=defense_radius+2):
		if shield(threat,cover_point,0.6 if cover_requires_prone else 1.1)>=0.66:
			cover_timer=randf_range(3.5,5.5)
			return
	var candidates: Array[Vector3]=[global_position]
	for radius in [3.0,6.0,10.0,15.0]:
		for i in range(10):
			var angle: float=float(i)*TAU/10+float(radius)
			candidates.append(global_position+Vector3(cos(angle)*radius,0,sin(angle)*radius))
	# The far side of walls, trunks and wrecks nearby, seen from the threat.
	var eye := global_position+Vector3.UP
	var space := get_world_3d().direct_space_state
	for i in range(8):
		var heading := Vector3(cos(float(i)*TAU/8),0,sin(float(i)*TAU/8))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye+heading*12,1))
		if hit.is_empty():continue
		var away := Vector3(hit.position)-threat
		away.y=0
		away=away.normalized()
		for depth in [0.8,1.6]:candidates.append(Vector3(hit.position)+away*depth)
	var ranked: Array[Dictionary]=[]
	var used := {}
	for candidate in candidates:
		var cell: Vector2i=game.district.nearest_cell(game.district.navigation_cell(candidate))
		if used.has(cell) or not game.district.grid.region.has_point(cell) or game.district.grid.is_point_solid(cell):continue
		used[cell]=true
		var point: Vector3=game.district.navigation_position(cell)+Vector3.UP*0.1
		if point.distance_to(global_position)>16:continue
		if defensive and Vector2(point.x-home.x,point.z-home.z).length()>defense_radius:continue
		var occupied := false
		for ally in game.bots:
			if ally!=self and not ally.dead and ally.has_cover and ally.cover_point.distance_to(point)<1.5:
				occupied=true
				break
		if occupied:continue
		# Crouched behind it, or else lying behind low cover.
		var low := wounded
		var protect := shield(threat,point,0.6 if low else 1.1)
		if protect<0.66 and not low:
			low=true
			protect=shield(threat,point,0.6)
		if protect<0.66:continue
		var score := point.distance_to(global_position)+(1-protect)*8+(2.5 if low and not wounded else 0.0)
		if point.distance_to(target)<12:score+=20
		# Prefer a fire position: lean out at the side or rise over the top.
		var side := Vector3(-(point-target).z,0,(point-target).x).normalized()*0.5
		if not wounded and (cover_clear(point+Vector3.UP*1.25+side,threat) or cover_clear(point+Vector3.UP*1.25-side,threat)):score-=4
		elif not wounded and cover_clear(point+Vector3.UP*(1.1 if low else 1.6),threat):score-=2.5
		ranked.append({"point":point,"score":score,"low":low})
	ranked.sort_custom(func(a,b):return float(a.score)<float(b.score))
	# Route checks are expensive: only the best few candidates get one.
	var checked := 0
	for entry in ranked:
		var point: Vector3=entry.point
		if point.distance_to(global_position)>0.8:
			if checked>=3 or not game.battle.budget("path"):break
			checked+=1
			if game.district.path(global_position,point).size()<2:continue
		has_cover=true
		cover_point=point
		cover_requires_prone=entry.low
		state="seek_cover"
		path_timer=0
		return
	has_cover=false
	cover_requires_prone=false

# Share of a body at this height (centre and both sides) hidden from a threat.
func shield(threat: Vector3, point: Vector3, height: float) -> float:
	var sample := point+Vector3.UP*height
	var middle := obstruction(threat,sample)
	if middle==0:return 0.0
	var heading := point-threat
	heading.y=0
	var side := Vector3(-heading.z,0,heading.x).normalized()*0.22
	# A fence hides, it does not cover: three quarters of the worth of a wall.
	var covered := 1.0/3 if middle==2 else 0.25
	for offset in [side,-side]:
		match obstruction(threat,sample+offset):
			2:covered+=1.0/3
			1:covered+=0.25
	return covered

# A shell burst close by: heads down and into cover for a few seconds.
func shell_burst(where: Vector3, strength: float) -> void:
	if dead:return
	shelled=maxf(shelled,2.5+strength*5.0)
	suppress(where,0.5+strength*1.6)
	if not friendly and not (has_cover and global_position.distance_to(cover_point)<0.85):cover_timer=minf(cover_timer,0.1)

func _physics_process(delta: float) -> void:
	if dead or not game.running or game.paused or vehicle!=null:
		lod_accum=0
		return
	lod_accum+=delta
	lod_interval=game.battle.update_interval(self)
	if lod_interval>1 and (Engine.get_physics_frames()+lod_slot)%lod_interval!=0:return
	var step:=minf(lod_accum,0.25)
	lod_accum=0
	_tick(step)

# move_and_slide() always integrates one physics tick. A reduced-rate update
# covers several ticks, so displacement is scaled and the speed restored.
func slide(step: float) -> void:
	# A soldier standing still on the ground needs no collision sweep. Any
	# capsule change (standing up, going prone) still runs the full solve.
	if game.battle.active and not shape_dirty and is_on_floor() and absf(velocity.x)<0.01 and absf(velocity.z)<0.01:
		velocity.y=0
		return
	shape_dirty=false
	var tick := get_physics_process_delta_time()
	if step<=tick*1.01:
		move_and_slide()
		return
	var k := step/tick
	velocity*=k
	move_and_slide()
	velocity/=k

func _tick(delta: float) -> void:
	if dead or not game.running or game.paused:return
	concussion.tick(delta)
	age+=delta
	since_shot+=delta
	under_fire_time=maxf(0,under_fire_time-delta)
	shelled=maxf(0,shelled-delta)
	no_sight_time+=delta
	flank_timer=maxf(0,flank_timer-delta)
	flank_probe_timer=maxf(0,flank_probe_timer-delta)
	contact_age+=delta
	last_visual_age+=delta
	suppress_age+=delta
	reaction_left=maxf(0,reaction_left-delta)
	panic_time=maxf(0,panic_time-delta)
	peek_clock+=delta
	think_timer-=delta
	path_timer-=delta
	cover_timer-=delta
	radio_timer-=delta
	shoot_timer-=delta
	wound_timer=maxf(0,wound_timer-delta)
	suppression=maxf(0,suppression-delta*0.30)
	shot_kick=move_toward(shot_kick,0,delta*1.7)
	recoil_offset=recoil_offset.move_toward(Vector2.ZERO,delta*(0.11 if stance>0.5 else 0.07))
	if bleeding>0:
		health-=bleeding*delta
		blood_loss=minf(1,blood_loss+bleeding*delta*0.012)
		if health<=0:
			die()
			return
	if friendly:game.squad.prepare_actor(self,delta)
	if update_medical(delta):return
	if pending_delay>=0:
		pending_delay-=delta
		if pending_delay<0 and not sees_player:
			alerted=true
			target=pending_contact
			contact_age=0
			cover_timer=0
	weapon.update(delta)
	while weapon.live_ejections>0:
		game.eject_case(n_rifle.to_global(Vector3(0.04,0.01,0)),n_rifle.global_basis,weapon.id,true)
		weapon.live_ejections-=1
	if weapon.phase!=previous_reload_phase:
		if weapon.phase in ["remove","insert","rack"]:
			game.spatial_shot({"remove":"mag_out","insert":"mag_in","rack":"bolt"}[weapon.phase],global_position+Vector3.UP,-16)
		previous_reload_phase=weapon.phase
	if weapon.rounds()==0 and not weapon.chambered and weapon.phase=="" and (weapon.debug_infinite or weapon.ammunition_total()>0):weapon.reload()
	var player: Node3D=combat_target if is_instance_valid(combat_target) else (null if friendly else game.player)
	var distance := global_position.distance_to(player.global_position) if is_instance_valid(player) else global_position.distance_to(target)
	if think_timer<=0:
		think_timer=0.35+randf()*0.16 if game.battle.active else 0.22+randf()*0.12
		# Distant or unseen soldiers of a large battle re-evaluate less often.
		if lod_interval>=3:think_timer*=1.4
		var eye: Vector3=n_head.to_global(CharacterArt.EYE+Vector3(0,0,-0.012))
		player=select_contact(eye)
		if player!=combat_target:
			# Recognition belongs to an individual, not to an interchangeable target.
			if is_instance_valid(combat_target):recognition=0
			sees_player=false
			combat_target=player
		distance=global_position.distance_to(player.global_position) if is_instance_valid(player) else global_position.distance_to(target)
		var in_view := float(observation.exposure)>0
		if float(observation.exposure)>0:
			recognition=minf(1,recognition+float(observation.rate)*think_timer*(1.4 if alerted else 1.0))
		# The role's own judgement (launchers, drones, the gunner's aim).
		else:recognition=maxf(0,recognition-think_timer*0.8)
		var previously_seen := sees_player
		sees_player=in_view and float(observation.exposure)>0 and recognition>=(0.3 if sees_player else 1.0)
		if sees_player:
			if not previously_seen:
				if friendly:
					under_fire_time=maxf(under_fire_time,2.5)
					cover_timer=0
				reaction_left=randf_range(0.28,0.65) if alerted else randf_range(0.45,0.95)
				aim_time=0
				panic_time=1.4 if distance<15 else 0.0
				tracked_aim=eye-global_basis.z*maxf(distance,3)
			no_sight_time=0
			if not alerted:shoot_timer=maxf(shoot_timer,0.65)
			alerted=true
			target=Vector3(observation.aim_point)
			target.y=game.district.ground_height(target)+0.1
			last_visual_point=observation.aim_point
			last_visual_age=0
			suppress_point=last_visual_point
			suppress_age=0
			pending_delay=-1
			known_height=Vector3(observation.aim_point).y-player.global_position.y+0.12
			contact_age=0
			if radio_timer<=0:
				radio_timer=2.0
				for ally in (game.allies if friendly else game.bots):
					if ally!=self and ally.global_position.distance_to(global_position)<85:ally.report_contact(target)
		if not friendly:spot_drone(eye,think_timer)
		if friendly:
			if cover_timer<=0 and (order in ["engage","assault"] or follow_concealment or (alerted and contact_age<15) or under_fire_time>0):find_cover()
		elif alerted and cover_timer<=0 and (flank_timer<=0 or suppression>1.4) and (not has_cover or suppression>0.4 or contact_age>7):find_cover()
		if kit!=null:kit.think(think_timer)
	if sees_player and reaction_left<=0:
		var pivot := global_position+Vector3.UP*1.4
		var from := pivot.direction_to(tracked_aim)
		var to := pivot.direction_to(last_visual_point)
		var angle := from.angle_to(to)
		tracked_aim=pivot+from.slerp(to,minf(1,delta*1.8/maxf(angle,0.001)))*pivot.distance_to(last_visual_point)
	var at_cover := has_cover and global_position.distance_to(cover_point)<0.85
	peek_choice_timer-=delta
	if at_cover and peek_choice_timer<=0:
		peek_choice_timer=0.6
		choose_peek()
	if not at_cover:
		peek_side=0
		peek_top=false
	var reload_active := weapon.phase!=""
	# A defender under fire or shelling stays in cover; in a large battle he
	# moves to a new firing point only after a long quiet spell.
	if not friendly and alerted and squad_role!="cover" and at_cover and no_sight_time>(12 if game.battle.active else 5) and shelled<=0 and suppression<1 and not reload_active and health>60 and flank_timer<=0 and flank_probe_timer<=0:
		flank_probe_timer=randf_range(1.0,1.8)
		var away := (global_position-target).normalized()
		var lateral := Vector3(-away.z,0,away.x)*(1 if get_index()%2==0 else -1)
		var candidate := global_position+away*3+lateral*8
		if defensive and candidate.distance_to(home)>defense_radius:candidate=home
		var cell: Vector2i=game.district.nearest_cell(game.district.navigation_cell(candidate))
		flank_point=game.district.navigation_position(cell)
		if game.battle.budget("path") and game.district.path(global_position,flank_point).size()>1 and not line_clear(target+Vector3.UP*1.5,flank_point+Vector3.UP):
			has_cover=false
			at_cover=false
			flank_timer=8
			path_timer=0
			cover_timer=8
			no_sight_time=0
	var hide := at_cover and ((friendly and under_fire_time>0 and squad_role!="cover") or shelled>0 or suppression>1.4 or reload_active or (squad_role!="cover" and fmod(peek_clock,4.8)<2.3))
	# A machine gunner stays on his gun longer; a launcher on the shoulder is
	# up whatever comes.
	if kit!=null and kit.kind=="mg" and at_cover and shelled<=0 and suppression<=2.2 and not reload_active and fmod(peek_clock,6.0)<4.2:hide=false
	if kit!=null and kit.exposed():hide=false
	var drone_fire := drone_shooter and drone_engaged() and not (sees_player and distance<DRONE_FIRST) and shelled<=0 and suppression<=1.4 and not reload_active and wound_timer<=0 and arm_wound<0.5 and collapse<0.01 and treatment_time<=0 and drone_target.take_aim(self)
	# The rest keep their heads down when a fast one comes (an FPV).
	if not drone_fire and drone_engaged() and drone_target.velocity.length()>12.0 and at_cover:hide=true
	if drone_fire:
		hide=false
		var at: Vector3=drone_target.global_position
		drone_aim=at+drone_target.velocity*(n_head.global_position.distance_to(at)/760.0)*drone_lead
	else:
		drone_aim=Vector3.INF
		drone_aim_time=0.0
	# A halted assault waits under cover; peeking resumes only on contact.
	# Within arm's reach of the chosen cover counts as being there.
	var holding: bool=friendly and has_cover and global_position.distance_to(cover_point)<4.0 and game.squad.holding(self)
	if holding and game.squad.quiet(self):hide=true
	blind_fire=at_cover and hide and suppression>1.8 and last_visual_age<3 and not reload_active and not line_clear(global_position+Vector3.UP*1.3,target+Vector3.UP*1.5)
	var desired_stance := 1.0 if hide or wound_timer>0 or reload_active or leg_wound>0.6 else 0.0
	if blind_fire:desired_stance=0.7
	# Fire discipline in a halted assault: aimed shots at seen enemies only.
	var gunner := kit!=null and kit.kind=="mg"
	suppressive_fire=(squad_role=="cover" or gunner) and not sees_player and suppress_age<(12 if gunner else 8) and not reload_active and not holding
	blind_fire=at_cover and not sees_player and (suppression>0.7 or (suppressive_fire and not gunner)) and suppress_age<8 and (peek_side!=0 or peek_top) and not reload_active and not holding
	if drone_fire:
		blind_fire=false
		suppressive_fire=false
	if at_cover and not hide and peek_side!=0:desired_stance=0.8
	if blind_fire:desired_stance=1.0
	if friendly and (follow_crouch or (follow_concealment and has_cover) or under_fire_time>0):desired_stance=maxf(desired_stance,1.0)
	# Waiting behind cover: lean out to fire on one knee, never stand up.
	if holding:desired_stance=maxf(desired_stance,0.8)
	if kit!=null and kit.busy():desired_stance=1.0 if kit.piloting() else 0.8
	if not idle.is_empty():desired_stance=0.0
	stance=move_toward(stance,desired_stance,delta*4)
	if not friendly:
		# Defenders lie down behind low cover and hit the ground under shelling
		# when no cover is near; they rise to a knee to fire.
		var lie := (at_cover and cover_requires_prone and hide) or (shelled>0 and not has_cover) or bipod_down(at_cover)
		tactical_prone=move_toward(tactical_prone,1.0 if lie else 0.0,delta*3)
	var aiming := (alerted and not hide and not reload_active and wound_timer<=0 and arm_wound<0.5 and contact_age<8) or drone_fire
	aim_weight=move_toward(aim_weight,1.0 if aiming else 0.0,delta*3)
	if aiming and sees_player:aim_time+=delta
	else:aim_time=maxf(0,aim_time-delta*3)
	state="covered" if hide else ("engage" if at_cover else ("seek_cover" if has_cover else ("search" if alerted else "patrol")))
	var standoff := (global_position-target).normalized()
	if standoff.length()<0.1:standoff=global_basis.z
	var search_point := home if defensive else target+standoff*12
	var destination := cover_point if has_cover else (flank_point if flank_timer>0 else (search_point if alerted else target))
	# The covering partner fires from where he is, once he is in his cover.
	if squad_role=="cover" and not sees_player and (not has_cover or at_cover):
		destination=global_position
		state="covering"
	if flank_timer>0 and not has_cover:state="flank"
	if not defensive and not alerted and global_position.distance_to(target)<1.4:
		target=home+Vector3(randf_range(-5,5),0,randf_range(-5,5))
		destination=target
	if not defensive and alerted and squad_role!="cover" and not has_cover and sees_player and flank_timer<=0:
		# Change lateral position instead of freezing in the open.
		destination=global_position+global_basis.x*(3 if int(age/3)%2==0 else -3)
	if friendly:
		destination=game.squad.destination(self)
		at_cover=has_cover and global_position.distance_to(cover_point)<0.85
		if order=="hold" and global_position.distance_to(destination)<0.8:at_cover=true
	if not idle.is_empty():
		if alerted or under_fire_time>0 or shelled>0 or suppression>0.5 or wound_timer>0 or collapse>0.1:Idle.stop(self)
		else:
			destination=Idle.destination(self,delta)
			at_cover=false
	if path_timer<=0 and game.battle.budget("path"):
		path_timer=1.1+randf()*0.3 if game.battle.active else (0.65 if friendly else 1.0)
		if last_path_goal.distance_to(destination)>1.5 or path_index>=path.size() or velocity.length()<0.2:
			path=game.district.path(global_position,destination)
			path_index=1 if path.size()>1 else 0
			last_path_goal=destination
	var direction := Vector3.ZERO
	if squad_role!="cover" and not at_cover and path_index<path.size() and wound_timer<0.35:
		var waypoint := Vector3(path[path_index].x,position.y,path[path_index].y)
		if position.distance_to(waypoint)<0.35/game.district.navigation_scale:path_index+=1
		else:direction=position.direction_to(waypoint)
	sprinting=alerted and direction.length()>0.1 and not at_cover and leg_wound<0.25 and arm_wound<0.5 and weapon.phase=="" and (has_cover or suppression>0.6 or flank_timer>0)
	var speed := (5.2 if sprinting else (2.4 if alerted else 1.1))*(1-leg_wound*0.65)*(0.55 if arm_wound>=0.5 else 1.0)*(1-stance*0.45)
	if friendly:
		tactical_prone=move_toward(tactical_prone,game.squad.posture(self,direction.length()>0.1),delta*4)
		speed=game.squad.movement(self,direction,destination)*(1-leg_wound*0.65)*(0.55 if arm_wound>=0.5 else 1.0)
		if sprinting:stance=move_toward(stance,0.2,delta*8)
		direction=game.squad.separate(self,direction)
	if friendly and bipod_down(at_cover):tactical_prone=move_toward(tactical_prone,1.0,delta*3)
	if not idle.is_empty():
		speed=minf(speed,Idle.STROLL_SPEED);sprinting=false
		tactical_prone=move_toward(tactical_prone,0.0,delta*3)
	if not friendly and tactical_prone>0.5:speed=minf(speed,0.85)
	if kit!=null and kit.holds():direction=Vector3.ZERO
	velocity.x=direction.x*speed
	if concussion.active():
		sprinting=false
		speed=minf(speed,2.4)*concussion.movement_multiplier()
		velocity.x=direction.x*speed
	velocity.z=direction.z*speed
	velocity.y-=19*delta
	slide(delta)
	var look: Vector3=game.squad.look_direction(self,direction) if friendly else (target-position if alerted else direction)
	if drone_fire:look=drone_aim-position
	if kit!=null and kit.facing()!=Vector3.INF:look=kit.facing()-position
	if not idle.is_empty():look=Idle.look(self,direction)
	if look.length()>0.1:
		var desired := atan2(-look.x,-look.z)
		rotation.y+=clampf(angle_difference(rotation.y,desired),-delta*2.2,delta*2.2)
	animate_pose(delta,direction.length()>0.1)
	if kit!=null and kit.kind=="mg":set_bipod(braced())
	if not idle.is_empty():
		Idle.pose(self)
		return
	if kit!=null and kit.act(delta):return
	if drone_fire:
		fire_at_drone(delta)
		return
	var settle := 0.65+distance*0.004
	if kit_id()=="sniper":settle=1.1+distance*0.0035
	var ready := sees_player and reaction_left<=0 and not hide and aim_time>(0.18 if panic_time>0 else settle)*(1+concussion.severity*3)
	if sprinting or reaction_left>0 or not (ready or blind_fire or suppressive_fire) or arm_wound>=0.5 or wound_timer>0 or weapon.phase!="":
		shoot_timer=maxf(0,shoot_timer)
		return
	if shoot_timer<=0.000001:
		var role:=kit_id()
		if burst_left<=0:
			burst_left=randi_range(2,4) if not blind_fire else randi_range(4,7)
			# PKM: bursts of five to ten; the sniper one aimed round at a time.
			if role=="mg":burst_left=randi_range(5,10) if not suppressive_fire else randi_range(8,14)
			elif role=="sniper":burst_left=1
			shoot_timer=0 # No accumulated firing debt from time without a target.
		while burst_left>0 and shoot_timer<=0.000001:
			if not shoot(player,distance):
				burst_left=0
				shoot_timer=0.25
				break
			burst_left-=1
			# The pause after a burst is drawn only when the burst is over: one
			# draw per burst, as before the roles (seeded scenarios rely on it).
			if burst_left>0:shoot_timer+=float(weapon.data.interval)
			elif role=="mg":shoot_timer+=randf_range(0.35,0.9)
			elif role=="sniper":shoot_timer+=randf_range(1.8,3.4);aim_time=0.6
			else:shoot_timer+=randf_range(0.8,1.7)

func animate_pose(delta: float, moving: bool) -> void:
	pose_serial+=1
	var down := maxf(collapse,tactical_prone)
	var lean_target := peek_side if (not friendly or under_fire_time<=0 or squad_role=="cover") and not blind_fire and not moving and weapon.phase=="" and fmod(peek_clock,4.8)>=2.3 else 0.0
	model.position.x=move_toward(model.position.x,lean_target*0.12,delta*0.65)
	var stride := sin(age*(14 if sprinting else (10 if alerted else 6)))*(0.58 if sprinting else 0.34) if moving else 0.0
	model.position.y=lerpf(-0.065-stance*0.365,0.20,down)
	model.rotation.x=-down*PI*0.5
	model.position.z=down*0.65
	# Changing a collision shape rebuilds it in the physics server: only on real change.
	if absf(down-shape_down)>0.004 or absf(stance-shape_stance)>0.004 or (down!=shape_down and (down==0 or down==1)) or (stance!=shape_stance and (stance==0 or stance==1)):
		shape_down=down
		shape_stance=stance
		shape_dirty=true
		n_shape.rotation.x=down*PI*0.5
		n_capsule.height=lerpf(1.82-stance*0.48,1.82,down)
		n_shape.position=Vector3(0,lerpf(n_capsule.height*0.5,0.32,down),-down*0.22)
	# Wound motion is an absolute, bounded offset, never accumulated per frame.
	lean_roll=move_toward(lean_roll,-lean_target*0.22*(1-down),delta*0.9)
	var flinch := sin(injury_age*17.0)*0.025*exp(-injury_age*3.0) if wound_timer>0 else 0.0
	model.rotation.z=lean_roll+flinch
	for index in range(2):
		var sign_value := 1 if index==0 else -1
		var hip := (0.45+stride*sign_value*0.7) if moving else (PI*0.5 if index==0 else 0.0)
		var knee := (-0.95+absf(stride)*0.5) if moving else -PI*0.5
		var leg_x := lerpf(stride*sign_value,hip,stance)*(1-down)
		var knee_x := lerpf(maxf(0,-stride*sign_value)*1.5,knee,stance)*(1-down)
		if moving and tactical_prone>collapse:
			leg_x+=sin(age*5+sign_value*PI/2)*0.12*tactical_prone
			knee_x-=maxf(0,sin(age*5+sign_value*PI/2))*0.35*tactical_prone
		n_legs[index].rotation.x=leg_x
		n_knees[index].rotation.x=knee_x
		n_feet[index].rotation.x=-leg_x-knee_x
	var rifle: Node3D=n_rifle
	var reload_active := weapon.phase!=""
	var bolt: Node3D=n_bolt
	bolt.position.z=shot_kick*1.5
	if weapon.phase=="rack":bolt.position.z=sin(clampf(weapon.clock/weapon.phase_duration(),0,1)*PI)*0.075
	var aim_pitch := 0.0
	if alerted:aim_pitch=clampf(atan2((target.y+known_height-0.12)-global_position.y-(1.52-0.065-stance*0.365),maxf(1,global_position.distance_to(target))),-0.45,0.45)
	# Up at a drone, steeply.
	if drone_aim!=Vector3.INF:aim_pitch=clampf(atan2(drone_aim.y-global_position.y-(1.52-0.065-stance*0.365),maxf(1,Vector2(drone_aim.x-global_position.x,drone_aim.z-global_position.z).length())),-0.45,1.25)
	rifle.position=Vector3(lerpf(0.14,0.11,aim_weight),1.27+aim_weight*0.25+(0.65 if blind_fire and peek_top else 0),lerpf(-0.28,-0.34,aim_weight))
	if blind_fire and peek_side!=0:rifle.position.x+=peek_side*0.60
	rifle.rotation=Vector3(aim_pitch+shot_kick+recoil_offset.y,recoil_offset.x,-0.35 if reload_active else (-peek_side*0.35 if blind_fire else 0))
	if reload_active:rifle.position.y=1.19
	if arm_wound>=0.5:rifle.position.y=1.04
	if collapse>0:
		rifle.position=rifle.position.lerp(Vector3(0.38,0.85,-0.12),collapse)
		rifle.rotation.x=lerpf(rifle.rotation.x,-PI/2,collapse)
	if tactical_prone>collapse:
		rifle.position=rifle.position.lerp(Vector3(0.14,1.34,-0.16),tactical_prone)
		rifle.rotation.x=lerpf(rifle.rotation.x,PI/2+aim_pitch,tactical_prone)
		# On its bipod the PKM stands on its legs (0.28 m, swung 0.3 rad
		# forward): the hinge 0.26 m above the ground, the bore at 0.31 m;
		# the gunner props himself on his elbows behind it.
		if bipod_open:rifle.position.z=lerpf(rifle.position.z,0.11,tactical_prone)
	# Rotate around the base of the neck, with a slight forward cheek weld.
	# Positive X tips the face upward: cap extension and keep the chin tucked.
	var head: Node3D=n_head
	head.position=Vector3(0.04*aim_weight,1.50-0.07*aim_weight,-0.02*aim_weight)
	head.rotation=Vector3(clampf(aim_pitch*0.55-0.06*aim_weight,-0.28,0.10 if drone_aim==Vector3.INF else 0.6),0,-0.14*aim_weight)
	if tactical_prone>collapse:head.rotation.x=lerpf(head.rotation.x,1.25,tactical_prone)
	# Hands, magazine and dressing are not part of the distant crowd model;
	# the rifle, head and legs above still carry the hitboxes and the muzzle.
	if render_far:return
	var left_target := rifle.position+rifle.basis*Vector3(-0.035,-0.045,-0.265)
	var mag: Node3D=n_mag
	mag.visible=not weapon.magazine.is_empty()
	mag.position=mag.get_meta("rest")
	if reload_active:
		var p := clampf(weapon.clock/weapon.phase_duration(),0,1)
		if weapon.phase=="remove":mag.position.y=float(mag.get_meta("rest").y)-smoothstep(0.3,1,p)*0.38
		if weapon.phase in ["stow","draw"]:
			var pouch := Vector3(-0.115+weapon.pending_slot*0.115,1.12,-0.25)
			var removed := rifle.to_global(Vector3(0,-0.38,-0.05))
			var chest := model.to_global(pouch)
			mag.global_position=removed.lerp(chest,p) if weapon.phase=="stow" else chest.lerp(removed,p)
			mag.visible=p<0.9 if weapon.phase=="stow" else p>0.1
		if weapon.phase=="insert":
			mag.visible=p>0.18
			mag.position.y=float(mag.get_meta("rest").y)-(1-smoothstep(0.18,0.9,p))*0.38
		left_target=model.to_local(mag.to_global(Vector3(0,-0.14,-0.05)))
		if weapon.phase=="rack":left_target=rifle.position+rifle.basis*Vector3(0.07,0.025,0.03+sin(p*PI)*0.07)
	if moving and tactical_prone>0.5 and collapse<0.1:left_target=Vector3(-0.30,1.12+sin(age*5)*0.14,-0.17)
	if arm_wound>=0.5:left_target=Vector3(-0.30,0.85,0.05)
	medical_prop.visible=treatment_time>0
	if treatment_time>0:
		if collapse<0.1:rifle.position.y=0.95
		left_target=Vector3(-0.12,0.84,-0.20)+Vector3(0,0.025*sin(age*8),0)
		medical_prop.position=left_target
	pose_arm("Left",left_target)
	pose_arm("Right",rifle.position+rifle.basis*Vector3(0.012,-0.09,0.085))

func pose_arm(side: String, wrist: Vector3) -> void:
	CharacterArt.pose_arm(model,side,wrist)

# The line of the bore for a point: turned up by the sight set for the
# range, so the round comes down on the point. Inside the direct-fire range
# a soldier keeps his direct-fire setting and aims at the lower edge, which
# comes to the same; beyond it he judges the range by eye (the sniper on the
# PSO-1's rangefinder scale) and sets the sight, and his error is the
# round's. The error is his own for a band of 50 m, not drawn from the
# global RNG (seeded scenarios keep their course).
func sighted(origin: Vector3, point: Vector3, role: String) -> Vector3:
	var line := origin.direction_to(point)
	if absf(line.y)>0.98:return line
	var distance := origin.distance_to(point)
	if distance>FlightModel.direct_fire(weapon.id):
		var judged := float(absi(hash([get_instance_id(),int(distance/50.0)]))%2001)/1000.0-1.0
		distance*=1.0+judged*(0.06 if role=="sniper" else 0.12)
	return line.rotated(line.cross(Vector3.UP).normalized(),FlightModel.aim_angle(weapon.id,distance))

func shoot(player: Node3D, distance: float) -> bool:
	if not concussion.can_fire():return false
	if dead or (friendly and not fire_at_will) or reaction_left>0 or sprinting or wound_timer>0 or treatment_time>0 or collapse>0.01 or arm_wound>=0.5:return false
	var origin: Vector3=n_muzzle.global_position
	var shoulder := global_position+Vector3.UP*lerpf(1.35-stance*0.19,0.36,tactical_prone)
	if blind_fire:
		var elbow := shoulder+(global_basis.x*peek_side*0.65 if peek_side!=0 else Vector3.UP*0.75)
		if not line_clear(shoulder,elbow) or not line_clear(elbow,origin):return false
	elif not line_clear(shoulder,origin):return false
	var end: Vector3=suppress_point
	if sees_player and not blind_fire:
		# Revalidate at shot time: visibility cached by the think tick may be stale.
		var eye: Vector3=n_head.to_global(CharacterArt.EYE+Vector3(0,0,-0.012))
		if not is_instance_valid(player) or (player is Hostile and (player.dead or player.concussion.incapacitated())) or (player is Operator and (player.health<=0 or player.get_meta("battle_out",false))):return false
		var current := Perception.observe(self,player,game,eye)
		if float(current.exposure)<=0:
			sees_player=false
			aim_time=0
			return false
		end=tracked_aim
	elif not (blind_fire or suppressive_fire) or suppress_age>=8:return false
	# Suppression deliberately strikes remembered cover; penetration decides
	# whether the shot passes. Never substitute the hidden player's position.
	if not (blind_fire or suppressive_fire) and not line_clear(origin,end):return false
	var muzzle_forward: Vector3=-n_rifle.global_basis.z
	if muzzle_forward.dot(origin.direction_to(end))<0.72:return false
	if not safe_fire_lane(origin,end):
		if friendly:game.squad.clear_fire_lane(self,origin,end)
		return false
	if not weapon.fire():return false
	since_shot=0
	var role:=kit_id()
	var spread := (0.008+arm_wound*0.025+suppression*0.006) if not blind_fire else 0.10
	# The PSO-1 and a rest: a sniper's round goes where it is laid.
	if role=="sniper" and not blind_fire:spread=0.0018+arm_wound*0.02+suppression*0.003
	spread+=concussion.severity*0.05
	if aim_weight<0.7 or panic_time>0:spread+=0.055
	if suppressive_fire:spread=maxf(spread,0.045 if role!="mg" else 0.022)
	var direction := sighted(origin,end,role)+global_basis.x*recoil_offset.x+Vector3.UP*recoil_offset.y+Vector3(randf_range(-spread,spread),randf_range(-spread,spread),randf_range(-spread,spread))
	game.ballistics.launch(origin,direction.normalized(),weapon.id,68,self)
	game.spatial_shot(weapon.id,origin)
	game.alert_opponents(self,origin)
	game.eject_case(n_rifle.to_global(Vector3(0.04,0.01,0)),n_rifle.global_basis,weapon.id)
	shot_kick=0.045
	# A machine gun on its bipod hardly climbs; held at the hip it does.
	var climb:=float(weapon.data.recoil)*(0.3 if braced() else 1.0)
	recoil_offset+=Vector2(randf_range(-0.008,0.008),climb)*(0.65 if stance>0.5 else 1.0)*(1.8 if blind_fire else 1.0)
	return true

# The PKM down on its bipod: lying, or resting on the cover he fires over.
func braced() -> bool:
	return kit!=null and kit.kind=="mg" and (tactical_prone>0.7 or (has_cover and global_position.distance_to(cover_point)<0.85))

# The PKM's bipod legs: swung down and spread when he rests the gun on them,
# folded back under the barrel otherwise (PkmArt: deployed (0.30, 0, ∓0.22)).
var bipod_open := false
func set_bipod(open: bool) -> void:
	if open==bipod_open:return
	var legs:=n_rifle.get_node_or_null("Bipod")
	if legs==null:return
	bipod_open=open
	for side in [["LegLeft",-1.0],["LegRight",1.0]]:
		var leg:=legs.get_node_or_null(String(side[0])) as Node3D
		if leg!=null:leg.rotation=Vector3(0.30,0,0.22*float(side[1])) if open else Vector3(-PI/2,0,0)

# A machine gunner engaging from the open lies behind the bipod.
func bipod_down(at_cover: bool) -> bool:
	return kit!=null and kit.kind=="mg" and alerted and contact_age<10 and weapon.phase=="" and velocity.length()<0.3 and (not at_cover or cover_requires_prone)

# Drones of the other side in the air, heard (heard_within) or seen in
# front or overhead against the sky: the nearest is noticed after a moment
# (sooner close by), and forgotten three seconds after it is out of sight.
func spot_drone(eye: Vector3, interval: float) -> void:
	var best: ReconDrone=null
	var best_distance := DRONE_SIGHT
	for node in get_tree().get_nodes_in_group("drones"):
		var drone: ReconDrone=node
		if drone.friendly==friendly or not drone.flying():continue
		var at: Vector3=drone.global_position
		var distance := eye.distance_to(at)
		if distance>=best_distance:continue
		var toward := eye.direction_to(at)
		var heard: float=drone.heard_within()
		if distance>heard and (-global_basis.z).dot(toward)<0.3 and toward.y<0.5:continue
		if not line_clear(eye,at) or game.district.foliage_visibility(eye,at)<=0:continue
		best=drone
		best_distance=distance
	if best==null:
		drone_lost+=interval
		if drone_lost>3.0:
			drone_target=null
			drone_notice=0.0
		return
	drone_lost=0.0
	if best!=drone_target:
		drone_target=best
		drone_notice=0.0
	# Heard: noticed in a second or so. Only seen: the smaller it looks the
	# longer (by its apparent area), longer still overhead out of the eyeline.
	var heard_at: float=best.heard_within()
	var rate := 1.1 if best_distance<heard_at else 0.55*pow(35.0/best_distance,2.0)
	if best_distance>=heard_at and (-global_basis.z).dot(eye.direction_to(best.global_position))<0.3:rate*=0.35
	drone_notice=minf(1.5,drone_notice+interval*rate*(1.3 if alerted else 1.0))

func drone_engaged() -> bool:
	return not friendly and is_instance_valid(drone_target) and drone_target.flying() and drone_notice>=1.0 and drone_lost<1.0

# Bursts at the drone once the rifle is up and on it; each burst with its
# own guess of the lead.
func fire_at_drone(delta: float) -> void:
	drone_aim_time+=delta
	if sprinting or drone_aim_time<0.6 or weapon.phase!="" or shoot_timer>0.000001:return
	if burst_left<=0:
		burst_left=randi_range(2,4)
		drone_lead=randf_range(0.5,1.3)
		shoot_timer=0
	while burst_left>0 and shoot_timer<=0.000001:
		if not shoot_drone():
			burst_left=0
			shoot_timer=0.3
			break
		burst_left-=1
		# Short bursts, the sights brought back on it after each.
		shoot_timer+=float(weapon.data.interval) if burst_left>0 else randf_range(1.0,2.2)

func shoot_drone() -> bool:
	if not concussion.can_fire() or dead or reaction_left>0 or sprinting or wound_timer>0 or treatment_time>0 or collapse>0.01 or arm_wound>=0.5:return false
	var origin: Vector3=n_muzzle.global_position
	var shoulder := global_position+Vector3.UP*(1.35-stance*0.19)
	if not line_clear(shoulder,origin) or not line_clear(origin,drone_aim):return false
	var muzzle_forward: Vector3=-n_rifle.global_basis.z
	if muzzle_forward.dot(origin.direction_to(drone_aim))<0.72:return false
	if not safe_fire_lane(origin,drone_aim):return false
	if not weapon.fire():return false
	since_shot=0
	# A small target in the sky, the rifle up steeply off-hand, in a hurry:
	# the aim wanders some 12 mils, more the further it is, more while the
	# rifle swings after a drone crossing the sky (and the lead is a guess,
	# above), more still until it has followed it a while.
	var reach := origin.distance_to(drone_aim)
	var sweep: float=drone_target.velocity.slide(origin.direction_to(drone_aim)).length()/maxf(reach,1.0) if is_instance_valid(drone_target) else 0.0
	var spread := 0.012+0.004*minf(reach,150.0)/30.0+sweep*0.05+suppression*0.006+concussion.severity*0.05+(0.010 if drone_aim_time<2.0 else 0.0)
	var direction := sighted(origin,drone_aim,kit_id())+global_basis.x*recoil_offset.x+Vector3.UP*recoil_offset.y+Vector3(randfn(0.0,spread),randfn(0.0,spread),randfn(0.0,spread))
	game.ballistics.launch(origin,direction.normalized(),weapon.id,68,self)
	game.spatial_shot(weapon.id,origin)
	game.alert_opponents(self,origin)
	game.eject_case(n_rifle.to_global(Vector3(0.04,0.01,0)),n_rifle.global_basis,weapon.id)
	shot_kick=0.045
	recoil_offset+=Vector2(randf_range(-0.008,0.008),0.021)*(0.65 if stance>0.5 else 1.0)
	return true

func receive_hit(amount: float, zone: String, incoming: Vector3, _point: Vector3) -> void:
	if dead:return
	injury_age=0
	if friendly:under_fire_time=6.0
	weapon.cancel()
	last_incoming=incoming
	wound_timer=maxf(wound_timer,3.0 if zone in ["chest","abdomen"] else 2.0)
	treatment_time=0
	treatment_wait=1.5
	burst_left=0
	blind_fire=false
	collapse_time=maxf(collapse_time,6.0)
	aim_time=0
	suppression=3
	bleeding+=2.4 if zone in ["chest","abdomen"] else 0.7
	if zone=="leg":leg_wound=minf(1,leg_wound+0.65)
	if zone=="arm":arm_wound=minf(1,arm_wound+0.6)
	if not alerted:target=global_position-incoming*25
	alerted=true
	contact_age=0
	cover_timer=0
	take_damage(amount)
	if not dead:game.pain_voice(self,amount>=12)

func take_damage(amount: float) -> void:
	if dead:return
	health-=amount
	if health<=0:die()

func receive_blast(amount: float, severity: float, incoming: Vector3) -> void:
	if dead:return
	concussion.apply(severity)
	last_incoming=incoming;injury_age=0
	weapon.cancel();burst_left=0;treatment_time=0;aim_time=0;aim_weight=0
	blind_fire=false;suppressive_fire=false;sees_player=false
	collapse_time=maxf(collapse_time,concussion.acute_left if concussion.active() else 4.0)
	wound_timer=maxf(wound_timer,3.0);suppression=3
	reaction_left=maxf(reaction_left,concussion.acute_left)
	take_damage(amount)
	if not dead:game.pain_voice(self,true)

# Takes a seat in a vehicle: out of sight, out of the physics of the field;
# the vehicle carries him and he cannot be hit through the armour.
func embark(carrier: BmpVehicle) -> void:
	vehicle=carrier
	visible=false
	collision_layer=0
	collision_mask=0
	hitbox_layers.clear()
	for hitbox in hitboxes:
		hitbox_layers.append(hitbox.collision_layer)
		hitbox.collision_layer=0
	velocity=Vector3.ZERO
	has_cover=false
	cover_requires_prone=false
	auto_cover=false
	flank_timer=0
	path=PackedVector2Array()
	path_index=0
	squad_role=""
	sprinting=false
	tactical_prone=0
	stance=0
	burst_left=0
	sees_player=false
	recognition=0

# Shown inside a vehicle on these layers, or hidden with 0; out of it the
# model is back on the world layer.
func show_aboard(mask: int) -> void:
	if mask==ride_layer:return
	ride_layer=mask
	visible=mask!=0
	# His number over the helmet would stand through the roof: hidden aboard.
	for item in model.find_children("*","VisualInstance3D",true,false):
		if item is Label3D:item.layers=0 if mask!=0 else 1
		else:item.layers=mask if mask!=0 else 1

# Steps out of the vehicle onto the ground at a point, facing a direction.
func disembark(point: Vector3, facing: Vector3) -> void:
	show_aboard(0)
	vehicle=null
	visible=true
	collision_layer=4
	collision_mask=1|2|4|64
	for i in range(mini(hitboxes.size(),hitbox_layers.size())):hitboxes[i].collision_layer=hitbox_layers[i]
	global_position=point
	rotation=Vector3(0,atan2(-facing.x,-facing.z),0)
	velocity=Vector3.ZERO
	path_timer=0
	cover_timer=randf()*0.6
	think_timer=randf()*0.3
	lod_accum=0
	shape_dirty=true

func die() -> void:
	if dead:return
	dead=true
	if kit!=null:kit.clear()
	var voice := get_node_or_null("PainVoice") as AudioStreamPlayer3D
	if voice:voice.stop()
	var callout := get_node_or_null("CoverVoice") as AudioStreamPlayer3D
	if callout:callout.stop()
	collision_layer=0
	collision_mask=0
	for hitbox in hitboxes:hitbox.collision_layer=0
	call_deferred("create_corpse")
	if not friendly:game.bot_down()

func create_corpse() -> void:
	if not is_inside_tree() or is_queued_for_deletion():return
	# Killed inside a vehicle: he stays in it, out of sight.
	if has_meta("died_inside") or vehicle!=null:
		visible=false
		return
	var corpse := Corpse.new()
	corpse.name="Corpse"
	add_child(corpse)
	corpse.setup(self,last_incoming)

func apply_wound(wound: Dictionary, zone: String, incoming: Vector3, point: Vector3) -> void:
	if dead:return
	injury_age=0
	treatment_time=0
	treatment_wait=1.5
	plate_integrity=maxf(0,plate_integrity-float(wound.plate_loss))
	last_wound=wound.kind
	var before := bleeding
	if wound.kind=="graze" or wound.kind=="blunt":
		wound_timer=0.35 if wound.kind=="graze" else 1.8
		collapse_time=maxf(collapse_time,4.0 if wound.kind=="graze" else 6.0)
		weapon.cancel()
		burst_left=0
		blind_fire=false
		last_incoming=incoming
		suppression=3
		aim_time=0
		if not alerted:target=global_position-incoming*25
		contact_age=0
		cover_timer=0
		alerted=true
		take_damage(float(wound.damage))
		if not dead:game.pain_voice(self,wound.kind!="graze")
	else:receive_hit(float(wound.damage),zone,incoming,point)
	bleeding=before+float(wound.bleeding)

# Treatment is a real timed action: bleeding continues, new hits interrupt it,
# death and pause cannot complete it, and the finite kit is consumed only on completion.
func update_medical(delta: float) -> bool:
	injury_age+=delta
	treatment_wait=maxf(0,treatment_wait-delta)
	collapse_time=maxf(0,collapse_time-delta)
	var needs_help := bleeding>0.2 or arm_wound>0 or leg_wound>0
	# Stay prone throughout injury, first aid and the initial protective drop.
	# The old arm-hit timer expired before shock/treatment, leaving a kneeling patient.
	var down := collapse_time>0 or wound_timer>0 or treatment_time>0 or needs_help or blood_loss>0.45 or concussion.severity>=0.35 or concussion.acute_left>0
	collapse=move_toward(collapse,1.0 if down else 0.0,delta*4.5)
	if needs_help and medical_kits>0 and treatment_wait<=0 and wound_timer<=0 and concussion.blackout_left<=0 and not concussion.incapacitated():
		# Immobile / heavily bleeding soldiers treat where they fell; mobile ones
		# first try nearby cover, but do not indefinitely ignore a worsening wound.
		var protected := not cover_clear(global_position+Vector3.UP*0.6,target+Vector3.UP*1.5)
		if bleeding>=3 or protected or blood_loss>0.15 or injury_age>5:
			if treatment_time<=0:treatment_time=6.0
	if treatment_time>0:
		treatment_time=maxf(0,treatment_time-delta)
		if treatment_time==0:
			medical_kits-=1
			health=100
			bleeding=0
			blood_loss=0
			arm_wound=0
			leg_wound=0
			collapse_time=0
			shoot_timer=maxf(shoot_timer,1.0)
			path_timer=0
	if down or collapse>0.01 or treatment_time>0 or wound_timer>0:
		state="treating" if treatment_time>0 else "wounded"
		if concussion.active() and treatment_time<=0:state="concussed"
		sprinting=false
		peek_side=0
		peek_top=false
		aim_time=0
		aim_weight=move_toward(aim_weight,0,delta*6)
		blind_fire=false
		stance=move_toward(stance,1,delta*4)
		var crawl := Vector3.ZERO
		if treatment_time<=0 and wound_timer<1 and blood_loss<0.45 and leg_wound<0.9 and arm_wound<0.9 and bleeding<3 and concussion.acute_left<=0 and not concussion.incapacitated():
			if cover_timer<=0:
				find_cover(true)
				if not has_cover:
					path=PackedVector2Array();path_index=0
				elif game.battle.budget("path"):
					path=game.district.path(global_position,cover_point)
					path_index=1 if path.size()>1 else 0
			if has_cover and global_position.distance_to(cover_point)>0.8 and path_index<path.size():
				var waypoint := Vector3(path[path_index].x,global_position.y,path[path_index].y)
				if global_position.distance_to(waypoint)<0.30/game.district.navigation_scale:path_index+=1
				else:crawl=global_position.direction_to(waypoint)
		if crawl.length()>0:
			state="crawl_to_cover"
			rotation.y+=clampf(angle_difference(rotation.y,atan2(-crawl.x,-crawl.z)),-delta,delta)
		var crawl_speed := 0.55*(1-leg_wound*0.7)*(1-arm_wound*0.5)
		crawl_speed*=concussion.movement_multiplier()
		velocity=Vector3(crawl.x*crawl_speed,velocity.y-19*delta,crawl.z*crawl_speed)
		slide(delta)
		animate_pose(delta,crawl.length()>0)
		return true
	return false

func assign_squad(role: String, partner: Hostile) -> void:
	if role=="cover" and squad_role!="cover":game.cover_voice(self)
	squad_partner=partner
	if role=="move" and squad_role!=role:
		# A defender bounds only out of cover that no longer shields him;
		# the cover search decides that, keeping a good position.
		if not defensive:has_cover=false
		cover_timer=0
	squad_role=role

func choose_peek() -> void:
	peek_side=0
	peek_top=false
	var threat := suppress_point if suppress_age<8 else target+Vector3.UP*1.3
	var head := global_position+Vector3.UP*1.25
	for side in [-1.0,1.0]:
		var candidate: Vector3=head+global_basis.x*side*0.48
		if line_clear(head,candidate) and line_clear(candidate,threat) and game.district.foliage_visibility(candidate,threat)>0:
			peek_side=side
			return
	var top := global_position+Vector3.UP*1.80
	if line_clear(head,top) and line_clear(top,threat) and game.district.foliage_visibility(top,threat)>0:peek_top=true

# Both factions use observed anatomy, foliage and lighting. Hidden actors never
# supply a live aim position, even when their entity is still the remembered target.
func select_contact(eye: Vector3) -> Node3D:
	var candidates: Array
	if game.battle.active:
		# Three nearest living opponents, the remembered one and one rotating
		# sample of the rest; a linear pass instead of sorting the whole team.
		var source: Array=game.bots if friendly else game.allies
		var dist: Array[float]=[]
		if not friendly and contact_valid(game.player):keep_nearest(game.player,candidates,dist)
		for actor in source:
			if contact_valid(actor):keep_nearest(actor,candidates,dist)
		if is_instance_valid(combat_target) and not candidates.has(combat_target):candidates.append(combat_target)
		if source.size()>3:
			var extra: Node3D=source[perception_cursor%source.size()]
			perception_cursor+=1
			if contact_valid(extra) and not candidates.has(extra):candidates.append(extra)
	else:candidates=game.bots.duplicate() if friendly else [game.player]+game.allies
	var best: Node3D
	var best_score := -1.0
	var best_observation := {"exposure":0.0,"rate":0.0}
	for actor in candidates:
		if not is_instance_valid(actor) or (actor is Hostile and (actor.dead or actor.vehicle!=null or actor.concussion.incapacitated())) or (actor is Operator and (actor.health<=0 or actor.get_meta("battle_out",false) or game.player_sheltered())):continue
		var center: Vector3=actor.camera.global_position if actor is Operator else actor.n_head.global_position
		if eye.distance_to(center)>220*optic or (-global_basis.z).dot(eye.direction_to(center))<=0.42:continue
		var priority: float=game.squad.contact_priority(self,center) if friendly else 0.0
		if priority<0:continue
		# A sniper looks for the gunners, the grenade launchers and the pilots.
		if optic>1.0 and actor is Hostile and actor.kit_id() in ["mg","rpg7","uav","sniper"]:priority+=12.0
		var seen := Perception.observe(self,actor,game,eye)
		if float(seen.exposure)<=0:continue
		var score := float(seen.rate)+(20.0 if actor==combat_target else 0.0)+priority
		if score>best_score:
			best=actor
			best_score=score
			best_observation=seen
	observation=best_observation
	# Keep identity through occlusion; memory positions are refreshed only on sight.
	var remembered_valid:=is_instance_valid(combat_target)
	if remembered_valid:
		if combat_target is Hostile:remembered_valid=not combat_target.dead and not combat_target.concussion.incapacitated()
		elif combat_target is Operator:remembered_valid=combat_target.health>0 and not combat_target.get_meta("battle_out",false)
	return best if best!=null else (combat_target if remembered_valid else null)

func contact_valid(actor: Node3D) -> bool:
	if not is_instance_valid(actor):return false
	if actor is Hostile:return not actor.dead and actor.vehicle==null
	return not (actor is Operator and (actor.health<=0 or actor.get_meta("battle_out",false)))

func keep_nearest(actor: Node3D, nearest: Array, dist: Array[float]) -> void:
	var d := global_position.distance_squared_to(actor.global_position)
	if nearest.size()<3:
		nearest.append(actor)
		dist.append(d)
		return
	var worst := 0
	if dist[1]>dist[worst]:worst=1
	if dist[2]>dist[worst]:worst=2
	if d>=dist[worst]:return
	nearest[worst]=actor
	dist[worst]=d

func safe_fire_lane(origin: Vector3, endpoint: Vector3) -> bool:
	var friends: Array=[game.player]+game.allies if friendly else game.bots.duplicate()
	for actor in friends:
		if actor==self or not is_instance_valid(actor) or (actor is Hostile and actor.dead):continue
		if actor is Operator and actor.get_meta("battle_out",false):continue
		var center: Vector3=actor.camera.global_position-Vector3.UP*0.45 if actor is Operator else actor.global_position+Vector3.UP*(0.35 if maxf(actor.collapse,actor.tactical_prone)>0.5 else 1.0)
		var along := (center-origin).dot(origin.direction_to(endpoint))
		if along<=0 or along>=origin.distance_to(endpoint):continue
		var margin := 0.65+along*(0.12 if blind_fire else 0.025)
		if Geometry3D.get_closest_point_to_segment(center,origin,endpoint).distance_to(center)<margin:return false
	return true
