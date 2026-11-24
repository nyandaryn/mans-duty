class_name TosCommand
extends Node

# The TOS-1A commander's war, for one: the player is the driver, the
# gunner-operator and the commander of a captured BM-1. The vehicle waits
# in a tree line 4.6 km south-west of the village; the battalion gives a
# firing position in the open field 4.1 km out. Drive there, stand on the
# jacks with the platform unlocked and the fire control warmed up (the
# maker's 90 s from the stop to the first rocket), lay by the 1D14 straight
# at what is seen, or by the coordinates of a target marked from the
# observation post's drone, fire, and leave before the enemy's counter-
# battery fire comes back. The order to storm is the player's, as for the
# BM-21 (GradCommand).
const START := Vector3(-2316,0,3985)
const START_YAW := 60.0
const FIRING_AREA := Vector3(-1797,0,3685)
const REACH := 2.4
const RELAY_HEIGHT := 3.0
const DRONE_LINK := 3000.0
const DRONE_PREPARE := 12.0
const REPORT_DELAY := 8.0
const COUNTER_BATTERY := Vector2(150.0,230.0)
const SEATS := ["driver","gunner","commander"]
var game: Node3D
var vehicle: TosVehicle
var seat := ""
var look := Vector2.ZERO
var zoomed := false
var hud: TosHud
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
var main_direction := 0.0
var assault_ordered := false
var seen_fired := 0
# Set by TosTraining: no enemy, no assault, no counter-battery fire.
var training := false
var last_report: Dictionary={}
var burst_log: Array[Vector3]=[]
# The point the last salvo was laid on, and the target it was meant for.
var aimed: Dictionary={}

func setup(owner_game: Node3D, ui_root: Control) -> void:
 game=owner_game
 hud=TosHud.new();hud.name="TosHud"
 game.place(hud,ui_root,0,0,1,1)
 hud.setup(game,self)

func active() -> bool:return game.player_class=="tos" and is_instance_valid(vehicle)

func reset() -> void:
 if is_instance_valid(hud):hud.close_all()
 if is_instance_valid(drone):drone.queue_free()
 if is_instance_valid(vehicle):vehicle.queue_free()
 vehicle=null;drone=null;seat="";piloting=false;drone_eta=-1;zoomed=false
 targets.clear();selected_target=-1;strongpoints.clear();destroyed=0
 impacts.clear();radio_log.clear();counter_fire.clear();clock=0;assault_ordered=false;seen_fired=0
 training=false;last_report={};burst_log.clear();aimed={}

func ground(point: Vector3) -> Vector3:
 return Vector3(point.x,data.height(point.x,point.z),point.z)

# Called once both armies are on the field.
func start() -> void:
 if game.player_class!="tos" or game.selected_map!=BattleMap.ID:return
 data=AvdiivkaData.shared()
 vehicle=TosVehicle.new()
 vehicle.friendly=true
 game.world_root.add_child(vehicle)
 vehicle.setup(game,0x7051)
 vehicle.make_drivable()
 var spot:=ground(START)
 var yaw:=deg_to_rad(START_YAW)
 place_vehicle(spot,yaw)
 # The commander starts by the driver's hatch, on the left of the bow.
 var side:=vehicle.to_global(Vector3(-3.0,0,-2.4))
 game.player.global_position=ground(side)+Vector3.UP*0.1
 face(vehicle.to_global(Vector3(0,1.0,-2.0)))
 var f:Vector2=BattleMap.FORMATION
 post=Vector3(f.x,0,f.y)+BattleMap.offset(14,26)
 post.y=game.district.ground_height(post)
 main_direction=snappedf(GradBallistics.bearing(Vector3.ZERO-FIRING_AREA),50.0)
 for item in BattleMap.strongpoints():
  var p: Vector2=item.point
  var spots: Array[Vector3]=[]
  for q: Vector2 in item.positions:spots.append(Vector3(q.x,game.district.ground_height(Vector3(q.x,0,q.y)),q.y))
  strongpoints.append({"title":item.title,"sector":item.sector,"point":Vector3(p.x,game.district.ground_height(Vector3(p.x,0,p.y)),p.y),"positions":spots,"hits":{},"garrison":[],"start":0,"hit":false,"destroyed":false})
 for bot in game.bots:
  var index:int=bot.get_meta("battle_sector",-1)
  if index>=0 and index<strongpoints.size():strongpoints[index].garrison.append(bot);bot.set_meta("strongpoint",index)
 for item in strongpoints:item.start=item.garrison.size()
 if game.training!="":
  radio("КЕРІВНИК НАВЧАННЯ","Полігон: противника немає, опорні пункти — навчальні цілі. Вогнева позиція — квадрат %s." % square_text(FIRING_AREA))
  return
 radio("КОМБАТ","Бойове завдання: вогнева позиція — поле в квадраті %s, ОН %s. Пакет повний, 24 ракети. Розвідка — дрон спостережного пункту (J на місці командира). Штурм — за твоєю командою (G)." % [square_text(FIRING_AREA),GradBallistics.mils_text(main_direction)])

