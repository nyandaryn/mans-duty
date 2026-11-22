class_name Mortar
extends Node3D

# 82-mm 2B14 «Podnos»: smoothbore, drop-fired, 1.22 m barrel on a bipod.
const BARREL := 1.22
const COLLAR := 0.70
# The traversing mechanism turns the barrel only a few degrees; a larger switch
# of direction means lifting and re-laying the bipod.
const TRAVERSE := 70
const RELAY_TIME := 6.0
const LOAD_TIME := 2.6
var game: Node3D
var charge := 0
var elevation := 1200
var azimuth := 0
var bipod_azimuth := 0
var relay_left := 0.0
# Where the bipod stood and the barrel pointed before the relay began.
var relay_from := 0
var relay_azimuth := 0
var reload_left := 0.0
var shots := 0
var kick := 0.0
var spread := 1.0
var state := "carried" # carried / assembling / deployed / packing / dropped
# 0 — the parts still in the crew's hands, 1 — laid and ready.
var assembly := 1.0
var base: Node3D
var pivot: Node3D
var legs: Array[MeshInstance3D]=[]
var feet: Array[Vector3]=[]
var sight: Node3D

func setup(owner_game: Node3D) -> void:
 game=owner_game
 name="Mortar2B14"
 base=Node3D.new();base.name="Base";add_child(base)
 var plate := Models.tube(base,Vector3(0,0.025,0),0.25,0.05,"#4b5240",Vector3.UP)
 plate.name="Baseplate"
 for i in range(6):
  var rib := Models.part(base,Vector3(cos(i*PI/3)*0.12,0.055,sin(i*PI/3)*0.12),Vector3(0.22,0.03,0.025),"464c3c")
  rib.rotation.y=-i*PI/3
 Models.tube(base,Vector3(0,0.075,0),0.07,0.05,"#3c4235",Vector3.UP)
 pivot=Node3D.new();pivot.name="Barrel";pivot.position=Vector3(0,0.09,0);add_child(pivot)
 Models.tube(pivot,Vector3(0,BARREL/2,0),0.047,BARREL,"#3f463a",Vector3.UP)
 Models.tube(pivot,Vector3(0,0.06,0),0.058,0.12,"#373d32",Vector3.UP)
 Models.tube(pivot,Vector3(0,BARREL-0.02,0),0.053,0.05,"#333a2f",Vector3.UP)
 Models.marker(pivot,"Muzzle",Vector3(0,BARREL+0.05,0))
 Models.tube(pivot,Vector3(0,COLLAR,0),0.062,0.09,"#30352b",Vector3.UP)
 # MPM-44M sight on its bracket at the left of the collar.
 sight=Node3D.new();sight.name="Sight";add_child(sight)
 Models.part(sight,Vector3.ZERO,Vector3(0.07,0.11,0.09),"2f3329")
 Models.tube(sight,Vector3(0,0.07,0),0.022,0.06,"#24281f",Vector3.UP)
 for i in range(2):
  var leg := Models.tube(self,Vector3.ZERO,0.018,1.0,"#3a4033",Vector3.UP)
  leg.name="BipodLeg"+str(i);legs.append(leg)
 var screw := Models.tube(self,Vector3.ZERO,0.016,1.0,"#2b3027",Vector3.UP)
 screw.name="ElevatingScrew";legs.append(screw)
 visible=false

func place(point: Vector3, mils: int) -> void:
 state="deployed";visible=true
 global_position=point
 rotation=Vector3.ZERO
 azimuth=posmod(mils,MortarBallistics.CIRCLE);bipod_azimuth=azimuth
 relay_left=0;reload_left=0
 reset_parts()
 lay_bipod()

# Deployment in view: baseplate down, bipod raised and spread, barrel seated on
# the plate, sight fitted. Packing plays the same steps backwards.
func begin_assembly(point: Vector3, mils: int) -> void:
 state="assembling";visible=true
 global_position=point;rotation=Vector3.ZERO
 azimuth=posmod(mils,MortarBallistics.CIRCLE);bipod_azimuth=azimuth
 relay_left=0;reload_left=0
 lay_bipod()
 set_assembly(0)

func begin_packing() -> void:
 state="packing"
 set_assembly(1)

# A cancelled pack-up leaves the mortar laid as it was.
func restore() -> void:
 state="deployed";visible=true
 reset_parts()
 pose()

func reset_parts() -> void:
 assembly=1.0
 base.position=Vector3.ZERO;base.rotation=Vector3.ZERO;base.visible=true
 pivot.visible=true;sight.visible=true;sight.scale=Vector3.ONE
 for leg in legs:leg.visible=true

