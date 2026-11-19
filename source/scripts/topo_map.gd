class_name TopoMap
extends Control

# A large-scale topographic sheet of the operation area in the manner of
# General Staff maps: contours, forest, roads, buildings, trenches and a 100 m
# grid. It never marks the player, allies, enemies or objectives: you find
# yourself by the terrain. The ruler gives distance and grid bearing.
# The great assault has a second sheet, the route: 1:25 000 from the village
# down to the tree belt where the column waits, with the commander's pencil marks
# of the assembly area and the route of the advance (N switches the sheets).
# On both sheets of the assault the enemy strongpoints are ringed in red
# pencil, as the briefing gave them, and crossed out once taken.
const HALF := 200.0
const ROUTE_HALF := 1350.0
const ROUTE_CENTER := Vector2(-60.0,850.0)
const SAMPLE := 2
const BASE_ALTITUDE := 142.0
const EASTING := 7311800.0
const NORTHING := 5497800.0
const PAPER := Color("ece6d2")
const WHITE := Color("f7f4ea")
const INK := Color("1f1e1b")
const BROWN := Color("b2692c")
const GREEN := Color("c5e0a5")
const GREEN_INK := Color("4f7d39")
const BLUE := Color("3d86c6")
const ORANGE := Color("eeb36a")
const BRICK := Color("cc7246")
const PENCIL := Color("1f3f9a")
const RED_PENCIL := Color("c0281f")
var game: Node3D
var view: Control
var built_for := 0
var title := ""
var kind := ""
var biome := ""
var interval := 1.0
var contours: Array=[]
var contour_labels: Array=[]
var spots: Array=[]
var buildings: Array[PackedVector2Array]=[]
var trees := PackedVector2Array()
var roads: Array=[]
var trenches: Array[PackedVector2Array]=[]
var marsh := PackedVector2Array()
var zoom := 1.0
var center := Vector2.ZERO
var ruler_from := Vector2.INF
var ruler_to := Vector2.INF
var measuring := false
var panning := false
var pan_moved := false
var page := "local"
# The sheet of real Avdiivka carries its true SK-42 coordinates.
var real_grid := false
var route: RouteSheet
var tab_rects: Dictionary={}

func setup(owner_game: Node3D, parent: Control) -> void:
 game=owner_game
 game.place(self,parent,0,0,1,1)
 mouse_filter=Control.MOUSE_FILTER_STOP
 gui_input.connect(sheet_input)
 view=Control.new();view.clip_contents=true;view.mouse_filter=Control.MOUSE_FILTER_STOP
 add_child(view)
 view.draw.connect(draw_view)
 view.gui_input.connect(view_input)
 resized.connect(layout)
 hide()

func toggle() -> void:
 if visible:close()
 else:open()

func open() -> bool:
 if not game.running or game.paused or game.commands_open or game.inventory_open:return false
 if game.player.field_rig.mode in ["drone","goggles"]:return false
 if built_for!=game.district.get_instance_id():build()
 # In the vehicle or out on the approach: the route sheet.
 var at: Vector3=game.player.global_position
 set_sheet("route" if has_route() and (game.player_vehicle()!=null or absf(at.x)>HALF or absf(at.z)>HALF) else "local")
 game.commands_open=true
 game.player.burst=0;game.player.firing_sequence_active=false;game.player.aim=false
 show();layout()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 return true

func close() -> void:
 if not visible:return
 hide()
 measuring=false;panning=false
 game.commands_open=false
 if game.running and not game.paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

# --- survey of the terrain --------------------------------------------------

func build() -> void:
 var district: District=game.district
 built_for=district.get_instance_id()
 contours.clear();contour_labels.clear();spots.clear();buildings.clear();roads.clear();trenches.clear()
 trees=PackedVector2Array();marsh=PackedVector2Array()
 zoom=1.0;center=Vector2.ZERO;ruler_from=Vector2.INF;ruler_to=Vector2.INF;page="local"
 var definition: Dictionary=district.campaign_definition
 title=district.map_title
 kind=str(definition.get("kind",""))
 biome=str(definition.get("biome",""))
 var heading := float(definition.get("heading",0.0))
 var real:=str(definition.get("terrain",""))=="avdiivka"
 real_grid=real
 if district.terrain!=null and not district.terrain.heights.is_empty():survey_relief(district.terrain)
 if real:
  # Every house of the sheet from OpenStreetMap, not only the enterable ones.
  for b in AvdiivkaData.shared().features.buildings:
   if absf(float(b[0]))>205 or absf(float(b[1]))>205:continue
   var outline := PackedVector2Array()
   var turn := Basis(Vector3.UP,float(b[4]))
   for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
    var p: Vector3=turn*Vector3(corner.x*float(b[2])*0.5,0,corner.y*float(b[3])*0.5)
    outline.append(Vector2(float(b[0])+p.x,float(b[1])+p.z))
   buildings.append(outline)
 for spec in ([] if real else definition.get("buildings",[])):
  var outline := PackedVector2Array()
  var basis := Basis(Vector3.UP,float(spec.yaw))
  var half_size: Vector2=Vector2(spec.size)*0.5
  for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
   var p: Vector3=basis*Vector3(corner.x*half_size.x,0,corner.y*half_size.y)
   outline.append(Vector2(spec.point)+Vector2(p.x,p.z))
  buildings.append(outline)
 for point in district.canopy_centers:trees.append(Vector2(point.x,point.z))
 for outline in district.map_marks:buildings.append(outline)
 var line := PackedVector2Array()
 for z in range(-200,201,4):line.append(Vector2(sin(z/57.0+heading)*18,z))
 if real:
  # The real streets of Avdiivka (OpenStreetMap) inside the sheet.
  for road in AvdiivkaData.shared().features.roads:
   if road[0] in OperationArea.SKIP_ROADS:continue
   var points:=AvdiivkaData.pairs(road[3])
   var inside:=false
   for p in points:
    if absf(p.x)<215 and absf(p.y)<215:inside=true;break
   if not inside:continue
   var major:bool=road[0] in ["trunk","primary","secondary","tertiary"]
   roads.append({"points":points,"width":7.6 if major else 4.6,"fill":Color("e58c58") if major else ORANGE})
 elif district.map_id==TrainingRange.ID:pass
 elif kind=="district":
  roads.append({"points":line,"width":7.6,"fill":Color("e58c58")})
  for z in [-70.0,30.0]:roads.append({"points":PackedVector2Array([Vector2(-200,z),Vector2(200,z)]),"width":7.6,"fill":Color("e58c58")})
 else:roads.append({"points":line,"width":4.6,"fill":ORANGE})
 for trench in definition.get("trenches",[]):trenches.append(PackedVector2Array(trench))
 if biome=="wet":
  for z in range(-196,197,9):
   for x in range(-196,197,9):
    var rotated := Vector2(x,z).rotated(heading)
    if exp(-pow((rotated.y-55)/40.0,2))>0.72 and not near_tree(Vector2(x,z),5):marsh.append(Vector2(x,z))

