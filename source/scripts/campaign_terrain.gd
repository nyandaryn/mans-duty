class_name CampaignTerrain
extends Node3D

const HALF := 200
const WIDTH := 401
var definition: Dictionary
var heights := PackedFloat32Array()
var noise := FastNoiseLite.new()
var micro := FastNoiseLite.new()
var ground_mesh: MeshInstance3D
var body: StaticBody3D
var minimum := INF
var maximum := -INF
var pads: Array[Dictionary]=[]
var firing_steps: Array[Vector2]=[]
# Real relief (Avdiivka): the battlefield follows the surveyed ground.
var data: AvdiivkaData

func configure(mission: Dictionary) -> void:
 definition=mission
 data=AvdiivkaData.shared() if mission.get("terrain","")=="avdiivka" else null
 noise.seed=int(mission.seed)
 noise.frequency=0.009
 noise.fractal_octaves=3
 micro.seed=int(mission.seed)+97
 micro.frequency=0.065
 micro.fractal_octaves=2
 pads.clear()
 firing_steps.clear()
 for trench in mission.trenches:
  for i in range(trench.size()-1):
   var a: Vector2=trench[i]
   var b: Vector2=trench[i+1]
   var steps := maxi(1,int(a.distance_to(b)/7))
   for step in range(1,steps):firing_steps.append(a.lerp(b,float(step)/steps))
 for building in mission.buildings:
  var center: Vector2=building.point
  pads.append({"center":center,"half":Vector2(building.size)*0.75+Vector2.ONE*3,"height":base_height(center)})
 pads.append({"center":Vector2(mission.spawn),"half":Vector2(10,10),"height":base_height(mission.spawn)})
 heights.resize(WIDTH*WIDTH)
 minimum=INF
 maximum=-INF
 for z in range(WIDTH):
  for x in range(WIDTH):
   var height := sculpt(Vector2(x-HALF,z-HALF))
   heights[z*WIDTH+x]=height
   minimum=minf(minimum,height)
   maximum=maxf(maximum,height)

func base_height(point: Vector2) -> float:
 if data!=null:
  # Inside: smooth relief and ground micro-relief. At the edge exactly the
  # outer terrain's height, so the two meshes meet without a step.
  var inner := smoothstep(0.0,24.0,HALF-maxf(absf(point.x),absf(point.y)))
  if inner<=0:return data.height(point.x,point.y)
  return data.battle_height(point.x,point.y)+micro.get_noise_2d(point.x*0.6,point.y*0.6)*0.18*inner
 var relief: float=definition.relief
 var rotated := point.rotated(float(definition.heading))
 var height := noise.get_noise_2d(point.x,point.y)*relief*0.65
 height+=sin(rotated.y/74.0)*relief*0.32+cos(rotated.x/95.0)*relief*0.20
 if definition.biome=="dry":height-=exp(-pow((rotated.x-15)/22.0,2))*relief*0.40
 if definition.biome=="wet":height-=exp(-pow((rotated.y-55)/40.0,2))*relief*0.28
 return height

func trench_distance(point: Vector2) -> float:
 var closest := INF
 for trench in definition.trenches:
  for i in range(trench.size()-1):
   var a: Vector2=trench[i]
   var b: Vector2=trench[i+1]
   closest=minf(closest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b)))
 return closest

func sculpt(point: Vector2) -> float:
 var value := base_height(point)
 # Rotated building footprints fit inside these generous, smoothly blended pads.
 for pad in pads:
  var relative: Vector2=(point-Vector2(pad.center)).abs()-Vector2(pad.half)
  var outside := maxf(relative.x,relative.y)
  if outside<=0:return float(pad.height)
  if outside<6:value=lerpf(float(pad.height),value,smoothstep(0,6,outside))
 var distance := trench_distance(point)
 if distance<5:
  var depth := 1.55*(1-smoothstep(1.9,3.3,distance))
  # Access ramps at the ends, with a gentle longitudinal grade for a capsule.
  var end_distance := INF
  for trench in definition.trenches:
   end_distance=minf(end_distance,point.distance_to(trench.front()))
   end_distance=minf(end_distance,point.distance_to(trench.back()))
  depth*=smoothstep(0,9,end_distance)
  var firing_distance := INF
  for step in firing_steps:firing_distance=minf(firing_distance,point.distance_to(step))
  depth*=1-0.45*(1-smoothstep(0.4,2.3,firing_distance))
  var berm := 0.32*exp(-pow((distance-3.7)/0.8,2))
  value+=berm-depth
 return value

