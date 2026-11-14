extends SkeletonModifier3D

var muzzle_bone := -1
var muzzle_offset := Vector3.ZERO
var muzzle_local := Vector3.ZERO
var standing: Dictionary[int, Quaternion] = {}
var low: Dictionary[int, Quaternion] = {}
var crouched := false
var ladder_direction := 0.0

func load_poses(animator: AnimationPlayer) -> void:
	standing = sample_pose(animator, &"shoot")
	low = sample_pose(animator, &"crouch_shoot")

func sample_pose(animator: AnimationPlayer, clip: StringName) -> Dictionary[int, Quaternion]:
	var result: Dictionary[int, Quaternion] = {}
	if not animator.has_animation(clip):
		return result
	var animation := animator.get_animation(clip)
	var skeleton := get_skeleton()
	for track in range(animation.get_track_count()):
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var path := animation.track_get_path(track)
		if path.get_subname_count() == 0:
			continue
		var bone_name := path.get_subname(0)
		if bone_name not in [&"mixamorig_RightShoulder", &"mixamorig_RightArm", &"mixamorig_RightForeArm"]:
			continue
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			result[index] = animation.rotation_track_interpolate(track, animation.length * 0.35)
	return result

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	var pose := low if crouched and not low.is_empty() else standing
	for index in pose:
		skeleton.set_bone_pose_rotation(index, pose[index])
	if muzzle_bone < 0:
		return
	var target := Vector3.BACK
	if not is_zero_approx(ladder_direction):
		target = (skeleton.global_basis.inverse() * (Vector3.RIGHT * ladder_direction)).normalized()
		var arm := skeleton.get_bone_parent(muzzle_bone)
		var toward_elbow := skeleton.get_bone_global_pose(muzzle_bone).origin - skeleton.get_bone_global_pose(arm).origin
		if toward_elbow.length_squared() > 0.000001:
			turn_bone(skeleton, arm, Quaternion(toward_elbow.normalized(), target))
	var forearm := skeleton.get_bone_global_pose(muzzle_bone)
	var barrel := (forearm.basis * muzzle_offset).normalized()
	if not barrel.is_zero_approx():
		turn_bone(skeleton, muzzle_bone, Quaternion(barrel, target))

func turn_bone(skeleton: Skeleton3D, bone: int, correction: Quaternion) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_rotation := skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion()
	var local := skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, (parent_rotation.inverse() * correction * parent_rotation * local).normalized())

func cache_muzzle() -> void:
	if muzzle_bone >= 0:
		muzzle_local = get_skeleton().get_bone_global_pose(muzzle_bone) * muzzle_offset
