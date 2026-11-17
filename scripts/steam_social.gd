extends Node

const FRIEND := 4
signal whispers_changed(contact: Variant)
signal invites_changed

const WHISPER_CHANNEL := 27
const WHISPER_LIMIT := 300
var whispers: Dictionary = {}
var unread_whispers: Dictionary = {}
var pinned: Dictionary = {}
var invites: Dictionary = {}
var next_whisper_at := 0

const STEAM_MIN := 76561197960265728
var steam: Object
var ready_to_query := false
var app_id := 0
var storage_path := "user://riftcore_social.cfg"
var message := ""
var followed: Dictionary = {}
var operator_id := ""
var recent_players: Dictionary = {}
var rift_friends: Dictionary = {}

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var data := ConfigFile.new()
	if data.load(storage_path) == OK:
		for id in data.get_section_keys("followed") if data.has_section("followed") else []:
			if valid_id(id):
				followed[id] = String(data.get_value("followed", id, ""))

		operator_id = String(data.get_value("records", "operator_id", ""))
		recent_players = data.get_value("records", "recent", {})
		rift_friends = data.get_value("records", "friends", {})
		pinned = data.get_value("records", "pinned", {})
		for contact in recent_players.values():
			contact.erase("times")
	if operator_id.is_empty():
		operator_id = Crypto.new().generate_random_bytes(8).hex_encode()
	save_social()

func get_records() -> Dictionary:
	return {"id": operator_id}

func receive_records(payload: Dictionary, alias: String) -> void:
	var id := String(payload.get("id", ""))
	if id.length() != 16 or not id.is_valid_hex_number() or id == operator_id:
		return
	if recent_players.size() >= 50 and not recent_players.has(id):
		for old_id in recent_players.keys():
			if not rift_friends.has(old_id):
				recent_players.erase(old_id)
				break
		if recent_players.size() >= 50:
			return
	var record := {"name": alias.left(20)}
	if recent_players.get(id) != record:
		recent_players[id] = record
		save_social()

func toggle_rift_friend(id: String) -> void:
	if rift_friends.has(id):
		rift_friends.erase(id)
		pinned.erase("rift:" + id)
	elif recent_players.has(id):
		rift_friends[id] = true
	save_social()

func toggle_pin(contact: String) -> bool:
	var previous := pinned.duplicate()
	if pinned.has(contact):
		pinned.erase(contact)
	else:
		pinned[contact] = true
	if save_social():
		return true
	pinned = previous
	return false

func record_invite(display_name: String, code: String) -> void:
	if invites.size() >= 8 and not invites.has(code):
		invites.erase(invites.keys()[0])
	var ticket := {"name": display_name, "at": Time.get_ticks_msec()}
	invites[code] = ticket
	invites_changed.emit()
	get_tree().create_timer(180.0).timeout.connect(func():
		if invites.get(code) == ticket:
			remove_invite(code)
	)

func remove_invite(code: String) -> void:
	if invites.erase(code):
		invites_changed.emit()

func connect_steam() -> void:
	if not Engine.has_singleton("Steam"):
		message = "Steam integration is unavailable in this build."
		return
	steam = Engine.get_singleton("Steam")
	if not ready_to_query:
		var configured := int(ProjectSettings.get_setting("riftcore/steam_app_id", 0))
		var expected := configured if configured > 0 else OS.get_environment("SteamAppId").to_int()
		if expected <= 0 or expected == 480:
			message = "Steam presence is unavailable in this build. Use a room code to invite a friend."
			return
		var result: Dictionary = steam.steamInitEx(expected, false)
		ready_to_query = int(result.get("status", -1)) == 0
		if ready_to_query:
			app_id = steam.getAppID()
			ready_to_query = app_id == expected
			if ready_to_query:
				steam.network_messages_session_request.connect(accept_whisper_session)
				RiftRelay.listen_for_steam_invites()
	if not ready_to_query:
		message = "RIFTCORE could not connect to Steam. Open Steam and try Refresh Presence."
	elif not steam.loggedOn():
		message = "Your Steam client is connected to RIFTCORE, but is signed out or disconnected from Steam."
	else:
		message = "Your Steam connection is online."

