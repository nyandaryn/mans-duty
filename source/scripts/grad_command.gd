class_name GradCommand
extends Node

# The BM-21 commander's war: the vehicle waits in a tree line about five
# kilometres south-west of the battle; recon from the observation post's
# drone, a salvo from an open firing position, the move away before the
# counter-battery fire arrives, and the order to storm once most strongpoints
# are destroyed. A strongpoint spreads over three yards: it is destroyed when
# two of its firing positions are hit or two thirds of its garrison are out. The player alone does the crew's work: drives, brings the
# launcher into action around the vehicle, lays at the sight and fires from
# the cab.
const START := Vector3(-2253,0,4388)
const START_YAW := 0.0
# Firing position assigned by the battalion: an open field 5.5 km from the
# battle. Main direction (ОН) and the boussole correction are in the order.
const FIRING_AREA := Vector3(-2612,0,4856)
const REACH := 2.4
const RELAY_HEIGHT := 3.0
const DRONE_LINK := 3000.0
const DRONE_PREPARE := 12.0
const REPORT_DELAY := 8.0
const COUNTER_BATTERY := Vector2(150.0,230.0)
var game: Node3D
var vehicle: GradVehicle
var seat := ""
var look := Vector2.ZERO
var hud: GradHud
var data: AvdiivkaData
var post := Vector3.ZERO
var drone: ReconDrone
var drone_eta := -1.0
var piloting := false
var targets: Array[Dictionary]=[]
var selected_target := -1
var strongpoints: Array[Dictionary]=[]
var destroyed := 0
var impacts: Array[Vector3]=[]
var last_impact := -100.0
var clock := 0.0
var radio_log: Array[String]=[]
var counter_fire: Array[Dictionary]=[]
var smoke_clock := 0.0
var lever_key := false
var main_direction := 0.0
var assault_ordered := false
var seen_fired := 0
# Set by GradTraining: no enemy, no assault, no counter-battery fire.
var training := false
var last_report: Dictionary={}
var burst_log: Array[Vector3]=[]

func setup(owner_game: Node3D, ui_root: Control) -> void:
 game=owner_game
 hud=GradHud.new();hud.name="GradHud"
 game.place(hud,ui_root,0,0,1,1)
 hud.setup(game,self)

func active() -> bool:return game.player_class=="grad" and is_instance_valid(vehicle)

func reset() -> void:
 if is_instance_valid(hud):hud.close_all()
 if is_instance_valid(drone):drone.queue_free()
 if is_instance_valid(vehicle):vehicle.queue_free()
 vehicle=null;drone=null;seat="";piloting=false;drone_eta=-1
 targets.clear();selected_target=-1;strongpoints.clear();destroyed=0
 impacts.clear();radio_log.clear();counter_fire.clear();clock=0;assault_ordered=false;seen_fired=0
 training=false;last_report={};burst_log.clear()

func ground(point: Vector3) -> Vector3:
 return Vector3(point.x,data.height(point.x,point.z),point.z)

