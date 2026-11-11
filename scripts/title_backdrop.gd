class_name TitleBackdrop
extends Control

var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var viewport_size := size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("030713"))
	var glow_center := Vector2(viewport_size.x * 0.72, viewport_size.y * 0.46)
	for ring in range(10, 0, -1):
		var radius := float(ring) * 62.0 + sin(time * 0.65) * 8.0
		var alpha := 0.006 + float(10 - ring) * 0.002
		draw_circle(glow_center, radius, Color(0.05, 0.55, 1.0, alpha))
	var horizon := viewport_size.y * 0.72
	for i in range(16):
		var y := horizon + pow(float(i) / 15.0, 1.8) * (viewport_size.y - horizon)
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), Color(0.05, 0.48, 0.72, 0.16), 1.0)
	for i in range(-12, 13):
		var bottom_x := viewport_size.x * 0.5 + float(i) * 105.0
		draw_line(Vector2(viewport_size.x * 0.5 + float(i) * 13.0, horizon), Vector2(bottom_x, viewport_size.y), Color(0.05, 0.48, 0.72, 0.14), 1.0)
	for i in range(18):
		var phase := fmod(time * (20.0 + i * 1.7) + i * 97.0, viewport_size.x + 240.0) - 120.0
		var y := 80.0 + fmod(float(i * 71), maxf(100.0, viewport_size.y - 180.0))
		draw_line(Vector2(phase, y), Vector2(phase + 36.0, y), Color(0.12, 0.75, 1.0, 0.12), 2.0)
	draw_line(Vector2(0, horizon), Vector2(viewport_size.x, horizon), Color(0.15, 0.85, 1.0, 0.5), 2.0)

