class_name Rpg22Art
extends RefCounted

# RPG-22 "Netto" disposable anti-tank launcher and its 72.5 mm rocket. Original
# procedural geometry: metres, muzzle along -Z, bore on the Z axis, +Y up, +X right.
#
# Public data used:
#  - 72.5 mm, 2.7 kg, 755 mm in transport and 850 mm ready to fire: a brown
#    plastic extension sleeve at the front slides 95-100 mm forward over the olive
#    fibreglass tube. Both ends are capped for transport; drawing the sleeve out
#    drops the front cover and the rear cover comes off. The front sight frame is
#    on the sleeve and rises with it; the diopter rear sight stands in the middle of
#    the tube on the firing mechanism (raising it cocks the mechanism, lowering it
#    de-cocks); the trigger lever is just ahead of it, so the right hand grips the
#    tube from above. Front sight marks "5", "15", "25" (50/150/250 m). Rocket:
#    1.5 kg, 133 m/s, motor burns out in the tube, four spring fins at the tail.
#    ru.wikipedia.org/wiki/РПГ-22, modernfirearms.net (RPG-22),
#    russianwarrior.com (755/850 mm), weaponsystems.net (flip-up sights).
#  Photos (Wikimedia Commons): "RPG-22 at exhibition «Presence».jpg" (both states
#  side by side), "Человек с РПГ-22 в руках целится на выставке, апрель 2018.jpg"
#  (sight heights, mechanism rail, rod), "RPG-22 of the Croatian Army.jpg" (hands,
#  hanging front cover), "Ручные реактивные гранатометы ... Russian RPG launchers.jpg".

const Kit = preload("res://scripts/rpg7_art.gd")

const LENGTH_TRANSPORT := 0.755
const LENGTH_COMBAT := 0.850
const CALIBER := 0.0725
const MASS_KG := 2.7
const GRENADE_MASS_KG := 1.5
const GRENADE_SPEED := 133.0
const SIGHT_RADIUS := 0.32
# Centre of the rear peep (extended state); the front frame stands SIGHT_RADIUS ahead.
const APERTURE := Vector3(0,0.095,0.020)
const APERTURE_RADIUS := 0.0055
# Right hand wraps the tube from above-right, index finger on the trigger lever.
const GRIP := Vector3(0.024,0.036,-0.050)
const TRIGGER := Vector3(0,0.0625,-0.052)
# Left hand under the brown sleeve; the tube's rear third lies on the shoulder.
const SUPPORT := Vector3(0,-0.047,-0.290)
const SHOULDER := Vector3(0,-0.041,0.220)
const REAR_Z := 0.400
const MUZZLE_Z := -0.450
const DEFAULT_MARKS := [[50,0.014],[100,0.029],[150,0.045],[200,0.063]]

static func build(extended: bool=true, marks: Array=DEFAULT_MARKS) -> Node3D:
	register_materials()
	var root := Node3D.new()
	root.name="RPG22"
	var front := MUZZLE_Z+(0.0 if extended else LENGTH_COMBAT-LENGTH_TRANSPORT)
	launch_tube(root)
	sleeve(root,front)
	mechanism(root)
	rear_sight(root,extended)
	front_sight(root,front+0.150,extended,marks)
	covers(root,front,extended)
	sling(root)
	markings(root)
	Models.marker(root,"Muzzle",Vector3(0,0,front))
	Models.marker(root,"Breech",Vector3(0,0,REAR_Z))
	Models.marker(root,"RearAperture",APERTURE)
	Models.merge_rigid(root)
	return root

