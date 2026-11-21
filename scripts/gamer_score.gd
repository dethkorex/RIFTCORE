extends RefCounted

const DOCUMENT := "riftcore_achievements"
const SkinKit := preload("res://scripts/operator_skins.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const AWARDS := {
	"iron_route": ["No Second Deployment", 40, "On Hard or Expert, defeat 12 security units and extract without losing a life."],
	"field_partners": ["Whole Squad Home", 65, "On Hard or Expert, defeat 14 security units as a squad and extract without losing a squad life."],
	"expert_entry": ["Guardian Breaker", 80, "Clear both acts and extract from any sector on Expert."],
	"expert_vanguard": ["Sweep and Salvage", 105, "On Expert, defeat 16 security units, recover 3 materials, and extract without losing a life."],
	"perfect_condition": ["Factory Finish", 90, "On Expert, extract with at least 95% health and 85% energy without losing a life."],
	"critical_hour": ["Beat the Blackout", 110, "On Expert, extract within eight minutes without losing a life."],
	"guardian_hunter": ["Five Locks Broken", 160, "Clear five different sectors on Expert."],
	"meridian_reclaimed": ["Meridian, Back Online", 250, "Clear every sector on Expert."],
}

static var achievement_catalog: Dictionary = build_catalog()
static var score_limit := compute_score_limit()

var owner := ""
var earned: Array[String] = []
var expert_sectors: Array[int] = []

static func build_catalog() -> Dictionary:
	var catalog := AWARDS.duplicate()
	for id in SkinKit.achievement_ids():
		catalog[id] = SkinKit.finish_achievement(id)
	return catalog

static func compute_score_limit() -> int:
	var total := 0
	for award in achievement_catalog.values():
		total += int(award[1])
	return total

func use_account(username: String) -> void:
	var key := username.to_lower()
	if owner == key:
		return
	owner = key
	earned.clear()
	expert_sectors.clear()
	if key.is_empty():
		return
	var stored := ConfigFile.new()
	if stored.load(local_path()) == OK:
		merge(stored.get_value("score", "progress", {}))

func local_path() -> String:
	return "user://riftcore_achievements_%s.cfg" % owner.sha256_text()

func merge(progress: Variant) -> void:
	if not progress is Dictionary:
		return
	var awards: Variant = progress.get("awards", [])
	if awards is Array:
		for id in awards:
			if id is String and achievement_catalog.has(id) and not earned.has(id):
				earned.append(id)
	var sectors: Variant = progress.get("expert_sectors", [])
	if sectors is Array:
		for value in sectors:
			if not value is int and not value is float:
				continue
			var sector := int(value)
			if value == sector and sector >= 1 and sector <= Catalog.SECTORS.size() and sector not in expert_sectors:
				expert_sectors.append(sector)

func snapshot() -> Dictionary:
	var awards := earned.duplicate()
	awards.sort()
	var sectors := expert_sectors.duplicate()
	sectors.sort()
	return {"awards": awards, "expert_sectors": sectors}

func save() -> Error:
	if owner.is_empty():
		return ERR_UNCONFIGURED
	var store := ConfigFile.new()
	store.set_value("score", "progress", snapshot())
	var path := ProjectSettings.globalize_path(local_path())
	var temporary := path + ".tmp"
	var error := store.save(temporary)
	return DirAccess.rename_absolute(temporary, path) if error == OK else error

func score() -> int:
	var points := 0
	for id in earned:
		points += int(achievement_catalog[id][1])
	return points

func record_clear(sector: int, mode: int, run: Dictionary) -> int:
	if owner.is_empty() or sector < 1 or sector > Catalog.SECTORS.size():
		return 0
	var before := snapshot()
	var previous := score()
	merge_finishes(run.get("finish_achievements", []))
	var clean := bool(run.get("clean", false))
	var kills := int(run.get("kills", 0))
	if mode >= Difficulty.HARD and clean and kills >= 12:
		add("iron_route")
	if mode >= Difficulty.HARD and clean and kills >= 14 and run.get("online", false):
		add("field_partners")
	if mode == Difficulty.NIGHTMARE:
		add(SkinKit.expert_finish(sector))
		add("expert_entry")
		if sector not in expert_sectors:
			expert_sectors.append(sector)
		if clean and kills >= 16 and int(run.get("materials", 0)) >= 3:
			add("expert_vanguard")
		if clean and float(run.get("health", 0.0)) >= 95.0 and float(run.get("energy", 0.0)) >= 85.0:
			add("perfect_condition")
		var seconds := float(run.get("seconds", 0.0))
		if clean and seconds > 0.0 and seconds <= 480.0:
			add("critical_hour")
	check_expert_progress()
	return score() - previous if persist_progress(before) else 0

func record_finishes(ids: Array) -> void:
	if owner.is_empty():
		return
	var before := snapshot()
	merge_finishes(ids)
	check_expert_progress()
	persist_progress(before)

func merge_finishes(ids: Array) -> void:
	for id in ids:
		if id is String and not SkinKit.finish_achievement(id).is_empty():
			add(id)
	for index in range(1, Catalog.SECTORS.size() + 1):
		if earned.has(SkinKit.expert_finish(index)) and index not in expert_sectors:
			expert_sectors.append(index)

func check_expert_progress() -> void:
	if not expert_sectors.is_empty():
		add("expert_entry")
	if expert_sectors.size() >= 5:
		add("guardian_hunter")
	if expert_sectors.size() == Catalog.SECTORS.size():
		add("meridian_reclaimed")

func persist_progress(before: Dictionary) -> bool:
	if before == snapshot() or save() == OK:
		return true
	earned.assign(before.awards)
	expert_sectors.assign(before.expert_sectors)
	push_warning("Could not save Gamer Score progress.")
	return false

func add(id: String) -> void:
	if not earned.has(id):
		earned.append(id)
