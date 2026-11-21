extends Control

const UI := preload("res://scripts/rift_ui.gd")
const CARD_SIZE := Vector2(154, 38)
static var arrow := PackedVector2Array([Vector2(11, 0), Vector2(-7, -8), Vector2(-3, 0), Vector2(-7, 8)])

var markers: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func begin_frame() -> void:
	if not markers.is_empty():
		markers.clear()
		queue_redraw()

func point_to(projected: Vector2, operator_name: String, distance: float, tint: Color) -> void:
	# Let the world-space revive marker take over once the body is visible.
	if Rect2(Vector2.ZERO, size).grow(-24.0).has_point(projected):
		return
	var inset := Vector2(minf(90.0, size.x * 0.23), 0.0)
	var top := minf(174.0, size.y * 0.29)
	var bottom := minf(80.0, size.y * 0.17)
	var safe := Rect2(Vector2(inset.x, top), size - Vector2(inset.x * 2.0, top + bottom))
	if not safe.has_area():
		return
	var center := safe.get_center()
	var toward := projected - center
	var half := safe.size * 0.5
	var horizontal_edge := absf(toward.x) / half.x > absf(toward.y) / half.y
	var reach := half.x / absf(toward.x) if horizontal_edge else half.y / absf(toward.y)
	var at := center + toward * reach
	var step := Vector2(0, CARD_SIZE.y + 5) if horizontal_edge else Vector2(CARD_SIZE.x + 5, 0)
	var bounds := Rect2(at - CARD_SIZE * 0.5, CARD_SIZE)
	for offset in [0.0, 1.0, -1.0, 2.0, -2.0]:
		var candidate: Vector2 = (at + step * offset).clamp(safe.position, safe.end)
		var card := Rect2(candidate - CARD_SIZE * 0.5, CARD_SIZE)
		if not markers.any(func(marker): return marker.bounds.grow(4.0).intersects(card)):
			bounds = card
			break
	var caption := operator_name if operator_name.length() <= 16 else operator_name.substr(0, 15) + "…"
	markers.append({"bounds": bounds, "angle": (projected - bounds.get_center()).angle(),
		"name": caption, "distance": "%d m · REVIVE" % roundi(distance), "tint": tint})
	queue_redraw()

func _draw() -> void:
	for marker in markers:
		var bounds: Rect2 = marker.bounds
		var tint: Color = marker.tint
		draw_rect(bounds, Color("091727f5"))
		draw_rect(bounds, Color(tint, 0.75), false, 1.5)
		draw_set_transform(bounds.position + Vector2(17, 19), marker.angle)
		draw_colored_polygon(arrow, tint)
		draw_set_transform(Vector2.ZERO)
		draw_string(UI.DISPLAY, bounds.position + Vector2(33, 16), marker.name,
			HORIZONTAL_ALIGNMENT_LEFT, 114, 17, UI.WHITE)
		draw_string(UI.DISPLAY, bounds.position + Vector2(33, 32), marker.distance,
			HORIZONTAL_ALIGNMENT_LEFT, 114, 14, tint)
