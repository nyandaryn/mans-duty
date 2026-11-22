class_name Operator
extends CharacterBody3D

const RADIAL := preload("res://scripts/radial_menu.gd")
# The universal cancel: the key left of 1 (~) or the mouse's back button.
const CANCEL_KEY := KEY_QUOTELEFT
const CANCEL_LABEL := "~"
const HANDLING_FALLBACK := {"ak_bolt_back":"bolt_pull","ak_bolt_release":"bolt","pkm_cover_open":"mag_out","pkm_cover_close":"mag_in","pkm_belt":"mag_out","pkm_bolt_back":"bolt_pull","pkm_handle_forward":"bolt"}

var backpack := BackpackState.new()
var field_rig: FieldRig
var launcher: LauncherRig
var concussion := ConcussionState.new()
var medical_uid := -1
# The ring of choices for 4 / 5, R with the RPG-7, J / Y (RADIAL), and what
# was taken from it last, by group: a tap takes that again.
var radial: RADIAL
var radial_choice := {}
var cancel_notice := ""
var cancel_notice_left := 0.0

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
# Ctrl toggles the crouch: one press to go down, another to stand up.
var crouch_requested := false
var prone := false
var barrel_blocked := false
var prone_requested := false
var prone_surface := Transform3D.IDENTITY
var world_body: OperatorBody
var vault: VaultTraversal
var lean := 0.0
var blind_mode := 0
var leg_injury := 0.0
var arm_injury := 0.0
var bleeding := 0.0
var injury_time := 0.0
# Two individual first-aid kits ride in belt pouches; used ones can be
# replaced from the backpack in the field inventory.
const BELT_MEDKITS := 2
var bandages := BELT_MEDKITS
var bandage_time := 0.0
var recoil_offset := Vector2.ZERO
var recoil_velocity := Vector2.ZERO
var recoil_sequence := 0
var since_shot := 10.0
const MEDICAL_TIME := 6.0
var pain := 0.0
var plate_integrity := 1.0
# The body armour chosen in the loadout (VestKind).
var vest := "korsar"
# The PKM on its bipod (X): lying down or rested on a parapet or a sill; the
# recoil then moves the gun three times less.
var bipod := false
var bipod_shown := false
var bipod_notice := ""
var bipod_notice_left := 0.0
# The PKM's rear sight slider raised for the range (PgUp / PgDn, 1–15): at the
# eye the gun tilts up by that much, the shot leaves along its bore.
var sight_tilt := 0.0
var last_wound := ""
var plates: Array[Area3D]=[]
var blood_loss := 0.0
var symptom_clock := 0.0
var medical_rig: MedicalRig
var arm_areas: Array[Area3D]=[]
var leg_areas: Array[Area3D]=[]
var scope_sight: ScopeSight
var breath_reserve := 1.0
var breath_recovery := 0.0
var holding_breath := false
var scope_fatigue := 0.0
var scope_adjust_time := 0.0
# Standing in a vehicle's hatch: returns the world point where the eyes must
# be. The operator neither walks nor falls nor changes posture there; he
# looks, aims and shoots.
var anchor := Callable()
# Soldiers lying on the ground near him, wounded or prone: he crawls past and
# over them, as over any body on the ground, instead of being caught in a
# ring of them. Standing men still stop him.
var passable: Dictionary = {}

func setup(owner_game: Node3D, primary: String, secondary: String) -> void:
	game = owner_game
	outfit_id=game.player_outfit
	vest=VestKind.valid(game.player_vest)
	weapons = [WeaponState.new(primary),WeaponState.new(secondary)]
	backpack=BackpackState.restore(game.loadout_bag.serialize())
	for weapon in weapons:
		weapon.debug_infinite=game.debug_invulnerable
		weapon.auto_rack=false
	collision_layer=2
	collision_mask=1|4|64
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
	camera.cull_mask=1|ScopeSight.FIRST_PERSON_LAYER
	add_child(camera)
	camera.current=true
	head_area=DamageModel.hitbox(self,self,"head",Vector3.ZERO,Vector3(0.22,0.27,0.23))
	chest_area=DamageModel.hitbox(self,self,"chest",Vector3.ZERO,Vector3(0.39,0.37,0.30))
	abdomen_area=DamageModel.hitbox(self,self,"abdomen",Vector3.ZERO,Vector3(0.34,0.26,0.27))
	for z in [-0.19,0.19]:
		var plate := DamageModel.hitbox(self,self,"plate",Vector3.ZERO,VestKind.plate_box(vest))
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
	ScopeSight.set_first_person(medical_rig)
	Wardrobe.dress(medical_rig,outfit_id,true)
	scope_sight=ScopeSight.new()
	add_child(scope_sight)
	scope_sight.setup(self)
	update_cover(1)
	make_viewmodel()
	field_rig=FieldRig.new()
	camera.add_child(field_rig)
	field_rig.setup(self)
	launcher=LauncherRig.new()
	camera.add_child(launcher)
	launcher.setup(self)
	vault=VaultTraversal.new()
	add_child(vault)
	vault.setup(self)
	world_body=OperatorBody.new()
	add_child(world_body)
	world_body.setup(self)
	var overlay := CanvasLayer.new()
	overlay.name="RadialLayer"
	overlay.layer=2
	add_child(overlay)
	radial=RADIAL.new()
	overlay.add_child(radial)
	radial.setup(self)

func current() -> WeaponState:
	return weapons[slot]

func is_vaulting() -> bool:
	return vault!=null and vault.active

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
	bipod_shown=false
	viewmodel.animate(current(),0)
	ScopeSight.set_first_person(viewmodel)
	scope_sight.attach(viewmodel)

func hip_position() -> Vector3:
	return Vector3(0.17,-0.18,-0.36) if slot==0 else Vector3(0.13,-0.15,-0.48)

