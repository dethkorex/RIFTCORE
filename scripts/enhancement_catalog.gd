extends RefCounted

const SOCKETS := ["frame", "core", "utility", "visor", "arm"]
const BASE_NAMES := {
	"frame": ["Ceramic Mesh", "Titan Lining", "Reactive Plating", "Impact Foam", "Bastion Skin", "Fiber Shell", "Pulse Insulation", "Kinetic Brace", "Chassis Ribbing", "Aegis Lattice"],
	"core": ["Flux Spine", "Cell Matrix", "Reactor Buffer", "Ion Tray", "Nova Coil", "Phase Capacitor", "Charge Mirror", "Dual Reactor", "Pulse Stack", "Nexus Battery"],
	"utility": ["Air Bearings", "Stride Gears", "Vector Dampers", "Jump Seals", "Slipstream Rails", "Kinetic Bearings", "Motion Drivers", "Rapid Couplers", "Hyper Treads", "Rift Servos"],
	"visor": ["Scan Optics", "Salvage Lens", "Focus Array", "Prism Filter", "Thermal Optics", "Range Finder", "Data Visor", "Spectral Lens", "Target Processor", "Nexus Scanner"],
	"arm": ["Grip Servo", "Buster Coupler", "Blade Link", "Pulse Chamber", "Arc Emitter", "Ion Driver", "Servo Rings", "Flux Barrel", "Precision Winding", "Starfire Relay"],
}

static func catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in SOCKETS:
		for index in 10:
			var rarity := mini(index / 3, 3)
			var fraction := 0.004 + index * 0.001
			var stats: Dictionary
			var detail: String
			match slot:
				"frame":
					stats = {"hp": 2 + index, "resist": fraction}
					detail = "+%d HP  ·  %.1f%% resistance" % [stats.hp, fraction * 100]
				"core":
					stats = {"energy": 3 + index, "charge": 1.0 - fraction}
					detail = "+%d energy  ·  %.1f%% lower charge cost" % [stats.energy, fraction * 100]
				"utility":
					stats = {"speed": 1.0 + fraction, "dash": 1.0 + fraction * 1.5}
					detail = "+%.1f%% run speed  ·  +%.1f%% dash speed" % [fraction * 100, fraction * 150]
				"visor":
					stats = {"bolts": 1.0 + fraction * 3, "xp": 1.0 + fraction * 2}
					detail = "+%.1f%% bolted salvage  ·  +%.1f%% pickup XP" % [fraction * 300, fraction * 200]
				_:
					stats = {"attack": 1.0 + fraction * 2}
					detail = "+%.1f%% Buster and blade damage" % (fraction * 200)
			result.append({"id": "socket_%s_%02d" % [slot, index], "name": BASE_NAMES[slot][index],
				"slot": slot, "rarity": rarity, "prices": [[45, 90, 175, 350][rarity] + index * 8],
				"effects": [detail], "level": 2 + index * 2, "stats": stats})
	return result