func place_vehicle(spot: Vector3, yaw: float) -> void:
 var normal:=data.normal_at(spot.x,spot.z)
 var forward:=Vector3(sin(yaw),0,-cos(yaw))
 vehicle.linear_velocity=Vector3.ZERO;vehicle.angular_velocity=Vector3.ZERO
 vehicle.look_at_from_position(spot+Vector3.UP*0.12,spot+Vector3.UP*0.12+forward,normal)
 game.district.operation_area.stream(spot,40)
 game.district.operation_area.collide_trees(spot)

func face(point: Vector3) -> void:
 var d: Vector3=game.player.global_position-point
 game.player.rotation.y=atan2(d.x,d.z)

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
 var line:="%s: %s" % [who,text]
 if line.length()>110:line=line.substr(0,100).rstrip(" ,.")+"… · G — радіо"
 game.squad.tell(line)

func clock_text() -> String:
 var t:=int(clock)
 return "%02d:%02d" % [t/60,t%60]

# --- Seats ------------------------------------------------------------------
func seat_point(id: String) -> Vector3:
 match id:
  "driver":return TosArt.DRIVER_EYE+(Vector3(0,0.42,0) if vehicle.hatch_open else Vector3.ZERO)
  "gunner":return TosArt.GUNNER_EYE
  "commander":return TosArt.COMMANDER_EYE
 return Vector3.ZERO

func enter(id: String) -> void:
 var player: Operator=game.player
 player.field_rig.cancel();game.inventory.close()
 seat=id;vehicle.seat=id;look=Vector2.ZERO;zoomed=false
 player.set_physics_process(false);player.set_process(false);player.set_process_unhandled_input(false)
 player.collision_layer=0;player.collision_mask=0;player.velocity=Vector3.ZERO
 player.viewmodel.hide();player.world_body.hide()
 vehicle.seat_camera.make_current()
 update_camera()
 hud.refresh()

func next_seat() -> void:
 enter(SEATS[(SEATS.find(seat)+1)%SEATS.size()])
 vehicle.say({"driver":"Місце механіка-водія","gunner":"Місце навідника-оператора · приціл 1Д14","commander":"Місце командира · ТКН-3А, пульт, дрон СП"}[seat],2)

func leave() -> void:
 if seat=="":return
 var player: Operator=game.player
 var spot:=vehicle.to_global(Vector3(-2.6 if seat!="commander" else 2.6,0,-2.2 if seat=="driver" else -0.4))
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
 vehicle.throttle=0;vehicle.brake_pedal=0;vehicle.clutch_pedal=0;vehicle.lever_input=Vector2.ZERO
 vehicle.traverse_input=0;vehicle.priming=false
 seat="";vehicle.seat=""
 hud.close_all()
 if game.running and not game.paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

