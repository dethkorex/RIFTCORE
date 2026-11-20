extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	failures+=int(not ok)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.profile.path="user://board-jump-test.cfg"
	game.checkpoint_path="user://board-jump-test-run.cfg"
	root.add_child(game)
	current_scene=game
	game.profile.manual_only=true
	game.sector=3
	game.act=2
	game.start_game(false,3)
	game.set_physics_process(false)
	var actor=game.player
	for body in game.game_root.get_node("Actors").get_children(): body.set_physics_process(false)
	actor.remote_input=true
	actor.remote_axis=Vector2.RIGHT
	var course=game.game_root.get_node("TERRAIN/RocketCourse")
	await physics_frame
	var peaks: Array[float]=[]
	for hold in [false,true]:
		course.mount(actor)
		actor.remote_pressed={"jump":true}
		actor.remote_held={"jump":true}
		var peak:=0.0
		var descending:=false
		var landed:=false
		var relaunched:=false
		for frame in 112:
			if frame>0: actor.remote_pressed.clear()
			if not hold and frame>7: actor.remote_held.clear()
			course.simulate(actor,1.0/60)
			var at: Vector3=course.to_local(actor.global_position)
			peak=maxf(peak,at.y-actor.standing_capsule.height*.5-course.HOVER_HEIGHT)
			descending=descending or actor.velocity.y<-.5
			if frame>30 and descending and not course.in_gap(at.x) and absf(at.y-actor.standing_capsule.height*.5-course.ground_height(at.x)-course.HOVER_HEIGHT)<.12:
				landed=true
			if landed and actor.velocity.y>2: relaunched=true
			await physics_frame
		peaks.append(peak)
		check(descending and landed,"%s Jump reaches an apex and lands"%("held" if hold else "released"))
		check(peak<1.35,"%s hop peaks at %.2f m above ride height"%["held" if hold else "released",peak])
		check(not relaunched,"landing cannot auto-jump while the button remains held")
	check(peaks[1]>peaks[0]+.15,"holding Jump extends the glide while releasing gives a shorter hop")
	course.mount(actor)
	actor.remote_pressed.clear()
	actor.remote_held={"jump":true}
	actor.global_position=course.to_global(Vector3(1870,course.ground_height(1870)-2,0))
	actor.velocity=Vector3(12,-3,0)
	var before: float=actor.global_position.y
	course.simulate(actor,1.0/60)
	check(actor.global_position.y<before,"rider below the track cannot snap upward through its collider")
	game.queue_free()
	current_scene=null
	await process_frame
	await process_frame
	print("HOVERBOARD JUMP RESULT failures=",failures)
	quit(int(failures>0))
