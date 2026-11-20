class_name BmpTroops
extends Node

# The troop compartment of the BMP-2 and the way in and out of it. Six men
# sit on the two benches along the middle of the hull, back to back, facing
# the firing ports in the sides, three a side; the seventh behind the driver
# and the one in the turret are out of sight beyond the turret basket. The
# left row leaves by the left door, the right row by the right one, the man
# nearest the door first: up from the bench, bent double along the aisle by
# the sponson (the roof is 1.1 m over the floor), head down through the low
# doorway, a step down to the ground and a step away. Boarding goes the other
# way, the front seats filled first, one man at a time in a doorway. Inside
# the men are seen only from the troop compartment (the interior layer); in
# the doorway they are on the world layer too. Vehicle frame: -Z forward,
# +X right; positions are on the floor or the ground under the man.
const FLOOR := 0.50
const SEAT_X := 0.40
const AISLE_X := 0.80
const LANE_X := 0.55
const NEAR_DOOR := 3.00
const OUT_DOOR := 3.42
const LAND_Z := 3.95
const STEP_Z := 4.40
# Past this the head is through the doorway: the world sees him.
const SEEN_Z := 2.60
const PASSAGE := Vector2(0.94,0.10)
const WALK := 1.0
const RUN := 2.6
# The next man of a row gets up this much after the one before him.
const NEXT := 0.85
const PLAYER_SEAT := 3
const PLAYER := "player"
const EYE_STAND := 1.65
# Poses in the frame of the man (-Z ahead): the lean of the body (negative
# is forward), the hips over the feet, thighs and shins against the vertical
# (positive forward), the pitch of the head, where the rifle is held and how
# (muzzle up at PI/2), the swing and lift of the legs in a stride.
const SIT := {"lean":-0.50,"hip":0.26,"thigh":2.09,"shin":0.0,"head":-0.20,"rifle":Vector3(0,0.32,-0.30),"pitch":1.27,"swing":0.0,"lift":0.0}
const DUCK := {"lean":-0.85,"hip":0.40,"thigh":1.11,"shin":-1.11,"head":-0.10,"rifle":Vector3(0.08,0.50,-0.46),"pitch":-0.40,"swing":0.25,"lift":0.2}
const DOOR := {"lean":-1.15,"hip":0.36,"thigh":1.17,"shin":-1.17,"head":-0.30,"rifle":Vector3(0.08,0.40,-0.50),"pitch":-0.60,"swing":0.2,"lift":0.15}
const STAND := {"lean":0.0,"hip":0.825,"thigh":0.0,"shin":0.0,"head":-0.05,"rifle":Vector3(0.14,1.205,-0.28),"pitch":0.0,"swing":0.45,"lift":0.7}
var vehicle: BmpVehicle
var game: Node3D
# Seat index → the man in it (a Hostile, or PLAYER).
var seats := {}
var moves: Array[Dictionary]=[]
var move_of := {}
var player_move := {}
var posed := {}
var clock := 0.0
var out_count := [0,0]

func setup(owner: BmpVehicle) -> void:
 vehicle=owner;game=owner.game;name="Troops"
 process_priority=900
 owner.add_child(self)

# --- Seats ----------------------------------------------------------------------
# 0–5: the benches, odd on the right, the rear pair first; 6 behind the
# driver and 7 in the turret, reached by the passages beside the basket.
static func lane(seat: int) -> int:return seat%2
static func side(seat: int) -> float:return -1.0 if seat%2==0 else 1.0
static func hidden(seat: int) -> bool:return seat>=6
static func seat_z(seat: int) -> float:return float(BmpArt.TROOP_Z[seat/2]) if seat<6 else PASSAGE.y

static func seat_spot(seat: int) -> Vector3:
 if hidden(seat):return Vector3(side(seat)*PASSAGE.x,FLOOR,PASSAGE.y)
 return Vector3(side(seat)*SEAT_X,FLOOR,seat_z(seat))

# Facing the firing port of his side; beyond the basket facing the rear.
static func seat_yaw(seat: int) -> float:
 if hidden(seat):return PI
 return -PI/2 if seat%2==1 else PI/2

func free_seat(order: Array) -> int:
 for seat in order:
  if not seats.has(seat):return seat
 return -1

