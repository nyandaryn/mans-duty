# Body armour worn over CharacterArt's soldier (root "Soldier": ground y=0,
# front -Z, the soldier's left is -X). Three vests, all built procedurally:
#
# * «Корсар М3с» (Темп-3000, ЗСУ): MM-14 cover wrapped round the torso over the
#   plate pockets, seven PALS rows front and back, side wings with four rows
#   closing over the front, padded straps with webbing, a velcro name flap and
#   drag handle on the back, a thick padded collar open at the throat and
#   higher at the nape, short pauldron-like shoulder protectors and a U-shaped
#   groin flap hung from two buckles under the front panel.
# * 6Б45 «Ратник»: EMR cover, boxier, olive binding on the edges, seven olive
#   PALS rows front and back plus rows on the sides, a waist strap with two
#   side-release buckles, a taller and thicker collar, big shoulder protectors
#   reaching towards the elbow with a velcro strap and tab, and a long groin
#   flap tapering to a rounded point.
# * Plate carrier: ranger green 250x300 mm plate bags with a shooter's cut, a
#   loop-velcro admin panel, PALS rows, laser-cut cummerbund with a
#   side-release buckle on each side, webbing straps under coyote shoulder
#   pads; no collar, pauldrons or groin flap, torso sides open above the
#   cummerbund.
#
# Photo sources: Темп-3000 catalogue image «KORSAR M3M» (spetstechnoexport.com/
# product/korsar-m3m); Корсар М3м on an exhibition stand (armyinform.com.ua,
# 2019-08-03 «Бронежилети "Корсар" для ЗСУ: позиція виробника»); Korsar-M3 back
# panel with a tape measure (bodyarmornews.com «The body armor of the war in
# Ukraine»); Wikimedia Commons «6B45 body armor.jpg», «6B45 bulletproof vest
# 2015.jpg», «6B45 bulletproof vest - InnovationDay2013part1-61.jpg» (Vitaly V.
# Kuzmin); the owner's reference photos.
#
# Node layout made by attach(): "Vest" under the model root (torso, straps,
# collar, buckles), "VestShoulder" under LeftArm and RightArm (arm-local, so it
# follows the upper arm), "VestGroin" under the root with its origin on the
# flap's top edge. Geometry is built once per kind and shared by every soldier.
class_name VestArt
extends RefCounted

const KINDS := ["korsar","ratnik","carrier"]

# Wrap surface of the current vest: stations (y, half width, half depth, centre
# z) of a superellipse whose exponent `sq` (<1) squares the cross-section.
static var prof: Array[Vector4]=[]
static var sq := 0.6
# Per kind and part: [group position, merged meshes]. Only resources are kept,
# so every soldier shares the same vertex buffers and nothing leaks at exit.
static var templates: Dictionary={}

static func attach(model: Node3D, kind: String) -> Node3D:
	remove(model)
	if not kind in KINDS:return null
	materials()
	if not templates.has(kind):templates[kind]=build(kind)
	var parts: Dictionary=templates[kind]
	var vest := instance(model,"Vest",parts["Vest"])
	if parts.has("VestGroin"):instance(model,"VestGroin",parts["VestGroin"])
	for side in ["Left","Right"]:
		var arm := model.get_node_or_null(side+"Arm") as Node3D
		if arm!=null and parts.has(side):instance(arm,"VestShoulder",parts[side])
	vest.set_meta("vest",kind)
	return vest

static func instance(parent: Node3D, label: String, part: Array) -> Node3D:
	var group := Models.group(parent,label,part[0])
	for mesh in part[1]:
		var node := MeshInstance3D.new()
		node.mesh=mesh
		group.add_child(node)
	return group

static func remove(model: Node3D) -> void:
	for path in ["Vest","VestGroin","LeftArm/VestShoulder","RightArm/VestShoulder"]:
		var old := model.get_node_or_null(path)
		if old!=null:
			old.get_parent().remove_child(old)
			old.free()

# Vest materials are separate from the uniform ("uniform*"/"cloth" names are
# what Wardrobe.dress replaces), so the cover keeps its own camouflage.
static func materials() -> void:
	if Models.materials.has("vest_hardware"):return
	for spec in [["vest_mm14","ua_pixel",Color(0.9,0.9,0.85)],["vest_emr","rf_digital",Color(0.96,0.98,0.93)]]:
		var camo := Wardrobe.fabric(spec[1]).duplicate() as StandardMaterial3D
		camo.resource_name=spec[0]
		camo.albedo_color=spec[2]
		camo.uv1_scale=Vector3.ONE*3.7
		Models.materials[spec[0]]=camo
	# Cloth noise averages 0.775: colours are set brighter than the target.
	for spec in [["vest_ranger","#646b53"],["vest_coyote","#a68f6b"],["vest_web_ua","#8f875a"],["vest_web_rf","#707a59"]]:
		var cloth := Models.surface("cloth").duplicate() as StandardMaterial3D
		cloth.resource_name=spec[0]
		cloth.albedo_color=Color(spec[1])
		cloth.roughness=0.95
		cloth.cull_mode=BaseMaterial3D.CULL_DISABLED
		Models.materials[spec[0]]=cloth
	var hard := StandardMaterial3D.new()
	hard.resource_name="vest_hardware"
	hard.albedo_color=Color("25282a")
	hard.roughness=0.55
	Models.materials["vest_hardware"]=hard

