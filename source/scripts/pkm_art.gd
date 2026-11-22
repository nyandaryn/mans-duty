class_name PkmArt
extends RefCounted

# PKM (GRAU 6P6M) 7.62x54R general-purpose machine gun: original game-ready mesh.
# Metres; bore on the Z axis, muzzle toward -Z, +Y up, +X is the gun's right.
#
# Reference data:
#  - Length 1192 mm (PKM; PK 1173 mm), barrel 605 mm / 658 mm with the flash
#    hider, sight radius 663 mm, empty mass 7.5 kg, 650 rpm. Open bolt, belt fed
#    from the right only, cases ejected to the left through a spring dust cover.
#    Feed cover hinged at the front. Rear sight graduated 1-15 (100-1500 m) with
#    windage; hooded post front sight. Quick-change barrel with carrying handle,
#    gas regulator, folding bipod on the gas cylinder, slotted flash hider,
#    skeleton butt with hinged shoulder rest, 100-round box clamped under the
#    receiver (cartridges lie parallel to the bore, belt rises up the right side).
#    Sources: en.wikipedia.org/wiki/PK_machine_gun, ru.wikipedia.org/wiki/
#    Пулемёт_Калашникова, modernfirearms.net (Kalashnikov PK/PKM), Small Arms
#    Survey PK weapon sheet.
#  - Proportions measured from the orthographic studio profile on Wikimedia
#    Commons "File:PKM 7.62×54mmR machine gun.png" (3500 px scaled to 1192 mm),
#    checked against "File:7,62 KK PKM Helsinki 2012.JPG" and "File:PK machine
#    gun.jpg": butt to receiver 285 mm, receiver 355 mm, grip top centre 330 mm
#    from the butt, rear sight 425 mm, front post 1088 mm, both sight tops about
#    62-66 mm above the bore, receiver -45..+55 mm about the bore, barrel
#    23 -> 20 mm, gas cylinder 29 mm under the bore, folded bipod about 280 mm,
#    100-round box about 97 (along the bore) x 130 x 165 mm.
#  - Layout follows the real gun: the rear sight sits on the fixed receiver top
#    just behind the feed cover, 85 mm ahead of the pistol grip.

const SIGHT_HEIGHT := 0.062
const REAR_Z := -0.005
const SIGHT_RADIUS := 0.663
const FRONT_Z := REAR_Z-SIGHT_RADIUS
const MUZZLE_Z := -0.772
const EYE_RELIEF := 0.19
const SIGHT_TRAVEL := 0.016
const COVER_HINGE := Vector3(0,0.030,-0.163)
const BIPOD_HINGE := Vector3(0,-0.056,-0.445)
const HANDLE_PIVOT := Vector3(0,0,-0.229)
const FURNITURE := "gun_polymer"
const BOX_PAINT := "#4f5b3b"
# Belt rounds: rim face of every round in the belt lies at this Z.
const RIM_Z := -0.068
const BELT_PITCH := 0.0145

static func build(root: Node3D, mag: Node3D, bolt: Node3D) -> void:
	root.set_meta("sight_height",SIGHT_HEIGHT)
	root.set_meta("rear_z",REAR_Z)
	root.set_meta("front_z",FRONT_Z)
	root.set_meta("muzzle_z",MUZZLE_Z)
	root.set_meta("eye_relief",EYE_RELIEF)
	root.set_meta("magwell",Vector3(0,-0.060,-0.1085))
	root.set_meta("support_hand",Vector3(-0.015,-0.098,-0.33))
	root.set_meta("stock_hand",Vector3(-0.012,-0.118,0.305))
	root.set_meta("charging_handle",Vector3(0.041,-0.047,-0.033))
	root.set_meta("ejection_port",Vector3(-0.025,-0.023,-0.039))
	receiver(root)
	sights(root)
	feed_cover(root)
	controls(root,bolt)
	stock(root)
	barrel(root)
	carry_handle(root)
	bipod(root)
	box(mag)
	belt_rounds(Models.group(mag,"Belt"))

