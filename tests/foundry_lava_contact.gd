extends "res://tests/game_test_tree.gd"
class GuestLink extends Node:
	func get_sender_id() -> int: return 12

var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	failures += int(not ok)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.profile.path="user://lava-contact-profile.cfg"
	game.checkpoint_path="user://lava-contact-run.cfg"
	root.add_child(game)
	current_scene=game
	game.profile.manual_only=true
	game.sector=1
	game.act=2
	game.start_game(false,1)
	game.set_physics_process(false)
	var lava=game.game_root.get_node("TERRAIN/LavaEscape")
	lava.set_physics_process(false)
	var actor=game.player
	for node in game.game_root.get_node("Actors").get_children(): node.set_physics_process(false)
	actor.fell_into_pit.disconnect(game._on_pit_fall)
	var deaths=[0]
	actor.fell_into_pit.connect(func(): deaths[0]+=1)
	var half=actor.standing_capsule.height*.5
	var guest = load("res://scenes/actors/riftcore_player.tscn").instantiate()
	lava.actors.add_child(guest)
	guest.set_physics_process(false)
	var mission = load("res://tests/coop_revival_fixture.gd").new()
	root.add_child(mission)
	mission.host = true
	mission.act = 2
	mission.roster = [11, 12]
	mission.operators.assign([actor, guest])
	mission.peer = GuestLink.new()
	mission.add_child(mission.peer)
	mission.gate_relays = game.gate_relays
	mission.arena_door = game.arena_door
	var bounds: AABB = lava.door.bounds
	var approach := Vector3(bounds.position.x - 1, bounds.position.y + half + .08, bounds.get_center().z)
	actor.global_position = approach
	for terminal in mission.gate_relays.terminals:
		guest.global_position = terminal.global_position + Vector3.UP * half
		mission.receive_gate_relay_request(2)
	check(mission.gate_relays.complete() and mission.broadcasts == 2, "Guest can activate both switches and broadcast their state")
	lava.require_full_party = true
	guest.global_position = approach - Vector3.RIGHT * 15
	lava._physics_process(.5)
	check(lava.door.lift() == 0, "Unlocked lava entrance waits for the distant guest")
	guest.global_position = approach
	guest.health = 0
	lava._physics_process(.5)
	check(lava.door.lift() == 0, "A downed party member cannot satisfy the entrance check")
	guest.health = guest.max_health
	lava._physics_process(.5)
	check(lava.door.passable, "Lava entrance opens when both party members arrive")
	actor.global_position = lava.to_global(Vector3(2, 1, 0))
	lava._physics_process(.016)
	check(lava.door.passable and lava.phase == lava.Phase.READY, "The entrance stays open for the second operator to cross")
	guest.global_position = lava.to_global(Vector3(2.5, 1, 0))
	lava._physics_process(.016)
	check(lava.phase == lava.Phase.SEALED, "The lava sequence starts after both operators cross")
	mission.free()
	guest.free()
	lava.door.reset()
	lava.phase = lava.Phase.READY
	lava.require_full_party = false
	lava.surface=7.0
	actor.global_position=lava.to_global(Vector3(12,7+half+.2,0))
	check(not lava.touches_lava(actor),"boots above lava remain safe")
	actor.global_position=lava.to_global(Vector3(12,7+half+.08,0))
	check(lava.touches_lava(actor),"visible wave crest touching boots is lethal")
	actor.global_position=lava.to_global(Vector3(lava.SHAFT_RIGHT+.15,7+half,0))
	check(lava.touches_lava(actor),"capsule edge contacts lava beyond its centre")
	actor.global_position=lava.to_global(Vector3(12,7+half,1.8))
	check(lava.touches_lava(actor),"front of rendered lava remains lethal outside old trigger depth")
	actor.global_position=lava.to_global(Vector3(12,7+half,3))
	check(not lava.touches_lava(actor),"outside the lava depth stays safe")
	actor.global_position=lava.to_global(Vector3(1,7+half,0))
	check(not lava.touches_lava(actor),"ceiling protects the low entrance tunnel above its lava cap")
	actor.global_position=lava.to_global(Vector3(1,2+half,0))
	check(lava.touches_lava(actor),"the entrance pool stays lethal when lava rises above its ceiling")
	lava.surface=2
	actor.global_position=lava.to_global(Vector3(1,2+half,0))
	check(lava.touches_lava(actor),"low tunnel lava follows the wide lower surface")
	for phase in [lava.Phase.RISING,lava.Phase.DRAINING]:
		actor.health=actor.max_health
		actor.invulnerable_time=1000
		actor.global_position=lava.to_global(Vector3(12,4+half,0))
		lava.surface=5
		lava.phase=phase
		lava.authority=true
		var before=deaths[0]
		lava._physics_process(.001)
		check(actor.health==0 and deaths[0]==before+1,"lava kills once in phase %d, bypassing damage immunity"%phase)
		lava._physics_process(.001)
		check(deaths[0]==before+1,"a dead player cannot lose repeated lives")
	actor.health=actor.max_health
	actor.global_position=lava.to_global(Vector3(12,4+half,0))
	lava.surface=5
	lava.authority=false
	lava._physics_process(.016)
	check(actor.health>0,"co-op replicas leave death authority with the host")
	lava.authority=true
	actor.fell_into_pit.connect(game._on_pit_fall)
	var lives=actor.lives
	lava._physics_process(.001)
	check(actor.health==0 and actor.lives==lives-1,"solo lava death deducts one life through the real respawn handler")
	await create_timer(.6).timeout
	check(actor.health==actor.max_health and actor.visible,"solo lava death respawns at the checkpoint")
	current_scene=null
	game.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	game=null
	lava=null
	actor=null
	await process_frame
	print("LAVA CONTACT RESULT failures=",failures)
	finish(int(failures>0))