# Hatches round the vehicle where F climbs in.
func stations() -> Array:
 return [
  {"id":"driver","point":vehicle.to_global(Vector3(-1.9,1.0,-2.1)),"text":"F — ЛЮК МЕХАНІКА-ВОДІЯ"},
  {"id":"gunner","point":vehicle.to_global(Vector3(-1.9,1.0,-0.3)),"text":"F — ЛЮК НАВІДНИКА-ОПЕРАТОРА · ПРИЦІЛ 1Д14"},
  {"id":"commander","point":vehicle.to_global(Vector3(1.9,1.0,-0.3)),"text":"F — ЛЮК КОМАНДИРА · ПУЛЬТ, ДРОН СП"}]

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
 if absf(vehicle.speed())>1.5:vehicle.say("На ходу в машину не лізуть",2);return true
 if vehicle.destroyed:vehicle.say("Машина знищена",2);return true
 enter(station.id)
 return true

# --- Readiness ----------------------------------------------------------------
func checklist() -> Array:
 var v:=vehicle
 return [
  ["Машина на місці, гальма на защіпці",v.parking and v.standing()],
  ["Двигун працює (гідравліка, приводи)",v.running],
  ["Живлення СУО · обчислювач і датчик крену %d %%" % roundi(v.fcs_warm*100),v.fcs_ready()],
  ["Домкрати опущено",v.jacks>=1.0],
  ["Стопори платформи й пакета знято",not v.stops_locked and v.stop_motion<=0.0],
  ["Дані цілі в обчислювачі",not v.solution.is_empty() and not v.solution.has("error")],
  ["Пакет наведено",v.elevation>=1.0 and v.laid()],
  ["ЗБРОЯ: запобіжник знято",v.armed]]

# --- Drone of the observation post -------------------------------------------
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

# A target given from outside (radio intelligence's fix of the enemy's own
# TOS-1A): on the tablet's list under its own name.
func enemy_target(title: String, point: Vector3) -> void:
 if game.player_class!="tos" or data==null:return
 var name:="%s (Ц-%d)" % [title,targets.size()+1]
 targets.append({"name":name,"point":point,"enemy":title})
 game.squad.tell("Нова ціль на планшеті: %s · %s" % [name,data.coordinates_text(point)])

# --- Firing data ------------------------------------------------------------------
func firing_data(point: Vector3) -> Dictionary:
 var origin:Vector3=vehicle.global_position
 var flat:=Vector2(point.x-origin.x,point.z-origin.z)
 var distance:=flat.length()
 var bearing:=GradBallistics.bearing(Vector3(flat.x,0,flat.y))
 var heading:=GradBallistics.bearing(-vehicle.global_basis.z)
 var relative:=wrapf(bearing-heading,-3000.0,3000.0)*0.06
 var e:=TosBallistics.elevation_for(distance)
 return {"distance":distance,"bearing":bearing,"height":point.y-origin.y,"relative":relative,
  "in_range":distance>=TosBallistics.SPAN.x and distance<=TosBallistics.SPAN.y,"in_sector":absf(relative)<=TosVehicle.TRAVERSE-3.0,
  "elevation":e,"time":TosBallistics.time_for(distance) if e>=0.0 else 0.0,
  "heading":fposmod(heading*0.06,360.0),"heading_wanted":fposmod(bearing*0.06,360.0)}

# The aim point of a target after the observer's report on it: the last
# miss is taken off the point the salvo was laid on.
func aim_point(target: Dictionary) -> Vector3:
 var point: Vector3=target.point
 if last_report.get("name","")==target.get("name","") and last_report.has("miss_vector") and aimed.get("name","")==target.get("name",""):
  var base: Vector3=aimed.point
  var miss: Vector2=last_report.miss_vector
  if miss.length()>15.0:return ground(base-Vector3(miss.x,0,miss.y))
  return base
 return point

# The selected target from the tablet into the computer, and laid.
func load_target() -> bool:
 if selected_target<0 or selected_target>=targets.size():vehicle.say("Ціль не обрано: познач з дрона (T) і обери на планшеті",3);return false
 var t: Dictionary=targets[selected_target]
 var point:=aim_point(t)
 var result:=vehicle.compute(point,t.name)
 if result.is_empty():return false
 if result.has("error"):vehicle.say(result.error,3);return false
 aimed={"name":t.name,"point":point}
 if vehicle.lay_solution():vehicle.say("Обчислювач: %s · Д %d м · пакет %+.1f° / %.1f° · політ %.0f с" % [t.name,roundi(result.distance),result.platform,result.package,result.time],4)
 return true

