extends "res://tests/game_test_tree.gd"

## Real-controller checks for the hand-authored landings. Each trial starts grounded
## on the preceding ledge. No changes to velocity, gravity or collisions in flight.
const ROUTES := [
	["PumpCraneBridge00", "PumpCraneRail00", "PumpSuspendedLanding00"],
	["FuelLineUpperWest", "FuelLineUpperEast"],
	["Room02_Switchback/UpperWalk00", "Room02_Switchback/UpperWalk01"],
	["Room05_Switchback/UpperWalk00", "Room05_Switchback/UpperWalk01"],
	["Room03_Junction/UpperWalk00", "Room03_Junction/UpperWalk01", "Room03_Junction/UpperWalk02"],
	["Room01_Switchback/UpperBalcony00", "Room01_Switchback/UpperBalcony01"],
	[], [], # The pressure/current levels have a dedicated route suite.
	["Room01_Switchback/UpperBeforePhase00", "Room01_Switchback/UpperBeforePhase01"],
	["Room04_Switchback/UpperWalk00", "Room04_Switchback/UpperWalk01", "Room04_Switchback/UpperWalk02"],
	["Room04_Switchback/UpperBalcony00", "Room04_Switchback/UpperBalcony01"],
	["Room02_Shaft/ExitLandingRejoin00", "Room02_Shaft/ExitLandingRejoin01"],
	["Room02_Branch/ExitLanding00", "Room02_Branch/ExitLanding01", "Room02_Branch/ExitLanding02"],
	["Room02_Junction/UpperBalcony00", "Room02_Junction/UpperBalcony01"],
	["Room04_Switchback/UpperBeforePhase00", "Room04_Switchback/UpperBeforePhase01", "Room04_Switchback/UpperBeforePhase02"],
	["Room06_Junction/UpperWalk00", "Room06_Junction/UpperWalk01"],
	["Room02_Branch/ExitLanding00", "Room02_Branch/ExitLanding01", "Room02_Branch/ExitLanding02"],
	["Room05_Junction/UpperWalk00", "Room05_Junction/UpperWalk01"],
	["Room03_Switchback/UpperBeforePhase00", "Room03_Switchback/UpperBeforePhase01"],
	["Room06_Switchback/UpperWalk00", "Room06_Switchback/UpperWalk01"],
]

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	failures += int(not ok)

func grounded_at(p, at: Vector3) -> bool:
	return p.grounded() and absf(p.global_position.y - at.y - .85) < .16

func settle(p, feet: Vector3) -> void:
	p.reset_predicted_position(feet + Vector3.UP * .89, Vector3.ZERO, 1)
	p.remote_axis = Vector2.ZERO
	p.remote_pressed.clear()
	p.remote_held.clear()
	p.remote_released.clear()
	for tick in 12:
		await physics_frame

func grounded_jump(p, a: StaticBody3D, b: StaticBody3D, dash: bool) -> bool:
	var shape := a.find_children("*", "CollisionShape3D", true, false)[0] as CollisionShape3D
	var half := (shape.shape as BoxShape3D).size.x * shape.global_basis.x.length() * .5
	var direction := signf(b.global_position.x - a.global_position.x)
	var takeoff := a.global_position.x + direction * (half - .55)
	var start := a.global_position
	start.x = takeoff - direction * minf(2.1, half * 1.4)
	await settle(p, start)
	if not grounded_at(p, start):
		return false
	p.remote_axis.x = direction
	for tick in 36:
		if (takeoff - p.global_position.x) * direction <= .08:
			break
		await physics_frame
	p.remote_pressed[&"jump"] = true
	p.remote_held[&"jump"] = true
	var target := b.global_position
	for tick in 110:
		if tick == 21 and dash:
			p.remote_pressed[&"dash"] = true
			p.remote_held[&"dash"] = true
		if direction * (target.x - p.global_position.x) < .78:
			p.remote_axis.x = 0.0
			p.remote_held.erase(&"dash")
		await physics_frame
		if tick > 8 and absf(target.x - p.global_position.x) < 1.4 and grounded_at(p, target):
			return true
		if p.global_position.y < minf(start.y, target.y) - 2.0:
			break
	return false

