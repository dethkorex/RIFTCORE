extends RefCounted

const Materials := preload("res://scripts/fabrication_catalog.gd")
const RARITIES := ["Common", "Rare", "Epic", "Legendary"]
const MATERIAL_PRICES := {"scrap": 75, "components": 80, "circuits": 135, "cells": 105}
const SECTOR_BUNDLE_PRICES := [125, 190, 320, 490]
const MATERIAL_STOCK := [
	["scrap", 12, 0, 1], ["components", 8, 0, 1], ["circuits", 6, 1, 10], ["cells", 8, 1, 5],
	["core", 1, 2, 30], ["legendary", 1, 3, 50], ["sector_1", 4, 0, 1], ["sector_2", 4, 0, 5],
	["sector_3", 4, 1, 10], ["sector_4", 4, 1, 15], ["sector_5", 4, 1, 20], ["sector_6", 4, 1, 25],
	["sector_7", 4, 2, 30], ["sector_8", 4, 2, 35], ["sector_9", 4, 2, 40], ["sector_10", 4, 3, 45],
]
const MEDICAL := [
	["patch_kit", "Patch Kit", 0, 30, 0, 1], ["repair_foam", "Repair Foam", 0, 39, 0, 5],
	["field_dressing", "Field Dressing", 0, 45, 0, 10], ["trauma_kit", "Trauma Kit", 1, 54, 0, 15],
	["nanogel", "Nanogel", 1, 58, 0, 20], ["rebuild_capsule", "Rebuild Capsule", 2, 82, 0, 30],
	["phoenix_gel", "Phoenix Gel", 3, 160, 0, 50],
	["spark_cell", "Spark Cell", 0, 0, 25, 1], ["pulse_cell", "Pulse Cell", 0, 0, 34, 5],
	["flux_flask", "Flux Flask", 0, 0, 42, 10], ["ion_cell", "Ion Cell", 1, 0, 50, 15],
	["arc_reserve", "Arc Reserve", 1, 0, 56, 20], ["nova_cell", "Nova Cell", 2, 0, 78, 30],
	["nexus_cell", "Nexus Cell", 3, 0, 150, 45],
	["field_pack", "Field Pack", 0, 22, 20, 1], ["resupply_pack", "Resupply Pack", 1, 38, 32, 15],
	["reserve_pack", "Reserve Pack", 2, 55, 45, 25], ["emergency_cache", "Emergency Cache", 3, 105, 90, 40],
]
const BOOSTS := [
	["strike_amp", "Strike Amp", 0, "attack", 0.16, 24, 1], ["pulse_amp", "Pulse Amp", 1, "attack", 0.22, 28, 15],
	["plasma_amp", "Plasma Amp", 2, "attack", 0.30, 30, 30], ["nova_amp", "Nova Amp", 3, "attack", 0.42, 36, 45],
	["guard_film", "Guard Film", 0, "defense", 0.14, 24, 1], ["shield_coat", "Shield Coat", 1, "defense", 0.19, 28, 15],
	["aegis_coat", "Aegis Coat", 2, "defense", 0.24, 30, 30], ["bastion_coat", "Bastion Coat", 3, "defense", 0.32, 36, 45],
	["stride_gel", "Stride Gel", 0, "speed", 0.11, 24, 1], ["runner_gel", "Runner Gel", 1, "speed", 0.15, 28, 15],
	["vector_gel", "Vector Gel", 2, "speed", 0.18, 30, 30], ["rift_gel", "Rift Gel", 3, "speed", 0.24, 36, 45],
	["strike_serum", "Strike Serum", 1, "attack", 0.14, 45, 20], ["guard_serum", "Guard Serum", 1, "defense", 0.12, 45, 20],
	["runner_serum", "Runner Serum", 2, "speed", 0.12, 55, 35], ["nova_serum", "Nova Serum", 3, "attack", 0.26, 60, 50],
]

static func catalog() -> Dictionary:
	var stock := {}
	for entry in MATERIAL_STOCK:
		var price: int = MATERIAL_PRICES.get(entry[0], SECTOR_BUNDLE_PRICES[entry[2]])
		stock["material_" + entry[0]] = {"name": Materials.label(entry[0]), "material": entry[0], "quantity": entry[1],
			"rarity": entry[2], "price": price, "shop_level": entry[3],
			"detail": "%d crafting materials" % entry[1], "icon": "core"}
	for entry in MEDICAL:
		var parts := PackedStringArray()
		if entry[3] > 0:
			parts.append("Restore %d HP" % entry[3])
		if entry[4] > 0:
			parts.append("Restore %d energy" % entry[4])
		var recovery: float = entry[3] + entry[4] * .86
		var price := maxi(30, roundi(recovery * [1.20, 1.42, 1.72, 2.0][entry[2]] / 5.0) * 5)
		stock[entry[0]] = {"name": entry[1], "rarity": entry[2], "price": price, "hp": entry[3],
			"energy": entry[4], "shop_level": entry[5], "detail": "  ·  ".join(parts), "icon": "frame" if entry[3] > 0 else "core"}
	for entry in BOOSTS:
		var strength: float = entry[4] * entry[5]
		var price := roundi(([20, 36, 62, 115][entry[2]] + strength * 6.0) / 5.0) * 5
		stock[entry[0]] = {"name": entry[1], "rarity": entry[2], "price": price, "stat": entry[3],
			"gain": entry[4], "duration": entry[5], "shop_level": entry[6],
			"detail": "+%d%% %s for %d seconds" % [roundi(entry[4] * 100), entry[3], entry[5]],
			"icon": {"attack": "arm", "defense": "frame", "speed": "utility"}[entry[3]]}
	return stock
