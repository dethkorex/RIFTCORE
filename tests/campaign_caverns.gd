extends "res://tests/level_landings.gd"

## Run with -- <first sector> <last sector> to split a campaign check.
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var first := args[0].to_int() if not args.is_empty() else 2
	var last := args[1].to_int() if args.size() > 1 else 10
	for sector in range(first, last + 1):
		if sector == 4:
			continue # Pressure Breach has a current, swim and wall-kick route suite.
		for act in [1, 2]:
			var game = load("res://scenes/main.tscn").instantiate()
			root.add_child(game)
			game.profile.path = "user://cavern-profile.cfg"
			game.checkpoint_path = "user://cavern-run.cfg"
			game.profile.manual_only = true
			game.sector = sector
			game.act = act
			game.start_game(false, sector)
			var actor = game.player
			actor.remote_input = true
			actor.invulnerable_time = 10000
			game.set_physics_process(false)
			for enemy in get_nodes_in_group(&"level_enemies"):
				enemy.set_physics_process(false)
				enemy.collision_layer = 0
			await physics_frame
			var rooms := get_nodes_in_group(&"authored_cavern")
			check(rooms.size() == 2, "%d.%d chamber count" % [sector, act])
			for room in rooms:
				var wall = room.get_node_or_null("FracturedBarricade")
				if wall:
					for shot in 5:
						var blast = load("res://scripts/projectile.gd").new()
						blast.owner_faction = "player"
						wall.hit_by_projectile(blast)
						blast.free()
					await physics_frame
				var main := room.find_children("Step*", "StaticBody3D", false, false)
				var branch := room.find_children("Fork*", "StaticBody3D", false, false)
				branch.push_front(main[int(room.get_meta("branch_from"))])
				if room.has_meta("branch_return"):
					branch.append(main[int(room.get_meta("branch_return"))])
				for path in [main, branch]:
					for i in range(1, path.size()):
						var from := path[i-1] as StaticBody3D
						var to := path[i] as StaticBody3D
						var reached := await grounded_jump(actor, from, to, false)
						if not reached:
							reached = await grounded_jump(actor, from, to, true)
						if not reached and to.position.y < from.position.y:
							reached = await drop_from_ledge(actor, from, to)
						if not reached and to.position.y < from.position.y:
							reached = await drop_through_to(actor, from, to)
						check(reached, "%s %s -> %s" % [room.get_meta("chamber"), from.name, to.name])
			game.queue_free()
			await process_frame
			await physics_frame
	print("CAVERN FAILURES ", failures)
	finish(failures)

func drop_through_to(actor, source: StaticBody3D, landing: StaticBody3D) -> bool:
	var half_width: float = source.get_node("Collider").shape.size.x * .5
	var start := source.global_position
	start.x = clampf(landing.global_position.x, start.x - half_width + .35, start.x + half_width - .35)
	await settle(actor, start)
	actor.remote_held[&"crouch"] = true
	actor.remote_pressed[&"dash"] = true
	await physics_frame
	actor.remote_held.erase(&"crouch")
	for tick in 85:
		actor.remote_axis.x = clampf((landing.global_position.x - actor.position.x)*2.0, -1, 1)
		await physics_frame
		for index in actor.get_slide_collision_count():
			var hit = actor.get_slide_collision(index)
			if hit.get_collider() == landing and hit.get_normal().y > .55:
				return true
	return false

# Descending shelves use a running step-off so the player passes underneath the upper fork.
func drop_from_ledge(actor, source: StaticBody3D, landing: StaticBody3D) -> bool:
	var width: float = source.get_node("Collider").shape.size.x
	var side := signf(landing.position.x - source.position.x)
	for dash_tick in [-1, 5, 11]:
		var feet := source.global_position + Vector3.RIGHT * side * (width * .5 - 1.8)
		await settle(actor, feet)
		actor.remote_axis.x = side
		var flight := 0
		for tick in 90:
			if not actor.grounded():
				flight += 1
			if flight == dash_tick:
				actor.remote_pressed[&"dash"] = true
			if (landing.global_position.x - actor.global_position.x) * side < .55:
				actor.remote_axis.x = 0.0
			await physics_frame
			if absf(actor.global_position.x - landing.global_position.x) < 1.5 and grounded_at(actor, landing.global_position):
				return true
			if actor.global_position.y < landing.global_position.y - 1:
				break
	return false