func ads_position() -> Vector3:
	if current().id=="svd":return -SvdArt.OCULAR-Vector3(0,0,SvdArt.EYE_RELIEF)
	return Vector3(0,-float(viewmodel.get_meta("sight_height")),-float(viewmodel.get_meta("rear_z"))-float(viewmodel.get_meta("eye_relief")))

func update_pose(delta: float) -> void:
	# The RPG-22's diopter 7 cm off the eye is left to the HUD's blur.
	camera.near=0.09 if launcher.peep_sighted() else 0.025
	ads_weight=move_toward(ads_weight,1.0 if aim else 0.0,delta*5.5)
	gun_kick=move_toward(gun_kick,0,delta*0.17)
	sway=sway.lerp(Vector2.ZERO,minf(delta*8,1))
	viewmodel.animate(current(),delta)
	# Handling sounds of a weapon's own: until a recording exists, the nearest
	# generic one.
	for sound_name in viewmodel.sound_events:game.sound(sound_name if game.sounds.has(sound_name) else HANDLING_FALLBACK.get(sound_name,"bolt"),-10)
	viewmodel.sound_events.clear()
	var movement := minf(Vector2(velocity.x,velocity.z).length(),1)
	var bob := Vector3(sin(step_time/2)*0.003,sin(step_time)*0.003,0)*movement*(1-ads_weight*0.85)
	var resting := hip_position().lerp(ads_position(),smoothstep(0,1,ads_weight))
	viewmodel.position=resting+viewmodel.phase_offset+bob+Vector3(0,0,gun_kick*0.65)
	if blind_mode!=0:
		viewmodel.position=Vector3(0,0.62,-0.07) if blind_mode==2 else Vector3(blind_mode*0.62,-0.10,-0.07)
	if bandage_time>0 or arm_injury>=0.5:viewmodel.position.y-=0.65
	# The rifle is slung while a grenade launcher is in the hands.
	viewmodel.visible=bandage_time<=0 and (field_rig==null or not field_rig.active()) and (launcher==null or not launcher.active())
	medical_rig.animate(bandage_time,MEDICAL_TIME)
	viewmodel.position.y-=switch_delay*0.45
	viewmodel.rotation=viewmodel.phase_rotation+Vector3(gun_kick+sway.y*(1-ads_weight*0.9),sway.x*(1-ads_weight*0.9),-sway.x*0.4)
	if current().id=="svd":
		var stability := (0.25 if prone else (0.60 if crouched else 1.0))*(0.18 if holding_breath else 1.0)
		var amplitude := (0.0015+scope_fatigue*0.003+arm_injury*0.008)*stability
		viewmodel.rotation+=Vector3(sin(symptom_clock*1.9)*amplitude+sin(symptom_clock*7.6)*amplitude*0.14,sin(symptom_clock*1.1)*amplitude*0.55,0)*ads_weight
		if scope_adjust_time>0:
			viewmodel.left_hand.position=viewmodel.left_hand.position.lerp(Vector3(-0.05,0.12,-0.035),minf(delta*16,1))
	sight_tilt=0.0
	if current().id=="pkm":
		var settle := smoothstep(0,1,ads_weight)
		# A 7.5 kg gun held up wanders; on its bipod it barely moves.
		var amplitude := (0.0004 if bipod else (0.0012 if prone else (0.0022 if crouched else 0.0035)))*(1+arm_injury*3)
		viewmodel.rotation+=Vector3(sin(symptom_clock*1.7)*amplitude+sin(symptom_clock*6.1)*amplitude*0.2,sin(symptom_clock*1.05)*amplitude*0.6,0)*ads_weight
		# The slider rises up the frame by the elevation of the range (to the
		# frame's top bar); the eye keeps notch and post in line, so the gun
		# tilts up about the rear sight by the same angle.
		var raised := minf(FlightModel.zero_angle("pkm",PkmArt.SIGHT_HEIGHT,float(current().scope_zero))*PkmArt.SIGHT_RADIUS,0.021)
		var slider := viewmodel.get_node_or_null("RearSightSlider") as Node3D
		if slider!=null:slider.position.y=PkmArt.SIGHT_HEIGHT+raised
		sight_tilt=raised/PkmArt.SIGHT_RADIUS*settle
		viewmodel.rotation.x+=sight_tilt
		viewmodel.position.y-=raised*settle
		if bipod!=bipod_shown:show_bipod(bipod)
	if blind_mode!=0:viewmodel.rotation=Vector3(gun_kick,0,-blind_mode*0.12 if abs(blind_mode)==1 else 0)
	if not aim and ads_weight<0.01 and blind_mode==0 and current().phase=="" and not field_rig.active() and not is_vaulting():
		# Point the held model toward the same scene point as the hip-fire mark.
		# The muzzle lies on the model's -Z axis. Aim that axis from its pivot;
		# rotating around a direction computed at the old muzzle over-converges.
		var point_direction := camera.global_basis.inverse()*point_fire_direction(viewmodel.global_position)
		viewmodel.basis=Basis.looking_at(point_direction,Vector3.UP)*viewmodel.basis
	scope_sight.update()
	if vault!=null:vault.rig.animate()
	if world_body!=null:world_body.update_pose()

