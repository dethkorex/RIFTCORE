extends "res://tests/game_test_tree.gd"

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	failures += int(not ok)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile.path = "user://shaft-grip-profile.cfg"
	game.checkpoint_path = "user://shaft-grip-run.cfg"
	root.add_child(game)
	game.profile.manual_only = true
	game.act = 2
	game.start_game(false, 1)
	var shaft: Node3D = game.game_root.get_node("TERRAIN/LavaEscape")
	var player = game.player
	game.set_physics_process(false)
	player.set_physics_process(false)
	shaft.set_physics_process(false)
	await physics_frame
	await physics_frame
	var bands := []
	for body in shaft.get_node("SideWalls").get_children():
		if body is StaticBody3D and not body.is_in_group(&"no_wall_kick"):
			bands.append(body.name)
	check(bands == [&"West02", &"West10", &"East07", &"East15"], "only the four grip bands support wall kicks")
	for flags in [0, 1, 2, 3]:
		game.gate_relays.set_active(flags)
		for tick in 30:
			shaft._physics_process(1.0 / 60.0)
		await physics_frame
		check(shaft.door.passable == (flags == 3) and shaft.door.blocker.disabled == (flags == 3),
			"escape entrance enforces relay mask %d" % flags)
	for sample in [["West02",-1], ["West01",-1], ["West05",-1], ["East07",1], ["East04",1], ["East12",1]]:
		var surface: StaticBody3D = shaft.get_node("SideWalls/" + sample[0])
		var side: float = sample[1]
		player.global_position = surface.global_position - Vector3(side * 1.07, 0, -2.07)
		player.hatch_floor = null
		player.wall_grace = 0
		player.dash_left = 0
		player.wall_launch_lock = 0
		player.contact_recoil = 0
		for tick in 4:
			player.velocity = Vector3(side * 9, -1, 0)
			player.move_and_slide()
			player.update_wall_contact(1.0 / 60.0, side)
			await physics_frame
		check(player.is_on_wall() and not player.grounded(), sample[0] + " gives real airborne wall contact")
		check((player.wall_grace > 0) == (not surface.is_in_group(&"no_wall_kick")), sample[0] + " enforces its grip during player movement")
	finish(failures)
