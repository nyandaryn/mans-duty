class_name BattleMode
extends Node

const SIZES := [12,20,28,50]
const CAPTURE_TIME := 30.0
# Seconds before the commander's role passes to a soldier already on the field.
const TAKEOVER_TIME := 5.0
# Defenders holding each sector from the start: the first line is the strongest.
const DEFENCE_SHARE := [0.4,0.3,0.3]
var game: Node3D
var active := false
var finished := false
var sector := 0
var progress := 0.0
var contested := false
var respawn_left := 0.0
var command_left := 0.0
var serial := 0
var corpses: Array[Hostile]=[]
var panel: Control
var result_reason := ""
var budget_frame := -1
var cover_budget := 2
var path_budget := 4
var peak_cover_queries := 0
var peak_path_queries := 0
var crowd: CrowdRenderer
# Only a mortarman controls the assault: it starts held until his order and he
# can halt it (consolidate, wait for the end of the barrage) and resume it.
var halted := false
var awaiting := false

func setup(owner_game: Node3D) -> void:
 game=owner_game

func reset() -> void:
 for actor in corpses:
  if is_instance_valid(actor):actor.queue_free()
 if is_instance_valid(crowd):
  crowd.clear_all();crowd.queue_free()
 crowd=null
 active=false;finished=false;corpses.clear();respawn_left=0
 halted=false;awaiting=false

func start() -> void:
 reset();active=true;sector=0;progress=0;contested=false;serial=0
 command_left=0;result_reason=""
 budget_frame=-1;peak_cover_queries=0;peak_path_queries=0
 crowd=CrowdRenderer.new();game.add_child(crowd);crowd.setup(game,game.battle_size+32)
 for actor in game.allies:
  actor.set_meta("battle_personal",true)
  crowd.register(actor)
 # Both armies are on the field from the first second and nobody arrives
 # later: every casualty is final. Defenders hold all three sectors in depth;
 # the attackers form up in front of the insertion, the commander behind them.
 var defenders:=defence_counts(game.battle_size)
 for index in range(3):
  for i in range(defenders[index]):deploy(false,index)
 for i in range(game.battle_size-game.allies.size()):deploy(true,0)
 if game.player_class in ["mortarman","grad"]:
  set_halt(true);awaiting=true
  game.squad.tell("Штурм очікує твоєї команди · G — %s" % ("радіо" if game.player_class=="grad" else "розрахунок"))

func set_halt(value: bool) -> void:
 halted=value
 if not value:awaiting=false
 for actor in game.allies:
  if not actor.get_meta("battle_managed",false) or not operational(actor):continue
  if value:
   var cell:Vector2i=game.district.nearest_cell(game.district.navigation_cell(actor.global_position))
   actor.set_meta("halt_point",game.district.navigation_position(cell))
  assign(actor)
  # Everyone looks for cover at once, staggered against the per-frame budget.
  if value:actor.has_cover=false;actor.cover_timer=randf()*1.5

static func defence_counts(size: int) -> Array[int]:
 var first:=ceili(size*DEFENCE_SHARE[0])
 var second:=mini(size-first,roundi(size*DEFENCE_SHARE[1]))
 return [first,second,size-first-second]

func deploy(friendly: bool, index: int) -> void:
 var point:Variant=safe_spawn(friendly,index)
 # A full formation still places the soldier: at the base, slightly offset.
 if point==null:point=formation_base(friendly,index)+BattleMap.offset(randf_range(-6,6),randf_range(-3,3)*(1 if friendly else -1))+Vector3.UP*0.05
 spawn_soldier(friendly,point,index)

func budget(kind: String) -> bool:
 if not active:return true
 var frame:=Engine.get_physics_frames()
 if frame!=budget_frame:budget_frame=frame;cover_budget=2;path_budget=4
 if kind=="cover":
  if cover_budget<=0:return false
  cover_budget-=1;peak_cover_queries=maxi(peak_cover_queries,2-cover_budget)
 else:
  if path_budget<=0:return false
  path_budget-=1;peak_path_queries=maxi(peak_path_queries,4-path_budget)
 return true

