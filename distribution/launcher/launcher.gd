extends Control

const MAX_PACKAGE := 512 * 1024 * 1024
const REPO_PATTERN := "^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9_.-]{1,90}$"
const TAG_PATTERN := "^v[0-9]{1,5}[.][0-9]{1,5}[.][0-9]{1,5}$"
const HASH_PATTERN := "^[0-9a-f]{64}$"

var install_root := ""
var repo := ""
var installed := ""
var next_tag := ""
var download_asset: Dictionary = {}
var status: Label
var update: Button
var play: Button
var progress: ProgressBar
var transfer: HTTPRequest
var busy := false
var target_platform := ""
var game_filename := ""

func _ready() -> void:
	var root_arg := OS.get_cmdline_user_args()
	install_root = root_arg[0] if OS.has_feature("editor") and not root_arg.is_empty() else OS.get_executable_path().get_base_dir()
	target_platform = "windows-x64" if OS.get_name() == "Windows" else "linux-x64"
	game_filename = "RIFTCORE.exe" if OS.get_name() == "Windows" else "RIFTCORE"
	var config := ConfigFile.new()
	if config.load(install_root.path_join("updates.cfg")) == OK:
		repo = String(config.get_value("updates", "repository", ""))
	installed = newest_installed()
	build_ui()
	if is_match(REPO_PATTERN, repo):
		check_updates()
	else:
		status.text = "Installed build %s  /  no release channel configured." % installed

func build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color("081528")
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 36)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 17)
	margins.add_child(stack)
	var logo := Label.new()
	logo.text = "RIFTCORE"
	logo.add_theme_color_override("font_color", Color("58eaff"))
	logo.add_theme_font_size_override("font_size", 47)
	stack.add_child(logo)
	var sub := Label.new()
	sub.text = "ROGUE PROTOCOL   /   PLAYTEST LAUNCHER"
	sub.add_theme_color_override("font_color", Color("ad8af0"))
	stack.add_child(sub)
	status = Label.new()
	status.text = "Checking for updates…"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 53
	stack.add_child(status)
	progress = ProgressBar.new()
	progress.hide()
	stack.add_child(progress)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	play = Button.new()
	play.text = "Play installed"
	play.custom_minimum_size = Vector2(160, 49)
	play.disabled = installed.is_empty()
	play.pressed.connect(launch_game)
	actions.add_child(play)
	update = Button.new()
	update.text = "Update and play"
	update.custom_minimum_size = Vector2(180, 49)
	update.disabled = true
	update.pressed.connect(apply_update)
	actions.add_child(update)
	if not play.disabled:
		play.grab_focus()

func _process(_delta: float) -> void:
	if busy and is_instance_valid(transfer) and not download_asset.is_empty():
		progress.value = 100.0 * float(transfer.get_downloaded_bytes()) / float(download_asset.size)

func is_match(pattern: String, value: String) -> bool:
	var regex := RegEx.new()
	return regex.compile(pattern) == OK and regex.search(value) != null

func compare_tags(a: String, b: String) -> bool:
	if b.is_empty():
		return true
	var left := a.substr(1).split(".")
	var right := b.substr(1).split(".")
	for i in range(3):
		var n := int(left[i])
		var m := int(right[i])
		if n != m:
			return n > m
	return false

func newest_installed() -> String:
	var best := ""
	var versions := install_root.path_join("versions")
	var dir := DirAccess.open(versions)
	if dir == null:
		return best
	for tag in dir.get_directories():
		if not is_match(TAG_PATTERN, tag):
			continue
		var folder := versions.path_join(tag)
		if FileAccess.file_exists(folder.path_join(game_filename)) and FileAccess.file_exists(folder.path_join("RIFTCORE.pck")) and compare_tags(tag, best):
			best = tag
	return best

