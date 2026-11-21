extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")
const COSMETIC_EPOCH := 1
const FIELD_REQUIREMENTS := [5, 4, 4, 4, 4, 4, 4, 4, 12, 5]
const EXPERT_REQUIREMENT := 2
const BOSS_REQUIREMENT := 2
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

const EXPERT_TITLES := [
	"Quench the Furnace", "Uproot the Colossus", "Shatter the Cold",
	"Tame the Undertow", "Unseal the Archives", "Clear for Landing",
	"Quarantine Lifted", "Lights Out in Orbit", "Nothing Left to Rust",
	"Break the Override",
]

# Albedo, inset enamel, lamp color, and the named achievement for each finish.
const FIELD_VARIANTS := [
	["Rivet Copper", "b3b3b8", "79492f", "ffdfb7", "Signal Received", "Extract from any sector five times."],
	["Claystorm", "c78b7c", "354458", "ffebd9", "Patrol Offline", "Defeat 12 security units and extract in four runs."],
	["Blue Hour", "3f527a", "c5aa79", "fff0cf", "Nothing Goes to Scrap", "Extract with at least 5 recovered materials in four runs."],
	["Ivory Alloy", "d7c9b3", "5e453a", "fdeadd", "Hazard Pay", "Earn 200 Bolts and extract in four runs."],
	["Iron Plum", "62536f", "c6a18e", "ffd9e8", "Armor Still Holding", "Extract with at least 85% health in four runs."],
	["Juniper Pearl", "4c7165", "c2b7d2", "eedbff", "Power to Spare", "Extract with at least 90% energy in four runs."],
	["Solar Graphite", "575d64", "e0be84", "fff1cb", "Before Shift Change", "Extract within 8 minutes in four runs."],
	["Oyster Violet", "c2b8d3", "483955", "fce8ff", "One More Reboot", "Extract without losing a life in four runs."],
	["Merlot Slate", "692f4a", "8fa9be", "ffe2db", "Back on the Roster", "Extract twelve times."],
	["Fossil Brass", "a38d5c", "384544", "fff1ce", "District Hopper", "Extract from five different sectors."],
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

static func record_field_finishes(run: Dictionary, progress: Dictionary, visited: int) -> Array[String]:
	var elapsed := float(run.get("seconds", 0.0))
	var goals := [
		true, int(run.get("kills", 0)) >= 12, int(run.get("materials", 0)) >= 5,
		int(run.get("bolts", 0)) >= 200, float(run.get("health", 0.0)) >= 85.0,
		float(run.get("energy", 0.0)) >= 90.0, elapsed > 0.0 and elapsed <= 480.0,
		bool(run.get("clean", false)), true, false,
	]
	var eligible: Array[String] = []
	for index in goals.size():
		var id := field_finish(index + 1)
		if goals[index]:
			progress[id] = mini(int(progress.get(id, 0)) + 1, FIELD_REQUIREMENTS[index])
		var count := visited if index == goals.size() - 1 else int(progress.get(id, 0))
		if count >= FIELD_REQUIREMENTS[index]:
			eligible.append(id)
	return eligible

static func expert_requirement(sector: int) -> String:
	return "Extract from %s on Expert twice." % Catalog.info(sector).title

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
		return [EXPERT_TITLES[sector - 1], 30, "%s Unlocks %s." % [expert_requirement(sector), paint[0]]]
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
