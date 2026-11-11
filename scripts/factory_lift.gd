extends AnimatableBody3D

@export var travel := 2.5
@export var horizontal_travel := 0.0
@export var seconds_per_leg := 2.0

func _ready() -> void:
	var bottom := position
	var duration := maxf(seconds_per_leg, 0.1)
	var cycle := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	cycle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cycle.tween_property(self, "position", bottom + Vector3(horizontal_travel, travel, 0.0), duration)
	cycle.tween_interval(0.35)
	cycle.tween_property(self, "position", bottom, duration)
	cycle.tween_interval(0.35)
