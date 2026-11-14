extends Control

const MAX_PACKAGE := 512 * 1024 * 1024
const REPO_PATTERN := "^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9_.-]{1,90}$"
const TAG_PATTERN := "^v[0-9]{1,5}[.][0-9]{1,5}[.][0-9]{1,5}(-preview)?$"
const LEGACY_MIGRATION_TAG := "v0.4.100"
const HASH_PATTERN := "^[0-9a-f]{64}$"

var install_root := ""
var repo := ""
var installed := ""
var next_tag := ""
var bundled_notes := ""
var preview_channel := false
var download_asset: Dictionary = {}
var status: Label
var notes_title: Label
var notes_body: RichTextLabel
var update: Button
var play: Button
var progress: ProgressBar
var transfer: HTTPRequest
var busy := false
var target_platform := ""
var game_filename := ""
var resume_upgrade := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root_arg := OS.get_cmdline_user_args()
	install_root = root_arg[0] if OS.has_feature("editor") and not root_arg.is_empty() else OS.get_executable_path().get_base_dir()
	target_platform = "windows-x64" if OS.get_name() == "Windows" else "linux-x64"
	game_filename = "RIFTCORE.exe" if OS.get_name() == "Windows" else "RIFTCORE"
	var config := ConfigFile.new()
	if config.load(install_root.path_join("updates.cfg")) == OK:
		repo = String(config.get_value("updates", "repository", ""))
		preview_channel = config.get_value("updates", "preview_channel", false)
	resume_upgrade = root_arg.has("--resume-upgrade")
	if OS.get_executable_path().get_base_dir().get_file() == LEGACY_MIGRATION_TAG:
		var bridge_root := install_root.get_base_dir().get_base_dir()
		if install_root.get_base_dir().get_file() == "versions" and FileAccess.file_exists(bridge_root.path_join("updates.cfg")):
			install_root = bridge_root
			build_ui()
			migrate_launcher.call_deferred()
			return
	installed = newest_installed()
	var notes_path := install_root.path_join("PATCH_NOTES.md")
	if installed == config.get_value("updates", "bundled_notes_tag", "") and FileAccess.file_exists(notes_path):
		bundled_notes = FileAccess.get_file_as_string(notes_path)
	build_ui()
	if is_match(REPO_PATTERN, repo):
		check_updates()
	else:
		status.text = "Installed build %s  /  no release channel configured." % installed
		show_fallback_notes("No release channel is configured for this installation.")

func migrate_launcher() -> void:
	status.text = "Upgrading the RIFTCORE launcher…"
	var target := install_root.path_join(game_filename)
	var staged := target + ".upgrade"
	var backup := target + ".previous"
	if DirAccess.copy_absolute(OS.get_executable_path(), staged, 493) != OK:
		status.text = "Could not stage the launcher update. Reopen the launcher to retry."
		return
	var moved := false
	for attempt in 60:
		if DirAccess.rename_absolute(target, backup) == OK:
			moved = true
			break
		await get_tree().create_timer(0.1).timeout
	if not moved:
		status.text = "Close any other RIFTCORE launcher windows, then retry the update."
		return
	if DirAccess.rename_absolute(staged, target) != OK:
		DirAccess.rename_absolute(backup, target)
		status.text = "Could not replace the launcher. Reopen it to retry."
		return
	var config := ConfigFile.new()
	var config_path := install_root.path_join("updates.cfg")
	if config.load(config_path) != OK:
		DirAccess.remove_absolute(target)
		DirAccess.rename_absolute(backup, target)
		status.text = "The installed update settings could not be read."
		return
	config.set_value("updates", "preview_channel", true)
	if config.save(config_path) != OK:
		DirAccess.remove_absolute(target)
		DirAccess.rename_absolute(backup, target)
		status.text = "The update settings could not be saved. Check the installation permissions."
		return
	if OS.create_process(target, relaunched_arguments()) <= 0:
		DirAccess.remove_absolute(target)
		DirAccess.rename_absolute(backup, target)
		status.text = "The launcher could not restart. Reopen it to retry."
		return
	DirAccess.remove_absolute(backup)
	get_tree().quit()