static func build(kind: String) -> Dictionary:
	var holder := Node3D.new()
	var parts: Dictionary={"Vest":Models.group(holder,"Vest")}
	if kind!="carrier":
		parts["VestGroin"]=Models.group(holder,"VestGroin")
		for side in ["Left","Right"]:parts[side]=Models.group(Models.group(holder,side+"Arm"),"VestShoulder")
	if kind=="korsar":korsar(parts)
	elif kind=="ratnik":ratnik(parts)
	else:carrier(parts)
	var out: Dictionary={}
	for key in parts:
		var group: Node3D=parts[key]
		Models.merge_rigid(group)
		var meshes: Array[Mesh]=[]
		for child in group.get_children():
			if child is MeshInstance3D:meshes.append(child.mesh)
		out[key]=[group.position,meshes]
	holder.free()
	return out

# --- Wrap surface --------------------------------------------------------

static func profile(y: float) -> Vector3:
	var n := prof.size()
	if y<=prof[0].x:return Vector3(prof[0].y,prof[0].z,prof[0].w)
	if y>=prof[n-1].x:return Vector3(prof[n-1].y,prof[n-1].z,prof[n-1].w)
	var i := 0
	while prof[i+1].x<y:i+=1
	var p0 := prof[maxi(i-1,0)]
	var p1 := prof[i]
	var p2 := prof[i+1]
	var p3 := prof[mini(i+2,n-1)]
	var t := (y-p1.x)/(p2.x-p1.x)
	return Vector3(p1.y,p1.z,p1.w).cubic_interpolate(Vector3(p2.y,p2.z,p2.w),Vector3(p0.y,p0.z,p0.w),Vector3(p3.y,p3.z,p3.w),t)

static func spow(v: float, e: float) -> float:
	return signf(v)*pow(absf(v),e)

# Angle 0 is the right side (+X), PI/2 the back, 3PI/2 the front.
static func around(theta: float, y: float, off: float=0.0) -> Vector3:
	var p := profile(y)
	return Vector3((p.x+off)*spow(cos(theta),sq),y,p.z+(p.y+off)*spow(sin(theta),sq))

static func normal(theta: float, y: float, off: float) -> Vector3:
	return (around(theta,y,off+0.01)-around(theta,y,off)).normalized()

# Angle of a point at height y and lateral offset x, on the front or the back.
static func angle(x: float, y: float, back: bool) -> float:
	var c := spow(clampf(x/profile(y).x,-1.0,1.0),1.0/sq)
	return acos(c) if back else TAU-acos(c)

# --- Mesh helpers --------------------------------------------------------

static func emit(parent: Node3D, tris: PackedVector3Array, key: String) -> void:
	if tris.is_empty():return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for v in tris:st.add_vertex(v)
	st.generate_normals()
	st.index()
	Models.mesh_node(parent,st.commit(),Vector3.ZERO,key)

# rows[j][i] become quads; the winding is chosen so faces look away from
# `inside` (Godot's front faces are clockwise).
static func grid(tris: PackedVector3Array, rows: Array, closed: bool, inside: Vector3) -> void:
	var out := PackedVector3Array()
	var score := 0.0
	var n: int=(rows[0] as PackedVector3Array).size()
	for j in range(rows.size()-1):
		var a: PackedVector3Array=rows[j]
		var b: PackedVector3Array=rows[j+1]
		for i in range(n if closed else n-1):
			var k := (i+1)%n
			out.append(a[i]);out.append(a[k]);out.append(b[i])
			out.append(a[k]);out.append(b[k]);out.append(b[i])
			score+=(b[i]-a[i]).cross(a[k]-a[i]).dot((a[i]+b[k])*0.5-inside)
	if score<0:
		for t in range(0,out.size(),3):
			var swap := out[t+1]
			out[t+1]=out[t+2]
			out[t+2]=swap
	tris.append_array(out)

