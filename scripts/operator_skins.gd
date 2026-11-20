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

# Albedo, inset enamel, lamp color, and the named achievement for each finish.
const FIELD_VARIANTS := [
	["Rivet Copper", "b3b3b8", "79492f", "ffdfb7", "First Extraction", "Extract from any sector."],
	["Claystorm", "c78b7c", "354458", "ffebd9", "Security Detail", "Defeat 6 security units in a run and extract."],
	["Blue Hour", "3f527a", "c5aa79", "fff0cf", "Cache Runner", "Extract with at least 3 recovered materials."],
	["Ivory Alloy", "d7c9b3", "5e453a", "fdeadd", "Field Payout", "Earn 80 Bolts in one run and extract."],
	["Iron Plum", "62536f", "c6a18e", "ffd9e8", "Hull Check", "Extract with at least 50% health."],
	["Juniper Pearl", "4c7165", "c2b7d2", "eedbff", "Charged Return", "Extract with at least 50% energy."],
	["Solar Graphite", "575d64", "e0be84", "fff1cb", "Scout’s Pace", "Extract within 15 minutes."],
	["Oyster Violet", "c2b8d3", "483955", "fce8ff", "Spare in the Bank", "Extract with at least one life remaining."],
	["Merlot Slate", "692f4a", "8fa9be", "ffe2db", "Second Shift", "Extract twice."],
	["Fossil Brass", "a38d5c", "384544", "fff1ce", "New Ground", "Extract from two different sectors."],
]

const LEGACY_FINISHES := {
	"paint:prism": ["Prism Ceramic", "e2bfc8", "664368", "f5d3fc"],
	"paint:mariner": ["Night Mariner", "28545a", "a0b8c6", "e1f7f8"],
	"paint:forge": ["Garnet Titanium", "562735", "9a5067", "ffe0e6"],
	"paint:crown": ["Imperial Opal", "d4c9d6", "515d8c", "e5ebff"],
}

static func expert_finish(sector: int) -> String:
	return "variant:%d" % sector if sector >= 1 and sector <= VARIANTS.size() else ""

static func field_finish(index: int) -> String:
	return "field:%d" % index if index >= 1 and index <= FIELD_VARIANTS.size() else ""

static func clear_finish_awards(run: Dictionary, clears: int, sectors: int) -> Array[String]:
	var elapsed := float(run.get("seconds", 0.0))
	var goals := [
		true, int(run.get("kills", 0)) >= 6, int(run.get("materials", 0)) >= 3,
		int(run.get("bolts", 0)) >= 80, float(run.get("health", 0.0)) >= 50.0,
		float(run.get("energy", 0.0)) >= 50.0, elapsed > 0.0 and elapsed <= 900.0,
		int(run.get("lives", 0)) >= 1, clears >= 2, sectors >= 2,
	]
	var earned: Array[String] = []
	for index in goals.size():
		if goals[index]:
			earned.append(field_finish(index + 1))
	return earned

static func achievement_ids() -> Array[String]:
	var result: Array[String] = []
	for index in range(1, FIELD_VARIANTS.size() + 1):
		result.append(field_finish(index))
	for index in range(1, VARIANTS.size() + 1):
		result.append(expert_finish(index))
	return result

static func finish_achievement(id: String) -> Array:
	var paint := palette(id)
	if paint.is_empty():
		return []
	if id.begins_with("field:"):
		return [paint[4], 10, "%s Unlocks %s." % [paint[5], paint[0]]]
	if id.begins_with("variant:"):
		var sector := int(id.trim_prefix("variant:"))
		var title: String = Catalog.info(sector).title
		return ["Expert · " + title, 30, "Clear both acts of %s on Expert. Unlocks %s." % [title, paint[0]]]
	return []

static func palette(id: String) -> Array:
	if LEGACY_FINISHES.has(id):
		return LEGACY_FINISHES[id]
	if id.begins_with("field:"):
		var field_index := int(id.trim_prefix("field:")) - 1
		if field_index >= 0 and field_index < FIELD_VARIANTS.size():
			return FIELD_VARIANTS[field_index]
	if id.begins_with("variant:"):
		var index := int(id.trim_prefix("variant:")) - 1
		if index >= 0 and index < VARIANTS.size():
			return VARIANTS[index]
	return []

static func label(id: String) -> String:
	var paint := palette(id)
	return paint[0] if not paint.is_empty() else String(Catalog.weapon(id).get("reward_name", "Standard Frame"))
