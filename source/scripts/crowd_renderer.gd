class_name CrowdRenderer
extends Node3D

# Distant soldiers in the large battle are drawn by GPU instancing: one
# MultiMesh per body part and faction, so the whole distant crowd costs ten
# draw calls instead of ~25 per soldier. Nearby soldiers in view, magnified
# ones in the PSO-1 field of view and the commander's own group keep the
# detailed model. Parts follow the same animated nodes that carry the hitboxes, so
# poses, wounds, prone positions and ragdolls match what the bullets hit.
const NEAR := 21.0
const HYSTERESIS := 3.5
const PERSONAL_NEAR := 45.0
# Out of view only shadows of a soldier are drawn: the instanced model casts
# them for a fraction of the cost. The margin covers a fast turn of the head.
const VIEW_MARGIN := deg_to_rad(24.0)
const ALWAYS_NEAR := 4.0
var game: Node3D
var entries: Array[Dictionary] = []
var multis: Array = [[],[]]
var free_slots: Array = [[],[]]
var next_slot := [0,0]
var capacity := [0,0]
var nodes: Array = [[],[]]
var far_count := 0
var near_count := 0

func setup(owner_game: Node3D, initial_capacity: int) -> void:
	game=owner_game
	name="CrowdRenderer"
	for team in range(2):
		var friendly := team==0
		var outfit: String=game.player_outfit if friendly else game.enemy_outfit
		var material := CrowdArt.material(outfit)
		for mesh in CrowdArt.parts(friendly):
			var multi := MultiMesh.new()
			multi.transform_format=MultiMesh.TRANSFORM_3D
			multi.mesh=mesh
			multi.instance_count=initial_capacity
			multi.visible_instance_count=0
			var node := MultiMeshInstance3D.new()
			node.multimesh=multi
			node.material_override=material
			add_child(node)
			multis[team].append(multi)
			nodes[team].append(node)
		capacity[team]=initial_capacity

func register(actor: Hostile) -> void:
	for entry in entries:
		if entry.actor==actor:return
	var team := 0 if actor.friendly else 1
	var slot: int
	if not free_slots[team].is_empty():slot=free_slots[team].pop_back()
	else:
		slot=next_slot[team]
		next_slot[team]+=1
		if slot>=capacity[team]:grow(team)
		for multi in multis[team]:multi.visible_instance_count=next_slot[team]
	# The soldier's own detailed geometry, recorded before any wound decals.
	var meshes: Array=[]
	for mesh in actor.model.find_children("*","MeshInstance3D",true,false):
		if mesh!=actor.medical_prop:meshes.append(mesh)
	var parents: Array=[]
	parents.resize(meshes.size())
	entries.append({"actor":actor,"team":team,"slot":slot,"far":false,"serial":-1,"dead_clock":0.0,"personal":actor.get_meta("battle_personal",false),"meshes":meshes,"parents":parents})

func grow(team: int) -> void:
	# Resizing clears instance data: rewrite every distant soldier of the side.
	capacity[team]*=2
	for multi in multis[team]:multi.instance_count=capacity[team]
	for entry in entries:
		if entry.team==team:entry.serial=-1

func release(entry: Dictionary) -> void:
	hide_slot(entry.team,entry.slot)
	free_slots[entry.team].append(entry.slot)

func hide_slot(team: int, slot: int) -> void:
	# A zero basis collapses the instance to a point: nothing is rasterised.
	var empty := Transform3D(Basis().scaled(Vector3.ZERO),Vector3.ZERO)
	for multi in multis[team]:multi.set_instance_transform(slot,empty)

# A distant soldier's detailed meshes leave the scene tree. Hidden nodes would
# still receive every transform update of the animated skeleton: dozens of
# meshes per soldier per tick. Hitbox areas and skeleton nodes stay in place.
func set_far(entry: Dictionary, far: bool) -> void:
	var actor: Hostile=entry.actor
	actor.render_far=far
	var meshes: Array=entry.meshes
	var parents: Array=entry.parents
	for i in range(meshes.size()):
		if not is_instance_valid(meshes[i]):continue
		var mesh: Node=meshes[i]
		if far and mesh.get_parent()!=null:
			parents[i]=mesh.get_parent()
			parents[i].remove_child(mesh)
		elif not far and mesh.get_parent()==null and is_instance_valid(parents[i]):
			parents[i].add_child(mesh)