# Stamped receiver body, fixed top with the rear sight, feed tray and trunnion.
static func receiver(root: Node3D) -> void:
	Models.bevel(root,Vector3(0,-0.0187,-0.039),Vector3(0.046,0.0525,0.348),"gun_metal",0.0015)
	block(root,Vector3(0,-0.0445,-0.039),Vector3(0.0472,0.003,0.344),"gun_edge")
	block(root,Vector3(0,0.0055,-0.039),Vector3(0.0468,0.003,0.344),"gun_edge")
	Models.bevel(root,Vector3(0,-0.016,0.1375),Vector3(0.044,0.058,0.005),"gun_edge",0.0012)
	# Fixed rear top: rounded back, stamped ribs, rear sight base on top.
	var top := PackedVector3Array([Vector3(0.134,0.0075,0),Vector3(0.134,0.036,0.006),Vector3(0.118,0.044,0.006),Vector3(-0.0125,0.044,0.001),Vector3(-0.0125,0.0075,0)])
	slab(root,fillet(top),0.044,"gun_metal",0.0035,PackedVector2Array(),0.0,false)
	for side in [-1,1]:
		block(root,Vector3(side*0.0222,0.027,0.058),Vector3(0.0016,0.004,0.13),"gun_metal")
		block(root,Vector3(side*0.0222,0.016,0.062),Vector3(0.0016,0.003,0.118),"gun_metal")
	# Stamped side panels: rivets, reinforcement strips and the trunnion rivets.
	for side in [-1,1]:
		for yz in [Vector2(-0.003,0.128),Vector2(-0.003,0.113),Vector2(-0.027,0.113),Vector2(-0.040,0.128),Vector2(-0.003,-0.111),Vector2(-0.003,-0.126),Vector2(-0.021,-0.118),Vector2(-0.040,-0.118),Vector2(-0.003,-0.197),Vector2(-0.033,-0.197),Vector2(-0.040,0.050),Vector2(-0.040,0.004)]:
			rivet(root,side*0.0232,yz.x,yz.y)
		block(root,Vector3(side*0.0233,-0.040,-0.165),Vector3(0.001,0.006,0.075),"gun_metal")
	# Trunnion front plate, barrel shank and the cover hinge lugs.
	Models.bevel(root,Vector3(0,-0.018,-0.2135),Vector3(0.044,0.050,0.003),"gun_edge",0.001)
	rod(root,Vector3(0,0,-0.191),0.0145,0.042,"gun_metal",Vector3.FORWARD,16)
	Models.bevel(root,Vector3(0,0.009,-0.191),Vector3(0.034,0.006,0.042),"gun_metal",0.002)
	for side in [-1,1]:
		Models.bevel(root,Vector3(side*0.0195,0.020,-0.163),Vector3(0.008,0.024,0.013),"gun_metal",0.0015)
		rod(root,Vector3(side*0.0195,0.030,-0.163),0.0052,0.008,"gun_metal",Vector3.RIGHT,12)
		rod(root,Vector3(side*0.0245,0.030,-0.163),0.003,0.002,"gun_edge",Vector3.RIGHT,8)
	# Feed tray: cartridge platform, stops and the right-hand belt inlet lip.
	block(root,Vector3(0,0.0085,-0.108),Vector3(0.042,0.002,0.094),"gun_edge")
	for z in [-0.153,-0.064]:Models.bevel(root,Vector3(0,0.013,z),Vector3(0.036,0.008,0.003),"gun_metal",0.0008)
	block(root,Vector3(0.0285,0.0085,-0.108),Vector3(0.011,0.002,0.092),"gun_edge")
	for z in [-0.145,-0.072]:block(root,Vector3(0.0275,0.0035,z),Vector3(0.008,0.009,0.004),"gun_metal")
	# Left side: ejection port with its spring dust cover and hinge rod.
	block(root,Vector3(-0.0232,-0.023,-0.039),Vector3(0.001,0.027,0.093),"gun_recess")
	Models.bevel(root,Vector3(-0.0238,-0.0235,-0.039),Vector3(0.0016,0.023,0.088),"gun_edge",0.001)
	rod(root,Vector3(-0.0242,-0.0085,-0.040),0.0016,0.13,"gun_edge",Vector3.FORWARD,6)
	# Barrel latch on the left front, lower trunnion and the box bracket.
	Models.bevel(root,Vector3(-0.0248,-0.012,-0.195),Vector3(0.003,0.022,0.024),"gun_metal",0.001)
	rivet(root,-0.0265,-0.006,-0.195,0.003)
	Models.bevel(root,Vector3(0,-0.0515,-0.1085),Vector3(0.034,0.013,0.094),"gun_metal",0.0015)
	for side in [-1,1]:
		block(root,Vector3(side*0.0185,-0.0565,-0.1085),Vector3(0.004,0.004,0.090),"gun_edge")
		for z in [-0.14,-0.077]:rivet(root,side*0.0172,-0.051,z,0.002)

# Rear frame sight on the fixed receiver top, hooded front post near the muzzle.
static func sights(root: Node3D) -> void:
	# Base, rear hinge block, folded leaf, latch knob and windage drum.
	Models.bevel(root,Vector3(0,0.047,0.027),Vector3(0.024,0.006,0.078),"gun_metal",0.0012)
	Models.bevel(root,Vector3(0,0.0515,0.062),Vector3(0.016,0.012,0.012),"gun_metal",0.0015)
	rod(root,Vector3(0,0.053,0.062),0.0025,0.0175,"gun_edge",Vector3.RIGHT,8)
	Models.bevel(root,Vector3(0,0.0525,0.032),Vector3(0.012,0.004,0.058),"gun_edge",0.0008).rotation.x=0.07
	rod(root,Vector3(-0.0080,0.0555,0.030),0.0052,0.004,"gun_metal",Vector3.RIGHT,12)
	rod(root,Vector3(-0.0102,0.0555,0.030),0.0036,0.001,"gun_edge",Vector3.RIGHT,10)
	rod(root,Vector3(0.0128,0.052,REAR_Z),0.0018,0.003,"gun_edge",Vector3.RIGHT,6)
	rod(root,Vector3(0.0147,0.052,REAR_Z),0.0048,0.004,"gun_metal",Vector3.RIGHT,12)
	for i in range(10):
		var angle := TAU*i/10
		block(root,Vector3(0.0149,0.052+sin(angle)*0.0048,REAR_Z+cos(angle)*0.0048),Vector3(0.0036,0.0009,0.0009),"gun_edge").rotation.x=-angle
	# Frame cheeks with stamped graduations 1-15; the slider rides between them.
	for side in [-1,1]:
		Models.bevel(root,Vector3(side*0.0105,0.064,REAR_Z),Vector3(0.003,0.038,0.0115),"gun_metal",0.0006)
		for k in range(15):
			var y := SIGHT_HEIGHT-0.009+k*SIGHT_TRAVEL/14.0
			var major := k%5==4 or k==0
			block(root,Vector3(side*0.0121,y,REAR_Z),Vector3(0.0004,0.0003,0.008 if major else 0.005),"gun_recess")
			block(root,Vector3(side*(0.0105 if major else 0.0112),y,REAR_Z+0.0058),Vector3(0.003 if major else 0.0016,0.0003,0.0004),"white" if major else "gun_recess")
	Models.bevel(root,Vector3(0,0.0845,REAR_Z),Vector3(0.024,0.003,0.0115),"gun_metal",0.0008)
	var slider := Models.group(root,"RearSightSlider",Vector3(0,SIGHT_HEIGHT,REAR_Z))
	Models.notch(slider,0.0,0.0,0.0175,0.0045)
	Models.bevel(slider,Vector3(0,-0.0145,0),Vector3(0.0175,0.005,0.0095),"gun_metal",0.0008)
	Models.bevel(slider,Vector3(0,-0.0125,0.0068),Vector3(0.025,0.007,0.0016),"gun_metal",0.0005)
	Models.bevel(slider,Vector3(0,-0.0125,-0.0068),Vector3(0.025,0.007,0.0016),"gun_metal",0.0005)
	# Front sight: barrel band, open tower, windage drum, post and two ears.
	rod(root,Vector3(0,0,FRONT_Z+0.0025),0.0135,0.033,"gun_metal",Vector3.FORWARD,20)
	for side in [-1,1]:rivet(root,side*0.0136,-0.004,FRONT_Z+0.0025,0.0026)
	var tower := PackedVector3Array([Vector3(FRONT_Z+0.019,0.008,0.001),Vector3(FRONT_Z+0.004,0.046,0.003),Vector3(FRONT_Z-0.015,0.046,0.003),Vector3(FRONT_Z-0.015,0.008,0.001)])
	var window := PackedVector3Array([Vector3(FRONT_Z+0.009,0.014,0.002),Vector3(FRONT_Z-0.001,0.036,0.003),Vector3(FRONT_Z-0.009,0.036,0.002),Vector3(FRONT_Z-0.009,0.014,0.002)])
	slab(root,fillet(tower),0.012,"gun_metal",0.0015,fillet(window),0.0,false)
	rod(root,Vector3(0,0.044,FRONT_Z),0.0052,0.013,"gun_metal",Vector3.RIGHT,12)
	for side in [-1,1]:rod(root,Vector3(side*0.0067,0.044,FRONT_Z),0.0028,0.001,"gun_edge",Vector3.RIGHT,8)
	Models.bevel(root,Vector3(0,(0.044+SIGHT_HEIGHT)/2,FRONT_Z),Vector3(0.0024,SIGHT_HEIGHT-0.044,0.003),"gun_metal",0.0002)
	Models.bevel(root,Vector3(0,0.039,FRONT_Z),Vector3(0.025,0.006,0.012),"gun_metal",0.001)
	for side in [-1,1]:
		var ear := Models.bevel(root,Vector3(side*0.0108,0.054,FRONT_Z),Vector3(0.0026,0.032,0.010),"gun_metal",0.0008)
		ear.rotation.z=side*0.06

