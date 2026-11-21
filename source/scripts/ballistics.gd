class_name Ballistics
extends Node

# Invisible projectiles; every physics step sweeps a segment to prevent tunnelling.
# Speeds are representative game values, not ammunition-specific firing tables.
const PROFILES = {
	"svd": {"speed": 830.0, "zero": 100.0},
	"ak74": {"speed": 880.0, "zero": 100.0},
	"m16": {"speed": 940.0, "zero": 100.0},
	"pm": {"speed": 315.0, "zero": 25.0},
	"m9": {"speed": 365.0, "zero": 25.0}
}
var game: Node3D
var projectiles: Array[Dictionary] = []
var hit_count := 0
var wind := Vector3.ZERO
# Living soldiers by 8 m cell, rebuilt once per physics tick for near-miss tests.
var nearby: Dictionary = {}
var indexed := false

func index_soldiers() -> void:
	nearby.clear()
	for team in [game.bots,game.allies]:
		for bot in team:
			if bot.dead or bot.vehicle!=null:continue
			var chest: Vector3=bot.global_position+Vector3.UP
			var key := Vector2i(floori(chest.x/8),floori(chest.z/8))
			if not nearby.has(key):nearby[key]=[]
			nearby[key].append([bot,chest])

func launch(origin: Vector3, direction: Vector3, weapon: String, damage: float, shooter: CollisionObject3D) -> void:
	var profile: Dictionary = PROFILES[weapon]
	# A soldier updated at a reduced rate moves several ticks at once; its
	# velocity, not the per-tick displacement, is the motion the bullet inherits.
	var carried := Vector3.ZERO
	if shooter is Hostile:carried=shooter.velocity
	elif shooter is CharacterBody3D:carried=shooter.get_real_velocity()
	projectiles.append({"weapon":weapon,"position":origin,"velocity":direction.normalized()*float(profile.speed)+carried,"speed":profile.speed,"drag":FlightModel.BC[weapon],"damage":damage,"shooter":weakref(shooter),"exclude":[shooter.get_rid()],"age":0.0,"distance":0.0,"crossings":[],"suppressed":{}})
	var areas: Array=shooter.hitboxes if shooter is Hostile else shooter.find_children("Hit_*","Area3D",true,false)
	for area in areas:
		if area.get_meta("actor",null)==shooter:projectiles[-1].exclude.append(area.get_rid())

func clear() -> void:
	projectiles.clear()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.running or game.paused:return
	if not projectiles.is_empty():index_soldiers()
	indexed=true
	var remaining := delta
	while remaining>0.0000001 and game.running:
		var step := minf(remaining,FlightModel.MAX_STEP)
		step_projectiles(step)
		remaining-=step
	indexed=false