func switch_weapon(index: int) -> void:
	if is_vaulting():return
	if index==slot or (field_rig!=null and field_rig.active()) or bandage_time>0:return
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
	# The universal cancel works with the inventory open as well.
	if is_cancel_event(event) and not game.commands_open:
		cancel_action()
		return
	if game.commands_open or game.inventory_open: return
	if is_vaulting():return
	if concussion.blackout_left>0 or concussion.incapacitated():return
	# In the drone Ctrl descends; it never changes the operator's stance there.
	if field_rig.mode!="drone" and not event.is_echo() and not anchor.is_valid():
		if event.is_action_pressed("crouch"):
			# From prone the press brings the operator up to a crouch.
			if prone_requested:
				prone_requested=false
				crouch_requested=true
			else:crouch_requested=not crouch_requested
		elif event.is_action_pressed("sprint") and crouch_requested and not prone_requested:crouch_requested=false
	if radial_input(event):return
	if launcher.active():launcher.handle_input(event);return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_4,KEY_5]:
		if event.physical_keycode==KEY_4:launcher.toggle()
		else:launcher.cycle()
		return
	# Y: an FPV from the pack (in the air the drone takes the key itself).
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_Y and field_rig.mode!="drone":
		field_rig.toggle_fpv()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_J:
		field_rig.toggle_drone()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_U and field_rig.mode!="drone":
		game.drone_feed.toggle()
		return
	if field_rig.mode=="drone":
		field_rig.drone.handle_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F:
		# F again while folding the drone: it stays out.
		if field_rig.mode=="recover_drone":cancel_action()
		elif not field_rig.recover_drone() and not game.grad.interact():game.crew.interact()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_N:
		game.crew.toggle_deploy()
		return
	if field_rig.busy():return
	if event is InputEventKey and event.pressed and not event.echo and current().id=="svd" and aim and current().phase=="" and scope_adjust_time<=0:
		var adjusted := true
		match event.physical_keycode:
			KEY_PAGEUP:current().scope_zero=mini(1000,current().scope_zero+100)
			KEY_PAGEDOWN:current().scope_zero=maxi(100,current().scope_zero-100)
			KEY_BRACKETRIGHT:current().scope_windage=mini(20,current().scope_windage+1)
			KEY_BRACKETLEFT:current().scope_windage=maxi(-20,current().scope_windage-1)
			KEY_L:current().scope_illuminated=not current().scope_illuminated
			_:adjusted=false
		if adjusted:
			scope_adjust_time=0.35
			game.sound("click",-18)
			return
	if event is InputEventKey and event.pressed and not event.echo and current().id=="pkm" and event.physical_keycode==KEY_X:
		toggle_bipod()
		return
	if event is InputEventKey and event.pressed and not event.echo and current().id in WeaponState.SIGHT_RANGES and event.physical_keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
		# The slider of the iron sight (the PKM's frame, the AK-74's tangent
		# leaf, the M16A2's knob), a hundred metres a notch.
		if current().phase=="" and scope_adjust_time<=0 and current().step_sight(event.physical_keycode==KEY_PAGEUP):
			scope_adjust_time=0.35
			game.sound("click",-18)
		return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var aim_scale := 1.0/field_rig.zoom if field_rig.mode=="rangefinder" else 0.22 if aim and current().id=="svd" else (0.65 if aim else 1.0)
		var yaw_delta: float= -event.relative.x*sensitivity*aim_scale
		yaw_delta=wrapf(yaw_delta,-PI,PI)
		if not prone or prone_turn_clear(yaw_delta):rotate_y(yaw_delta)
		pitch=clampf(pitch-event.relative.y*sensitivity*aim_scale,-1.45,1.45)
		sway+=Vector2(-event.relative.x,event.relative.y)*0.00008
		sway=sway.clamp(Vector2(-0.02,-0.02),Vector2(0.02,0.02))
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_K:
		field_rig.toggle_rangefinder()
		return
	if field_rig.active():
		if event.is_action_pressed("fire") and field_rig.mode=="rangefinder":field_rig.measure()
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			field_rig.step_zoom(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1)
		return
	# H again while treating: the kit back in its pouch.
	if event.is_action_pressed("bandage") and not event.is_echo() and bandage_time>0:
		cancel_action()
		return
	if event.is_action_pressed("bandage"):begin_bandage()
	if bandage_time>0:return
	if event.is_action_pressed("reload") and not event.is_echo() and current().inspection_in_hand():
		if arm_injury<0.5 and injury_time<=0 and current().reload(current().inspection_slot if current().inspection_slot>=0 else 0):burst=0
		return
	if event.is_action_pressed("prone") and not event.is_echo() and not anchor.is_valid():prone_requested=not prone_requested
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
	concussion.tick(delta)
	symptom_clock+=delta
	scope_adjust_time=maxf(0,scope_adjust_time-delta)
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
	field_rig.tick(delta)
	launcher.tick(delta)
	update_bipod(delta)
	cancel_notice_left=maxf(0,cancel_notice_left-delta)
	if cancel_notice_left==0:cancel_notice=""
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
			if medical_uid>=0:backpack.remove(medical_uid)
			else:bandages-=1
			medical_uid=-1
	if is_vaulting():
		vault.tick(delta)
		cooldown=maxf(0,cooldown-delta)
		update_pose(delta)
		return
	update_cover(delta)
	if not anchor.is_valid() and Input.is_action_just_pressed("jump") and vault.try_start():
		vault.tick(delta)
		update_pose(delta)
		return
	var sustained: bool=not (game.commands_open or game.inventory_open) and ((current().mode()=="АВТО" and Input.is_action_pressed("fire") and not hands_held()) or burst>0)
	cooldown=cooldown-delta if sustained and firing_sequence_active else maxf(0,cooldown-delta)
	if not sustained:firing_sequence_active=false
	switch_delay=maxf(0,switch_delay-delta)
	aim=not (game.commands_open or game.inventory_open) and Input.is_action_pressed("aim") and not hands_held() and current().phase=="" and switch_delay<=0 and blind_mode==0 and bandage_time<=0 and arm_injury<0.5 and injury_time<=0 and not field_rig.active()
	var crouch := crouched
	if not concussion.can_aim():aim=false
	var aiming_weapon := aim or (launcher.mode=="ready" and Input.is_action_pressed("aim") and not hands_held() and concussion.can_aim())
	var sprint := Input.is_action_pressed("sprint") and not aiming_weapon and not crouch and arm_injury<0.5 and leg_injury<0.5 and pain<0.5
	if concussion.active():sprint=false
	var input := Vector2.ZERO if (game.commands_open or game.inventory_open or anchor.is_valid()) else Input.get_vector("left","right","forward","back")
	# Stepping away calls off hands-on work (deploying, packing, lifting the mortar).
	if field_rig.mode=="work" and input.length()>0.2:field_rig.interrupt_work("СКАСОВАНО")
	var direction := (transform.basis*Vector3(input.x,0,input.y)).normalized()
	var speed := 6.3*Equipment.run_multiplier(carried_mass()) if sprint else 3.8
	if crouch: speed=2.0
	if prone:speed=0.85
	if aiming_weapon: speed=minf(speed,2.4)
	speed*=1-leg_injury*0.65
	if bandage_time>0 or blood_loss>0.65 or field_rig.busy():speed=0
	if field_rig.mode in ["rangefinder","pouch","pouch_stow"]:speed=minf(speed,1.4)
	speed*=concussion.movement_multiplier()
	if injury_time>0:speed*=0.45
	velocity.x=move_toward(velocity.x,direction.x*speed,delta*22)
	velocity.z=move_toward(velocity.z,direction.z*speed,delta*22)
	if anchor.is_valid():velocity=Vector3.ZERO
	elif not is_on_floor(): velocity.y-=19*delta
	elif not (game.commands_open or game.inventory_open) and Input.is_action_just_pressed("jump") and not prone and leg_injury<0.5 and injury_time<=0 and bandage_time<=0 and not field_rig.active() and not concussion.active(): velocity.y=5.2
	else: velocity.y=-0.3
	if anchor.is_valid():global_position+=anchor.call()-camera.global_position
	else:move_and_slide()
	if position.y < (game.district.terrain.minimum-15 if game.district.terrain!=null else -5): take_damage(100)
	var planar_speed := Vector2(velocity.x,velocity.z).length()
	travelled+=planar_speed*delta
	step_time+=delta*planar_speed*2.2
	# Head/body transforms are resolved by update_cover, including collision limits.
	var view_fov := field_rig.view_fov() if field_rig.mode=="rangefinder" else (50.0 if current().id=="svd" else 65.0) if aim else 78.0
	if launcher.mode=="ready":
		# Through the PGO-7 its 13° field fills the circle of the eyepiece.
		var sighted: float=LauncherRig.PGO_FIELD/0.9 if launcher.kind=="rpg7" else (42.0 if launcher.kind=="rpg22" else 60.0)
		view_fov=lerpf(78,sighted,smoothstep(0,1,launcher.ads))
	camera.fov=lerpf(camera.fov,view_fov,minf(delta*12,1))
	camera.far=4000.0 if game.player_class=="grad" and game.battle.active else 700.0 if game.battle.active else 1250.0 if field_rig.mode=="rangefinder" else (850.0 if launcher.active() else (900.0 if game.district.map_id==TrainingRange.ID else 160.0))
	update_breath(delta,sprint and planar_speed>4.5)
	recoil=move_toward(recoil,0,delta*0.12)
	camera.rotation.x=pitch+recoil+recoil_offset.y+sin(symptom_clock*1.8)*blood_loss*0.025+sin(symptom_clock*17)*pain*0.002
	camera.rotation.y=recoil_offset.x+sin(symptom_clock*1.2)*blood_loss*0.025
	camera.rotation.z+=sin(symptom_clock*1.5)*blood_loss*0.035
	camera.rotation+=concussion.view_sway(symptom_clock)
	current().update(delta)
	while current().live_ejections>0:
		game.eject_case(viewmodel.get_node("EjectionPort").global_position,viewmodel.global_basis,current().id,true)
		current().live_ejections-=1
	update_pose(delta)
	barrel_blocked=not weapon_obstruction(true).is_empty()
	update_trigger()