# AI level of detail, in physics ticks between two updates of one soldier.
# Nearby and magnified soldiers update every tick; distant ones less often,
# off-screen ones least. Elapsed time is accumulated, so speeds, timers and
# rates of fire are unchanged. Outside the large battle everything is full rate.
var lod_frame := -1
var lod_camera: Camera3D
var lod_origin := Vector3.ZERO
var lod_zoom := 1.0

func update_interval(actor: Hostile) -> int:
 if not active:return 1
 var frame:=Engine.get_physics_frames()
 if frame!=lod_frame:
  lod_frame=frame
  lod_camera=game.get_viewport().get_camera_3d()
  if lod_camera!=null:
   lod_origin=lod_camera.global_position
   lod_zoom=clampf(lod_camera.fov/78.0,0.2,1.0)
   if is_instance_valid(game.player) and game.player.scope_sight!=null and game.player.scope_sight.enabled:lod_zoom=0.25
 # A camera closed this tick (the mortar sight) may already be out of the tree.
 if not is_instance_valid(lod_camera) or not lod_camera.is_inside_tree():return 1
 var distance:=actor.global_position.distance_to(lod_origin)
 if distance<28:return 1
 var apparent:=distance*lod_zoom
 if lod_camera.is_position_in_frustum(actor.global_position+Vector3.UP):
  if apparent<45:return 1
  return 2 if apparent<110 else 3
 return 3 if distance<60 else 4

func center(index: int=-1) -> Vector3:
 var c: Vector2=BattleMap.CENTERS[clampi(sector if index<0 else index,0,2)]
 return Vector3(c.x,game.district.ground_height(Vector3(c.x,0,c.y)),c.y)

func operational(actor: Hostile) -> bool:
 return is_instance_valid(actor) and not actor.dead and not actor.concussion.incapacitated()

# Resupply point: the attackers' rear, or behind the sector a defender holds.
func depot(friendly: bool, index: int=-1) -> Vector3:
 # The attackers' ammunition point is where they formed up, not the
 # insertion point where the commander or the mortar crew may stand.
 if friendly:return formation_base(true,0)+BattleMap.offset(-14,6) if sector==0 else center(sector-1)+BattleMap.offset(0,24)
 return center(index)+BattleMap.offset(0,-48)

# Sector a defender holds: his own until it falls, then the next line.
func defended_sector(actor: Hostile) -> int:
 return mini(2,maxi(sector,actor.get_meta("battle_sector",0)))

func formation_base(friendly: bool, index: int) -> Vector3:
 if friendly:
  var f:Vector2=BattleMap.FORMATION
  return Vector3(f.x,game.district.ground_height(Vector3(f.x,0,f.y)),f.y)
 return center(index)+BattleMap.offset(0,-6)

# Initial position: three lanes 34 m apart, rows of five soldiers 2.2 m apart,
# each next row 3 m further from the enemy.
func safe_spawn(friendly: bool, index: int) -> Variant:
 var base:=formation_base(friendly,index)
 var depth:=1.0 if friendly else -1.0
 var enemies: Array=game.bots if friendly else game.allies+[game.player]
 var preferred:=int(serial/4) if friendly else serial
 for attempt in range(90):
  var lane:=float((preferred+attempt)%3-1)*34
  var slot:=int(attempt/3)
  var desired:=base+BattleMap.offset(lane+float(slot%5-2)*2.2,depth*float(slot/5)*3)
  var point: Vector3=game.district.navigation_position(game.district.nearest_cell(game.district.navigation_cell(desired)))
  if Vector2(point.x-desired.x,point.z-desired.z).length()>4:continue
  var safe:=true
  for enemy in enemies:
   if not is_instance_valid(enemy) or (enemy is Hostile and not operational(enemy)) or (enemy is Operator and (enemy.health<=0 or enemy.get_meta("battle_out",false))):continue
   if enemy.global_position.distance_to(point)<20:safe=false;break
  for actor in game.allies+game.bots+[game.player]:
   if actor is Operator and actor.get_meta("battle_out",false):continue
   if is_instance_valid(actor) and not (actor is Hostile and actor.dead) and actor.global_position.distance_to(point)<1.8:safe=false;break
  if safe:return point+Vector3.UP*0.05
 return null

