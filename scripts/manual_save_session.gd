extends RefCounted

const Profile := preload("res://scripts/rogue_profile.gd")
const SLOT_COUNT := 3
const FORMAT := 2

static var slot_directory := "user://riftcore_manual_v1"

var slot: int
var profile := Profile.new()
var run := ConfigFile.new()
var owns_slot := false

func _init(number: int) -> void:
	slot = number
	profile.manual_only = true

static func read_slot(number: int) -> ConfigFile:
	if number < 1 or number > SLOT_COUNT:
		return null
	var data := ConfigFile.new()
	if data.load(slot_path(number)) != OK or int(data.get_value("slot", "format", 0)) not in [1, FORMAT]:
		return null
	return data

static func slot_path(number: int) -> String:
	return slot_directory.path_join("slot_%d.cfg" % number)

func load_slot() -> bool:
	var data := read_slot(slot)
	if not data:
		return false
	owns_slot = true
	profile.decode_from(data)
	run = ConfigFile.new()
	copy_checkpoint(data, run)
	return true

func save_slot() -> Error:
	var data := ConfigFile.new()
	data.set_value("slot", "format", FORMAT)
	data.set_value("slot", "saved_at", Time.get_datetime_string_from_system(false, true))
	profile.encode_into(data)
	copy_checkpoint(run, data)
	var error := write_slot(data)
	if error == OK:
		owns_slot = true
	return error

func invalidate_defeated_run() -> Error:
	if not owns_slot:
		return OK
	var data := read_slot(slot)
	if not data:
		return OK
	if data.has_section("checkpoint"):
		data.erase_section("checkpoint")
	data.set_value("profile", "unlocked_sector", 1)
	data.set_value("profile", "player_xp", profile.player_xp)
	data.set_value("profile", "core_shards", profile.core_shards)
	data.set_value("profile", "reserve_lives", profile.reserve_lives)
	data.set_value("inventory", "stock", profile.inventory)
	data.set_value("inventory", "quick", profile.quick_slots)
	data.set_value("inventory", "blueprints", profile.blueprint_items)
	for id in profile.blueprints:
		data.set_value("blueprints", id, true)
	for index in profile.memories:
		data.set_value("archive", "fragment_%d" % index, true)
	for ending in profile.endings:
		data.set_value("archive", ending, true)
	for id in Profile.GEAR:
		if profile.gear.get(id) in ["equipped", "carried"] and data.has_section_key("equipment", id):
			data.erase_section_key("equipment", id)
		elif data.get_value("equipment", id, "") == "equipped":
			data.set_value("equipment", id, "stored")
	return write_slot(data)

func write_slot(data: ConfigFile) -> Error:
	var directory := ProjectSettings.globalize_path(slot_directory)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var target := ProjectSettings.globalize_path(slot_path(slot))
	var temporary := target + ".tmp"
	error = data.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, target)
	return error

static func copy_checkpoint(source: ConfigFile, target: ConfigFile) -> void:
	if source.has_section("checkpoint"):
		for key in source.get_section_keys("checkpoint"):
			target.set_value("checkpoint", key, source.get_value("checkpoint", key))
