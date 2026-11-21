class_name AssaultSquad
extends Node

const ORDERS = {"engage":"Знищити в секторі", "assault":"Штурмувати точку", "follow":"За мною", "move":"На позицію", "hold":"Тримати позицію", "cover":"Прикрити сектор", "cease":"Не стріляти", "free":"Вогонь дозволено"}
var game: Node3D
var selected := -1
var notice: Label
var point := Vector3.ZERO
var point_valid := false
var view_origin := Vector3.ZERO
var view_direction := Vector3.FORWARD
var notice_time := 0.0
var trail := PackedVector3Array()
var tactics_clock := 0.0
var commander_cover := false
var conceal_clock := 0.0

# The player no longer commands riflemen: personal allies exist only as the
# mortarman's crew, ordered through MortarCrew. Orders below remain the
# behaviour vocabulary of allied soldiers (the battle uses "assault").
func setup(owner_game: Node3D, _ui_root: Control) -> void:
 game=owner_game
 notice=game.label("",15,game.GOLD)
 notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 game.place(notice,game.hud,0.035,0.20,0.55,0.29)

func spawn() -> void:
 selected=-1
 trail=PackedVector3Array([game.player.global_position])
 tactics_clock=0
 commander_cover=false
 conceal_clock=0
 for i in range(game.ally_count):
  var actor := Hostile.new()
  actor.friendly=true
  actor.formation_index=i
  game.add_child(actor)
  var desired: Vector3=formation_point(i)
  var cell: Vector2i=game.district.nearest_cell(game.district.navigation_cell(desired))
  var position: Vector3=game.district.navigation_position(cell)+Vector3.UP*0.15
  actor.setup(game,position)
  actor.rotation.y=game.player.rotation.y
  actor.defensive=true
  actor.defense_radius=7
  actor.has_cover=false
  actor.order_point=position
  game.allies.append(actor)
  var tag := Label3D.new()
  tag.text="%02d" % (i+1)
  tag.font_size=40
  tag.pixel_size=0.008
  tag.position.y=0.45
  tag.modulate=Color("a5c8cf")
  tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  tag.visibility_range_end=45
  actor.model.get_node("Head").add_child(tag)

func stealth_follow() -> bool:
 return game.player.crouched or game.player.prone or (commander_cover and Vector2(game.player.velocity.x,game.player.velocity.z).length()<4.5)

func trail_point(distance: float) -> Vector3:
 var last: Vector3=game.player.global_position
 for i in range(trail.size()-1,-1,-1):
  var segment := last.distance_to(trail[i])
  if segment>=distance:return last.move_toward(trail[i],distance)
  distance-=segment
  last=trail[i]
 return last+game.player.global_basis.z*distance

func formation_point(index: int) -> Vector3:
 var row := int(index/2)
 var setback := 3.5+row*2.8
 var sign_side := -1.0 if index%2==0 else 1.0
 var result: Vector3
 if stealth_follow() and trail.size()>1:
  result=trail_point(setback)
  # A narrow file uses the commander's actual trail around trunks and corners.
  var tangent := trail_point(maxf(0,setback-1))-trail_point(setback+1)
  tangent.y=0
  var side := Vector3(-tangent.z,0,tangent.x).normalized()
  result+=side*sign_side*0.48
 else:
  var width := 0.55 if stealth_follow() else 2.2+row*0.35
  result=game.player.global_position+game.player.global_basis*Vector3(sign_side*width,0,setback)
 result.y=game.district.ground_height(result)+0.1
 return result

func prepare_actor(actor: Hostile, delta: float=0.0) -> void:
 actor.exposed_time=actor.exposed_time+delta if actor.under_fire_time>0 and not actor.has_cover else 0.0
 actor.home=formation_point(actor.formation_index) if actor.order=="follow" else actor.order_point
 actor.defense_radius=18 if actor.order=="follow" else 6
 actor.follow_concealment=actor.order=="follow" and stealth_follow()
 actor.follow_crouch=actor.order=="follow" and game.player.crouched
 actor.follow_prone=actor.order=="follow" and game.player.prone
 # The mortar assistant kneels at the plate while the crew lays the mortar.
 if actor.get_meta("crew_kneel",false):actor.follow_crouch=true
 if actor.order=="assault":
  if Vector2(actor.position.x-actor.order_point.x,actor.position.z-actor.order_point.z).length()<2 and absf(actor.position.y-actor.order_point.y)<2:
   actor.assault_arrived=true
  if actor.has_cover and actor.global_position.distance_to(actor.cover_point)<1.1:actor.cover_dwell+=delta
  else:actor.cover_dwell=0
 if actor.order=="cover":
  actor.home=actor.get_meta("hold_point",actor.global_position)
  actor.squad_role="cover" if (actor.has_cover and actor.global_position.distance_to(actor.cover_point)<0.9) or (not actor.has_cover and actor.under_fire_time<=0) else ""
  if game.elapsed<float(actor.get_meta("cover_until",0)) and actor.fire_at_will:
   actor.alerted=true
   actor.suppress_point=actor.order_point
   actor.suppress_age=0
   actor.target=actor.order_point-Vector3.UP
 elif actor.auto_cover and actor.has_cover and actor.global_position.distance_to(actor.cover_point)<0.9:
  actor.squad_role="cover"
 else:actor.squad_role=""