func spawn_soldier(friendly: bool, point: Vector3, index: int=0) -> Hostile:
 var actor:=Hostile.new();actor.friendly=friendly
 actor.formation_index=game.allies.size() if friendly else serial
 actor.set_meta("battle_managed",true);actor.set_meta("battle_group",int(serial/4)%3)
 if not friendly:actor.set_meta("battle_sector",index)
 serial+=1
 game.add_child(actor);actor.setup(game,point)
 actor.rotation.y=BattleMap.facing(friendly);actor.has_cover=false
 actor.think_timer=randf_range(0.1,0.8);actor.path_timer=randf_range(0.1,1.3)
 if friendly:game.allies.append(actor)
 else:game.bots.append(actor)
 if is_instance_valid(crowd):crowd.register(actor)
 assign(actor)
 return actor

# Out of rounds: a comrade close by passes a spare magazine, or the soldier
# takes the magazines of a fallen soldier nearby. Returns the body to walk to,
# or null when resupplied on the spot or nothing is close.
func resupply(actor: Hostile) -> Variant:
 for other in (game.allies if actor.friendly else game.bots):
  if other==actor or not operational(other) or other.global_position.distance_to(actor.global_position)>12:continue
  var loaded:Array=range(other.weapon.pouches.size()).filter(func(i):return int(other.weapon.pouches[i].get("rounds",0))>0)
  if loaded.size()<2:continue
  if give_magazine(actor.weapon,other.weapon.pouches[loaded[0]]):
   other.weapon.pouches[loaded[0]]={}
   return null
 var nearest:Hostile=null
 for body in corpses+game.allies+game.bots:
  if not is_instance_valid(body) or not body.dead or body.weapon.id!=actor.weapon.id or body.weapon.ammunition_total()<=int(body.weapon.chambered):continue
  if body.global_position.distance_to(actor.global_position)>18:continue
  if nearest==null or body.global_position.distance_to(actor.global_position)<nearest.global_position.distance_to(actor.global_position):nearest=body
 if nearest==null:return null
 if nearest.global_position.distance_to(actor.global_position)>2.2:return nearest.global_position
 var spoils:Array=nearest.weapon.pouches+[nearest.weapon.magazine]
 for magazine in spoils:
  if int(magazine.get("rounds",0))>0 and give_magazine(actor.weapon,magazine.duplicate()):magazine.rounds=0
 return null

static func give_magazine(weapon: WeaponState, magazine: Dictionary) -> bool:
 for i in range(weapon.pouches.size()):
  if int(weapon.pouches[i].get("rounds",0))==0:
   weapon.pouches[i]=magazine.duplicate()
   return true
 return false

