extends Control

const UI := preload("res://scripts/rift_ui.gd")
const CURRENCY := preload("res://assets/ui/bolt.svg")
const SHARD := preload("res://assets/ui/core-shard.svg")
const PAUSE_PLATE := preload("res://assets/ui/riftcore_kit/panel_base_small.png")
const PORTRAIT := preload("res://assets/ui/rx07_menu.png")
const CYAN := Color("00caff")
const WHITE := Color("f1f8ff")
const INK := Color(0.018, 0.046, 0.13, 0.96)
const HUD_SCALE := 0.75

var health := 1.0
var energy := 1.0
var health_capacity := 80.0
var energy_capacity := 75.0
var displayed_health_capacity := 80.0
var displayed_energy_capacity := 75.0
var credits := 0
var core_shards := 0
var experience := 0
var animated_xp := 0.0
var xp_tween: Tween
var notice: Label
var notice_tween: Tween
var remaining := 0
var act := 1
var coop := false
var reserve_lives := 0
var reached_exit := false
var weapon := "STANDARD FRAME"
var suit_tint := Color("55e7ff")
var lives := 3
var failed := false
var boss_visible := false
var boss_health := 1.0
var boss_name := "FORGE TITAN"
var boss_tint := Color("ff8c36")
var exit_task := "REACH THE FACTORY EXIT"

func show_quick_slots(profile) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -110
	row.offset_right = 110
	row.offset_top = -73
	row.offset_bottom = -15
	var icons := preload("res://scripts/equipment_icons.gd")
	for index in 4:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(51, 56)
		panel.add_theme_stylebox_override("panel", UI.frame(Color("0b1b32"), UI.CYAN, 1))
		row.add_child(panel)
		var stack := UI.column(panel, 0)
		var slot: Dictionary = profile.quick_slots[index]
		var id := String(slot.get("id", ""))
		var key: String = ["↑", "←", "→", "↓"][index] if not Input.get_connected_joypads().is_empty() else str(index + 1)
		var count := UI.label(stack, key, 14, UI.CYAN)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var icon := TextureRect.new()
		var item_icon: Texture2D = icons.icon(profile.stock[id].icon, profile.stock[id].icon) if profile.stock.has(id) else null
		icon.custom_minimum_size = Vector2(23, 23)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(icon)
		var quantity := UI.label(stack, "", 14, UI.WHITE)
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var refresh := func():
			if is_instance_valid(icon):
				var remaining := int(profile.quick_slots[index].get("count", 0))
				icon.texture = item_icon if remaining > 0 else null
				quantity.text = str(remaining)
		refresh.call()
		profile.quick_changed.connect(refresh)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	RiftSettings.hud_scale_changed.connect(queue_redraw)
	notice = Label.new()
	add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -400
	notice.offset_right = 400
	notice.offset_top = 120
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_override("font", UI.DISPLAY)
	notice.add_theme_constant_override("outline_size", 8)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.hide()

func set_experience(total: int) -> void:
	var old_level := RiftPlayer.level_for_experience(experience)
	experience = total
	if xp_tween and xp_tween.is_valid():
		xp_tween.kill()
	xp_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	xp_tween.tween_method(func(value: float):
		animated_xp = value
		queue_redraw()
	, animated_xp, float(total), 0.55)
	xp_tween.parallel().tween_property(self, "displayed_health_capacity", health_capacity, 0.55)
	xp_tween.parallel().tween_property(self, "displayed_energy_capacity", energy_capacity, 0.55)
	if RiftPlayer.level_for_experience(total) > old_level:
		RiftAudio.play_effect(&"level_up")
		announce("LEVEL UP!", Color("c9a0ff"))
		RiftAudio.play_effect(&"voice_level_up")

