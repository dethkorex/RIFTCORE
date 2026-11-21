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
	check(session.profile.recipe_materials(id) == {"scrap": 3, "components": 1},
		"An early Forge plan crafts with common salvage from its own sector")
	check(session.profile.recipe_materials("bp_01_03") == {"scrap": 3, "cells": 1},
		"An early energy plan uses cells available in Ember Foundry")
	check(session.profile.recipe_materials("bp_01_04") == {"scrap": 6, "components": 2, "sector_1": 1},
		"Rare Forge plans use a single local material without advanced boss ingredients")
	check(session.profile.recipe_materials("survey_optics") == {"scrap": 3, "components": 1},
		"Older starter plans stay craftable without advanced circuits")
	var legendary: Dictionary = session.profile.recipe_materials("bp_10_15")
	check(legendary.get("sector_10") == 3 and legendary.get("core") == 2 and legendary.get("legendary") == 1,
		"Legendary plans still require their local material, boss cores and a fracture crystal")
	check(is_equal_approx(session.profile.GEAR[id].stats.resist, 0.08)
		and session.profile.GEAR["bp_01_01"].stats.hp == 14
		and is_equal_approx(session.profile.GEAR["bp_01_02"].stats.attack, 1.10),
		"Early Forge blueprints give meaningful armor, HP and damage bonuses")
	session.profile.materials.merge(session.profile.recipe_materials(id), true)
	check(session.profile.craft(id) == "Blueprint undiscovered.", "Undiscovered recipes cannot be crafted")
	session.profile.blueprints[id] = true
	check(session.profile.craft(id).contains("sent to Storage"), "Fabrication spends materials and puts gear in storage")
	var crafter = manual_save.new(2).profile
	crafter.award_player_xp(100000000)
	crafter.blueprints["vital_weave"] = true
	crafter.gear["impact_liner"] = "equipped"
	crafter.materials.merge(crafter.recipe_materials("vital_weave"), true)
	check(crafter.craft("vital_weave", true).contains("equipped")
		and crafter.equipped_for("frame") == "vital_weave" and crafter.gear.get("impact_liner") == "stored",
		"Craft and equip swaps the current gear into Storage")
	check(crafter.craft("vital_weave", true) == "Blueprint already fabricated.", "Craft and equip cannot spend the same recipe twice")
	crafter.blueprints["pulse_lens"] = true
	crafter.materials.merge(crafter.recipe_materials("pulse_lens"), true)
	for gear_id in crafter.GEAR:
		if crafter.stored_count() >= crafter.storage_capacity():
			break
		if not crafter.gear.has(gear_id) and gear_id != "pulse_lens":
			crafter.gear[gear_id] = "stored"
	check(crafter.craft("pulse_lens") == "Storage is full." and crafter.craft("pulse_lens", true).contains("equipped"),
		"An empty socket can accept new gear when Storage is full")
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
	check(restored.profile.unlocked_sector == catalog.SECTORS.size() and restored.profile.rank("armor") == 1 and restored.profile.core_shards == 12, "The rounded talent price and whole shard balance persist through reconstruction")
	var player_script = load("res://scripts/player.gd")
	var milestones := {}
	for stock_id in restored.profile.stock:
		var shopper = manual_save.new(1).profile
		var item: Dictionary = shopper.stock[stock_id]
		var required: int = item.shop_level
		shopper.credits = item.price
		if item.get("material", "") in ["core", "legendary"]:
			shopper.player_xp = player_script.experience_threshold(50)
			check(shopper.buy_supply(stock_id) == "Item unavailable." and shopper.credits == item.price,
				"%s can no longer be purchased" % item.name)
			continue
		if required > 1:
			shopper.player_xp = player_script.experience_threshold(50)
			shopper.operator_level = required - 1
			var locked: String = shopper.buy_supply(stock_id)
			if locked != "Unlocks at Operator Lv. %d." % required or shopper.credits != item.price or shopper.supply_owned(stock_id) != 0:
				check(false, "%s rejects a purchase before its milestone" % stock_id)
		shopper.player_xp = 0
		shopper.operator_level = required
		var result: String = shopper.buy_supply(stock_id)
		if not result.begins_with("Purchased ") or shopper.credits != 0 or shopper.supply_owned(stock_id) != item.get("quantity", 1):
			check(false, "%s can be purchased at its milestone" % stock_id)
		milestones[required] = true
	var levels := milestones.keys()
	levels.sort()
	check(levels == [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50], "Shop stock unlocks every five Operator Levels")
	var old_shop_save := ConfigFile.new()
	old_shop_save.set_value("checkpoint", "experience", player_script.experience_threshold(10))
	var shopper = manual_save.new(2).profile
	shopper.decode_from(old_shop_save)
	check(shopper.shop_announced_through == 10, "Older saves only get announcements for future milestones")
	var shop_save := ConfigFile.new()
	shop_save.set_value("checkpoint", "experience", player_script.experience_threshold(20))
	shopper.encode_into(shop_save)
	shopper.decode_from(shop_save)
	check(shopper.shop_milestone() == 20 and shopper.shop_announced_through == 10, "Saving after earning XP keeps the new shop announcement pending")
	shopper.shop_announced_through = shopper.shop_milestone()
	shopper.encode_into(shop_save)
	shopper.decode_from(shop_save)
	check(shopper.shop_announced_through == 20, "Seen shop milestones carry over with the operator")
	var talents = manual_save.new(3).profile
	talents.award_player_xp(player_script.experience_threshold(50))
	talents.core_shards = 3000
	check(talents.buy("field_reboot").begins_with("Requires Tier") and talents.rank("field_reboot") == 0 and talents.core_shards == 3000,
		"Level and currency cannot bypass a locked talent tier")
	check(talents.buy("armor").contains("installed") and talents.buy("field_reboot").contains("installed"), "A Survivability root unlocks Field Reboot")
	check(talents.buy("overpressure").begins_with("Requires Tier"), "Survivability progress does not unlock later Damage tiers")
	check(talents.buy("field_reboot").contains("II installed") and talents.buy("field_reboot").contains("III installed") and talents.rank("field_reboot") == 3,
		"Field Reboot has three paid ranks")
	talents.owned["socket_arm_04"] = 1
	check(talents.buy("overpressure").begins_with("Requires Tier 1") and talents.rank("socket_arm_04") == 1,
		"An imported upper-tier talent stays installed without bypassing missing prerequisites")
	check(talents.buy("socket_arm_07") == "Unknown upgrade.", "Imported bonuses are preserved without selling the retired perks")
	check(talents.buy("recovery_circuit").begins_with("Requires Tier 3"), "A player cannot skip Tier 3 to reach a capstone")
	check(talents.buy("shock_dampers").contains("installed") and talents.buy("recovery_circuit").contains("I installed"),
		"Installing a Tier 3 talent opens the Tier 4 capstone in its branch")
	talents.record_sector_clear(1, difficulty.NORMAL)
	var target := "bp_01_02"
	talents.pin_blueprint(target)
	check(talents.pinned_blueprint == target and talents.blueprint_min_mode(target) == difficulty.NORMAL, "A cleared sector exposes its blueprint hunt")
	check(talents.advance_blueprint_hunt(2, difficulty.HARD, 10).is_empty() and talents.advance_blueprint_hunt(1, difficulty.NORMAL, 1).is_empty() and talents.blueprint_hunts.is_empty(),
		"A different sector or underlevel extraction does not count")
	for attempt in 2:
		check(talents.advance_blueprint_hunt(1, difficulty.NORMAL, 3).is_empty(), "Eligible extraction adds hunt progress")
	check(talents.advance_blueprint_hunt(1, difficulty.NORMAL, 3) == target and talents.blueprint_items.has(target) and talents.pinned_blueprint.is_empty(),
		"Third eligible extraction banks the blueprint once")
	var talent_save := ConfigFile.new()
	talents.encode_into(talent_save)
	var reloaded = manual_save.new(3).profile
	reloaded.decode_from(talent_save)
	check(reloaded.rank("field_reboot") == 3 and reloaded.blueprint_items.has(target), "Revive ranks and the hunted blueprint survive a save reload")
	# Start with an independent old slot alongside the legacy fixture.
	manual_save.slot_directory = manual_save.slot_directory.path_join("shared-migration")
	var first = manual_save.new(1)
	var second = manual_save.new(2)
	var old_first := ConfigFile.new()
	old_first.set_value("slot", "format", 2)
	old_first.set_value("inventory", "stored_supplies", {"patch_kit": 2})
	old_first.set_value("profile", "materials", {"scrap": 3})
	old_first.set_value("profile", "core_shards", 5)
	old_first.set_value("upgrades", "armor", 1)
	old_first.set_value("equipment", "impact_liner", "stored")
	old_first.set_value("checkpoint", "experience", 900)
	var old_second := ConfigFile.new()
	old_second.set_value("slot", "format", 2)
	old_second.set_value("inventory", "stored_supplies", {"patch_kit": 1})
	old_second.set_value("profile", "core_shards", 7)
	old_second.set_value("blueprints", "pulse_lens", true)
	old_second.set_value("checkpoint", "experience", 120)
	check(first.write_slot(old_first) == OK and second.write_slot(old_second) == OK and first.load_slot(), "Legacy operators can initialize shared progress")
	check(first.profile.core_shards == 12 and first.profile.rank("armor") == 1 and first.profile.stored_supplies.get("patch_kit") == 3 and first.profile.blueprints.has("pulse_lens"), "Legacy storage, shards, talents, and recipes merge across slots")
	first.profile.stored_supplies["patch_kit"] = 2
	check(first.save_slot() == OK and second.load_slot(), "Second operator picks up the shared changes")
	check(second.profile.stored_supplies.get("patch_kit") == 2 and second.profile.gear.get("impact_liner") == "stored" and second.run.get_value("checkpoint", "experience") == 120, "Storage stays shared while run XP remains slot-specific")
	second.profile.blueprints["bp_01_02"] = true
	check(second.profile.change_hub_inventory("blueprint/bp_01_02", 1, second.save_slot),
		"A party member can pick up a spare physical copy of a learned recipe")
	check(first.load_slot() and first.profile.blueprint_pouch.has("bp_01_02") and first.profile.blueprints.has("bp_01_02"),
		"The spare blueprint and learned recipe both survive an operator reload")
	check(first.profile.stow_pouch_blueprint("bp_01_02").contains("Storage") and first.save_slot() == OK and
		second.load_slot() and second.profile.blueprint_items.has("bp_01_02"),
		"Storage retains spare blueprints for a learned recipe")
	var third = manual_save.new(3)
	check(third.load_shared() == OK and third.profile.core_shards == 12 and third.profile.materials.get("scrap") == 3 and third.run.get_sections().is_empty(), "A fresh operator inherits storage and talents with a fresh run")
	var account = load("res://scripts/player_account.gd").new()
	account.path = manual_save.slot_directory.path_join("test-account.cfg")
	var fresh = manual_save.new(1)
	var extra_files: Array[String] = []
	check(account.remove_local_progress(extra_files) == OK and not FileAccess.file_exists(manual_save.shared_path()) and not fresh.load_slot() and fresh.load_shared() == OK and fresh.profile.core_shards == 0 and fresh.profile.rank("armor") == 0 and fresh.profile.blueprints.is_empty() and fresh.profile.stored_supplies.is_empty(), "Profile reset erases slots and the shared save")
	var old_account := ConfigFile.new()
	old_account.set_value("player", "name", "Wardrobe QA")
	old_account.set_value("player", "xp", 130)
	old_account.set_value("wardrobe", "unlocked", ["field:1", "variant:1"])
	old_account.set_value("wardrobe", "selections", {1: "field:1"})
	old_account.save(account.path)
	account.restore()
	old_first.set_value("wardrobe", "owned_frames", ["relay"])
	old_first.set_value("profile", "credits", 900)
	first.write_slot(old_first)
	check(account.unlocked_skins.is_empty() and account.display_skin(1).is_empty() and account.experience == 130, "Legacy profile clears finishes and keeps earned XP")
	check(first.load_slot() and first.profile.owned_frames.is_empty() and first.profile.credits == 900, "Legacy slot clears frame purchases and keeps its Bolt balance")
	var clean_run := {"kills": 30, "materials": 10, "bolts": 400, "health": 100, "energy": 100, "seconds": 320, "clean": true}
	account.award_clear(1, difficulty.NORMAL, clean_run)
	check(account.experience == 130 + 88, "Normal clears grant slower Profile XP and preserve XP already earned")
	check(account.clear_reward(1, difficulty.HARD) == 131 and account.clear_reward(1, difficulty.NIGHTMARE) == 175,
		"The lower Profile XP rate still rewards higher difficulties")
	check(account.unlocked_skins.is_empty(), "One high-scoring run cannot unlock a finish")
	for run_index in 3:
		account.award_clear(1, difficulty.NORMAL, clean_run)
	check(account.unlocked_skins.size() == 1, "Qualifying clears award at most one finish per extraction")
	account.award_clear(2, difficulty.NIGHTMARE, clean_run)
	check(not account.unlocked_skins.has("variant:2"), "A first Expert extraction does not award its finish")
	account.award_clear(2, difficulty.NIGHTMARE, clean_run)
	check(account.unlocked_skins.has("variant:2"), "Two Expert extractions award that sector's finish")
	var after_reset = load("res://scripts/player_account.gd").new()
	after_reset.path = account.path
	after_reset.restore()
	check(after_reset.unlocked_skins == account.unlocked_skins and after_reset.finish_progress == account.finish_progress, "New wardrobe unlocks and progress survive a reload")
	quit(failures)