func relaunched_arguments() -> PackedStringArray:
	if DisplayServer.get_name() == "headless":
		return PackedStringArray(["--headless", "--quit-after", "60"])
	return PackedStringArray(["--", "--resume-upgrade"])

func build_ui() -> void:
	var font_theme := Theme.new()
	font_theme.default_font = preload("res://branding/Barlow-Medium.ttf")
	theme = font_theme
	var shade := ColorRect.new()
	shade.color = Color("091526")
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 28)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margins.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	stack.add_child(header)
	add_brand_art(header, preload("res://branding/riftcore-icon.svg"), Vector2(92, 92))
	add_brand_art(header, preload("res://branding/riftcore-wordmark.svg"), Vector2(400, 82))
	var version := Label.new()
	version.text = "INSTALLER  0.2"
	version.add_theme_color_override("font_color", Color("ff78cb"))
	stack.add_child(version)
	stack.add_child(HSeparator.new())
	status = Label.new()
	status.text = "Checking for updates…"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 53
	status.add_theme_color_override("font_color", Color("bfd8eb"))
	stack.add_child(status)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 20
	progress.add_theme_stylebox_override("fill", panel_style(Color("1db7d4"), Color("74efff")))
	progress.hide()
	stack.add_child(progress)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	play = launcher_button(actions, "Play installed", Color("21324b"), Color("637d99"))
	play.disabled = installed.is_empty()
	play.pressed.connect(launch_game)
	update = launcher_button(actions, "Update and play", Color("103b50"), Color("47e8ff"))
	update.disabled = true
	update.pressed.connect(apply_update)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", panel_style(Color("101e32"), Color("365d79")))
	stack.add_child(panel)
	var note_stack := VBoxContainer.new()
	note_stack.add_theme_constant_override("separation", 6)
	panel.add_child(note_stack)
	notes_title = Label.new()
	notes_title.add_theme_color_override("font_color", Color("47e8ff"))
	note_stack.add_child(notes_title)
	notes_body = RichTextLabel.new()
	notes_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_body.focus_mode = Control.FOCUS_ALL
	notes_body.bbcode_enabled = false
	notes_body.selection_enabled = true
	note_stack.add_child(notes_body)
	show_fallback_notes("Patch notes will appear after the release check.")
	if not play.disabled:
		play.grab_focus()

func show_fallback_notes(message: String) -> void:
	show_notes(installed, bundled_notes if not bundled_notes.is_empty() else message)

func show_notes(tag: String, notes: String) -> void:
	notes_title.text = "PATCH NOTES  /  " + tag if not tag.is_empty() else "PATCH NOTES"
	notes_body.clear()
	if notes.strip_edges().is_empty():
		notes_body.add_text("No patch notes were published for this build.")
		return
	for line in notes.split("\n"):
		if line.begins_with("# "):
			continue
		if line.begins_with("## "):
			notes_body.push_bold()
			notes_body.push_color(Color("8eeaff"))
			notes_body.add_text(line.substr(3))
			notes_body.pop()
			notes_body.pop()
		elif line.begins_with("- "):
			notes_body.add_text("• " + line.substr(2))
		else:
			notes_body.add_text(line)
		notes_body.newline()
	notes_body.scroll_to_line(0)

func add_brand_art(host: Container, art: Texture2D, dimensions: Vector2) -> void:
	var picture := TextureRect.new()
	picture.texture = art
	picture.custom_minimum_size = dimensions
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.add_child(picture)

func panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	return style

func launcher_button(host: Container, title: String, fill: Color, accent: Color) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(180, 47)
	var idle := panel_style(fill, accent)
	var purple := Color("bf82ff")
	var highlight := panel_style(fill.lerp(purple, 0.29), purple)
	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", highlight)
	button.focus_entered.connect(func(): button.add_theme_stylebox_override("normal", highlight))
	button.focus_exited.connect(func(): button.add_theme_stylebox_override("normal", idle))
	button.add_theme_stylebox_override("pressed", panel_style(fill.darkened(0.18), accent))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", panel_style(Color("101e32"), Color("35425a")))
	host.add_child(button)
	return button

