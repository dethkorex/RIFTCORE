extends Node

const MAX_PACKAGE := 512 * 1024 * 1024
const REPO_PATTERN := "^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9_.-]{1,90}$"
const TAG_PATTERN := "^v[0-9]{1,5}[.][0-9]{1,5}[.][0-9]{1,5}(-preview)?$"
const LEGACY_MIGRATION_TAG := "v0.4.100"
const HASH_PATTERN := "^[0-9a-f]{64}$"

const OFFICIAL_REPO := "dethkorex/RIFTCORE"

var install_root := ""
var repo := ""
var preview_channel := false
var game_filename := "RIFTCORE.exe" if OS.get_name() == "Windows" else "RIFTCORE"
var target_platform := "windows-x64" if OS.get_name() == "Windows" else "linux-x64"
var transfer: HTTPRequest
var expected_bytes := 0

func configure_game() -> String:
	var folder := OS.get_executable_path().get_base_dir()
	install_root = folder.get_base_dir().get_base_dir() if folder.get_base_dir().get_file() == "versions" and is_match(TAG_PATTERN, folder.get_file()) else folder
	var release: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/update_channel.json")) if FileAccess.file_exists("res://assets/update_channel.json") else {}
	if not release is Dictionary:
		release = {}
	var current := String(release.get("tag", "v%s-preview" % ProjectSettings.get_setting("application/config/version")))
	repo = String(release.get("repo", OFFICIAL_REPO))
	preview_channel = current.ends_with("-preview")
	var config := ConfigFile.new()
	if config.load(install_root.path_join("updates.cfg")) == OK:
		repo = String(config.get_value("updates", "repository", repo))
		preview_channel = config.get_value("updates", "preview_channel", preview_channel)
	return current

func is_match(pattern: String, value: String) -> bool:
	var regex := RegEx.new()
	return regex.compile(pattern) == OK and regex.search(value) != null

func compare_tags(a: String, b: String) -> bool:
	if b.is_empty():
		return true
	var left := a.trim_suffix("-preview").substr(1).split(".")
	var right := b.trim_suffix("-preview").substr(1).split(".")
	for i in range(3):
		var n := int(left[i])
		var m := int(right[i])
		if n != m:
			return n > m
	return not a.ends_with("-preview") and b.ends_with("-preview")

func newest_installed() -> String:
	var best := ""
	var versions := install_root.path_join("versions")
	var dir := DirAccess.open(versions)
	if dir == null:
		return best
	for tag in dir.get_directories():
		if tag == LEGACY_MIGRATION_TAG or not is_match(TAG_PATTERN, tag):
			continue
		var folder := versions.path_join(tag)
		if version_is_complete(folder, [game_filename, "RIFTCORE.pck"]) and compare_tags(tag, best):
			best = tag
	return best

func select_release(releases: Variant) -> String:
	var best := ""
	if not releases is Array:
		return best
	for release in releases:
		if not release is Dictionary or release.get("draft", false):
			continue
		var tag := String(release.get("tag_name", ""))
		if not is_match(TAG_PATTERN, tag) or not compare_tags(tag, best):
			continue
		var assets = release.get("assets", [])
		if assets is Array and assets.any(func(asset): return asset is Dictionary and asset.get("name", "") == "update.json"):
			best = tag
	return best

func get_json(url: String, budget: int, headers := PackedStringArray()) -> Variant:
	var request := HTTPRequest.new()
	request.timeout = 8.0
	request.body_size_limit = budget
	add_child(request)
	if request.request(url, headers) != OK:
		request.queue_free()
		return null
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		return null
	return JSON.parse_string(response[3].get_string_from_utf8())

func fetch_manifest() -> Variant:
	if not is_match(REPO_PATTERN, repo):
		return null
	if not preview_channel:
		return await get_json("https://github.com/%s/releases/latest/download/update.json" % repo, 32768)
	var releases: Variant = await get_json("https://api.github.com/repos/%s/releases?per_page=20" % repo,
		1024 * 1024, PackedStringArray(["Accept: application/vnd.github+json"]))
	var tag := select_release(releases)
	if tag.is_empty():
		return null
	var manifest: Variant = await get_json(release_url(tag, "update.json"), 32768)
	return manifest if manifest is Dictionary and manifest.get("tag") == tag else null

func release_url(tag: String, file_name: String) -> String:
	return "https://github.com/%s/releases/download/%s/%s" % [repo, tag, file_name]

