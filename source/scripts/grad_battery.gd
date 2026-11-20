class_name GradBattery
extends Node

# The supporting battery of the great assault for the rifleman and the
# sniper: three BM-21 already on the firing position (the field 5.5 km
# south-west of the village the BM-21 commander is sent to) when the battle
# starts. Their crews bring the launchers into action and lay each one on a
# strongpoint of its own, one launcher for each; then they wait in the cabs
# and all three fire their full packages together on the commander's order.
# The crew is three men a launcher: the commander takes the cover off, the
# driver unlocks the package, the gunner lays it at the panorama. They lay
# the way the D726 sight does: the package bearing to the target and the
# tube elevation of the firing table for its range plus the angle of site.
const COUNT := 3
const SPACING := 60.0
const CREW := ["commander","driver","gunner"]
# Crew spots round the vehicle (vehicle frame) and the cab door they board by.
const SPOTS := {"commander":Vector3(0.6,0,4.3),"driver":Vector3(-2.0,0,0.0),"gunner":Vector3(-2.0,0,1.9)}
const DOOR := Vector3(-2.0,0,-1.5)
const WALK := 1.6
var game: Node3D
var battle: BattleMode
var data: AvdiivkaData
var center := Vector3.ZERO
var forward := Vector3.FORWARD
var side := Vector3.RIGHT
var launchers: Array[GradVehicle]=[]
var crews: Array[Dictionary]=[]
var figures: Array[Node3D]=[]
var ordered := false
var clock := 0.0

func setup(owner_game: Node3D, owner_battle: BattleMode) -> void:
	game=owner_game;battle=owner_battle
	name="GradBattery"
	data=AvdiivkaData.shared()
	center=ground(GradCommand.FIRING_AREA)
	var village:=Vector3(0,0,0)-center
	village.y=0
	forward=village.normalized()
	side=Vector3(-forward.z,0,forward.x)
	# Left to right across the line of fire, the same way as the targets.
	var order: Array=range(3)
	order.sort_custom(func(a,b):return side.dot(battle.center(a))<side.dot(battle.center(b)))
	game.district.operation_area.stream(center,30)
	for i in range(COUNT):
		var vehicle:=GradVehicle.new()
		game.world_root.add_child(vehicle)
		vehicle.setup(game)
		vehicle.name="AlliedGrad%d" % (i+1)
		var target_index: int=order[i]
		var target:=battle.center(target_index)
		var spot:=ground(center+side*(i-1)*SPACING+forward*randf_range(-8.0,8.0))
		# The target 75° to the left of the vehicle axis, as the tablet advises.
		var bearing:=GradBallistics.bearing(target-spot)*0.06
		var heading:=deg_to_rad(fposmod(bearing+75.0+randf_range(-4.0,4.0),360.0))
		var axis:=Vector3(sin(heading),0,-cos(heading))
		vehicle.look_at_from_position(spot+Vector3.UP*0.25,spot+Vector3.UP*0.25+axis,data.normal_at(spot.x,spot.z))
		launchers.append(vehicle)
		var crew:={"vehicle":vehicle,"target":target,"sector":target_index,"state":"out","time":-randf_range(0.5,2.5),"men":{},"laid":false}
		for role in CREW:
			var man:=figure(vehicle,role)
			crew.men[role]=man
		crews.append(crew)

func ground(point: Vector3) -> Vector3:
	return Vector3(point.x,data.height(point.x,point.z),point.z)

# A crewman: a soldier's figure that walks between the stations.
func figure(vehicle: GradVehicle, role: String) -> Node3D:
	var body:=Node3D.new()
	body.name="GradCrew_%s" % role
	game.world_root.add_child(body)
	var model:=Models.soldier(body,true)
	Wardrobe.dress(model,game.player_outfit)
	CharacterArt.team_markings(model,true)
	var spot:=ground(vehicle.to_global(DOOR+Vector3(0,0,-0.6*CREW.find(role))))
	body.global_position=spot
	body.set_meta("goal",SPOTS[role])
	figures.append(body)
	return body

func reset() -> void:
	for vehicle in launchers:
		if is_instance_valid(vehicle):vehicle.queue_free()
	for body in figures:
		if is_instance_valid(body):body.queue_free()
	launchers.clear();figures.clear();crews.clear()

func _exit_tree() -> void:reset()

# --- Laying ------------------------------------------------------------------
# Bearing (mils) and absolute elevation of the tubes (mils) for a target.
func aim(crew: Dictionary) -> Vector2:
	var vehicle: GradVehicle=crew.vehicle
	var from:=vehicle.global_position
	var target: Vector3=crew.target
	var flat:=Vector2(target.x-from.x,target.z-from.z)
	var distance:=flat.length()
	var site:=(target.y-from.y)/(0.001*maxf(distance,1.0))
	return Vector2(GradBallistics.bearing(Vector3(flat.x,0,flat.y)),GradBallistics.elevation_for(0,distance)+site)

