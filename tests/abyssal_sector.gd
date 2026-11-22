extends "res://tests/game_test_tree.gd"
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,caption: String) -> void:
	print("PASS " if ok else "FAIL ",caption)
	failures+=int(not ok)
func run() -> void:
	for act in [1,2]:
		var game=load("res://scenes/main.tscn").instantiate()
		game.profile.path="user://abyssal-test.cfg"
		game.checkpoint_path="user://abyssal-test-run.cfg"
		root.add_child(game)
		current_scene=game
		game.profile.manual_only=true
		game.sector=4
		game.act=act
		game.start_game(false,4)
		game.set_physics_process(false)
		var stage=game.game_root
		var pressure=stage.get_node("TERRAIN/PressureBreach")
		pressure.set_physics_process(false)
		var actor=game.player
		for node in stage.get_node("Actors").get_children():
			node.set_physics_process(false)
			if node!=actor: node.collision_layer=0
		actor.remote_input=true
		actor.invulnerable_time=10000
		await physics_frame
		check(stage.decks.size()>50,"act %d retains a substantial multi-storey route"%act)
		check(game.camera_rig.max_x>620,"act %d retains the original map length"%act)
		check(game.gate_relays.terminals.size()==2,"act %d has exactly two boss-door relays"%act)
		check(not game.gate_relays.complete(),"act %d starts with its boss door locked"%act)
		for j in 2:
			check(game.gate_relays.return_points[j].distance_to(game.gate_relays.terminals[j].position) > 15, "act %d rescue return leads to the start of the relay route" % act)
		var cramped:=[]
		for a in stage.decks:
			for b in stage.decks:
				if b.y>a.y+.1 and b.y-a.y<2.30 and absf(a.x-b.x)<(a.z+b.z)*.5-.02: cramped.append([a,b])
		check(cramped.is_empty(),"act %d has no overlapping low ledges: %s"%[act,str(cramped)])
		for terminal in game.gate_relays.terminals:
			actor.global_position=terminal.global_position+Vector3(0,.86,0)
			check(game.gate_relays.interact(actor,false),"act %d relay can be activated on its landing"%act)
		check(game.gate_relays.complete(),"act %d both relays unlock the boss door"%act)
		# Real CharacterBody movement under the authored current; no teleport during ascent.
		var jet=get_nodes_in_group(&"abyssal_current")[0]
		actor.global_position=jet.global_position-Vector3.UP*(jet.dimensions.y*.5-.90)
		actor.velocity=Vector3.ZERO
		actor.remote_axis=Vector2.ZERO
		var start_y: float=actor.global_position.y
		for frame in 90:
			actor._physics_process(1.0/60)
			await physics_frame
		check(actor.global_position.y>start_y+6,"act %d current lifts the real player body"%act)
		check(actor.velocity.y<=jet.speed+.01,"act %d current speed stays capped"%act)
		actor.controls_suspended=true
		actor.velocity=Vector3.ZERO
		jet.apply_to(actor,.1)
		check(actor.velocity==Vector3.ZERO,"act %d suspended player is not pushed by a current"%act)
		actor.controls_suspended=false
		# Physics sample of rising, gap, descending and reverse jumps in each act.
		var route=stage.ROUTE_ONE if act==1 else stage.ROUTE_TWO
		for link_index in range(route.size()-1):
			if act==1 and link_index==1: continue # Separate physical current ascent above.
			var a: Vector3=route[link_index]
			var b: Vector3=route[link_index+1]
			if act==2 and a.x==104:
				check(await swim_passage(actor),"flooded conduit requires a real dive, rise and safe dry exit")
				await check_swimming_controls(actor)
				continue
			if act==2 and b.x==334:
				check(await climb_chimney(actor),"current-assisted wall kicks reach the chimney cache from the basement valve")
				continue
			if act==2 and b.x==445:
				pressure.apply_snapshot([7,90.0,true,true,[0,0,0]])
				pressure._process(2.0)
				await physics_frame
			var reached: bool=await jump(actor,a,b)
			if not reached: reached=await jump(actor,a,b,2.4)
			check(reached,"act %d real jump %d reaches its landing"%[act,link_index])
		var cavern_branch: Array = [Vector3(131,6.6,12),Vector3(139.1,8.65,4),Vector3(131.4,10.75,4),Vector3(123.6,12.55,4.5),Vector3(114,12.55,6)] if act == 1 else [Vector3(508,.75,10),Vector3(518,-2,5),Vector3(524,-3.4,4.6),Vector3(532,-3.9,6),Vector3(540,-2.4,4.6)]
		for i in range(cavern_branch.size()-1):
			var crossed: bool = await jump(actor, cavern_branch[i], cavern_branch[i+1])
			if not crossed: crossed = await jump(actor, cavern_branch[i], cavern_branch[i+1], 1.9)
			check(crossed, "act %d turbine chamber landing %d" % [act, i])
		var branch: Array = [Vector3(499,3.8,10),Vector3(506.75,6,5),Vector3(497,8.2,5),Vector3(486,10.4,7),Vector3(473,12.6,9),Vector3(460,14.8,8)] if act==1 else [Vector3(70,9.8,8),Vector3(80,12,5),Vector3(70,14.2,8),Vector3(56,16.4,10),Vector3(42,16.4,8),Vector3(28,16.4,8),Vector3(16,16.4,8)]
		for i in range(branch.size()-1):
			var reached: bool=await jump(actor,branch[i],branch[i+1])
			if not reached: reached=await jump(actor,branch[i],branch[i+1],2.4)
			check(reached,"act %d reverse relay branch jump %d is reachable"%[act,i])
		if act==2:
			var return_route:=[Vector3(493,1,10),Vector3(500,3.2,4),Vector3(490,5.4,5),Vector3(480,7.6,5),Vector3(468,9.8,9)]
			for i in range(return_route.size()-1):
				var reached: bool=await jump(actor,return_route[i],return_route[i+1])
				if not reached: reached=await jump(actor,return_route[i],return_route[i+1],2.4)
				check(reached,"act II second relay return jump %d is reachable"%i)
		if act==1:
			actor.global_position=Vector3(409,4.655,0)
			actor.velocity=Vector3.ZERO
			actor.remote_axis=Vector2.ZERO
			actor.remote_held.clear()
			actor.remote_pressed.clear()
			for i in 8:
				actor._physics_process(1.0/60)
				await physics_frame
			check(pressure.insulated(actor),"amber ceramic landing provides actual electrical insulation")
			actor.invulnerable_time=0
			var hp:float=actor.health
			pressure.clock=0
			pressure.next_hit.clear()
			pressure._physics_process(.05)
			check(actor.health==hp,"active electrical grid cannot hurt a grounded player on ceramic")
			actor.invulnerable_time=10000
		if act==2:
			pressure.apply_snapshot([0,0.0,false,false,[0.0,0.0,0.0]])
			actor.global_position=Vector3(222,12.86,0)
			pressure.started=true
			actor.remote_held[&"field_interact"]=true
			pressure._physics_process(.9)
			check(pressure.active_valves==0 and pressure.holds[0]>.8,"valve requires a continuous hold")
			actor.remote_held.clear()
			pressure._physics_process(.05)
			check(pressure.holds[0]==0,"releasing the valve cancels its hold")
			for valve in pressure.valves:
				actor.global_position=valve.at+Vector3(0,.86,0)
				actor.remote_held[&"field_interact"]=true
				pressure._physics_process(1.81)
			actor.remote_held.clear()
			check(pressure.active_valves==7,"all three independent pressure valves activate")
			pressure._process(.02)
			check(pressure.redirects[0].jet.direction==Vector3.RIGHT,"valve A redirects the upper current toward the hidden cache")
			var boosted: bool=await jump(actor,Vector3(232,12,6),Vector3(246,14.2,10))
			check(boosted,"redirected current and dash reach the harder upper cache route")
			check(not pressure.completed,"valves cannot bypass the pressure bleed cycle")
			actor.controls_suspended=true
			var before: float=pressure.elapsed
			pressure._physics_process(1)
			check(pressure.elapsed==before,"pressure timer pauses with suspended gameplay")
			actor.controls_suspended=false
			pressure.elapsed=89.9
			pressure._physics_process(.2)
			check(pressure.completed,"ninety-second pressure cycle and three valves release the lock")
			var state: Array=pressure.snapshot()
			pressure.active_valves=0
			pressure.completed=false
			pressure.apply_snapshot(state)
			check(pressure.completed and pressure.active_valves==7,"save/rejoin snapshot restores the shared release lock")
			for i in 90:
				pressure._process(1.0/60)
				await physics_frame
			check(pressure.locks[0].body.get_child(0).disabled,"open lock removes its collider after the slab clears the player")
			pressure._physics_process(5)
			check(pressure.completed,"completed lock stays open for late party members")
			pressure.apply_snapshot([7,0,true,true,[0,0,0]])
			check(not pressure.completed,"invalid premature completion cannot bypass pressure time")
		for grid in pressure.grids:
			pressure.clock=3.4-grid.offset
			check(pressure.grid_live(grid.offset),"electrical damage uses the visible active phase")
			pressure.clock=1.0-grid.offset
			check(not pressure.grid_live(grid.offset),"electrical safe window has no active damage")
		game.queue_free()
		current_scene=null
		await process_frame
		await physics_frame
		await process_frame
	print("ABYSSAL RESULT failures=",failures)
	finish(1 if failures else 0)