# Hinged feed cover: pivot on the front hinge, rear lifts (negative rotation.x).
static func feed_cover(root: Node3D) -> void:
	var cover := Models.group(root,"FeedCover",COVER_HINGE)
	var h := COVER_HINGE
	var hump := PackedVector3Array([Vector3(-0.1695,0.016,0.004),Vector3(-0.1695,0.047,0.004),Vector3(-0.163,0.055,0.006),Vector3(-0.020,0.055,0.006),Vector3(-0.0135,0.049,0.004),Vector3(-0.0135,0.0075,0),Vector3(-0.152,0.0075,0.006)])
	var outline := PackedVector2Array()
	for p in fillet(hump):outline.append(p-Vector2(h.z,h.y))
	slab(cover,outline,0.049,"gun_metal",0.004,PackedVector2Array(),0.0,false)
	Models.bevel(cover,Vector3(0,0.0575,-0.128)-h,Vector3(0.030,0.006,0.065),"gun_metal",0.002)
	for z in [-0.152,-0.106]:rod(cover,Vector3(0,0.0606,z)-h,0.0024,0.0012,"gun_edge",Vector3.UP,8)
	block(cover,Vector3(0,0.0558,-0.057)-h,Vector3(0.006,0.0016,0.066),"gun_edge")
	for side in [-1,1]:
		block(cover,Vector3(side*0.0247,0.039,-0.088)-h,Vector3(0.0016,0.004,0.135),"gun_metal")
		block(cover,Vector3(side*0.0247,0.0475,-0.040)-h,Vector3(0.0016,0.003,0.040),"gun_metal")
	# Left feed-slide housing, right belt window, rear latch, hinge knuckle.
	Models.bevel(cover,Vector3(-0.0252,0.030,-0.116)-h,Vector3(0.002,0.020,0.052),"gun_edge",0.001)
	for z in [-0.136,-0.096]:rivet(cover,-0.0264,0.030-h.y,z-h.z,0.0022)
	block(cover,Vector3(0.0246,0.0195,-0.108)-h,Vector3(0.001,0.021,0.090),"gun_recess")
	Models.bevel(cover,Vector3(-0.0255,0.042,-0.021)-h,Vector3(0.004,0.009,0.010),"gun_edge",0.001)
	rod(cover,Vector3.ZERO,0.0052,0.031,"gun_metal",Vector3.RIGHT,12)
	# Underside: feed slide and the two belt pawls, seen when the cover is up.
	block(cover,Vector3(0,0.0055,-0.105)-h,Vector3(0.034,0.004,0.070),"gun_edge")
	for x in [-0.008,0.008]:block(cover,Vector3(x,0.0025,-0.083)-h,Vector3(0.004,0.004,0.012),"gun_metal")