# Aboard at once (the column formed up) or walking in through his door.
func take(actor: Hostile, walk: bool) -> void:
 var seat:=-1
 if walk:
  var near:=0 if vehicle.to_local(actor.global_position).x<0.0 else 1
  for row in [near,1-near]:
   seat=free_seat([6,4,2,0] if row==0 else [7,5,3,1])
   if seat>=0:break
 else:seat=free_seat([0,1,2,3,4,5,6,7])
 if seat<0:return
 seats[seat]=actor
 posed.erase(actor)
 if walk:start(actor,seat,false,entry_keys(seat,vehicle.to_local(actor.global_position)),0.0)

func seat_of(who) -> int:
 for seat in seats:
  if typeof(seats[seat])==typeof(who) and seats[seat]==who:return seat
 return -1

# The passenger sits in the right row, in the middle.
func seat_player() -> void:
 var who=seats.get(PLAYER_SEAT)
 if who is Hostile:
  seats.erase(PLAYER_SEAT)
  forget_move(who)
  var other:=free_seat([0,1,2,4,5,6,7])
  if other>=0:seats[other]=who;posed.erase(who)
 seats[PLAYER_SEAT]=PLAYER

func unseat_player() -> void:
 if not player_move.is_empty():moves.erase(player_move);player_move={}
 if seats.get(PLAYER_SEAT) is String:seats.erase(PLAYER_SEAT)

func forget(actor: Hostile) -> void:
 var seat:=seat_of(actor)
 if seat>=0:seats.erase(seat)
 forget_move(actor)
 posed.erase(actor)

func forget_move(who) -> void:
 var move: Dictionary=move_of.get(who,{})
 if not move.is_empty():moves.erase(move)
 move_of.erase(who)

func busy() -> bool:return not moves.is_empty()

func moving(who) -> bool:return (who is String and not player_move.is_empty()) or (not who is String and move_of.has(who))

func player_moving() -> bool:return not player_move.is_empty() and float(player_move.wait)<=0.0

# --- Ways in and out ---------------------------------------------------------------
# Everybody out, row by row from the doors.
func unload_all() -> void:
 for row in [0,1]:
  var k:=0
  for seat in [row,row+2,row+4,row+6]:
   if not seats.has(seat):continue
   var who=seats[seat]
   if moving(who):k+=1;continue
   start_exit(seat,float(k)*NEXT)
   k+=1

# Only the passenger: past the knees of whoever still sits by the door.
func unload_player() -> void:
 if not seats.get(PLAYER_SEAT) is String:return
 if not player_move.is_empty():player_move.wait=0.0;return
 start_exit(PLAYER_SEAT,0.0)

func start_exit(seat: int, wait: float) -> void:
 var who=seats[seat]
 if who is String:
  var keys:=player_keys()
  var look:=player_look()
  keys[0].yaw=look.x;keys[0].pitch=look.y
  start(who,seat,true,keys,wait)
 else:start(who,seat,true,exit_keys(seat),wait)

func start(who, seat: int, out: bool, keys: Array, wait: float) -> void:
 var move:={"who":who,"seat":seat,"lane":lane(seat),"out":out,"keys":keys,"key":1,"time":0.0,"wait":wait,"phase":float(seat)*1.3}
 moves.append(move)
 if who is String:player_move=move
 else:move_of[who]=move

static func key(at: Vector3, yaw: float, pose: Dictionary, time: float, gait: float=0.0, arc: float=0.0, stride: float=10.0) -> Dictionary:
 return {"at":at,"yaw":yaw,"pose":pose,"time":time,"gait":gait,"arc":arc,"stride":stride}

# The ground behind a doorway in the vehicle frame (it may stand on a slope).
func ground_y(s: float) -> float:
 var point:=vehicle.to_global(Vector3(s*LANE_X,0,LAND_Z))
 if is_instance_valid(game.district):point.y=game.district.ground_height(point)
 return clampf(vehicle.to_local(point).y,-0.6,0.4)

