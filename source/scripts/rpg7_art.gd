class_name Rpg7Art
extends RefCounted

# RPG-7V with the PGO-7 optical sight and a PG-7VL round. Original procedural
# geometry: metres, muzzle along -Z, bore on the Z axis, +Y up, +X right.
#
# Public data used (no drawings; proportions measured off photographs):
#  - RPG-7V: 950 mm long, 40 mm bore, 6.3 kg (about 7 kg with the PGO-7). The tube
#    widens in the middle into the chamber where the expelling charge burns; that
#    part is covered by the lacquered wooden heat shield. Behind it the divergent
#    nozzle (venturi) ends in a bell. Two grips: the front one hangs from the
#    aluminium trigger housing (the hammer spur sticks out of the back of the
#    housing and is pulled down to cock), the second, plain grip sits under the
#    sight bracket. Hooded front sight near the muzzle, folding leaf (200-500 m)
#    in a hood on the chamber, PGO-7 bracket plate on the LEFT of the chamber.
#    ru.wikipedia.org/wiki/РПГ-7, en.wikipedia.org/wiki/RPG-7,
#    sadefensejournal.com/the-rpg-7-system-primer (hammer spur, divergent nozzle).
#  - PGO-7V: 2.7x, 13 deg field, about 0.5 kg; box body with a rubber eyecup at the
#    rear, a hooded objective at the front, elevation handwheel on top.
#    armyrecognition.com (RPG-7), optixco.com (PGO-7V).
#  - PG-7VL "Luch": 93 mm head, 990 mm with the PG-7P charge, 2.6 kg, 112 m/s off
#    the launcher, sustainer to about 300 m/s, 500 mm RHA. Loaded, only the head
#    and the sustainer nozzle ring stand ahead of the muzzle; the 40 mm motor,
#    the folded stabiliser and the paper-cased charge sit inside the tube, the
#    charge in the widened chamber.
#  Photos (Wikimedia Commons): "RPG-7V detached noBG (cropped).jpg" (side view,
#  0.57 mm/px: all launcher stations below), "RPG-7 with PG-7VL round.jpg" (head
#  protrudes 0.39 m), "PG-7VL round at Interpolitex-2016 01.jpg", "Protitankový
#  komplet RPG-7.jpg" (PGO-7 above the rear grip), "RPG PG 7VL.png".

const LENGTH := 0.950
const TUBE_CALIBER := 0.040
const WARHEAD_CALIBER := 0.093
const MASS_KG := 6.3
const MASS_WITH_SIGHT_KG := 7.0
const GRENADE_LENGTH := 0.990
const GRENADE_MASS_KG := 2.6
const GRENADE_SPEED := 112.0
# Launcher stations are measured as d from the muzzle: z = MUZZLE_Z + d. The
# origin (d = 0.32 m) is at the rear grip, the loaded launcher's balance point.
const MUZZLE_Z := -0.32
const MUZZLE := Vector3(0,0,-0.32)
const BREECH := Vector3(0,0,0.63)
# Centre of the rear face of the PGO-7 eyecup; the optical axis runs along -Z.
const EYEPIECE := Vector3(-0.062,0.052,0.075)
# Firing hand on the front (trigger) grip, half way down it.
const GRIP := Vector3(0,-0.120,-0.183)
# The second grip, under the sight bracket (many gunners hold it with the left hand).
const REAR_GRIP := Vector3(0,-0.078,-0.018)
# Left hand under the bare muzzle section, ahead of the trigger guard.
const SUPPORT := Vector3(0,-0.024,-0.255)
# Underside of the narrow rear part of the wooden shield that rests on the shoulder.
const SHOULDER := Vector3(0,-0.026,0.28)
# The "Hammer" group sits here; rotation.x = HAMMER_COCKED pulls the spur down.
const HAMMER_PIVOT := Vector3(0,-0.041,-0.149)
const HAMMER_COCKED := 0.55

static func build(loaded: bool=true) -> Node3D:
	register_materials()
	var root := Node3D.new()
	root.name="RPG7"
	var m := MUZZLE_Z
	launch_tube(root,m)
	front_sight(root,m)
	chamber_fittings(root,m)
	trigger_group(root,m)
	grips(root,m)
	pgo7(root)
	sling(root,m)
	Models.marker(root,"Muzzle",MUZZLE)
	Models.marker(root,"Breech",BREECH)
	Models.marker(root,"Eyepiece",EYEPIECE)
	# Loaded round: its origin (motor/head joint) sits on the muzzle face.
	var loaded_round := Models.group(root,"Grenade",MUZZLE)
	loaded_round.add_child(grenade(true,false))
	loaded_round.visible=loaded
	Models.merge_rigid(root)
	return root