# Pistol grip, trigger group, safety, charging handle and the visible carrier.
static func controls(root: Node3D, bolt: Node3D) -> void:
	Models.bevel(root,Vector3(0,-0.0515,0.062),Vector3(0.030,0.013,0.13),"gun_metal",0.0015)
	var grip := PackedVector3Array([Vector3(0.0565,-0.052,0.001),Vector3(0.0615,-0.066,0.004),Vector3(0.0655,-0.081,0.005),Vector3(0.0745,-0.104,0.008),Vector3(0.088,-0.140,0.006),Vector3(0.093,-0.150,0.006),Vector3(0.125,-0.150,0.008),Vector3(0.1305,-0.138,0.006),Vector3(0.1215,-0.090,0.008),Vector3(0.118,-0.052,0.001)])
	slab(root,fillet(grip),0.030,FURNITURE,0.007)
	for side in [-1,1]:
		Models.bevel(root,Vector3(side*0.0152,-0.104,0.102),Vector3(0.001,0.072,0.030),"gun_grip",0.002).rotation.x=-0.18
	rod(root,Vector3(0,-0.1505,0.109),0.0035,0.001,"gun_edge",Vector3.UP,8)
	# Bent steel trigger guard, curved trigger blade.
	var guard := [Vector3(0,-0.057,0.002),Vector3(0,-0.068,0.000),Vector3(0,-0.082,0.004),Vector3(0,-0.090,0.014),Vector3(0,-0.092,0.030),Vector3(0,-0.090,0.046),Vector3(0,-0.083,0.056),Vector3(0,-0.072,0.0615),Vector3(0,-0.060,0.063)]
	for i in range(guard.size()-1):
		var a: Vector3=guard[i]
		var b: Vector3=guard[i+1]
		rod(root,(a+b)*0.5,0.0024,a.distance_to(b)+0.0015,"gun_metal",a.direction_to(b),6)
	Models.bevel(root,Vector3(0,-0.067,0.034),Vector3(0.006,0.020,0.005),"gun_edge",0.001).rotation.x=-0.25
	Models.bevel(root,Vector3(0,-0.079,0.039),Vector3(0.006,0.007,0.005),"gun_edge",0.001).rotation.x=-0.85
	for side in [-1,1]:rivet(root,side*0.0155,-0.052,0.028,0.0022)
	# Left-side safety flag above the trigger.
	rivet(root,-0.0157,-0.049,0.094,0.004)
	Models.bevel(root,Vector3(-0.0165,-0.053,0.076),Vector3(0.0025,0.007,0.036),"gun_metal",0.001).rotation.x=0.16
	# Right side: charging-handle slot, carrier face and the handle itself.
	Models.bevel(root,Vector3(0.0232,-0.026,0.0425),Vector3(0.001,0.0065,0.185),"gun_recess",0.001)
	block(bolt,Vector3(0.0237,-0.026,-0.031),Vector3(0.0012,0.0045,0.022),"gun_edge")
	Models.bevel(bolt,Vector3(0.029,-0.026,-0.033),Vector3(0.012,0.0065,0.010),"gun_metal",0.001)
	Models.bevel(bolt,Vector3(0.0355,-0.036,-0.033),Vector3(0.005,0.024,0.011),"gun_metal",0.0012).rotation.z=0.32
	rod(bolt,Vector3(0.041,-0.047,-0.033),0.0058,0.016,"gun_edge",Vector3.FORWARD,12)
	for z in [-0.0405,-0.0255]:rod(bolt,Vector3(0.041,-0.047,z),0.0062,0.0015,"gun_metal",Vector3.FORWARD,12)

# Skeleton butt with a real opening, steel butt plate and folding shoulder rest.
static func stock(root: Node3D) -> void:
	var outer := PackedVector3Array()
	for p in [Vector3(8,22,2),Vector3(186,22,14),Vector3(222,8,12),Vector3(281,8,1),Vector3(281,-44,1),Vector3(224,-44,10),Vector3(180,-92,10),Vector3(165,-102,8),Vector3(148,-98,8),Vector3(128,-84,12),Vector3(70,-82,16),Vector3(36,-100,10),Vector3(22,-104,3),Vector3(8,-104,2)]:
		outer.append(Vector3(0.42-p.x*0.001,p.y*0.001,p.z*0.001))
	var hole := PackedVector3Array()
	for p in [Vector3(52,-2,14),Vector3(174,-2,9),Vector3(160,-46,9),Vector3(52,-46,14)]:
		hole.append(Vector3(0.42-p.x*0.001,p.y*0.001,p.z*0.001))
	slab(root,fillet(outer),0.038,FURNITURE,0.0065,fillet(hole))
	Models.bevel(root,Vector3(0,-0.0405,0.4165),Vector3(0.041,0.131,0.007),"gun_metal",0.002)
	for y in [0.012,-0.092]:rod(root,Vector3(0,y,0.4205),0.003,0.0012,"gun_edge",Vector3.BACK,8)
	# Folding shoulder rest lies forward on the comb, hinged at the butt plate.
	rod(root,Vector3(0,0.029,0.414),0.0045,0.03,"gun_metal",Vector3.RIGHT,10)
	Models.bevel(root,Vector3(0,0.0255,0.398),Vector3(0.026,0.004,0.030),"gun_metal",0.0012)
	for side in [-1,1]:
		rod(root,Vector3(side*0.0152,0.029,0.414),0.0025,0.001,"gun_edge",Vector3.RIGHT,8)
		screw(root,Vector3(side*0.0192,-0.094,0.395),side)
		screw(root,Vector3(side*0.0192,0.012,0.395),side)
		for z in [0.146,0.168]:rivet(root,side*0.0192,-0.018,z,0.003)
	# Sling swivel on the left of the lower bar.
	Models.bevel(root,Vector3(-0.0195,-0.088,0.300),Vector3(0.002,0.008,0.024),"gun_metal",0.001)
	sling_loop(root,Vector3(-0.0225,-0.098,0.300),0.011,0.0075,"gun_edge").rotation.y=PI/2

