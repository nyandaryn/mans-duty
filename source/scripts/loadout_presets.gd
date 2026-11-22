class_name LoadoutPresets
extends RefCounted

var presets: Dictionary={}
var path := "user://loadouts.cfg"

func read() -> void:
 var config := ConfigFile.new()
 if config.load(path)!=OK:return
 var raw: Variant=config.get_value("loadouts","presets",{})
 if not raw is Dictionary:return
 for key in raw:
  if presets.size()>=24:break
  if key is String and raw[key] is Dictionary:presets[key.left(32)]=validate(raw[key])

static func validate(data: Dictionary) -> Dictionary:
 var primary := str(data.get("primary","ak74"))
 var role := PlayerClass.valid(str(data.get("class",PlayerClass.infer(primary))))
 var bag := BackpackState.restore(data.get("backpack",{}))
 PlayerClass.clean_bag(role,bag)
 return {"class":role,"primary":PlayerClass.primary_for(role,primary),"secondary":PlayerClass.secondary_for(role,str(data.get("secondary","pm"))),"outfit":Wardrobe.valid(str(data.get("outfit","ua_pixel"))),"vest":VestKind.valid(str(data.get("vest","korsar"))),"backpack":bag.serialize()}

func save_preset(title: String, data: Dictionary) -> Error:
 title=title.strip_edges().left(32)
 if title.is_empty() or (presets.size()>=24 and not presets.has(title)):return ERR_INVALID_PARAMETER
 var next := presets.duplicate(true)
 next[title]=validate(data)
 var config := ConfigFile.new()
 config.set_value("loadouts","presets",next)
 var result := config.save(path)
 if result==OK:presets=next
 return result
