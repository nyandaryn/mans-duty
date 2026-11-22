class_name DamageModel
extends RefCounted

# Game wound model, not a medical or ammunition penetration model.
static func hitbox(actor: Node3D, parent: Node3D, zone: String, center: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name="Hit_"+zone
	area.collision_layer=16
	area.collision_mask=0
	area.monitoring=false
	area.set_meta("actor",actor)
	area.set_meta("zone",zone)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=size
	shape.shape=box
	shape.position=center
	area.add_child(shape)
	parent.add_child(area)
	return area

# Tight boxes follow the bone axis instead of enclosing a diagonal limb in empty space.
static func limb_hitbox(actor: Node3D, parent: Node3D, zone: String, end: Vector3, width: float, upper: bool) -> Area3D:
	var area := hitbox(actor,parent,zone,Vector3.ZERO,Vector3(width,end.length(),width))
	area.position=end*0.5
	area.quaternion=Quaternion(Vector3.UP,end.normalized())
	area.set_meta("upper_limb",upper)
	return area

# Intersect the complete trajectory with the oriented hitbox. Entry-face coordinates
# alone classify every lateral shot as a graze, regardless of penetration depth.
static func trajectory_location(area: Area3D, point: Vector3, direction: Vector3) -> Vector2:
	var shape: CollisionShape3D=area.get_child(0)
	var half: Vector3=shape.shape.size*0.5
	var p := shape.to_local(point)
	var d := (shape.global_basis.inverse()*direction).normalized()
	var enter := -INF
	var leave := INF
	for axis in range(3):
		if absf(d[axis])<0.00001:
			if absf(p[axis])>half[axis]+0.001:return Vector2(1,0)
			continue
		var a := (-half[axis]-p[axis])/d[axis]
		var b := (half[axis]-p[axis])/d[axis]
		enter=maxf(enter,minf(a,b))
		leave=minf(leave,maxf(a,b))
	var depth := maxf(0,leave-enter)
	var minimum := minf(half.x,minf(half.y,half.z))*2
	if depth<minimum*0.18:return Vector2(1,0)
	var closest := p+d*clampf(-p.dot(d),enter,leave)
	var radial := Vector2(closest.x/half.x,closest.z/half.z).length()
	# Upper-limb central tracks stand in for vulnerable vessels; no random artery roll.
	var upper: bool=area.get_meta("upper_limb",closest.y>0)
	return Vector2(minf(radial,0.86),0.5 if upper and radial<0.4 else -0.5)

static func damage(weapon: String, zone: String, energy: float) -> float:
	var rifle := weapon in ["ak74","m16","svd","pkm"]
	var base := 86.0 if weapon in ["svd","pkm"] else (68.0 if rifle else 40.0)
	var factors := {"head":3.5,"chest":1.0,"abdomen":0.85,"arm":0.50,"leg":0.65}
	return base*float(factors.get(zone,1.0))*energy

static func wound(zone: String, weapon: String, energy: float, location: Vector2, plate_integrity: float, vest: String="korsar") -> Dictionary:
	var result := {"kind":"penetrating","damage":damage(weapon,zone,energy),"bleeding":1.2,"pain":0.7,"disabled":false,"plate_loss":0.0}
	if energy<0.12:
		result.kind="blunt"
		result.damage=energy*35
		result.bleeding=0.0
		result.pain=energy*2
		return result
	if zone=="head":
		result.kind="fatal_head"
		result.damage=1000.0
		result.bleeding=2.0
		return result
	if zone=="plate":
		var penetration := energy*(1.0 if weapon in ["ak74","m16","svd","pkm"] else 0.30)
		result.plate_loss=energy*(0.45 if weapon in ["ak74","m16","svd","pkm"] else 0.12)
		# The plate's class (VestKind): class 4 of the Korsar, 5A of the 6B45,
		# class 6 of the carrier's plates.
		if VestKind.plate_holds(vest,penetration,plate_integrity):
			result.kind="blunt"
			result.damage=8.0+energy*6.0
			result.bleeding=0.0
			result.pain=0.85
			return result
		result.kind="plate_penetration"
		result.damage=damage(weapon,"chest",energy)*0.9
		result.bleeding=3.8
		return result
	# Soft armour round the torso stops a pistol round: a bruise.
	if zone in ["chest","abdomen"] and VestKind.soft_holds(vest,weapon,energy):
		result.kind="blunt"
		result.damage=4.0+energy*5.0
		result.bleeding=0.0
		result.pain=0.6
		return result
	# A marginal hit on the limb's outer region is treated as a graze.
	if zone in ["arm","leg"] and absf(location.x)>0.87:
		result.kind="graze"
		result.damage=7.0*energy
		result.bleeding=0.15
		result.pain=0.22
		return result
	if zone=="abdomen":
		result.kind="internal"
		result.bleeding=4.0
	elif zone=="chest":
		result.kind="thoracic"
		result.bleeding=3.0
	elif zone in ["arm","leg"]:
		result.disabled=true
		if absf(location.x)<0.4 and location.y>0.05:
			result.kind="arterial"
			result.bleeding=3.8
		else:result.bleeding=1.0
	return result