# A surface f(u,v,offset)->point, u and v in 0..1. Edges named in `hems`
# (1:u=0, 2:u=1, 4:v=0, 8:v=1) fold inwards by `hem`, giving the padded cover
# a visible thickness without a hidden inner surface.
static func panel(parent: Node3D, key: String, f: Callable, nu: int, nv: int, hem: float, inside: Vector3, hems: int=15, closed: bool=false) -> void:
	var us: Array=[]
	var vs: Array=[]
	if hems&1 and not closed:us.append([0.0,true])
	for i in range(nu if closed else nu+1):us.append([float(i)/nu,false])
	if hems&2 and not closed:us.append([1.0,true])
	if hems&4:vs.append([0.0,true])
	for j in range(nv+1):vs.append([float(j)/nv,false])
	if hems&8:vs.append([1.0,true])
	var rows: Array=[]
	for v in vs:
		var ring := PackedVector3Array()
		for u in us:ring.append(f.call(u[0],v[0],-hem if (u[1] or v[1]) else 0.0))
		rows.append(ring)
	var tris := PackedVector3Array()
	grid(tris,rows,closed,inside)
	emit(parent,tris,key)

# Rounded-rectangle profile swept along a path (straps, collar, handles).
static func sweep(parent: Node3D, key: String, centres: PackedVector3Array, across: PackedVector3Array, outward: PackedVector3Array, half: PackedVector2Array, caps: bool=true) -> void:
	var rows: Array=[]
	for i in range(centres.size()):
		var hx := half[i].x
		var hy := half[i].y
		var r := minf(hx,hy)*0.6
		var ring := PackedVector3Array()
		for p in [Vector2(hx,-hy+r),Vector2(hx,hy-r),Vector2(hx-r,hy),Vector2(-hx+r,hy),Vector2(-hx,hy-r),Vector2(-hx,-hy+r),Vector2(-hx+r,-hy),Vector2(hx-r,-hy)]:
			ring.append(centres[i]+across[i]*p.x+outward[i]*p.y)
		rows.append(ring)
	var tris := PackedVector3Array()
	for j in range(rows.size()-1):
		var part := PackedVector3Array()
		grid(part,[rows[j],rows[j+1]],true,(centres[j]+centres[j+1])*0.5)
		tris.append_array(part)
	if caps:
		for end in [0,rows.size()-1]:
			var ring: PackedVector3Array=rows[end]
			var away := centres[0]-centres[1] if end==0 else centres[end]-centres[end-1]
			var cap := PackedVector3Array()
			for i in range(1,7):cap.append_array([ring[0],ring[i],ring[i+1]])
			if (cap[2]-cap[0]).cross(cap[1]-cap[0]).dot(away)<0:
				for t in range(0,cap.size(),3):
					var swap := cap[t+1]
					cap[t+1]=cap[t+2]
					cap[t+2]=swap
			tris.append_array(cap)
	emit(parent,tris,key)

# PALS webbing: 25 mm band, raised in loops between 38 mm bar-tacks.
static func strip(parent: Node3D, key: String, points: PackedVector3Array, normals: PackedVector3Array, across: Vector3, width: float=0.0125, loops: bool=true) -> void:
	var low := PackedVector3Array()
	var mid := PackedVector3Array()
	var high := PackedVector3Array()
	for i in range(points.size()):
		var lift := (0.0045 if i%2==1 else 0.0018) if loops else 0.0035
		low.append(points[i]-across*width)
		mid.append(points[i]+normals[i]*lift)
		high.append(points[i]+across*width)
	var tris := PackedVector3Array()
	grid(tris,[low,mid,high],false,points[points.size()/2]-normals[points.size()/2]*0.1)
	emit(parent,tris,key)

# Angles from t0 to t1 at equal distances along the surface (the squared
# superellipse is far from uniform in angle). Last entry: the arc length.
static func arc_thetas(t0: float, t1: float, y: float, off: float, n: int) -> PackedFloat32Array:
	var samples := 96
	var acc := PackedFloat32Array([0.0])
	var prev := around(t0,y,off)
	for i in range(1,samples+1):
		var p := around(lerpf(t0,t1,float(i)/samples),y,off)
		acc.append(acc[i-1]+prev.distance_to(p))
		prev=p
	var out := PackedFloat32Array()
	var j := 0
	for k in range(n+1):
		var target := acc[samples]*k/n
		while j<samples-1 and acc[j+1]<target:j+=1
		var f := clampf((target-acc[j])/maxf(acc[j+1]-acc[j],1e-6),0.0,1.0)
		out.append(lerpf(t0,t1,(j+f)/samples))
	out.append(acc[samples])
	return out

static func molle(parent: Node3D, key: String, y: float, ta: float, tb: float, off: float, loops: bool=true) -> void:
	var t0 := minf(ta,tb)
	var t1 := maxf(ta,tb)
	var arc: float=arc_thetas(t0,t1,y,off,1)[2]
	var n := maxi(1,roundi(arc/0.038))*2
	if not loops:n=maxi(2,roundi(arc/0.03))
	var ts := arc_thetas(t0,t1,y,off,n)
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(n+1):
		points.append(around(ts[i],y,off))
		normals.append(normal(ts[i],y,off))
	strip(parent,key,points,normals,Vector3.UP,0.0125,loops)

