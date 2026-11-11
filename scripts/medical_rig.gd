class_name MedicalRig
extends Node3D

var lid: Node3D
var left: Node3D
var right: Node3D
var dressing: Node3D
var timer := 0.0

func _ready() -> void:
	position=Vector3(0,-0.24,-0.48)
	Models.bevel(self,Vector3(0,-0.035,0),Vector3(0.19,0.085,0.13),"465643",0.012)
	Models.bevel(self,Vector3(0,0.008,0),Vector3(0.17,0.009,0.11),"252e29",0.004)
	for x in [-0.05,0,0.05]:Models.bevel(self,Vector3(x,0.017,0),Vector3(0.035,0.015,0.075),"d2cdb5",0.005)
	lid=Models.group(self,"Lid",Vector3(0,0.005,-0.065))
	Models.bevel(lid,Vector3(0,0,0.065),Vector3(0.19,0.019,0.13),"56664a",0.009)
	# Neutral first-aid symbol; no simulation of a specific drug or procedure.
	Models.bevel(lid,Vector3(0,0.011,0.065),Vector3(0.055,0.002,0.018),"d2cdb5",0.001)
	Models.bevel(lid,Vector3(0,0.012,0.065),Vector3(0.018,0.002,0.055),"d2cdb5",0.001)
	left=hand("Left",Vector3(-0.11,-0.03,0.025))
	right=hand("Right",Vector3(0.11,0.02,0.03))
	dressing=Models.group(right,"Dressing",Vector3(-0.03,0.02,-0.025))
	Models.tube(dressing,Vector3.ZERO,0.025,0.05,"d2cdb5",Vector3.RIGHT)
	Models.bevel(dressing,Vector3(0,-0.035,0),Vector3(0.05,0.075,0.002),"d2cdb5",0.001)
	visible=false

func hand(title: String, origin: Vector3) -> Node3D:
	var node := Models.group(self,title,origin)
	Models.bevel(node,Vector3.ZERO,Vector3(0.055,0.025,0.08),"glove",0.008)
	for i in range(4):Models.tube(node,Vector3(-0.020+i*0.013,0,-0.056),0.006,0.04,"glove")
	Models.tube(node,Vector3(0,0.01,0.12),0.036,0.22,"cloth",Vector3.BACK,0.028)
	return node

func animate(remaining: float, duration: float) -> void:
	visible=remaining>0
	if not visible:return
	var progress := 1.0-remaining/duration
	var open_amount := smoothstep(0.08,0.25,progress)*(1-smoothstep(0.85,1,progress))
	position.y=-0.24-(1-smoothstep(0,0.12,progress))*0.35-smoothstep(0.91,1,progress)*0.35
	lid.rotation.x=-open_amount*1.85
	dressing.visible=progress>0.25 and progress<0.83
	var cycle := sin(progress*TAU*4)*0.025
	right.position=Vector3(0.10-0.08*open_amount,0.01+0.06*open_amount+cycle,0.03+0.05*open_amount)
	right.rotation.z=-open_amount*0.4
	left.rotation.z=0.1+cycle
