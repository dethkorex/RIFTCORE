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
	session.profile.award_player_xp(100000000)
	session.profile.memories.append(2)
	check(session.profile.player_level() == 50, "Permanent rank stops at level 50")
	session.profile.materials.merge(session.profile.recipe_materials("vital_weave"), true)
	check(session.profile.craft("vital_weave").contains("sent to Storage"), "Fabrication spends materials and puts gear in storage")
	check(session.save_slot() == OK, "Current-format slot saves")
	check(session.invalidate_defeated_run() == OK, "Permanent death invalidates disk checkpoint")
	var restored = manual_save.new(1)
	check(restored.load_slot() and not restored.run.has_section("checkpoint"), "A defeated deployment cannot be resumed")
	check(restored.profile.gear.has("vital_weave") and restored.profile.gear.has("pulse_lens") and not restored.profile.gear.has("air_jets"), "Storage survives while equipped gear is lost")
	check(restored.profile.player_level() == 50 and restored.profile.memories.has(2), "Permanent rank and memory fragments survive")
	quit(failures)