func update_trigger() -> void:
	var automatic := current().mode()=="АВТО" and Input.is_action_pressed("fire") and not hands_held()
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

func update_breath(delta: float, sprinting: bool) -> void:
	scope_fatigue=move_toward(scope_fatigue,1.0 if sprinting else 0.0,delta*(0.23 if sprinting else 0.075))
	breath_recovery=maxf(0,breath_recovery-delta)
	holding_breath=current().id=="svd" and aim and Input.is_action_pressed("sprint") and breath_reserve>0 and breath_recovery<=0 and scope_fatigue<0.75 and Vector2(velocity.x,velocity.z).length()<0.8
	if holding_breath:
		breath_reserve=maxf(0,breath_reserve-delta*0.25)
		if breath_reserve==0:
			breath_recovery=3.0
			scope_fatigue=maxf(scope_fatigue,0.55)
			holding_breath=false
	else:breath_reserve=minf(1,breath_reserve+delta*0.12)

func shoot(preserve_remainder: bool=false) -> bool:
	if not concussion.can_fire():return false
	if is_vaulting():return false
	if (game.commands_open or game.inventory_open) or (field_rig!=null and field_rig.active()):return false
	if cooldown>0.000001 or switch_delay>0 or scope_adjust_time>0 or bandage_time>0 or arm_injury>=0.5 or injury_time>0.4 or blood_loss>0.65: return false
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
	if current().id in WeaponState.SIGHT_RANGES:zero=float(current().scope_zero)
	var sight_height := float(viewmodel.get_meta("sight_height"))
	# Physical bore is below the iron-sight line: the round crosses it at the
	# sight's setting, no target snapping. On «П» (AK-74) the round rises up to
	# about 0.4 m over the line by 220 m: aim at the lower edge of a target.
	var elevation := FlightModel.zero_angle(current().id,sight_height,zero)
	# SVD's bore is physical; its optical reticle moves for elevation/windage.
	if current().id=="svd":elevation=0
	# The PKM is already tilted up by its raised sight.
	elevation-=sight_tilt
	var direction := (-viewmodel.global_basis.z+viewmodel.global_basis.y*elevation).normalized()
	if not aim and blind_mode==0:direction=-viewmodel.global_basis.z
	var spread := 0.0005 if aim else 0.012
	if current().id=="svd" and aim:spread=0.00022
	if current().id=="pkm":spread=(0.0007 if bipod else 0.0016) if aim else (0.006 if bipod else 0.014)
	spread+=arm_injury*0.008+injury_time*0.01
	spread+=concussion.severity*0.04
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
	var braced := 0.33 if bipod else 1.0
	stability*=braced
	var impulse := float(current().data.recoil)*stability*(1+minf(recoil_sequence-1,8)*0.045)
	recoil_velocity+=Vector2(randf_range(-0.35,0.35),1.0)*impulse*33.0
	gun_kick=minf(gun_kick+impulse*1.8,0.18)
	recoil=minf(recoil+float(current().data.recoil)*0.4*braced,0.1)
	pitch=clampf(pitch+float(current().data.recoil)*0.08*braced,-1.45,1.45)
	return true

