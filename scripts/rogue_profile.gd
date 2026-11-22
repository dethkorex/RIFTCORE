extends RefCounted

const OperatorFrames := preload("res://scripts/operator_frames.gd")

signal quick_changed

const Catalog := preload("res://scripts/sector_catalog.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const LEGACY_CHALLENGE_COUNT := 3
const SECONDS_PER_DAY := 86400
const CHALLENGE_VERSION := 3
const CHALLENGE_SETS := [
	[
		["Gatebreaker", "Reach Act II after defeating 6 security units.", "act", 1, 0, {"act_kills": 6}],
		["Clear the Route", "Extract after defeating 12 security units.", "kills", 12, 0],
		["Salvage Run", "Extract with at least 10 recovered materials.", "materials", 10, 0],
		["Security Sweep", "Extract on Hard or Expert after defeating 17 security units.", "kills", 17, 1],
		["No Casualties", "Extract on Hard or Expert with no lives lost and 18 security defeats.", "clean", 1, 1, {"kills": 18}],
	],
	[
		["First Breach", "Reach Act II after defeating 7 security units.", "act", 1, 0, {"act_kills": 7}],
		["Credit Runner", "Extract after collecting at least 140 Bolts.", "bolts", 140, 0],
		["Health Reserve", "Extract with at least 90% health.", "health", 90, 0],
		["Quick Response", "Extract on Hard or Expert within 13 minutes.", "time", 780, 1],
		["Perfect Extraction", "Extract on Hard or Expert with no lives lost and at least 95% health.", "clean", 1, 1, {"health": 95}],
	],
	[
		["Frontline", "Reach Act II after defeating 8 security units.", "act", 1, 0, {"act_kills": 8}],
		["Salvage Specialist", "Extract with at least 12 recovered materials.", "materials", 12, 0],
		["Power Reserve", "Extract with at least 85% energy.", "energy", 85, 0],
		["Sweep Team", "Extract on Hard or Expert after defeating 18 security units.", "kills", 18, 1],
		["Heavy Haul", "Extract on Hard or Expert with no lives lost, 10 materials and 12 security defeats.", "clean", 1, 1, {"materials": 10, "kills": 12}],
	],
	[
		["Breach and Advance", "Reach Act II after defeating 6 security units.", "act", 1, 0, {"act_kills": 6}],
		["On the Clock", "Extract within 10 minutes.", "time", 600, 0],
		["Intact Chassis", "Extract with at least 85% health and 80% energy.", "health", 85, 0, {"energy": 80}],
		["Sweep and Recover", "Extract on Hard or Expert with 14 security defeats and 8 recovered materials.", "kills", 14, 1, {"materials": 8}],
		["Under Pressure", "Extract on Hard or Expert within 10 minutes with no lives lost.", "time", 600, 1, {"clean": 1}],
	],
	[
		["Make an Opening", "Reach Act II after defeating 7 security units.", "act", 1, 0, {"act_kills": 7}],
		["Bolts on Board", "Extract after collecting at least 160 Bolts.", "bolts", 160, 0],
		["Clean Run", "Extract with no lives lost and 14 security defeats.", "clean", 1, 0, {"kills": 14}],
		["Full Power", "Extract on Hard or Expert with at least 90% energy.", "energy", 90, 1],
		["Lasting Charge", "Extract on Hard or Expert with no lives lost, 85% energy and 15 security defeats.", "clean", 1, 1, {"energy": 85, "kills": 15}],
	],
]

const UPGRADES := [
	{"id": "armor", "branch": "Survivability", "tier": 0, "name": "Ceramic Armor", "icon": "aegis",
		"prices": [15, 28, 54], "levels": [1, 9, 16], "values": [12, 35, 58], "effects": ["+12% maximum HP", "+35% maximum HP and 10% damage resistance", "+58% maximum HP and 14% damage resistance"]},
	{"id": "field_reboot", "branch": "Survivability", "tier": 1, "name": "Field Reboot", "icon": "quick_heal",
		"prices": [85, 145, 220], "levels": [8, 14, 22],
		"effects": ["Revive allies 20% faster: hold Field Interact for 3.2 seconds.", "Revive allies 35% faster: hold Field Interact for 2.6 seconds.", "Revive allies 50% faster: hold Field Interact for 2 seconds."]},
	{"id": "last_stand", "branch": "Survivability", "tier": 1, "name": "Last Stand", "icon": "impact_liner",
		"prices": [65, 110, 175], "levels": [5, 12, 20], "values": [15, 25, 35], "effect": "Take %d%% less damage when below 30%% HP."},
	{"id": "shock_dampers", "branch": "Survivability", "tier": 2, "name": "Shock Dampers", "icon": "armor_plate",
		"prices": [85, 135, 200], "levels": [10, 17, 25], "values": [25, 40, 60], "effect": "Direct hits knock you back %d%% less."},
	{"id": "phase_lining", "branch": "Survivability", "tier": 2, "name": "Phase Lining", "icon": "visor",
		"prices": [88, 140, 215], "levels": [10, 17, 25], "values": [0.20, 0.35, 0.50], "effect": "Gain %.2f extra seconds of invulnerability after taking a hit."},
	{"id": "capacitor", "branch": "Survivability", "tier": 2, "name": "Flux Capacitor", "icon": "charge_relay",
		"prices": [85, 135, 205], "levels": [10, 17, 25], "values": [20, 43, 67], "effects": ["+20% maximum energy", "+43% maximum energy and 20% cheaper boss-weapon charge shots", "+67% maximum energy and 30% cheaper boss-weapon charge shots"]},
	{"id": "recovery_circuit", "branch": "Survivability", "tier": 3, "name": "Recovery Circuit", "icon": "quick_hybrid",
		"prices": [120, 200, 300], "levels": [15, 23, 32], "values": [20, 40, 65], "effect": "Health and energy items restore %d%% more."},
	{"id": "impact_converter", "branch": "Survivability", "tier": 3, "name": "Impact Converter", "icon": "quick_energy",
		"prices": [130, 215, 325], "levels": [15, 23, 32], "values": [6, 9, 13], "effect": "Restore %d%% of maximum energy when you survive a damaging hit."},
	{"id": "ghost_drive", "branch": "Survivability", "tier": 3, "name": "Ghost Drive", "icon": "air_jets",
		"prices": [125, 205, 310], "levels": [15, 23, 32], "values": [0.08, 0.12, 0.16], "effect": "Avoid damage for the first %.2f seconds of a dash."},
	{"id": "phoenix_protocol", "branch": "Survivability", "tier": 4, "name": "Phoenix Protocol", "icon": "quick_defense",
		"prices": [230, 390, 650], "levels": [28, 40, 50], "values": [35, 65, 100], "effect": "Survive one lethal damage hit per act and recover to at least %d%% health."},
	{"id": "buster", "branch": "Damage", "tier": 0, "name": "Buster Overdrive", "icon": "overdrive_arm",
		"prices": [25, 41, 70], "levels": [1, 9, 16], "values": [15, 32, 48], "effect": "+%d%% Buster and saber damage."},
	{"id": "saber_reach", "branch": "Damage", "tier": 1, "name": "Saber Reach", "icon": "quick_attack",
		"prices": [60, 105, 170], "levels": [5, 12, 20], "values": [15, 25, 40], "effect": "+%d%% reach on close-range saber strikes."},
	{"id": "accelerator", "branch": "Damage", "tier": 1, "name": "Rail Accelerator", "icon": "quick_speed",
		"prices": [63, 108, 170], "levels": [5, 12, 20], "values": [15, 30, 50], "effect": "Standard Buster shots travel %d%% faster."},
	{"id": "snap_charge", "branch": "Damage", "tier": 2, "name": "Snap Charge", "icon": "pulse_lens",
		"prices": [92, 150, 220], "levels": [10, 17, 25], "values": [12, 24, 35], "effect": "Buster and saber need %d%% less time to fully charge."},
	{"id": "magma_catalyst", "branch": "Damage", "tier": 2, "name": "Magma Catalyst", "icon": "talent_flame",
		"prices": [88, 145, 215], "levels": [10, 17, 25], "values": [20, 40, 65], "effect": "Magma attacks deal %d%% more burn damage."},
	{"id": "trigger_relay", "branch": "Damage", "tier": 2, "name": "Trigger Relay", "icon": "charge_regulator",
		"prices": [82, 135, 205], "levels": [10, 17, 25], "values": [10, 20, 32], "effect": "Reduce the time between shots by %d%%."},
	{"id": "overpressure", "branch": "Damage", "tier": 3, "name": "Overpressure", "icon": "charge_relay",
		"prices": [120, 200, 300], "levels": [15, 23, 32], "values": [10, 20, 35], "effect": "+%d%% charged Buster and saber damage."},
	{"id": "ripple_edge", "branch": "Damage", "tier": 3, "name": "Ripple Edge", "icon": "talent_pierce",
		"prices": [125, 195, 290], "levels": [15, 23, 32], "values": [1, 2, 3], "effect": "A charged saber wave can strike %d additional targets."},
	{"id": "dash", "branch": "Damage", "tier": 3, "name": "Vector Drive", "icon": "utility",
		"prices": [105, 170, 255], "levels": [15, 23, 32], "effects": ["+10% dash speed and 15% shorter cooldown", "+20% dash speed and 32% shorter cooldown", "+28% dash speed and 44% shorter cooldown"]},
	{"id": "echo_arsenal", "branch": "Damage", "tier": 4, "name": "Echo Arsenal", "icon": "talent_echo",
		"prices": [250, 420, 690], "levels": [28, 40, 50], "values": [45, 70, 100], "effect": "Charged Buster and saber attacks fire a second volley at %d%% power. The echo costs no energy."},
	{"id": "salvage_appraisal", "branch": "Scavenger", "tier": 0, "name": "Salvage Appraisal", "icon": "salvage_chip",
		"prices": [24, 47, 80], "levels": [1, 9, 16], "values": [18, 33, 55], "effect": "Find %d%% more bolts in currency pickups."},
	{"id": "storage", "branch": "Scavenger", "tier": 1, "name": "Storage Expansion", "icon": "recovery_bearing",
		"prices": [20, 36, 68], "levels": [5, 13, 21], "effects": ["+7 gear storage positions", "+14 gear storage positions", "+21 gear storage positions"]},
	{"id": "fabrication", "branch": "Scavenger", "tier": 1, "name": "Fabrication Efficiency", "icon": "repair_actuator",
		"prices": [20, 36, 68], "levels": [5, 13, 21], "effects": ["20% scrap discount when crafting", "40% scrap discount when crafting", "60% scrap discount when crafting"]},
	{"id": "vendor_license", "branch": "Scavenger", "tier": 2, "name": "Vendor License", "icon": "salvage_optic",
		"prices": [82, 136, 210], "levels": [10, 17, 25], "values": [10, 20, 30], "effect": "Save %d%% on supplies and materials at the Station Shop."},
	{"id": "recipe_decoder", "branch": "Scavenger", "tier": 2, "name": "Recipe Decoder", "icon": "core",
		"prices": [88, 145, 220], "levels": [10, 17, 25], "values": [2, 4, 6], "effect": "Craft learned blueprints up to %d Player Levels early."},
	{"id": "combat_telemetry", "branch": "Scavenger", "tier": 2, "name": "Combat Telemetry", "icon": "recon_optic",
		"prices": [75, 120, 180], "levels": [10, 17, 25], "values": [10, 20, 32], "effect": "+%d%% Operator XP from defeating enemies and bosses."},
	{"id": "recovery_crew", "branch": "Scavenger", "tier": 3, "name": "Recovery Crew", "icon": "arm",
		"prices": [100, 180, 270], "levels": [15, 23, 32], "values": [2, 4, 7], "effect": "Extract with %d extra sector materials."},
	{"id": "shard_reclaimer", "branch": "Scavenger", "tier": 3, "name": "Shard Reclaimer", "icon": "talent_shard",
		"prices": [130, 205, 320], "levels": [15, 23, 32], "values": [1, 2, 3], "effect": "Bank %d bonus Core Shards on successful extraction."},
	{"id": "resupply_contract", "branch": "Scavenger", "tier": 3, "name": "Resupply Contract", "icon": "talent_case",
		"prices": [110, 180, 270], "levels": [15, 23, 32], "values": [1, 2, 3], "effect": "Send %d bonus Resupply Packs to Storage on extraction."},
	{"id": "archive_mastery", "branch": "Scavenger", "tier": 4, "name": "Archive Mastery", "icon": "talent_decoder",
		"prices": [220, 365, 620], "levels": [28, 40, 50], "values": [1, 2, 3], "effect": "Extract with up to %d extra undiscovered blueprints eligible for the sector and difficulty."},
]
const TALENT_BRANCHES := ["Survivability", "Damage", "Scavenger"]
const TALENT_TIER_COUNT := 5
const FORMER_ROOTS := ["capacitor", "dash", "trigger_relay", "combat_telemetry"]
const LEGACY_TALENT_LEVELS := [1, 5, 10, 15]
const TALENT_RANKS := ["I", "II", "III"]
const TALENT_PRICE_PERCENT := 85
const CHALLENGE_SET_SHARD_MULTIPLIER := 1.5
const FIELD_REBOOT := "field_reboot"
const HUNT_CLEARS := 3

const Enhancements := preload("res://scripts/enhancement_catalog.gd")
const Stock := preload("res://scripts/stock_catalog.gd")
static var stock := Stock.catalog()
static var enhancements := Enhancements.catalog()
const QUICK_MAX := 3
const STACK_MAX := 100
const BLUEPRINT_POUCH_SIZE := 8
var reconstruction_seen := false
var briefed_acts := PackedInt32Array()
var shop_announced_through := 1
var pinned_blueprint := ""
var blueprint_hunts: Dictionary = {}
var blueprint_items := {}
var blueprint_pouch: Array[String] = []
var inventory := {}
var carried_materials := {}
var stored_supplies := {}
var quick_slots: Array[Dictionary] = [{}, {}, {}, {}]

const GEAR_SLOTS := {"frame": "Frame", "core": "Core", "utility": "Utility", "visor": "Visor", "arm": "Arm Module"}
const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color("b5c9de"), Color("68c9ff"), Color("d0a0ff"), Color("ffca68")]
const Blueprints := preload("res://scripts/blueprint_catalog.gd")
const LEGACY_GEAR := {
	"impact_liner": {"name": "Impact Liner", "slot": "frame", "price": 320, "rarity": 0, "perk": "12% damage resistance", "stats": {"resist": 0.12}},
	"vital_weave": {"name": "Vital Weave", "slot": "frame", "price": 360, "rarity": 0, "perk": "+18 maximum HP", "stats": {"hp": 18}},
	"pulse_lens": {"name": "Pulse Lens", "slot": "core", "price": 420, "rarity": 0, "perk": "+14% Buster and saber damage", "stats": {"attack": 1.14}},
	"charge_relay": {"name": "Charge Relay", "slot": "core", "price": 440, "rarity": 0, "perk": "+20 energy and 10% lower boss-weapon charge cost", "stats": {"energy": 20, "charge": 0.9}},
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
	"flux_prism": {"name": "Flux Prism", "slot": "core", "price": 920, "rarity": 1, "perk": "+18% attack and 6% lower boss-weapon charge cost", "stats": {"attack": 1.18, "charge": 0.94}},
	"arc_regulator": {"name": "Arc Regulator", "slot": "core", "price": 1150, "rarity": 1, "perk": "+15 energy and 18% lower boss-weapon charge cost", "stats": {"energy": 15, "charge": 0.82}},
	"twin_reactor": {"name": "Twin Reactor", "slot": "core", "price": 1640, "rarity": 2, "perk": "+20% attack and +32 energy", "stats": {"attack": 1.2, "energy": 32}},
	"phase_condenser": {"name": "Phase Condenser", "slot": "core", "price": 1850, "rarity": 2, "perk": "+43 energy and 21% lower boss-weapon charge cost", "stats": {"energy": 43, "charge": 0.79}},
	"nova_core": {"name": "Nova Core", "slot": "core", "price": 3180, "rarity": 3, "perk": "+34% attack and +16 energy", "stats": {"attack": 1.34, "energy": 16}},
	"zero_cell": {"name": "Zero Cell", "slot": "core", "price": 3450, "rarity": 3, "perk": "+62 energy and 29% lower boss-weapon charge cost", "stats": {"energy": 62, "charge": 0.71}},
	"vector_vanes": {"name": "Vector Vanes", "slot": "utility", "price": 740, "rarity": 1, "perk": "6% faster run, 14% faster dash, 15% shorter dash cooldown", "stats": {"speed": 1.06, "dash": 1.14, "cooldown": 0.85}},
	"scavenger_array": {"name": "Scavenger Array", "slot": "utility", "price": 860, "rarity": 1, "perk": "70% more bolts from pickups", "stats": {"bolts": 1.7}},
	"strike_thrusters": {"name": "Strike Thrusters", "slot": "utility", "price": 1060, "rarity": 1, "perk": "+9% attack and 12% faster dash", "stats": {"attack": 1.09, "dash": 1.12}},
	"slipstream_drive": {"name": "Slipstream Drive", "slot": "utility", "price": 1690, "rarity": 2, "perk": "19% faster dash and 27% shorter cooldown", "stats": {"dash": 1.19, "cooldown": 0.73}},
	"treasure_beacon": {"name": "Treasure Beacon", "slot": "utility", "price": 1860, "rarity": 2, "perk": "90% more bolts from pickups and +12 HP", "stats": {"bolts": 1.9, "hp": 12}},
	"rift_skates": {"name": "Rift Skates", "slot": "utility", "price": 3090, "rarity": 3, "perk": "25% faster dash and 32% shorter cooldown", "stats": {"dash": 1.25, "cooldown": 0.68}},
	"golden_relay": {"name": "Golden Relay", "slot": "utility", "price": 3320, "rarity": 3, "perk": "Double bolts from pickups and +12% attack", "stats": {"bolts": 2, "attack": 1.12}},
	"survey_optics": {"name": "Survey Optics", "slot": "visor", "price": 430, "rarity": 0, "perk": "+12% XP from kills", "stats": {"xp": 1.12}},
	"hazard_scan": {"name": "Hazard Scanner", "slot": "visor", "price": 860, "rarity": 1, "perk": "+16% XP from kills and 5% damage resistance", "stats": {"xp": 1.16, "resist": 0.05}},
	"deep_scan": {"name": "Deep Scan Visor", "slot": "visor", "price": 1700, "rarity": 2, "perk": "+30% XP from kills", "stats": {"xp": 1.3}},
	"oracle_optics": {"name": "Oracle Optics", "slot": "visor", "price": 3290, "rarity": 3, "perk": "+38% XP from kills and +10 energy", "stats": {"xp": 1.38, "energy": 10}},
	"repair_servos": {"name": "Repair Servos", "slot": "arm", "price": 470, "rarity": 0, "perk": "Health pickups restore 20% more", "stats": {"healing": 1.2}},
	"rifle_stabilizer": {"name": "Buster Stabilizer", "slot": "arm", "price": 920, "rarity": 1, "perk": "+12% Buster and saber damage", "stats": {"attack": 1.12}},
	"recovery_arm": {"name": "Recovery Arm", "slot": "arm", "price": 1790, "rarity": 2, "perk": "Health pickups restore 45% more and +10 HP", "stats": {"healing": 1.45, "hp": 10}},
	"titan_servo": {"name": "Titan Servo", "slot": "arm", "price": 3500, "rarity": 3, "perk": "+18% attack and health pickups restore 30% more", "stats": {"attack": 1.18, "healing": 1.3}},
}