func package_entry(info: Variant) -> Dictionary:
	if not info is Dictionary or not info.get("assets", {}) is Dictionary:
		return {}
	var tag := String(info.get("tag", ""))
	var entry: Variant = info.get("assets", {}).get(target_platform)
	if not is_match(TAG_PATTERN, tag) or not entry is Dictionary:
		return {}
	var name := "RIFTCORE-%s.zip" % target_platform
	var bytes := int(entry.get("size", 0))
	var checksum := String(entry.get("sha256", ""))
	if entry.get("file", "") != name or bytes < 1 or bytes > MAX_PACKAGE or not is_match(HASH_PATTERN, checksum):
		return {}
	return {"file": name, "size": bytes, "sha256": checksum}

func download_progress() -> float:
	if not is_instance_valid(transfer) or expected_bytes <= 0:
		return 0.0
	return 100.0 * float(transfer.get_downloaded_bytes()) / expected_bytes

func launcher_entry(info: Dictionary) -> Dictionary:
	var entry: Variant = info.get("launcher", {}).get(target_platform) if info.get("launcher", {}) is Dictionary else null
	var tag := String(info.get("tag", ""))
	if not entry is Dictionary or not is_match(TAG_PATTERN, tag):
		return {}
	var name := "RIFTCORE-Launcher-%s" % target_platform + (".exe" if OS.get_name() == "Windows" else "")
	var build := int(entry.get("build", 0))
	var bytes := int(entry.get("size", 0))
	var hash := String(entry.get("sha256", ""))
	if build < 1 or entry.get("file") != name or bytes < 1 or bytes > MAX_PACKAGE or not is_match(HASH_PATTERN, hash):
		return {}
	return {"file": name, "build": build, "size": bytes, "sha256": hash}

