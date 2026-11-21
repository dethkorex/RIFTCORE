extends RefCounted

const ART := {
	"medical": ["65efad", '<path d="M9 9h30l5 6v24l-5 5H9l-5-5V15z"/><path d="M17 9V5h14v4M4 19h10m20 0h10"/>', '<path d="M21 19h6v6h6v6h-6v6h-6v-6h-6v-6h6z"/>'],
	"hybrid": ["65eed2", '<path d="M9 8h30l5 6v23l-7 6H11l-7-6V14z"/><path d="M16 8V4h16v4M4 17h8m24 0h8"/>', '<path d="M14 21h5v5h5v5h-5v5h-5v-5H9v-5h5zM33 18l-6 11h5l-2 7 9-11h-5l3-7z"/>'],
	"energy": ["5ddaff", '<path d="M18 5h12v5h7l5 5v22l-6 6H12l-6-6V15l5-5h7z"/><path d="M10 17v9m28-9v9"/>', '<path d="M26 14L15 28h8l-3 11 13-16h-9z"/>'],
	"attack": ["ffd17f", '<path d="M4 24L17 10h20l7 8v9L31 41H11l-7-8z"/>', '<path d="M26 14h10v9L20 35l-6-6zM14 29l-5 5m8 0l-4 4"/>'],
	"defense": ["85b9ff", '<path d="M24 4l17 7v13c0 9-7 15-17 20C14 39 7 33 7 24V11z"/>', '<path d="M24 12l10 4v8c0 5-4 10-10 13-6-3-10-8-10-13v-8zM19 24l4 4 7-8"/>'],
	"speed": ["d8a0ff", '<path d="M5 13h12l12 11-12 11H5l12-11zM22 13h10l12 11-12 11H22l12-11z"/>', '<path d="M5 8h14M3 40h14M31 8h11m-9 32h11"/>'],
	"scrap": ["91c9ed", '<path d="M19 4h10l2 6 5 2 6-2 4 8-5 4v5l5 4-4 8-6-2-5 2-2 5H19l-2-5-5-2-6 2-4-8 5-4v-5l-5-4 4-8 6 2 5-2z"/>', '<circle cx="24" cy="24" r="9"/><path d="M22 20l6 6m-8 0l6-6"/>'],
	"components": ["afcfe5", '<path d="M11 8l19-4 13 13-3 20-19 7L7 32zM11 8l10 11 22-2M21 19l-1 17 20 1"/>', '<path d="M21 19l8-3 8 7-2 8-8 3-7-6z"/>'],
	"circuits": ["75dcab", '<path d="M10 6h25l7 7v25l-5 5H10l-5-5V11z"/><path d="M10 12h8v6m20 17h-9v-5M11 34h6v-5m18-7h6"/>', '<path d="M17 17h14v14H17zM22 22h4v4h-4z"/>'],
	"alloy": ["a9dcff", '<path d="M12 13l24-4 9 16-5 10-27 5-9-9zM12 13l9 15 24-3M4 31l17-3-8 12"/>', '<path d="M18 15l15-3 6 11-15 2zM25 32l11-2"/>'],
}

static var textures: Dictionary[String, Texture2D] = {}

static func icon(item: Dictionary) -> Texture2D:
	var key := kind(item)
	if not textures.has(key):
		var art: Array = ART[key]
		var source := '<svg xmlns="http://www.w3.org/2000/svg" width="144" height="144" viewBox="0 0 48 48"><g stroke-linecap="round" stroke-linejoin="round"><g fill="#%s" fill-opacity=".19" stroke="#%s" stroke-width="1.65">%s</g><g fill="#%s" fill-opacity=".54" stroke="#def8ff" stroke-width="1.2">%s</g></g></svg>' % [art[0], art[0], art[1], art[0], art[2]]
		var glyph := Image.new()
		glyph.load_svg_from_string(source)
		textures[key] = ImageTexture.create_from_image(glyph)
	return textures[key]

static func kind(item: Dictionary) -> String:
	if item.has("material"):
		var material: String = item.material
		return {"scrap": "scrap", "components": "components", "circuits": "circuits", "cells": "energy"}.get(material, "alloy")
	if item.has("stat"):
		return item.stat
	if item.get("hp", 0) == 0:
		return "energy"
	return "hybrid" if item.get("energy", 0) > 0 else "medical"