static func launch_tube(root: Node3D, m: float) -> void:
	# Muzzle face, muzzle section, cone into the chamber block, front shield ring.
	lathe(root,[Vector2(m,0.0200),Vector2(m,0.0213),Vector2(m+0.0012,0.0226),Vector2(m+0.012,0.0226),Vector2(m+0.0128,0.0222),Vector2(m+0.205,0.0222),Vector2(m+0.211,0.0232),Vector2(m+0.230,0.0292),Vector2(m+0.241,0.0310),Vector2(m+0.329,0.0310),Vector2(m+0.330,0.0362),Vector2(m+0.343,0.0362),Vector2(m+0.345,0.0346)],"gun_metal",24)
	# Open bore, 85 mm deep before it is closed off.
	lathe(root,[Vector2(m+0.085,0.0200),Vector2(m,0.0200)],"rpg_bore",20)
	cyl(root,Vector3(0,0,m+0.085),0.0201,0.001,"gun_recess",Vector3.BACK,12)
	# Lacquered wooden heat shield: full over the chamber, tapering to the rear tube.
	lathe(root,[Vector2(m+0.345,0.0330),Vector2(m+0.3475,0.0354),Vector2(m+0.36,0.0357),Vector2(m+0.515,0.0357),Vector2(m+0.532,0.0350),Vector2(m+0.548,0.0328),Vector2(m+0.563,0.0292),Vector2(m+0.576,0.0262),Vector2(m+0.588,0.0251),Vector2(m+0.742,0.0251),Vector2(m+0.745,0.0236)],"rpg_wood",28)
	# Glued seam of the two shield halves, underneath.
	Models.bevel(root,Vector3(0,-0.0352,m+0.44),Vector3(0.004,0.0012,0.16),"gun_recess",0.0003)
	Models.bevel(root,Vector3(0,-0.0247,m+0.665),Vector3(0.004,0.0012,0.15),"gun_recess",0.0003)
	# Clamp bands with their screw lugs on top.
	for d in [0.591,0.731]:
		lathe(root,[Vector2(m+d,0.0246),Vector2(m+d+0.0008,0.0268),Vector2(m+d+0.0112,0.0268),Vector2(m+d+0.012,0.0246)],"gun_metal",24)
		Models.bevel(root,Vector3(0,0.0298,m+d+0.006),Vector3(0.0075,0.0075,0.0095),"gun_metal",0.0015)
		cyl(root,Vector3(0,0.0298,m+d+0.006),0.0018,0.0095,"gun_edge",Vector3.RIGHT,8)
	# Coupling ring and the divergent nozzle with its flared bell; the throat stays open.
	lathe(root,[Vector2(m+0.744,0.0250),Vector2(m+0.7445,0.0293),Vector2(m+0.7565,0.0293),Vector2(m+0.757,0.0276)],"gun_metal",24)
	lathe(root,[Vector2(m+0.757,0.0274),Vector2(m+0.790,0.0294),Vector2(m+0.830,0.0336),Vector2(m+0.870,0.0381),Vector2(m+0.903,0.0421),Vector2(m+0.912,0.0433),Vector2(m+0.9135,0.0452),Vector2(m+0.932,0.0463),Vector2(m+0.9365,0.0486),Vector2(m+0.9415,0.0620),Vector2(m+0.9445,0.0656),Vector2(m+0.950,0.0659),Vector2(m+0.950,0.0445),Vector2(m+0.947,0.0424),Vector2(m+0.900,0.0355),Vector2(m+0.850,0.0292),Vector2(m+0.800,0.0228),Vector2(m+0.775,0.0190)],"rpg_bell",32)
	cyl(root,Vector3(0,0,m+0.775),0.0192,0.001,"gun_recess",Vector3.BACK,12)

static func front_sight(root: Node3D, m: float) -> void:
	# Clamp, base, two protective ears with a hood; the post stands in the open gap.
	lathe(root,[Vector2(m+0.022,0.0220),Vector2(m+0.0225,0.0244),Vector2(m+0.0715,0.0244),Vector2(m+0.072,0.0220)],"gun_metal",24)
	Models.bevel(root,Vector3(0,0.0268,m+0.047),Vector3(0.019,0.008,0.050),"gun_metal",0.0015)
	for side in [-1,1]:
		Models.bevel(root,Vector3(side*0.0105,0.0385,m+0.047),Vector3(0.0028,0.020,0.046),"gun_metal",0.0006)
		pin(root,Vector3(side*0.0121,0.034,m+0.030),0.0018)
	Models.bevel(root,Vector3(0,0.0485,m+0.047),Vector3(0.0238,0.0028,0.046),"gun_metal",0.0006)
	for z in [m+0.034,m+0.060]:cyl(root,Vector3(0,0.0500,z),0.0034,0.0008,"gun_recess",Vector3.UP,10)
	Models.bevel(root,Vector3(0,0.0365,m+0.052),Vector3(0.0022,0.013,0.0025),"gun_metal",0.0003)
	Models.bevel(root,Vector3(0,0.0318,m+0.038),Vector3(0.0035,0.0022,0.014),"gun_edge",0.0003)
	# Front sling swivel on the left of the sight clamp.
	Models.bevel(root,Vector3(-0.0235,0.0045,m+0.088),Vector3(0.006,0.010,0.012),"gun_metal",0.0015)
	ring(root,Vector3(-0.0275,-0.004,m+0.088),0.0085,0.0062,"gun_edge",Vector3.RIGHT)

