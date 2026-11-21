class_name Demolition
extends RefCounted

# Heavy fire brings the village down: a «Grad» rocket on a private house
# collapses it on whoever is inside, a mortar bomb or a Shmel needs a few;
# blasts put the fence panels over. Tuned game damage, not engineering data.
const HOUSE_HP := 100.0
# Damage of a hit on the walls or the roof, of a burst beside them (falling
# off to nothing at "reach" metres from the wall), and how far the blast puts
# fences over.
const HITS := {
 "grad":{"direct":120.0,"near":60.0,"reach":4.5,"fences":7.0},
 "rpo":{"direct":55.0,"near":18.0,"reach":2.5,"fences":3.5},
 "mine":{"direct":38.0,"near":14.0,"reach":2.5,"fences":3.5},
 "cannon":{"direct":5.0,"near":0.0,"reach":0.0,"fences":1.2},
}
# The heap a house leaves: walls and roof slumped into a low mound of broken
# brick, about a metre for a single storey, spilt a little past where the
# walls stood. Its sides are no steeper than a BMP-2 runs up without its nose
# or stern touching (the hull overhangs the end road wheels by 1.4 m at
# 0.43 m off the ground: 16.6°), so the tracks take it whole.
const SPILL := 1.2
const SLOPE := 14.0
# The foot of the mound goes a little into the ground: no step at its edge.
const BURY := 0.1

# The ground is one trimesh: each of its triangles would be a separate
# result of a shape query and crowd out the walls and fences. Left out.
static func ground(district: Node3D) -> Array[RID]:
 if district.has_meta("ground_rids"):return district.get_meta("ground_rids")
 var rids: Array[RID]=[]
 for body in district.find_children("*","StaticBody3D",true,false):
  if body.has_meta("terrain"):rids.append(body.get_rid())
 district.set_meta("ground_rids",rids)
 return rids

static func houses(game: Node3D) -> Array:
 if not is_instance_valid(game.district):return []
 return game.district.get_meta("houses",[])

# Where the blast is in the house's own frame: x/z across the footprint,
# y above its foot.
static func local_point(house: Dictionary, where: Vector3) -> Vector3:
 return Basis(Vector3.UP,float(house.yaw)).inverse()*(where-Vector3(house.center))

static func inside(house: Dictionary, where: Vector3, margin: float=0.0) -> bool:
 var p:=local_point(house,where)
 var half: Vector2=house.half
 return absf(p.x)<half.x+margin and absf(p.z)<half.y+margin and p.y>-1.0 and p.y<float(house.height)+margin

# Distance from the blast to the walls and roof (0 on or inside them).
static func gap(house: Dictionary, where: Vector3) -> float:
 var p:=local_point(house,where)
 var half: Vector2=house.half
 var dx:=maxf(absf(p.x)-half.x,0.0);var dz:=maxf(absf(p.z)-half.y,0.0)
 var dy:=maxf(p.y-float(house.height),0.0)
 return Vector3(dx,dy,dz).length()

static func blast(game: Node3D, where: Vector3, kind: String) -> void:
 var hit: Dictionary=HITS.get(kind,HITS.rpo)
 var reach: float=hit.reach
 for house in houses(game):
  if house.down:continue
  var half: Vector2=house.half
  if Vector2(where.x-house.center.x,where.z-house.center.z).length()>half.length()+reach+1.0:continue
  var distance:=gap(house,where)
  var damage:=0.0
  if distance<=0.6:damage=hit.direct
  elif distance<reach:damage=float(hit.near)*(1.0-distance/reach)
  if damage<=0.0:continue
  house.hp=float(house.hp)-damage
  if house.hp<=0.0:collapse(game,house,where)
 knock_fences(game,where,float(hit.fences))

