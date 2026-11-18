extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print("PASS " if value else "FAIL ", description)
	if not value:
		failures += 1

func frames(count: int) -> void:
	for index in count:
		await physics_frame

func until(test: Callable, count: int) -> bool:
	for index in count:
		if test.call():
			return true
		await physics_frame
	return false

func start(sector: int, act: int, mode: int = 0):
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile.path = "user://sector-test-profile.cfg"
	game.checkpoint_path = "user://sector-test-checkpoint.cfg"
	root.add_child(game)
	current_scene = game
	game.profile.manual_only = true
	game.sector = sector
	game.act = act
	game.mission_difficulty = mode
	game.start_game(false)
	for actor in get_nodes_in_group(&"level_enemies"):
		actor.set_physics_process(false)
		actor.position.z = -8.0
	return game

func enter(game) -> bool:
	var player = game.player
	player.remote_input = true
	game.gate_relays.set_active(3)
	var gate: Vector3 = game.gate.global_position
	player.position = gate + Vector3(-2.3, .91, 0)
	await until(func(): return game.arena_door.passable, 160)
	player.remote_axis.x = 1.0
	var started := await until(func(): return game.arena_intro, 165)
	player.remote_axis.x = 0.0
	if not started:
		return false
	if not await until(func(): return game.boss.active, 430):
		return false
	player.invulnerable_time = 1000.0
	return true

func break_anchor(game, opponent) -> bool:
	if not await until(func(): return not opponent.root_anchor.dormant and opponent.root_anchor.collision_layer == 2, 90):
		return false
	var anchor: Vector3 = opponent.root_anchor.global_position
	var player = game.player
	for hit in opponent.root_anchor.durability:
		player.position = anchor + Vector3((-2.3 if opponent.position.x >= anchor.x else 2.3), -.05, 0)
		player.velocity = Vector3.ZERO
		player.facing = 1 if player.position.x < anchor.x else -1
		player.shoot(false)
		await frames(12)
	return await until(func(): return opponent.exposed, 90)