func threat_point(actor: Hostile) -> Vector3:
 if actor.suppress_age<12:return actor.suppress_point
 if actor.alerted and actor.contact_age<15:return actor.target+Vector3.UP*1.5
 if actor.order in ["engage","assault"]:return actor.global_position+actor.order_direction*70+Vector3.UP*1.6
 # No enemy coordinates: without a contact only screen the commander's heading.
 return game.player.global_position-game.player.global_basis.z*45+Vector3.UP*1.6

func in_order_sector(actor: Hostile, position: Vector3) -> bool:
 var direction := position-actor.order_origin
 direction.y=0
 return direction.length()<2 or actor.order_direction.dot(direction.normalized())>=cos(deg_to_rad(40))

func contact_priority(actor: Hostile, position: Vector3) -> float:
 if actor.order!="engage":return 0.0
 if in_order_sector(actor,position):return 40.0
 # A visible close threat is still eligible for self-defence. This never
 # supplies aim coordinates: the shared perception checks run afterwards.
 return 0.0 if actor.global_position.distance_to(position)<8 else -1.0

func look_direction(actor: Hostile, movement_direction: Vector3) -> Vector3:
 if actor.order in ["engage","assault"]:
  var remembered := actor.alerted and actor.contact_age<8
  if actor.order=="engage":remembered=remembered and (in_order_sector(actor,actor.target) or actor.under_fire_time>0)
  if actor.sees_player or remembered:return actor.target-actor.position
  if actor.order=="assault" and movement_direction.length()>0.1:return movement_direction
  return actor.order_direction.rotated(Vector3.UP,sin(actor.age*0.55)*0.30)
 if actor.alerted:return actor.target-actor.position
 if movement_direction.length()>0.1:return movement_direction
 var heading:Vector3=-game.player.global_basis.z if actor.order=="follow" else actor.order_direction
 return heading.rotated(Vector3.UP,sin(actor.age*0.4+actor.formation_index)*0.45)

func assault_advancing(actor: Hostile) -> bool:
 return actor.order=="assault" and not actor.assault_arrived and not actor.auto_cover and actor.cover_dwell>=2.6 and actor.suppression<1.8 and actor.weapon.phase=="" and actor.collapse<0.1 and actor.treatment_time<=0

func protection(actor: Hostile, point: Vector3, height: float, concealment: bool=false) -> float:
 var threat := threat_point(actor)
 var direction := (point-threat).normalized()
 var side := Vector3(-direction.z,0,direction.x)*0.22
 var covered := 0.0
 for offset in [Vector3.ZERO,side,-side]:
  var sample: Vector3=point+Vector3.UP*height+offset
  # A fence panel hides a man (three quarters of a wall's worth), it does not
  # stop a bullet.
  var between: int=actor.obstruction(threat,sample)
  if between==2:covered+=1.0/3
  elif between==1:covered+=0.25
  elif concealment and game.district.foliage_visibility(threat,sample)<=0:covered+=0.22
 return covered

func occupied(actor: Hostile, point: Vector3) -> bool:
 for other in game.allies:
  if other!=actor and not other.dead and other.has_cover and other.cover_point.distance_to(point)<1.35:return true
 return false

# The assault is halted: battle groups consolidate behind cover and wait.
func holding(actor: Hostile) -> bool:
 return game.battle.active and game.battle.halted and actor.get_meta("battle_managed",false)

# No enemy seen, heard or shooting lately.
func quiet(actor: Hostile) -> bool:
 return not actor.sees_player and actor.contact_age>8 and actor.suppress_age>8 and actor.under_fire_time<=0

