class_name Operator
extends CharacterBody3D

var inspection_combo := false
var outfit_id := "ua_pixel"
var game: Node3D
var camera: Camera3D
var weapons: Array = []
var slot := 0
var health := 100.0
var pitch := 0.0
var cooldown := 0.0
var burst := 0
var firing_sequence_active := false
var aim := false
var recoil := 0.0
var viewmodel: WeaponRig
var muzzle: Marker3D
var flash := 0.0
var step_time := 0.0
var travelled := 0.0
var shots := 0
var hits := 0
var switch_delay := 0.0
var sensitivity := 0.0022
var ads_weight := 0.0
var gun_kick := 0.0
var sway := Vector2.ZERO
var settling := 0.0
var body_shape: CollisionShape3D
var head_area: Area3D
var chest_area: Area3D
var abdomen_area: Area3D
var crouched := false
var prone := false
var barrel_blocked := false
var prone_requested := false
var lean := 0.0
var blind_mode := 0
var leg_injury := 0.0
var arm_injury := 0.0
var bleeding := 0.0
var injury_time := 0.0
var bandages := 2
var bandage_time := 0.0
var recoil_offset := Vector2.ZERO
var recoil_velocity := Vector2.ZERO
var recoil_sequence := 0
var since_shot := 10.0
const MEDICAL_TIME := 6.0
var pain := 0.0
var plate_integrity := 1.0
var last_wound := ""
var plates: Array[Area3D]=[]
var blood_loss := 0.0
var symptom_clock := 0.0
var medical_rig: MedicalRig
var arm_areas: Array[Area3D]=[]
var leg_areas: Array[Area3D]=[]

func setup(owner_game: Node3D, primary: String, secondary: String) -> void:
	game = owner_game
	outfit_id=game.player_outfit
	weapons = [WeaponState.new(primary),WeaponState.new(secondary)]
	for weapon in weapons:weapon.debug_infinite=game.debug_invulnerable
	collision_layer=2
	collision_mask=1|4
	var shape := CapsuleShape3D.new()
	shape.radius=0.3
	shape.height=1.8
	var collision := CollisionShape3D.new()
	collision.shape=shape
	body_shape=collision
	collision.position.y=0.9
	add_child(collision)
	camera=Camera3D.new()
	camera.position.y=1.65
	camera.near=0.025
	camera.far=160
	camera.fov=78
	add_child(camera)
	camera.current=true
	head_area=DamageModel.hitbox(self,self,"head",Vector3.ZERO,Vector3(0.22,0.27,0.23))
	chest_area=DamageModel.hitbox(self,self,"chest",Vector3.ZERO,Vector3(0.39,0.37,0.30))
	abdomen_area=DamageModel.hitbox(self,self,"abdomen",Vector3.ZERO,Vector3(0.34,0.26,0.27))
	for z in [-0.19,0.19]:
		var plate := DamageModel.hitbox(self,self,"plate",Vector3.ZERO,Vector3(0.32,0.37,0.05))
		plate.position.z=z
		plates.append(plate)
	for x in [-0.13,0.13]:
		var leg := DamageModel.hitbox(self,self,"leg",Vector3.ZERO,Vector3(0.18,0.80,0.22))
		leg.position=Vector3(x,0.45,0)
		leg_areas.append(leg)
	for x in [-0.27,0.27]:
		var arm := DamageModel.hitbox(self,self,"arm",Vector3.ZERO,Vector3(0.15,0.37,0.21))
		arm.position=Vector3(x,1.3,-0.10)
		arm_areas.append(arm)
	medical_rig=MedicalRig.new()
	camera.add_child(medical_rig)
	Wardrobe.dress(medical_rig,outfit_id,true)
	update_cover(1)
	make_viewmodel()

func current() -> WeaponState:
	return weapons[slot]

func make_viewmodel() -> void:
	if is_instance_valid(viewmodel):
		camera.remove_child(viewmodel)
		viewmodel.queue_free()
	viewmodel=Models.weapon(current().id) as WeaponRig
	camera.add_child(viewmodel)
	Wardrobe.dress(viewmodel,outfit_id,true)
	muzzle=viewmodel.get_node("Muzzle")
	viewmodel.position=hip_position()
	ads_weight=0
	gun_kick=0
	viewmodel.animate(current(),0)

func hip_position() -> Vector3:
	return Vector3(0.17,-0.18,-0.36) if slot==0 else Vector3(0.13,-0.15,-0.48)

