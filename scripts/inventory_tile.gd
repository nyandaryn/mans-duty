extends Button
var kind := "rifle"
var title := ""
var subtitle := ""
var accent := Color("b8a779")
func _draw() -> void:
 var font := ThemeDB.fallback_font
 draw_string(font,Vector2(14,24),title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c8cbbb"))
 draw_string(font,Vector2(14,size.y-12),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,12,accent)
 var center := size*Vector2(0.5,0.48)
 var steel := Color("8b958e")
 if kind=="rifle":
  draw_rect(Rect2(center+Vector2(-55,-6),Vector2(90,14)),steel)
  draw_line(center+Vector2(35,-3),center+Vector2(108,-3),steel,5)
  draw_colored_polygon(PackedVector2Array([center+Vector2(-55,-5),center+Vector2(-104,-13),center+Vector2(-104,14),center+Vector2(-55,6)]),steel)
  draw_colored_polygon(PackedVector2Array([center+Vector2(-3,8),center+Vector2(16,8),center+Vector2(9,40),center+Vector2(-8,36)]),steel)
  draw_line(center+Vector2(-32,8),center+Vector2(-40,29),steel,9)
 elif kind=="pistol":
  draw_rect(Rect2(center+Vector2(-40,-16),Vector2(88,16)),steel)
  draw_colored_polygon(PackedVector2Array([center+Vector2(-33,0),center+Vector2(-10,0),center+Vector2(-19,43),center+Vector2(-43,43)]),steel)
  draw_rect(Rect2(center+Vector2(-10,1),Vector2(24,18)),steel,false,3)
 else:
  draw_rect(Rect2(center+Vector2(-9,-15),Vector2(18,36)),steel)
  for x in [-4,2]:draw_line(center+Vector2(x,-11),center+Vector2(x,17),Color("414b42"),2)
