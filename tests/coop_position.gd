extends SceneTree

class FakePeer extends Node:
	func get_host() -> int:
		return 11

	func get_sender_id() -> int:
		return 11

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(passed: bool, description: String) -> void:
	print("PASS " if passed else "FAIL ", description)
	failures += int(not passed)

func run() -> void:
	var mission = load("res://scripts/coop_mission.gd").new()
	var actor = (load("res://scenes/actors/riftcore_player.tscn") as PackedScene).instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.remote_input = true
	actor.local_prediction = true
	mission.operators.append(actor)
	mission.roster = [11]
	var peer := FakePeer.new()
	mission.peer = peer
	var rig = load("res://scripts/camera_rig.gd").new()
	root.add_child(rig)
	rig.target = actor
	mission.camera = rig
	var wall := StaticBody3D.new()
	var surface := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.4, 6.0, 3.0)
	surface.shape = shape
	wall.add_child(surface)
	root.add_child(wall)
	actor.global_position = Vector3(.63, 1.1, 0.0)
	rig.snap_to_target()
	var host_position := Vector3(-2.1, 1.1, 0.0)
	mission.targets = [[host_position, Vector3.ZERO, 80.0, 75.0, "idle", -1.0, "", 3, 80.0, 75.0, Vector3.ZERO, 0.0, false, 0.0, [], {}, 0.0, 0.0, 0, {}]]
	mission.correction = host_position - actor.global_position
	actor.wall_sliding = true
	actor.wall_grace = .9
	actor.jump_buffer = .9
	for i in 20:
		await physics_frame
		mission.reconcile_local_movement(1.0 / 60.0)
		if i == 3:
			check(actor.global_position.x > .58 and mission.correction.x < -2.5, "Blocked correction retains the unapplied movement")
	check(actor.global_position.is_equal_approx(host_position), "Guest recovers to the host side of a solid wall")
	check(not actor.wall_sliding and actor.wall_grace == 0.0 and actor.jump_buffer == 0.0, "Resync clears the old wall climb state")
	check(rig.global_position.is_equal_approx(rig.target_position()) and rig.target == actor, "Camera immediately frames the recovered guest")
	actor.global_position = Vector3(-3.0, 1.1, 0.0)
	mission.correction = Vector3(.40, 0, 0)
	mission.snapshot_age = .40
	await physics_frame
	mission.reconcile_local_movement(1.0 / 60.0)
	check(is_equal_approx(actor.global_position.x, -3.0), "Expired snapshots cannot drag the guest")
	mission.snapshot_age = .0
	for i in 35:
		await physics_frame
		mission.reconcile_local_movement(1.0 / 60.0)
	check(actor.global_position.x > -2.72 and actor.global_position.x < -2.58, "Small corrections remain smooth")
	actor.global_position = Vector3(12.0, 1.1, 0.0)
	mission.receive_operators(1, mission.targets, 1, [0, 0, 0.0, 4, 0])
	check(actor.global_position.is_equal_approx(host_position), "First snapshot after deploy or rejoin restores host position")
	actor.global_position = Vector3(12.0, 1.1, 0.0)
	mission.receive_operators(1, mission.targets, 2, [0, 0, 0.0, 500, 0])
	check(actor.global_position.is_equal_approx(host_position), "A missing input-history sample cannot leave the operator far from the host")
	actor.global_position.x = host_position.x + .5
	mission.receive_operators(1, mission.targets, 3, [0, 0, 0.0, 501, 1])
	check(actor.global_position.is_equal_approx(host_position) and rig.global_position.is_equal_approx(rig.target_position()), "A checkpoint relocation updates the operator and camera together")
	mission.free()
	peer.free()
	quit(failures)