static func launch_tube(root: Node3D) -> void:
	# Olive fibreglass tube; open bore at both ends, rocket nose and motor nozzle inside.
	Kit.lathe(root,[Vector2(-0.205,0.0372),Vector2(-0.285,0.0372),Vector2(-0.285,0.0410),Vector2(0.386,0.0410),Vector2(0.386,0.0433),Vector2(0.400,0.0433),Vector2(0.400,0.0372),Vector2(0.300,0.0372)],"rpg22_tube",32)
	Kit.cyl(root,Vector3(0,0,0.300),0.0373,0.001,"gun_recess",Vector3.BACK,16)
	Kit.ring(root,Vector3(0,0,0.302),0.0185,0.0105,"gun_metal")
	Kit.cyl(root,Vector3(0,0,-0.205),0.0373,0.001,"gun_recess",Vector3.BACK,16)
	Kit.lathe(root,[Vector2(-0.262,0.0),Vector2(-0.258,0.006),Vector2(-0.245,0.016),Vector2(-0.225,0.027),Vector2(-0.206,0.033)],"rpg22_head",12)
	# Clamp bands; the outer two carry the sling swivels.
	for z in [0.240,0.060,-0.100]:
		Kit.lathe(root,[Vector2(z-0.007,0.0410),Vector2(z-0.0065,0.0428),Vector2(z+0.0065,0.0428),Vector2(z+0.007,0.0410)],"rpg22_tube",32)
		Models.bevel(root,Vector3(0.042,-0.004,z),Vector3(0.005,0.010,0.012),"rpg22_mech",0.0012)
	for side in [-1,1]:Models.bevel(root,Vector3(side*0.0445,0.0,0.392),Vector3(0.004,0.012,0.016),"rpg22_mech",0.0012)

static func sleeve(root: Node3D, front: float) -> void:
	# Brown extension sleeve over the tube's front end, with lip and rear collar.
	var rear := front+0.200
	Kit.lathe(root,[Vector2(-0.285,0.0414),Vector2(front,0.0414),Vector2(front,0.0462),Vector2(front+0.002,0.0468),Vector2(front+0.011,0.0468),Vector2(front+0.013,0.0447),Vector2(rear-0.015,0.0447),Vector2(rear-0.013,0.0466),Vector2(rear,0.0466),Vector2(rear,0.0412)],"rpg22_sleeve",32)
	# Box on top sheathes the mechanism rail and carries the front sight frame.
	Models.bevel(root,Vector3(0,0.0505,rear-0.075),Vector3(0.028,0.019,0.150),"rpg22_sleeve",0.003)
	Models.bevel(root,Vector3(0,0.0602,rear-0.100),Vector3(0.022,0.0012,0.080),"rpg22_mech",0.0004)
	for side in [-1,1]:Kit.pin(root,Vector3(side*0.0142,0.052,rear-0.125),0.0022)

static func mechanism(root: Node3D) -> void:
	# Rail along the top, housing around the rear sight, trigger lever ahead of it.
	Models.bevel(root,Vector3(0,0.0445,0.055),Vector3(0.024,0.009,0.640),"rpg22_mech",0.002)
	Models.bevel(root,Vector3(0,0.0505,-0.005),Vector3(0.030,0.016,0.160),"rpg22_mech",0.0025)
	Models.bevel(root,Vector3(0,0.0585,0.045),Vector3(0.022,0.003,0.040),"gun_edge",0.0008)
	var lever := Models.bevel(root,TRIGGER+Vector3(0,-0.002,0),Vector3(0.013,0.005,0.030),"gun_rubber",0.0015)
	lever.rotation.x=0.10
	for i in range(5):Models.bevel(root,TRIGGER+Vector3(0,0.0006+i*0.0003,-0.010+i*0.005),Vector3(0.012,0.0008,0.0012),"gun_recess",0.0002)
	for side in [-1,1]:
		for z in [-0.070,0.060]:Kit.pin(root,Vector3(side*0.0152,0.050,z),0.0022)
		Models.bevel(root,Vector3(side*0.0151,0.0478,-0.020),Vector3(0.0008,0.005,0.050),"gun_recess",0.0002)
	# Striker rod on the left with its rear knob and guide clips.
	Models.limb(root,Vector3(-0.021,0.0455,0.383),Vector3(-0.021,0.0455,0.085),0.0032,"rpg22_mech")
	Kit.cyl(root,Vector3(-0.021,0.0455,0.388),0.0055,0.008,"gun_edge",Vector3.BACK,12)
	for z in [0.300,0.180]:Models.bevel(root,Vector3(-0.019,0.0440,z),Vector3(0.011,0.007,0.008),"rpg22_mech",0.0012)

