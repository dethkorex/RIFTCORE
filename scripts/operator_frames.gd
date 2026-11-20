extends RefCounted

const NAMES := {
	"": "Standard Frame",
	"relay": "Relay",
	"kestrel": "Kestrel",
	"bastion": "Bastion",
	"vector": "Vector",
	"aegis": "Aegis",
}

const PRICES := {"relay": 8000, "kestrel": 12000, "bastion": 18000, "vector": 25000, "aegis": 35000}

static func owned(id: String, save: ConfigFile) -> bool:
	return id.is_empty() or (save != null and id in save.get_value("wardrobe", "owned_frames", []))

static func model_path(id: String) -> String:
	return "res://assets/models/operator_frames/%s.glb" % id

static func available(id: String) -> bool:
	return id.is_empty() or (NAMES.has(id) and ResourceLoader.exists(model_path(id), "PackedScene"))

static func label(id: String) -> String:
	return NAMES.get(id, NAMES[""])

static func load_model(id: String) -> PackedScene:
	return load(model_path(id)) as PackedScene if not id.is_empty() and available(id) else null
