extends RefCounted

const FLASH := preload("res://assets/vfx/kenney/light_01.png")
const SPARK := preload("res://assets/vfx/kenney/spark_04.png")
const SMOKE := preload("res://assets/vfx/kenney/smoke_05.png")
const RING := preload("res://assets/vfx/kenney/circle_03.png")

static func sprite(parent: Node3D, texture: Texture2D, at: Vector3, size: float, tint: Color) -> Sprite3D:
	var layer := Sprite3D.new()
	layer.texture = texture
	layer.pixel_size = size / texture.get_width()
	layer.modulate = tint
	layer.position = at
	parent.add_child(layer)
	return layer

static func hit(parent: Node3D, tint: Color, strength: float) -> void:
	var flash := sprite(parent, FLASH, Vector3(0, 0, 0.12), 1.05 * strength, tint.lerp(Color.WHITE, 0.63))
	var sparks := sprite(parent, SPARK, Vector3(0, 0, 0.15), 0.83 * strength, Color(tint.lerp(Color.WHITE, 0.36), 0.88))
	sparks.rotation.z = randf_range(-PI, PI)
	var tween := parent.create_tween().set_parallel()
	tween.tween_property(flash, "modulate:a", 0.0, 0.11)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.62, 0.11)
	tween.tween_property(sparks, "modulate:a", 0.0, 0.20)
	tween.tween_property(sparks, "scale", Vector3.ONE * 1.65, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func explosion(parent: Node3D, tint: Color) -> void:
	hit(parent, tint, 2.15)
	var ring := sprite(parent, RING, Vector3(0, 0, 0.18), 0.72, Color(tint.lerp(Color.WHITE, 0.31), 0.70))
	var tween := parent.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3.ONE * 4.5, 0.36)
	tween.tween_property(ring, "modulate:a", 0.0, 0.33)
	for i in range(3):
		var offset := Vector3((i - 1) * 0.33, -0.08, 0.10 - i * 0.025)
		var smoke := sprite(parent, SMOKE, offset, 1.1, Color(tint.lerp(Color("354051"), 0.76), 0.61))
		smoke.rotation.z = i * 1.9
		tween.tween_property(smoke, "position", offset + Vector3((i - 1) * 0.55, 0.47 + i * 0.14, 0), 0.43)
		tween.tween_property(smoke, "scale", Vector3.ONE * (1.55 + i * 0.17), 0.43)
		tween.tween_property(smoke, "modulate:a", 0.0, 0.43)
