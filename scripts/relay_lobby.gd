extends Node

signal changed
signal deploy_requested(host: bool, sector: int)
signal deployment_countdown(sector: int, number: int)
var counting_down := false
signal partner_moved(id: int, x: float, facing: float, animation: String, display_name: String)
signal blueprint_drop_changed(key: String, id: String, owner: int, x: float)
signal blueprint_received(id: String)
signal guest_joined
signal mission_returned
signal mission_disconnected(message: String)
signal party_rejoin_offered
signal invite_received(display_name: String, code: String, password: String)
signal party_chat_changed

const Profile := preload("res://scripts/rogue_profile.gd")
const Keys := preload("res://addons/GD-Sync/Scripts/KeyStore.gd")
const Client := preload("res://addons/GD-Sync/MultiplayerClient.gd")
const PlayerDirectory := preload("res://scripts/player_directory.gd")
const PartyVoice := preload("res://scripts/party_voice.gd")
const PartyRecovery := preload("res://scripts/party_recovery.gd")
const RelayEnums := preload("res://addons/GD-Sync/Scripts/Enums/Enums.gd")
const Codes := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CodeLength := 10
const ROOM_PREFIX := "riftcore-coop-v17-"
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const MAX_PLAYERS := 4
const PARTY_ACCESS := {"public": "Public", "friends": "Friends Only", "invite": "Invite Only"}
const ACCESS_TAG := "RiftcoreAccess"
const PARTY_CHAT_INTERVAL := 150
const PARTY_CHAT_BURST := 4.0
const RELAY_UNAVAILABLE := "Online rooms are unavailable. Solo play is available."

var status := "Create a room or enter a friend’s room code."
var connected_room := ""
var pending := ""
var room_code := ""
var room_size := 0
var room_access := "public"
var room_password := ""
var previous_room_password := ""
var pending_access := ""
var pending_password := ""
var public_rooms: Array[Dictionary] = []
var browsing_rooms := false
var lobby_browse_status := ""
var browse_generation := 0
var available := false
var pending_invite := 0
var directory_invite := ""
var checking_friend_room := false
var quitting := false
var relay_starting := false
var relay_ready := false
var copy_on_join := false
var party_operators: Dictionary[int, String] = {}
var last_party_whisper: Dictionary[int, int] = {}
var party_messages: Array[Dictionary] = []
var party_chat_allowance: Dictionary[int, Vector2] = {}
var mission_active := false
var mission_roster: Array = []
var mission_mode := 0
var previous_room := ""
var hard_sectors: Array = []
var nightmare_unlocked := false
var steam_invite_lobbies: Dictionary = {}
var local_name := "RX-07"
var local_armor_finish := ""
var local_operator_frame := ""
var unlocked_sector := 1

var blueprint_drops: Dictionary = {}
var station_positions: Dictionary = {}
var last_station_pose := Vector2(INF, INF)
var last_station_animation := ""
var last_station_update_at := 0
var drop_serial := 0
var relay: Node
var request_timeout: Timer
var voice: PartyVoice
var directory: PlayerDirectory
var recovery: PartyRecovery

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	recovery = PartyRecovery.new()
	recovery.name = "PartyRecovery"
	recovery.lobby = self
	add_child(recovery)
	recovery.resumed.connect(func(roster: Array): mission_roster = roster.duplicate())
	voice = PartyVoice.new()
	voice.name = "PartyVoice"
	voice.lobby = self
	add_child(voice)
	directory = PlayerDirectory.new()
	directory.lobby = self
	add_child(directory)
	available = Keys.has_keys()
	if not available:
		status = RELAY_UNAVAILABLE
	request_timeout = Timer.new()
	request_timeout.one_shot = true
	request_timeout.wait_time = 30.0
	request_timeout.timeout.connect(func():
		if is_rejoining_mission():
			rejoin_attempt_failed("The relay did not answer. Retrying…")
		else:
			leave("The connection timed out. Try again.", false)
	)
	add_child(request_timeout)

func _initialize_client() -> void:
	if is_instance_valid(relay):
		return
	relay = get_tree().root.get_node_or_null("GDSync")
	if relay == null:
		relay = Client.new()
		relay.name = "GDSync"
		get_tree().root.add_child(relay)
	relay.connected.connect(func():
		relay_ready = true
		relay_starting = false
		_request_room()
		if browsing_rooms:
			relay.get_public_lobbies()
	)
	relay.lobbies_received.connect(_public_rooms_received)
	relay.connection_failed.connect(_connection_failed)
	relay.disconnected.connect(_disconnected)
	relay.lobby_created.connect(_join_created_room)
	relay.lobby_creation_failed.connect(_room_failed)
	relay.lobby_joined.connect(_room_joined)
	relay.lobby_join_failed.connect(_room_failed)
	relay.steam_join_request.connect(func(lobby_name: String, has_password: bool):
		if not has_password and lobby_name.begins_with(ROOM_PREFIX):
			join_room(lobby_name.trim_prefix(ROOM_PREFIX))
	)
	relay.client_joined.connect(_players_changed)
	relay.client_left.connect(_peer_left)
	relay.host_changed.connect(_host_changed)
	relay.player_data_changed.connect(_difficulty_data_changed)
	relay.kicked.connect(func(_reason: String): leave("You were removed from the room."))