# A box laid on the wrap surface (buckles, tabs).
static func box_on(parent: Node3D, key: String, theta: float, y: float, off: float, size: Vector3, edge: float=0.003) -> MeshInstance3D:
	var n := normal(theta,y,off)
	var tangent := Vector3.UP.cross(n).normalized()
	var node := Models.bevel(parent,around(theta,y,off+size.z*0.5),size,key,edge)
	node.basis=Basis(tangent,n.cross(tangent).normalized(),n)
	return node

# --- Shared vest parts ---------------------------------------------------

static func bottom_edge(theta: float, cut: Dictionary) -> float:
	var p := around(theta,1.1)
	var side := pow(clampf(absf(p.x)/profile(1.1).x,0.0,1.0),4.0)
	var end: float=cut.back_bottom if sin(theta)>0 else cut.front_bottom
	return lerpf(end,cut.side_bottom,side)

# Neckline, flat shoulder seam and armhole of a wrap-around cover.
static func top_edge(theta: float, cut: Dictionary) -> float:
	var back := sin(theta)>0
	var x := absf(around(theta,1.25).x)
	var neck: float=cut.back_neck if back else cut.front_neck
	var shoulder: float=cut.back_shoulder if back else cut.front_shoulder
	var neck_x: float=cut.neck_x
	var arm_x: float=cut.arm_x
	if x<neck_x:
		var q := x/neck_x
		return neck+(shoulder-neck)*(1.0-sqrt(maxf(0.0,1.0-q*q)))
	if x<arm_x:return shoulder
	var t := clampf((x-arm_x)/(profile(1.25).x-arm_x),0.0,1.0)
	return cut.armpit+(shoulder-cut.armpit)*sqrt(maxf(0.0,1.0-t*t))

static func cover(parent: Node3D, key: String, cut: Dictionary, hem: float) -> void:
	var f := func(u: float, v: float, o: float) -> Vector3:
		var t := u*TAU
		return around(t,lerpf(bottom_edge(t,cut),top_edge(t,cut),v),o)
	panel(parent,key,f,48,7,hem,Vector3(0,1.2,0),12,true)

# Edge tape: a band on the outside that folds over the edge.
static func binding(parent: Node3D, key: String, cut: Dictionary, upper: bool) -> void:
	var f := func(u: float, v: float, o: float) -> Vector3:
		var t := u*TAU
		var y: float=top_edge(t,cut)+lerpf(-0.014,0.0035,v) if upper else bottom_edge(t,cut)+lerpf(-0.0035,0.014,v)
		return around(t,y,0.0025+o)
	panel(parent,key,f,48,1,0.02,Vector3(0,1.2,0),8 if upper else 4,true)

# Strap over the shoulder at lateral x, following the measured outline of
# the soldier's shoulder (torso, the rig's own straps and plate bags) in the
# y-z plane: radius every 10 degrees round (y=1.33, z=0), from the chest (0)
# over the top (90) to the back (180).
const SHOULDER := [0.188,0.189,0.181,0.180,0.170,0.170,0.150,0.146,0.149,0.153,0.154,0.156,0.156,0.166,0.190,0.184,0.173,0.172,0.174]

static func shoulder_point(x: float, deg: float, off: float) -> Vector3:
	var r: float
	if deg<0:r=SHOULDER[0]/cos(deg_to_rad(deg))
	elif deg>180:r=SHOULDER[18]/cos(deg_to_rad(deg-180))
	else:
		var i := mini(int(deg/10.0),17)
		r=cubic_interpolate(SHOULDER[i],SHOULDER[i+1],SHOULDER[maxi(i-1,0)],SHOULDER[mini(i+2,18)],deg/10.0-i)
	var a := deg_to_rad(deg)
	return Vector3(x,1.33+(r+off)*sin(a),-(r+off)*cos(a))

static func shoulder_path(x: float, from: float, to: float, steps: int, off: float) -> Array:
	var centres := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(steps+1):
		var deg := lerpf(from,to,float(i)/steps)
		var p := shoulder_point(x,deg,off)
		var tangent := shoulder_point(x,deg+2,off)-shoulder_point(x,deg-2,off)
		var n := Vector3(0,-tangent.z,tangent.y).normalized()
		if n.dot(p-Vector3(x,1.33,0))<0:n=-n
		centres.append(p)
		normals.append(n)
	return [centres,normals]

