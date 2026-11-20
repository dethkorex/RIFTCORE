extends Node3D
var dimensions := Vector3(3,10,3.2)
var speed := 9.0
var direction := Vector3.UP
func _ready() -> void:
	add_to_group(&"abyssal_current")
func contains(at: Vector3) -> bool:
	var p := to_local(at)
	return absf(p.x)<dimensions.x*.5 and absf(p.y)<dimensions.y*.5 and absf(p.z)<dimensions.z*.5
func apply_to(actor: RiftPlayer, delta: float) -> void:
	if contains(actor.global_position) and not actor.controls_suspended and actor.health>0 and actor.contact_recoil<=0:
		if absf(direction.x)>.5:
			actor.velocity.x=move_toward(actor.velocity.x,speed*direction.x,85.0*delta)
		else:
			actor.velocity.y=move_toward(actor.velocity.y,speed*direction.y,85.0*delta)
		actor.air_dash_available=true
