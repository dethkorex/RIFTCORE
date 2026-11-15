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
	["Riftbreaker Core", "core", "attack", 3, 1.58, 0.016],
	["Singularity Shell", "frame", "resist", 3, 0.27, 0.010],
	["Phase Runner", "utility", "dash", 3, 1.39, 0.016],
]
const FIRST_BOSS_PART := 12
const FIRST_NIGHTMARE_PART := 15
const EFFECTS := {
	"resist": "%.0f%% damage resistance", "hp": "+%.0f maximum HP",
	"attack": "+%.0f%% Buster and saber damage", "energy": "+%.0f maximum energy",
	"dash": "+%.0f%% dash speed", "cooldown": "%.0f%% shorter dash cooldown",
	"xp": "+%.0f%% XP from kills", "healing": "+%.0f%% healing from pickups",
	"charge": "%.0f%% cheaper charged shots", "bolts": "+%.0f%% bolts from pickups",
}
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const CACHE_RATE := 0.085

static func rarity_for(part: int) -> int:
	return 0 if part == 14 else int(PARTS[part][3])

static func blueprint_level(sector: int, part: int) -> int:
	if part == 14:
		return 1
	var baseline := Difficulty.recommended_level(sector, Difficulty.NORMAL)
	var rarity := rarity_for(part)
	if rarity == 0:
		return baseline + part % 4
	return mini(Difficulty.PLAYER_LEVEL_CAP, baseline + [0, 4, 7, 10][rarity] + part % 3)

static func maximum_rarity(sector: int, mode: int) -> int:
	return mini(3, floori(float(sector - 1) / 3.0) + mode)

static func drop_pool(sector: int, mode: int, level: int, boss_cache: bool) -> Array[int]:
	var pool: Array[int] = []
	var next := Difficulty.recommended_level(sector + 1, mode)
	if sector == SECTOR_NAMES.size():
		next += 7
	var ceiling := mini(level, next)
	for part in PARTS.size():
		if part >= FIRST_NIGHTMARE_PART and (mode != Difficulty.NIGHTMARE or not boss_cache):
			continue
		if part >= FIRST_BOSS_PART and not boss_cache:
			continue
		if blueprint_level(sector, part) <= ceiling and rarity_for(part) <= maximum_rarity(sector, mode):
			pool.append(part)
	return pool

static func roll_cache(sector: int, mode: int, level: int, boss_cache: bool, rng: RandomNumberGenerator) -> String:
	if not boss_cache and rng.randf() >= CACHE_RATE * Difficulty.LOOT[mode]:
		return ""
	var pool := drop_pool(sector, mode, level, boss_cache)
	if pool.is_empty():
		# The boss reward stays guaranteed for under-level deployments.
		# Supply a starter plan that the operator can use.
		return blueprint_id(sector, 14) if boss_cache else ""
	var weights := PackedFloat32Array()
	for part in pool:
		var rarity := rarity_for(part)
		var improvement := pow(Difficulty.LOOT[mode], rarity)
		weights.append(float([1.0, .26, .085, .024][rarity]) * improvement)
	return blueprint_id(sector, pool[rng.rand_weighted(weights)])

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
				"rarity": rarity_for(part), "level": blueprint_level(sector + 1, part), "sector": sector + 1, "perk": EFFECTS[stat] % amount,
				"boss_only": part >= FIRST_BOSS_PART,
				"nightmare_only": part >= FIRST_NIGHTMARE_PART,
				"stats": {stat: value},
			}
	return result

static func blueprint_id(sector: int, part: int) -> String:
	return "bp_%02d_%02d" % [sector, part]