static var GEAR := Blueprints.all_gear(LEGACY_GEAR)
var blueprints: Dictionary = {}

var path := "user://riftcore_profile.cfg"
const Materials := preload("res://scripts/fabrication_catalog.gd")
const PLAYER_LEVEL_CAP := Difficulty.PLAYER_LEVEL_CAP
const Story := preload("res://scripts/rift_story.gd")
var memories: Array[int] = []
var endings: Array[String] = []
var materials: Dictionary = {}
var core_shards := 0:
	set(value):
		core_shards = maxi(0, value)
var operator_name := "RX-07"
var survival_seconds := 0.0
var player_xp := 0
var cosmetic := "Standard"
var credits := 0
var owned_frames: Array = []
var owned: Dictionary = {}
var unlocked_sector := 1
var completed_challenges: Dictionary = {}
var challenge_cycles: Dictionary = {}
var loot_clears: Dictionary = {}
var normal_clears: Dictionary = {}
var hard_clears: Dictionary = {}
var reserve_lives := 0
var first_main_bosses: Array = []
var gear := {}
var manual_only := false
var operator_level := 1

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

func claim_briefing(sector: int, act: int) -> bool:
	var key := (sector - 1) * 2 + act
	if briefed_acts.has(key):
		return false
	briefed_acts.append(key)
	return true

