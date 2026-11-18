class_name BattleMap
extends RefCounted

# «Великий штурм» on real ground: the southern private sector of Avdiivka,
# 400 × 400 m between the forest strip and Soborna street, built from
# OpenStreetMap houses and roads and SRTM relief (AvdiivkaData). The streets
# run east-south-east; the attackers come out of the forest strip in the
# south-west and cross three streets to the north-north-east.
const ID := "battle_front"
const CENTERS := [Vector2(-26,55),Vector2(22,-43),Vector2(69,-137)]
const TITLES := ["А / ВУЛ. ЯРОСЛАВА ГОМЗИ","Б / ВУЛ. СПОРТИВНА","В / ВУЛ. СОБОРНА"]
const SPAWN := Vector2(-58,158)
const FORMATION := Vector2(-40,136)
# Unit vector along the streets (towards east-south-east).
const STREET := Vector2(0.913,0.407)
const CAR_PAINT := ["5a4636","4a3e33","6a5444","3f3a33"]
const WALLS := ["c9c3ad","c2b48c","9a5a44","b8b5a6","9fb0ad","b9a68a"]
const ROOFS := ["6f7372","8a5a3c","6a4a3a","5f6b62","7b7e78"]
const FENCES := ["6d7b6a","7a6a58","8c8f8a","5d6a73"]
# Houses and fences of the battlefield, merged per 50 m chunk (ColorMesh).
static var scenery: Dictionary={}

# Towards the defenders: from each street to the next one north.
static func north() -> Vector2:return Vector2(STREET.y,-STREET.x)

# Offset in the battle's own frame: x along the streets, z back towards the
# attackers' rear (the old maps' +Z).
static func offset(x: float, z: float) -> Vector3:
 var rear:=-north()
 return Vector3(STREET.x*x+rear.x*z,0,STREET.y*x+rear.y*z)

# Distance of a point behind another along the axis of attack.
static func depth(from: Vector3, to: Vector3) -> float:
 var rear:=-north()
 return (to.x-from.x)*rear.x+(to.z-from.z)*rear.y

# Heading (rotation.y) of a soldier looking at the enemy.
static func facing(friendly: bool) -> float:
 var look:=north() if friendly else -north()
 return atan2(-look.x,-look.y)

# Three strongpoints per line, in the yards on the defenders' side.
static func strongpoints() -> Array:
 var points: Array=[]
 for i in range(3):
  var c: Vector2=CENTERS[i]
  for along in [-34.0,0.0,34.0]:
   points.append({"sector":i,"point":c+STREET*along+north()*(13.0 if along==0 else 11.0),"title":"ОП-%d" % (points.size()+1)})
 return points

static func definition() -> Dictionary:
 return {"id":ID,"title":"ВЕЛИКИЙ ШТУРМ / АВДІЇВКА","kind":"battle","biome":"orchard","seed":161126,"relief":0.0,"terrain":"avdiivka","heading":0.0,"size":400,"spawn":SPAWN,"defender_count":0,"buildings":full_houses(),"belts":[],"trenches":[],"insertion_cover":false,"defer_flush":true}

# OSM houses beside each strongpoint become full houses with rooms; the rest
# of the street is built as closed light houses.
static func full_houses() -> Array:
 var data := AvdiivkaData.shared()
 var chosen: Array=[]
 var used: Dictionary={}
 for sp in strongpoints():
  var best: Array=[];var best_distance:=26.0
  for i in range(data.features.buildings.size()):
   var b: Array=data.features.buildings[i]
   if b[6]!="H" or used.has(i):continue
   var at := Vector2(b[0],b[1])
   if (at-Vector2(sp.point)).dot(north())<-4:continue
   var distance:=at.distance_to(sp.point)
   if distance<best_distance:best=[i,b];best_distance=distance
  if best.is_empty():continue
  used[best[0]]=true
  var b: Array=best[1]
  # The door faces the street, which is south of the defenders' houses.
  var facing:=-north()
  chosen.append({"point":Vector2(b[0],b[1]),"size":Vector2(clampf(maxf(b[2],b[3]),9,13),clampf(minf(b[2],b[3]),7.5,10)),"yaw":atan2(-facing.x,-facing.y),"variant":chosen.size()%5,"floors":1,"osm":best[0]})
 return chosen

