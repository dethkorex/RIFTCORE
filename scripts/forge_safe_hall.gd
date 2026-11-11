extends Node3D

var target: Node3D
var opened := false
var transition: Tween

func _ready() -> void:
	$Shield.area_entered.connect(_protect_hall)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dx := absf(target.global_position.x - global_position.x)
	var in_range := absf(target.global_position.y - global_position.y) < 3.4
	if not opened and dx < 2.6 and in_range:
		toggle(true)
	elif opened and (dx > 3.15 or not in_range):
		toggle(false)

func toggle(want_open: bool) -> void:
	opened = want_open
	if transition and transition.is_valid():
		transition.kill()
	var blocker := $Blocker/CollisionShape3D as CollisionShape3D
	if not want_open:
		blocker.set_deferred("disabled", false)
	transition = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	transition.tween_property($Door, "position:y", 4.10 if want_open else 0.0, 0.37)
	if want_open:
		transition.tween_callback(blocker.set_deferred.bind("disabled", true))

func _protect_hall(area: Area3D) -> void:
	if area.is_in_group(&"rift_projectile") and area.owner_faction == "enemy":
		area.spent = true
		area.queue_free()