func find_cover(actor: Hostile, wounded: bool=false) -> void:
 actor.cover_timer=1.1+actor.formation_index*0.09
 var danger := actor.under_fire_time>0 or (actor.alerted and actor.contact_age<12)
 var concealment := actor.follow_concealment and not danger
 var hold := holding(actor)
 # A waiting soldier kneels behind cover: judge protection at kneeling height.
 var height := 1.0 if hold else 1.42
 var current := protection(actor,actor.global_position,0.60 if wounded or actor.follow_prone else height,concealment)
 var assault_bound := not wounded and assault_advancing(actor)
 # Halted: keep the chosen cover while it still shields; no hopping between
 # positions, a fresh choice at most every few seconds.
 if hold and actor.has_cover and actor.cover_point.distance_to(actor.home)<=19:
  # Every new sighting moves the threat point; a fresh shooter elsewhere is
  # not a reason to run. The spot is kept while it shields at least a third,
  # and for 6 s in any case.
  var kept: float=game.elapsed-float(actor.get_meta("cover_since",-100.0))
  var shield := protection(actor,actor.cover_point,0.6 if actor.cover_requires_prone else height)
  if shield>=0.33 or kept<6.0:
   actor.cover_timer=4.0+randf()*2.0
   return
 # Finish the current bound before choosing another destination.
 if not wounded and actor.order=="assault" and actor.has_cover and actor.global_position.distance_to(actor.cover_point)>1.1 and protection(actor,actor.cover_point,0.6 if actor.cover_requires_prone else height)>=0.65:return
 # Stay in good cover while the commander hides. Formation changes cannot pull
 # a suppressed soldier back into the same exposed lane.
 if not assault_bound and current>=0.98 and (actor.global_position.distance_to(actor.home)<4 or actor.under_fire_time>0 or actor.auto_cover or actor.order=="assault"):
  actor.has_cover=true
  actor.cover_point=actor.global_position
  actor.cover_requires_prone=wounded or actor.follow_prone
  if hold:actor.set_meta("cover_since",game.elapsed)
  return
 var advancing := assault_bound or (actor.order in ["follow","move"] and current>0.65 and actor.global_position.distance_to(actor.home)>8 and not actor.auto_cover and actor.under_fire_time<=0)
 var candidates: Array[Vector3]=[actor.global_position,actor.home]
 var rings:Array=[3.0,7.0,12.0,16.0,19.0] if game.battle.active else [1.5,3.0,5.0,8.0,12.0]
 var rays:=8 if game.battle.active else 16
 for radius in rings:
  for i in range(rays):
   var angle := float(i)*TAU/rays
   candidates.append(actor.global_position+Vector3(cos(angle)*radius,0,sin(angle)*radius))
 # Geometry samples find the protected side of thin trunks, which a coarse ring
 # alone almost always misses. Positions are then snapped to navigable ground.
 var eye := actor.global_position+Vector3.UP
 var geometry_rays:=8 if game.battle.active else 20
 for i in range(geometry_rays):
  var direction := Vector3(cos(float(i)*TAU/geometry_rays),0,sin(float(i)*TAU/geometry_rays))
  var hit: Dictionary=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye+direction*11,1))
  if hit.is_empty():continue
  var away := (Vector3(hit.position)-threat_point(actor)).normalized()
  away.y=0
  for depth in [0.8,1.6,2.4]:candidates.append(Vector3(hit.position)+away*depth)
 var ranked: Array[Dictionary]=[]
 var used: Dictionary={}
 for candidate in candidates:
  var cell: Vector2i=game.district.nearest_cell(game.district.navigation_cell(candidate))
  if used.has(cell) or not game.district.grid.region.has_point(cell) or game.district.grid.is_point_solid(cell):continue
  used[cell]=true
  var point: Vector3=game.district.navigation_position(cell)+Vector3.UP*0.1
  var travel := actor.global_position.distance_to(point)
  if travel>(20 if game.battle.active else 14) or occupied(actor,point):continue
  # Halted groups look for cover around where they stopped, not only at it.
  if (actor.order in ["hold","cover","engage"] or actor.assault_arrived) and point.distance_to(actor.home)>(18 if hold else 6):continue
  # Under fire a halted soldier does not run far across open ground for cover.
  if hold and danger and travel>12:continue
  if assault_bound and point.distance_to(actor.home)>actor.global_position.distance_to(actor.home)-2:continue
  var low := wounded or actor.follow_prone
  var shield := protection(actor,point,0.60 if low else height,concealment)
  if shield<0.65 and (danger or hold) and not low:
   low=true
   shield=protection(actor,point,0.60)
  if shield< (0.6 if concealment else 0.65):continue
  var score := travel*(0.7 if hold else 1.25)+point.distance_to(actor.home)*(3.3 if advancing else 0.45)+(1-shield)*8+(3 if low and not actor.follow_prone else 0)
  if danger or hold:
   var advance := actor.global_position.distance_to(threat_point(actor))-point.distance_to(threat_point(actor))
   score+=maxf(0,advance)*(0.35 if advancing else 1.5)
  ranked.append({"point":point,"score":score,"prone":low})
 ranked.sort_custom(func(a,b):return float(a.score)<float(b.score))
 var best_score := INF
 var best: Dictionary={}
 var best_route := PackedVector2Array()
 for candidate in ranked.slice(0,3 if game.battle.active else 6):
  if not game.battle.budget("path"):break
  var route: PackedVector2Array=game.district.path(actor.global_position,candidate.point)
  if route.is_empty():continue
  var score: float=candidate.score
  var exposed := 0.0
  for j in range(1,route.size(),maxi(1,int(route.size()/8))):
   var sample := Vector3(route[j].x,0,route[j].y)
   sample.y=game.district.ground_height(sample)+0.1
   exposed+=1.0-protection(actor,sample,0.55 if candidate.prone else 1.1,concealment)
  score+=exposed*(2.5 if danger else 1.0)
  if score<best_score:
   best_score=score
   best=candidate
   best_route=route
 if not best.is_empty():
  if actor.cover_point.distance_to(best.point)>1.1:actor.cover_dwell=0
  actor.has_cover=true
  actor.cover_point=best.point
  actor.cover_requires_prone=best.prone
  actor.path=best_route
  actor.path_index=1 if best_route.size()>1 else 0
  actor.path_timer=0.7
  actor.state="seek_cover"
  if hold:actor.cover_timer=4.0+randf()*2.0;actor.set_meta("cover_since",game.elapsed)
 # Halted with nothing better around: stay at the old cover rather than lie in the open.
 elif (current<0.6 or (assault_bound and actor.under_fire_time<=0)) and not (hold and actor.has_cover):
  actor.has_cover=false
  actor.cover_requires_prone=false
  actor.path_timer=0
  # Allow a short opportunity to leave cover when no better protected point
  # exists; do not reselect the position just vacated on the next think tick.
  if assault_bound:actor.cover_timer=2.0

