extends Node

signal changed

const Codes := preload("res://addons/GD-Sync/Scripts/Enums/Enums.gd")
const Operators := preload("res://scripts/manual_save_session.gd")
const Player := preload("res://scripts/player_account.gd")
const DOCUMENT := "riftcore_progress"
const ReleaseReset := preload("res://scripts/playtest_reset.gd")
const REMOTE_EPOCH := "riftcore_save_epoch"
const MARKER := "user://riftcore_cloud_sync.cfg"
const RECOVERY := "user://riftcore_cloud_recovery.cfg"
const MAX_BYTES := 256 * 1024

var directory: Node
var status := "Saved on this device."
var remote: Dictionary = {}
var busy := false
var conflict := false
var last_checked_hash := ""
var elapsed := 6.0
var was_online := false
var prepared_for := ""
var checked_release := false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if directory.busy:
		return
	if not directory.online():
		if was_online:
			was_online = false
			update("Offline · Saves stay on this device.")
		return
	elapsed += delta
	if not busy and (not was_online or elapsed >= 6.0):
		was_online = true
		elapsed = 0.0
		if fingerprint(snapshot()) != last_checked_hash:
			sync()

func snapshot() -> Dictionary:
	var profile := ConfigFile.new()
	if profile.load(Player.PATH) != OK:
		return {}
	var data := {"profile": profile.encode_to_text(), "operators": {}}
	for number in range(1, Operators.SLOT_COUNT + 1):
		var stored := Operators.read_slot(number)
		if stored != null:
			data.operators[str(number)] = stored.encode_to_text()
	return data

func fingerprint(data: Dictionary) -> String:
	return JSON.stringify(data).sha256_text()

func marker() -> ConfigFile:
	var data := ConfigFile.new()
	data.load(MARKER)
	return data

func remember(revision: String, data: Dictionary) -> void:
	var saved := ConfigFile.new()
	saved.set_value("sync", "account", directory.username)
	saved.set_value("sync", "revision", revision)
	saved.save(MARKER)
	last_checked_hash = fingerprint(data)

func reset() -> void:
	prepared_for = ""
	remote.clear()
	conflict = false
	last_checked_hash = ""
	for path in [MARKER, RECOVERY]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	update("Saved on this device.")

func reset_cloud_progress() -> int:
	if busy or directory.busy or not directory.online():
		return ERR_BUSY
	busy = true
	var error := await prepare_release()
	var owner: String = directory.username
	if error == 0:
		for prior in [true, false]:
			if owner != directory.username or not directory.online():
				error = ERR_CONNECTION_ERROR
				break
			var code: int = await directory.lobby.relay.account_delete_document(document_path(ReleaseReset.epoch(), prior))
			if code not in [0, Codes.ACCOUNT_DELETE_DOCUMENT_RESPONSE_CODE.DOESNT_EXIST]:
				error = ERR_CANT_CREATE
				break
	busy = false
	return error

func document_path(release: String, previous := false) -> String:
	var suffix := "_" + release.replace(".", "_") if not release.is_empty() else ""
	return DOCUMENT + suffix + ("_previous" if previous else "")

func prepare_release() -> int:
	var target := ReleaseReset.epoch()
	if target.is_empty() or prepared_for == directory.username:
		return 0
	var backend: Node = directory.lobby.relay
	var check: Dictionary = await backend.account_get_document(REMOTE_EPOCH)
	var code := int(check.get("Code", 1))
	if code != 0 and code != Codes.ACCOUNT_GET_DOCUMENT_RESPONSE_CODE.DOESNT_EXIST:
		return code
	var remote_epoch: Variant = check.get("Result")
	var stored := String(remote_epoch.get("release", "")) if code == 0 and remote_epoch is Dictionary else ""
	if stored.naturalnocasecmp_to(target) > 0:
		return ERR_UNAVAILABLE
	if stored != target:
		for path in [DOCUMENT, DOCUMENT + "_previous", document_path(stored), document_path(stored, true)]:
			var deleted: int = await backend.account_delete_document(path)
			if deleted != 0 and deleted != Codes.ACCOUNT_DELETE_DOCUMENT_RESPONSE_CODE.DOESNT_EXIST:
				return deleted
			if stored.is_empty() and path == DOCUMENT + "_previous":
				break
		var written: int = await backend.account_document_set(REMOTE_EPOCH, {"release": target}, false)
		if written != 0:
			return written
	prepared_for = directory.username
	return 0

func rename_owner(old_name: String, new_name: String) -> void:
	var saved := marker()
	if saved.get_value("sync", "account", "") == old_name:
		saved.set_value("sync", "account", new_name)
		saved.save(MARKER)
	prepared_for = ""
	last_checked_hash = ""

func read_remote() -> int:
	checked_release = false
	var error := await prepare_release()
	if error != 0:
		return error
	var result: Dictionary = await directory.lobby.relay.account_get_document(document_path(ReleaseReset.epoch()))
	var code := int(result.get("Code", 1))
	if code == Codes.ACCOUNT_GET_DOCUMENT_RESPONSE_CODE.DOESNT_EXIST:
		checked_release = true
		remote = {}
		return 0
	if code != 0:
		return code
	var document: Variant = result.get("Result")
	if not (document is Dictionary and document.get("version") == 1 and document.get("revision") is String
		and not String(document.revision).is_empty() and document.get("data") is Dictionary):
		return ERR_FILE_CORRUPT
	if not valid_snapshot(document.data):
		return ERR_FILE_CORRUPT
	remote = document
	checked_release = true
	return 0

