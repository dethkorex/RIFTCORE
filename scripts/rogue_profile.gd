extends RefCounted

signal quick_changed

const Catalog := preload("res://scripts/sector_catalog.gd")
const CHALLENGES := [
	{"name": "Gatebreaker", "objective": "Defeat the Act 1 miniboss and enter Act 2.", "credits": 120, "step": 15},
	{"name": "Sector Clear", "objective": "Defeat the Act 2 boss and reach extraction.", "credits": 240, "step": 25},
	{"name": "Clean Run", "objective": "Clear both acts in the same run without losing a life.", "credits": 420, "step": 35},
]

const UPGRADES := [
	{"id": "armor", "name": "Ceramic Armor", "prices": [15, 28], "effects": ["+12 starting HP", "+28 starting HP and 10% damage resistance"]},
	{"id": "capacitor", "name": "Flux Capacitor", "prices": [19, 34], "effects": ["+15 starting energy", "+32 starting energy and 20% cheaper charged shots"]},
	{"id": "buster", "name": "Buster Overdrive", "prices": [25, 41], "effects": ["+15% Buster and saber damage", "+32% Buster and saber damage"]},
	{"id": "dash", "name": "Vector Drive", "prices": [31, 47], "effects": ["+10% dash speed and 15% shorter cooldown", "+20% dash speed and 32% shorter cooldown"]},
	{"id": "storage", "name": "Storage Expansion", "prices": [20, 36], "effects": ["+7 storage positions", "+14 storage positions"]},
	{"id": "fabrication", "name": "Fabrication Efficiency", "prices": [20, 36], "effects": ["20% scrap discount", "40% scrap discount"]},
]

const Enhancements := preload("res://scripts/enhancement_catalog.gd")
const Stock := preload("res://scripts/stock_catalog.gd")
static var stock := Stock.catalog()
static var enhancements := Enhancements.catalog()
const QUICK_MAX := 5
const STACK_MAX := 100
var blueprint_items := {}
var inventory := {}
var quick_slots: Array[Dictionary] = [{}, {}, {}, {}]

