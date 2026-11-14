extends RefCounted

const SECTOR_NAMES := ["Forge", "Canopy", "Cryo", "Abyss", "Cipher", "Jetstream", "Splice", "Orbital", "Scrap", "Nexus"]
const PARTS := [
	["Reactive Liner", "frame", "resist", 0, 0.040, 0.003],
	["Reinforced Plating", "frame", "hp", 0, 7, 1],
	["Pulse Calibrator", "core", "attack", 0, 1.04, 0.005],
	["Reserve Capacitor", "core", "energy", 0, 7, 1],
	["Traversal Jets", "utility", "dash", 1, 1.06, 0.006],
	["Recovery Bearings", "utility", "cooldown", 1, 0.94, -0.007],
	["Recon Optics", "visor", "xp", 1, 1.12, 0.012],
	["Repair Actuator", "arm", "healing", 2, 1.18, 0.013],
	["Charge Regulator", "core", "charge", 2, 0.92, -0.011],
	["Aegis Chassis", "frame", "resist", 3, 0.12, 0.008],
	["Overdrive Arm", "arm", "attack", 3, 1.14, 0.014],
	["Salvage Optics", "visor", "bolts", 2, 1.22, 0.022],
	["Commander Plating", "frame", "resist", 2, 0.105, 0.006],
	["Overseer Core", "core", "attack", 3, 1.18, 0.014],
	["Boss Relay", "utility", "dash", 1, 1.13, 0.008],
]
const FIRST_BOSS_PART := 12
const EFFECTS := {
	"resist": "%.0f%% damage resistance", "hp": "+%.0f maximum HP",
	"attack": "+%.0f%% Buster and saber damage", "energy": "+%.0f maximum energy",
	"dash": "+%.0f%% dash speed", "cooldown": "%.0f%% shorter dash cooldown",
	"xp": "+%.0f%% XP from pickups", "healing": "+%.0f%% healing from pickups",
	"charge": "%.0f%% cheaper charged shots", "bolts": "+%.0f%% bolts from pickups",
}
# Unconditional chances per loot roll, evaluated from rarest to most common.
const RATES := {
	"enemy": [0.007, 0.0025, 0.0008, 0.0002],
	"elite": [0.014, 0.005, 0.0016, 0.0004],
	"container": [0.022, 0.008, 0.0025, 0.0006],
	"miniboss": [0.034, 0.012, 0.004, 0.001],
	"boss": [0.060, 0.024, 0.008, 0.002],
	"boss_cache": [0.0, 0.105, 0.045, 0.012],
}

static func all_gear(legacy: Dictionary) -> Dictionary:
	var result := legacy.duplicate()
	for sector in SECTOR_NAMES.size():
		for part in PARTS.size():
			var definition: Array = PARTS[part]
			var stat: String = definition[2]
			var value := float(definition[4]) + float(definition[5]) * sector
			var amount := value if stat in ["hp", "energy"] else absf(value - (0.0 if stat == "resist" else 1.0)) * 100.0
			result[blueprint_id(sector + 1, part)] = {
				"name": "%s %s" % [SECTOR_NAMES[sector], definition[0]], "slot": definition[1],
				"rarity": definition[3], "sector": sector + 1, "perk": EFFECTS[stat] % amount,
				"boss_only": part >= FIRST_BOSS_PART,
				"stats": {stat: value},
			}
	return result

static func blueprint_id(sector: int, part: int) -> String:
	return "bp_%02d_%02d" % [sector, part]

static func roll(sector: int, source: String, rng: RandomNumberGenerator, loot_scale := 1.0) -> String:
	var rates: Array = RATES.get(source, RATES.enemy)
	var chance := rng.randf()
	for rarity in range(3, -1, -1):
		chance -= rates[rarity] * (1.0 + (loot_scale - 1.0) * (0.5 + 0.25 * rarity))
		if chance < 0:
			var pool: Array[int] = []
			for index in PARTS.size():
				if PARTS[index][3] == rarity and (index >= FIRST_BOSS_PART) == (source == "boss_cache"):
					pool.append(index)
			return blueprint_id(sector, pool[rng.randi_range(0, pool.size() - 1)])
	return ""
