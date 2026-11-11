class_name Hostile
extends CharacterBody3D

var recognition := 0.0
var observation: Dictionary = {}
var game: Node3D
var model: Node3D
var health := 100.0
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
var flank_point := Vector3.ZERO
var recoil_offset := Vector2.ZERO
var medical_kits := 2
var treatment_time := 0.0
var treatment_wait := 0.0
var collapse := 0.0
var collapse_time := 0.0
var blood_loss := 0.0
var medical_prop: MeshInstance3D

func setup(owner_game: Node3D, spawn: Vector3) -> void:
	game=owner_game
	weapon.debug_infinite=game.debug_invulnerable
	position=spawn
	home=spawn
	target=spawn
	collision_layer=4
	collision_mask=1|2|4
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.30
	capsule.height=1.82
	collision.shape=capsule
	collision.position.y=0.91
	add_child(collision)
	model=Models.soldier(self)
	Wardrobe.dress(model,game.enemy_outfit)
	hitboxes.append(DamageModel.hitbox(self,model.get_node("Head"),"head",Vector3(0,0.18,-0.01),Vector3(0.26,0.35,0.28)))
	hitboxes.append(DamageModel.hitbox(self,model,"chest",Vector3(0,1.29,0),Vector3(0.40,0.36,0.30)))
	hitboxes.append(DamageModel.hitbox(self,model,"abdomen",Vector3(0,1.00,0),Vector3(0.34,0.22,0.28)))
	for z in [-0.19,0.19]:hitboxes.append(DamageModel.hitbox(self,model,"plate",Vector3(0,1.24,z),Vector3(0.32,0.38,0.05)))
	for side in ["Left","Right"]:
		hitboxes.append(DamageModel.limb_hitbox(self,model.get_node(side+"Leg"),"leg",Vector3(0,-0.36,0.015),0.21,true))
		hitboxes.append(DamageModel.limb_hitbox(self,model.get_node(side+"Leg/Knee"),"leg",Vector3(0,-0.36,0),0.16,false))
		hitboxes.append(DamageModel.hitbox(self,model.get_node(side+"Leg/Knee/Foot"),"leg",Vector3(0,-0.02,-0.035),Vector3(0.15,0.16,0.25)))
		hitboxes[-1].set_meta("upper_limb",false)
		var elbow := Vector3(-0.06,-0.24,-0.17) if side=="Left" else Vector3(0.11,-0.24,-0.08)
		hitboxes.append(DamageModel.limb_hitbox(self,model.get_node(side+"Arm"),"arm",elbow,0.17,true))
		var wrist := Vector3(0.39,0.17,-0.32) if side=="Left" else Vector3(-0.19,0.15,-0.18)
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
	think_timer=randf()*0.4
	path_timer=randf()*1.5
	rotation.y=randf()*TAU

func hear(where: Vector3) -> void:
	if dead or global_position.distance_to(where)>180:return
	# A sound gives an approximate bearing, not continuous knowledge through walls.
	if sees_player:return
	var error := clampf(global_position.distance_to(where)*0.08,2.0,9.0)
	pending_contact=where+Vector3(randf_range(-error,error),0,randf_range(-error,error))
	if pending_delay<0:pending_delay=randf_range(0.18,0.65) if not alerted else 0.12

func report_contact(where: Vector3) -> void:
	if dead or sees_player:return
	pending_contact=where
	if pending_delay<0:pending_delay=randf_range(0.4,1.0)

func suppress(source: Vector3, amount: float) -> void:
	if dead:return
	suppression=minf(3.0,suppression+amount)
	if not alerted:
		alerted=true
		target=Vector3(source.x,0,source.z)
		contact_age=0
		cover_timer=0

