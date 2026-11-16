extends RefCounted

const Account := preload("res://scripts/player_account.gd")
const Slots := preload("res://scripts/manual_save_session.gd")
const STAMP := "user://riftcore_playtest_epoch.cfg"

static func epoch() -> String:
	var configured := String(ProjectSettings.get_setting("riftcore/testing/progress_epoch", ""))
	if not configured.is_empty():
		return configured
	return String(ProjectSettings.get_setting("application/config/version")) if ProjectSettings.get_setting("riftcore/testing/reset_progress_on_update", false) else ""

static func migrate_local(account: Account) -> Error:
	var release := epoch()
	if release.is_empty():
		return OK
	var marker := ConfigFile.new()
	if marker.load(STAMP) == OK and String(marker.get_value("testing", "release", "")).naturalnocasecmp_to(release) >= 0:
		return OK
	var files: Array[String] = [
		"user://riftcore_profile.cfg", "user://riftcore_checkpoint.cfg",
		"user://riftcore_cloud_sync.cfg", "user://riftcore_cloud_recovery.cfg",
	]
	for i in range(1, Slots.SLOT_COUNT + 1):
		files.append(Slots.slot_path(i))
	for file in files:
		for path in [file, file + ".tmp"]:
			if FileAccess.file_exists(path):
				var error := DirAccess.remove_absolute(path)
				if error != OK:
					return error
	if not account.display_name.is_empty():
		account.clear_progress()
		var error := account.save()
		if error != OK:
			return error
	RiftSocial.best_times.clear()
	for contact in RiftSocial.recent_players.values():
		contact.times = {}
	if not RiftSocial.save_social():
		return ERR_CANT_CREATE
	marker.set_value("testing", "release", release)
	return marker.save(STAMP)