# The gunner's laser reading into the computer, and laid.
func lay_by_laser() -> bool:
 var reading: Dictionary=vehicle.laser_reading
 if reading.is_empty() or float(reading.get("distance",-1.0))<0.0:vehicle.say("Спершу виміряй дальність (R)",2);return false
 var result:=vehicle.compute(reading.point,"1Д14")
 if result.is_empty():return false
 if result.has("error"):vehicle.say(result.error,3);return false
 aimed={"name":"1Д14","point":reading.point}
 vehicle.lay_solution()
 vehicle.say("Обчислювач: Д %d м · пакет %+.1f° / %.1f° · політ %.0f с" % [roundi(result.distance),result.platform,result.package,result.time],4)
 return true

func fire() -> void:
 if vehicle.fire():
  if aimed.is_empty():aimed={"name":"","point":vehicle.solution.get("point",Vector3.ZERO)}
  radio("ТОС","Пуск! %d %s." % [vehicle.series,"парами" if vehicle.pairs else "одиночними"])

# --- Strongpoints, bursts and the observer's reports -------------------------
func impact(where: Vector3) -> void:
 burst_log.append(where)
 if Vector2(where.x,where.z).length()<1500.0:
  impacts.append(where);last_impact=clock
 for item in strongpoints:
  if item.destroyed:continue
  if int(item.start)>0:
   for j in range(item.positions.size()):
    if where.distance_to(item.positions[j])<12.0:item.hits[j]=true
   continue
  var d:=where.distance_to(item.point)
  if d<9.0:item.hit=true
  elif d<30.0:item.near=int(item.get("near",0))+1

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
  radio("СП","Розривів біля цілей не спостерігаю (%d). Перевір дані." % count);return
 var origin:Vector3=vehicle.global_position
 var line:=Vector2(aim.point.x-origin.x,aim.point.z-origin.z).normalized()
 var miss:=Vector2(center.x-aim.point.x,center.z-aim.point.z)
 var along:=miss.dot(line)
 var across:=line.x*miss.y-line.y*miss.x
 var distance:=Vector2(aim.point.x-origin.x,aim.point.z-origin.z).length()
 var mils:=across/(0.001*distance)
 var range_text:="переліт %d" % roundi(along) if along>15 else ("недоліт %d" % roundi(-along) if along<-15 else "по дальності в цілі")
 var side_text:=("праворуч %s" % GradBallistics.mils_text(absf(mils))) if mils>3 else (("ліворуч %s" % GradBallistics.mils_text(absf(mils))) if mils<-3 else "по напрямку в цілі")
 last_report={"time":clock,"along":along,"mils":mils,"count":count,"name":aim.get("name",aim.get("title","")),"miss_vector":miss}
 radio("СП","Відносно %s: %d розривів, %s, %s." % [aim.get("name",aim.get("title","")),count,range_text,side_text])

# The enemy answers a salvo a few minutes later at the place it came from.
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
  radio("КОМБАТ","Штурмовим групам — вперед! По опорних пунктах, де вже свої, не бити: зона ураження 200 на 400.")
 else:
  game.battle.set_halt(true)
  radio("КОМБАТ","Групам закріпитися на досягнутих рубежах.")

func status_text() -> String:
 if training:return "НАВЧАННЯ · ТОС-1А «СОЛНЦЕПЁК» · РАКЕТ %d/24\nПОЛІГОН · ЦІЛЬ ОП-2 %s" % [vehicle.remaining(),"ЗНИЩЕНО" if strongpoints.size()>1 and strongpoints[1].destroyed else ""]
 var lines:="ТОС-1А · ОП ЗНИЩЕНО %d/%d · РАКЕТ %d/24" % [destroyed,strongpoints.size(),vehicle.remaining()]
 if game.battle.awaiting:lines+="\nШТУРМ ОЧІКУЄ КОМАНДИ · G — РАДІО"
 elif game.battle.halted:lines+="\nШТУРМ ПРИЗУПИНЕНО · G — РАДІО"
 else:lines+="\nШТУРМ ТРИВАЄ · %s · СИЛИ %d : %d" % [game.battle.objective_title(),game.battle.living(true),game.battle.living(false)]
 return lines

