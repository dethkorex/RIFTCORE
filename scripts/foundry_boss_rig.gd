extends Node3D

@export var warden := false

var skeleton: Skeleton3D
var bones: Dictionary = {}
var rest_rotations: Dictionary = {}
var rest_positions: Dictionary = {}
var rotor_phase := 0.0
var left_burner: Node3D
var right_burner: Node3D
var drill_tip: Node3D
var hammer_head: Node3D

func _ready() -> void:
	skeleton = find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	for index in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(index)
		bones[bone] = index
		rest_rotations[bone] = skeleton.get_bone_pose_rotation(index)
		rest_positions[bone] = skeleton.get_bone_pose_position(index)
	if warden:
		left_burner = attach_marker(&"BurnerLeft", Vector3(.31, .425, -.418))
		right_burner = attach_marker(&"BurnerRight", Vector3(.31, .425, .418))
	else:
		drill_tip = attach_marker(&"DrillRotor", Vector3(.234, .134, -.454))
		hammer_head = attach_marker(&"R_Forearm", Vector3(.093, .22, .405))

func attach_marker(bone: StringName, at: Vector3) -> Node3D:
	var index: int = bones[bone]
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var marker := Marker3D.new()
	marker.position = skeleton.get_bone_global_rest(index).affine_inverse() * at
	marker.scale = Vector3.ONE / $Rig.scale
	attachment.add_child(marker)
	return marker

func animate(delta: float, step: float, heat: float, hammer: float, recoil: float, exposed: bool) -> void:
	if warden:
		# Alternate diagonal pairs to give the kiln a stable four-beat silhouette.
		tilt(&"bone_4", step)
		tilt(&"bone_7", step)
		tilt(&"bone_1", -step)
		tilt(&"bone_10", -step)
		tilt(&"bone_5", -step * .72)
		tilt(&"bone_8", -step * .72)
		tilt(&"bone_2", step * .72)
		tilt(&"bone_11", step * .72)
		tilt(&"BurnerLeft", -.35 * heat + recoil)
		tilt(&"BurnerRight", -.29 * heat + recoil)
		return

	tilt(&"L_Thigh", step)
	tilt(&"R_Thigh", -step)
	tilt(&"L_Calf", maxf(0.0, -step) * .72)
	tilt(&"R_Calf", maxf(0.0, step) * .72)
	tilt(&"L_Foot", -step * .54)
	tilt(&"R_Foot", step * .54)
	tilt(&"R_Upperarm", hammer * .64)
	tilt(&"R_Forearm", hammer * .36)
	tilt(&"L_Upperarm", -.32 * heat + recoil)
	tilt(&"L_Forearm", -.19 * heat + recoil * .45)

	rotor_phase = fposmod(rotor_phase + delta * (3.0 + heat * 27.0), TAU)
	var rotor: int = bones[&"DrillRotor"]
	skeleton.set_bone_pose_rotation(rotor, rest_rotations[&"DrillRotor"] * Quaternion(Vector3.UP, rotor_phase))
	slide(&"ShutterLeft", Vector3.FORWARD * (.035 if exposed else -.015), delta)
	slide(&"ShutterRight", Vector3.BACK * (.035 if exposed else -.015), delta)

func cinematic_pose(delta: float, airborne: float, landing: float, showpiece: float, power: float) -> void:
	animate(delta, 0.0, power, 0.0, 0.0, false)
	if warden:
		for bone in [&"bone_4", &"bone_7", &"bone_1", &"bone_10"]:
			tilt(bone, airborne * 0.16)
		tilt(&"BurnerLeft", -0.64 * showpiece - 0.18 * power + 0.24 * landing)
		tilt(&"BurnerRight", -0.48 * showpiece - 0.28 * power + 0.21 * landing)
		tilt(&"tripo__Head_0", -0.17 * showpiece + 0.11 * landing)
	else:
		tilt(&"L_Thigh", -0.24 * airborne)
		tilt(&"R_Thigh", -0.16 * airborne)
		tilt(&"L_Calf", 0.39 * airborne)
		tilt(&"R_Calf", 0.33 * airborne)
		tilt(&"Spine02", -0.13 * showpiece + 0.19 * landing)
		tilt(&"L_Upperarm", -0.70 * showpiece - 0.12 * power + 0.20 * landing)
		tilt(&"L_Forearm", -0.30 * showpiece)
		tilt(&"R_Upperarm", 0.40 * showpiece + 0.19 * landing)
		tilt(&"R_Forearm", -0.46 * showpiece)

func tilt(bone: StringName, radians: float) -> void:
	var index: int = bones[bone]
	# The source rigs face +X. Convert their transverse axis into each joint's basis.
	var axis := (skeleton.get_bone_global_rest(index).basis.inverse() * Vector3.FORWARD).normalized()
	skeleton.set_bone_pose_rotation(index, rest_rotations[bone] * Quaternion(axis, radians))

func slide(bone: StringName, offset: Vector3, delta: float) -> void:
	var index: int = bones[bone]
	var parent := skeleton.get_bone_parent(index)
	var local_offset := skeleton.get_bone_global_rest(parent).basis.inverse() * offset
	var target: Vector3 = rest_positions[bone] + local_offset
	var origin := skeleton.get_bone_pose_position(index)
	skeleton.set_bone_pose_position(index, origin.lerp(target, 1.0 - exp(-delta * 16.0)))
