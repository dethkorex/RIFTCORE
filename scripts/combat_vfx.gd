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
	var flash := sprite(parent, FLASH, Vector3(0, 0, 0.12), 1.20 * strength, tint.lerp(Color.WHITE, 0.63))
	var sparks := sprite(parent, SPARK, Vector3(0, 0, 0.15), 0.95 * strength, Color(tint.lerp(Color.WHITE, 0.36), 0.88))
	sparks.rotation.z = randf_range(-PI, PI)
	var tween := parent.create_tween().set_parallel()
	tween.tween_property(flash, "modulate:a", 0.0, 0.14)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.62, 0.14)
	tween.tween_property(sparks, "modulate:a", 0.0, 0.23)
	tween.tween_property(sparks, "scale", Vector3.ONE * 1.65, 0.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func recovery(parent: Node3D, tint: Color, level_up := false) -> Node3D:
	var effect := Node3D.new()
	parent.add_child(effect)
	var ring := sprite(effect, RING, Vector3(0, .08, -.20), 2.25 if level_up else 1.75, Color(tint, .88 if level_up else .77))
	ring.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, .18, .57)
	glow.light_color = tint
	glow.light_energy = 4.0 if level_up else 2.0
	glow.omni_range = 4.0 if level_up else 2.25
	effect.add_child(glow)
	var pulse := effect.create_tween().set_parallel()
	pulse.tween_property(ring, "scale", Vector3.ONE * 1.35, .64).set_ease(Tween.EASE_OUT)
	pulse.tween_property(ring, "modulate:a", 0.0, .54).set_delay(.12)
	pulse.tween_property(glow, "light_energy", 0.0, 1.08).set_delay(.13)
	if level_up:
		var halo := sprite(effect, FLASH, Vector3(0, .16, -.24), 3.0, Color(tint, .56))
		halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pulse.tween_property(halo, "modulate:a", 0.0, .66)
		for index in 12:
			var angle := TAU * index / 12.0
			var outward := Vector3(cos(angle), 0.0, sin(angle))
			var spark := sprite(effect, SPARK, outward * .46 + Vector3.DOWN * .74, .19, tint.lightened(.42))
			spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			var duration := .76 + (index % 3) * .12
			pulse.tween_property(spark, "position", outward * 1.14 + Vector3.UP * 1.30, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			pulse.tween_property(spark, "modulate:a", 0.0, duration - .26).set_delay(.26)
	pulse.chain().tween_callback(effect.queue_free)
	return effect

static func explosion(parent: Node3D, tint: Color) -> void:
	preload("res://scripts/pack_combat_vfx.gd").explosion(parent, tint, 0.94)