# --- Frame --------------------------------------------------------------------
func _process(delta: float) -> void:
 if not active() or not game.running or game.paused:return
 clock+=delta
 if drone_eta>=0:
  drone_eta-=delta
  if drone_eta<0:drone_eta=-1;spawn_drone()
 if seat!="":
  game.player.global_position=vehicle.to_global(seat_point(seat)+Vector3(0,-0.9,0))
  update_camera()
  read_controls(delta)
  # Out of a burning vehicle at once.
  if vehicle.hull.burning or vehicle.destroyed:leave()
 if vehicle.running:vehicle.starter=false
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
 match seat:
  "gunner":
   camera.global_transform=vehicle.sight_transform()
   camera.fov=TosVehicle.SIGHT_FOV
  "commander":
   var platform: Node3D=vehicle.art.platform
   var device:=platform.global_transform*Transform3D(Basis.IDENTITY,Vector3(0.62,0.70,-0.80))
   camera.global_transform=device*Transform3D(Basis(Vector3.UP,look.x)*Basis(Vector3.RIGHT,look.y),Vector3.ZERO)
   camera.fov=10.0 if zoomed else 70.0
  "driver":
   var body: Node3D=vehicle.art.root
   var eye:=seat_point("driver")
   var turn:=look
   # Closed down, the TNPO-168V shows a strip ahead.
   if not vehicle.hatch_open:turn=Vector2(clampf(look.x,-0.3,0.3),clampf(look.y,-0.12,0.12))
   camera.global_transform=body.global_transform*Transform3D(Basis(Vector3.UP,turn.x)*Basis(Vector3.RIGHT,turn.y),eye+(Vector3(0,0,-0.12) if not vehicle.hatch_open else Vector3.ZERO))
   camera.fov=75.0 if vehicle.hatch_open else 48.0

func read_controls(delta: float) -> void:
 var v:=vehicle
 var typing: bool=game.commands_open
 if seat=="driver" and not typing:
  v.throttle=move_toward(v.throttle,1.0 if Input.is_action_pressed("forward") else 0.0,delta*(1.6 if Input.is_action_pressed("forward") else 3.0))
  v.brake_pedal=move_toward(v.brake_pedal,1.0 if Input.is_action_pressed("back") else 0.0,delta*3.0)
  v.clutch_pedal=move_toward(v.clutch_pedal,1.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 0.0,delta*(4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.4))
  v.lever_input=Vector2(float(Input.is_action_pressed("left")),float(Input.is_action_pressed("right")))
  v.starter=Input.is_physical_key_pressed(KEY_X) and v.starter
  v.priming=Input.is_physical_key_pressed(KEY_P) and v.master and not v.running
 else:
  v.throttle=0;v.brake_pedal=0;v.lever_input=Vector2.ZERO;v.priming=false
  if seat!="driver":v.clutch_pedal=0
 if seat=="gunner" and not typing:
  v.fine=Input.is_physical_key_pressed(KEY_CTRL)
  v.traverse_input=float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
  var pitch:=float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN))
  if pitch!=0.0:v.sight_pitch=clampf(v.sight_pitch+pitch*(0.4 if v.fine else 2.0)*delta,-8.0,20.0)
 else:v.traverse_input=0.0

func instruments_shown() -> bool:
 return seat=="driver" and not piloting and hud.open_panel()=="" and Input.is_action_pressed("aim")