# --- The PKM's bipod ---------------------------------------------------------------
# A surface under the bipod's hinge within the legs' reach: a parapet, a sill,
# a car's bonnet. Lying down, the ground.
func bipod_support() -> Dictionary:
	if not is_instance_valid(viewmodel):return {}
	var hinge: Vector3=viewmodel.to_global(PkmArt.BIPOD_HINGE)
	var query := PhysicsRayQueryParameters3D.create(hinge+Vector3.UP*0.05,hinge+Vector3.DOWN*0.32,1,[get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func toggle_bipod() -> void:
	if bipod:
		bipod=false
		game.sound("click",-16)
		return
	if Vector2(velocity.x,velocity.z).length()>0.6:
		bipod_notice="СОШКИ: СПЕРШУ ЗУПИНИСЬ";bipod_notice_left=2.0
		return
	if not prone and bipod_support().is_empty():
		bipod_notice="СОШКИ: ЛЯЖ (Z) АБО ПОКЛАДИ КУЛЕМЕТ НА ОПОРУ — БРУСТВЕР, ПІДВІКОННЯ, СТІНКУ";bipod_notice_left=2.5
		return
	bipod=true
	game.sound("click",-14)

# Folded again by moving off, by standing up from it, by another weapon.
func update_bipod(delta: float) -> void:
	bipod_notice_left=maxf(0,bipod_notice_left-delta)
	if not bipod:return
	if current().id!="pkm" or Vector2(velocity.x,velocity.z).length()>0.6 or is_vaulting() or launcher.active() or field_rig.active() or (not prone and bipod_support().is_empty()):
		bipod=false

func show_bipod(open: bool) -> void:
	bipod_shown=open
	var legs := viewmodel.get_node_or_null("Bipod")
	if legs==null:return
	for side in [["LegLeft",-1.0],["LegRight",1.0]]:
		var leg := legs.get_node_or_null(String(side[0])) as Node3D
		if leg!=null:leg.rotation=Vector3(0.30,0,0.22*float(side[1])) if open else Vector3(-PI/2,0,0)

func point_fire_direction(origin: Vector3) -> Vector3:
	# Geometric convergence only: no actor selection and no drop compensation.
	# Projectiles still originate at the physical muzzle and hit intervening cover.
	var forward := -camera.global_basis.z
	var target := camera.global_position+forward*250.0
	var excluded: Array[RID]=[get_rid()]
	for area in [head_area,chest_area,abdomen_area]+plates+arm_areas+leg_areas:excluded.append(area.get_rid())
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,target,1|16,excluded)
	query.collide_with_areas=true;query.hit_from_inside=true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():target=hit.position
	var offset := target-origin
	# Never reverse the shot when the camera sees a surface behind the muzzle.
	return offset.normalized() if offset.dot(forward)>0.05 else forward

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
	if health<=0:
		if is_vaulting():vault.cancel()
		game.finish(false)

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
		if fitted_prone_surface(body_shape.shape,yaw_delta*step/steps)==null:return false
	return true

func fitted_prone_surface(shape: Shape3D, yaw_delta: float=0.0) -> Variant:
	var heading := Basis(Vector3.UP,yaw_delta)*global_basis
	var support := GroundSupport.sample(get_world_3d().direct_space_state,global_position,heading,0.20,-0.12,1.10,[get_rid()])
	if support.is_empty():return null
	var body_frame := Transform3D(heading,global_position)
	var surface: Transform3D=body_frame.affine_inverse()*support.frame
	# Collision motion owns vertical position. Re-anchoring the collider to the
	# world floor each frame would let its parent sink while the shape stayed up.
	surface.origin.y=float(support.roughness)
	for extra in [0.015,0.045,0.085,0.13]:
		var fitted := surface
		fitted.origin.y+=extra
		var pose := fitted*Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0.25,0.48))
		if posture_clear(shape,pose,yaw_delta):return fitted
	return null

func let_through(body: PhysicsBody3D, on: bool) -> void:
	if on:
		add_collision_exception_with(body)
		body.add_collision_exception_with(self)
		passable[body.get_instance_id()]=body.get_rid()
	elif passable.has(body.get_instance_id()):
		passable.erase(body.get_instance_id())
		if is_instance_valid(body):
			remove_collision_exception_with(body)
			body.remove_collision_exception_with(self)