func jump(actor,a: Vector3,b: Vector3,edge_offset:=.55) -> bool:
	actor.remote_held.clear()
	actor.remote_pressed.clear()
	actor.remote_released.clear()
	for body in actor.drop_through.keys():
		actor.remove_collision_exception_with(body)
	actor.drop_through.clear()
	actor.hatch_floor=null
	actor.set_crouch(false)
	actor.dash_left=0
	actor.dash_lock=0
	actor.wall_grace=0
	var direction:=signf(b.x-a.x)
	actor.global_position=Vector3(a.x+direction*(a.z*.5-edge_offset),a.y+.855,0)
	actor.velocity=Vector3.ZERO
	actor.remote_axis=Vector2.ZERO
	for frame in 5:
		actor._physics_process(1.0/60)
		await physics_frame
	actor.remote_axis=Vector2(direction,0)
	actor.velocity.x=9*direction
	actor.remote_pressed[&"jump"]=true
	actor.remote_held[&"jump"]=true
	for frame in 150:
		if frame==1: actor.remote_pressed.clear()
		if frame==22:
			actor.remote_pressed[&"dash"]=true
		if frame==23: actor.remote_pressed.clear()
		if direction*(actor.global_position.x-b.x)>-b.z*.5+.65: actor.remote_axis=Vector2.ZERO
		actor._physics_process(1.0/60)
		await physics_frame
		if actor.is_on_floor() and actor.global_position.y>b.y+1.5 and direction*(actor.global_position.x-b.x)>-b.z*.5:
			actor.remote_held.clear()
			actor.remote_pressed={&"crouch":true,&"dash":true}
			actor.remote_held[&"crouch"]=true
			actor.dash_lock=0
			actor._physics_process(1.0/60)
			actor.remote_pressed.clear()
		for current in get_nodes_in_group(&"abyssal_current"):
			if current.contains(actor.global_position) and actor.global_position.y>b.y+5 and absf(actor.global_position.x-b.x)<4: return true
		if absf(actor.global_position.y-b.y-.85)<.10 and absf(actor.global_position.x-b.x)<b.z*.5+.1 and actor.is_on_floor(): return true
		if actor.global_position.y<b.y-6:
			print("JUMP FELL from=",a," to=",b," at=",actor.global_position)
			return false
	print("JUMP TIMEOUT from=",a," to=",b," at=",actor.global_position)
	return false

