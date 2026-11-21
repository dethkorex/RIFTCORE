extends RefCounted

const Difficulty := preload("res://scripts/mission_difficulty.gd")

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

static func component_sources(sector: int) -> Array:
	return COMPONENT_POOLS[clampi(sector, 1, COMPONENT_POOLS.size()) - 1]

static func pool(sector: int) -> Array:
	return ["scrap", "core", "legendary", sector_key(sector)] + component_sources(sector)

static func roll(sector: int, budget: int, mode: int, level: int, rng: RandomNumberGenerator, boss := false) -> Dictionary:
	var difficulty := Difficulty.index(mode)
	var level_bonus := clampi(level - 1, 0, Difficulty.PLAYER_LEVEL_CAP - 1) * .003
	var bonus: float = level_bonus + [0.0, .12, .25][difficulty]
	var sector_part := sector_key(sector)
	var components := component_sources(sector)
	var keys := ["scrap", components[0], components[1], sector_part]
	var drops: Array[String] = []
	for key: String in keys:
		var chance: float = {"scrap": .87, "components": .73, "cells": .61, "circuits": .54}.get(key, .48)
		if rng.randf() < minf(.97, chance + bonus + (.10 if boss else 0.0)):
			drops.append(key)
	if drops.is_empty():
		drops.append(keys[rng.randi_range(0, keys.size() - 1)])
	if boss and sector_part not in drops:
		drops.append(sector_part)
	var result := {}
	while result.size() < budget and not drops.is_empty():
		var key: String = drops.pop_at(rng.randi_range(0, drops.size() - 1))
		result[key] = 1
	# Larger caches can add an extra unit to a part they already rolled.
	if budget > keys.size() and result.size() > 1 and rng.randf() < .40 + bonus:
		var picked: Array = result.keys()
		result[picked[rng.randi_range(0, picked.size() - 1)]] += 1
	if boss:
		result["core"] = 1
		if rng.randf() < [0.22, 0.36, 0.55][difficulty] + level_bonus:
			result["legendary"] = 1
	return result
