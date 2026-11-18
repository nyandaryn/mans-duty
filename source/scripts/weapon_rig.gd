class_name WeaponRig
extends Node3D

var inspection_mag: Node3D
var chamber_round: Node3D
var chamber_window: Node3D
var weapon_id := "ak74"
var magazine: Node3D
var bolt: Node3D
var left_hand: Node3D
var charging_handle: Node3D
var flash_node: MeshInstance3D
var phase_offset := Vector3.ZERO
var phase_rotation := Vector3.ZERO
var previous_phase := ""
var previous_progress := 0.0
var slide_kick := 0.0
var flash_time := 0.0
var sound_events: Array[String] = []

func configure(id: String) -> void:
	weapon_id=id
	magazine=get_node("Magazine")
	MagazineView.decorate(magazine,id)
	inspection_mag=magazine.duplicate() as Node3D
	inspection_mag.name="InspectionMagazine"
	inspection_mag.visible=false
	add_child(inspection_mag)
	var port := Vector3(0.016,0.022,-0.015) if id in ["pm","m9"] else Vector3(0.035,0.009,-0.025)
	chamber_window=Models.bevel(self,port,Vector3(0.002,0.014,0.022),"gun_recess",0.001)
	chamber_round=Models.group(self,"ChamberEvidence",port+Vector3(0.002,0,0))
	Models.tube(chamber_round,Vector3.ZERO,0.004,0.016,"brass",Vector3.FORWARD)
	chamber_round.visible=false
	chamber_window.visible=false
	bolt=get_node("Bolt")
	left_hand=get_node("LeftHand")
	charging_handle=get_node_or_null("ChargingHandle")
	# Brief gas flash at the muzzle, never a visible projectile or a beam.
	var mesh := SphereMesh.new()
	mesh.radius=0.012
	mesh.height=0.038
	mesh.radial_segments=8
	mesh.rings=3
	flash_node=MeshInstance3D.new()
	flash_node.mesh=mesh
	flash_node.position=get_node("Muzzle").position+Vector3(0,0,-0.015)
	flash_node.rotation.x=PI/2
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(1,0.68,0.25,0.6)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_node.material_override=material
	flash_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_node.visible=false
	add_child(flash_node)

func fired() -> void:
	slide_kick=1.0
	flash_time=0.018

func phase_sound(threshold: float, progress: float, sound_name: String) -> void:
	if previous_progress<threshold and progress>=threshold:sound_events.append(sound_name)