func _process(_delta: float) -> void:
	if busy and is_instance_valid(transfer) and not download_asset.is_empty():
		progress.value = 100.0 * float(transfer.get_downloaded_bytes()) / float(download_asset.size)

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
		if FileAccess.file_exists(folder.path_join(game_filename)) and FileAccess.file_exists(folder.path_join("RIFTCORE.pck")) and compare_tags(tag, best):
			best = tag
	return best

func check_updates() -> void:
	var release_tag := ""
	if preview_channel:
		release_tag = await find_preview_release()
	var request := HTTPRequest.new()
	request.timeout = 5.5
	request.body_size_limit = 32768
	add_child(request)
	var url := "https://github.com/%s/releases/latest/download/update.json" % repo
	if not release_tag.is_empty():
		url = "https://github.com/%s/releases/download/%s/update.json" % [repo, release_tag]
	if request.request(url) != OK:
		request.queue_free()
		show_fallback_notes("Patch notes are unavailable offline.")
		status.text = "Update check unavailable. You can still play installed."
		return
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		show_fallback_notes("Patch notes are unavailable offline.")
		status.text = "Update server unavailable. You can still play installed."
		return
	apply_manifest(JSON.parse_string(response[3].get_string_from_utf8()))

func find_preview_release() -> String:
	var request := HTTPRequest.new()
	request.timeout = 5.5
	request.body_size_limit = 1024 * 1024
	add_child(request)
	var url := "https://api.github.com/repos/%s/releases?per_page=20" % repo
	if request.request(url, ["Accept: application/vnd.github+json"]) != OK:
		request.queue_free()
		return ""
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		return ""
	return select_release(JSON.parse_string(response[3].get_string_from_utf8()))

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

func apply_manifest(info: Variant) -> void:
	if not info is Dictionary or not info.get("assets", {}) is Dictionary:
		status.text = "Invalid release manifest."
		return
	var tag := String(info.get("tag", ""))
	var assets: Dictionary = info.get("assets", {})
	if tag == LEGACY_MIGRATION_TAG:
		show_fallback_notes("The launcher migration is complete. Game updates are available on the preview channel.")
		status.text = "Play your installed game or check again when the preview channel is available."
		return
	var entry = assets.get(target_platform)
	if not is_match(TAG_PATTERN, tag) or not entry is Dictionary:
		status.text = "This release does not match your platform."
		return
	var name := "RIFTCORE-%s.zip" % target_platform
	var bytes := int(entry.get("size", 0))
	if entry.get("file", "") != name or bytes < 1 or bytes > MAX_PACKAGE or not is_match(HASH_PATTERN, String(entry.get("sha256", ""))):
		status.text = "Invalid release package details."
		return
	if not installed.is_empty() and compare_tags(installed, tag):
		status.text = "%s is newer than the public release." % installed
		return
	var latest_notes = info.get("notes", "")
	if latest_notes is String and not latest_notes.is_empty():
		show_notes(tag, latest_notes)
	else:
		show_fallback_notes("No patch notes were published for this build.")
	if not compare_tags(tag, installed):
		status.text = "%s is up to date." % installed
		return
	next_tag = tag
	download_asset = {"file": name, "size": bytes, "sha256": String(entry.sha256)}
	status.text = "%s is available. Installed: %s." % [tag, installed if not installed.is_empty() else "none"]
	update.disabled = false
	if resume_upgrade:
		resume_upgrade = false
		apply_update()

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
	var steam_runtime := ["GODOTSTEAM_LICENSE.md", "steam_api64.dll", "libgodotsteam.windows.template_release.x86_64.dll"] if game_filename.ends_with(".exe") else ["GODOTSTEAM_LICENSE.md", "libsteam_api.so", "libgodotsteam.linux.template_release.x86_64.so"]
	if entries.size() == expected.size() + steam_runtime.size():
		expected.append_array(steam_runtime)
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
	var arguments := PackedStringArray()
	if OS.get_name() == "Linux" and DisplayServer.get_name().to_lower() == "wayland":
		arguments = PackedStringArray(["--display-driver", "wayland"])
	if OS.create_process(executable, arguments, false) <= 0:
		fail_update("The installed game could not launch.")
	else:
		get_tree().quit()

