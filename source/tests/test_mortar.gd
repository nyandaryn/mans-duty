extends SceneTree
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failed=true;printerr("FAIL: ",message)
func _initialize():call_deferred("run")

func settle(game, crew: MortarCrew, seconds: float) -> void:
 var steps := int(seconds/0.1)
 for i in range(steps):
  crew.mortar._physics_process(0.1)
  crew._physics_process(0.1)

func run():
 seed(820014)
 # Ballistics calibrated to the published envelope of the 2B14 / O-832DU.
 var minimum: float=MortarBallistics.simulate(0,MortarBallistics.ELEVATION_MAX).range
 check(absf(minimum-85)<3,"Charge 0 at 85° gives the 85 m minimum range (%.1f m)" % minimum)
 var full: float=MortarBallistics.simulate(4,MortarBallistics.ELEVATION_MIN).range
 check(absf(full-3100)<40,"Full variable charge reaches about 3100 m (%.0f m)" % full)
 var longest: float=MortarBallistics.simulate(5,MortarBallistics.ELEVATION_MIN).range
 check(absf(longest-3922)<25,"Long-range charge reaches 3922 m (%.0f m)" % longest)
 check(MortarBallistics.mils_text(1186)=="11-86" and MortarBallistics.mils_text(45)=="00-45" and MortarBallistics.mils_text(-10)=="59-90","Thousandths in Soviet notation")
 check(MortarBallistics.azimuth(Vector3(0,0,-1))==0 and MortarBallistics.azimuth(Vector3(1,0,0))==1500 and MortarBallistics.azimuth(Vector3(0,0,1))==3000 and MortarBallistics.azimuth(Vector3(-1,0,0))==4500,"Grid bearing runs clockwise from north")
 check(MortarBallistics.direction(1500).distance_to(Vector3(1,0,0))<0.0001,"Bearing converts back to a direction")
 var setting: float=MortarBallistics.elevation_for(0,300)
 check(setting>750 and setting<1417 and absf(MortarBallistics.range_for(0,setting)-300)<0.5,"Table inverts range to sight setting")
 check(MortarBallistics.elevation_for(0,600)<0 and MortarBallistics.elevation_for(0,60)<0,"Ranges outside a charge are refused")
 var rows: Array=MortarBallistics.firing_rows(1)
 check(rows.size()>=8 and rows[0].elevation>rows[-1].elevation and rows[0].per_mil>0 and rows[0].time>rows[-1].time,"Printed table: higher setting, shorter range, longer flight")
 var coarse: float=MortarBallistics.simulate(1,1000).range
 var fine_position := Vector3.ZERO
 var fine_velocity: Vector3=MortarBallistics.launch_velocity(1,1000,0)
 for i in range(20000):
  var next: Array=MortarBallistics.advance(fine_position,fine_velocity,1.0/120)
  var p: Vector3=next[0]
  if p.y<0:break
  fine_position=p;fine_velocity=next[1]
 check(absf(Vector2(fine_position.x,fine_position.z).length()-coarse)<1.0,"World flight step agrees with the table integration")

 var game=load("res://main.tscn").instantiate();game.set_meta("automated_preview",true);root.add_child(game);await process_frame
 game.volume=0
 # Classes: weapons, ammunition and group.
 game.loadout_bag.equipped=true;game.loadout_bag.add("rpo_a");game.loadout_bag.add("ammo_ak74")
 var removed: Array=game.set_player_class("sniper")
 check(game.primary=="svd" and game.ally_count==0 and removed.size()==2 and game.loadout_bag.items.is_empty(),"Sniper: SVD only, no group, other calibres leave the pack")
 check(game.loadout_screen.picker.options()==["svd"],"Weapon picker offers only the class weapons")
 game.loadout_screen.refresh()
 check(not game.loadout_screen.catalog_tiles.rpo_a.visible and game.loadout_screen.catalog_tiles.ammo_svd.visible and not game.loadout_screen.catalog_tiles.mortar_mine.visible,"Catalogue shows the sniper's items")
 game.set_player_class("rifleman")
 check(game.primary=="ak74" and game.loadout_screen.picker.options()==["ak74","m16"],"Rifleman takes AK-74M or M16")
 game.set_player_class("mortarman")
 game.loadout_screen.refresh()
 check(game.primary=="ak74" and game.ally_count==1 and game.loadout_screen.catalog_tiles.mortar_mine.visible and not game.loadout_screen.catalog_tiles.rpo_a.visible,"Mortarman: AK-74M, one assistant, mines in the catalogue")
 game.loadout_screen.add_item("rpo_a")
 check(game.loadout_bag.count("rpo_a")==0,"Catalogue refuses an item the class cannot carry")
 game.loadout_bag.add("mortar_mine")

 game.battle_size=18;game.selected_map=BattleMap.ID;game.start_match()
 # The column is taken as arrived: the groups are on the start line.
 game.battle.skip_approach()
 for squad in game.battle.mech:squad.vehicle.set_physics_process(false);squad.vehicle.gunner.manned=false
 game.set_physics_process(false);game.battle.set_physics_process(false);game.squad.set_physics_process(false);game.crew.set_physics_process(false)
 game.blasts.set_physics_process(false)
 for actor in game.allies+game.bots:actor.set_physics_process(false)
 game.player.set_physics_process(false)
 var crew: MortarCrew=game.crew
 var battle: BattleMode=game.battle
 check(crew.active() and crew.mortar.state=="carried" and is_instance_valid(crew.assistant) and crew.assistant==game.allies[0],"Mortar crew: the 2B14 and one assistant")
 check(crew.assistant_plate and crew.assistant_mines==10 and crew.assistant.get_meta("crew_role")=="assistant","Assistant carries the baseplate and a box of ten mines")
 check(game.player.backpack.count("mortar_mine")==1,"Mortarman can carry mines in his own pack")
 check(game.player.carried_mass()>Equipment.carried_mass(game.player.weapons,game.player.backpack,game.player.bandages)+30,"Barrel and bipod weigh on the mortarman")
 check(battle.halted and battle.awaiting and battle.status().contains("ОЧІКУЄ КОМАНДИ"),"Assault waits for the mortarman's order")
 var managed: Hostile=null
 for actor in game.allies:
  if actor.get_meta("battle_managed",false) and actor.vehicle==null:managed=actor;break
 battle.assign(managed)
 check(managed.assault_arrived and managed.home.distance_to(managed.get_meta("halt_point"))<0.1,"Held groups consolidate where they stand")
 check(battle.successor()!=crew.assistant,"Command does not pass to the assistant while others live")
 # Deployment needs the baseplate: the assistant has to be near.
 crew.assistant.global_position=game.player.global_position+Vector3(40,0,0)
 check(not crew.deploy() and game.player.field_rig.mode=="","No baseplate within reach, no deployment")
 crew.assistant.global_position=game.player.global_position+Vector3(2,0,0)
 var stand: Vector3=game.player.global_position
 check(crew.deploy() and game.player.field_rig.mode=="work" and crew.mortar.state=="assembling" and crew.mortar.visible,"Deployment is hands-on work in view")
 check(game.player.crouch_requested and crew.assistant.get_meta("crew_kneel",false) and crew.assistant.order=="hold","Mortarman and assistant kneel at the work")
 game.player.field_rig.tick(MortarCrew.DEPLOY_TIME*0.1);crew._physics_process(0.016)
 var plate_height: float=crew.mortar.base.position.y
 check(crew.mortar.assembly>0.05 and crew.mortar.assembly<0.2 and plate_height>0.1 and not crew.mortar.pivot.visible and not crew.mortar.legs[0].visible,"The baseplate goes down first")
 check(game.player.field_rig.work_target.distance_to(crew.mortar.base.global_position)<0.01,"Hands work at the plate")
 game.player.field_rig.tick(MortarCrew.DEPLOY_TIME*0.3);crew._physics_process(0.016)
 check(crew.mortar.base.position.y<0.01 and crew.mortar.legs[0].visible and not crew.mortar.sight.visible,"Then the bipod is raised")
 Input.action_press("forward")
 game.player._physics_process(1.0/60)
 Input.action_release("forward")
 crew._physics_process(0.016)
 check(game.player.field_rig.mode=="" and game.player.field_rig.work_notice.contains("СКАСОВАНО") and crew.mortar.state=="carried" and not crew.mortar.visible,"A step cancels the deployment")
 check(not crew.assistant.has_meta("crew_kneel") and crew.assistant_plate,"Cancelled: the assistant keeps the plate and stands up")
 game.player.velocity=Vector3.ZERO;game.player.global_position=stand
 check(crew.deploy(),"Deployment restarts")
 game.player.field_rig.tick(3);crew._physics_process(0.016)
 crew.toggle_deploy()
 check(game.player.field_rig.mode=="" and crew.mortar.state=="carried" and crew.assembling=="","N again calls off the deployment")
 game.player.global_position+=Vector3(0.3,0,0)
 check(crew.deploy(),"Deployment restarts")
 game.player.global_position+=Vector3(1.5,0,0)
 game.player.field_rig.tick(0.1);crew._physics_process(0.016)
 check(game.player.field_rig.mode=="" and game.player.field_rig.work_notice.contains("ПЕРЕРВАНО") and crew.mortar.state=="carried","Being pushed away interrupts deployment")
 game.player.global_position=stand
 game.player.rotation.y=-PI/2
 await physics_frame
 check(crew.deploy(),"Deployment restarts")
 game.player.field_rig.tick(MortarCrew.DEPLOY_TIME-1);crew._physics_process(0.016)
 check(crew.mortar.state=="assembling" and crew.mortar.pivot.visible and crew.mortar.sight.visible,"Barrel and sight fitted last; deployment takes its full time")
 game.player.field_rig.tick(1.1)
 check(crew.mortar.state=="deployed" and not crew.assistant_plate and crew.mortar.visible,"Mortar laid on the baseplate")
 check(absi(crew.mortar.azimuth-1500)<=1,"Main direction is where the mortarman faced")
 check(game.player.carried_mass()<Equipment.carried_mass(game.player.weapons,game.player.backpack,game.player.bandages)+1,"A deployed mortar is off the back")
 # Sight: charge, elevation and bearing; traverse limits of the bipod.
 check(crew.interact() and crew.sight.visible and game.commands_open,"F at the mortar opens the sight")
 crew.mortar.set_azimuth(crew.mortar.azimuth+40)
 check(crew.mortar.relay_left==0 and crew.mortar.traverse_offset()==40,"Small corrections stay on the traversing mechanism")
 crew.mortar.set_azimuth(crew.mortar.azimuth+300)
 check(crew.mortar.relay_left>0 and crew.mortar.traverse_offset()==0 and not crew.mortar.ready_to_fire(),"Large switch re-lays the bipod first")
 crew.mortar._physics_process(Mortar.RELAY_TIME+0.1)
 crew.mortar.set_azimuth(1500)
 crew.mortar._physics_process(Mortar.RELAY_TIME+0.1)
 crew.sight.choose_charge(0)
 var distance := 130.0
 crew.mortar.set_elevation(roundi(MortarBallistics.elevation_for(0,distance)))
 crew.sight.refresh()
 check(crew.sight.table.get_child_count()>=4*8 and crew.sight.settings.text.contains("ЗАРЯД 0"),"Sight shows settings and the firing table")
 # A live round from the pack, with the spread removed to test the trajectory.
 crew.mortar.spread=0
 for actor in game.allies+game.bots:
  if actor!=crew.assistant:actor.global_position=Vector3(-150,0.2,-150)
 var origin: Vector3=crew.mortar.global_position
 check(crew.player_fire() and game.player.backpack.count("mortar_mine")==0 and game.blasts.mines.size()==1,"Mortarman fires a mine from his pack")
 check(not crew.player_fire(),"Next round waits for loading")
 var flight := 0.0
 while not game.blasts.mines.is_empty() and flight<30:
  game.blasts._physics_process(1.0/60);flight+=1.0/60
  if int(flight*60)%30==0:await physics_frame
 var burst: Vector3=game.blasts.last_detonation
 var expected: float=MortarBallistics.range_for(0,crew.mortar.elevation)
 var travelled := Vector2(burst.x-origin.x,burst.z-origin.z)
 check(burst.is_finite() and absf(travelled.length()-expected)<5,"Burst lands at the table range (%.1f / %.1f m)" % [travelled.length(),expected])
 check(absf(rad_to_deg(Vector2(1,0).angle_to(travelled)))<2,"Burst lies on the laid bearing")
 check(absf(flight-MortarBallistics.time_for(0,crew.mortar.elevation))<0.6,"Time of flight matches the table (%.1f s)" % flight)
 crew.mortar._physics_process(Mortar.LOAD_TIME+0.1)
 check(not crew.player_fire(),"No mines in the box or the pack, no shot")
 crew.sight.close()
 # The assistant places the box beside the mortar.
 crew.command("box")
 check(crew.task=="box" and crew.assistant.order=="move","Assistant carries the box to the mortar")
 # Live: standing a few metres off, in contact with the enemy. A cover close
 # by must not stop him short of the spot (he used to stay put near the mortar).
 var helper: Hostile=crew.assistant
 helper.global_position=crew.task_point+Vector3(2.6,0,1.2)
 helper.alerted=true;helper.contact_age=0;helper.under_fire_time=3
 helper.target=crew.task_point+Vector3(0,0,-60)
 var walked := 0
 while crew.task=="box" and walked<600:
  helper._physics_process(1.0/60)
  crew._physics_process(1.0/60)
  walked+=1
  if walked%6==0:await physics_frame
 print("BOX walked=%.1f s" % (walked/60.0))
 check(crew.boxes.size()==1 and crew.boxes[0].mines==10 and crew.assistant_mines==0 and crew.task=="","Box with ten mines set down")
 check(crew.box_mines_at_mortar()==10,"Box is within reach of the mortar")
 # Mortarman takes a mine for himself.
 game.player.global_position=crew.boxes[0].global_position+Vector3(0,0.1,0.5)
 check(crew.box_first(crew.boxes[0]) and crew.prompt().contains("ВЗЯТИ МІНУ"),"F at the box offers a mine")
 check(crew.interact() and game.player.field_rig.mode=="work","Taking a mine is hands-on work")
 game.player.field_rig.tick(MortarCrew.TAKE_TIME+0.1)
 check(game.player.backpack.count("mortar_mine")==1 and crew.boxes[0].mines==9,"Mine moved from the box to the pack")
 # The assistant fires the laid mortar with his own mines (now in the box).
 crew.mortar.spread=1
 crew.command("fire3")
 check(crew.task=="fire" and not crew.assistant.fire_at_will,"Assistant takes up the fire mission")
 crew.assistant.global_position=crew.task_point
 settle(game,crew,13)
 check(crew.fired==3 and crew.boxes[0].mines==6 and crew.task=="" and crew.assistant.fire_at_will,"Assistant fired three mines from the laid mortar")
 check(game.blasts.mines.size()==3,"Three mines in flight")
 crew.command("fire_all")
 crew.assistant.global_position=crew.task_point
 settle(game,crew,4)
 crew.command("cease")
 check(crew.task=="" and crew.fired>=1 and crew.boxes[0].mines<6,"Cease fire stops the mission")
 # Assault control.
 crew.command("resume")
 check(not battle.halted and not battle.awaiting,"Order resumes the assault")
 battle.assign(managed)
 check(not managed.assault_arrived or managed.home.distance_to(battle.center())<40,"Groups head for the objective again")
 crew.command("halt")
 battle.assign(managed)
 check(battle.halted and not battle.awaiting and battle.status().contains("ПРИЗУПИНЕНО") and managed.assault_arrived,"Halt: groups consolidate and wait")
 crew.command("resume")
 # Packing returns the plate to the assistant; his loss leaves the load behind.
 game.player.global_position=crew.mortar.global_position+Vector3(-1,0.1,0)
 check(crew.pack() and crew.mortar.state=="packing","Pack-up starts near the mortar")
 game.player.field_rig.tick(MortarCrew.PACK_TIME*0.5);crew._physics_process(0.016)
 check(absf(crew.mortar.assembly-0.5)<0.05 and not crew.mortar.sight.visible and not crew.mortar.pivot.visible and crew.mortar.legs[0].visible,"Pack-up: sight and barrel off first, then the bipod")
 crew.toggle_deploy()
 check(crew.mortar.state=="deployed" and crew.mortar.assembly==1.0 and crew.mortar.sight.visible,"A cancelled pack-up leaves the mortar laid")
 check(crew.pack(),"Pack-up restarts")
 game.player.field_rig.tick(MortarCrew.PACK_TIME+0.1)
 check(crew.mortar.state=="carried" and crew.assistant_plate,"Mortar packed, baseplate back with the assistant")
 crew.assistant.die()
 crew._physics_process(0.1)
 check(not crew.assistant_ready() and crew.boxes.size()==2 and crew.boxes[1].plate,"Fallen assistant leaves the baseplate")
 check(not crew.deploy(),"No assistant, no plate: no deployment")
 game.player.global_position=crew.boxes[1].global_position+Vector3(0.6,0.1,0)
 check(crew.prompt().contains("ОПОРНУ ПЛИТУ") and crew.interact(),"Mortarman picks up the plate")
 game.player.field_rig.tick(MortarCrew.PLATE_TIME+0.1)
 check(crew.player_plate and game.player.carried_mass()>Equipment.carried_mass(game.player.weapons,game.player.backpack,game.player.bandages)+46,"Plate adds 17 kg")
 check(crew.deploy() and game.player.field_rig.work_time==MortarCrew.DEPLOY_ALONE,"Deploying alone takes longer")
 game.player.field_rig.tick(MortarCrew.DEPLOY_ALONE+0.1)
 check(crew.mortar.state=="deployed" and not crew.player_plate,"Mortar deployed by one man")
 # Map: a General Staff style sheet without any marks of the player.
 var started := Time.get_ticks_msec()
 check(game.topo_map.open() and game.commands_open,"M opens the map")
 print("MAP BUILD ms=",Time.get_ticks_msec()-started)
 var topo: TopoMap=game.topo_map
 print("MAP contours=",topo.contours.size()," buildings=",topo.buildings.size()," trees=",topo.trees.size()," roads=",topo.roads.size())
 check(topo.contours.size()>=3 and topo.buildings.size()>=40 and topo.trees.size()>100 and topo.roads.size()>=3,"Map shows the relief, houses, trees and streets of Avdiivka")
 var total := 0
 for contour in topo.contours:total+=contour.segments.size()
 check(total>200,"Contours are traced over the terrain (%d points)" % total)
 var north: Dictionary=TopoMap.measure(Vector2(0,0),Vector2(0,-100))
 var east: Dictionary=TopoMap.measure(Vector2(0,0),Vector2(100,0))
 check(absf(north.distance-100)<0.01 and north.azimuth==0 and east.azimuth==1500,"Map ruler gives distance and grid bearing")
 check(TopoMap.grid_label(7311900)=="11,9" and TopoMap.grid_label(5497800)=="97,8","Grid labelled in kilometres and hundreds")
 topo.zoom=3;topo.center=Vector2(150,150);topo.clamp_view()
 check(topo.center.x<=200-200/3.0+0.01,"Magnified map stays on the sheet")
 game.close_panels()
 check(not topo.visible and not game.commands_open,"Map closes")
 # Riflemen and snipers have no crew and no command menu.
 game.set_player_class("rifleman");game.start_match()
 check(not game.crew.active() and game.allies.size()==game.battle_size-0 and not game.battle.halted and game.battle.prep=="barrage","Rifleman: no crew, the assault starts with the battery's fire")
 game.crew.toggle()
 check(not game.crew.panel.visible,"Rifleman has no command menu")
 game.queue_free();await process_frame;await process_frame
 print("FAIL: " if failed else "PASS: ",checks," mortar / classes / crew / map checks")
 quit(1 if failed else 0)
