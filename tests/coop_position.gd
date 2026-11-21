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
	var support:=StaticBody3D.new()
	var deck:=CollisionShape3D.new()
	var deck_shape:=BoxShape3D.new()
	deck_shape.size=Vector3(20,1,6)
	deck.shape=deck_shape
	support.add_child(deck)
	root.add_child(support)
	support.position=Vector3(-10,-.5,0)
	actor.global_position=Vector3(-10,.9,0)
	await physics_frame
	actor.velocity=Vector3.DOWN*3
	actor.move_and_slide()
	actor.move_and_slide()
	actor.velocity=Vector3.ZERO
	mission.targets[0][0]=Vector3(-9,actor.global_position.y,0)
	mission.targets[0][10]=Vector3.ZERO
	mission.input_positions[502]=Vector3(-8,actor.global_position.y,0)
	mission.last_sent_axis=Vector2.ZERO
	mission.receive_operators(1,mission.targets,4,[0,0,0.0,502,1])
	check(actor.grounded() and mission.correction.x>0,"A resting guest corrects toward the server despite an older prediction sample on the opposite side")
	var jump: int = 1 << mission.INPUTS.find(&"jump")
	var shoot: int = 1 << mission.INPUTS.find(&"shoot")
	var remote := {}
	mission.apply_input_edges(actor, remote, jump, 0, 104)
	mission.apply_input_edges(actor, remote, shoot, 0, 102)
	check(actor.remote_pressed.has(&"jump") and actor.remote_pressed.has(&"shoot"), "An older shot edge survives a newer jump packet")
	actor.remote_pressed.clear()
	mission.apply_input_edges(actor, remote, shoot, 0, 102)
	check(actor.remote_pressed.is_empty(), "The duplicate shot edge from the reliable copy cannot fire twice")
	mission.input_times[503] = Time.get_ticks_usec() - 170000
	mission.update_snapshot_lead(503)
	check(mission.snapshot_lead > mission.TICK * 0.5 and mission.snapshot_lead <= mission.MAX_SNAPSHOT_LEAD, "Interpolation lead adapts to a delayed acknowledgment")
	var patrol := PackedFloat32Array([561.023, -10.479, -0.01, 1.57, 0.2, 81.5])
	var packed = mission.pack_security(patrol)
	check(packed is PackedByteArray and packed.size() == patrol.size() * 2, "The compressed patrol payload uses half as many bytes")
	check(absf(float(packed.decode_s16(0)) / 32.0 - patrol[0]) < 0.016, "Patrol positions retain centimeter-scale precision")
	patrol[0] = 1300.0
	check(mission.pack_security(patrol) is PackedFloat32Array, "Large world coordinates fall back to full precision")
	var partner = (load("res://scenes/actors/riftcore_player.tscn") as PackedScene).instantiate()
	root.add_child(partner)
	partner.set_physics_process(false)
	mission.operators.append(partner)
	mission.roster = [11, 12]
	actor.set_operator_appearance("", "field:1")
	mission.receive_operator_appearance(1, ["", "field:2"])
	mission.receive_operator_appearance(0, ["", "field:2"])
	check(actor.armor_finish == "field:1" and partner.armor_finish == "field:2", "Replicated appearance applies to the addressed partner and preserves the local finish")
	var partner_state: Array = mission.targets[0].duplicate()
	partner_state.append_array([0, Vector4.ZERO, Vector3.ZERO, "", 27 << mission.BUSTER_PITCH_SHIFT])
	mission.apply_operator_state(partner, partner_state, false)
	var pitch := deg_to_rad(27.0)
	check(partner.buster_pose.direction_override.is_equal_approx(Vector3(-cos(pitch), sin(pitch), 0.0)), "Co-op keeps a partner's shallow left aim")
	partner_state[24] = 4 << mission.LEGACY_BUSTER_AIM_SHIFT
	mission.apply_operator_state(partner, partner_state, false)
	check(partner.buster_pose.direction_override.is_zero_approx(), "A legacy downward pose cannot aim the partner's cannon below level")
	mission.free()
	peer.free()
	quit(failures)
