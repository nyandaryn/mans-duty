extends Button
var kind := "rifle"
var title := ""
var subtitle := ""
var accent := Color("b8a779")
var preview: ModelPreview

func _ready() -> void:
 preview=ModelPreview.new()
 add_child(preview)
 preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var compact := kind in ["magazine","medkit"]
 preview.offset_left=40 if compact else 12
 preview.offset_right=-8 if compact else -12
 preview.offset_top=5 if compact else 30
 preview.offset_bottom=-5 if compact else -28

func show_weapon(id: String) -> void:
 preview.show_weapon(id,kind=="magazine")

func show_item(id: String) -> void:
 preview.show_item(id)

func _draw() -> void:
 var font := ThemeDB.fallback_font
 draw_string(font,Vector2(14,24),title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c8cbbb"))
 draw_string(font,Vector2(14,size.y-12),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,12,accent)
