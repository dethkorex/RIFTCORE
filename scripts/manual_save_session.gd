extends RefCounted

const Profile := preload("res://scripts/rogue_profile.gd")
const SLOT_COUNT := 3
const FORMAT := 2

static var slot_directory := "user://riftcore_manual_v1"

var slot: int
var profile := Profile.new()
var run := ConfigFile.new()
var owns_slot := false
var play_seconds := 0
var shared_gear_under_loadout: Array[String] = []
var session_started_at := Time.get_ticks_msec()

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

static func shared_path() -> String:
	return slot_directory.path_join("shared_progress.cfg")

func load_shared() -> Error:
	var saved := ConfigFile.new()
	var error := saved.load(shared_path())
	var shared := Profile.new()
	if error == OK:
		shared.decode_from(saved)
		for id in saved.get_value("inventory", "blueprint_pouch", []):
			if shared.blueprint_items.erase(id):
				shared.blueprint_pouch.append(id)
	elif error == ERR_FILE_NOT_FOUND:
		for number in range(1, SLOT_COUNT + 1):
			var old := read_slot(number)
			if not old:
				continue
			var legacy := Profile.new()
			legacy.decode_from(old)
			for id in legacy.materials:
				shared.materials[id] = int(shared.materials.get(id, 0)) + int(legacy.materials[id])
			for id in legacy.stored_supplies:
				shared.stored_supplies[id] = int(shared.stored_supplies.get(id, 0)) + int(legacy.stored_supplies[id])
			for id in legacy.gear:
				if legacy.gear[id] == "stored":
					shared.gear[id] = "stored"
			for id in legacy.owned:
				shared.owned[id] = maxi(shared.rank(id), legacy.rank(id))
			for id in legacy.blueprint_hunts:
				shared.blueprint_hunts[id] = maxi(int(shared.blueprint_hunts.get(id, 0)), int(legacy.blueprint_hunts[id]))
			shared.core_shards += legacy.core_shards
			shared.blueprints.merge(legacy.blueprints)
			shared.blueprint_items.merge(legacy.blueprint_items)
	else:
		return error
	profile.materials = shared.materials
	profile.stored_supplies = shared.stored_supplies
	profile.blueprints = shared.blueprints
	profile.blueprint_items = shared.blueprint_items
	profile.blueprint_pouch = shared.blueprint_pouch
	profile.blueprint_hunts = shared.blueprint_hunts
	profile.owned = shared.owned
	profile.core_shards = shared.core_shards
	for id in profile.blueprints:
		profile.blueprint_items.erase(id)
	for id in profile.gear.keys():
		if profile.gear[id] == "stored":
			profile.gear.erase(id)
	shared_gear_under_loadout.clear()
	for id in shared.gear:
		if profile.gear.get(id) == "equipped":
			shared_gear_under_loadout.append(id)
		else:
			profile.gear[id] = "stored"
	return OK

func save_shared() -> Error:
	var data := ConfigFile.new()
	data.set_value("profile", "materials", profile.materials)
	data.set_value("profile", "core_shards", profile.core_shards)
	data.set_value("inventory", "stored_supplies", profile.stored_supplies)
	data.set_value("inventory", "blueprints", profile.blueprint_items)
	data.set_value("inventory", "blueprint_pouch", profile.blueprint_pouch)
	data.set_value("archive", "blueprint_hunts", profile.blueprint_hunts)
	for id in profile.blueprints:
		data.set_value("blueprints", id, true)
	for id in profile.owned:
		data.set_value("upgrades", id, profile.rank(id))
	for id in shared_gear_under_loadout:
		data.set_value("equipment", id, "stored")
	for id in profile.gear:
		if profile.gear[id] == "stored":
			data.set_value("equipment", id, "stored")
	return write_config(data, shared_path())

static func delete_slot(number: int) -> Error:
	if not read_slot(number):
		return ERR_FILE_NOT_FOUND
	if not FileAccess.file_exists(shared_path()):
		var existing = load("res://scripts/manual_save_session.gd").new(number)
		var error: Error = existing.load_shared()
		if error == OK:
			error = existing.save_shared()
		if error != OK:
			return error
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(number)))

func persist_reconstruction_seen() -> Error:
	if not owns_slot:
		return OK
	var data := read_slot(slot)
	if not data:
		return ERR_FILE_NOT_FOUND
	data.set_value("story", "reconstruction_seen", true)
	return write_slot(data)

