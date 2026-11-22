extends "res://tests/game_test_tree.gd"

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
	check(course.MINIMUM_SECONDS >= 120,"course takes at least two minutes at maximum speed")
	check(game.gate_relays.terminals[0].global_position.x > course.global_position.x + course.LENGTH,"relay A belongs to spillway finish")
	await physics_frame
	course.mount(actor)
	var mission = load("res://scripts/coop_mission.gd").new()
	mission.stage = game.game_root
	actor.rocket_course = null
	game.camera_rig.max_x = 600.0
	var state := [actor.global_position,Vector3.ZERO,actor.health,actor.energy,"idle",1.0,"",3,actor.max_health,actor.max_energy,Vector3(12,2,0),0.0,false,0.0,[],{},0.0,0.0,0,{},actor.experience,Vector4.ZERO,Vector3(1,12,0)]
	mission.apply_operator_state(actor,state,false)
	check(actor.rocket_course==course and game.camera_rig.max_x > course.global_position.x + course.LENGTH,"guest and rejoin snapshots restore course and camera bounds")
	check(actor.velocity==Vector3(12,2,0),"remote board receives the rider's velocity for slope and thruster visuals")
	actor.rocket_course=null
	var compact: Array=state.slice(0,11)+[state[16],state[17],state.slice(20,23)]
	mission.apply_operator_state(actor,compact,false)
	check(actor.rocket_course==course,"compact teammate snapshots retain rocket-board visuals")
	mission.free()
	actor.velocity = Vector3(12,0,0)
	var enemies := 0
	for enemy in game.game_root.get_node("Actors").get_children():
		if enemy.name.begins_with("Spillway"):
			enemies += 1
			check(enemy.health > 0.0 and enemy.lower_death_limit() < enemy.global_position.y,
				"%s spawns above its course-local pit floor" % enemy.name)
	check(enemies == 15, "fifteen patrols are placed on the spillway")
	check(course.ROUTE.HOP_GAPS.size() == 14 and course.ROUTE.BOOST_GAPS.size() == 7,
		"the route has short jumps and separate long boost gaps")
	var hop_positions: Array[float] = []
	for gap in course.ROUTE.HOP_GAPS:
		hop_positions.append(gap.x - 2.1)
	for rack in course.SPIKES:
		hop_positions.append(rack.x - rack.y * .5 - 4.4)
	hop_positions.sort()
	var next_hop := 0
	var glide_until := 0.0
	var max_speed := 0.0
	var hover_clearance := true
	var max_lift := 0.0
	var done := false
	for frame in 13000:
		var x: float = course.to_local(actor.global_position).x
		var lower := false
		for gate in course.GATES:
			lower = lower or (x > gate - 5.2 and x < gate + 3.0)
		actor.remote_held.clear()
		actor.remote_pressed.clear()
		if lower:
			actor.remote_held["crouch"] = true
		elif next_hop < hop_positions.size() and x >= hop_positions[next_hop]:
			actor.remote_pressed["jump"] = true
			glide_until = x + 20.0
			next_hop += 1
		if x < glide_until:
			actor.remote_held["jump"] = true
		for gap in course.ROUTE.BOOST_GAPS:
			if x > gap.x - 6.0 and x < gap.y + 1.0:
				actor.remote_held["jump"] = true
		course.simulate(actor,1.0/60)
		var at: Vector3 = course.to_local(actor.global_position)
		if is_instance_valid(actor.rocket_course):
			max_lift = maxf(max_lift,at.y-course.ground_height(at.x)-actor.standing_capsule.height*.5-course.HOVER_HEIGHT)
		max_speed = maxf(max_speed,actor.rocket_speed)
		if frame>20 and x<28:
			var feet: float = course.to_local(actor.global_position).y-actor.standing_capsule.height*.5
			hover_clearance = hover_clearance and feet-course.ground_height(x)>.40
		if not is_instance_valid(actor.rocket_course):
			done = actor.health > 0.0 and (game.gate_relays.active & 1) != 0 and actor.global_position.x < course.global_position.x
			print("course end frame=",frame," at=",actor.global_position," local x=",x," health=",actor.health," seconds=",actor.rocket_seconds)
			break
		if frame % 600 == 0:
			print("course frame=",frame," x=",x," y=",actor.global_position.y," hp=",actor.health)
		await physics_frame
	check(done,"authored course is completable with crouch and thrust controls")
	check(max_lift<=course.MAX_BOOST_HEIGHT+.02,"all boosts stay close to the track (peak %.2f m)"%max_lift)
	check(max_speed<=course.MAX_SPEED+.001,"downhill momentum respects speed cap")
	check(hover_clearance,"rider and board hover above the flat track")
	check(game.gate_relays.active & 1,"finishing the course activates relay A")
	check(actor.rocket_seconds >= 120.0,"full traversal exceeds two minutes")
	course.mount(actor)
	actor.remote_held.clear()
	actor.global_position = course.to_global(Vector3(course.GATES[0],course.ground_height(course.GATES[0])+10,0))
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
	actor.global_position = course.to_global(Vector3(course.GATES[0] - 1.0,course.ground_height(course.GATES[0]) + .85 + course.HOVER_HEIGHT,0))
	await physics_frame
	course.simulate(actor,1.0/60)
	check(not is_instance_valid(actor.rocket_course),"standing into a spike gate is lethal")
	print("FROZEN SECTOR TEST failures=",failures)
	game.queue_free()
	await process_frame
	finish(1 if failures else 0)