func step_projectiles(delta: float) -> void:
	if not is_instance_valid(game) or not game.running or game.paused:return
	var space := game.get_world_3d().direct_space_state
	if not indexed:index_soldiers()
	# Drones in the air: a round going close past one is a warning to its pilot.
	var drones: Array=[]
	for drone in game.get_tree().get_nodes_in_group("drones"):
		if drone.flying():drones.append(drone)
	for index in range(projectiles.size()-1,-1,-1):
		var bullet: Dictionary=projectiles[index]
		var position: Vector3=bullet.position
		var next := FlightModel.advance(position,bullet.velocity,float(bullet.drag),delta,wind)
		var exclusions: Array[RID] = []
		for rid in bullet.exclude:exclusions.append(rid)
		# Retain exclusions only while crossing that solid. Overlapping materials
		# still receive their own hit and energy cost in the same physics step.
		for c in bullet.crossings.duplicate():
			if (position-Vector3(c.exit)).dot(Vector3(c.direction))>0.001:bullet.crossings.erase(c)
			else:exclusions.append(c.rid)
		var hit: Dictionary={}
		var ray_start := position
		for layer in range(24):
			var ray_end: Vector3=next[0]
			var crossing_exit: Dictionary={}
			var travel_direction := ray_start.direction_to(ray_end)
			for crossing in bullet.crossings:
				var along: float=(Vector3(crossing.exit)-ray_start).dot(travel_direction)
				if along>=0 and along<ray_start.distance_to(ray_end):
					ray_end=ray_start+travel_direction*along
					crossing_exit=crossing
			var query := PhysicsRayQueryParameters3D.create(ray_start,ray_end,1|16,exclusions)
			query.hit_from_inside=true
			query.collide_with_areas=true
			hit=space.intersect_ray(query)
			if hit.is_empty():
				if not crossing_exit.is_empty():
					exclusions.erase(crossing_exit.rid)
					bullet.crossings.erase(crossing_exit)
					ray_start=ray_end+travel_direction*0.0005
					if layer==23:next[0]=ray_start
					continue
				break
			if hit.collider.has_meta("actor"):break
			var body: CollisionObject3D=hit.collider
			var direction: Vector3=next[1].normalized()
			var exit: Variant=null if body.has_meta("terrain") else Penetration.exit_point(body,int(hit.shape),hit.position,direction)
			var material: String=body.get_meta("ballistic_material","")
			if exit==null or material.is_empty():break
			var thickness: float=hit.position.distance_to(exit)
			# A sheet on a thicker collider (the corrugation of a fence): the metal
			# along the path, oblique hits longer as through the collider.
			thickness*=float(body.get_meta("sheet_scale",1.0))
			var before := Penetration.energy(bullet.weapon,next[1].length())
			var after := Penetration.remaining(bullet.weapon,next[1].length(),material,thickness)
			if body.has_method("strike"):body.strike(hit.position,direction,before-after,after>1.0)
			game.impact(hit.position,hit.normal,body)
			hit_count+=1
			if after<=1.0:
				# Already emitted entry effects; don't count or emit them twice.
				hit["surface_processed"]=true
				break
			var ratio := sqrt(after/before)
			next[1]*=ratio
			next[0]=Vector3(hit.position)+(next[0]-Vector3(hit.position))*ratio
			bullet.crossings.append({"rid":body.get_rid(),"exit":exit,"direction":direction})
			exclusions.append(body.get_rid())
			game.impact(exit,direction,body)
			ray_start=hit.position
			hit={}
			# A finite layer budget never permits skipping remaining geometry.
			if layer==23:next[0]=ray_start
		bullet.age+=delta
		bullet.distance+=position.distance_to(next[0])
		var segment_end: Vector3=hit.position if not hit.is_empty() else next[0]
		var shooter: Object=bullet.shooter.get_ref()
		var low := Vector2i(floori((minf(position.x,segment_end.x)-1.8)/8),floori((minf(position.z,segment_end.z)-1.8)/8))
		var high := Vector2i(floori((maxf(position.x,segment_end.x)+1.8)/8),floori((maxf(position.z,segment_end.z)+1.8)/8))
		for cx in range(low.x,high.x+1):
			for cz in range(low.y,high.y+1):
				for entry in nearby.get(Vector2i(cx,cz),[]):
					if not is_instance_valid(entry[0]):continue
					var bot: Hostile=entry[0]
					if bot.dead or bot==shooter:continue
					# Nearby friendly fire is not an enemy contact. Direct hits still hurt.
					if (shooter==game.player and bot.friendly) or (shooter is Hostile and shooter.friendly==bot.friendly) or (shooter is BmpVehicle and shooter.friendly==bot.friendly):continue
					var chest: Vector3=entry[1]
					var near := Geometry3D.get_closest_point_to_segment(chest,position,segment_end)
					var identity: int=bot.get_instance_id()
					if near.distance_to(chest)<1.8 and not bullet.suppressed.has(identity):
						# A near miss is one impulse per bullet, independent of substep size.
						bullet.suppressed[identity]=true
						bot.suppress(position,0.8)
		for drone in drones:
			if not (shooter is Hostile) or shooter.friendly==drone.friendly:continue
			var at: Vector3=drone.global_position
			if Geometry3D.get_closest_point_to_segment(at,position,segment_end).distance_to(at)<4.0:drone.near_miss()
		if not hit.is_empty():
			var actor: Object=hit.collider.get_meta("actor") if hit.collider.has_meta("actor") else null
			var energy_factor := clampf(next[1].length_squared()/(float(bullet.speed)*float(bullet.speed)),0.0,1.0)
			if actor is ReconDrone:
				actor.receive_hit(float(bullet.damage)*energy_factor,"drone",next[1].normalized(),hit.position)
				game.impact(hit.position,hit.normal)
			elif actor!=null and actor!=shooter and actor.has_method("receive_hit"):
				var zone: String=hit.collider.get_meta("zone","chest")
				if shooter==game.player:
					game.player.hits+=1
					game.hit_marker=0.15
				var area: Area3D=hit.collider
				var location := DamageModel.trajectory_location(area,hit.position,next[1].normalized())
				var wound := DamageModel.wound(zone,bullet.weapon,energy_factor,location,actor.plate_integrity)
				if actor!=game.player or not game.debug_invulnerable:
					actor.apply_wound(wound,zone,next[1].normalized(),hit.position)
					game.blood.add_wound(actor,area,hit.position,hit.normal,wound)
			elif actor==shooter:
				# Shooter's body areas are excluded at launch; defensive fallback.
				pass
			else:
				if not hit.get("surface_processed",false):game.impact(hit.position,hit.normal,hit.collider)
			if not hit.get("surface_processed",false):hit_count+=1
			projectiles.remove_at(index)
			# A hit may finish the match. Never deliver queued damage after victory/death.
			if not game.running:
				clear()
				return
		elif float(bullet.age)>8.0 or float(bullet.distance)>(1500 if bullet.weapon=="svd" else 1200) or next[0].y< (game.district.terrain.minimum-20 if game.district.terrain!=null else -10):
			projectiles.remove_at(index)
		else:
			bullet.position=next[0]
			bullet.velocity=next[1]
