class_name TopoMap
extends Control

# A large-scale topographic sheet of the operation area in the manner of
# General Staff maps: contours, forest, roads, buildings, trenches and a 100 m
# grid. It never marks the player, allies, enemies or objectives: you find
# yourself by the terrain. The ruler gives distance and grid bearing.
const HALF := 200.0
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

func setup(owner_game: Node3D, parent: Control) -> void:
 game=owner_game
 game.place(self,parent,0,0,1,1)
 mouse_filter=Control.MOUSE_FILTER_STOP
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
 zoom=1.0;center=Vector2.ZERO;ruler_from=Vector2.INF;ruler_to=Vector2.INF
 var definition: Dictionary=district.campaign_definition
 title=district.map_title
 kind=str(definition.get("kind",""))
 biome=str(definition.get("biome",""))
 var heading := float(definition.get("heading",0.0))
 if district.terrain!=null and not district.terrain.heights.is_empty():survey_relief(district.terrain)
 var real:=str(definition.get("terrain",""))=="avdiivka"
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
 var count := int(HALF*2/SAMPLE)+1
 var grid := PackedFloat32Array();grid.resize(count*count)
 var low := INF
 var high := -INF
 # Generalised relief: a cartographer draws the landform, not every hummock.
 # A separable box blur over about 14 m removes ground micro-relief.
 var raw := PackedFloat32Array();raw.resize(count*count)
 for j in range(count):
  for i in range(count):raw[j*count+i]=terrain.heights[(j*SAMPLE)*CampaignTerrain.WIDTH+i*SAMPLE]+BASE_ALTITUDE
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

func scale_factor() -> float:return view.size.x/(HALF*2)*zoom

func clamp_view() -> void:
 var reach := HALF-HALF/zoom
 center=center.clamp(Vector2(-reach,-reach),Vector2(reach,reach))

func to_screen(point: Vector2) -> Vector2:return view.size*0.5+(point-center)*scale_factor()
func to_world(point: Vector2) -> Vector2:return center+(point-view.size*0.5)/scale_factor()

func easting(x: float) -> float:return EASTING+x
func northing(z: float) -> float:return NORTHING-z

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
 for value in range(-200,201,100):
  var x := frame.position.x+view.size.x*0.5+(value-center.x)*s
  var y := frame.position.y+view.size.y*0.5+(value-center.y)*s
  if x>=frame.position.x-0.5 and x<=frame.end.x+0.5:
   var text := grid_label(easting(value))
   for edge in [frame.position.y-16*line,frame.end.y+30*line]:draw_string(font,Vector2(x-14,edge),text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*line+4),INK)
   draw_line(Vector2(x,band.position.y),Vector2(x,frame.position.y),INK,1)
   draw_line(Vector2(x,frame.end.y),Vector2(x,band.end.y),INK,1)
  if y>=frame.position.y-0.5 and y<=frame.end.y+0.5:
   var text := grid_label(northing(value))
   draw_string(font,Vector2(frame.position.x-58*line-14,y+5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*line+4),INK)
   draw_string(font,Vector2(frame.end.x+18*line,y+5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*line+4),INK)
   draw_line(Vector2(band.position.x,y),Vector2(frame.position.x,y),INK,1)
   draw_line(Vector2(frame.end.x,y),Vector2(band.end.x,y),INK,1)
 # Margin information in the order of a General Staff sheet.
 var small := int(11*line+4)
 draw_string(font,Vector2(sheet.position.x+24*line,sheet.position.y+30*line),"Система координат 1942 р.",HORIZONTAL_ALIGNMENT_LEFT,-1,small,INK)
 draw_string(font,Vector2(sheet.position.x+24*line,sheet.position.y+48*line),"Балтійська система висот",HORIZONTAL_ALIGNMENT_LEFT,-1,small,INK)
 draw_string(font,Vector2(sheet.position.x,sheet.position.y+28*line),"ГЕНЕРАЛЬНИЙ ШТАБ",HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,small,INK)
 draw_string(font,Vector2(sheet.position.x,sheet.position.y+58*line),title,HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,int(19*line+6),INK)
 draw_string(font,Vector2(sheet.position.x,sheet.position.y+28*line),"ТАЄМНО",HORIZONTAL_ALIGNMENT_RIGHT,sheet.size.x-24*line,small,INK)
 draw_string(font,Vector2(sheet.position.x,sheet.position.y+56*line),"М-37-121-А-б-2",HORIZONTAL_ALIGNMENT_RIGHT,sheet.size.x-24*line,int(17*line+5),INK)
 # Bottom margin: scale, graphic scale, contour interval; diagram at left.
 var y := frame.end.y+30*line+small*1.5
 draw_string(font,Vector2(sheet.position.x,y),"1 : 10 000",HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,int(16*line+5),INK)
 # Graphic scale: measured on screen at the current magnification.
 var unit := 10.0
 for candidate in [10.0,20.0,25.0,50.0,100.0]:
  if candidate*4*s<=sheet.size.x*0.40:unit=candidate
 var length := unit*s
 var bar_y := y+small*0.55
 var start := Vector2(sheet.position.x+sheet.size.x*0.5-length*2,bar_y)
 for i in range(4):
  draw_rect(Rect2(start+Vector2(i*length,0),Vector2(length,5*line+2)),INK if i%2==0 else WHITE)
  draw_string(font,start+Vector2(i*length-4,5*line+2+small),str(roundi(i*unit)),HORIZONTAL_ALIGNMENT_LEFT,-1,small,INK)
 draw_rect(Rect2(start,Vector2(length*4,5*line+2)),INK,false,1)
 draw_string(font,start+Vector2(length*4-4,5*line+2+small),"%d м" % roundi(unit*4),HORIZONTAL_ALIGNMENT_LEFT,-1,small,INK)
 var spacing := str(roundi(interval)) if is_equal_approx(interval,roundf(interval)) else ("%.1f" % interval).replace(".",",")
 y=bar_y+5*line+2+small*2.35
 draw_string(font,Vector2(sheet.position.x,y),"Суцільні горизонталі проведено через %s м" % spacing,HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,small,INK)
 draw_string(font,Vector2(sheet.position.x,y+small*1.25),"Прямокутна сітка через 100 м",HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,small,INK)
 # Declination diagram: grid line, true and magnetic meridians.
 var arm := 46*line
 var root := Vector2(sheet.position.x+30*line,frame.end.y+30*line+arm+small)
 draw_line(root,root+Vector2(0,-arm),INK,1.5)
 draw_line(root,root+Vector2(-sin(0.03),-cos(0.03))*arm,INK,1)
 draw_line(root,root+Vector2(sin(0.13),-cos(0.13))*arm,INK,1)
 var note := int(10*line+3)
 for i in range(3):
  draw_string(font,root+Vector2(16*line,-arm+small*0.8+i*note*1.2),["Азимути далекоміра","й лінійки — дирекційні","кути, тисячні"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,note,INK)
 draw_string(font,Vector2(sheet.position.x,sheet.end.y-small*0.6),"ЛКМ — лінійка   ПКМ — зсунути / прибрати   коліщатко — масштаб   M / Esc — закрити",HORIZONTAL_ALIGNMENT_CENTER,sheet.size.x,small,Color("4b4a42"))

func draw_view() -> void:
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