func near_tree(point: Vector2, radius: float) -> bool:
 for tree in trees:
  if tree.distance_squared_to(point)<radius*radius:return true
 return false

func survey_relief(terrain: CampaignTerrain) -> void:
 var base: float=AvdiivkaData.shared().base_altitude if real_grid else BASE_ALTITUDE
 var count := int(HALF*2/SAMPLE)+1
 var grid := PackedFloat32Array();grid.resize(count*count)
 var low := INF
 var high := -INF
 # Generalised relief: a cartographer draws the landform, not every hummock.
 # A separable box blur over about 14 m removes ground micro-relief.
 var raw := PackedFloat32Array();raw.resize(count*count)
 for j in range(count):
  for i in range(count):raw[j*count+i]=terrain.heights[(j*SAMPLE)*CampaignTerrain.WIDTH+i*SAMPLE]+base
 var blur := PackedFloat32Array();blur.resize(count*count)
 var reach := 3
 for j in range(count):
  for i in range(count):
   var total := 0.0
   for d in range(-reach,reach+1):total+=raw[j*count+clampi(i+d,0,count-1)]
   blur[j*count+i]=total/(reach*2+1)
 for j in range(count):
  for i in range(count):
   var total := 0.0
   for d in range(-reach,reach+1):total+=blur[clampi(j+d,0,count-1)*count+i]
   var value := total/(reach*2+1)
   grid[j*count+i]=value
   low=minf(low,value);high=maxf(high,value)
 interval=10.0
 for step in [0.5,1.0,2.0,2.5,5.0,10.0]:
  if (high-low)/step<=14:interval=step;break
 var levels: Array[float]=[]
 var level := ceilf(low/interval)*interval
 while level<=high:levels.append(level);level+=interval
 var segments: Array[PackedVector2Array]=[]
 for l in levels:segments.append(PackedVector2Array())
 for j in range(count-1):
  for i in range(count-1):
   var a := grid[j*count+i]
   var b := grid[j*count+i+1]
   var c := grid[(j+1)*count+i+1]
   var d := grid[(j+1)*count+i]
   var lo := minf(minf(a,b),minf(c,d))
   var hi := maxf(maxf(a,b),maxf(c,d))
   if hi-lo<0.0001:continue
   var first := maxi(0,ceili((lo-levels[0])/interval)) if not levels.is_empty() else 0
   var origin := Vector2(-HALF+i*SAMPLE,-HALF+j*SAMPLE)
   for index in range(first,levels.size()):
    var value: float=levels[index]
    if value>hi:break
    if value<lo:continue
    var points := PackedVector2Array()
    for edge in [[a,b,Vector2(0,0),Vector2(1,0)],[b,c,Vector2(1,0),Vector2(1,1)],[c,d,Vector2(1,1),Vector2(0,1)],[d,a,Vector2(0,1),Vector2(0,0)]]:
     var h1: float=edge[0]
     var h2: float=edge[1]
     if (h1<value)!=(h2<value):
      points.append(origin+Vector2(edge[2]).lerp(edge[3],(value-h1)/(h2-h1))*SAMPLE)
    if points.size()>=2:segments[index].append_array(points.slice(0,4 if points.size()>=4 else 2))
 for index in range(levels.size()):
  var main := posmod(roundi(levels[index]/interval),5)==0
  contours.append({"level":levels[index],"segments":segments[index],"index":main})
  if main:
   var placed: Array[Vector2]=[]
   for s in range(0,segments[index].size()-1,2):
    var at: Vector2=(segments[index][s]+segments[index][s+1])*0.5
    if absf(at.x)>170 or absf(at.y)>170:continue
    var free := true
    for other in placed:
     if other.distance_to(at)<140:free=false
    if free:
     placed.append(at);contour_labels.append([at,altitude_text(levels[index],0)])
    if placed.size()>=3:break
 # Spot heights on summits, as surveyed points with a dot and a value.
 var candidates: Array=[]
 for j in range(4,count-4,6):
  for i in range(4,count-4,6):
   var value := grid[j*count+i]
   var top := true
   for dj in range(-6,7,2):
    for di in range(-6,7,2):
     var nj := clampi(j+dj,0,count-1)
     var ni := clampi(i+di,0,count-1)
     if grid[nj*count+ni]>value+0.001:top=false
   if top:candidates.append([Vector2(-HALF+i*SAMPLE,-HALF+j*SAMPLE),value])
 candidates.sort_custom(func(x,y):return x[1]>y[1])
 for candidate in candidates:
  var free := true
  for other in spots:
   if Vector2(other[0]).distance_to(candidate[0])<80:free=false
  if free:spots.append(candidate)
  if spots.size()>=8:break

