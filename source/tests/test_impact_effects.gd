extends SceneTree

# What a bullet throws up where it strikes (ImpactEffects): concrete and
# brick burst into powder and chips, a board splinters, a steel plate sparks,
# soil spurts up and its clods come down on the ground; less of it further
# from the eye, nothing far off; a man hit throws dust off his clothes, and a
# rifle round through him a mist behind him. The battle's random numbers stay
# as they were.
var checks := 0
var failed := false
var game: Node3D
var base := Vector3.ZERO
var camera: Camera3D
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failed=true
		printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
	for i in range(n):await physics_frame

func ground(x: float, z: float) -> Vector3:
	var p := base+Vector3(x,0,z)
	p.y=game.district.ground_height(p)
	return p

func open_ground(start: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D=game.district.get_world_3d().direct_space_state
	for radius in range(0,200,10):
		var steps: int=maxi(1,radius/3)
		for k in range(steps):
			var c: Vector3=start+Vector3(cos(k*TAU/steps),0,sin(k*TAU/steps))*radius
			var h0: float=game.district.ground_height(c)
			var clear := true
			for ox in range(-11,12,2):
				for oz in range(-5,13,2):
					var p: Vector3=c+Vector3(ox,0,oz)
					var h: float=game.district.ground_height(p)
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,h+30,p.z),Vector3(p.x,h-0.5,p.z),1))
					if absf(h-h0)>0.5 or hit.is_empty() or absf(float(hit.position.y)-h)>0.3:clear=false
			for ox in range(-11,12,1):
				for up in [0.4,1.2,2.2]:
					if not space.intersect_ray(PhysicsRayQueryParameters3D.create(c+Vector3(ox,h0+up,13),c+Vector3(ox,h0+up,-5),1)).is_empty():clear=false
			if clear:return Vector3(c.x,0,c.z)
	return start

func block(at: Vector3, size: Vector3, color: Color, substance: String) -> DestructibleSurface:
	var body: DestructibleSurface=game.district.collider(at,size,substance)
	body.set_meta("surface_color",color)
	body.tint=color
	return body

func look(from: Vector3, at: Vector3) -> void:
	camera.global_position=from
	camera.look_at(at)

func shoot(from: Vector3, to: Vector3, weapon: String="ak74") -> void:
	game.impacts.thrown.clear()
	game.ballistics.launch(from,from.direction_to(to),weapon,68,game.player)
	for i in range(4):game.ballistics._physics_process(1.0/60.0)

func layer(kind: String) -> Array:
	return game.impacts.thrown.filter(func(t):return t.layer==kind)