func assign(actor: Hostile) -> void:
 if not operational(actor) or not actor.get_meta("battle_managed",false):return
 var index:=sector if actor.friendly else defended_sector(actor)
 var goal:=center(index)
 var supply:Variant=resupply(actor) if actor.weapon.ammunition_total()==0 else null
 if actor.friendly and halted:
  # Consolidate where the halt found them: take cover there and hold.
  goal=actor.get_meta("halt_point",actor.global_position)
  if actor.home.distance_to(goal)>4:actor.has_cover=false;actor.path_timer=0;actor.cover_dwell=0
  actor.home=goal;actor.order_point=goal;actor.defensive=true;actor.defense_radius=12
  actor.order="assault";actor.order_direction=actor.position.direction_to(center(index));actor.order_origin=actor.position
  actor.assault_arrived=true
  return
 var group:int=actor.get_meta("battle_group",0)
 var lane:=float(group-1)*30
 # Use a flank approach until near the position, then converge on the sector.
 if absf(BattleMap.depth(goal,actor.position))>27:goal+=BattleMap.offset(lane,16 if actor.friendly else -12)
 else:goal+=BattleMap.offset((actor.formation_index%4-1.5)*4,-2 if actor.friendly else -6)
 goal=game.district.navigation_position(game.district.nearest_cell(game.district.navigation_cell(goal)))
 if supply is Vector3:goal=game.district.navigation_position(game.district.nearest_cell(game.district.navigation_cell(supply)))
 elif actor.weapon.ammunition_total()==0:
  goal=depot(actor.friendly,index)
  goal=game.district.navigation_position(game.district.nearest_cell(game.district.navigation_cell(goal)))
  if actor.position.distance_to(goal)<7:
   var time:float=actor.get_meta("resupply_time",0.0)+1
   actor.set_meta("resupply_time",time)
   if time>=6:actor.weapon=WeaponState.new("ak74");actor.set_meta("resupply_time",0.0)
  else:actor.set_meta("resupply_time",0.0)
 if actor.home.distance_to(goal)>4:
  actor.has_cover=false;actor.path_timer=0;actor.cover_dwell=0
 actor.home=goal;actor.order_point=goal;actor.defensive=true;actor.defense_radius=25
 if actor.friendly:
  actor.order="assault";actor.order_direction=actor.position.direction_to(center(index));actor.order_origin=actor.position
  actor.assault_arrived=actor.position.distance_to(goal)<2.5
 else:
  # A strategic destination is never a visual contact or an aim coordinate.
  if not actor.alerted:actor.target=goal

func update_objective(delta: float) -> void:
 var a:=0;var d:=0;var target:=center()
 for actor in game.allies+game.bots:
  if not operational(actor) or actor.collapse>0.5 or actor.treatment_time>0:continue
  if Vector2(actor.position.x-target.x,actor.position.z-target.z).length()>22 or absf(actor.position.y-target.y)>3:continue
  if actor.friendly:a+=1
  else:d+=1
 if game.player.health>0 and not game.player.get_meta("battle_out",false) and game.player.position.distance_to(target)<22:a+=1
 contested=a>0 and d>0
 if a>0 and d==0:progress=minf(1,progress+delta/CAPTURE_TIME)
 elif d>0 and a==0:progress=maxf(0,progress-delta/(CAPTURE_TIME*2))
 if progress>=1:
  var flag:=game.district.get_node_or_null("SectorFlag"+str(sector)) as MeshInstance3D
  if flag:flag.material_override=Models.surface("d4b951")
  sector+=1;progress=0;command_left=0
  if sector>=3:complete(true,"Усі три рубежі захоплено.")
  else:game.squad.tell("РУБІЖ ЗАЙНЯТО · НАСТУПНА ЦІЛЬ: "+BattleMap.TITLES[sector])

func retire_casualties() -> void:
 for friendly in [true,false]:
  var team:Array=game.allies if friendly else game.bots
  for actor in team.duplicate():
   if operational(actor):continue
   # Incapacitated casualties stay incapacitated and are never healed or
   # replaced: the battle has no reinforcements.
   if actor.get_meta("battle_personal",false):continue
   team.erase(actor);corpses.append(actor)
  while corpses.size()>20:
   var old:Hostile=corpses.pop_front()
   if is_instance_valid(old):old.queue_free()

# Command passes to the nearest fit soldier already on the field. There is
# no reserve: when no allied soldier is left standing the commander is the last.
func successor() -> Hostile:
 var from:Vector3=game.player.global_position if is_instance_valid(game.player) else game.district.player_spawn
 var best: Hostile=null;var best_distance:=INF
 var helper: Hostile=null
 for actor in game.allies:
  if not operational(actor) or actor.collapse>0.5 or actor.treatment_time>0:continue
  # The mortar assistant stays with the crew unless nobody else is left.
  if actor.get_meta("crew_role","")=="assistant":helper=actor;continue
  var distance:float=actor.global_position.distance_to(from)
  if distance<best_distance:best=actor;best_distance=distance
 return best if best!=null else helper

