extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(passed: bool, description: String) -> void:
	print("PASS " if passed else "FAIL ", description)
	failures += int(not passed)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass a scratch directory for save fixtures.")
		quit(2)
		return
	var manual_save = load("res://scripts/manual_save_session.gd")
	manual_save.slot_directory = args[0].path_join("save-test-%d" % OS.get_process_id())
	var session = manual_save.new(1)
	var legacy := ConfigFile.new()
	legacy.set_value("slot", "format", 1)
	legacy.set_value("profile", "credits", 300)
	legacy.set_value("equipment", "pulse_lens", "stored")
	legacy.set_value("equipment", "air_jets", "equipped")
	legacy.set_value("checkpoint", "sector", 4)
	legacy.set_value("checkpoint", "experience", 900)
	check(session.write_slot(legacy) == OK and session.load_slot(), "Legacy slots open")
	check(session.profile.player_level() == 1 and session.run.get_value("checkpoint", "experience") == 900, "Legacy operator XP stays separate from permanent level")
	check(session.profile.credits == 300 and session.profile.core_shards == 3 and session.profile.materials.get("scrap") == 6, "Legacy resource balances migrate")
	var difficulty := preload("res://scripts/mission_difficulty.gd")
	var catalog := preload("res://scripts/sector_catalog.gd")
	check(session.profile.available_difficulty(1, difficulty.HARD) == difficulty.NORMAL, "Hard stays locked on a fresh sector")
	check(session.profile.record_sector_clear(1, difficulty.NORMAL), "First Normal clear unlocks Hard")
	check(session.profile.hard_unlocked(1) and not session.profile.hard_unlocked(2), "Hard unlock only applies to the sector cleared")
	check(not session.profile.record_sector_clear(1, difficulty.NORMAL), "Repeating Normal does not trigger the unlock again")
	for sector in range(1, catalog.SECTORS.size()):
		session.profile.record_sector_clear(sector, difficulty.NORMAL)
		session.profile.record_sector_clear(sector, difficulty.HARD)
	check(not session.profile.nightmare_unlocked(), "Expert stays locked with one Hard clear missing")
	session.profile.record_sector_clear(catalog.SECTORS.size(), difficulty.NORMAL)
	check(not session.profile.nightmare_unlocked(), "Normal clears do not count toward Expert")
	session.profile.record_sector_clear(catalog.SECTORS.size(), difficulty.HARD)
	check(session.profile.nightmare_unlocked(), "The final Hard clear unlocks Expert")
	var earlier := ConfigFile.new()
	earlier.set_value("archive", "loot_clears", {2: difficulty.NORMAL})
	earlier.set_value("archive", "hard_clears", {3: true})
	var earlier_profile = session.profile.get_script().new()
	earlier_profile.decode_from(earlier)
	check(earlier_profile.hard_unlocked(2) and earlier_profile.hard_unlocked(3) and not earlier_profile.hard_unlocked(1), "Previous sector clears retain Hard access")
	check(earlier_profile.unlocked_sector == 4, "Previous sector clears restore deployment access")
	session.profile.award_player_xp(100000000)
	session.profile.memories.append(2)
	check(session.profile.player_level() == 50, "Permanent rank stops at level 50")
	var id := "bp_01_00"
	session.profile.materials.merge(session.profile.recipe_materials(id), true)
	check(session.profile.craft(id) == "Blueprint undiscovered.", "Undiscovered recipes cannot be crafted")
	session.profile.blueprints[id] = true
	check(session.profile.craft(id).contains("sent to Storage"), "Fabrication spends materials and puts gear in storage")
	session.profile.unlock_sector(catalog.SECTORS.size())
	session.profile.quick_slots[0] = {"id": "patch_kit", "count": 2}
	session.profile.stored_supplies["patch_kit"] = 4
	check(session.save_slot() == OK, "Current-format slot saves")
	session.profile.core_shards = 25
	check(session.profile.buy("armor").contains("installed"), "Purchase a permanent enhancement after the manual save")
	check(session.invalidate_defeated_run() == OK, "Permanent death invalidates disk checkpoint")
	check(not session.run.has_section("checkpoint") and session.profile.quick_slots[0].is_empty(), "The defeated in-memory run and quick slots reset")
	var restored = manual_save.new(1)
	check(restored.load_slot() and not restored.run.has_section("checkpoint"), "A defeated deployment cannot be resumed")
	check(restored.profile.gear.has(id) and restored.profile.blueprints.has(id) and restored.profile.gear.has("pulse_lens") and not restored.profile.gear.has("air_jets"), "Storage survives while equipped gear is lost")
	check(restored.profile.quick_slots[0].is_empty() and restored.profile.stored_supplies.get("patch_kit") == 4, "Only equipped supplies are lost")
	check(restored.profile.player_level() == 50 and restored.profile.memories.has(2), "Permanent rank and memory fragments survive")
	check(restored.profile.hard_unlocked(1) and restored.profile.nightmare_unlocked(), "Difficulty unlocks survive a defeated run and save reload")
	check(restored.profile.unlocked_sector == catalog.SECTORS.size() and restored.profile.rank("armor") == 1 and restored.profile.core_shards == 10, "Unlocked sectors and paid enhancements persist through reconstruction")
	var player_script = load("res://scripts/player.gd")
	var milestones := {}
	for stock_id in restored.profile.stock:
		var shopper = manual_save.new(1).profile
		var item: Dictionary = shopper.stock[stock_id]
		var required: int = item.shop_level
		shopper.credits = item.price
		if required > 1:
			shopper.player_xp = player_script.experience_threshold(required - 1)
			var locked: String = shopper.buy_supply(stock_id)
			if locked != "Unlocks at Player Lv. %d." % required or shopper.credits != item.price or shopper.supply_owned(stock_id) != 0:
				check(false, "%s rejects a purchase before its milestone" % stock_id)
		shopper.player_xp = player_script.experience_threshold(required)
		var result: String = shopper.buy_supply(stock_id)
		if not result.begins_with("Purchased ") or shopper.credits != 0 or shopper.supply_owned(stock_id) != item.get("quantity", 1):
			check(false, "%s can be purchased at its milestone" % stock_id)
		milestones[required] = true
	var levels := milestones.keys()
	levels.sort()
	check(levels == [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50], "Shop stock unlocks every five Player Levels")
	var old_shop_save := ConfigFile.new()
	old_shop_save.set_value("profile", "player_xp", player_script.experience_threshold(10))
	var shopper = manual_save.new(2).profile
	shopper.decode_from(old_shop_save)
	check(shopper.shop_announced_through == 10, "Older saves only get announcements for future milestones")
	shopper.award_player_xp(player_script.experience_threshold(20) - shopper.player_xp)
	var shop_save := ConfigFile.new()
	shopper.encode_into(shop_save)
	shopper.decode_from(shop_save)
	check(shopper.shop_milestone() == 20 and shopper.shop_announced_through == 10, "Saving after earning XP keeps the new shop announcement pending")
	shopper.shop_announced_through = shopper.shop_milestone()
	shopper.encode_into(shop_save)
	shopper.decode_from(shop_save)
	check(shopper.shop_announced_through == 20, "Seen shop milestones carry over with the operator")
	quit(failures)