func posture_clear(shape: Shape3D, local_pose: Transform3D, yaw_delta: float=0.0) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	var body_basis := Basis(Vector3.UP,yaw_delta)*global_basis
	query.transform=Transform3D(body_basis,global_position+Vector3.UP*0.035)*local_pose
	query.collision_mask=1|4
	var skip: Array[RID]=[get_rid()]
	skip.append_array(passable.values())
	query.exclude=skip
	query.margin=0.005
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func update_cover(delta: float) -> void:
	if is_vaulting():return
	if field_rig!=null and field_rig.mode=="drone":return
	var disabled_legs := leg_injury>=0.5 or blood_loss>0.45 or concussion.acute_left>0 or concussion.incapacitated()
	if disabled_legs:prone_requested=true
	var requested_crouch := crouch_requested or disabled_legs
	var over := Input.is_action_pressed("peek_up")
	var modifier := Input.is_action_pressed("blind_modifier")
	var height := 0.93 if requested_crouch else 1.65
	if requested_crouch and over and not modifier and not disabled_legs:height=1.46
	var shape := CapsuleShape3D.new()
	shape.radius=0.24 if prone_requested else 0.30
	shape.height=1.75 if prone_requested else height+0.15
	var local_pose := Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0.25,0.48)) if prone_requested else Transform3D(Basis.IDENTITY,Vector3(0,shape.height*0.5,0))
	var surface: Variant=fitted_prone_surface(shape) if prone_requested else Transform3D.IDENTITY
	if prone_requested and surface!=null:local_pose=surface*local_pose
	var rise := 0.0
	if prone and not prone_requested:
		for clearance in [0.0,0.04,0.08,0.12,0.18,0.26]:
			var raised := local_pose
			raised.origin.y+=clearance
			if posture_clear(shape,raised):rise=clearance;break
		local_pose.origin.y+=rise
	# Check the whole horizontal body before lying down or turning, and the
	# full destination height before rising beneath low cover.
	if surface!=null and posture_clear(shape,local_pose):
		body_shape.shape=shape
		body_shape.transform=local_pose
		if rise>0:
			global_position.y+=rise
			body_shape.position.y-=rise
		prone=prone_requested
		prone_surface=surface
	elif prone_requested!=prone:
		prone_requested=prone
	if prone:height=0.40
	elif body_shape.rotation.x==0:height=body_shape.shape.height-0.15
	crouched=height<1.5
	blind_mode=0
	if not prone and modifier and slot==0 and current().phase=="" and arm_injury<0.5 and bandage_time<=0 and not field_rig.active():
		if Input.is_action_pressed("lean_left"):blind_mode=-1
		elif Input.is_action_pressed("lean_right"):blind_mode=1
		elif over:blind_mode=2
	var requested_lean := Input.get_axis("lean_left","lean_right") if blind_mode==0 and not prone else 0.0
	lean=move_toward(lean,requested_lean,delta*3.5)
	var anchor := prone_surface*Vector3(0,height,0) if prone else Vector3(0,height,0)
	var safe := safe_camera_position(anchor,anchor+Vector3(lean*0.36,0,0))
	camera.position=camera.position.lerp(safe,minf(1,delta*(5 if prone else 9)))
	camera.rotation.z=-camera.position.x*0.28
	update_damage_pose(height)

func update_damage_pose(height: float) -> void:
	head_area.position=camera.position+Vector3(0,-0.055,0.035)
	chest_area.rotation=Vector3(PI/2,0,0) if prone else Vector3.ZERO
	chest_area.position=Vector3(0,0.26,0.30) if prone else Vector3(camera.position.x*0.45,height-0.36,0)
	abdomen_area.rotation=Vector3(PI/2,0,0) if prone else Vector3.ZERO
	abdomen_area.position=Vector3(0,0.25,0.62) if prone else Vector3(0,height-0.65,0)
	for i in range(plates.size()):
		var plate := plates[i]
		plate.rotation=Vector3(PI/2,0,0) if prone else Vector3.ZERO
		# Its top at the notch of the breastbone, the top of the chest.
		var lift:=(0.37-VestKind.plate_box(vest).y)*0.5-0.01
		plate.position=Vector3(0,0.10 if i==0 else 0.42,0.30-lift) if prone else chest_area.position+Vector3(0,lift,-0.19 if i==0 else 0.19)
	for i in range(leg_areas.size()):
		var leg := leg_areas[i]
		var leg_height := 0.80 if prone or not crouched else 0.42
		leg.get_child(0).shape.size.y=leg_height
		leg.rotation=Vector3(PI/2,0,0) if prone else Vector3.ZERO
		leg.position=Vector3(-0.13 if i==0 else 0.13,0.20 if prone else leg_height*0.5,1.05 if prone else 0.0)
	for i in range(arm_areas.size()):
		arm_areas[i].rotation=Vector3(PI/2,0,0) if prone else Vector3.ZERO
		arm_areas[i].position=Vector3((-0.27 if i==0 else 0.27)+camera.position.x*0.4,0.25 if prone else height-0.35,-0.06 if prone else -0.10)
	if prone:
		for area in [chest_area,abdomen_area]+plates+arm_areas+leg_areas:
			area.transform=prone_surface*area.transform

func receive_hit(amount: float, zone: String, _incoming: Vector3, _point: Vector3) -> void:
	if game.debug_invulnerable:return
	if is_vaulting():vault.cancel()
	if zone=="leg":leg_injury=minf(1,leg_injury+0.6)
	if zone=="arm":arm_injury=minf(1,arm_injury+0.6)
	bleeding+=2.0 if zone in ["chest","abdomen"] else 0.5
	pain=minf(1,pain+0.65)
	injury_time=3.0 if zone in ["chest","abdomen"] else 2.0
	recoil+=0.035
	bandage_time=0
	if field_rig!=null:field_rig.cancel()
	take_damage(amount)

