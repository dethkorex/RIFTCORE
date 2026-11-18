extends SceneTree

var failures := 0
func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	print(("PASS " if ok else "FAIL ")+description)
	if not ok:
		failures += 1

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile.path = "user://frozen-test.cfg"
	game.checkpoint_path = "user://frozen-test-run.cfg"
	root.add_child(game)
	current_scene = game
	game.profile.manual_only = true
	game.sector = 3
	game.act = 2
	game.start_game(false,3)
	game.set_physics_process(false)
	var actor = game.player
	for object in game.game_root.get_node("Actors").get_children():
		object.set_physics_process(false)
	actor.remote_input = true
	actor.remote_axis = Vector2(1,0)
	var course = game.game_root.get_node("TERRAIN/RocketCourse")
	check(course.MINIMUM_SECONDS >= 90,"course takes at least 90 seconds at maximum speed")
	check(game.gate_relays.terminals[0].global_position.x>2800,"relay A belongs to spillway finish")
	await physics_frame
	course.mount(actor)
	var mission = load("res://scripts/coop_mission.gd").new()
	mission.stage = game.game_root
	actor.rocket_course = null
	game.camera_rig.max_x = 600.0
	var state := [actor.global_position,Vector3.ZERO,actor.health,actor.energy,"idle",1.0,"",3,actor.max_health,actor.max_energy,Vector3(12,2,0),0.0,false,0.0,[],{},0.0,0.0,0,{},actor.experience,Vector4.ZERO,Vector3(1,12,0)]
	mission.apply_operator_state(actor,state,false)
	check(actor.rocket_course==course and game.camera_rig.max_x>2800,"guest and rejoin snapshots restore course and camera bounds")
	check(actor.velocity==Vector3(12,2,0),"remote board receives the rider's velocity for slope and thruster visuals")
	mission.free()
	actor.velocity = Vector3(12,0,0)
	var max_speed := 0.0
	var hover_clearance := true
	var done := false
	for frame in 13000:
		var x: float = course.to_local(actor.global_position).x
		var lower := false
		for gate in course.GATES:
			lower = lower or (x>gate-11 and x<gate+4)
		actor.remote_held.clear()
		if lower:
			actor.remote_held["crouch"] = true
		for i in course.PADS.size():
			if x > course.PADS[i]-2 and x < course.GAPS[i].y+2:
				actor.remote_held["jump"] = true
		course.simulate(actor,1.0/60)
		max_speed = maxf(max_speed,actor.rocket_speed)
		if frame>20 and x<28:
			var feet: float = course.to_local(actor.global_position).y-actor.standing_capsule.height*.5
			hover_clearance = hover_clearance and feet-course.ground_height(x)>.40
		if not is_instance_valid(actor.rocket_course):
			done = actor.health>0 and actor.global_position.x<800
			print("course end frame=",frame," at=",actor.global_position," health=",actor.health," seconds=",actor.rocket_seconds)
			break
		if frame % 600 == 0:
			print("course frame=",frame," x=",x," y=",actor.global_position.y," hp=",actor.health)
		await physics_frame
	check(done,"authored course is completable with crouch and thrust controls")
	check(max_speed<=course.MAX_SPEED+.001,"downhill momentum respects speed cap")
	check(hover_clearance,"rider and board hover above the flat track")
	check(game.gate_relays.active & 1,"finishing the course activates relay A")
	check(actor.rocket_seconds>=90,"full traversal exceeds 90 seconds")
	course.mount(actor)
	actor.remote_held.clear()
	actor.global_position = course.to_global(Vector3(155,course.ground_height(155)+10,0))
	course.simulate(actor,1.0/60)
	check(actor.health>0,"flying clear above a gate does not hit an invisible spike volume")
	actor.global_position = course.to_global(Vector3(course.LENGTH,course.ground_height(course.LENGTH)+6,0))
	actor.velocity = Vector3(12,-2,0)
	course.simulate(actor,1.0/60)
	check(is_instance_valid(actor.rocket_course),"rider must land at the exit before returning to the main route")
	actor.global_position = course.to_global(Vector3(course.LENGTH,course.ground_height(course.LENGTH)+.85+course.HOVER_HEIGHT,0))
	actor.velocity = Vector3.ZERO
	course.simulate(actor,1.0/60)
	check(not is_instance_valid(actor.rocket_course),"landing at exit completes the course")
	actor.health = actor.max_health
	course.mount(actor)
	actor.remote_held.clear()
	actor.set_crouch(false)
	actor.global_position = course.to_global(Vector3(154,course.ground_height(155)+.85+course.HOVER_HEIGHT,0))
	await physics_frame
	course.simulate(actor,1.0/60)
	check(not is_instance_valid(actor.rocket_course),"standing into a spike gate is lethal")
	print("FROZEN SECTOR TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