func discard(entry: Dictionary) -> void:
	# Detached meshes of a freed soldier are orphans: free them explicitly.
	for mesh in entry.meshes:
		if is_instance_valid(mesh) and mesh.get_parent()==null:mesh.free()

func clear_all() -> void:
	for entry in entries:
		if is_instance_valid(entry.actor) and not entry.actor.is_queued_for_deletion():
			if entry.far:set_far(entry,false)
		else:discard(entry)
	entries.clear()

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:clear_all()

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera==null:return
	var origin := camera.global_position
	var scope: Camera3D=null
	if is_instance_valid(game.player) and game.player.scope_sight!=null and game.player.scope_sight.enabled:scope=game.player.scope_sight.camera
	var forward := -camera.global_basis.z
	var size := get_viewport().get_visible_rect().size
	var half_height := deg_to_rad(camera.fov)*0.5
	var half_width := atan(tan(half_height)*size.x/maxf(1.0,size.y))
	var view_cos := cos(minf(PI,half_width+VIEW_MARGIN))
	far_count=0
	near_count=0
	for index in range(entries.size()-1,-1,-1):
		var entry: Dictionary=entries[index]
		if not is_instance_valid(entry.actor) or entry.actor.is_queued_for_deletion():
			release(entry)
			discard(entry)
			entries.remove_at(index)
			continue
		var actor: Hostile=entry.actor
		# A soldier inside a vehicle is drawn by nobody: hide his instance
		# and keep his detailed meshes out of the tree until he steps out.
		if actor.vehicle!=null:
			if not entry.get("aboard",false):
				entry.aboard=true
				if not entry.far:
					entry.far=true
					set_far(entry,true)
				hide_slot(entry.team,entry.slot)
			continue
		if entry.get("aboard",false):
			entry.aboard=false
			entry.serial=-1
		var position := actor.global_position
		var distance := origin.distance_to(position)
		var limit: float=PERSONAL_NEAR if entry.personal else NEAR
		# The PSO-1 shows four times larger: judge detail by apparent size.
		if scope!=null and distance*0.25<limit+HYSTERESIS and scope.is_position_in_frustum(position+Vector3.UP):distance*=0.25
		var far: bool=distance>limit+HYSTERESIS if not entry.far else distance>limit
		if not far and distance>ALWAYS_NEAR and forward.dot((position+Vector3.UP-origin)/distance)<view_cos:far=true
		if far!=entry.far:
			entry.far=far
			set_far(entry,far)
			if far:entry.serial=-1
			else:hide_slot(entry.team,entry.slot)
		if not far:
			near_count+=1
			continue
		far_count+=1
		if actor.dead:
			# Ragdolls settle within seconds; afterwards refresh rarely.
			entry.dead_clock+=delta
			if entry.serial==actor.pose_serial and entry.dead_clock<(0.0 if float(entry.get("dead_age",0.0))<4.0 else 1.0):continue
			entry.dead_age=float(entry.get("dead_age",0.0))+entry.dead_clock
			entry.dead_clock=0.0
		elif entry.serial==actor.pose_serial:continue
		entry.serial=actor.pose_serial
		var parts: Array=multis[entry.team]
		var slot: int=entry.slot
		parts[0].set_instance_transform(slot,actor.model.global_transform)
		parts[1].set_instance_transform(slot,actor.n_legs[0].global_transform)
		parts[2].set_instance_transform(slot,actor.n_legs[1].global_transform)
		parts[3].set_instance_transform(slot,actor.n_knees[0].global_transform)
		parts[4].set_instance_transform(slot,actor.n_knees[1].global_transform)