func apply_wound(wound: Dictionary, zone: String, incoming: Vector3, point: Vector3) -> void:
	if game.debug_invulnerable:return
	current().cancel()
	if field_rig!=null:field_rig.cancel()
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

func needs_bandage() -> bool:
	return health<100 or arm_injury>0 or leg_injury>0 or bleeding>0

func medical_count() -> int:return bandages+backpack.count("medkit")

func carried_mass() -> float:
	var crew_load: float=game.crew.carried_mass() if game!=null and game.crew!=null and game.player==self else 0.0
	return Equipment.carried_mass(weapons,backpack,bandages,vest)+(0.4 if field_rig!=null and is_instance_valid(field_rig.drone) else 0.0)+crew_load

func start_medical(uid: int=-1) -> void:
	if concussion.blackout_left>0 or concussion.incapacitated():return
	if is_vaulting():return
	medical_uid=uid
	current().cancel()
	bandage_time=MEDICAL_TIME
	burst=0

func begin_bandage() -> bool:
	if concussion.blackout_left>0 or concussion.incapacitated() or (launcher!=null and launcher.active()):return false
	if is_vaulting():return false
	if not needs_bandage() or medical_count()<=0 or bandage_time>0 or (field_rig!=null and field_rig.mode!=""):return false
	if is_instance_valid(game.inventory):game.inventory.transfer.cancel()
	current().cancel()
	if bandages<=0:return field_rig.request(backpack.first("medkit"))
	start_medical()
	return true

# --- The ring of choices --------------------------------------------------------
# The fire and aim buttons wait while the ring is up and on the press that
# closed it.
func hands_held() -> bool:return radial!=null and radial.blocks_weapon()

# A key that takes something out of the pack with more than one kind of it
# there: a tap acts at once with the kind taken last, held it opens the ring.
# One kind only, or something already in hand: the key works as before.
func radial_input(event: InputEvent) -> bool:
	if radial==null or not (event is InputEventKey):return false
	if not event.pressed:return radial.release(event.physical_keycode)
	if radial.engaged():return event.physical_keycode==radial.key
	if event.echo:return false
	match event.physical_keycode:
		KEY_4,KEY_5:return launcher_key(event.physical_keycode)
		KEY_R:return round_key(KEY_R)
		KEY_J,KEY_Y:return drone_key(event.physical_keycode)
	return false

func launcher_key(code: int) -> bool:
	var choices := launcher_choices()
	if choices.size()<2:return false
	if launcher.active():
		# In the hands 4 puts it back at once; 5 held — the one to change to.
		if code==KEY_4 or launcher.mode not in ["draw","ready"]:return false
		radial.arm(code,"launcher","ГРАНАТОМЕТ",choices,launcher.kind,radial_pick,func():launcher.cycle())
		return true
	if launcher.busy_reason()!="":return false
	var tap := func():
		if code==KEY_4:launcher.equip(-1,preferred("launcher"))
		else:launcher.cycle()
	radial.arm(code,"launcher","ГРАНАТОМЕТ",choices,preferred("launcher"),radial_pick,tap)
	return true

func round_key(code: int) -> bool:
	if not (launcher.active() and launcher.kind=="rpg7" and launcher.mode=="ready" and not launcher.loaded()):return false
	var choices := round_choices()
	if choices.size()<2:return false
	radial.arm(code,"round","ПОСТРІЛ ДО РПГ-7",choices,preferred("round"),radial_pick,func():launcher.load_round(preferred("round")))
	return true

func drone_key(code: int) -> bool:
	if field_rig.mode!="" or field_rig.active() or launcher.active():return false
	var choices := drone_choices()
	if choices.size()<2:return false
	var tap := func():
		if code==KEY_J:field_rig.toggle_drone()
		else:field_rig.toggle_fpv(preferred("fpv"))
	radial.arm(code,"drone","ДРОН",choices,"recon_drone" if code==KEY_J else preferred("fpv"),radial_pick,tap)
	return true

func launcher_choices() -> Array:
	var list := []
	for which in ["rpg7","rpo_a","rpg22"]:
		var count := backpack.count(which)
		if count<=0:continue
		var entry := backpack.item(backpack.first(which))
		var detail := "ОДНОРАЗОВИЙ"
		if which=="rpg7":detail=(str(LauncherRig.ROUND_TITLE.get(str(entry.get("round","pg7vl")),"ПГ-7ВЛ"))+" У ТРУБІ") if entry.get("loaded",false)==true else "НЕ ЗАРЯДЖЕНО"
		elif which=="rpg22":detail="РОЗКЛАДЕНИЙ" if entry.get("extended",false)==true else "СКЛАДЕНИЙ"
		var in_hands: bool=launcher.active() and launcher.kind==which
		list.append({"id":which,"title":LauncherRig.SHORT[which],"count":count,"detail":"У РУКАХ" if in_hands else detail,"enabled":not in_hands})
	return list

func round_choices() -> Array:
	var list := []
	for which in launcher.rpg7_rounds():
		list.append({"id":which,"title":LauncherRig.ROUND_TITLE[which],"count":backpack.count(which),"detail":LauncherRig.ROUND_KIND.get(which,""),"enabled":true})
	return list

func drone_choices() -> Array:
	var list := []
	var recon := backpack.count("recon_drone")
	var parked := field_rig.recon_parked()
	if recon>0 or parked:
		list.append({"id":"recon_drone","title":"РОЗВІДДРОН","count":recon,"detail":"РОЗКЛАДЕНИЙ · ОКУЛЯРИ" if parked else "РОЗКЛАСТИ","enabled":true})
	for which in Equipment.FPV:
		var count := backpack.count(which)
		if count>0:list.append({"id":which,"title":Equipment.ITEMS[which].short,"count":count,"detail":"КУМУЛЯТИВНИЙ" if which=="fpv_heat" else "ОСКОЛКОВИЙ","enabled":true})
	return list