func animate(state: WeaponState, delta: float) -> void:
	var phase := state.phase
	var p := clampf(state.clock/state.phase_duration(),0,1) if phase!="" else 0.0
	if phase!=previous_phase:
		previous_progress=-0.001
		previous_phase=phase
	var offset := Vector3.ZERO
	var angles := Vector3.ZERO
	var hand_target: Vector3=get_meta("left_rest")
	var hand_rotation: Vector3=get_meta("left_rotation")
	var mag_offset := Vector3.ZERO
	var mag_rotation := Vector3.ZERO
	var pistol := weapon_id in ["pm","m9"]
	var well: Vector3=get_meta("magwell")
	magazine.visible=not state.magazine.is_empty()
	inspection_mag.visible=false
	chamber_round.visible=false
	chamber_window.visible=false
	var evidence_rounds := state.rounds()
	if phase=="stow":evidence_rounds=int(state.held_old.get("rounds",0))
	elif phase in ["draw","insert"]:evidence_rounds=int(state.held_new.get("rounds",0))
	MagazineView.update(magazine,evidence_rounds)
	if phase=="remove":
		offset=Vector3(-0.05,0.08,-0.06) if not pistol else Vector3(-0.06,0.045,0.015)
		angles=Vector3(-0.12,0.22,-0.65) if not pistol else Vector3(0.12,0.10,-0.48)
		var grasp := smoothstep(0.0,0.32,p)
		var pull := smoothstep(0.40,1.0,p)
		mag_offset=Vector3(0,-0.34*pull,0.07*pull)
		mag_rotation.x=0.35*pull if weapon_id in ["ak74","svd"] else 0.06*pull
		hand_target=hand_target.lerp(well+Vector3(-0.035,-0.025,0.015)+mag_offset,grasp)
		hand_rotation=Vector3(0.15,0,-0.25)
		phase_sound(0.30,p,"mag_out")
	elif phase in ["stow","draw"]:
		offset=Vector3(-0.05,0.08,-0.06)
		angles=Vector3(-0.12,0.22,-0.65)
		var pouch := pouch_position(state.pending_slot)
		var removed := Vector3(0,-0.34,0.07)
		if phase=="stow" and state.inspected_loaded_reload:
			var start := inspection_pose(-1,state.inspection_departure)
			removed=start.origin
			mag_rotation=start.basis.get_euler()*(1-smoothstep(0,1,p))
			offset=Vector3.ZERO
			angles=Vector3.ZERO
		mag_offset=removed.lerp(pouch,smoothstep(0,1,p)) if phase=="stow" else pouch.lerp(removed,smoothstep(0,1,p))
		magazine.visible=p<0.88 if phase=="stow" else p>0.12
		hand_target=well+mag_offset
		hand_rotation=Vector3(0.15,0,-0.25)
	elif phase in ["inspect_mag","inspect_pouch"]:
		var from_pouch := phase=="inspect_pouch"
		var pose := inspection_pose(state.inspection_slot,state.clock)
		var inspected: Node3D=inspection_mag if from_pouch else magazine
		inspection_mag.visible=from_pouch and state.clock>=0.16 and state.clock<2.0
		if from_pouch:inspection_mag.transform=pose
		else:
			mag_offset=pose.origin
			mag_rotation=pose.basis.get_euler()
		MagazineView.update(inspected,state.inspected_rounds())
		var grip := pose.origin+pose.basis*well+Vector3(-0.025,-0.025,0)
		hand_target=hand_target.lerp(grip,smoothstep(0,0.18,state.clock))
		hand_rotation=Vector3(0.2,0.2,-0.25)
		if not from_pouch:
			phase_sound(0.16/2.1,p,"mag_out")
			phase_sound(2.02/2.1,p,"mag_in")
	elif phase in ["ready_remove","ready_stow","ready_insert"]:
		var start := inspection_pose(state.inspection_slot,state.inspection_departure)
		var pouch := pouch_position(state.pending_slot)
		inspection_mag.visible=true
		MagazineView.update(inspection_mag,int(state.held_new.get("rounds",0)))
		var pair := Transform3D(Basis.from_euler(Vector3(0.15,0,0.1)),Vector3(-0.065,-0.21,0.07))
		if phase=="ready_remove":
			inspection_mag.transform=start.interpolate_with(pair,smoothstep(0,1,p))
			mag_offset=Vector3(0,-0.21,0.07)*smoothstep(0.2,1,p)
			magazine.visible=true
			phase_sound(0.25,p,"mag_out")
		elif phase=="ready_stow":
			mag_offset=Vector3(0,-0.21,0.07).lerp(pouch,smoothstep(0,1,p))
			magazine.visible=p<0.92
			MagazineView.update(magazine,int(state.held_old.get("rounds",0)))
			inspection_mag.transform=pair
			inspection_mag.position=mag_offset+Vector3(-0.065,0,0)
		else:
			magazine.visible=false
			inspection_mag.transform=Transform3D(pair.basis,pouch+Vector3(-0.065,0,0)).interpolate_with(Transform3D.IDENTITY,smoothstep(0,1,p))
			phase_sound(0.94,p,"mag_in")
		hand_target=inspection_mag.position+inspection_mag.basis*well+Vector3(-0.025,-0.025,0)
		hand_rotation=Vector3(0.15,0,-0.25)
	elif phase=="inspect_chamber":
		var hold := smoothstep(0,0.30,p)*(1-smoothstep(0.75,1,p))
		offset=Vector3(-0.08,0.06,-0.02)*hold
		angles=Vector3(0.12,0.35,1.15)*hold
		bolt.position.z=(0.009 if not state.bolt_open else 0.035)*hold
		chamber_window.visible=hold>0.75
		chamber_round.visible=hold>0.75 and state.chambered
		hand_target=hand_target.lerp(Vector3(-0.055,-0.025,0.035),hold)
		hand_rotation=Vector3(0,0,-0.35)
		phase_sound(0.25,p,"bolt_pull")
		phase_sound(0.82,p,"bolt")
	elif phase=="insert":
		offset=Vector3(-0.05,0.08,-0.06) if not pistol else Vector3(-0.06,0.045,0.015)
		angles=Vector3(-0.12,0.22,-0.65) if not pistol else Vector3(0.12,0.10,-0.48)
		var lift := smoothstep(0.25,0.94,p)
		mag_offset=Vector3(-0.018*(1-lift),-0.35*(1-lift),0.075*(1-lift))
		mag_rotation.x=0.35*(1-lift) if weapon_id in ["ak74","svd"] else 0.06*(1-lift)
		magazine.visible=p>=0.20
		hand_target=well+Vector3(-0.035,-0.025,0.015)+mag_offset
		hand_rotation=Vector3(0.15,0,-0.25)
		phase_sound(0.94,p,"mag_in")
	elif phase=="rack":
		offset=Vector3(-0.025,0.035,-0.02)
		angles=Vector3(0.06,-0.12,-0.5 if weapon_id in ["ak74","svd"] else -0.24)
		var handle_pos := Vector3(0.041,0.025,0.02)
		if weapon_id=="svd":handle_pos=Vector3(0.056,0.006,-0.025)
		if weapon_id=="m16":handle_pos=Vector3(-0.03,-0.015,0.015) if state.bolt_open else Vector3(0,0.042,0.12)
		if pistol:handle_pos=Vector3(0.015,0.025,0.05)
		hand_target=well.lerp(handle_pos,smoothstep(0,0.35,p))
		hand_rotation=Vector3(0,0.4,-1.0) if pistol else Vector3(0,0,-0.6)
		var pull := smoothstep(0.35,0.63,p)*(1-smoothstep(0.72,0.83,p))
		if not state.bolt_open:
			bolt.position.z=pull*(0.04 if pistol else 0.075)
			hand_target.z+=bolt.position.z
			if is_instance_valid(charging_handle):charging_handle.position.z=0.113+pull*0.075
		else:
			bolt.position.z=(0.035 if pistol else 0.06)*(1-smoothstep(0.72,0.80,p))
		if weapon_id=="svd" and state.bolt_open:
			bolt.position.z+=0.006*sin(p*PI)
			hand_target.z+=bolt.position.z
		phase_sound(0.38,p,"bolt_pull")
		phase_sound(0.76,p,"bolt")
	if phase not in ["rack","inspect_chamber"]:
		bolt.position.z=(0.035 if pistol else 0.065) if state.bolt_open else slide_kick*(0.035 if pistol else 0.065)
		if is_instance_valid(charging_handle):charging_handle.position.z=0.113
	var trigger := get_node_or_null("RightHand/TriggerFinger")
	if trigger:trigger.position.x=lerpf(0.023,0.007,slide_kick)
	slide_kick=maxf(0,slide_kick-delta*18)
	flash_time=maxf(0,flash_time-delta)
	flash_node.visible=flash_time>0
	magazine.position=mag_offset
	magazine.rotation=mag_rotation
	left_hand.position=left_hand.position.lerp(hand_target,minf(delta*24,1))
	left_hand.rotation=left_hand.rotation.lerp(hand_rotation,minf(delta*20,1))
	phase_offset=phase_offset.lerp(offset,minf(delta*12,1))
	phase_rotation=phase_rotation.lerp(angles,minf(delta*12,1))
	# Two independent forearms follow the wrists; palm rotation must not swing a
	# rigid sleeve into the eye, especially when racking a pistol slide.
	for side in ["Left","Right"]:
		var grip: Node3D=get_node(side+"Hand")
		var arm: Node3D=get_node(side+"Forearm")
		var wrist := grip.position+grip.basis*Vector3(0,-0.05,0.025)
		var elbow := Vector3(-0.22 if side=="Left" else 0.25,-0.36,0.24)
		arm.position=(wrist+elbow)/2
		arm.quaternion=Quaternion(Vector3.UP,elbow.direction_to(wrist))
		arm.scale=Vector3(1,wrist.distance_to(elbow)/0.26,1)
	previous_progress=p

func pouch_position(slot: int) -> Vector3:
	return Vector3(-0.30+slot*0.14,-0.46,0.18) if weapon_id not in ["pm","m9"] else Vector3(-0.30-slot*0.11,-0.58,0.20)

func inspection_pose(slot: int, time: float) -> Transform3D:
	var eye := Vector3(-0.16,0.12,0.045)
	var rotation := Vector3(0.72,-0.65*smoothstep(0.85,1.35,time),0.10)
	var source := pouch_position(slot) if slot>=0 else Vector3.ZERO
	var removed := source if slot>=0 else Vector3(0,-0.16,0.06)
	var lift := smoothstep(0.18 if slot>=0 else 0.38,0.66,time)
	var returning := smoothstep(1.65,2.0 if slot>=0 else 1.91,time)
	var position := removed.lerp(eye,lift).lerp(removed,returning)
	if slot<0:
		position=source.lerp(position,smoothstep(0.16,0.38,time))
		position=position.lerp(source,smoothstep(1.91,2.1,time))
	return Transform3D(Basis.from_euler(rotation*lift*(1-returning)),position)