const GEAR_SLOTS := {"frame": "Frame", "core": "Core", "utility": "Utility", "visor": "Visor", "arm": "Arm Module"}
const UPGRADE_SLOTS := {"armor": "frame", "capacitor": "core", "buster": "core", "dash": "utility", "storage": "utility", "fabrication": "core"}
const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color("b5c9de"), Color("68c9ff"), Color("d0a0ff"), Color("ffca68")]
const PRESET_COUNT := 3
const Blueprints := preload("res://scripts/blueprint_catalog.gd")
const LEGACY_GEAR := {
	"impact_liner": {"name": "Impact Liner", "slot": "frame", "price": 320, "rarity": 0, "perk": "12% damage resistance", "stats": {"resist": 0.12}},
	"vital_weave": {"name": "Vital Weave", "slot": "frame", "price": 360, "rarity": 0, "perk": "+18 maximum HP", "stats": {"hp": 18}},
	"pulse_lens": {"name": "Pulse Lens", "slot": "core", "price": 420, "rarity": 0, "perk": "+14% Buster and saber damage", "stats": {"attack": 1.14}},
	"charge_relay": {"name": "Charge Relay", "slot": "core", "price": 440, "rarity": 0, "perk": "+20 energy and 10% lower charge cost", "stats": {"energy": 20, "charge": 0.9}},
	"air_jets": {"name": "Air Jets", "slot": "utility", "price": 380, "rarity": 0, "perk": "8% faster dash, 12% shorter dash cooldown", "stats": {"dash": 1.08, "cooldown": 0.88}},
	"salvage_chip": {"name": "Salvage Chip", "slot": "utility", "price": 290, "rarity": 0, "perk": "50% more bolts from currency pickups", "stats": {"bolts": 1.5}},
	"shock_brace": {"name": "Shock Brace", "slot": "frame", "price": 620, "rarity": 1, "perk": "+12 HP and 9% damage resistance", "stats": {"hp": 12, "resist": 0.09}},
	"carbon_shell": {"name": "Carbon Shell", "slot": "frame", "price": 780, "rarity": 1, "perk": "+26 maximum HP", "stats": {"hp": 26}},
	"coolant_mesh": {"name": "Coolant Mesh", "slot": "frame", "price": 980, "rarity": 1, "perk": "+18 HP and +14 energy", "stats": {"hp": 18, "energy": 14}},
	"glacier_plate": {"name": "Glacier Plate", "slot": "frame", "price": 1430, "rarity": 2, "perk": "+22 HP and 15% damage resistance", "stats": {"hp": 22, "resist": 0.15}},
	"vanguard_cage": {"name": "Vanguard Cage", "slot": "frame", "price": 1960, "rarity": 2, "perk": "+44 maximum HP", "stats": {"hp": 44}},
	"aegis_shell": {"name": "Aegis Shell", "slot": "frame", "price": 3080, "rarity": 3, "perk": "+32 HP and 19% damage resistance", "stats": {"hp": 32, "resist": 0.19}},
	"berserker_mesh": {"name": "Berserker Mesh", "slot": "frame", "price": 3280, "rarity": 3, "perk": "+19% attack, +12 HP, and 7% damage resistance", "stats": {"hp": 12, "resist": 0.07, "attack": 1.19}},
	"coil_stack": {"name": "Coil Stack", "slot": "core", "price": 640, "rarity": 1, "perk": "+34 maximum energy", "stats": {"energy": 34}},
	"flux_prism": {"name": "Flux Prism", "slot": "core", "price": 920, "rarity": 1, "perk": "+18% attack and 6% lower charge cost", "stats": {"attack": 1.18, "charge": 0.94}},
	"arc_regulator": {"name": "Arc Regulator", "slot": "core", "price": 1150, "rarity": 1, "perk": "+15 energy and 18% lower charge cost", "stats": {"energy": 15, "charge": 0.82}},
	"twin_reactor": {"name": "Twin Reactor", "slot": "core", "price": 1640, "rarity": 2, "perk": "+20% attack and +32 energy", "stats": {"attack": 1.2, "energy": 32}},
	"phase_condenser": {"name": "Phase Condenser", "slot": "core", "price": 1850, "rarity": 2, "perk": "+43 energy and 21% lower charge cost", "stats": {"energy": 43, "charge": 0.79}},
	"nova_core": {"name": "Nova Core", "slot": "core", "price": 3180, "rarity": 3, "perk": "+34% attack and +16 energy", "stats": {"attack": 1.34, "energy": 16}},
	"zero_cell": {"name": "Zero Cell", "slot": "core", "price": 3450, "rarity": 3, "perk": "+62 energy and 29% lower charge cost", "stats": {"energy": 62, "charge": 0.71}},
	"vector_vanes": {"name": "Vector Vanes", "slot": "utility", "price": 740, "rarity": 1, "perk": "6% faster run, 14% faster dash, 15% shorter dash cooldown", "stats": {"speed": 1.06, "dash": 1.14, "cooldown": 0.85}},
	"scavenger_array": {"name": "Scavenger Array", "slot": "utility", "price": 860, "rarity": 1, "perk": "70% more bolts from pickups", "stats": {"bolts": 1.7}},
	"strike_thrusters": {"name": "Strike Thrusters", "slot": "utility", "price": 1060, "rarity": 1, "perk": "+9% attack and 12% faster dash", "stats": {"attack": 1.09, "dash": 1.12}},
	"slipstream_drive": {"name": "Slipstream Drive", "slot": "utility", "price": 1690, "rarity": 2, "perk": "19% faster dash and 27% shorter cooldown", "stats": {"dash": 1.19, "cooldown": 0.73}},
	"treasure_beacon": {"name": "Treasure Beacon", "slot": "utility", "price": 1860, "rarity": 2, "perk": "90% more bolts from pickups and +12 HP", "stats": {"bolts": 1.9, "hp": 12}},
	"rift_skates": {"name": "Rift Skates", "slot": "utility", "price": 3090, "rarity": 3, "perk": "25% faster dash and 32% shorter cooldown", "stats": {"dash": 1.25, "cooldown": 0.68}},
	"golden_relay": {"name": "Golden Relay", "slot": "utility", "price": 3320, "rarity": 3, "perk": "Double bolts from pickups and +12% attack", "stats": {"bolts": 2, "attack": 1.12}},
	"survey_optics": {"name": "Survey Optics", "slot": "visor", "price": 430, "rarity": 0, "perk": "+12% XP from pickups", "stats": {"xp": 1.12}},
	"hazard_scan": {"name": "Hazard Scanner", "slot": "visor", "price": 860, "rarity": 1, "perk": "+16% XP from pickups and 5% damage resistance", "stats": {"xp": 1.16, "resist": 0.05}},
	"deep_scan": {"name": "Deep Scan Visor", "slot": "visor", "price": 1700, "rarity": 2, "perk": "+30% XP from pickups", "stats": {"xp": 1.3}},
	"oracle_optics": {"name": "Oracle Optics", "slot": "visor", "price": 3290, "rarity": 3, "perk": "+38% XP from pickups and +10 energy", "stats": {"xp": 1.38, "energy": 10}},
	"repair_servos": {"name": "Repair Servos", "slot": "arm", "price": 470, "rarity": 0, "perk": "Health pickups restore 20% more", "stats": {"healing": 1.2}},
	"rifle_stabilizer": {"name": "Buster Stabilizer", "slot": "arm", "price": 920, "rarity": 1, "perk": "+12% Buster and saber damage", "stats": {"attack": 1.12}},
	"recovery_arm": {"name": "Recovery Arm", "slot": "arm", "price": 1790, "rarity": 2, "perk": "Health pickups restore 45% more and +10 HP", "stats": {"healing": 1.45, "hp": 10}},
	"titan_servo": {"name": "Titan Servo", "slot": "arm", "price": 3500, "rarity": 3, "perk": "+18% attack and health pickups restore 30% more", "stats": {"attack": 1.18, "healing": 1.3}},
}