static func build(world: District) -> void:
 scenery.clear()
 world.batch_cell=100.0
 world.campaign_definition=definition()
 var data := AvdiivkaData.shared()
 var builder:=CampaignWorld.new()
 builder.build(world,world.campaign_definition)
 var props:=BattleProps.new(world,161126)
 var rng:=props.rng
 var full: Dictionary={}
 for spec in world.campaign_definition.buildings:full[int(spec.osm)]=spec
 # Footprints that keep fences, trees and wrecks out of houses.
 var rects: Array=[]
 for i in range(data.features.buildings.size()):
  var b: Array=data.features.buildings[i]
  if absf(b[0])>197 or absf(b[1])>197:continue
  if full.has(i):
   var spec: Dictionary=full[i]
   rects.append([spec.point,Vector2(spec.size)*0.5+Vector2.ONE*4.5,float(spec.yaw)])
   continue
  # A footprint crossing the edge of the battlefield is left to the outer area.
  if absf(b[0])+maxf(b[2],b[3])*0.5>199 or absf(b[1])+maxf(b[2],b[3])*0.5>199:continue
  rects.append([Vector2(b[0],b[1]),Vector2(b[2],b[3])*0.5,float(b[4])])
  light_house(world,props,b)
 var roads: Array=[]
 for road in data.features.roads:
  var points:=AvdiivkaData.pairs(road[3])
  var near:=false
  for p in points:if absf(p.x)<260 and absf(p.y)<260:near=true
  if near:roads.append([points,float(road[1]),int(road[2]),str(road[0])])
 fences(world,props,roads,rects)
 vegetation(world,builder,data,roads,rects)
 # Strongpoints: a sandbag emplacement facing the attack and a dugout.
 var occupied: Array[Vector2]=[]
 var facing:=atan2(north().x,north().y)
 for sp in strongpoints():
  var at:Vector2=sp.point
  props.sandbags(at,facing)
  dugout(props,at+north()*5.5+STREET*3,facing)
  occupied.append(at)
 # Sector flags on the streets.
 for i in range(3):
  var c:Vector2=CENTERS[i]
  var p:=Vector3(c.x,world.ground_height(Vector3(c.x,0,c.y)),c.y)
  world.rod(p,p+Vector3.UP*5,0.045,"60675c")
  var flag:=Models.part(world,p+Vector3(0.7,4.5,0),Vector3(1.4,0.8,0.025),"ab6355")
  flag.name="SectorFlag"+str(i)
 # Wrecks on the streets and on the open approach from the forest strip.
 var wrecks:=[["ifv",Vector2(-12,118),0.3],["tank",Vector2(-118,98),2.1],["apc",Vector2(48,128),-0.4],["truck",Vector2(-70,24),0.42],["car",Vector2(10,76),0.42],["car",Vector2(-60,42),0.4],
  ["car",Vector2(60,-22),2.0],["hedgehogs",Vector2(-4,-56),0.42],["barriers",Vector2(40,-35),0.42],["car",Vector2(-25,-75),0.45],["apc",Vector2(96,-118),0.4],["hedgehogs",Vector2(48,-150),0.42],["car",Vector2(120,-104),2.6]]
 for item in wrecks:
  var at:Vector2=item[1];var yaw:float=item[2]
  if blocked(at,rects,3.0):continue
  occupied.append(at)
  match item[0]:
   "apc":props.apc(at,yaw)
   "ifv":props.ifv(at,yaw,0.8)
   "tank":props.tank(at,yaw)
   "truck":props.truck(at,yaw)
   "hedgehogs":props.hedgehogs(at,yaw)
   "car":world.car(Vector3(at.x,world.ground_height(Vector3(at.x,0,at.y)),at.y),Color(CAR_PAINT[occupied.size()%4]),yaw,true)
   "barriers":
    for offset: Vector2 in [Vector2(-5,0),Vector2(0.5,2.5),Vector2(5.5,-0.5)]:
     var q:=at+offset.rotated(-yaw)
     var p:=Vector3(q.x,0,q.y);p.y=world.ground_height(p)
     world.concrete_barrier(p)
 # The insertion in the forest edge is screened by gabions towards the town.
 var ahead:Vector2=(Vector2(CENTERS[0])-SPAWN).normalized()
 var side:=Vector2(-ahead.y,ahead.x)
 for offset in [-22.0,0.0,22.0]:props.gabions(SPAWN+ahead*10+side*offset,atan2(-side.y,side.x),9)
 # Shell craters: the sector has been shelled for months.
 var made:=0
 var tries:=0
 while made<46 and tries<2000:
  tries+=1
  var at:=Vector2(rng.randf_range(-190,190),rng.randf_range(-190,190))
  if blocked(at,rects,2.5) or at.distance_to(SPAWN)<16:continue
  var clear:=true
  for other in occupied:
   if at.distance_to(other)<8:clear=false
  if not clear:continue
  props.crater(at,rng.randf_range(1.2,2.8))
  occupied.append(at)
  made+=1
 var material:=ColorMesh.material(world)
 for key in scenery:
  var instance:=MeshInstance3D.new()
  instance.name="Block_%d_%d" % [key.x,key.y]
  instance.mesh=scenery[key].build(material)
  world.add_child(instance)
 scenery.clear()
 OperationArea.attach(world)
 world.flush();world.flush_details();world.rebuild_campaign_grid()

