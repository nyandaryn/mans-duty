class_name AmmoPacketArt
extends RefCounted

static func paper_material() -> void:
 if Models.materials.has("kraft_paper"):return
 var material := StandardMaterial3D.new()
 material.resource_name="kraft_paper"
 material.albedo_color=Color("9b805c")
 material.roughness=0.98
 var noise := FastNoiseLite.new();noise.seed=4307;noise.frequency=0.18
 var texture := NoiseTexture2D.new();texture.width=128;texture.height=128;texture.noise=noise;texture.seamless=true
 var ramp := Gradient.new();ramp.set_color(0,Color("8b785c"));ramp.set_color(1,Color("e3cfaa"));texture.color_ramp=ramp
 material.albedo_texture=texture;material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*35
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 Models.materials["kraft_paper"]=material

static func triangle(parent: Node3D, a: Vector3, b: Vector3, c: Vector3) -> void:
 var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for vertex in [a,b,c]:st.add_vertex(vertex)
 st.generate_normals();Models.mesh_node(parent,st.commit(),Vector3.ZERO,"kraft_paper")

static func build(kind: String) -> Node3D:
 paper_material()
 var root := Node3D.new();root.name="PaperPacket"
 var id: String=Equipment.ITEMS[kind].weapon
 var rifle := id not in ["pm","m9"]
 var depth := 0.080 if id=="svd" else (0.061 if rifle else 0.035)
 var height := 0.050 if id=="svd" else 0.037
 var pitch := 0.0146 if id=="svd" else 0.0102
 var half_width := pitch*5+0.003
 var width := half_width*2
 # Paper envelope with folded gussets, overlapping flaps and a staple.
 Models.bevel(root,Vector3(0,-height/2,0),Vector3(width,0.001,depth),"kraft_paper",0.0004)
 for x in [-half_width,half_width]:
  Models.bevel(root,Vector3(x,0,0),Vector3(0.001,height,depth),"kraft_paper",0.0004)
 for z in [-depth/2,depth/2]:
  Models.bevel(root,Vector3(0,0,z),Vector3(width,height,0.001),"kraft_paper",0.0004)
  triangle(root,Vector3(-half_width,height/2,z*1.02),Vector3(0,-0.004,z*1.02),Vector3(half_width,height/2,z*1.02))
  triangle(root,Vector3(-half_width,-height/2,z*1.025),Vector3(0,0.004,z*1.025),Vector3(half_width,-height/2,z*1.025))
  Models.limb(root,Vector3(-half_width*0.85,height*0.42,z*1.04),Vector3(0,-0.004,z*1.04),0.0003,"#74634e")
  Models.limb(root,Vector3(0,-0.004,z*1.04),Vector3(half_width*0.85,height*0.42,z*1.04),0.0003,"#74634e")
 var flap := Models.group(root,"PaperFlap",Vector3(0,height/2,-depth/2))
 Models.bevel(flap,Vector3(0,0,depth*0.5),Vector3(width,0.001,depth),"kraft_paper",0.0004)
 triangle(flap,Vector3(-half_width,0.0008,0),Vector3(0,0.001,depth*0.78),Vector3(half_width,0.0008,0))
 Models.limb(flap,Vector3(-0.006,0.0015,depth*0.65),Vector3(0.006,0.0015,depth*0.65),0.0005,"steel")
 for x in [-0.006,0.006]:Models.limb(flap,Vector3(x,0.0015,depth*0.65),Vector3(x,0.0015,depth*0.65+0.003),0.0005,"steel")
 var stamp := Label3D.new();stamp.text=Equipment.ITEMS[kind].short+"\n30 шт."
 stamp.font_size=48;stamp.pixel_size=0.00023;stamp.position=Vector3(0,0.002,depth*0.34);stamp.rotation.x=-PI/2
 stamp.modulate=Color("35332a");flap.add_child(stamp)
 var rounds := Models.group(root,"Contents")
 var debris := CartridgeDebris.new()
 var mesh := debris.cartridge_mesh(not rifle,true,id=="svd")
 debris.free()
 for i in range(30):
  var round := MeshInstance3D.new();round.mesh=mesh
  round.position=Vector3((i%10-4.5)*pitch,(i/10-1)*pitch,0.008 if id=="svd" else 0.002)
  rounds.add_child(round)
 for child in [root,flap]:Models.merge_rigid(child)
 return root

static func show_contents(root: Node3D, count: int, opening: float) -> void:
 var flap := root.get_node_or_null("PaperFlap") as Node3D
 if flap==null:return
 flap.rotation.x=-clampf(opening,0,1)*2.2
 var contents := root.get_node("Contents")
 for i in range(contents.get_child_count()):contents.get_child(i).visible=i<count