func ensure_relay() -> void:
	if not available:
		return
	_initialize_client()
	if not relay_ready and not relay_starting and not relay.is_active():
		relay_starting = true
		relay.start_multiplayer()

func quit_game() -> void:
	if quitting:
		return
	quitting = true
	if is_instance_valid(relay) and relay.account_is_logged_in():
		var clear_whispers: bool = not directory.whispers.session_owner.is_empty()
		relay.quit(_finish_account_session.bind(clear_whispers) if directory.online() else Callable())
	else:
		get_tree().quit()

func _finish_account_session(clear_whispers: bool) -> void:
	# Back up the save before transient chat and presence cleanup can block its write.
	await directory.progress.sync()
	if not directory.online():
		return
	if clear_whispers:
		directory.whispers.clear_cloud()
	directory.unpublish_presence()

func browse_rooms() -> void:
	if not available or browsing_rooms:
		return
	browsing_rooms = true
	lobby_browse_status = "Searching for open lobbies…"
	browse_generation += 1
	var generation := browse_generation
	changed.emit()
	ensure_relay()
	if relay_ready:
		relay.get_public_lobbies()
	get_tree().create_timer(12.0).timeout.connect(func():
		if browsing_rooms and generation == browse_generation:
			_finish_browse("The relay did not return a lobby list. Try Refresh.")
	)

func _public_rooms_received(rows: Array) -> void:
	if not browsing_rooms:
		return
	var matches: Array[Dictionary] = []
	var seen := {}
	for info in rows:
		if not info is Dictionary or not info.get("Open", true) or info.get("HasPassword", false):
			continue
		var name := String(info.get("Name", ""))
		var max_players := int(info.get("PlayerLimit", MAX_PLAYERS))
		var players := int(info.get("PlayerCount", 0))
		var code := name.trim_prefix(ROOM_PREFIX)
		var tags: Variant = info.get("Tags", {})
		if not name.begins_with(ROOM_PREFIX) or not valid_code(code) or seen.has(code) or code == connected_room:
			continue
		if players < 1 or players >= max_players or not tags is Dictionary or tags.get(ACCESS_TAG, "public") != "public":
			continue
		seen[code] = true
		var host := String(tags.get("RiftcoreHost", info.get("Host", ""))).strip_edges()
		matches.append({"code": code, "host": Profile.clean_operator_name(host), "players": players, "limit": max_players})
	matches.sort_custom(func(a, b): return a.host.nocasecmp_to(b.host) < 0)
	public_rooms = matches
	_finish_browse("No public lobbies have open seats." if matches.is_empty() else "")

func _finish_browse(message: String) -> void:
	browsing_rooms = false
	lobby_browse_status = message
	changed.emit()

func host_room(access := "public") -> void:
	if not pending.is_empty() or not connected_room.is_empty():
		return
	if not PARTY_ACCESS.has(access) and access != "code":
		return
	if access in ["friends", "invite"] and not directory.online():
		_update("Sign in to host a restricted party.")
		return
	var code := ""
	for byte in Crypto.new().generate_random_bytes(CodeLength):
		code += Codes[byte % Codes.length()]
	pending_access = access
	var password := Crypto.new().generate_random_bytes(8).hex_encode() if access in ["friends", "invite"] else ""
	_open("host", code, password)

func publish_operator_appearance(frame: String, finish: String) -> void:
	local_operator_frame = frame
	local_armor_finish = finish
	if is_instance_valid(relay) and not connected_room.is_empty():
		relay.player_set_data("operator_frame", frame)
		relay.player_set_data("armor_finish", finish)

func copy_invite_code() -> void:
	if not can_copy_invite_code():
		return
	if connected_room.is_empty():
		copy_on_join = true
		host_room("code")
	else:
		DisplayServer.clipboard_set(connected_room)
		_update("Room code copied. Send it to your friend.")

func can_copy_invite_code() -> bool:
	return can_invite_to_party() and room_password.is_empty()

func can_invite_to_party() -> bool:
	return available and pending.is_empty() and not mission_active and room_size < MAX_PLAYERS and (connected_room.is_empty() or relay.is_host())

func can_invite_friend() -> bool:
	return can_copy_invite_code() and pending_invite == 0 and directory_invite.is_empty() and RiftSocial.ready_to_query

func can_invite_directory_friend() -> bool:
	return directory.online() and can_invite_to_party() and directory_invite.is_empty() and pending_invite == 0