func set_assembly(value: float) -> void:
 assembly=clampf(value,0,1)
 if feet.size()!=2:return
 var t := assembly
 var forward := MortarBallistics.direction(bipod_azimuth)
 # Plate: lowered from the hands and laid flat.
 var down := smoothstep(0.0,0.25,t)
 base.visible=true
 base.position=Vector3(0,lerpf(0.55,0.0,down),0)+forward*lerpf(-0.25,0.0,down)
 base.rotation=Vector3(lerpf(1.15,0.0,down),0,0)
 # Bipod: raised from the folded position and its legs spread.
 var spread_legs := smoothstep(0.25,0.55,t)
 var bore_now := bore()
 var collar_final := Vector3(0,0.09,0)+bore_now*COLLAR
 var middle: Vector3=(feet[0]+feet[1])*0.5
 var folded_head: Vector3=middle.lerp(Vector3(0,0.06,0),0.85)+Vector3.UP*0.04
 var head: Vector3=folded_head.lerp(collar_final,spread_legs)
 for i in range(2):
  legs[i].visible=t>=0.22
  var foot: Vector3=middle.lerp(feet[i],spread_legs)+Vector3(0,0.02,0)
  stick(legs[i],head,foot)
 legs[2].visible=t>=0.22
 stick(legs[2],head,middle.lerp(middle+Vector3.UP*0.25,spread_legs)+Vector3(0,0.02,0))
 # Barrel: carried across the plate, then seated and laid on the bipod head.
 var seat := smoothstep(0.55,0.85,t)
 pivot.visible=t>=0.52
 var held := (forward+Vector3.UP*0.18).normalized()
 pivot.position=(Vector3(0,0.42,0)-held*0.45).lerp(Vector3(0,0.09,0),seat)
 pivot.quaternion=Quaternion(Vector3.UP,held).slerp(Quaternion(Vector3.UP,bore_now),seat)
 # Sight fitted last.
 var fitted := smoothstep(0.85,1.0,t)
 sight.visible=t>=0.85
 sight.scale=Vector3.ONE*maxf(0.01,fitted)
 var side := Vector3(-forward.z,0,forward.x)
 sight.position=collar_final-side*0.11+Vector3.UP*0.04
 sight.rotation=Vector3(0,-MortarBallistics.radians(azimuth),0)

# The part the hands are working on, for the first-person animation.
func work_point() -> Vector3:
 if assembly<0.25:return base.global_position
 if assembly<0.55:return legs[0].global_position.lerp(legs[1].global_position,0.5)
 if assembly<0.85:return pivot.global_position+pivot.global_basis.y*0.5
 return sight.global_position

func drop(point: Vector3) -> void:
 reset_parts()
 state="dropped";visible=true
 global_position=point;rotation=Vector3(0,randf()*TAU,0)
 pivot.quaternion=Quaternion(Vector3.UP,Vector3(0.96,0.10,0).normalized())
 for i in range(legs.size()):stick(legs[i],Vector3(0.20,0.05,0.12+i*0.06),Vector3(0.95,0.05,0.10+i*0.08))
 sight.position=Vector3(0.6,0.12,-0.10)

func carry() -> void:
 state="carried";visible=false
 reset_parts()

# Bipod feet stay planted on the ground where the crew laid them.
func lay_bipod() -> void:
 var forward := MortarBallistics.direction(bipod_azimuth)
 var side := Vector3(-forward.z,0,forward.x)
 var reach := cos(MortarBallistics.radians(1100))*COLLAR+0.05
 feet.clear()
 for sign_side in [-1.0,1.0]:
  var foot: Vector3=global_position+forward*reach+side*sign_side*0.34
  foot.y=game.district.ground_height(foot) if is_instance_valid(game.district) else global_position.y
  feet.append(to_local(foot))
 pose()

func traverse_offset() -> int:
 return wrapi(azimuth-bipod_azimuth,-MortarBallistics.CIRCLE/2,MortarBallistics.CIRCLE/2)

func set_charge(value: int) -> void:charge=clampi(value,0,MortarBallistics.CHARGES.size()-1)
func set_elevation(value: int) -> void:
 elevation=clampi(value,MortarBallistics.ELEVATION_MIN,MortarBallistics.ELEVATION_MAX);pose()
func set_azimuth(value: int) -> void:
 var before := azimuth
 azimuth=posmod(value,MortarBallistics.CIRCLE)
 if absi(traverse_offset())>TRAVERSE:
  if relay_left<=0:relay_from=bipod_azimuth;relay_azimuth=before
  bipod_azimuth=azimuth;relay_left=RELAY_TIME
  lay_bipod()
 pose()

