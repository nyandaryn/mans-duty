extends Control

var game: Node3D

# Compass, with world-relative bearing.
func draw_compass(bearing: float, col: Color) -> void:
	var center := size/2
	for i in range(-5,6):
		var x := center.x+i*42
		draw_line(Vector2(x,28),Vector2(x,34 if i%2 else 39),Color(0.8,0.82,0.72,0.65),1)
	draw_string(ThemeDB.fallback_font,Vector2(center.x-27,60),"%03d°" % (int(bearing)%360),HORIZONTAL_ALIGNMENT_LEFT,-1,18,col)

# Bearing of a camera's line of sight, clockwise from north (−Z).
static func view_bearing(camera: Camera3D) -> float:
	var forward := -camera.global_basis.z
	if Vector2(forward.x,forward.z).length()<0.1:forward=camera.global_basis.y
	return fposmod(rad_to_deg(atan2(forward.x,-forward.z)),360.0)

func _draw() -> void:
	if not game.running: return
	if game.player.field_rig.mode=="drone":
		draw_drone_view()
		return
	var center := size/2
	var col := Color("f0e7cf")
	# In the cab of the BM-21 its own instruments replace the soldier's.
	if (is_instance_valid(game.grad) and game.grad.seat!="") or (is_instance_valid(game.bmp) and game.bmp.seat!="" and not game.bmp.head_out):
		if game.damage_flash>0:draw_rect(game.screen_rect(self),Color(0.65,0.13,0.08,game.damage_flash*0.5),false,18)
		# The compass stays at any seat: the bearing the view from it faces.
		var seat_camera := get_viewport().get_camera_3d()
		if seat_camera!=null:draw_compass(view_bearing(seat_camera),col)
		return
	if not game.player.is_vaulting() and not game.player.aim and game.player.blind_mode==0 and game.player.arm_injury<0.5 and game.player.bandage_time<=0 and not game.player.field_rig.active():
		for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			draw_line(center+direction*5,center+direction*11,col,1)
	if game.damage_flash>0:
		var red := Color(0.65,0.13,0.08,game.damage_flash*0.5)
		draw_rect(game.screen_rect(self),red,false,18)
	draw_compass(fposmod(-rad_to_deg(game.player.rotation.y),360),col)
	var font := ThemeDB.fallback_font
	if game.debug_invulnerable:draw_string(font,Vector2(24,100),"DEBUG · БЕЗСМЕРТЯ / ПОПОВНЕННЯ МАГАЗИНІВ · F8",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e4bf68"))
	if game.player.current().id=="svd" and game.player.aim:
		var w: WeaponState=game.player.current()
		draw_string(font,Vector2(24,size.y-208),"ПСО-1 · 4×   БАРАБАН %d м   БОКОВА %+.1f · PgUp/PgDn · [ / ]" % [w.scope_zero,w.scope_windage*0.5],HORIZONTAL_ALIGNMENT_LEFT,-1,14,col)
		draw_string(font,Vector2(24,size.y-184),"L · ПІДСВІТКА   Shift · ЗАТРИМАТИ ДИХАННЯ"+(" · ВІДНОВЛЕННЯ" if game.player.breath_recovery>0 else (" · ЗАТРИМАНО" if game.player.holding_breath else "")),HORIZONTAL_ALIGNMENT_LEFT,-1,14,col)
	if game.player.current().id=="pkm" and not game.player.launcher.active():
		var w: WeaponState=game.player.current()
		draw_string(font,Vector2(24,size.y-208),"ПКМ · ПРИЦІЛ %d — %d м · PgUp/PgDn   СОШКИ: %s · X" % [w.scope_zero/100,w.scope_zero,"НА ОПОРІ" if game.player.bipod else "СКЛАДЕНІ"],HORIZONTAL_ALIGNMENT_LEFT,-1,14,col)
		if game.player.bipod_notice_left>0:draw_string(font,Vector2(24,size.y-184),game.player.bipod_notice,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e5a17e"))
	# The rifle's sight while aiming or being set.
	if game.player.current().id in ["ak74","m16"] and not game.player.launcher.active() and (game.player.aim or game.player.scope_adjust_time>0):
		var w: WeaponState=game.player.current()
		var direct: bool=w.scope_zero==int(Ballistics.PROFILES[w.id].zero)
		draw_string(font,Vector2(24,size.y-208),"%s · ПРИЦІЛ %s — %d м · PgUp/PgDn%s" % [w.data.name,w.sight_label(),w.scope_zero,"   ПРЯМИЙ ПОСТРІЛ: ЦІЛЬСЯ В НИЖНІЙ КРАЙ ЦІЛІ" if direct else ""],HORIZONTAL_ALIGNMENT_LEFT,-1,14,col)
	if game.player.barrel_blocked and not game.player.field_rig.active():draw_string(font,center+Vector2(-95,48),"СТВОЛ ПЕРЕКРИТО",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e5a17e"))
	var status := ""
	if game.player.last_wound=="blunt" and game.player.injury_time>0:status="УДАР У БРОНЕПЛИТУ · ЦІЛІСНІСТЬ %d %%" % int(game.player.plate_integrity*100)
	if game.player.blind_mode!=0:status="ВОГОНЬ БЕЗ ВІЗУАЛЬНОГО КОНТРОЛЮ"
	elif absf(game.player.lean)>0.1:status="ВИГЛЯДАННЯ З-ЗА УКРИТТЯ"
	if game.player.prone:status+="   ЛЕЖАЧИ · Z — ПІДВЕСТИСЯ"
	if game.player.bleeding>0:status+="   КРОВОТЕЧА · H — АПТЕЧКА (%d)" % game.player.medical_count()
	if game.player.bandage_time>0:status="АПТЕЧКА  %.1f с" % game.player.bandage_time
	if game.player.leg_injury>0:status+="   ПОРАНЕННЯ НОГИ"
	if game.player.arm_injury>0:status+="   РУКА: СТРІЛЬБА НЕДОСТУПНА · H"
	if game.player.concussion.active():status+="   КОНТУЗІЯ · АПТЕЧКА НЕ ВІДНОВЛЮЄ БОЄЗДАТНІСТЬ"
	if game.player.concussion.incapacitated():status="ТЯЖКА КОНТУЗІЯ · ПОТРІБНА ЕВАКУАЦІЯ"
	draw_string(font,Vector2(24,size.y-150),status,HORIZONTAL_ALIGNMENT_LEFT,-1,15,col)
	var drone: ReconDrone=game.player.field_rig.drone
	var crew_prompt: String=game.crew.prompt() if not game.commands_open else ""
	if is_instance_valid(drone) and not game.player.field_rig.active() and drone.can_recover():
		draw_string(font,center+Vector2(-140,90),"F — СКЛАСТИ ДРОН У НАПЛІЧНИК",HORIZONTAL_ALIGNMENT_LEFT,-1,16,col)
	elif crew_prompt!="":
		draw_string(font,center+Vector2(-170,90),crew_prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,16,col)
	elif game.player.field_rig.work_notice!="" and not game.player.field_rig.active():
		draw_string(font,Vector2(24,size.y-120),game.player.field_rig.work_notice,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e5a17e"))
	elif game.player.field_rig.drone_notice!="":
		draw_string(font,Vector2(24,size.y-120),game.player.field_rig.drone_notice,HORIZONTAL_ALIGNMENT_LEFT,-1,14,col)
	if game.player.bandage_time>0:
		var progress: float=1-game.player.bandage_time/Operator.MEDICAL_TIME
		var bar := Rect2(center.x-140,size.y-190,280,8)
		draw_rect(bar,Color(0.12,0.16,0.14,0.9))
		draw_rect(Rect2(bar.position,Vector2(bar.size.x*progress,bar.size.y)),Color("c6bb92"))

	var estimate: String=game.player.current().inspection_estimate()
	if estimate!="":
		var popup := Rect2(center.x-205,size.y*0.72,410,44)
		draw_rect(popup,Color(0.025,0.045,0.035,0.88))
		draw_string(font,popup.position+Vector2(16,28),estimate,HORIZONTAL_ALIGNMENT_LEFT,-1,17,col)
	var field: FieldRig=game.player.field_rig
	var launcher: LauncherRig=game.player.launcher
	# Every action that takes time: how to call it off (Operator.cancel_action).
	var cancel_line: String=game.player.cancel_hint()
	if cancel_line!="":
		var width := font.get_string_size(cancel_line,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		draw_string(font,Vector2(center.x-width*0.5,size.y-64),cancel_line,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e4bf68"))
	elif game.player.cancel_notice!="":
		var width := font.get_string_size(game.player.cancel_notice,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		draw_string(font,Vector2(center.x-width*0.5,size.y-64),game.player.cancel_notice,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e5a17e"))
	if not launcher.active() and launcher.notice_left>0:
		draw_string(font,Vector2(center.x-310,size.y-90),launcher.notice,HORIZONTAL_ALIGNMENT_LEFT,-1,15,col)
	if launcher.active():
		if launcher.through_scope():draw_pgo7(center)
		var short: String={"rpo_a":"РПО-А","rpg7":"РПГ-7","rpg22":"РПГ-22"}[launcher.kind]
		var text := "РПО-А «ШМЕЛЬ» · ПКМ — ПРИЦІЛ · ЛКМ — ПОСТРІЛ · 4 — ПРИБРАТИ"
		if launcher.kind=="rpg7":
			var stock := PackedStringArray()
			for which in LauncherRig.RPG7_ROUNDS:
				var count: int=game.player.backpack.count(which)
				if count>0 or which=="pg7vl":stock.append("%s %d" % [LauncherRig.ROUND_TITLE[which],count])
			var choice := " (УТРИМАЙ — ВИБІР)" if launcher.rpg7_rounds().size()>1 else ""
			text="РПГ-7В1 · %s · ПОСТРІЛИ: %s · ПКМ — ПГО-7 · ЛКМ — ПОСТРІЛ · R — ЗАРЯДИТИ%s · 4 — ПРИБРАТИ" % [("ЗАРЯДЖЕНО "+LauncherRig.ROUND_TITLE[launcher.loaded_round()]) if launcher.loaded() else "НЕ ЗАРЯДЖЕНО"," / ".join(stock),choice]
			# The PGO-7's chevrons are laid for the PG-7VL (LauncherRig.OG7V_PGO).
			if launcher.loaded_round()=="og7v":
				var hint := LauncherRig.og7v_hint()
				draw_string(font,Vector2(center.x-font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x*0.5,size.y-114),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e4bf68"))
		elif launcher.kind=="rpg22":
			if launcher.armed():text="РПГ-22 · БОЙОВЕ ПОЛОЖЕННЯ · РАМКА 5 / 15 / 25 — 50 / 150 / 250 м · ПКМ — ПРИЦІЛ · ЛКМ — ПОСТРІЛ · 4 — ПРИБРАТИ"
			else:text="РПГ-22 · ПОХІДНЕ ПОЛОЖЕННЯ · R — ПРИВЕСТИ В БОЙОВЕ (НАЗАД НЕ СКЛАДАЄТЬСЯ) · 4 — ПРИБРАТИ"
		if launcher.mode=="draw":
			text="ЗНЯТТЯ %s З КРІПЛЕННЯ · %.1f с" % [short,maxf(0,float(LauncherRig.DRAW[launcher.kind])-launcher.timer)]
		elif launcher.mode=="arm":text="ПЕРЕВЕДЕННЯ РПГ-22 В БОЙОВЕ ПОЛОЖЕННЯ · %.1f с" % maxf(0,LauncherRig.ARM_TIME-launcher.timer)
		elif launcher.mode=="load":text="ЗАРЯДЖАННЯ %s · %.1f с" % [LauncherRig.ROUND_TITLE.get(launcher.loading,"ПОСТРІЛУ"),maxf(0,LauncherRig.LOAD_TIME-launcher.timer)]
		elif launcher.mode=="stow":text="ПОВЕРНЕННЯ %s НА КРІПЛЕННЯ" % short
		elif launcher.mode=="spent":text="ВІДКИДАННЯ ВІДСТРІЛЯНОЇ ТРУБИ"
		if launcher.notice!="":text=launcher.notice
		# A long line (the RPG-7's) is centred to stay on the screen.
		draw_string(font,Vector2(center.x-maxf(325,font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x*0.5),size.y-90),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,col)
		return
	if field!=null and field.active():
		var text := ""
		if field.mode=="rangefinder":
			var radius := size.y*0.40
			var eye := center
			for i in range(96):
				var a := TAU*i/96
				var b := TAU*(i+1)/96
				var points := PackedVector2Array([eye+Vector2(cos(a),sin(a))*radius,eye+Vector2(cos(b),sin(b))*radius,eye+Vector2(cos(b),sin(b))*size.x*2,eye+Vector2(cos(a),sin(a))*size.x*2])
				draw_colored_polygon(points,Color("090d0b"))
			draw_line(center+Vector2(-12,0),center+Vector2(12,0),Color("d3b26d"),1)
			draw_line(center+Vector2(0,-12),center+Vector2(0,12),Color("d3b26d"),1)
			draw_string(font,center+Vector2(-150,80),field.reading,HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("edb962"))
			text="ДАЛЕКОМІР · %d× · КОЛІЩАТКО — КРАТНІСТЬ %d–%d× · ЛКМ — ВИМІРЯТИ · K — ПРИБРАТИ" % [field.zoom,FieldRig.ZOOM_MIN,FieldRig.ZOOM_MAX]
		elif field.mode=="work":
			text="%s · %.1f с" % [field.work_title,maxf(0,field.work_time-field.timer)]
			var bar := Rect2(center.x-160,size.y-118,320,8)
			draw_rect(bar,Color(0.12,0.16,0.14,0.9))
			draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(field.timer/maxf(field.work_time,0.01),0,1),bar.size.y)),Color("c6bb92"))
		elif field.mode=="pouch":text="ДАЛЕКОМІР З ПІДСУМКА НА БРОНІ"
		elif field.mode=="pouch_stow":text="ДАЛЕКОМІР У ПІДСУМОК"
		elif field.mode=="goggles":text="НАДЯГАННЯ FPV-ОКУЛЯРІВ"
		elif field.mode=="recover_drone":text="СКЛАДАННЯ ДРОНА В НАПЛІЧНИК"
		elif field.mode!="":text="НАПЛІЧНИК · "+("ПОВЕРНЕННЯ ПРЕДМЕТА" if field.mode=="stow" else "ДІСТАВАННЯ · %.1f с" % maxf(0,FieldRig.ACCESS_TIME-field.timer))
		elif game.inventory.transfer.active:
			var tx: MagazineTransfer=game.inventory.transfer
			if tx.belt:text="ЦИНК ЗІ СТРІЧКОЮ З НАПЛІЧНИКА" if tx.draw_left>0 else ("ЦИНК У НАПЛІЧНИК" if tx.moved>0 else "ЗАМІНА СТРІЧКИ В КОРОБЦІ ПКМ")
			else:text="ДІСТАВАННЯ З НАПЛІЧНИКА" if tx.box_bag!=null and tx.draw_left>0 else "СПОРЯДЖЕННЯ МАГАЗИНА"
		draw_string(font,Vector2(center.x-260,size.y-90),text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,col)

func draw_drone_view() -> void:
	var drone: ReconDrone=game.player.field_rig.drone
	if not is_instance_valid(drone):return
	var font := ThemeDB.fallback_font
	var ink := Color("d7e7cb")
	var center := size*0.5
	var screen: Rect2=game.screen_rect(self)
	draw_rect(screen,Color(0.015,0.022,0.018,0.9),false,24)
	draw_rect(Rect2(24,24,size.x-48,52),Color(0.015,0.025,0.018,0.72))
	draw_string(font,Vector2(40,57),"FPV / РОЗВІДКА     АКБ %d %% · ≈%d хв     ЗВ’ЯЗОК %d %%" % [roundi(drone.battery*100),floori(drone.battery*ReconDrone.FLIGHT_SECONDS/60.0),roundi(drone.signal_strength*100)],HORIZONTAL_ALIGNMENT_LEFT,-1,20,ink)
	draw_string(font,Vector2(40,103),"НАД ЗЕМЛЕЮ %.1f м     %.1f км/год     ВЕРТ %+.1f м/с     ДО ПІЛОТА %.0f м     %s" % [drone.floor_height,Vector2(drone.velocity.x,drone.velocity.z).length()*3.6,drone.velocity.y,drone.global_position.distance_to(game.player.global_position),drone.mode_text()],HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
	for side in [-1,1]:draw_line(center+Vector2(side*10,0),center+Vector2(side*45,0),ink,1)
	draw_line(center+Vector2(0,-8),center+Vector2(0,8),ink,1)
	draw_string(font,Vector2(40,size.y-95),drone.notice,HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
	var alarm := drone.alarm()
	if alarm!="":
		var blink := 0.55+0.45*absf(sin(float(Time.get_ticks_msec())*0.008))
		draw_string(font,Vector2(0,size.y*0.30),alarm,HORIZONTAL_ALIGNMENT_CENTER,size.x,26,Color(0.92,0.32,0.26,blink))
	draw_string(font,Vector2(40,size.y-65),"WASD — РУХ (ВІДПУСТИ — ГАЛЬМУЄ Й ЗАВИСАЄ) · МИША — КУРС / КАМЕРА · SPACE / CTRL — ВИСОТА · SHIFT — СПОРТ",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	draw_string(font,Vector2(40,size.y-39),"J — ЗНЯТИ ОКУЛЯРИ (ДРОН ЗАВИСНЕ, КАРТИНКА — НА НАРУЧНОМУ ЕКРАНІ, U) · F — МОТОРИ ПІСЛЯ ПОСАДКИ",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	if drone.signal_strength<0.3:
		var loss := 1-drone.signal_strength/0.3
		for i in range(0,int(size.y),5):
			var flicker := absf(sin(i*13.4+float(Time.get_ticks_msec())*0.06))
			draw_line(Vector2(screen.position.x,i),Vector2(screen.end.x,i),Color(flicker,flicker,flicker,loss*0.55),2)
		if drone.signal_strength<0.04:
			draw_rect(screen,Color(0.04,0.05,0.04,0.96))
			draw_string(font,center-Vector2(130,0),"ВТРАТА ВІДЕОЗВ’ЯЗКУ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,ink)

# The PGO-7V3 at the eye: the round eyepiece, the PG-7VL's range chevrons
# 2…5 (200…500 m; the top one is the optical axis), the lead scale in
# thousandths beside the top chevron and the stadia scale for a tank 2.7 m
# high (2…10 — 200…1000 m) at the lower left. Every mark is laid off the
# grenade's flight in the game (LauncherRig), so the chevron of the range on
# the target sends the grenade there.
func draw_pgo7(center: Vector2) -> void:
	var camera: Camera3D=game.player.camera
	var radius := size.y*0.45
	var per_radian := size.y*0.5/tan(deg_to_rad(camera.fov)*0.5)
	var ink := Color(0.03,0.03,0.025,0.95)
	var font := ThemeDB.fallback_font
	for i in range(96):
		var a := TAU*i/96
		var b := TAU*(i+1)/96
		draw_colored_polygon(PackedVector2Array([center+Vector2(cos(a),sin(a))*radius,center+Vector2(cos(b),sin(b))*radius,center+Vector2(cos(b),sin(b))*size.x*2,center+Vector2(cos(a),sin(a))*size.x*2]),Color(0,0,0,1))
	draw_arc(center,radius-5,0,TAU,96,Color(0,0,0,0.45),10)
	for distance in [200,300,400,500]:
		var y := center.y+tan(LauncherRig.pgo_chevron(distance))*per_radian
		var arm := 10.0
		draw_polyline(PackedVector2Array([Vector2(center.x-arm,y+arm*0.75),Vector2(center.x,y),Vector2(center.x+arm,y+arm*0.75)]),ink,2.0)
		draw_string(font,Vector2(center.x+arm+5,y+13),str(distance/100),HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	var mil := TAU/6000.0
	for k in range(1,5):
		for side in [-1,1]:
			var x: float=center.x+float(side)*tan(k*10*mil)*per_radian
			var tall := 14.0 if k%2==0 else 8.0
			draw_line(Vector2(x,center.y-tall*0.5),Vector2(x,center.y+tall*0.5),ink,1.6)
			if k%2==0:draw_string(font,Vector2(x-8,center.y-tall*0.5-4),str(k*10),HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
	var base_y := center.y+radius*0.55
	var x_left := center.x-radius*0.78
	var x_right := center.x-radius*0.12
	draw_line(Vector2(x_left,base_y),Vector2(x_right,base_y),ink,1.6)
	var curve := PackedVector2Array()
	for step in range(33):
		var hundreds := 2.0+step*0.25
		var x := lerpf(x_left,x_right,(hundreds-2.0)/8.0)
		curve.append(Vector2(x,base_y-tan(2.7/(hundreds*100.0))*per_radian))
	for i in range(0,curve.size()-1,2):draw_line(curve[i],curve[i+1],ink,1.6)
	for hundreds in [2,4,6,8,10]:
		var x := lerpf(x_left,x_right,(hundreds-2.0)/8.0)
		draw_line(Vector2(x,base_y),Vector2(x,base_y+5),ink,1.4)
		draw_string(font,Vector2(x-5,base_y+19),str(hundreds),HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
