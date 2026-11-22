extends RefCounted

# A native process drives only its own Input actions. The host places the party at
# the start of each independent scenario and fast-forwards the unrelated boss fights.
var test
var mission
var actor: Node3D
var shaft: Node3D
var checkpoint_dir := ""
var sequence := 0

func exercise(client) -> void:
	test = client
	test.lobby.recovery.changed.connect(rejoin_if_offered, CONNECT_DEFERRED)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--foundry-sync="):
			checkpoint_dir = arg.trim_prefix("--foundry-sync=")
	test.game.menu.leave_page()
	if not await sync("foundry-deploy"):
		return
	if test.host:
		test.lobby.deploy(1)
	if not await require(func(): return is_instance_valid(test.game.coop_mission) and not test.game.coop_deploy_loading, 90, "Both clients deploy"):
		return
	mission = test.game.coop_mission
	test.mission = mission
	for act in [1, 2]:
		if not await require(func(): return mission.act == act and not mission.changing_act, 95, "Act %d loads" % act):
			return
		actor = mission.operators[mission.local_index]
		print("NET ",mission.get_path()," local=",mission.local_index," host=",mission.host," roster=", mission.roster)
		if not await require(func(): return mission.remote_players[mission.roster[1]].loaded if test.host else mission.loadout_confirmed,40,"Guest loadout acknowledged"): return
		if not await sync("network-ready"): return
		if test.host:
			for watched in mission.operators:
				watched.fell_into_pit.connect(func(): print("PIT ",watched.name," ",watched.global_position),CONNECT_DEFERRED)
		if (act == 2 or test.suite == "foundry") and (not await split_routes(act) or not await relays(act)):
			return
		if act == 2 and not await escape():
			return
		if not await sync("boss-ready"):
			return
		if test.host:
			await test.clear_boss(1, act)
	if not await require(func(): return is_instance_valid(mission.extraction_return_button), 55, "Personal extraction screen"):
		return
	if not await sync("both-reports"):
		return
	mission.mark_local_return_ready()
	await require(func(): return is_instance_valid(test.game.home_hub) and not test.lobby.mission_active and test.lobby.room_size == 2, 20, "Both operators extracted into the same party")
	await sync("hub-return")

func rejoin_if_offered() -> void:
	var button = test.game.recovery_button
	if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
		print("FOUNDRY accepting Rejoin Party")
		button.pressed.emit()

func next_motion_frame() -> void:
	await test.physics_frame
	while test.paused or (not test.host and mission.snapshot_age > .6):
		stop()
		await test.process_frame

func sync(label: String) -> bool:
	print("FOUNDRY waiting ", label)
	if checkpoint_dir.is_empty():
		return await test.barrier(label, 95)
	sequence += 1
	var name := "%02d-%s-" % [sequence,label]
	var file := FileAccess.open(checkpoint_dir.path_join(name + str(test.client)),FileAccess.WRITE)
	if not file:
		test.check(false,"Cannot write test checkpoint " + label)
		return false
	file.close()
	return await require(func(): return FileAccess.file_exists(checkpoint_dir.path_join(name + str(1-test.client))),95,"barrier " + label)

func require(condition: Callable, seconds: float, label: String) -> bool:
	var ok: bool = await test.until(condition, seconds)
	if not ok and is_instance_valid(mission):
		print("WORLD act=",mission.act," mask=",mission.gate_relays.active," seq=",mission.latest_state," sent=",mission.state_sequence, " operators=",mission.latest_operators, " enemies=",mission.latest_security," loaded=",mission.loadout_confirmed)
		for p in mission.operators:
			if is_instance_valid(p): print("OPERATOR ",p.name, " pos=",p.position, " hp=",p.health, " lives=",p.lives)
	test.check(ok, label)
	return ok

func stage_at(points: Array, label: String) -> bool:
	stop()
	if not await sync("prepare-" + label):
		return false
	if test.host:
		for i in 2:
			var p = mission.operators[i]
			p.global_position = Vector3(points[i].x, points[i].y + p.standing_capsule.height * .5 + .06, 0)
			p.velocity = Vector3.ZERO
			p.invulnerable_time = 300
			mission.mark_position_reset(p)
		mission.broadcast_state(true)
	var at: Vector2 = points[mission.local_index]
	return await require(func(): return absf(actor.position.x - at.x) < .9 and absf(feet() - at.y) < .25 and actor.grounded(), 8, label + " staging")

