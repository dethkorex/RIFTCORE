extends "res://tests/game_test_tree.gd"

class GuestLink extends Node:
	func get_sender_id() -> int:
		return 12

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

func lava_probe(boss: Node, at: Vector3) -> Node3D:
	var probe = load("res://scenes/actors/riftcore_player.tscn").instantiate()
	boss.get_parent().add_child(probe)
	probe.set_physics_process(false)
	probe.invulnerable_time = 100.0
	probe.global_position = at + Vector3.UP * (probe.standing_capsule.height * .5 + .01)
	return probe

func verify_titan_lava(game: Node) -> void:
	var boss = game.boss
	var player = game.player
	var deck: Node3D = game.game_root.get_node("TERRAIN/TitanEastPerch")
	player.global_position = deck.global_position + Vector3.UP * .9
	var probe := lava_probe(boss, Vector3(deck.global_position.x, boss.floor_height, 0))
	var deaths := [0]
	probe.fell_into_pit.connect(func(): deaths[0] += 1)
	boss.begin_attack("lava_surge")
	check(boss.tracks.visible and not boss.lava_surface.visible, "Act 2 warns before the lava rises")
	await advance_until(boss, boss.lava_warning_time() + 1.2)
	check(boss.lava_surface.visible and probe.health == 0.0, "Act 2 flood kills a floor operator even with invulnerability")
	await advance_until(boss, boss.lava_warning_time() + 2.8)
	check(deaths[0] == 1 and is_equal_approx(player.health, player.max_health), "Act 2 refuge stays safe and lava takes only one life per contact")
	var snapshot: Array = boss.foundry_snapshot()
	boss.clear_attack()
	boss.apply_foundry_snapshot(snapshot)
	check(boss.lava_surface.visible and boss.lava_surface.global_position.y > boss.floor_height + 2.0, "Act 2 replica shows the same lava height")
	await advance_until(boss, boss.lava_warning_time() + 4.2)
	check(boss.motion.is_empty() and not is_instance_valid(boss.lava_surface), "Act 2 lava drains before the next attack")

