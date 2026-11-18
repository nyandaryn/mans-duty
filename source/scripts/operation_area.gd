class_name OperationArea
extends Node3D

# The real ground around the battlefield: 12 × 12 km of Avdiivka and its
# outskirts (relief, land cover, roads, railways, houses, woods) from
# AvdiivkaData, where the rocket launcher marches, deploys and fires. The
# 400 × 400 m battlefield in the middle stays the detailed CampaignTerrain;
# the outer ground leaves a hole there and meets its edge exactly.
#
# Ground and far canopy are flat grids displaced on the GPU (no vertex loops
# at load); collision is four heightmap strips read from the relief image.
# Roads, water and the town's houses are built on a worker thread and appear
# a few seconds after the battle starts; house colliders exist at once.
const GROUND := preload("res://scripts/outer_ground.gdshader")
const CHUNK := 1200.0
const TREE_CHUNK := 300.0
const TREES_END := 900.0
const RIBBONS_END := 3200.0
const BOUNDARY_LAYER := 64
const INNER := 200.0
const SKIP_ROADS := ["footway","path","steps","pedestrian","cycleway","bridleway"]
const WALLS := {"H":["c9c3ad","c2b48c","9a5a44","b8b5a6","9fb0ad","b9a68a","a99e86"],"S":["8a8678","6f6a5e","7d7a6c","837261"],"A":["b9b3a3","a8a296","c4b9a0","9c9a92"],"I":["9a978c","8b8a83","a49d8b","7f7c74"],"P":["c6bda8","b3a991","a7b0a3"]}
const ROOFS := ["6f7372","8a5a3c","6a4a3a","5f6b62","7b7e78","555a5c"]
const STOREY := {"H":2.9,"S":2.5,"A":2.9,"I":4.5,"P":3.4}
var data: AvdiivkaData
var world: District
var terrain: CampaignTerrain
var vertex_material: StandardMaterial3D
var tree_mesh: ArrayMesh
var tree_x := PackedFloat32Array()
var tree_z := PackedFloat32Array()
var tree_h := PackedFloat32Array()
var tree_kind := PackedByteArray()
var tree_chunks: Dictionary={}
var tree_built: Dictionary={}
var trunks: StaticBody3D
var trunk_center := Vector2(INF,INF)
var stream_timer := 0.0
var task := -1
var cancelled := false
var detail_ready := false

static func attach(district: District) -> OperationArea:
 var area := OperationArea.new()
 area.name="OperationArea"
 area.world=district
 area.terrain=district.terrain
 area.data=AvdiivkaData.shared()
 district.operation_area=area
 district.add_child(area)
 area.build()
 return area

func build() -> void:
 vertex_material=StandardMaterial3D.new()
 vertex_material.vertex_color_use_as_albedo=true
 vertex_material.vertex_color_is_srgb=true
 vertex_material.roughness=0.95
 # The battlefield keeps its fence, but only for people: the drone, rockets
 # and bullets pass over the edge into the operation area.
 for child in world.get_children():
  if child is StaticBody3D and child.has_meta("boundary"):child.collision_layer=BOUNDARY_LAYER
 load_trees()
 ground()
 collision()
 house_colliders()
 limits()
 task=WorkerThreadPool.add_task(build_detail,false,"Operation area detail")

func _exit_tree() -> void:
 cancelled=true
 if task>=0:
  WorkerThreadPool.wait_for_task_completion(task)
  task=-1

static func inner_building(b: Array) -> bool:
 var reach:=maxf(float(b[2]),float(b[3]))*0.5
 return absf(b[0])<=197 and absf(b[1])<=197 and absf(b[0])+reach<=199 and absf(b[1])+reach<=199

