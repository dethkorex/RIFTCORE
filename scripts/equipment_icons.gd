extends RefCounted

const Profile := preload("res://scripts/rogue_profile.gd")

const PATHS := {
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
static var textures := {}

static func icon(id: String, slot: String) -> Texture2D:
	if not textures.has(id):
		var image := Image.new()
		var tint: Color = COLORS[slot]
		var symbol := id
		if Profile.GEAR.has(id):
			var item: Dictionary = Profile.GEAR[id]
			tint = Profile.RARITY_COLORS[item.rarity] if item.rarity > 0 else tint
			if not PATHS.has(id):
				var stats: Dictionary = item.stats
				for stat in STAT_ICONS:
					if stats.has(stat):
						symbol = STAT_ICONS[stat]
						break
		var hex := String(tint.to_html(false))
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 32 32"><g fill="none" stroke="#%s" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [hex, PATHS.get(symbol, PATHS[slot])]
		image.load_svg_from_string(svg)
		textures[id] = ImageTexture.create_from_image(image)
	return textures[id]