func invite_directory_friend(name: String) -> void:
	if not can_invite_directory_friend():
		return
	directory_invite = name
	if connected_room.is_empty():
		host_room("invite")
	else:
		_send_directory_invite.call_deferred()

func _send_directory_invite() -> void:
	var friend := directory_invite
	var room := connected_room
	if friend.is_empty() or room.is_empty():
		return
	var result: int = await relay.account_invite_friend_to_lobby(friend)
	if directory_invite != friend or connected_room != room:
		return
	directory_invite = ""
	_update("Invite sent to %s." % friend if result == 0 else directory.response_message("Could not send the invite", result))

func join_room(entered_code: String, password := "") -> void:
	if not pending.is_empty() or not connected_room.is_empty():
		return
	var code := entered_code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if not valid_code(code):
		_update("Enter the ten-character room code.")
		return
	_open("join", code, password)

func can_rejoin_party() -> bool:
	return available and not previous_room.is_empty() and can_receive_invite()

func rejoin_party() -> void:
	if recovery.active():
		recovery.start_rejoin()
	elif can_rejoin_party():
		_open("rejoin_party", previous_room, previous_room_password)

func is_rejoining_mission() -> bool:
	return pending in ["rejoin_mission", "recreate_mission"]

func joinable_room() -> String:
	if room_access == "invite" or (room_access == "friends" and not relay.is_host()):
		return ""
	return connected_room if pending.is_empty() and not mission_active and room_size < MAX_PLAYERS else ""

func join_directory_friend(name: String) -> void:
	if checking_friend_room or not can_receive_invite() or not directory.online():
		return
	checking_friend_room = true
	_update("Checking %s’s party…" % name)
	var entry: Dictionary = await directory.lookup_open_room(name)
	if entry.is_empty() and can_receive_invite() and directory.online():
		await get_tree().create_timer(0.5).timeout
		if can_receive_invite() and directory.online():
			entry = await directory.lookup_open_room(name)
	checking_friend_room = false
	if not can_receive_invite():
		return
	if entry.is_empty():
		_update("%s’s party is no longer open." % name)
		return
	if entry.get("access") == "friends":
		directory.request_friends_party(name, entry.code)
	else:
		join_room(entry.code)

func listen_for_steam_invites() -> void:
	if RiftSocial.ready_to_query and available:
		_initialize_client()
		var steam: Object = RiftSocial.steam
		if not steam.is_connected("lobby_invite", _receive_steam_invite):
			steam.connect("lobby_invite", _receive_steam_invite)
			steam.connect("lobby_data_update", _receive_invite_lobby_data)

func can_receive_invite() -> bool:
	return available and not mission_active and connected_room.is_empty() and pending.is_empty()

func _receive_steam_invite(inviter: int, lobby: int, _game: int) -> void:
	if not can_receive_invite() or steam_invite_lobbies.has(lobby) or steam_invite_lobbies.size() >= MAX_PLAYERS:
		return
	var steam: Object = RiftSocial.steam
	if steam.getFriendRelationship(inviter) != 3:
		return
	steam_invite_lobbies[lobby] = inviter
	if not steam.requestLobbyData(lobby):
		steam_invite_lobbies.erase(lobby)
		return
	get_tree().create_timer(8.0).timeout.connect(func(): steam_invite_lobbies.erase(lobby))

func _receive_invite_lobby_data(success: int, lobby: int, member: int) -> void:
	if member != lobby or not steam_invite_lobbies.has(lobby):
		return
	var inviter: int = steam_invite_lobbies[lobby]
	steam_invite_lobbies.erase(lobby)
	if success == 0 or not can_receive_invite():
		return
	var steam: Object = RiftSocial.steam
	var name: String = steam.getLobbyData(lobby, "gdsyncid")
	if not name.begins_with(ROOM_PREFIX) or steam.getLobbyData(lobby, "haspassword") == "true":
		return
	var code := name.trim_prefix(ROOM_PREFIX)
	if valid_code(code):
		invite_received.emit(Profile.clean_operator_name(steam.getFriendPersonaName(inviter)), code, "")

func invite_friend(steam_id: int) -> void:
	if not can_invite_friend() or not RiftSocial.can_whisper(steam_id):
		return
	pending_invite = steam_id
	if connected_room.is_empty():
		host_room("code")
	else:
		_send_pending_invite.call_deferred()

func _send_pending_invite() -> void:
	var recipient := pending_invite
	for attempt in 40:
		if pending_invite != recipient or connected_room.is_empty():
			return
		var lobby: int = relay._steam.steam_lobby_id
		if lobby != 0:
			var sent: bool = RiftSocial.steam.inviteUserToLobby(lobby, recipient)
			pending_invite = 0
			_update("Steam invitation sent." if sent else "Steam couldn't send the invite. You can share your room code.")
			return
		await get_tree().create_timer(0.25).timeout
	pending_invite = 0
	_update("Steam didn't open an invite lobby. You can share your room code.")

