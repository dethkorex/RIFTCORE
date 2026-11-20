extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")
# Exterior ceramic, inset enamel, and luminous hardware are painted separately.
const VARIANTS := [
	["Obsidian Silver", "41444c", "9cabb9", "edf5ff"],
	["Orchid Porcelain", "efdcbb", "664765", "f5c5da"],
	["Signal Saffron", "d6ae43", "30373d", "fff3b3"],
	["Oxblood Nickel", "822739", "c0b6ab", "ffe0d1"],
	["Copper Tide", "28636a", "ad7461", "ffd2a7"],
	["Dune Onyx", "bd9d79", "3f302e", "fff4de"],
	["Iolite Steel", "9293bf", "333855", "e4e4ff"],
	["Verdigris Pearl", "a8c6b8", "27494e", "f1dfab"],
	["Rose Carbon", "403941", "c3868d", "ffd9e7"],
	["Chalk and Ink", "eeeff3", "292a30", "e6e8ef"],
]

const LEGACY_FINISHES := {
	"paint:prism": ["Prism Ceramic", "e2bfc8", "664368", "f5d3fc"],
	"paint:mariner": ["Night Mariner", "28545a", "a0b8c6", "e1f7f8"],
	"paint:forge": ["Garnet Titanium", "562735", "9a5067", "ffe0e6"],
	"paint:crown": ["Imperial Opal", "d4c9d6", "515d8c", "e5ebff"],
}

static func expert_finish(sector: int) -> String:
	return "variant:%d" % sector if sector >= 1 and sector <= VARIANTS.size() else ""

static func palette(id: String) -> Array:
	if LEGACY_FINISHES.has(id):
		return LEGACY_FINISHES[id]
	if id.begins_with("variant:"):
		var index := int(id.trim_prefix("variant:")) - 1
		if index >= 0 and index < VARIANTS.size():
			return VARIANTS[index]
	return []

static func label(id: String) -> String:
	var paint := palette(id)
	return paint[0] if not paint.is_empty() else String(Catalog.weapon(id).get("reward_name", "Standard Frame"))
