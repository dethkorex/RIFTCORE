extends "res://tests/game_test_tree.gd"

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(passed: bool, message: String) -> void:
	print("PASS " if passed else "FAIL ", message)
	failures += int(not passed)

func wait_ticks(amount: int) -> void:
	for index in amount:
		await physics_frame

func run() -> void:
	for act in [1, 2]:
		var suffix := "" if act == 1 else "_act_2"
		var stage := (load("res://scenes/levels/machine_jungle%s.tscn" % suffix) as PackedScene).instantiate()
		root.add_child(stage)
		current_scene = stage
		var room := stage.get_node("TERRAIN/Room02_Switchback" if act == 1 else "TERRAIN/Room05_Switchback")
		var merge := room.get_node("CompactMerge") as StaticBody3D
		var actor = stage.get_node("Actors/RiftcoreMecha")
		actor.remote_input = true
		actor.invulnerable_time = 60.0
		for enemy in get_nodes_in_group("level_enemies"):
			enemy.set_physics_process(false)
			enemy.collision_layer = 0
		actor.global_position = merge.global_position + Vector3.UP * 0.87
		await wait_ticks(6)
		check(actor.grounded(), "Act %d lands on the compact deck" % act)
		actor.remote_held[&"crouch"] = true
		actor.remote_pressed[&"dash"] = true
		await wait_ticks(7)
		actor.remote_held.clear()
		check(actor.global_position.y < merge.global_position.y + .4, "Act %d drops through the compact deck" % act)
		actor.reset_predicted_position(merge.global_position + Vector3.UP * 0.87, Vector3.ZERO, 1.0)
		actor.remote_axis.x = 1.0
		var wall := room.get_node("DropBulkhead") as StaticBody3D
		var crossed := false
		for tick in 42:
			await physics_frame
			if actor.global_position.x > wall.global_position.x + .65:
				crossed = true
				break
		if not crossed:
			print("Stalled at ", actor.global_position)
			for index in actor.get_slide_collision_count():
				print(actor.get_slide_collision(index).get_collider().get_path())
		check(crossed, "Act %d can pass the bulkhead from the upper approach" % act)
		var pod_zone = room.get_node("MergeField" if act == 1 else "SumpField")
		actor.remote_axis.x = 0
		actor.set_physics_process(false)
		var height := Vector3.UP * .58
		var origin: Vector3 = pod_zone.pod.global_position + height - Vector3.RIGHT * 2.0
		actor.launch_buster(origin, Vector3.RIGHT, true, false, 38)
		await wait_ticks(16)
		check(pod_zone.pod.health == 0.0 and not pod_zone.is_physics_processing(), "Act %d buster can hit and disable the visible spore pod" % act)
		check(pod_zone.damage_volume.shape.size.x <= 1.75, "Act %d spore damage stays near the plant" % act)
		stage.queue_free()
		await wait_ticks(4)
	finish(failures)
