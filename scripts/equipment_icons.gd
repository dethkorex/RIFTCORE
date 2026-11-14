extends RefCounted

const Profile := preload("res://scripts/rogue_profile.gd")

const PATHS := {
	"armor_plate": '<path d="M5 8l11-4 11 4v14l-11 6-11-6zM9 10l7-2 7 2v8l-7 5-7-5zM16 8v15"/>',
	"recovery_bearing": '<circle cx="16" cy="16" r="11"/><circle cx="16" cy="16" r="4"/><path d="M16 5v4m0 14v4M5 16h4m14 0h4M8 8l3 3m10 10 3 3m0-16-3 3m-10 10-3 3"/>',
	"recon_optic": '<path d="M4 16c7-11 17-11 24 0-7 11-17 11-24 0z"/><circle cx="16" cy="16" r="4"/><path d="M16 3v4m0 18v4"/>',
	"repair_actuator": '<path d="M7 24l10-10 1-7 5-3-1 6 6-1-3 5-7 1-10 11zM5 8h7m-4-3v7"/>',
	"charge_regulator": '<path d="M7 5h18v22H7zM4 10h3m-3 6h3m-3 6h3m18-12h3m-3 6h3m-3 6h3M18 8l-6 9h6l-3 7 7-10h-6z"/>',
	"aegis": '<path d="M16 2l11 5v8c0 6-4 11-11 15C9 26 5 21 5 15V7zM16 8l6 3v5c0 3-2 6-6 8-4-2-6-5-6-8v-5z"/>',
	"overdrive_arm": '<path d="M4 18l15-10 8 2 1 7-15 10-8-2zM8 17l6 5m0-9 6 5m0-9 6 5M5 22l-3 2"/>',
	"salvage_optic": '<path d="M4 15l12-7 12 7-12 7zM10 19v6m12-6v6M16 4v4"/><circle cx="16" cy="15" r="3"/>',
	"visor": '<path d="M4 11l4-4h16l4 4v10l-5 4h-5l-2-3-2 3H9l-5-4zM8 15h16m-16 4h7m2 0h7"/>',
	"arm": '<path d="M8 5h11l5 8v10l-6 4H9l-2-5 3-5-3-7zM12 9h5l4 7m-8 3h7"/>',
	"frame": '<path d="M16 3l10 4v8c0 7-4 11-10 14C10 26 6 22 6 15V7z"/><path d="M11 14h10M16 9v10"/>',
	"core": '<path d="M16 3l11 6v14l-11 6-11-6V9z"/><circle cx="16" cy="16" r="5"/>',
	"utility": '<path d="M6 23l6-7-6-7h7l6 7-6 7zM17 23l6-7-6-7h6l6 7-6 7z"/>',
	"impact_liner": '<path d="M16 3l11 5v9c0 5-5 9-11 12C10 26 5 22 5 17V8z"/><path d="M10 15l4 4 8-8"/>',
	"vital_weave": '<path d="M12 6h8v6h6v8h-6v6h-8v-6H6v-8h6z"/>',
	"pulse_lens": '<circle cx="16" cy="16" r="9"/><circle cx="16" cy="16" r="3"/><path d="M16 2v5m0 18v5M2 16h5m18 0h5"/>',
	"charge_relay": '<rect x="7" y="6" width="18" height="23" rx="3"/><path d="M12 6V3h8v3m-4 4l-4 7h6l-2 7 6-9h-6z"/>',
	"air_jets": '<path d="M7 16l9-10 9 10-9-3zM11 19l-4 7m9-7v9m5-9l4 7"/>',
	"salvage_chip": '<path d="M6 7h6v10a4 4 0 008 0V7h6v10a10 10 0 01-20 0zm0 5h6m8 0h6"/>',
}
const COLORS := {"frame": Color("7ff0ba"), "core": Color("79d8ff"), "utility": Color("e5abff"), "visor": Color("79e6ed"), "arm": Color("ffc98a")}
const STAT_ICONS := {"xp": "visor", "healing": "vital_weave","resist": "impact_liner", "bolts": "salvage_chip", "dash": "air_jets", "attack": "pulse_lens", "energy": "charge_relay", "hp": "vital_weave"}
const BLUEPRINT_ICONS := [
	"impact_liner", "armor_plate", "pulse_lens", "charge_relay", "air_jets", "recovery_bearing",
	"recon_optic", "repair_actuator", "charge_regulator", "aegis", "overdrive_arm", "salvage_optic",
]
static var textures := {}

static func icon(id: String, slot: String) -> Texture2D:
	if not textures.has(id):
		var image := Image.new()
		var tint: Color = COLORS[slot]
		var symbol := id
		if Profile.GEAR.has(id):
			var item: Dictionary = Profile.GEAR[id]
			tint = Profile.RARITY_COLORS[item.rarity] if item.rarity > 0 else tint
			if item.has("sector"):
				symbol = BLUEPRINT_ICONS[id.get_slice("_", 2).to_int()]
			elif not PATHS.has(id):
				var stats: Dictionary = item.stats
				for stat in STAT_ICONS:
					if stats.has(stat):
						symbol = STAT_ICONS[stat]
						break
		var hex := String(tint.to_html(false))
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 32 32"><g fill="none" stroke="#%s" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [hex, PATHS.get(symbol, PATHS[slot])]
		image.load_svg_from_string(svg)
		textures[id] = ImageTexture.create_from_image(image)
	return textures[id]