func ground() -> void:
 var relief:=ImageTexture.create_from_image(Image.create_from_data(data.size,data.size,false,Image.FORMAT_RF,data.relief_bytes))
 var cover:=ImageTexture.create_from_image(Image.create_from_data(data.size,data.size,false,Image.FORMAT_RGB8,data.cover))
 var forest:=ImageTexture.create_from_image(Image.create_from_data(data.size,data.size,false,Image.FORMAT_L8,data.forest))
 var grain: Texture2D=(terrain.ground_mesh.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture
 var materials: Array[ShaderMaterial]=[]
 for raised in [0.0,1.0]:
  var material:=ShaderMaterial.new()
  material.shader=GROUND
  material.set_shader_parameter("relief",relief)
  material.set_shader_parameter("cover",cover)
  material.set_shader_parameter("forest",forest)
  material.set_shader_parameter("grain",grain)
  material.set_shader_parameter("half_size",data.half)
  material.set_shader_parameter("grid_step",data.step)
  material.set_shader_parameter("inner",INNER)
  material.set_shader_parameter("nodes",data.size)
  material.set_shader_parameter("canopy",raised)
  materials.append(material)
 # Ground: 10 × 10 chunks of 1.2 km sharing one 60 × 60 cell grid.
 var plane:=PlaneMesh.new()
 plane.size=Vector2(CHUNK,CHUNK)
 plane.subdivide_width=int(CHUNK/data.step)-1
 plane.subdivide_depth=int(CHUNK/data.step)-1
 var count:=int(data.half*2/CHUNK)
 for j in range(count):
  for i in range(count):
   var instance:=MeshInstance3D.new()
   instance.name="Ground_%d_%d" % [i,j]
   instance.mesh=plane
   instance.material_override=materials[0]
   instance.position=Vector3(-data.half+(i+0.5)*CHUNK,0,-data.half+(j+0.5)*CHUNK)
   instance.custom_aabb=AABB(Vector3(-CHUNK*0.5,data.minimum-2,-CHUNK*0.5),Vector3(CHUNK,data.maximum-data.minimum+4,CHUNK))
   instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   add_child(instance)
 # Far canopy: 300 m chunks over the woods, swapped with the single trees.
 var small:=PlaneMesh.new()
 small.size=Vector2(TREE_CHUNK,TREE_CHUNK)
 small.subdivide_width=int(TREE_CHUNK/data.step)-1
 small.subdivide_depth=int(TREE_CHUNK/data.step)-1
 var offset:=int(data.half/TREE_CHUNK)
 for cj in range(offset*2):
  for ci in range(offset*2):
   # Chunks with trees are the wooded ones; the shader drops open ground.
   if not tree_chunks.has(Vector2i(ci-offset,cj-offset)):continue
   var instance:=MeshInstance3D.new()
   instance.name="Canopy_%d_%d" % [ci,cj]
   instance.mesh=small
   instance.material_override=materials[1]
   instance.position=Vector3(-data.half+(ci+0.5)*TREE_CHUNK,0,-data.half+(cj+0.5)*TREE_CHUNK)
   instance.custom_aabb=AABB(Vector3(-TREE_CHUNK*0.5,data.minimum-2,-TREE_CHUNK*0.5),Vector3(TREE_CHUNK,data.maximum-data.minimum+24,TREE_CHUNK))
   instance.visibility_range_begin=TREES_END
   instance.visibility_range_begin_margin=40
   instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   add_child(instance)

# Four heightmap strips around the battlefield; Jolt splits every cell along
# the same diagonal as the drawn ground and AvdiivkaData.height().
func collision() -> void:
 var body:=StaticBody3D.new()
 body.name="OuterGround"
 body.set_meta("ballistic_material","earth")
 body.set_meta("terrain",true)
 body.set_meta("surface_color",Color("7d7a58"))
 add_child(body)
 var image:=Image.create_from_data(data.size,data.size,false,Image.FORMAT_RF,data.relief_bytes)
 var low:=int((data.half-INNER)/data.step);var high:=int((data.half+INNER)/data.step);var n:=data.size-1
 for strip in [[0,0,n,low],[0,high,n,n],[0,low,low,high],[high,low,n,high]]:
  var i0:int=strip[0];var j0:int=strip[1];var i1:int=strip[2];var j1:int=strip[3]
  var shape:=HeightMapShape3D.new()
  shape.update_map_data_from_image(image.get_region(Rect2i(i0,j0,i1-i0+1,j1-j0+1)),0.0,1.0/data.step)
  var collision:=CollisionShape3D.new()
  collision.shape=shape
  collision.scale=Vector3.ONE*data.step
  collision.position=Vector3(-data.half+(i0+i1)*0.5*data.step,0,-data.half+(j0+j1)*0.5*data.step)
  body.add_child(collision)

func ground_at(x: float, z: float) -> float:
 return terrain.height_at(Vector2(x,z))

# Everything about a house that its collider and its drawing share. The
# random state is seeded by the position, so both agree on every roll.
func house_shape(b: Array) -> Dictionary:
 var x:float=b[0];var z:float=b[1];var w:float=b[2];var d:float=b[3];var yaw:float=b[4];var levels:int=maxi(1,int(b[5]));var code:String=b[6]
 var basis:=Basis(Vector3.UP,yaw)
 var low:=INF;var high:=-INF
 for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
  var p:=basis*Vector3(corner.x*w*0.5,0,corner.y*d*0.5)
  var h:=ground_at(x+p.x,z+p.z)
  low=minf(low,h);high=maxf(high,h)
 var rng:=RandomNumberGenerator.new()
 rng.seed=hash(Vector2(x,z))
 var storey: float=STOREY.get(code,2.9)
 var top:=high+0.4+storey*levels+(0.4 if code=="A" else 0.0)
 # Months of shelling: blown-off roofs and burnt-out shells.
 var state:=rng.randf()
 var ruined:=state<0.12 and code!="A"
 var roofless:=state<0.38
 if ruined:top=high+rng.randf_range(1.2,2.4)
 var gable:=not ruined and not roofless and code in ["H","S"]
 var span:=minf(w,d)
 var rise:=minf(2.6,span*(0.28 if code=="S" else 0.38)) if gable else 0.0
 return {"x":x,"z":z,"w":w,"d":d,"yaw":yaw,"basis":basis,"levels":levels,"code":code,"low":low-0.6,"high":high,"top":top,"storey":storey,"ruined":ruined,"roofless":roofless,"gable":gable,"rise":rise,"rng":rng}

func house_colliders() -> void:
 var bodies: Dictionary={}
 for b in data.features.buildings:
  if inner_building(b) or absf(b[0])>data.half-30 or absf(b[1])>data.half-30:continue
  var key:=Vector2i(floori(b[0]/600.0),floori(b[1]/600.0))
  if not bodies.has(key):
   var body:=StaticBody3D.new()
   body.name="Houses_%d_%d" % [key.x,key.y]
   body.set_meta("ballistic_material","brick")
   body.set_meta("surface_color",Color("b8b0a0"))
   body.set_meta("indestructible",true)
   add_child(body)
   bodies[key]=body
  var shape_info:=house_shape(b)
  var top:float=shape_info.top+float(shape_info.rise)*0.6
  var body: StaticBody3D=bodies[key]
  var shape:=BoxShape3D.new()
  shape.size=Vector3(float(b[2]),top-float(shape_info.low),float(b[3]))
  var owner_id:=body.create_shape_owner(body)
  body.shape_owner_add_shape(owner_id,shape)
  body.shape_owner_set_transform(owner_id,Transform3D(shape_info.basis,Vector3(float(b[0]),(top+float(shape_info.low))*0.5,float(b[1]))))

# Worker thread: roads, railways, streams, ponds and the town's houses as
# vertex-coloured meshes per chunk. Nodes are added on the main thread.
func build_detail() -> void:
 var ribbons: Dictionary={}
 for road in data.features.roads:
  if cancelled:return
  var kind:String=road[0]
  if kind in SKIP_ROADS:continue
  var width:float=road[1]
  if int(road[2])==1:
   ribbon(ribbons,AvdiivkaData.pairs(road[3]),[-width*0.5-0.7,-width*0.5,width*0.5,width*0.5+0.7],[Color("8b8676"),Color("4c4f4d"),Color("4c4f4d"),Color("8b8676")],0.16)
  else:
   ribbon(ribbons,AvdiivkaData.pairs(road[3]),[-width*0.5,-width*0.18,width*0.18,width*0.5],[Color("7d6c52"),Color("6c5c45"),Color("6c5c45"),Color("7d6c52")],0.12)
 for line in data.features.rails:
  ribbon(ribbons,AvdiivkaData.pairs(line),[-2.4,-0.85,0.85,2.4],[Color("6f675b"),Color("3d3934"),Color("3d3934"),Color("6f675b")],0.32)
 for stream in data.features.streams:
  ribbon(ribbons,AvdiivkaData.pairs(stream[1]),[-1.6,-0.6,0.6,1.6],[Color("5d6a55"),Color("4b5e60"),Color("4b5e60"),Color("5d6a55")],0.05)
 if cancelled:return
 var ponds:=water()
 var town: Dictionary={}
 for b in data.features.buildings:
  if cancelled:return
  if inner_building(b) or absf(b[0])>data.half-30 or absf(b[1])>data.half-30:continue
  var key:=Vector2i(floori(b[0]/600.0),floori(b[1]/600.0))
  if not town.has(key):town[key]=[PackedVector3Array(),PackedVector3Array(),PackedColorArray(),PackedInt32Array()]
  house(town[key],house_shape(b))
 if not cancelled:call_deferred("attach_detail",ribbons,ponds,town)

func attach_detail(ribbons: Dictionary, ponds: Array, town: Dictionary) -> void:
 if task>=0:
  WorkerThreadPool.wait_for_task_completion(task)
  task=-1
 for key in ribbons:
  var c: Array=ribbons[key]
  var instance:=MeshInstance3D.new()
  instance.name="Roads_%d_%d" % [key.x,key.y]
  instance.mesh=mesh_from(c[0],c[1],c[2],c[3],vertex_material)
  instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  instance.visibility_range_end=RIBBONS_END
  add_child(instance)
 if not ponds.is_empty() and not ponds[3].is_empty():
  var material:=vertex_material.duplicate() as StandardMaterial3D
  material.roughness=0.15
  material.metallic=0.3
  material.cull_mode=BaseMaterial3D.CULL_DISABLED
  var instance:=MeshInstance3D.new()
  instance.name="Water"
  instance.mesh=mesh_from(ponds[0],ponds[1],ponds[2],ponds[3],material)
  instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(instance)
 for key in town:
  var c: Array=town[key]
  var instance:=MeshInstance3D.new()
  instance.name="Town_%d_%d" % [key.x,key.y]
  instance.mesh=mesh_from(c[0],c[1],c[2],c[3],vertex_material)
  add_child(instance)
 detail_ready=true

static func mesh_from(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, material: Material) -> ArrayMesh:
 var arrays: Array=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_COLOR]=colors
 arrays[Mesh.ARRAY_INDEX]=indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh.surface_set_material(0,material)
 return mesh

