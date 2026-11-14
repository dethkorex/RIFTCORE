extends Node

var menu_open: Callable
var pointer := Control.new()
var pointer_position := Vector2.ZERO
var mouse_inside := true
var using_pointer := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := CanvasLayer.new()
	overlay.layer = 200
	add_child(overlay)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.focus_mode = Control.FOCUS_NONE
	pointer.hide()
	pointer.draw.connect(draw_pointer)
	overlay.add_child(pointer)
	var window := get_window()
	window.mouse_entered.connect(func(): mouse_inside = true)
	window.mouse_exited.connect(func(): mouse_inside = false)
	window.focus_exited.connect(stop_pointer)

func _input(event: InputEvent) -> void:
	if not menu_open.is_valid() or not menu_open.call():
		return
	if event is InputEventMouse:
		mouse_inside = true
		pointer_position = event.position
		using_pointer = true
		refresh_pointer()

func _process(_delta: float) -> void:
	refresh_pointer()

func refresh_pointer() -> void:
	var should_draw: bool = (menu_open.is_valid() and menu_open.call() and using_pointer
		and mouse_inside and get_viewport().get_visible_rect().has_point(pointer_position))
	pointer.position = pointer_position
	if should_draw:
		pointer.show()
		if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif pointer.visible:
		pointer.hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func stop_pointer() -> void:
	using_pointer = false
	refresh_pointer()

func _exit_tree() -> void:
	if pointer.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func draw_pointer() -> void:
	var points := PackedVector2Array([
		Vector2(0, 0), Vector2(2, 24), Vector2(8, 18), Vector2(13, 28),
		Vector2(17, 26), Vector2(12, 16), Vector2(21, 16),
	])
	pointer.draw_colored_polygon(points, Color("e7f8ff"))
	points.append(points[0])
	pointer.draw_polyline(points, Color("102940"), 2.0, true)
