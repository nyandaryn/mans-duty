class_name VaultTraversal
extends Node3D

# A short crouched capsule follows a checked lift / cross / land path.
# Neither the obstacle nor the character's collisions are ever disabled.
const HEIGHT := 1.08
const RADIUS := 0.30
const MAX_LEDGE := 1.35
const REACH := 1.40
var operator: Operator
var active := false
var elapsed := 0.0
var duration := 1.25
var progress := 0.0
var route: PackedVector3Array
var grips: PackedVector3Array
var start_pitch := 0.0
var start_eye := 1.65
var shape := CapsuleShape3D.new()
var clearance_shape := CapsuleShape3D.new()
var eye := SphereShape3D.new()
var rig: VaultRig

func setup(owner_operator: Operator) -> void:
 operator=owner_operator
 shape.radius=RADIUS;shape.height=HEIGHT
 # Leave a small contact band in speculative sweeps. A standing capsule
 # pressed against a sill is touching it, not embedded in it. The actual
 # movement still uses the full physical radius and collision response.
 clearance_shape.radius=RADIUS-0.012;clearance_shape.height=HEIGHT-0.02
 eye.radius=0.10
 rig=VaultRig.new();operator.camera.add_child(rig);rig.setup(self)

func eligible() -> bool:
 if operator.concussion.active():return false
 return not active and operator.game.running and not operator.game.paused and not operator.game.inventory_open and not operator.game.commands_open and operator.is_on_floor() and not operator.prone and not operator.prone_requested and operator.arm_injury<0.5 and operator.leg_injury<0.5 and operator.injury_time<=0 and operator.blood_loss<0.45 and operator.bandage_time<=0 and operator.switch_delay<=0 and operator.current().phase=="" and operator.current().pending_slot<0 and not operator.field_rig.active()

func ray(from: Vector3, to: Vector3) -> Dictionary:
 return operator.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1,[operator.get_rid()]))

func clear_segment(from: Vector3, to: Vector3, query_shape: Shape3D, offset: Vector3) -> bool:
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape=query_shape;query.transform=Transform3D(Basis.IDENTITY,from+offset)
 query.collision_mask=operator.collision_mask;query.exclude=[operator.get_rid()];query.margin=0.008
 var space := operator.get_world_3d().direct_space_state
 # cast_motion ignores initial overlaps, so explicitly reject those too.
 if not space.intersect_shape(query,1).is_empty():return false
 query.motion=to-from
 if space.cast_motion(query)[0]<0.999:return false
 query.transform.origin=to+offset
 return space.intersect_shape(query,1).is_empty()

func clear_route(points: PackedVector3Array) -> bool:
 for i in range(points.size()-1):
  # Only the initial approach may start in the standing contact band.
  # Once clear of the wall, reserve the full shoulders plus the query margin;
  # a smaller sweep can accept a path that catches a projecting window jamb.
  var swept_shape := clearance_shape if i==0 else shape
  if not clear_segment(points[i],points[i+1],swept_shape,Vector3.UP*(HEIGHT*0.5+0.01)):return false
 return true

func probe() -> Dictionary:
 # A usable opening need not be exactly centred on the player's chest.
 # Check short sideways approaches instead of requiring perfect alignment
 # with both hand contacts. The full body path still has to be unobstructed.
 for lateral in [0.0,0.15,-0.15,0.30,-0.30,0.45,-0.45]:
  var candidate := probe_offset(lateral)
  if not candidate.is_empty():return candidate
 return {}

