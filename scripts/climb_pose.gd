extends SkeletonModifier3D

var cycle := 0.0

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	var step := sin(cycle)
	for side in [1.0, -1.0]:
		var label := "Left" if side > 0.0 else "Right"
		var swing: float = step * side
		aim(skeleton, label + "Arm", label + "ForeArm", Vector3(side * 0.35, 0.63 + swing * 0.24, 0.62))
		aim(skeleton, label + "ForeArm", label + "Hand", Vector3(side * -0.08, 0.76 - swing * 0.28, 0.48))
		aim(skeleton, label + "UpLeg", label + "Leg", Vector3(side * 0.14, -0.71 - swing * 0.23, 0.39 + swing * 0.22))
		aim(skeleton, label + "Leg", label + "Foot", Vector3(side * 0.05, -0.92, -0.19 - swing * 0.18))

func aim(skeleton: Skeleton3D, joint: String, child: String, toward: Vector3) -> void:
	var index := skeleton.find_bone("mixamorig_" + joint)
	var end := skeleton.find_bone("mixamorig_" + child)
	if index < 0 or end < 0:
		return
	var bone := skeleton.get_bone_global_pose(index)
	var tip := skeleton.get_bone_global_pose(end)
	var vector := tip.origin - bone.origin
	if vector.length_squared() < 0.000001:
		return
	var parent := skeleton.get_bone_parent(index)
	var correction := Quaternion(vector.normalized(), toward.normalized())
	var parent_rotation := skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion()
	var local := skeleton.get_bone_pose_rotation(index)
	skeleton.set_bone_pose_rotation(index, (parent_rotation.inverse() * correction * parent_rotation * local).normalized())
