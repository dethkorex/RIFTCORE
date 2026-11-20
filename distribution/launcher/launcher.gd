extends Control

const UpdateClient := preload("res://update_client.gd")

const LAUNCHER_BUILD := 7
const SteamArtwork := preload("res://steam_artwork.gd")

var client := UpdateClient.new()
var install_root := ""
var repo := ""
var installed := ""
var next_tag := ""
var update_manifest: Dictionary
var launcher_update := false
var bundled_notes := ""
var preview_channel := false
var status: Label
var build_label: Label
var notes_title: Label
var notes_body: RichTextLabel
var update: Button
var play: Button
var progress: ProgressBar
var busy := false
var resume_upgrade := false
var checking := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root_arg := OS.get_cmdline_user_args()
	install_root = root_arg[0] if OS.has_feature("editor") and not root_arg.is_empty() else OS.get_executable_path().get_base_dir()
	add_child(client)
	var config := ConfigFile.new()
	if config.load(install_root.path_join("updates.cfg")) == OK:
		repo = String(config.get_value("updates", "repository", ""))
		preview_channel = config.get_value("updates", "preview_channel", false)
	resume_upgrade = root_arg.has("--resume-upgrade")
	for argument in root_arg:
		if argument.begins_with("--cleanup-launcher="):
			clean_launcher_download.call_deferred(argument.trim_prefix("--cleanup-launcher="))
	if root_arg.has("--replace-launcher"):
		var folder := OS.get_executable_path().get_base_dir()
		if folder.get_file().begins_with("launcher-") and folder.get_base_dir().get_file() == "downloads":
			install_root = folder.get_base_dir().get_base_dir()
			build_ui()
			migrate_launcher.call_deferred(true)
			return
	if OS.get_executable_path().get_base_dir().get_file() == UpdateClient.LEGACY_MIGRATION_TAG:
		var bridge_root := install_root.get_base_dir().get_base_dir()
		if install_root.get_base_dir().get_file() == "versions" and FileAccess.file_exists(bridge_root.path_join("updates.cfg")):
			install_root = bridge_root
			build_ui()
			migrate_launcher.call_deferred()
			return
	client.install_root = install_root
	client.repo = repo
	client.preview_channel = preview_channel
	installed = client.newest_installed()
	if DisplayServer.get_name() != "headless":
		SteamArtwork.apply.call_deferred(install_root)
	var notes_path := install_root.path_join("PATCH_NOTES.md")
	if installed == config.get_value("updates", "bundled_notes_tag", "") and FileAccess.file_exists(notes_path):
		bundled_notes = FileAccess.get_file_as_string(notes_path)
	build_ui()
	if client.is_match(UpdateClient.REPO_PATTERN, repo):
		check_updates()
	else:
		status.text = "No release channel is configured."
		show_fallback_notes("")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		client.cancel_download()

func clean_launcher_download(folder: String) -> void:
	if not client.is_match("^launcher-[0-9]+-[0-9]+$", folder):
		return
	var downloads := install_root.path_join("downloads")
	var directory := DirAccess.open(downloads)
	if directory == null or directory.is_link(folder):
		return
	var staging := DirAccess.open(downloads.path_join(folder))
	if staging == null or staging.is_link(client.game_filename):
		return
	for attempt in 35:
		if not staging.file_exists(client.game_filename) or staging.remove(client.game_filename) == OK:
			directory.remove(folder)
			return
		await get_tree().create_timer(.12).timeout

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func migrate_launcher(self_update := false) -> void:
	status.text = "Upgrading the RIFTCORE launcher…"
	var target := install_root.path_join(client.game_filename)
	var staged := target + ".upgrade"
	var backup := target + ".previous"
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
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
	if not self_update:
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
	if not self_update:
		DirAccess.remove_absolute(backup)
	get_tree().quit()

