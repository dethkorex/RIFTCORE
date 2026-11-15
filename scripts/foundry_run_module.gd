extends CanvasLayer

signal selected(id: String)

const UI := preload("res://scripts/rift_ui.gd")
const MODULES := {
	"deflector": ["Saber Deflector", "Time a saber swing to send enemy shots back and recover 5 energy."],
	"prism": ["Buster Prism", "A charged standard Buster shot splits into two fragments on its first hit."],
	"conduit": ["Charge Conduit", "Charged suit weapons use 25% less energy."],
}

func choose() -> void:
	layer = 42
	add_to_group(&"interactive_dialogue")
	var cover := ColorRect.new()
	cover.color = Color("050b19de")
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	cover.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.theme = UI.theme()
	panel.custom_minimum_size.x = 480
	panel.add_theme_stylebox_override("panel", UI.texture_frame("panel_base_large", 40, Vector2(20, 17)))
	center.add_child(panel)
	var rows := UI.column(panel, 10)
	UI.label(rows, "Kiln Warden reclaimed", 30, UI.CYAN)
	UI.label(rows, "Choose one module for this run.", 17, UI.MUTED)
	for id in MODULES:
		var data: Array = MODULES[id]
		var button := UI.button(rows, data[0], func(): selected.emit(id), false, 36)
		button.size_flags_horizontal = Control.SIZE_FILL
		UI.label(rows, data[1], 16, UI.MUTED)
		if id == MODULES.keys()[0]:
			button.grab_focus()
