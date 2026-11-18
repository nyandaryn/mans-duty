class_name RangeCourse
extends TrainingCourse

# Infantry courses on the training range: knock-down targets go up for the
# run, the soldier is put where a chapter starts, a step may watch for a short
# action (a magazine check, a measurement) that is over before it is checked.
var targets: Dictionary={}
var seen: Dictionary={}
var hits_at: Dictionary={}
var shots_at := 0
var blasts_at := 0

func target_ids() -> Array:return []
func preparing_text() -> String:return "Готуємо рубіж."
func loading_tip() -> String:
 return "Полігон без противника. Картка кроку — праворуч угорі, маркер показує, куди йти; F6 — виконати крок автоматично."

func player() -> Operator:return game.player
func weapon() -> WeaponState:return game.player.current()

func on_begin() -> void:
 clear_targets()
 seen.clear()
 for id in target_ids():
  targets[id]=RangeTarget.new().setup(game.world_root,id,TrainingRange.TARGETS[id])

func on_stop() -> void:
 clear_targets()

func clear_targets() -> void:
 for t in targets.values():
  if is_instance_valid(t):t.queue_free()
 targets.clear()

func on_enter(_id: String) -> void:
 seen.clear()
 for id in targets:hits_at[id]=targets[id].hits
 shots_at=player().shots if is_instance_valid(player()) else 0
 blasts_at=game.blasts.detonations

# Hits on a target since the step began.
func hits(id: String) -> int:
 return targets[id].hits-int(hits_at.get(id,0)) if targets.has(id) else 0

# F6 on a shooting step: the hits are counted as made.
func score(id: String, count: int) -> void:
 if targets.has(id):targets[id].hits=int(hits_at.get(id,0))+count

# Something seen at any moment of the step, kept until the step changes.
func saw(key: String, now: bool) -> bool:
 if now:seen[key]=true
 return seen.get(key,false)

func measured() -> bool:
 var rig: FieldRig=player().field_rig
 return saw("measure",rig.mode=="rangefinder" and rig.reading.length()>0 and rig.reading[0] in "0123456789")

func place(at: Vector3, look: Vector3) -> void:
 var p:=player()
 p.global_position=Vector3(at.x,game.district.ground_height(at)+0.1,at.z)
 p.velocity=Vector3.ZERO
 face(look)

func face(point: Vector3) -> void:
 var d: Vector3=player().global_position-point
 player().rotation.y=atan2(d.x,d.z)
 player().pitch=0.0

func stance(lying: bool, kneeling: bool=false) -> void:
 player().prone_requested=lying
 player().crouch_requested=kneeling and not lying

func target_marker(id: String, caption: String) -> Dictionary:
 return {"point":TrainingRange.TARGETS[id].point+Vector3.UP*(1.9 if TrainingRange.TARGETS[id].kind=="figure" else 1.1),"caption":caption}

# Over a panel the card goes to the bottom left: beside the map sheet and the
# mortar sight, over the soldier's portrait in the inventory — its buttons
# are on the right.
func layout_mode() -> String:
 if game.topo_map.visible or game.crew.sight.visible or game.inventory_open:return "compact_left"
 return "full"

# …and narrows to the room left of the panel.
func card_width() -> float:
 var edge := INF
 if game.topo_map.visible:edge=game.topo_map.get_global_rect().position.x+game.topo_map.sheet_rect().position.x
 elif game.crew.sight.visible:edge=game.crew.sight.sheet.get_global_rect().position.x
 elif game.inventory_open:edge=game.inventory.get_global_rect().position.x+game.inventory.size.x*CombatInventory.GEAR_LEFT
 if edge==INF:return CARD_WIDTH
 var room: float=edge-card.get_global_rect().position.x-16.0-38.0
 return clampf(floorf(room),250.0,CARD_WIDTH)

func markers_hidden() -> bool:
 if not is_instance_valid(player()):return true
 return game.topo_map.visible or game.inventory_open or game.crew.sight.visible or player().ads_weight>0.6 or player().field_rig.mode=="rangefinder"

func hits_text(id: String, need: int) -> String:
 return "Влучань: %d / %d" % [mini(hits(id),need),need]