func lay(crew: Dictionary, delta: float) -> bool:
	var vehicle: GradVehicle=crew.vehicle
	var goal:=aim(crew)
	var turn:=wrapf(goal.x-vehicle.package_bearing(),-3000.0,3000.0)*0.06
	var lift:=(goal.y-vehicle.absolute_elevation_mils())*0.06
	vehicle.azimuth=clampf(vehicle.azimuth+clampf(turn,-GradVehicle.TRAVERSE_RATE*delta,GradVehicle.TRAVERSE_RATE*delta),GradVehicle.ELECTRIC_LEFT,GradVehicle.ELECTRIC_RIGHT)
	vehicle.elevation=clampf(vehicle.elevation+clampf(lift,-GradVehicle.ELEVATION_RATE*delta,GradVehicle.ELEVATION_RATE*delta),0.0,GradVehicle.ELECTRIC_TOP)
	vehicle.apply_launcher()
	# Within half a thousandth both ways.
	return absf(turn)<0.03 and absf(lift)<0.03

func walk(body: Node3D, goal: Vector3, delta: float) -> bool:
	var at:=body.global_position
	var flat:=Vector3(goal.x-at.x,0,goal.z-at.z)
	if flat.length()<0.15:return true
	var step:=minf(flat.length(),WALK*delta)
	var next:=at+flat.normalized()*step
	body.global_position=ground(next)
	body.rotation.y=atan2(-flat.x,-flat.z)
	return false

# --- Frame -------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not game.running or game.paused:return
	clock+=delta
	for crew in crews:tick(crew,delta)

func tick(crew: Dictionary, delta: float) -> void:
	var vehicle: GradVehicle=crew.vehicle
	if not is_instance_valid(vehicle):return
	crew.time=float(crew.time)+delta
	var men: Dictionary=crew.men
	match crew.state:
		"out":
			# Out of the cab to the stations; the engine started for the
			# generator of the electric laying drive.
			if not vehicle.ignition:vehicle.ignition=true;vehicle.starter=true;vehicle.crank_left=0.8
			if vehicle.running:vehicle.starter=false
			var there:=true
			for role in CREW:
				if not walk(men[role],vehicle.to_global(SPOTS[role]),delta):there=false
			if there and float(crew.time)>0.0:crew.state="prepare";crew.time=0.0
		"prepare":
			if vehicle.running:vehicle.starter=false
			face(men.commander,vehicle.to_global(Vector3(0,1.5,2.5)))
			face(men.driver,vehicle.global_position+Vector3.UP)
			face(men.gunner,vehicle.art.turret.global_position)
			if float(crew.time)>3.5 and vehicle.travel_lock:
				vehicle.travel_lock=false;vehicle.springs_locked=true
			if float(crew.time)>5.0 and not vehicle.bracket_up:vehicle.set_bracket(true)
			if float(crew.time)>9.0 and vehicle.cover_on:vehicle.set_cover(false)
			if float(crew.time)>9.5:
				vehicle.power_takeoff=true;vehicle.shields_down=true
				vehicle.battery_on=true;vehicle.fire_mode=1;vehicle.program_wound=true
				crew.state="lay";crew.time=0.0
		"lay":
			if lay(crew,delta) and float(crew.time)>2.0:
				crew.state="check";crew.time=0.0
		"check":
			lay(crew,delta)
			if float(crew.time)>2.5:crew.state="board";crew.time=0.0
		"board":
			var aboard:=true
			for role in CREW:
				var body: Node3D=men[role]
				if not body.visible:continue
				if walk(body,vehicle.to_global(DOOR),delta):body.hide()
				else:aboard=false
			if aboard:crew.state="ready";crew.laid=true
		"ready":
			lay(crew,delta)
			if ordered:crew.state="fire";vehicle.set_lever(true)
		"fire":
			if vehicle.remaining()==0:vehicle.set_lever(false);crew.state="done"

func face(body: Node3D, point: Vector3) -> void:
	var d:=point-body.global_position
	if Vector2(d.x,d.z).length()>0.1:body.rotation.y=atan2(-d.x,-d.z)

# --- The battery as the battle sees it -------------------------------------------
func ready_count() -> int:
	var count:=0
	for crew in crews:
		if crew.state in ["ready","fire","done"]:count+=1
	return count

func laying_count() -> int:
	var count:=0
	for crew in crews:
		if crew.state in ["lay","check","board"]:count+=1
	return count

func all_ready() -> bool:return ready_count()==crews.size()

func fire() -> void:ordered=true

func fired() -> int:
	var count:=0
	for vehicle in launchers:count+=vehicle.fired
	return count

# All packages empty and the last rocket down.
func finished() -> bool:
	if not ordered:return false
	for crew in crews:
		if crew.state!="done":return false
	return game.blasts.grads.is_empty()

func in_flight() -> int:return game.blasts.grads.size()

# --- Views for the soldier's tablet ------------------------------------------------
# The battery from its flank: the three launchers in a row, the nearest large,
# the rockets leaving over them toward the village.
func battery_view() -> Transform3D:
	var eye:=center+side*85.0-forward*35.0
	eye.y=data.height(eye.x,eye.z)+11.0
	var look:=center-side*12.0+forward*6.0
	look.y=data.height(look.x,look.z)+2.5
	return Transform3D(Basis.looking_at(look-eye,Vector3.UP),eye)

# The whole village from the observation post's drone high to the south.
func village_view() -> Transform3D:
	var middle:=Vector3.ZERO
	for i in range(3):middle+=battle.center(i)
	middle/=3.0
	var south:=Vector3(-BattleMap.north().x,0,-BattleMap.north().y)
	var eye:=middle+south*430.0+Vector3.UP*270.0
	return Transform3D(Basis.looking_at(middle-eye,Vector3.UP),eye)