func living(friendly: bool) -> int:
 var count:=0
 for actor in game.allies if friendly else game.bots:
  if operational(actor):count+=1
 if friendly and is_instance_valid(game.player) and game.player.health>0 and not game.player.get_meta("battle_out",false):count+=1
 return count

func player_fell() -> bool:
 if respawn_left>0:return true
 # The BM-21 commander has no successor on the field.
 if game.player_class=="grad":
  if is_instance_valid(game.grad):game.grad.leave()
  complete(false,"Командир БМ-21 вибув.");return true
 if successor()==null:return false
 respawn_left=TAKEOVER_TIME
 game.crew.player_fell(game.player.global_position)
 game.inventory.close();game.close_panels();game.player.field_rig.cancel()
 game.player.launcher.cancel();game.player.set_physics_process(false);game.player.set_process_unhandled_input(false)
 game.player.set_meta("battle_out",true);game.player.collision_layer=0;game.player.collision_mask=0
 for area in game.player.find_children("*","Area3D",true,false):area.collision_layer=0
 game.player.viewmodel.hide();game.player.world_body.hide()
 return true

# The chosen soldier becomes the commander: his body leaves the AI army and
# the operator takes his place and heading. Nobody new enters the battlefield.
func respawn_player() -> void:
 var body:=successor()
 if body==null:
  complete(false,"Командир вибув. Живих бійців не лишилося.");return
 var point:=body.global_position+Vector3.UP*0.05;var yaw:=body.rotation.y
 game.allies.erase(body);game.squad.selected=-1;body.queue_free()
 var old:Operator=game.player
 var next:=Operator.new();game.add_child(next);game.player=next;next.position=point;next.rotation.y=yaw;next.setup(game,game.primary,game.secondary);next.sensitivity=game.sensitivity
 old.queue_free();game.damage_flash=0;game.hearing.reset();game.squad.trail=PackedVector3Array([point])

func complete(won: bool, reason: String) -> void:
 finished=true;result_reason=reason;game.finish(won)

func _physics_process(delta: float) -> void:
 if not active or finished or not game.running or game.paused:return
 # A heavily concussed commander hands over to a soldier on the field.
 # With nobody left he stays where he lies: the assault never ends while the
 # commander is alive, only by his death or by the capture of all sectors.
 if game.player.concussion.incapacitated() and respawn_left<=0 and successor()!=null and game.player_class!="grad":player_fell()
 if respawn_left>0:
  respawn_left=maxf(0,respawn_left-delta)
  if respawn_left==0:respawn_player()
  if finished:return
 command_left-=delta
 if command_left<=0:
  command_left=1
  retire_casualties()
  for actor in game.allies+game.bots:assign(actor)
 update_objective(delta)

func status() -> String:
 var target:=center();var offset:Vector3=target-game.player.position
 var bearing:=wrapf(rad_to_deg(atan2(-offset.x,-offset.z)),0,360)
 if respawn_left>0:return "КОМАНДИР ВИБУВ · КОМАНДУВАННЯ ПРИЙМЕ НАЙБЛИЖЧИЙ БОЄЦЬ ЧЕРЕЗ %d с\nУ строю: %d · бій триває" % [ceili(respawn_left),living(true)]
 if awaiting:return "ШТУРМ ОЧІКУЄ КОМАНДИ ГРАВЦЯ · G — %s\nГрупи на вихідних рубежах · СИЛИ %d : %d" % ["РАДІО" if game.player_class=="grad" else "РОЗРАХУНОК",living(true),living(false)]
 if halted:return "ШТУРМ ПРИЗУПИНЕНО · ГРУПИ ЗАКРІПЛЮЮТЬСЯ · G — ПРОДОВЖИТИ\n%s · СИЛИ %d : %d" % [BattleMap.TITLES[mini(sector,2)],living(true),living(false)]
 return "ШТУРМ · %s · %d м / %03d°\n%s %d%% · СИЛИ %d : %d" % [BattleMap.TITLES[mini(sector,2)],offset.length(),bearing,"БОЇ ЗА РУБІЖ" if contested else "ЗАКРІПЛЕННЯ",roundi(progress*100),living(true),living(false)]

