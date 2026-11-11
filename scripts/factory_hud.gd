extends Control

const PORTRAIT := preload("res://assets/ui/rx07_menu.png")
const CYAN := Color("00caff")
const WHITE := Color("f1f8ff")
const INK := Color(0.018, 0.046, 0.13, 0.96)

var health := 1.0
var energy := 1.0
var health_capacity := 80.0
var energy_capacity := 75.0
var displayed_health_capacity := 80.0
var displayed_energy_capacity := 75.0
var credits := 0
var experience := 0
var animated_xp := 0.0
var xp_tween: Tween
var notice: Label
var notice_tween: Tween
var remaining := 0
var reached_exit := false
var weapon := ""
var lives := 3
var failed := false
var boss_visible := false
var boss_health := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	notice = Label.new()
	add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -270
	notice.offset_right = 270
	notice.offset_top = 184
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 38)
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

func announce(message: String, tint: Color) -> void:
	if notice_tween and notice_tween.is_valid():
		notice_tween.kill()
	notice.text = message
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
	var face := ThemeDB.fallback_font
	draw_string(face, at + Vector2(1, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("020817"))
	draw_string(face, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func gauge(y: float, label: String, ratio: float, tint: Color, width: float) -> void:
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

func task(at: Vector2, value: String, done: bool) -> void:
	var color := CYAN if done else WHITE
	draw_rect(Rect2(at + Vector2(0, -13), Vector2(14, 14)), color, false, 2.0)
	if done:
		draw_polyline(PackedVector2Array([at + Vector2(3, -6), at + Vector2(6, -3), at + Vector2(12, -10)]), CYAN, 2.0)
	caption(at + Vector2(23, 0), value, 16, color)

func _draw() -> void:
	var health_width := clampf(150.0 + (displayed_health_capacity - 80.0) * 1.4, 150.0, 245.0)
	var energy_width := clampf(150.0 + (displayed_energy_capacity - 75.0) * 1.8, 150.0, 245.0)
	plate(Rect2(105, 69, 124 + maxf(health_width, energy_width), 103), 13)
	plate(Rect2(20, 26, 103, 118), 15)
	var source_size := PORTRAIT.get_size()
	draw_texture_rect_region(PORTRAIT, Rect2(26, 33, 91, 103),
		Rect2(source_size * Vector2(0.415, 0.008), source_size * Vector2(0.17, 0.27)))
	plate(Rect2(130, 39, 96, 26), 8)
	plate(Rect2(236, 36, 86, 29), 8)
	caption(Vector2(145, 58), "RX-07", 18)
	caption(Vector2(250, 57), "LV.%02d" % RiftPlayer.level_for_experience(experience), 18)
	gauge(77, "HEALTH", health, Color("62f10b"), health_width)
	gauge(108, "ENERGY", energy, Color("04dafa"), energy_width)
	var shown_level := RiftPlayer.level_for_experience(animated_xp)
	var threshold := RiftPlayer.experience_threshold(shown_level)
	var next_threshold := RiftPlayer.experience_threshold(shown_level + 1)
	gauge(139, "XP", (animated_xp - threshold) / (next_threshold - threshold), Color("ab72ff"), 150.0)
	plate(Rect2(334, 20, 255, 31), 10)
	caption(Vector2(352, 43), "RIFTCORE   ///", 23)
	var right := size.x - 20.0
	var x := right - 348.0
	plate(Rect2(x, 21, 348, 105), 14)
	for y in range(56, 120, 5):
		draw_line(Vector2(x + 5, y), Vector2(right - 5, y), Color("102752"), 1.0)
	caption(Vector2(x + 18, 49), "⊕   OBJECTIVE", 22)
	draw_line(Vector2(x + 12, 55), Vector2(right - 12, 55), CYAN, 1.0)
	task(Vector2(x + 20, 80), "REACH THE FACTORY EXIT", reached_exit)
	task(Vector2(x + 20, 106), "OPTIONAL: SECURITY   %d LEFT" % remaining, remaining == 0)
	plate(Rect2(right - 222, 139, 222, 36), 11)
	caption(Vector2(right - 207, 164), "⬡   CREDITS  %04d" % credits, 19)
	plate(Rect2(right - 222, 181, 222, 33), 9)
	caption(Vector2(right - 207, 204), "RX   LIVES   %02d" % lives, 17)
	if boss_visible:
		var center := size.x * 0.5
		plate(Rect2(center - 180, 183, 360, 47), 11, Color("ff8c36"))
		caption(Vector2(center - 163, 205), "FORGE TITAN", 18)
		draw_rect(Rect2(center - 163, 213, 326, 7), Color("482738"))
		draw_rect(Rect2(center - 163, 213, 326 * boss_health, 7), Color("ff752d"))
	if failed:
		plate(Rect2(size.x * 0.5 - 168, size.y * 0.72, 336, 44), 10, Color("ff536c"))
		caption(Vector2(size.x * 0.5 - 151, size.y * 0.72 + 28), "RUN OVER   /   BANKING CREDITS" if lives <= 0 else "SYSTEM FAILURE   /   RESPAWNING", 17)

	plate(Rect2(18, 157, 119, 29))
	caption(Vector2(28, 178), "DEF  %.1f%%" % (RiftPlayer.defense_for_experience(experience) * 100.0), 15, Color("a8e5ff"))
	if not weapon.is_empty():
		plate(Rect2(18, 192, 287, 29))
		caption(Vector2(28, 213), weapon + "   /   Q · RB", 15, Color("ffaf60") if weapon == "MAGMA BREAKER" else CYAN)