static func chamber_fittings(root: Node3D, m: float) -> void:
	# Rear leaf sight: base, sloped hood, folded leaf with slider and range marks.
	Models.bevel(root,Vector3(0,0.0335,m+0.278),Vector3(0.020,0.009,0.074),"gun_metal",0.0015)
	for side in [-1,1]:
		slab(root,PackedVector2Array([Vector2(m+0.242,0.036),Vector2(m+0.316,0.036),Vector2(m+0.316,0.0625),Vector2(m+0.262,0.0625),Vector2(m+0.244,0.045)]),0.0028,"gun_metal",side*0.0105)
	Models.bevel(root,Vector3(0,0.0615,m+0.300),Vector3(0.0238,0.0028,0.032),"gun_metal",0.0006)
	Models.bevel(root,Vector3(0,0.0415,m+0.276),Vector3(0.015,0.0028,0.060),"gun_metal",0.0005)
	Models.bevel(root,Vector3(0,0.0442,m+0.262),Vector3(0.018,0.0045,0.009),"gun_edge",0.0008)
	for i in range(4):Models.bevel(root,Vector3(-0.004,0.0431,m+0.272+i*0.009),Vector3(0.005,0.0004,0.0008),"white",0.0001)
	for side in [-1,1]:Models.bevel(root,Vector3(side*0.0035,0.0438,m+0.304),Vector3(0.004,0.0032,0.003),"gun_metal",0.0004)
	Models.bevel(root,Vector3(0,0.0375,m+0.337),Vector3(0.006,0.004,0.008),"gun_metal",0.001)
	# PGO-7 bracket plate on the left of the chamber, with two oval slots and screws.
	Models.bevel(root,Vector3(-0.0335,0.006,m+0.279),Vector3(0.007,0.024,0.104),"gun_metal",0.0015)
	for z in [m+0.252,m+0.304]:Models.bevel(root,Vector3(-0.0372,0.006,z),Vector3(0.0012,0.0085,0.040),"gun_recess",0.003)
	for z in [m+0.231,m+0.327]:pin(root,Vector3(-0.0372,0.006,z),0.0032)
	# Machined lug under the chamber for the rear grip.
	Models.bevel(root,Vector3(0,-0.031,m+0.305),Vector3(0.022,0.010,0.058),"gun_metal",0.002)
	for side in [-1,1]:pin(root,Vector3(side*0.0112,-0.031,m+0.290),0.0022)

