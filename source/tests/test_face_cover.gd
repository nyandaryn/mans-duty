extends SceneTree
# Balaclavas and the neck gaiter (FaceCover), packs on the bots' backs, and
# the gear screen: the face slot and its chooser, Esc, presets, settings.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

# The corners of the triangles the mesh draws (it keeps the head's vertices).
func used_vertices(mesh: ArrayMesh) -> PackedVector3Array:
 var arrays:=mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var used:={}
 for index in arrays[Mesh.ARRAY_INDEX]:used[index]=true
 var result:=PackedVector3Array()
 for index in used:result.append(vertices[index])
 return result

func run():
 # --- The data ---------------------------------------------------------------
 check(FaceCover.IDS.size()==6 and FaceCover.IDS[0]=="none","Five face covers and none")
 for id in FaceCover.IDS:
  check(FaceCover.DATA.has(id) and String(FaceCover.DATA[id].short)!="" and String(FaceCover.DATA[id].brief)!="","%s has a name, a short label and a description" % id)
  check((FaceCover.mass(id)>0.0)==(id!="none"),"%s weighs what it should (%.2f kg)" % [id,FaceCover.mass(id)])
 check(FaceCover.valid("bogus")=="none" and FaceCover.label("bogus")==FaceCover.label("none"),"An unknown id means no face cover")
 for side in [true,false]:
  var worn:=0
  for index in range(8):
   var id:=FaceCover.issue(side,index)
   check(id in FaceCover.IDS,"Issued covers are known ones (%s)" % id)
   if id!="none":worn+=1
  check(worn>=3 and worn<=5,"About half the %s wear one (%d of 8)" % ["defenders' men" if not side else "our men",worn])
 # --- The meshes: an eye slot in the balaclava, the gaiter below the eyes ---
 var balaclava:=used_vertices(FaceCover.mesh(false))
 var in_slot:=0
 var above:=0
 var below:=0
 for v in balaclava:
  if absf(v.x)<0.05 and absf(v.y-FaceCover.SLOT_Y)<0.015 and v.z< -0.08:in_slot+=1
  if v.y>FaceCover.SLOT_Y+0.05:above+=1
  if v.y<FaceCover.SLOT_Y-0.07:below+=1
 check(balaclava.size()>1000,"The balaclava is cut from the whole head (%d vertices)" % balaclava.size())
 check(in_slot==0,"The eye slot is open (%d vertices in it)" % in_slot)
 check(above>100 and below>100,"Knit above the eyes and below them (%d / %d)" % [above,below])
 var gaiter:=used_vertices(FaceCover.mesh(true))
 var top:=-INF
 for v in gaiter:top=maxf(top,v.y)
 check(gaiter.size()>200 and top<0.128+FaceCover.LIFT+0.002,"The gaiter stops at the bridge of the nose (top %.3f m)" % top)
 check(FaceCover.mesh(false)==FaceCover.mesh(false),"The meshes are built once")

 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game)
 game.volume=0
 for i in range(3):await process_frame
 var screen=game.loadout_screen
 # --- The gear screen ----------------------------------------------------------
 check(screen.face_buttons.size()==FaceCover.IDS.size(),"Every face cover has a card")
 check(screen.slots.has("face") and screen.slots.has("pack") and screen.slots.has("vest") and screen.slots.has("outfit"),"The doll has face, uniform, vest and pack slots")
 screen.open_chooser("face")
 check(screen.chooser.visible and screen.chooser_pages["face"].visible and not screen.chooser_pages["vest"].visible,"The face slot opens its list")
 screen.face_buttons["camo"].pressed.emit()
 check(game.player_face=="camo" and screen.face_buttons["camo"].button_pressed,"A card puts that cover on and shows it chosen")
 check(screen.portrait.content_key.ends_with("+camo"),"The portrait wears it (%s)" % screen.portrait.content_key)
 check(screen.slots.face.preview.content_key=="head:%s+camo" % game.player_outfit,"The face slot shows the head in it")
 check(screen.examine_title.text==FaceCover.label("camo"),"The chosen cover is described (%s)" % screen.examine_title.text)
 # Kept in the settings (the automated preview does not save: allow it once).
 game.remove_meta("automated_preview");game.save_settings();game.set_meta("automated_preview",true)
 var settings:=ConfigFile.new();settings.load("user://settings.cfg")
 check(settings.get_value("loadout","face","")=="camo","The choice is kept in the settings")
 game.player_face="none";game.load_settings()
 check(game.player_face=="camo","…and read back from them")
 check(screen.dismiss() and not screen.chooser.visible,"Esc closes the list first")
 check(not screen.dismiss(),"…and then has nothing more to close")
 # The class view: the kit's weight, run and pack.
 screen.pinned="";screen.inspect_rest()
 await process_frame
 check(screen.examine_bars.get_child_count()==3,"The class view shows the kit's weight, run and pack (%d bars)" % screen.examine_bars.get_child_count())
 var before: float=screen.kit_weight()
 game.choose_face("none")
 check(is_equal_approx(before-screen.kit_weight(),FaceCover.mass("camo")),"The cover counts in the kit's weight")
 # Presets carry it.
 game.choose_face("gaiter")
 screen.preset_name.text="Тест балаклави";screen.save_preset()
 game.choose_face("black")
 var index:=-1
 for i in range(screen.preset_select.item_count):if screen.preset_select.get_item_text(i)=="Тест балаклави":index=i
 check(index>0,"The preset is listed")
 screen.load_selected(index)
 check(game.player_face=="gaiter","A preset puts its face cover back on (%s)" % game.player_face)
 # --- In the battle -----------------------------------------------------------
 game.choose_face("olive")
 game.start_match()
 for i in range(10):await physics_frame
 check(game.player.face_cover=="olive","The player goes out in the chosen cover")
 var covered:=0
 var bare:=0
 var packs:=0
 var without:=0
 for bot in game.bots+game.allies:
  if bot.model==null:continue
  var cover: Node=bot.model.get_node_or_null("Head/FaceCover")
  check((cover!=null)==(bot.face_cover!="none") and String(bot.model.get_meta("face_cover",""))==bot.face_cover,"%s: the cover on the model is the issued one (%s)" % [bot.name,bot.face_cover])
  if cover!=null:
   covered+=1
   check(cover.get_node_or_null("Mask")!=null and cover.get_node_or_null("Neck")!=null,"%s: mask and neck tube" % bot.name)
  else:bare+=1
  var pack: Node=bot.model.get_node_or_null("Backpack")
  check((pack!=null)==bot.has_pack,"%s: a pack on the back when he carries one" % bot.name)
  if bot.has_pack:packs+=1
  else:without+=1
 check(covered>0 and bare>0,"Some bots in balaclavas, some without (%d / %d)" % [covered,bare])
 check(packs>0 and without>0,"Some bots with packs, some without (%d / %d)" % [packs,without])
 game.queue_free()
 await process_frame
 if checks<60:check(false,"Every step ran (%d checks)" % checks)
 print("%s: %d face cover, pack and gear screen checks" % ["FAILED" if failed else "PASS",checks])
 quit(1 if failed else 0)