func feet() -> float:
	return actor.position.y - actor.standing_capsule.height * .5

func stop() -> void:
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)

func axis(value: float) -> void:
	if value > .02: Input.action_press("move_right", minf(value, 1))
	else: Input.action_release("move_right")
	if value < -.02: Input.action_press("move_left", minf(-value, 1))
	else: Input.action_release("move_left")

func steer(x: float) -> float:
	return clampf((x - actor.position.x) * 3.8 - actor.velocity.x * .15, -1, 1)

func walk(x: float, limit := 170) -> void:
	for i in limit:
		axis(clampf(steer(x), -.55, .55) if absf(x - actor.position.x) < 2.5 else steer(x))
		await next_motion_frame()
		if absf(actor.position.x - x) < .16 and actor.grounded(): break
	axis(0)

func jump() -> void:
	Input.action_release("jump")
	await next_motion_frame()
	Input.action_press("jump")

func cross(edge: float, landing_edge: float, target: float, height: float, approach_ticks := 100) -> bool:
	await walk(edge, approach_ticks)
	if absf(actor.position.x - edge) > .55:
		print("TAKEOFF OUT OF REACH ", actor.position, " wanted ", edge)
		return false
	print("TAKEOFF ",actor.position, " target ",Vector2(target,height))
	var direction := signf(target - edge)
	axis(direction)
	await jump()
	for i in 92:
		await next_motion_frame()
		axis(steer(landing_edge - direction * .48 if feet() < height - .02 and actor.velocity.y > 0 else target))
		if i > 6 and actor.grounded(): break
	stop()
	var landed := absf(feet() - height) < .23 and absf(actor.position.x - target) < 2
	if not landed: print("MISSED ", Vector2(target, height), " actor ", actor.position, " grounded ",actor.grounded())
	return landed

func split_routes(act: int) -> bool:
	if test.host:
		for guard in mission.enemies:
			if is_instance_valid(guard) and guard.position.x < 0:
				guard.take_damage(guard.health)
	var positions := [Vector2(-42.4, 6.75), Vector2(-40,-2)] if act == 1 else [Vector2(-66,-4.4), Vector2(-74,0)]
	if not await stage_at(positions, "entry-fork"): return false
	var upper: bool = test.host == (act == 1)
	var steps: Array
	if act == 1:
		steps = [[-38.2,-35,-33.35,7.6],[-26.95,-24,-22.4,5.8]] if upper else [[-37.4,-34.8,-33.4,-2.8],[-31.85,-29.1,-27.95,-2.8],[-26.4,-23.4,-22.1,-1.55],[-20.15,-17.5,-16.2,0]]
	else:
		steps = [[-71.6,-68.5,-66.8,1],[-63.15,-59.9,-58.6,2.25],[-52.4,-49.2,-48,1.1]] if upper else [[-63.4,-60.4,-59.15,-5.1],[-58.45,-56.3,-55.15,-5.1],[-54.4,-51.9,-50.65,-3.6],[-48.6,-47,-45.65,-1.8],[-44,-43.5,-42.4,0]]
	for step in steps:
		var ok := await cross(step[0],step[1],step[2],step[3])
		test.check(ok, "Act %d %s landing %.1f" % [act,"upper" if upper else "lower",step[2]])
		if not ok: return false
	if act == 2 and upper:
		if not await cross(-45.25,-43.5,-42.4,0):
			test.check(false, "Bridge to transfer lock")
			return false
	var meeting := -13.6 if act == 1 else -42.1
	await walk(meeting)
	return await require(func(): return mission.operators.all(func(p): return absf(p.position.x - meeting) < 2.6 and p.health > 0), 18, "Both route markers meet at the junction")

func interact() -> void:
	var event := InputEventAction.new()
	event.action = &"field_interact"
	event.pressed = true
	Input.parse_input_event(event)
	await next_motion_frame()
	event = InputEventAction.new()
	event.action = &"field_interact"
	Input.parse_input_event(event)