# A strip laid on the relief with stations every 6 m or less, mitred so
# bends leave no gaps; `offsets` across it, one colour per offset.
func ribbon(chunks: Dictionary, line: PackedVector2Array, offsets: Array, colors: Array, lift: float) -> void:
 var points:=PackedVector2Array()
 for i in range(line.size()-1):
  var steps:=maxi(1,ceili(line[i].distance_to(line[i+1])/6.0))
  for k in range(steps):points.append(line[i].lerp(line[i+1],float(k)/steps))
 if line.size()>0:points.append(line[line.size()-1])
 if points.size()<2:return
 var sides:=PackedVector2Array()
 for i in range(points.size()):
  var before:=(points[i]-points[maxi(0,i-1)]).normalized()
  var after:=(points[mini(points.size()-1,i+1)]-points[i]).normalized()
  if before==Vector2.ZERO:before=after
  if after==Vector2.ZERO:after=before
  var tangent:=(before+after).normalized()
  if tangent==Vector2.ZERO:tangent=after
  var side:=Vector2(-tangent.y,tangent.x)
  sides.append(side/clampf(side.dot(Vector2(-after.y,after.x)),0.5,1.0))
 var count:=offsets.size()
 for i in range(points.size()-1):
  var mid:=(points[i]+points[i+1])*0.5
  if absf(mid.x)<INNER and absf(mid.y)<INNER:continue
  if absf(mid.x)>data.half-25 or absf(mid.y)>data.half-25:continue
  var key:=Vector2i(floori(mid.x/CHUNK),floori(mid.y/CHUNK))
  if not chunks.has(key):chunks[key]=[PackedVector3Array(),PackedVector3Array(),PackedColorArray(),PackedInt32Array()]
  var c: Array=chunks[key]
  var base:int=c[0].size()
  for station: int in [i,i+1]:
   var p:=points[station];var side:=sides[station]
   for k in range(count):
    var q:=p+side*float(offsets[k])
    c[0].append(Vector3(q.x,data.height(q.x,q.y)+lift,q.y))
    c[1].append(data.normal_at(q.x,q.y))
    c[2].append(colors[k])
  for k in range(count-1):
   var a:=base+k;var b:=base+count+k
   c[3].append_array([a,b,a+1,a+1,b,b+1])

