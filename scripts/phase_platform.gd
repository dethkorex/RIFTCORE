extends StaticBody3D

@export var phase_offset := 0.0
@export var period := 4.3
var clock := 0.0
var previous := true

func _ready() -> void:
	clock = phase_offset

func _physics_process(delta: float) -> void:
	clock = fposmod(clock + delta, period)
	var phase := clock / period
	var solid := phase < 0.65
	visible = (solid and (phase < 0.49 or int(clock * 13.0) % 2 == 0)) or phase > 0.94
	if solid != previous:
		$Collider.set_deferred("disabled", not solid)
		previous = solid