static func rear_sight(root: Node3D, extended: bool) -> void:
	# Diopter plate hinged on the housing: upright when cocked, folded forward over
	# the trigger lever for transport. The peep is a real hole.
	var hinge := Vector3(0,0.0585,APERTURE.z)
	var pose := Models.group(root,"RearSightPose",hinge)
	var h := APERTURE.y-hinge.y
	var cut := 0.0062
	Kit.cyl(pose,Vector3.ZERO,0.003,0.024,"gun_edge",Vector3.RIGHT,10)
	Models.bevel(pose,Vector3(0,(h-cut)/2,0),Vector3(0.024,h-cut,0.003),"rpg22_mech",0.0006)
	Models.bevel(pose,Vector3(0,h+cut+0.003,0),Vector3(0.024,0.006,0.003),"rpg22_mech",0.0006)
	for side in [-1,1]:Models.bevel(pose,Vector3(side*(cut+0.0029),h,0),Vector3(0.0058,2*cut,0.003),"rpg22_mech",0.0004)
	Kit.ring(pose,Vector3(0,h,0),0.0095,APERTURE_RADIUS,"gun_edge",Vector3.BACK,24)
	pose.rotation.x=0.0 if extended else -PI/2
	Kit.bake(pose)

static func front_sight(root: Node3D, z: float, extended: bool, marks: Array) -> void:
	# Window frame on the sleeve: range bars centred on the line of sight, range in
	# tens of metres on the left plate. Looking from APERTURE through a bar points
	# the line of sight down by that mark's elevation.
	var hinge := Vector3(0,0.0600,z)
	var pose := Models.group(root,"FrontSightPose",hinge)
	var heights: Array[float]=[]
	for mark in marks:heights.append(APERTURE.y-SIGHT_RADIUS*tan(float(mark[1]))-hinge.y)
	var top := APERTURE.y+0.008-hinge.y
	var low := top-0.012
	for y in heights:low=minf(low,y-0.0055)
	low=maxf(low,0.0045)
	var t := 0.0016
	Kit.cyl(pose,Vector3.ZERO,0.0025,0.034,"gun_edge",Vector3.RIGHT,10)
	Models.bevel(pose,Vector3(-0.0165,top/2,0),Vector3(0.011,top,t),"rpg22_mech",0.0004)
	Models.bevel(pose,Vector3(0.0128,top/2,0),Vector3(0.0036,top,t),"rpg22_mech",0.0004)
	Models.bevel(pose,Vector3(-0.0037,top-0.0014,0),Vector3(0.0366,0.0028,t),"rpg22_mech",0.0004)
	Models.bevel(pose,Vector3(-0.0037,low/2,0),Vector3(0.0366,low,t),"rpg22_mech",0.0004)
	for i in range(marks.size()):
		var y: float=heights[i]
		Models.bevel(pose,Vector3(0,y,0),Vector3(0.011,0.0008,0.0011),"gun_recess",0.0001)
		digits(pose,str(int(marks[i][0])/10),Vector3(-0.0165,y,t/2+0.0002),0.0040,"white")
	pose.rotation.x=0.0 if extended else -PI/2
	Kit.bake(pose)

