extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")
const CHALLENGES := [
	{"name": "Gatebreaker", "objective": "Defeat the Act 1 miniboss and enter Act 2.", "credits": 120, "step": 15},
	{"name": "Sector Clear", "objective": "Defeat the Act 2 boss and reach extraction.", "credits": 240, "step": 25},
	{"name": "Clean Run", "objective": "Clear both acts in the same run without losing a life.", "credits": 420, "step": 35},
]

const UPGRADES := [
	{"id": "armor", "name": "Ceramic Armor", "prices": [1500, 2800], "effects": ["+12 starting HP", "+28 starting HP and 10% damage resistance"]},
	{"id": "capacitor", "name": "Flux Capacitor", "prices": [1950, 3400], "effects": ["+15 starting energy", "+32 starting energy and 20% cheaper charged shots"]},
	{"id": "buster", "name": "Buster Overdrive", "prices": [2550, 4100], "effects": ["+15% Buster and saber damage", "+32% Buster and saber damage"]},
	{"id": "dash", "name": "Vector Drive", "prices": [3100, 4700], "effects": ["+10% dash speed and 15% shorter cooldown", "+20% dash speed and 32% shorter cooldown"]},
]

const GEAR_SLOTS := {"frame": "Frame", "core": "Core", "utility": "Utility", "visor": "Visor", "arm": "Arm Module"}
const UPGRADE_SLOTS := {"armor": "frame", "capacitor": "core", "buster": "core", "dash": "utility"}
const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color("b5c9de"), Color("68c9ff"), Color("d0a0ff"), Color("ffca68")]
const PRESET_COUNT := 3
const GEAR := {
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
	"vector_vanes": {"name": "Vector Vanes", "slot": "utility", "price": 740, "rarity": 1, "perk": "14% faster dash and 15% shorter cooldown", "stats": {"dash": 1.14, "cooldown": 0.85}},
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

var path := "user://riftcore_profile.cfg"
var credits := 0
var owned: Dictionary = {}
var unlocked_sector := 1
var completed_challenges: Dictionary = {}
var reserve_lives := 0
var gear := {}
var manual_only := false
var loadouts: Dictionary = {}

func restore() -> void:
	var data := ConfigFile.new()
	if data.load(path) != OK:
		return
	decode_from(data)

func decode_from(data: ConfigFile) -> void:
	credits = maxi(0, int(data.get_value("profile", "credits", 0)))
	unlocked_sector = clampi(int(data.get_value("profile", "unlocked_sector", 1)), 1, Catalog.SECTORS.size())
	reserve_lives = maxi(0, int(data.get_value("profile", "reserve_lives", 0)))
	completed_challenges.clear()
	for sector in range(1, unlocked_sector + 1):
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
		if state in ["stored", "equipped"]:
			gear[id] = state
	for upgrade in UPGRADES:
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
	data.set_value("profile", "credits", credits)
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

func buy_gear(id: String) -> String:
	if not GEAR.has(id) or gear.has(id):
		return "You already own this item."
	var item: Dictionary = GEAR[id]
	if credits < int(item.price):
		return "Not enough banked bolts."
	credits -= int(item.price)
	gear[id] = "stored"
	if save() != OK:
		credits += int(item.price)
		gear.erase(id)
		return "Could not save the purchase."
	return "%s moved to Storage." % item.name

func move_gear(id: String) -> String:
	if not gear.has(id):
		return "This item is not owned."
	var previous := gear.duplicate()
	var item: Dictionary = GEAR[id]
	if gear[id] == "equipped":
		gear[id] = "stored"
	else:
		var old := equipped_for(item.slot)
		if not old.is_empty():
			gear[old] = "stored"
		gear[id] = "equipped"
	if save() != OK:
		gear = previous
		return "Could not save the equipment change."
	return "%s %s." % [item.name, gear[id]]

func lose_equipped_gear() -> void:
	var previous := gear.duplicate()
	for id in gear.keys():
		if gear[id] == "equipped":
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
	reserve_lives += earned.size()
	if save() != OK:
		credits -= payment
		reserve_lives -= earned.size()
		unlocked_sector = previous_sector
		for id in earned:
			completed_challenges.erase(id)
		push_warning("Could not save challenge rewards.")
		return {}
	return {"credits": payment, "lives": earned.size()}

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

func rank(id: String) -> int:
	return clampi(int(owned.get(id, 0)), 0, 2)

func buy(id: String) -> String:
	for item in UPGRADES:
		if item.id != id:
			continue
		var current := rank(id)
		if current >= item.prices.size():
			return "Maximum rank installed."
		var price: int = item.prices[current]
		if credits < price:
			return "Not enough banked bolts."
		credits -= price
		owned[id] = current + 1
		if save() != OK:
			credits += price
			if current == 0:
				owned.erase(id)
			else:
				owned[id] = current
			return "Could not save the purchase."
		return "%s %s installed." % [item.name, "I" if current == 0 else "II"]
	return "Unknown upgrade."
