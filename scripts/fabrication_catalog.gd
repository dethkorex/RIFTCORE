extends RefCounted

const COMMON := {"scrap": "Industrial Scrap", "components": "Mechanical Components",
	"circuits": "Advanced Circuits", "cells": "Energy Cells", "core": "Boss Core", "legendary": "Fracture Crystal"}
const SECTOR_MATERIALS := [
	"Forge Alloy", "Conductive Sap", "Cryo Quartz", "Pressure Pearl", "Cipher Glass",
	"Storm Filament", "Splice Tissue", "Solar Foil", "Magnetite", "Nexus Residue",
]

static func sector_key(sector: int) -> String:
	return "sector_%d" % clampi(sector, 1, SECTOR_MATERIALS.size())

static func label(id: String) -> String:
	if id.begins_with("sector_"):
		var number := id.get_slice("_", 1).to_int()
		if number >= 1 and number <= SECTOR_MATERIALS.size():
			return SECTOR_MATERIALS[number - 1]
	return COMMON.get(id, id.capitalize())

static func roll(sector: int, source: String, rng: RandomNumberGenerator) -> Dictionary:
	var result := {"scrap": rng.randi_range(1, 3)}
	var table := [
		["components", "circuits", "cells"], ["cells", "components", "circuits"],
		["cells", "circuits", "components"], ["circuits", "cells", "components"],
		["circuits", "components", "cells"], ["components", "cells", "circuits"],
		["cells", "circuits", "components"], ["cells", "components", "circuits"],
		["components", "circuits", "cells"], ["circuits", "cells", "components"],
	]
	var tier: Array = table[clampi(sector, 1, table.size()) - 1]
	result[tier[rng.rand_weighted(PackedFloat32Array([0.55, 0.30, 0.15]))]] = 1 if source == "enemy" else 2
	if source != "enemy" or rng.randf() < 0.16:
		result[sector_key(sector)] = 1
	if source == "boss":
		result["core"] = 1
	if source in ["boss", "elite"] and rng.randf() < (0.22 if source == "boss" else 0.06):
		result["legendary"] = 1
	return result