# Called once both armies are on the field.
func start() -> void:
 if game.player_class!="grad" or game.selected_map!=BattleMap.ID:return
 data=AvdiivkaData.shared()
 vehicle=GradVehicle.new()
 game.world_root.add_child(vehicle)
 vehicle.setup(game)
 var spot:=ground(START)
 var normal:=data.normal_at(spot.x,spot.z)
 var forward:=Vector3(sin(START_YAW),0,-cos(START_YAW))
 vehicle.look_at_from_position(spot+Vector3.UP*0.25,spot+Vector3.UP*0.25+forward,normal)
 game.district.operation_area.stream(spot,40)
 game.district.operation_area.collide_trees(spot)
 # The commander starts beside the driver's door.
 var door:=vehicle.to_global(Vector3(-2.2,0,-1.4))
 game.player.global_position=ground(door)+Vector3.UP*0.1
 face(vehicle.to_global(Vector3(-1.45,1.0,-1.35)))
 var f:Vector2=BattleMap.FORMATION
 post=Vector3(f.x,0,f.y)+BattleMap.offset(14,26)
 post.y=game.district.ground_height(post)
 var battle_center:=Vector3(0,0,0)
 main_direction=snappedf(GradBallistics.bearing(battle_center-FIRING_AREA),50.0)
 for item in BattleMap.strongpoints():
  var p: Vector2=item.point
  var spots: Array[Vector3]=[]
  for q: Vector2 in item.positions:spots.append(Vector3(q.x,game.district.ground_height(Vector3(q.x,0,q.y)),q.y))
  strongpoints.append({"title":item.title,"sector":item.sector,"point":Vector3(p.x,game.district.ground_height(Vector3(p.x,0,p.y)),p.y),"positions":spots,"hits":{},"garrison":[],"start":0,"hit":false,"destroyed":false})
 # The pairs on the posts between the strongpoints belong to none of them.
 for bot in game.bots:
  var index:int=bot.get_meta("battle_sector",-1)
  if index>=0 and index<strongpoints.size():strongpoints[index].garrison.append(bot);bot.set_meta("strongpoint",index)
 for item in strongpoints:item.start=item.garrison.size()
 if game.training!="":
  radio("КЕРІВНИК НАВЧАННЯ","Полігон: противника немає, опорні пункти — навчальні цілі. Вогнева позиція — квадрат %s. ПБ %s." % [square_text(FIRING_AREA),GradBallistics.mils_text(GradVehicle.BOUSSOLE_CORRECTION)])
  return
 radio("КОМБАТ","Бойове завдання: вогнева позиція — поле в квадраті %s, ОН %s. ПБ %s. Ракети 9М22У з великими гальмівними кільцями. Розвідка — дрон спостережного пункту (J у кабіні). Штурм — за твоєю командою (G)." % [square_text(FIRING_AREA),GradBallistics.mils_text(main_direction),GradBallistics.mils_text(GradVehicle.BOUSSOLE_CORRECTION)])

# Turns the player on foot towards a point (a door, a station).
func face(point: Vector3) -> void:
 var d: Vector3=game.player.global_position-point
 game.player.rotation.y=atan2(d.x,d.z)

# The tablet and the radio stay at hand during the work at the vehicle; other
# field rig actions (rangefinder in the hands, drone goggles) keep the keys.
func panels_free() -> bool:
 var rig: FieldRig=game.player.field_rig
 return not rig.active() or rig.mode=="work"

func square_text(point: Vector3) -> String:
 var x:=int(data.grid_x(point.z)/1000.0)%100
 var y:=int(data.grid_y(point.x)/1000.0)%100
 return "%02d%02d" % [x,y]

func radio(who: String, text: String) -> void:
 radio_log.push_front("%s · %s: %s" % [clock_text(),who,text])
 radio_log.resize(mini(radio_log.size(),14))
 # The full message stays in the radio log; the screen line is kept short.
 var line:="%s: %s" % [who,text]
 if line.length()>110:line=line.substr(0,100).rstrip(" ,.")+"… · G — радіо"
 game.squad.tell(line)

func clock_text() -> String:
 var t:=int(clock)
 return "%02d:%02d" % [t/60,t%60]

# --- Seats and the work around the vehicle -------------------------------
func seat_point(id: String) -> Vector3:
 match id:
  "driver":return GradArt.DRIVER_EYE
  "commander":return GradArt.COMMANDER_EYE
 return Vector3.ZERO

func enter(id: String) -> void:
 var player: Operator=game.player
 player.field_rig.cancel();game.inventory.close()
 seat=id;vehicle.seat=id;look=Vector2.ZERO
 player.set_physics_process(false);player.set_process(false);player.set_process_unhandled_input(false)
 player.collision_layer=0;player.collision_mask=0;player.velocity=Vector3.ZERO
 player.viewmodel.hide();player.world_body.hide()
 vehicle.seat_camera.make_current()
 vehicle.seat_camera.fov=75 if id!="gunner" else 10.0
 hud.refresh()

func leave() -> void:
 if seat=="":return
 var player: Operator=game.player
 var side:=-1.0 if seat in ["driver","gunner"] else 1.0
 var spot:=vehicle.to_global(Vector3(side*2.0,0,-1.4 if seat!="gunner" else 1.8))
 if seat=="gunner":spot=vehicle.art.turret.to_global(Vector3(-1.9,0,0.6))
 spot=ground(spot)
 var space:=vehicle.get_world_3d().direct_space_state
 var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(spot+Vector3.UP*4,spot+Vector3.DOWN*4,1,[vehicle.get_rid()]))
 if not hit.is_empty():spot=hit.position
 player.global_position=spot+Vector3.UP*0.05
 player.rotation.y=atan2(-(spot-vehicle.global_position).x,-(spot-vehicle.global_position).z)+PI
 player.pitch=0
 player.set_physics_process(true);player.set_process(true);player.set_process_unhandled_input(true)
 player.collision_layer=2;player.collision_mask=1|4|64
 player.viewmodel.show();player.world_body.show()
 player.camera.make_current()
 vehicle.throttle=0;vehicle.brake_pedal=0;vehicle.clutch_pedal=0;vehicle.steer_input=0
 vehicle.traverse_input=0;vehicle.elevation_input=0;vehicle.set_lever(false)
 seat="";vehicle.seat=""
 hud.close_all()
 if game.running and not game.paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