static func covers(root: Node3D, front: float, extended: bool) -> void:
	# Front cover: closed in transport, hanging from its hinge once the sleeve is out.
	var pose := Models.group(root,"FrontCoverPose",Vector3(0,-0.0475,front-0.004))
	Kit.lathe(pose,[Vector2(-0.007,0.0),Vector2(-0.007,0.0455),Vector2(-0.0058,0.0490),Vector2(0.008,0.0490),Vector2(0.008,0.0470),Vector2(-0.004,0.0470),Vector2(-0.004,0.0)],"rpg22_tube",28,false,Vector3(0,0.0475,0.004))
	Models.bevel(pose,Vector3(0,-0.002,0.004),Vector3(0.016,0.006,0.012),"rpg22_mech",0.001)
	Kit.cyl(pose,Vector3(0,0,0.004),0.0025,0.020,"gun_edge",Vector3.RIGHT,10)
	Models.bevel(pose,Vector3(0,0.0475,-0.0075),Vector3(0.022,0.004,0.0012),"rpg22_mech",0.0003)
	pose.rotation.x=PI-0.2 if extended else 0.0
	Kit.bake(pose)
	# Rear cover: only in transport, it is pulled off before firing.
	if not extended:
		Kit.lathe(root,[Vector2(0.401,0.0),Vector2(0.401,0.0434),Vector2(0.389,0.0434),Vector2(0.389,0.0458),Vector2(0.4085,0.0458),Vector2(0.410,0.0442),Vector2(0.410,0.0)],"rpg22_tube",28)
		Models.bevel(root,Vector3(0,0.0,0.4103),Vector3(0.030,0.004,0.0012),"rpg22_mech",0.0003)

static func sling(root: Node3D) -> void:
	for z in [0.240,-0.100]:
		Models.bevel(root,Vector3(-0.031,-0.030,z),Vector3(0.008,0.008,0.012),"rpg22_mech",0.0015)
		Kit.ring(root,Vector3(-0.036,-0.037,z),0.0085,0.0062,"gun_edge",Vector3.RIGHT)
	Kit.strap(root,[Vector3(-0.040,-0.043,0.240),Vector3(-0.047,-0.060,0.170),Vector3(-0.049,-0.070,0.070),Vector3(-0.047,-0.066,-0.020),Vector3(-0.040,-0.046,-0.100)],0.025,"gear_#6b6845")

static func markings(root: Node3D) -> void:
	# Black instruction label on the left with the white "direction of fire" arrow.
	var r := 0.0412
	Kit.lathe(root,[Vector2(-0.088,r),Vector2(0.048,r)],"rpg22_label",10,false,Vector3.ZERO,Vector2(PI*0.78,PI*1.22))
	Kit.lathe(root,[Vector2(-0.038,r+0.0003),Vector2(0.026,r+0.0003)],"white",2,false,Vector3.ZERO,Vector2(PI-0.05,PI+0.05))
	for i in range(6):
		var half := 0.0085*(1.0-(i+0.5)/6.0)/r
		Kit.lathe(root,[Vector2(-0.0385-(i+1)*0.0034,r+0.0003),Vector2(-0.0385-i*0.0034,r+0.0003)],"white",2,false,Vector3.ZERO,Vector2(PI-half,PI+half))
	for i in range(4):Kit.lathe(root,[Vector2(-0.080,r+0.0003),Vector2(-0.080+0.045-i*0.008,r+0.0003)],"#8d8f86",2,false,Vector3.ZERO,Vector2(PI*0.83+i*0.035,PI*0.83+i*0.035+0.012))
	# Stencilled lot data on the right.
	for i in range(3):Kit.lathe(root,[Vector2(-0.06,r+0.0003),Vector2(-0.06+0.05-i*0.012,r+0.0003)],"#c9c6a8",2,false,Vector3.ZERO,Vector2(0.10+i*0.07,0.13+i*0.07))

# Seven-segment numbers centred on origin, in the XY plane, read from +Z.
const SEGMENTS := {"0":"abcdef","1":"bc","2":"abged","3":"abgcd","4":"fgbc","5":"afgcd","6":"afgedc","7":"abc","8":"abcdefg","9":"abcdfg"}
static func digits(parent: Node3D, text: String, origin: Vector3, height: float, key: String) -> void:
	var w := height*0.6
	var s := height*0.17
	var gap := height*0.28
	var total := text.length()*w+(text.length()-1)*gap
	for c in range(text.length()):
		var cx := origin.x-total/2+w/2+c*(w+gap)
		for segment in SEGMENTS.get(text[c],""):
			var at := Vector2(cx,origin.y)
			var size := Vector2(w,s)
			match segment:
				"a":at.y+=height/2-s/2
				"d":at.y-=height/2-s/2
				"b","c","e","f":
					size=Vector2(s,height/2+s/2)
					at.x+=(w/2-s/2)*(1 if segment in ["b","c"] else -1)
					at.y+=(height/4)*(1 if segment in ["b","f"] else -1)
			Models.bevel(parent,Vector3(at.x,at.y,origin.z),Vector3(size.x,size.y,0.0004),key,0.0001)

