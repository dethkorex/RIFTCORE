extends CanvasLayer

signal dismissed
signal leave_requested

const UI := preload("res://scripts/rift_ui.gd")
const Overlay := preload("res://scripts/controller_overlay.gd")
const OperatorPanel := preload("res://scripts/pause_operator_panel.gd")

var in_mission := false
var operator: Callable
var quick_edited: Callable
var profile
var menu: Control
var actions: VBoxContainer
var confirmation: VBoxContainer
var resume_button: Button
var stay_button: Button
var pause_layout: HBoxContainer
var pause_tabs: TabContainer
var settings_button: Button
var settings_page: PanelContainer

func _ready() -> void:
	layer = 90
	menu = Overlay.new()
	menu.theme = UI.theme()
	menu.pause_action = close
	menu.back_action = func():
		if is_instance_valid(settings_page):
			hide_settings()
			return
		if confirmation.visible:
			show_confirmation(false)
		else:
			close()
	add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.075, 0.48)
	menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 200 if in_mission else 350
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var layout := HBoxContainer.new()
	pause_layout = layout
	layout.add_theme_constant_override("separation", 12)
	center.add_child(layout)
	layout.add_child(panel)
	if in_mission:
		var operator_panel := OperatorPanel.new()
		operator_panel.operator = operator
		operator_panel.profile = profile
		operator_panel.quick_edited = quick_edited
		layout.add_child(operator_panel)
		menu.sections = operator_panel.sections
		pause_tabs = menu.sections
	var content := UI.column(panel)
	UI.label(content, "CO-OP PAUSE", 30, UI.CYAN)
	var hint := "The mission continues. You can still take damage." if in_mission else "Your partner can still move around the station."
	UI.label(content, hint, 17, UI.MUTED)
	actions = UI.column(content, 8)
	resume_button = UI.button(actions, "Resume", close, true)
	menu.first_focus = resume_button
	settings_button = UI.button(actions, "Settings", show_settings)
	UI.button(actions, "Leave Mission…" if in_mission else "Leave Party…", show_confirmation.bind(true))
	confirmation = UI.column(content, 8)
	UI.label(confirmation, "Leaving disconnects you from the party.", 17, UI.MUTED)
	stay_button = UI.button(confirmation, "Stay in Party", show_confirmation.bind(false), true)
	UI.button(confirmation, "Confirm Leave", func(): leave_requested.emit())
	menu.hide()
	menu.process_mode = Node.PROCESS_MODE_DISABLED

func is_open() -> bool:
	return menu.visible

func open() -> void:
	menu.process_mode = Node.PROCESS_MODE_INHERIT
	menu.show()
	show_confirmation(false)

func close() -> void:
	hide_settings()
	menu.hide()
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	dismissed.emit()

func show_confirmation(enabled: bool) -> void:
	actions.visible = not enabled
	confirmation.visible = enabled
	(stay_button if enabled else resume_button).grab_focus()

func show_settings() -> void:
	pause_layout.hide()
	settings_page = PanelContainer.new()
	menu.add_child(settings_page)
	settings_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_page.offset_left = 60
	settings_page.offset_top = 30
	settings_page.offset_right = -60
	settings_page.offset_bottom = -30
	var content := UI.column(settings_page, 8)
	UI.label(content, "SETTINGS", 30, UI.CYAN)
	var settings := UI.settings(content)
	menu.sections = settings.tabs
	menu.pause_action = hide_settings
	menu.first_focus = settings.initial_focus
	UI.button(content, "Back to Pause", hide_settings)
	settings.initial_focus.grab_focus()

func hide_settings() -> void:
	if not is_instance_valid(settings_page):
		return
	menu.remove_child(settings_page)
	settings_page.queue_free()
	settings_page = null
	pause_layout.show()
	menu.sections = pause_tabs
	menu.pause_action = close
	menu.first_focus = resume_button
	settings_button.grab_focus()
