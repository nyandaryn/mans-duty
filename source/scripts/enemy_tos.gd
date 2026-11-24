class_name EnemyTos
extends Node

# The enemy's TOS-1A in the great assault (balance, VALIDATION «ТОС-1А»).
# One vehicle and one package of 24 rockets for the whole battle: reloading
# takes the TZM-T 24 minutes, more than a battle lasts. It waits in a tree
# line 3–3.6 km behind the village and fires only on what its drone
# observer reports: a group of ours standing still for half a minute — six
# men or two BMPs within 60 m, or a mortar that keeps firing from one place
# — within its range and at least 450 m from the defenders (its ellipse of
# 300 × 150 m would cover them too). From the report to the first rocket
# it takes 3–5 minutes: the report, the drive out to the firing position,
# 90 s to bring the vehicle into action. The salvo goes where the target
# was at the report: a column that has moved off by then is not hit.
# Twelve rockets a salvo, two salvos at most; after each it drives back
# into cover. Our radio intelligence takes the launch and reports its grid
# with an error of about 150 m (the «Grad» commander gets it as a target);
# a destroyed TOS fires no more.
const HIDE_RANGE := Vector2(3000.0,3600.0)
const HIDE_SPREAD := 0.35
const FIRE_OFFSET := Vector2(150.0,300.0)
const FIRST_LOOK := 60.0
const LOOK_PERIOD := 20.0
const SAMPLE_PERIOD := 5.0
const STILL_TIME := 30.0
const STILL_MOVE := 8.0
const CLUSTER := 60.0
const MEN := 6
const VEHICLES := 2
const SAFETY := 450.0
const DELAY := Vector2(180.0,300.0)
const READY := 90.0
const SALVO := 12
const SALVOS := 2
const MORTAR_ROUNDS := 6
const MORTAR_WINDOW := 180.0
const MORTAR_AREA := 30.0
# The drone's coordinates of a target (per axis, m) and of a mortar found by
# its sound (a wider guess).
const AIM_ERROR := 20.0
const MORTAR_ERROR := 45.0
const LOCATE_ERROR := 150.0
const LOCATE_DELAY := Vector2(30.0,60.0)
const REST := 60.0
static var battles := 0
# Set by a test to vary the TOS between seeded runs.
static var salt := 0
# The timings above, on the instance: a test shortens them to see a whole
# salvo in a minute or two.
var first_look := FIRST_LOOK
var delay_range := DELAY
var ready_time := READY
var game: Node3D
var battle: BattleMode
var vehicle: TosVehicle
var rng := RandomNumberGenerator.new()
var hide := Vector3.ZERO
var fire_point := Vector3.ZERO
# hidden / out / laying / firing / back / spent / dead
var state := "hidden"
var clock := 0.0
# Its effects' shaders drawn once a second into the battle, through the
# camera that is rendering by then (TosEffects.warm_up).
var warmed := false
var look_clock := 0.0
var sample_clock := 0.0
var still: Dictionary={}
# The planned salvo: {"aim", "kind", "reported", "fire_at"}; empty when none.
var plan: Dictionary={}
var arrived_at := -1.0
var salvo_started := -1.0
var salvo_done := -1.0
var salvos := 0
var located := Vector3.INF
var locate_at := -1.0
var rest_until := 0.0
# What it did, in order (the tests read it): [clock, event, detail].
var events: Array=[]

func setup(owner_game: Node3D, owner_battle: BattleMode) -> void:
 game=owner_game;battle=owner_battle;name="EnemyTos"
 # Its own sequence, never drawn from the game's: a seeded battle plays the
 # same with it on the field until it fires. In play every battle has
 # another place and another fall of shot (the clock); the tests and the
 # previews get the same one for the same battle, and a test may salt it.
 var key:="tos:%d:%s:%d:%d" % [game.battle_size,game.player_class,battles,salt]
 if not game.has_meta("automated_preview"):key+=":%d" % Time.get_ticks_usec()
 rng.seed=hash(key)
 battles+=1
 owner_battle.add_child(self)

func data() -> AvdiivkaData:return AvdiivkaData.shared()

func ground(point: Vector3) -> Vector3:
 return Vector3(point.x,data().height(point.x,point.z),point.z)

func note(event: String, detail: Variant=null) -> void:
 events.append([clock,event,detail])

# A tree line behind the village, the flattest of a few places; the firing
# position on open ground 150–300 m from it toward the village.
func deploy() -> void:
 var north:=BattleMap.north()
 var best:=Vector3.ZERO
 var best_score:=-INF
 for k in range(16):
  var angle:=rng.randf_range(-HIDE_SPREAD,HIDE_SPREAD)
  var flat:=north.rotated(angle)*rng.randf_range(HIDE_RANGE.x,HIDE_RANGE.y)
  var score:=data().normal_at(flat.x,flat.y).y
  if score>best_score:best_score=score;best=Vector3(flat.x,0,flat.y)
 hide=ground(best)
 var toward:=(Vector3.ZERO-hide);toward.y=0;toward=toward.normalized()
 var side:=toward.cross(Vector3.UP)
 fire_point=ground(hide+toward*rng.randf_range(FIRE_OFFSET.x,FIRE_OFFSET.y)+side*rng.randf_range(-60.0,60.0))
 vehicle=TosVehicle.new()
 vehicle.friendly=false
 game.world_root.add_child(vehicle)
 vehicle.setup(game,rng.randi())
 vehicle.name="EnemyTos"
 vehicle.place(hide,toward)
 note("deployed",hide)

