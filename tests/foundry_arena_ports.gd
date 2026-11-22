extends "res://tests/game_test_tree.gd"

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func verify(condition: bool, detail: String) -> void:
	print("FOUNDRY ", "PASS " if condition else "FAIL ", detail)
	failures += int(not condition)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var act := int(args[0]) if not args.is_empty() else 1
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile.path = "user://foundry-port-test.cfg"
	game.checkpoint_path = "user://foundry-port-save.cfg"
	root.add_child(game)
	current_scene = game
	game.profile.manual_only = true
	game.act = act
	game.start_game(false)
	var terrain = game.game_root.get_node("TERRAIN")
	var boss = game.boss
	var player = game.player
	player.remote_input = true
	game.set_physics_process(false)
	boss.target = player
	boss.set_physics_process(false)
	for actor in game.game_root.get_node("Actors").get_children():
		if actor.is_in_group("level_enemies"):
			actor.position.z = -8
			actor.set_physics_process(false)

	var relay = terrain.get_node("FurnaceBleedCoupler" if act == 1 else "ValveHoistCoupler")
	var vent = terrain.get_node("FurnaceVent" if act == 1 else "TurnbackFlare")
	vent.phase_time = func(): return vent.flame.warning_time + 0.12 - vent.offset
	await physics_frame
	await physics_frame
	verify(vent.lit, "vent cycles before operating the valve")
	player.position = Vector3(53.5, .87, 0) if act == 1 else Vector3(471.75, 1.46, 0)
	player.facing = 1.0
	player.shoot(false)
	for tick in 100:
		await physics_frame
		if relay.shown_power == 1 and not vent.lit:
			break
	verify(relay.triggered and not vent.lit, "buster shot reaches coupler and shuts off its vent")
	for tick in 620:
		await physics_frame
	verify(vent.lit == (act == 2), "hoist restores pressure after returning, fixed bleeder stays open")

	player.set_physics_process(false)
	var ports: Array[Node] = terrain.get_node("BossFloorPorts").get_children()
	for side in [-1.0, 1.0]:
		boss.clear_attack()
		var center := 2 if side < 0 else 7
		player.global_position = ports[center].global_position + Vector3.UP * .86
		boss.begin_attack("kiln_backdraft" if act == 1 else "casting_wave")
		var replica: Array = boss.foundry_snapshot()
		var count := 3 if act == 1 else 5
		verify(boss.zones.size() == count, "expected number of active floor outlets")
		for i in count:
			var index: int = center - 1 + i if act == 1 else (4 - i if side < 0 else 5 + i)
			var zone = boss.zones[i]
			verify(is_equal_approx(zone.global_position.x, ports[index].global_position.x), "flame matches grate %s" % ports[index].name)
			if act == 2 and i > 0:
				verify(zone.warning_time > boss.zones[i - 1].warning_time, "casting wave travels outward")
		boss.clear_attack()
		boss.apply_foundry_snapshot(replica)
		verify(boss.foundry_snapshot()[9] == replica[9], "guest reconstructs the same warning positions, widths and timing")
		var first = boss.zones[0]
		var next = boss.zones[1]
		var hp: float = player.health
		player.global_position.x = (first.global_position.x + next.global_position.x) * .5
		player.invulnerable_time = 0
		boss.elapsed = maxf(first.warning_time, next.warning_time) + .05
		boss.advance_flames(true)
		verify(is_equal_approx(player.health, hp), "space between grates is safe during the blast")
		player.global_position.x = first.global_position.x
		boss.advance_flames(true)
		verify(player.health < hp, "standing on the glowing grate deals damage")
		player.health = player.max_health
		player.clear_boss_debuff()
	finish(failures)