func destination(actor: Hostile) -> Vector3:
 if actor.flank_timer>0:return actor.flank_point
 var danger := actor.under_fire_time>0 or (actor.alerted and actor.contact_age<12)
 if actor.has_cover:
  var lag := actor.cover_point.distance_to(actor.home)
  if actor.order in ["engage","assault"] or danger or actor.auto_cover or lag<(12 if actor.follow_concealment else 7):return actor.cover_point
  actor.has_cover=false
  actor.cover_requires_prone=false
 var desired: Vector3=actor.home
 # Under fire with no usable cover: lower the silhouette before moving on.
 if actor.under_fire_time>0 and not actor.has_cover and actor.exposed_time<1.25:return actor.global_position
 if game.district.off_grid(desired):return desired
 var cell: Vector2i=game.district.nearest_cell(game.district.navigation_cell(desired))
 var reachable: Vector3=game.district.navigation_position(cell)
 if Vector2(reachable.x-desired.x,reachable.z-desired.z).length()>4:return actor.global_position
 return reachable

func posture(actor: Hostile, moving: bool) -> float:
 if actor.follow_prone:return 1.0
 # Halted: kneel behind cover (or lie behind low cover) and stay that way,
 # firing from there; with no cover, lie down where they stopped.
 if holding(actor):
  if actor.has_cover and actor.global_position.distance_to(actor.cover_point)<1.8:return 1.0 if actor.cover_requires_prone else 0.0
  if not actor.has_cover and not moving:return 1.0
  if moving:return 0.0
 if actor.cover_requires_prone and (not moving or actor.global_position.distance_to(actor.cover_point)<1.5):
  # Briefly rise for a checked peek, then conceal again. Following a prone
  # commander always takes priority; a blocked muzzle still cannot shoot.
  if not moving and (actor.auto_cover or actor.order in ["cover","engage","assault"]) and (actor.peek_top or actor.peek_side!=0) and fmod(actor.peek_clock,4.8)>3.6:return 0.0
  return 1.0
 if actor.under_fire_time>0 and not actor.has_cover:return 1.0
 return 0.0