static func altitude_text(value: float, decimals: int=1) -> String:
 return ("%.1f" % value).replace(".",",") if decimals>0 else str(roundi(value))

# --- drawing ------------------------------------------------------------------

func frame_rect() -> Rect2:
 var sheet := sheet_rect()
 var side := sheet.size.y*0.74
 return Rect2(sheet.position+Vector2((sheet.size.x-side)*0.5,sheet.size.y*0.095),Vector2(side,side))

func sheet_rect() -> Rect2:
 var height := size.y*0.97
 var width := minf(size.x*0.98,height*0.93)
 return Rect2((size-Vector2(width,height))*0.5,Vector2(width,height))

func layout() -> void:
 if not is_instance_valid(view):return
 var frame := frame_rect()
 view.position=frame.position;view.size=frame.size
 clamp_view()
 queue_redraw();view.queue_redraw()

func scale_factor() -> float:return view.size.x/(half()*2)*zoom

func clamp_view() -> void:
 var reach := half()-half()/zoom
 center=center.clamp(origin()-Vector2(reach,reach),origin()+Vector2(reach,reach))

# --- the two sheets of the great assault -------------------------------------
func half() -> float:return ROUTE_HALF if page=="route" else HALF
func origin() -> Vector2:return ROUTE_CENTER if page=="route" else Vector2.ZERO
func has_route() -> bool:return is_instance_valid(game.district) and game.district.map_id==BattleMap.ID

func set_sheet(id: String) -> void:
 if id=="route" and not has_route():id="local"
 if id==page:return
 page=id;zoom=1.0;center=origin()
 if page=="route" and route==null:
  route=RouteSheet.new()
  route.build(AvdiivkaData.shared(),Rect2(ROUTE_CENTER-Vector2.ONE*ROUTE_HALF,Vector2.ONE*ROUTE_HALF*2))
 measuring=false;panning=false
 layout()

# Grid lines across the frame: [world coordinate, label] for x and for z.
func grid_x() -> Array:
 var lines: Array=[]
 if page=="route":
  var data:=AvdiivkaData.shared()
  var e:=ceilf((data.easting+origin().x-half())/1000.0)*1000.0
  while e<=data.easting+origin().x+half():lines.append([e-data.easting,"%02d" % (int(e/1000.0)%100)]);e+=1000.0
  return lines
 for value in range(-200,201,100):lines.append([float(value),grid_label(easting(value))])
 return lines

func grid_z() -> Array:
 var lines: Array=[]
 if page=="route":
  var data:=AvdiivkaData.shared()
  var n:=ceilf((data.northing-origin().y-half())/1000.0)*1000.0
  while n<=data.northing-origin().y+half():lines.append([data.northing-n,"%02d" % (int(n/1000.0)%100)]);n+=1000.0
  return lines
 for value in range(-200,201,100):lines.append([float(value),grid_label(northing(value))])
 return lines

func sheet_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  for id in tab_rects:
   if Rect2(tab_rects[id]).has_point(event.position):
    set_sheet(id);game.sound("click",-14);accept_event();return

func to_screen(point: Vector2) -> Vector2:return view.size*0.5+(point-center)*scale_factor()
func to_world(point: Vector2) -> Vector2:return center+(point-view.size*0.5)/scale_factor()

func easting(x: float) -> float:return (AvdiivkaData.shared().easting if real_grid else EASTING)+x
func northing(z: float) -> float:return (AvdiivkaData.shared().northing if real_grid else NORTHING)-z