# Spots around the vehicle where F does something.
func stations() -> Array:
 var list: Array=[]
 list.append({"id":"driver","point":vehicle.to_global(Vector3(-1.45,1.0,-1.35)),"text":"F — КАБІНА: МІСЦЕ ВОДІЯ"})
 list.append({"id":"commander","point":vehicle.to_global(Vector3(1.45,1.0,-1.35)),"text":"F — КАБІНА: МІСЦЕ КОМАНДИРА · ПУЛЬТ"})
 var gunner:Vector3=vehicle.art.turret.to_global(Vector3(-1.45,-0.35,0.6))
 list.append({"id":"gunner","point":gunner,"text":"F — ДО ПРИЦІЛУ" if vehicle.bracket_up else "F — ВСТАНОВИТИ КРОНШТЕЙН ПРИЦІЛУ (8 с)"})
 list.append({"id":"valve","point":vehicle.to_global(Vector3(-1.45,1.0,0.55)),"text":"F — КРАН «БОЙОВЕ / ПОХІД» → %s" % ("ПОХІД" if vehicle.springs_locked else "БОЙОВЕ")})
 list.append({"id":"lock","point":vehicle.to_global(Vector3(-1.4,1.0,0.0)),"text":"F — %s ПАКЕТ (6 с)" % ("РОЗСТОПОРИТИ" if vehicle.travel_lock else "ЗАСТОПОРИТИ ПО-ПОХІДНОМУ")})
 list.append({"id":"cover","point":vehicle.to_global(Vector3(0,1.0,3.75)),"text":"F — %s" % ("ЗНЯТИ ЧОХОЛ З ПАКЕТА (20 с)" if vehicle.cover_on else "НАДІТИ ЧОХОЛ (35 с)")})
 return list

func nearest_station() -> Dictionary:
 if not active() or seat!="":return {}
 var from:Vector3=game.player.global_position+Vector3.UP
 var best:={};var best_distance:=REACH
 for item in stations():
  var d:=from.distance_to(item.point)
  if d<best_distance:best=item;best_distance=d
 return best

func interact() -> bool:
 var station:=nearest_station()
 if station.is_empty():return false
 var rig: FieldRig=game.player.field_rig
 match station.id:
  "driver","commander":
   if absf(vehicle.speed())>1.5:vehicle.say("На ходу в кабіну не сідають",2);return true
   enter(station.id)
  "gunner":
   if not vehicle.bracket_up:
    return rig.work("КРОНШТЕЙН ПРИЦІЛУ",8.0,func():vehicle.set_bracket(true);vehicle.say("Кронштейн у бойовому положенні, приціл і панорама встановлені",3))
   enter("gunner")
  "valve":
   return rig.work("КРАН «БОЙОВЕ / ПОХІД»",3.0,func():vehicle.toggle_springs())
  "lock":
   return rig.work("ПОХІДНЕ КРІПЛЕННЯ ПАКЕТА",6.0,func():vehicle.toggle_lock())
  "cover":
   if vehicle.cover_on:return rig.work("ЧОХОЛ ПАКЕТА",20.0,func():vehicle.set_cover(false);vehicle.say("Чохол знято й укладено",3))
   if not vehicle.travel_lock:vehicle.say("Чохол надівають на застопорений пакет",3);return true
   return rig.work("ЧОХОЛ ПАКЕТА",35.0,func():vehicle.set_cover(true);vehicle.say("Пакет зачохлено",3))
 return true