# Barrel, collar, gas block with regulator, gas cylinder, front sight, hider.
static func barrel(root: Node3D) -> void:
	rod(root,Vector3(0,0,-0.2295),0.0165,0.037,"gun_metal",Vector3.FORWARD,20)
	for z in [-0.2125,-0.2465]:rod(root,Vector3(0,0,z),0.0172,0.003,"gun_edge",Vector3.FORWARD,20)
	for side in [-1,1]:Models.bevel(root,Vector3(side*0.0163,0.001,-0.2295),Vector3(0.002,0.008,0.016),"gun_recess",0.003)
	rod(root,Vector3(0,0,-0.366),0.0115,0.236,"gun_metal",Vector3.FORWARD,20)
	rod(root,Vector3(0,0,-0.5935),0.0098,0.153,"gun_metal",Vector3.FORWARD,20)
	# Gas block, regulator with three notches, sling loop.
	rod(root,Vector3(0,0,-0.5025),0.0155,0.037,"gun_metal",Vector3.FORWARD,20)
	Models.bevel(root,Vector3(0,-0.022,-0.5025),Vector3(0.017,0.031,0.033),"gun_metal",0.002)
	rod(root,Vector3(0,-0.029,-0.471),0.0105,0.030,"gun_edge",Vector3.FORWARD,16)
	for i in range(3):
		var angle := PI*0.25+i*PI*0.5
		block(root,Vector3(cos(angle)*0.0105,-0.029+sin(angle)*0.0105,-0.476),Vector3(0.003,0.003,0.010),"gun_recess")
	Models.bevel(root,Vector3(0.0125,-0.037,-0.466),Vector3(0.006,0.011,0.008),"gun_metal",0.001)
	sling_loop(root,Vector3(-0.019,-0.030,-0.508),0.0095,0.0065,"gun_edge").rotation.y=PI/2
	# Lower receiver extension, gas cylinder and bipod clamp.
	Models.bevel(root,Vector3(0,-0.0265,-0.264),Vector3(0.022,0.029,0.102),"gun_metal",0.002)
	for side in [-1,1]:rod(root,Vector3(side*0.0111,-0.030,-0.255),0.0042,0.001,"gun_recess",Vector3.RIGHT,8)
	rod(root,Vector3(0,-0.029,-0.320),0.0105,0.012,"gun_metal",Vector3.FORWARD,16,0.0086)
	rod(root,Vector3(0,-0.029,-0.370),0.0086,0.11,"gun_metal",Vector3.FORWARD,16)
	rod(root,Vector3(0,-0.029,-0.4385),0.0118,0.027,"gun_metal",Vector3.FORWARD,16)
	Models.bevel(root,Vector3(0,-0.046,-0.445),Vector3(0.030,0.020,0.018),"gun_metal",0.002)
	for side in [-1,1]:rivet(root,side*0.0151,-0.046,-0.445,0.0028)
	# Slotted flash hider: collar, ring, four bars between four slots, closed crown.
	rod(root,Vector3(0,0,-0.6935),0.0118,0.023,"gun_metal",Vector3.FORWARD,20)
	rod(root,Vector3(0,0,-0.7085),0.0122,0.007,"gun_metal",Vector3.FORWARD,20)
	for i in range(4):
		var middle := PI/4+i*PI/2
		sector(root,-0.764,-0.712,0.0122,0.0086,middle-0.48,middle+0.48,"gun_metal",3)
	rod(root,Vector3(0,0,-0.738),0.0078,0.052,"gun_recess",Vector3.FORWARD,12)
	lathe(root,PackedVector2Array([Vector2(0.0078,-0.764),Vector2(0.0122,-0.764),Vector2(0.0122,-0.7702),Vector2(0.0106,-0.772),Vector2(0.0074,-0.772),Vector2(0.0062,-0.7708)]),Vector3.ZERO,"gun_metal",20)
	rod(root,Vector3(0,0,-0.7704),0.0063,0.0008,"gun_recess",Vector3.FORWARD,12)

# Barrel carrying handle on the collar; folded to the right, clear of the sights.
static func carry_handle(root: Node3D) -> void:
	var handle := Models.group(root,"CarryHandle",HANDLE_PIVOT)
	var p := HANDLE_PIVOT
	rod(handle,Vector3(0,0,-0.0075),0.0186,0.013,"gun_metal",Vector3.FORWARD,20)
	var arm := PackedVector3Array([Vector3(-0.243,0.012,0.002),Vector3(-0.214,0.012,0.004),Vector3(-0.193,0.052,0.006),Vector3(-0.186,0.080,0.003),Vector3(-0.202,0.084,0.003),Vector3(-0.214,0.056,0.006),Vector3(-0.243,0.026,0.002)])
	var outline := PackedVector2Array()
	for q in fillet(arm):outline.append(q-Vector2(p.z,p.y))
	slab(handle,outline,0.007,"gun_metal",0.0015,PackedVector2Array(),0.0,false)
	for q in [Vector2(0.034,-0.229),Vector2(0.050,-0.214),Vector2(0.068,-0.200)]:
		rivet(handle,0.0038,q.x,q.y-p.z,0.003)
	WeaponArt.loft(handle,[Vector4(0.0895,-0.2045-p.z,0.012,0.016),Vector4(0.0895,-0.2015-p.z,0.022,0.029),Vector4(0.0895,-0.1080-p.z,0.022,0.029),Vector4(0.0895,-0.1050-p.z,0.012,0.016)],FURNITURE,0.42)
	for side in [-1,1]:
		Models.bevel(handle,Vector3(side*0.0111,0.0895,-0.153-p.z),Vector3(0.001,0.018,0.074),"gun_grip",0.002)
	handle.rotation.z=-1.35