static var GEAR := Blueprints.all_gear(LEGACY_GEAR)
var blueprints: Dictionary = {}

var path := "user://riftcore_profile.cfg"
const Materials := preload("res://scripts/fabrication_catalog.gd")
const PLAYER_LEVEL_CAP := 50
const Story := preload("res://scripts/rift_story.gd")
var memories: Array[int] = []
var endings: Array[String] = []
var materials: Dictionary = {}
var core_shards := 0
const COSMETICS := {"Standard": Color("55e7ff"), "Magenta": Color("ff67ce"), "Gold": Color("ffd069")}
var operator_name := "RX-07"
var player_xp := 0
var cosmetic := "Standard"
var credits := 0
var owned: Dictionary = {}
var unlocked_sector := 1
var completed_challenges: Dictionary = {}
var reserve_lives := 0
var gear := {}
var manual_only := false
var loadouts: Dictionary = {}

static func clean_operator_name(value: String) -> String:
	var cleaned := ""
	for character in value.strip_edges():
		var code := character.unicode_at(0)
		if code >= 32 and code != 127 and not (code >= 0x202a and code <= 0x202e) and not (code >= 0x2066 and code <= 0x2069):
			cleaned += character
	cleaned = cleaned.strip_edges().left(20)
	return "RX-07" if cleaned.is_empty() else cleaned

func restore() -> void:
	var data := ConfigFile.new()
	if data.load(path) != OK:
		return
	decode_from(data)

func player_level() -> int:
	return mini(PLAYER_LEVEL_CAP, RiftPlayer.level_for_experience(player_xp))

func award_player_xp(amount: int) -> void:
	player_xp = mini(RiftPlayer.experience_threshold(PLAYER_LEVEL_CAP), player_xp + maxi(amount, 0))

func cosmetic_level(id: String) -> int:
	return {"Standard": 1, "Magenta": 8, "Gold": 25}.get(id, PLAYER_LEVEL_CAP + 1)

func storage_capacity() -> int:
	return 12 + floori(player_level() / 5.0) + rank("storage") * 7