func stage_launcher(info: Dictionary) -> String:
	var entry := launcher_entry(info)
	if entry.is_empty():
		return ""
	var folder := install_root.path_join("downloads").path_join("launcher-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return ""
	var path := folder.path_join(game_filename)
	if not await download_verified(String(info.tag), entry, path):
		return ""
	if OS.get_name() != "Windows" and FileAccess.set_unix_permissions(path, 493) != OK:
		return ""
	return path

func install(info: Dictionary) -> String:
	var entry := package_entry(info)
	if entry.is_empty() or not is_match(REPO_PATTERN, repo):
		return "Invalid update package."
	var tag: String = info.tag
	if tag == LEGACY_MIGRATION_TAG:
		return "This release is a launcher migration."
	var staging := install_root.path_join("downloads")
	var result := DirAccess.make_dir_recursive_absolute(staging)
	if result != OK:
		return "Could not write to the update folder (%s)." % error_string(result)
	var zip_path := staging.path_join("%s-%d-%d.zip" % [tag, OS.get_process_id(), Time.get_ticks_usec()])
	if not await download_verified(tag, entry, zip_path):
		return "Download failed or did not pass the integrity check. Your installed game is unchanged."
	var error := unpack_version(zip_path, tag)
	DirAccess.remove_absolute(zip_path)
	if error.is_empty():
		prune_versions(tag)
	return error

func download_verified(tag: String, entry: Dictionary, path: String) -> bool:
	transfer = HTTPRequest.new()
	transfer.download_file = path
	transfer.timeout = 900.0
	transfer.body_size_limit = MAX_PACKAGE
	expected_bytes = entry.size
	add_child(transfer)
	var response: Array = []
	if transfer.request(release_url(tag, entry.file)) == OK:
		response = await transfer.request_completed
	transfer.queue_free()
	transfer = null
	var valid: bool = not response.is_empty() and response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200
	valid = valid and FileAccess.file_exists(path) and FileAccess.get_size(path) == entry.size and FileAccess.get_sha256(path) == entry.sha256
	if not valid and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return valid

func prune_versions(current: String) -> void:
	var versions := install_root.path_join("versions")
	var directory := DirAccess.open(versions)
	if directory == null:
		return
	var rollback := ""
	for tag in directory.get_directories():
		if tag != LEGACY_MIGRATION_TAG and is_match(TAG_PATTERN, tag) and compare_tags(current, tag):
			if version_is_complete(versions.path_join(tag), [game_filename, "RIFTCORE.pck"]) and compare_tags(tag, rollback):
				rollback = tag
	# Remove only known package files. Unknown files, links and newer versions are retained.
	var allowed := [game_filename, "RIFTCORE.pck", "GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt",
		"GODOTSTEAM_LICENSE.md", "steam_api64.dll", "libgodotsteam.windows.template_release.x86_64.dll",
		"libsteam_api.so", "libgodotsteam.linux.template_release.x86_64.so"]
	for tag in directory.get_directories():
		if tag == rollback or tag == LEGACY_MIGRATION_TAG or not is_match(TAG_PATTERN, tag) or not compare_tags(current, tag) or directory.is_link(tag):
			continue
		var folder := DirAccess.open(versions.path_join(tag))
		if folder == null or not folder.get_directories().is_empty():
			continue
		var files := folder.get_files()
		if not Array(files).all(func(name): return name in allowed and not folder.is_link(name)):
			continue
		# Moving first keeps a locked/running Windows version intact.
		var stale := tag + "-superseded-%d" % Time.get_ticks_usec()
		if directory.rename(tag, stale) != OK:
			continue
		var stale_folder := DirAccess.open(versions.path_join(stale))
		if stale_folder == null:
			continue
		for name in files:
			stale_folder.remove(name)
		directory.remove(stale)

func unpack_version(zip_path: String, tag: String) -> String:
	if not is_match(TAG_PATTERN, tag):
		return "Invalid update version."
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return "Could not read the update archive."
	var expected := [game_filename, "RIFTCORE.pck", "GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt"]
	var steam_runtime := ["GODOTSTEAM_LICENSE.md", "steam_api64.dll", "libgodotsteam.windows.template_release.x86_64.dll"] if game_filename.ends_with(".exe") else ["GODOTSTEAM_LICENSE.md", "libsteam_api.so", "libgodotsteam.linux.template_release.x86_64.so"]
	var entries := zip.get_files()
	if entries.size() == expected.size() + steam_runtime.size():
		expected.append_array(steam_runtime)
	if entries.size() != expected.size() or not expected.all(func(entry): return entry in entries):
		zip.close()
		return "The archive does not contain the expected files for %s." % target_platform
	var versions := install_root.path_join("versions")
	var final_path := versions.path_join(tag)
	var temporary := versions.path_join("%s-install-%d-%d" % [tag, OS.get_process_id(), Time.get_ticks_usec()])
	var result := DirAccess.make_dir_recursive_absolute(temporary)
	if result != OK:
		zip.close()
		return "Could not create the version folder (%s)." % error_string(result)
	var message := ""
	for name in expected:
		var contents := zip.read_file(name)
		var output := FileAccess.open(temporary.path_join(name), FileAccess.WRITE)
		if contents.is_empty() or output == null:
			message = "Could not extract %s. Check free disk space and install permissions." % name
			break
		var stored := output.store_buffer(contents)
		output.flush()
		var write_error := output.get_error()
		output.close()
		if not stored or write_error != OK or FileAccess.get_size(temporary.path_join(name)) != contents.size():
			message = "Could not write %s. Check free disk space and install permissions." % name
			break
	zip.close()
	if message.is_empty() and OS.get_name() != "Windows":
		result = FileAccess.set_unix_permissions(temporary.path_join(game_filename), 493)
		if result != OK:
			message = "Could not make the game executable (%s). Use a writable Linux filesystem." % error_string(result)
	if message.is_empty():
		message = activate_version(temporary, final_path, expected)
	for name in expected:
		var staged := temporary.path_join(name)
		if FileAccess.file_exists(staged):
			DirAccess.remove_absolute(staged)
	if DirAccess.dir_exists_absolute(temporary):
		DirAccess.remove_absolute(temporary)
	return message

func activate_version(staged: String, destination: String, expected: Array) -> String:
	# Never overwrite a running version. A previous incomplete install is moved aside.
	if version_is_complete(destination, expected):
		return ""
	var backup := staged + "-incomplete"
	if DirAccess.dir_exists_absolute(destination):
		var moved := DirAccess.rename_absolute(destination, backup)
		if moved != OK:
			return "Could not move the incomplete update folder (%s)." % error_string(moved)
	var result := DirAccess.rename_absolute(staged, destination)
	if result == OK:
		return ""
	if DirAccess.dir_exists_absolute(backup) and not DirAccess.dir_exists_absolute(destination):
		DirAccess.rename_absolute(backup, destination)
	if version_is_complete(destination, expected):
		return ""
	return "Could not activate the update (%s)." % error_string(result)

func version_is_complete(folder: String, files: Array) -> bool:
	if not files.all(func(name): return FileAccess.file_exists(folder.path_join(name)) and FileAccess.get_size(folder.path_join(name)) > 0):
		return false
	return OS.get_name() == "Windows" or (FileAccess.get_unix_permissions(folder.path_join(game_filename)) & FileAccess.UNIX_EXECUTE_OWNER) != 0

func start_version(tag: String, arguments := PackedStringArray()) -> bool:
	var executable := install_root.path_join("versions").path_join(tag).path_join(game_filename)
	if OS.get_name() == "Linux" and DisplayServer.get_name().to_lower() == "wayland" and arguments.is_empty():
		arguments = PackedStringArray(["--display-driver", "wayland"])
	return OS.create_process(executable, arguments, false) > 0