func player_level() -> int:
	return mini(PLAYER_LEVEL_CAP, RiftPlayer.level_for_experience(player_xp))

func shop_milestone() -> int:
	var milestone := 1
	for item in stock.values():
		var required: int = item.shop_level
		if required <= operator_level:
			milestone = maxi(milestone, required)
	return milestone

func award_player_xp(amount: int) -> void:
	player_xp = mini(RiftPlayer.experience_threshold(PLAYER_LEVEL_CAP), player_xp + maxi(amount, 0))

func cosmetic_level(id: String) -> int:
	return {"Standard": 1, "Magenta": 8, "Gold": 25}.get(id, PLAYER_LEVEL_CAP + 1)

func storage_capacity() -> int:
	return 12 + floori(operator_level / 5.0) + rank("storage") * 7

func decode_from(data: ConfigFile) -> void:
	reconstruction_seen = bool(data.get_value("story", "reconstruction_seen", false))
	var saved_briefings: Variant = data.get_value("story", "briefed_acts", PackedInt32Array())
	briefed_acts = saved_briefings if saved_briefings is PackedInt32Array else PackedInt32Array()
	operator_name = clean_operator_name(str(data.get_value("profile", "operator_name", "RX-07")))
	survival_seconds = maxf(0.0, float(data.get_value("profile", "survival_seconds", 0.0)))
	materials.clear()
	blueprints.clear()
	blueprint_hunts.clear()
	var hunts: Variant = data.get_value("archive", "blueprint_hunts", {})
	if hunts is Dictionary:
		for id in hunts:
			if GEAR.has(id):
				blueprint_hunts[id] = clampi(int(hunts[id]), 0, HUNT_CLEARS - 1)
	var pin := String(data.get_value("archive", "pinned_blueprint", ""))
	pinned_blueprint = pin if GEAR.has(pin) else ""
	if data.has_section("blueprints"):
		for id in data.get_section_keys("blueprints"):
			if GEAR.has(id) and data.get_value("blueprints", id, false):
				blueprints[id] = true
	blueprint_items.clear()
	inventory.clear()
	carried_materials.clear()
	stored_supplies.clear()
	quick_slots = [{}, {}, {}, {}]
	var saved_blueprints: Variant = data.get_value("inventory", "blueprints", {})
	if saved_blueprints is Dictionary:
		for id in saved_blueprints:
			if GEAR.has(id):
				blueprint_items[id] = true
	blueprint_pouch.clear()
	var pouch: Variant = data.get_value("inventory", "blueprint_pouch", [])
	if pouch is Array:
		for id in pouch:
			if id is String and GEAR.has(id):
				blueprint_items[id] = true
	var items: Variant = data.get_value("inventory", "stock", {})
	var separated := data.has_section_key("inventory", "stored_supplies")
	if items is Dictionary:
		for id in items:
			if stock.has(id) and not stock[id].has("material"):
				var destination := inventory if separated else stored_supplies
				destination[id] = clampi(int(items[id]), 0, STACK_MAX)
	var stored: Variant = data.get_value("inventory", "stored_supplies", {})
	if stored is Dictionary:
		for id in stored:
			if stock.has(id) and not stock[id].has("material"):
				stored_supplies[id] = maxi(0, int(stored[id]))
	var carried: Variant = data.get_value("inventory", "carried_materials", {})
	if carried is Dictionary:
		for item in stock.values():
			if item.has("material") and carried.has(item.material):
				carried_materials[item.material] = clampi(int(carried[item.material]), 0, STACK_MAX)
	var assigned: Variant = data.get_value("inventory", "quick", [])
	if assigned is Array:
		for index in mini(quick_slots.size(), assigned.size()):
			if assigned[index] is Dictionary:
				var id := String(assigned[index].get("id", ""))
				var count := clampi(int(assigned[index].get("count", 0)), 0, 5)
				var field := clampi(int(assigned[index].get("field", 0)), 0, mini(count, QUICK_MAX))
				if not data.has_section_key("checkpoint", "recovered_supplies"):
					count -= field
					field = 0
				if count > 0 and stock.has(id) and not stock[id].has("material"):
					quick_slots[index] = {"id": id, "count": mini(count, QUICK_MAX)}
					if field > 0:
						quick_slots[index].field = field
					if count > QUICK_MAX:
						inventory[id] = mini(STACK_MAX, int(inventory.get(id, 0)) + count - QUICK_MAX)
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
	core_shards = ceili(float(data.get_value("profile", "core_shards", legacy_bolts / 100)))
	# Legacy slots retain their original bolt balance and get a one-time scrap grant.
	if not data.has_section_key("profile", "materials"):
		materials["scrap"] = legacy_bolts / 50
	player_xp = 0
	award_player_xp(int(data.get_value("profile", "player_xp", 0)))
	operator_level = RiftPlayer.level_for_experience(int(data.get_value("checkpoint", "experience", 0)))
	var shop_level := shop_milestone()
	shop_announced_through = clampi(int(data.get_value("story", "shop_announced_through", shop_level)), 1, shop_level)
	var skin := String(data.get_value("profile", "cosmetic", "Standard"))
	cosmetic = skin if operator_level >= cosmetic_level(skin) else "Standard"
	credits = maxi(0, int(data.get_value("profile", "credits", 0)))
	owned_frames = data.get_value("wardrobe", "owned_frames", []) if OperatorFrames.current_wardrobe(data) else []
	unlocked_sector = clampi(int(data.get_value("profile", "unlocked_sector", 1)), 1, Catalog.SECTORS.size())
	reserve_lives = maxi(0, int(data.get_value("profile", "reserve_lives", 0)))
	first_main_bosses = data.get_value("profile", "first_main_bosses", [])
	completed_challenges.clear()
	var cycles: Variant = data.get_value("challenge_cycles", "sectors", {})
	challenge_cycles = cycles if cycles is Dictionary else {}
	var clears: Variant = data.get_value("archive", "loot_clears", {})
	loot_clears = clears if clears is Dictionary else {}
	var hard: Variant = data.get_value("archive", "hard_clears", {})
	hard_clears = hard if hard is Dictionary else {}
	var normal: Variant = data.get_value("archive", "normal_clears", false)
	normal_clears = normal if normal is Dictionary else {}
	if not normal is Dictionary:
		# Older profiles only saved their highest clear. Keep their earned access.
		for number in range(1, Catalog.SECTORS.size() + 1):
			if loot_clears.has(number) or hard_clears.get(number, false):
				normal_clears[number] = true
	for number in range(1, Catalog.SECTORS.size()):
		if normal_clears.get(number, false) or hard_clears.get(number, false):
			unlocked_sector = maxi(unlocked_sector, number + 1)
	for number in memories:
		if not loot_clears.has(number):
			loot_clears[number] = 0
	for sector in range(1, Catalog.SECTORS.size() + 1):
		for tier in range(LEGACY_CHALLENGE_COUNT):
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
		var saved_rank := clampi(int(data.get_value("upgrades", id, 0)), 0, upgrade.prices.size())
		if saved_rank > 0:
			owned[id] = saved_rank