func build_menu(parent: Control) -> void:
 panel=Control.new();game.place(panel,parent,0,0,1,1)
 UiKit.sheet(game,panel,0.8)
 UiKit.header(game,panel,"ГОЛОВНЕ МЕНЮ   /   ВЕЛИКИЙ ШТУРМ","ВЕЛИКИЙ ШТУРМ","АВДІЇВКА · ПРИВАТНИЙ СЕКТОР · 400 × 400 М · ТРИ РУБЕЖІ",func():game.main_menu.back())
 var map:=Control.new();map.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.place(map,panel,0.035,0.25,0.5,0.82)
 map.draw.connect(func():
  var s:=map.size;var side:=minf(s.x,s.y);var o:=Vector2((s.x-side)*0.5,0);var box:=Vector2(side,side)
  map.draw_rect(Rect2(o,box),Color(0.04,0.07,0.055,0.9))
  for k in range(1,8):
   map.draw_line(o+Vector2(side*k/8,0),o+Vector2(side*k/8,side),Color(1,1,1,0.06))
   map.draw_line(o+Vector2(0,side*k/8),o+Vector2(side,side*k/8),Color(1,1,1,0.06))
  map.draw_rect(Rect2(o,box),UiKit.LINE,false,1.0)
  var font:=UiKit.font("head")
  var prev:=o+Vector2(.5,.92)*side
  for i in range(3):
   var c:Vector2=BattleMap.CENTERS[i];var p:Vector2=o+(c+Vector2.ONE*200)/400*side
   map.draw_line(prev,p,UiKit.ACCENT,3);prev=p
  # Nine strongpoints of the defence.
  for item in BattleMap.strongpoints():
   var q:Vector2=o+(Vector2(item.point)+Vector2.ONE*200)/400*side
   map.draw_rect(Rect2(q-Vector2(5,5),Vector2(10,10)),Color(UiKit.DANGER,0.85))
  for i in range(3):
   var c:Vector2=BattleMap.CENTERS[i];var p:Vector2=o+(c+Vector2.ONE*200)/400*side
   map.draw_circle(p,20,Color(0.05,0.07,0.06));map.draw_arc(p,20,0,TAU,32,UiKit.ACCENT,2.0)
   map.draw_string(font,p+Vector2(-7,7),["А","Б","В"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,20,UiKit.INK)
  map.draw_string(font,o+Vector2(12,side-12),"■ ОПОРНІ ПУНКТИ    ○ РУБЕЖІ А · Б · В",HORIZONTAL_ALIGNMENT_LEFT,-1,13,UiKit.MUTED)
 )
 var text:=UiKit.wrapped(BattleMap.MENU_TEXT,16,UiKit.SOFT)
 game.place(text,panel,0.54,0.25,0.965,0.74)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);game.place(row,panel,0.035,0.85,0.5,0.92)
 var caption:=UiKit.text("БОТІВ НА СТОРОНУ",16,UiKit.ACCENT,"head");caption.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(caption)
 var size:=OptionButton.new();size.custom_minimum_size=Vector2(150,46)
 for n in SIZES:size.add_item(str(n)+" × "+str(n))
 size.selected=maxi(0,SIZES.find(game.battle_size));row.add_child(size)
 size.item_selected.connect(func(i:int):game.battle_size=SIZES[i];game.save_settings())
 var pick:=UiKit.cta("ОБРАТИ ШТУРМ →",func():game.selected_map=BattleMap.ID;game.save_settings();game.update_map_description();game.main_menu.show_screen("loadout"))
 game.place(pick,panel,0.54,0.83,0.965,0.9)
 panel.hide()
