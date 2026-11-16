extends RefCounted

const Account := preload("res://scripts/player_account.gd")
const STAMP := "user://riftcore_playtest_epoch.cfg"

static func epoch() -> String:
	var configured := String(ProjectSettings.get_setting("riftcore/testing/progress_epoch", ""))
	if not configured.is_empty():
		return configured
	return String(ProjectSettings.get_setting("application/config/version")) if ProjectSettings.get_setting("riftcore/testing/reset_progress_on_update", false) else ""

static func migrate_local(account: Account) -> Error:
	var release := epoch()
	# Ordinary playtest resets only advance progress_epoch.
	var account_epoch := String(ProjectSettings.get_setting("riftcore/testing/account_epoch", ""))
	var marker := ConfigFile.new()
	marker.load(STAMP)
	var reset_progress := not release.is_empty() and String(marker.get_value("testing", "release", "")).naturalnocasecmp_to(release) < 0
	var reset_account := not account_epoch.is_empty() and String(marker.get_value("testing", "account", "")).naturalnocasecmp_to(account_epoch) < 0
	if not reset_progress and not reset_account:
		return OK
	var error := account.remove_local_progress([
		"user://riftcore_profile.cfg", "user://riftcore_checkpoint.cfg",
		"user://riftcore_cloud_sync.cfg", "user://riftcore_cloud_recovery.cfg",
	])
	if error != OK:
		return error
	account.clear_progress()
	if reset_account:
		error = RiftRelay.directory.reset_local_link()
		if error != OK:
			return error
		if not RiftSocial.reset_social_data():
			return ERR_CANT_CREATE
		RiftSettings.startup_mode = ""
		RiftSettings.last_operator_name = ""
		error = RiftSettings.save()
		if error != OK:
			return error
		account.display_name = ""
		marker.set_value("testing", "account", account_epoch)
	elif not account.display_name.is_empty():
		error = account.save()
		if error != OK:
			return error
	marker.set_value("testing", "release", release)
	return marker.save(STAMP)