func save() -> Error:
	if manual_only:
		return OK
	var data := ConfigFile.new()
	encode_into(data)
	return data.save(path)

func encode_into(data: ConfigFile) -> void:
	data.set_value("story", "reconstruction_seen", reconstruction_seen)
	data.set_value("story", "briefed_acts", briefed_acts)
	data.set_value("story", "shop_announced_through", shop_announced_through)
	data.set_value("archive", "pinned_blueprint", pinned_blueprint)
	data.set_value("archive", "blueprint_hunts", blueprint_hunts)
	data.set_value("inventory", "stock", inventory)
	data.set_value("inventory", "carried_materials", carried_materials)
	data.set_value("inventory", "stored_supplies", stored_supplies)
	data.set_value("inventory", "quick", quick_slots)
	data.set_value("inventory", "blueprints", blueprint_items)
	data.set_value("inventory", "blueprint_pouch", blueprint_pouch)
	for id in blueprints:
		data.set_value("blueprints", id, true)
	for index in memories:
		data.set_value("archive", "fragment_%d" % index, true)
	for ending in endings:
		data.set_value("archive", ending, true)
	data.set_value("profile", "credits", credits)
	data.set_value("wardrobe", "epoch", OperatorFrames.COSMETIC_EPOCH)
	data.set_value("wardrobe", "owned_frames", owned_frames)
	data.set_value("profile", "player_xp", player_xp)
	data.set_value("profile", "operator_name", operator_name)
	data.set_value("profile", "survival_seconds", survival_seconds)
	data.set_value("profile", "cosmetic", cosmetic)
	data.set_value("profile", "materials", materials)
	data.set_value("profile", "core_shards", core_shards)
	data.set_value("profile", "unlocked_sector", unlocked_sector)
	data.set_value("profile", "reserve_lives", reserve_lives)
	data.set_value("profile", "first_main_bosses", first_main_bosses)
	for id in owned:
		data.set_value("upgrades", id, rank(id))
	for id in completed_challenges:
		data.set_value("challenges", id, true)
	data.set_value("challenge_cycles", "sectors", challenge_cycles)
	data.set_value("archive", "loot_clears", loot_clears)
	data.set_value("archive", "normal_clears", normal_clears)
	data.set_value("archive", "hard_clears", hard_clears)
	for id in gear:
		data.set_value("equipment", id, gear[id])