func valid_code(code: String) -> bool:
	if code.length() != CodeLength:
		return false
	for character in code:
		if not Codes.contains(character):
			return false
	return true

func _open(operation: String, code: String, password := "") -> void:
	if not available:
		_update(RELAY_UNAVAILABLE)
		return
	_initialize_client()
	room_code = code
	pending = operation
	pending_password = password
	_update("Connecting to the online relay…")
	request_timeout.start()
	if relay_ready:
		_request_room()
	else:
		ensure_relay()

func _request_room() -> void:
	if pending.is_empty():
		return
	if relay.account_is_logged_in() and not directory.username.is_empty():
		relay.player_set_username(directory.username)
	elif not relay.account_is_logged_in():
		relay.player_set_username("RX-%s" % Crypto.new().generate_random_bytes(6).hex_encode())
	match pending:
		"host":
			_update("Creating your room…")
			relay.lobby_create(_room_name(), pending_password, pending_access == "public", MAX_PLAYERS,
				{ACCESS_TAG: pending_access, "RiftcoreHost": local_name})
		"join":
			_update("Joining the party…")
			relay.lobby_join(_room_name(), pending_password)
		"rejoin_party":
			_update("Rejoining your party…")
			relay.lobby_join(_room_name(), pending_password)
		"rejoin_mission":
			_update("Rejoining your mission…")
			relay.lobby_join(_room_name(), recovery.password)
		"recreate_mission":
			relay.lobby_create(_room_name(), recovery.password, room_access == "public", MAX_PLAYERS,
				{ACCESS_TAG: room_access, "RiftcoreHost": local_name})

func _join_created_room(lobby_name: String) -> void:
	if pending == "host" and lobby_name == _room_name():
		relay.lobby_join(lobby_name, pending_password)
	elif pending == "recreate_mission" and lobby_name == _room_name():
		relay.lobby_join(lobby_name, recovery.password)

func _room_joined(lobby_name: String) -> void:
	if pending.is_empty() or lobby_name != _room_name():
		return
	request_timeout.stop()
	relay.expose_func(_receive_deploy, RelayEnums.EXPOSE_PERMISSION.HOST)
	relay.expose_func(_receive_countdown, RelayEnums.EXPOSE_PERMISSION.HOST)
	relay.expose_func(_receive_return, RelayEnums.EXPOSE_PERMISSION.HOST)
	relay.expose_func(_receive_abandon)
	recovery.expose()
	relay.expose_func(_receive_partner_position)
	relay.expose_func(_receive_sector_records)
	relay.expose_func(_receive_party_whisper)
	relay.expose_func(_receive_party_message)
	relay.expose_func(voice.receive_voice)
	relay.expose_func(_request_blueprint_drop)
	relay.expose_func(_request_blueprint_pickup)
	relay.expose_func(_receive_blueprint_drop, RelayEnums.EXPOSE_PERMISSION.HOST)
	relay.expose_func(_deliver_blueprint, RelayEnums.EXPOSE_PERMISSION.HOST)
	var joined_as_guest := pending in ["join", "rejoin_party"]
	var rejoining := is_rejoining_mission()
	connected_room = room_code
	directory.clear_friends_party_request()
	if not rejoining:
		room_access = pending_access if pending == "host" else String(relay.lobby_get_tag(ACCESS_TAG, "public"))
		room_password = pending_password
	previous_room = ""
	previous_room_password = ""
	pending_access = ""
	pending_password = ""
	pending = ""
	voice.publish_preference()
	relay.player_set_data("operator_name", local_name)
	relay.player_set_data("armor_finish", local_armor_finish)
	relay.player_set_data("operator_frame", local_operator_frame)
	_publish_difficulty_unlocks()
	if joined_as_guest:
		guest_joined.emit.call_deferred()
	_players_changed(0)
	if rejoining:
		recovery.retry_at = 0
		recovery.changed.emit()
		return
	if copy_on_join:
		copy_on_join = false
		copy_invite_code()
	if pending_invite != 0:
		_send_pending_invite.call_deferred()
	if not directory_invite.is_empty():
		_send_directory_invite.call_deferred()

func _room_failed(lobby_name: String, error: int) -> void:
	if pending.is_empty() or lobby_name != _room_name():
		return
	if is_rejoining_mission():
		if pending == "rejoin_mission" and recovery.slot == 0 and error == RelayEnums.LOBBY_JOIN_ERROR.LOBBY_DOES_NOT_EXIST:
			pending = "recreate_mission"
			_request_room()
		else:
			rejoin_attempt_failed("The mission room is still unavailable. Retrying…")
		return
	var message := "Could not create a room. Try again." if pending == "host" else "Could not join this room. Check the code and make sure both players are on the same game version."
	if error == RelayEnums.LOBBY_JOIN_ERROR.INCORRECT_PASSWORD and pending != "host":
		message = "This party requires a friend connection or a current invite."
	leave("%s (GD Sync code %d)" % [message, error], false)