func verify_warden_lava(game: Node) -> void:
	var boss = game.boss
	var player = game.player
	var purge_route: Node3D = game.game_root.get_node("TERRAIN/WardenPurgeRoute")
	var valve_deck := purge_route.get_node("ValveDeck") as Node3D
	var safety := purge_route.get_node("Takeoff") as Node3D
	var perch: Vector3 = boss.warden_perch_position()
	var platform := boss.warden_perch as StaticBody3D
	var collider := platform.get_node("Collider") as CollisionShape3D
	var berth := collider.shape as ConvexPolygonShape3D
	var front := -INF
	for point in berth.points:
		front = maxf(front, collider.to_global(point).z)
	var jump_apex: float = pow(player.wall_kick_height, 2.0) / (2.0 * player.gravity)
	check(front < -player.standing_capsule.radius and platform.global_position.y - valve_deck.global_position.y > jump_apex + 1.0, "The open-backed Warden dock sits above operator reach")
	var column := game.game_root.get_node("TERRAIN/WardenKickColumn") as StaticBody3D
	var switchback := purge_route.get_node("Switchback") as Node3D
	var jump_height: float = pow(player.jump_velocity, 2.0) / (2.0 * player.gravity)
	check(safety.position.y > jump_height + 1.5 and column.position.x > safety.position.x and switchback.position.x - safety.position.x > 7.5, "The first landing requires a wall kick and has a full traverse to the second")
	var space := column.get_world_3d().direct_space_state
	var x := column.global_position.x
	var feet_y: float = boss.floor_height
	var through := PhysicsRayQueryParameters3D.create(Vector3(x - 1, feet_y + player.standing_capsule.height, 0), Vector3(x + 1, feet_y + player.standing_capsule.height, 0), 1)
	var contact := PhysicsRayQueryParameters3D.create(Vector3(x - 1, feet_y + 3, 0), Vector3(x + 1, feet_y + 3, 0), 1)
	check(space.intersect_ray(through).is_empty() and space.intersect_ray(contact).get("collider") == column, "The kick pier clears the ground lane and has a solid midair grip")
	player.global_position = safety.global_position + Vector3.UP * .9
	var west := lava_probe(boss, Vector3(boss.arena_left + 2.0, boss.floor_height, 0))
	var east := lava_probe(boss, Vector3(boss.arena_right - 2.0, boss.floor_height, 0))
	var deaths := [0]
	east.fell_into_pit.connect(func(): deaths[0] += 1)
	boss.global_position = boss.warden_landing_position()
	var start: Vector3 = boss.global_position
	boss.begin_attack("lava_surge")
	await advance_until(boss, 1.57)
	check(boss.global_position.y > start.y + 3.0, "Warden leaps toward the raised gantry")
	check(boss.tracks.visible and not boss.lava_surface.visible and east.health > 0.0, "The flood warning gives operators time to reach the ledges")
	var warning: float = boss.warden_flood_warning()
	await advance_until(boss, warning + .28)
	check(boss.global_position.is_equal_approx(perch) and not boss.exposed, "Warden lands and holds above the flood while armored")
	check(east.health == 0.0 and west.health == 0.0, "Both ends of the room flood together and lava contact kills immediately")
	var state: Array = boss.foundry_snapshot()
	var reached_height: float = boss.lava_surface.global_position.y
	boss.clear_attack()
	boss.apply_foundry_snapshot(state)
	check(boss.lava_surface.visible and is_equal_approx(reached_height, boss.lava_surface.global_position.y), "Co-op replicas reconstruct the uniform rising surface")
	await advance_until(boss, warning + boss.WARDEN_RISE_TIME + .35)
	check(boss.lava_surface.global_position.y > reached_height and deaths[0] == 1 and is_equal_approx(player.health, player.max_health), "The lava rises continuously below the safe first ledge")
	player.velocity = Vector3.DOWN * 8.0
	player.move_and_slide()
	boss.elevated_time[player.get_instance_id()] = 1.25
	boss.maybe_target_warden_ledge()
	check(boss.zones.size() == 1 and boss.zones[0].global_position.y > boss.floor_height + 1.9, "Warden targets a lingering player with telegraphed steam on their ledge")
	check(boss.global_position.is_equal_approx(perch) and not boss.exposed and boss.purge_valve.ready_to_turn, "Warden stays overhead until the valve is turned")
	var stranded := lava_probe(boss, safety.global_position)
	player.global_position = switchback.global_position + Vector3.UP * .9
	await advance_until(boss, warning + boss.WARDEN_UPPER_SURGE_DELAY + boss.WARDEN_UPPER_SURGE_TIME + .12)
	check(stranded.health == 0.0 and player.health > 0.0 and boss.lava_surface.global_position.y > safety.global_position.y + 1.0, "The higher surge swallows the first ledge but leaves the wall-kick landing safe")
	var valve: Node3D = boss.purge_valve
	var guest = lava_probe(boss, safety.global_position)
	var mission = load("res://tests/coop_revival_fixture.gd").new()
	root.add_child(mission)
	mission.host = true
	mission.act = 1
	mission.roster = [11, 12]
	mission.operators.assign([player, guest])
	mission.peer = GuestLink.new()
	mission.add_child(mission.peer)
	mission.boss = boss
	mission.boss_started = true
	mission.receive_gate_relay_request(1)
	check(mission.broadcasts == 0 and boss.warden_drain_started < 0.0, "A distant co-op operator cannot turn the purge valve")
	guest.global_position = valve.global_position - Vector3.UP * .29
	mission.receive_gate_relay_request(1)
	mission.receive_gate_relay_request(1)
	var accepted: bool = mission.broadcasts == 1 and boss.warden_drain_started >= 0.0
	check(accepted, "The single raised valve accepts one nearby co-op interaction")
	mission.queue_free()
	if not accepted:
		return
	var drain_until: float = boss.warden_drop_start()
	var land_at: float = boss.warden_landing_time()
	var full_height: float = boss.lava_surface.global_position.y
	await advance_until(boss, boss.warden_drain_started + .45)
	check(boss.lava_surface.visible and boss.lava_surface.global_position.y < full_height and boss.zones.is_empty(), "Turning the valve lowers the surface and closes the elevated steam vents")
	await advance_until(boss, drain_until + .10)
	check(not boss.lava_surface.visible and not boss.exposed and boss.warden_impact_mark.visible, "The floor drains before the marked Warden drop")
	var draining: Array = boss.foundry_snapshot()
	boss.clear_attack()
	boss.apply_foundry_snapshot(draining)
	check(not boss.lava_surface.visible and boss.pressure_released, "Co-op replicas recover the drained floor and turned valve")
	var landing_pos: Vector3 = boss.warden_landing_position()
	var hit := lava_probe(boss, Vector3(landing_pos.x, boss.floor_height, 0.0))
	hit.invulnerable_time = 0.0
	var clear := lava_probe(boss, Vector3(landing_pos.x, boss.floor_height + .85, 0.0))
	clear.invulnerable_time = 0.0
	await advance_until(boss, land_at + .03)
	check(boss.exposed and is_equal_approx(boss.global_position.y, boss.floor_height + boss.chassis_height), "The Warden becomes vulnerable on landing")
	check(hit.health < hit.max_health and clear.health == clear.max_health, "The landing impact is grounded and can be jumped")
	var boss_hp: float = boss.health
	boss.take_damage(10.0)
	check(boss.health < boss_hp, "The landed Warden takes damage during the purge window")
	await advance_until(boss, boss.window_end + .1)
	check(boss.motion.is_empty() and not is_instance_valid(boss.lava_surface) and not boss.exposed, "The purge window closes and clears the phase")

func run() -> void:
	for act in [1, 2]:
		var game := start(act)
		check(game.boss.get_parent().has_node("BossDeploymentPad"), "Act %d has a boss deployment pad" % act)
		await physics_frame
		if act == 2:
			await verify_charge(game)
			await verify_titan_lava(game)
		else:
			await verify_warden_lava(game)
		game.queue_free()
		await process_frame
	finish(failures)
