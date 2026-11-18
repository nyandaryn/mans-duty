class_name TrainingRange
extends RefCounted

# «ПОЛІГОН»: the flat range the rifleman, sniper and mortarman courses run on.
# A firing line with lanes to 25, 50 and 100 m, a low wall to vault and a
# concrete block to lean from, a bunker for the RPO-A, a sniper mat with
# figures at 300 and about 500 m, a mortar pit with an enemy position 362 m
# away on the 1:10 000 sheet. North is −Z; a berm closes the range at 420 m.
const ID := "range"
const TITLE := "ПОЛІГОН"
const SPAWN := Vector3(0,0.2,168)
const LINE := Vector3(0,0,150)
const BLOCK := Vector3(7,0,150)
const WALL := Vector3(-14,0,140)
const BUNKER := Vector3(-24,0,32)
const SNIPER := Vector3(32,0,160)
const PIT := Vector3(70,0,172)
const POSITION := Vector3(-50,0,-170)
const BERM_Z := -420.0
# Knock-down targets: where they stand, what they are, the board beside them.
const TARGETS := {
 "t25":{"point":Vector3(-4,0,125),"kind":"chest","board":"25 м","from":LINE},
 "t50":{"point":Vector3(4,0,100),"kind":"chest","board":"50 м","from":LINE},
 "t100":{"point":Vector3(0,0,50),"kind":"figure","board":"100 м","from":LINE},
 "s300":{"point":Vector3(32,0,-140),"kind":"figure","board":"300 м","from":SNIPER},
 # No board: the range is read off the reticle.
 "s500":{"point":Vector3(14,0,-339),"kind":"figure","board":"","from":SNIPER},
 "p1":{"point":POSITION+Vector3(-3,0,1),"kind":"figure","board":"","from":PIT},
 "p2":{"point":POSITION+Vector3(2,0,-1),"kind":"figure","board":"","from":PIT},
 "p3":{"point":POSITION+Vector3(5,0,3),"kind":"chest","board":"","from":PIT}}

static func distance(a: Vector3, b: Vector3) -> float:
 return Vector2(a.x-b.x,a.z-b.z).length()