func water() -> Array:
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
 for flat in data.features.water:
  var poly:=AvdiivkaData.pairs(flat)
  if poly.size()>3 and poly[0].distance_to(poly[poly.size()-1])<0.01:poly.remove_at(poly.size()-1)
  if poly.size()<3:continue
  var inside:=true
  for p in poly:
   if absf(p.x)>INNER or absf(p.y)>INNER:inside=false
  if inside:continue
  var level:=INF
  for p in poly:level=minf(level,data.height(p.x,p.y))
  var triangles:=Geometry2D.triangulate_polygon(poly)
  if triangles.is_empty():continue
  var base:=vertices.size()
  for p in poly:
   vertices.append(Vector3(p.x,level+0.25,p.y));normals.append(Vector3.UP);colors.append(Color("4f6467"))
  for index in triangles:indices.append(base+index)
 return [vertices,normals,colors,indices]

# A quad a-b-d-e drawn to be seen from the side `facing` points to (Godot
# front faces wind clockwise); without `facing`, from where a-b-d-e runs
# clockwise.
static func quad(c: Array, a: Vector3, b: Vector3, d: Vector3, e: Vector3, color: Color, facing: Vector3=Vector3.ZERO) -> void:
 var normal:=-(d-a).cross(e-b).normalized()
 if facing!=Vector3.ZERO and normal.dot(facing)<0:
  var swap:=b;b=e;e=swap;normal=-normal
 var base:int=c[0].size()
 for p in [a,b,d,e]:
  c[0].append(p);c[1].append(normal);c[2].append(color)
 c[3].append_array([base,base+1,base+2,base,base+2,base+3])