func movement(actor: Hostile, direction: Vector3, goal: Vector3) -> float:
 var moving := direction.length()>0.1
 var distance := actor.global_position.distance_to(goal)
 var hurry := actor.has_cover and distance>0.9 and actor.under_fire_time>0
 var commander_speed: float=Vector2(game.player.velocity.x,game.player.velocity.z).length()
 var advancing := actor.order=="assault" and not actor.assault_arrived and distance>2
 # A halted soldier shifts a few metres between covers bent low, not running.
 if holding(actor) and distance<4:
  actor.sprinting=false
  return 0.85 if actor.tactical_prone>0.5 else 2.1
 actor.sprinting=moving and actor.tactical_prone<0.1 and actor.leg_wound<0.25 and actor.arm_wound<0.5 and actor.weapon.phase=="" and (hurry or advancing or (not actor.follow_concealment and ((actor.order=="follow" and commander_speed>4.5) or distance>8)))
 if actor.tactical_prone>0.5:return 0.85
 if actor.sprinting:return 6.5 if hurry else 6.8
 return 2.1 if actor.follow_crouch or actor.stance>0.5 else 3.8

func coordinate() -> void:
 var eligible: Array[Hostile]=[]
 for actor in game.allies:
  actor.auto_cover=false
  if actor.dead or actor.vehicle!=null or actor.order not in ["follow","move","assault"] or not actor.fire_at_will or actor.collapse>0.1 or actor.weapon.phase!="" or actor.weapon.ammunition_total()==0:continue
  if actor.order=="assault" and not actor.assault_arrived and actor.cover_dwell>6.5 and not actor.get_meta("battle_managed",false):continue
  if actor.contact_age>12 and actor.suppress_age>8:continue
  if actor.has_cover and actor.global_position.distance_to(actor.cover_point)<1.1:eligible.append(actor)
 # One protected soldier covers while the rest seek their next positions.
 # A lone, hurt or empty soldier cannot hold up the group indefinitely.
 var groups:Dictionary={}
 for actor in eligible:
  var group:int=actor.get_meta("battle_group",-1) if game.battle.active else -1
  if not groups.has(group):groups[group]=[]
  groups[group].append(actor)
 for group in groups:
  var candidates:Array=groups[group]
  if game.allies.filter(func(a):return not a.dead).size()<2:continue
  var actor:Hostile=candidates[int(game.elapsed/4.5)%candidates.size()]
  actor.auto_cover=true
  if actor.squad_role!="cover":game.cover_voice(actor)

func commander_uses_cover() -> bool:
 var eye: Vector3=game.player.global_position+Vector3.UP*1.1
 var forward: Vector3=-game.player.global_basis.z
 for angle in [0.0,-0.22,0.22,-0.5,0.5,-1.1,1.1]:
  var end := eye+forward.rotated(Vector3.UP,angle)*3.5
  var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,end,1))
  if not hit.is_empty() and absf(Vector3(hit.normal).y)<0.7:return true
 return false

func _physics_process(delta: float) -> void:
 if not is_instance_valid(game) or not game.running or game.paused:return
 conceal_clock-=delta
 if conceal_clock<=0:
  conceal_clock=0.25
  commander_cover=commander_uses_cover()
 var position: Vector3=game.player.global_position
 if trail.is_empty() or trail[-1].distance_to(position)>20:trail=PackedVector3Array([position])
 elif trail[-1].distance_to(position)>0.65:
  trail.append(position)
  if trail.size()>128:trail.remove_at(0)
 tactics_clock-=delta
 if tactics_clock<=0:
  tactics_clock=0.45
  coordinate()

func separate(actor: Hostile, direction: Vector3) -> Vector3:
 if direction.length()<0.1:return direction
 var push := Vector3.ZERO
 for other in [game.player]+game.allies:
  if other==actor or not is_instance_valid(other) or (other is Hostile and (other.dead or other.vehicle!=null)):continue
  var away: Vector3=actor.global_position-other.global_position
  away.y=0
  if away.length()>0.01 and away.length()<1.1:push+=away.normalized()*(1.1-away.length())*1.2
 var result := direction+push
 # Steering is constrained by physical collision; navigation still chooses doors.
 return result.normalized() if result.length()>1 else result

func aim_point() -> void:
 var camera: Camera3D=game.player.camera
 view_origin=camera.global_position
 view_direction=-camera.global_basis.z
 view_direction.y=0
 if view_direction.length()<0.01:view_direction=-game.player.global_basis.z
 view_direction=view_direction.normalized()
 var ray := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*120,1)
 var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
 point_valid=not hit.is_empty()
 if point_valid:point=hit.position

