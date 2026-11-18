extends RefCounted

static func present(actor: RiftPlayer) -> void:
	if actor.health<=0.0:
		if not actor.has_meta(&"corpse_visual"):
			actor.set_meta(&"corpse_visual",actor.model_root.transform)
			actor.play_character_animation("land",true)
			if actor.animation_player and actor.animation_player.has_animation("land"):
				actor.animation_player.seek(actor.animation_player.get_animation("land").length*.7,true)
				actor.animation_player.pause()
			for modifier in [actor.buster_pose,actor.slide_pose,actor.climb_pose]:
				if modifier: modifier.influence=0.0
		actor.model_root.position=Vector3(.72,-actor.standing_capsule.height*.5+.20,0)
		actor.model_root.basis=Basis(Vector3.BACK,PI*.5)*Basis(Vector3.UP,actor.facing*PI*.5)
		actor.show()
	elif actor.has_meta(&"corpse_visual"):
		actor.model_root.transform=actor.get_meta(&"corpse_visual")
		actor.remove_meta(&"corpse_visual")
		actor.play_character_animation("idle",true)
		actor.show()
