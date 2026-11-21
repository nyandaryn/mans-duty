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
	if not launcher.active() and launcher.notice_left>0:
		draw_string(font,Vector2(center.x-310,size.y-90),launcher.notice,HORIZONTAL_ALIGNMENT_LEFT,-1,15,col)
	if launcher.active():
		var text := "РПО-А «ШМЕЛЬ» · ПКМ — ПРИЦІЛ · ЛКМ — ПОСТРІЛ · 4 — ПРИБРАТИ"
		if launcher.mode=="draw":text="ЗНЯТТЯ РПО-А З КРІПЛЕННЯ · %.1f с" % maxf(0,LauncherRig.ACCESS_TIME-launcher.timer)
		elif launcher.mode=="stow":text="ПОВЕРНЕННЯ РПО-А НА КРІПЛЕННЯ"
		elif launcher.mode=="spent":text="ВІДКИДАННЯ ВІДСТРІЛЯНОЇ ТРУБИ"
		if launcher.notice!="":text=launcher.notice
		draw_string(font,Vector2(center.x-325,size.y-90),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,col)
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
			text="%s · %.1f с · РУХ — СКАСУВАТИ" % [field.work_title,maxf(0,field.work_time-field.timer)]
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
			text=("ДІСТАВАННЯ З НАПЛІЧНИКА" if tx.box_bag!=null and tx.draw_left>0 else "СПОРЯДЖЕННЯ МАГАЗИНА")+" · TAK — ПЕРЕРВАТИ"
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
	draw_string(font,Vector2(40,103),"НАД ЗЕМЛЕЮ %.1f м     %.1f км/год     ДО ПІЛОТА %.0f м" % [drone.floor_height,drone.velocity.length()*3.6,drone.global_position.distance_to(game.player.global_position)],HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
	for side in [-1,1]:draw_line(center+Vector2(side*10,0),center+Vector2(side*45,0),ink,1)
	draw_line(center+Vector2(0,-8),center+Vector2(0,8),ink,1)
	draw_string(font,Vector2(40,size.y-95),drone.notice,HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
	var alarm := drone.alarm()
	if alarm!="":
		var blink := 0.55+0.45*absf(sin(float(Time.get_ticks_msec())*0.008))
		draw_string(font,Vector2(0,size.y*0.30),alarm,HORIZONTAL_ALIGNMENT_CENTER,size.x,26,Color(0.92,0.32,0.26,blink))
	draw_string(font,Vector2(40,size.y-65),"WASD — РУХ · МИША — КУРС / КАМЕРА · SPACE / CTRL — ВИСОТА · SHIFT — ШВИДШЕ",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	draw_string(font,Vector2(40,size.y-39),"J — ЗНЯТИ ОКУЛЯРИ (ДРОН ЗАВИСНЕ, КАРТИНКА — НА НАРУЧНОМУ ЕКРАНІ, U) · F — МОТОРИ ПІСЛЯ ПОСАДКИ",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	if drone.signal_strength<0.3:
		var loss := 1-drone.signal_strength/0.3
		for i in range(0,int(size.y),5):
			var flicker := absf(sin(i*13.4+float(Time.get_ticks_msec())*0.06))
			draw_line(Vector2(screen.position.x,i),Vector2(screen.end.x,i),Color(flicker,flicker,flicker,loss*0.55),2)
		if drone.signal_strength<0.04:
			draw_rect(screen,Color(0.04,0.05,0.04,0.96))
			draw_string(font,center-Vector2(130,0),"ВТРАТА ВІДЕОЗВ’ЯЗКУ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,ink)
