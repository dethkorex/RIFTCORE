extends SceneTree

const Story := preload("res://scripts/rift_story.gd")
const Reader := preload("res://scripts/dialogue_typewriter.gd")

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ", message)
	failures += int(not condition)

func run() -> void:
	var saves = load("res://scripts/manual_save_session.gd")
	var dialogue_script = load("res://scripts/story_dialogue.gd")
	var settings := root.get_node("RiftSettings")
	var scratch := "user://story-tutorial-test-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	settings.path = scratch.path_join("options.cfg")
	settings.seen_story_beats = PackedStringArray()
	saves.slot_directory = scratch.path_join("slots")
	var operator = saves.new(1)
	operator.run.set_value("checkpoint", "sector", 1)
	check(operator.save_slot() == OK, "A run is saved before the first deployment briefing")
	check(settings.claim_deployment_briefing(operator.profile, 1, 1), "The first deployment shows its briefing")
	check(operator.invalidate_defeated_run() == OK, "Operator wipe invalidates the run")
	settings.seen_story_beats = PackedStringArray()
	settings.restore()
	var rebuilt = saves.new(1)
	check(rebuilt.load_slot() and not rebuilt.run.has_section("checkpoint"), "Reconstruction reloads without the old run")
	check(not settings.claim_deployment_briefing(rebuilt.profile, 1, 1), "The briefing stays seen after reconstruction and restarting the game")
	check(not settings.claim_deployment_briefing(saves.new(2).profile, 1, 1), "Changing operator slots preserves first-visit progress")
	check(settings.claim_deployment_briefing(rebuilt.profile, 1, 2), "The initial visit to the next act shows its own briefing")
	var legacy := ConfigFile.new()
	legacy.set_value("story", "briefed_acts", PackedInt32Array([3]))
	rebuilt.profile.decode_from(legacy)
	check(not settings.claim_deployment_briefing(rebuilt.profile, 2, 1) and settings.seen_story_beats.has("briefing_3"),
		"Previously seen briefings migrate from older operator saves")
	check(settings.claim_story_beat("reconstruction") and not settings.claim_story_beat("reconstruction"),
		"The reconstruction lesson only shows once")
	check(settings.claim_story_beat("arena_hint_1_1") and not settings.claim_story_beat("arena_hint_1_1"),
		"The first-visit arena hint only shows once")

	settings.seen_story_beats.append("campaign_story_v2_1_1")
	var revised: Array = settings.deployment_dialogue(rebuilt.profile, 1, 1)
	check(revised.size() == 2 and revised[0][0] == "NOVA" and revised[1][0] == "RX-07",
		"Returning operators see the rewritten campaign dialogue without repeating a tutorial they already saw")
	check(settings.deployment_dialogue(rebuilt.profile, 1, 1).is_empty(),
		"The updated deployment dialogue is remembered after its first showing")
	var fresh_sector: Array = settings.deployment_dialogue(rebuilt.profile, 2, 2)
	check(fresh_sector.size() == 3 and fresh_sector[2][0] == Story.GUIDE,
		"New lessons are tagged for NOVA's tutorial presentation")

	var valid_campaign := true
	for sector in range(1, 11):
		for act in [1, 2]:
			var deployment := Story.deployment(sector, act)
			var exchange := Story.boss_exchange(sector, act)
			valid_campaign = valid_campaign and deployment.size() >= 3 and exchange.size() >= 3
			for line in deployment + exchange:
				valid_campaign = valid_campaign and line.size() in [2, 3] and not line[1].strip_edges().is_empty()
	check(valid_campaign, "All twenty acts have valid deployment and boss dialogue")

	var dialogue = dialogue_script.new()
	root.add_child(dialogue)
	dialogue.play([["NOVA", "Check the pad."], ["RX-07", "I'm ready.", Story.Mood.RESOLUTE],
		["RX-07", "Wait. Is that a crack?", Story.Mood.CONCERNED]], "Deploy")
	await process_frame
	var reader := dialogue.get_child(-1) as Reader
	var first_portrait: Texture2D = dialogue.portrait_image.texture
	check(first_portrait == dialogue_script.NOVA and dialogue.speaking and dialogue.is_in_group("interactive_dialogue"),
		"NOVA's portrait animates while her line types")
	reader.advance()
	check(reader.body.visible_characters == -1 and not dialogue.speaking and reader.waiting,
		"First press reveals the whole line and settles the portrait")
	reader.advance()
	check(dialogue.portrait_image.texture != first_portrait and reader.body.text == "I'm ready." and dialogue.speaking,
		"Second press switches to RX-07 and animates his portrait")
	var resolute_portrait: Texture2D = dialogue.portrait_image.texture
	reader.advance()
	reader.advance()
	check(dialogue.portrait_image.texture != resolute_portrait and dialogue.speaking,
		"RX-07 changes expression when his mood changes")
	reader.skip()
	check(not dialogue.visible and not dialogue.is_in_group("interactive_dialogue"),
		"Skip closes the dialogue and unlocks gameplay input")
	dialogue.queue_free()
	await process_frame
	quit(failures)
