extends "res://tests/game_test_tree.gd"

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, detail: String) -> void:
	print("PASS " if condition else "FAIL ", detail)
	failures += int(not condition)

func start(act: int) -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.profile.manual_only = true
	game.act = act
	game.start_game(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.boss.set_physics_process(false)
	game.boss.target = game.player
	game.boss.active = true
	return game

func advance_until(boss: Node, time: float) -> void:
	while boss.elapsed < time and not boss.motion.is_empty():
		await physics_frame
		boss.advance_attack(1.0 / 60.0)

func verify_charge(game: Node) -> void:
	var boss = game.boss
	var player = game.player
	var spawn: Vector3 = boss.global_position
	for mode in 3:
		boss.clear_attack()
		boss.step += 1
		boss.configure_difficulty(mode)
		boss.global_position = spawn
		player.global_position = spawn + Vector3(-9, 0, 0)
		player.invulnerable_time = 100.0
		boss.begin_attack("rupture" if mode == 2 else "rush")
		check(boss.core_index >= 0 and boss.falling_core.core.position.y > 5.0, "Mode %d starts with the core hanging over the arena" % mode)
		if boss.core_index < 0:
			continue
		var core_x: float = boss.falling_core.global_position.x
		player.global_position = Vector3(core_x - 3.0, boss.floor_height + 1.0, 0)
		await advance_until(boss, boss.CORE_LAND_TIME + .06)
		check(is_zero_approx(boss.falling_core.core.position.y) and not boss.exposed, "The slam drops the core before the vulnerable window")
		var snapshot: Array = boss.foundry_snapshot()
		boss.clear_attack()
		boss.apply_foundry_snapshot(snapshot)
		check(boss.falling_core.visible and is_equal_approx(boss.falling_core.global_position.x, core_x), "A replica reconstructs the landed core")
		await advance_until(boss, boss.AIM_LOCK_TIME + .05)
		check(boss.rush_hits_core and is_instance_valid(boss.tracks), "Standing past the core locks the charge lane")
		await advance_until(boss, boss.RUSH_END_TIME)
		check(boss.core_shattered and boss.exposed and not boss.falling_core.visible, "The drill breaks the core and stuns Titan")
		var health: float = boss.health
		boss.take_damage(10.0)
		check(boss.health < health, "Titan takes damage during the stun")
		var stunned: Array = boss.foundry_snapshot()
		boss.clear_attack()
		boss.apply_foundry_snapshot(stunned)
		check(boss.exposed and not boss.falling_core.visible, "A replica shows Titan exposed with the core destroyed")
	boss.clear_attack()
	boss.global_position = spawn
	player.global_position = spawn + Vector3(-3.5, 0, 0)
	boss.begin_attack("rush")
	await advance_until(boss, boss.RUSH_END_TIME + .06)
	check(boss.world_impact and not boss.core_shattered and not boss.exposed, "A missed charge leaves Titan's armor sealed")
	boss.clear_attack()

func verify_lava(game: Node, act: int) -> void:
	var boss = game.boss
	var player = game.player
	var path := "TERRAIN/WardenEastPerch" if act == 1 else "TERRAIN/TitanEastPerch"
	var deck: Node3D = game.game_root.get_node(path)
	var low := Vector3(deck.global_position.x, boss.floor_height + .9, 0)
	player.global_position = low
	player.health = player.max_health
	player.invulnerable_time = 0.0
	boss.begin_attack("lava_surge")
	check(boss.tracks.visible and not boss.lava_surface.visible, "Act %d warns before the lava rises" % act)
	await advance_until(boss, boss.lava_warning_time() + 1.2)
	check(boss.lava_surface.visible and player.health < player.max_health, "Act %d lava damages the operator on the lower floor" % act)
	var health: float = player.health
	player.global_position = deck.global_position + Vector3.UP * .9
	player.invulnerable_time = 0.0
	await advance_until(boss, boss.lava_warning_time() + 2.8)
	check(is_equal_approx(health, player.health), "Act %d east perch stays above the lava" % act)
	var snapshot: Array = boss.foundry_snapshot()
	boss.clear_attack()
	boss.apply_foundry_snapshot(snapshot)
	check(boss.lava_surface.visible and boss.lava_surface.global_position.y + 7.0 > boss.floor_height + 2.0, "Act %d replica shows the same lava height" % act)
	await advance_until(boss, boss.lava_warning_time() + 4.2)
	check(boss.motion.is_empty() and not is_instance_valid(boss.lava_surface), "Act %d lava drains before the next attack" % act)

func run() -> void:
	for act in [1, 2]:
		var game := start(act)
		check(game.boss.get_parent().has_node("BossDeploymentPad"), "Act %d has a boss deployment pad" % act)
		await physics_frame
		if act == 2:
			await verify_charge(game)
		await verify_lava(game, act)
		game.queue_free()
		await process_frame
	finish(failures)