# Fence panels near the burst go over, the nearest for certain.
static func knock_fences(game: Node3D, where: Vector3, radius: float) -> void:
 if radius<=0.0:return
 var sphere:=SphereShape3D.new();sphere.radius=radius
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.transform.origin=where;query.collision_mask=1
 query.exclude=ground(game.district)
 var count:=0
 for contact in game.district.get_world_3d().direct_space_state.intersect_shape(query,32):
  var body: Object=contact.collider
  if not body is DestructibleSurface or not body.has_meta("crushable") or body.breaking:continue
  var distance: float=body.global_position.distance_to(where)
  if distance>radius*0.6 and randf()<0.45:continue
  var away: Vector3=body.global_position-where;away.y=0
  flatten(game,body,away.normalized()*(1.0+3.0*(1.0-distance/radius)))
  count+=1
  if count>=16:break

# A light piece of the yard pushed over (by a hull or a blast): a falling
# fragment, out of the merged mesh and off the walking map.
static func flatten(game: Node3D, body: DestructibleSurface, direction: Vector3) -> void:
 var district: Node3D=body.district
 if not is_instance_valid(district) or body.breaking:return
 body.breaking=true
 var shape_node: CollisionShape3D=body.get_child(0)
 var size: Vector3=shape_node.shape.size
 var bounds:=AABB(-size/2,size)
 var material: String=body.get_meta("ballistic_material","wood")
 district.fragment(body.global_position,Vector3(size.x,size.y,0.03) if body.has_meta("sheet_scale") else size,body.tint,"wood" if body.has_meta("sheet_scale") else material,direction,body.global_basis)
 if body.has_meta("fence_mesh"):BattleMap.knock_fence(body)
 elif body.has_meta("merged_mesh"):take_out(body.get_meta("merged_mesh"),body.get_meta("merged_range"))
 elif body.batch!=null and body.batch_index>=0:body.batch.set_instance_transform(body.batch_index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
 body.collision_layer=0;body.collision_mask=0
 district.refresh_navigation(body.global_transform*bounds,body.get_instance_id(),[])
 body.queue_free()
 game.spatial_shot("bolt",body.global_position,-6)

# A piece drawn into a merged mesh (a fence panel, a wall corner on a heap)
# leaves it: its vertices fold into one point, the mesh is built again.
static func take_out(instance, span: Vector2i) -> void:
 if not is_instance_valid(instance):return
 var mesh: ColorMesh=instance.get_meta("color_mesh")
 for i in range(span.x,span.y):mesh.vertices[i]=mesh.vertices[span.x]
 instance.mesh=mesh.build(instance.mesh.surface_get_material(0))

# The house comes down: walls and roof into a heap in its footprint, the
# people inside under it, dust, the rumble.
static func collapse(game: Node3D, house: Dictionary, where: Vector3) -> void:
 house.down=true
 var district: District=game.district
 var basis:=Basis(Vector3.UP,float(house.yaw))
 var origin: Vector3=house.center
 var half: Vector2=house.half
 var rng:=RandomNumberGenerator.new();rng.seed=hash(Vector2i(int(origin.x*10),int(origin.z*10)))
 # Whoever is inside is buried; the commander too.
 for actor in [game.player]+game.bots+game.allies:
  if not is_instance_valid(actor):continue
  if actor is Hostile and (actor.dead or actor.vehicle!=null):continue
  if actor is Operator and (actor.get_meta("battle_out",false) or game.player_sheltered()):continue
  if not inside(house,actor.global_position+Vector3.UP*0.3,0.2):continue
  if actor is Hostile:
   actor.set_meta("buried",true)
   actor.take_damage(100000.0)
   actor.call_deferred("hide")
  else:actor.receive_blast(5000.0,1.0,Vector3.DOWN)
 # The house leaves the scene: the closed one out of its block, the walls,
 # floors and furniture of the full one each out of its batch.
 var removed: Array=[]
 if not house.full:
  var block: MeshInstance3D=house.get("block")
  if is_instance_valid(block):
   var mesh: ColorMesh=block.get_meta("color_mesh")
   var span: Vector2i=house.range
   for i in range(span.x,span.y):mesh.vertices[i]=mesh.vertices[span.x]
   block.mesh=mesh.build(block.mesh.surface_get_material(0))
  if is_instance_valid(house.body):removed.append(house.body)
 else:
  # Porch and annex go with it, the yard walls four metres off stand.
  var box:=BoxShape3D.new();box.size=Vector3(half.x*2+5.0,float(house.height)+1.0,half.y*2+5.0)
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=box;query.collision_mask=1
  query.exclude=ground(district)
  query.transform=Transform3D(basis,origin+Vector3.UP*float(house.height)*0.5)
  for contact in district.get_world_3d().direct_space_state.intersect_shape(query,512):
   var body: Object=contact.collider
   if not body is DestructibleSurface or body.has_meta("indestructible") or body.has_meta("crushable") or body.has_meta("rubble"):continue
   if removed.has(body) or not inside(house,body.global_position,2.4):continue
   removed.append(body)
 for body: DestructibleSurface in removed:
  if body.batch!=null and body.batch_index>=0:body.batch.set_instance_transform(body.batch_index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
  body.breaking=true
  body.collision_layer=0;body.collision_mask=0
  district.navigation_obstacles.remove_body(body.get_instance_id())
  body.queue_free()
 var heap:=rubble(district,house,rng)
 var reach:=Vector3(half.x+0.5,0,half.y+0.5)
 district.navigation_rubble=true
 district.refresh_navigation(AABB(origin-Vector3(reach.length(),0.5,reach.length()),Vector3(reach.length()*2,3.0,reach.length()*2)),0,[heap])
 # The vehicles' map: the heap is open to the tracks.
 var battle=game.get("battle")
 if battle!=null and battle.vehicle_grid!=null:
  var spread:=Vector2(mound(house).base).length()
  BmpRoutes.open_rubble(district,battle.vehicle_grid,AABB(origin-Vector3(spread,0.5,spread),Vector3(spread*2,3.0,spread*2)))
 # Dust over the heap, brick and slate thrown off the top.
 var effects:=GradEffects.shared(game)
 for k in range(14):
  var at:=origin+basis*Vector3(rng.randf_range(-half.x,half.x),rng.randf_range(0.6,3.5),rng.randf_range(-half.y,half.y))
  effects.puff(at,rng.randf_range(2.6,5.2),rng.randf_range(0.5,0.66),Vector3(rng.randf_range(-0.6,0.6),0.25,rng.randf_range(-0.6,0.6)))
 for k in range(5):
  var at:=origin+basis*Vector3(rng.randf_range(-half.x,half.x)*0.8,float(house.height)*0.6,rng.randf_range(-half.y,half.y)*0.8)
  var away: Vector3=at-where;away.y=0
  district.fragment(at,Vector3(rng.randf_range(0.3,0.8),0.22,rng.randf_range(0.3,0.6)),Color(house.paint),"brick",away.normalized()*3.0+Vector3.UP*2.0,Basis.from_euler(Vector3(rng.randf(),rng.randf()*TAU,rng.randf())))
 game.spatial_shot("collapse",origin+Vector3.UP*2.0,4)

# The mound in the house's own frame: half its base (the footprint and the
# spill), its height, how far in from the foot its sides rise.
static func mound(house: Dictionary) -> Dictionary:
 var half: Vector2=house.half
 var base:=half+Vector2.ONE*SPILL
 var height:=clampf(minf(half.x,half.y)*0.25,0.6,1.1)
 var run:=(height+BURY)/tan(deg_to_rad(SLOPE))
 # A shed leaves too little for the sides: a lower heap, not a steeper one.
 var room:=minf(base.x,base.y)-0.3
 if run>room:
  run=room
  height=room*tan(deg_to_rad(SLOPE))-BURY
 return {"base":base,"height":height,"run":run}

# Height of the heap over the ground at a point (x, z) of the house's frame:
# a flat top, the sides down to the buried foot.
static func mound_height(shape: Dictionary, at: Vector2) -> float:
 var base: Vector2=shape.base
 var edge:=minf(base.x-absf(at.x),base.y-absf(at.y))
 return -BURY+(float(shape.height)+BURY)*clampf(edge/float(shape.run),0.0,1.0)

# The heap: broken brick over a low mound, slabs of the roof and beams on
# it, the corners of the walls broken off at uneven heights. The mound is one
# solid body: it stops bullets, a vehicle drives over it, and on the walking
# map it keeps to the footprint the house had. The corners stand apart: a
# BMP or a blast puts them over like a fence.
static func rubble(district: District, house: Dictionary, rng: RandomNumberGenerator) -> DestructibleSurface:
 var basis:=Basis(Vector3.UP,float(house.yaw))
 var origin: Vector3=house.center
 var half: Vector2=house.half
 var paint:=Color(house.paint);var roof:=Color(house.roof)
 var shape:=mound(house)
 var base: Vector2=shape.base
 var height: float=shape.height
 var run: float=shape.run
 var lift:=atan((height+BURY)/run)
 var surface:=func(at: Vector2) -> Vector3:
  var p:=origin+basis*Vector3(at.x,0,at.y)
  p.y=district.ground_height(p)+mound_height(shape,at)
  return p
 var mesh:=ColorMesh.new()
 # The mound itself, lumpy, in brick dust and plaster.
 var dust: Array=[paint.darkened(0.4),paint.darkened(0.3),Color("6e6a60"),Color("7a7468"),Color("9a5a44").darkened(0.25)]
 var nx:=maxi(2,ceili(base.x*2.0/1.1));var nz:=maxi(2,ceili(base.y*2.0/1.1))
 var grid: Array[Vector3]=[]
 for j in range(nz+1):
  for i in range(nx+1):
   var p: Vector3=surface.call(Vector2(-base.x+base.x*2.0*i/nx,-base.y+base.y*2.0*j/nz))
   if i>0 and i<nx and j>0 and j<nz:p.y+=rng.randf_range(0.0,0.12)
   grid.append(p)
 for j in range(nz):
  for i in range(nx):
   var row:=j*(nx+1)
   mesh.quad(grid[row+i],grid[row+i+1],grid[row+nx+2+i],grid[row+nx+1+i],dust[rng.randi()%dust.size()],Vector3.UP)
 # Pieces lying on it, along the slope where they lie on a side.
 var colors: Array=[paint,paint.darkened(0.3),Color("9a5a44"),Color("8f8a7c"),roof,Color("2b2621"),roof.darkened(0.2)]
 var pieces:=int(clampf(half.x*half.y*2.4,36,90))
 for k in range(pieces):
  var at:=Vector2(rng.randf_range(-1,1)*(base.x-0.4),rng.randf_range(-1,1)*(base.y-0.4))
  var size:=Vector3(rng.randf_range(0.4,1.2),rng.randf_range(0.15,0.4),rng.randf_range(0.4,1.0))
  var tilt:=0.3
  match k%7:
   5:size=Vector3(rng.randf_range(1.8,3.2),0.14,0.16);tilt=0.25
   4,6:size=Vector3(rng.randf_range(1.2,2.4),0.07,rng.randf_range(0.9,1.6));tilt=0.2
  var normal:=Vector3.UP
  var edge_x:=base.x-absf(at.x);var edge_z:=base.y-absf(at.y)
  if minf(edge_x,edge_z)<run:
   var out:=Vector3(signf(at.x),0,0) if edge_x<edge_z else Vector3(0,0,signf(at.y))
   normal=Vector3.UP*cos(lift)+out*sin(lift)
  var lay:=Basis(Quaternion(Vector3.UP,normal))*Basis.from_euler(Vector3(rng.randf_range(-tilt,tilt),rng.randf()*TAU,rng.randf_range(-tilt,tilt)))
  mesh.box(Transform3D(basis*lay,surface.call(at)+basis*(normal*size.y*0.15)),size,colors[k%colors.size()])
 # The corners of the walls, each wing drawn apart to be taken out alone.
 var corners: Array=[]
 for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
  if rng.randf()<0.35:continue
  var high:=rng.randf_range(0.9,2.6)
  var along_x:=minf(rng.randf_range(0.8,2.4),half.x);var along_z:=minf(rng.randf_range(0.8,2.4),half.y)
  for wing in [[Vector2(corner.x*(half.x-along_x*0.5),corner.y*(half.y-0.15)),Vector3(along_x,high,0.3)],[Vector2(corner.x*(half.x-0.15),corner.y*(half.y-along_z*0.5)),Vector3(0.3,high*0.8,along_z)]]:
   var at: Vector2=wing[0]
   var size: Vector3=wing[1]+Vector3(0,0.2,0)
   var center:=Vector3(origin.x,0,origin.z)+basis*Vector3(at.x,0,at.y)
   center.y=district.ground_height(center)-0.2+size.y*0.5
   var first:=mesh.vertices.size()
   mesh.box(Transform3D(basis,center),size,paint)
   corners.append([center,size,Vector2i(first,mesh.vertices.size())])
 var instance:=MeshInstance3D.new();instance.name="Rubble"
 instance.mesh=mesh.build(ColorMesh.material(district))
 instance.set_meta("color_mesh",mesh)
 district.add_child(instance)
 for item in corners:
  var wall:=district.collider(item[0],item[1],"brick") as DestructibleSurface
  wall.basis=basis
  wall.tint=paint
  wall.set_meta("surface_color",paint)
  wall.set_meta("indestructible",true)
  wall.set_meta("crushable",true)
  wall.set_meta("merged_mesh",instance);wall.set_meta("merged_range",item[2])
 # The mound's body: the hull of its foot and its top.
 var body:=district.collider(origin,Vector3(half.x*2,height,half.y*2),"brick") as DestructibleSurface
 body.basis=basis
 var points:=PackedVector3Array()
 var low:=INF;var top:=-INF
 for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
  for inner in [base,base-Vector2.ONE*run]:
   var local:=basis.inverse()*(Vector3(surface.call(corner*inner))-origin)
   points.append(local)
   low=minf(low,local.y);top=maxf(top,local.y)
 var hull:=ConvexPolygonShape3D.new();hull.points=points
 var collision: CollisionShape3D=body.get_child(0)
 collision.shape=hull
 collision.set_meta("navigation_box",AABB(Vector3(-half.x,low,-half.y),Vector3(half.x*2,top-low,half.y*2)))
 body.tint=paint.darkened(0.3)
 body.set_meta("surface_color",paint.darkened(0.3))
 body.set_meta("indestructible",true)
 body.set_meta("rubble",true)
 # The cells the heap covers: the vehicles' routes and their drivers.
 var cells: Dictionary=district.get_meta("rubble_cells",{})
 var scale: float=district.navigation_scale
 var reach:=base.length()
 for z in range(floori((origin.z-reach)*scale),ceili((origin.z+reach)*scale)+1):
  for x in range(floori((origin.x-reach)*scale),ceili((origin.x+reach)*scale)+1):
   var local:=basis.inverse()*Vector3(x/scale-origin.x,0,z/scale-origin.z)
   if absf(local.x)<base.x and absf(local.z)<base.y:cells[Vector2i(x,z)]=true
 district.set_meta("rubble_cells",cells)
 return body

static func sound() -> AudioStreamWAV:
 # Original synthesised effect: the crack of the walls, the long rumble of
 # the masonry coming down, bricks rattling out of it.
 var rate:=22050
 var length:=3.2
 var count:=int(rate*length)
 var bytes:=PackedByteArray();bytes.resize(count*2)
 var rng:=RandomNumberGenerator.new();rng.seed=40719
 var low:=0.0;var mid:=0.0
 var rattle:=0.0
 for i in range(count):
  var t:=float(i)/rate
  var noise:=rng.randf_range(-1,1)
  low=lerpf(low,noise,0.035)
  mid=lerpf(mid,noise,0.22)
  if rng.randf()<0.0016*(1.0-t/length):rattle=rng.randf_range(0.4,0.9)
  rattle*=0.993
  var sample:=noise*0.5*exp(-t*14.0)+low*3.4*smoothstep(0.0,0.15,t)*exp(-t*0.95)+mid*0.35*exp(-t*1.6)+rattle*noise*0.6
  bytes.encode_s16(i*2,int(clampf(sample,-0.9,0.9)*26000))
 var audio:=AudioStreamWAV.new();audio.format=AudioStreamWAV.FORMAT_16_BITS;audio.mix_rate=rate;audio.data=bytes
 return audio
