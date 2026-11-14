extends Node

var menu_open: Callable
var pointer := Control.new()
var pointer_position := Vector2.ZERO
var mouse_inside := true
var using_pointer := false
var using_controller := false
var owns_mouse_mode := false
var over_text := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"menu_pointer")
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
	if (event is InputEventJoypadButton and event.pressed) or event is InputEventJoypadMotion:
		observe_controller(event)
	elif event is InputEventMouseButton or (event is InputEventMouseMotion and (not using_controller or not event.relative.is_zero_approx())):
		using_controller = false
		mouse_inside = true
		pointer_position = event.position
		using_pointer = true
		refresh_pointer()

func observe_controller(event: InputEvent) -> void:
	if not menu_open.is_valid() or not menu_open.call():
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) <= 0.28:
		return
	using_pointer = false
	using_controller = true
	refresh_pointer()

func _process(_delta: float) -> void:
	refresh_pointer()

func refresh_pointer() -> void:
	var opened: bool = menu_open.is_valid() and menu_open.call()
	var should_draw := opened and using_pointer and mouse_inside and get_viewport().get_visible_rect().has_point(pointer_position)
	pointer.position = pointer_position
	if should_draw:
		var hovered := get_viewport().gui_get_hovered_control()
		var text_cursor: bool = hovered is LineEdit and hovered.editable
		if text_cursor != over_text:
			over_text = text_cursor
			pointer.queue_redraw()
	pointer.visible = should_draw
	var should_hide := should_draw or (opened and using_controller and mouse_inside and get_window().has_focus())
	if should_hide:
		owns_mouse_mode = true
		if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif owns_mouse_mode:
		owns_mouse_mode = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func stop_pointer() -> void:
	using_pointer = false
	refresh_pointer()

func _exit_tree() -> void:
	if owns_mouse_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func draw_pointer() -> void:
	var edge := Color("72edff")
	var shadow := Color("06111f")
	if over_text:
		var caps := PackedVector2Array([
			Vector2(-4, -8), Vector2(4, -8), Vector2(0, -8),
			Vector2(0, 8), Vector2(-4, 8), Vector2(4, 8),
		])
		pointer.draw_multiline(caps, shadow, 4.0, true)
		pointer.draw_multiline(caps, edge, 2.0, true)
		return

	var outline := PackedVector2Array([
		Vector2(0, 0), Vector2(22, 13), Vector2(13, 15),
		Vector2(18, 24), Vector2(13, 27), Vector2(8, 18), Vector2(2, 24),
	])
	pointer.draw_colored_polygon(outline, shadow)
	outline.append(outline[0])
	pointer.draw_polyline(outline, shadow, 4.0, true)
	pointer.draw_polyline(outline, edge, 1.5, true)
	pointer.draw_colored_polygon(PackedVector2Array([
		Vector2(3, 5), Vector2(16, 12), Vector2(8, 13), Vector2(4, 18),
	]), Color("dcefff"))