func relays(act: int) -> bool:
	# Approach two separate terminals. In each act the joiner owns one switch input.
	var spots := [Vector2(72.9,-16.4), Vector2(237.4,-19.45)] if act == 1 else [Vector2(285.6,6.9),Vector2(486.8,-4.6)]
	if not await stage_at(spots,"relay-rooms"): return false
	if not await sync("both-at-switches"): return false
	for index in 2:
		if mission.local_index == index: await interact()
		var mask := 1 if index == 0 else 3
		if not await require(func(): return mission.gate_relays.active == mask, 14,"Shared relay mask %d" % mask): return false
		if not await sync("relay-%d" % index): return false
	if act == 1:
		# Meet at the pump outlet. The guest exits the activated boiler on foot.
		if not await stage_at([Vector2(258,-2.75), Vector2(238.1,-19.45)],"boiler-exit"): return false
		if test.host:
			var seal = mission.stage.get_node("TERRAIN/BoilerSeal")
			seal.set_fractures(seal.HITS_TO_BREAK)
			mission.broadcast_state(true)
		if not await require(func(): return not is_instance_valid(mission.stage.get_node_or_null("TERRAIN/BoilerSeal")) or not mission.stage.get_node("TERRAIN/BoilerSeal").visible,5,"Discharge seal clears on both peers"): return false
		if not test.host:
			var route := [[246.8,249.2,250.4,-18.05],[252.35,254.4,255.5,-16.25],[254.9,252.8,251.55,-14.15],[252.5,254.35,255.6,-12.05]]
			for step in route:
				if not await cross(step[0],step[1],step[2],step[3]):
					test.check(false,"Guest crosses boiler discharge")
					return false
			await walk(256.24)
			if not await kick_to(1, 257.15, -7.55, false):
				test.check(false,"Guest wall-kicks onto the discharge ram")
				return false
			if not await cross(256.95,253.73,253.25,-5.21) or not await cross(253.5,256.5,257.65,-2.75):
				test.check(false,"Guest reaches repair apron")
				return false
		return await require(func(): return mission.operators.all(func(p): return absf(p.position.x-258)<1.5 and absf(p.position.y+1.9)<.5),35,"Regroup after boiler relay on repair apron")
	return true

func kick_to(side: float, target: float, height: float, shaft_band: bool) -> bool:
	axis(side)
	await jump()
	var outbound := false
	for i in 178:
		await next_motion_frame()
		if feet() > height - .08 and actor.grounded() and absf(actor.position.x - target) < 2.2:
			stop()
			return true
		if not shaft_band and feet() > height - .04 and actor.position.x > 254.43:
			axis(steer(target))
			continue
		if not outbound and actor.wall_grace > 0 and actor.wall_launch_lock <= 0 and actor.coyote <= 0 and (shaft_band or actor.velocity.y < 4):
			var high := feet() > height-2.96
			axis(side)
			await jump()
			for hold in 3: await next_motion_frame()
			if high: outbound = true
			elif not shaft_band: side *= -1
		if outbound:
			var outside := target + side*(kick_width*.5+.42)
			axis(steer(target if feet() >= height+.015 or not shaft_band else outside))
		else: axis(side)
	stop()
	print("KICK MISSED ",actor.position, " target ",Vector2(target,height))
	return false

var kick_width := 0.0

func escape() -> bool:
	shaft = mission.lava_escape
	# Isolate the timed traversal from variable patrol and flyer collisions.
	if test.host:
		for guard in mission.enemies:
			if is_instance_valid(guard) and guard.position.x >= 489 and guard.position.x < shaft.position.x+32:
				guard.take_damage(guard.health)
	if not await stage_at([Vector2(501.65,-10.1), Vector2(487.65,-4.6)],"shaft-approach"): return false
	if not await sync("split-at-entrance"): return false
	test.check(not shaft.door.passable, "Shaft stays closed with only host at the entrance")
	if not test.host:
		await walk(490.2)
		await walk(501.55)
	if not await require(func(): return shaft.door.passable and mission.operators.all(func(p): return shaft.door.near(p)),30,"Both operators regroup and the shaft door opens"): return false
	if not await sync("enter-together"): return false
	# Let the joining operator enter first, so replication delay at the door
	# does not take time away from their climb when the host triggers the surge.
	if test.host and not await require(func(): return shaft.past_entrance(mission.operators[1]), 10, "Guest enters the open shaft"):
		return false
	return await climb_shaft()