static func grid_label(value: float) -> String:
 # Kilometres within the 100 km square and hundreds of metres: 12,4.
 var km := floori(value/1000.0)
 return "%02d,%d" % [km%100,roundi(fposmod(value,1000.0)/100.0)%10]

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.025,0.02,0.93))
 var sheet := sheet_rect()
 var frame := frame_rect()
 draw_rect(sheet,PAPER)
 var font := ThemeDB.fallback_font
 var line := sheet.size.y/1000.0
 # Frames: inner neat line, a ticked band and a heavy outer line.
 draw_rect(frame,INK,false,1.2)
 var band := frame.grow(9*line)
 draw_rect(band,INK,false,1.0)
 draw_rect(frame.grow(13*line),INK,false,3.0)
 var s := scale_factor()
 for entry in grid_x():
  var x := frame.position.x+view.size.x*0.5+(float(entry[0])-center.x)*s
  if x>=frame.position.x-0.5 and x<=frame.end.x+0.5:
   var text: String=entry[1]
   for edge in [frame.position.y-16*line,frame.end.y+30*line]:draw_string(font,Vector2(x-14,edge),text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*line+4),INK)
   draw_line(Vector2(x,band.position.y),Vector2(x,frame.position.y),INK,1)
   draw_line(Vector2(x,frame.end.y),Vector2(x,band.end.y),INK,1)
 for entry in grid_z():
  var y := frame.position.y+view.size.y*0.5+(float(entry[0])-center.y)*s
  if y>=frame.position.y-0.5 and y<=frame.end.y+0.5:
   var text: String=entry[1]
   draw_string(font,Vector2(frame.position.x-58*line-14,y+5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*line+4),INK)
   draw_string(font,Vector2(frame.end.x+18*line,y+5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*line+4),INK)
   draw_line(Vector2(band.position.x,y),Vector2(frame.position.x,y),INK,1)
   draw_line(Vector2(frame.end.x,y),Vector2(band.end.x,y),INK,1)
 # Margin information in the order of a General Staff sheet.
 var small := int(11*line+4)
 draw_string(font,Vector2(sheet.position.x+24*line,sheet.position.y+30*line),"Система координат 1942 р.",HORIZONTAL_ALIGNMENT_LEFT,-1,small,INK)
 draw_string(font,Vector2(sheet.position.x+24*line,sheet.position.y+48*line),"Балтійська система висот",HORIZONTAL_ALIGNMENT_LEFT,-1,small,INK)
 draw_string(font,Vector2(sheet.position.x,sheet.position.y+28*line),"ГЕНЕРАЛЬНИЙ ШТАБ",HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,small,INK)
 var routed := page=="route"
 draw_string(font,Vector2(sheet.position.x,sheet.position.y+58*line),"АВДІЇВКА · ПІВДЕННІ ПІДСТУПИ" if routed else title,HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,int(19*line+6),INK)
 draw_string(font,Vector2(sheet.position.x,sheet.position.y+28*line),"ТАЄМНО",HORIZONTAL_ALIGNMENT_RIGHT,sheet.size.x-24*line,small,INK)
 var code := "М-37-121-А-б-2"
 if real_grid:code=str(AvdiivkaData.shared().meta.get("sheet_50k","М-37-136-Г"))+"-а" if routed else str(AvdiivkaData.shared().meta.get("sheet_10k",code))
 draw_string(font,Vector2(sheet.position.x,sheet.position.y+56*line),code,HORIZONTAL_ALIGNMENT_RIGHT,sheet.size.x-24*line,int(17*line+5),INK)
 # Bottom margin: scale, graphic scale, contour interval; diagram at left.
 var y := frame.end.y+30*line+small*1.5
 draw_string(font,Vector2(sheet.position.x,y),"1 : 25 000" if routed else "1 : 10 000",HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,int(16*line+5),INK)
 # Graphic scale: measured on screen at the current magnification.
 var unit := 10.0
 for candidate in [10.0,20.0,25.0,50.0,100.0,200.0,250.0,500.0,1000.0]:
  if candidate*4*s<=sheet.size.x*0.40:unit=candidate
 var length := unit*s
 var bar_y := y+small*0.55
 var start := Vector2(sheet.position.x+sheet.size.x*0.5-length*2,bar_y)
 for i in range(4):
  draw_rect(Rect2(start+Vector2(i*length,0),Vector2(length,5*line+2)),INK if i%2==0 else WHITE)
  draw_string(font,start+Vector2(i*length-4,5*line+2+small),str(roundi(i*unit)),HORIZONTAL_ALIGNMENT_LEFT,-1,small,INK)
 draw_rect(Rect2(start,Vector2(length*4,5*line+2)),INK,false,1)
 draw_string(font,start+Vector2(length*4-4,5*line+2+small),"%d м" % roundi(unit*4),HORIZONTAL_ALIGNMENT_LEFT,-1,small,INK)
 var step_value: float=route.interval if routed else interval
 var spacing := str(roundi(step_value)) if is_equal_approx(step_value,roundf(step_value)) else ("%.1f" % step_value).replace(".",",")
 y=bar_y+5*line+2+small*2.35
 draw_string(font,Vector2(sheet.position.x,y),"Суцільні горизонталі проведено через %s м" % spacing,HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,small,INK)
 draw_string(font,Vector2(sheet.position.x,y+small*1.25),"Прямокутна сітка через 1 км" if routed else "Прямокутна сітка через 100 м",HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,small,INK)
 # Declination diagram: grid line, true and magnetic meridians.
 var arm := 46*line
 var root := Vector2(sheet.position.x+30*line,frame.end.y+30*line+arm+small)
 draw_line(root,root+Vector2(0,-arm),INK,1.5)
 draw_line(root,root+Vector2(-sin(0.03),-cos(0.03))*arm,INK,1)
 draw_line(root,root+Vector2(sin(0.13),-cos(0.13))*arm,INK,1)
 var note := int(10*line+3)
 for i in range(3):
  draw_string(font,root+Vector2(16*line,-arm+small*0.8+i*note*1.2),["Азимути далекоміра","й лінійки — дирекційні","кути, тисячні"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,note,INK)
 var help := "ЛКМ — лінійка   ПКМ — зсунути / прибрати   коліщатко — масштаб   M / Esc — закрити"
 if has_route():help+="   N — інший аркуш"
 draw_string(font,Vector2(sheet.position.x,sheet.end.y-small*0.6),help,HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,small,Color("4b4a42"))
 # The two sheets of the great assault, as tabs in the right margin.
 tab_rects.clear()
 if has_route():
  var tab_size := int(12*line+4)
  var at := Vector2(sheet.end.x-24*line,frame.end.y+30*line+small*1.5)
  for entry in [["route","МАРШРУТ · 1:25 000"],["local","СЕЛО · 1:10 000"]]:
   var w := font.get_string_size(entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,tab_size).x+18
   var box := Rect2(at.x-w,at.y-tab_size-6,w,tab_size+12)
   var chosen: bool=page==entry[0]
   draw_rect(box,INK if chosen else WHITE)
   draw_rect(box,INK,false,1)
   draw_string(font,box.position+Vector2(9,tab_size+2),entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,tab_size,WHITE if chosen else INK)
   tab_rects[entry[0]]=box
   at.y+=tab_size+16

func draw_view() -> void:
 if page=="route":draw_route();return
 var s := scale_factor()
 var px := 1.0/s
 view.draw_set_transform(view.size*0.5-center*s,0,Vector2(s,s))
 view.draw_rect(Rect2(-HALF,-HALF,HALF*2,HALF*2),WHITE)
 for point in marsh:
  for row in range(3):
   var y := point.y-1.6+row*1.6
   view.draw_line(Vector2(point.x-2.2+row*0.6,y),Vector2(point.x+0.6+row*0.6,y),BLUE,1.1*px)
 var radius := 2.7 if kind=="village" else 3.6
 for tree in trees:view.draw_circle(tree,radius,GREEN)
 for contour in contours:
  if not contour.segments.is_empty():view.draw_multiline(contour.segments,BROWN,(1.6 if contour.index else 0.8)*px)
 for road in roads:
  view.draw_polyline(road.points,INK,road.width+2.0*px)
  view.draw_polyline(road.points,road.fill,road.width)
 for trench in trenches:
  view.draw_polyline(trench,INK,1.6*px)
  for i in range(trench.size()-1):
   var a: Vector2=trench[i]
   var b: Vector2=trench[i+1]
   var normal := (b-a).orthogonal().normalized()
   var steps := int(a.distance_to(b)/3.0)
   for step in range(steps):
    var at := a.lerp(b,(step+0.5)/steps)
    view.draw_line(at,at+normal*1.4,INK,1.2*px)
 for outline in buildings:
  view.draw_colored_polygon(outline,BRICK)
  var closed := outline.duplicate();closed.append(outline[0])
  view.draw_polyline(closed,INK,1.1*px)
 for i in range(0,trees.size(),3):
  var tree: Vector2=trees[i]
  if biome=="pine":
   view.draw_line(tree+Vector2(0,0.9),tree+Vector2(0,-0.9),GREEN_INK,1.0*px)
   view.draw_line(tree+Vector2(-0.6,-0.1),tree+Vector2(0,-0.9),GREEN_INK,1.0*px)
   view.draw_line(tree+Vector2(0.6,-0.1),tree+Vector2(0,-0.9),GREEN_INK,1.0*px)
  else:
   view.draw_arc(tree+Vector2(0,-0.4),0.75,0,TAU,10,GREEN_INK,1.0*px)
   view.draw_line(tree+Vector2(0,0.35),tree+Vector2(0,1.0),GREEN_INK,1.0*px)
 for value in range(-200,201,100):
  view.draw_line(Vector2(value,-HALF),Vector2(value,HALF),INK,0.9*px)
  view.draw_line(Vector2(-HALF,value),Vector2(HALF,value),INK,0.9*px)
 view.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
 var font := ThemeDB.fallback_font
 var size_text := int(clampf(9+zoom*2,10,18))
 for entry in contour_labels:
  var at := to_screen(entry[0])
  view.draw_rect(Rect2(at-Vector2(10,8),Vector2(22,12)),WHITE)
  view.draw_string(font,at+Vector2(-9,3),entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,size_text-1,BROWN)
 for spot in spots:
  var at := to_screen(spot[0])
  view.draw_circle(at,2.0,INK)
  view.draw_string(font,at+Vector2(4,-3),altitude_text(spot[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,size_text,INK)
 draw_enemy_marks()
 draw_ruler()

func draw_ruler() -> void:
 var font := ThemeDB.fallback_font
 if ruler_from.is_finite() and ruler_to.is_finite():
  var a := to_screen(ruler_from)
  var b := to_screen(ruler_to)
  view.draw_line(a,b,PENCIL,2)
  view.draw_circle(a,3,PENCIL)
  view.draw_arc(b,5,0,TAU,16,PENCIL,1.5)
  var text := ruler_text()
  var box := Rect2(b+Vector2(10,-24),Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+12,24))
  if box.end.x>view.size.x:box.position.x=b.x-box.size.x-10
  if box.position.y<0:box.position.y=b.y+10
  # The far end may be off the magnified view: keep the reading on the sheet.
  box.position=box.position.clamp(Vector2(4,4),view.size-box.size-Vector2(4,4))
  view.draw_rect(box,Color(0.97,0.96,0.91,0.92))
  view.draw_string(font,box.position+Vector2(6,17),text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,PENCIL)

static func measure(from: Vector2, to: Vector2) -> Dictionary:
 var delta := to-from
 return {"distance":delta.length(),"azimuth":MortarBallistics.azimuth(Vector3(delta.x,0,delta.y))}

func ruler_text() -> String:
 var result := measure(ruler_from,ruler_to)
 return "%d м · %s" % [roundi(result.distance),MortarBallistics.mils_text(result.azimuth)]

func view_input(event: InputEvent) -> void:
 if event is InputEventMouseButton:
  var mouse := event as InputEventMouseButton
  if mouse.button_index==MOUSE_BUTTON_LEFT:
   measuring=mouse.pressed
   if mouse.pressed:ruler_from=to_world(mouse.position);ruler_to=ruler_from
  elif mouse.button_index==MOUSE_BUTTON_RIGHT:
   if mouse.pressed:panning=true;pan_moved=false
   else:
    panning=false
    if not pan_moved:ruler_from=Vector2.INF;ruler_to=Vector2.INF
  elif mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   var anchor := to_world(mouse.position)
   zoom=clampf(zoom*(1.25 if mouse.button_index==MOUSE_BUTTON_WHEEL_UP else 0.8),1.0,5.0)
   center=anchor-(mouse.position-view.size*0.5)/scale_factor()
   clamp_view()
  queue_redraw();view.queue_redraw()
 elif event is InputEventMouseMotion:
  var motion := event as InputEventMouseMotion
  if measuring:ruler_to=to_world(motion.position);view.queue_redraw()
  if panning:
   if motion.relative.length()>0.5:pan_moved=true
   center-=motion.relative/scale_factor();clamp_view()
   queue_redraw();view.queue_redraw()

func _input(event: InputEvent) -> void:
 if not visible or not (event is InputEventKey) or not event.pressed or event.echo:return
 if event.physical_keycode in [KEY_M,KEY_ESCAPE]:
  close();get_viewport().set_input_as_handled()
 elif event.physical_keycode==KEY_N and has_route():
  set_sheet("local" if page=="route" else "route");game.sound("click",-14)
  get_viewport().set_input_as_handled()

# --- the route sheet ------------------------------------------------------------
func draw_route() -> void:
 var s := scale_factor()
 var px := 1.0/s
 view.draw_set_transform(view.size*0.5-center*s,0,Vector2(s,s))
 view.draw_rect(Rect2(ROUTE_CENTER-Vector2.ONE*ROUTE_HALF,Vector2.ONE*ROUTE_HALF*2),WHITE)
 route.draw(view,px)
 for entry in grid_x():view.draw_line(Vector2(entry[0],ROUTE_CENTER.y-ROUTE_HALF),Vector2(entry[0],ROUTE_CENTER.y+ROUTE_HALF),INK,0.9*px)
 for entry in grid_z():view.draw_line(Vector2(ROUTE_CENTER.x-ROUTE_HALF,entry[0]),Vector2(ROUTE_CENTER.x+ROUTE_HALF,entry[0]),INK,0.9*px)
 view.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
 var font := ThemeDB.fallback_font
 for entry in route.labels:
  var at := to_screen(entry[0])
  view.draw_rect(Rect2(at-Vector2(12,8),Vector2(26,12)),WHITE)
  view.draw_string(font,at+Vector2(-11,3),entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,11,BROWN)
 for place in route.places:
  var at := to_screen(place[0])
  var big: bool=place[2]=="town"
  view.draw_string(font,at+Vector2(-40,0),place[1],HORIZONTAL_ALIGNMENT_CENTER,80,18 if big else 14,INK)
 draw_pencil_marks()
 draw_enemy_marks()
 draw_ruler()

# The commander's own pencil on the sheet: the assembly area of the column
# in the grove by the highway, and the route of the advance to the village.
func draw_pencil_marks() -> void:
 var district: Node3D=game.district
 var count: int=maxi(1,game.battle.mech.size()) if game.battle.active else 1
 var spots: Array[Vector2]=[]
 for i in range(count):
  var p: Vector3=BmpRoutes.parking(i,district).origin
  spots.append(Vector2(p.x,p.z))
 var middle := Vector2.ZERO
 for p in spots:middle+=p/spots.size()
 var reach := 60.0
 for p in spots:reach=maxf(reach,middle.distance_to(p)+45.0)
 var s := scale_factor()
 var c := to_screen(middle)
 var r := maxf(reach*s,15.0)
 hand_ring(c,Vector2(1.12,0.9)*r,PENCIL,0.0)
 # Route of the advance: dashes along the highway and the corridor.
 var path := PackedVector2Array([to_screen(spots[0])])
 for p in BmpRoutes.ROAD:path.append(to_screen(p))
 for p in BmpRoutes.CORRIDOR:path.append(to_screen(p))
 var run := 0.0
 var phase := 0.0
 for i in range(path.size()-1):
  var a: Vector2=path[i]
  var b: Vector2=path[i+1]
  var length := a.distance_to(b)
  if length<0.5:continue
  var normal := (b-a).orthogonal()/length
  var t := 0.0
  # Dashes of 9 px with gaps of 6, running on across the bends.
  while t<length-0.01:
   var dash := phase<9.0
   var step := minf((9.0 if dash else 15.0)-phase,length-t)
   if dash:
    var wa := sin((run+t)*0.11)*1.4
    var wb := sin((run+t+step)*0.11)*1.4
    view.draw_line(a.lerp(b,t/length)+normal*wa,a.lerp(b,(t+step)/length)+normal*wb,PENCIL,2.0,true)
   t+=step;phase=fmod(phase+step,15.0)
  run+=length
 var tip: Vector2=path[path.size()-1]
 var back: Vector2=(path[path.size()-2]-tip).normalized()
 view.draw_line(tip,tip+back.rotated(0.45)*13.0,PENCIL,2.2,true)
 view.draw_line(tip,tip+back.rotated(-0.45)*13.0,PENCIL,2.2,true)
 # Handwriting: a slant and a slight tilt.
 var font := ThemeDB.fallback_font
 var label := c+Vector2(r*1.2+6,-r*0.25)
 view.draw_set_transform(label,-0.12,Vector2(1.0,1.0))
 view.draw_string(font,Vector2.ZERO,"ВР",HORIZONTAL_ALIGNMENT_LEFT,-1,22,PENCIL)
 view.draw_string(font,Vector2(2,18),"(%d БМП)" % count,HORIZONTAL_ALIGNMENT_LEFT,-1,14,PENCIL)
 view.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

# A ring drawn in one stroke, a little uneven, its ends overlapping.
func hand_ring(c: Vector2, radius: Vector2, color: Color, phase: float) -> void:
 var ring := PackedVector2Array()
 for k in range(41):
  var a := -0.9+phase+k*(TAU+0.45)/40.0
  var wobble := 1.0+0.06*sin(a*3.0+0.7+phase)+0.035*sin(a*5.0+2.1)
  ring.append(c+Vector2(cos(a)*radius.x,sin(a)*radius.y)*wobble)
 view.draw_polyline(ring,color,2.2,true)

# The three enemy strongpoints of the great assault in red pencil; a taken
# one is crossed out.
func draw_enemy_marks() -> void:
 if not has_route():return
 var font := ThemeDB.fallback_font
 var s := scale_factor()
 var middle := Vector2.ZERO
 for c in BattleMap.CENTERS:middle+=c/BattleMap.CENTERS.size()
 for i in range(BattleMap.CENTERS.size()):
  var point: Vector2=BattleMap.CENTERS[i]
  var c := to_screen(point)
  var r := maxf(45.0*s,8.0)
  hand_ring(c,Vector2(1.0,0.86)*r,RED_PENCIL,1.3+i*1.9)
  if game.battle.active and game.battle.cleared[i]:
   view.draw_line(c+Vector2(-0.7,-0.6)*r,c+Vector2(0.75,0.65)*r,RED_PENCIL,2.0,true)
   view.draw_line(c+Vector2(-0.65,0.7)*r,c+Vector2(0.7,-0.6)*r,RED_PENCIL,2.0,true)
  # The label outside the group, slanted like handwriting.
  var out: Vector2=(point-middle).normalized()
  var size_text := 14 if r<20.0 else 18
  var text := "ОП-%d" % (i+1)
  var w := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_text).x
  var at := c+out*(r+6.0)+Vector2(-w*0.5+out.x*w*0.5,size_text*0.35+out.y*size_text*0.5)
  # Kept on the sheet: inside the ring's side if the margin cuts it off.
  if at.x<4.0 or at.x+w>view.size.x-4.0:at.x=c.x-w*0.5
  if at.y<size_text+2.0 or at.y>view.size.y-4.0:at.y=c.y+size_text*0.35
  at=at.clamp(Vector2(4.0,size_text+2.0),Vector2(view.size.x-w-4.0,view.size.y-4.0))
  view.draw_set_transform(at,-0.1,Vector2.ONE)
  view.draw_string(font,Vector2.ZERO,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_text,RED_PENCIL)
  view.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

class RouteSheet extends RefCounted:
 # Built once from the OpenStreetMap and SRTM data of the operation area:
 # each layer is a mesh or one multiline, a few draw calls for the sheet.
 const WOOD := Color("c5e0a5")
 const WOOD_EDGE := Color("7fae5c")
 const WATER := Color("a8cfec")
 const WATER_INK := Color("3d86c6")
 const HOUSE := Color("cc7246")
 const ROAD_INK := Color("1f1e1b")
 const MAJOR := Color("e58c58")
 const LESSER := Color("f2d27a")
 const TRACK := Color("8a6a44")
 const CONTOUR := Color("b2692c")
 var woods: ArrayMesh
 var water: ArrayMesh
 var houses: ArrayMesh
 var lines: Dictionary={}
 var labels: Array=[]
 var places: Array=[]
 var interval := 5.0
 func touches(points: PackedVector2Array, area: Rect2) -> bool:
  for p in points:
   if area.has_point(p):return true
  return false
 func add_lines(style: String, points: PackedVector2Array) -> void:
  if points.size()<2:return
  var list: PackedVector2Array=lines.get(style,PackedVector2Array())
  for k in range(points.size()-1):list.append(points[k]);list.append(points[k+1])
  lines[style]=list
 func fill(rings: Array, color: Color) -> ArrayMesh:
  var vertices:=PackedVector2Array();var colors:=PackedColorArray()
  for ring in rings:
   var points: PackedVector2Array=ring
   if points.size()>3 and points[0].is_equal_approx(points[points.size()-1]):points=points.slice(0,points.size()-1)
   var index:=Geometry2D.triangulate_polygon(points)
   for k in index:vertices.append(points[k]);colors.append(color)
  var mesh:=ArrayMesh.new()
  if vertices.is_empty():return mesh
  var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  return mesh
 func build(data: AvdiivkaData, area: Rect2) -> void:
  var near:=area.grow(300.0)
  var f: Dictionary=data.features
  var rings: Array=[]
  for w in f.woods:
   var points:=AvdiivkaData.pairs(w)
   if touches(points,near):rings.append(points);add_lines("wood_edge",points)
  woods=fill(rings,WOOD)
  for r in f.rows:
   var points:=AvdiivkaData.pairs(r)
   if touches(points,near):add_lines("rows",points)
  rings=[]
  for w in f.water:
   var points:=AvdiivkaData.pairs(w)
   if touches(points,near):rings.append(points);add_lines("water",points)
  water=fill(rings,WATER)
  for item in f.streams:
   var points:=AvdiivkaData.pairs(item[1])
   if touches(points,near):add_lines("water",points)
  for r in f.rails:
   var points:=AvdiivkaData.pairs(r)
   if touches(points,near):add_lines("rails",points)
  for r in f.roads:
   if r[0] in OperationArea.SKIP_ROADS:continue
   var points:=AvdiivkaData.pairs(r[3])
   if not touches(points,near):continue
   var kind: String=r[0]
   if kind in ["trunk","trunk_link","primary","primary_link"]:add_lines("major",points)
   elif kind in ["secondary","secondary_link","tertiary","tertiary_link"]:add_lines("lesser",points)
   elif kind=="track":add_lines("track",points)
   else:add_lines("minor",points)
  var vertices:=PackedVector2Array();var colors:=PackedColorArray()
  for b in f.buildings:
   var x:=float(b[0]);var z:=float(b[1])
   if not near.has_point(Vector2(x,z)):continue
   var c:=cos(float(b[4]));var sn:=sin(float(b[4]))
   var w:=float(b[2])*0.5;var d:=float(b[3])*0.5
   var q: Array=[]
   for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
    q.append(Vector2(x+c*corner.x*w+sn*corner.y*d,z-sn*corner.x*w+c*corner.y*d))
   for index in [0,1,2,0,2,3]:vertices.append(q[index]);colors.append(HOUSE)
  houses=ArrayMesh.new()
  if not vertices.is_empty():
   var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
   arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
   houses.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  for place in data.meta.get("places",[]):
   var at:=Vector2(float(place[1]),float(place[2]))
   if area.has_point(at):places.append([at,str(place[0]),str(place[3])])
  survey(data,area)
 # Contours from the 20 m relief nodes, marching squares as on the sheet
 # of the village.
 func survey(data: AvdiivkaData, area: Rect2) -> void:
  var i0:=floori((area.position.x+data.half)/data.step);var i1:=ceili((area.end.x+data.half)/data.step)
  var j0:=floori((area.position.y+data.half)/data.step);var j1:=ceili((area.end.y+data.half)/data.step)
  var low:=INF;var high:=-INF
  for j in range(j0,j1+1):
   for i in range(i0,i1+1):
    var h:=data.node(i,j)+data.base_altitude
    low=minf(low,h);high=maxf(high,h)
  interval=20.0
  for candidate in [1.0,2.0,2.5,5.0,10.0,20.0]:
   if (high-low)/candidate<=24:interval=candidate;break
  var thin:=PackedVector2Array();var thick:=PackedVector2Array()
  var placed: Array[Vector2]=[]
  for j in range(j0,j1):
   for i in range(i0,i1):
    var a:=data.node(i,j)+data.base_altitude;var b:=data.node(i+1,j)+data.base_altitude
    var c:=data.node(i+1,j+1)+data.base_altitude;var d:=data.node(i,j+1)+data.base_altitude
    var lo:=minf(minf(a,b),minf(c,d));var hi:=maxf(maxf(a,b),maxf(c,d))
    if hi-lo<0.0001:continue
    var corner:=Vector2(i*data.step-data.half,j*data.step-data.half)
    var level:=ceilf(lo/interval)*interval
    while level<=hi:
     var points:=PackedVector2Array()
     for edge in [[a,b,Vector2(0,0),Vector2(1,0)],[b,c,Vector2(1,0),Vector2(1,1)],[c,d,Vector2(1,1),Vector2(0,1)],[d,a,Vector2(0,1),Vector2(0,0)]]:
      var h1: float=edge[0];var h2: float=edge[1]
      if (h1<level)!=(h2<level):points.append(corner+Vector2(edge[2]).lerp(edge[3],(level-h1)/(h2-h1))*data.step)
     if points.size()>=2:
      var main:=posmod(roundi(level/interval),5)==0
      (thick if main else thin).append_array(points.slice(0,4 if points.size()>=4 else 2))
      if main and area.grow(-300.0).has_point(points[0]):
       var free:=true
       for other in placed:
        if other.distance_to(points[0])<900.0:free=false;break
       if free:placed.append(points[0]);labels.append([points[0],str(roundi(level))])
     level+=interval
  lines["contour"]=thin;lines["contour_main"]=thick
 func draw(canvas: Control, px: float) -> void:
  if woods.get_surface_count()>0:canvas.draw_mesh(woods,null)
  if water.get_surface_count()>0:canvas.draw_mesh(water,null)
  var styles:=[["contour",CONTOUR,0.8],["contour_main",CONTOUR,1.5],["wood_edge",WOOD_EDGE,0.8],["rows",WOOD_EDGE,1.6],["water",WATER_INK,1.2],["rails",ROAD_INK,2.2],["track",TRACK,1.0],["minor",ROAD_INK,1.0]]
  for style in styles:
   if lines.has(style[0]) and lines[style[0]].size()>=2:canvas.draw_multiline(lines[style[0]],style[1],float(style[2])*px)
  # Roads with a casing: the highway orange, the lesser roads yellow.
  for style in [["lesser",LESSER,2.6],["major",MAJOR,3.6]]:
   if not lines.has(style[0]):continue
   canvas.draw_multiline(lines[style[0]],ROAD_INK,(float(style[2])+1.8)*px)
   canvas.draw_multiline(lines[style[0]],style[1],float(style[2])*px)
  if houses.get_surface_count()>0:canvas.draw_mesh(houses,null)
