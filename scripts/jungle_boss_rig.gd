extends Node3D
## In-place poses for the two Machine Jungle mechs. Their CharacterBodies own all movement.

enum Motion { IDLE, ERUPT, VOLLEY, CHARGE, SWEEP, ROOT_FLOOD, STAGGER }

const SIDES := [&"Left", &"Right"]

var skeleton: Skeleton3D
var sentinel := false
var indices := {}
var rests := {}
var bone_axes := {}
var intent := [-1.0, 0.0, Motion.IDLE, 0.0]
var weights := PackedFloat32Array()
var stride_phase := 0.0
var walking := 0.0
var cinematic := false

func bind_model(model: Node3D, height: float, floor_offset: float, is_sentinel: bool) -> void:
	sentinel = is_sentinel
	# Both imported rigs face +X. Use +Z as the rig's forward axis in combat.
	model.rotation.y = -PI * 0.5
	skeleton = model.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	var from_model := skeleton.global_basis.inverse().orthonormalized() * global_basis.orthonormalized()
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		indices[name] = i
		rests[name] = skeleton.get_bone_pose_rotation(i)
		var rest := skeleton.get_bone_global_rest(i).basis
		bone_axes[name] = rest.orthonormalized().inverse() * from_model
	weights.resize(Motion.size())
	pose(0.0, 0.0, 0.0)

	var inverse := global_transform.affine_inverse()
	var bounds := AABB()
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if not mesh.mesh:
			continue
		# Skinned mesh bounds come from the bind pose and give a stable foot level.
		var part := (inverse * mesh.global_transform) * mesh.get_aabb()
		bounds = part if bounds.size == Vector3.ZERO else bounds.merge(part)
	var fit := height / maxf(bounds.size.y, 0.01)
	model.scale *= fit
	var center := bounds.get_center()
	model.position = Vector3(-center.x * fit, -floor_offset - bounds.position.y * fit, -center.z * fit)
	rotation.y = -1.04
	set_process(true)

func set_combat_pose(facing: float, speed: float, motion: Motion, weight: float) -> void:
	intent = [facing, speed, motion, weight]

func snapshot() -> Array:
	return intent

func apply_snapshot(state: Array) -> void:
	if state.size() == 4:
		intent = state

func _process(delta: float) -> void:
	if cinematic or not is_visible_in_tree():
		return
	var ease := 1.0 - exp(-delta * 15.0)
	var desired_speed := minf(float(intent[1]) / 4.5, 1.0)
	walking = lerpf(walking, desired_speed, ease)
	stride_phase = fposmod(stride_phase + (3.0 + desired_speed * 7.4) * delta, TAU)
	rotation.y = lerp_angle(rotation.y, float(intent[0]) * 1.04, ease)
	for motion in weights.size():
		var desired := float(intent[3]) if motion == int(intent[2]) else 0.0
		weights[motion] = lerpf(weights[motion], desired, ease)
	pose(sin(stride_phase) * walking, 0.0, 0.0)

func cinematic_pose(_delta: float, airborne: float, landing: float, showpiece: float, power: float) -> void:
	cinematic = true
	weights.fill(0.0)
	pose(0.0, airborne, landing, showpiece, power)

func finish_cinematic() -> void:
	cinematic = false
	pose(0.0, 0.0, 0.0)

func pose(step: float, air: float, land: float, showpiece := 0.0, power := 0.0) -> void:
	var erupt := weights[Motion.ERUPT]
	var volley := weights[Motion.VOLLEY]
	var charge := weights[Motion.CHARGE]
	var sweep := weights[Motion.SWEEP]
	var flood := weights[Motion.ROOT_FLOOD]
	var hurt := weights[Motion.STAGGER]
	var flare := showpiece * 0.36 + power * 0.18 + flood * 0.46
	var brace := air * 0.31
	var guard := 0.91 if sentinel else 0.78

	turn(&"Spine", Vector3((0.21 if sentinel else 0.34) * land + 0.20 * charge + 0.16 * erupt - 0.08 * flare - 0.16 * hurt,
		0.13 * sweep + (0.0 if sentinel else -0.12 * showpiece), 0.015 * step))
	turn(&"Head", Vector3(0.10 * charge - 0.10 * showpiece + 0.07 * land, -0.11 * sweep, 0.0))
	for index in SIDES.size():
		var side: StringName = SIDES[index]
		var direction := 1.0 if index == 0 else -1.0
		var stride := step * direction
		var vine_weight := sweep if index == 0 else 0.0
		var weapon_weight := erupt * (0.42 if sentinel or index == 1 else 0.20)
		var arm_raise := showpiece * (0.12 if sentinel else (0.10 if index == 0 else 0.23))
		turn(StringName("%sUpperArm" % side), Vector3(0.0, -direction * (0.35 + weapon_weight + volley * 0.32 + vine_weight * 0.82),
			-direction * (guard - flare - arm_raise - air * 0.32 - weapon_weight - vine_weight * 0.62 - volley * 0.30 + charge * 0.17 + stride * 0.08 + land * 0.13)))
		turn(StringName("%sForearm" % side), Vector3(0.0, -direction * (0.04 + volley * 0.20 + vine_weight * 0.42), direction * air * 0.14))
		turn(StringName("%sThigh" % side), Vector3(stride * 0.34 - brace + hurt * 0.07, 0.0, 0.0))
		turn(StringName("%sCalf" % side), Vector3(maxf(0.0, -stride) * 0.44 + brace * 1.8, 0.0, 0.0))
		turn(StringName("%sFoot" % side), Vector3(-stride * 0.14 - brace * 0.55, 0.0, 0.0))
	if sentinel:
		turn(&"L_Hand", Vector3(0.0, -0.32 * showpiece, 0.23 * power))
		turn(&"R_Hand", Vector3(0.0, 0.32 * showpiece, -0.23 * power))
	else:
		turn(&"VineBend", Vector3(0.0, -0.32 * sweep + 0.18 * flare, -0.19 * sweep + 0.26 * showpiece))
		turn(&"VineTip", Vector3(0.0, -0.30 * sweep, -0.30 * sweep + 0.16 * flare + 0.24 * power))

func turn(name: StringName, angles: Vector3) -> void:
	if not indices.has(name):
		return
	var axes: Basis = bone_axes[name]
	var rotation := Quaternion(axes.x, angles.x) * Quaternion(axes.y, angles.y) * Quaternion(axes.z, angles.z)
	var rest: Quaternion = rests[name]
	skeleton.set_bone_pose_rotation(indices[name], rest * rotation)