func announce(message: String, tint: Color, font_size := 30) -> void:
	if notice_tween and notice_tween.is_valid():
		notice_tween.kill()
	notice.text = message
	notice.add_theme_font_size_override("font_size", font_size)
	notice.add_theme_color_override("font_color", tint)
	notice.show()
	notice.pivot_offset = notice.size * 0.5
	notice.scale = Vector2.ONE * 0.72
	notice.modulate.a = 0.0
	notice_tween = create_tween()
	notice_tween.tween_property(notice, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	notice_tween.parallel().tween_property(notice, "modulate:a", 1.0, 0.16)
	notice_tween.tween_interval(1.2)
	notice_tween.tween_property(notice, "modulate:a", 0.0, 0.32)
	notice_tween.tween_callback(notice.hide)

func plate(rect: Rect2, cut := 9.0, edge := CYAN) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var r := rect.end.x
	var b := rect.end.y
	var outline := PackedVector2Array([
		Vector2(x + cut, y), Vector2(r - cut, y), Vector2(r, y + cut),
		Vector2(r, b - cut), Vector2(r - cut, b), Vector2(x + cut, b),
		Vector2(x, b - cut), Vector2(x, y + cut)
	])
	draw_colored_polygon(outline, INK)
	outline.append(outline[0])
	draw_polyline(outline, Color("103f7a"), 7.0)
	draw_polyline(outline, edge, 2.5)
	draw_line(Vector2(x + cut + 3, y + 3), Vector2(r - cut - 3, y + 3), WHITE, 1.0)

func caption(at: Vector2, value: String, font_size := 18, color := WHITE) -> void:
	var face := UI.DISPLAY
	draw_string(face, at + Vector2(1, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("020817"))
	draw_string(face, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func gauge(y: float, label: String, ratio: float, tint: Color, width: float, values := "") -> void:
	plate(Rect2(129, y, 78, 25), 6, WHITE)
	caption(Vector2(137, y + 18), label, 14)
	plate(Rect2(214, y, width, 25), 7, WHITE)
	var segments := maxi(1, roundi((width - 19.0) / 23.5))
	var step := (width - 19.0) / segments
	for i in range(segments):
		var x := 220.0 + i * step
		var amount := clampf(ratio * segments - i, 0.0, 1.0)
		var slant := Vector2(8, -17)
		var start := Vector2(x, y + 21)
		var segment_width := Vector2(step - 2.5, 0)
		draw_colored_polygon(PackedVector2Array([start, start + segment_width, start + segment_width + slant, start + slant]), Color("172d4b"))
		if amount > 0.0:
			draw_colored_polygon(PackedVector2Array([start, start + segment_width * amount, start + segment_width * amount + slant, start + slant]), tint)
	if not values.is_empty():
		const FONT_SIZE := 17
		var face := UI.DISPLAY
		var text_width := face.get_string_size(values, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var at := Vector2(214.0 + (width - text_width) * 0.5, y + 18)
		draw_string_outline(face, at, values, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 5, Color("020817"))
		draw_string(face, at, values, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WHITE)

func task(at: Vector2, value: String, done: bool) -> void:
	var color := CYAN if done else WHITE
	draw_rect(Rect2(at + Vector2(0, -13), Vector2(14, 14)), color, false, 2.0)
	if done:
		draw_polyline(PackedVector2Array([at + Vector2(3, -6), at + Vector2(6, -3), at + Vector2(12, -10)]), CYAN, 2.0)
	caption(at + Vector2(23, 0), value, 16, color)

func _draw() -> void:
	var hud_scale := HUD_SCALE * RiftSettings.hud_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * hud_scale)
	var hud_size := size / hud_scale
	var health_width := clampf(150.0 + (displayed_health_capacity - 80.0) * 1.4, 150.0, 245.0)
	var energy_width := clampf(150.0 + (displayed_energy_capacity - 75.0) * 1.8, 150.0, 245.0)
	draw_texture_rect(PAUSE_PLATE, Rect2(102, 67, 132 + maxf(health_width, energy_width), 111), false)
	plate(Rect2(20, 26, 103, 118), 15)
	var source_size := PORTRAIT.get_size()
	draw_texture_rect_region(PORTRAIT, Rect2(26, 33, 91, 103),
		Rect2(source_size * Vector2(0.415, 0.008), source_size * Vector2(0.17, 0.27)))
	plate(Rect2(130, 39, 96, 26), 8)
	caption(Vector2(145, 58), "RX-07", 18)
	gauge(77, "HEALTH", health, Color("62f10b"), health_width, "%d / %d" % [roundi(health * health_capacity), roundi(health_capacity)])
	gauge(108, "ENERGY", energy, Color("04dafa"), energy_width, "%d / %d" % [roundi(energy * energy_capacity), roundi(energy_capacity)])
	var shown_level := RiftPlayer.level_for_experience(animated_xp)
	var threshold := RiftPlayer.experience_threshold(shown_level)
	var next_threshold := RiftPlayer.experience_threshold(shown_level + 1)
	gauge(139, "XP", (animated_xp - threshold) / (next_threshold - threshold), Color("ab72ff"), 150.0)
	var right := hud_size.x - 20.0
	if not coop:
		var x := right - 348.0
		plate(Rect2(x, 21, 348, 105), 14)
		for y in range(56, 120, 5):
			draw_line(Vector2(x + 5, y), Vector2(right - 5, y), Color("102752"), 1.0)
		caption(Vector2(x + 18, 49), "ACT %s  /  OBJECTIVE" % ("II" if act == 2 else "I"), 22)
		draw_line(Vector2(x + 12, 55), Vector2(right - 12, 55), CYAN, 1.0)
		task(Vector2(x + 20, 80), exit_task, reached_exit)
		task(Vector2(x + 20, 106), "OPTIONAL: SECURITY   %d LEFT" % remaining, remaining == 0)
	var counters := Vector2(20, 218) if coop else Vector2(right - 222, 139)
	plate(Rect2(counters, Vector2(222, 65)), 11)
	draw_texture_rect(CURRENCY, Rect2(counters + Vector2(13, 5), Vector2(24, 24)), false)
	caption(counters + Vector2(47, 25), "BOLTS  %04d" % credits, 19)
	draw_line(counters + Vector2(13, 34), counters + Vector2(208, 34), Color("346681"))
	draw_texture_rect(SHARD, Rect2(counters + Vector2(13, 37), Vector2(24, 24)), false)
	caption(counters + Vector2(47, 55), "%04d CORE SHARDS" % core_shards, 17)
	plate(Rect2(counters + Vector2(0, 71), Vector2(222, 33)), 9)
	var life_text := "RX   LIVES   %02d" % lives
	if reserve_lives > 0:
		life_text += "  +%d" % reserve_lives
	caption(counters + Vector2(15, 94), life_text, 17)
	if boss_visible:
		var center := hud_size.x * 0.5
		plate(Rect2(center - 180, 14, 360, 47), 11, boss_tint)
		caption(Vector2(center - 163, 36), boss_name, 18)
		draw_rect(Rect2(center - 163, 44, 326, 7), Color("482738"))
		draw_rect(Rect2(center - 163, 44, 326 * boss_health, 7), boss_tint)
	if failed:
		plate(Rect2(hud_size.x * 0.5 - 168, hud_size.y * 0.72, 336, 44), 10, Color("ff536c"))
		caption(Vector2(hud_size.x * 0.5 - 151, hud_size.y * 0.72 + 28), "RUN OVER   /   BANKING CREDITS" if lives <= 0 else "SYSTEM FAILURE   /   RESPAWNING", 17)

	plate(Rect2(18, 164, 280, 43), 9, suit_tint)
	var visor := PackedVector2Array([Vector2(33, 174), Vector2(40, 171), Vector2(48, 171),
		Vector2(55, 174), Vector2(54, 189), Vector2(44, 200), Vector2(34, 189), Vector2(33, 174)])
	draw_polyline(visor, suit_tint, 2.0, true)
	draw_line(Vector2(36, 182), Vector2(52, 182), suit_tint, 2.0, true)
	caption(Vector2(64, 182), weapon, 16, suit_tint)
	var device := "pad" if not Input.get_connected_joypads().is_empty() else "key"
	var previous := RiftSettings.binding_label("previous_suit", device)
	var next := RiftSettings.binding_label("swap_weapon", device)
	caption(Vector2(64, 199), "%s  ‹  PREV     NEXT  ›  %s" % [previous, next], 12, Color("a8c6db"))
