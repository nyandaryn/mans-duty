extends Control

var game: Node3D

func _draw() -> void:
	if not game.running: return
	var center := size/2
	var col := Color("f0e7cf")
	if not game.player.aim and game.player.blind_mode==0 and game.player.arm_injury<0.5 and game.player.bandage_time<=0:
		for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			draw_line(center+direction*5,center+direction*11,col,1)
	if game.damage_flash>0:
		var red := Color(0.65,0.13,0.08,game.damage_flash*0.5)
		draw_rect(Rect2(Vector2.ZERO,size),red,false,18)
	# Compass, with world-relative bearing.
	var bearing := fposmod(-rad_to_deg(game.player.rotation.y),360)
	var font := ThemeDB.fallback_font
	for i in range(-5,6):
		var x := center.x+i*42
		draw_line(Vector2(x,28),Vector2(x,34 if i%2 else 39),Color(0.8,0.82,0.72,0.65),1)
	draw_string(font,Vector2(center.x-27,60),"%03d°" % int(bearing),HORIZONTAL_ALIGNMENT_LEFT,-1,18,col)
	if game.debug_invulnerable:draw_string(font,Vector2(24,100),"DEBUG · БЕЗСМЕРТЯ / ПОПОВНЕННЯ МАГАЗИНІВ · F8",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e4bf68"))
	if game.player.barrel_blocked:draw_string(font,center+Vector2(-95,48),"СТВОЛ ПЕРЕКРИТО",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e5a17e"))
	var status := ""
	if game.player.last_wound=="blunt" and game.player.injury_time>0:status="УДАР У БРОНЕПЛИТУ · ЦІЛІСНІСТЬ %d %%" % int(game.player.plate_integrity*100)
	if game.player.blind_mode!=0:status="ВОГОНЬ БЕЗ ВІЗУАЛЬНОГО КОНТРОЛЮ"
	elif absf(game.player.lean)>0.1:status="ВИГЛЯДАННЯ З-ЗА УКРИТТЯ"
	if game.player.prone:status+="   ЛЕЖАЧИ · Z — ПІДВЕСТИСЯ"
	if game.player.bleeding>0:status+="   КРОВОТЕЧА · H — АПТЕЧКА (%d)" % game.player.bandages
	if game.player.bandage_time>0:status="АПТЕЧКА  %.1f с" % game.player.bandage_time
	if game.player.leg_injury>0:status+="   ПОРАНЕННЯ НОГИ"
	if game.player.arm_injury>0:status+="   РУКА: СТРІЛЬБА НЕДОСТУПНА · H"
	draw_string(font,Vector2(24,size.y-150),status,HORIZONTAL_ALIGNMENT_LEFT,-1,15,col)
	if game.player.bandage_time>0:
		var progress: float=1-game.player.bandage_time/Operator.MEDICAL_TIME
		var bar := Rect2(center.x-140,size.y-190,280,8)
		draw_rect(bar,Color(0.12,0.16,0.14,0.9))
		draw_rect(Rect2(bar.position,Vector2(bar.size.x*progress,bar.size.y)),Color("c6bb92"))
