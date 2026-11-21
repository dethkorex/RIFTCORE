extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for tick in count:
		await physics_frame

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	failures += int(not ok)

func check_guard(game) -> void:
	var guard = game.game_root.get_node("Actors/FurnaceGuard")
	guard.set_physics_process(false)
	guard.global_position = Vector3(70, 40, 0)
	var player = game.player
	for side in [-1.0, 1.0]:
		guard.direction = side
		guard.health = guard.max_health
		guard.attack_time = 0.0
		guard.shot_windup = 0.0
		guard.stagger_left = 0.0
		guard.invulnerable_time = 0.0
		guard.refresh_defense()
		await frames(3)
		var start: Vector3 = guard.global_position + Vector3(side * 4.1, 0, 0)
		var aim := Vector3.LEFT * float(side)
		player.launch_buster(start, aim, false, false, 18)
		await frames(22)
		check(is_equal_approx(guard.health, guard.max_health), "Closed shield blocks frontal tap, facing %s" % side)
		# This trajectory clips the upper edge of the projected plate and clears the body.
		player.launch_buster(start + Vector3.UP * 1.28, aim, true, false, 20)
		await frames(22)
		var remaining: float = guard.health
		check(remaining < guard.max_health and not guard.guard_active(), "Charged hit on shield rim damages and opens guard, facing %s" % side)
		check(is_equal_approx(guard.get_node("HealthBar").material_override.get_shader_parameter("remaining"), remaining / guard.max_health), "Visible HP meter follows guard damage")
		guard.invulnerable_time = 0
		player.launch_buster(start, aim, false, false, 8)
		await frames(22)
		check(guard.health < remaining, "Tap follows up through broken shield")
		guard.stagger_left = 0
		guard.invulnerable_time = 0
		guard.refresh_defense()
		remaining = guard.health
		player.launch_buster(guard.global_position - Vector3.RIGHT * side * 4.1, -aim, false, false, 8)
		await frames(22)
		check(guard.health < remaining, "Rear shot bypasses active shield")

func check_boulder(game, act: int) -> void:
	var rock = get_first_node_in_group(&"foundry_boulder")
	var player = game.player
	player.set_physics_process(false)
	player.global_position = rock.global_position + Vector3(rock.direction * 2.0, -1.0, 0)
	await frames(3)
	check(rock.status == 1, "Act %d approach triggers the boulder warning" % act)
	player.global_position = rock.global_position + Vector3.UP * 15
	var mark: float = rock.start.x + rock.direction * rock.runway_length
	var crossed := false
	var ticks := 0
	var checked_respawn := false
	while ticks < 550 and rock.status < 3:
		await physics_frame
		ticks += 1
		if rock.status == 2 and not checked_respawn:
			rock.reset_runway()
			check(rock.status == 2, "A respawn cannot interrupt a moving boulder")
			checked_respawn = true
		if (rock.position.x - mark) * rock.direction > 1.0:
			crossed = true
	print("Act ", act, " mark ", mark, " final ", rock.position, " state ", rock.status, " ticks ", ticks)
	check(crossed, "Act %d boulder keeps rolling beyond the yellow line" % act)
	check(rock.status == 3 and not rock.body_mesh.visible, "Act %d roll ends by shattering or leaving the sector" % act)
	var state: Array = rock.snapshot()
	check(is_equal_approx(state[4], rock.position.y), "Co-op snapshot includes actual boulder height")

func make_test_boulder(terrain: Node3D, at: Vector3) -> AnimatableBody3D:
	var rock := AnimatableBody3D.new()
	rock.set_script(load("res://scripts/foundry_boulder.gd"))
	rock.position = at
	terrain.add_child(rock)
	return rock

func check_fracture(game) -> void:
	var terrain: Node3D = game.game_root.get_node("TERRAIN")
	for charged in [false, true]:
		var rock := make_test_boulder(terrain, Vector3(30, 18, 0))
		rock.set_physics_process(false)
		var required := 4 if charged else 6
		for attempt in required:
			var shot = load("res://scripts/projectile.gd").new()
			shot.is_charged = charged
			rock.hit_by_projectile(shot)
			shot.free()
			check(rock.status == (3 if attempt == required - 1 else 0),
				"%s hit %d of %d" % ["Charged" if charged else "Standard", attempt + 1, required])
		rock.reset_runway()
		check(rock.status == 3 and not rock.body_mesh.visible, "Destroyed boulder stays destroyed on respawn")
		rock.queue_free()
	var wall := StaticBody3D.new()
	wall.position = Vector3(30, 18, 0)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 10, 3)
	collider.shape = box
	wall.add_child(collider)
	terrain.add_child(wall)
	var rolling := make_test_boulder(terrain, Vector3(34, 18, 0))
	var replica := make_test_boulder(terrain, Vector3(34, 27, 0))
	replica.authority = false
	await frames(3)
	rolling.status = 2
	for tick in 60:
		await physics_frame
		if rolling.status != 2:
			break
	check(rolling.status == 3 and rolling.hit_count == rolling.TO_BREAK and not rolling.body_mesh.visible,
		"Forward collision shatters the rolling boulder")
	replica.apply_snapshot(rolling.snapshot())
	check(replica.status == 3 and not replica.body_mesh.visible, "Guest snapshot shows the wall shatter")

func run() -> void:
	for act in [1, 2]:
		var game = load("res://scenes/main.tscn").instantiate()
		game.profile.manual_only = true
		root.add_child(game)
		current_scene = game
		game.act = act
		game.start_game(false, 1)
		await frames(8)
		if act == 1:
			await check_guard(game)
		await check_boulder(game, act)
		if act == 1:
			await check_fracture(game)
		game.queue_free()
		await frames(5)
	for voice in root.get_node("RiftAudio").find_children("*", "AudioStreamPlayer", true, false):
		voice.stop()
	await create_timer(0.5).timeout
	quit(failures)
