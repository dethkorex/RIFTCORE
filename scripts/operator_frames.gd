extends RefCounted

const NAMES := {
	"": "Standard Frame",
	"relay": "Relay",
	"kestrel": "Kestrel",
	"bastion": "Bastion",
	"vector": "Vector",
	"aegis": "Aegis",
}

const COSMETIC_EPOCH := preload("res://scripts/operator_skins.gd").COSMETIC_EPOCH
const PRICES := {"relay": 10000, "kestrel": 15000, "bastion": 23000, "vector": 32000, "aegis": 44000}

static func current_wardrobe(save: ConfigFile) -> bool:
	return save != null and int(save.get_value("wardrobe", "epoch", 0)) == COSMETIC_EPOCH

static func owned(id: String, save: ConfigFile) -> bool:
	return id.is_empty() or (current_wardrobe(save) and id in save.get_value("wardrobe", "owned_frames", []))

static func model_path(id: String) -> String:
	return "res://assets/models/operator_frames/%s.glb" % id

static func available(id: String) -> bool:
	return id.is_empty() or (NAMES.has(id) and ResourceLoader.exists(model_path(id), "PackedScene"))

static func label(id: String) -> String:
	return NAMES.get(id, NAMES[""])

static func load_model(id: String) -> PackedScene:
	return load(model_path(id)) as PackedScene if not id.is_empty() and available(id) else null