static func triangle(c: Array, a: Vector3, b: Vector3, d: Vector3, color: Color) -> void:
 var normal:=-(b-a).cross(d-a).normalized()
 var base:int=c[0].size()
 for p in [a,b,d]:
  c[0].append(p);c[1].append(normal);c[2].append(color)
 c[3].append_array([base,base+1,base+2])

# Walls with rows of windows, then a gable roof, a flat roof, the attic floor
# of a house that lost its roof, or the burnt floor of a ruin.
func house(c: Array, s: Dictionary) -> void:
 var rng: RandomNumberGenerator=s.rng
 var basis: Basis=s.basis;var w:float=s.w;var d:float=s.d;var code:String=s.code
 var low:float=s.low;var high:float=s.high;var top:float=s.top;var storey:float=s.storey
 var ruined:bool=s.ruined;var roofless:bool=s.roofless
 var palette:Array=WALLS.get(code,WALLS["H"])
 var wall:=Color(palette[rng.randi()%palette.size()])
 if roofless and rng.randf()<0.5:wall=wall.darkened(0.3)
 var origin:=Vector3(s.x,0,s.z)
 var corners: Array[Vector3]=[]
 for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:corners.append(origin+basis*Vector3(corner.x*w*0.5,0,corner.y*d*0.5))
 for k in range(4):
  var a:Vector3=corners[k];var e:Vector3=corners[(k+1)%4]
  var outward:=(a+e)*0.5-origin;outward.y=0
  quad(c,Vector3(a.x,low,a.z),Vector3(e.x,low,e.z),Vector3(e.x,top,e.z),Vector3(a.x,top,a.z),wall.darkened(0.04*k),outward)
  if ruined:continue
  var out:=outward.normalized()*0.04
  var along:=e-a;var length:=along.length()
  if length<2.5:continue
  var glass:=Color("26292a") if roofless else Color("343c3e")
  for level in range(int(s.levels)):
   var sill:=high+0.4+storey*level+0.9
   if code=="A" or code=="P":
    quad(c,a+along*0.06+out+Vector3.UP*sill,e-along*0.06+out+Vector3.UP*sill,e-along*0.06+out+Vector3.UP*(sill+1.3),a+along*0.06+out+Vector3.UP*(sill+1.3),glass,out)
   elif code=="H":
    var count:=maxi(1,int(length/3.5))
    for k2 in range(count):
     var mid:=a+along*((k2+0.5)/count)
     var half_w:=along.normalized()*0.55
     quad(c,mid-half_w+out+Vector3.UP*sill,mid+half_w+out+Vector3.UP*sill,mid+half_w+out+Vector3.UP*(sill+1.2),mid-half_w+out+Vector3.UP*(sill+1.2),glass,out)
 if ruined:
  quad(c,Vector3(corners[0].x,top-0.3,corners[0].z),Vector3(corners[1].x,top-0.3,corners[1].z),Vector3(corners[2].x,top-0.3,corners[2].z),Vector3(corners[3].x,top-0.3,corners[3].z),Color("4a453d"),Vector3.UP)
  return
 var roof:=Color(ROOFS[rng.randi()%ROOFS.size()])
 if not s.gable:
  quad(c,Vector3(corners[0].x,top,corners[0].z),Vector3(corners[1].x,top,corners[1].z),Vector3(corners[2].x,top,corners[2].z),Vector3(corners[3].x,top,corners[3].z),Color("5e5a52") if roofless else roof.darkened(0.1),Vector3.UP)
  return
 # Gable roof along the long side with a 0.35 m overhang.
 var long_x:=w>=d
 var span:=d if long_x else w
 var rise:float=s.rise
 var hl:=(w if long_x else d)*0.5+0.35;var hs:=span*0.5+0.35
 var ax:=basis.x if long_x else basis.z
 var az:=basis.z if long_x else basis.x
 var ridge_a:=origin+Vector3.UP*(top+rise)-ax*hl;var ridge_b:=origin+Vector3.UP*(top+rise)+ax*hl
 var drop:=0.35*rise/(span*0.5)
 for side: float in [-1.0,1.0]:
  var eave_a:=origin+Vector3.UP*(top-drop)-ax*hl+az*hs*side;var eave_b:=origin+Vector3.UP*(top-drop)+ax*hl+az*hs*side
  var up:=(az*side+Vector3.UP).normalized()
  quad(c,eave_a,eave_b,ridge_b,ridge_a,roof.darkened(0.08 if side>0 else 0.0),up)
  quad(c,eave_a,eave_b,ridge_b,ridge_a,roof.darkened(0.3),-up)
  var gable_base:=origin+Vector3.UP*top+ax*(hl-0.35)*side
  triangle(c,gable_base-az*span*0.5,gable_base+az*span*0.5,gable_base+Vector3.UP*rise,wall)
  triangle(c,gable_base+az*span*0.5,gable_base-az*span*0.5,gable_base+Vector3.UP*rise,wall)