func _connection_failed(error: int) -> void:
	relay_starting = false
	relay_ready = false
	if browsing_rooms:
		_finish_browse("Could not reach the lobby browser. Try Refresh.")
	if pending.is_empty():
		return
	if is_rejoining_mission():
		rejoin_attempt_failed("Could not reach the relay. Retrying…")
		return
	if error == RelayEnums.CONNECTION_FAILED.INVALID_PUBLIC_KEY:
		leave("GD Sync rejected the relay configuration. Check the RIFTCORE playtest keys.", false)
	else:
		leave("Could not reach the online relay. Try again.", false)

func rejoin_attempt_failed(message: String) -> void:
	request_timeout.stop()
	pending = ""
	room_code = ""
	relay._session_controller.lobby_left()
	_update(message)
	recovery.attempt_failed()

func _disconnected() -> void:
	relay_starting = false
	relay_ready = false
	if quitting:
		return
	if mission_active and not recovery.mission_id.is_empty():
		pending = ""
		connected_room = ""
		room_code = ""
		room_size = 0
		voice.reset()
		request_timeout.stop()
		relay._session_controller.lobby_left()
		relay._request_processor.clear_for_server_switch()
		_update("Relay connection lost. Your mission is paused.")
		recovery.transport_lost()
		return
	if not pending.is_empty() or not connected_room.is_empty():
		if not connected_room.is_empty():
			previous_room = connected_room
			previous_room_password = room_password
		relay._session_controller.lobby_left()
		relay._request_processor.clear_for_server_switch()
		leave("Lost the connection to the online relay.", false)
		if can_rejoin_party():
			party_rejoin_offered.emit()

func _players_changed(_client_id: int) -> void:
	if connected_room.is_empty():
		return
	room_size = relay.lobby_get_player_count()
	relay._data_controller.schedule_friend_status()
	_update("%d / %d players connected" % [room_size, MAX_PLAYERS])
	if room_size >= 2 and not mission_active:
		share_sector_records.call_deferred()
		if _client_id != 0 and relay.is_host():
			for key in blueprint_drops:
				var drop: Dictionary = blueprint_drops[key]
				relay.call_func_on(_client_id, _receive_blueprint_drop, key, drop.id, drop.owner, drop.x)

func share_sector_records() -> void:
	if room_size >= 2 and is_instance_valid(relay):
		relay.call_func(_receive_sector_records, RiftSocial.get_records(), local_name)

func _receive_sector_records(payload: Dictionary, alias: String) -> void:
	var sender: int = relay.get_sender_id()
	if room_size >= 2 and sender != relay.get_client_id() and relay.lobby_get_all_clients().has(sender):
		if connected_room.is_empty():
			return
		var new_player: bool = not RiftSocial.recent_players.has(String(payload.get("id", "")))
		RiftSocial.receive_records(payload, Profile.clean_operator_name(alias))
		var operator := String(payload.get("id", ""))
		if RiftSocial.recent_players.has(operator) and not party_operators.has(sender) and party_operators.find_key(operator) == null:
			party_operators[sender] = operator
			changed.emit()
		if new_player and RiftSocial.recent_players.has(String(payload.get("id", ""))):
			share_sector_records.call_deferred()

func whisper_to_operator(operator: String, body: String) -> bool:
	var id: Variant = party_operators.find_key(operator)
	if id == null or connected_room.is_empty() or not relay.lobby_get_all_clients().has(id):
		return false
	relay.call_func_on(id, _receive_party_whisper, body)
	return true

func _receive_party_whisper(body: String) -> void:
	var sender: int = relay.get_sender_id()
	if connected_room.is_empty() or not party_operators.has(sender) or not relay.lobby_get_all_clients().has(sender) or body.length() > RiftSocial.WHISPER_LIMIT:
		return
	var now := Time.get_ticks_msec()
	if now - last_party_whisper.get(sender, -1000) < 450:
		return
	var message := RiftSocial.clean_whisper(body)
	if message.is_empty():
		return
	last_party_whisper[sender] = now
	RiftSocial.receive_whisper("rift:" + party_operators[sender], message)

func send_party_message(raw: String) -> bool:
	var body := RiftSocial.clean_whisper(raw)
	if connected_room.is_empty() or room_size < 2 or not is_instance_valid(relay) or body.is_empty() or not allow_party_message(relay.get_client_id()):
		return false
	relay.call_func(_receive_party_message, body)
	append_party_message(local_name, body, true)
	return true

