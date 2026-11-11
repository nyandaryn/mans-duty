class_name Ballistics
extends Node

# Invisible projectiles; every physics step sweeps a segment to prevent tunnelling.
# Speeds are representative game values, not ammunition-specific firing tables.
const PROFILES = {
	"ak74": {"speed": 880.0, "drag": 0.00055, "zero": 100.0},
	"m16": {"speed": 940.0, "drag": 0.00050, "zero": 100.0},
	"pm": {"speed": 315.0, "drag": 0.00085, "zero": 25.0},
	"m9": {"speed": 365.0, "drag": 0.00075, "zero": 25.0}
}
const GRAVITY := Vector3(0,-9.81,0)
var game: Node3D
var projectiles: Array[Dictionary] = []
var hit_count := 0

static func advance(position: Vector3, velocity: Vector3, drag: float, delta: float) -> Array[Vector3]:
	var acceleration := GRAVITY-velocity*velocity.length()*drag
	return [position+velocity*delta+acceleration*(0.5*delta*delta),velocity+acceleration*delta]

func launch(origin: Vector3, direction: Vector3, weapon: String, damage: float, shooter: CollisionObject3D) -> void:
	var profile: Dictionary = PROFILES[weapon]
	projectiles.append({"weapon":weapon,"position":origin,"velocity":direction.normalized()*float(profile.speed),"speed":profile.speed,"drag":profile.drag,"damage":damage,"shooter":weakref(shooter),"exclude":[shooter.get_rid()],"age":0.0,"distance":0.0})
	for area in shooter.find_children("Hit_*","Area3D",true,false):projectiles[-1].exclude.append(area.get_rid())

func clear() -> void:
	projectiles.clear()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.running or game.paused:return
	var space := game.get_world_3d().direct_space_state
	for index in range(projectiles.size()-1,-1,-1):
		var bullet: Dictionary=projectiles[index]
		var position: Vector3=bullet.position
		var next := advance(position,bullet.velocity,float(bullet.drag),delta)
		var exclusions: Array[RID] = []
		for rid in bullet.exclude:exclusions.append(rid)
		var query := PhysicsRayQueryParameters3D.create(position,next[0],1|16,exclusions)
		query.hit_from_inside=true
		query.collide_with_areas=true
		var hit := space.intersect_ray(query)
		bullet.age+=delta
		bullet.distance+=position.distance_to(next[0])
		var segment_end: Vector3=hit.position if not hit.is_empty() else next[0]
		var shooter: Object=bullet.shooter.get_ref()
		for bot in game.bots:
			if bot.dead or bot==shooter:continue
			var near := Geometry3D.get_closest_point_to_segment(bot.global_position+Vector3.UP,position,segment_end)
			if near.distance_to(bot.global_position+Vector3.UP)<1.8:
				bot.suppress(position,0.8)
		if not hit.is_empty():
			var actor: Object=hit.collider.get_meta("actor") if hit.collider.has_meta("actor") else null
			var energy_factor := clampf(next[1].length_squared()/(float(bullet.speed)*float(bullet.speed)),0.3,1.0)
			if actor!=null and actor!=shooter and actor.has_method("receive_hit"):
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
				game.impact(hit.position,hit.normal)
			hit_count+=1
			projectiles.remove_at(index)
			# A hit may finish the match. Never deliver queued damage after victory/death.
			if not game.running:
				clear()
				return
		elif float(bullet.age)>3.0 or float(bullet.distance)>1200 or next[0].y< -10:
			projectiles.remove_at(index)
		else:
			bullet.position=next[0]
			bullet.velocity=next[1]