static func build(world: District) -> void:
 world.map_id=ID
 world.map_title=TITLE
 world.grid_limit=60
 world.player_spawn=SPAWN
 world.player_spawn_yaw=0.0
 world.spawn_points.clear()
 world.random.seed=4407
 # Mown field in stripes along the lanes, the firing line and its gravel.
 world.box(Vector3(0,-0.3,-90),Vector3(420,0.6,700),Color("5f6646"),true,"earth")
 for k in range(-7,8):
  if k%2==0:world.box(Vector3(k*14,0.01,-90),Vector3(14,0.02,700),Color("677048"))
 world.box(LINE+Vector3(0,0.02,0),Vector3(44,0.04,7),Color("7a7462"))
 for x in range(-20,21,8):world.box(LINE+Vector3(x,0.05,-3.4),Vector3(0.12,0.02,0.6),Color("d8d4c0"))
 world.box(LINE+Vector3(0,0.03,18),Vector3(3,0.06,36),Color("7a7462"))
 # Lean from the block, vault the wall.
 world.box(BLOCK+Vector3(0,0.65,0),Vector3(1.7,1.3,0.6),Color("8e8f86"),true)
 world.box(WALL+Vector3(0,0.5,0),Vector3(4.0,1.0,0.35),Color("8a7f6a"),true)
 world.box(WALL+Vector3(0,1.03,0),Vector3(4.1,0.06,0.42),Color("6f6858"))
 # Bunker for the RPO-A: earth and logs with a dark embrasure facing the line,
 # a bare earth mound round it so it reads at 120 m.
 world.box(BUNKER+Vector3(0,0.3,0),Vector3(8.5,0.6,6.5),Color("74644a"),true,"earth")
 world.box(BUNKER+Vector3(0,0.8,0),Vector3(5.0,1.6,3.6),Color("5d5240"),true,"earth")
 world.box(BUNKER+Vector3(0,1.7,0),Vector3(5.4,0.22,4.0),Color("6b5c42"),true,"wood")
 world.box(BUNKER+Vector3(0,1.05,1.81),Vector3(2.4,0.34,0.04),Color("1b1a16"))
 for i in range(5):world.rod(BUNKER+Vector3(-2.6,1.86,-1.6+i*0.8),BUNKER+Vector3(2.6,1.86,-1.6+i*0.8),0.13,"6a5a40")
 # Sniper mat and the mortar pit, a ring of sandbags open at the back.
 world.box(SNIPER+Vector3(0,0.03,0),Vector3(1.3,0.06,2.6),Color("4b5136"))
 for k in range(10):
  var a:=PI*0.62+k*TAU/13.0
  world.box(PIT+Vector3(cos(a)*2.6,0.3,sin(a)*2.6),Vector3(1.4,0.6,0.55),Color("8a7a58"),true,"fabric")
 world.box(PIT+Vector3(0,0.02,0),Vector3(4.2,0.04,4.2),Color("6a604a"))
 # The enemy position for the mortar: a sandbag nest and a burnt-out car.
 for k in range(9):
  var a:=k*TAU/11.0
  world.box(POSITION+Vector3(cos(a)*5.5,0.35,sin(a)*5.5),Vector3(2.0,0.7,0.7),Color("7d7052"),true,"fabric")
 world.car(POSITION+Vector3(9,0,-6),Color("4a3e33"),0.6,true)
 # Range control tower behind the line: four posts, a deck, a roof.
 var tower:=LINE+Vector3(-38,0,12)
 for corner in [Vector3(-1.5,0,-1.5),Vector3(1.5,0,-1.5),Vector3(-1.5,0,1.5),Vector3(1.5,0,1.5)]:
  world.box(tower+corner+Vector3(0,2.6,0),Vector3(0.22,5.2,0.22),Color("6b5a40"),true,"wood")
 world.box(tower+Vector3(0,3.2,0),Vector3(3.6,0.16,3.6),Color("7a6748"),true,"wood")
 world.box(tower+Vector3(0,3.75,-1.75),Vector3(3.6,0.9,0.06),Color("7a6748"))
 world.box(tower+Vector3(0,5.3,0),Vector3(4.2,0.14,4.2),Color("4a4a44"))
 for i in range(8):world.box(tower+Vector3(1.9,0.4*i+0.2,-1.0+i*0.3),Vector3(0.7,0.06,0.25),Color("6b5a40"))
 # Red flags on the berm: the range is live.
 for x in [-150,-50,50,150]:
  world.rod(Vector3(x,6,BERM_Z),Vector3(x,10.5,BERM_Z),0.06,"5a5a55")
  world.box(Vector3(x+0.75,9.9,BERM_Z),Vector3(1.5,1.0,0.03),Color("b3261e"))
 # Signs.
 board(world,LINE+Vector3(-24,0,1),"ВОГНЕВИЙ РУБІЖ")
 board(world,SNIPER+Vector3(2.2,0,0.8),"СНАЙПЕР")
 board(world,PIT+Vector3(3.6,0,1.5),"МІНОМЕТ")
 # Berm closing the range, tree lines on the flanks, fence round it.
 world.box(Vector3(0,3.0,BERM_Z),Vector3(420,6,12),Color("62563e"),true,"earth")
 for z in range(240,-400,-24):
  for side in [-1,1]:world.tree(Vector3(side*(188+world.random.randf_range(-5,5)),0,z+world.random.randf_range(-6,6)))
 for x in range(-150,151,30):world.tree(Vector3(x+world.random.randf_range(-6,6),0,236))
 for side in [-1,1]:world.collider(Vector3(side*205,1.5,-90),Vector3(0.2,3,700))
 world.collider(Vector3(0,1.5,255),Vector3(420,3,0.2))
 # What the 1:10 000 sheet shows besides the trees.
 for spec in [[BUNKER,Vector2(5,3.6)],[WALL,Vector2(4,0.6)],[BLOCK,Vector2(1.7,0.6)],[PIT,Vector2(5,5)],[POSITION,Vector2(11,11)]]:
  var p: Vector3=spec[0];var s: Vector2=spec[1]
  world.map_marks.append(PackedVector2Array([Vector2(p.x-s.x*0.5,p.z-s.y*0.5),Vector2(p.x+s.x*0.5,p.z-s.y*0.5),Vector2(p.x+s.x*0.5,p.z+s.y*0.5),Vector2(p.x-s.x*0.5,p.z+s.y*0.5)]))

static func board(world: District, at: Vector3, text: String) -> void:
 world.rod(at,at+Vector3.UP*1.6,0.04,"5b5644")
 world.box(at+Vector3(0,1.75,0),Vector3(1.9,0.42,0.04),Color("d9d3bc"))
 var label:=Label3D.new();label.text=text;label.font_size=40;label.pixel_size=0.0055
 label.modulate=Color("2a2a24");label.outline_size=0
 label.position=at+Vector3(0,1.75,0.03)
 world.add_child(label)