# The rocket in flight: fins open, nose along -Z, origin at the head/motor joint.
static func grenade() -> Node3D:
	register_materials()
	var root := Node3D.new()
	root.name="PG22"
	Kit.lathe(root,[Vector2(-0.215,0.0),Vector2(-0.2146,0.0030),Vector2(-0.2128,0.0055),Vector2(-0.2095,0.0068),Vector2(-0.2010,0.0072),Vector2(-0.2000,0.0080)],"gun_edge",16)
	Kit.lathe(root,[Vector2(-0.2000,0.0080),Vector2(-0.190,0.0118),Vector2(-0.172,0.0176),Vector2(-0.152,0.0232),Vector2(-0.132,0.0280),Vector2(-0.112,0.0318),Vector2(-0.094,0.0343),Vector2(-0.079,0.0358),Vector2(-0.070,0.03625),Vector2(-0.036,0.03625),Vector2(-0.031,0.0352),Vector2(-0.020,0.0310),Vector2(-0.008,0.0262),Vector2(0.0,0.0232)],"rpg22_head",28)
	Kit.lathe(root,[Vector2(-0.0705,0.0360),Vector2(-0.0700,0.0366),Vector2(-0.0660,0.0366),Vector2(-0.0655,0.0360)],"gun_edge",28)
	Kit.lathe(root,[Vector2(-0.0505,0.03625),Vector2(-0.050,0.0366),Vector2(-0.044,0.0366),Vector2(-0.0435,0.03625)],"gun_recess",28)
	# Motor tube and nozzle; four spring fins swept back at the tail.
	Kit.lathe(root,[Vector2(0.0,0.0215),Vector2(0.352,0.0215),Vector2(0.356,0.0190),Vector2(0.372,0.0178),Vector2(0.375,0.0165),Vector2(0.375,0.0120),Vector2(0.360,0.0108)],"rpg22_motor",24)
	Kit.cyl(root,Vector3(0,0,0.3605),0.0109,0.001,"gun_recess",Vector3.BACK,12)
	Kit.lathe(root,[Vector2(0.0,0.0217),Vector2(0.006,0.0217)],"gun_edge",24)
	for i in range(4):
		var fin := Kit.slab(root,PackedVector2Array([Vector2(0.302,0.0205),Vector2(0.352,0.0205),Vector2(0.373,0.068),Vector2(0.352,0.068)]),0.0016,"rpg22_motor")
		fin.rotation.z=TAU*i/4+PI/4-PI/2
	Models.merge_rigid(root)
	return root

static func register_materials() -> void:
	Kit.register_materials()
	if Models.materials.has("rpg22_tube"):return
	var tube := Models.surface("cloth").duplicate() as StandardMaterial3D
	tube.resource_name="rpg22_tube"
	tube.albedo_color=Color("6b7a44")
	tube.roughness=0.72
	Models.materials["rpg22_tube"]=tube
	var mech := Models.surface("gun_metal").duplicate() as StandardMaterial3D
	mech.resource_name="rpg22_mech"
	mech.albedo_color=Color("57534a")
	Models.materials["rpg22_mech"]=mech
	for spec in [["rpg22_sleeve","6a2e22",0.0,0.5],["rpg22_label","141516",0.0,0.5],["rpg22_head","4f5934",0.0,0.6],["rpg22_motor","5b5e50",0.4,0.55]]:
		var mat := StandardMaterial3D.new()
		mat.resource_name=spec[0]
		mat.albedo_color=Color(spec[1])
		mat.metallic=spec[2]
		mat.roughness=spec[3]
		Models.materials[spec[0]]=mat