func exit_keys(seat: int) -> Array:
 var s:=side(seat)
 var keys:=[]
 if hidden(seat):
  keys.append(key(seat_spot(seat),PI,DUCK,0.0))
  var along:=Vector3(s*0.90,FLOOR,1.0)
  keys.append(key(along,PI,DUCK,seat_spot(seat).distance_to(along)/WALK,1.0))
 else:
  keys.append(key(seat_spot(seat),seat_yaw(seat),SIT,0.0))
  keys.append(key(Vector3(s*AISLE_X,FLOOR,seat_z(seat)+0.12),PI,DUCK,0.55))
 var inside:=Vector3(s*LANE_X,FLOOR,NEAR_DOOR)
 keys.append(key(inside,PI,DUCK,Vector3(keys[-1].at).distance_to(inside)/WALK,1.0))
 keys.append(key(Vector3(s*LANE_X,FLOOR,OUT_DOOR),PI,DOOR,0.5,0.6))
 # Each a little apart from the man before him.
 var n:int=out_count[lane(seat)]
 out_count[lane(seat)]=n+1
 var gy:=ground_y(s)
 keys.append(key(Vector3(s*LANE_X,gy,LAND_Z),PI,STAND,0.6,0.3,0.10))
 keys.append(key(Vector3(s*(LANE_X+0.12+0.25*float(n%2)),gy,STEP_Z+0.35*float(n%3)),PI,STAND,0.45,1.0,0.0,5.0))
 return keys

func entry_keys(seat: int, from: Vector3) -> Array:
 var s:=side(seat)
 var gy:=ground_y(s)
 var land:=Vector3(s*LANE_X,gy,LAND_Z)
 var flat:=land-from;flat.y=0.0
 from.y=clampf(from.y,gy-0.3,gy+0.3)
 var keys:=[key(from,atan2(-flat.x,-flat.z) if flat.length()>0.05 else 0.0,STAND,0.0)]
 keys.append(key(land,0.0,STAND,maxf(0.25,flat.length()/RUN),1.3,0.0,5.0))
 # Up over the sill when the doorway is clear.
 var climb:=key(Vector3(s*LANE_X,FLOOR,OUT_DOOR),0.0,DOOR,0.6,0.3,0.08)
 climb.door=true
 keys.append(climb)
 var inside:=Vector3(s*LANE_X,FLOOR,NEAR_DOOR)
 keys.append(key(inside,0.0,DUCK,0.45,0.6))
 if hidden(seat):
  var along:=Vector3(s*0.90,FLOOR,1.0)
  keys.append(key(along,0.0,DUCK,inside.distance_to(along)/WALK,1.0))
  keys.append(key(seat_spot(seat),0.0,DUCK,along.distance_to(seat_spot(seat))/WALK,1.0))
 else:
  var aisle:=Vector3(s*AISLE_X,FLOOR,seat_z(seat)+0.12)
  keys.append(key(aisle,0.0,DUCK,inside.distance_to(aisle)/WALK,1.0))
  keys.append(key(seat_spot(seat),seat_yaw(seat),SIT,0.6))
 return keys

# The passenger's eyes on the way out (positions are the eyes here).
func player_keys() -> Array:
 var keys:=[key(BmpArt.TROOP_EYE,-PI/2,{},0.0)]
 keys[0].pitch=0.0
 var aisle:=Vector3(0.84,1.20,float(BmpArt.TROOP_Z[1])+0.14)
 var inside:=Vector3(0.68,1.16,NEAR_DOOR)
 var gy:=ground_y(1.0)
 for item in [[aisle,-0.12,0.55,0.0,0.0],[inside,-0.10,aisle.distance_to(inside)/WALK,1.0,0.0],[Vector3(0.60,1.04,OUT_DOOR+0.08),-0.18,0.5,0.6,0.0],
   [Vector3(0.60,gy+EYE_STAND,LAND_Z),-0.06,0.6,0.3,0.08],[Vector3(0.68,gy+EYE_STAND,STEP_Z+0.2),0.0,0.45,1.0,0.0]]:
  var k:=key(item[0],PI,{},item[2],item[3],item[4],7.0)
  k.pitch=item[1]
  keys.append(k)
 return keys

# --- Frame ------------------------------------------------------------------------
func _process(delta: float) -> void:
 if game==null or not game.running or game.paused:return
 clock+=delta
 prune()
 # The vehicle drives off: whoever is half way is put where he was going.
 var fast:=absf(vehicle.speed())>2.0
 for move in moves.duplicate():
  if not moves.has(move):continue
  if fast:
   if float(move.wait)>0.0 and move.out:drop(move);continue
   move.key=move.keys.size();move.wait=0.0
   finish(move)
   continue
  if advance(move,delta):finish(move)
 place()

func prune() -> void:
 for seat in seats.keys():
  var who=seats[seat]
  if who is String:continue
  if not is_instance_valid(who) or who.dead or who.vehicle!=vehicle:
   seats.erase(seat)
   forget_move(who)
   posed.erase(who)

