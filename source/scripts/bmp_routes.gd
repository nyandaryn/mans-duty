class_name BmpRoutes
extends RefCounted

# The approach of the mechanized column, on the real roads of the operation
# area. The vehicles wait 1.9 km south of the village under the tree belt
# along a field road west of the highway, nose to the east, on the verge
# below the trees. On the order they go out one by one along the field road
# to the highway, up it to the north and leave it before the village: across
# the field into the corridor between the tree belt along the highway and
# the wood south of the village, along the edge of the wood, to its northern
# tip at the village edge. About three minutes of driving.
const ROAD := [Vector2(-148.0,1903.0),Vector2(-79.0,1891.0),Vector2(-4.0,1880.0),Vector2(168.9,1865.0),Vector2(68.3,1555.6),Vector2(-1.4,1347.8),Vector2(-36.6,1230.0),Vector2(-76.1,1120.2),Vector2(-132.7,955.2),Vector2(-311.0,418.4)]
const CORRIDOR := [Vector2(-262.0,402.0),Vector2(-150.0,345.0),Vector2(-108.0,300.0),Vector2(-135.0,255.0),Vector2(-165.0,215.0),Vector2(-188.0,175.0),Vector2(-211.0,135.0),Vector2(-222.0,100.0),Vector2(-205.0,74.0)]
# The field road on along the belt, for the parking places of the column.
const PARK_ROAD := Vector2(-664.0,1956.0)
const PARK_SPACING := 20.0
const PARK_VERGE := 6.0
# Column march: 25–50 m between vehicles; a highway pace and a field pace.
const COLUMN_GAP := 35.0
const ROAD_SPEED := 12.5
const FIELD_SPEED := 6.0
# Half the hull width with a margin, in navigation cells around obstacles.
const CLEARANCE := 2
# Further out the cells are still dear: the hull turning sweeps its corners
# (half its length), so the routes keep to the middle of a street.
const MARGIN := 4
const MARGIN_COST := 4.0

static func flat(p: Vector2, district: Node3D) -> Vector3:
 return Vector3(p.x,district.ground_height(Vector3(p.x,0,p.y)),p.y)

# Where the vehicle of a column place stands under the trees, and its yaw.
static func parking(index: int, district: Node3D) -> Transform3D:
 var head: Vector2=ROAD[0]
 var back:=(PARK_ROAD-head).normalized()
 # Under the trees: the belt is on the north side of the field road.
 var verge:=Vector2(back.y,-back.x)
 if verge.y>0:verge=-verge
 var p:=head+back*(12.0+index*PARK_SPACING)+verge*PARK_VERGE
 var at:=flat(p,district)
 var forward:=Vector3(-back.x,0,-back.y)
 return Transform3D(Basis.looking_at(forward,Vector3.UP),at)

# The whole approach from a column place to the village edge, as 3D points.
static func approach(index: int, district: Node3D) -> PackedVector3Array:
 var points:=PackedVector3Array()
 points.append(parking(index,district).origin)
 for p in ROAD:points.append(flat(p,district))
 for p in CORRIDOR:points.append(flat(p,district))
 return points

# Length of the road part of an approach (the highway pace applies there).
static func road_length() -> float:
 var total:=0.0
 for i in range(1,ROAD.size()):total+=(ROAD[i]-ROAD[i-1]).length()
 return total

# --- Inside the village ----------------------------------------------------
# A grid for a vehicle: the soldiers' navigation grid with every obstacle
# grown by the half width of the hull.
static func vehicle_grid(district: Node3D) -> AStarGrid2D:
 var source: AStarGrid2D=district.grid
 var region:=source.region
 var w:=region.size.x;var h:=region.size.y
 var solid:=PackedByteArray();solid.resize(w*h)
 for z in range(h):
  for x in range(w):
   solid[z*w+x]=1 if source.is_point_solid(Vector2i(region.position.x+x,region.position.y+z)) else 0
 var blocked:=dilate(solid,w,h,CLEARANCE)
 var near:=dilate(solid,w,h,MARGIN)
 var grid:=AStarGrid2D.new()
 grid.region=region
 grid.cell_size=source.cell_size
 grid.offset=source.offset
 grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 grid.update()
 for z in range(h):
  for x in range(w):
   var cell:=Vector2i(region.position.x+x,region.position.y+z)
   if blocked[z*w+x]==1:grid.set_point_solid(cell,true)
   else:grid.set_point_weight_scale(cell,source.get_point_weight_scale(cell)*(MARGIN_COST if near[z*w+x]==1 else 1.0))
 return grid

# Square dilation of a mask, separable: rows, then columns.
static func dilate(mask: PackedByteArray, w: int, h: int, reach: int) -> PackedByteArray:
 var rows:=PackedByteArray();rows.resize(w*h)
 for z in range(h):
  var base:=z*w
  for x in range(w):
   for d in range(-reach,reach+1):
    var xx:=x+d
    if xx>=0 and xx<w and mask[base+xx]==1:rows[base+x]=1;break
 var out:=PackedByteArray();out.resize(w*h)
 for z in range(h):
  for x in range(w):
   for d in range(-reach,reach+1):
    var zz:=z+d
    if zz>=0 and zz<h and rows[zz*w+x]==1:out[z*w+x]=1;break
 return out

# Length of a route over the ground.
static func length_of(route: PackedVector3Array) -> float:
 var total:=0.0
 for i in range(1,route.size()):total+=Vector2(route[i].x-route[i-1].x,route[i].z-route[i-1].z).length()
 return total

