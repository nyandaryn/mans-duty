class_name CampaignWorld
extends RefCounted

var world: District
var definition: Dictionary
var rng := RandomNumberGenerator.new()
var origin := Vector3.ZERO
var basis := Basis.IDENTITY
var defense_posts: Array[Vector3]=[]

func build(district: District, mission: Dictionary) -> void:
 world=district
 definition=mission
 rng.seed=int(mission.seed)
 world.terrain=CampaignTerrain.new()
 world.add_child(world.terrain)
 world.terrain.configure(mission)
 world.terrain.build_geometry()
 world.grid_limit=199
 world.map_id=mission.id
 world.map_title=mission.title.to_upper()
 world.player_spawn=ground(mission.spawn)+Vector3.UP*0.12
 world.player_spawn_yaw=0
 world.spawn_points.clear()
 for building in mission.buildings:house(building)
 vegetation()
 trenches()
 scenery()
 # Reserve sheltered insertion on the reverse side of a local earthwork.
 origin=ground(mission.spawn)
 basis=Basis.IDENTITY
 if mission.get("insertion_cover",true):
  for x in [-3.5,3.5]:part(Vector3(x,0.85,-6),Vector3(7,1.7,1.3),"726449","earth")
 if defense_posts.is_empty():defense_posts.append(ground(Vector2(0,-45)))
 for i in range(int(mission.defender_count)):
  var point: Vector3=defense_posts[mini(defense_posts.size()-1,int(float(i)*defense_posts.size()/int(mission.defender_count)))]
  if i>=defense_posts.size():point+=Vector3((i%2)*1.1,0,(i%3)*0.8)
  world.spawn_points.append(point+Vector3.UP*0.10)
 # A map that adds its own scenery afterwards builds the batches once.
 if mission.get("defer_flush",false):return
 world.flush()
 world.flush_details()
 world.rebuild_campaign_grid()

func ground(point: Vector2) -> Vector3:
 return Vector3(point.x,world.terrain.height_at(point),point.y)

func part(local: Vector3, size: Vector3, color: String, substance: String="concrete", solid: bool=true, extra_rotation: Vector3=Vector3.ZERO) -> void:
 var position := origin+basis*local
 var rotation := basis*Basis.from_euler(extra_rotation)
 world.box(position,size,Color(color),solid,substance)
 var key := Color(color).to_html()+"|"+world.cell_key(position)
 var batch: Dictionary=world.batches[key]
 var index: int=batch.transforms.size()-1
 batch.transforms[index]=Transform3D(rotation.scaled_local(size),position)
 if solid:batch.bodies[index].basis=rotation

const WALL_COLORS := ["b5aa8c","a7b1ad","aa8170","c3bfa6","8d9695"]
const ROOF_COLORS := ["875746","586569","76796b","815c48","575951"]