func close() -> void:
 game.close_panels()

func choose(index: int) -> void:
 selected=index
 tell("Група" if selected<0 else "Боєць %02d" % (selected+1))

func cycle() -> void:
 for offset in range(1,game.allies.size()+2):
  var index: int=(selected+offset+1)%(game.allies.size()+1)-1
  if index<0 or (not game.allies[index].dead and not game.allies[index].get_meta("battle_managed",false)):
   choose(index)
   return

func targets() -> Array:
 if selected>=0 and selected<game.allies.size():return [game.allies[selected]]
 return game.allies.filter(func(actor):return not actor.get_meta("battle_managed",false))

func issue(id: String) -> void:
 if not game.running or game.paused or not ORDERS.has(id):return
 if id in ["move","cover","assault"] and not point_valid:
  tell("Спочатку вкажи поверхню прицілом")
  return
 var accepted := 0
 var unreachable := 0
 for actor in targets():
  if actor.dead:continue
  if id in ["cease","free"]:
   actor.fire_at_will=id=="free"
   actor.burst_left=0
  else:
   var destination: Vector3=actor.global_position
   if id in ["move","assault"]:
    var offset := Vector3.ZERO
    if selected<0:
     var side := Vector3(-view_direction.z,0,view_direction.x)
     offset=side*((actor.formation_index%2)*3-1.5)-view_direction*float(actor.formation_index/2)*2.5
    destination=point+offset
    var cell: Vector2i=game.district.nearest_cell(game.district.navigation_cell(destination))
    var snapped: Vector3=game.district.navigation_position(cell)
    var route: PackedVector2Array=game.district.path(actor.global_position,snapped)
    if Vector2(snapped.x-destination.x,snapped.z-destination.z).length()>4 or absf(snapped.y-point.y)>2.5 or route.is_empty():
     unreachable+=1
     continue
    destination=snapped
   actor.order=id
   actor.order_point=point if id=="cover" else destination
   actor.order_origin=view_origin
   actor.order_direction=view_direction
   actor.assault_arrived=false
   actor.cover_dwell=0
   if id in ["engage","assault"]:
    actor.fire_at_will=true
    actor.burst_left=0
    actor.think_timer=0
    # A command is a direction, not proof of a contact. Existing visual and
    # hearing memory remain subject to their normal expiry and perception.
    actor.sees_player=false
    actor.recognition=0
   actor.set_meta("hold_point",actor.global_position)
   actor.set_meta("cover_until",game.elapsed+20)
   actor.has_cover=false
   actor.cover_requires_prone=false
   actor.auto_cover=false
   actor.flank_timer=0
   actor.path_timer=0
   actor.path=PackedVector2Array()
   actor.path_index=0
   actor.cover_timer=0
   actor.squad_role="cover" if id=="cover" else ""
  accepted+=1
 tell("%s · прийняли: %d%s" % [ORDERS[id],accepted," · немає проходу: %d" % unreachable if unreachable>0 else ""])

func tell(message: String) -> void:
 notice.text=message
 notice_time=5

func _process(delta: float) -> void:
 if not is_instance_valid(game) or not game.running or game.paused:return
 notice_time=maxf(0,notice_time-delta)
 if notice_time==0:notice.text=""

func clear_fire_lane(actor: Hostile, origin: Vector3, endpoint: Vector3) -> void:
 if actor.flank_timer>0 or actor.follow_prone or actor.collapse>0.1:return
 var direction:=origin.direction_to(endpoint)
 var side:=Vector3(-direction.z,0,direction.x).normalized()
 for sign_side in [-1,1]:
  var point:Vector3=actor.position+side*sign_side*2.0
  point=game.district.navigation_position(game.district.nearest_cell(game.district.navigation_cell(point)))
  if point.distance_to(actor.position)>3 or not actor.line_clear(actor.position+Vector3.UP,point+Vector3.UP):continue
  if actor.under_fire_time>0 and protection(actor,point,0.6)<0.65:continue
  if not actor.safe_fire_lane(point+Vector3.UP,endpoint) or not game.battle.budget("path"):continue
  var route:PackedVector2Array=game.district.path(actor.position,point)
  if route.size()<2:continue
  actor.flank_point=point;actor.flank_timer=2.5;actor.has_cover=false
  actor.path=route;actor.path_index=1;actor.path_timer=1.0;actor.cover_timer=2.5
  return