# --- Readiness ------------------------------------------------------------
func checklist() -> Array:
 return [
  ["Стоянкове гальмо затягнуто",vehicle.handbrake],
  ["Тиск у шинах %.1f (не нижче 3,0)" % vehicle.tyre,vehicle.tyre>=3.0],
  ["Двигун працює, КВП увімкнено (привід наведення)",vehicle.running and vehicle.power_takeoff],
  ["Кран «БОЙОВЕ» — ресори вимкнено",vehicle.springs_locked],
  ["Чохол з пакета знято",not vehicle.cover_on],
  ["Пакет розстопорено",not vehicle.travel_lock],
  ["Кронштейн прицілу в бойовому положенні",vehicle.bracket_up],
  ["Броньовані щитки опущено",vehicle.shields_down],
  ["Пульт: ВБ-55, контроль живлення, режим, програму зведено",vehicle.battery_on and vehicle.fire_mode>0 and vehicle.program_wound]]

# --- Drone of the observation post -----------------------------------------
func request_drone() -> void:
 if is_instance_valid(drone) and drone.health>0 and drone.battery>0.04:
  begin_piloting();return
 if drone_eta>=0:vehicle.say("СП готує дрон до зльоту: %d с" % ceili(drone_eta),2);return
 drone_eta=DRONE_PREPARE
 radio("СП","Прийняв. Дрон у повітрі через %d секунд, канал через ретранслятор." % int(DRONE_PREPARE))

func spawn_drone() -> void:
 if is_instance_valid(drone):drone.queue_free()
 drone=ReconDrone.new()
 game.world_root.add_child(drone)
 drone.setup(game.player,{"battery":1.0,"condition":1.0})
 drone.relay=post+Vector3.UP*RELAY_HEIGHT
 drone.link_range=DRONE_LINK
 drone.limit=OperationArea.INNER*29.0
 drone.ceiling=350.0
 drone.zoomable=true
 drone.camera.fov=84.0
 drone.return_camera=vehicle.seat_camera
 drone.on_lost=end_piloting
 drone.global_position=post+Vector3.UP*30.0+BattleMap.offset(0,6)
 drone.yaw=BattleMap.facing(true)
 drone.armed=true;drone.landed=false
 radio("СП","Дрон у повітрі над СП, висота 30. Передаю керування.")

func begin_piloting() -> void:
 if seat!="commander" or not is_instance_valid(drone):return
 if drone.begin_control():
  piloting=true;game.commands_open=false;hud.close_all()
  Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func end_piloting() -> void:
 if not piloting:return
 piloting=false
 if is_instance_valid(drone) and drone.piloting:drone.end_control()
 if seat!="":vehicle.seat_camera.make_current()

# Laser rangefinder of the drone camera (Mavic 3T class, up to 1200 m).
func rangefinder() -> Dictionary:
 if not is_instance_valid(drone):return {}
 var from:=drone.camera.global_position
 var to:=from-drone.camera.global_basis.z*1200.0
 var hit:=drone.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1,[drone.get_rid()]))
 if hit.is_empty():return {}
 var p:Vector3=hit.position
 return {"point":p,"distance":from.distance_to(p)}

func mark_target() -> void:
 var reading:=rangefinder()
 if reading.is_empty():drone.notice="ДАЛЕКОМІР: НЕМАЄ ВІДБИТТЯ";return
 var point:Vector3=reading.point
 var name:="Ц-%d" % (targets.size()+1)
 targets.append({"name":name,"point":point})
 selected_target=targets.size()-1
 drone.notice="%s: %s · h %.0f м" % [name,data.coordinates_text(point),data.altitude(point.y)]
 game.sound("click",-10)

# --- Firing data the tablet shows (GPS position of the launcher) ----------
func firing_data(point: Vector3) -> Dictionary:
 var origin:Vector3=vehicle.global_position
 var flat:=Vector2(point.x-origin.x,point.z-origin.z)
 var distance:=flat.length()
 var bearing:=GradBallistics.bearing(Vector3(flat.x,0,flat.y))
 var height:=point.y-origin.y
 var site:=height/(0.001*maxf(distance,1.0))
 var heading:=GradBallistics.bearing(-vehicle.global_basis.z)
 var relative:=wrapf(bearing-heading,-3000.0,3000.0)*0.06
 return {"distance":distance,"bearing":bearing,"height":height,"site":site,"relative":relative}

# Every setting the tablet computes for a target: deflection, sight, level,
# time of flight, the vehicle heading that puts the target in a sector, and
# the corrections from the observer's last report on it.
const LEFT_SECTOR := Vector2(-95.0,-45.0)
const RIGHT_SECTOR := Vector2(45.0,65.0)

