extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")
const VARIANTS := [
	["Cinder Ink", "161922", "e078ab"],
	["Porcelain Signal", "e8dfcc", "6a38ed"],
	["Ultramarine Alloy", "26387b", "f5f0dc"],
	["Scarlet Circuit", "901b37", "f1ecd0"],
	["Boreal Graphite", "192641", "87a1ff"],
	["Palladium Rust", "a2aab6", "b54b39"],
	["Wasp Porcelain", "e3e9d6", "b9d429"],
	["Orchid Steel", "704885", "c8eb8a"],
	["Midnight Brass", "302421", "bca87d"],
	["Ivory Eclipse", "f1e4e3", "946d77"],
]

const STORE := {
	"paint:prism": ["Prism Ceramic", "e6a9ae", "5f2274", 5200],
	"paint:mariner": ["Night Mariner", "14756b", "a1cff4", 6800],
	"paint:forge": ["Garnet Titanium", "211116", "cd3768", 8200],
	"paint:crown": ["Imperial Opal", "d9ced7", "4d62cb", 10000],
}

static func palette(id: String) -> Array:
	if STORE.has(id):
		return STORE[id]
	if id.begins_with("variant:"):
		var index := int(id.trim_prefix("variant:")) - 1
		if index >= 0 and index < VARIANTS.size():
			return VARIANTS[index]
	return []

static func label(id: String) -> String:
	if STORE.has(id):
		return STORE[id][0]
	if id.begins_with("variant:"):
		var index := int(id.trim_prefix("variant:")) - 1
		return VARIANTS[index][0] if index >= 0 and index < VARIANTS.size() else "Standard Frame"
	var weapon := Catalog.weapon(id)
	return String(weapon.get("reward_name", "Standard Frame"))