func climb_shaft() -> bool:
	var start_x: float = shaft.position.x
	var start_y: float = shaft.position.y
	var lives: int = actor.lives
	await walk(start_x+6.20)
	var previous: Node3D = shaft.get_node("ShaftFloor1")
	var route: Array = shaft.get_node("Climb").get_children()
	route.append(shaft.get_node("ExitBridge"))
	var rising := false
	var step := 0
	var retries := 0
	while step < route.size():
		var deck: Node3D = route[step]
		var target := float(start_x + deck.position.x)
		var height := float(start_y + deck.position.y)
		var width := 6 * absf(deck.scale.x)
		var passed := await climb_ledge(previous, deck, target, height, width)
		if not passed and actor.grounded() and retries < 5:
			# Rejoining acknowledges the host landing. Resume the climb from the
			# platform supporting the operator, including after a missed jump.
			var supports := [shaft.get_node("ShaftFloor1")] + route.slice(0, step + 1)
			var support := supports.find_custom(func(p): return absf(feet() - p.global_position.y) < .18 and absf(actor.position.x - p.global_position.x) <= 3 * absf(p.scale.x) + .3)
			if support >= 0:
				previous = supports[support]
				step = support
				retries += 1
				continue
		if not passed:
			test.check(false,"Climb " + str(deck.name) + " at " + str(actor.position))
			return false
		rising = rising or shaft.phase == shaft.Phase.RISING
		previous = deck
		step += 1
		print("SHAFT ",deck.name," feet=",feet()," lava=",start_y+shaft.surface)
	await walk(start_x+28.1)
	if not await require(func(): return mission.operators.all(func(p): return p.position.x > start_x+shaft.EXIT_CLEARANCE and p.position.y > start_y+78 and p.health > 0),10,"Both living operators cross the shaft exit"): return false
	test.check(rising and actor.lives == lives, "Escaped an active surge without losing a life")
	return await require(func(): return shaft.phase == shaft.Phase.READY and is_equal_approx(shaft.surface,shaft.REST_LEVEL),10,"Lava drains on both clients")

func shaft_steer(target: float) -> float:
	return clampf((target - actor.position.x) * 3.4 - actor.velocity.x * .16, -1.0, 1.0)

func climb_ledge(previous: Node3D, deck: Node3D, target: float, height: float, width: float) -> bool:
	var from := previous.global_position.x
	var span := 3 * absf(previous.scale.x)
	var wall := str(deck.name).ends_with("WallKick")
	var side := (-1.0 if deck.position.x < 12.0 else 1.0) if wall else signf(target-actor.position.x)
	var edge := from + side*(span-.45) if wall else clampf(target, from-span+.38, from+span-.38)
	if not wall:
		# Leave space for the capsule at the overlapping corners of solid landings.
		var clear := target - side*(width*.5+.72)
		edge = minf(clear,edge) if side > 0 else maxf(clear,edge)
	if previous.name == "ShaftFloor1":
		edge = shaft.position.x + 6.2
	Input.action_release("jump")
	for frame in (24 if wall else 43):
		if not wall and absf(edge - actor.position.x)<.17: break
		axis(shaft_steer(edge))
		await next_motion_frame()
	if wall:
		kick_width = width
		return await kick_to(side, target, height, true)
	var near := target-side*(width*.5+.61)
	axis(shaft_steer(near))
	Input.action_press("jump")
	await next_motion_frame()
	for frame in 72:
		if frame > 14 and actor.grounded() and absf(feet() - previous.global_position.y)<.14: break
		axis(shaft_steer(target-side*(width*.5-.68) if feet() > height-.025 else near))
		await next_motion_frame()
		if actor.grounded() and absf(feet()-height)<.13:
			stop()
			return true
	stop()
	return false
