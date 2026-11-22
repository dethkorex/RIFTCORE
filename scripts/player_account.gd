extends RefCounted

const ManualSave := preload("res://scripts/manual_save_session.gd")
const Profile := ManualSave.Profile
const SkinKit := preload("res://scripts/operator_skins.gd")
const Frames := preload("res://scripts/operator_frames.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")

const PATH := "user://riftcore_player_profile.cfg"
const CLEAR_XP_MULTIPLIER := 0.5

var path := PATH
var last_operator := 0
var display_name := ""
var experience := 0
var records: Dictionary = {}
var total_clears := 0
var total_kills := 0
var longest_run := 0.0
var longest_operator := ""
var unlocked_skins: Array = []
var operator_skins: Dictionary = {}
var operator_frames: Dictionary = {}
var finish_progress: Dictionary = {}
var finish_sectors: Array = []

func restore() -> void:
	var data := ConfigFile.new()
	if data.load(path) == OK:
		display_name = Profile.clean_operator_name(str(data.get_value("player", "name", "RX-07")))
		last_operator = clampi(int(data.get_value("player", "last_operator", 0)), 0, ManualSave.SLOT_COUNT)
		experience = clampi(int(data.get_value("player", "xp", 0)), 0, RiftPlayer.experience_threshold(Profile.PLAYER_LEVEL_CAP))
		records = data.get_value("records", "sector_times", {})
		total_clears = int(data.get_value("records", "clears", 0))
		total_kills = int(data.get_value("records", "kills", 0))
		longest_run = float(data.get_value("records", "longest_run", 0.0))
		longest_operator = str(data.get_value("records", "longest_operator", ""))
		if int(data.get_value("wardrobe", "epoch", 0)) == SkinKit.COSMETIC_EPOCH:
			unlocked_skins = data.get_value("wardrobe", "unlocked", [])
			operator_skins = data.get_value("wardrobe", "selections", {})
			operator_frames = data.get_value("wardrobe", "frames", {})
			finish_progress = data.get_value("wardrobe", "finish_progress", {})
			finish_sectors = data.get_value("wardrobe", "finish_sectors", [])
		return
	var previous_name := RiftSettings.last_operator_name
	for index in range(1, ManualSave.SLOT_COUNT + 1):
		var slot := ManualSave.read_slot(index)
		if slot:
			if previous_name.is_empty():
				previous_name = str(slot.get_value("profile", "operator_name", "RX-07"))
			experience = maxi(experience, int(slot.get_value("profile", "player_xp", 0)))
	experience = clampi(experience, 0, RiftPlayer.experience_threshold(Profile.PLAYER_LEVEL_CAP))
	if not previous_name.is_empty():
		create(previous_name)

func create(raw_name: String) -> Error:
	if not display_name.is_empty() or raw_name.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	display_name = Profile.clean_operator_name(raw_name)
	var error := save()
	if error != OK:
		display_name = ""
	return error

func clear_progress() -> void:
	last_operator = 0
	experience = 0
	records.clear()
	total_clears = 0
	total_kills = 0
	longest_run = 0.0
	longest_operator = ""
	operator_skins.clear()
	operator_frames.clear()
	unlocked_skins.clear()
	finish_progress.clear()
	finish_sectors.clear()

func save() -> Error:
	var data := ConfigFile.new()
	data.set_value("player", "name", display_name)
	data.set_value("player", "xp", experience)
	data.set_value("player", "last_operator", last_operator)
	data.set_value("records", "sector_times", records)
	data.set_value("records", "clears", total_clears)
	data.set_value("records", "kills", total_kills)
	data.set_value("records", "longest_run", longest_run)
	data.set_value("records", "longest_operator", longest_operator)
	data.set_value("wardrobe", "epoch", SkinKit.COSMETIC_EPOCH)
	data.set_value("wardrobe", "finish_progress", finish_progress)
	data.set_value("wardrobe", "finish_sectors", finish_sectors)
	data.set_value("wardrobe", "unlocked", unlocked_skins)
	data.set_value("wardrobe", "selections", operator_skins)
	data.set_value("wardrobe", "frames", operator_frames)
	var target := ProjectSettings.globalize_path(path)
	var temporary := target + ".tmp"
	var error := data.save(temporary)
	return DirAccess.rename_absolute(temporary, target) if error == OK else error