func decode_from(data: ConfigFile) -> void:
	operator_name = clean_operator_name(str(data.get_value("profile", "operator_name", "RX-07")))
	materials.clear()
	blueprints.clear()
	if data.has_section("blueprints"):
		for id in data.get_section_keys("blueprints"):
			if GEAR.has(id) and data.get_value("blueprints", id, false):
				blueprints[id] = true
	blueprint_items.clear()
	inventory.clear()
	quick_slots = [{}, {}, {}, {}]
	var saved_blueprints: Variant = data.get_value("inventory", "blueprints", {})
	if saved_blueprints is Dictionary:
		for id in saved_blueprints:
			if GEAR.has(id) and not blueprints.has(id):
				blueprint_items[id] = true
	var items: Variant = data.get_value("inventory", "stock", {})
	if items is Dictionary:
		for id in items:
			if stock.has(id) and not stock[id].has("material"):
				inventory[id] = clampi(int(items[id]), 0, STACK_MAX)
	var assigned: Variant = data.get_value("inventory", "quick", [])
	if assigned is Array:
		for index in mini(quick_slots.size(), assigned.size()):
			if assigned[index] is Dictionary:
				var id := String(assigned[index].get("id", ""))
				if stock.has(id) and not stock[id].has("material"):
					quick_slots[index] = {"id": id, "count": clampi(int(assigned[index].get("count", 0)), 0, QUICK_MAX)}
	memories.clear()
	for index in range(1, Story.MEMORIES.size() + 1):
		if data.get_value("archive", "fragment_%d" % index, false):
			memories.append(index)
	endings.clear()
	for ending in ["standard", "secret"]:
		if data.get_value("archive", ending, false):
			endings.append(ending)
	var saved_materials = data.get_value("profile", "materials", {})
	if saved_materials is Dictionary:
		for id in saved_materials:
			materials[id] = maxi(0, int(saved_materials[id]))
	var legacy_bolts := maxi(0, int(data.get_value("profile", "credits", 0)))
	core_shards = maxi(0, int(data.get_value("profile", "core_shards", legacy_bolts / 100)))
	# Legacy slots retain their original bolt balance and get a one-time scrap grant.
	if not data.has_section_key("profile", "materials"):
		materials["scrap"] = legacy_bolts / 50
	player_xp = 0
	award_player_xp(int(data.get_value("profile", "player_xp", 0)))
	var skin := String(data.get_value("profile", "cosmetic", "Standard"))
	cosmetic = skin if player_level() >= cosmetic_level(skin) else "Standard"
	credits = maxi(0, int(data.get_value("profile", "credits", 0)))
	unlocked_sector = clampi(int(data.get_value("profile", "unlocked_sector", 1)), 1, Catalog.SECTORS.size())
	reserve_lives = maxi(0, int(data.get_value("profile", "reserve_lives", 0)))
	completed_challenges.clear()
	for sector in range(1, Catalog.SECTORS.size() + 1):
		for tier in range(CHALLENGES.size()):
			var id := challenge_key(sector, tier)
			if bool(data.get_value("challenges", id, false)):
				completed_challenges[id] = true
	owned.clear()
	gear.clear()
	for id in GEAR:
		var state := String(data.get_value("equipment", id, ""))
		if state == "equipped" and not equipped_for(GEAR[id].slot).is_empty():
			state = "stored"
		if state in ["stored", "equipped", "carried"]:
			gear[id] = state
			blueprints[id] = true
	for upgrade in all_upgrades():
		var id: String = upgrade.id
		var saved_rank := clampi(int(data.get_value("upgrades", id, 0)), 0, 2)
		if saved_rank > 0:
			owned[id] = saved_rank

	loadouts.clear()
	for number in range(1, PRESET_COUNT + 1):
		var record = data.get_value("loadouts", str(number), false)
		if record is Dictionary:
			loadouts[number] = {}
			for slot in GEAR_SLOTS:
				var id := String(record.get(slot, ""))
				if GEAR.has(id) and GEAR[id].slot == slot:
					loadouts[number][slot] = id

