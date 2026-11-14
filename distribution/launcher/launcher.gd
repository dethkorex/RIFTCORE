extends Control

const UpdateClient := preload("res://update_client.gd")

const LAUNCHER_BUILD := 3

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
var notes_title: Label
var notes_body: RichTextLabel
var update: Button
var play: Button
var progress: ProgressBar
var busy := false
var resume_upgrade := false

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
	var notes_path := install_root.path_join("PATCH_NOTES.md")
	if installed == config.get_value("updates", "bundled_notes_tag", "") and FileAccess.file_exists(notes_path):
		bundled_notes = FileAccess.get_file_as_string(notes_path)
	build_ui()
	if client.is_match(UpdateClient.REPO_PATTERN, repo):
		check_updates()
	else:
		status.text = "Installed build %s  /  no release channel configured." % installed
		show_fallback_notes("No release channel is configured for this installation.")

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
	return PackedStringArray(["--", "--resume-upgrade"])

func build_ui() -> void:
	var font_theme := Theme.new()
	font_theme.default_font = preload("res://branding/BarlowCondensed-ExtraBoldItalic.ttf")
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
	version.text = "LAUNCHER  0.2  /  BUILD %d" % LAUNCHER_BUILD
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
	if busy:
		progress.value = client.download_progress()

func check_updates() -> void:
	var manifest: Variant = await client.fetch_manifest()
	if manifest == null:
		show_fallback_notes("Patch notes are unavailable offline.")
		status.text = "Update server unavailable. You can still play installed."
		return
	apply_manifest(manifest)

func apply_manifest(info: Variant) -> void:
	if not info is Dictionary or not info.get("assets", {}) is Dictionary:
		status.text = "Invalid release manifest."
		return
	var tag := String(info.get("tag", ""))
	if tag == UpdateClient.LEGACY_MIGRATION_TAG:
		show_fallback_notes("The launcher migration is complete. Game updates are available on the preview channel.")
		status.text = "Play your installed game or check again when the preview channel is available."
		return
	if client.package_entry(info).is_empty():
		status.text = "This release does not have a valid package for your platform."
		return
	if not installed.is_empty() and client.compare_tags(installed, tag):
		status.text = "%s is newer than the public release." % installed
		return
	var latest_notes = info.get("notes", "")
	if latest_notes is String and not latest_notes.is_empty():
		show_notes(tag, latest_notes)
	else:
		show_fallback_notes("No patch notes were published for this build.")
	launcher_update = int(client.launcher_entry(info).get("build", 0)) > LAUNCHER_BUILD
	if not client.compare_tags(tag, installed) and not launcher_update:
		status.text = "%s is up to date." % installed
		if resume_upgrade:
			launch_game()
		return
	next_tag = tag
	update_manifest = info
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
	if launcher_update:
		status.text = "Updating the launcher…"
		var replacement := await client.stage_launcher(update_manifest)
		if replacement.is_empty() or OS.create_process(replacement, PackedStringArray(["--", "--replace-launcher"])) <= 0:
			fail_update("Could not update the launcher. You can still play installed.")
			return
		get_tree().quit()
		return
	var error := await client.install(update_manifest)
	if not error.is_empty():
		fail_update(error)
		return
	installed = next_tag
	busy = false
	launch_game()

func fail_update(message: String) -> void:
	busy = false
	progress.hide()
	play.disabled = installed.is_empty()
	update.disabled = false
	status.text = message

func launch_game() -> void:
	if installed.is_empty():
		return
	if not client.start_version(installed):
		fail_update("The installed game could not launch. Check its file permissions and dependencies.")
	else:
		get_tree().quit()
