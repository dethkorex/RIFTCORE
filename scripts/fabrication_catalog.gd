extends RefCounted

const COMMON := {"scrap": "Industrial Scrap", "components": "Mechanical Components",
	"circuits": "Advanced Circuits", "cells": "Energy Cells", "core": "Boss Core", "legendary": "Fracture Crystal"}
const SECTOR_MATERIALS := [
	"Forge Alloy", "Conductive Sap", "Cryo Quartz", "Pressure Pearl", "Cipher Glass",
	"Storm Filament", "Splice Tissue", "Solar Foil", "Magnetite", "Nexus Residue",
]
const COMPONENT_POOLS := [
	["components", "cells"], ["cells", "components"], ["cells", "circuits"],
	["circuits", "cells"], ["circuits", "components"], ["components", "circuits"],
	["cells", "components"], ["cells", "circuits"], ["components", "cells"], ["circuits", "components"],
]

static func sector_key(sector: int) -> String:
	return "sector_%d" % clampi(sector, 1, SECTOR_MATERIALS.size())

static func label(id: String) -> String:
	if id.begins_with("sector_"):
		var number := id.get_slice("_", 1).to_int()
		if number >= 1 and number <= SECTOR_MATERIALS.size():
			return SECTOR_MATERIALS[number - 1]
	return COMMON.get(id, id.capitalize())

static func pool(sector: int) -> Array:
	return ["scrap", "core", "legendary", sector_key(sector)] + COMPONENT_POOLS[clampi(sector, 1, COMPONENT_POOLS.size()) - 1]

static func roll(sector: int, source: String, rng: RandomNumberGenerator, loot_scale := 1.0) -> Dictionary:
	var result := {"scrap": rng.randi_range(1, 3)}
	var components: Array = COMPONENT_POOLS[clampi(sector, 1, COMPONENT_POOLS.size()) - 1]
	result[components[0 if rng.randf() < 0.67 else 1]] = 1 if source == "enemy" else 2
	if source != "enemy" or rng.randf() < 0.16 * loot_scale:
		result[sector_key(sector)] = 1
	if source == "boss":
		result["core"] = 1
	if source in ["boss", "elite"] and rng.randf() < (0.22 if source == "boss" else 0.06) * loot_scale:
		result["legendary"] = 1
	return result