func run():
	game=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.volume=0
	game.start_match()
	await frames(5)
	game.player.set_physics_process(false)
	game.ballistics.set_physics_process(false)
	for bot in game.bots+game.allies:
		bot.set_physics_process(false)
		bot.position=Vector3(0,-300,0)
	base=open_ground(game.district.player_spawn)
	game.player.global_position=ground(0,40)+Vector3.UP*0.1
	camera=game.menu_camera
	camera.current=true
	var effects: ImpactEffects=game.impacts
	check(effects!=null and effects.dust.multimesh.instance_count==ImpactEffects.DUST_CAPACITY,"The impact effects are built with the district")
	effects.record=true
	var concrete := block(ground(-4.5,0)+Vector3(0,1.1,0),Vector3(2.4,2.2,0.3),Color("8d8a82"),"concrete")
	var brick := block(ground(-1.5,0)+Vector3(0,1.1,0),Vector3(2.4,2.2,0.25),Color("8a4a35"),"brick")
	block(ground(1.5,0)+Vector3(0,1.1,0),Vector3(2.4,2.2,0.04),Color("6d5a43"),"wood")
	block(ground(4.5,0)+Vector3(0,1.1,0),Vector3(2.4,2.2,0.012),Color("4c5248"),"steel")
	var berm := block(ground(0,6)+Vector3(0,0.2,0),Vector3(3,0.4,3),Color("6b5b45"),"earth")
	await frames(3)

	# --- concrete from 6 m, the eye 3 m off -------------------------------------
	var g := ground(-4.5,0)
	look(g+Vector3(1.2,1.5,3.0),g+Vector3(0,1.25,0))
	var marks: int=game.bullet_marks.size()
	shoot(g+Vector3(0.3,1.4,6),g+Vector3(0,1.25,0))
	var face := Vector3(0,0,1)
	check(effects.last.get("material")=="concrete" and effects.last.detail==3,"Concrete near the eye: full detail (%s)" % [effects.last])
	check(layer("dust").size()>=8 and layer("chip").size()>=6,"A burst of powder and chips (%d puffs, %d chips)" % [layer("dust").size(),layer("chip").size()])
	var off_face := true
	for t in layer("dust")+layer("chip"):off_face=off_face and Vector3(t.velocity).dot(face)>-0.01
	check(off_face,"Everything flies off the face it struck")
	check(game.bullet_marks.size()==marks+1 and game.bullet_marks[-1].material_override==ImpactEffects.mark_material("concrete",false),"A crater left in the concrete")
	var size: float=game.bullet_marks[-1].global_basis.get_scale().x
	check(size>0.03 and size<0.08,"…some 5 cm across (%.3f m)" % size)
	var powder: Color=layer("dust")[0].color
	# --- brick ----------------------------------------------------------------------
	g=ground(-1.5,0)
	look(g+Vector3(1.2,1.5,3.0),g+Vector3(0,1.25,0))
	shoot(g+Vector3(0.3,1.4,6),g+Vector3(0,1.25,0))
	var red: Color=layer("dust")[0].color
	check(effects.last.get("material")=="brick" and red.r-red.b>powder.r-powder.b+0.1,"Brick dust is red (%s against %s)" % [red,powder])
	# --- a board: splinters in, longer ones out of the far side ----------------------
	g=ground(1.5,0)
	look(g+Vector3(1.2,1.5,3.0),g+Vector3(0,1.25,0))
	shoot(g+Vector3(0.3,1.4,6),g+Vector3(0,1.25,0))
	# (Only what the board threw: the bullet flies on to the wall behind.)
	var board_at := g+Vector3(0,1.25,0)
	var splinters := layer("chip").filter(func(t):return Vector3(t.at).distance_to(board_at)<0.5)
	var long := true
	var forward := 0
	var way := (g+Vector3(0,1.25,0)-(g+Vector3(0.3,1.4,6))).normalized()
	for t in splinters:
		var dims: Vector3=t.dims
		long=long and maxf(dims.x,maxf(dims.y,dims.z))>=4.0*minf(dims.x,minf(dims.y,dims.z))
		if Vector3(t.velocity).dot(way)>0.5:forward+=1
	check(splinters.size()>=10 and long,"A board splinters: long thin pieces (%d)" % splinters.size())
	check(forward>=7,"Out of the far side the splinters go on with the bullet (%d)" % forward)
	check(layer("spark").filter(func(t):return Vector3(t.at).distance_to(board_at)<0.5).is_empty(),"Wood does not spark")
	# --- steel plate: a flash and sparks off along the ricochet --------------------
	g=ground(4.5,0)
	look(g+Vector3(1.2,1.5,3.0),g+Vector3(0,1.25,0))
	shoot(g+Vector3(0.3,1.4,6),g+Vector3(0,1.25,0))
	check(effects.last.get("material")=="steel" and layer("flash").size()==1 and layer("spark").size()>=8,"Steel: a flash and a spray of sparks (%d)" % layer("spark").size())
	var outward := true
	for t in layer("spark"):outward=outward and Vector3(t.velocity).dot(face)>0.0
	check(outward,"The sparks fly off the plate, not into it")
	# --- steel cores spark on concrete now and then, a pistol never -------------------
	g=ground(-4.5,0)
	look(g+Vector3(1.2,1.5,3.0),g+Vector3(0,1.25,0))
	var rifle_sparks := 0
	var pistol_sparks := 0
	for i in range(20):
		shoot(g+Vector3(0.3+i*0.02,1.4,6),g+Vector3(-0.9+i*0.09,0.6+i*0.05,0))
		rifle_sparks+=layer("spark").size()
		shoot(g+Vector3(0.3+i*0.02,1.4,6),g+Vector3(-0.9+i*0.09,0.7+i*0.05,0),"pm")
		pistol_sparks+=layer("spark").size()
	check(rifle_sparks>0 and pistol_sparks==0,"Rifle rounds strike a spark off concrete now and then (%d), pistol rounds never (%d)" % [rifle_sparks,pistol_sparks])
	# --- soil: a spurt, and the clods come down on the ground ------------------------
	var top := ground(0,6)+Vector3(0,0.4,0)
	look(top+Vector3(2.5,1.2,2.5),top)
	shoot(top+Vector3(-1.5,1.6,6),top)
	check(effects.last.get("material")=="earth","Soil (%s)" % [effects.last])
	var rising := 0
	for t in layer("dust"):if Vector3(t.velocity).y>0.0:rising+=1
	check(rising>=layer("dust").size()-2 and layer("dust").size()>=8,"The dust spurts up (%d of %d)" % [rising,layer("dust").size()])
	var highest := 0.0
	var landed := true
	for t in layer("chip"):
		var v: Vector3=t.velocity
		var drag: float=t.drag
		var peak: float=Vector3(t.at).y
		for k in range(40):peak=maxf(peak,ImpactEffects.travel(t.at,v,drag,float(t.land)*k/40.0).y)
		highest=maxf(highest,peak-top.y)
		if float(t.land)<float(t.life):
			var down := ImpactEffects.travel(t.at,v,drag,float(t.land))
			landed=landed and absf(down.y-top.y)<0.05
	check(highest>0.15 and highest<2.6,"Clods thrown up some way (%.2f m), not to the roofs" % highest)
	check(landed,"…and they come down on the ground")
	check(layer("chip").size()>=10,"Clods and grit (%d)" % layer("chip").size())
	# --- what the shader does: landing time ----------------------------------------------
	var t_land := ImpactEffects.fall(1.0,3.0,0.3,0.0,5.0)
	check(absf(ImpactEffects.travel(Vector3(0,1,0),Vector3(0,3,0),0.3,t_land).y)<0.001 and t_land>0.6,"Landing time where the flight meets the ground (%.3f s)" % t_land)
	check(ImpactEffects.fall(1.0,3.0,0.3,0.0,0.3)==0.3,"Still in the air at the end of its life")
	# --- further off: less of it, nothing far away ---------------------------------
	g=ground(-4.5,0)
	var counts: Array=[]
	for distance in [80.0,250.0,600.0]:
		look(g+Vector3(0,1.5,distance),g+Vector3(0,1.25,0))
		marks=game.bullet_marks.size()
		shoot(g+Vector3(0.3,1.4,6),g+Vector3(0.2,1.0,0))
		counts.append([effects.last.detail,layer("dust").size(),layer("chip").size(),game.bullet_marks.size()-marks])
	check(counts[0][0]==2 and counts[0][1]<=7 and counts[0][2]<=5 and counts[0][3]==1,"At 80 m: fewer puffs and chips, the hole still left (%s)" % [counts[0]])
	check(counts[1][0]==1 and counts[1][1]<=3 and counts[1][2]==0 and counts[1][3]==0,"At 250 m: only the cloud, no chips, no hole (%s)" % [counts[1]])
	check(counts[2][0]==0 and counts[2][1]==0 and counts[2][3]==0,"At 600 m: nothing (%s)" % [counts[2]])
	# --- a man: dust off his clothes, a mist behind him ------------------------------
	var man: Hostile=game.bots[0]
	man.global_position=ground(7.5,1.5)
	man.rotation.y=0.0
	man.animate_pose(1,false)
	await frames(2)
	look(man.global_position+Vector3(1.3,1.45,-2.0),man.global_position+Vector3(0,1.2,0))
	var from := man.global_position+Vector3(6,1.3,0.03)
	var aim := man.global_position+Vector3(0,1.3,0)
	shoot(from,aim)
	check(effects.last.get("material")=="body" and ImpactEffects.wearable(String(effects.last.cloth.material)),"A man hit: his clothes found (%s)" % [effects.last.get("cloth")])
	var cloth: Color=effects.last.cloth.tone
	var d := from.direction_to(aim)
	var entry := Vector3.INF
	var mist := 0
	var behind := true
	var dusty := 0
	for t in layer("dust"):
		var c: Color=t.color
		if c.r>c.g*2.0:
			mist+=1
			behind=behind and (Vector3(t.at)-man.global_position).dot(d)>0.12
		else:
			dusty+=1
			entry=t.at
			check(absf(c.g-cloth.lerp(Color("bdb6a5"),0.5).g)<0.02,"The puff is the colour of his dusty clothes")
	check(dusty>=4 and entry!=Vector3.INF and (entry-man.global_position).dot(d)<-0.1,"Dust and fibres off his clothes where it went in (%d)" % dusty)
	check(mist>=4 and behind,"A rifle round through him: a mist of blood out of his far side (%d)" % mist)
	# The far side of him, not of the arm it went in by.
	var exit_at: Variant=ImpactEffects.exit_through(man,man.hitboxes[1],aim+Vector3(0.21,0,0),Vector3.LEFT)
	check(exit_at is Vector3 and (Vector3(exit_at)-man.global_position).dot(Vector3.LEFT)>0.15,"The round comes out of the far side of his body (%s)" % [exit_at])
	# Another man for a pistol round.
	var other: Hostile=game.bots[1]
	man.global_position=Vector3(0,-300,0)
	other.global_position=ground(7.5,1.5)
	other.rotation.y=0.0
	other.animate_pose(1,false)
	await frames(2)
	shoot(from,aim,"pm")
	check(effects.last.get("material")=="body","The pistol round hits him")
	var pistol_mist := 0
	for t in layer("dust"):if Color(t.color).r>Color(t.color).g*2.0:pistol_mist+=1
	check(pistol_mist==0,"A pistol round stays in him: no mist")
	# A plate that stops it: dust, no blood.
	var plate: Area3D=null
	for area in other.hitboxes:if String(area.get_meta("zone",""))=="plate":plate=area
	effects.thrown.clear()
	effects.body_hit(other,plate,plate.global_position+Vector3(0,0,-0.1),Vector3.FORWARD,Vector3.BACK,{"kind":"blunt"},"ak74",1.0,null)
	var blood := 0
	for t in effects.thrown:if Color(t.color).r>Color(t.color).g*2.0:blood+=1
	check(effects.thrown.size()>=6 and blood==0,"A plate stops it: a puff off the carrier, no blood (%d / %d)" % [effects.thrown.size(),blood])
	# --- a drone hit: bits of it, no hole in the air -----------------------------------
	marks=game.bullet_marks.size()
	effects.thrown.clear()
	effects.drone_hit(other.global_position+Vector3(0,6,0),Vector3.DOWN)
	check(layer("chip").size()==4 and game.bullet_marks.size()==marks,"A drone hit: bits of its shell, no mark hanging in the air")
	# --- the battle's dice ------------------------------------------------------------
	seed(77)
	var expected := randf()
	seed(77)
	look(g+Vector3(1.2,1.5,3.0),g+Vector3(0,1.25,0))
	effects.strike(g+Vector3(0,1.25,0.15),Vector3.BACK,concrete,Vector3.FORWARD,1300.0,false,"ak74")
	effects.body_hit(man,man.hitboxes[1],aim,Vector3.RIGHT,Vector3.LEFT,{"kind":"thoracic"},"ak74",1.0,aim+Vector3.LEFT*0.3)
	game.blood.add_wound(man,man.hitboxes[1],aim,Vector3.RIGHT,{"kind":"thoracic","bleeding":3.0},Vector3.LEFT,aim+Vector3.LEFT*0.3)
	check(randf()==expected,"Effects and blood draw their own random numbers, not the battle's")
	# --- the clock stops with the game ----------------------------------------------
	var clock := effects.clock
	await process_frame
	await process_frame
	check(effects.clock>clock,"The effects' clock runs with the game")
	game.paused=true
	clock=effects.clock
	await process_frame
	await process_frame
	check(effects.clock==clock,"…and stops while it is paused")
	game.paused=false
	# --- a new match clears them ----------------------------------------------------
	game.start_match()
	await frames(3)
	check(is_instance_valid(game.impacts) and game.impacts.thrown.is_empty() and game.impacts.cursor.dust==0,"A new match starts with no dust in the air")
	brick.queue_free()
	berm.queue_free()
	game.queue_free()
	await process_frame
	print("%s: %d impact effect checks" % ["FAILED" if failed else "PASS",checks])
	quit(1 if failed else 0)