# Folding bipod: each leg pivots at its own hinge and points along local -Y.
static func bipod(root: Node3D) -> void:
	var mount := Models.group(root,"Bipod",BIPOD_HINGE)
	for side in [-1,1]:
		var leg := Models.group(mount,"LegLeft" if side<0 else "LegRight",Vector3(side*0.012,0,0))
		rod(leg,Vector3.ZERO,0.0062,0.011,"gun_metal",Vector3.RIGHT,12)
		Models.bevel(leg,Vector3(0,-0.019,0),Vector3(0.0105,0.026,0.0135),"gun_metal",0.0015)
		Models.bevel(leg,Vector3(0,-0.146,0),Vector3(0.0095,0.232,0.0145),"gun_metal",0.0015)
		block(leg,Vector3(side*0.0049,-0.142,0.0),Vector3(0.001,0.19,0.0055),"gun_edge")
		Models.bevel(leg,Vector3(0,-0.266,0),Vector3(0.0085,0.012,0.011),"gun_metal",0.0015)
		Models.bevel(leg,Vector3(side*0.004,-0.2765,0),Vector3(0.026,0.0045,0.017),"gun_metal",0.0012)
		block(leg,Vector3(side*0.004,-0.2705,0.0085),Vector3(0.022,0.011,0.002),"gun_metal")
		block(leg,Vector3(-side*0.0058,-0.215,0),Vector3(0.0025,0.012,0.010),"gun_edge")
		rivet(leg,side*0.0058,0.0,0.0,0.0034)
		leg.rotation.x=-PI/2

# Steel 100-round box: ribbed faces, lid with belt flap, side clamp and handle.
static func box(mag: Node3D) -> void:
	var center := Vector3(0.037,-0.141,-0.1085)
	Models.bevel(mag,center+Vector3(0,-0.002,0),Vector3(0.130,0.160,0.097),BOX_PAINT,0.004)
	Models.bevel(mag,center+Vector3(0,0.0785,0),Vector3(0.133,0.006,0.100),BOX_PAINT,0.0015)
	Models.bevel(mag,center+Vector3(0,0.0715,0),Vector3(0.1325,0.009,0.0995),BOX_PAINT,0.001)
	for face in [-1,1]:
		for y in [0.035,0.0,-0.035]:
			block(mag,center+Vector3(0,y,face*0.0488),Vector3(0.100,0.011,0.002),BOX_PAINT)
		block(mag,center+Vector3(0,-0.064,face*0.0488),Vector3(0.060,0.011,0.002),BOX_PAINT)
	# Lid hinge, belt mouth with its sprung flap, lid clasp and folding bail.
	rod(mag,center+Vector3(-0.066,0.077,0),0.0028,0.094,"gun_metal",Vector3.FORWARD,8)
	block(mag,Vector3(0.047,-0.0593,-0.1085),Vector3(0.025,0.001,0.089),"gun_recess")
	block(mag,Vector3(0.0325,-0.0515,-0.1085),Vector3(0.002,0.016,0.086),BOX_PAINT).rotation.z=0.3
	Models.bevel(mag,center+Vector3(0.0665,0.066,0),Vector3(0.003,0.022,0.020),"gun_metal",0.001)
	rod(mag,Vector3(center.x+0.068,-0.08,-0.1085),0.003,0.0012,"gun_metal",Vector3.RIGHT,8)
	for z in [-0.032,0.032]:
		rod(mag,Vector3(0.086,-0.0585,center.z+z),0.0016,0.028,"gun_metal",Vector3.RIGHT,6)
		block(mag,Vector3(0.0985,-0.0575,center.z+z),Vector3(0.006,0.004,0.006),"gun_metal")
	rod(mag,Vector3(0.072,-0.0585,center.z),0.0016,0.065,"gun_metal",Vector3.FORWARD,6)
	# Left-face spring clamp with the T latch that locks onto the bracket.
	Models.bevel(mag,center+Vector3(-0.0665,0.028,0),Vector3(0.0025,0.090,0.044),"gun_metal",0.004)
	block(mag,center+Vector3(-0.0675,0.044,0),Vector3(0.001,0.030,0.006),"gun_recess")
	rod(mag,center+Vector3(-0.069,0.019,0),0.0028,0.004,"gun_metal",Vector3.RIGHT,8)
	block(mag,center+Vector3(-0.0698,0.011,0),Vector3(0.0018,0.015,0.0035),"gun_metal")
	Models.bevel(mag,Vector3(0,-0.058,center.z),Vector3(0.028,0.003,0.088),"gun_metal",0.001)

# Short run of linked rounds from the box mouth up into the feed tray.
static func belt_rounds(strip: Node3D) -> void:
	var centers: Array[Vector2]=[]
	for k in range(9):
		var s := k*BELT_PITCH
		var a := 0.027
		var arc := PI*0.5*0.016
		if s<a:
			centers.append(Vector2(0.004+s,0.0175))
		elif s<a+arc:
			var angle := PI*0.5-(s-a)/0.016
			centers.append(Vector2(0.031,0.0015)+Vector2(cos(angle),sin(angle))*0.016)
		else:
			centers.append(Vector2(0.047,0.0015-(s-a-arc)))
	var case_profile := PackedVector2Array([Vector2(0,0),Vector2(0.0072,0),Vector2(0.0072,-0.0016),Vector2(0.0061,-0.0024),Vector2(0.00565,-0.0455),Vector2(0.0043,-0.0505),Vector2(0.0043,-0.0537)])
	var bullet_profile := PackedVector2Array([Vector2(0.0039,-0.051),Vector2(0.0039,-0.0595),Vector2(0.0031,-0.0675),Vector2(0.0013,-0.0752),Vector2(0,-0.0772)])
	var band := PackedVector2Array([Vector2(0.0058,-0.011),Vector2(0.0068,-0.0115),Vector2(0.0068,-0.0255),Vector2(0.0058,-0.026)])
	var collar := PackedVector2Array([Vector2(0.0054,-0.036),Vector2(0.0063,-0.0365),Vector2(0.0063,-0.0425),Vector2(0.0054,-0.043)])
	for k in range(centers.size()):
		var c := centers[k]
		var at := Vector3(c.x,c.y,RIM_Z)
		lathe(strip,case_profile,at,"brass",8)
		lathe(strip,bullet_profile,at,"copper",8)
		lathe(strip,band,at,"gun_metal",8)
		lathe(strip,collar,at,"gun_metal",8)
		if k>0:
			var prev := centers[k-1]
			var d := (c-prev).normalized()
			var mid := (c+prev)*0.5
			# Link tab and spring joint between neighbours, on the outer side.
			var normal := Vector2(-d.y,d.x)
			for z in [RIM_Z-0.0185,RIM_Z-0.0395]:
				var tab := block(strip,Vector3(mid.x+normal.x*0.004,mid.y+normal.y*0.004,z),Vector3(0.003,BELT_PITCH*0.75,0.006 if z>RIM_Z-0.03 else 0.005),"gun_metal")
				tab.rotation.z=atan2(-d.x,d.y)

