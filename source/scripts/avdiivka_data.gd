class_name AvdiivkaData
extends RefCounted

# Real map data of Avdiivka built by tools/build_avdiivka.py from
# OpenStreetMap (ODbL) and SRTM-derived relief. Game metres: x — easting,
# −z — grid north of the Gauss–Krüger zone 7, as on SK-42 sheets.
const ROOT := "res://assets/maps/avdiivka/"
const BATTLE := 200
static var cache: AvdiivkaData
var meta: Dictionary
var features: Dictionary
var relief := PackedFloat32Array()
var size := 601
var step := 20.0
var half := 6000.0
var cover := PackedByteArray()
var forest := PackedByteArray()
var battle := PackedByteArray()
var base_altitude := 0.0
var easting := 0.0
var northing := 0.0
var minimum := INF
var maximum := -INF
var relief_bytes := PackedByteArray()
var battle_relief := PackedFloat32Array()

static func shared() -> AvdiivkaData:
 if cache==null:
  cache=AvdiivkaData.new()
  cache.load_all()
 return cache

func load_all() -> void:
 meta=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"meta.json"))
 features=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"features.json"))
 relief_bytes=FileAccess.get_file_as_bytes(ROOT+"relief.bin")
 relief=relief_bytes.to_float32_array()
 battle_relief=FileAccess.get_file_as_bytes(ROOT+"battle_relief.bin").to_float32_array()
 cover=FileAccess.get_file_as_bytes(ROOT+"cover.bin")
 forest=FileAccess.get_file_as_bytes(ROOT+"forest.bin")
 battle=FileAccess.get_file_as_bytes(ROOT+"battle.bin")
 size=int(meta.relief.size);step=float(meta.relief.step);half=float(meta.relief.half)
 base_altitude=float(meta.base_altitude)
 easting=float(meta.origin.easting);northing=float(meta.origin.northing)
 var sorted_relief:=relief.duplicate();sorted_relief.sort()
 minimum=sorted_relief[0];maximum=sorted_relief[sorted_relief.size()-1]

func node_normal(i: int, j: int) -> Vector3:
 return Vector3(node(i-1,j)-node(i+1,j),2*step,node(i,j-1)-node(i,j+1)).normalized()

func normal_at(x: float, z: float) -> Vector3:
 return node_normal(roundi((x+half)/step),roundi((z+half)/step))

# Bilinear land cover between the nodes, for blending at the battlefield edge.
func cover_at(x: float, z: float) -> Color:
 var gx := (x+half)/step;var gz := (z+half)/step
 var i := floori(gx);var j := floori(gz)
 var u := gx-i;var v := gz-j
 return cover_color(i,j).lerp(cover_color(i+1,j),u).lerp(cover_color(i,j+1).lerp(cover_color(i+1,j+1),u),v)

func node(i: int, j: int) -> float:
 return relief[clampi(j,0,size-1)*size+clampi(i,0,size-1)]

# Same split of each grid square as the rendered outer terrain and the
# collision heightmap, so a point on the drawn ground has this height.
func height(x: float, z: float) -> float:
 var gx := clampf((x+half)/step,0,size-1.0001)
 var gz := clampf((z+half)/step,0,size-1.0001)
 var i := floori(gx);var j := floori(gz)
 var u := gx-i;var v := gz-j
 var a := relief[j*size+i];var b := relief[j*size+i+1]
 var c := relief[(j+1)*size+i];var d := relief[(j+1)*size+i+1]
 return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)

# Battlefield relief at 1 m (precomputed Catmull–Rom, edge on the outer
# ground's triangles), bilinear between the metre nodes.
func battle_height(x: float, z: float) -> float:
 var n := BATTLE*2+1
 var gx := clampf(x+BATTLE,0,n-1.0001);var gz := clampf(z+BATTLE,0,n-1.0001)
 var i := floori(gx);var j := floori(gz)
 var u := gx-i;var v := gz-j
 var a := battle_relief[j*n+i];var b := battle_relief[j*n+i+1]
 var c := battle_relief[(j+1)*n+i];var d := battle_relief[(j+1)*n+i+1]
 return lerpf(lerpf(a,b,u),lerpf(c,d,u),v)

# Smooth (Catmull–Rom) relief for the 1 m battlefield mesh: no 20 m facets.
func smooth_height(x: float, z: float) -> float:
 var gx := (x+half)/step;var gz := (z+half)/step
 var i := floori(gx);var j := floori(gz)
 var u := gx-i;var v := gz-j
 var rows: Array[float]=[]
 for dj in range(-1,3):
  rows.append(cubic(node(i-1,j+dj),node(i,j+dj),node(i+1,j+dj),node(i+2,j+dj),u))
 return cubic(rows[0],rows[1],rows[2],rows[3],v)

static func cubic(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
 return p1+0.5*t*(p2-p0+t*(2.0*p0-5.0*p1+4.0*p2-p3+t*(3.0*(p1-p2)+p3-p0)))

func cover_color(i: int, j: int) -> Color:
 var index := (clampi(j,0,size-1)*size+clampi(i,0,size-1))*3
 return Color8(cover[index],cover[index+1],cover[index+2])

func forested(i: int, j: int) -> bool:
 if i<0 or j<0 or i>=size or j>=size:return false
 return forest[j*size+i]>127

func forest_at(x: float, z: float) -> bool:
 return forested(roundi((x+half)/step),roundi((z+half)/step))

func battle_color(x: float, z: float) -> Color:
 var n := BATTLE*2+1
 var i := clampi(roundi(x+BATTLE),0,n-1);var j := clampi(roundi(z+BATTLE),0,n-1)
 var index := (j*n+i)*3
 return Color8(battle[index],battle[index+1],battle[index+2])

# Rectangular coordinates as read off the sheet: X — northing, Y — easting
# with the zone number, in metres.
func grid_x(z: float) -> float:return northing-z
func grid_y(x: float) -> float:return easting+x

static func split_coordinate(value: float) -> String:
 var text := str(roundi(value))
 return text.substr(0,text.length()-5)+" "+text.substr(text.length()-5,2)+" "+text.substr(text.length()-3)

func coordinates_text(point: Vector3) -> String:
 return "X %s  Y %s" % [split_coordinate(grid_x(point.z)),split_coordinate(grid_y(point.x))]

func altitude(y: float) -> float:return y+base_altitude

static func pairs(flat: Array) -> PackedVector2Array:
 var points := PackedVector2Array()
 for i in range(0,flat.size()-1,2):points.append(Vector2(flat[i],flat[i+1]))
 return points