func relaunched_arguments() -> PackedStringArray:
	if DisplayServer.get_name() == "headless":
		return PackedStringArray(["--headless", "--quit-after", "60"])
	var args := PackedStringArray(["--"])
	if not OS.get_cmdline_user_args().has("--no-autoplay"):
		args.append("--resume-upgrade")
	var folder := OS.get_executable_path().get_base_dir().get_file()
	if client.is_match("^launcher-[0-9]+-[0-9]+$", folder):
		args.append("--cleanup-launcher=" + folder)
	return args

func build_ui() -> void:
	var font_theme := Theme.new()
	font_theme.default_font_size = 16
	theme = font_theme
	var shade := ColorRect.new()
	shade.color = Color("070e1d")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 22)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margins.add_child(layout)

	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", panel_style(Color("111e34"), Color("45d9f4")))
	layout.add_child(banner)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	banner.add_child(header)
	add_brand_art(header, preload("res://branding/riftcore-icon.svg"), Vector2(56, 56))
	add_brand_art(header, preload("res://branding/riftcore-wordmark.svg"), Vector2(280, 48))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var version := label(header, "Launcher 0.3", 18, Color("b3ccdf"), true)
	version.autowrap_mode = TextServer.AUTOWRAP_OFF
	version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	layout.add_child(columns)
	var start := card(columns, Color("172a42"), Color("355974"))
	start.custom_minimum_size.x = 270
	label(start, "GAME STATUS", 23, Color("55e9ff"), true)
	build_label = label(start, "", 16, Color("b3ccdf"))
	refresh_build_label()
	var splash := load("res://assets/ui/steam/hero.jpg") as Texture2D
	if splash:
		var art := TextureRect.new()
		art.texture = splash
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size.y = 108
		art.modulate = Color("b9c9dc")
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start.add_child(art)
	var description := FileAccess.get_file_as_string("res://branding/DESCRIPTION.txt").strip_edges()
	if not description.is_empty():
		label(start, description, 15, Color("b3ccdf"))
	start.add_child(HSeparator.new())
	status = label(start, "Checking for updates…", 17, Color("e8f5ff"))
	status.custom_minimum_size.y = 56

	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 18
	progress.show_percentage = true
	progress.add_theme_stylebox_override("background", panel_style(Color("0d1a2c"), Color("345573"), false))
	progress.add_theme_stylebox_override("fill", panel_style(Color("13758e"), Color("50d0eb"), false))
	progress.hide()
	start.add_child(progress)

	var flexible := Control.new()
	flexible.size_flags_vertical = Control.SIZE_EXPAND_FILL
	start.add_child(flexible)
	play = launcher_button(start, "Play", Color("126484"), Color("5ce9fc"))
	play.disabled = installed.is_empty()
	play.pressed.connect(launch_game)
	update = launcher_button(start, "Retry update", Color("182c45"), Color("577494"))
	update.hide()
	update.pressed.connect(check_updates)

	var notes := card(columns, Color("101d31"), Color("34536e"))
	notes.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_title = label(notes, "PATCH NOTES", 23, Color("5be9fc"), true)
	notes_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	notes.add_child(HSeparator.new())
	notes_body = RichTextLabel.new()
	notes_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_body.add_theme_constant_override("line_separation", 7)
	notes_body.add_theme_color_override("default_color", Color("e1eef9"))
	notes_body.focus_mode = Control.FOCUS_ALL
	notes_body.selection_enabled = true
	notes.add_child(notes_body)
	show_fallback_notes("Checking the release channel…")
	if not play.disabled:
		play.grab_focus()

func card(host: Container, fill: Color, border: Color) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", panel_style(fill, border))
	host.add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	frame.add_child(content)
	return content

func label(host: Container, title: String, size: int, color: Color, heading := false) -> Label:
	var entry := Label.new()
	entry.text = title
	entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_theme_font_size_override("font_size", size)
	entry.add_theme_color_override("font_color", color)
	if heading:
		entry.add_theme_font_override("font", preload("res://branding/BarlowCondensed-ExtraBoldItalic.ttf"))
	host.add_child(entry)
	return entry

