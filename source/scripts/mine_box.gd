class_name MineBox
extends Node3D

# A wooden box for ten 82-mm mines (packed in two rows) or, when a crewman
# falls, the load he carried: the baseplate and the mines left with him.
const CAPACITY := 10
var mines := 0
var plate := false
var noses: Array[Node3D]=[]
var plate_model: Node3D
var box_model: Node3D

func setup(point: Vector3, yaw: float, count: int, with_plate: bool, as_box: bool=true) -> void:
 name="MineBox"
 global_position=point;rotation.y=yaw
 mines=count;plate=with_plate
 box_model=Node3D.new();add_child(box_model)
 Models.part(box_model,Vector3(0,0.13,0),Vector3(0.56,0.26,0.46),"5b6543")
 var lid := Models.part(box_model,Vector3(0,0.36,-0.25),Vector3(0.56,0.03,0.46),"56603f")
 lid.rotation.x=-1.25
 for x in [-0.30,0.30]:Models.part(box_model,Vector3(x,0.17,0),Vector3(0.04,0.04,0.16),"3a3f2f")
 Models.part(box_model,Vector3(0,0.19,0.232),Vector3(0.30,0.05,0.008),"d8d2b0")
 for row in range(2):
  for i in range(5):
   var nose := Models.tube(box_model,Vector3(-0.2+i*0.1,0.27,-0.1+row*0.2),0.036,0.05,"#5d6450",Vector3.UP,0.012)
   noses.append(nose)
 box_model.visible=as_box
 plate_model=Node3D.new();add_child(plate_model)
 Models.tube(plate_model,Vector3(0.62,0.025,0),0.25,0.05,"#4b5240",Vector3.UP)
 refresh()

func refresh() -> void:
 for i in range(noses.size()):noses[i].visible=i<mines
 plate_model.visible=plate
 if not box_model.visible and mines>0:box_model.visible=true

func empty() -> bool:return mines<=0 and not plate

static func mine_model() -> Node3D:
 var root := Node3D.new();root.name="Mine82"
 # O-832DU: teardrop steel body, ten-fin stabiliser, nose fuse.
 Models.tube(root,Vector3(0,0.0,0),0.041,0.12,"#5d6450",Vector3.UP)
 Models.tube(root,Vector3(0,0.10,0),0.041,0.08,"#5d6450",Vector3.UP,0.022)
 Models.tube(root,Vector3(0,0.155,0),0.016,0.04,"#b39d5e",Vector3.UP,0.008)
 Models.tube(root,Vector3(0,-0.09,0),0.041,0.06,"#5d6450",Vector3.UP,0.024)
 Models.tube(root,Vector3(0,-0.17,0),0.012,0.12,"#4a5040",Vector3.UP)
 for i in range(10):
  var fin := Models.part(root,Vector3(cos(i*TAU/10)*0.026,-0.21,sin(i*TAU/10)*0.026),Vector3(0.03,0.07,0.003),"4f5543")
  fin.rotation.y=-i*TAU/10
 Models.tube(root,Vector3(0,-0.14,0),0.02,0.025,"#c9b892",Vector3.UP)
 Models.merge_rigid(root)
 return root
