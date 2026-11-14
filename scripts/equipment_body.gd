extends Control

const UI := preload("res://scripts/rift_ui.gd")
const ICONS := preload("res://scripts/equipment_icons.gd")
const PROFILE := preload("res://scripts/rogue_profile.gd")
const AVATAR := preload("res://scenes/actors/riftcore_player.tscn")

const SOCKETS := {
	"frame": {"joint": Vector2(0.455, 0.30), "row": 0.41, "left": true},
	"core": {"joint": Vector2(0.506, 0.329), "row": 0.38, "left": false},
	"utility": {"joint": Vector2(0.447, 0.748), "row": 0.75, "left": true},
	"visor": {"joint": Vector2(0.50, 0.19), "row": 0.13, "left": true},
	"arm": {"joint": Vector2(0.63, 0.48), "row": 0.66, "left": false},
}
var buttons := {}
var badges := {}
var profile
var selected := "frame"

func install(data, active: String, action: Callable, workshop := false) -> void:
	profile = data
	selected = active
	custom_minimum_size = Vector2(430, 290)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var screen := SubViewportContainer.new()
	screen.stretch = true
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.gui_disable_input = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	screen.add_child(view)
	var actor := AVATAR.instantiate() as RiftPlayer
	view.add_child(actor)
	actor.position.y = 0.89
	actor.set_physics_process(false)
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.model_root.rotation.y = 0
	actor.play_character_animation("idle", true)
	var silhouette := ShaderMaterial.new()
	silhouette.shader = preload("res://assets/ui/equipment_silhouette.gdshader")
	for mesh in actor.model_root.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = silhouette
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	view.add_child(camera)
	camera.position = Vector3(0, 0.88, 4.0)
	camera.make_current()
	var order := ["visor", "frame", "core", "arm", "utility"]
	for slot in order:
		var id: String = profile.equipped_for(slot) if profile and not workshop else ""
		var name: String = PROFILE.GEAR_SLOTS[slot]
		var detail := "Empty" if id.is_empty() else String(PROFILE.GEAR[id].name)
		if workshop:
			var count := 0
			for upgrade in profile.all_upgrades():
				if String(upgrade.get("slot", PROFILE.UPGRADE_SLOTS.get(upgrade.id, ""))) == slot and profile.rank(upgrade.id) > 0:
					count += 1
			detail = "%d installed" % count
		var button := UI.button(self, name + "\n" + detail, action.bind(slot), slot == selected)
		button.icon = ICONS.icon(slot if id.is_empty() else id, slot)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		button.add_theme_constant_override("h_separation", 7)
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = name if id.is_empty() else String(PROFILE.GEAR[id].perk)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		buttons[slot] = button
		var badge := Panel.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var edge: Color = ICONS.COLORS[slot]
		var badge_style := UI.frame(Color("0b1a29"), edge if slot == selected else edge.darkened(0.35), 1)
		badge_style.set_corner_radius_all(7)
		badge.add_theme_stylebox_override("panel", badge_style)
		add_child(badge)
		badge.size = Vector2(28.0, 28.0)
		var item_icon := TextureRect.new()
		item_icon.texture = button.icon
		item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(item_icon)
		item_icon.position = Vector2(4, 4)
		item_icon.size = Vector2(20, 20)
		badges[slot] = badge
		if slot == selected:
			button.grab_focus()
	resized.connect(place_sockets)
	for index in range(order.size()):
		var button: Button = buttons[order[index]]
		button.focus_neighbor_top = button.get_path_to(buttons[order[posmod(index - 1, order.size())]])
		button.focus_neighbor_bottom = button.get_path_to(buttons[order[(index + 1) % order.size()]])
	place_sockets.call_deferred()

func place_sockets() -> void:
	for slot in buttons:
		var button: Button = buttons[slot]
		var socket: Dictionary = SOCKETS[slot]
		var wide := minf(size.x * 0.34, 168.0)
		button.size = Vector2(wide, 55.0)
		button.position = Vector2(9.0 if socket.left else size.x - wide - 9.0, size.y * float(socket.row) - 27.0)
		badges[slot].position = socket.joint * size - Vector2(14, 14)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("091827"))
	var grid := Color("112b40")
	for x in range(0, int(size.x), 25):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid)
	for y in range(0, int(size.y), 25):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid)
	if buttons.is_empty():
		return
	for slot in buttons:
		var socket: Dictionary = SOCKETS[slot]
		var button: Button = buttons[slot]
		var joint: Vector2 = socket.joint * size
		var edge := button.position + Vector2(button.size.x if socket.left else 0.0, 27.0)
		var color: Color = ICONS.COLORS[slot]
		if selected != slot:
			color = color.darkened(0.34)
		draw_polyline(PackedVector2Array([edge, Vector2(joint.x, edge.y), joint]), color, 1.3, true)
		draw_circle(joint, 6.0, color, false, 1.5, true)