func ads_position() -> Vector3:
	return Vector3(0,-float(viewmodel.get_meta("sight_height")),-float(viewmodel.get_meta("rear_z"))-float(viewmodel.get_meta("eye_relief")))

func update_pose(delta: float) -> void:
	ads_weight=move_toward(ads_weight,1.0 if aim else 0.0,delta*5.5)
	gun_kick=move_toward(gun_kick,0,delta*0.17)
	sway=sway.lerp(Vector2.ZERO,minf(delta*8,1))
	viewmodel.animate(current(),delta)
	for sound_name in viewmodel.sound_events:game.sound(sound_name,-10)
	viewmodel.sound_events.clear()
	var movement := minf(Vector2(velocity.x,velocity.z).length(),1)
	var bob := Vector3(sin(step_time/2)*0.003,sin(step_time)*0.003,0)*movement*(1-ads_weight*0.85)
	var resting := hip_position().lerp(ads_position(),smoothstep(0,1,ads_weight))
	viewmodel.position=resting+viewmodel.phase_offset+bob+Vector3(0,0,gun_kick*0.65)
	if blind_mode!=0:
		viewmodel.position=Vector3(0,0.62,-0.07) if blind_mode==2 else Vector3(blind_mode*0.62,-0.10,-0.07)
	if bandage_time>0 or arm_injury>=0.5:viewmodel.position.y-=0.65
	viewmodel.visible=bandage_time<=0
	medical_rig.animate(bandage_time,MEDICAL_TIME)
	viewmodel.position.y-=switch_delay*0.45
	viewmodel.rotation=viewmodel.phase_rotation+Vector3(gun_kick+sway.y*(1-ads_weight*0.9),sway.x*(1-ads_weight*0.9),-sway.x*0.4)
	if blind_mode!=0:viewmodel.rotation=Vector3(gun_kick,0,-blind_mode*0.12 if abs(blind_mode)==1 else 0)

func switch_weapon(index: int) -> void:
	if index==slot: return
	current().cancel()
	slot=index
	burst=0
	firing_sequence_active=false
	cooldown=0.35
	switch_delay=0.35
	make_viewmodel()
	game.sound("click",-15)

func _unhandled_input(event: InputEvent) -> void:
	if not game.running or game.paused: return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var yaw_delta: float= -event.relative.x*sensitivity*(0.65 if aim else 1.0)
		yaw_delta=wrapf(yaw_delta,-PI,PI)
		if not prone or prone_turn_clear(yaw_delta):rotate_y(yaw_delta)
		pitch=clampf(pitch-event.relative.y*sensitivity*(0.65 if aim else 1.0),-1.45,1.45)
		sway+=Vector2(-event.relative.x,event.relative.y)*0.00008
		sway=sway.clamp(Vector2(-0.02,-0.02),Vector2(0.02,0.02))
	if event.is_action_pressed("bandage") and (health<100 or arm_injury>0 or leg_injury>0 or bleeding>0) and bandages>0 and bandage_time<=0:
		current().cancel()
		bandage_time=MEDICAL_TIME
		burst=0
	if bandage_time>0:return
	if event.is_action_pressed("reload") and not event.is_echo() and current().inspection_in_hand():
		if arm_injury<0.5 and injury_time<=0 and current().reload(current().inspection_slot if current().inspection_slot>=0 else 0):burst=0
		return
	if event.is_action_pressed("prone") and not event.is_echo():prone_requested=not prone_requested
	if event.is_action_pressed("inspect_mag") and not event.is_echo():inspection_combo=false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
		var pouch := int(event.physical_keycode)-KEY_1
		if Input.is_action_pressed("reload"):
			if arm_injury<0.5 and injury_time<=0 and current().reload(pouch):burst=0
			return
		if Input.is_action_pressed("inspect_mag"):
			inspection_combo=true
			if arm_injury<0.5 and injury_time<=0:current().inspect_magazine(pouch)
			return
	if event.is_action_released("inspect_mag") and not inspection_combo and arm_injury<0.5:current().inspect_magazine()
	if event.is_action_pressed("inspect_chamber") and arm_injury<0.5:current().inspect_chamber()
	if event.is_action_pressed("primary"):switch_weapon(0)
	if event.is_action_pressed("secondary"):switch_weapon(1)
	if event.is_action_pressed("rack") and arm_injury<0.5:
		if current().rack(): burst=0
	if event.is_action_pressed("mode"):
		current().cycle_mode()
		burst=0
		game.sound("click",-16)
	if event.is_action_pressed("fire"):
		if current().mode()=="3 ПОСТРІЛИ" and burst==0 and cooldown<=0 and current().phase=="": burst=3
		elif current().mode()=="ОДИН": shoot()