func load_trees() -> void:
 var bytes:=FileAccess.get_file_as_bytes(AvdiivkaData.ROOT+"trees.bin")
 var count:=bytes.size()/6
 tree_x.resize(count);tree_z.resize(count);tree_h.resize(count);tree_kind.resize(count)
 for i in range(count):
  var x:=bytes.decode_s16(i*6)*0.25;var z:=bytes.decode_s16(i*6+2)*0.25
  tree_x[i]=x;tree_z[i]=z;tree_kind[i]=bytes[i*6+4];tree_h[i]=bytes[i*6+5]*0.1
  var key:=Vector2i(floori(x/TREE_CHUNK),floori(z/TREE_CHUNK))
  if not tree_chunks.has(key):tree_chunks[key]=PackedInt32Array()
  tree_chunks[key].append(i)
 tree_mesh=make_tree_mesh()

# One low-poly tree, 1 m tall: trunk and an irregular crown, vertex coloured.
func make_tree_mesh() -> ArrayMesh:
 var material:=vertex_material.duplicate() as StandardMaterial3D
 material.roughness=1.0
 var c: Array=[PackedVector3Array(),PackedVector3Array(),PackedColorArray(),PackedInt32Array()]
 var bark:=Color("5a5144")
 for k in range(5):
  var a0:=TAU*k/5;var a1:=TAU*(k+1)/5
  quad(c,Vector3(cos(a0)*0.025,0,sin(a0)*0.025),Vector3(cos(a1)*0.025,0,sin(a1)*0.025),Vector3(cos(a1)*0.016,0.5,sin(a1)*0.016),Vector3(cos(a0)*0.016,0.5,sin(a0)*0.016),bark,Vector3(cos((a0+a1)*0.5),0,sin((a0+a1)*0.5)))
 var noise:=RandomNumberGenerator.new();noise.seed=7
 var rings:=4;var sides:=7
 var points: Array=[]
 for r in range(rings+1):
  var row: Array=[]
  var phi:=PI*r/rings
  for k in range(sides):
   var theta:=TAU*k/sides+(0.4 if r%2==1 else 0.0)
   var bump:=1.0 if r==0 or r==rings else noise.randf_range(0.82,1.15)
   row.append(Vector3(sin(phi)*cos(theta)*0.27*bump,0.66+cos(phi)*0.34*bump,sin(phi)*sin(theta)*0.27*bump))
  points.append(row)
 for r in range(rings):
  for k in range(sides):
   var shade:=Color("6f7f4c").lerp(Color("3f4c2d"),float(r)/rings)
   var centre:Vector3=(points[r][k]+points[r][(k+1)%sides]+points[r+1][(k+1)%sides]+points[r+1][k])*0.25
   quad(c,points[r][k],points[r][(k+1)%sides],points[r+1][(k+1)%sides],points[r+1][k],shade,centre-Vector3(0,0.66,0))
 # Crown normals from its centre, so it shades like a mass of foliage.
 var normals: PackedVector3Array=c[1]
 var vertices: PackedVector3Array=c[0]
 for i in range(20,vertices.size()):normals[i]=(vertices[i]-Vector3(0,0.66,0)).normalized()
 return mesh_from(vertices,normals,c[2],c[3],material)