static func free_cell(grid: AStarGrid2D, cell: Vector2i, reach: int=12) -> Vector2i:
 if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):return cell
 for r in range(1,reach+1):
  for dz in range(-r,r+1):
   for dx in range(-r,r+1):
    if maxi(absi(dx),absi(dz))!=r:continue
    var c:=cell+Vector2i(dx,dz)
    if grid.is_in_boundsv(c) and not grid.is_point_solid(c):return c
 return Vector2i(999999,999999)

static func cell_of(district: Node3D, point: Vector3) -> Vector2i:
 return district.navigation_cell(point)

static func line_free(grid: AStarGrid2D, a: Vector2i, b: Vector2i) -> bool:
 var steps:=maxi(absi(b.x-a.x),absi(b.y-a.y))
 for i in range(1,steps):
  var t:=float(i)/steps
  var c:=Vector2i(roundi(lerpf(a.x,b.x,t)),roundi(lerpf(a.y,b.y,t)))
  if grid.is_point_solid(c):return false
 return true

# A driveable path between two points of the village, straightened.
static func path(district: Node3D, grid: AStarGrid2D, from: Vector3, to: Vector3) -> PackedVector3Array:
 var result:=PackedVector3Array()
 var a:=free_cell(grid,cell_of(district,from))
 var b:=free_cell(grid,cell_of(district,to))
 if a.x==999999 or b.x==999999:return result
 var cells:=grid.get_id_path(a,b)
 if cells.is_empty():return result
 var keep: Array[Vector2i]=[cells[0]]
 var i:=0
 while i<cells.size()-1:
  var j:=cells.size()-1
  while j>i+1 and not line_free(grid,cells[i],cells[j]):j-=1
  keep.append(cells[j])
  i=j
 for c in keep:result.append(district.navigation_position(c))
 return result

static func reachable(grid: AStarGrid2D, district: Node3D, point: Vector3) -> bool:
 var c:=cell_of(district,point)
 return grid.is_in_boundsv(c) and not grid.is_point_solid(c)

static func sight_blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
 var query:=PhysicsRayQueryParameters3D.create(from,to,1,exclude)
 return not space.intersect_ray(query).is_empty()

# Room for the hull to turn: free cells two out in every direction of the
# vehicle's grid (where the walls are already grown by half the hull).
static func roomy(grid: AStarGrid2D, district: Node3D, point: Vector3) -> bool:
 var c:=cell_of(district,point)
 if not grid.is_in_boundsv(c) or grid.is_point_solid(c):return false
 for d in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2),Vector2i(2,2),Vector2i(-2,2),Vector2i(2,-2),Vector2i(-2,-2)]:
  var n:Vector2i=c+d
  if not grid.is_in_boundsv(n) or grid.is_point_solid(n):return false
 return true

static func by_cost(found: Array, limit: int) -> Array:
 found.sort_custom(func(a,b):return a[0]<b[0])
 var points:=[]
 for item in found.slice(0,limit):points.append(item[1])
 return points

# Last cover before an objective: places the vehicle can reach and turn in,
# between `near` and `far` metres from the objective, that the objective
# cannot see (houses, the wood between), nearest first to where the vehicle
# is coming from.
static func dismount_points(district: Node3D, grid: AStarGrid2D, space: PhysicsDirectSpaceState3D, objective: Vector3, from: Vector3, exclude: Array[RID], near: float=95.0, far: float=170.0, avoid: Array=[], apart: float=0.0, limit: int=6) -> Array:
 var found:=[]
 var eye:=objective+Vector3.UP*2.2
 var r:=near
 while r<=far:
  for k in range(28):
   var angle:=TAU*k/28.0
   var p:=objective+Vector3(cos(angle),0,sin(angle))*r
   if absf(p.x)>190 or absf(p.z)>190:continue
   if not roomy(grid,district,p):continue
   p.y=district.ground_height(p)
   var crowded:=false
   for q in avoid:
    if Vector3(q).distance_to(p)<apart:crowded=true;break
   if crowded:continue
   if not sight_blocked(space,eye,p+Vector3.UP*1.9,exclude):continue
   found.append([p.distance_to(from),p])
  r+=15.0
 return by_cost(found,limit)

# Fire positions for support: the turret sees the objective, the hull is
# screened if possible; behind the infantry, toward where they came from.
static func overwatch_points(district: Node3D, grid: AStarGrid2D, space: PhysicsDirectSpaceState3D, objective: Vector3, rear: Vector3, exclude: Array[RID], near: float=75.0, far: float=135.0, limit: int=6) -> Array:
 var found:=[]
 var eye:=objective+Vector3.UP*1.6
 var back:=Vector3(rear.x-objective.x,0,rear.z-objective.z).normalized()
 var r:=near
 while r<=far:
  for k in range(-6,7):
   var angle:=k*0.17
   var p:=objective+back.rotated(Vector3.UP,angle)*r
   if absf(p.x)>190 or absf(p.z)>190:continue
   if not roomy(grid,district,p):continue
   p.y=district.ground_height(p)
   if sight_blocked(space,p+Vector3.UP*2.4,eye,exclude):continue
   var cost:=absf(angle)*30.0+absf(r-100.0)*0.5
   if not sight_blocked(space,p+Vector3.UP*0.9,eye,exclude):cost+=40.0
   found.append([cost,p])
  r+=12.0
 return by_cost(found,limit)