func run() -> void:
	await boss_balance()
	var foundry = start(1, 1)
	var scout = get_nodes_in_group(&"level_enemies")[0]
	var base_hp: float = scout.max_health
	check(scout.enemy_level == 1 and scout.level_tag.text == "LV. 1", "Ember Foundry level 1")
	foundry.queue_free()
	await frames(3)
	for act in [1, 2]:
		var game = start(2, act)
		var jungle_enemies := get_nodes_in_group(&"level_enemies")
		check(jungle_enemies.all(func(enemy): return enemy.enemy_level == 4 and enemy.level_tag.text == "LV. 4" and enemy.sector_damage_scale > 1.0), "all Jungle security is level 4 in act %d" % act)
		check(await enter(game), "ordinary entrance and intro act %d" % act)
		var boss = game.boss
		var hp: float = boss.health
		boss.take_damage(10000.0)
		check(boss.health == hp, "sealed armor blocks damage act %d" % act)
		if act == 1:
			for phase in 3:
				var opened := await break_anchor(game, boss)
				check(opened, "real Buster hits uproot seed anchor %d" % (phase+1))
				if not opened:
					break
				boss.take_damage(10000.0)
				if phase < 2:
					check(not boss.exposed and boss.root_phase == phase + 1, "threshold regrows armor")
		else:
			var operator = game.player
			operator.position = Vector3(622.9, 2.82, 0)
			operator.velocity = Vector3.ZERO
			await frames(18)
			operator.remote_axis.x = -1.0
			operator.remote_pressed["jump"] = true
			operator.remote_held["jump"] = true
			for frame in 100:
				if operator.position.x < 621.1:
					operator.remote_axis.x = 0.0
				if operator.grounded() and operator.position.y > 4.20:
					break
				await physics_frame
			check(operator.grounded() and operator.position.y > 4.20, "real jump reaches west root step " + str(operator.position))
			operator.remote_axis.x = -1.0
			operator.remote_pressed["jump"] = true
			for frame in 110:
				if operator.position.x < 618.25:
					operator.remote_axis.x = 0.0
				if operator.grounded() and operator.position.y > 6.30 and absf(operator.position.x - boss.drains[0].global_position.x) < 1.4:
					break
				await physics_frame
			check(operator.grounded() and operator.position.y > 6.3 and absf(operator.position.x - boss.drains[0].global_position.x) < 1.4, "second jump reaches the illuminated drain " + str(operator.position))
			operator.remote_axis.x = 0.0
			operator.remote_held.erase("jump")
			operator.position = boss.drains[0].global_position + Vector3(1.70,.93,0)
			operator.velocity = Vector3.ZERO
			check(await until(func(): return boss.flood_left > 0.0, 680), "root flood starts on the normal attack cycle")
			await frames(52)
			check(not boss.exposed, "high ground alone does not open the reactor")
			operator.position = boss.drains[0].global_position + Vector3.UP * .92
			operator.velocity = Vector3.ZERO
			check(await until(func(): return boss.exposed, 170), "standing on west drain clears flood and opens reactor")
			check(boss.flood_left == 0.0, "flood ends immediately on successful drain")
			await until(func(): return not boss.exposed, 520)
			check(not boss.exposed, "reactor seals after seven-second opening")
			operator.position = boss.drains[1].global_position + Vector3.UP * .94
			operator.velocity = Vector3.ZERO
			check(await until(func(): return boss.exposed, 760), "east drain opens the reactor on the next cycle")
			boss.take_damage(10000.0)
		check(await until(func(): return game.boss_defeated,180), "boss defeat advances act %d" % act)
		if act == 2:
			check(game.run_weapons.has("thorn_swarm"), "Thorn Swarm awarded")
			await frames(320)
		game.queue_free()
		await frames(3)
	for mode in [1,2]:
		var game = start(2,1,mode)
		check(get_nodes_in_group(&"level_enemies").all(func(enemy): return enemy.enemy_level == (8 if mode == 1 else 16) and enemy.sector_damage_scale > 1.2), "Jungle level and damage scale with difficulty %d" % mode)
		game.queue_free()
		await frames(3)
	quit(failures)

func boss_balance() -> void:
	for act in [1, 2]:
		var foundry = start(1, act)
		var base: float = foundry.boss.max_health
		foundry.queue_free()
		await frames(3)
		var previous_health := base
		for difficulty in [0, 1, 2]:
			var game = start(2, act, difficulty)
			var boss = game.boss
			var player = game.player
			check(boss.max_health > previous_health * 1.50, "act %d mode %d HP scales from %.1f to %.1f" % [act, difficulty, previous_health, boss.max_health])
			previous_health = boss.max_health
			boss.active = true
			boss.target = player
			var before: float = boss.health
			boss.burn_power = 100.0
			boss.apply_burn_tick()
			check(is_equal_approx(boss.health, before), "act %d mode %d armor blocks damage-over-time" % [act, difficulty])
			if act == 1:
				boss.exposed = true
			else:
				boss.exposed_left = boss.CORE_WINDOW
			boss.take_damage(100.0)
			var expected := float(([80, 74, 68] if act == 1 else [75, 68, 62])[difficulty])
			check(is_equal_approx(before - boss.health, expected), "act %d mode %d exposed defense reduces 100 damage to %.0f" % [act, difficulty, expected])
			if act == 1:
				boss.locked_direction = 1.0
				boss.aim = boss.global_position + Vector3.RIGHT * 3.0
				boss.attack = "volley"
				boss.strike()
			else:
				boss.strike_x = boss.global_position.x - 3.0
				boss.attack = 1
				boss._release()
			var shots := get_nodes_in_group(&"rift_projectile")
			var expected_shot: float = (22.4 if act == 1 else 34.0) * [1.0, 1.18, 1.38][difficulty]
			check(not shots.is_empty() and is_equal_approx(shots[0].damage, expected_shot), "act %d mode %d spawned shot does %.1f damage" % [act, difficulty, expected_shot])
			game.queue_free()
			await frames(3)
