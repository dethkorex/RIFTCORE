extends SceneTree

const Catalog = preload("res://scripts/sector_catalog.gd")
var failures := 0

func _initialize():
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func park_enemies(game) -> void:
	for bot in get_nodes_in_group("level_enemies"):
		if game.game_root.is_ancestor_of(bot):
			bot.set_physics_process(false)
			bot.collision_layer = 0

func run():
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if not args.is_empty() else OS.get_user_data_dir()
	var scene := load("res://scenes/main.tscn") as PackedScene
	var save_path := dir.path_join("act-test-save.cfg")
	var profile_path := dir.path_join("act-test-profile.cfg")
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(profile_path)
	var seed := ConfigFile.new()
	seed.set_value("checkpoint", "sector", 1)
	seed.set_value("checkpoint", "at_start", true)
	seed.save(save_path)
	for number in range(1, 11):
		var game = scene.instantiate()
		game.profile.path = profile_path
		game.checkpoint_path = save_path
		root.add_child(game)
		current_scene = game
		game.load_game()
		park_enemies(game)
		await frames(72)
		var p = game.player
		var info := Catalog.info(number)
		check(game.sector == number and game.act == 1 and game.boss.name == "SectorMiniboss", "%02d original map deploys with a miniboss" % number)
		p.invulnerable_time = 999.0
		p.global_position = game.gate.global_position + Vector3(-2.1, .87, 0)
		p.velocity = Vector3.ZERO
		await frames(50)
		p.global_position = game.gate.global_position + Vector3(3.4, .87, 0)
		var entrance_x: float = p.global_position.x
		var arena_floor: float = game.gate.global_position.y
		await frames(69)
		check(game.arena_intro and not p.is_physics_processing() and p.global_position.x > entrance_x + 1.0 and game.boss.visible and game.boss.global_position.y > arena_floor + 2.25, "%02d entrance locks movement, walks RX-07 in and reveals the falling miniboss" % number)
		await frames(167)
		var mini = game.boss
		check(game.arena_sealed and mini.active and p.is_physics_processing() and mini.global_position.y > arena_floor and mini.turn >= 1, "%02d gate seals and guard executes its attack pattern" % number)
		var clean := number % 2 == 0
		if not clean:
			var original_mini = weakref(mini)
			game._on_pit_fall()
			await frames(44)
			check(original_mini.get_ref() == null and game.boss.health == game.boss.max_health and p.lives == 2, "%02d death resets the guard and costs one life" % number)
			p.global_position = game.gate.global_position + Vector3(-2.1, .87, 0)
			p.velocity = Vector3.ZERO
			await frames(50)
			p.global_position = game.gate.global_position + Vector3(3.4, .87, 0)
			await frames(142)
		game.boss.take_damage(game.boss.health * 3.0)
		await frames(44)
		check(game.boss_defeated and not game.run_weapons.has(info.reward) and not game.game_root.has_node("ExitBarrier"), "%02d guard opens Act 2 without granting final weapon" % number)
		p.gain_experience(40)
		p.credits = 77
		p.health = 43
		p.energy = 21
		var xp: int = p.experience
		var reserves: int = game.profile.reserve_lives
		var bank: int = game.profile.credits
		p.global_position = game.game_root.get_node("MARKERS/RoomExit").global_position
		p.velocity = Vector3.ZERO
		await frames(4)
		for frame in range(2400):
			if not game.advancing_act:
				break
			await physics_frame
		var saved := ConfigFile.new()
		var saved_act: bool = saved.load(save_path) == OK and saved.get_value("checkpoint", "act", 0) == 2
		p = game.player
		check(saved_act and game.act == 2 and p.experience == xp and p.credits == 77 and p.lives == (3 if clean else 2) and p.health == 43 and p.energy == 21, "%02d Act 2 saves and carries exact run state" % number)
		check(game.profile.reserve_lives == reserves + 1 and game.profile.credits > bank and game.profile.completed_challenges.has("%d_1" % number), "%02d Gatebreaker banks credits and one reserve life" % number)
		park_enemies(game)
		await frames(60)
		check(p.is_on_floor() and game.boss.name == info.boss_node and game.remaining_enemies >= 7, "%02d new route has a safe spawn, placed enemies, and the original boss" % number)
		p.invulnerable_time = 999.0
		p.global_position = game.gate.global_position + Vector3(-2.1, .87, 0)
		await frames(50)
		p.global_position = game.gate.global_position + Vector3(3.4, .87, 0)
		p.velocity = Vector3.ZERO
		await frames(69)
		check(game.arena_intro and not p.is_physics_processing() and game.boss.visible and game.camera_rig.global_position.distance_to(game.boss.global_position) < 6.1, "%02d camera reveals the dropping final boss" % number)
		await frames(186)
		check(game.arena_sealed and game.boss.active and game.boss.is_on_floor(), "%02d final boss engages on the new arena floor" % number)
		var boss = game.boss
		var before: float = boss.health
		if number in [2, 3]:
			boss.take_fire_damage(10.0)
		elif not String(info.weak).is_empty():
			boss.take_element_damage(10.0, p.global_position, info.weak)
		if number == 3 or not String(info.weak).is_empty():
			check(before - boss.health > 13.0, "%02d final boss elemental weakness still applies" % number)
		if number >= 3:
			boss.cooldown = 999
			for move in boss.PATTERNS[number]:
				boss.execute(move)
				await frames(2)
		boss.take_damage(boss.health * 3.0)
		await frames(285)
		var shots := []
		p.shot_fired.connect(func(shot): shots.append(shot.weapon_id))
		p.energy = p.max_energy
		var previous_energy: float = p.energy
		p.shoot(true)
		await frames(8)
		if number >= 3:
			check(info.reward in shots and is_equal_approx(previous_energy - p.energy, 30.0), "%02d charged reward fires and spends energy once" % number)
		var blueprint := "bp_%02d_00" % number
		p.recovered_blueprints[blueprint] = true
		p.global_position = game.game_root.get_node("MARKERS/RoomExit").global_position
		p.velocity = Vector3.ZERO
		await frames(6)
		var extracted := saved.load(save_path) == OK
		check(game.sector_complete and game.run_weapons.has(info.reward) and extracted and saved.get_value("checkpoint", "sector", 0) == mini(10, number + 1) and saved.get_value("checkpoint", "act", 0) == (2 if number == 10 else 1), "%02d final boss rewards and extraction advance campaign" % number)
		check(game.profile.blueprints.has(blueprint) and p.recovered_blueprints.is_empty(), "%02d extraction banks a discovered blueprint" % number)
		check(game.pause_menu.find_children("*", "Label", true, false).any(func(label): return label.text == "DEPLOYMENT COMPLETE"), "%02d extraction displays the mission report" % number)
		check(game.profile.completed_challenges.has("%d_2" % number) and game.profile.completed_challenges.has("%d_3" % number) == clean and game.profile.reserve_lives == reserves + (3 if clean else 2), "%02d completion tiers pay once and Clean Run requires zero deaths" % number)
		var repeat: Array[int] = [0, 1]
		if clean:
			repeat.append(2)
		var second_award: Dictionary = game.profile.complete_challenges(number, repeat)
		check(second_award.is_empty(), "%02d repeat completion cannot pay again" % number)
		paused = false
		root.remove_child(game)
		game.queue_free()
		await frames(3)
	quit(failures)
