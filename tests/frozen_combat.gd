extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, description: String) -> void:
	print(("PASS " if ok else "FAIL ")+description)
	if not ok:
		failures += 1
func run() -> void:
	for act in [1,2]:
		var game = load("res://scenes/main.tscn").instantiate()
		game.profile.path = "user://frozen-combat-test.cfg"
		game.checkpoint_path = "user://frozen-combat-run.cfg"
		root.add_child(game)
		current_scene = game
		game.profile.manual_only = true
		game.sector = 3
		game.act = act
		game.start_game(false,3)
		game.set_physics_process(false)
		for actor in game.game_root.get_node("Actors").get_children():
			actor.set_physics_process(false)
		var boss = game.boss
		var rig = boss.frozen_rig
		check(rig!=null,"act %d uses the new frozen rig"%act)
		for clip in ["idle","walk","shoot","slash"]:
			check(rig.animation.has_animation(clip),"act %d has %s animation"%[act,clip])
		for clip in ["idle","walk","shoot","slash"]:
			rig.animation.play(clip)
			for i in 9:
				rig.animation.seek(rig.animation.get_animation(clip).length*float(i)/8,true)
				for side in ["Left","Right"]:
					var index: int = rig.skeleton.find_bone(side+"Foot")
					var foot: Vector3 = rig.skeleton.global_transform*rig.skeleton.get_bone_global_pose(index).origin
					check(foot.y>game.gate.global_position.y-.12 and foot.y<game.gate.global_position.y+.72,"act %d %s %s foot stays near arena floor"%[act,clip,side])
		var start: Vector3 = boss.global_position
		var intro = load("res://scripts/boss_intro.gd").new()
		game.add_child(intro)
		await intro.play(game.camera_rig,boss,game.gate.global_position.y,"FROZEN TEST",Color.CYAN,3,act,game.factory_hud,true)
		check(boss.global_position.is_equal_approx(start),"act %d cinematic lands at the arena floor"%act)
		check(not rig.cinematic and rig.clip=="idle","act %d cinematic restores idle"%act)
		check(is_equal_approx(game.factory_hud.boss_health,boss.health),"act %d health bar fills completely"%act)
		boss.active = true
		boss.target = game.player
		if act == 1:
			for attack in ["signature","volley","charge"]:
				boss.attack = attack
				boss.telegraph()
				boss.strike()
		else:
			boss.strike_x = boss.global_position.x-4
			for attack in ["ice_wall","shards","ice_burst","charge"]:
				boss.execute(attack)
		check(get_nodes_in_group("rift_projectile").any(func(shot): return shot.launch_profile>=0 and (shot.launch_profile>>3)==3),"act %d fires new ice projectiles"%act)
		rig.set_combat_pose(-1,0,"volley")
		await process_frame
		await process_frame
		check(rig.clip=="shoot","act %d plays attack animation"%act)
		var intent: Array = rig.snapshot().duplicate()
		rig.set_combat_pose(1,0,"")
		rig.apply_snapshot(intent)
		check(rig.snapshot()==intent,"act %d restores co-op animation intent"%act)
		game.queue_free()
		for frame in 4:
			await process_frame
	print("FROZEN COMBAT TEST failures=",failures)
	quit(failures)
