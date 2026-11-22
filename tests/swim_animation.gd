extends "res://tests/game_test_tree.gd"
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	failures+=int(not ok)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.profile.path="user://swim-animation-profile.cfg"
	game.checkpoint_path="user://swim-animation-run.cfg"
	root.add_child(game)
	current_scene=game
	game.profile.manual_only=true
	game.sector=4
	game.act=2
	game.start_game(false,4)
	game.set_physics_process(false)
	for body in game.game_root.get_node("Actors").get_children(): body.set_physics_process(false)
	var actor=game.player
	actor.global_position=Vector3(136,-4,0)
	actor.remote_input=true
	for direction in [1.0,-1.0]:
		actor.facing=direction
		actor.velocity=Vector3(direction*5.8,0,0)
		for frame in 55:
			actor.update_character_visuals(direction)
			await process_frame
		check(actor.model_root.basis.y.dot(Vector3.RIGHT*direction)>.85,"horizontal swimmer points toward travel direction %d"%direction)
		check((actor.model_root.transform*Vector3(0,.85,0)).length()<.01,"swimming rotates about the torso instead of the feet")
		actor.fire_lock=.3
		actor.update_character_visuals(direction)
		actor.animation_player.advance(0)
		actor.buster_pose._process_modification_with_delta(1.0/60)
		var skeleton=actor.muzzle_skeleton
		var forearm: Transform3D=skeleton.get_bone_global_pose(actor.muzzle_bone)
		var barrel: Vector3=(skeleton.global_basis*(forearm.basis*actor.muzzle_offset)).normalized()
		check(barrel.dot(Vector3.RIGHT*direction)>.95,"swimming cannon aims horizontally while the body is prone")
		actor.fire_lock=0
	var crawl
	for modifier in actor.muzzle_skeleton.get_children():
		if modifier.get_script() and modifier.get_script().resource_path=="res://scripts/swim_pose.gd": crawl=modifier
	crawl.set_process(false)
	crawl.propulsion=1.0
	var reaches: Array[float]=[]
	for phase in [0.0,PI]:
		actor.animation_player.advance(0)
		crawl.cycle=phase
		crawl._process_modification_with_delta(1.0/60)
		var skeleton=actor.muzzle_skeleton
		var left: Vector3=skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_LeftHand")).origin
		var right: Vector3=skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_RightHand")).origin
		reaches.append(left.y-right.y)
	check(reaches[0]>.25 and reaches[1]<-.25,"front-crawl arms alternate reach and recovery instead of moving together")
	crawl.set_process(true)
	actor.velocity=Vector3(0,4.5,0)
	for frame in 55:
		actor.update_character_visuals(0)
		await process_frame
	check(actor.model_root.basis.y.y>.9,"ascending swimmer turns upward")
	actor.velocity=Vector3(0,-4.5,0)
	for frame in 55:
		actor.update_character_visuals(0)
		await process_frame
	check(actor.model_root.basis.y.y<-.75,"diving swimmer points downward")
	actor.velocity=Vector3.ZERO
	for frame in 55:
		actor.update_character_visuals(0)
		await process_frame
	check(actor.model_root.basis.y.y>.95,"stationary swimmer returns to upright treading water")
	actor.global_position=Vector3(183,-2.55,0)
	for frame in 60:
		actor.update_character_visuals(0)
		await process_frame
	check(absf(actor.model_root.rotation.x)<.01 and actor.model_root.position.distance_to(Vector3(0,-.85,0))<.01,"leaving water restores the dry standing pivot")
	current_scene=null
	game.queue_free()
	await process_frame
	await process_frame
	print("SWIM ANIMATION RESULT failures=",failures)
	finish(int(failures>0))