func _receive_party_message(raw: String) -> void:
	var sender: int = relay.get_sender_id()
	if connected_room.is_empty() or sender == relay.get_client_id() or not relay.lobby_get_all_clients().has(sender) or raw.length() > RiftSocial.WHISPER_LIMIT:
		return
	var body := RiftSocial.clean_whisper(raw)
	if body.is_empty() or not allow_party_message(sender):
		return
	var alias := Profile.clean_operator_name(str(relay.player_get_data(sender, "operator_name", "RX-07")))
	append_party_message(alias, body, false)

func allow_party_message(sender: int) -> bool:
	var now := Time.get_ticks_msec()
	var allowance := party_chat_allowance.get(sender, Vector2(now, PARTY_CHAT_BURST)) as Vector2
	var available_messages := minf(PARTY_CHAT_BURST, allowance.y + (now - allowance.x) / PARTY_CHAT_INTERVAL)
	if available_messages < 1.0:
		return false
	party_chat_allowance[sender] = Vector2(now, available_messages - 1.0)
	return true

func append_party_message(alias: String, body: String, outgoing: bool) -> void:
	party_messages.append({"name": alias, "body": body, "outgoing": outgoing})
	if party_messages.size() > 60:
		party_messages.pop_front()
	party_chat_changed.emit()

func can_deploy() -> bool:
	return not mission_active and not counting_down and room_size >= 2 and is_instance_valid(relay) and relay.is_host()

func set_difficulty_unlocks(sectors: Array, expert: bool) -> void:
	hard_sectors = sectors.duplicate()
	nightmare_unlocked = expert
	if not connected_room.is_empty() and is_instance_valid(relay):
		_publish_difficulty_unlocks()

func _publish_difficulty_unlocks() -> void:
	relay.player_set_data("hard_sectors", hard_sectors)
	relay.player_set_data("nightmare_unlocked", nightmare_unlocked)

func _difficulty_data_changed(client_id: int, key: String, _value: Variant) -> void:
	if not connected_room.is_empty() and not mission_active and client_id != relay.get_client_id() and key in ["hard_sectors", "nightmare_unlocked"]:
		changed.emit()

func can_play_difficulty(sector: int, mode: int) -> bool:
	match mode:
		Difficulty.NORMAL:
			return true
		Difficulty.HARD:
			return hard_sectors.has(sector)
		Difficulty.NIGHTMARE:
			return nightmare_unlocked
	return false

func party_can_play_difficulty(sector: int, mode: int) -> bool:
	if not can_play_difficulty(sector, mode) or not is_instance_valid(relay):
		return false
	for id in relay.lobby_get_all_clients():
		if id == relay.get_client_id():
			continue
		if mode == Difficulty.HARD:
			var sectors: Variant = relay.player_get_data(id, "hard_sectors", [])
			if not sectors is Array or not sectors.has(sector):
				return false
		if mode == Difficulty.NIGHTMARE and relay.player_get_data(id, "nightmare_unlocked", false) != true:
			return false
	return true

func deploy(sector := 1, mode := 0) -> void:
	if not can_deploy() or sector < 1 or sector > unlocked_sector:
		return
	if not party_can_play_difficulty(sector, mode):
		_update("Everyone in the party must clear this sector on Normal first." if mode == Difficulty.HARD else "Everyone in the party must clear all sectors on Hard first.")
		return
	mission_roster = relay.lobby_get_all_clients().duplicate()
	mission_roster.erase(relay.get_client_id())
	mission_roster.sort()
	mission_roster.push_front(relay.get_client_id())
	if mission_roster.size() < 2 or mission_roster.size() > MAX_PLAYERS:
		return
	var starting_room := connected_room
	var starting_roster := mission_roster.duplicate()
	counting_down = true
	for number in range(5, -1, -1):
		var members: Array = relay.lobby_get_all_clients()
		if starting_room != connected_room or not relay.is_host() or members.size() != starting_roster.size() or not starting_roster.all(func(id): return members.has(id)):
			counting_down = false
			deployment_countdown.emit(sector, -1)
			if starting_room == connected_room and relay.is_host():
				relay.call_func(_receive_countdown, sector, -1)
			mission_roster.clear()
			return
		relay.call_func(_receive_countdown, sector, number)
		deployment_countdown.emit(sector, number)
		await get_tree().create_timer(1.0 if number > 0 else 0.33).timeout
	counting_down = false
	var final_members: Array = relay.lobby_get_all_clients()
	if starting_room != connected_room or not relay.is_host() or final_members.size() != starting_roster.size() or not starting_roster.all(func(id): return final_members.has(id)):
		mission_roster.clear()
		deployment_countdown.emit(sector, -1)
		if starting_room == connected_room and relay.is_host():
			relay.call_func(_receive_countdown, sector, -1)
		return
	if not recovery.new_mission(mission_roster, sector, mode):
		mission_roster.clear()
		deployment_countdown.emit(sector, -1)
		relay.call_func(_receive_countdown, sector, -1)
		_update("Could not set up mission recovery. Try deploying again.")
		return
	_clear_blueprint_drops()
	mission_active = true
	mission_mode = mode
	deploy_requested.emit(true, sector)