static func chunk(at: Vector3) -> ColorMesh:
 var key:=Vector2i(floori(at.x/50.0),floori(at.z/50.0))
 if not scenery.has(key):scenery[key]=ColorMesh.new()
 return scenery[key]

# A box placed like BattleProps.block(), drawn into the merged scenery.
static func blk(props: BattleProps, local: Vector3, size: Vector3, color: String, rot: Vector3=Vector3.ZERO) -> void:
 var at:=props.origin+props.basis*local
 chunk(at).box(Transform3D(props.basis*Basis.from_euler(rot),at),size,Color(color))

static func roof(props: BattleProps, local: Vector3, size: Vector3, color: String, wall: String, rot: Vector3) -> void:
 var at:=props.origin+props.basis*local
 chunk(at).prism(Transform3D(props.basis*Basis.from_euler(rot),at),size,Color(color),Color(wall))

static func blocked(at: Vector2, rects: Array, margin: float) -> bool:
 for r in rects:
  var local:Vector2=(at-Vector2(r[0])).rotated(float(r[2]))
  var half:Vector2=r[1]
  if absf(local.x)<half.x+margin and absf(local.y)<half.y+margin:return true
 return false

# A closed private house as it stands after months of shelling: walls with
# windows and a door, a gable roof of slate or sheet metal, or a burnt shell.
static func light_house(world: District, props: BattleProps, b: Array) -> void:
 var w:float=b[2];var d:float=b[3];var yaw:float=b[4];var levels:int=b[5];var code:String=b[6]
 var center:=Vector2(b[0],b[1])
 var basis:=Basis(Vector3.UP,yaw)
 var low:=INF;var high:=-INF
 for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1),Vector2.ZERO]:
  var p:Vector3=basis*Vector3(corner.x*w*0.5,0,corner.y*d*0.5)
  var h:=world.ground_height(Vector3(center.x+p.x,0,center.y+p.z))
  low=minf(low,h);high=maxf(high,h)
 props.origin=Vector3(center.x,low-0.3,center.y);props.basis=basis
 var rng:=props.rng
 var shed:=code=="S"
 var storey:=2.4 if shed else 2.9
 var state:=rng.randf()
 var ruined:=state<0.14 and not shed
 var damaged:=state<0.48
 var base:=high-low+0.3
 var wall_h:=base+(rng.randf_range(1.0,2.0) if ruined else storey*levels+(0.0 if shed else 0.35))
 var paint:String=WALLS[rng.randi()%WALLS.size()]
 if shed:paint=["8a8678","6f6a5e","7d7a6c"][rng.randi()%3]
 if damaged and rng.randf()<0.5:paint=Color(paint).darkened(0.35).to_html(false)
 props.solid(Vector3(0,wall_h*0.5,0),Vector3(w,wall_h,d),"brick",paint)
 blk(props,Vector3(0,wall_h*0.5,0),Vector3(w,wall_h,d),paint)
 if not shed:
  blk(props,Vector3(0,base+0.2,0),Vector3(w+0.06,0.6,d+0.06),"6b675c")
  # Windows: dark glazing, empty frames where blasts took the glass out.
  var sill:=base+0.95
  if not ruined or wall_h>base+1.9:
   for face in range(4):
    var along_x:=face<2
    var length:=w if along_x else d
    var count:=maxi(1,int(length/3.4))
    for k in range(count):
     var u:=-length*0.5+(k+0.5)*length/count
     var glass:="1d2021" if damaged else "2f3a3d"
     var at:=Vector3(u,sill+0.62,(d*0.5+0.02)*(1 if face==0 else -1)) if along_x else Vector3((w*0.5+0.02)*(1 if face==2 else -1),sill+0.62,u)
     blk(props,at,Vector3(1.15,1.25,0.06) if along_x else Vector3(0.06,1.25,1.15),glass)
     blk(props,at-Vector3(0,0.66,0),Vector3(1.3,0.07,0.16) if along_x else Vector3(0.16,0.07,1.3),"9a978a")
   blk(props,Vector3(w*0.3,base+1.0,d*0.5+0.03),Vector3(0.95,2.0,0.06),"4e3f31")
 if ruined:
  # Roof and ceiling gone; rubble inside and around the walls.
  props.origin.y=low
  for k in range(10):
   blk(props,Vector3(rng.randf_range(-w,w)*0.45,0.25,rng.randf_range(-d,d)*0.45),Vector3(rng.randf_range(0.4,1.2),rng.randf_range(0.2,0.5),rng.randf_range(0.4,1.0)),["8f8a7c","6e6a60","9a5a44"][k%3],Vector3(0,rng.randf()*TAU,0))
  return
 # Gable roof along the long side (ridge on the prism's Z axis).
 var long_x:=w>=d
 var span:=(d if long_x else w)+0.7
 var length:=(w if long_x else d)+0.6
 var rise:=minf(2.6,span*(0.30 if shed else 0.38))
 var cover:String=ROOFS[rng.randi()%ROOFS.size()]
 var roof_rot:=Vector3(0,PI*0.5 if long_x else 0.0,0)
 if shed:
  blk(props,Vector3(0,wall_h+0.06,0),Vector3(w+0.3,0.12,d+0.3),cover,Vector3(0.0 if long_x else 0.12,0,0.12 if long_x else 0.0))
  return
 if damaged and rng.randf()<0.6:
  # Half of the roof blown off: the other half stands, rafters show.
  roof(props,Vector3(0,wall_h+rise*0.5,0)+(Vector3(length*0.25,0,0) if long_x else Vector3(0,0,length*0.25)),Vector3(span,rise,length*0.5),cover,paint,roof_rot)
  for k in range(4):
   var t:=-length*0.5+(k+0.5)*length*0.125
   var at:=Vector3(t,0,0) if long_x else Vector3(0,0,t)
   for s in [-1,1]:
    var eave:=(Vector3(0,wall_h,s*span*0.5) if long_x else Vector3(s*span*0.5,wall_h,0))+at
    props.rod(eave,at+Vector3(0,wall_h+rise,0),0.06,"2b2621")
  props.debris(maxf(w,d)*0.7,12)
 else:
  roof(props,Vector3(0,wall_h+rise*0.5,0),Vector3(span,rise,length),cover,paint,roof_rot)
 blk(props,Vector3(w*0.22,wall_h+rise*0.6,d*0.1),Vector3(0.5,1.4,0.5),"8d6755")