func house(spec: Dictionary) -> void:
 origin=ground(spec.point)
 basis=Basis(Vector3.UP,float(spec.yaw))
 var size: Vector2=spec.size
 var w := size.x
 var d := size.y
 var floors: int=spec.floors
 var variant: int=spec.variant
 var wall_colors := WALL_COLORS
 var roof_colors := ROOF_COLORS
 var wall: String=wall_colors[variant]
 part(Vector3(0,0.02,0),Vector3(w+0.3,0.08,d+0.3),"78796e")
 # Four facades: segmented masonry around real windows and a front doorway.
 for face in range(4):
  var front := face<2
  var length := w if front else d
  var count := maxi(3,int(length/3.0))
  var unit := length/count
  for floor_index in range(floors):
   for bay in range(count):
    var u := -length/2+(bay+0.5)*unit
    var bottom := floor_index*2.9
    var door := face==0 and floor_index==0 and bay==count/2
    var opening := 1.65 if door else (1.25+variant*0.07)
    var pier := (unit-opening)/2
    for segment in [[u-unit*0.5+pier/2,pier,bottom,bottom+2.9],[u+unit*0.5-pier/2,pier,bottom,bottom+2.9],[u,opening,bottom,bottom+(0.04 if door else 0.85)],[u,opening,bottom+2.22,bottom+2.9]]:
     var height: float=segment[3]-segment[2]
     if height<0.02:continue
     var position := Vector3(segment[0],(segment[2]+segment[3])/2,(-d/2 if face==0 else d/2)) if front else Vector3((-w/2 if face==2 else w/2),(segment[2]+segment[3])/2,segment[0])
     var dimensions := Vector3(segment[1],height,0.30) if front else Vector3(0.30,height,segment[1])
     part(position,dimensions,wall,"brick")
    if not door:
     var sill := Vector3(u,bottom+0.83,(-d/2 if face==0 else d/2)) if front else Vector3((-w/2 if face==2 else w/2),bottom+0.83,u)
     part(sill,Vector3(opening+0.15,0.08,0.45) if front else Vector3(0.45,0.08,opening+0.15),"717c73","wood")
     for edge in [-1,1]:
      var frame: Vector3=sill+(Vector3(edge*opening/2,0.7,0) if front else Vector3(0,0.7,edge*opening/2))
      part(frame,Vector3(0.055,1.4,0.33) if front else Vector3(0.33,1.4,0.055),"6a776d","wood")
     if floor_index==0 and face==1:
      var post := origin+basis*(sill+Vector3(0,0, -1.3))
      post.y=origin.y+0.08
      defense_posts.append(post)
   if floor_index>0 and face==0:part(Vector3(0,floor_index*2.9,0),Vector3(w,0.18,d),"727970")
 # Ground-floor partitions with an actual central passage and furniture.
 for x in [-w*0.34,w*0.34]:part(Vector3(x,1.3,0),Vector3(w*0.32,2.6,0.16),"9e9b83","brick")
 part(Vector3(0,2.48,0),Vector3(w*0.35,0.25,0.16),"9e9b83","brick")
 for side in [-1,1]:
  part(Vector3(side*w*0.32,0.73,d*0.15),Vector3(1.4,0.12,0.85),"7d654c","wood")
  for dx in [-0.5,0.5]:
   part(Vector3(side*w*0.32+dx,0.35,d*0.15),Vector3(0.08,0.7,0.55),"685440","wood")
  part(Vector3(side*w*0.37,0.35,-d*0.25),Vector3(1.3,0.7,2),"636b57","fabric")
 var roof_y := floors*2.9
 if variant in [1,4] or definition.kind=="district":
  part(Vector3(0,roof_y,0),Vector3(w+0.6,0.25,d+0.6),roof_colors[variant])
  for side in [-1,1]:part(Vector3(side*w/2,roof_y+0.28,0),Vector3(0.2,0.55,d),wall,"brick")
 else:
  var angle := 0.30+variant*0.035
  var span := (w/2+0.6)/cos(angle)
  for side in [-1,1]:part(Vector3(side*w/4,roof_y+w/4*tan(angle),0),Vector3(span,0.16,d+0.9),roof_colors[variant],"wood",true,Vector3(0,0,-side*angle))
  for side in [-1,1]:gable(Vector3(0,roof_y,side*d/2),w,w/2*tan(angle),wall)
 part(Vector3(w*0.24,roof_y+1.0,d*0.20),Vector3(0.65,2,0.65),"8d6755","brick")
 # Porches, annexes and yard walls vary with architecture, not just paint.
 if variant%2==0:
  part(Vector3(0,2.6,-d/2-1.2),Vector3(3.2,0.14,2.6),roof_colors[variant],"wood")
  for x in [-1.4,1.4]:part(Vector3(x,1.3,-d/2-2.2),Vector3(0.12,2.6,0.12),"696f60","wood")
 if variant in [2,3]:
  part(Vector3(w/2+2,1.1,d*0.20),Vector3(3.8,2.2,0.2),"797d6a","wood")
  part(Vector3(w/2+2,2.2,d*0.20),Vector3(4.2,0.14,4.0),roof_colors[variant],"wood")
 for side in [-1,1]:part(Vector3(side*(w/2+4),0.65,0),Vector3(0.15,1.3,d+4),"81846e","wood")
 world.interior_points.append(origin+basis*Vector3(0,0.1,-d*0.23))
 world.entrances.append(origin+basis*Vector3(0,0.1,-d/2-1))

func vegetation() -> void:
 for belt in definition.belts:
  var a: Vector2=belt[0]
  var b: Vector2=belt[1]
  var width: float=belt[2]
  var length := a.distance_to(b)
  var perpendicular := Vector2(-(b-a).y,(b-a).x).normalized()
  for i in range(int(length/5)):
   for row in range(-int(width/5),int(width/5)+1):
    var point := a.lerp(b,(i+0.5)/(length/5))+perpendicular*(row*4.5+rng.randf_range(-1.5,1.5))
    point+=Vector2(rng.randf_range(-1.2,1.2),rng.randf_range(-1.2,1.2))
    if absf(point.x)>192 or absf(point.y)>192 or world.terrain.trench_distance(point)<10:continue
    if point.distance_to(definition.spawn)<18:continue
    tree_at(point)
    if rng.randf()<0.25:shrub(point+perpendicular*2)
 if definition.kind!="forest":
  for building in definition.buildings:
   for i in range(3 if definition.kind=="village" else 1):
    var point: Vector2=building.point+Vector2(-20-i*4,16)
    if absf(point.x)<190 and absf(point.y)<190:tree_at(point,true)
 # Sparse ground vegetation leaves the meadows readable and traversable.
 for i in range(1100):
  var point := Vector2(rng.randf_range(-195,195),rng.randf_range(-195,195))
  if world.terrain.trench_distance(point)<5:continue
  # No grass tufts on surveyed paved roads.
  if world.terrain.data!=null and world.terrain.data.battle_color(point.x,point.y).v<0.33:continue
  var p := ground(point)
  world.detail("foliage",p+Vector3.UP*0.14,Vector3(0.6,0.38,0.6),"989a68",Vector3(0,rng.randf()*TAU,0))