func equipped_for(slot: String) -> String:
	for id in gear:
		if gear[id] == "equipped" and GEAR[id].slot == slot:
			return id
	return ""

static func recipe_level(id: String) -> int:
	if GEAR[id].has("level"):
		return int(GEAR[id].level)
	var index := id.get_slice("_", 2).to_int() if GEAR[id].has("sector") else LEGACY_GEAR.keys().find(id)
	var rarity := int(GEAR[id].rarity)
	return [1, 5, 15, 30][rarity] + (index % 5 if rarity > 0 else 0)

func crafting_level(id: String) -> int:
	return maxi(1, recipe_level(id) - int(talent_bonus("recipe_decoder")))

func recipe_materials(id: String) -> Dictionary:
	var item: Dictionary = GEAR[id]
	var rarity: int = item.rarity
	var sector := int(item.get("sector", 0))
	var stats: Dictionary = item.stats
	var preferred := "components"
	if stats.has("energy") or stats.has("charge") or stats.has("healing"):
		preferred = "cells"
	elif item.slot == "visor":
		preferred = "circuits"
	var parts := Materials.component_sources(sector)
	if sector == 0 and rarity >= 2:
		parts = ["components", "cells", "circuits"]
	var component: String = preferred if preferred in parts else parts[0]
	var scrap: float = [3, 6, 10, 14][rarity] * (1.0 - rank("fabrication") * 0.2)
	var bill := {"scrap": ceili(scrap), component: [1, 2, 4, 6][rarity]}
	if rarity > 0:
		if sector > 0:
			bill[Materials.sector_key(sector)] = rarity
		else:
			# Older blueprints have no home sector.
			var secondary := "circuits" if rarity >= 2 and component != "circuits" else ("cells" if component != "cells" else "components")
			bill[secondary] = rarity
	if rarity >= 2:
		bill["core"] = rarity - 1
	if rarity == 3:
		bill["legendary"] = 1
	return bill

func stored_count() -> int:
	return gear.values().count("stored")

func craft_limit(id: String, equip_now := false) -> String:
	if not GEAR.has(id):
		return "Unknown blueprint."
	if not blueprints.has(id):
		return "Blueprint undiscovered."
	if gear.has(id):
		return "Blueprint already fabricated."
	var level := recipe_level(id) if equip_now else crafting_level(id)
	if operator_level < level:
		return "Requires Operator Level %d." % level
	if stored_count() >= storage_capacity():
		if not equip_now:
			return "Storage is full."
		if not equipped_for(GEAR[id].slot).is_empty():
			return "Free a Storage slot for your current gear."
	var bill := recipe_materials(id)
	for material in bill:
		if int(materials.get(material, 0)) < int(bill[material]):
			return "Missing fabrication materials."
	return ""

func craft(id: String, equip_now := false) -> String:
	var restriction := craft_limit(id, equip_now)
	if not restriction.is_empty():
		return restriction
	var previous := materials.duplicate()
	var previous_gear := gear.duplicate()
	var bill := recipe_materials(id)
	for material in bill:
		materials[material] -= bill[material]
	var replaced := equipped_for(GEAR[id].slot) if equip_now else ""
	if not replaced.is_empty():
		gear[replaced] = "stored"
	gear[id] = "equipped" if equip_now else "stored"
	if save() != OK:
		materials = previous
		gear = previous_gear
		return "Could not fabricate item."
	if equip_now:
		return "%s equipped. %s sent to Storage." % [GEAR[id].name, GEAR[replaced].name] if not replaced.is_empty() else "%s equipped." % GEAR[id].name
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
		if operator_level < recipe_level(id):
			return "Requires Operator Level %d." % recipe_level(id)
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
	var previous_quick := quick_slots.duplicate()
	for id in gear.keys():
		if gear[id] == "equipped":
			gear.erase(id)
	quick_slots = [{}, {}, {}, {}]
	if save() != OK:
		gear = previous
		quick_slots = previous_quick
		push_warning("Could not save equipment loss.")
	quick_changed.emit()

static func challenge_key(sector: int, tier: int) -> String:
	return "%d_%d" % [sector, tier + 1]

func record_sector_clear(sector: int, mode: int) -> bool:
	loot_clears[sector] = maxi(int(loot_clears.get(sector, 0)), mode)
	if mode == Difficulty.NORMAL and not hard_unlocked(sector):
		normal_clears[sector] = true
		return true
	if mode == Difficulty.HARD:
		hard_clears[sector] = true
	return false

func hard_unlocked(sector: int) -> bool:
	return normal_clears.get(sector, false)

func available_difficulty(sector: int, requested: int) -> int:
	if requested == Difficulty.NIGHTMARE and nightmare_unlocked():
		return Difficulty.NIGHTMARE
	if requested >= Difficulty.HARD and hard_unlocked(sector):
		return Difficulty.HARD
	return Difficulty.NORMAL

func hard_clear_count() -> int:
	var count := 0
	for sector in range(1, Catalog.SECTORS.size() + 1):
		if hard_clears.get(sector, false):
			count += 1
	return count

func nightmare_unlocked() -> bool:
	return hard_clear_count() == Catalog.SECTORS.size()

func challenge_cycle(sector: int, clock := Time.get_datetime_dict_from_system()) -> Dictionary:
	var cycle: Dictionary = challenge_cycles.get(sector, {})
	var today := challenge_day(clock)
	if int(cycle.get("version", 0)) != CHALLENGE_VERSION:
		cycle = {"version": CHALLENGE_VERSION, "set": 0, "done": [], "claimed": [], "day": today}
		challenge_cycles[sector] = cycle
		return cycle
	if not cycle.has("claimed"):
		cycle["claimed"] = cycle.done.duplicate()
	if today > int(cycle.get("day", today)):
		var picker := RandomNumberGenerator.new()
		picker.seed = hash([today, sector, operator_name])
		var next := posmod(int(cycle.set) + picker.randi_range(1, CHALLENGE_SETS.size() - 1), CHALLENGE_SETS.size())
		cycle = {"version": CHALLENGE_VERSION, "set": next, "done": [], "claimed": [],
			"day": today, "carryover": challenge_rewards(sector, cycle)}
		challenge_cycles[sector] = cycle
	return cycle

static func challenge_day(clock := Time.get_datetime_dict_from_system()) -> int:
	return clock.year * 10000 + clock.month * 100 + clock.day

static func challenge_seconds_left(clock := Time.get_datetime_dict_from_system()) -> int:
	return SECONDS_PER_DAY - clock.hour * 3600 - clock.minute * 60 - clock.second

static func challenge_life(index: int) -> int:
	return int(index == 4)

