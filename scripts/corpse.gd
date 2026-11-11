class_name Corpse
extends Node3D

var game: Node3D
var bodies: Array[RigidBody3D]=[]
var paused_velocities: Dictionary={}
var was_paused := false

func setup(bot: Node3D, incoming: Vector3) -> void:
	game=bot.game
	# Deepest nodes first: all visuals retain their world pose when detached.
	var specs := [
		["LeftLeg/Knee",Vector3(0,-0.22,-0.02),Vector3(0.14,0.45,0.22),4.0],
		["RightLeg/Knee",Vector3(0,-0.22,-0.02),Vector3(0.14,0.45,0.22),4.0],
		["LeftLeg",Vector3(0,-0.18,0),Vector3(0.18,0.36,0.20),8.0],
		["RightLeg",Vector3(0,-0.18,0),Vector3(0.18,0.36,0.20),8.0],
		["LeftArm/Forearm",Vector3(0.19,0.085,-0.16),Vector3(0.38,0.14,0.26),2.0],
		["RightArm/Forearm",Vector3(-0.095,0.075,-0.09),Vector3(0.23,0.14,0.20),2.0],
		["LeftArm",Vector3(-0.03,-0.12,-0.085),Vector3(0.16,0.28,0.17),3.0],
		["RightArm",Vector3(0.055,-0.12,-0.04),Vector3(0.16,0.28,0.17),3.0],
		["Head",Vector3(0,0.16,0),Vector3(0.23,0.28,0.24),5.0],
		["CarriedRifle",Vector3(0,-0.04,-0.09),Vector3(0.07,0.22,1.05),3.0],
		[".",Vector3(0,1.17,0.025),Vector3(0.39,0.51,0.32),30.0]]
	var parts: Dictionary={}
	var anchors: Dictionary={}
	for spec in specs:
		var visual: Node3D=bot.model if spec[0]=="." else bot.model.get_node(spec[0])
		anchors[spec[0]]=visual.global_transform
		var body := RigidBody3D.new()
		body.name=String(spec[0]).replace("/","_").replace(".","Torso")
		body.mass=spec[3]
		body.collision_layer=8
		body.collision_mask=1|8
		body.linear_damp=0.45
		body.angular_damp=3.5 if spec[0]=="Head" else 1.7
		body.continuous_cd=true
		add_child(body)
		body.global_transform=visual.global_transform*Transform3D(Basis.IDENTITY,spec[1])
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size=spec[2]
		collision.shape=shape
		body.add_child(collision)
		visual.reparent(body,true)
		body.linear_velocity=bot.velocity*0.5+incoming.normalized()*0.12
		bodies.append(body)
		parts[spec[0]]=body
	for a in bodies:
		for b in bodies:
			if a!=b and (a==parts["CarriedRifle"] or b==parts["CarriedRifle"]):a.add_collision_exception_with(b)
	for spec in [["LeftLeg",".",false],["RightLeg",".",false],["LeftLeg/Knee","LeftLeg",true],["RightLeg/Knee","RightLeg",true],["LeftArm",".",false],["RightArm",".",false],["LeftArm/Forearm","LeftArm",false],["RightArm/Forearm","RightArm",false],["Head",".",false]]:
		var joint: Joint3D
		if spec[0]=="Head":
			var neck := Generic6DOFJoint3D.new()
			neck.name="NeckJoint"
			# Limited extension, flexion, yaw and roll; translations remain locked.
			for axis in ["x","y","z"]:
				neck.call("set_flag_"+axis,Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT,true)
				neck.call("set_param_"+axis,Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT,0.0)
				neck.call("set_param_"+axis,Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT,0.0)
				neck.call("set_flag_"+axis,Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT,true)
			neck.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT,-0.42)
			neck.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT,0.10)
			neck.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT,-0.50)
			neck.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT,0.50)
			neck.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT,-0.22)
			neck.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT,0.22)
			joint=neck
		elif spec[2]:
			var hinge := HingeJoint3D.new()
			hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT,true)
			hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER,-0.08)
			hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER,2.1)
			joint=hinge
		else:
			var cone := ConeTwistJoint3D.new()
			cone.swing_span=0.85
			cone.twist_span=0.35
			joint=cone
		add_child(joint)
		joint.global_transform=anchors[spec[0]]
		if spec[0]=="Head":joint.global_basis=parts["."].global_basis
		else:joint.rotate_object_local(Vector3.UP,PI/2)
		joint.node_a=joint.get_path_to(parts[spec[1]])
		joint.node_b=joint.get_path_to(parts[spec[0]])
	parts["."].angular_velocity=bot.global_basis*Vector3(0.9,0,0.35)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(game):return
	if game.paused and not was_paused:
		for body in bodies:
			paused_velocities[body.get_instance_id()]=[body.linear_velocity,body.angular_velocity]
			body.freeze=true
	elif not game.paused and was_paused:
		for body in bodies:
			body.freeze=false
			body.linear_velocity=paused_velocities[body.get_instance_id()][0]
			body.angular_velocity=paused_velocities[body.get_instance_id()][1]
	was_paused=game.paused