func _physics_process(delta: float) -> void:
	if not game.running or game.paused: return
	symptom_clock+=delta
	pain=move_toward(pain,maxf(arm_injury,leg_injury)*0.45,delta*0.045)
	since_shot+=delta
	if since_shot>0.35:recoil_sequence=0
	recoil_velocity-=recoil_offset*100.0*delta
	recoil_velocity*=exp(-15.0*delta)
	recoil_offset+=recoil_velocity*delta
	injury_time=maxf(0,injury_time-delta)
	if bleeding>0 and not game.debug_invulnerable:
		blood_loss=minf(1,blood_loss+bleeding*delta*0.012)
		health=maxf(0,health-bleeding*delta)
		if health<=0:
			game.finish(false)
			return
	if bandage_time>0:
		bandage_time=maxf(0,bandage_time-delta)
		if bandage_time==0:
			bleeding=0
			blood_loss=0
			pain=0
			arm_injury=0
			leg_injury=0
			injury_time=0
			health=100
			bandages-=1
	update_cover(delta)
	var sustained := (current().mode()=="АВТО" and Input.is_action_pressed("fire")) or burst>0
	cooldown=cooldown-delta if sustained and firing_sequence_active else maxf(0,cooldown-delta)
	if not sustained:firing_sequence_active=false
	switch_delay=maxf(0,switch_delay-delta)
	aim=Input.is_action_pressed("aim") and current().phase=="" and switch_delay<=0 and blind_mode==0 and bandage_time<=0 and arm_injury<0.5 and injury_time<=0
	var crouch := crouched
	var sprint := Input.is_action_pressed("sprint") and not aim and not crouch and arm_injury<0.5 and leg_injury<0.5 and pain<0.5
	var input := Input.get_vector("left","right","forward","back")
	var direction := (transform.basis*Vector3(input.x,0,input.y)).normalized()
	var speed := 6.3 if sprint else 3.8
	if crouch: speed=2.0
	if prone:speed=0.85
	if aim: speed=minf(speed,2.4)
	speed*=1-leg_injury*0.65
	if bandage_time>0 or blood_loss>0.65:speed=0
	if injury_time>0:speed*=0.45
	velocity.x=move_toward(velocity.x,direction.x*speed,delta*22)
	velocity.z=move_toward(velocity.z,direction.z*speed,delta*22)
	if not is_on_floor(): velocity.y-=19*delta
	elif Input.is_action_just_pressed("jump") and not prone and leg_injury<0.5 and injury_time<=0 and bandage_time<=0: velocity.y=5.2
	else: velocity.y=-0.3
	move_and_slide()
	if position.y < -5: take_damage(100)
	var planar_speed := Vector2(velocity.x,velocity.z).length()
	travelled+=planar_speed*delta
	step_time+=delta*planar_speed*2.2
	# Head/body transforms are resolved by update_cover, including collision limits.
	camera.fov=lerpf(camera.fov,65.0 if aim else 78.0,minf(delta*12,1))
	recoil=move_toward(recoil,0,delta*0.12)
	camera.rotation.x=pitch+recoil+recoil_offset.y+sin(symptom_clock*1.8)*blood_loss*0.025+sin(symptom_clock*17)*pain*0.002
	camera.rotation.y=recoil_offset.x+sin(symptom_clock*1.2)*blood_loss*0.025
	camera.rotation.z+=sin(symptom_clock*1.5)*blood_loss*0.035
	current().update(delta)
	while current().live_ejections>0:
		game.eject_case(viewmodel.get_node("EjectionPort").global_position,viewmodel.global_basis,current().id,true)
		current().live_ejections-=1
	update_pose(delta)
	barrel_blocked=not weapon_obstruction(true).is_empty()
	update_trigger()

func update_trigger() -> void:
	var automatic := current().mode()=="АВТО" and Input.is_action_pressed("fire")
	var emitted := 0
	while (automatic or burst>0) and cooldown<=0.000001 and emitted<8:
		if not shoot(true):
			burst=0
			firing_sequence_active=false
			cooldown=maxf(0,cooldown)
			break
		firing_sequence_active=true
		emitted+=1
		if burst>0:burst-=1

