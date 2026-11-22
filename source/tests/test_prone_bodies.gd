extends SceneTree

# Lying among bodies: wounded men down around him, the dead, a man lying
# prone. He crawls out past and over them and turns among them; a man
# standing in his way still stops him, and one who gets up again is solid.
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failed=true
		printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func frames(n: int):
	for i in range(n):await physics_frame

func crawl(player: Operator, action: String, seconds: float) -> float:
	var start := player.global_position
	Input.action_press(action)
	await frames(int(seconds*60))
	Input.action_release(action)
	return Vector2(player.global_position.x-start.x,player.global_position.z-start.z).length()

func lie_down(player: Operator, at: Vector3) -> void:
	player.global_position=at
	player.rotation=Vector3.ZERO
	player.prone_requested=true
	await frames(10)

# Eight men round him, half of them within reach of his body.
func ring(game: Node3D, at: Vector3, how: String) -> Array:
	var men: Array=[]
	for i in range(8):
		var bot: Hostile=game.bots[i]
		var angle := TAU*i/8
		bot.global_position=at+Vector3(cos(angle),0,sin(angle))*(1.1 if i%2==0 else 0.7)
		bot.rotation.y=angle+PI*0.5
		match how:
			"dead":
				bot.set_physics_process(true)
				bot.die()
			"wounded":
				bot.collapse=1.0
				bot.animate_pose(0.1,false)
			"prone":
				bot.tactical_prone=1.0
				bot.animate_pose(0.1,false)
		men.append(bot)
	return men

func away(men: Array) -> void:
	for bot in men:
		if is_instance_valid(bot):bot.global_position=Vector3(0,-300,0)

func run():
	var game: Node3D=load("res://main.tscn").instantiate()
	game.set_meta("automated_preview",true)
	root.add_child(game)
	await process_frame
	game.volume=0
	game.start_match()
	await frames(3)
	var player: Operator=game.player
	for bot in game.bots+game.allies:
		bot.set_physics_process(false)
		bot.position=Vector3(0,-300,0)
	var at := Vector3(0,0.05,35)
	# Wounded men down all round him.
	await lie_down(player,at)
	check(player.prone,"He lies down")
	var wounded := ring(game,at,"wounded")
	await frames(30)
	check(wounded.all(func(bot):return bot.lying),"The wounded lie on the ground")
	check(player.passable.size()==8,"…and he can crawl past every one of them (%d)" % player.passable.size())
	check(player.prone_turn_clear(PI/2) and player.prone_turn_clear(-PI/2),"He turns among them")
	var moved: float=await crawl(player,"forward",2.0)
	check(moved>1.2,"He crawls out over the wounded (%.2f m in 2 s)" % moved)
	# One gets up again: solid once more.
	var risen: Hostile=wounded[0]
	risen.collapse=0.0
	risen.animate_pose(0.1,false)
	check(not risen.lying and not player.passable.has(risen.get_instance_id()),"A man who gets up is solid again")
	away(wounded)
	for bot in wounded:
		bot.collapse=0.0
		bot.animate_pose(0.1,false)
	# Men lying prone by choice.
	await lie_down(player,at)
	var prone := ring(game,at,"prone")
	await frames(10)
	moved=await crawl(player,"back",2.0)
	check(moved>1.2,"He crawls out past men lying prone (%.2f m)" % moved)
	away(prone)
	for bot in prone:
		bot.tactical_prone=0.0
		bot.animate_pose(0.1,false)
	# A man standing in front of his head stops him.
	await lie_down(player,at+Vector3(6,0,0))
	var standing: Hostile=game.bots[0]
	standing.global_position=player.global_position+player.global_basis*Vector3(0,0,-0.55)
	standing.animate_pose(0.1,false)
	await frames(5)
	check(not standing.lying,"He stands")
	moved=await crawl(player,"forward",2.0)
	check(moved<0.4,"A standing man stops him (%.2f m)" % moved)
	standing.global_position=Vector3(0,-300,0)
	# The dead.
	await lie_down(player,at)
	var dead := ring(game,at,"dead")
	await frames(180)
	moved=await crawl(player,"left",2.0)
	check(moved>1.2,"He crawls out over the dead (%.2f m)" % moved)
	check(dead.all(func(bot):return not player.passable.has(bot.get_instance_id())),"The dead leave no exceptions behind")
	game.queue_free()
	await process_frame
	if checks<11:check(false,"Every step ran (%d checks)" % checks)
	print("%s: %d prone-among-bodies checks" % ["FAILED" if failed else "PASS",checks])
	quit(1 if failed else 0)