func hint_text() -> String:
 match seat:
  "driver":return "W ГАЗ  S ГАЛЬМО  A/D ВАЖЕЛІ (утримуй — до упору)  SHIFT ЗЧЕПЛЕННЯ  Q/E ПЕРЕДАЧА  I МАСА  P МЗН  X СТАРТЕР\nSPACE СТОЯНКОВЕ  [ ] РУЧНИЙ ГАЗ  H ЛЮК  ПКМ ПРИЛАДИ  C МІСЦЕ  F ВИЙТИ  M ПЛАНШЕТ  G РАДІО"
  "gunner":return "← → ПЛАТФОРМА (CTRL — ТОЧНО)  ↑ ↓ / МИША — ГОЛОВКА ПРИЦІЛУ  R ДАЛЕКОМІР  ENTER ОБЧИСЛИТИ Й НАВЕСТИ\nSPACE ПУСК  M ПЛАНШЕТ  G РАДІО  C МІСЦЕ  F ВИЙТИ"
  "commander":return "E ПУЛЬТ  SPACE ПУСК  ENTER ДАНІ З ПЛАНШЕТА → ОБЧИСЛЮВАЧ  J ДРОН СП  ПКМ ТКН-3А ×5  M ПЛАНШЕТ  G РАДІО  C МІСЦЕ  F ВИЙТИ"
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
  if key==KEY_G and panels_free():hud.toggle("radio");accept();return
  if key==KEY_M and panels_free():hud.toggle("tablet");accept();return
  if key==KEY_ESCAPE and hud.open_panel()!="":hud.close_all();accept();return
 if seat=="":
  if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_J and game.player.backpack.first("recon_drone")<0 and not is_instance_valid(game.player.field_rig.drone):
   vehicle.say("Дрон СП керується з термінала на місці командира",3);accept()
  return
 if hud.open_panel()!="" and hud.open_panel()!="console":return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and seat=="commander":
  zoomed=not zoomed;accept();return
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  var s:float=game.player.sensitivity
  if seat=="gunner":
   vehicle.sight_pitch=clampf(vehicle.sight_pitch-event.relative.y*s*(4.0 if vehicle.fine else 12.0),-8.0,20.0)
  else:
   var scale:=0.15 if zoomed else 1.0
   look.x=clampf(look.x-event.relative.x*s*scale,-PI if seat=="commander" else -2.0,PI if seat=="commander" else 2.0)
   look.y=clampf(look.y-event.relative.y*s*scale,-0.5 if seat=="commander" else -1.1,0.6 if seat=="commander" else 0.9)
  accept();return
 if event is InputEventKey:
  var key: int=event.physical_keycode
  if not event.pressed or event.echo:return
  match key:
   KEY_F:leave()
   KEY_C:next_seat()
   KEY_E:
    if seat=="commander":hud.toggle("console")
    elif seat=="driver":vehicle.shift(1)
   KEY_Q:
    if seat=="driver":vehicle.shift(-1)
   KEY_I:
    if seat=="driver":vehicle.toggle_master()
   KEY_X:
    if seat=="driver":vehicle.begin_crank()
   KEY_H:
    if seat=="driver":vehicle.toggle_hatch()
   KEY_SPACE:
    if seat=="driver":vehicle.toggle_parking()
    else:fire()
   KEY_BRACKETLEFT:
    if seat=="driver":vehicle.hand_throttle=maxf(0,vehicle.hand_throttle-0.05)
   KEY_BRACKETRIGHT:
    if seat=="driver":vehicle.hand_throttle=minf(0.6,vehicle.hand_throttle+0.05)
   KEY_R:
    if seat=="gunner":
     var reading:=vehicle.range_target()
     if not reading.is_empty():vehicle.say(laser_text(reading),3)
   KEY_ENTER,KEY_KP_ENTER:
    if seat=="gunner":lay_by_laser()
    elif seat=="commander":load_target()
   KEY_J:
    if seat=="commander":request_drone()
   _:
    return
  accept()

func laser_text(reading: Dictionary) -> String:
 var d: float=reading.get("distance",-1.0)
 if d==-1.0:return "1Д14: немає відбиття (до 10 км)"
 if d==-2.0:return "1Д14: ближче 400 м — не вимірює"
 return "1Д14: дальність %d м · ENTER — в обчислювач" % roundi(d)

func accept() -> void:get_viewport().set_input_as_handled()

func close_panels() -> void:
 if is_instance_valid(hud):hud.close_all()