func build_tree_chunk(key: Vector2i) -> void:
 tree_built[key]=true
 var indices:PackedInt32Array=tree_chunks.get(key,PackedInt32Array())
 if indices.is_empty():return
 var multi:=MultiMesh.new()
 multi.transform_format=MultiMesh.TRANSFORM_3D
 multi.use_colors=true
 multi.mesh=tree_mesh
 multi.instance_count=indices.size()
 var r:=RandomNumberGenerator.new();r.seed=hash(key)
 for n in range(indices.size()):
  var i:=indices[n]
  var h:=tree_h[i]
  var spread:=h*(1.35 if tree_kind[i]==2 else r.randf_range(0.8,1.1))
  var basis:=Basis(Vector3.UP,r.randf()*TAU).scaled(Vector3(spread,h,spread))
  multi.set_instance_transform(n,Transform3D(basis,Vector3(tree_x[i],data.height(tree_x[i],tree_z[i])-0.25,tree_z[i])))
  var tint:=Color(1,1,1).lerp(Color(0.86,0.9,0.72),r.randf())
  if tree_kind[i]==2:tint=tint.lerp(Color(1.05,1.02,0.86),0.4)
  multi.set_instance_color(n,tint)
 var instance:=MultiMeshInstance3D.new()
 instance.name="Trees_%d_%d" % [key.x,key.y]
 instance.multimesh=multi
 instance.visibility_range_end=TREES_END
 instance.visibility_range_end_margin=40
 add_child(instance)