func probe_offset(lateral: float) -> Dictionary:
 var start := operator.global_position
 var forward := -operator.global_basis.z
 var right := operator.global_basis.x
 var scan_start := start+right*lateral
 for height in [0.15,0.45,0.8,1.15]:
  var face := ray(scan_start+Vector3.UP*height,scan_start+Vector3.UP*height+forward*REACH)
  if face.is_empty() or face.normal.dot(-forward)<0.65:continue
  var sample: Vector3=face.position+forward*0.13
  var top := ray(Vector3(sample.x,start.y+MAX_LEDGE+0.12,sample.z),Vector3(sample.x,start.y+0.06,sample.z))
  if top.is_empty() or top.normal.y<0.75:continue
  var rise: float=top.position.y-start.y
  if rise<0.12 or rise>MAX_LEDGE:continue
  var hands := PackedVector3Array()
  for side in [-1,1]:
   var point: Vector3=top.position+right*side*0.23
   var support := ray(point+Vector3.UP*0.10,point-Vector3.UP*0.13)
   if support.is_empty() or support.normal.y<0.7:break
   hands.append(support.position+Vector3.UP*0.025)
  if hands.size()!=2:continue
  # Align with the opening before planting the palms. Step slightly back
  # when touching a projecting frame so the full capsule can rise past it.
  # A small lift clears uneven footing without shrinking the shoulders.
  var distance_to_face: float=(face.position-start).dot(forward)
  var approach := start+right*lateral+forward*(distance_to_face-0.43)+Vector3.UP*minf(0.10,rise*0.4)
  var lift := Vector3(approach.x,top.position.y+0.065,approach.z)
  # Search beyond the near face, including thick ledges which can be climbed onto.
  for distance in [0.65,0.9,1.2,1.55]:
   var landing: Vector3=Vector3(face.position.x,start.y,face.position.z)+forward*distance
   var floor_y := -INF
   var supported := true
   for x in [-0.22,0.0,0.22]:
    for z in [-0.22,0.0,0.22]:
     var foot: Vector3=landing+right*x+forward*z
     var ground := ray(Vector3(foot.x,lift.y+0.15,foot.z),Vector3(foot.x,top.position.y-1.4,foot.z))
     if ground.is_empty() or ground.normal.y<0.7 or ground.position.y>top.position.y+0.08:
      supported=false;break
     floor_y=maxf(floor_y,ground.position.y)
    if not supported:break
   if not supported:continue
   landing.y=floor_y+0.03
   var cross := Vector3(landing.x,lift.y,landing.z)
   var points := PackedVector3Array([start,approach,lift,cross,landing])
   if not clear_route(points):continue
   # Head lowers before the lift, and remains inside the tucked body while crossing.
   if not clear_segment(start+Vector3.UP*operator.camera.position.y,start+Vector3.UP*0.88,eye,Vector3.ZERO):continue
   return {"route":points,"grips":hands,"rise":rise}
 return {}

func try_start() -> bool:
 if not eligible():return false
 var candidate := probe()
 if candidate.is_empty():return false
 route=candidate.route;grips=candidate.grips
 duration=1.05+float(candidate.rise)*0.30+maxf(0,operator.carried_mass()-18)*0.004
 elapsed=0;progress=0;active=true
 start_pitch=operator.pitch;start_eye=operator.camera.position.y
 operator.velocity=Vector3.ZERO;operator.aim=false;operator.ads_weight=0
 operator.burst=0;operator.firing_sequence_active=false
 operator.blind_mode=0;operator.lean=0;operator.barrel_blocked=false
 operator.crouched=true;operator.body_shape.shape=shape
 operator.body_shape.transform=Transform3D(Basis.IDENTITY,Vector3.UP*HEIGHT*0.5)
 operator.scope_sight.update()
 return true

func point_at(t: float) -> Vector3:
 if t<0.12:return route[0]
 if t<0.28:return route[0].lerp(route[1],smoothstep(0.12,0.28,t))
 if t<0.48:return route[1].lerp(route[2],smoothstep(0.28,0.48,t))
 if t<0.78:return route[2].lerp(route[3],smoothstep(0.48,0.78,t))
 return route[3].lerp(route[4],smoothstep(0.78,0.94,t))

func tick(delta: float) -> void:
 if not active or operator.game.paused:return
 if not operator.game.running or operator.health<=0 or operator.injury_time>0 or operator.leg_injury>=0.5 or operator.arm_injury>=0.5:
  cancel();return
 if progress>0.28 and progress<0.52:
  for grip in grips:
   var support := ray(grip+Vector3.UP*0.06,grip-Vector3.UP*0.08)
   if support.is_empty() or absf(support.position.y-(grip.y-0.025))>0.055:
    cancel();return
 # Bound movement steps even after a stalled frame so the bend in the path
 # cannot become a diagonal shortcut through the sill.
 var left := minf(delta,0.1)
 while left>0 and active:
  var step := minf(left,1.0/120);left-=step
  var next := minf(elapsed+step,duration)
  var target := point_at(next/duration)
  if not clear_segment(operator.global_position,target,clearance_shape,Vector3.UP*(HEIGHT*0.5+0.01)):cancel();return
  var collision := operator.move_and_collide(target-operator.global_position,false,0.002)
  if collision!=null:cancel();return
  elapsed=next;progress=elapsed/duration
  if progress>=1.0:cancel();return
 operator.velocity=Vector3.ZERO
 operator.camera.position=Vector3(0,lerpf(start_eye,0.88,smoothstep(0,0.12,progress)),0)
 var bend := smoothstep(0,0.18,progress)*(1-smoothstep(0.78,1,progress))
 operator.camera.rotation=Vector3(lerpf(start_pitch,-0.30,bend),0,sin(progress*TAU)*0.025*bend)
 operator.camera.fov=lerpf(operator.camera.fov,78,minf(delta*12,1))
 operator.update_damage_pose(HEIGHT-0.15)

func cancel() -> void:
 active=false;rig.visible=false
 operator.velocity=Vector3.ZERO
 # The normal controller restores standing only when there is headroom.
 operator.crouched=true
 operator.camera.rotation=Vector3(operator.pitch,0,0)
 operator.viewmodel.visible=true
