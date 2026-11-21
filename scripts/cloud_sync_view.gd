extends RefCounted

const UI := preload("res://scripts/rift_ui.gd")
const STAGES := ["Authenticating profile", "Syncing save slots", "Verifying operator data"]
const GREEN := Color("52ebbb")

static func build(columns: HBoxContainer, directory) -> void:
	var stage := UI.profile_panel(columns, 2.65)
	var status := UI.profile_panel(columns, 1.0)
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	var texture := cloud_icon()
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	stage.add_child(title_row)
	add_badge(title_row, texture, 68)
	var title := UI.column(title_row, 3)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.label(title, "Checking Cloud Saves", 38, UI.CYAN)
	UI.label(title, "Checking for cloud saves linked to your RIFTCORE profile.", 19, UI.MUTED)
	stage.add_child(HSeparator.new())

	var meter := UI.equipment_card(UI.CYAN)
	stage.add_child(meter)
	var segments := Control.new()
	segments.custom_minimum_size.y = 23
	segments.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(segments)
	var rows: Array[PanelContainer] = []
	var marks: Array[Label] = []
	var captions: Array[Label] = []
	for text in STAGES:
		var plate := PanelContainer.new()
		plate.custom_minimum_size.y = 43
		stage.add_child(plate)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		plate.add_child(row)
		var mark := UI.profile_label(row, "", 22)
		mark.custom_minimum_size.x = 30
		marks.append(mark)
		var label := UI.profile_label(row, text, 20)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		captions.append(UI.profile_label(row, "", 16))
		rows.append(plate)

	UI.label(status, "Cloud Save Status", 26, UI.CYAN)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 9)
	status.add_child(status_row)
	add_badge(status_row, texture, 43)
	var connection := UI.column(status_row, 2)
	connection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mode := UI.label(connection, "", 19, Color("ffd079"))
	var account := String(directory.username)
	var cloud = directory.progress
	var marker: ConfigFile = cloud.marker()
	var stamp := String(marker.get_value("sync", "checked_at", "")) if marker.get_value("sync", "account", "") == account else ""
	add_fact(status, "LAST SYNC", "No recorded sync" if stamp.is_empty() else stamp.replace("T", " ").left(16) + " UTC")
	add_fact(status, "CONNECTED PROFILE", account if not account.is_empty() else "Awaiting sign-in")
	var slots := add_fact(status, "CLOUD SAVE SLOTS", "Checking…")
	var tip := UI.equipment_card(Color("e0a34c"))
	status.add_child(tip)
	UI.label(tip, "If the saves differ, you can choose which copy to keep.", 16, UI.MUTED)

	segments.draw.connect(func():
		var width := segments.size.x / 24.0
		var filled := 8 * int(cloud.roster_check_stage)
		for index in 24:
			var x := index * width
			var left := Vector2(x, segments.size.y)
			var slant := Vector2(minf(8.0, width * 0.48), -segments.size.y)
			var span := Vector2(width - 2.0 - slant.x, 0)
			segments.draw_colored_polygon(PackedVector2Array([left, left + span, left + span + slant, left + slant]),
				UI.CYAN if index < filled else Color("193749"))
	)
	var refresh := func():
		var current: int = cloud.roster_check_stage
		mode.text = "SYNCING" if current == 1 else "VERIFYING"
		if current == 2:
			var data: Dictionary = cloud.remote.get("data", {})
			var operator_slots: Dictionary = data.get("operators", {})
			slots.text = "%d saved" % operator_slots.size()
		for index in rows.size():
			var tint := GREEN if index < current else (UI.CYAN if index == current else UI.MUTED)
			var fill := Color("0b2d38") if index <= current else Color("102033")
			rows[index].add_theme_stylebox_override("panel", UI.profile_frame(fill, tint, Vector2(12, 4), index == current))
			marks[index].text = "✓" if index < current else ("◌" if index == current else "◇")
			captions[index].text = "Complete" if index < current else ("In Progress" if index == current else "Pending")
			for label in [marks[index], captions[index]]:
				label.add_theme_color_override("font_color", tint)
		segments.queue_redraw()
	cloud.roster_check_changed.connect(refresh)
	stage.tree_exiting.connect(func(): cloud.roster_check_changed.disconnect(refresh), CONNECT_ONE_SHOT)
	refresh.call()

static func add_fact(parent: VBoxContainer, caption: String, text: String) -> Label:
	parent.add_child(HSeparator.new())
	UI.profile_label(parent, caption, 14, UI.MUTED)
	return UI.label(parent, text, 18)

static func add_badge(parent: HBoxContainer, texture: Texture2D, extent: int) -> void:
	var badge := UI.equipment_card(UI.CYAN)
	badge.custom_minimum_size = Vector2(extent, extent)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(badge)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.add_child(icon)

static func cloud_icon() -> Texture2D:
	var icon := Image.new()
	icon.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 48 48"><g fill="none" stroke="#55e7ff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M15 32h-3a9 9 0 0 1-1-18 13 13 0 0 1 25 1 8.5 8.5 0 0 1 0 17h-3"/><path d="M20 41V25l-4 4m4-4 4 4m5-3v15l-4-4m4 4 4-4"/></g></svg>')
	return ImageTexture.create_from_image(icon)
