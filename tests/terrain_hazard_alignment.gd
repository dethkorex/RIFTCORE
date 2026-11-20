extends SceneTree

var failures := 0
var elapsed := 0.0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	failures += int(not ok)

func sample(seconds: float) -> void:
	elapsed = seconds
	for tick in 5:
		await physics_frame

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var deck = load("res://assets/campaign/orbital_array/terrain/phase.tscn").instantiate()
	stage.add_child(deck)
	deck.phase_time = func(): return elapsed
	for fraction in [.2, .57, .78, .95, .05]:
		await sample(fraction * deck.period)
		var solid: bool = fraction < .65
		var ray := PhysicsRayQueryParameters3D.create(Vector3.UP, Vector3.DOWN)
		var hit := stage.get_world_3d().direct_space_state.intersect_ray(ray)
		check((hit.get("collider") == deck) == solid, "phase %.2f physical foothold" % fraction)
		check(not deck.panels.is_empty() and deck.panels.all(func(panel): return panel.is_visible_in_tree() == solid), "phase %.2f visible deck" % fraction)
		check(deck.lamps.size() == 2 and deck.lamps.all(func(lamp): return lamp.is_visible_in_tree()), "phase %.2f signal lamps" % fraction)

	var press = load("res://scripts/biome_zone.gd").new()
	press.kind = press.Kind.PRESS
	press.dimensions = Vector3(4, 5, 3)
	press.position = Vector3(10, 2.5, 0)
	press.phase_time = func(): return elapsed
	stage.add_child(press)
	var player = load("res://scenes/actors/riftcore_player.tscn").instantiate()
	stage.add_child(player)
	player.set_physics_process(false)
	player.invulnerable_time = 0
	player.position = Vector3(10, 3.3, 0)
	var full_health: float = player.health
	await sample(press.period * .75)
	check(not press.overlaps_body(player) and player.health == full_health, "operator above lowered jaw is clear")
	player.position.y = press.effect.global_position.y
	await sample(press.period * .78)
	check(press.overlaps_body(player) and player.health < full_health, "lowered jaw damages on contact")
	var after_hit: float = player.health
	player.invulnerable_time = 0
	await sample(press.period * .12)
	check(not press.overlaps_body(player) and player.health == after_hit, "retracted jaw clears the operator")
	print("TERRAIN ALIGNMENT FAILURES ", failures)
	quit(failures)
