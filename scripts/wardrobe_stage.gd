extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("091a2e"))
	var horizon := size * Vector2(0.5, 0.64)
	var floor_start := size.y * 0.76
	for row in range(12):
		var fraction := row / 12.0
		var top := lerpf(0.0, floor_start, fraction)
		var height := ceilf(floor_start / 12.0)
		draw_rect(Rect2(0, top, size.x, height), Color("132b47").lerp(Color("09182a"), 1.0 - fraction))
	draw_colored_polygon(PackedVector2Array([Vector2(0, floor_start), horizon, Vector2(size.x, floor_start), size, Vector2(0, size.y)]), Color("112742"))
	for x in [-0.55, -0.23, 0.06, 0.36, 0.64, 0.94, 1.23, 1.55]:
		draw_line(horizon, Vector2(size.x * x, size.y), Color("254467"), 1.0, true)
	for depth in [0.47, 0.62, 0.81, 0.98]:
		var y := lerpf(horizon.y, size.y, depth)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("254467"), 1.0)
	for side: float in [-1.0, 1.0]:
		for step in range(3):
			var d := (0.29 - 0.076 * step) * size.x * side
			var x := horizon.x + d
			var top := size.y * (0.04 + 0.14 * step)
			var joint := Vector2(x, top + size.y * 0.16)
			var end := Vector2(x, lerpf(floor_start, horizon.y, step * 0.26))
			var rail := PackedVector2Array([Vector2(x + d * 0.56, top), joint, end, end + Vector2(d * 0.2, size.y * 0.055)])
			draw_polyline(rail, Color("152d49"), 12.0 - step * 3.0, true)
			draw_polyline(rail, Color("25496c"), 2.0, true)
			var light_end := joint.lerp(rail[0], 0.32)
			draw_line(joint, light_end, Color("135987"), 8.0 - step * 2.0, true)
			draw_line(joint, light_end, Color("8deaff"), 3.7 - step, true)