func remove_local_progress(other_files: Array[String]) -> Error:
	var files: Array[String] = [path, ManualSave.shared_path()]
	files.append_array(other_files)
	for slot in range(1, ManualSave.SLOT_COUNT + 1):
		files.append(ManualSave.slot_path(slot))
	var renamed: Dictionary[String, String] = {}
	var suffix := ".deleted-profile-%d" % Time.get_ticks_usec()
	for file in files:
		for original in [file, file + ".tmp"]:
			if not FileAccess.file_exists(original):
				continue
			var staged: String = original + suffix
			var error := DirAccess.rename_absolute(original, staged)
			if error != OK:
				for source in renamed:
					DirAccess.rename_absolute(renamed[source], source)
				return error
			renamed[original] = staged
	for staged in renamed.values():
		var error := DirAccess.remove_absolute(staged)
		if error != OK:
			push_warning("Could not remove a staged profile file: " + error_string(error))
	return OK

static func clear_reward(sector: int, difficulty: int) -> int:
	var base_xp := 145 + sector * 30
	var difficulty_multiplier := 1.0 + Difficulty.index(difficulty) * 0.5
	return roundi(base_xp * difficulty_multiplier * CLEAR_XP_MULTIPLIER)

func award_clear(sector: int, difficulty: int, result := {}) -> Dictionary:
	var previous := experience
	experience = mini(RiftPlayer.experience_threshold(Profile.PLAYER_LEVEL_CAP), experience + clear_reward(sector, difficulty))
	var previous_records := records.duplicate()
	var previous_run := longest_run
	var previous_operator := longest_operator
	var kills := maxi(0, int(result.get("kills", 0)))
	total_clears += 1
	total_kills += kills
	var seconds := float(result.get("seconds", 0.0))
	if seconds > 0.0 and is_finite(seconds):
		var key := "%d:%d:%d" % [sector, difficulty, int(result.get("online", false))]
		if seconds < float(records.get(key, INF)):
			records[key] = seconds
		track_survival(float(result.get("survival", seconds)), str(result.get("operator", "RX-07")))
	var before_skins := unlocked_skins.duplicate()
	var before_progress := finish_progress.duplicate()
	var before_sectors := finish_sectors.duplicate()
	if sector not in finish_sectors:
		finish_sectors.append(sector)
	var eligible := SkinKit.record_field_finishes(result, finish_progress, finish_sectors.size())
	var new_finish := ""
	if sector >= 1 and sector <= SkinKit.Catalog.SECTORS.size() and difficulty >= Difficulty.HARD:
		var reward: String = SkinKit.Catalog.SECTORS[sector - 1].reward
		if counted_finish(reward, SkinKit.BOSS_REQUIREMENT):
			eligible.push_front(reward)
		if difficulty == Difficulty.NIGHTMARE:
			var variant := SkinKit.expert_finish(sector)
			if counted_finish(variant, SkinKit.EXPERT_REQUIREMENT):
				eligible.push_front(variant)
	for id in eligible:
		if not unlocked_skins.has(id):
			unlocked_skins.append(id)
			new_finish = id
			break
	if save() != OK:
		unlocked_skins = before_skins
		finish_progress = before_progress
		finish_sectors = before_sectors
		new_finish = ""
		experience = previous
		records = previous_records
		longest_run = previous_run
		longest_operator = previous_operator
		total_clears -= 1
		total_kills -= kills
		push_warning("Could not save completed-sector Player Profile XP.")
	var new_finish_ids := unlocked_skins.filter(func(id: String): return id not in before_skins and not SkinKit.finish_achievement(id).is_empty())
	return {"before": previous, "after": experience, "unlocked_finish": new_finish, "new_finish_ids": new_finish_ids}

func track_survival(seconds: float, operator: String) -> bool:
	if not is_finite(seconds) or seconds <= longest_run:
		return false
	longest_run = seconds
	longest_operator = operator
	return true

func counted_finish(id: String, required: int) -> bool:
	finish_progress[id] = mini(int(finish_progress.get(id, 0)) + 1, required)
	return int(finish_progress[id]) >= required

func display_skin(slot: int) -> String:
	var choice := String(operator_skins.get(slot, ""))
	return choice if unlocked_skins.has(choice) else ""

func display_frame(slot: int) -> String:
	var choice := String(operator_frames.get(slot, ""))
	return choice if Frames.available(choice) and Frames.owned(choice, ManualSave.read_slot(slot)) else ""

func select_appearance(slot: int, frame: String, choice: String) -> Error:
	if slot < 1 or slot > ManualSave.SLOT_COUNT or not Frames.available(frame) \
			or not Frames.owned(frame, ManualSave.read_slot(slot)) \
			or (not choice.is_empty() and not unlocked_skins.has(choice)):
		return ERR_INVALID_PARAMETER
	var previous_frame := String(operator_frames.get(slot, ""))
	var previous_finish := String(operator_skins.get(slot, ""))
	operator_frames[slot] = frame
	operator_skins[slot] = choice
	var error := save()
	if error != OK:
		operator_frames[slot] = previous_frame
		operator_skins[slot] = previous_finish
	return error