func tree_at(point: Vector2, orchard: bool=false) -> void:
 for building in definition.buildings:
  var local := (point-Vector2(building.point)).rotated(-float(building.yaw))
  if absf(local.x)<building.size.x/2+2.5 and absf(local.y)<building.size.y/2+2.5:return
 var pos := ground(point)
 var height := rng.randf_range(4,6) if orchard else rng.randf_range(7,11)
 var radius := rng.randf_range(0.14,0.25)
 world.solid_trunk(pos,height,radius)
 world.canopy_centers.append(pos+Vector3.UP*(height-1))
 var color := "a4ad87"
 if definition.biome=="dry":color="b7ac78"
 if definition.biome=="autumn":color="c0a264"
 if definition.biome=="pine":color="728a6a"
 for i in range(28 if orchard else 40):
  var angle := rng.randf()*TAU
  var radius_leaf := sqrt(rng.randf())*(2.1 if orchard else 3.0)
  var y := rng.randf_range(height-2.6,height+0.4)
  if definition.biome=="pine":radius_leaf*=clampf((height+0.6-y)/3.2,0.1,1)
  world.detail("foliage",pos+Vector3(cos(angle)*radius_leaf,y,sin(angle)*radius_leaf),Vector3.ONE*rng.randf_range(1.5,2.2),color,Vector3(rng.randf_range(-1,1),angle,rng.randf_range(-0.6,0.6)))

func shrub(point: Vector2) -> void:
 var pos := ground(point)
 world.concealment_patches.append(pos+Vector3.UP*0.65)
 for i in range(8):world.detail("foliage",pos+Vector3(rng.randf_range(-0.6,0.6),rng.randf_range(0.25,0.95),rng.randf_range(-0.6,0.6)),Vector3.ONE,"8b9873",Vector3(0,rng.randf()*TAU,0))

func trenches() -> void:
 for trench in definition.trenches:
  for i in range(trench.size()-1):
   var a: Vector2=trench[i]
   var b: Vector2=trench[i+1]
   var steps := maxi(1,int(a.distance_to(b)/7))
   for step in range(1,steps):
    var point := a.lerp(b,float(step)/steps)
    origin=ground(point)
    basis=Basis.IDENTITY
    # A firing step elevates the defender above the dug floor while retreating
    # along the trench still drops their head below the surrounding ground.
    defense_posts.append(origin)
    if step%3==0:
     part(Vector3(0,0.01,0),Vector3(0.7,0.015,0.7),"6e5a42","wood",false)

func scenery() -> void:
 # Tracks are painted on the terrain mesh itself and follow every slope.
 if definition.kind=="district":
  for z in [-135,-95,-55,-15,25,65]:
   var x := sin(float(z)/57+float(definition.heading))*18
   var p := ground(Vector2(x+7,z))
   world.rod(p,p+Vector3.UP*5.5,0.07,"586363")
   world.rod(p+Vector3.UP*5.3,p+Vector3(-1.2,5.3,0),0.05,"586363")
   origin=p+Vector3(-1.2,5.3,0)
   basis=Basis.IDENTITY
   part(Vector3.ZERO,Vector3(0.8,0.13,0.3),"bec2ae","steel",false)
  for i in range(4):
   var z := -105+i*45
   var x := sin(float(z)/57+float(definition.heading))*18-6
   var p := ground(Vector2(x,z))
   world.car(p,Color(["687c73","9a806b","a6a89b","5d6d7a"][i]))
 for building in definition.buildings:
  var center: Vector2=building.point
  origin=ground(center+Vector2(0,building.size.y/2+5))
  basis=Basis(Vector3.UP,float(building.yaw))
  # Utility sheds and scattered yard cover distinguish the approach routes.
  part(Vector3(-2,0.65,0),Vector3(1.2,1.3,0.6),"737564","wood")
  part(Vector3(2,0.45,1),Vector3(1.4,0.9,0.7),"807660","wood")
 # Visible boundary markers; matching collision keeps the playable area 400 m.
 for side in [-1,1]:
  for along in range(-198,199,6):
   for p in [Vector2(side*199,along),Vector2(along,side*199)]:
    origin=ground(p)
    basis=Basis.IDENTITY
    part(Vector3(0,0.7,0),Vector3(0.10,1.4,0.10),"6e725e","wood")
  world.collider(Vector3(side*200,15,0),Vector3(0.1,80,400)).set_meta("boundary",true)
  world.collider(Vector3(0,15,side*200),Vector3(400,80,0.1)).set_meta("boundary",true)

func gable(local: Vector3, width: float, height: float, color: String) -> void:
 var holder := Node3D.new()
 var visual := Models.profile(holder,PackedVector2Array([Vector2(-width/2,0),Vector2(0,height),Vector2(width/2,0)]),0.24,color)
 holder.remove_child(visual)
 holder.free()
 var body := DestructibleSurface.new()
 body.district=world
 body.tint=Color(color)
 body.set_meta("ballistic_material","brick")
 body.set_meta("surface_color",Color(color))
 var collision := CollisionShape3D.new()
 collision.shape=visual.mesh.create_trimesh_shape()
 collision.shape.backface_collision=true
 body.add_child(collision)
 visual.name="SurfaceMesh"
 body.add_child(visual)
 world.add_child(body)
 body.transform=Transform3D(basis*Basis(Vector3.UP,PI/2),origin+basis*local)
