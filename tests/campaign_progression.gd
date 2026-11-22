extends "res://tests/game_test_tree.gd"

const Catalog := preload("res://scripts/sector_catalog.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func wait_for(condition: Callable, ticks: int) -> bool:
	for tick in ticks:
		if condition.call():
			return true
		await physics_frame
	return false

func check(passed: bool, label: String) -> bool:
	print("PASS " if passed else "FAIL ", label)
	failures += int(not passed)
	return passed

func prepare_operator(game) -> void:
	game.player.invulnerable_time = 999.0
	for enemy in get_nodes_in_group(&"level_enemies"):
		if game.game_root.is_ancestor_of(enemy):
			enemy.set_physics_process(false)
			enemy.collision_layer = 0

func enter_arena(game, after_retry := false) -> bool:
	var operator = game.player
	var gate: Vector3 = game.gate.global_position
	operator.global_position = gate + Vector3(-2.1, .88, 0)
	await physics_frame
	if not after_retry:
		if not check(game.gate_relays.count() == 0 and not game.gate_open, "Both relays start unpowered and the gate stays shut"):
			return false
		for terminal in game.gate_relays.terminals:
			operator.global_position = terminal.global_position + Vector3.UP * .88
			if not game.gate_relays.interact(operator, false):
				return check(false, "Relay responds to the operator at its terminal")
	operator.global_position = gate + Vector3(-2.1, .88, 0)
	operator.velocity = Vector3.ZERO
	if not check(await wait_for(func(): return game.arena_door.passable, 160), "Both relays release the gate"):
		return false
	operator.global_position = gate + Vector3(3.4, .88, 0)
	if not check(await wait_for(func(): return game.arena_intro, 95), "Entering the arena starts the intro"):
		return false
	return check(await wait_for(func(): return game.arena_sealed and game.boss.active and operator.is_physics_processing(), 550),
		"The gate seals and the fight takes over from the intro")

func defeat_boss(game) -> bool:
	var boss = game.boss
	var operator = game.player
	if game.sector == 1:
		for phase in 3:
			boss.open_armor()
			boss.take_damage(100000.0)
	elif game.sector == 2 and game.act == 1:
		for phase in 3:
			if not await wait_for(func(): return not boss.root_anchor.dormant, 150):
				return check(false, "Briar grows its next anchor")
			boss.root_anchor.present(boss.root_anchor.global_position, 0, true)
			boss.expose_briar()
			boss.take_damage(100000.0)
	elif game.sector == 2:
		operator.global_position = boss.drains[0].global_position + Vector3.UP * .90
		operator.velocity = Vector3.ZERO
		if not await wait_for(func(): return boss.exposed, 720):
			return check(false, "Verdant's canopy drain exposes its reactor")
		boss.take_damage(100000.0)
	else:
		boss.take_damage(100000.0)
	return check(game.boss_defeated, "Defeat opens the route to extraction")

func move_to_exit(game) -> void:
	game.player.global_position = game.game_root.get_node("MARKERS/RoomExit").global_position
	game.player.velocity = Vector3.ZERO

func play_sector(game, save_path: String, number: int) -> void:
	var info := Catalog.info(number)
	check(game.boss.name == "SectorMiniboss", "Act I deploys with a miniboss")
	prepare_operator(game)
	if not await enter_arena(game):
		return
	if number == 1:
		var original: WeakRef = weakref(game.boss)
		game._on_pit_fall()
		if not check(await wait_for(func(): return original.get_ref() == null and not game.respawning, 250), "Death replaces the boss and restores the arena"):
			return
		check(game.boss.health == game.boss.max_health and game.player.lives == 2, "Retry restores boss HP and costs one life")
		check(game.gate_relays.count() == 2, "Retry retains the powered relays")
		if not await enter_arena(game, true):
			return
	if not await defeat_boss(game):
		return
	check(not game.run_weapons.has(info.reward), "The miniboss leaves the sector weapon with the final boss")
	game.player.gain_experience(40)
	game.player.credits = 77
	game.player.health = 43
	game.player.energy = 21
	var xp: int = game.player.experience
	var lives: int = game.player.lives
	# Keep the stage cached for the headless renderer before the threaded transition.
	var next_stage := load(game.level_path(2)) as PackedScene
	if not check(next_stage != null, "Act II scene is available to the loader"):
		return
	move_to_exit(game)
	if not check(await wait_for(func(): return game.act == 2 and not game.advancing_act, 1800), "Extraction from Act I loads Act II"):
		print("Transition state: act=", game.act, " loading=", game.advancing_act, " retry=", game.act_exit_retry,
			" operator=", game.player.global_position)
		return
	var operator = game.player
	var saved := ConfigFile.new()
	check(operator.experience == xp and operator.credits == 77 and operator.lives == lives
		and operator.health == 43 and operator.energy == 21 and saved.load(save_path) == OK
		and saved.get_value("checkpoint", "act", 0) == 2, "Act II carries operator state and writes a resume point")
	check(game.boss.name == info.boss_node and game.remaining_enemies > 0, "Act II deploys the sector boss and its enemy roster")
	prepare_operator(game)
	if not await enter_arena(game) or not await defeat_boss(game):
		return
	if not check(await wait_for(func(): return not game.suit_reveal_active and game.run_weapons.has(info.reward), 800), "The final boss awards the sector weapon"):
		return
	var blueprint := "bp_%02d_00" % number
	operator.recovered_blueprints[blueprint] = true
	move_to_exit(game)
	if not check(await wait_for(func(): return game.sector_complete, 160), "Final extraction completes the sector"):
		return
	check(saved.load(save_path) == OK and saved.get_value("checkpoint", "sector", 0) == mini(number + 1, Catalog.SECTORS.size()),
		"Extraction saves the next deployment")
	check(game.profile.blueprint_items.has(blueprint) and operator.recovered_blueprints.is_empty(), "Extraction banks the discovered blueprint in Storage")
	check(game.profile.hard_unlocked(number) and is_instance_valid(game.pause_menu), "A Normal clear unlocks Hard and shows the mission report")

func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var args := OS.get_cmdline_user_args()
	var directory := args[0] if not args.is_empty() else OS.get_user_data_dir()
	for number in range(1, Catalog.SECTORS.size() + 1):
		print("SECTOR ", number)
		var game = scene.instantiate()
		var save_path := directory.path_join("campaign-test-run-%02d.cfg" % number)
		game.profile.path = directory.path_join("campaign-test-profile-%02d.cfg" % number)
		game.checkpoint_path = save_path
		root.add_child(game)
		current_scene = game
		game.profile.manual_only = true
		game.sector = number
		game.start_game(false, number)
		await play_sector(game, save_path, number)
		paused = false
		game.queue_free()
		await process_frame
	finish(failures)
