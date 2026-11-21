extends RefCounted

const PEAK := Color(1.0, 0.035, 0.055, 0.82)
const CLEAR := Color(1.0, 0.035, 0.055, 0.0)
const DURATION := 0.085

var pieces: Array[MeshInstance3D] = []
var original_overlays: Array[Material] = []
var red := StandardMaterial3D.new()
var fade: Tween

func _init(model: Node3D) -> void:
	if model is MeshInstance3D:
		pieces.append(model)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		pieces.append(child)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.render_priority = 1

func pulse(model: Node3D, fatal: bool) -> void:
	if fade and fade.is_valid():
		fade.kill()
	red.albedo_color = PEAK
	if fatal:
		restore_overlays()
		if DisplayServer.get_name() != "headless":
			show_final_pulse(model)
		return
	if original_overlays.is_empty():
		for piece in pieces:
			original_overlays.append(piece.material_overlay if is_instance_valid(piece) else null)
			if is_instance_valid(piece):
				piece.material_overlay = red
	fade = model.create_tween()
	fade.tween_property(red, "albedo_color", CLEAR, DURATION)
	fade.tween_callback(restore_overlays)

# Death removes the actor immediately. Carry its last visible pose through the short flash.
func show_final_pulse(model: Node3D) -> void:
	var silhouette := Node3D.new()
	model.get_parent().get_parent().add_child(silhouette)
	var poses: Dictionary[Skeleton3D, Skeleton3D] = {}
	for piece in pieces:
		if not is_instance_valid(piece) or not piece.mesh or not visible_on_model(piece, model):
			continue
		var echo := MeshInstance3D.new()
		echo.mesh = piece.mesh
		echo.material_override = red
		echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		silhouette.add_child(echo)
		echo.global_transform = piece.global_transform
		var rig := piece.get_node_or_null(piece.skeleton) as Skeleton3D
		if rig and piece.skin:
			if not poses.has(rig):
				poses[rig] = copy_pose(rig, silhouette)
			echo.skin = piece.skin
			echo.skeleton = echo.get_path_to(poses[rig])
	var last_pulse := silhouette.create_tween()
	last_pulse.tween_property(red, "albedo_color", CLEAR, DURATION)
	last_pulse.tween_callback(silhouette.queue_free)

func copy_pose(rig: Skeleton3D, parent: Node3D) -> Skeleton3D:
	var pose := Skeleton3D.new()
	parent.add_child(pose)
	pose.global_transform = rig.global_transform
	for i in rig.get_bone_count():
		pose.add_bone(rig.get_bone_name(i))
	for i in rig.get_bone_count():
		pose.set_bone_parent(i, rig.get_bone_parent(i))
		pose.set_bone_rest(i, rig.get_bone_rest(i))
		pose.set_bone_pose(i, rig.get_bone_pose(i))
	return pose

func restore_overlays() -> void:
	for i in original_overlays.size():
		if is_instance_valid(pieces[i]) and pieces[i].material_overlay == red:
			pieces[i].material_overlay = original_overlays[i]
	original_overlays.clear()

# A guest may already have hidden the defeated actor from its latest health snapshot.
func visible_on_model(piece: Node3D, model: Node3D) -> bool:
	var part := piece
	while part != model:
		if not part.visible:
			return false
		part = part.get_parent_node_3d()
		if not part:
			return false
	return model.visible