# The kind a tap takes: the one picked from the ring last, while the pack
# still holds it; otherwise the first in the usual order.
func preferred(group: String) -> String:
	var chosen := str(radial_choice.get(group,""))
	match group:
		"launcher":
			return chosen if chosen!="" and launcher.carried(chosen) else launcher.next_kind()
		"round":
			if chosen!="" and backpack.first(chosen)>=0:return chosen
			var rounds := launcher.rpg7_rounds()
			return str(rounds[0]) if not rounds.is_empty() else ""
		"fpv":
			if chosen!="" and backpack.first(chosen)>=0:return chosen
			var uid := field_rig.first_fpv()
			return str(backpack.item(uid).kind) if uid>=0 else ""
	return chosen

func radial_pick(group: String, id: String) -> void:
	match group:
		"launcher":
			radial_choice["launcher"]=id
			if launcher.active():
				if id!=launcher.kind and launcher.mode in ["draw","ready"]:
					launcher.queued=id
					launcher.stow()
			else:launcher.equip(-1,id)
		"round":
			radial_choice["round"]=id
			launcher.load_round(id)
		"drone":
			if id=="recon_drone":field_rig.toggle_drone()
			else:
				radial_choice["fpv"]=id
				field_rig.toggle_fpv(id)

# --- The universal cancel ---------------------------------------------------------
func is_cancel_event(event: InputEvent) -> bool:
	if event is InputEventKey:return event.pressed and not event.echo and event.physical_keycode==CANCEL_KEY
	if event is InputEventMouseButton:return event.pressed and event.button_index==MOUSE_BUTTON_XBUTTON1
	return false

# What the soldier is doing now that takes time and can be called off ("" —
# nothing).
func timed_action() -> String:
	if launcher.active():
		var short: String=LauncherRig.SHORT[launcher.kind]
		match launcher.mode:
			"draw":return "ЗНЯТТЯ %s З КРІПЛЕННЯ" % short
			"stow":return "ПОВЕРНЕННЯ %s НА КРІПЛЕННЯ" % short
			"load":return "ЗАРЯДЖАННЯ РПГ-7"
			"arm":return "ПЕРЕВЕДЕННЯ РПГ-22 В БОЙОВЕ ПОЛОЖЕННЯ"
			"spent":return "ВІДКИДАННЯ ТРУБИ"
		return ""
	if field_rig.mode!="" or field_rig.transfer().active:
		match field_rig.mode:
			"access":return "ДІСТАВАННЯ З НАПЛІЧНИКА"
			"fpv_place":return "FPV-ДРОН НА ЗЕМЛЮ"
			"goggles":return "НАДЯГАННЯ ОКУЛЯРІВ"
			"recover_drone":return "СКЛАДАННЯ ДРОНА"
			"stow":return "ПОВЕРНЕННЯ В НАПЛІЧНИК"
			"belt":return "АПТЕЧКА В ПІДСУМОК НА ПОЯСІ"
			"pouch":return "ДАЛЕКОМІР З ПІДСУМКА"
			"pouch_stow":return "ДАЛЕКОМІР У ПІДСУМОК"
			"work":return field_rig.work_title
			"":return "ЗАМІНА СТРІЧКИ" if field_rig.transfer().belt else "СПОРЯДЖЕННЯ МАГАЗИНА"
		return ""
	if bandage_time>0:return "АПТЕЧКА"
	if current().phase not in ["","repack"]:return current().status()
	if mortar_relaying():return "ПЕРЕНЕСЕННЯ ДВОНОГИ МІНОМЕТА"
	return ""

func mortar_relaying() -> bool:
	return game.crew!=null and is_instance_valid(game.crew.mortar) and game.crew.mortar.relay_left>0

# The line the HUD shows under a timed action.
func cancel_hint() -> String:
	var what := timed_action()
	if what=="":return ""
	var hands := launcher.active() or field_rig.mode!="" or field_rig.transfer().active
	return CANCEL_LABEL+(" АБО КРОК" if field_rig.mode=="work" else "")+" — СКАСУВАТИ"+("" if hands else " · "+what)

# ~ (or the mouse's back button): whatever takes time stops; nothing is lost
# (see interrupt() in LauncherRig, FieldRig, WeaponState, Mortar).
func cancel_action() -> bool:
	if radial!=null and radial.engaged():
		radial.close()
		return true
	var what := timed_action()
	if what=="":return false
	var done := false
	if launcher.active():done=launcher.interrupt()
	elif field_rig.mode!="" or field_rig.transfer().active:done=field_rig.interrupt()
	elif bandage_time>0:
		# The kit goes back unused: it is spent only when the treatment ends.
		bandage_time=0
		medical_uid=-1
		done=true
	elif current().phase!="":done=current().interrupt()
	elif mortar_relaying():done=game.crew.mortar.cancel_relay()
	if done:
		cancel_notice="СКАСОВАНО: "+what
		cancel_notice_left=2.0
		game.sound("click",-18)
	return done

# Fragments of a burst: what the vest keeps off (BlastSystem.detonate).
func blast_protection(_where: Vector3) -> float:return VestKind.blast_factor(vest)

func receive_blast(amount: float, severity: float, _incoming: Vector3) -> void:
	if game.debug_invulnerable or not game.running:return
	concussion.apply(severity)
	if is_vaulting():vault.cancel()
	field_rig.cancel();current().cancel();bandage_time=0;burst=0
	aim=false;ads_weight=0
	pain=maxf(pain,minf(1,amount/80))
	injury_time=maxf(injury_time,2.0)
	take_damage(amount)
