class_name Idle
extends RefCounted

# Men with nothing to do yet: the defenders before they know of the attack,
# our squads by their vehicles before «По машинах!», the crews by their
# parked vehicles. They behave as people do at a quiet post: stand and look
# into the distance, walk to and fro, sit down, talk in twos, smoke; the
# rifle hangs on its sling. Any alarm ends it (Hostile drops the state when
# he is alerted or under fire). Decisions are made a few times a second at
# most; the pose is a handful of joint angles.
const ACTIVITIES := ["watch","stroll","sit","talk","smoke"]
const WEIGHTS := [3.0,3.0,2.0,2.0,1.5]
const STROLL_SPEED := 1.05

# Starts the quiet life around an anchor, looking toward a point (the side
# the enemy, or the village, lies on).
static func place(actor: Hostile, look_at: Vector3, anchor: Variant=null) -> void:
 var at: Vector3=anchor if anchor is Vector3 else actor.global_position
 actor.idle={"anchor":at,"look":look_at,"activity":"","left":0.0,"spot":at,"partner":null,"clock":randf()*10.0,"phase":randf()*TAU}
 choose(actor)

static func stop(actor: Hostile) -> void:
 if not is_instance_valid(actor) or actor.idle.is_empty():return
 var partner: Variant=actor.idle.get("partner")
 actor.idle={}
 if partner is Hostile and is_instance_valid(partner) and not partner.idle.is_empty() and partner.idle.get("partner")==actor:
  partner.idle.partner=null;partner.idle.left=0.0
 if is_instance_valid(actor.n_rifle):actor.n_rifle.visible=true

static func active(actor: Hostile) -> bool:return not actor.idle.is_empty()

static func choose(actor: Hostile) -> void:
 var idle: Dictionary=actor.idle
 var total:=0.0
 for w in WEIGHTS:total+=w
 var pick:=randf()*total
 var activity:="watch"
 for i in range(ACTIVITIES.size()):
  pick-=WEIGHTS[i]
  if pick<=0.0:activity=ACTIVITIES[i];break
 idle.activity=activity
 idle.partner=null
 var anchor: Vector3=idle.anchor
 match activity:
  "watch":
   idle.left=randf_range(10.0,25.0)
   idle.spot=near(actor,anchor,2.5)
  "stroll":
   idle.left=randf_range(14.0,30.0)
   idle.spot=near(actor,anchor,9.0)
   idle.pause=0.0
  "sit":
   idle.left=randf_range(18.0,45.0)
   idle.spot=near(actor,anchor,3.0)
  "talk":
   idle.left=randf_range(12.0,30.0)
   var partner:=find_partner(actor)
   if partner==null:
    idle.activity="smoke";idle.spot=near(actor,anchor,2.0)
   else:
    idle.partner=partner
    partner.idle.activity="talk";partner.idle.partner=actor;partner.idle.left=idle.left
    var middle: Vector3=(actor.global_position+partner.global_position)*0.5
    var across: Vector3=(partner.global_position-actor.global_position)
    across.y=0
    if across.length()<0.1:across=Vector3.RIGHT
    across=across.normalized()*0.65
    idle.spot=snap(actor,middle-across);partner.idle.spot=snap(partner,middle+across)
  "smoke":
   idle.left=randf_range(10.0,20.0)
   idle.spot=near(actor,anchor,2.5)

static func find_partner(actor: Hostile) -> Hostile:
 var team: Array=actor.game.allies if actor.friendly else actor.game.bots
 var best: Hostile=null
 var best_d:=9.0
 for other in team:
  if other==actor or other.dead or other.idle.is_empty() or other.vehicle!=null:continue
  if other.idle.get("partner")!=null or other.idle.activity=="sit":continue
  var d:=actor.global_position.distance_to(other.global_position)
  if d<best_d:best_d=d;best=other
 return best

static func near(actor: Hostile, anchor: Vector3, radius: float) -> Vector3:
 var p:=anchor+Vector3(randf_range(-radius,radius),0,randf_range(-radius,radius))
 return snap(actor,p)