func solution(target: Dictionary) -> Dictionary:
 var d:=firing_data(target.point)
 var span:Vector2=GradBallistics.RING_SPAN[0]
 var s:=d.duplicate()
 s.in_range=d.distance>=span.x and d.distance<=span.y
 s.deflection=fposmod(float(d.bearing)-GradVehicle.BOUSSOLE_CORRECTION+3000.0,6000.0)
 var e:=GradBallistics.elevation_for(0,d.distance)
 s.sight=snappedf(e,0.5) if e>=0.0 else -1.0
 s.level=3000.0+roundf(d.site)
 s.time=GradBallistics.time_for(0,d.distance) if s.in_range else 0.0
 s.per_mil=maxf(1.0,absf(GradBallistics.range_for(0,e+1.0)-GradBallistics.range_for(0,e))) if e>=0.0 else 1.0
 s.in_sector=(d.relative>=LEFT_SECTOR.x and d.relative<=LEFT_SECTOR.y) or (d.relative>=RIGHT_SECTOR.x and d.relative<=RIGHT_SECTOR.y)
 # Compass heading of the vehicle axis with the target at −75° (left) or +55°.
 s.heading_left=fposmod(float(d.bearing)*0.06+75.0,360.0)
 s.heading_right=fposmod(float(d.bearing)*0.06-55.0,360.0)
 s.heading=fposmod(GradBallistics.bearing(-vehicle.global_basis.z)*0.06,360.0)
 s.cab_zone=absf(d.relative)<GradVehicle.CAB_ZONE and s.sight<183.0
 if last_report.get("name","")==target.get("name","") and last_report.has("along") and last_report.has("settings"):
  var base: Dictionary=last_report.settings
  var along: float=last_report.along if absf(last_report.along)>15.0 else 0.0
  var side: float=last_report.mils if absf(last_report.mils)>3.0 else 0.0
  s.correction={"along":last_report.along,"mils":last_report.mils,"sight":snappedf(float(base.get("sight",s.sight))-along/s.per_mil,0.5),"deflection":fposmod(roundf(float(base.get("deflection",s.deflection))-side),6000.0),"needed":along!=0.0 or side!=0.0}
 return s

# --- Strongpoints, bursts and the observer's reports -----------------------
func impact(where: Vector3) -> void:
 burst_log.append(where)
 if Vector2(where.x,where.z).length()<1500.0:
  impacts.append(where);last_impact=clock
 for item in strongpoints:
  if item.destroyed:continue
  if int(item.start)>0:
   for j in range(item.positions.size()):
    if where.distance_to(item.positions[j])<10.0:item.hits[j]=true
   continue
  # An empty training strongpoint falls to a hit or three bursts within 25 m.
  var d:=where.distance_to(item.point)
  if d<7.0:item.hit=true
  elif d<25.0:item.near=int(item.get("near",0))+1

func update_strongpoints() -> void:
 for item in strongpoints:
  if item.destroyed:continue
  var living:=0
  for actor in item.garrison:
   if game.battle.operational(actor):living+=1
  if item.hit or int(item.get("near",0))>=3 or item.hits.size()>=2 or (item.start>0 and living<=int(item.start)/3):
   item.destroyed=true;destroyed+=1
   radio("СП","%s знищено. Знищено %d з %d опорних пунктів." % [item.title,destroyed,strongpoints.size()])

func report_bursts() -> void:
 if impacts.is_empty() or clock-last_impact<REPORT_DELAY:return
 var center:=Vector3.ZERO
 for p in impacts:center+=p
 center/=impacts.size()
 var aim: Dictionary={}
 var best:=INF
 # The observer reports against the target the mission was fired at; only
 # bursts far from it are referred to the nearest other target.
 if selected_target>=0 and selected_target<targets.size():
  var chosen: Dictionary=targets[selected_target]
  var miss:=Vector2(chosen.point.x-center.x,chosen.point.z-center.z).length()
  if miss<600.0:aim=chosen;best=miss
 if aim.is_empty():
  for item in targets+strongpoints:
   var d:=Vector2(item.point.x-center.x,item.point.z-center.z).length()
   if d<best:best=d;aim=item
 var count:=impacts.size()
 impacts.clear()
 if aim.is_empty() or best>900.0:
  last_report={"time":clock,"miss":true,"count":count}
  radio("СП","Розривів біля цілей не спостерігаю (%d). Перевір установки." % count);return
 var origin:Vector3=vehicle.global_position
 var line:=Vector2(aim.point.x-origin.x,aim.point.z-origin.z).normalized()
 var miss:=Vector2(center.x-aim.point.x,center.z-aim.point.z)
 var along:=miss.dot(line)
 var across:=line.x*miss.y-line.y*miss.x
 var distance:=Vector2(aim.point.x-origin.x,aim.point.z-origin.z).length()
 # Positive across the line of fire is to the right as seen from the launcher.
 var mils:=across/(0.001*distance)
 var range_text:="переліт %d" % roundi(along) if along>15 else ("недоліт %d" % roundi(-along) if along<-15 else "по дальності в цілі")
 var side_text:=("праворуч %s" % GradBallistics.mils_text(absf(mils))) if mils>3 else (("ліворуч %s" % GradBallistics.mils_text(absf(mils))) if mils<-3 else "по напрямку в цілі")
 last_report={"time":clock,"along":along,"mils":mils,"count":count,"name":aim.get("name",aim.get("title","")),"settings":vehicle.last_launch.duplicate()}
 radio("СП","Відносно %s: %d розривів, %s, %s." % [aim.get("name",aim.get("title","")),count,range_text,side_text])