static func straps(parent: Node3D, key: String, x: float, width: float, thick: float, from: float, to: float, web: String, rows: Array) -> void:
	for side in [-1,1]:
		var path: Array=shoulder_path(side*x,from,to,11,thick*0.5+0.004)
		var centres: PackedVector3Array=path[0]
		var normals: PackedVector3Array=path[1]
		var across := PackedVector3Array()
		var half := PackedVector2Array()
		for i in range(centres.size()):
			across.append(Vector3.RIGHT)
			half.append(Vector2(width*0.5,thick*0.5))
		sweep(parent,key,centres,across,normals,half)
		# Short webbing rows across the front of the strap.
		for a in rows:
			var p: Array=shoulder_path(side*x,a,a,1,thick*0.5+0.004)
			var c: Vector3=(p[0] as PackedVector3Array)[0]
			var n: Vector3=(p[1] as PackedVector3Array)[0]
			var points := PackedVector3Array()
			var ns := PackedVector3Array()
			for i in range(5):
				points.append(c+n*(thick*0.5+0.001)+Vector3.RIGHT*lerpf(-width*0.46,width*0.46,i/4.0))
				ns.append(n)
			strip(parent,web,points,ns,Vector3.RIGHT.cross(n).normalized(),0.0125)

# Stand-up collar: open at the throat (gap in radians each side of the
# front), heights (back, side, front end) of the top and bottom edges.
static func collar(parent: Node3D, key: String, inner: Vector2, centre_z: float, thick: float, gap: float, top: Vector3, bottom: Vector3, flare: float, front_flare: float) -> void:
	var centres := PackedVector3Array()
	var across := PackedVector3Array()
	var outward := PackedVector3Array()
	var half := PackedVector2Array()
	var steps := 20
	for i in range(steps+1):
		var phi := lerpf(-(PI-gap),PI-gap,float(i)/steps)
		var c := cos(phi)
		var w := absf(c) if c>=0 else 0.0
		var yt := lerpf(top.y,top.x,w) if c>=0 else lerpf(top.y,top.z,-c/cos(gap))
		var yb := lerpf(bottom.y,bottom.x,w) if c>=0 else lerpf(bottom.y,bottom.z,-c/cos(gap))
		var radial := Vector3(sin(phi),0,c)
		var mid := Vector3((inner.x+thick*0.5)*sin(phi),0,centre_z+(inner.y+thick*0.5)*c)
		var low := mid+radial*(flare+front_flare*pow(maxf(0.0,-c),2.0))+Vector3(0,yb,0)
		var high := mid+Vector3(0,yt,0)
		var up := (high-low).normalized()
		centres.append((low+high)*0.5)
		across.append(up)
		outward.append((radial-up*radial.dot(up)).normalized())
		half.append(Vector2(low.distance_to(high)*0.5,thick*0.5))
	sweep(parent,key,centres,across,outward,half)

# Pauldron in the arm's own frame: a partial tube round the upper arm, open
# on the inner side, with a rounded cap over the deltoid.
static func pad_point(side: int, u: float, v: float, o: float, size: Vector4) -> Vector3:
	var axis := (CharacterArt.UPPER_LEFT if side<0 else CharacterArt.UPPER_RIGHT).normalized()
	var out := Vector3(side,0,0)
	out=(out-axis*out.dot(axis)).normalized()
	var fwd := Vector3.FORWARD
	fwd=(fwd-axis*fwd.dot(axis)-out*fwd.dot(out)).normalized()
	# size: radius, length, cap angle, half span
	var phi := lerpf(-size.w,size.w,u)
	var radial := out*cos(phi)+fwd*sin(phi)
	var top := 0.02
	var s: float
	var r: float
	if v<0.3:
		var beta := size.z*(1.0-v/0.3)
		s=top-size.x*sin(beta)
		r=size.x*cos(beta)
	else:
		var q := (v-0.3)/0.7
		s=lerpf(top,size.y,q)
		r=size.x*(1.0+0.05*sin(PI*q))
	return axis*s+radial*(r+o)

static func pauldron(parent: Node3D, side: int, key: String, size: Vector4, band_key: String, band: Vector2, tab: bool) -> void:
	var axis := (CharacterArt.UPPER_LEFT if side<0 else CharacterArt.UPPER_RIGHT).normalized()
	panel(parent,key,func(u: float, v: float, o: float) -> Vector3:return pad_point(side,u,v,o,size),8,8,0.016,axis*0.1)
	# Strap band near the lower edge.
	var b := func(u: float, v: float, o: float) -> Vector3:
		return pad_point(side,lerpf(-0.04,1.04,u),lerpf(band.x,band.y,v),0.006+o,size)
	panel(parent,band_key,b,8,1,0.007,axis*0.1)
	if tab:
		var t := func(u: float, v: float, o: float) -> Vector3:
			return pad_point(side,lerpf(0.36,0.64,u),lerpf(0.45,0.66,v),0.005+o,size)
		panel(parent,band_key,t,2,2,0.006,axis*0.1)

# Groin flap hanging from its top edge (the group's origin), front -Z.
static func groin_flap(parent: Node3D, key: String, length: float, width: float, pointed: bool) -> void:
	var f := func(u: float, v: float, o: float) -> Vector3:
		var s := u*2.0-1.0
		var half: float
		if pointed:
			half=width*pow(cos(clampf((v-0.22)/0.78,0.0,1.0)*PI*0.5),0.7)
		else:
			var q := clampf((v-0.62)/0.38,0.0,1.0)
			half=lerpf(width,width*0.9,minf(v/0.62,1.0))*sqrt(maxf(0.0,1.0-q*q))
		return Vector3(s*half,-v*length,-0.016*(1.0-s*s)+0.03*v*v-o)
	panel(parent,key,f,8,9,0.018,Vector3(0,-length*0.5,0.3))