func height_at(point: Vector2) -> float:
 # Around the battlefield: the real ground of the operation area.
 if data!=null and (absf(point.x)>HALF or absf(point.y)>HALF):return data.height(point.x,point.y)
 if heights.is_empty():return sculpt(point)
 var x := clampf(point.x+HALF,0,WIDTH-1.0001)
 var z := clampf(point.y+HALF,0,WIDTH-1.0001)
 var ix := floori(x)
 var iz := floori(z)
 var u := x-ix
 var v := z-iz
 var a := heights[iz*WIDTH+ix]
 var b := heights[iz*WIDTH+ix+1]
 var c := heights[(iz+1)*WIDTH+ix]
 var d := heights[(iz+1)*WIDTH+ix+1]
 # Same diagonal as the rendered and collidable triangles, not bilinear height.
 return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)

func surface_color(point: Vector2) -> Color:
 if data!=null:
  var ground := data.battle_color(point.x,point.y)
  var grain := clampf(micro.get_noise_2d(point.x,point.y)*1.8+0.5,0,1)
  ground=ground.lerp(ground.lightened(0.12),grain*0.6).lerp(ground.darkened(0.10),(1-grain)*0.4)
  if not definition.trenches.is_empty() and trench_distance(point)<4:ground=ground.lerp(Color("60503d"),0.8)
  return ground
 var palette := {"meadow":[Color("657249"),Color("8c8960")],"pine":[Color("555d43"),Color("87775c")],"dry":[Color("9b9168"),Color("75674c")],"wet":[Color("4b6044"),Color("655f4b")],"autumn":[Color("847747"),Color("5c6447")],"orchard":[Color("77834e"),Color("9c8d68")],"urban":[Color("8d8d7d"),Color("686f61")]}
 var colors: Array=palette[definition.biome]
 var color: Color=colors[0].lerp(colors[1],clampf(micro.get_noise_2d(point.x,point.y)*1.8+0.5,0,1))
 var road_x := sin(point.y/57+float(definition.heading))*18
 if definition.kind=="district":
  var road_distance := minf(absf(point.x-road_x),minf(absf(point.y+70),absf(point.y-30)))
  if road_distance<5.7:color=Color("93978b")
  if road_distance<3.8:color=Color("444b4b")
  if absf(point.x-road_x)<0.12 and fmod(absf(point.y),9)<4:color=Color("babca5")
 elif absf(point.x-road_x)<2.3:color=Color("796f54")
 if trench_distance(point)<4:color=color.lerp(Color("60503d"),0.8)
 return color

func build_geometry() -> void:
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 var colors := PackedColorArray()
 var indices := PackedInt32Array()
 vertices.resize(WIDTH*WIDTH)
 normals.resize(WIDTH*WIDTH)
 colors.resize(WIDTH*WIDTH)
 indices.resize((WIDTH-1)*(WIDTH-1)*6)
 var cursor := 0
 for z in range(WIDTH):
  for x in range(WIDTH):
   var point := Vector2(x-HALF,z-HALF)
   var index := z*WIDTH+x
   vertices[index]=Vector3(point.x,heights[index],point.y)
   # Neighbours straight from the grid; at the rim through height_at().
   var left := heights[index-1] if x>0 else height_at(point-Vector2.RIGHT)
   var right := heights[index+1] if x<WIDTH-1 else height_at(point+Vector2.RIGHT)
   var up := heights[index-WIDTH] if z>0 else height_at(point-Vector2.DOWN)
   var down := heights[index+WIDTH] if z<WIDTH-1 else height_at(point+Vector2.DOWN)
   normals[index]=Vector3(left-right,2,up-down).normalized()
   colors[index]=surface_color(point)
   if x<WIDTH-1 and z<WIDTH-1:
    for i in [index,index+1,index+WIDTH,index+1,index+WIDTH+1,index+WIDTH]:
     indices[cursor]=i
     cursor+=1
 var arrays: Array=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_COLOR]=colors
 arrays[Mesh.ARRAY_INDEX]=indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material := StandardMaterial3D.new()
 material.vertex_color_use_as_albedo=true
 material.vertex_color_is_srgb=true
 var grain := FastNoiseLite.new()
 grain.seed=int(definition.seed)
 grain.frequency=0.19
 var texture := NoiseTexture2D.new()
 texture.width=128
 texture.height=128
 texture.noise=grain
 texture.seamless=true
 var ramp := Gradient.new()
 ramp.set_color(0,Color(0.65,0.65,0.65))
 ramp.set_color(1,Color.WHITE)
 texture.color_ramp=ramp
 material.albedo_texture=texture
 material.uv1_triplanar=true
 material.uv1_world_triplanar=true
 material.uv1_scale=Vector3.ONE*0.35
 material.roughness=1
 mesh.surface_set_material(0,material)
 ground_mesh=MeshInstance3D.new()
 ground_mesh.name="TerrainSurface"
 ground_mesh.mesh=mesh
 add_child(ground_mesh)
 body=StaticBody3D.new()
 body.name="TerrainCollision"
 body.set_meta("ballistic_material","earth")
 body.set_meta("terrain",true)
 var collision := CollisionShape3D.new()
 collision.shape=mesh.create_trimesh_shape()
 body.add_child(collision)
 add_child(body)
