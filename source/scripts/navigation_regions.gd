class_name NavigationRegions
extends RefCounted

# Four-way connectivity matches reachability of the grid's diagonal mode:
# a diagonal is legal only when both adjoining orthogonal cells are open.
# Destruction opens cells; union-find updates those connections without a
# flood fill of the whole map, and rejects impossible A* searches immediately.
var region := Rect2i()
var parents := PackedInt32Array()

func build(grid: AStarGrid2D) -> void:
 region=grid.region
 parents.resize(region.size.x*region.size.y)
 parents.fill(-1)
 for y in range(region.size.y):
  for x in range(region.size.x):
   var index := y*region.size.x+x
   if grid.is_point_solid(region.position+Vector2i(x,y)):continue
   parents[index]=index
   if x>0:join(index,index-1)
   if y>0:join(index,index-region.size.x)

func root_of(index: int) -> int:
 if index<0 or index>=parents.size() or parents[index]<0:return -1
 while parents[index]!=index:
  parents[index]=parents[parents[index]]
  index=parents[index]
 return index

func join(a: int, b: int) -> void:
 var ra := root_of(a)
 var rb := root_of(b)
 if ra>=0 and rb>=0 and ra!=rb:parents[maxi(ra,rb)]=mini(ra,rb)

func index_of(cell: Vector2i) -> int:
 return (cell.y-region.position.y)*region.size.x+cell.x-region.position.x

func connected(a: Vector2i, b: Vector2i) -> bool:
 if not region.has_point(a) or not region.has_point(b):return false
 var root_a := root_of(index_of(a))
 return root_a>=0 and root_a==root_of(index_of(b))

func open_cell(cell: Vector2i) -> void:
 var index := index_of(cell)
 if parents[index]>=0:return
 parents[index]=index
 for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
  if region.has_point(cell+step):join(index,index_of(cell+step))