# The universal cancel (~ at the sight): the bipod stays where it was laid,
# the barrel back on the direction it had.
func cancel_relay() -> bool:
 if relay_left<=0:return false
 bipod_azimuth=relay_from;azimuth=relay_azimuth;relay_left=0
 lay_bipod();pose()
 return true

func ready_to_fire() -> bool:return state=="deployed" and relay_left<=0 and reload_left<=0

func bore() -> Vector3:
 var e := MortarBallistics.radians(elevation)
 return (MortarBallistics.direction(azimuth)*cos(e)+Vector3.UP*sin(e)).normalized()

func muzzle() -> Vector3:return pivot.get_node("Muzzle").global_position

func pose() -> void:
 if state!="deployed":return
 pivot.quaternion=Quaternion(Vector3.UP,bore())
 pivot.position=Vector3(0,0.09,0)-bore()*kick*0.05
 var collar := pivot.position+bore()*COLLAR
 if feet.size()==2:
  for i in range(2):stick(legs[i],collar,feet[i])
  stick(legs[2],collar,(feet[0]+feet[1])*0.5+Vector3.UP*0.25)
 var forward := MortarBallistics.direction(azimuth)
 var side := Vector3(-forward.z,0,forward.x)
 sight.position=collar-side*0.11+Vector3.UP*0.04
 sight.rotation=Vector3(0,-MortarBallistics.radians(azimuth),0)

func stick(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
 node.position=(a+b)*0.5
 var along := b-a
 if along.length()<0.001:return
 node.quaternion=Quaternion(Vector3.UP,along.normalized())
 node.scale=Vector3(1,along.length(),1)

func fire(shooter: Node3D) -> bool:
 if not ready_to_fire():return false
 var velocity_scale := 1.0+randfn(0,MortarBallistics.VELOCITY_SPREAD)*spread
 var e := elevation+randfn(0,MortarBallistics.ELEVATION_SPREAD)*spread
 var a := azimuth+randfn(0,MortarBallistics.DIRECTION_SPREAD)*spread
 game.blasts.launch_mine(muzzle(),MortarBallistics.launch_velocity(charge,e,a,velocity_scale),shooter)
 reload_left=LOAD_TIME;kick=1;shots+=1
 game.spatial_shot("mortar_launch",muzzle(),-1)
 if is_instance_valid(game.player):
  game.hearing.exposure=minf(1.6,game.hearing.exposure+0.5/pow(maxf(1,game.player.global_position.distance_to(global_position)/4),1.3))
 var puff := BlastEffect.new();game.blasts.add_child(puff);puff.setup(game,muzzle(),0.35)
 # The report carries far; defenders within earshot learn where it came from.
 for bot in game.bots:
  if not bot.dead and bot.global_position.distance_to(global_position)<140:bot.hear(global_position)
 return true

func _physics_process(delta: float) -> void:
 if not is_instance_valid(game) or not game.running or game.paused or state!="deployed":return
 relay_left=maxf(0,relay_left-delta)
 reload_left=maxf(0,reload_left-delta)
 if kick>0:
  kick=maxf(0,kick-delta*4)
  pose()

static func sound(kind: String) -> AudioStreamWAV:
 # Original synthesised effects, not recordings of this weapon.
 var rate := 22050
 var length: float={"launch":0.9,"whistle":1.6,"blast":1.9}[kind]
 var count := int(rate*length)
 var bytes := PackedByteArray();bytes.resize(count*2)
 var rng := RandomNumberGenerator.new();rng.seed=82014+kind.length()
 var low := 0.0
 var phase := 0.0
 for i in range(count):
  var t := float(i)/rate
  var noise := rng.randf_range(-1,1)
  low=lerpf(low,noise,0.08)
  var sample := 0.0
  if kind=="launch":sample=low*2.2*exp(-t*7)+sin(TAU*48*t)*0.5*exp(-t*9)+noise*0.25*exp(-t*40)
  elif kind=="whistle":
   phase+=TAU*(1500-700*t/length)/rate
   sample=(sin(phase)*0.8+noise*0.08)*0.22*smoothstep(0,1.2,t)*(1-smoothstep(1.45,1.6,t))
  else:sample=noise*0.45*exp(-t*20)+low*2.6*exp(-t*2.6)+sin(TAU*42*t)*0.2*exp(-t*4)
  bytes.encode_s16(i*2,int(clampf(sample,-0.9,0.9)*28000))
 var audio := AudioStreamWAV.new();audio.format=AudioStreamWAV.FORMAT_16_BITS;audio.mix_rate=rate;audio.data=bytes
 return audio