func clear() -> void:
 if is_instance_valid(vehicle):vehicle.queue_free()
 vehicle=null

func active() -> bool:return state!="dead" and state!="spent"

func _physics_process(delta: float) -> void:
 if not game.running or game.paused or not battle.active or battle.finished or battle.skipping:return
 if not is_instance_valid(vehicle):return
 clock+=delta
 if not warmed and clock>1.0:warmed=true;TosEffects.warm_up(game)
 if vehicle.destroyed:
  if state!="dead":
   state="dead";plan.clear();note("destroyed")
   game.squad.tell("ТОС противника знищено")
  return
 sample_clock-=delta
 if sample_clock<=0.0:sample_clock=SAMPLE_PERIOD;sample()
 if locate_at>0.0 and clock>=locate_at:locate_at=-1.0;report_launch()
 match state:
  "hidden":
   if plan.is_empty():
    look_clock-=delta
    if look_clock<=0.0 and clock>=first_look and clock>=rest_until:
     look_clock=LOOK_PERIOD
     look()
   elif clock>=float(plan.fire_at)-ready_time-drive_time():go_out()
  "out":
   if not vehicle.moving() and vehicle.crawl<0.05:
    arrived_at=clock;state="laying"
    if not lay():abort("поза досяжністю")
  "laying":
   if clock>=maxf(float(plan.fire_at),arrived_at+ready_time) and vehicle.laid():
    if not safe(plan.aim):abort("свої поруч")
    elif vehicle.fire_salvo(mini(SALVO,vehicle.remaining())):
     state="firing";salvo_started=clock
     warn()
    elif vehicle.hull.weapon_out:abort("приціл розбито")
  "firing":
   if not vehicle.firing():
    if salvo_done<0.0:salvo_done=clock
    if clock-salvo_done>6.0:go_back()
  "back":
   if not vehicle.moving() and vehicle.crawl<0.05:
    vehicle.stow()
    state="hidden" if salvos<SALVOS and vehicle.has_rockets() else "spent"
    rest_until=clock+REST
    note("hidden")

func drive_time() -> float:
 return hide.distance_to(fire_point)/TosVehicle.FIELD_SPEED+15.0

# --- The observer ----------------------------------------------------------
# Who of ours is where, and since when he has stood there.
func units() -> Array:
 var list: Array=[]
 var player: Node3D=game.player
 if is_instance_valid(player) and not player.get_meta("battle_out",false) and not game.player_sheltered() and player.health>0:
  list.append([player,player.global_position,"man"])
 for actor in game.allies:
  if not is_instance_valid(actor) or actor.dead or actor.vehicle!=null:continue
  list.append([actor,actor.global_position,"man"])
 for squad in battle.mech:
  if not is_instance_valid(squad) or not is_instance_valid(squad.vehicle) or squad.vehicle.destroyed:continue
  list.append([squad.vehicle,squad.vehicle.global_position,"bmp"])
 return list

func sample() -> void:
 var seen:={}
 for entry in units():
  var id: int=(entry[0] as Object).get_instance_id()
  seen[id]=true
  var at: Vector3=entry[1]
  if not still.has(id) or Vector3(still[id].at).distance_to(at)>STILL_MOVE:still[id]={"at":at,"since":clock}
 for id in still.keys():
  if not seen.has(id):still.erase(id)

func look() -> void:
 var best: Dictionary={}
 var groups: Array=[]
 var standing: Array=[]
 for entry in units():
  var id: int=(entry[0] as Object).get_instance_id()
  if still.has(id) and clock-float(still[id].since)>=STILL_TIME:standing.append(entry)
 for entry in standing:
  var men:=0;var bmps:=0;var sum:=Vector3.ZERO
  for other in standing:
   if Vector3(other[1]).distance_to(entry[1])>CLUSTER:continue
   if other[2]=="bmp":bmps+=1
   else:men+=1
   sum+=other[1]
  if men>=MEN or bmps>=VEHICLES:groups.append({"aim":sum/float(men+bmps),"kind":"group","score":men+bmps*4})
 var mortar:=mortar_position()
 if mortar!=Vector3.INF:groups.append({"aim":mortar,"kind":"mortar","score":MORTAR_ROUNDS})
 for group in groups:
  if not reachable(group.aim) or not safe(group.aim):continue
  if best.is_empty() or int(group.score)>int(best.score):best=group
 if best.is_empty():return
 var error:=MORTAR_ERROR if best.kind=="mortar" else AIM_ERROR
 var aim: Vector3=best.aim+Vector3(rng.randfn(0.0,error),0,rng.randfn(0.0,error))
 plan={"aim":ground(aim),"kind":best.kind,"reported":clock,"fire_at":clock+rng.randf_range(delay_range.x,delay_range.y)}
 note("reported",plan.duplicate())