# Street frontage: picket and sheet fences with gates and blasted gaps.
static func fences(world: District, props: BattleProps, roads: Array, rects: Array) -> void:
 var rng:=props.rng
 for road in roads:
  if str(road[3]) not in ["residential","unclassified","living_street","tertiary","secondary"]:continue
  var points:PackedVector2Array=road[0]
  var offset:=float(road[1])*0.5+2.6
  for i in range(points.size()-1):
   var a:=points[i];var b:=points[i+1]
   var along:=b-a;var length:=along.length()
   if length<3:continue
   var u:=along/length;var normal:=Vector2(-u.y,u.x)
   for s: float in [-1.0,1.0]:
    var color:String=FENCES[rng.randi()%FENCES.size()]
    var t:=1.5
    while t<length-1.5:
     var mid:=a+u*(t+1.25)+normal*s*offset
     var gap:=rng.randf()<0.38 or blocked(mid,rects,0.4) or absf(mid.x)>196 or absf(mid.y)>196
     if not gap:
      var g:=world.ground_height(Vector3(mid.x,0,mid.y))
      props.origin=Vector3(mid.x,g,mid.y);props.basis=Basis(Vector3.UP,atan2(-u.y,u.x))
      var tilt:=Vector3(0,0,rng.randf_range(-0.05,0.05)) if rng.randf()<0.3 else Vector3.ZERO
      blk(props,Vector3(0,0.68,0),Vector3(2.45,1.36,0.04),color,tilt)
      blk(props,Vector3(-1.2,0.75,0),Vector3(0.07,1.5,0.07),"4a4a44")
      props.solid(Vector3(0,0.68,0),Vector3(2.5,1.36,0.08),"wood",color)
     t+=2.5

