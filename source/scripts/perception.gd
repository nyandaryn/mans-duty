class_name Perception
extends RefCounted

# Gameplay recognition, not an optical sensor or a clinically calibrated vision model.
# Scores accumulate over time. A concealed target is harder to recognize, never invisible.
static func rate(distance: float, exposure: float, color_match: float, light: float, motion: float, recent_shot: float, foliage: float, prone: bool, ghillie: bool) -> float:
 if exposure<=0 or foliage<=0 or distance>220:return 0.0
 if distance<=10:return 9.0*maxf(exposure,0.35)
 var angular_size := pow(55.0/maxf(distance,10),1.45)
 var contrast := lerpf(1.5,0.32,clampf(color_match,0,1))
 var silhouette := 0.65 if prone else 1.0
 if ghillie and motion<0.15:silhouette*=lerpf(1.0,0.65,color_match)
 var movement := 1.0+clampf(motion/3,0,2)*2.0
 var result := angular_size*exposure*contrast*light*silhouette*movement*maxf(foliage,0.08)
 if recent_shot<1.2:result=result*4+exposure*maxf(0.2,2.5-distance/100)
 return clampf(result,0.008,12.0)

static func observe(bot: Node3D, player: Node3D, game: Node3D, eye: Vector3) -> Dictionary:
 if player is Hostile:return observe_soldier(bot,player,game,eye)
 var space := bot.get_world_3d().direct_space_state
 var samples: Array[Vector3]=[player.chest_area.global_position,player.abdomen_area.global_position,player.camera.global_position]
 var weights := [0.30,0.18,0.18]
 for area in player.arm_areas:
  samples.append(area.global_position)
  weights.append(0.10)
 for area in player.leg_areas:
  samples.append(area.global_position)
  weights.append(0.07)
 var aim_point: Vector3=player.camera.global_position
 var exposure := 0.0
 var light := 0.0
 var matching := 0.0
 var foliage := 0.0
 for i in range(samples.size()):
  var point: Vector3=samples[i]
  if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,point,1)).is_empty():continue
  if game.district.foliage_visibility(eye,point)<=0:continue
  if exposure==0:aim_point=point
  var weight: float=weights[i]
  exposure+=weight
  light+=game.district.light_at(point,game.sunlight.global_basis.z)*weight
  matching+=Wardrobe.match_color(player.outfit_id,game.district.background_color(eye,point))*weight
  foliage+=weight
 if exposure>0:
  light/=exposure
  matching/=exposure
  foliage/=exposure
 var distance := eye.distance_to(player.camera.global_position)
 var speed := Vector2(player.velocity.x,player.velocity.z).length()
 return {"aim_point":aim_point,"exposure":exposure,"light":light,"matching":matching,"foliage":foliage,"rate":rate(distance,exposure,matching,light,speed,player.since_shot,foliage,player.prone,player.outfit_id.begins_with("ghillie"))}

static func observe_soldier(observer: Node3D, soldier: Hostile, game: Node3D, eye: Vector3) -> Dictionary:
 var exposure := 0.0
 var light := 0.0
 var matching := 0.0
 var aim_point := soldier.global_position+Vector3.UP
 var space := observer.get_world_3d().direct_space_state
 var query := PhysicsRayQueryParameters3D.new()
 query.from=eye
 query.collision_mask=1
 var toward_sun: Vector3=game.sunlight.global_basis.z
 # Head, chest, abdomen and both knees: cached nodes, same anatomy as before.
 for node in soldier.sight_points:
  var point: Vector3=node.global_position
  query.to=point
  if not space.intersect_ray(query).is_empty():continue
  if game.district.foliage_visibility(eye,point)<=0:continue
  if exposure==0:aim_point=point
  exposure+=0.2
  light+=game.district.light_at(point,toward_sun)*0.2
  matching+=Wardrobe.match_color(soldier.outfit_id,game.district.background_color(eye,point))*0.2
 if exposure>0:
  light/=exposure
  matching/=exposure
 var speed := Vector2(soldier.velocity.x,soldier.velocity.z).length()
 return {"aim_point":aim_point,"exposure":exposure,"light":light,"matching":matching,"foliage":1.0 if exposure>0 else 0.0,"rate":rate(eye.distance_to(aim_point),exposure,matching,light,speed,soldier.since_shot,1.0,maxf(soldier.collapse,soldier.tactical_prone)>0.5,soldier.outfit_id.begins_with("ghillie"))}