static func trigger_group(root: Node3D, m: float) -> void:
	# Aluminium trigger housing hung under the muzzle section. It is L-shaped, so the
	# guard opening around the trigger stays empty.
	slab(root,PackedVector2Array([Vector2(m+0.104,-0.0150),Vector2(m+0.186,-0.0150),Vector2(m+0.186,-0.0690),Vector2(m+0.178,-0.0772),Vector2(m+0.129,-0.0772),Vector2(m+0.129,-0.0262),Vector2(m+0.104,-0.0262)]),0.020,"rpg_alu")
	Models.bevel(root,Vector3(0,-0.0475,m+0.1040),Vector3(0.011,0.050,0.0045),"rpg_alu",0.0012)
	Models.bevel(root,Vector3(0,-0.0748,m+0.1165),Vector3(0.011,0.0045,0.025),"rpg_alu",0.0012)
	Models.bevel(root,Vector3(0,-0.0712,m+0.1063),Vector3(0.011,0.0045,0.009),"rpg_alu",0.0012).rotation.x=-0.8
	Models.bevel(root,Vector3(0,-0.038,m+0.1215),Vector3(0.0055,0.022,0.0042),"gun_metal",0.0008).rotation.x=0.18
	Models.bevel(root,Vector3(0,-0.0555,m+0.1178),Vector3(0.0055,0.016,0.0042),"gun_metal",0.0008).rotation.x=-0.35
	# Cross-bolt safety above the grip, housing screws, stamped data lines.
	cyl(root,Vector3(0,-0.032,m+0.152),0.0042,0.0265,"gun_metal",Vector3.RIGHT,12)
	for side in [-1,1]:
		for p in [Vector2(-0.0205,m+0.112),Vector2(-0.0205,m+0.180),Vector2(-0.050,m+0.170),Vector2(-0.066,m+0.140),Vector2(-0.045,m+0.137)]:pin(root,Vector3(side*0.0102,p.x,p.y),0.0022)
		for i in range(3):Models.bevel(root,Vector3(side*0.0101,-0.041-i*0.0045,m+0.156),Vector3(0.0004,0.0014,0.012-i*0.003),"gun_recess",0.0001)
	# Hammer: pivots inside the housing, the serrated spur sticks out behind it.
	var hammer := Models.group(root,"Hammer",HAMMER_PIVOT)
	Models.bevel(hammer,Vector3(0,0.0075,0.0),Vector3(0.007,0.017,0.008),"gun_metal",0.001)
	var tilt := Basis(Vector3.RIGHT,-0.18)
	var spur_at := Vector3(0,-0.002,0.0235)
	Models.bevel(hammer,spur_at,Vector3(0.0085,0.0065,0.029),"gun_metal",0.001).rotation.x=-0.18
	for i in range(4):Models.bevel(hammer,spur_at+tilt*Vector3(0,0.0033,0.004+i*0.0032),Vector3(0.0088,0.0008,0.0011),"gun_recess",0.0002).rotation.x=-0.18
	cyl(hammer,Vector3.ZERO,0.0035,0.0235,"gun_edge",Vector3.RIGHT,10)
	Models.merge_rigid(hammer)

static func grips(root: Node3D, m: float) -> void:
	# Lofted wooden grips raked slightly towards the muzzle, as on the real launcher.
	var front := WeaponArt.loft(root,[Vector4(0.0,0.0,0.026,0.045),Vector4(-0.001,0.007,0.0305,0.045),Vector4(-0.006,0.046,0.031,0.042),Vector4(-0.0115,0.083,0.0295,0.039),Vector4(-0.0125,0.0885,0.026,0.034)],"rpg_grip",0.42)
	front.position=Vector3(0,-0.075,m+0.1445)
	front.rotation.x=PI/2
	var rear := WeaponArt.loft(root,[Vector4(0.0,0.0,0.028,0.054),Vector4(-0.001,0.010,0.031,0.045),Vector4(-0.005,0.052,0.031,0.042),Vector4(-0.0095,0.089,0.0295,0.039),Vector4(-0.0105,0.0945,0.026,0.034)],"rpg_grip",0.42)
	rear.position=Vector3(0,-0.027,m+0.305)
	rear.rotation.x=PI/2
	for side in [-1,1]:
		pin(root,Vector3(side*0.0156,-0.120,m+0.138),0.0034)
		pin(root,Vector3(side*0.0156,-0.074,m+0.299),0.0034)