# Enemy counter-battery fire answers a salvo a few minutes later at the
# position it was fired from.
func plan_counter_fire() -> void:
 var spot:=vehicle.global_position
 for item in counter_fire:
  if Vector3(item.point).distance_to(spot)<150.0:return
 counter_fire.append({"point":spot,"time":clock+randf_range(COUNTER_BATTERY.x,COUNTER_BATTERY.y),"shells":14,"next":0.0})

func update_counter_fire(delta: float) -> void:
 for item in counter_fire.duplicate():
  if clock<float(item.time):continue
  item.next=float(item.next)-delta
  if float(item.next)>0:continue
  item.next=randf_range(1.5,4.0)
  var p:Vector3=item.point+Vector3(randfn(0,45),0,randfn(0,45))
  p=ground(p)
  game.blasts.detonate(p+Vector3.UP*0.2,"grad")
  if int(item.shells)==14:radio("СП","Над вашою вогневою — розриви! Противник веде контрбатарейну боротьбу.")
  item.shells=int(item.shells)-1
  if int(item.shells)<=0:counter_fire.erase(item)

func order_assault(go: bool) -> void:
 if training:radio("КЕРІВНИК НАВЧАННЯ","На полігоні штурмових груп немає. У бою ця кнопка рушить штурм.");return
 if go:
  if destroyed<ceili(strongpoints.size()*0.5):radio("КОМБАТ","Прийняв. Знищено лише %d з %d ОП — штурм буде важким." % [destroyed,strongpoints.size()])
  game.battle.set_halt(false);assault_ordered=true
  radio("КОМБАТ","Штурмовим групам — вперед! Вогонь по опорних пунктах лише за моєю командою, по своїх не бити.")
 else:
  game.battle.set_halt(true)
  radio("КОМБАТ","Групам закріпитися на досягнутих рубежах.")

func status_text() -> String:
 if training:return "НАВЧАННЯ · БМ-21 «ГРАД» · РАКЕТ %d/40\nПОЛІГОН · ЦІЛЬ ОП-2 %s" % [vehicle.remaining(),"ЗНИЩЕНО" if strongpoints.size()>1 and strongpoints[1].destroyed else ""]
 var lines:="БМ-21 «ГРАД» · ОП ЗНИЩЕНО %d/%d · РАКЕТ %d/40" % [destroyed,strongpoints.size(),vehicle.remaining()]
 if game.battle.awaiting:lines+="\nШТУРМ ОЧІКУЄ КОМАНДИ · G — РАДІО"
 elif game.battle.halted:lines+="\nШТУРМ ПРИЗУПИНЕНО · G — РАДІО"
 else:lines+="\nШТУРМ ТРИВАЄ · %s · СИЛИ %d : %d" % [game.battle.objective_title(),game.battle.living(true),game.battle.living(false)]
 return lines