func refresh_build_label() -> void:
	build_label.text = "Installed  ·  %s" % (installed if not installed.is_empty() else "None")

func show_fallback_notes(message: String) -> void:
	show_notes(installed, bundled_notes if not bundled_notes.is_empty() else message)

func show_notes(tag: String, notes: String) -> void:
	notes_title.text = "PATCH NOTES  /  " + tag if not tag.is_empty() else "PATCH NOTES"
	notes_body.clear()
	if notes.strip_edges().is_empty():
		notes_body.add_text("No patch notes were published for this build.")
		return
	for line in notes.split("\n"):
		if line.is_empty() or line.begins_with("# "):
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

func panel_style(fill: Color, border: Color, padded := true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 3
	if padded:
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
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
	if busy:
		progress.value = client.download_progress()

func check_updates() -> void:
	if checking or busy:
		return
	checking = true
	play.disabled = true
	update.hide()
	status.text = "Checking for updates…"
	var manifest: Variant = await client.fetch_manifest()
	checking = false
	if manifest == null:
		show_fallback_notes("Connect to check for new versions and patch notes.")
		fail_update("Couldn't reach the update server. Try again when you're online." if installed.is_empty() else
			"Update server unavailable. Your installed game is ready to play.")
		return
	apply_manifest(manifest)

func apply_manifest(info: Variant) -> void:
	if not info is Dictionary:
		fail_update("The update server returned an invalid release.")
		return
	var tag := String(info.get("tag", ""))
	if tag == UpdateClient.LEGACY_MIGRATION_TAG:
		fail_update("Waiting for the preview release channel.")
		return
	if not installed.is_empty() and client.compare_tags(installed, tag):
		status.text = "%s is ready." % installed
		play.disabled = false
		play.grab_focus()
		return
	if client.package_entry(info).is_empty():
		fail_update("The newest release has no valid game package for this platform.")
		return
	var latest_notes = info.get("notes", "")
	if latest_notes is String and not latest_notes.is_empty():
		show_notes(tag, latest_notes)
	else:
		show_fallback_notes("")
	launcher_update = int(client.launcher_entry(info).get("build", 0)) > LAUNCHER_BUILD
	if client.compare_tags(tag, installed) or launcher_update:
		next_tag = tag
		update_manifest = info
		apply_update()
		return
	status.text = "Ready to play. Your game is up to date."
	play.disabled = false
	play.grab_focus()
	if resume_upgrade:
		launch_game()

func apply_update() -> void:
	if busy or next_tag.is_empty():
		return
	busy = true
	update.hide()
	play.disabled = true
	progress.show()
	progress.value = 0
	status.text = "Downloading %s…" % next_tag
	if launcher_update:
		status.text = "Updating the launcher…"
		var replacement := await client.stage_launcher(update_manifest)
		var arguments := PackedStringArray(["--", "--replace-launcher"])
		if not resume_upgrade:
			arguments.append("--no-autoplay")
		if replacement.is_empty() or OS.create_process(replacement, arguments) <= 0:
			fail_update("Couldn't install the launcher update.")
			return
		get_tree().quit()
		return
	var error := await client.install(update_manifest)
	if not error.is_empty():
		fail_update(error)
		return
	installed = next_tag
	refresh_build_label()
	busy = false
	progress.hide()
	play.disabled = false
	play.grab_focus()
	status.text = "Ready to play. Your game is up to date."
	if resume_upgrade:
		launch_game()

func fail_update(message: String) -> void:
	busy = false
	progress.hide()
	play.disabled = installed.is_empty()
	update.show()
	if play.disabled:
		update.grab_focus()
	else:
		play.grab_focus()
	status.text = message

func launch_game() -> void:
	if busy or installed.is_empty():
		return
	if not client.start_version(installed):
		fail_update("The installed game could not launch. Check its file permissions and dependencies.")
	else:
		get_tree().quit()
