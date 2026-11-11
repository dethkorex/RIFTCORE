extends Label3D

func animate(amount: float, hurt_player: bool, burning := false) -> void:
	text = "%.1f" % amount if absf(amount - roundf(amount)) > 0.05 else "%d" % roundi(amount)
	font_size = 74 if hurt_player else 65
	pixel_size = 0.0034
	outline_size = 14
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	modulate = Color("ff7b85") if hurt_player else (Color("ff8a44") if burning else Color("ffe6a9"))
	var rise := create_tween().set_parallel()
	rise.tween_property(self, "position", position + Vector3(randf_range(-0.12, 0.12), 0.64, 0), 0.53).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(self, "modulate:a", 0.0, 0.22).set_delay(0.31)
	rise.chain().tween_callback(queue_free)