func save() -> Error:
	if manual_only:
		return OK
	var data := ConfigFile.new()
	encode_into(data)
	return data.save(path)

func encode_into(data: ConfigFile) -> void:
	data.set_value("inventory", "stock", inventory)
	data.set_value("inventory", "quick", quick_slots)
	data.set_value("inventory", "blueprints", blueprint_items)
	for id in blueprints:
		data.set_value("blueprints", id, true)
	for index in memories:
		data.set_value("archive", "fragment_%d" % index, true)
	for ending in endings:
		data.set_value("archive", ending, true)
	data.set_value("profile", "credits", credits)
	data.set_value("profile", "player_xp", player_xp)
	data.set_value("profile", "operator_name", operator_name)
	data.set_value("profile", "cosmetic", cosmetic)
	data.set_value("profile", "materials", materials)
	data.set_value("profile", "core_shards", core_shards)
	data.set_value("profile", "unlocked_sector", unlocked_sector)
	data.set_value("profile", "reserve_lives", reserve_lives)
	for id in owned:
		data.set_value("upgrades", id, rank(id))
	for id in completed_challenges:
		data.set_value("challenges", id, true)
	for id in gear:
		data.set_value("equipment", id, gear[id])

	for number in loadouts:
		data.set_value("loadouts", str(number), loadouts[number])

func record_loadout(number: int) -> String:
	var previous := loadouts.duplicate()
	var preset := {}
	for slot in GEAR_SLOTS:
		var id := equipped_for(slot)
		if not id.is_empty():
			preset[slot] = id
	loadouts[number] = preset
	if save() != OK:
		loadouts = previous
		return "Could not record this preset."
	return "Preset %d updated. Use Save Game to keep it across launches." % number

func apply_loadout(number: int) -> String:
	if not loadouts.has(number):
		return "This preset is empty."
	var preset: Dictionary = loadouts[number]
	for id in preset.values():
		if not gear.has(id):
			return "%s is missing. Rebuy it or update this preset." % GEAR[id].name
	var previous := gear.duplicate()
	for id in gear:
		gear[id] = "equipped" if id in preset.values() else "stored"
	if save() != OK:
		gear = previous
		return "Could not equip this preset."
	return "Preset %d equipped." % number

func equipped_for(slot: String) -> String:
	for id in gear:
		if gear[id] == "equipped" and GEAR[id].slot == slot:
			return id
	return ""

static func recipe_level(id: String) -> int:
	var index := id.get_slice("_", 2).to_int() if GEAR[id].has("sector") else LEGACY_GEAR.keys().find(id)
	var rarity := int(GEAR[id].rarity)
	return [1, 5, 15, 30][rarity] + (index % 5 if rarity > 0 else 0)

func recipe_materials(id: String) -> Dictionary:
	var index := id.get_slice("_", 2).to_int() if GEAR[id].has("sector") else LEGACY_GEAR.keys().find(id)
	var rarity := int(GEAR[id].rarity)
	var bill := {"scrap": ceili((4 + rarity * 4) * (1.0 - rank("fabrication") * 0.2)),
		["components", "circuits", "cells"][index % 3]: 2 + rarity * 2}
	if rarity > 0:
		bill[Materials.sector_key(int(GEAR[id].get("sector", index % 10 + 1)))] = rarity
	if rarity >= 2:
		bill["core"] = rarity - 1
	if rarity == 3:
		bill["legendary"] = 1
	return bill

func stored_count() -> int:
	return gear.values().count("stored")

func craft_limit(id: String) -> String:
	if not blueprints.has(id):
		return "Blueprint undiscovered."
	if gear.has(id):
		return "Blueprint already fabricated."
	if player_level() < recipe_level(id):
		return "Requires Player Level %d." % recipe_level(id)
	if stored_count() >= storage_capacity():
		return "Storage is full."
	var bill := recipe_materials(id)
	for material in bill:
		if int(materials.get(material, 0)) < int(bill[material]):
			return "Missing fabrication materials."
	return ""

