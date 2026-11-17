extends RefCounted

const APPROACH := 4.8
const OPEN_SPEED := 13.5
const CLOSE_SPEED := 9.0
const MAX_LIFT := 4.2

var panel: Node3D
var blocker: CollisionShape3D
var bounds: AABB
var closed_y: float
var passable := false

func _init(portal: Node3D) -> void:
	panel = portal.get_node("Door")
	blocker = portal.get_node("Blocker/CollisionShape3D")
	var shape := blocker.shape as BoxShape3D
	bounds = blocker.global_transform * AABB(-shape.size * 0.5, shape.size)
	closed_y = panel.position.y

func reset() -> void:
	apply(0.0, false)

func near(operator: RiftPlayer, reach := APPROACH) -> bool:
	var at := operator.global_position
	var feet := at.y - operator.standing_capsule.height * 0.5
	return operator.health > 0.0 and at.x >= bounds.position.x - reach and at.x <= bounds.end.x + reach \
		and feet >= bounds.position.y - 0.75 and feet < bounds.position.y + 2.8 \
		and at.z >= bounds.position.z and at.z <= bounds.end.z

func inside(operator: RiftPlayer, far_edge: float) -> bool:
	var at := operator.global_position
	return operator.health > 0.0 and at.x >= bounds.end.x + operator.standing_capsule.radius + 0.24 \
		and at.x < far_edge and at.y >= bounds.position.y - 0.25 \
		and at.y < bounds.end.y and at.z >= bounds.position.z and at.z <= bounds.end.z

func crossing(operator: RiftPlayer) -> bool:
	var at := operator.global_position
	var radius := operator.standing_capsule.radius + 0.12
	return at.x + radius >= bounds.position.x and at.x - radius <= bounds.end.x \
		and at.y + operator.standing_capsule.height * 0.5 > bounds.position.y and at.y < bounds.end.y \
		and at.z + radius >= bounds.position.z and at.z - radius <= bounds.end.z

func lift() -> float:
	return panel.position.y - closed_y

func step(delta: float, open: bool, operators: Array) -> void:
	var wanted := MAX_LIFT if open else 0.0
	var height := 1.7
	var occupied := false
	for operator: RiftPlayer in operators:
		if operator.health > 0.0:
			height = maxf(height, operator.standing_capsule.height)
			occupied = occupied or crossing(operator)
	var clearance := height + 0.26
	if occupied and passable:
		wanted = maxf(wanted, clearance)
	var next := move_toward(lift(), wanted, (OPEN_SPEED if open else CLOSE_SPEED) * delta)
	apply(next, next >= clearance)

func apply(opening: float, can_cross: bool) -> void:
	var height := closed_y + clampf(opening, 0.0, MAX_LIFT)
	if panel.position.y != height:
		panel.position.y = height
	if can_cross == passable and blocker.disabled == can_cross:
		return
	passable = can_cross
	blocker.set_deferred("disabled", can_cross)
