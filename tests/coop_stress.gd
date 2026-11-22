extends "res://tests/game_test_tree.gd"

var game
var lobby
var peer
var mission
var link
var host := false
var count := 2
var slot := 0
var client := 0
var failures := 0
var suite := "network"
var seen := {}
var start_time := 0
var checked_messages := false
var barrier_sequence := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, caption: String) -> void:
	print(("STRESS PASS " if ok else "STRESS FAIL "),OS.get_name()," client=",client," ",caption)
	if not ok:
		failures += 1

func until(test: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if test.call(): return true
		await create_timer(.04).timeout
	return test.call()

func barrier(name: String, timeout := 30.0) -> bool:
	barrier_sequence += 1
	var phase := barrier_sequence
	peer.lobby_set_data("stress_"+str(client),phase)
	var ready := await until(func():
		for index in count:
			var reached = peer.lobby_get_data("stress_"+str(index),0)
			if not (reached is int or reached is float) or reached < phase: return false
		return true
	,timeout)
	check(ready,"barrier "+name)
	return ready

func run() -> void:
	start_time = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	host = args[1]=="host"
	count = int(args[2])
	client = int(args[3])
	suite = args[4]
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.path="user://stress-profile.cfg"
	game.checkpoint_path="user://stress-operator.cfg"
	root.add_child(game)
	current_scene=game
	# Physical controllers connected to the QA machine must not overwrite the
	# synthetic held actions of background clients. This changes this test's
	# in-memory InputMap only; player bindings/settings files are untouched.
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion or event is InputEventJoypadButton:
				InputMap.action_erase_event(action,event)
	lobby=root.get_node("RiftRelay")
	game.profile.operator_name="Stress %d"%client
	game.profile.unlocked_sector=10
	lobby.unlocked_sector=10
	game.open_home_hub()
	game.home_hub.station_requested.emit("Social")
	game.menu.show_page("Party")
	if host: game.menu.relay_host.pressed.emit()
	else:
		game.menu.relay_code.text=args[5]
		game.menu.relay_join.pressed.emit()
	if not await until(func(): return not lobby.connected_room.is_empty(),40):
		check(false,"join test room")
		finish(1)
		return
	peer=lobby.relay
	if host: print("STRESS ROOM ",lobby.connected_room)
	if not await until(func(): return lobby.room_size==count,70):
		check(false,"all participants joined")
		finish(1)
		return
	check(true,"joined %d-player room"%count)
	lobby.party_chat_changed.connect(capture_chat)
	await barrier("chat-ready")
	for i in 16:
		check(lobby.send_party_message("STRESS-%d-%02d"%[client,i]),"party send %d"%i)
		await create_timer(.60).timeout
	await barrier("chat-sent")
	await until(func(): return seen.size()>=count*16,10)
	check(seen.size()==count*16,"all %d party messages received exactly once"%(count*16))
	if failures>0:
		finish(1)
		return
	for sector in ([1] if suite=="lava" else ([4] if suite=="abyssal" else ([1,2,3] if suite=="network" else range(1,11)))):
		if not await barrier("deploy-%d"%sector): break
		game.menu.leave_page()
		if host: lobby.deploy(sector)
		if not await until(func(): return is_instance_valid(game.coop_mission),20):
			check(false,"deployment")
			break
		mission=game.coop_mission
		slot=mission.local_index
		link=load("res://tests/coop_test_link.gd").new()
		link.real_peer=peer
		root.add_child(link)
		mission.peer=link
		await until(func(): return not mission.changing_act and mission.operators[slot].is_physics_processing(),10)
		if suite=="network" and sector==1:
			await network_cases()
			if failures>0: break
		for act in [1,2]:
			if not await until(func(): return mission.act==act and not mission.changing_act,25):
				check(false,"act %d loaded"%act)
				break
			if not await barrier("sector-%d-act-%d"%[sector,act]): break
			if sector==4 and act==2 and suite=="abyssal":
				await swim_cases()
				await pressure_cases()
			if sector==1 and act==2 and suite=="lava":
				await lava_cases()
			if sector==3 and act==2:
				if host:
					var course=mission.stage.get_node("TERRAIN/RocketCourse")
					for rider in mission.operators: course.mount(rider)
					mission.broadcast_state(true)
				check(await until(func(): return mission.operators.all(func(rider): return is_instance_valid(rider.rocket_course)),5),"all party members see every rider's rocket board")
				await barrier("boards-synced")
			if host: await clear_boss(sector,act)
			if act==1:
				check(await until(func(): return mission.act==2 and not mission.changing_act,35),"sector %d act transition"%sector)
			else:
				check(await until(func(): return is_instance_valid(game.home_hub) and not lobby.mission_active,55),"sector %d extraction and party preserved"%sector)
		link.queue_free()
		if failures>0: break
	if failures==0 and suite=="network":
		await barrier("wipe-deploy")
		if host: lobby.deploy(1)
		if await until(func(): return is_instance_valid(game.coop_mission),20):
			mission=game.coop_mission
			if host:
				await create_timer(2).timeout
				for actor in mission.operators:
					actor.lives=0
					actor.health=0
				mission.check_campaign_progress()
			check(await until(func(): return is_instance_valid(game.home_hub) and not lobby.mission_active,20),"whole-party wipe returns everyone to hub")
			check(lobby.room_size==count and not lobby.connected_room.is_empty(),"wipe preserves lobby")
			check(game.profile.operator_level==1,"wipe resets operator level")
	await barrier("finished",10)
	print("STRESS RESULT ",OS.get_name()," client=",client," players=",count," suite=",suite," failures=",failures," seconds=",(Time.get_ticks_msec()-start_time)/1000)
	lobby.leave()
	await create_timer(.3).timeout
	finish(1 if failures else 0)

func capture_chat() -> void:
	for message in lobby.party_messages:
		if String(message.body).begins_with("STRESS-"):
			seen[message.body]=true

func lava_cases() -> void:
	var lava=mission.lava_escape
	check(is_instance_valid(lava),"native co-op rising lava is installed")
	if host:
		for actor in mission.operators:
			actor.global_position=mission.respawn_point()
			actor.velocity=Vector3.ZERO
			mission.mark_position_reset(actor)
		mission.broadcast_state(true)
	await barrier("lava-ready")
	for victim in count:
		var actor=mission.operators[victim]
		var starting_lives=actor.lives
		await barrier("lava-contact-%d"%victim)
		if host:
			actor.invulnerable_time=1000
			actor.velocity=Vector3.ZERO
			actor.global_position=lava.to_global(Vector3(12,4+actor.standing_capsule.height*.5,0))
			lava.surface=5
			lava.phase=lava.Phase.RISING
			mission.mark_position_reset(actor)
			mission.broadcast_state(true)
		check(await until(func(): return actor.lives==starting_lives-1,8),"rising lava deducts one life for player %d on every client"%victim)
		check(await until(func(): return actor.health>0 and actor.lives==starting_lives-1 and not actor.has_meta("coop_down"),8),"player %d respawns alive at the squad checkpoint"%victim)
		check(actor.global_position.distance_to(mission.respawn_point())<2,"lava respawn location stays synchronized for player %d"%victim)
		await barrier("lava-respawned-%d"%victim)
	check(not lobby.connected_room.is_empty() and lobby.room_size==count,"lava deaths preserve the co-op party")

func build_arena() -> void:
	var terrain=mission.stage.get_node("TERRAIN")
	if terrain.has_node("StressFloor"): return
	var floor_body:=StaticBody3D.new()
	floor_body.name="StressFloor"
	floor_body.position=Vector3(-110,-.4,0)
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(100,.8,8)
	collision.shape=shape
	floor_body.add_child(collision)
	terrain.add_child(floor_body)
	mission.camera.min_x=-160

func network_cases() -> void:
	build_arena()
	await barrier("arena-ready")
	if host:
		for i in count:
			var actor=mission.operators[i]
			actor.global_position=Vector3(-130+i*4,.9,0)
			actor.velocity=Vector3.ZERO
			actor.invulnerable_time=1000
			mission.mark_position_reset(actor)
		mission.broadcast_state(true)
	var actor=mission.operators[slot]
	await until(func(): return actor.global_position.x<0 and actor.grounded(),10)
	for setting in [[0,0,0],[70,65,10],[130,80,20]]:
		link.latency_ms=setting[0]
		link.jitter_ms=setting[1]
		link.loss_percent=setting[2]
		await barrier("network-%d"%setting[0])
		for i in 25:
			Input.action_press("move_right" if i%2==0 else "move_left")
			Input.action_release("move_left" if i%2==0 else "move_right")
			if i%6==0: Input.action_press("jump")
			Input.action_press("shoot")
			await create_timer(.12).timeout
			Input.action_release("jump")
			Input.action_release("shoot")
		Input.action_release("move_left")
		Input.action_release("move_right")
		await create_timer(2.0).timeout
		check(actor.health>0 and absf(actor.velocity.x)<.2,"input releases settle under delay/loss %s"%[setting])
		if not host:
			var state: Array=mission.targets[slot]
			print("STRESS POSITION client=",client," local=",actor.global_position," server=",state[0]," correction=",mission.correction," age=",mission.snapshot_age," ack=",mission.acknowledged_input)
			check(actor.global_position.distance_to(state[0])<2.0,"guest converges to own authoritative position")
		check(lobby.room_size==count and not lobby.recovery.active(),"party remains connected during impairment")
	link.latency_ms=0
	link.jitter_ms=0
	link.loss_percent=0
	await create_timer(.6).timeout
	await barrier("rejoin-ready")
	for target in range(1,count):
		var before_xp: int=actor.experience
		var before_lives: int=actor.lives
		var before_hp: float=actor.health
		if slot==target:
			peer._connection_controller.reset_multiplayer(true)
		check(await until(func(): return lobby.recovery.active(),10),"connection interruption enters recovery")
		if slot==target:
			lobby.rejoin_party()
		check(await until(func(): return not lobby.recovery.active() and lobby.room_size==count,45),"party resumes after slot %d reconnect"%target)
		await create_timer(2).timeout
		check(actor.experience==before_xp and actor.lives==before_lives and is_equal_approx(actor.health,before_hp),"rejoin preserves XP, HP and lives")
		await barrier("rejoined-%d"%target)
	if host:
		var hp: float=mission.operators[1].health
		var lives: int=mission.operators[1].lives
		mission.operators[0].die_in_pit()
		await create_timer(2.5).timeout
		check(mission.operators[0].lives==2 and mission.operators[1].lives==lives and mission.operators[1].health==hp,"one death uses only that operator's life")
	await barrier("death-tested")
	await checkpoint_and_revive_cases()
	print("STRESS LINK sent=",link.sent," dropped=",link.dropped," delivered=",link.delivered)

func checkpoint_and_revive_cases() -> void:
	var beacon
	for path in mission.CHECKPOINT_PATHS:
		beacon=mission.stage.get_node_or_null(path)
		if beacon: break
	check(is_instance_valid(beacon),"stage has a checkpoint to test")
	if not is_instance_valid(beacon): return
	var notices: int=mission.checkpoint_notices
	await barrier("checkpoint-ready")
	if host:
		var scout=mission.operators[1]
		scout.global_position=beacon.global_position+Vector3.UP*.9
		scout.velocity=Vector3.ZERO
		mission.mark_position_reset(scout)
		mission.broadcast_state(true)
	check(await until(func(): return mission.checkpoint_notices==notices+1,8),"one scout triggers a checkpoint notification for this squad member")
	check(mission.checkpoint.distance_to(beacon.global_position+Vector3.UP*.88)<.1,"all members receive the same squad respawn point")
	await barrier("checkpoint-shared")
	if host:
		for i in count:
			mission.operators[i].global_position=Vector3(-130+i*1.6,.9,0)
			mission.operators[i].velocity=Vector3.ZERO
			mission.mark_position_reset(mission.operators[i])
		mission.broadcast_state(true)
	await create_timer(1).timeout
	for target in [1,0]:
		var rescuer := 1 if target==0 else 0
		await barrier("corpse-%d-ready"%target)
		if host:
			var victim=mission.operators[target]
			victim.lives=1
			victim.global_position=Vector3(100,-100,0)
			victim.die_in_pit()
			mission.broadcast_state(true)
		check(await until(func(): return mission.operators[target].health<=0 and mission.operators[target].lives==0,5),"last-life fall synchronizes a downed body")
		check(mission.operators[target].visible and mission.operators[target].global_position.x<0 and mission.operators[target].global_position.y>0,"pit corpse is visible on the last safe platform")
		await barrier("corpse-%d-visible"%target)
		if slot==rescuer: Input.action_press("field_interact")
		check(await until(func(): return mission.reboot_left>0,5),"held interact starts a revive on both clients")
		await create_timer(1).timeout
		mission.update_revive_meter()
		if slot in [target,rescuer]: check(mission.revive_meter.visible and mission.revive_meter.value>0,"revive progress is visible to the rescuer and downed player")
		if slot==rescuer: Input.action_release("field_interact")
		check(await until(func(): return mission.reboot_left<=0,4) and mission.operators[target].health<=0,"releasing the button cancels the networked revive")
		await barrier("revive-%d-cancelled"%target)
		if slot==rescuer: Input.action_press("field_interact")
		check(await until(func(): return mission.operators[target].health>0,8),"a complete hold revives the teammate")
		if slot==rescuer: Input.action_release("field_interact")
		var victim=mission.operators[target]
		check(is_equal_approx(victim.health,victim.max_health) and victim.lives==0,"network revival gives full HP and zero spare lives")
		await barrier("revive-%d-complete"%target)
	await create_timer(.4).timeout
	await barrier("host-recovery-ready")
	if host: peer._connection_controller.reset_multiplayer(true)
	check(await until(func(): return lobby.recovery.active(),10),"host connection interruption pauses the squad")
	if host: lobby.rejoin_party()
	check(await until(func(): return not lobby.recovery.active() and lobby.room_size==count,45),"host rejoins with the same mission and squad")
	await create_timer(1).timeout
	check(mission.checkpoint.distance_to(beacon.global_position+Vector3.UP*.88)<.1 and mission.checkpoint_notices==notices+1,"recovery keeps the squad checkpoint without repeating its notification")
	check(mission.operators[slot].health>0 and mission.operators[slot].lives==0 if slot in [0,1] else mission.operators[slot].health>0,"recovery preserves a revived operator with zero spare lives")
	await barrier("host-recovery-complete")

func clear_boss(sector: int, act: int) -> void:
	mission.gate_relays.set_active(3)
	for i in count:
		var actor=mission.operators[i]
		actor.rocket_course=null
		actor.invulnerable_time=1000
		actor.global_position=mission.gate.global_position+Vector3(-2-i*.35,.9,0)
		actor.velocity=Vector3.ZERO
		mission.mark_position_reset(actor)
	mission.check_campaign_progress()

	check(await until(func(): return mission.arena_door.passable,4),"boss door opens for whole party")
	for i in count:
		mission.operators[i].global_position=mission.gate.global_position+Vector3(4+i*.5,.95,0)
		mission.mark_position_reset(mission.operators[i])
	mission.check_campaign_progress()
	check(await until(func(): return mission.boss_started and not mission.boss_intro_active,20),"sector %d act %d boss cinematic"%[sector,act])
	if sector==2:
		check(await game.clear_jungle_test_boss(mission),"Jungle damage gates work for %d players"%count)
	elif mission.boss.has_method("open_armor"):
		for phase in 3:
			mission.boss.open_armor()
			mission.boss.take_damage(100000)
	else: mission.boss.take_damage(100000)
	check(mission.boss_defeated,"sector %d act %d boss defeat"%[sector,act])
	if act==2: await until(func(): return not mission.suit_reveal_playing,25)
	mission.operators[0].global_position=mission.exit_marker.global_position
	mission.check_campaign_progress()


func pressure_cases() -> void:
	var pressure=mission.stage.get_node("TERRAIN/PressureBreach")
	link.latency_ms=70
	link.jitter_ms=65
	link.loss_percent=10
	if host:
		for i in count:
			var actor=mission.operators[i]
			actor.invulnerable_time=1000
			actor.global_position=pressure.valves[i%3].at+Vector3(0,.86,0)
			actor.velocity=Vector3.ZERO
			mission.mark_position_reset(actor)
		pressure.started=true
		pressure.elapsed=0
		mission.broadcast_state(true)
	await barrier("pressure-valves-ready")
	Input.action_press("field_interact")
	await create_timer(3.2).timeout
	Input.action_release("field_interact")
	var first_flags:=3 if count==2 else 7
	check(await until(func():return pressure.active_valves==first_flags,5),"cross-platform held valves replicate under jitter and loss")
	await barrier("pressure-first-valves")
	if host and pressure.active_valves!=7:
		mission.operators[0].global_position=pressure.valves[2].at+Vector3(0,.86,0)
		mission.operators[0].velocity=Vector3.ZERO
		mission.mark_position_reset(mission.operators[0])
		Input.action_press("field_interact")
		await create_timer(2.5).timeout
		Input.action_release("field_interact")
	check(await until(func():return pressure.active_valves==7,6),"whole squad sees all three pressure valves")
	check(await until(func():return pressure.redirects[0].jet.direction==Vector3.RIGHT,3),"valve current redirection matches on every client")
	check(not pressure.completed,"co-op valves respect the ninety-second pressure cycle")
	await barrier("pressure-cycle")
	if host:
		pressure.elapsed=89.9
		mission.broadcast_state(true)
	check(await until(func():return pressure.completed,6),"shared lock opens on Windows and Linux")
	check(await until(func():return pressure.locks[0].body.get_child(0).disabled,4),"shared lock collider clears for every party member")
	await barrier("pressure-complete")
	# Application packet interruption, without disconnecting the real account.
	await barrier("pressure-rejoin-ready")
	if not host:
		link.blacked_out_until=Time.get_ticks_msec()+600
		await create_timer(1.2).timeout
	check(pressure.completed and pressure.active_valves==7,"completed pressure lock survives packet interruption")
	link.latency_ms=0
	link.jitter_ms=0
	link.loss_percent=0
	await barrier("pressure-recovered")
	for target in [1,0]:
		await barrier("pressure-disconnect-%d"%target)
		var local=mission.operators[slot]
		var before:=[local.experience,local.lives,local.health]
		if slot==target: peer._connection_controller.reset_multiplayer(true)
		check(await until(func():return lobby.recovery.active(),10),"pressure run enters recovery after real disconnection")
		if slot==target: lobby.rejoin_party()
		check(await until(func():return not lobby.recovery.active() and lobby.room_size==count,45),"pressure run resumes after slot %d rejoins"%target)
		await create_timer(1.0).timeout
		check(pressure.completed and pressure.active_valves==7,"real rejoin retains all valves and the open pressure lock")
		check(local.experience==before[0] and local.lives==before[1] and is_equal_approx(local.health,before[2]),"pressure rejoin preserves operator progress")
		await barrier("pressure-disconnect-%d-done"%target)

func swim_cases() -> void:
	link.latency_ms=70
	link.jitter_ms=65
	link.loss_percent=10
	if host:
		for i in count:
			var actor=mission.operators[i]
			actor.invulnerable_time=1000
			actor.global_position=Vector3(104+i*.1,5.655,0)
			actor.velocity=Vector3.ZERO
			mission.mark_position_reset(actor)
		mission.broadcast_state(true)
	await barrier("swim-ready")
	await create_timer(.7).timeout
	var local=mission.operators[slot]
	var entered:=false
	var dived:=false
	var rose:=false
	var done:=false
	var deadline:=Time.get_ticks_msec()+45000
	var trace_at:=0
	while Time.get_ticks_msec()<deadline:
		var at: Vector3=local.global_position
		if Time.get_ticks_msec()>trace_at:
			trace_at=Time.get_ticks_msec()+5000
			print("SWIM TRACE slot=",slot," at=",at," wet=",local.swim_volume()!=null," suspended=",local.controls_suspended," blocked=",mission.local_input_blocked()," flags=",[entered,dived,rose])
		entered=entered or local.swim_volume()!=null
		dived=dived or (at.x>126.7 and at.y<-3.4)
		rose=rose or (at.x>149.8 and at.y>-.7)
		if at.x>185 and local.grounded():
			done=true
			break
		var target_y: float=-5.4 if at.x<132 else .2
		var vertical:=clampf((target_y-at.y)*1.5,-1,1)
		Input.action_press("move_right",1)
		if vertical<0:
			Input.action_release("climb_up")
			Input.action_press("climb_down",-vertical)
		else:
			Input.action_release("climb_down")
			Input.action_press("climb_up",vertical)
		await create_timer(.04).timeout
	for action in ["move_right","climb_down","climb_up"]: Input.action_release(action)
	check(done and entered and dived and rose,"native co-op swims below/above both baffles and exits on dry ground at=%s flags=%s"%[local.global_position,str([entered,dived,rose])])
	check(local.health>0 and local.swim_volume()==null,"native swimmer retains health and leaves water movement cleanly")
	await barrier("swim-exited")
	check(await until(func():return mission.checkpoint_notices>0,6),"swim exit checkpoint notifies the squad")