func _receive_countdown(sector: int, number: int) -> void:
	if not mission_active and not connected_room.is_empty() and relay.get_sender_id() == relay.get_host() and number >= -1 and number <= 5:
		deployment_countdown.emit(sector, number)

func _receive_deploy(sector: int, roster: Array, mode: int, credentials: Dictionary) -> void:
	if connected_room.is_empty() or sector < 1 or sector > 10 or relay.get_sender_id() != relay.get_host():
		return
	if mission_active:
		if credentials.get("id") == recovery.mission_id:
			recovery.acknowledge_deploy()
		return
	if not can_play_difficulty(sector, mode):
		return
	if roster.size() < 2 or roster.size() > MAX_PLAYERS or roster[0] != relay.get_host() or not roster.has(relay.get_client_id()):
		return
	var members: Array = relay.lobby_get_all_clients()
	if roster.any(func(id): return not id is int or roster.count(id) != 1 or not members.has(id)):
		return
	if not recovery.accept_mission(roster, credentials):
		return
	relay._session_controller.lobby_password = recovery.password
	relay._data_controller.schedule_friend_status()
	mission_roster = roster.duplicate()
	mission_mode = mode
	_clear_blueprint_drops()
	mission_active = true
	recovery.acknowledge_deploy()
	deploy_requested.emit(false, sector)

func send_station_position(x: float, facing: float, animation: String) -> void:
	if room_size >= 2 and not mission_active and is_instance_valid(relay):
		station_positions[relay.get_client_id()] = x
		var now := Time.get_ticks_msec()
		var pose := Vector2(x, facing)
		if now - last_station_update_at < 500 and animation == last_station_animation and pose.is_equal_approx(last_station_pose):
			return
		last_station_update_at = now
		last_station_pose = pose
		last_station_animation = animation
		relay.call_func_unreliable(_receive_partner_position, x, facing, animation, local_name)

func _receive_partner_position(x: float, facing: float, animation: String, display_name: String) -> void:
	var sender: int = relay.get_sender_id()
	if mission_active or room_size < 2 or sender == relay.get_client_id() or not relay.lobby_get_all_clients().has(sender):
		return
	if is_finite(x) and is_finite(facing) and animation in ["idle", "walk", "run"]:
		station_positions[sender] = clampf(x, -19.15, 19.15)
		partner_moved.emit(sender, clampf(x, -19.15, 19.15), clampf(facing, -1.57, 1.57), animation, Profile.clean_operator_name(display_name))

func return_to_station() -> void:
	if mission_active and not recovery.active() and relay.is_host():
		relay.call_func(_receive_return)
		_restore_party_access()
		_finish_return()

func _restore_party_access() -> void:
	relay.lobby_change_password(room_password)
	relay._session_controller.lobby_password = room_password
	relay.lobby_open()

func _receive_return() -> void:
	if mission_active and relay.get_sender_id() == relay.get_host():
		relay._session_controller.lobby_password = room_password
		_finish_return()

func _finish_return() -> void:
	mission_active = false
	mission_roster.clear()
	recovery.clear()
	recovery.changed.emit()
	_players_changed(0)
	mission_returned.emit()

func _peer_left(client_id: int) -> void:
	voice.remove_speaker(client_id)
	station_positions.erase(client_id)
	var operator := party_operators.get(client_id, "") as String
	party_operators.erase(client_id)
	if not operator.is_empty():
		RiftSocial.clear_whisper("rift:" + operator)
	last_party_whisper.erase(client_id)
	party_chat_allowance.erase(client_id)
	if relay.is_host() and not mission_active:
		for key in blueprint_drops.keys():
			if blueprint_drops[key].owner == client_id:
				_publish_blueprint_drop(key, "", client_id, 0.0)
	if mission_active and mission_roster.has(client_id):
		recovery.begin()
	_players_changed(client_id)

func _host_changed(is_host: bool, _host_id: int) -> void:
	if not is_host or connected_room.is_empty():
		return
	if mission_active:
		if recovery.slot == 0:
			return
		recovery.begin()
		# When the relay promotes a guest, keep the original room open to the reserved seats.
		relay.lobby_change_password(recovery.password)
	else:
		relay.lobby_set_tag("RiftcoreHost", local_name)
	relay.lobby_open()
	relay._data_controller.schedule_friend_status()
	changed.emit()

func _receive_abandon() -> void:
	if mission_active and mission_roster.has(relay.get_sender_id()):
		if relay.is_host() and not connected_room.is_empty():
			_restore_party_access()
		_finish_return()