func shoot(preserve_remainder: bool=false) -> bool:
	if cooldown>0.000001 or switch_delay>0 or bandage_time>0 or arm_injury>=0.5 or injury_time>0.4 or blood_loss>0.65: return false
	if not current().fire():
		if current().phase=="":
			game.sound("click",-15)
			cooldown=0.2
		return false
	cooldown=(minf(cooldown,0) if preserve_remainder else 0.0)+float(current().data.interval)
	shots+=1
	viewmodel.fired()
	game.sound(current().id,-5)
	game.alert_bots(global_position)
	var profile: Dictionary=Ballistics.PROFILES[current().id]
	var zero := float(profile.zero)
	var speed := float(profile.speed)
	var sight_height := float(viewmodel.get_meta("sight_height"))
	# Physical bore is below the iron-sight line. Fixed zero, no target snapping.
	var elevation := sight_height/zero+9.81*zero/(2*speed*speed)
	var direction := (-viewmodel.global_basis.z+viewmodel.global_basis.y*elevation).normalized()
	var spread := 0.0005 if aim else 0.012
	spread+=arm_injury*0.008+injury_time*0.01
	if blind_mode!=0:spread=0.075
	if Vector2(velocity.x,velocity.z).length()>1: spread*=2.5
	direction=(direction+viewmodel.global_basis.x*randf_range(-spread,spread)+viewmodel.global_basis.y*randf_range(-spread,spread)).normalized()
	var muzzle_pos := muzzle.global_position
	var cover := weapon_obstruction()
	barrel_blocked=not cover.is_empty()
	if not cover.is_empty():
		game.impact(cover.position,cover.normal)
	else:
		game.ballistics.launch(muzzle_pos,direction,current().id,float(current().data.damage),self)
	game.eject_case(viewmodel.get_node("EjectionPort").global_position,viewmodel.global_basis,current().id)
	since_shot=0
	recoil_sequence+=1
	var stability := (0.78 if aim else 1.1)*(0.50 if prone else (0.73 if crouched else 1.0))*(1.7 if blind_mode!=0 else 1.0)
	if Vector2(velocity.x,velocity.z).length()>1:stability*=1.25
	var impulse := float(current().data.recoil)*stability*(1+minf(recoil_sequence-1,8)*0.045)
	recoil_velocity+=Vector2(randf_range(-0.35,0.35),1.0)*impulse*33.0
	gun_kick=minf(gun_kick+impulse*1.8,0.18)
	recoil=minf(recoil+float(current().data.recoil)*0.4,0.1)
	pitch=clampf(pitch+float(current().data.recoil)*0.08,-1.45,1.45)
	return true

func weapon_obstruction(look_ahead: bool=false) -> Dictionary:
	if not is_instance_valid(viewmodel) or not is_instance_valid(muzzle):return {}
	var receiver := viewmodel.global_position
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,receiver,1,[get_rid()])
	query.hit_from_inside=true
	var cover := get_world_3d().direct_space_state.intersect_ray(query)
	if cover.is_empty():
		query.from=receiver
		query.to=muzzle.global_position
		cover=get_world_3d().direct_space_state.intersect_ray(query)
	if cover.is_empty() and look_ahead:
		query.from=muzzle.global_position
		query.to=query.from-viewmodel.global_basis.z*0.6
		cover=get_world_3d().direct_space_state.intersect_ray(query)
	return cover

func take_damage(amount: float) -> void:
	if not game.running or game.debug_invulnerable: return
	health=maxf(0,health-amount)
	game.damage_flash=0.6
	game.sound("hurt",-14)
	if health>0:game.pain_voice(self,amount>=12)
	if health<=0: game.finish(false)

func safe_camera_position(anchor: Vector3, desired: Vector3) -> Vector3:
	var shape := SphereShape3D.new()
	shape.radius=0.10
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,to_global(anchor))
	query.motion=to_global(desired)-to_global(anchor)
	query.collision_mask=1
	query.margin=0.025
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	return anchor.lerp(desired,maxf(0,fractions[0]-0.02)) if not fractions.is_empty() else anchor

func prone_turn_clear(yaw_delta: float) -> bool:
	var steps := maxi(1,ceili(absf(yaw_delta)/0.04))
	for step in range(1,steps+1):
		if not posture_clear(body_shape.shape,body_shape.transform,yaw_delta*step/steps):return false
	return true

