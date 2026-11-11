extends SceneTree
var failed := 0
func _initialize():
	call_deferred("run")
func frames(n: int):
	for i in n:
		await physics_frame
func ok(condition: bool, msg: String):
	print("PASS " if condition else "FAIL ", msg)
	if not condition:
		failed += 1
func make_game(profile_file: String, checkpoint_file: String):
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile.path = profile_file
	game.checkpoint_path = checkpoint_file
	root.add_child(game)
	current_scene = game
	return game
func run():
	var dir := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else OS.get_user_data_dir()
	var a := dir.path_join("sector-qa-profile.cfg")
	var b := dir.path_join("sector-qa-checkpoint.cfg")
	for path in [a,b]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var game = make_game(a,b)
	game.start_game(false)
	await frames(4)
	var p = game.player
	p.invulnerable_time = 99
	var ladder: Node3D = game.game_root.get_node("TERRAIN/ArenaLadderWest")
	p.global_position = ladder.global_position + Vector3.UP * 0.86
	p.model_root.rotation.y = PI / 2.0
	Input.action_press("climb_up")
	await frames(18)
	ok(p.ladder == ladder and p.global_position.y > 1.3 and p.model_root.global_basis.z.dot(-ladder.global_basis.z) > 0.995, "ladder climbs and turns the model squarely toward the rungs")
	Input.action_release("climb_up")
	Input.action_press("climb_down")
	await frames(6)
	ok(p.ladder == ladder and p.velocity.y < 0.0 and p.model_root.global_basis.z.dot(-ladder.global_basis.z) > 0.995, "descending still faces the rungs")
	Input.action_release("climb_down")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	ok(p.ladder == null and absf(absf(p.model_root.rotation.y) - PI / 2.0) < 0.01, "jump off restores side-facing movement")
	var rb := false
	for event in InputMap.action_get_events("swap_weapon"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			rb = true
	ok(rb and not p.magma_unlocked, "RB default and no unearned fire weapon")
	game.boss.active = true
	game.boss.target = p
	game.boss.invulnerable_time = 0.0
	game.boss.take_damage(game.boss.health)
	await frames(55)
	p.gain_experience(230)
	p.global_position = game.game_root.get_node("MARKERS/RoomExit").global_position
	p.velocity = Vector3.ZERO
	await frames(6)
	ok(game.sector_complete, "Factory extraction records a clear")
	paused = false
	game.queue_free()
	await frames(3)
	var next = make_game(a,b)
	ok(next.menu.saved_sector == 2 and next.menu.at_sector_start, "Command Deck offers the Machine Jungle deployment")
	next.load_game()
	await frames(175)
	p = next.player
	ok(next.sector == 2 and p.lives == 3 and p.experience == 230 and p.magma_unlocked, "Machine Jungle loads with three lives, carried XP, and Magma Breaker carried in the saved run")
	ok(p.is_on_floor() and next.remaining_enemies == 22, "Jungle spawn stands on the floor with 22 configured enemies")
	var jungle_enemy = next.game_root.get_node("Actors/JungleUnit04")
	var hp: float = jungle_enemy.health
	jungle_enemy.take_fire_damage(10.0,p.global_position)
	ok(absf(jungle_enemy.health - hp + 15.0) < .01, "Magma deals 1.5x fire critical damage against jungle enemies")
	ok(next.game_root.get_node("TERRAIN/JungleTrap0").device.get_child_count() > 0, "jungle trap builds active geometry")
	var barrier = next.game_root.get_node("TERRAIN/CanopyVine")
	barrier.take_damage(1000.0)
	ok(barrier.health == 1.0, "vines withstand ordinary buster shots")
	barrier.take_fire_damage(8.0)
	await frames(5)
	ok(barrier.health == 0.0 and barrier.get_node("CollisionShape3D").disabled, "fire burns the vines and disables the barrier")
	Input.action_press("swap_weapon")
	await frames(3)
	Input.action_release("swap_weapon")
	ok(p.magma_active, "RB swaps the persisted fire weapon on after deploying")
	p.invulnerable_time = 999

	p.global_position = next.gate.global_position + Vector3(-2.15, 0.88, 0)
	await frames(60)
	p.global_position = next.gate.global_position + Vector3(3.4, 0.88, 0)
	await frames(55)
	var boss = next.boss
	ok(next.arena_sealed and boss.active, "crossing the boss gate seals the arena and starts the boss")
	var x_before: float = boss.global_position.x
	await frames(210)
	ok(boss.pattern > 1 and boss.global_position.x < x_before and boss.is_on_floor() and boss.facing < 0.0, "Verdant moves on the floor, faces RX-07, and advances the attack pattern")
	boss.take_damage(680.0)
	await frames(130)
	ok(get_nodes_in_group("arena_minions").size() >= 1, "Verdant summons a Canopy Wasp after its health threshold")
	boss.take_damage(boss.health)
	await frames(10)
	ok(next.run_weapons.has("thorn_swarm") and p.thorn_active and p.nature_suit_mesh.visible and not p.fire_suit_mesh.visible, "Verdant defeat unlocks Thorn Swarm")
	p.set_magma_active(false)
	p.energy=0.0
	p.global_position=next.gate.global_position + Vector3(-5.5,.88,0)
	p.velocity=Vector3.ZERO
	await frames(4)
	Input.action_press("dash")
	await frames(2)
	Input.action_release("dash")
	ok(p.dash_left>0.0 and p.energy==0.0,"ground dash works at zero energy and spends none")
	p.energy=p.max_energy
	var ammo: float = p.energy
	p.set_thorn_active()
	p.shoot(false)
	await frames(5)
	ok(absf(ammo - p.energy - 7.0) < .01, "Thorn Swarm fires a burst and costs energy")
	quit(failed)
