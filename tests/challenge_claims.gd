extends SceneTree

const Difficulty := preload("res://scripts/mission_difficulty.gd")
const Stock := preload("res://scripts/stock_catalog.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	failures += int(not ok)

func run() -> void:
	var saves = load("res://scripts/manual_save_session.gd")
	saves.slot_directory = "user://challenge-test-%d" % OS.get_process_id()
	var session = saves.new(1)
	var profile = session.profile
	profile.unlocked_sector = 3
	profile.credits = 200
	profile.reserve_lives = 6
	var starting_shards: int = profile.core_shards
	check(session.save_slot() == OK, "Scratch operator saved")
	check(profile.record_challenges(1, {"act": 1}, session.persist_challenge_progress) == 1,
		"Entering Act II unlocks a reward")
	check(profile.credits == 200 and profile.core_shards == starting_shards and profile.reserve_lives == 6,
		"Challenge completion never pays automatically")
	check(profile.record_challenges(1, {"act": 1}) == 0, "Repeating the objective does not increase the payout")
	var restored = saves.new(1)
	check(restored.load_slot() and restored.profile.challenge_cycle(1).done == [0],
		"Ready-to-claim progress survives a reload before extraction")
	var before: Dictionary = profile.challenge_rewards(1, profile.challenge_cycle(1))
	check(profile.claim_challenge_rewards(1, func(): return ERR_CANT_CREATE) == ERR_CANT_CREATE and
		profile.credits == 200 and profile.challenge_rewards(1, profile.challenge_cycle(1)) == before,
		"A failed write rolls back both the claim and currency")

	profile.challenge_cycle(1).day = 20000101
	check(profile.challenge_cycle(1).done.is_empty() and profile.challenge_rewards(1, profile.challenge_cycle(1)) == before,
		"Unclaimed rewards survive the midnight reset")
	profile.challenge_cycles[2] = {"set": 0, "day": profile.challenge_day(), "done": [0, 1, 2, 3, 4]}
	check(profile.challenge_rewards(2, profile.challenge_cycle(2)).lives == 0,
		"Legacy auto-paid challenges cannot be claimed again")

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	set_meta(&"riftcore_save_session", session)
	set_meta(&"startup_choice_confirmed", true)
	root.add_child(game)
	root.get_node("RiftSettings").show_hub_tips = false
	game.menu.open_station("Sector select")
	await process_frame
	check(game.menu.find_children("*", "Button", true, false).all(func(button): return button.text not in ["Challenges", "Claim Rewards"]),
		"Daily challenges and reward claims live at their own station")
	game.menu.open_station("Challenges")
	await process_frame
	var claim: Button
	for node in game.menu.find_children("*", "Button", true, false):
		if node.text == "Claim Rewards":
			claim = node
			break
	check(is_instance_valid(claim), "Challenges tab offers a claim action")
	if is_instance_valid(claim):
		var focused := root.gui_get_focus_owner()
		check(focused != null and focused.get_node_or_null(focused.focus_neighbor_right) == claim,
			"The selected sector links directly to the claim button for controller navigation")
		claim.pressed.emit()
	check(profile.credits == 200 + before.credits and profile.core_shards == starting_shards + before.shards
		and profile.reserve_lives == 7, "Claim adds Bolts, Core Shards, and an extra life")
	check(restored.load_slot() and restored.profile.reserve_lives == 7 and restored.profile.credits == profile.credits
		and restored.profile.claim_challenge_rewards(1) == ERR_DOES_NOT_EXIST, "Claim and its wallet are persisted together")

	var payout: int = profile.record_challenges(3, {"act": 1, "clear": 1, "clean": 1, "kills": 10, "materials": 5})
	var set_reward: Dictionary = profile.challenge_rewards(3, profile.challenge_cycle(3))
	check(payout == 5 and set_reward.shards == 7 + profile.challenge_set_shards(3),
		"Completing the set adds its reduced shard bonus once")
	check(Difficulty.extraction_shards(1, Difficulty.NORMAL) == 2 and Difficulty.extraction_shards(10, Difficulty.NIGHTMARE) == 6,
		"Base shard rewards scale by sector and difficulty")

	var catalog := Stock.catalog()
	check(catalog.patch_kit.hp == 30 and catalog.patch_kit.price == 90 and
		catalog.spark_cell.energy == 25 and catalog.field_pack.hp >= 20 and catalog.guard_film.duration == 24,
		"Starter supplies give better recovery and longer buffs at lower prices")

	game.start_game(false, 1)
	await process_frame
	check(game.player.lives == 3 and game.factory_hud.lives == 10, "Solo HUD displays starting and bonus lives as one total")
	game.player.add_life()
	check(game.factory_hud.lives == 11, "A life pickup increments that total")
	game.player.lives = 1
	game._on_pit_fall()
	check(game.player.lives == 1 and game.factory_hud.lives == 7 and profile.reserve_lives == 6,
		"Last-life death spends a banked life and reflects it on the HUD")
	check(restored.load_slot() and restored.profile.reserve_lives == 6, "The spent bonus life is saved immediately")
	await create_timer(1.4, true).timeout
	var shards_before_extraction: int = profile.core_shards
	var bolts_before_extraction: int = profile.credits
	game.act = 2
	game.boss_defeated = true
	game.player.global_position = game.game_root.get_node("MARKERS/RoomExit").global_position
	game._process(0.0)
	check(game.sector_complete and profile.core_shards == shards_before_extraction + 2 and
		profile.credits == bolts_before_extraction + 160, "Extraction awards the reduced mission payout only")
	check(profile.challenge_rewards(1, profile.challenge_cycle(1)).lives > 0 and profile.reserve_lives == 6,
		"Extraction leaves newly completed challenge rewards waiting at the station")
	paused = false
	game.queue_free()
	await process_frame
	quit(failures)
