extends Node

const FRIEND := 4
const STEAM_MIN := 76561197960265728
var steam: Object
var ready_to_query := false
var app_id := 0
var storage_path := "user://riftcore_social.cfg"
var message := ""
var followed: Dictionary = {}

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var data := ConfigFile.new()
	if data.load(storage_path) == OK:
		for id in data.get_section_keys("followed") if data.has_section("followed") else []:
			if valid_id(id):
				followed[id] = String(data.get_value("followed", id, ""))

func connect_steam() -> void:
	if not Engine.has_singleton("Steam"):
		message = "Steam integration is unavailable in this build."
		return
	steam = Engine.get_singleton("Steam")
	if not ready_to_query:
		var configured := int(ProjectSettings.get_setting("riftcore/steam_app_id", 0))
		var expected := configured if configured > 0 else OS.get_environment("SteamAppId").to_int()
		if expected <= 0 or expected == 480:
			message = "Live Steam presence is unavailable without a RIFTCORE Steamworks App ID. Room codes still work."
			return
		var result: Dictionary = steam.steamInitEx(expected, false)
		ready_to_query = int(result.get("status", -1)) == 0
		if ready_to_query:
			app_id = steam.getAppID()
			ready_to_query = app_id == expected
	if not ready_to_query:
		message = "RIFTCORE could not connect to Steam. Open Steam and try Refresh Presence."
	elif not steam.loggedOn():
		message = "Your Steam client is connected to RIFTCORE, but is signed out or disconnected from Steam."
	else:
		message = "Your Steam connection is online."

func _process(_delta: float) -> void:
	if ready_to_query and (not steam.loggedOn() or get_node_or_null("/root/GDSync") == null):
		steam.run_callbacks()

func contacts() -> Array[Dictionary]:
	var ids := followed.duplicate()
	var connected: bool = ready_to_query and steam.loggedOn()
	if connected:
		for index in steam.getFriendCount(FRIEND):
			var friend_id: int = steam.getFriendByIndex(index, FRIEND)
			var game: Dictionary = steam.getFriendGamePlayed(friend_id)
			if app_id > 0 and int(game.get("id", 0)) == app_id:
				ids[str(friend_id)] = ""
	var rows: Array[Dictionary] = []
	for id in ids:
		var name := String(followed.get(id, ""))
		var status := "Friend presence unavailable"
		var priority := 3
		if connected and steam.getFriendRelationship(int(id)) == 3:
			var display: String = steam.getFriendPersonaName(int(id))
			if not display.is_empty() and display != "[unknown]":
				name = display
			var info: Dictionary = steam.getFriendGamePlayed(int(id))
			if int(info.get("id", 0)) == app_id and app_id > 0:
				status = "Playing RIFTCORE"
				priority = 0
			elif int(steam.getFriendPersonaState(int(id))) in [1, 2, 3, 4, 5, 6]:
				status = "Friend is online"
				priority = 1
			else:
				status = "Friend appears offline"
				priority = 2
		if name.is_empty():
			name = id
		rows.append({"id": id, "name": name, "status": status, "priority": priority, "saved": followed.has(id)})
	rows.sort_custom(func(a, b): return a.priority < b.priority if a.priority != b.priority else a.name.nocasecmp_to(b.name) < 0)
	return rows

func resolve_contact_id(value: String) -> String:
	value = value.strip_edges()
	for prefix in ["https://steamcommunity.com/profiles/", "http://steamcommunity.com/profiles/"]:
		if value.begins_with(prefix):
			var profile_id := value.trim_prefix(prefix).get_slice("?", 0).get_slice("#", 0).trim_suffix("/")
			return profile_id if valid_id(profile_id) else ""
	if valid_id(value):
		return value
	if value.is_valid_int() and value.length() <= 10:
		var account := value.to_int()
		if account > 0 and account <= 4294967295:
			return str(STEAM_MIN + account)
	return ""

func valid_id(value: String) -> bool:
	return value.length() == 17 and value.is_valid_int() and value.to_int() > STEAM_MIN and value.to_int() <= STEAM_MIN + 4294967295

func save_contact(id: String, alias: String) -> bool:
	if not valid_id(id):
		return false
	var previous := followed.duplicate()
	if alias.is_empty():
		followed.erase(id)
	else:
		followed[id] = alias.left(40)
	var data := ConfigFile.new()
	for key in followed:
		data.set_value("followed", key, followed[key])
	if data.save(storage_path) == OK:
		return true
	followed = previous
	return false

func open_friends() -> void:
	if OS.shell_open("steam://open/friends") != OK:
		OS.shell_open("https://steamcommunity.com/my/friends/")

func open_profile(id: String) -> void:
	if valid_id(id):
		OS.shell_open("https://steamcommunity.com/profiles/" + id)