func craft(id: String) -> String:
	if not GEAR.has(id):
		return "Unknown blueprint."
	var restriction := craft_limit(id)
	if not restriction.is_empty():
		return restriction
	var previous := materials.duplicate()
	var bill := recipe_materials(id)
	for material in bill:
		materials[material] -= bill[material]
	gear[id] = "stored"
	if save() != OK:
		materials = previous
		gear.erase(id)
		return "Could not fabricate item."
	return "%s fabricated and sent to Storage." % GEAR[id].name

func deposit_materials(recovered: Dictionary) -> void:
	for id in recovered:
		materials[id] = int(materials.get(id, 0)) + int(recovered[id])

func move_gear(id: String) -> String:
	if not gear.has(id):
		return "This item is not owned."
	var previous := gear.duplicate()
	var item: Dictionary = GEAR[id]
	if gear[id] == "equipped":
		if stored_count() >= storage_capacity():
			return "Storage is full."
		gear[id] = "stored"
	else:
		var old := equipped_for(item.slot)
		if not old.is_empty():
			if gear[id] == "carried" and stored_count() >= storage_capacity():
				return "Storage is full. Make room for the replaced gear."
			gear[old] = "stored"
		gear[id] = "equipped"
	if save() != OK:
		gear = previous
		return "Could not save the equipment change."
	return "%s %s." % [item.name, gear[id]]

func lose_equipped_gear() -> void:
	var previous := gear.duplicate()
	for id in gear.keys():
		if gear[id] in ["equipped", "carried"]:
			gear.erase(id)
	if gear.size() != previous.size() and save() != OK:
		gear = previous
		push_warning("Could not save equipment loss.")

static func challenge_key(sector: int, tier: int) -> String:
	return "%d_%d" % [sector, tier + 1]

static func challenge_credits(sector: int, tier: int) -> int:
	return CHALLENGES[tier].credits + (sector - 1) * CHALLENGES[tier].step

func unlock_sector(sector: int) -> void:
	var next := clampi(sector, 1, Catalog.SECTORS.size())
	if next <= unlocked_sector:
		return
	var previous := unlocked_sector
	unlocked_sector = next
	if save() != OK:
		unlocked_sector = previous
		push_warning("Could not save the unlocked sector.")

func complete_challenges(sector: int, tiers: Array[int]) -> Dictionary:
	var earned: Array[String] = []
	var payment := 0
	for tier in tiers:
		var id := challenge_key(sector, tier)
		if completed_challenges.has(id):
			continue
		earned.append(id)
		completed_challenges[id] = true
		payment += challenge_credits(sector, tier)
	if earned.is_empty():
		return {}
	var previous_sector := unlocked_sector
	unlocked_sector = maxi(unlocked_sector, sector)
	credits += payment
	var shards := earned.size() * (3 + sector)
	core_shards += shards
	reserve_lives += earned.size()
	if save() != OK:
		credits -= payment
		core_shards -= shards
		reserve_lives -= earned.size()
		unlocked_sector = previous_sector
		for id in earned:
			completed_challenges.erase(id)
		push_warning("Could not save challenge rewards.")
		return {}
	return {"credits": payment, "shards": shards, "lives": earned.size()}

func use_reserve_life() -> bool:
	if reserve_lives <= 0:
		return false
	reserve_lives -= 1
	if save() == OK:
		return true
	reserve_lives += 1
	return false

func deposit(amount: int) -> Error:
	amount = maxi(0, amount)
	if amount == 0:
		return OK
	credits += amount
	var result := save()
	if result != OK:
		credits -= amount
	return result

func all_upgrades() -> Array:
	return UPGRADES + enhancements

func collect_blueprint(id: String) -> bool:
	if not GEAR.has(id) or blueprints.has(id) or blueprint_items.has(id):
		return false
	blueprint_items[id] = true
	return true

func learn_blueprint(id: String) -> String:
	if not blueprint_items.has(id):
		return "Blueprint unavailable."
	blueprint_items.erase(id)
	blueprints[id] = true
	if save() != OK:
		blueprints.erase(id)
		blueprint_items[id] = true
		return "Could not save the blueprint."
	return "Learned " + String(GEAR[id].name) + "."

