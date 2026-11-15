extends StaticBody3D

@export var phase_offset := 0.0
@export var period := 4.3
@export_range(0.8, 1.0) var crossing_window_scale := 1.0
var clock := 0.0
var previous := true
var phase_time: Callable

func _ready() -> void:
	clock = phase_offset

func _physics_process(delta: float) -> void:
	clock = fposmod(float(phase_time.call()) + phase_offset if phase_time.is_valid() else clock + delta, period)
	var phase := clock / period
	var solid_until := 0.65 * crossing_window_scale
	var solid := phase < solid_until
	visible = (solid and (phase < solid_until - 0.16 or int(clock * 13.0) % 2 == 0)) or phase > 0.94
	if solid != previous:
		$Collider.set_deferred("disabled", not solid)
		previous = solid