# Two webbing tabs and buckles that hang the groin flap under the front edge.
static func groin_hangers(parent: Node3D, web: String, y: float, spread: float) -> void:
	for x in [-spread,spread]:
		var t := angle(x,y,false)
		var points := PackedVector3Array()
		var normals := PackedVector3Array()
		for i in range(4):
			var yy := y+0.03-i*0.022
			points.append(around(t,yy,0.003)+Vector3(0,0,0.006*float(i==3)))
			normals.append(normal(t,yy,0.003))
		strip(parent,web,points,normals,Vector3.RIGHT,0.0125,false)
		box_on(parent,"vest_hardware",t,y-0.022,0.006,Vector3(0.033,0.022,0.008),0.003)

static func drag_handle(parent: Node3D, key: String, y: float, back_z: float) -> void:
	var centres := PackedVector3Array()
	var across := PackedVector3Array()
	var outward := PackedVector3Array()
	var half := PackedVector2Array()
	for i in range(7):
		var q := float(i)/6
		centres.append(Vector3(lerpf(-0.05,0.05,q),y,back_z+0.004+0.022*sin(q*PI)))
		across.append(Vector3.UP)
		outward.append(Vector3.BACK)
		half.append(Vector2(0.0135,0.0025))
	sweep(parent,key,centres,across,outward,half)

# --- Korsar M3s ------------------------------------------------------------

static func korsar(parts: Dictionary) -> void:
	var vest: Node3D=parts["Vest"]
	prof.assign([Vector4(0.965,0.203,0.197,0.004),Vector4(1.05,0.206,0.201,0.0),Vector4(1.15,0.210,0.204,0.0),Vector4(1.25,0.217,0.204,0.0),Vector4(1.34,0.222,0.200,-0.002),Vector4(1.42,0.212,0.182,-0.004),Vector4(1.48,0.196,0.168,0.0)])
	sq=0.58
	var cut := {"front_bottom":0.972,"side_bottom":0.995,"back_bottom":0.98,"front_neck":1.405,"front_shoulder":1.43,"back_neck":1.44,"back_shoulder":1.465,"neck_x":0.085,"arm_x":0.165,"armpit":1.21}
	cover(vest,"vest_mm14",cut,0.018)
	# Front rows behind the rig's magazine pouches (y 1.03-1.20) are skipped.
	for i in range(7):
		var y := 1.04+i*0.05
		if y>1.21:molle(vest,"vest_web_ua",y,angle(-0.15,y,false),angle(0.15,y,false),0.0015)
		molle(vest,"vest_web_ua",y-0.01,angle(-0.14,y,true),angle(0.14,y,true),0.0015)
	# Side wings close over the front panel.
	for side in [-1,1]:
		var back_t := angle(side*0.12,1.08,true)
		var front_t := angle(side*0.163,1.08,false)
		if side>0:front_t-=TAU
		var w := func(u: float, v: float, o: float) -> Vector3:
			return around(lerpf(back_t,front_t,u),lerpf(0.988,1.178,v),0.011+o)
		panel(vest,"vest_mm14",w,12,3,0.014,Vector3(0,1.08,0))
		for i in range(4):
			var y := 1.012+i*0.048
			var a := lerpf(back_t,front_t,0.06)
			var b := lerpf(back_t,front_t,0.95)
			molle(vest,"vest_web_ua",y,a,b,0.0125)
	# Velcro name flap and drag handle on the back.
	var flap := func(u: float, v: float, o: float) -> Vector3:
		var y := lerpf(1.35,1.405,v)
		return around(lerpf(angle(0.12,y,true),angle(-0.12,y,true),u),y,0.004+o)
	panel(vest,"vest_web_ua",flap,6,2,0.006,Vector3(0,1.4,0))
	drag_handle(vest,"vest_web_ua",1.422,around(PI*0.5,1.422).z)
	straps(vest,"vest_mm14",0.132,0.085,0.022,-18.0,198.0,"vest_web_ua",[0.0,13.0])
	collar(vest,"vest_mm14",Vector2(0.1,0.104),-0.012,0.034,0.5,Vector3(1.565,1.53,1.49),Vector3(1.432,1.452,1.395),0.02,0.042)
	groin_hangers(vest,"vest_web_ua",0.975,0.075)
	var groin: Node3D=parts["VestGroin"]
	groin.position=Vector3(0,0.99,-0.176)
	groin_flap(groin,"vest_mm14",0.30,0.115,false)
	for side in ["Left","Right"]:
		var s := -1 if side=="Left" else 1
		pauldron(parts[side],s,"vest_mm14",Vector4(0.097,0.145,deg_to_rad(42),deg_to_rad(112)),"vest_mm14",Vector2(0.80,0.95),false)