static func pgo7(root: Node3D) -> void:
	var x := EYEPIECE.x
	var y := EYEPIECE.y
	# Body with a raised top deck; the optical axis runs through its upper part.
	var body := WeaponArt.loft(root,[Vector4(0.045,-0.079,0.039,0.052),Vector4(0.044,-0.073,0.046,0.064),Vector4(0.044,0.021,0.046,0.064),Vector4(0.045,0.028,0.040,0.054)],"gun_metal",0.3)
	body.position.x=x
	Models.bevel(root,Vector3(x,0.0765,-0.027),Vector3(0.034,0.004,0.074),"gun_metal",0.0015)
	for side in [-1,1]:Models.bevel(root,Vector3(x+side*0.0231,0.044,-0.026),Vector3(0.001,0.050,0.080),"gun_edge",0.0004)
	# Objective with its lens and the sun hood.
	cyl(root,Vector3(x,y,-0.0845),0.0178,0.012,"gun_metal",Vector3.BACK,20)
	lathe(root,[Vector2(-0.0925,0.0186),Vector2(-0.1125,0.0188),Vector2(-0.1125,0.0208),Vector2(-0.0905,0.0208),Vector2(-0.0905,0.0176)],"gun_metal",24,false,Vector3(x,y,0))
	cyl(root,Vector3(x,y,-0.0925),0.0187,0.001,"rpg_glass",Vector3.BACK,20)
	# Eyepiece and the soft rubber eyecup; its rear face is EYEPIECE.
	cyl(root,Vector3(x,y,0.0345),0.0158,0.014,"gun_metal",Vector3.BACK,20)
	lathe(root,[Vector2(0.041,0.0162),Vector2(0.052,0.0176),Vector2(0.064,0.0196),Vector2(0.0735,0.0213),Vector2(0.075,0.0207),Vector2(0.075,0.0176),Vector2(0.0735,0.0166),Vector2(0.060,0.0149),Vector2(0.046,0.0137)],"gun_rubber",28,false,Vector3(x,y,0))
	cyl(root,Vector3(x,y,0.047),0.0138,0.001,"rpg_glass",Vector3.BACK,20)
	# Elevation handwheel with a knurled rim and white index marks.
	var wheel := Vector3(x+0.003,0.0835,-0.040)
	cyl(root,wheel,0.0128,0.010,"gun_metal",Vector3.UP,20)
	cyl(root,wheel+Vector3(0,0.0055,0),0.0105,0.0015,"gun_edge",Vector3.UP,20)
	for i in range(12):
		var a := TAU*i/12
		Models.bevel(root,wheel+Vector3(cos(a)*0.0128,0,sin(a)*0.0128),Vector3(0.0016,0.009,0.0016),"gun_edge",0.0003).rotation.y=-a
	for i in range(6):
		var a := PI*0.35+i*0.26
		Models.bevel(root,wheel+Vector3(cos(a)*0.0089,0.0064,sin(a)*0.0089),Vector3(0.0034,0.0004,0.0006),"white",0.0001).rotation.y=-a
	# Reticle lamp switch and battery cap on the left side.
	cyl(root,Vector3(x-0.0245,0.032,-0.012),0.0085,0.007,"gun_metal",Vector3.RIGHT,16)
	cyl(root,Vector3(x-0.0285,0.032,-0.012),0.0065,0.002,"gun_edge",Vector3.RIGHT,16)
	Models.bevel(root,Vector3(x-0.0245,0.058,-0.052),Vector3(0.004,0.008,0.012),"gun_metal",0.001)
	pin(root,Vector3(x-0.0235,0.060,0.008),0.003)
	# Clamp onto the launcher's bracket plate, with its locking lever.
	Models.bevel(root,Vector3(-0.0435,0.005,-0.040),Vector3(0.011,0.034,0.088),"gun_metal",0.002)
	cyl(root,Vector3(-0.051,-0.004,-0.040),0.006,0.006,"gun_edge",Vector3.RIGHT,12)
	Models.bevel(root,Vector3(-0.055,-0.014,-0.040),Vector3(0.004,0.022,0.007),"gun_metal",0.001).rotation.x=0.3

static func sling(root: Node3D, m: float) -> void:
	# Rear swivel under the nozzle coupling; the webbing runs close along the left side.
	Models.bevel(root,Vector3(-0.012,-0.029,m+0.751),Vector3(0.007,0.008,0.010),"gun_metal",0.0015)
	ring(root,Vector3(-0.016,-0.038,m+0.751),0.0085,0.0062,"gun_edge",Vector3.RIGHT)
	strap(root,[Vector3(-0.031,-0.012,m+0.092),Vector3(-0.036,-0.032,m+0.20),Vector3(-0.039,-0.046,m+0.36),Vector3(-0.035,-0.049,m+0.52),Vector3(-0.027,-0.045,m+0.66),Vector3(-0.019,-0.044,m+0.745)],0.024,"gear_#6b6440")