func check_updates() -> void:
	var request := HTTPRequest.new()
	request.timeout = 5.5
	request.body_size_limit = 32768
	add_child(request)
	var url := "https://github.com/%s/releases/latest/download/update.json" % repo
	if request.request(url) != OK:
		request.queue_free()
		status.text = "Update check unavailable. You can still play installed."
		return
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		status.text = "Update server unavailable. You can still play installed."
		return
	var info = JSON.parse_string(response[3].get_string_from_utf8())
	if not info is Dictionary or not info.get("assets", {}) is Dictionary:
		status.text = "Invalid release manifest."
		return
	var tag := String(info.get("tag", ""))
	var entry = info.assets.get(target_platform)
	if not is_match(TAG_PATTERN, tag) or not entry is Dictionary:
		status.text = "This release does not match your platform."
		return
	var name := "RIFTCORE-%s.zip" % target_platform
	var bytes := int(entry.get("size", 0))
	if entry.get("file", "") != name or bytes < 1 or bytes > MAX_PACKAGE or not is_match(HASH_PATTERN, String(entry.get("sha256", ""))):
		status.text = "Invalid release package details."
		return
	if not compare_tags(tag, installed):
		status.text = "%s is up to date." % installed
		return
	next_tag = tag
	download_asset = {"file": name, "size": bytes, "sha256": String(entry.sha256)}
	status.text = "%s is available. Installed: %s." % [tag, installed if not installed.is_empty() else "none"]
	update.disabled = false

func apply_update() -> void:
	if busy or next_tag.is_empty():
		return
	busy = true
	update.disabled = true
	play.disabled = true
	progress.show()
	progress.value = 0
	status.text = "Downloading %s…" % next_tag
	var staging := install_root.path_join("downloads")
	if DirAccess.make_dir_recursive_absolute(staging) != OK:
		fail_update("Could not open the download directory.")
		return
	var zip_path := staging.path_join(next_tag + ".zip")
	transfer = HTTPRequest.new()
	transfer.download_file = zip_path
	transfer.timeout = 145.0
	transfer.body_size_limit = MAX_PACKAGE
	add_child(transfer)
	var url := "https://github.com/%s/releases/download/%s/%s" % [repo, next_tag, download_asset.file]
	if transfer.request(url) != OK:
		transfer.queue_free()
		fail_update("Could not start the download.")
		return
	var response: Array = await transfer.request_completed
	transfer.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		DirAccess.remove_absolute(zip_path)
		fail_update("Download failed. Your installed game is unchanged.")
		return
	var file := FileAccess.open(zip_path, FileAccess.READ)
	var correct_size: bool = file != null and file.get_length() == download_asset.size
	if file:
		file.close()
	if not correct_size or FileAccess.get_sha256(zip_path) != download_asset.sha256:
		DirAccess.remove_absolute(zip_path)
		fail_update("The download did not pass the integrity check.")
		return
	if not unpack_version(zip_path, next_tag):
		DirAccess.remove_absolute(zip_path)
		fail_update("Could not install the update. Your installed game is unchanged.")
		return
	DirAccess.remove_absolute(zip_path)
	installed = next_tag
	busy = false
	launch_game()

func unpack_version(zip_path: String, tag: String) -> bool:
	if not is_match(TAG_PATTERN, tag):
		return false
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return false
	var expected := [game_filename, "RIFTCORE.pck", "GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt"]
	var entries := zip.get_files()
	if entries.size() != expected.size():
		zip.close()
		return false
	for name in expected:
		if not name in entries:
			zip.close()
			return false
	var versions := install_root.path_join("versions")
	var final_path := versions.path_join(tag)
	var temporary := versions.path_join("%s-install-%d" % [tag, Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(temporary) != OK:
		zip.close()
		return false
	var ok := true
	for name in expected:
		var contents := zip.read_file(name)
		var output := FileAccess.open(temporary.path_join(name), FileAccess.WRITE)
		if contents.is_empty() or not output:
			ok = false
			break
		output.store_buffer(contents)
		output.close()
	zip.close()
	if ok and OS.get_name() != "Windows":
		ok = FileAccess.set_unix_permissions(temporary.path_join(game_filename), 493) == OK
	if ok:
		ok = DirAccess.rename_absolute(temporary, final_path) == OK
	if not ok:
		for name in expected:
			DirAccess.remove_absolute(temporary.path_join(name))
		DirAccess.remove_absolute(temporary)
	return ok

func fail_update(message: String) -> void:
	busy = false
	progress.hide()
	play.disabled = installed.is_empty()
	update.disabled = false
	status.text = message

func launch_game() -> void:
	if installed.is_empty():
		return
	var executable := install_root.path_join("versions").path_join(installed).path_join(game_filename)
	if OS.create_process(executable, [], false) <= 0:
		fail_update("The installed game could not launch.")
	else:
		get_tree().quit()