# A mortar that has fired its rounds from one place in the last minutes:
# heard and found by the drone.
func mortar_position() -> Vector3:
 var shots: Array=game.blasts.mine_log
 var recent: Array=[]
 for shot in shots:
  if game.blasts.clock-float(shot[0])<=MORTAR_WINDOW:recent.append(shot[1])
 if recent.size()<MORTAR_ROUNDS:return Vector3.INF
 var last: Vector3=recent[-1]
 var sum:=Vector3.ZERO;var count:=0
 for at in recent:
  if Vector3(at).distance_to(last)<=MORTAR_AREA:sum+=at;count+=1
 return sum/count if count>=MORTAR_ROUNDS else Vector3.INF

func reachable(aim: Vector3) -> bool:
 var flat:=Vector2(aim.x-fire_point.x,aim.z-fire_point.z).length()
 return flat>=TosBallistics.SPAN.x+50.0 and flat<=TosBallistics.SPAN.y-100.0

# Far enough from every defender still on his feet (and their vehicles).
func safe(aim: Vector3) -> bool:
 for actor in game.bots:
  if not is_instance_valid(actor) or actor.dead:continue
  if Vector2(actor.global_position.x-aim.x,actor.global_position.z-aim.z).length()<SAFETY:return false
 if is_instance_valid(battle.armour):
  for item in battle.armour.vehicles:
   if is_instance_valid(item) and not item.destroyed and Vector2(item.global_position.x-aim.x,item.global_position.z-aim.z).length()<SAFETY:return false
 return true

# --- The salvo -------------------------------------------------------------
func go_out() -> void:
 if vehicle.immobile:
  # Stuck in the tree line: it fires from where it is if it can.
  state="out";note("out_immobile");return
 var toward:=Vector3(plan.aim)-fire_point;toward.y=0;toward=toward.normalized()
 var mid:=ground(hide.lerp(fire_point,0.5))
 vehicle.drive_to(PackedVector3Array([mid,fire_point,ground(fire_point+toward*8.0)]))
 state="out";note("out")

func lay() -> bool:
 var from:=vehicle.global_position+Vector3.UP*2.4
 var aim: Vector3=plan.aim
 var flat:=Vector2(aim.x-from.x,aim.z-from.z)
 var elevation:=TosBallistics.elevation_to(flat.length(),from.y-aim.y)
 if elevation<0.0:return false
 var bearing:=GradBallistics.bearing(Vector3(flat.x,0,flat.y))
 if not vehicle.lay(bearing,elevation):return false
 note("laid",[bearing,elevation])
 return true

func abort(reason: String) -> void:
 note("aborted",reason)
 plan.clear()
 go_back()

func go_back() -> void:
 salvo_done=-1.0
 if salvo_started>=0.0:
  salvos+=1;salvo_started=-1.0
  if located==Vector3.INF and locate_at<0.0:locate_at=clock+rng.randf_range(LOCATE_DELAY.x,LOCATE_DELAY.y)
 plan.clear()
 vehicle.stow()
 state="back"
 if vehicle.immobile:return
 vehicle.drive_to(PackedVector3Array([ground(vehicle.global_position.lerp(hide,0.5)),hide]))
 note("back")

# The launches heard and seen: the warning on the squad radio net, the
# men by and in the vehicles near the aim point take cover.
func warn() -> void:
 var aim: Vector3=plan.aim
 var eta:=TosBallistics.time_for(Vector2(aim.x-fire_point.x,aim.z-fire_point.z).length())
 note("launch",[aim,eta])
 game.radio_voice.say("tos_launch")
 game.squad.tell("Пуск ТОС з півночі! До розривів ≈%d с · усім в укриття" % roundi(eta))
 battle.incoming_salvo(aim,eta)

# Our radio intelligence's fix of the launch: the «Grad» commander gets it
# as a target.
func report_launch() -> void:
 located=ground(fire_point+Vector3(rng.randfn(0.0,LOCATE_ERROR*0.6),0,rng.randfn(0.0,LOCATE_ERROR*0.6)))
 note("located",located)
 game.radio_voice.say("tos_located")
 var grid:=data().coordinates_text(located) if data().has_method("coordinates_text") else "%.0f, %.0f" % [located.x,located.z]
 game.squad.tell("Радіорозвідка: позиція ТОС противника — %s" % grid)
 if is_instance_valid(game.grad) and game.grad.has_method("enemy_target"):game.grad.enemy_target("ТОС",located)
 if is_instance_valid(game.tos):game.tos.enemy_target("ТОС противника",located)