func buy_supply(id: String) -> String:
	if not stock.has(id):
		return "Item unavailable."
	var item: Dictionary = stock[id]
	var qty: int = item.get("quantity", 1)
	var target := materials if item.has("material") else inventory
	var key: String = item.get("material", id)
	var before := int(target.get(key, 0))
	if before + qty > STACK_MAX:
		return "Stack full."
	if credits < item.price:
		return "Not enough bolts."
	credits -= item.price
	target[key] = before + qty
	if save() != OK:
		credits += item.price
		target[key] = before
		return "Could not save the purchase."
	return "Purchased " + String(item.name) + "."

func assign_quick(index: int, id: String) -> String:
	if index < 0 or index >= quick_slots.size() or not stock.has(id) or stock[id].has("material"):
		return "Invalid quick slot."
	var previous := quick_slots[index].duplicate()
	var old_id := String(previous.get("id", ""))
	var old_count := int(previous.get("count", 0))
	var before := int(inventory.get(id, 0))
	if not old_id.is_empty() and old_id != id and int(inventory.get(old_id, 0)) + old_count > STACK_MAX:
		return "Make room for the previous stack."
	var amount := mini(QUICK_MAX - (old_count if old_id == id else 0), before)
	if amount <= 0:
		return "Slot is full or the item is out of stock."
	var snapshot := inventory.duplicate()
	if not old_id.is_empty() and old_id != id:
		inventory[old_id] = int(inventory.get(old_id, 0)) + old_count
	inventory[id] = before - amount
	quick_slots[index] = {"id": id, "count": amount + (old_count if old_id == id else 0)}
	if save() != OK:
		inventory = snapshot
		quick_slots[index] = previous
		return "Could not save the quick slot."
	return "%s assigned." % stock[id].name

func clear_quick(index: int) -> String:
	var slot := quick_slots[index]
	var id := String(slot.get("id", ""))
	if id.is_empty():
		return "Slot is empty."
	var count := int(slot.get("count", 0))
	var previous := int(inventory.get(id, 0))
	if previous + count > STACK_MAX:
		return "Inventory stack is full."
	inventory[id] = previous + count
	quick_slots[index] = {}
	if save() != OK:
		quick_slots[index] = slot
		inventory[id] = previous
		return "Could not save the quick slot."
	return "Stack returned to inventory."

func consume_quick(index: int, operator: RiftPlayer) -> bool:
	if index < 0 or index >= quick_slots.size() or operator.health <= 0:
		return false
	var slot := quick_slots[index]
	var id := String(slot.get("id", ""))
	var count := int(slot.get("count", 0))
	if count < 1 or not stock.has(id):
		return false
	var item: Dictionary = stock[id]
	if not item.has("stat") and not (item.get("hp", 0) > 0 and operator.health < operator.max_health) and not (item.get("energy", 0) > 0 and operator.energy < operator.max_energy):
		return false
	slot.count = count - 1
	if save() != OK:
		slot.count = count
		return false
	operator.apply_supply(item)
	quick_changed.emit()
	return true

func rank(id: String) -> int:
	return clampi(int(owned.get(id, 0)), 0, 2)

func enhancement_level(id: String, current: int) -> int:
	for item in enhancements:
		if item.id == id:
			return item.level
	return (5 if id in ["storage", "fabrication"] else 1) + current * 8

func buy(id: String) -> String:
	for item in all_upgrades():
		if item.id != id:
			continue
		var current := rank(id)
		if current >= item.prices.size():
			return "Maximum rank installed."
		var price: int = item.prices[current]
		if player_level() < enhancement_level(id, current):
			return "Player level too low for this rank."
		if core_shards < price:
			return "Not enough Core Shards."
		core_shards -= price
		owned[id] = current + 1
		if save() != OK:
			core_shards += price
			if current == 0:
				owned.erase(id)
			else:
				owned[id] = current
			return "Could not save the purchase."
		return "%s %s installed." % [item.name, "I" if current == 0 else "II"]
	return "Unknown upgrade."
