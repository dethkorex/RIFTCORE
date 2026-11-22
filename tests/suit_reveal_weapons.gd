extends "res://tests/game_test_tree.gd"
var failures:=0
var demonstration_done:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	failures+=int(not ok)
func demonstrate(reveal,actor,rig,plate) -> void:
	await reveal.demonstrate(actor,rig,plate)
	demonstration_done=true
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.profile.path="user://suit-demo-test.cfg"
	game.checkpoint_path="user://suit-demo-test-run.cfg"
	root.add_child(game)
	current_scene=game
	game.profile.manual_only=true
	game.start_game(false,1)
	game.set_physics_process(false)
	game.camera_rig.set_process(false)
	for actor in game.game_root.get_node("Actors").get_children(): actor.set_physics_process(false)
	var actor=game.player
	actor.remote_input=true
	actor.energy=0
	var catalog=load("res://scripts/sector_catalog.gd")
	var projectile_script=load("res://scripts/projectile.gd")
	for reward in catalog.SECTORS:
		actor.unlock_sector_weapon(reward.reward)
		var reveal=load("res://scripts/suit_reveal.gd").new()
		game.game_root.add_child(reveal)
		var plate=reveal.ability_card(game.hud,reward,Color(reward.color))
		var initial_health: float=actor.health
		var shots: Dictionary={}
		var regular:=false
		var wrong:=false
		demonstration_done=false
		demonstrate.call_deferred(reveal,actor,game.camera_rig,plate)
		while not demonstration_done:
			await process_frame
			for child in reveal.get_children():
				if child.get_script()==projectile_script:
					shots[child.get_instance_id()]=true
					regular=regular or not child.is_charged
					wrong=wrong or child.weapon_id!=reward.reward
		check(shots.size()>=3 and not regular and not wrong,"%s demonstrates charged shots from its acquired weapon"%reward.reward_name)
		check(actor.energy==0 and actor.health==initial_health and actor.showcase_projectiles==null,"%s demo is safe at zero energy and releases its showcase"%reward.reward_name)
		plate.queue_free()
		reveal.queue_free()
		await process_frame
	game.queue_free()
	current_scene=null
	await process_frame
	await process_frame
	print("SUIT REVEAL WEAPONS RESULT failures=",failures)
	finish(int(failures>0))
