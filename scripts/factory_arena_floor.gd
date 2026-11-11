extends StaticBody3D

func _ready() -> void:
	# One continuous physics surface prevents capsule snags at the arena's modular seams.
	for part in ["GateLanding", "ArenaEntry", "ArenaCenter", "ArenaExit", "ArenaExtension", "ArenaEnd"]:
		var tile := get_parent().get_node_or_null("TERRAIN/" + part + "/Body0") as StaticBody3D
		if tile:
			tile.collision_layer = 0