static func challenge_shards(sector: int, tier: int) -> int:
	if tier < 3:
		return 3 + clampi(tier, 0, 2)
	var sector_bonus := (clampi(sector, 1, Catalog.SECTORS.size()) - 1) / 3
	return mini(15, 10 + sector_bonus + 2 * (tier - 3))

static func challenge_set_shards(sector: int) -> int:
	var base := 3 + (sector - 1) / 3
	return roundi(base * CHALLENGE_SET_SHARD_MULTIPLIER)

static func rotated_challenge_credits(sector: int, index: int) -> int:
	return 120 + index * 35 + (sector - 1) * 18

func challenge_rewards(sector: int, cycle: Dictionary) -> Dictionary:
	var carryover: Dictionary = cycle.get("carryover", {})
	var reward := {"credits": int(carryover.get("credits", 0)), "shards": ceili(float(carryover.get("shards", 0))),
		"lives": int(carryover.get("lives", 0))}
	for index in 5:
		if cycle.done.has(index) and not cycle.claimed.has(index):
			reward.credits += rotated_challenge_credits(sector, index)
			reward.shards += challenge_shards(sector, index)
			reward.lives += challenge_life(index) if int(cycle.get("version", 0)) == CHALLENGE_VERSION else 1
	if cycle.done.size() == 5 and cycle.claimed.size() < 5:
		reward.shards += challenge_set_shards(sector)
	return reward

func record_challenges(sector: int, results: Dictionary, persist := Callable()) -> int:
	var cycle := challenge_cycle(sector)
	var previous: Array = cycle.done.duplicate()
	for index in 5:
		if cycle.done.has(index):
			continue
		var task: Array = CHALLENGE_SETS[cycle.set][index]
		if results.get("mode", Difficulty.NORMAL) < task[4]:
			continue
		if task[2] != "act" and results.get("clear", 0) != 1:
			continue
		if not meets_challenge_target(results, task[2], task[3]):
			continue
		var conditions: Dictionary = task[5] if task.size() > 5 else {}
		if conditions.keys().all(func(metric): return meets_challenge_target(results, metric, conditions[metric])):
			cycle.done.append(index)
	var earned: int = cycle.done.size() - previous.size()
	if earned == 0:
		return 0
	var error: int = persist.call() if persist.is_valid() else save()
	if error != OK:
		cycle.done = previous
		push_warning("Could not save challenge progress: %s" % error_string(error))
		return 0
	return earned

static func meets_challenge_target(results: Dictionary, metric: String, threshold: float) -> bool:
	if not results.has(metric):
		return false
	var value := float(results[metric])
	return is_finite(value) and (value > 0.0 and value <= threshold if metric == "time" else value >= threshold)

func claim_challenge_rewards(sector: int, persist := Callable()) -> Error:
	if sector < 1 or sector > unlocked_sector:
		return ERR_INVALID_PARAMETER
	var cycle := challenge_cycle(sector)
	var reward := challenge_rewards(sector, cycle)
	if reward.credits == 0 and reward.shards == 0 and reward.lives == 0:
		return ERR_DOES_NOT_EXIST
	var previous := cycle.duplicate(true)
	cycle.claimed = cycle.done.duplicate()
	cycle.erase("carryover")
	credits += reward.credits
	core_shards += reward.shards
	reserve_lives += reward.lives
	var error: int = persist.call() if persist.is_valid() else save()
	if error != OK:
		challenge_cycles[sector] = previous
		credits -= reward.credits
		core_shards -= reward.shards
		reserve_lives -= reward.lives
	return error

func grant_first_boss_life(sector: int, persist := Callable()) -> bool:
	if sector < 1 or sector > Catalog.SECTORS.size() or sector in first_main_bosses 			or loot_clears.has(sector) or hard_clears.get(sector, false) or normal_clears.get(sector, false):
		return false
	first_main_bosses.append(sector)
	reserve_lives += 1
	var error: int = persist.call() if persist.is_valid() else save()
	if error != OK:
		first_main_bosses.erase(sector)
		reserve_lives -= 1
		push_warning("Could not save the first main boss reward: %s" % error_string(error))
		return false
	return true

func unlock_sector(sector: int) -> void:
	var next := clampi(sector, 1, Catalog.SECTORS.size())
	if next <= unlocked_sector:
		return
	var previous := unlocked_sector
	unlocked_sector = next
	if save() != OK:
		unlocked_sector = previous
		push_warning("Could not save the unlocked sector.")

func spend_reserve_lives(amount: int, persist := Callable()) -> bool:
	if amount < 1 or reserve_lives < amount:
		return false
	reserve_lives -= amount
	var error: int = persist.call() if persist.is_valid() else save()
	if error == OK:
		return true
	reserve_lives += amount
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

func can_collect_blueprint(id: String) -> bool:
	return GEAR.has(id) and not blueprints.has(id) and not blueprint_items.has(id) and not blueprint_pouch.has(id)

func move_blueprint_to_pouch(id: String) -> String:
	if not blueprint_items.has(id) or blueprint_pouch.size() >= BLUEPRINT_POUCH_SIZE:
		return "Blueprint pouch is full or the item is unavailable."
	blueprint_items.erase(id)
	blueprint_pouch.append(id)
	if save() != OK:
		blueprint_pouch.erase(id)
		blueprint_items[id] = true
		return "Could not move the blueprint."
	return "Moved to Blueprint Pouch."

func stow_pouch_blueprint(id: String) -> String:
	if not blueprint_pouch.has(id):
		return "Blueprint is unavailable."
	var slot := blueprint_pouch.find(id)
	blueprint_pouch.remove_at(slot)
	blueprint_items[id] = true
	if save() != OK:
		blueprint_items.erase(id)
		blueprint_pouch.insert(slot, id)
		return "Could not stow the blueprint."
	return "Returned to Storage."

func collect_blueprint(id: String) -> bool:
	if not can_collect_blueprint(id):
		return false
	blueprint_items[id] = true
	blueprint_hunts.erase(id)
	if pinned_blueprint == id:
		pinned_blueprint = ""
	return true

func blueprint_min_mode(id: String) -> int:
	if not GEAR.has(id) or not GEAR[id].has("sector"):
		return -1
	var sector: int = GEAR[id].sector
	for mode in Difficulty.NAMES.size():
		for part in Blueprints.drop_pool(sector, mode, PLAYER_LEVEL_CAP, true):
			if Blueprints.blueprint_id(sector, part) == id:
				return mode
	return -1

func pin_blueprint(id: String) -> void:
	if pinned_blueprint == id:
		pinned_blueprint = ""
	elif can_collect_blueprint(id) and loot_clears.has(GEAR[id].get("sector", 0)) and blueprint_min_mode(id) >= 0:
		pinned_blueprint = id

func advance_blueprint_hunt(sector: int, mode: int, operator_level: int) -> String:
	var id := pinned_blueprint
	if not can_collect_blueprint(id) or GEAR[id].get("sector", 0) != sector:
		return ""
	for part in Blueprints.drop_pool(sector, mode, operator_level, true):
		if Blueprints.blueprint_id(sector, part) != id:
			continue
		var clears := int(blueprint_hunts.get(id, 0)) + 1
		if clears >= HUNT_CLEARS:
			return id if collect_blueprint(id) else ""
		blueprint_hunts[id] = clears
		return ""
	return ""

func apply_recovery_crew(sector: int, recovered: Dictionary) -> void:
	var bonus := int(talent_bonus("recovery_crew"))
	if bonus > 0:
		var material := Materials.sector_key(sector)
		recovered[material] = int(recovered.get(material, 0)) + bonus

