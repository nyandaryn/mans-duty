extends SceneTree

# Screenshots of a house brought down by a «Grad» rocket: before, in the dust,
# the heap after; a brick house of a strongpoint the same. Prints how long
# the collapse frame and the next ones took.
var game: Node3D
var out := ""
func _initialize():call_deferred("run")
func frames(n: int):
 for i in range(n):await process_frame
func snap(name: String, settle: int=1):
 await frames(settle)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("SNAP ",name," FPS=",Engine.get_frames_per_second())

func look_at_house(house: Dictionary, distance: float) -> void:
 var center: Vector3=house.center
 var houses: Array=game.district.get_meta("houses",[])
 var best:=Vector3.INF
 for k in range(24):
  var a:=TAU*k/24.0
  var spot:=center+Vector3(cos(a),0,sin(a))*distance
  spot.y=game.district.ground_height(spot)+0.05
  var clear:=true
  for other in houses:
   if other!=house and Demolition.inside(other,spot+Vector3.UP,1.5):clear=false;break
  if not clear:continue
  var hit: Dictionary=game.district.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(spot+Vector3.UP*1.6,center+Vector3.UP*1.5,1))
  if hit.is_empty() or Demolition.inside(house,hit.position,0.4):best=spot;break
 if best==Vector3.INF:best=center+Vector3(distance,0,0);best.y=game.district.ground_height(best)+0.05
 game.player.global_position=best
 var d:=center+Vector3.UP*1.5-(best+Vector3.UP*1.6)
 game.player.rotation.y=atan2(-d.x,-d.z)
 game.player.pitch=atan2(d.y,Vector2(d.x,d.z).length())

func hit(house: Dictionary, name: String) -> void:
 look_at_house(house,float(Vector2(house.half).length())+11.0)
 await snap(name+"-before",20)
 var t0:=Time.get_ticks_usec()
 game.blasts.detonate(Vector3(house.center)+Vector3.UP*(float(house.height)-0.8),"grad")
 var t1:=Time.get_ticks_usec()
 var worst:=0
 for i in range(10):
  var a:=Time.get_ticks_usec()
  await process_frame
  worst=maxi(worst,Time.get_ticks_usec()-a)
 print("COLLAPSE %s: detonate %.1f ms, worst of next 10 frames %.1f ms" % [name,(t1-t0)/1000.0,worst/1000.0])
 await snap(name+"-dust",10)
 await snap(name+"-after",420)
 await snap(name+"-settled",900)

func run():
 out=OS.get_environment("KVARTAL_PREVIEW_DIR")
 game=load("res://main.tscn").instantiate()
 game.set_meta("automated_preview",true)
 root.add_child(game)
 await process_frame
 game.volume=0
 game.set_player_class("rifleman")
 game.battle_size=18
 game.selected_map=BattleMap.ID
 game.start_match()
 game.battle.skip_approach()
 for actor in game.bots+game.allies:actor.set_physics_process(false)
 for squad in game.battle.mech:squad.set_physics_process(false);squad.vehicle.gunner.allowed=false
 game.player.set_physics_process(false)
 game.set_debug_invulnerable(true)
 await frames(30)
 var houses: Array=game.district.get_meta("houses",[])
 var light: Dictionary={}
 for house in houses:
  if not house.full and Vector2(house.half).x>3.5 and Vector2(house.half).y>3.0 and float(house.height)>5.0 and Vector3(house.center).length()<120.0:light=house;break
 await hit(light,"demolish-house")
 var keep: Dictionary=houses.filter(func(h):return h.full)[1]
 await hit(keep,"demolish-strongpoint")
 quit()