# PG-7VL alone, nose along -Z. Origin: the joint between the head's nozzle ring and
# the 40 mm motor, i.e. the point that sits on the muzzle face when loaded.
static func grenade(with_charge: bool=true, fins_open: bool=false) -> Node3D:
	register_materials()
	var root := Node3D.new()
	root.name="PG7VL"
	# Piezo nose fuze, long conical ogive, seam, body and boat tail of the 93 mm head.
	lathe(root,[Vector2(-0.385,0.0),Vector2(-0.3846,0.0035),Vector2(-0.3832,0.0066),Vector2(-0.3805,0.0088),Vector2(-0.3770,0.0098),Vector2(-0.3565,0.0100),Vector2(-0.3555,0.0108)],"rpg_alu",16)
	lathe(root,[Vector2(-0.3555,0.0104),Vector2(-0.335,0.0142),Vector2(-0.305,0.0205),Vector2(-0.270,0.0282),Vector2(-0.235,0.0356),Vector2(-0.205,0.0415),Vector2(-0.188,0.0446),Vector2(-0.1775,0.0463),Vector2(-0.1765,0.0465),Vector2(-0.1757,0.0456),Vector2(-0.1743,0.0456),Vector2(-0.1735,0.0465),Vector2(-0.150,0.0462),Vector2(-0.122,0.0450),Vector2(-0.100,0.0428),Vector2(-0.086,0.0398),Vector2(-0.076,0.0358),Vector2(-0.069,0.0315),Vector2(-0.0655,0.0283),Vector2(-0.0645,0.0246),Vector2(-0.0325,0.0246),Vector2(-0.0315,0.0228)],"rpg_olive",28)
	# Stencilled lot data on both sides of the body.
	for a in [0.0,PI]:
		for i in range(3):
			var span := 0.030-i*0.008
			lathe(root,[Vector2(-0.160,0.04655),Vector2(-0.160+span,0.04655-span*0.043)],"rpg_stencil",2,false,Vector3.ZERO,Vector2(a-0.15+i*0.10,a-0.125+i*0.10))
	# Sustainer nozzle ring: six rounded, canted nozzles just ahead of the muzzle.
	lathe(root,[Vector2(-0.0315,0.0214),Vector2(-0.030,0.0226),Vector2(-0.0065,0.0226),Vector2(-0.0045,0.0212),Vector2(0.0,0.0205)],"rpg_motor",24)
	for i in range(6):
		var a := TAU*(i+0.5)/6
		var radial := Vector3(cos(a),sin(a),0)
		var axis := (radial*0.45+Vector3.BACK).normalized()
		var nozzle := lathe(root,[Vector2(-0.0075,0.0),Vector2(-0.0072,0.0042),Vector2(-0.0050,0.0060),Vector2(0.0065,0.0064),Vector2(0.0065,0.0046),Vector2(0.0030,0.0038)],"rpg_motor",10)
		nozzle.transform=Transform3D(along(axis),radial*0.0222+Vector3(0,0,-0.014))
	# 40 mm motor with aluminium joint bands.
	lathe(root,[Vector2(0.0,0.0195),Vector2(0.230,0.0195),Vector2(0.2315,0.0150),Vector2(0.2325,0.0095)],"rpg_motor",20)
	for z in [0.0,0.146,0.195]:lathe(root,[Vector2(z,0.0195),Vector2(z+0.0005,0.0199),Vector2(z+0.0055,0.0199),Vector2(z+0.006,0.0195)],"rpg_alu",20)
	if not with_charge or fins_open:
		# Stabiliser tube, hinge ring, four blades and the small spinning tail unit.
		cyl(root,Vector3(0,0,0.365),0.0085,0.270,"gun_metal",Vector3.BACK,12)
		cyl(root,Vector3(0,0,0.500),0.0115,0.012,"gun_metal",Vector3.BACK,12)
		for i in range(4):
			var outline := PackedVector2Array([Vector2(0.474,0.0100),Vector2(0.505,0.0100),Vector2(0.513,0.095),Vector2(0.497,0.095)]) if fins_open else PackedVector2Array([Vector2(0.402,0.0092),Vector2(0.505,0.0092),Vector2(0.505,0.0180),Vector2(0.406,0.0180)])
			slab(root,outline,0.0016,"gun_metal").rotation.z=TAU*i/4+PI/4-PI/2
		lathe(root,[Vector2(0.506,0.0),Vector2(0.506,0.0100),Vector2(0.531,0.0100),Vector2(0.533,0.0080),Vector2(0.533,0.0055),Vector2(0.525,0.0050)],"gun_metal",12)
		for i in range(4):slab(root,PackedVector2Array([Vector2(0.508,0.0095),Vector2(0.530,0.0095),Vector2(0.530,0.0175),Vector2(0.512,0.0175)]),0.0012,"gun_metal").rotation.z=TAU*i/4-PI/2
	if with_charge:
		# PG-7P expelling charge: paper-cased cylinder over the folded stabiliser.
		lathe(root,[Vector2(0.226,0.0196),Vector2(0.227,0.0201),Vector2(0.246,0.0201),Vector2(0.247,0.0196)],"rpg_alu",20)
		lathe(root,[Vector2(0.2465,0.0193),Vector2(0.600,0.0193),Vector2(0.6035,0.0187),Vector2(0.605,0.0170),Vector2(0.605,0.0)],"rpg_charge",20)
		for z in [0.300,0.320]:lathe(root,[Vector2(z,0.0194),Vector2(z+0.004,0.0194)],"rpg_stencil",20)
		cyl(root,Vector3(0,0,0.6052),0.0045,0.0008,"rpg_alu",Vector3.BACK,10)
	Models.merge_rigid(root)
	return root