# --- 6B45 Ratnik ------------------------------------------------------------

static func ratnik(parts: Dictionary) -> void:
	var vest: Node3D=parts["Vest"]
	prof.assign([Vector4(0.962,0.206,0.201,0.004),Vector4(1.05,0.209,0.205,0.0),Vector4(1.15,0.213,0.207,0.0),Vector4(1.25,0.219,0.207,0.0),Vector4(1.34,0.224,0.203,-0.002),Vector4(1.42,0.214,0.186,-0.004),Vector4(1.48,0.198,0.17,0.0)])
	sq=0.5
	var cut := {"front_bottom":0.968,"side_bottom":0.985,"back_bottom":0.975,"front_neck":1.395,"front_shoulder":1.435,"back_neck":1.445,"back_shoulder":1.47,"neck_x":0.075,"arm_x":0.17,"armpit":1.215}
	cover(vest,"vest_emr",cut,0.018)
	binding(vest,"vest_web_rf",cut,true)
	binding(vest,"vest_web_rf",cut,false)
	for i in range(7):
		var y := 1.065+i*0.05
		if y>1.21:molle(vest,"vest_web_rf",y,angle(-0.165,y,false),angle(0.165,y,false),0.0015)
		molle(vest,"vest_web_rf",y-0.015,angle(-0.155,y,true),angle(0.155,y,true),0.0015)
	for side in [-1,1]:
		for i in range(3):
			var y := 1.03+i*0.05
			var a := angle(side*0.163,y,false)
			var b := angle(side*0.19,y,true)
			if side>0:a-=TAU
			molle(vest,"vest_web_rf",y,a,b,0.0015)
	# Waist strap with side-release buckles at the panel corners.
	var y0 := 1.008
	molle(vest,"vest_web_rf",y0,angle(-0.2,y0,false),angle(0.2,y0,false),0.002,false)
	for x in [-0.168,0.168]:
		var t := angle(x,y0,false)
		box_on(vest,"vest_hardware",t,y0,0.006,Vector3(0.04,0.03,0.01),0.004)
		box_on(vest,"vest_hardware",angle(x+signf(x)*0.03,y0,false),y0,0.006,Vector3(0.024,0.026,0.012),0.004)
	drag_handle(vest,"vest_web_rf",1.425,around(PI*0.5,1.425).z)
	straps(vest,"vest_emr",0.13,0.092,0.024,-18.0,198.0,"vest_web_rf",[6.0])
	collar(vest,"vest_emr",Vector2(0.104,0.108),-0.012,0.04,0.46,Vector3(1.58,1.54,1.5),Vector3(1.43,1.455,1.395),0.024,0.04)
	groin_hangers(vest,"vest_web_rf",0.972,0.085)
	var groin: Node3D=parts["VestGroin"]
	groin.position=Vector3(0,0.985,-0.178)
	groin_flap(groin,"vest_emr",0.34,0.125,true)
	for side in ["Left","Right"]:
		var s := -1 if side=="Left" else 1
		pauldron(parts[side],s,"vest_emr",Vector4(0.106,0.21,deg_to_rad(44),deg_to_rad(116)),"vest_web_rf",Vector2(0.82,0.93),true)

# --- Plate carrier -----------------------------------------------------------

# Plate bag stations (y, width, depth) shared by the shell and the parts laid
# on it; z is the bag's centre (negative: front).
const BAG := [Vector3(1.032,0.33,0.07),Vector3(1.07,0.368,0.094),Vector3(1.34,0.358,0.088),Vector3(1.40,0.30,0.08),Vector3(1.437,0.24,0.064)]

static func bag_station(y: float) -> Vector3:
	for i in range(BAG.size()-1):
		var a: Vector3=BAG[i]
		var b: Vector3=BAG[i+1]
		if y<=b.x or i==BAG.size()-2:return a.lerp(b,clampf((y-a.x)/(b.x-a.x),0.0,1.0))
	return BAG[0]

# Outer face of a plate bag (the shell's square=0.5 superellipse) at x, y.
static func bag_point(x: float, y: float, z: float, off: float) -> Vector3:
	var s := bag_station(y)
	var c := clampf(x/(s.y*0.5),-1.0,1.0)
	var depth := s.z*0.5*sqrt(sqrt(maxf(0.0,1.0-c*c*c*c)))
	return Vector3(x,y,z+signf(z)*(depth+off))

static func bag_normal(x: float, y: float, z: float) -> Vector3:
	var p := bag_point(x,y,z,0.0)
	var dx := bag_point(x+0.005,y,z,0.0)-p
	var dy := bag_point(x,y+0.005,z,0.0)-p
	var n := dx.cross(dy).normalized()
	return n if n.z*z>0 else -n