# --- Geometry helpers ---------------------------------------------------------

# Cylinder with a chosen facet count and a single band (Models.tube always
# uses 20 facets and two bands, too many for pins and small rods).
static func rod(parent: Node3D, pos: Vector3, radius: float, length: float, key: String, axis: Vector3=Vector3.FORWARD, facets: int=8, top: float=-1) -> MeshInstance3D:
	var node := Models.tube(parent,pos,radius,length,key,axis,top)
	var mesh: CylinderMesh=node.mesh
	mesh.radial_segments=facets
	mesh.rings=0
	return node

# Flush rivet head on a side face (axis along X).
static func rivet(parent: Node3D, x: float, y: float, z: float, radius: float=0.0024) -> void:
	rod(parent,Vector3(x,y,z),radius,0.0012,"gun_edge",Vector3.RIGHT,6)

# Slotted screw head on a side face; side is -1 (left) or +1 (right).
static func screw(parent: Node3D, pos: Vector3, side: float) -> void:
	rod(parent,pos,0.003,0.0015,"gun_edge",Vector3.RIGHT,8)
	block(parent,pos+Vector3(side*0.0008,0,0),Vector3(0.0006,0.001,0.0045),"gun_recess")

# Plain box (12 triangles) for marks, ribs and tabs too small to need a chamfer.
static func block(parent: Node3D, pos: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	return Models.mesh_node(parent,mesh,pos,key)

# Low-poly torus for sling loops.
static func sling_loop(parent: Node3D, pos: Vector3, outer: float, inner: float, key: String) -> MeshInstance3D:
	var node := Models.ring(parent,pos,outer,inner,key)
	var mesh: TorusMesh=node.mesh
	mesh.rings=14
	mesh.ring_segments=6
	return node

# Rounded corners: each point is (z, y, radius); radius 0 keeps a sharp corner.
static func fillet(points: PackedVector3Array, segments: int=3) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	for i in range(n):
		var a := Vector2(points[(i-1+n)%n].x,points[(i-1+n)%n].y)
		var b := Vector2(points[i].x,points[i].y)
		var c := Vector2(points[(i+1)%n].x,points[(i+1)%n].y)
		var cut := minf(points[i].z,minf(a.distance_to(b),c.distance_to(b))*0.48)
		if cut<=0.00001:
			out.append(b)
			continue
		var p1 := b+(a-b).normalized()*cut
		var p2 := b+(c-b).normalized()*cut
		for s in range(segments+1):
			var u := float(s)/segments
			out.append(p1.lerp(b,u).lerp(b.lerp(p2,u),u))
	var clean := PackedVector2Array()
	for p in out:
		if clean.is_empty() or clean[-1].distance_to(p)>0.00005:clean.append(p)
	if clean.size()>1 and clean[0].distance_to(clean[-1])<=0.00005:clean.remove_at(clean.size()-1)
	return clean

static func signed_area(loop: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(loop.size()):
		var a := loop[i]
		var b := loop[(i+1)%loop.size()]
		total+=a.x*b.y-b.x*a.y
	return total*0.5

static func oriented(loop: PackedVector2Array, ccw: bool) -> PackedVector2Array:
	var out := loop.duplicate()
	if (signed_area(out)>0)!=ccw:out.reverse()
	return out

# Moves every vertex to the left of the loop direction: inward on a CCW
# outline, outward (into the material) on a CW hole.
static func offset_loop(loop: PackedVector2Array, distance: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := loop.size()
	for i in range(n):
		var e1 := (loop[i]-loop[(i-1+n)%n]).normalized()
		var e2 := (loop[(i+1)%n]-loop[i]).normalized()
		var n1 := Vector2(-e1.y,e1.x)
		var n2 := Vector2(-e2.y,e2.x)
		var m := (n1+n2).normalized()
		out.append(loop[i]+m*distance/maxf(m.dot(n1),0.5))
	return out

# Adds a triangle whose front face points along `out` (Godot: clockwise front).
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (b-a).cross(c-a).dot(out)>0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)

# Splits the area between a CCW outline and a CW hole into two simple polygons.
static func split_ring(outer: PackedVector2Array, hole: PackedVector2Array) -> Array[PackedVector2Array]:
	var h1 := 0
	var h2 := 0
	for i in range(hole.size()):
		if hole[i].x<hole[h1].x:h1=i
		if hole[i].x>hole[h2].x:h2=i
	var o1 := 0
	var o2 := 0
	for i in range(outer.size()):
		if outer[i].distance_to(hole[h1])<outer[o1].distance_to(hole[h1]):o1=i
		if outer[i].distance_to(hole[h2])<outer[o2].distance_to(hole[h2]):o2=i
	var result: Array[PackedVector2Array]=[]
	for pair in [[o1,o2,h2,h1],[o2,o1,h1,h2]]:
		var polygon := PackedVector2Array()
		var i: int=pair[0]
		while true:
			polygon.append(outer[i])
			if i==pair[1]:break
			i=(i+1)%outer.size()
		i=pair[2]
		while true:
			polygon.append(hole[i])
			if i==pair[3]:break
			i=(i+1)%hole.size()
		result.append(polygon)
	return result

# Profile (z, y) extruded across X with chamfered, rounded edges; an optional
# hole loop is cut right through (a real opening, not a painted recess).
static func slab(parent: Node3D, outline: PackedVector2Array, width: float, key: String, edge: float=0.003, hole: PackedVector2Array=PackedVector2Array(), x: float=0.0, smooth: bool=true) -> MeshInstance3D:
	var loops: Array[PackedVector2Array]=[oriented(outline,true)]
	if hole.size()>2:loops.append(oriented(hole,false))
	var half := width/2
	var b := minf(edge,half*0.45)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var caps: Array[PackedVector2Array]=[]
	for loop in loops:
		var cap := offset_loop(loop,b)
		caps.append(cap)
		var rings: Array[PackedVector2Array]=[cap,loop,loop,cap]
		var xs: Array[float]=[x-half,x-half+b,x+half-b,x+half]
		st.set_smooth_group(0 if smooth else -1)
		for r in range(3):
			for i in range(loop.size()):
				var j := (i+1)%loop.size()
				var e := loop[j]-loop[i]
				var out := Vector3(0,-e.x,e.y)
				var p0 := Vector3(xs[r],rings[r][i].y,rings[r][i].x)
				var p1 := Vector3(xs[r],rings[r][j].y,rings[r][j].x)
				var p2 := Vector3(xs[r+1],rings[r+1][i].y,rings[r+1][i].x)
				var p3 := Vector3(xs[r+1],rings[r+1][j].y,rings[r+1][j].x)
				tri(st,p0,p2,p1,out)
				tri(st,p1,p2,p3,out)
	st.set_smooth_group(-1)
	var polygons: Array[PackedVector2Array]=[caps[0]]
	if caps.size()>1:polygons=split_ring(caps[0],caps[1])
	for side in [-1.0,1.0]:
		for polygon in polygons:
			var indices := Geometry2D.triangulate_polygon(polygon)
			for t in range(0,indices.size(),3):
				var v: Array[Vector3]=[]
				for k in range(3):v.append(Vector3(x+side*half,polygon[indices[t+k]].y,polygon[indices[t+k]].x))
				tri(st,v[0],v[1],v[2],Vector3(side,0,0))
	st.generate_normals()
	st.index()
	return Models.mesh_node(parent,st.commit(),Vector3.ZERO,key)

# Surface of revolution about +Z. Profile points are (radius, z), listed from
# the rear toward the front so the left-hand profile normal faces outward.
static func lathe(parent: Node3D, profile: PackedVector2Array, pos: Vector3, key: String, segments: int=12) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for p in range(profile.size()-1):
		var a := profile[p]
		var b := profile[p+1]
		var normal := Vector2(-(b.y-a.y),b.x-a.x)
		for i in range(segments):
			var t0 := TAU*i/segments
			var t1 := TAU*(i+1)/segments
			var tm := (t0+t1)*0.5
			var out := Vector3(cos(tm)*normal.x,sin(tm)*normal.x,normal.y)
			var a0 := pos+Vector3(cos(t0)*a.x,sin(t0)*a.x,a.y)
			var a1 := pos+Vector3(cos(t1)*a.x,sin(t1)*a.x,a.y)
			var b0 := pos+Vector3(cos(t0)*b.x,sin(t0)*b.x,b.y)
			var b1 := pos+Vector3(cos(t1)*b.x,sin(t1)*b.x,b.y)
			if a.x>0.0:tri(st,a0,b0,a1,out)
			if b.x>0.0:tri(st,a1,b0,b1,out)
	st.generate_normals()
	st.index()
	return Models.mesh_node(parent,st.commit(),Vector3.ZERO,key)

# One bar of a slotted tube: annular sector between two angles along -Z.
static func sector(parent: Node3D, z0: float, z1: float, outer: float, inner: float, a0: float, a1: float, key: String, steps: int=4) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in range(steps):
		var t0 := lerpf(a0,a1,float(i)/steps)
		var t1 := lerpf(a0,a1,float(i+1)/steps)
		var tm := (t0+t1)*0.5
		var radial := Vector3(cos(tm),sin(tm),0)
		for r in [outer,inner]:
			var out: Vector3=radial if r==outer else -radial
			var p0 := Vector3(cos(t0)*r,sin(t0)*r,z0)
			var p1 := Vector3(cos(t1)*r,sin(t1)*r,z0)
			var p2 := Vector3(cos(t0)*r,sin(t0)*r,z1)
			var p3 := Vector3(cos(t1)*r,sin(t1)*r,z1)
			tri(st,p0,p2,p1,out)
			tri(st,p1,p2,p3,out)
		for z in [z0,z1]:
			var out_z := Vector3(0,0,signf(z-(z0+z1)*0.5))
			var q0 := Vector3(cos(t0)*inner,sin(t0)*inner,z)
			var q1 := Vector3(cos(t1)*inner,sin(t1)*inner,z)
			var q2 := Vector3(cos(t0)*outer,sin(t0)*outer,z)
			var q3 := Vector3(cos(t1)*outer,sin(t1)*outer,z)
			tri(st,q0,q2,q1,out_z)
			tri(st,q1,q2,q3,out_z)
	for t in [a0,a1]:
		var out_t := Vector3(-sin(t),cos(t),0)*(1.0 if t==a1 else -1.0)
		var e0 := Vector3(cos(t)*inner,sin(t)*inner,z0)
		var e1 := Vector3(cos(t)*outer,sin(t)*outer,z0)
		var e2 := Vector3(cos(t)*inner,sin(t)*inner,z1)
		var e3 := Vector3(cos(t)*outer,sin(t)*outer,z1)
		tri(st,e0,e2,e1,out_t)
		tri(st,e1,e2,e3,out_t)
	st.generate_normals()
	st.index()
	return Models.mesh_node(parent,st.commit(),Vector3.ZERO,key)