func apply_resupply_contract(recovered: Dictionary) -> int:
	var packs := int(talent_bonus("resupply_contract"))
	if packs > 0:
		recovered["resupply_pack"] = int(recovered.get("resupply_pack", 0)) + packs
	return packs

func award_archive_mastery(sector: int, mode: int, operator_level: int) -> Array[String]:
	var limit := int(talent_bonus("archive_mastery"))
	var earned: Array[String] = []
	if limit == 0:
		return earned
	var eligible := Blueprints.drop_pool(sector, mode, operator_level, true)
	eligible.shuffle()
	for part in eligible:
		var id := Blueprints.blueprint_id(sector, part)
		if collect_blueprint(id):
			earned.append(GEAR[id].name)
			if earned.size() == limit:
				break
	return earned

func learn_blueprint(id: String) -> String:
	if not GEAR.has(id) or not blueprint_items.has(id):
		return "Blueprint unavailable."
	if blueprints.has(id):
		return "Recipe already unlocked."
	if operator_level < crafting_level(id):
		return "Requires Operator Level %d." % crafting_level(id)
	blueprint_items.erase(id)
	blueprints[id] = true
	if save() != OK:
		blueprints.erase(id)
		blueprint_items[id] = true
		return "Could not save the blueprint."
	return "Learned " + String(GEAR[id].name) + "."

static func hub_item_label(key: String) -> String:
	if key.begins_with("blueprint/"):
		return String(GEAR.get(key.trim_prefix("blueprint/"), {}).get("name", "")) + " Blueprint"
	return String(stock.get(key, {}).get("name", ""))

static func valid_hub_item(key: String, amount: int) -> bool:
	if key.begins_with("blueprint/"):
		return amount == 1 and GEAR.has(key.trim_prefix("blueprint/"))
	return stock.has(key) and amount > 0 and amount <= STACK_MAX

func hub_item_count(key: String) -> int:
	if key.begins_with("blueprint/"):
		return int(blueprint_pouch.has(key.trim_prefix("blueprint/")))
	return supply_owned(key) if stock.has(key) else 0

func can_receive_hub_item(key: String, amount: int) -> bool:
	if not valid_hub_item(key, amount):
		return false
	if key.begins_with("blueprint/"):
		var id := key.trim_prefix("blueprint/")
		return blueprint_pouch.size() < BLUEPRINT_POUCH_SIZE and not blueprint_items.has(id) and not blueprint_pouch.has(id)
	return hub_item_count(key) + amount <= STACK_MAX

func change_hub_inventory(key: String, amount: int, persist: Callable) -> bool:
	if amount == 0 or not valid_hub_item(key, absi(amount)):
		return false
	var before := hub_item_count(key)
	if before + amount < 0 or (amount > 0 and not can_receive_hub_item(key, amount)):
		return false
	set_hub_item_count(key, before + amount)
	var error: Error = persist.call() if persist.is_valid() else save()
	if error != OK:
		set_hub_item_count(key, before)
		return false
	return true

func set_hub_item_count(key: String, count: int) -> void:
	if key.begins_with("blueprint/"):
		var id := key.trim_prefix("blueprint/")
		if count == 0:
			blueprint_pouch.erase(id)
		elif not blueprint_pouch.has(id):
			blueprint_pouch.append(id)
		return
	var item: Dictionary = stock[key]
	var target := carried_materials if item.has("material") else inventory
	var id: String = item.get("material", key)
	if count == 0:
		target.erase(id)
	else:
		target[id] = count

func refund_hub_item(key: String, amount: int, persist: Callable) -> bool:
	if not valid_hub_item(key, amount):
		return false
	if can_receive_hub_item(key, amount):
		return change_hub_inventory(key, amount, persist)
	var is_blueprint := key.begins_with("blueprint/")
	var target: Dictionary
	var id := key
	if is_blueprint:
		id = key.trim_prefix("blueprint/")
		if blueprint_items.has(id) or blueprint_pouch.has(id):
			return true
		target = blueprint_items
	else:
		var item: Dictionary = stock[key]
		target = materials if item.has("material") else stored_supplies
		id = item.get("material", key)
	var before: Variant = target.get(id)
	target[id] = true if is_blueprint else int(target.get(id, 0)) + amount
	var error: Error = persist.call() if persist.is_valid() else save()
	if error == OK:
		return true
	if before == null:
		target.erase(id)
	else:
		target[id] = before
	return false

func withdraw_inventory(key: String) -> String:
	if key.begins_with("blueprint/"):
		return move_blueprint_to_pouch(key.trim_prefix("blueprint/"))
	if not stock.has(key):
		return "Item unavailable."
	var item: Dictionary = stock[key]
	var source := materials if item.has("material") else stored_supplies
	var id: String = item.get("material", key)
	var before := int(source.get(id, 0))
	var carried := hub_item_count(key)
	var moved := mini(before, STACK_MAX - carried)
	if moved <= 0:
		return "Inventory stack is full." if before > 0 else "No items in Storage."
	if moved == before:
		source.erase(id)
	else:
		source[id] = before - moved
	set_hub_item_count(key, carried + moved)
	if save() != OK:
		source[id] = before
		set_hub_item_count(key, carried)
		return "Could not move the item."
	return "%s ×%d moved to Inventory." % [item.name, moved]

func supply_owned(id: String) -> int:
	var item: Dictionary = stock[id]
	return int(carried_materials.get(item.material, 0)) if item.has("material") else int(inventory.get(id, 0))

func supply_purchase_limit(id: String) -> int:
	if not sold_at_shop(id):
		return 0
	var item: Dictionary = stock[id]
	return clampi(floori(float(STACK_MAX - supply_owned(id)) / int(item.get("quantity", 1))), 0, STACK_MAX)

func supply_price(id: String) -> int:
	return maxi(1, ceili(stock[id].price * (1.0 - talent_bonus("vendor_license") / 100.0)))

func supply_order_price(id: String, bundles: int) -> int:
	var bulk_rate := 85 if bundles >= 10 else (90 if bundles >= 5 else 100)
	return ceili(supply_price(id) * bundles * bulk_rate / 100.0)

static func sold_at_shop(id: String) -> bool:
	return stock.has(id) and stock[id].get("material", "") not in ["core", "legendary"]

func buy_frame(id: String, persist: Callable) -> String:
	var price := int(OperatorFrames.PRICES.get(id, 0))
	if price <= 0 or not OperatorFrames.available(id) or not persist.is_valid():
		return "Frame unavailable."
	if id in owned_frames:
		return "Frame already owned."
	if credits < price:
		return "Not enough Bolts."
	credits -= price
	owned_frames.append(id)
	if persist.call() != OK:
		credits += price
		owned_frames.erase(id)
		return "Could not save the purchase."
	return "%s unlocked." % OperatorFrames.label(id)

func buy_supply(id: String, bundles := 1) -> String:
	if not sold_at_shop(id) or bundles < 1:
		return "Item unavailable."
	var item: Dictionary = stock[id]
	if operator_level < int(item.shop_level):
		return "Unlocks at Operator Lv. %d." % item.shop_level
	if bundles > supply_purchase_limit(id):
		return "Stack full."
	var cost := supply_order_price(id, bundles)
	if credits < cost:
		return "Not enough bolts."
	var quantity: int = int(item.get("quantity", 1)) * bundles
	var target := carried_materials if item.has("material") else inventory
	var key: String = item.get("material", id)
	var before := supply_owned(id)
	credits -= cost
	target[key] = before + quantity
	if save() != OK:
		credits += cost
		target[key] = before
		return "Could not save the purchase."
	return "Purchased %s ×%d. Added to Inventory." % [item.name, quantity]

