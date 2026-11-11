extends SceneTree

const Catalog = preload("res://scripts/sector_catalog.gd")
var failures := 0

func _initialize():
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func mark(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:
		failures += 1

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if not args.is_empty() else OS.get_user_data_dir()
	var profile_path := dir.path_join("campaign-test-profile.cfg")
	var save_path := dir.path_join("campaign-test-checkpoint.cfg")
	var seed := ConfigFile.new()
	seed.set_value("checkpoint", "sector", 3)
	seed.set_value("checkpoint", "at_start", true)
	seed.set_value("checkpoint", "experience", 560)
	seed.set_value("checkpoint", "weapons", ["magma_breaker", "thorn_swarm"])
	seed.save(save_path)
	for number in range(3, 11):
		var info := Catalog.info(number)
		var game = load("res://scenes/main.tscn").instantiate()
		game.profile.path = profile_path
		game.checkpoint_path = save_path
		root.add_child(game)
		current_scene = game
		game.load_game()
		await frames(95)
		if not is_instance_valid(game.player):
			mark(false, "sector %d loads a player" % number)
			quit(failures)
			return
		var p = game.player
		var terrain = game.game_root.get_node("TERRAIN")
		mark(game.sector == number and p.is_on_floor() and p.lives == 3 and p.experience >= 560, "%02d %s loads and preserves XP and three lives" % [number,info.title])
		var enemies := 0
		var roles := {}
		for bot in get_nodes_in_group("level_enemies"):
			if not game.game_root.is_ancestor_of(bot):
				continue
			enemies += 1
			roles[bot.variant] = true
			bot.set_physics_process(false)
			bot.collision_layer = 0
		mark(enemies >= 12 and roles.size() == 5 and terrain.has_node("BiomeGimmick00"), "%02d five enemy variants, placed roster, and themed hazards" % number)
		p.invulnerable_time = 999
		p.global_position = game.gate.global_position + Vector3(-2.1, .88, 0)
		p.velocity = Vector3.ZERO
		await frames(58)
		p.global_position = game.gate.global_position + Vector3(4.0, .88, 0)
		await frames(80)
		var boss = game.boss
		mark(game.arena_sealed and boss.active and boss.name == info.boss_node, "%02d gate seals for %s" % [number,info.boss])
		var prior: float = boss.health
		if number == 3:
			boss.take_fire_damage(10)
		else:
			boss.take_element_damage(10,p.global_position,info.weak)
		mark(prior - boss.health > 13.0, "%02d boss elemental weakness is functional" % number)
		await frames(160)
		mark(boss.attack_index > 0 and boss.is_on_floor(), "%02d boss runs its attack state machine on the arena floor" % number)
		boss.cooldown = 999
		for move in boss.PATTERNS[number]:
			boss.execute(move)
			await frames(2)
		boss.take_damage(boss.health * 3.0)
		await frames(6)
		mark(game.boss_defeated and game.run_weapons.has(info.reward) and p.special_weapon == info.reward, "%02d %s unlocks and equips" % [number,info.reward_name])
		var shots := []
		p.shot_fired.connect(func(shot): shots.append(shot.weapon_id))
		p.energy = p.max_energy
		var previous_energy: float = p.energy
		p.shoot(true)
		await frames(8)
		mark(info.reward in shots and is_equal_approx(previous_energy - p.energy,30.0), "%02d reward fires its charged shot and spends energy once" % number)
		p.global_position = game.game_root.get_node("MARKERS/RoomExit").global_position
		p.velocity = Vector3.ZERO
		await frames(8)
		var save := ConfigFile.new()
		var success := save.load(save_path) == OK
		mark(game.sector_complete and success and int(save.get_value("checkpoint","sector",-1)) == mini(10,number+1), "%02d extraction advances the campaign" % number)
		paused = false
		root.remove_child(game)
		game.queue_free()
		await frames(3)
	quit(failures)
