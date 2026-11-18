class_name RangeTarget
extends Node3D

# A knock-down target of the training range: chest (№4, 0.5 × 0.5 m) or full
# figure (№6, 0.5 × 1.5 m) on a stand, turned to the shooter. A bullet knocks
# it back and it rises in 2.5 s; hits are counted for the training steps.
const SIZES := {"chest":Vector2(0.5,0.5),"figure":Vector2(0.5,1.5)}
const STAND := 0.35
const DOWN_TIME := 2.5
var id := ""
var kind := "chest"
var hits := 0
var last_hit := Vector3.INF
var down_left := 0.0
var pivot: Node3D
var body: StaticBody3D

func setup(parent: Node3D, target_id: String, spec: Dictionary) -> RangeTarget:
 id=target_id;kind=spec.kind
 parent.add_child(self)
 var at: Vector3=spec.point
 global_position=at
 var from: Vector3=spec.from
 rotation.y=atan2(from.x-at.x,from.z-at.z)
 var size: Vector2=SIZES[kind]
 var wood:=material(Color("6b5a40"))
 # Stand: two posts in a low earth bank that hides them from the line.
 for x in [-0.18,0.18]:part(self,Vector3(x,STAND*0.5,-0.08),Vector3(0.05,STAND,0.05),wood)
 part(self,Vector3(0,0.12,0.25),Vector3(size.x+0.5,0.24,0.35),material(Color("5a5038")))
 pivot=Node3D.new();pivot.position=Vector3(0,STAND,0);add_child(pivot)
 body=StaticBody3D.new();body.set_meta("range_target",self);pivot.add_child(body)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(size.x,size.y,0.04)
 shape.shape=box;shape.position=Vector3(0,size.y*0.5,0);body.add_child(shape)
 # Olive silhouette: head and shoulders, and the body of the full figure.
 var olive:=material(Color("495234"))
 var shoulders:=minf(size.y,0.32)
 part(body,Vector3(0,size.y-0.5+shoulders*0.5,0),Vector3(size.x,shoulders,0.03),olive)
 part(body,Vector3(0,size.y-0.09,0),Vector3(0.22,0.18,0.03),olive)
 if kind=="figure":part(body,Vector3(0,(size.y-0.5)*0.5,0),Vector3(size.x*0.86,size.y-0.5,0.03),olive)
 if str(spec.get("board",""))!="":
  var post:=Node3D.new();post.position=Vector3(size.x*0.5+0.7,0,0);add_child(post)
  part(post,Vector3(0,0.45,0),Vector3(0.05,0.9,0.05),wood)
  part(post,Vector3(0,0.98,0),Vector3(0.62,0.3,0.03),material(Color("d9d3bc")))
  var label:=Label3D.new();label.text=spec.board;label.font_size=48;label.pixel_size=0.005
  label.modulate=Color("2a2a24");label.outline_size=0;label.position=Vector3(0,0.98,0.02)
  post.add_child(label)
 return self

static func material(color: Color) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=0.95
 return m

static func part(parent: Node3D, at: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size;box.material=surface
 mesh.mesh=box;mesh.position=at;parent.add_child(mesh)
 return mesh

func up() -> bool:return down_left<=0.0

# Called by the bullet impact on its plate.
func hit(where: Vector3) -> void:
 if not up():return
 hits+=1;last_hit=where;down_left=DOWN_TIME

func _process(delta: float) -> void:
 down_left=maxf(0.0,down_left-delta)
 var lie:=-1.45 if down_left>0.4 else 0.0
 pivot.rotation.x=move_toward(pivot.rotation.x,lie,delta*(9.0 if lie<0 else 3.5))
