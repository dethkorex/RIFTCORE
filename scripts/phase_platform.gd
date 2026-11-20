extends StaticBody3D

@export var phase_offset := 0.0
@export var period := 4.3
@export_range(0.8, 1.0) var crossing_window_scale := 1.0
var clock := 0.0
var previous := true
var phase_time: Callable
var panels: Array[MeshInstance3D] = []
var lamps: Array[MeshInstance3D] = []
var last_signal := -1

func _ready() -> void:
	clock = phase_offset
	for part: MeshInstance3D in find_children("Panel*", "MeshInstance3D", false, false):
		if part.name in [&"PanelM2", &"PanelM5"]:
			lamps.append(part)
		else:
			panels.append(part)

func _physics_process(delta: float) -> void:
	clock = fposmod(float(phase_time.call()) + phase_offset if phase_time.is_valid() else clock + delta, period)
	var phase := clock / period
	var solid_until := 0.65 * crossing_window_scale
	var solid := phase < solid_until
	if solid != previous:
		for panel in panels:
			panel.visible = solid
		$Collider.set_deferred("disabled", not solid)
		previous = solid
	# The deck stays visible for its entire solid interval. Two fascia lamps
	# mark the missing span and warn of a change without suggesting a foothold.
	var signal_state := 0
	if solid and phase > solid_until - 0.18:
		signal_state = 1
	elif not solid:
		signal_state = 3 if phase > 0.88 else 2
	if last_signal != signal_state:
		last_signal = signal_state
		var colors := [Color("68f2cc"), Color("ffb632"), Color("294156"), Color("79dcff")]
		for lamp in lamps:
			lamp.material_override = RiftProjectile.light_paint(colors[signal_state], 0.35 if signal_state == 2 else 2.4)