static func snap(actor: Hostile, point: Vector3) -> Vector3:
 var district: Node3D=actor.game.district
 if district.grid==null:return point
 var cell: Vector2i=district.nearest_cell(district.navigation_cell(point))
 return district.navigation_position(cell)+Vector3.UP*0.05

# Where he goes now (Hostile asks every tick).
static func destination(actor: Hostile, delta: float) -> Vector3:
 var idle: Dictionary=actor.idle
 idle.clock=float(idle.clock)+delta
 idle.left=float(idle.left)-delta
 if float(idle.left)<=0.0:choose(actor)
 var spot: Vector3=idle.spot
 if idle.activity=="stroll":
  if actor.global_position.distance_to(spot)<1.0:
   idle.pause=float(idle.get("pause",0.0))+delta
   # A pause, then on to another point.
   if float(idle.pause)>randf_range(2.5,6.0):
    idle.pause=0.0
    idle.spot=near(actor,idle.anchor,9.0)
   return actor.global_position
 if actor.global_position.distance_to(spot)<0.6:return actor.global_position
 return spot

static func moving(actor: Hostile) -> bool:
 return actor.global_position.distance_to(actor.idle.spot)>0.6 and not (actor.idle.activity=="stroll" and float(actor.idle.get("pause",0.0))>0.0)

# Where he looks: the distance, the man he talks to, the way he walks.
static func look(actor: Hostile, walking: Vector3) -> Vector3:
 var idle: Dictionary=actor.idle
 if walking.length()>0.1:return walking
 var partner: Variant=idle.partner
 if idle.activity=="talk" and partner is Hostile and is_instance_valid(partner):return partner.global_position-actor.global_position
 var far: Vector3=idle.look
 var away:=far-actor.global_position
 away.y=0
 # Now and then a look round.
 var sway:=sin(float(idle.clock)*0.21+float(idle.phase))*0.6
 return away.rotated(Vector3.UP,sway)

# The body: rifle slung, sitting, a hand to the mouth, hands talking.
static func pose(actor: Hostile) -> void:
 var idle: Dictionary=actor.idle
 var t: float=idle.clock
 var activity: String=idle.activity
 var resting:=not moving(actor)
 if activity=="sit" and resting:
  actor.model.position.y=-0.72
  for i in range(2):
   actor.n_legs[i].rotation.x=1.45
   actor.n_knees[i].rotation.x=-0.35-0.25*float(i)
   actor.n_feet[i].rotation.x=-1.1+0.25*float(i)
 if actor.render_far:return
 var rifle: Node3D=actor.n_rifle
 # On the sling across the chest, muzzle down.
 rifle.position=Vector3(0.10,1.06,-0.14)
 rifle.rotation=Vector3(-1.25,0.15,0.35)
 if activity=="sit" and resting:
  rifle.position=Vector3(0.0,0.72,-0.38);rifle.rotation=Vector3(0,PI/2,0)
 var right:=rifle.position+rifle.basis*Vector3(0.012,-0.09,0.085)
 var left:=Vector3(-0.24,0.93,-0.02)
 match activity:
  "smoke":
   if resting and fmod(t+float(idle.phase),7.0)<2.2:right=Vector3(0.03,1.55,-0.16)
  "talk":
   if resting:
    left=Vector3(-0.22,1.18+0.07*sin(t*2.6),-0.30+0.05*sin(t*1.7))
    if fmod(t,5.0)<1.6:right=Vector3(0.20,1.20+0.05*sin(t*3.1),-0.28)
  "watch":
   if resting and fmod(t+float(idle.phase),11.0)<3.0:
    # A hand up against the light, looking out.
    right=Vector3(0.06,1.62,-0.13)
  "sit":
   if resting:left=Vector3(-0.20,0.80,-0.30);right=Vector3(0.20,0.80,-0.30)
 actor.n_head.rotation.y=sin(t*0.37+float(idle.phase))*0.35 if activity in ["watch","smoke"] else 0.0
 actor.pose_arm("Right",right)
 actor.pose_arm("Left",left)
