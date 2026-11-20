extends SceneTree

var failures := 0

class PacketSink extends Node:
	var received: Array
	func get_sender_id() -> int: return 1
	func get_host() -> int: return 1
	func call_func_unreliable(_method: Callable, act: int, security: PackedFloat32Array, arena: Array, props: Array, xp: int, sequence: int) -> void:
		received = [act, security, arena.duplicate(true), props.duplicate(), xp, sequence]


func _initialize() -> void:
	run.call_deferred()

func check_direction(boss, direction: float, stage: String) -> void:
	var forward: Vector3 = boss.armor.global_basis.z.normalized()
	var horizontal := Vector2(forward.x, forward.z).normalized()
	if horizontal.dot(Vector2(direction, 0)) < 0.995:
		push_error("%s %s expected %s, forward is %s" % [boss.name, stage, direction, forward])
		failures += 1

func check_guest_pose(game, side: float) -> void:
	var mission = load("res://scripts/coop_mission.gd").new()
	var transport := PacketSink.new()
	mission.peer = transport
	mission.stage = game.game_root
	mission.act = game.act
	mission.sector = game.sector
	mission.boss = game.boss
	mission.boss_started = true
	mission.gate_relays = game.gate_relays
	mission.arena_door = game.arena_door
	mission.repair_hall = game.repair_hall
	mission.room_status = Label.new()
	mission.host = true
	mission.broadcast_state()
	game.boss.armor.rotation.y = 0.0
	game.boss.facing = -side
	mission.host = false
	mission.callv("receive_state", transport.received)
	check_direction(game.boss, side, "guest received host's armor rotation")
	mission.room_status.free()
	transport.free()
	mission.free()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var last := int(args[1]) if args.size() > 1 else 10
	for sector in range(first, last + 1):
		for act in [1, 2]:
			var game = load("res://scenes/main.tscn").instantiate()
			game.profile.path = "user://boss-facing-test.cfg"
			game.checkpoint_path = "user://boss-facing-checkpoint.cfg"
			root.add_child(game)
			current_scene = game
			game.profile.manual_only = true
			game.sector = sector
			game.act = act
			game.start_game(false)
			var boss = game.boss
			var player = game.player
			player.set_physics_process(false)
			player.invulnerable_time = 30
			game.set_physics_process(false)
			# Alternate entry sides to catch a hard-coded west-facing cinematic exit.
			var side := -1.0 if act == 1 else 1.0
			player.position = boss.position + Vector3.RIGHT * side * 5.0
			var cinematic = load("res://scripts/boss_intro.gd").new()
			boss.add_child(cinematic)
			await cinematic.play(game.camera_rig, boss, game.gate.position.y, "TEST", Color.WHITE, sector, act, game.factory_hud)
			check_direction(boss, side, "after camera return")
			boss.active = true
			boss.target = player
			player.position.x = boss.position.x - side * 7.0
			for tick in 34:
				await physics_frame
			check_direction(boss, -side, "after cross-over")
			if sector >= 4:
				check_guest_pose(game, -side)
			print("FACING sector ", sector, " act ", act, " tested both sides")
			root.remove_child(game)
			game.queue_free()
			await process_frame
	quit(failures)