func collect_field_supply(id: String, recovered: Dictionary) -> bool:
	if not stock.has(id) or stock[id].has("material"):
		return false
	var previous := int(recovered.get(id, 0))
	if previous >= STACK_MAX:
		return false
	recovered[id] = previous + 1
	return true

func stow_purchase(id: String) -> String:
	if not stock.has(id) or supply_owned(id) <= 0:
		return "No carried items to stow."
	var item: Dictionary = stock[id]
	var source := carried_materials if item.has("material") else inventory
	var target := materials if item.has("material") else stored_supplies
	var key: String = item.get("material", id)
	var count := int(source[key])
	var stored := int(target.get(key, 0))
	source.erase(key)
	target[key] = stored + count
	if save() != OK:
		source[key] = count
		target[key] = stored
		return "Could not stow the item."
	return "%s ×%d moved to Storage." % [item.name, count]

func finish_field_supplies(recovered: Dictionary, extracted: bool) -> Dictionary:
	var loot := recovered.duplicate() if extracted else {}
	for index in quick_slots.size():
		var slot := quick_slots[index]
		var field := int(slot.get("field", 0))
		if field > 0:
			if extracted:
				loot[slot.id] = int(loot.get(slot.id, 0)) + field
			slot.count -= field
			slot.erase("field")
			if slot.count == 0:
				quick_slots[index] = {}
	recovered.clear()
	quick_changed.emit()
	return loot

func deposit_supplies(recovered: Dictionary) -> void:
	for id in recovered:
		if stock.has(id) and not stock[id].has("material"):
			stored_supplies[id] = int(stored_supplies.get(id, 0)) + maxi(0, int(recovered[id]))

func assign_quick(index: int, id: String, source := &"inventory", recovered := {}) -> String:
	if index < 0 or index >= quick_slots.size() or not stock.has(id) or stock[id].has("material"):
		return "Invalid quick slot."
	var previous := quick_slots[index].duplicate()
	var old_id := String(previous.get("id", ""))
	var old_count := int(previous.get("count", 0))
	var old_field := int(previous.get("field", 0))
	var pocket := recovered if source == &"field" else stored_supplies if source == &"storage" else inventory
	var before := int(pocket.get(id, 0))
	if not old_id.is_empty() and old_id != id and (int(inventory.get(old_id, 0)) + old_count - old_field > STACK_MAX
			or int(recovered.get(old_id, 0)) + old_field > STACK_MAX):
		return "Make room for the previous stack."
	var amount := mini(QUICK_MAX - (old_count if old_id == id else 0), before)
	if amount <= 0:
		return "Slot is full or the item is out of stock."
	var snapshot := inventory.duplicate()
	var field_snapshot := recovered.duplicate()
	if not old_id.is_empty() and old_id != id:
		inventory[old_id] = int(inventory.get(old_id, 0)) + old_count - old_field
		if old_field > 0:
			recovered[old_id] = int(recovered.get(old_id, 0)) + old_field
	pocket[id] = before - amount
	quick_slots[index] = {"id": id, "count": amount + (old_count if old_id == id else 0)}
	var field := (old_field if old_id == id else 0) + (amount if source == &"field" else 0)
	if field > 0:
		quick_slots[index].field = field
	if save() != OK:
		inventory = snapshot
		recovered.assign(field_snapshot)
		if source == &"storage":
			stored_supplies[id] = before
		quick_slots[index] = previous
		return "Could not save the quick slot."
	quick_changed.emit()
	return "%s assigned." % stock[id].name

func clear_quick(index: int, recovered := {}) -> String:
	if index < 0 or index >= quick_slots.size():
		return "Invalid quick slot."
	var slot := quick_slots[index]
	var id := String(slot.get("id", ""))
	if id.is_empty():
		return "Slot is empty."
	var count := int(slot.get("count", 0))
	var field := int(slot.get("field", 0))
	var previous := int(inventory.get(id, 0))
	var previous_field := int(recovered.get(id, 0))
	if previous + count - field > STACK_MAX or previous_field + field > STACK_MAX:
		return "Inventory stack is full."
	inventory[id] = previous + count - field
	if field > 0:
		recovered[id] = previous_field + field
	quick_slots[index] = {}
	if save() != OK:
		quick_slots[index] = slot
		inventory[id] = previous
		if field > 0:
			recovered[id] = previous_field
		return "Could not save the quick slot."
	quick_changed.emit()
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
	var field := int(slot.get("field", 0))
	if field > 0:
		slot.field = field - 1
	if save() != OK:
		slot.count = count
		if field > 0:
			slot.field = field
		return false
	operator.apply_supply(item)
	quick_changed.emit()
	return true

func rank(id: String) -> int:
	return clampi(int(owned.get(id, 0)), 0, 3)

func talent_bonus(id: String) -> float:
	var installed := rank(id)
	if installed == 0:
		return 0.0
	for item in UPGRADES:
		if item.id == id and item.has("values"):
			return float(item.values[installed - 1])
	return 0.0

static func talent_effect(item: Dictionary, index: int) -> String:
	return item.effects[index] if item.has("effects") else item.effect % item.values[index]

func talent_branch(item: Dictionary) -> String:
	if item.has("branch"):
		return item.branch
	match item.category:
		"Armor", "Energy":
			return "Survivability"
		"Weapons", "Mobility":
			return "Damage"
		_:
			return "Scavenger"

func talent_tier(item: Dictionary) -> int:
	if item.has("tier"):
		return item.tier
	for tier in range(LEGACY_TALENT_LEVELS.size() - 1, 0, -1):
		if item.level >= LEGACY_TALENT_LEVELS[tier]:
			return tier
	return 0

func talent_gate(branch: String, tier: int) -> String:
	var catalog := all_upgrades()
	for earlier in range(tier):
		var unlocked := catalog.any(func(other):
			if rank(other.id) == 0 or talent_branch(other) != branch:
				return false
			return talent_tier(other) == earlier or (earlier == 0 and other.id in FORMER_ROOTS)
		)
		if not unlocked:
			return "Requires Tier %d talent" % (earlier + 1)
	return ""

static func talent_price(item: Dictionary, rank_index: int) -> int:
	return roundi(int(item.prices[rank_index]) * TALENT_PRICE_PERCENT / 100.0)

func talent_lock(item: Dictionary) -> String:
	var installed := rank(item.id)
	if installed >= item.prices.size():
		return "Installed"
	var level: int = item.levels[installed]
	if player_level() < level:
		return "Requires Lv. %d" % level
	var gate := talent_gate(talent_branch(item), talent_tier(item))
	if not gate.is_empty():
		return gate
	if core_shards < talent_price(item, installed):
		return "Not enough Core Shards"
	return ""

func buy(id: String) -> String:
	for item in UPGRADES:
		if item.id != id:
			continue
		var current := rank(id)
		var reason := talent_lock(item)
		if not reason.is_empty():
			return reason + "."
		var price := talent_price(item, current)
		core_shards -= price
		owned[id] = current + 1
		if save() != OK:
			core_shards += price
			if current == 0:
				owned.erase(id)
			else:
				owned[id] = current
			return "Could not save the purchase."
		return "%s %s installed." % [item.name, TALENT_RANKS[current]]
	return "Unknown upgrade."
