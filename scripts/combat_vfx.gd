extends RefCounted

const FLASH := preload("res://assets/vfx/kenney/light_01.png")
const SPARK := preload("res://assets/vfx/kenney/spark_04.png")
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
	preload("res://scripts/pack_combat_vfx.gd").explosion(parent, tint, 0.94)