func climb_chimney(actor) -> bool:
	actor.remote_held.clear()
	actor.remote_pressed.clear()
	actor.remote_released.clear()
	actor.global_position=Vector3(317,-4.7,0)
	actor.velocity=Vector3.ZERO
	var launched=false
	var cooldown=0
	var direction=1.0
	for frame in 1200:
		actor.remote_pressed.clear()
		actor.remote_held[&'jump']=true
		cooldown=maxi(0,cooldown-1)
		if actor.global_position.y>=3.8: launched=true
		actor.remote_axis=Vector2(direction if launched else (1.0 if actor.global_position.x<322.25 else 0.0),0)
		if actor.wall_grace>0 and cooldown==0:
			actor.remote_pressed[&'jump']=true
			direction=-actor.wall_side
			cooldown=12
		if actor.global_position.y>12.9: direction=1
		actor._physics_process(1.0/60)
		await physics_frame

		if actor.global_position.x>331 and actor.is_on_floor() and actor.global_position.y>12:
			return true
	return false

func swim_passage(actor) -> bool:
	for body in actor.drop_through.keys(): actor.remove_collision_exception_with(body)
	actor.drop_through.clear()
	actor.hatch_floor=null
	actor.remote_held.clear()
	actor.remote_pressed.clear()
	actor.remote_released.clear()
	actor.global_position=Vector3(104,5.655,0)
	actor.velocity=Vector3.ZERO
	actor.dash_left=0
	actor.melee_lock=0
	actor.set_crouch(false)
	var entered:=false
	var dived:=false
	var rose:=false
	for frame in 1800:
		var at: Vector3=actor.global_position
		var target_y: float=-5.4 if at.x<132 else .2
		actor.remote_axis=Vector2(1,clampf((target_y-at.y)*1.5,-1,1))
		actor._physics_process(1.0/60)
		await physics_frame
		entered=entered or actor.swim_volume()!=null
		dived=dived or (at.x>126.7 and at.y<-3.4)
		rose=rose or (at.x>149.8 and at.y>-.7)
		if at.x>176 and actor.is_on_floor():
			check(entered and dived and rose,"swim route passes below and above its solid baffles")
			check(actor.swim_volume()==null,"leaving the pool restores normal platform movement")
			return entered and dived and rose and actor.health>0
	print("SWIM STUCK ",actor.global_position)
	return false