# Edge of the operation area: only vehicles and people are held in.
func limits() -> void:
 var edge:=data.half-40
 for side in [-1,1]:
  for size_pos in [[Vector3(1,600,edge*2),Vector3(side*edge,0,0)],[Vector3(edge*2,600,1),Vector3(0,0,side*edge)]]:
   var body:=StaticBody3D.new()
   body.collision_layer=BOUNDARY_LAYER
   body.collision_mask=0
   body.set_meta("boundary",true)
   var collision:=CollisionShape3D.new()
   var shape:=BoxShape3D.new();shape.size=size_pos[0]
   collision.shape=shape
   body.position=size_pos[1]
   body.add_child(collision)
   add_child(body)

func _process(delta: float) -> void:
 stream_timer-=delta
 if stream_timer>0:return
 stream_timer=0.2
 var camera:=get_viewport().get_camera_3d()
 if camera==null:return
 stream(camera.global_position,3)

# Builds the tree chunks around a point, nearest first, a few per call.
func stream(at: Vector3, budget: int) -> void:
 var reach:=ceili((TREES_END+TREE_CHUNK)/TREE_CHUNK)
 var center:=Vector2i(floori(at.x/TREE_CHUNK),floori(at.z/TREE_CHUNK))
 var candidates: Array=[]
 for dz in range(-reach,reach+1):
  for dx in range(-reach,reach+1):
   var key:=center+Vector2i(dx,dz)
   if tree_built.has(key) or not tree_chunks.has(key):continue
   var middle:=(Vector2(key)+Vector2(0.5,0.5))*TREE_CHUNK
   var distance:=middle.distance_to(Vector2(at.x,at.z))
   if distance<TREES_END+TREE_CHUNK:candidates.append([distance,key])
 candidates.sort_custom(func(a,b):return a[0]<b[0])
 for k in range(mini(budget,candidates.size())):build_tree_chunk(candidates[k][1])

# Trunk colliders near a vehicle, rebuilt as it moves on.
func collide_trees(at: Vector3) -> void:
 var here:=Vector2(at.x,at.z)
 if here.distance_to(trunk_center)<40:return
 trunk_center=here
 if trunks!=null:trunks.queue_free()
 trunks=StaticBody3D.new()
 trunks.name="Trunks"
 trunks.set_meta("ballistic_material","wood")
 add_child(trunks)
 var shape:=CylinderShape3D.new();shape.radius=0.22;shape.height=4.0
 var center:=Vector2i(floori(at.x/TREE_CHUNK),floori(at.z/TREE_CHUNK))
 for dz in range(-1,2):
  for dx in range(-1,2):
   for i in tree_chunks.get(center+Vector2i(dx,dz),PackedInt32Array()):
    if Vector2(tree_x[i],tree_z[i]).distance_to(here)>110:continue
    var owner_id:=trunks.create_shape_owner(trunks)
    trunks.shape_owner_add_shape(owner_id,shape)
    trunks.shape_owner_set_transform(owner_id,Transform3D(Basis.IDENTITY,Vector3(tree_x[i],data.height(tree_x[i],tree_z[i])+1.8,tree_z[i])))