# --- Frame ------------------------------------------------------------------
func _process(delta: float) -> void:
 if not active() or not game.running or game.paused:return
 clock+=delta
 if drone_eta>=0:
  drone_eta-=delta
  if drone_eta<0:drone_eta=-1;spawn_drone()
 if seat!="":
  var player: Operator=game.player
  player.global_position=vehicle.to_global(Vector3(-0.5 if seat=="driver" else 0.5,1.3,-1.1)) if seat!="gunner" else vehicle.art.turret.to_global(Vector3(-1.45,-0.35,0.6))
  update_camera()
  read_controls(delta)
 update_counter_fire(delta)
 smoke_clock-=delta
 if smoke_clock<=0:
  smoke_clock=1.0
  update_strongpoints()
  report_bursts()
  var effects:=GradEffects.shared(game)
  for item in strongpoints:
   if item.destroyed:effects.puff(Vector3(item.point)+Vector3(randf_range(-2,2),1.5,randf_range(-2,2)),1.6,0.35,Vector3(0.4,0.6,0))
 if vehicle.fired!=seen_fired:
  seen_fired=vehicle.fired
  if not training:plan_counter_fire()
 game.objective.text=status_text()
 game.soldier_controls.text=hint_text()
 game.hud_text.visible=seat=="" and not game.player.field_rig.active()
 game.objective.visible=not piloting

func update_camera() -> void:
 var camera:=vehicle.seat_camera
 if seat=="gunner":
  camera.global_transform=vehicle.panorama_transform()
  camera.fov=10.0
  return
 var eye:=seat_point(seat)
 var body: Node3D=vehicle.art.root
 camera.global_transform=body.global_transform*Transform3D(Basis(Vector3.UP,look.x)*Basis(Vector3.RIGHT,look.y),eye)
 camera.fov=75.0

func read_controls(delta: float) -> void:
 var typing: bool=game.commands_open
 if seat=="driver" and not typing:
  vehicle.throttle=move_toward(vehicle.throttle,1.0 if Input.is_action_pressed("forward") else 0.0,delta*(1.6 if Input.is_action_pressed("forward") else 3.0))
  vehicle.brake_pedal=move_toward(vehicle.brake_pedal,1.0 if Input.is_action_pressed("back") else 0.0,delta*3.0)
  vehicle.clutch_pedal=move_toward(vehicle.clutch_pedal,1.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 0.0,delta*(4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.4))
  vehicle.steer_input=float(Input.is_action_pressed("right"))-float(Input.is_action_pressed("left"))
  vehicle.starter=Input.is_physical_key_pressed(KEY_X)
 else:
  vehicle.throttle=0;vehicle.brake_pedal=0;vehicle.steer_input=0;vehicle.starter=false
  if seat!="driver":vehicle.clutch_pedal=0
 if seat=="gunner" and not typing:
  vehicle.manual_drive=Input.is_physical_key_pressed(KEY_CTRL)
  vehicle.traverse_input=float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
  vehicle.elevation_input=float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN))
 else:
  vehicle.traverse_input=0;vehicle.elevation_input=0
 if seat=="commander":
  var held:=lever_key or hud.lever_button_down()
  vehicle.set_lever(held)
 else:vehicle.set_lever(false)

# The instruments are on the dashboard; the right mouse button held in the
# driver's seat shows their readings large on the screen.
func instruments_shown() -> bool:
 return seat=="driver" and not piloting and hud.open_panel()=="" and Input.is_action_pressed("aim")

func hint_text() -> String:
 match seat:
  "driver":return "W ГАЗ  S ГАЛЬМО  A/D КЕРМО  SHIFT ЗЧЕПЛЕННЯ  Q/E ПЕРЕДАЧА  I ЗАПАЛЮВАННЯ  X СТАРТЕР  SPACE СТОЯНКОВЕ  L РОЗДАТКА\nP КВП  [ ] РУЧНИЙ ГАЗ  T ПІДКАЧКА ШИН  V ЩИТКИ  ПКМ ПРИЛАДИ  R ПРИЙМАЧ  C МІСЦЕ КОМАНДИРА  F ВИЙТИ  M ПЛАНШЕТ  G РАДІО"
  "commander":return "E ПУЛЬТ  SPACE ПУСК (утримувати)  J ДРОН СП  M ПЛАНШЕТ  G РАДІО  V ЩИТКИ  R ПРИЙМАЧ  C МІСЦЕ ВОДІЯ  F ВИЙТИ"
  "gunner":return "← → ПОВОРОТ ПАКЕТА  ↑ ↓ ПІДНЕСЕННЯ  CTRL РУЧНИЙ ПРИВІД  Q/E КУТОМІР  W/S ПРИЦІЛ  A/D РІВЕНЬ  (SHIFT ×10, ALT ×100)  B БУСОЛЬ  МИША — ГОЛОВКА  F ВИЙТИ"
 var station:=nearest_station()
 return station.text if not station.is_empty() else game.control_hint()

