extends RefCounted

# Generated from assets/campaign/sector_plan.json by build_catalog.py.
const SECTORS := [
 {
  "number": 1,
  "id": "neon_factory",
  "title": "Neon Factory",
  "boss_slug": "forge_titan",
  "boss": "Forge Titan",
  "boss_node": "ForgeTitan",
  "element": "Fire / Mechanical",
  "reward": "magma_breaker",
  "reward_name": "Magma Breaker",
  "color": "ff8b36",
  "shot": "fire",
  "health": 1040,
  "weak": "",
  "gimmick": "",
  "level": "res://scenes/levels/neon_factory_test.tscn",
  "boss_scene": "res://scenes/levels/forge_titan.tscn",
  "enemies": []
 },
 {
  "number": 2,
  "id": "machine_jungle",
  "title": "Machine Jungle",
  "boss_slug": "verdant_colossus",
  "boss": "Verdant Colossus",
  "boss_node": "VerdantColossus",
  "element": "Nature / Poison",
  "reward": "thorn_swarm",
  "reward_name": "Thorn Swarm",
  "color": "a5ff71",
  "shot": "nature",
  "health": 1700,
  "weak": "magma_breaker",
  "gimmick": "Toxic root flood",
  "level": "res://scenes/levels/machine_jungle.tscn",
  "boss_scene": "res://scenes/levels/verdant_colossus.tscn",
  "enemies": []
 },
 {
  "number": 3,
  "id": "frozen_reactor",
  "title": "Frozen Reactor",
  "boss_slug": "cryo_warden",
  "boss": "Cryo Warden",
  "boss_node": "CryoWarden",
  "element": "Ice",
  "reward": "frost_lance",
  "reward_name": "Frost Lance",
  "color": "63dfff",
  "shot": "ice",
  "health": 1875,
  "weak": "magma_breaker",
  "gimmick": "Ice traction and coolant vents",
  "level": "res://scenes/levels/frozen_reactor.tscn",
  "boss_scene": "res://scenes/levels/cryo_warden.tscn",
  "enemies": [
   "Cryo Skater",
   "Shard Crawler",
   "Glacier Bastion",
   "Coolant Sentry",
   "Ice Wisp"
  ]
 },
 {
  "number": 4,
  "id": "abyssal_plant",
  "title": "Abyssal Plant",
  "boss_slug": "volt_kraken",
  "boss": "Volt Kraken",
  "boss_node": "VoltKraken",
  "element": "Electric / Water",
  "reward": "tidal_arc",
  "reward_name": "Tidal Arc",
  "color": "70e9ef",
  "shot": "electric",
  "health": 2075,
  "weak": "frost_lance",
  "gimmick": "Buoyant water and live electrode grids",
  "level": "res://scenes/levels/abyssal_plant.tscn",
  "boss_scene": "res://scenes/levels/volt_kraken.tscn",
  "enemies": [
   "Pressure Guard",
   "Arc Crab",
   "Dive Bulwark",
   "Coil Sentry",
   "Current Jelly"
  ]
 },
 {
  "number": 5,
  "id": "buried_archives",
  "title": "Buried Archives",
  "boss_slug": "sand_cipher",
  "boss": "Sand Cipher",
  "boss_node": "SandCipher",
  "element": "Sand / Technology",
  "reward": "data_lance",
  "reward_name": "Data Lance",
  "color": "ffc568",
  "shot": "data",
  "health": 2250,
  "weak": "tidal_arc",
  "gimmick": "Phasing ledges and sand geysers",
  "level": "res://scenes/levels/buried_archives.tscn",
  "boss_scene": "res://scenes/levels/sand_cipher.tscn",
  "enemies": [
   "Archive Sentinel",
   "Dune Scarab",
   "Cipher Guard",
   "Glyph Turret",
   "Relic Wisp"
  ]
 },
 {
  "number": 6,
  "id": "sky_dock",
  "title": "Sky Dock",
  "boss_slug": "aerowyrm",
  "boss": "Aerowyrm",
  "boss_node": "Aerowyrm",
  "element": "Wind / Speed",
  "reward": "gale_edge",
  "reward_name": "Gale Edge",
  "color": "8bffca",
  "shot": "wind",
  "health": 2475,
  "weak": "data_lance",
  "gimmick": "Wind lanes and air lifts",
  "level": "res://scenes/levels/sky_dock.tscn",
  "boss_scene": "res://scenes/levels/aerowyrm.tscn",
  "enemies": [
   "Deck Runner",
   "Gust Stalker",
   "Hangar Bastion",
   "Jet Sentry",
   "Wind Kite"
  ]
 },
 {
  "number": 7,
  "id": "biolab",
  "title": "BioLab",
  "boss_slug": "omega_chimera",
  "boss": "Omega Chimera",
  "boss_node": "OmegaChimera",
  "element": "Mutation / Chaos",
  "reward": "chimera_burst",
  "reward_name": "Chimera Burst",
  "color": "ff62b1",
  "shot": "chaos",
  "health": 2700,
  "weak": "gale_edge",
  "gimmick": "Mutation pulses and bounce pads",
  "level": "res://scenes/levels/biolab.tscn",
  "boss_scene": "res://scenes/levels/omega_chimera.tscn",
  "enemies": [
   "Culture Scout",
   "Mutation Crawler",
   "Quarantine Brute",
   "Dose Sentry",
   "Splice Drone"
  ]
 },
 {
  "number": 8,
  "id": "orbital_array",
  "title": "Orbital Array",
  "boss_slug": "eclipse_nova",
  "boss": "Eclipse Nova",
  "boss_node": "EclipseNova",
  "element": "Gravity / Light",
  "reward": "singularity_shot",
  "reward_name": "Singularity Shot",
  "color": "bc9aff",
  "shot": "gravity",
  "health": 2910,
  "weak": "chimera_burst",
  "gimmick": "Low gravity and timed solar fields",
  "level": "res://scenes/levels/orbital_array.tscn",
  "boss_scene": "res://scenes/levels/eclipse_nova.tscn",
  "enemies": [
   "Solar Scout",
   "Orbit Crawler",
   "Gravity Bastion",
   "Helio Sentry",
   "Nova Probe"
  ]
 },
 {
  "number": 9,
  "id": "scrapyard_expanse",
  "title": "Scrapyard Expanse",
  "boss_slug": "rust_revenant",
  "boss": "Rust Revenant",
  "boss_node": "RustRevenant",
  "element": "Metal / Regeneration",
  "reward": "scrap_reaver",
  "reward_name": "Scrap Reaver",
  "color": "ff9452",
  "shot": "metal",
  "health": 3160,
  "weak": "singularity_shot",
  "gimmick": "Magnetic pull and scrap presses",
  "level": "res://scenes/levels/scrapyard_expanse.tscn",
  "boss_scene": "res://scenes/levels/rust_revenant.tscn",
  "enemies": [
   "Salvage Runner",
   "Rivet Crawler",
   "Magnet Bulwark",
   "Scrap Sentry",
   "Rust Kite"
  ]
 },
 {
  "number": 10,
  "id": "riftcore_nexus",
  "title": "RiftCore Nexus",
  "boss_slug": "the_architect",
  "boss": "The Architect",
  "boss_node": "TheArchitect",
  "element": "Corruption / Energy",
  "reward": "core_override",
  "reward_name": "Core Override",
  "color": "ff6ca8",
  "shot": "core",
  "health": 3600,
  "weak": "scrap_reaver",
  "gimmick": "Corruption gates and phase locks",
  "level": "res://scenes/levels/riftcore_nexus.tscn",
  "boss_scene": "res://scenes/levels/the_architect.tscn",
  "enemies": [
   "Rift Pursuer",
   "Null Crawler",
   "Nexus Guardian",
   "Breach Sentry",
   "Corrupt Echo"
  ]
 }
]

static func info(number: int) -> Dictionary:
	return SECTORS[clampi(number - 1, 0, SECTORS.size() - 1)]

static func weapon(id: String) -> Dictionary:
	for entry in SECTORS:
		if entry.reward == id:
			return entry
	return {}