func drop(move: Dictionary) -> void:
 moves.erase(move)
 if move.who is String:player_move={}
 else:move_of.erase(move.who)

func advance(move: Dictionary, delta: float) -> bool:
 if float(move.wait)>0.0:
  move.wait=float(move.wait)-delta
  if float(move.wait)>0.0:return false
  move.wait=0.0
  # The passenger gets up from where he is looking.
  if move.who is String:
   var look:=player_look()
   move.keys[0].yaw=look.x;move.keys[0].pitch=look.y
  return false
 var keys: Array=move.keys
 var before:=spot(move)
 var left:=delta
 while left>0.0 and int(move.key)<keys.size():
  var next: Dictionary=keys[move.key]
  if float(move.time)<=0.0 and next.get("door",false) and doorway_busy(move):break
  var need:=float(next.time)-float(move.time)
  if left<need:move.time=float(move.time)+left;left=0.0
  else:left-=need;move.time=0.0;move.key=int(move.key)+1
 var stride:=float(keys[mini(int(move.key),keys.size()-1)].stride)
 move.phase=float(move.phase)+before.distance_to(spot(move))*stride
 return int(move.key)>=keys.size()

func player_look() -> Vector2:
 var command=game.get("bmp")
 if command==null:return Vector2(-PI/2,0)
 return Vector2(-PI/2+command.look.x,command.look.y)

# Somebody else of the same row in the doorway.
func doorway_busy(move: Dictionary) -> bool:
 for other in moves:
  if other==move or other.lane!=move.lane or float(other.wait)>0.0:continue
  var z:=spot(other).z
  if z>2.95 and z<3.88:return true
 return false

# Where he is now and how he stands: the two keys around this moment.
func sample(move: Dictionary) -> Dictionary:
 var keys: Array=move.keys
 var k:=clampi(int(move.key),1,keys.size()-1)
 var a: Dictionary=keys[k-1];var b: Dictionary=keys[k]
 if int(move.key)>=keys.size() or float(move.wait)>0.0:
  var last: Dictionary=keys[-1] if int(move.key)>=keys.size() else keys[0]
  return {"at":last.at,"yaw":last.yaw,"from":last,"to":last,"blend":1.0,"gait":0.0}
 var t:=clampf(float(move.time)/maxf(0.001,float(b.time)),0.0,1.0)
 var e:=smoothstep(0.0,1.0,t)
 var along:=t if float(b.gait)>0.5 else e
 var at:=Vector3(a.at).lerp(b.at,along)+Vector3.UP*sin(PI*t)*float(b.arc)
 var yaw:=lerp_angle(float(a.yaw),float(b.yaw),smoothstep(0.0,1.0,minf(1.0,t/0.45)))
 return {"at":at,"yaw":yaw,"from":a,"to":b,"blend":e,"gait":float(b.gait)}

func spot(move: Dictionary) -> Vector3:return sample(move).at

func finish(move: Dictionary) -> void:
 drop(move)
 var who=move.who
 if not move.out:
  posed.erase(who)
  return
 seats.erase(move.seat)
 var end: Dictionary=move.keys[-1]
 var at:=vehicle.to_global(end.at)
 if who is String:
  var command=game.get("bmp")
  if command!=null and command.vehicle==vehicle and command.seat=="troop":command.step_out(at,vehicle.global_basis.z)
  return
 var actor: Hostile=who
 posed.erase(actor)
 if not is_instance_valid(actor) or actor.dead:return
 vehicle.aboard.erase(actor)
 actor.rotation=Vector3.ZERO
 actor.disembark(vehicle.ground_spot(at,false),vehicle.global_basis.z)
 if vehicle.squad!=null and vehicle.squad.has_method("stepped_out"):vehicle.squad.stepped_out(actor)

# --- Bodies ------------------------------------------------------------------------
# Is the passenger in this compartment to see them?
func viewer_inside() -> bool:
 var command=game.get("bmp")
 return command!=null and command.vehicle==vehicle and command.seat=="troop"