func _input(event: InputEvent) -> void:
 if not active() or not game.running or game.paused:return
 if not (event is InputEventKey or event is InputEventMouseMotion or event is InputEventMouseButton):return
 if piloting:
  if event is InputEventKey and event.pressed and not event.echo:
   if event.physical_keycode==KEY_J or event.physical_keycode==KEY_ESCAPE:end_piloting();accept();return
   if event.physical_keycode==KEY_T:mark_target();accept();return
  if is_instance_valid(drone):drone.handle_input(event)
  accept();return
 if event is InputEventKey and event.pressed and not event.echo:
  var key: int=event.physical_keycode
  if key==KEY_G and panels_free():
   hud.toggle("radio");accept();return
  if key==KEY_M and panels_free():
   hud.toggle("tablet");accept();return
  if key==KEY_ESCAPE and hud.open_panel()!="":
   hud.close_all();accept();return
 if seat=="":
  if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_J:
   vehicle.say("Дрон СП керується з термінала в кабіні командира",3);accept()
  return
 if hud.open_panel()!="" and hud.open_panel()!="console":
  return
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  var s:float=game.player.sensitivity
  if seat=="gunner":
   vehicle.head_pitch=clampf(vehicle.head_pitch-event.relative.y*s*8.0,-5.0,18.0)
  else:
   look.x=clampf(look.x-event.relative.x*s,-2.0,2.0)
   look.y=clampf(look.y-event.relative.y*s,-1.1,0.9)
  accept();return
 if event is InputEventKey:
  var key: int=event.physical_keycode
  if seat=="commander" and key==KEY_SPACE:
   lever_key=event.pressed;accept();return
  if not event.pressed or event.echo:return
  var step:=100.0 if event.alt_pressed else (10.0 if event.shift_pressed else 1.0)
  match key:
   KEY_F:leave()
   KEY_C:
    if seat=="driver":enter("commander")
    elif seat=="commander":enter("driver")
   KEY_V:
    if seat!="gunner":vehicle.toggle_shields()
   KEY_E:
    if seat=="commander":hud.toggle("console")
    elif seat=="driver":vehicle.shift(1)
    elif seat=="gunner":vehicle.deflection=fposmod(vehicle.deflection+step,6000.0);game.sound("click",-22)
   KEY_Q:
    if seat=="driver":vehicle.shift(-1)
    elif seat=="gunner":vehicle.deflection=fposmod(vehicle.deflection-step,6000.0);game.sound("click",-22)
   KEY_J:
    if seat=="commander":request_drone()
   KEY_I:
    if seat=="driver":vehicle.toggle_ignition()
   KEY_R:
    if seat=="driver" or seat=="commander":vehicle.toggle_radio()
   KEY_X:
    if seat=="driver":vehicle.begin_crank()
   KEY_SPACE:
    if seat=="driver":vehicle.toggle_handbrake()
   KEY_L:
    if seat=="driver":vehicle.toggle_range()
   KEY_P:
    if seat=="driver":vehicle.toggle_power_takeoff()
   KEY_T:
    if seat=="driver":vehicle.cycle_inflation()
   KEY_BRACKETLEFT:
    if seat=="driver":vehicle.hand_throttle=maxf(0,vehicle.hand_throttle-0.05)
   KEY_BRACKETRIGHT:
    if seat=="driver":vehicle.hand_throttle=minf(0.6,vehicle.hand_throttle+0.05)
   KEY_W:
    if seat=="gunner":vehicle.sight_setting=clampf(vehicle.sight_setting+(0.5 if step==1.0 else step),0.0,1200.0);game.sound("click",-22)
   KEY_S:
    if seat=="gunner":vehicle.sight_setting=clampf(vehicle.sight_setting-(0.5 if step==1.0 else step),0.0,1200.0);game.sound("click",-22)
   KEY_D:
    if seat=="gunner":vehicle.level_setting=clampf(vehicle.level_setting+step,2700.0,3300.0);game.sound("click",-22)
   KEY_A:
    if seat=="gunner":vehicle.level_setting=clampf(vehicle.level_setting-step,2700.0,3300.0);game.sound("click",-22)
   KEY_B:
    if seat=="gunner":vehicle.boussole=not vehicle.boussole;game.sound("click",-16)
   _:
    # Pause, inventory, fullscreen and the rest stay with the game.
    return
  accept()

func accept() -> void:get_viewport().set_input_as_handled()

func close_panels() -> void:
 if is_instance_valid(hud):hud.close_all()
