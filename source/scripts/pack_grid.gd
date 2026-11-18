class_name PackGrid
extends Control

signal selected(uid: int)
signal changed
var bag: BackpackState
var editable := false
var chosen := -1
var cards: Dictionary={}
var last_layout := ""

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_STOP
 resized.connect(func():last_layout="";refresh())

func cell_size() -> float:return minf(size.x/BackpackState.WIDTH,size.y/BackpackState.HEIGHT)
func origin() -> Vector2:return (size-Vector2(6,4)*cell_size())*0.5
func cell_at(point: Vector2) -> Vector2i:return Vector2i(((point-origin())/maxf(1,cell_size())).floor())

func refresh() -> void:
 queue_redraw()
 if bag==null:return
 var layout := str(bag.serialize())+str(size)
 if layout==last_layout:return
 last_layout=layout
 for card in cards.values():card.queue_free()
 cards.clear()
 for entry in bag.items:
  var card := Control.new()
  card.mouse_filter=Control.MOUSE_FILTER_IGNORE
  add_child(card)
  cards[int(entry.uid)]=card
  card.position=origin()+Vector2(entry.x,entry.y)*cell_size()+Vector2(3,3)
  var footprint: Vector2i=Equipment.ITEMS[entry.kind].size
  card.size=Vector2(footprint)*cell_size()-Vector2(6,6)
  var preview := ModelPreview.new()
  card.add_child(preview)
  preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  preview.offset_bottom=-17
  preview.show_item(entry.kind)
  var caption := Label.new()
  caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
  caption.text=Equipment.ITEMS[entry.kind].short
  caption.add_theme_font_size_override("font_size",10)
  caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  card.add_child(caption)
  caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
  caption.offset_top=-18

func entry_at(point: Vector2) -> Dictionary:
 if bag==null:return {}
 var cell := cell_at(point)
 for entry in bag.items:
  if Rect2i(Vector2i(entry.x,entry.y),Equipment.ITEMS[entry.kind].size).has_point(cell):return entry
 return {}

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed:
  var entry := entry_at(event.position)
  if entry.is_empty():return
  if event.button_index==MOUSE_BUTTON_RIGHT and editable:
   bag.remove(int(entry.uid));changed.emit();refresh()
  elif event.button_index==MOUSE_BUTTON_LEFT:
   chosen=int(entry.uid);selected.emit(chosen);queue_redraw()

func _get_drag_data(at_position: Vector2) -> Variant:
 if not editable:return null
 var entry := entry_at(at_position)
 if entry.is_empty():return null
 var preview := Label.new()
 preview.text=Equipment.ITEMS[entry.kind].name
 set_drag_preview(preview)
 return {"pack":get_instance_id(),"uid":int(entry.uid)}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
 if not editable or not data is Dictionary or data.get("pack",0)!=get_instance_id():return false
 var entry := bag.item(int(data.uid))
 return not entry.is_empty() and bag.can_place(entry.kind,cell_at(at_position),int(entry.uid))

func _drop_data(at_position: Vector2, data: Variant) -> void:
 if bag.move_item(int(data.uid),cell_at(at_position)):changed.emit();refresh()

func _draw() -> void:
 var cell := cell_size()
 for y in range(4):
  for x in range(6):draw_style_box(style(Color("111b18"),Color("34443b")),Rect2(origin()+Vector2(x,y)*cell,Vector2.ONE*cell-Vector2.ONE*2))
 if bag==null or not bag.equipped:
  draw_string(ThemeDB.fallback_font,origin()+Vector2(12,cell*2),"НАПЛІЧНИК НЕ ОДЯГНЕНО",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("89958c"));return
 for entry in bag.items:
  var rect := Rect2(origin()+Vector2(entry.x,entry.y)*cell,Vector2(Equipment.ITEMS[entry.kind].size)*cell-Vector2.ONE*2)
  draw_style_box(style(Color("25332b"),Color("b8a66c") if int(entry.uid)==chosen else Color("56644d")),rect)

static func style(fill: Color, border: Color) -> StyleBoxFlat:
 var result := StyleBoxFlat.new()
 result.bg_color=fill
 result.border_color=border
 result.set_border_width_all(1)
 return result