func leave(message := "Create a room or enter a friend’s room code.", deliberate := true) -> void:
	directory.clear_friends_party_request()
	voice.reset()
	_clear_blueprint_drops()
	var was_in_mission := mission_active
	if deliberate:
		previous_room = ""
		previous_room_password = ""
		if was_in_mission and not connected_room.is_empty() and relay.is_active():
			relay.call_func(_receive_abandon)
			if relay.is_host():
				_restore_party_access()
	recovery.clear()
	recovery.changed.emit()
	mission_active = false
	mission_roster.clear()
	var was_joined := not connected_room.is_empty()
	var disconnect := not pending.is_empty() or was_joined
	pending = ""
	connected_room = ""
	pending_access = ""
	pending_password = ""
	room_access = "public"
	room_password = ""
	pending_invite = 0
	directory_invite = ""
	copy_on_join = false
	party_operators.clear()
	last_party_whisper.clear()
	party_chat_allowance.clear()
	RiftSocial.clear_whispers("rift:")
	party_messages.clear()
	party_chat_changed.emit()
	room_code = ""
	room_size = 0
	request_timeout.stop()
	if disconnect and is_instance_valid(relay):
		if was_joined and relay.is_active():
			relay.lobby_leave()
		if not directory.online() or not was_joined:
			relay.stop_multiplayer()
			relay_starting = false
			relay_ready = false
	_update(message if available else RELAY_UNAVAILABLE)
	if was_in_mission:
		mission_disconnected.emit(message)

func _room_name() -> String:
	return ROOM_PREFIX + room_code

func _update(message: String) -> void:
	status = message
	changed.emit()

func can_share_blueprints() -> bool:
	return not connected_room.is_empty() and room_size >= 2 and not mission_active and is_instance_valid(relay)

func drop_blueprint(id: String, x: float) -> bool:
	if not can_share_blueprints() or not Profile.GEAR.has(id):
		return false
	if relay.is_host():
		_create_blueprint_drop(relay.get_client_id(), id, x)
	else:
		relay.call_func_on(relay.get_host(), _request_blueprint_drop, id, x)
	return true

func _request_blueprint_drop(id: String, x: float) -> void:
	_create_blueprint_drop(relay.get_sender_id(), id, x)

func _create_blueprint_drop(owner: int, id: String, x: float) -> void:
	if not can_share_blueprints() or not relay.is_host() or (owner != relay.get_client_id() and not relay.lobby_get_all_clients().has(owner)):
		return
	if not Profile.GEAR.has(id) or not is_finite(x):
		return
	var deck_x := clampf(x, -19.15, 19.15)
	if absf(deck_x - float(station_positions.get(owner, deck_x))) > 2.5:
		deck_x = float(station_positions[owner])
	drop_serial += 1
	_publish_blueprint_drop(str(drop_serial), id, owner, deck_x)

func _publish_blueprint_drop(key: String, id: String, owner: int, x: float) -> void:
	_apply_blueprint_drop(key, id, owner, x)
	relay.call_func(_receive_blueprint_drop, key, id, owner, x)

func _receive_blueprint_drop(key: String, id: String, owner: int, x: float) -> void:
	if relay.get_sender_id() == relay.get_host() and not mission_active and not connected_room.is_empty():
		_apply_blueprint_drop(key, id, owner, x)

func _apply_blueprint_drop(key: String, id: String, owner: int, x: float) -> void:
	if id.is_empty():
		blueprint_drops.erase(key)
	elif Profile.GEAR.has(id):
		blueprint_drops[key] = {"id": id, "owner": owner, "x": x}
	blueprint_drop_changed.emit(key, id, owner, x)

func pick_up_blueprint(key: String) -> void:
	if not can_share_blueprints():
		return
	if relay.is_host():
		_grant_blueprint_drop(key, relay.get_client_id())
	else:
		relay.call_func_on(relay.get_host(), _request_blueprint_pickup, key)

func _request_blueprint_pickup(key: String) -> void:
	_grant_blueprint_drop(key, relay.get_sender_id())

func _grant_blueprint_drop(key: String, receiver: int) -> void:
	if not can_share_blueprints() or not relay.is_host() or (receiver != relay.get_client_id() and not relay.lobby_get_all_clients().has(receiver)):
		return
	var drop: Dictionary = blueprint_drops.get(key, {})
	if drop.is_empty() or receiver == drop.owner or not station_positions.has(receiver):
		return
	if absf(float(station_positions[receiver]) - float(drop.x)) > 1.6:
		return
	_publish_blueprint_drop(key, "", drop.owner, 0.0)
	if receiver == relay.get_client_id():
		blueprint_received.emit(drop.id)
	else:
		relay.call_func_on(receiver, _deliver_blueprint, drop.id)

func _deliver_blueprint(id: String) -> void:
	if relay.get_sender_id() == relay.get_host() and can_share_blueprints():
		blueprint_received.emit(id)

func _clear_blueprint_drops() -> void:
	for key in blueprint_drops:
		blueprint_drop_changed.emit(key, "", 0, 0.0)
	blueprint_drops.clear()
	station_positions.clear()