func load_slot() -> bool:
	var data := read_slot(slot)
	if not data:
		return false
	owns_slot = true
	play_seconds = maxi(0, int(data.get_value("slot", "play_seconds", 0)))
	session_started_at = Time.get_ticks_msec()
	profile.decode_from(data)
	run = ConfigFile.new()
	copy_checkpoint(data, run)
	return load_shared() == OK

func save_slot() -> Error:
	var data := ConfigFile.new()
	data.set_value("slot", "format", FORMAT)
	data.set_value("slot", "saved_at", Time.get_datetime_string_from_system(false, true))
	data.set_value("slot", "play_seconds", play_seconds + floori((Time.get_ticks_msec() - session_started_at) / 1000.0))
	profile.encode_into(data)
	copy_checkpoint(run, data)
	var error := write_progress(data)
	if error == OK:
		owns_slot = true
	return error

func invalidate_defeated_run() -> Error:
	run = ConfigFile.new()
	profile.lose_equipped_gear()
	if not owns_slot:
		return OK
	var data := read_slot(slot)
	if not data:
		return OK
	if data.has_section("checkpoint"):
		data.erase_section("checkpoint")
	data.set_value("profile", "unlocked_sector", profile.unlocked_sector)
	data.set_value("profile", "credits", profile.credits)
	data.set_value("profile", "materials", profile.materials)
	data.set_value("profile", "player_xp", profile.player_xp)
	data.set_value("story", "shop_announced_through", profile.shop_announced_through)
	data.set_value("profile", "core_shards", profile.core_shards)
	data.set_value("profile", "reserve_lives", profile.reserve_lives)
	data.set_value("profile", "first_main_bosses", profile.first_main_bosses)
	data.set_value("inventory", "stock", profile.inventory)
	data.set_value("inventory", "carried_materials", profile.carried_materials)
	data.set_value("inventory", "stored_supplies", profile.stored_supplies)
	data.set_value("inventory", "quick", profile.quick_slots)
	data.set_value("inventory", "blueprints", profile.blueprint_items)
	data.set_value("inventory", "blueprint_pouch", profile.blueprint_pouch)
	data.set_value("challenge_cycles", "sectors", profile.challenge_cycles)
	data.set_value("archive", "loot_clears", profile.loot_clears)
	data.set_value("archive", "normal_clears", profile.normal_clears)
	data.set_value("archive", "hard_clears", profile.hard_clears)
	data.set_value("archive", "pinned_blueprint", profile.pinned_blueprint)
	data.set_value("archive", "blueprint_hunts", profile.blueprint_hunts)
	for id in profile.blueprints:
		data.set_value("blueprints", id, true)
	for index in profile.memories:
		data.set_value("archive", "fragment_%d" % index, true)
	for ending in profile.endings:
		data.set_value("archive", ending, true)
	for id in profile.owned:
		data.set_value("upgrades", id, profile.rank(id))
	if data.has_section("equipment"):
		data.erase_section("equipment")
	for id in profile.gear:
		data.set_value("equipment", id, profile.gear[id])
	return write_progress(data)

func persist_challenge_progress() -> Error:
	var data := read_slot(slot)
	if not data:
		return ERR_FILE_NOT_FOUND
	data.set_value("challenge_cycles", "sectors", profile.challenge_cycles)
	return write_slot(data)

func persist_reserve_lives() -> Error:
	var data := read_slot(slot)
	if not data:
		return ERR_FILE_NOT_FOUND
	data.set_value("profile", "reserve_lives", profile.reserve_lives)
	data.set_value("profile", "first_main_bosses", profile.first_main_bosses)
	return write_slot(data)

func write_progress(data: ConfigFile) -> Error:
	var previous := FileAccess.get_file_as_bytes(slot_path(slot)) if FileAccess.file_exists(slot_path(slot)) else PackedByteArray()
	var error := write_slot(data)
	if error != OK:
		return error
	error = save_shared()
	if error != OK:
		if previous.is_empty():
			DirAccess.remove_absolute(slot_path(slot))
		else:
			var original := ConfigFile.new()
			if original.parse(previous.get_string_from_utf8()) == OK:
				write_slot(original)
	return error

func write_slot(data: ConfigFile) -> Error:
	return write_config(data, slot_path(slot))

static func write_config(data: ConfigFile, path: String) -> Error:
	var directory := ProjectSettings.globalize_path(slot_directory)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var target := ProjectSettings.globalize_path(path)
	var temporary := target + ".tmp"
	error = data.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, target)
	return error

static func copy_checkpoint(source: ConfigFile, target: ConfigFile) -> void:
	if source.has_section("checkpoint"):
		for key in source.get_section_keys("checkpoint"):
			target.set_value("checkpoint", key, source.get_value("checkpoint", key))