func sync(prefer_local := false) -> void:
	if busy or directory.busy or not directory.online():
		return
	if prefer_local and not conflict:
		return
	var displayed_revision := String(remote.get("revision", ""))
	busy = true
	var error := await read_remote()
	if not directory.online() or error != 0:
		busy = false
		update("Local save kept. Cloud sync will retry." if error != ERR_FILE_CORRUPT else "Cloud save could not be read. Local save kept.")
		return
	var current := snapshot()
	var saved := marker()
	var remote_data: Dictionary = remote.get("data", {})
	var revision := String(remote.get("revision", ""))
	var accepted_revision := String(saved.get_value("sync", "revision", "")) if saved.get_value("sync", "account", "") == directory.username else ""
	if fingerprint(current) == fingerprint(remote_data):
		remember(revision, current)
		conflict = false
		busy = false
		update("Local and cloud saves match.")
		return
	var may_replace := prefer_local and not revision.is_empty() and revision == displayed_revision
	if not revision.is_empty() and revision != accepted_revision and not may_replace:
		conflict = true
		last_checked_hash = fingerprint(current)
		busy = false
		update("A different cloud save is available. Choose which copy to keep in Saves.")
		return
	if not valid_snapshot(current):
		busy = false
		last_checked_hash = fingerprint(current)
		update("Cloud backup is waiting for a valid local profile save.")
		return
	if may_replace:
		var backup: int = await directory.lobby.relay.account_document_set(document_path(ReleaseReset.epoch(), true), remote, false)
		if backup != 0 or not directory.online():
			busy = false
			update("Could not back up the cloud copy. Both saves were kept.")
			return
	var document := {
		"version": 1, "revision": Crypto.new().generate_random_bytes(16).hex_encode(),
		"saved_at": Time.get_datetime_string_from_system(true, true), "data": current,
	}
	var response: int = await directory.lobby.relay.account_document_set(document_path(ReleaseReset.epoch()), document, false)
	busy = false
	if response != 0:
		update("Saved locally. Cloud backup will retry.")
		return
	remote = document
	conflict = false
	remember(document.revision, current)
	update("Saved on this device and in the cloud.")

func valid_snapshot(data: Dictionary) -> bool:
	if not data.get("profile") is String or not data.get("operators") is Dictionary:
		return false
	if var_to_bytes(data).size() > MAX_BYTES:
		return false
	var profile := ConfigFile.new()
	if profile.parse(data.profile) != OK:
		return false
	var name := String(profile.get_value("player", "name", ""))
	if name.is_empty():
		return false
	for id in data.operators:
		if id not in ["1", "2", "3"] or not data.operators[id] is String:
			return false
		var stored := ConfigFile.new()
		if stored.parse(data.operators[id]) != OK or int(stored.get_value("slot", "format", 0)) not in [1, Operators.FORMAT]:
			return false
	return true

func restore_cloud() -> Dictionary:
	if busy or not directory.online() or remote.is_empty():
		return {"error": ERR_UNAVAILABLE}
	var selected_revision := String(remote.revision)
	busy = true
	var error := await read_remote()
	if error != 0 or remote.get("revision", "") != selected_revision:
		busy = false
		update("The cloud save changed. Review it again before restoring.")
		return {"error": ERR_BUSY}
	var previous := snapshot()
	var backup := ConfigFile.new()
	backup.set_value("recovery", "data", previous)
	error = backup.save(RECOVERY)
	if error == OK:
		var copy: Dictionary = remote.data.duplicate(true)
		var profile := ConfigFile.new()
		error = profile.parse(copy.profile)
		if error == OK:
			error = apply_snapshot(copy)
	busy = false
	if error != OK:
		update("Could not restore the cloud save. Your original copy is in the recovery file.")
		return {"error": error}
	conflict = false
	remember(selected_revision, remote.data)
	update("Cloud save restored to this device.")
	return {"error": OK}

func apply_snapshot(data: Dictionary) -> Error:
	var ops := data.operators as Dictionary
	var values := {Player.PATH: data.profile}
	for number in range(1, Operators.SLOT_COUNT + 1):
		values[Operators.slot_path(number)] = ops.get(str(number), "")
	var moved := {}
	var installed: Array[String] = []
	var suffix := ".cloud-original-%s" % Crypto.new().generate_random_bytes(8).hex_encode()
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Operators.slot_directory))
	if error != OK:
		return error
	for path in values:
		if FileAccess.file_exists(path):
			var original: String = path + suffix
			error = DirAccess.rename_absolute(path, original)
			if error != OK:
				break
			moved[path] = original
		var content: String = values[path]
		if content.is_empty():
			continue
		var stored := ConfigFile.new()
		error = stored.parse(content)
		if error == OK:
			error = stored.save(path)
			if FileAccess.file_exists(path):
				installed.append(path)
		if error != OK:
			break
	if error != OK:
		for path in installed:
			DirAccess.remove_absolute(path)
		for path in moved:
			DirAccess.rename_absolute(moved[path], path)
		return error
	for path in moved.values():
		DirAccess.remove_absolute(path)
	return OK

func update(message: String) -> void:
	status = message
	changed.emit()