static func bag_row(parent: Node3D, key: String, y: float, z: float, half: float) -> void:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var n := maxi(1,roundi(half*2/0.038))*2
	for i in range(n+1):
		var x := lerpf(-half,half,float(i)/n)
		points.append(bag_point(x,y,z,0.0012))
		normals.append(bag_normal(x,y,z))
	strip(parent,key,points,normals,Vector3.UP)

static func carrier(parts: Dictionary) -> void:
	var vest: Node3D=parts["Vest"]
	for z in [-0.15,0.15]:
		var stations: Array[Vector4]=[]
		for s in BAG:stations.append(Vector4(s.x,s.y,s.z,z))
		CharacterArt.shell(vest,stations,"vest_ranger",0.004,24,0.5)
	# Front: admin panel above three PALS rows; back: five rows and a handle.
	var admin := func(u: float, v: float, o: float) -> Vector3:
		var x := lerpf(-0.105,0.105,u)
		var y := lerpf(1.29,1.39,v)
		return bag_point(x,y,-0.15,0.0045+o)
	panel(vest,"vest_ranger",admin,4,2,0.006,Vector3(0,1.34,0))
	var zip := PackedVector3Array()
	var zip_normals := PackedVector3Array()
	for i in range(5):
		var x := lerpf(-0.095,0.095,i/4.0)
		zip.append(bag_point(x,1.381,-0.15,0.0052))
		zip_normals.append(bag_normal(x,1.381,-0.15))
	strip(vest,"vest_hardware",zip,zip_normals,Vector3.UP,0.003,false)
	var tab := Models.bevel(vest,bag_point(0.072,1.37,-0.15,0.0075),Vector3(0.009,0.024,0.004),"vest_hardware",0.0015)
	tab.rotation.z=0.12
	for y in [1.08,1.13,1.18]:bag_row(vest,"vest_ranger",y,-0.15,0.15)
	for y in [1.10,1.15,1.20,1.25,1.30]:bag_row(vest,"vest_ranger",y,0.15,0.15)
	drag_handle(vest,"vest_ranger",1.415,bag_point(0,1.415,0.15,0.0).z)
	# Laser-cut cummerbund round the sides, slots and a buckle each side.
	prof.assign([Vector4(0.99,0.197,0.176,0.0),Vector4(1.19,0.206,0.178,0.0)])
	sq=0.62
	for side in [-1,1]:
		var front_t := angle(side*0.165,1.09,false)
		var back_t := angle(side*0.165,1.09,true)
		if side>0:front_t-=TAU
		var band := func(u: float, v: float, o: float) -> Vector3:
			return around(lerpf(front_t,back_t,u),lerpf(1.005,1.175,v),o)
		panel(vest,"vest_ranger",band,14,3,0.008,Vector3(0,1.09,0))
		# Slots 25 mm long on a 38 mm pitch, between the bags' edges.
		var slots := PackedVector3Array()
		for row in range(3):
			var y := 1.04+row*0.045
			var ts := arc_thetas(front_t,back_t,y,0.001,40)
			var arc: float=ts[41]
			for k in range(4):
				var centre := 0.5+(k-1.5)*0.038/arc
				var a := ts[roundi((centre-0.0125/arc)*40)]
				var b := ts[roundi((centre+0.0125/arc)*40)]
				grid(slots,[PackedVector3Array([around(a,y-0.0035,0.001),around(b,y-0.0035,0.001)]),PackedVector3Array([around(a,y+0.0035,0.001),around(b,y+0.0035,0.001)])],false,Vector3(0,y,0))
		emit(vest,slots,"vest_hardware")
		# Webbing tab from the buckle forward under the front bag.
		var bt := lerpf(front_t,back_t,0.2)
		molle(vest,"vest_ranger",1.09,lerpf(front_t,back_t,-0.02),bt,0.002,false)
		box_on(vest,"vest_hardware",bt,1.09,0.004,Vector3(0.036,0.03,0.01),0.004)
		box_on(vest,"vest_hardware",lerpf(front_t,back_t,0.29),1.09,0.004,Vector3(0.026,0.026,0.012),0.004)
	# Webbing straps over the shoulders under coyote pads.
	for side in [-1,1]:
		var x: float=side*0.13
		for spec in [[14.0,172.0,Vector2(0.021,0.0025),"vest_ranger"],[36.0,144.0,Vector2(0.037,0.0115),"vest_coyote"]]:
			var path: Array=shoulder_path(x,spec[0],spec[1],12,spec[2].y+0.003)
			var centres: PackedVector3Array=path[0]
			var normals: PackedVector3Array=path[1]
			var across := PackedVector3Array()
			var half := PackedVector2Array()
			for i in range(centres.size()):
				across.append(Vector3.RIGHT)
				half.append(spec[2])
			sweep(vest,spec[3],centres,across,normals,half)