static func register_materials() -> void:
	if Models.materials.has("rpg_wood"):return
	# Red-brown lacquered birch plywood, grain along the tube.
	var wood := Models.surface("wood").duplicate() as StandardMaterial3D
	wood.resource_name="rpg_wood"
	wood.albedo_color=Color("923424")
	wood.roughness=0.55
	Models.materials["rpg_wood"]=wood
	# Grip panels: same wood with the fine checkering normal map.
	var grip := Models.surface("gun_grip").duplicate() as StandardMaterial3D
	grip.resource_name="rpg_grip"
	grip.albedo_color=Color("8e3b27")
	grip.roughness=0.7
	Models.materials["rpg_grip"]=grip
	var alu := Models.surface("gun_edge").duplicate() as StandardMaterial3D
	alu.resource_name="rpg_alu"
	alu.albedo_color=Color("cfd3d1")
	alu.roughness=0.45
	Models.materials["rpg_alu"]=alu
	var bell := Models.surface("gun_metal").duplicate() as StandardMaterial3D
	bell.resource_name="rpg_bell"
	bell.albedo_color=Color("3a4442")
	Models.materials["rpg_bell"]=bell
	var bore := Models.surface("gun_metal").duplicate() as StandardMaterial3D
	bore.resource_name="rpg_bore"
	bore.albedo_color=Color("1e2224")
	Models.materials["rpg_bore"]=bore
	for spec in [["rpg_olive","5f5b33",0.0,0.78],["rpg_motor","4f5232",0.1,0.74],["rpg_charge","6f6d45",0.0,0.95],["rpg_stencil","1b1c18",0.0,0.9],["rpg_glass","0d1719",0.35,0.06]]:
		var mat := StandardMaterial3D.new()
		mat.resource_name=spec[0]
		mat.albedo_color=Color(spec[1])
		mat.metallic=spec[2]
		mat.roughness=spec[3]
		Models.materials[spec[0]]=mat

# --- Mesh helpers (also used by the RPG-22 model) ---

