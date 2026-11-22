@tool
extends StaticBody3D

# The tread follows the grade. Its retaining panels extend vertically to bedrock.
func _ready() -> void:
	var up := global_basis.inverse() * Vector3.UP
	if up.is_equal_approx(Vector3.UP):
		return
	var plumb := Basis(Vector3.RIGHT, up, Vector3.BACK)
	for piece in get_children():
		if piece is MeshInstance3D:
			piece.transform = Transform3D(plumb, Vector3.ZERO) * piece.transform
	var collider := $FoundationCollider as CollisionShape3D
	var half := (collider.shape as BoxShape3D).size * .5
	var corners := PackedVector3Array()
	for x in [-half.x, half.x]:
		for y in [-half.y, half.y]:
			for z in [-half.z, half.z]:
				corners.append(plumb * (collider.position + Vector3(x, y, z)))
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = corners
	collider.position = Vector3.ZERO
	collider.shape = wedge
