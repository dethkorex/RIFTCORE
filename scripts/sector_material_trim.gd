@tool
extends RefCounted

const SHADER := preload("res://assets/campaign/material_trim.gdshader")
const PLATFORM_ROWS := [0, 107, 208, 298, 392, 474, 558, 643, 725, 810, 887]
const ARMOR_ROWS := [117, 171, 227, 284, 345, 404, 458, 512, 568, 623, 678]

static func make(number: int, armor := false) -> ShaderMaterial:
	var image_path := "res://assets/campaign/boss_trim_height.png" if armor else "res://assets/campaign/platform_trim_height.png"
	var atlas := load(image_path) as Texture2D
	var rows := ARMOR_ROWS if armor else PLATFORM_ROWS
	var index := clampi(number - 1, 0, 9)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("trim_sheet", atlas)
	var height := float(atlas.get_height())
	material.set_shader_parameter("strip", Vector2(rows[index] + 3, rows[index + 1] - 3) / height)
	if armor:
		material.set_shader_parameter("span", Vector2(2.84, 0.46))
		material.set_shader_parameter("center_y", 0.0)
		material.set_shader_parameter("metallic", 0.48)
	return material
