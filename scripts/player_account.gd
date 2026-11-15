extends RefCounted

const ManualSave := preload("res://scripts/manual_save_session.gd")
const Profile := ManualSave.Profile

var path := "user://riftcore_player_profile.cfg"
var display_name := ""
var experience := 0
var records: Dictionary = {}
var total_clears := 0
var total_kills := 0
var longest_run := 0.0
var longest_operator := ""

func restore() -> void:
	var data := ConfigFile.new()
	if data.load(path) == OK:
		display_name = Profile.clean_operator_name(str(data.get_value("player", "name", "RX-07")))
		experience = clampi(int(data.get_value("player", "xp", 0)), 0, RiftPlayer.experience_threshold(Profile.PLAYER_LEVEL_CAP))
		records = data.get_value("records", "sector_times", {})
		total_clears = int(data.get_value("records", "clears", 0))
		total_kills = int(data.get_value("records", "kills", 0))
		longest_run = float(data.get_value("records", "longest_run", 0.0))
		longest_operator = str(data.get_value("records", "longest_operator", ""))
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

func save() -> Error:
	var data := ConfigFile.new()
	data.set_value("player", "name", display_name)
	data.set_value("player", "xp", experience)
	data.set_value("records", "sector_times", records)
	data.set_value("records", "clears", total_clears)
	data.set_value("records", "kills", total_kills)
	data.set_value("records", "longest_run", longest_run)
	data.set_value("records", "longest_operator", longest_operator)
	var target := ProjectSettings.globalize_path(path)
	var temporary := target + ".tmp"
	var error := data.save(temporary)
	return DirAccess.rename_absolute(temporary, target) if error == OK else error

func remove_local_progress(other_files: Array[String]) -> Error:
	var files: Array[String] = [path]
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
	return roundi((145 + sector * 30) * (1.0 + difficulty * 0.5))

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
	if save() != OK:
		experience = previous
		records = previous_records
		longest_run = previous_run
		longest_operator = previous_operator
		total_clears -= 1
		total_kills -= kills
		push_warning("Could not save completed-sector Player Profile XP.")
	return {"before": previous, "after": experience}

func track_survival(seconds: float, operator: String) -> bool:
	if not is_finite(seconds) or seconds <= longest_run:
		return false
	longest_run = seconds
	longest_operator = operator
	return true