# Surface of revolution about the Z axis. profile: Vector2(z, radius) points; the
# outside lies to the left of travel, so outer walls run towards +Z and bores
# back towards -Z. Normals are smoothed across bends whose normals agree more
# than `smooth` (cosine). arc limits the sweep (radians from +X towards +Y).
static func lathe(parent: Node3D, profile: Array, key: String, segments: int=24, caps: bool=false, offset: Vector3=Vector3.ZERO, arc: Vector2=Vector2(0,TAU), smooth: float=0.77) -> MeshInstance3D:
	if Models.lite and segments>8:segments=maxi(8,segments/2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := profile.size()
	var normals: Array[Vector2]=[]
	for k in range(count-1):
		var t: Vector2=(profile[k+1]-profile[k]).normalized()
		normals.append(Vector2(-t.y,t.x))
	var ring_dirs: Array[Vector2]=[]
	for i in range(segments+1):
		var angle := lerpf(arc.x,arc.y,float(i)/segments)
		ring_dirs.append(Vector2(cos(angle),sin(angle)))
	for k in range(count-1):
		var a: Vector2=profile[k]
		var b: Vector2=profile[k+1]
		if a.is_equal_approx(b) or (a.y<0.00001 and b.y<0.00001):continue
		var na: Vector2=normals[k]
		var nb: Vector2=normals[k]
		if k>0 and normals[k-1].dot(normals[k])>smooth:na=(normals[k-1]+normals[k]).normalized()
		if k<count-2 and normals[k+1].dot(normals[k])>smooth:nb=(normals[k+1]+normals[k]).normalized()
		for i in range(segments):
			var u := ring_dirs[i]
			var w := ring_dirs[i+1]
			var quad := [[Vector3(u.x*a.y,u.y*a.y,a.x),Vector3(u.x*na.y,u.y*na.y,na.x)],[Vector3(u.x*b.y,u.y*b.y,b.x),Vector3(u.x*nb.y,u.y*nb.y,nb.x)],[Vector3(w.x*a.y,w.y*a.y,a.x),Vector3(w.x*na.y,w.y*na.y,na.x)],[Vector3(w.x*b.y,w.y*b.y,b.x),Vector3(w.x*nb.y,w.y*nb.y,nb.x)]]
			# Skip the degenerate half of quads that touch the axis.
			var order: Array=[]
			if a.y>=0.00001:order.append_array([0,1,2])
			if b.y>=0.00001:order.append_array([2,1,3])
			for index in order:
				st.set_normal(quad[index][1])
				st.add_vertex(quad[index][0]+offset)
	if caps:
		for end in [0,count-1]:
			var p: Vector2=profile[end]
			if p.y<0.00001:continue
			var travel: float=profile[1].x-profile[0].x if end==0 else profile[end].x-profile[end-1].x
			var normal := Vector3(0,0,-signf(travel) if end==0 else signf(travel))
			for i in range(segments):
				var u := ring_dirs[i]
				var w := ring_dirs[i+1]
				face(st,[Vector3(0,0,p.x)+offset,Vector3(u.x*p.y,u.y*p.y,p.x)+offset,Vector3(w.x*p.y,w.y*p.y,p.x)+offset],normal)
	st.index()
	return Models.mesh_node(parent,st.commit(),Vector3.ZERO,key)

# Basis whose Z axis points along `axis`.
static func along(axis: Vector3) -> Basis:
	var z := axis.normalized()
	var x := (Vector3.UP if absf(z.y)<0.9 else Vector3.RIGHT).cross(z).normalized()
	return Basis(x,z.cross(x),z)

# Capped (optionally tapered) cylinder with few facets; end_radius is at the +axis end.
static func cyl(parent: Node3D, center: Vector3, radius: float, length: float, key: String, axis: Vector3=Vector3.BACK, segments: int=12, end_radius: float=-1.0) -> MeshInstance3D:
	var node := lathe(parent,[Vector2(-length/2,0.0),Vector2(-length/2,radius),Vector2(length/2,radius if end_radius<0 else end_radius),Vector2(length/2,0.0)],key,segments)
	node.transform=Transform3D(along(axis),center)
	return node

# Torus of the given outer/inner radii lying across `axis`.
static func ring(parent: Node3D, center: Vector3, outer: float, inner: float, key: String, axis: Vector3=Vector3.BACK, segments: int=18) -> MeshInstance3D:
	var profile: Array=[]
	for i in range(9):
		var t := TAU*i/8
		profile.append(Vector2((outer-inner)*0.5*sin(t),(outer+inner)*0.5+(outer-inner)*0.5*cos(t)))
	var node := lathe(parent,profile,key,segments,false,Vector3.ZERO,Vector2(0,TAU),0.5)
	node.transform=Transform3D(along(axis),center)
	return node

# Screw or pin head facing sideways (X).
static func pin(parent: Node3D, center: Vector3, radius: float) -> void:
	cyl(parent,center,radius,0.0012,"gun_edge",Vector3.RIGHT,10)

# Flat-shaded extrusion along X of an outline given as Vector2(z, y) points.
static func slab(parent: Node3D, outline: PackedVector2Array, width: float, key: String, x: float=0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := width*0.5
	var triangles := Geometry2D.triangulate_polygon(outline)
	for side in [-1.0,1.0]:
		for i in range(0,triangles.size(),3):
			var points: Array=[]
			for j in range(3):
				var p := outline[triangles[i+j]]
				points.append(Vector3(side*h,p.y,p.x))
			face(st,points,Vector3(side,0,0))
	var area := 0.0
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		area+=a.x*b.y-b.x*a.y
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		var out := Vector2(b.y-a.y,a.x-b.x).normalized()*signf(area)
		var normal := Vector3(0,out.y,out.x)
		face(st,[Vector3(-h,a.y,a.x),Vector3(h,a.y,a.x),Vector3(-h,b.y,b.x)],normal)
		face(st,[Vector3(-h,b.y,b.x),Vector3(h,a.y,a.x),Vector3(h,b.y,b.x)],normal)
	st.index()
	return Models.mesh_node(parent,st.commit(),Vector3(x,0,0),key)

# One flat triangle; Godot's front faces wind clockwise seen from outside.
static func face(st: SurfaceTool, points: Array, normal: Vector3) -> void:
	var a: Vector3=points[0]
	var b: Vector3=points[1]
	var c: Vector3=points[2]
	if (b-a).cross(c-a).dot(normal)>0:
		var swap := b
		b=c
		c=swap
	for p in [a,b,c]:
		st.set_normal(normal)
		st.add_vertex(p)

# Webbing strap through a list of points, broad face sideways.
static func strap(parent: Node3D, points: Array, width: float, key: String) -> void:
	for i in range(points.size()-1):
		var a: Vector3=points[i]
		var b: Vector3=points[i+1]
		var dir := a.direction_to(b)
		var side := (Vector3.RIGHT-dir*dir.x).normalized()
		var node := Models.bevel(parent,Vector3.ZERO,Vector3(0.0025,width,a.distance_to(b)+0.004),key,0.0008)
		node.transform=Transform3D(Basis(side,dir.cross(side),dir),(a+b)*0.5)

# Moves a posed sub-assembly's meshes into its parent so merge_rigid can combine them.
static func bake(group: Node3D) -> void:
	var parent := group.get_parent() as Node3D
	for child in group.get_children():
		if child is MeshInstance3D:
			var placed: Transform3D=group.transform*child.transform
			group.remove_child(child)
			parent.add_child(child)
			child.transform=placed
	group.free()
