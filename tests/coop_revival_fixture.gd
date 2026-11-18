extends "res://scripts/coop_mission.gd"
## Keep the production mission logic, replacing only live transport and startup.
var broadcasts := 0
func _ready() -> void: pass
func _process(_delta: float) -> void: pass
func _physics_process(_delta: float) -> void: pass
func broadcast_state(_reliable := false) -> void:
	broadcasts += 1
