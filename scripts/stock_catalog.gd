extends RefCounted

const Materials := preload("res://scripts/fabrication_catalog.gd")
const RARITIES := ["Common", "Rare", "Epic", "Legendary"]
const PRICES := [175, 425, 1050, 2400]
const MATERIAL_STOCK := [
	["scrap", 15, 0], ["components", 8, 0], ["circuits", 5, 1], ["cells", 6, 1],
	["core", 1, 2], ["legendary", 1, 3], ["sector_1", 4, 0], ["sector_2", 4, 0],
	["sector_3", 4, 1], ["sector_4", 4, 1], ["sector_5", 4, 1], ["sector_6", 4, 1],
	["sector_7", 4, 2], ["sector_8", 4, 2], ["sector_9", 4, 2], ["sector_10", 4, 3],
]
const MEDICAL := [
	["patch_kit", "Patch Kit", 0, 18, 0], ["repair_foam", "Repair Foam", 0, 27, 0],
	["field_dressing", "Field Dressing", 0, 34, 0], ["trauma_kit", "Trauma Kit", 1, 46, 0],
	["nanogel", "Nanogel", 1, 58, 0], ["rebuild_capsule", "Rebuild Capsule", 2, 82, 0],
	["phoenix_gel", "Phoenix Gel", 3, 160, 0],
	["spark_cell", "Spark Cell", 0, 0, 15], ["pulse_cell", "Pulse Cell", 0, 0, 24],
	["flux_flask", "Flux Flask", 0, 0, 31], ["ion_cell", "Ion Cell", 1, 0, 44],
	["arc_reserve", "Arc Reserve", 1, 0, 56], ["nova_cell", "Nova Cell", 2, 0, 78],
	["nexus_cell", "Nexus Cell", 3, 0, 150],
	["field_pack", "Field Pack", 0, 12, 12], ["resupply_pack", "Resupply Pack", 1, 32, 27],
	["reserve_pack", "Reserve Pack", 2, 55, 45], ["emergency_cache", "Emergency Cache", 3, 105, 90],
]
const BOOSTS := [
	["strike_amp", "Strike Amp", 0, "attack", 0.12, 18], ["pulse_amp", "Pulse Amp", 1, "attack", 0.20, 24],
	["plasma_amp", "Plasma Amp", 2, "attack", 0.30, 30], ["nova_amp", "Nova Amp", 3, "attack", 0.42, 36],
	["guard_film", "Guard Film", 0, "defense", 0.10, 18], ["shield_coat", "Shield Coat", 1, "defense", 0.17, 24],
	["aegis_coat", "Aegis Coat", 2, "defense", 0.24, 30], ["bastion_coat", "Bastion Coat", 3, "defense", 0.32, 36],
	["stride_gel", "Stride Gel", 0, "speed", 0.08, 18], ["runner_gel", "Runner Gel", 1, "speed", 0.13, 24],
	["vector_gel", "Vector Gel", 2, "speed", 0.18, 30], ["rift_gel", "Rift Gel", 3, "speed", 0.24, 36],
	["strike_serum", "Strike Serum", 1, "attack", 0.14, 45], ["guard_serum", "Guard Serum", 1, "defense", 0.12, 45],
	["runner_serum", "Runner Serum", 2, "speed", 0.12, 55], ["nova_serum", "Nova Serum", 3, "attack", 0.26, 60],
]

static func catalog() -> Dictionary:
	var stock := {}
	for entry in MATERIAL_STOCK:
		stock["material_" + entry[0]] = {"name": Materials.label(entry[0]), "material": entry[0], "quantity": entry[1],
			"rarity": entry[2], "price": PRICES[entry[2]], "detail": "%d crafting materials" % entry[1], "icon": "core"}
	for entry in MEDICAL:
		var parts := PackedStringArray()
		if entry[3] > 0:
			parts.append("Restore %d HP" % entry[3])
		if entry[4] > 0:
			parts.append("Restore %d energy" % entry[4])
		stock[entry[0]] = {"name": entry[1], "rarity": entry[2], "price": PRICES[entry[2]], "hp": entry[3],
			"energy": entry[4], "detail": "  ·  ".join(parts), "icon": "frame" if entry[3] > 0 else "core"}
	for entry in BOOSTS:
		stock[entry[0]] = {"name": entry[1], "rarity": entry[2], "price": PRICES[entry[2]], "stat": entry[3],
			"gain": entry[4], "duration": entry[5], "detail": "+%d%% %s for %d seconds" % [roundi(entry[4] * 100), entry[3], entry[5]],
			"icon": {"attack": "arm", "defense": "frame", "speed": "utility"}[entry[3]]}
	return stock