func _process(_delta: float) -> void:
	if ready_to_query and (not steam.loggedOn() or get_node_or_null("/root/GDSync") == null):
		steam.run_callbacks()
	if ready_to_query and steam.loggedOn():
		for packet in steam.receiveMessagesOnChannel(WHISPER_CHANNEL, 12):
			var sender := int(packet.get("identity", 0))
			var payload: PackedByteArray = packet.get("payload", PackedByteArray())
			if payload.size() <= WHISPER_LIMIT * 4 and can_whisper(sender):
				var message_text := clean_whisper(payload.get_string_from_utf8())
				if not message_text.is_empty():
					receive_whisper(sender, message_text)

func can_whisper(id: int) -> bool:
	return id >= STEAM_MIN and ready_to_query and steam.loggedOn() and steam.getFriendRelationship(id) == 3 \
		and int(steam.getFriendPersonaState(id)) in [1, 2, 3, 4, 5, 6]

func accept_whisper_session(id: int) -> void:
	if can_whisper(id):
		steam.acceptSessionWithUser(id)

func clean_whisper(raw: String) -> String:
	var cleaned := ""
	for character in raw.strip_edges().left(WHISPER_LIMIT):
		var code := character.unicode_at(0)
		if code >= 32 and code != 127 and not (code >= 0x202a and code <= 0x202e) and not (code >= 0x2066 and code <= 0x2069):
			cleaned += character
	return cleaned.strip_edges()

func send_whisper(id: Variant, raw: String) -> bool:
	var body := clean_whisper(raw)
	var now := Time.get_ticks_msec()
	if body.is_empty() or now < next_whisper_at:
		return false
	if id is String and id.begins_with("account:"):
		var queued: bool = RiftRelay.directory.whispers.queue(id.trim_prefix("account:"), body)
		if queued:
			next_whisper_at = now + 500
		return queued
	if id is String:
		if not RiftRelay.whisper_to_operator(id.trim_prefix("rift:"), body):
			return false
	elif not can_whisper(id) or steam.sendMessageToUser(id, body.to_utf8_buffer(), steam.NETWORKING_SEND_RELIABLE_NO_NAGLE, WHISPER_CHANNEL) != 1:
		return false
	next_whisper_at = now + 500
	add_whisper(id, body, true)
	return true

func receive_whisper(id: Variant, body: String) -> void:
	unread_whispers[id] = int(unread_whispers.get(id, 0)) + 1
	add_whisper(id, body, false)

func add_whisper(id: Variant, body: String, outgoing: bool) -> void:
	if not whispers.has(id):
		if whispers.size() >= 32:
			var oldest: Variant = whispers.keys()[0]
			whispers.erase(oldest)
			unread_whispers.erase(oldest)
		whispers[id] = []
	var conversation: Array = whispers[id]
	conversation.append({"body": body, "outgoing": outgoing, "at": Time.get_time_string_from_system().left(5)})
	if conversation.size() > 50:
		conversation.pop_front()
	whispers_changed.emit(id)

func clear_whisper(id: Variant) -> void:
	unread_whispers.erase(id)
	if whispers.erase(id):
		whispers_changed.emit(id)

func clear_whispers(prefix: String) -> void:
	for id in whispers.keys():
		if id is String and id.begins_with(prefix):
			clear_whisper(id)

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
			if (name.is_empty() or name == id) and not display.is_empty() and display != "[unknown]":
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
	var previous_pins := pinned.duplicate()
	if alias.is_empty():
		followed.erase(id)
		pinned.erase("steam:" + id)
	else:
		followed[id] = alias.left(40)
	if save_social():
		return true
	followed = previous
	pinned = previous_pins
	return false

func save_social() -> bool:
	var data := ConfigFile.new()
	for key in followed:
		data.set_value("followed", key, followed[key])
	data.set_value("records", "operator_id", operator_id)
	data.set_value("records", "recent", recent_players)
	data.set_value("records", "friends", rift_friends)
	data.set_value("records", "pinned", pinned)
	return data.save(storage_path) == OK

func reset_social_data() -> bool:
	followed.clear()
	recent_players.clear()
	rift_friends.clear()
	pinned.clear()
	whispers.clear()
	unread_whispers.clear()
	invites.clear()
	operator_id = Crypto.new().generate_random_bytes(8).hex_encode()
	invites_changed.emit()
	return save_social()

func open_friends() -> void:
	if OS.shell_open("steam://open/friends") != OK:
		OS.shell_open("https://steamcommunity.com/my/friends/")

func open_profile(id: String) -> void:
	if valid_id(id):
		OS.shell_open("https://steamcommunity.com/profiles/" + id)