func line_clear(a: Vector3, b: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()

func find_cover() -> void:
	cover_timer=randf_range(2.5,4.5)
	var best_score := INF
	var best := Vector3.ZERO
	var found := false
	# Sample nearby walkable positions; test protection from the last known threat.
	for radius in [3.0,6.0,10.0,15.0]:
		for i in range(12):
			var angle := float(i)*TAU/12
			var point := global_position+Vector3(cos(angle)*radius,0,sin(angle)*radius)
			point.y=0.1
			var cell := Vector2i(roundi(point.x),roundi(point.z))
			if not game.district.grid.region.has_point(cell) or game.district.grid.is_point_solid(cell):continue
			if line_clear(target+Vector3.UP*1.5,point+Vector3.UP*1.1):continue
			var occupied := false
			for ally in game.bots:
				if ally!=self and not ally.dead and ally.has_cover and ally.cover_point.distance_to(point)<1.8:occupied=true
			if occupied:continue
			var route: PackedVector2Array=game.district.path(global_position,point)
			if route.size()<2:continue
			var score := float(route.size())+point.distance_to(target)*0.05
			if line_clear(point+Vector3.UP*1.65,target+Vector3.UP):score-=4.0
			if score<best_score:
				best_score=score
				best=point
				found=true
	has_cover=found
	if found:
		cover_point=best
		state="seek_cover"
		path_timer=0

func _physics_process(delta: float) -> void:
	if dead or not game.running or game.paused:return
	age+=delta
	no_sight_time+=delta
	flank_timer=maxf(0,flank_timer-delta)
	contact_age+=delta
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
	if update_medical(delta):return
	if pending_delay>=0:
		pending_delay-=delta
		if pending_delay<0:
			alerted=true
			target=pending_contact
			contact_age=0
			cover_timer=0
	weapon.update(delta)
	while weapon.live_ejections>0:
		var rifle: Node3D=model.get_node("CarriedRifle")
		game.eject_case(rifle.to_global(Vector3(0.04,0.01,0)),rifle.global_basis,weapon.id,true)
		weapon.live_ejections-=1
	if weapon.phase!=previous_reload_phase:
		if weapon.phase in ["remove","insert","rack"]:
			game.spatial_shot({"remove":"mag_out","insert":"mag_in","rack":"bolt"}[weapon.phase],global_position+Vector3.UP,-16)
		previous_reload_phase=weapon.phase
	if weapon.rounds()==0 and not weapon.chambered and weapon.phase=="" and (weapon.debug_infinite or weapon.ammunition_total()>0):weapon.reload()
	var player: Operator=game.player
	var distance := global_position.distance_to(player.global_position)
	if think_timer<=0:
		think_timer=0.22+randf()*0.12
		var eye: Vector3=model.get_node("Head").to_global(Vector3(0.047,0.17,-0.126))
		var endpoint := player.camera.global_position
		var toward := eye.direction_to(endpoint)
		var in_view := distance<220 and (alerted or (-global_basis.z).dot(toward)>0.35 or distance<10)
		observation=Perception.observe(self,player,game,eye) if in_view else {"exposure":0.0,"rate":0.0}
		if float(observation.exposure)>0:
			recognition=minf(1,recognition+float(observation.rate)*think_timer*(1.4 if alerted else 1.0))
		else:recognition=maxf(0,recognition-think_timer*0.8)
		sees_player=in_view and float(observation.exposure)>0 and recognition>=(0.3 if sees_player else 1.0)
		if sees_player:
			no_sight_time=0
			if not alerted:shoot_timer=maxf(shoot_timer,0.65)
			alerted=true
			target=player.global_position
			known_height=Vector3(observation.aim_point).y-player.global_position.y+0.12
			contact_age=0
			if radio_timer<=0:
				radio_timer=2.0
				for ally in game.bots:
					if ally!=self and ally.global_position.distance_to(global_position)<85:ally.report_contact(target)
		if alerted and cover_timer<=0 and (flank_timer<=0 or suppression>1.4) and (not has_cover or suppression>0.4 or contact_age>7):find_cover()
	var at_cover := has_cover and global_position.distance_to(cover_point)<0.85
	var reload_active := weapon.phase!=""
	if at_cover and no_sight_time>5 and suppression<1 and not reload_active and health>60:
		var away := (global_position-target).normalized()
		var lateral := Vector3(-away.z,0,away.x)*(1 if get_index()%2==0 else -1)
		var candidate := target+away*12+lateral*9
		var cell: Vector2i=game.district.nearest_cell(Vector2i(roundi(candidate.x),roundi(candidate.z)))
		flank_point=Vector3(cell.x,0.1,cell.y)
		if game.district.path(global_position,flank_point).size()>1:
			has_cover=false
			at_cover=false
			flank_timer=8
			path_timer=0
			cover_timer=8
			no_sight_time=0
	var hide := at_cover and (suppression>1.4 or reload_active or fmod(peek_clock,4.8)<2.3)
	blind_fire=at_cover and hide and suppression>1.8 and contact_age<4 and not reload_active and not line_clear(global_position+Vector3.UP*1.3,target+Vector3.UP*1.5)
	var desired_stance := 1.0 if hide or wound_timer>0 or reload_active or leg_wound>0.6 else 0.0
	if blind_fire:desired_stance=0.7
	stance=move_toward(stance,desired_stance,delta*4)
	var aiming := alerted and not hide and not reload_active and wound_timer<=0 and arm_wound<0.5 and contact_age<8
	aim_weight=move_toward(aim_weight,1.0 if aiming else 0.0,delta*3)
	if aiming and sees_player:aim_time+=delta
	else:aim_time=maxf(0,aim_time-delta*3)
	state="covered" if hide else ("engage" if at_cover else ("seek_cover" if has_cover else ("search" if alerted else "patrol")))
	var destination := cover_point if has_cover else (flank_point if flank_timer>0 else target)
	if flank_timer>0 and not has_cover:state="flank"
	if not alerted and global_position.distance_to(target)<1.4:
		target=home+Vector3(randf_range(-5,5),0,randf_range(-5,5))
		destination=target
	if alerted and not has_cover and sees_player and flank_timer<=0:
		# Change lateral position instead of freezing in the open.
		destination=global_position+global_basis.x*(3 if int(age/3)%2==0 else -3)
	if path_timer<=0:
		path_timer=1.0
		path=game.district.path(global_position,destination)
		path_index=1 if path.size()>1 else 0
	var direction := Vector3.ZERO
	if not at_cover and path_index<path.size() and wound_timer<0.35:
		var waypoint := Vector3(path[path_index].x,position.y,path[path_index].y)
		if position.distance_to(waypoint)<0.5:path_index+=1
		else:direction=position.direction_to(waypoint)
	var speed := (3.2 if alerted else 1.1)*(1-leg_wound*0.65)*(0.55 if arm_wound>=0.5 else 1.0)*(1-stance*0.45)
	velocity.x=direction.x*speed
	velocity.z=direction.z*speed
	velocity.y-=19*delta
	move_and_slide()
	var look := target-position if alerted else direction
	if look.length()>0.1:rotation.y=lerp_angle(rotation.y,atan2(-look.x,-look.z),minf(1,delta*6))
	animate_pose(delta,direction.length()>0.1)
	var ready := sees_player and not hide and aim_time>(0.22 if distance<8 else 0.65+distance*0.004)
	if not (ready or blind_fire) or arm_wound>=0.5 or wound_timer>0 or weapon.phase!="":
		shoot_timer=maxf(0,shoot_timer)
		return
	if shoot_timer<=0.000001:
		if burst_left<=0:
			burst_left=randi_range(2,4) if not blind_fire else randi_range(4,7)
			shoot_timer=0 # No accumulated firing debt from time without a target.
		while burst_left>0 and shoot_timer<=0.000001:
			if not shoot(player,distance):
				burst_left=0
				shoot_timer=0
				break
			burst_left-=1
			shoot_timer+=float(weapon.data.interval) if burst_left>0 else randf_range(0.8,1.7)

func animate_pose(delta: float, moving: bool) -> void:
	var stride := sin(age*(10 if alerted else 6))*0.34 if moving else 0.0
	model.position.y=lerpf(-0.065-stance*0.365,0.20,collapse)
	model.rotation.x=collapse*PI*0.5
	model.rotation.z=sin(wound_timer*17)*minf(wound_timer,0.12)
	for side in ["Left","Right"]:
		var sign_value := 1 if side=="Left" else -1
		var hip := PI*0.5 if side=="Left" else 0.0
		var knee := -PI*0.5
		model.get_node(side+"Leg").rotation.x=lerpf(stride*sign_value,hip,stance)*(1-collapse)
		model.get_node(side+"Leg/Knee").rotation.x=lerpf(maxf(0,-stride*sign_value)*1.5,knee,stance)*(1-collapse)
		model.get_node(side+"Leg/Knee/Foot").rotation.x=-model.get_node(side+"Leg").rotation.x-model.get_node(side+"Leg/Knee").rotation.x
	var rifle: Node3D=model.get_node("CarriedRifle")
	var reload_active := weapon.phase!=""
	var bolt: Node3D=rifle.get_node("Bolt")
	bolt.position.z=shot_kick*1.5
	if weapon.phase=="rack":bolt.position.z=sin(clampf(weapon.clock/weapon.phase_duration(),0,1)*PI)*0.075
	var aim_pitch := 0.0
	if alerted:aim_pitch=clampf(atan2((target.y+known_height-0.12)-global_position.y-(1.52-0.065-stance*0.365),maxf(1,global_position.distance_to(target))),-0.45,0.45)
	rifle.position=Vector3(lerpf(0.14,0.11,aim_weight),1.27+aim_weight*0.25+(0.65 if blind_fire else 0),lerpf(-0.30,-0.42,aim_weight))
	rifle.rotation=Vector3(aim_pitch+shot_kick+recoil_offset.y,recoil_offset.x,-0.35 if reload_active else 0)
	if reload_active:rifle.position.y=1.19
	if arm_wound>=0.5:rifle.position.y=1.04
	if collapse>0:
		rifle.position=rifle.position.lerp(Vector3(0.38,0.85,-0.12),collapse)
		rifle.rotation.x=lerpf(rifle.rotation.x,-PI/2,collapse)
	# Rotate around the base of the neck, with a slight forward cheek weld.
	# Positive X tips the face upward: cap extension and keep the chin tucked.
	var head: Node3D=model.get_node("Head")
	head.position=Vector3(0.04*aim_weight,1.50-0.07*aim_weight,-0.02*aim_weight)
	head.rotation=Vector3(clampf(aim_pitch*0.55-0.06*aim_weight,-0.28,0.10),0,-0.14*aim_weight)
	var left_target := rifle.position+rifle.basis*Vector3(-0.035,-0.045,-0.265)
	var mag: Node3D=rifle.get_node("Magazine")
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
	if arm_wound>=0.5:left_target=Vector3(-0.30,0.85,0.05)
	medical_prop.visible=treatment_time>0
	if treatment_time>0:
		if collapse<0.1:rifle.position.y=0.95
		left_target=Vector3(-0.12,0.84,-0.20)+Vector3(0,0.025*sin(age*8),0)
		medical_prop.position=left_target
	pose_arm("Left",left_target)
	pose_arm("Right",rifle.position+rifle.basis*Vector3(0.012,-0.09,0.085))

func pose_arm(side: String, wrist: Vector3) -> void:
	var arm: Node3D=model.get_node(side+"Arm")
	var forearm: Node3D=arm.get_node("Forearm")
	var shoulder := arm.position
	var rest_elbow := Vector3(0.11,-0.24,-0.08) if side=="Right" else Vector3(-0.06,-0.24,-0.17)
	var rest_forearm := Vector3(-0.19,0.15,-0.18) if side=="Right" else Vector3(0.39,0.17,-0.32)
	var direction := shoulder.direction_to(wrist)
	var length_a := rest_elbow.length()
	var length_b := rest_forearm.length()
	var distance := clampf(shoulder.distance_to(wrist),0.08,length_a+length_b-0.001)
	var along := (length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
	var pole := Vector3(1 if side=="Right" else -1,-1,0.2)
	pole=(pole-direction*pole.dot(direction)).normalized()
	var elbow := shoulder+direction*along+pole*sqrt(maxf(0,length_a*length_a-along*along))
	arm.quaternion=Quaternion(rest_elbow.normalized(),shoulder.direction_to(elbow))
	forearm.position=arm.basis.inverse()*(elbow-shoulder)
	forearm.basis=arm.basis.inverse()*Basis(Quaternion(rest_forearm.normalized(),elbow.direction_to(wrist)))

func shoot(player: Operator, distance: float) -> bool:
	if dead or wound_timer>0 or treatment_time>0 or collapse>0.01 or arm_wound>=0.5:return false
	var origin: Vector3=model.get_node("CarriedRifle/BotMuzzle").global_position
	var shoulder := global_position+Vector3.UP*(1.35-stance*0.19)
	if not line_clear(shoulder,origin):return false
	var end: Vector3=observation.get("aim_point",player.camera.global_position-Vector3.UP*0.12) if sees_player and not blind_fire else target+Vector3.UP*1.15
	# Blind fire is at the last known point, inaccurate, and never through cover.
	if not line_clear(origin,end):return false
	if not weapon.fire():return false
	var spread := (0.008+arm_wound*0.025+suppression*0.006) if not blind_fire else 0.10
	if aim_weight<0.7:spread+=0.055
	var direction := origin.direction_to(end)+global_basis.x*recoil_offset.x+Vector3.UP*recoil_offset.y+Vector3(randf_range(-spread,spread),randf_range(-spread,spread),randf_range(-spread,spread))
	game.ballistics.launch(origin,direction.normalized(),"ak74",68,self)
	game.spatial_shot("ak74",origin)
	var rifle: Node3D=model.get_node("CarriedRifle")
	game.eject_case(rifle.to_global(Vector3(0.04,0.01,0)),rifle.global_basis,"ak74")
	shot_kick=0.045
	recoil_offset+=Vector2(randf_range(-0.008,0.008),0.021)*(0.65 if stance>0.5 else 1.0)*(1.8 if blind_fire else 1.0)
	return true

func receive_hit(amount: float, zone: String, incoming: Vector3, _point: Vector3) -> void:
	if dead:return
	weapon.cancel()
	last_incoming=incoming
	wound_timer=maxf(wound_timer,3.0 if zone in ["chest","abdomen"] else 2.0)
	treatment_time=0
	treatment_wait=1.5
	burst_left=0
	blind_fire=false
	if zone in ["leg","chest","abdomen"]:collapse_time=maxf(collapse_time,4.0)
	if zone=="arm":collapse_time=maxf(collapse_time,1.2)
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

func die() -> void:
	if dead:return
	dead=true
	var voice := get_node_or_null("PainVoice") as AudioStreamPlayer3D
	if voice:voice.stop()
	collision_layer=0
	collision_mask=0
	for hitbox in hitboxes:hitbox.collision_layer=0
	call_deferred("create_corpse")
	game.bot_down()

func create_corpse() -> void:
	if not is_inside_tree() or is_queued_for_deletion():return
	var corpse := Corpse.new()
	corpse.name="Corpse"
	add_child(corpse)
	corpse.setup(self,last_incoming)

func apply_wound(wound: Dictionary, zone: String, incoming: Vector3, point: Vector3) -> void:
	if dead:return
	treatment_time=0
	treatment_wait=1.5
	plate_integrity=maxf(0,plate_integrity-float(wound.plate_loss))
	last_wound=wound.kind
	var before := bleeding
	if wound.kind=="graze" or wound.kind=="blunt":
		wound_timer=0.35 if wound.kind=="graze" else 1.8
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
	treatment_wait=maxf(0,treatment_wait-delta)
	collapse_time=maxf(0,collapse_time-delta)
	var down := collapse_time>0 or leg_wound>=0.5 or blood_loss>0.45
	collapse=move_toward(collapse,1.0 if down else 0.0,delta*3)
	var needs_help := bleeding>0.2 or arm_wound>0 or leg_wound>0
	if needs_help and medical_kits>0 and treatment_wait<=0 and wound_timer<=0:
		# Immobile / heavily bleeding soldiers treat where they fell; mobile ones
		# first try nearby cover, but do not indefinitely ignore a worsening wound.
		var protected := not line_clear(global_position+Vector3.UP*0.6,target+Vector3.UP*1.5)
		if down or bleeding>=3 or protected or blood_loss>0.15:
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
		aim_time=0
		aim_weight=move_toward(aim_weight,0,delta*6)
		blind_fire=false
		stance=move_toward(stance,1,delta*4)
		velocity=Vector3(0,velocity.y-19*delta,0)
		move_and_slide()
		animate_pose(delta,false)
		return true
	return false