func place() -> void:
 var viewer:=viewer_inside()
 var frame:=vehicle.global_transform
 var parked:=frame.origin+frame.basis.y*0.9
 for seat in seats:
  var who=seats[seat]
  if who is String:continue
  var actor: Hostile=who
  var move: Dictionary=move_of.get(actor,{})
  if move.is_empty() or float(move.wait)>0.0:
   # On his seat.
   if hidden(seat) or not viewer:
    actor.show_aboard(0);actor.global_position=parked;posed.erase(actor)
    continue
   actor.show_aboard(BmpArt.INTERIOR_LAYER)
   actor.global_transform=frame*Transform3D(Basis(Vector3.UP,seat_yaw(seat)),seat_spot(seat))
   if not posed.get(actor,false):
    pose(actor,SIT,0.0,0.0)
    posed[actor]=true
   # Looking about now and then.
   var seed:=float(actor.get_instance_id()%997)
   actor.n_head.rotation.y=sin(clock*0.27+seed)*0.35+sin(clock*0.11+seed*0.5)*0.25
   continue
  posed.erase(actor)
  var now:=sample(move)
  var at: Vector3=now.at
  var end: bool=hidden(seat) and ((move.out and int(move.key)<=1 and float(move.time)<=0.0) or (not move.out and int(move.key)>=move.keys.size()-1 and float(move.time)>=float(move.keys[-1].time)*0.9))
  var mask:=BmpArt.INTERIOR_LAYER|1 if at.z>SEEN_Z else (BmpArt.INTERIOR_LAYER if viewer and not end else 0)
  actor.show_aboard(mask)
  if mask==0:actor.global_position=parked;continue
  # Upright once out on the ground, with the hull inside.
  var tilted:=frame.basis*Basis(Vector3.UP,float(now.yaw))
  var upright:=Basis(Vector3.UP,frame.basis.get_euler().y+float(now.yaw))
  var w:=clampf((at.z-OUT_DOOR)/(LAND_Z-OUT_DOOR),0.0,1.0)
  actor.global_transform=Transform3D(Basis(Quaternion(tilted.orthonormalized()).slerp(Quaternion(upright),w)),frame*at)
  pose(actor,blend(now.from.pose,now.to.pose,float(now.blend)),float(move.phase),float(now.gait))

# The passenger's eyes on the way out, in the vehicle frame.
func player_view() -> Transform3D:
 var now:=sample(player_move)
 var pitch:=lerpf(float(now.from.get("pitch",0.0)),float(now.to.get("pitch",0.0)),float(now.blend))
 var bob:=sin(float(player_move.phase)*2.0)*0.018*minf(1.0,float(now.gait))
 return Transform3D(Basis(Vector3.UP,float(now.yaw))*Basis(Vector3.RIGHT,pitch),Vector3(now.at)+Vector3.UP*bob)

static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
 if t<=0.0:return a
 if t>=1.0:return b
 var out:={}
 for name in a:
  if a[name] is Vector3:out[name]=Vector3(a[name]).lerp(b[name],t)
  else:out[name]=lerpf(float(a[name]),float(b[name]),t)
 return out

# The bot's own rig: the body leaned round its hips, the legs folded under
# it with the soles flat, the head up to look ahead, the rifle in both hands.
static func pose(actor: Hostile, p: Dictionary, phase: float, gait: float) -> void:
 var model:=actor.model
 var lean:=float(p.lean)
 model.rotation=Vector3(lean,0,0)
 model.position=Vector3(0,float(p.hip),0)-Basis(Vector3.RIGHT,lean)*Vector3(0,0.89,0)
 for i in range(2):
  var s:=sin(phase+PI*float(i))*gait
  var thigh:=float(p.thigh)+s*float(p.swing)
  var shin:=float(p.shin)+s*float(p.swing)*0.4-maxf(0.0,-s)*float(p.lift)
  actor.n_legs[i].rotation.x=thigh-lean
  actor.n_knees[i].rotation.x=shin-thigh
  actor.n_feet[i].rotation.x=-shin
 actor.n_head.position=Vector3(0,1.5,0)
 actor.n_head.rotation=Vector3(float(p.head)-lean,0,0)
 var rifle:=actor.n_rifle
 rifle.transform=model.transform.affine_inverse()*Transform3D(Basis(Vector3.RIGHT,float(p.pitch)),p.rifle)
 CharacterArt.pose_arm(model,"Left",rifle.position+rifle.basis*Vector3(-0.035,-0.045,-0.265))
 CharacterArt.pose_arm(model,"Right",rifle.position+rifle.basis*Vector3(0.012,-0.09,0.085))