func check_swimming_controls(actor) -> void:
	var exit_at: Vector3=actor.global_position
	actor.remote_held.clear()
	actor.remote_pressed.clear()
	actor.remote_axis=Vector2.ZERO
	var probe: Transform3D=actor.global_transform
	probe.origin=Vector3(110,8,0)
	check(actor.test_move(probe,Vector3(10,0,0)),"sealed upper hull prevents an air-dash bypass of the swim")
	actor.global_position=Vector3(122,-5,0)
	actor.velocity=Vector3.ZERO
	actor.controls_suspended=true
	for i in 20:
		actor._physics_process(1.0/60)
		await physics_frame
	check(actor.global_position.distance_to(Vector3(122,-5,0))<.01,"suspending controls freezes underwater movement")
	actor.controls_suspended=false
	actor.remote_held[&"field_interact"]=true
	for i in 120:
		actor._physics_process(1.0/60)
		await physics_frame
	check(actor.global_position.distance_to(Vector3(122,-5,0))<.02,"held interaction provides stable underwater hovering for revives")
	actor.remote_held.clear()
	actor.remote_axis=Vector2(1,0)
	actor.dash_lock=0
	actor.resume_input_guard=0
	actor.remote_pressed[&"dash"]=true
	actor._physics_process(1.0/60)
	await physics_frame
	check(actor.velocity.x>8 and actor.velocity.x<=9.01,"underwater dash gives a bounded swim burst")
	actor.remote_pressed.clear()
	actor.dash_left=0
	actor.global_position=Vector3(122,-5,0)
	actor.velocity=Vector3.ZERO
	actor.remote_axis=Vector2.ZERO
	actor.fire_lock=0
	actor.melee_lock=0
	actor.cancel_charge()
	var shots:={"count":0}
	var fired:=func(_projectile):shots.count+=1
	actor.shot_fired.connect(fired)
	actor.remote_pressed[&"shoot"]=true
	actor.remote_held[&"shoot"]=true
	actor._physics_process(1.0/60)
	await physics_frame
	actor.remote_pressed.clear()
	actor.remote_held.clear()
	actor._physics_process(1.0/60)
	await physics_frame
	check(shots.count>0,"normal blaster input still fires underwater")
	actor.shot_fired.disconnect(fired)
	actor.global_position=exit_at
	actor.velocity=Vector3.ZERO