func run() -> void:
	for i in ROUTES.size():
		var sector := 1 + floori(i / 2.0)
		var act := 1 + i % 2
		var label := "%d.%d" % [sector, act]
		var game = load("res://scenes/main.tscn").instantiate()
		game.profile.path = "user://landings-profile.cfg"
		game.checkpoint_path = "user://landings-run.cfg"
		root.add_child(game)
		current_scene = game
		game.profile.manual_only = true
		game.sector = sector
		game.act = act
		game.start_game(false, sector)
		var stage: Node3D = game.game_root
		var p = game.player
		p.remote_input = true
		p.invulnerable_time = 10000
		game.set_physics_process(false)
		for enemy in get_nodes_in_group(&"level_enemies"):
			enemy.set_physics_process(false)
			enemy.collision_layer = 0
		await physics_frame
		if sector == 1 and act == 1:
			# These adjoining tiles are a single runway, before the first jump.
			await settle(p, Vector3.ZERO)
			p.remote_axis.x = 1.0
			for tick in 140:
				if p.global_position.x >= 13.0:
					break
				await physics_frame
			check(p.global_position.x >= 13.0 and p.grounded(), "Foundry intake is walkable up to the first gap")
			p.remote_axis.x = 0.0
		var invalid := []
		for shape: CollisionShape3D in stage.find_children("*", "CollisionShape3D", true, false):
			if not shape.disabled and (not shape.shape or not shape.get_parent() is CollisionObject3D):
				invalid.append(shape.get_path())
		check(invalid.is_empty(), label + " collision shapes " + str(invalid))
		for marker in ["MARKERS/PlayerSpawn", "TERRAIN/MidpointCheckpoint", "TERRAIN/ForgeHallCheckpoint"]:
			var feet: Vector3 = stage.get_node(marker).global_position
			if marker.ends_with("PlayerSpawn"):
				feet.y -= .85
			await settle(p, feet)
			check(grounded_at(p, feet), label + " supported " + marker + " " + str(p.global_position))
		for step: StaticBody3D in stage.find_children("MiddleStep", "StaticBody3D", true, false):
			var apron := step.get_parent().get_node_or_null("ForkApron00") as StaticBody3D
			if not apron:
				continue
			var step_shape := step.get_node("Collision") as CollisionShape3D
			var x: float = step.global_position.x - step_shape.shape.size.x * .5 - 1.65
			var headroom: float = step_shape.global_position.y - step_shape.shape.size.y * .5 - apron.global_position.y
			check(headroom >= 2.19, label + " fork headroom " + str(step.get_parent().name))
			await settle(p, Vector3(x, apron.global_position.y, 0))
			p.remote_pressed[&"jump"] = true
			p.remote_held[&"jump"] = true
			for tick in 55:
				if tick == 9:
					p.remote_axis.x = 1
				if p.global_position.x >= step.global_position.x - .9:
					p.remote_axis.x = 0
				await physics_frame
			check(grounded_at(p, step.global_position), label + " rise from fork onto " + str(step.get_parent().name))
		for j in 2:
			game.gate_relays.set_active(2 if j == 0 else 1)
			game.gate_relays.update_prompt(p, true)
			var landmark: String = game.gate_relays.landmarks[j]
			check(not landmark.is_empty() and game.gate_relays.door_prompt.visible and game.gate_relays.door_prompt.text.contains(landmark.to_upper()), label + " missing relay landmark " + landmark)
			if not (sector == 3 and act == 2 and j == 0): # The board awards this relay at the finish line.
				var terminal: Vector3 = game.gate_relays.terminals[j].global_position
				game.gate_relays.set_active(0)
				await settle(p, terminal)
				check(grounded_at(p, terminal) and game.gate_relays.interact(p, false), label + " relay " + str(j+1) + " on a usable landing")
			var approach = stage.get_node_or_null("MARKERS/RelayApproach%d" % [j+1])
			check(approach != null, label + " has return approach " + str(j+1))
			if approach:
				game.gate_relays.set_active(2 if j == 0 else 1)
				await settle(p, game.gate.global_position + Vector3.LEFT * 2.1)
				var returned: bool = game.gate_relays.interact(p, true)
				for tick in 10:
					await physics_frame
				check(returned and game.gate_relays.count() == 1 and grounded_at(p, approach.global_position) and not game.gate_relays.is_near(p, game.gate_relays.terminals[j]), label + " service return to approach " + str(j+1))
		var route: Array = ROUTES[i]
		for j in range(1, route.size()):
			var a = stage.get_node("TERRAIN/" + route[j-1])
			var b = stage.get_node("TERRAIN/" + route[j])
			for direction in [1, -1]:
				var left = a if direction == 1 else b
				var right = b if direction == 1 else a
				var landed := await grounded_jump(p, left, right, false)
				if not landed:
					landed = await grounded_jump(p, left, right, true)
				check(landed, label + " jump " + str(left.name) + " to " + str(right.name) + " " + str(p.global_position))
		game.queue_free()
		await process_frame
		await physics_frame
	print("LANDING FAILURES ", failures)
	finish(failures)