# Woods of the forest strip, fruit trees in the yards, grass and bushes.
static func vegetation(world: District, builder: CampaignWorld, data: AvdiivkaData, roads: Array, rects: Array) -> void:
 var rng:=builder.rng
 var woods: Array[PackedVector2Array]=[]
 for flat in data.features.woods:
  var poly:=AvdiivkaData.pairs(flat)
  var box:=Rect2(poly[0],Vector2.ZERO)
  for p in poly:box=box.expand(p)
  if box.intersects(Rect2(-200,-200,400,400)):woods.append(poly)
 for z in range(-194,195,7):
  for x in range(-194,195,7):
   var at:=Vector2(x+rng.randf_range(-2.5,2.5),z+rng.randf_range(-2.5,2.5))
   var inside:=false
   for poly in woods:
    if Geometry2D.is_point_in_polygon(at,poly):inside=true;break
   if not inside or at.distance_to(SPAWN)<17 or blocked(at,rects,1.5):continue
   builder.tree_at(at)
   if rng.randf()<0.3:builder.shrub(at+Vector2(2,1))
 # Fruit trees behind about every other house.
 for r in rects:
  if rng.randf()<0.45:continue
  var c:Vector2=r[0]
  for attempt in range(4):
   var at:=c+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(8,12)
   if absf(at.x)>192 or absf(at.y)>192 or blocked(at,rects,1.8) or road_distance(at,roads)<5:continue
   builder.tree_at(at,true)
   break
 for road in roads:
  var points:PackedVector2Array=road[0]
  for i in range(points.size()-1):
   if rng.randf()<0.6:continue
   var at:=points[i].lerp(points[i+1],rng.randf())+Vector2.from_angle(rng.randf()*TAU)*(float(road[1])*0.5+4)
   if absf(at.x)>192 or absf(at.y)>192 or blocked(at,rects,1.0):continue
   builder.shrub(at)

static func road_distance(at: Vector2, roads: Array) -> float:
 var best:=INF
 for road in roads:
  var points:PackedVector2Array=road[0]
  for i in range(points.size()-1):
   best=minf(best,at.distance_to(Geometry2D.get_closest_point_to_segment(at,points[i],points[i+1])))
 return best

# Log-roofed dugout half sunk into a yard: a low mound with an entrance.
static func dugout(props: BattleProps, at: Vector2, yaw: float) -> void:
 props.place(at,yaw)
 props.solid(Vector3(0,0.45,0),Vector3(4.2,0.9,3.2),"earth","5b4d3c")
 blk(props,Vector3(0,0.45,0),Vector3(4.2,0.9,3.2),"5b4d3c")
 blk(props,Vector3(0,0.98,0),Vector3(4.6,0.2,3.6),"675843")
 for k in range(6):props.rod(Vector3(-2.1,1.1,-1.5+k*0.6),Vector3(2.1,1.1,-1.5+k*0.6),0.11,"4f4434")
 blk(props,Vector3(0,0.4,1.75),Vector3(1.0,0.8,0.3),"2a2622")

const MENU_TEXT := "А · вул. Ярослава Гомзи → Б · вул. Спортивна → В · вул. Соборна\n\nПівденний приватний сектор Авдіївки: реальні будинки й вулиці (OpenStreetMap) та рельєф. Штурм виходить з лісосмуги на південному заході. Займи рубіж і утримуй його 30 с без противника в зоні.\n\nПротивник тримає дев'ять опорних пунктів, по три на кожній вулиці. Мінометник і командир БМ-21 «Град» командують штурмом: на старті штурм чекає їхньої команди. «Град» стоїть за кілька кілометрів у полі.\n\nУсі війська на полі від початку, підкріплень немає. Після твоєї загибелі командування за 5 с приймає найближчий живий боєць."