func posture_clear(shape: Shape3D, local_pose: Transform3D, yaw_delta: float=0.0) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	var body_basis := Basis(Vector3.UP,yaw_delta)*global_basis
	query.transform=Transform3D(body_basis,global_position+Vector3.UP*0.035)*local_pose
	query.collision_mask=1|4
	query.exclude=[get_rid()]
	query.margin=0.005
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func update_cover(delta: float) -> void:
	var disabled_legs := leg_injury>=0.5 or blood_loss>0.45
	if disabled_legs:prone_requested=true
	var requested_crouch := Input.is_action_pressed("crouch") or disabled_legs
	var over := Input.is_action_pressed("peek_up")
	var modifier := Input.is_action_pressed("blind_modifier")
	var height := 0.93 if requested_crouch else 1.65
	if requested_crouch and over and not modifier and not disabled_legs:height=1.46
	var shape := CapsuleShape3D.new()
	shape.radius=0.24 if prone_requested else 0.30
	shape.height=1.75 if prone_requested else height+0.15
	var local_pose := Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0.25,0.48)) if prone_requested else Transform3D(Basis.IDENTITY,Vector3(0,shape.height*0.5,0))
	# Check the whole horizontal body before lying down or turning, and the
	# full destination height before rising beneath low cover.
	if posture_clear(shape,local_pose):
		body_shape.shape=shape
		body_shape.transform=local_pose
		prone=prone_requested
	elif prone_requested!=prone:
		prone_requested=prone
	if prone:height=0.40
	elif body_shape.rotation.x==0:height=body_shape.shape.height-0.15
	crouched=height<1.5
	blind_mode=0
	if not prone and modifier and slot==0 and current().phase=="" and arm_injury<0.5 and bandage_time<=0:
		if Input.is_action_pressed("lean_left"):blind_mode=-1
		elif Input.is_action_pressed("lean_right"):blind_mode=1
		elif over:blind_mode=2
	var requested_lean := Input.get_axis("lean_left","lean_right") if blind_mode==0 and not prone else 0.0
	lean=move_toward(lean,requested_lean,delta*3.5)
	var anchor := Vector3(0,height,0)
	var safe := safe_camera_position(anchor,anchor+Vector3(lean*0.36,0,0))
	camera.position=camera.position.lerp(safe,minf(1,delta*(5 if prone else 9)))
	camera.rotation.z=-camera.position.x*0.28
	head_area.position=camera.position+Vector3(0,-0.055,0.035)
	chest_area.rotation.x=PI/2 if prone else 0.0
	chest_area.position=Vector3(0,0.26,0.30) if prone else Vector3(camera.position.x*0.45,height-0.36,0)
	abdomen_area.rotation.x=PI/2 if prone else 0.0
	abdomen_area.position=Vector3(0,0.25,0.62) if prone else Vector3(0,height-0.65,0)
	for i in range(plates.size()):
		var plate := plates[i]
		plate.rotation.x=PI/2 if prone else 0.0
		plate.position=Vector3(0,0.10 if i==0 else 0.42,0.30) if prone else chest_area.position+Vector3(0,0,-0.19 if i==0 else 0.19)
	for i in range(leg_areas.size()):
		var leg := leg_areas[i]
		var leg_height := 0.80 if prone or not crouched else 0.42
		leg.get_child(0).shape.size.y=leg_height
		leg.rotation.x=PI/2 if prone else 0.0
		leg.position=Vector3(-0.13 if i==0 else 0.13,0.20 if prone else leg_height*0.5,1.05 if prone else 0.0)
	for i in range(arm_areas.size()):
		arm_areas[i].rotation.x=PI/2 if prone else 0.0
		arm_areas[i].position=Vector3((-0.27 if i==0 else 0.27)+camera.position.x*0.4,0.25 if prone else height-0.35,-0.06 if prone else -0.10)

func receive_hit(amount: float, zone: String, _incoming: Vector3, _point: Vector3) -> void:
	if game.debug_invulnerable:return
	if zone=="leg":leg_injury=minf(1,leg_injury+0.6)
	if zone=="arm":arm_injury=minf(1,arm_injury+0.6)
	bleeding+=2.0 if zone in ["chest","abdomen"] else 0.5
	pain=minf(1,pain+0.65)
	injury_time=3.0 if zone in ["chest","abdomen"] else 2.0
	recoil+=0.035
	bandage_time=0
	take_damage(amount)

func apply_wound(wound: Dictionary, zone: String, incoming: Vector3, point: Vector3) -> void:
	if game.debug_invulnerable:return
	current().cancel()
	plate_integrity=maxf(0,plate_integrity-float(wound.plate_loss))
	last_wound=wound.kind
	var before := bleeding
	if wound.kind=="graze" or wound.kind=="blunt":
		pain=minf(1,pain+float(wound.pain))
		injury_time=0.35 if wound.kind=="graze" else 1.8
		bandage_time=0
		take_damage(float(wound.damage))
	else:receive_hit(float(wound.damage),zone,incoming,point)
	bleeding=before+float(wound.bleeding)
