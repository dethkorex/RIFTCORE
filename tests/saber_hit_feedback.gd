extends SceneTree

var failures := 0
var hits: Array[bool] = []
var reports := 0

class HostLink extends Node:
	func get_host() -> int: return 1
	func get_sender_id() -> int: return 1

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	failures += int(not condition)

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 0, 6)
	var audio := root.get_node("RiftAudio")
	audio.child_entered_tree.connect(func(voice):
		if voice is AudioStreamPlayer3D and voice.stream.resource_path.ends_with("/enemy_damage.wav"):
			reports += 1
	)
	var actor = load("res://scenes/actors/riftcore_player.tscn").instantiate()
	stage.add_child(actor)
	actor.set_physics_process(false)
	actor.remote_input = true
	actor.switch_combat_mode()
	var enemy = load("res://scripts/enemy.gd").new()
	enemy.variant = 0
	enemy.mission_enemy = true
	enemy.detachment_sector = 1
	enemy.add_to_group("damageable_enemies")
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	enemy.max_health = 500
	enemy.health = enemy.max_health
	enemy.position.x = -1.25
	enemy.enemy_damaged.connect(func(fatal: bool): hits.append(fatal))
	var piece = enemy.robot.find_children("*", "MeshInstance3D", true, false)[0]
	var previous_overlay := StandardMaterial3D.new()
	piece.material_overlay = previous_overlay
	var hp: float = enemy.health
	actor.remote_pressed[&"shoot"] = true
	actor.remote_held[&"shoot"] = true
	actor.update_melee(1.0 / 60)
	actor.remote_pressed.clear()
	actor.remote_held.clear()
	actor.remote_released[&"shoot"] = true
	actor.update_melee(1.0 / 60)
	actor.remote_released.clear()
	check(actor.combo_step == 1 and actor.melee_lock > 0, "Tap starts the opening cut")
	actor.remote_axis.x = -1
	for i in 9:
		actor.simulate_movement(1.0 / 60)
	check(hits == [false] and reports == 1 and enemy.health < hp, "Reversal before contact strikes behind the starting direction, exactly once")
	check(piece.material_overlay != previous_overlay and piece.material_overlay.albedo_color.r > .95, "Damage starts a red flash synchronously")
	check(actor.velocity.x < 0 and not actor.grounded(), "Airborne saber cut responds to left movement")
	actor.remote_axis.x = 1
	for i in 5:
		actor.simulate_movement(1.0 / 60)
	check(hits.size() == 1 and actor.combo_facing == 1, "Turn during recovery leaves the resolved hit alone")
	enemy.invulnerable_time = 1
	enemy.take_damage(3)
	enemy.invulnerable_time = 0
	enemy.take_damage(0)
	check(reports == 1 and hits.size() == 1, "Invulnerability and zero damage stay silent")
	enemy.take_damage(1)
	enemy.burn_power = 1
	enemy.apply_burn_tick()
	check(hits.size() == 3 and reports == 3, "Rapid damage and a burn tick each restart one pulse and sound")
	for i in 12:
		await process_frame
	check(piece.material_overlay == previous_overlay, "Original material overlay restored")
	# Keep tapping across the end of a combo, including the finisher recovery.
	enemy.position.x = 15
	actor.perform_melee(1)
	for next in [2, 3, 1]:
		actor.remote_pressed[&"shoot"] = true
		actor.update_melee(1.0 / 60)
		actor.remote_pressed.clear()
		var prior: int = actor.combo_step
		for frame in 28:
			actor.update_melee(1.0 / 60)
			if actor.combo_step != prior:
				break
		check(actor.combo_step == next, "Buffered tap chains to cut %d" % next)
	actor.position = Vector3.ZERO
	actor.switch_combat_mode()
	actor.switch_combat_mode()
	actor.remote_pressed[&"shoot"] = true
	actor.remote_held[&"shoot"] = true
	for frame in 36:
		actor.update_melee(1.0 / 60)
		actor.remote_pressed.clear()
	actor.remote_held.clear()
	actor.update_melee(1.0 / 60)
	actor.facing = -1
	for frame in 20:
		actor.update_melee(1.0 / 60)
	var wave = get_first_node_in_group("rift_projectile")
	check(wave != null and wave.direction.x < 0, "Charged release follows an aerial turn")
	enemy.position.x = -1
	enemy.take_damage(1000)
	check(hits.back() and reports == 4, "Lethal damage produces a final pulse and sound")
	for frame in 18:
		await process_frame
	var actors := Node3D.new()
	stage.add_child(actors)
	var boss = load("res://scenes/levels/kiln_warden.tscn").instantiate()
	actors.add_child(boss)
	boss.active = true
	boss.set_physics_process(false)
	boss.exposed = false
	boss.take_damage(9)
	check(boss.damage_flash == null and reports == 4, "Closed Kiln Warden armor suppresses damage feedback")
	boss.exposed = true
	boss.take_damage(9)
	check(boss.damage_flash != null and reports == 5, "Exposed Kiln Warden flashes on actual damage")
	var mission = load("res://scripts/coop_mission.gd").new()
	mission.peer = HostLink.new()
	mission.host = false
	mission.boss = boss
	mission.operators.append(actor)
	var buster = audio.voices[&"buster"]
	buster.stop()
	mission.receive_weapon_sound(mission.act + 1, 0, "buster", actor.global_position)
	check(not buster.playing, "A stale shot sound from another act is ignored")
	mission.receive_weapon_sound(mission.act, 0, "buster", actor.global_position)
	check(buster.playing, "Guest hears its own confirmed buster through the SFX bus")
	var remaining: float = boss.health
	mission.receive_enemy_hit(mission.act + 1, -1, false)
	mission.receive_enemy_hit(mission.act, -1, false)
	check(reports == 6 and boss.health == remaining, "Guest presents the host hit once without applying damage again")
	mission.peer.free()
	mission.free()
	for gate_name in ["Gate", "ExitBarrier"]:
		var marker := Node3D.new()
		marker.name = gate_name
		stage.add_child(marker)
	var cryo = load("res://scenes/levels/cryo_warden.tscn").instantiate()
	actors.add_child(cryo)
	cryo.active = true
	cryo.set_physics_process(false)
	cryo.take_damage(cryo.health + 1)
	check(reports == 7 and cryo.health == 0, "Skinned Cryo Warden presents its killing hit")
	actor.melee_lock = 0
	actor.remote_held[&"guard"] = true
	actor.simulate_movement(.016)
	check(actor.guarding and actor.guard_stage == 0 and actor.guard_bubble.visible, "Holding block raises a blue shield")
	actor.update_guard(12, true)
	check(actor.guarding and actor.guard_stage == 0, "Holding the shield does not spend hits")
	var front: Vector3 = actor.global_position + Vector3.RIGHT * actor.facing
	var back: Vector3 = actor.global_position - Vector3.RIGHT * actor.facing
	check(not actor.blocks_hit(back) and actor.guard_stage == 0, "Rear attacks do not spend shield hits")
	check(actor.blocks_hit(front) and actor.guard_stage == 1, "First block turns the shield yellow")
	actor.update_guard(2, false)
	actor.update_guard(.016, true)
	check(actor.guarding and actor.guard_stage == 1, "Lowering the shield preserves its damage")
	check(actor.blocks_hit(front) and actor.guard_stage == 2, "Second block turns the shield red")
	check(actor.blocks_hit(front) and not actor.guarding and not actor.guard_bubble.visible and actor.guard_cooldown == 10, "Third hit is blocked and breaks the shield")
	actor.switch_combat_mode()
	actor.switch_combat_mode()
	actor.update_guard(9.99, true)
	check(not actor.guarding and not actor.blocks_hit(front), "Mode swapping and holding Block cannot bypass recovery")
	actor.update_guard(.01, true)
	check(actor.guarding and actor.guard_stage == 0, "Shield returns blue after ten seconds")
	for voice in audio.get_children():
		if voice is AudioStreamPlayer or voice is AudioStreamPlayer3D:
			voice.stop()
	stage.queue_free()
	for frame in 8:
		await process_frame
	quit(failures)
