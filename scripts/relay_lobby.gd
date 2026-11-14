extends Node

signal changed
signal deploy_requested(host: bool, sector: int)
signal partner_moved(id: int, x: float, facing: float, animation: String, display_name: String)
signal blueprint_drop_changed(key: String, id: String, owner: int, x: float)
signal blueprint_received(id: String)
signal guest_joined
signal mission_returned
signal mission_disconnected(message: String)
signal invite_received(display_name: String, code: String)

const Profile := preload("res://scripts/rogue_profile.gd")
const Keys := preload("res://addons/GD-Sync/Scripts/KeyStore.gd")
const Client := preload("res://addons/GD-Sync/MultiplayerClient.gd")
const RelayEnums := preload("res://addons/GD-Sync/Scripts/Enums/Enums.gd")
const Codes := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CodeLength := 10
const ROOM_PREFIX := "riftcore-coop-v10-"
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const MAX_PLAYERS := 4
const RELAY_UNAVAILABLE := "Online rooms are unavailable. Solo play is available."

var status := "Create a room or enter a friend’s room code."
var connected_room := ""
var pending := ""
var room_code := ""
var room_size := 0
var available := false
var pending_invite := 0
var mission_active := false
var mission_roster: Array = []
var mission_mode := 0
var nightmare_unlocked := false
var steam_invite_lobbies: Dictionary = {}
var local_name := "RX-07"
var unlocked_sector := 1

var blueprint_drops: Dictionary = {}
var station_positions: Dictionary = {}
var drop_serial := 0
var relay: Node
var request_timeout: Timer

func _ready() -> void:
	available = Keys.has_keys()
	if not available:
		status = RELAY_UNAVAILABLE
	request_timeout = Timer.new()
	request_timeout.one_shot = true
	request_timeout.wait_time = 30.0
	request_timeout.timeout.connect(func(): leave("The connection timed out. Try again."))
	add_child(request_timeout)

func _initialize_client() -> void:
	if is_instance_valid(relay):
		return
	relay = get_tree().root.get_node_or_null("GDSync")
	if relay == null:
		relay = Client.new()
		relay.name = "GDSync"
		get_tree().root.add_child(relay)
	relay.connected.connect(_request_room)
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
	relay.kicked.connect(func(_reason: String): leave("You were removed from the room."))

func host_room() -> void:
	if not pending.is_empty() or not connected_room.is_empty():
		return
	var code := ""
	for byte in Crypto.new().generate_random_bytes(CodeLength):
		code += Codes[byte % Codes.length()]
	_open("host", code)

func join_room(entered_code: String) -> void:
	if not pending.is_empty() or not connected_room.is_empty():
		return
	var code := entered_code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if not valid_code(code):
		_update("Enter the ten-character room code.")
		return
	_open("join", code)

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
		invite_received.emit(Profile.clean_operator_name(steam.getFriendPersonaName(inviter)), code)

func invite_friend(steam_id: int) -> void:
	if not available or not RiftSocial.ready_to_query or not RiftSocial.steam.loggedOn():
		return
	if room_size >= MAX_PLAYERS or mission_active or pending_invite != 0 or not pending.is_empty():
		return
	if not connected_room.is_empty() and not relay.is_host():
		_update("Only the party leader can send Steam invites.")
		return
	pending_invite = steam_id
	if connected_room.is_empty():
		host_room()
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

func _open(operation: String, code: String) -> void:
	if not available:
		_update(RELAY_UNAVAILABLE)
		return
	_initialize_client()
	room_code = code
	pending = operation
	_update("Connecting to the online relay…")
	request_timeout.start()
	relay.start_multiplayer()

func _request_room() -> void:
	relay.player_set_username("RX-%s" % Crypto.new().generate_random_bytes(6).hex_encode())
	match pending:
		"host":
			_update("Creating your room…")
			relay.lobby_create(_room_name(), "", false, MAX_PLAYERS)
		"join":
			_update("Joining your friend’s room…")
			relay.lobby_join(_room_name())

func _join_created_room(lobby_name: String) -> void:
	if pending == "host" and lobby_name == _room_name():
		relay.lobby_join(lobby_name)

func _room_joined(lobby_name: String) -> void:
	if pending.is_empty() or lobby_name != _room_name():
		return
	request_timeout.stop()
	relay.expose_func(_receive_deploy, RelayEnums.EXPOSE_PERMISSION.HOST)
	relay.expose_func(_receive_return, RelayEnums.EXPOSE_PERMISSION.HOST)
	relay.expose_func(_receive_partner_position)
	relay.expose_func(_receive_sector_records)
	relay.expose_func(_request_blueprint_drop)
	relay.expose_func(_request_blueprint_pickup)
	relay.expose_func(_receive_blueprint_drop, RelayEnums.EXPOSE_PERMISSION.HOST)
	relay.expose_func(_deliver_blueprint, RelayEnums.EXPOSE_PERMISSION.HOST)
	var joined_as_guest := pending == "join"
	connected_room = room_code
	pending = ""
	relay.player_set_data("operator_name", local_name)
	relay.player_set_data("nightmare_unlocked", nightmare_unlocked)
	if joined_as_guest:
		guest_joined.emit.call_deferred()
	_players_changed(0)
	if pending_invite != 0:
		_send_pending_invite.call_deferred()

func _room_failed(lobby_name: String, error: int) -> void:
	if pending.is_empty() or lobby_name != _room_name():
		return
	var message := "Could not create a room. Try again." if pending == "host" else "Could not join this room. Check the code and make sure both players are on the same game version."
	leave("%s (GD Sync code %d)" % [message, error])

func _connection_failed(error: int) -> void:
	if pending.is_empty():
		return
	if error == RelayEnums.CONNECTION_FAILED.INVALID_PUBLIC_KEY:
		leave("GD Sync rejected the relay configuration. Check the RIFTCORE playtest keys.")
	else:
		leave("Could not reach the online relay. Try again.")

func _disconnected() -> void:
	if not pending.is_empty() or not connected_room.is_empty():
		leave("Lost the connection to the online relay.")

func _players_changed(_client_id: int) -> void:
	if connected_room.is_empty():
		return
	room_size = relay.lobby_get_player_count()
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
		if new_player and RiftSocial.recent_players.has(String(payload.get("id", ""))):
			share_sector_records.call_deferred()

func can_deploy() -> bool:
	return not mission_active and room_size >= 2 and is_instance_valid(relay) and relay.is_host()

func set_nightmare_unlocked(value: bool) -> void:
	nightmare_unlocked = value
	if not connected_room.is_empty() and is_instance_valid(relay):
		relay.player_set_data("nightmare_unlocked", value)

func party_can_play_nightmare() -> bool:
	if not nightmare_unlocked or not is_instance_valid(relay):
		return false
	for id in relay.lobby_get_all_clients():
		if id != relay.get_client_id() and not relay.player_get_data(id, "nightmare_unlocked", false):
			return false
	return true

func deploy(sector := 1, mode := 0) -> void:
	if not can_deploy() or sector < 1 or sector > unlocked_sector:
		return
	if mode == Difficulty.NIGHTMARE and not party_can_play_nightmare():
		_update("Everyone in the party must unlock Nightmare first.")
		return
	mission_roster = relay.lobby_get_all_clients().duplicate()
	mission_roster.erase(relay.get_client_id())
	mission_roster.sort()
	mission_roster.push_front(relay.get_client_id())
	if mission_roster.size() < 2 or mission_roster.size() > MAX_PLAYERS:
		return
	_clear_blueprint_drops()
	mission_active = true
	mission_mode = clampi(mode, 0, 2)
	relay.lobby_close()
	relay.call_func(_receive_deploy, sector, mission_roster, mission_mode)
	deploy_requested.emit(true, sector)

func _receive_deploy(sector: int, roster: Array, mode: int) -> void:
	if mission_active or connected_room.is_empty() or sector < 1 or sector > 10 or relay.get_sender_id() != relay.get_host():
		return
	if mode == Difficulty.NIGHTMARE and not nightmare_unlocked:
		return
	if roster.size() < 2 or roster.size() > MAX_PLAYERS or roster[0] != relay.get_host() or not roster.has(relay.get_client_id()):
		return
	var members: Array = relay.lobby_get_all_clients()
	if roster.any(func(id): return not id is int or roster.count(id) != 1 or not members.has(id)):
		return
	mission_roster = roster.duplicate()
	mission_mode = clampi(mode, 0, 2)
	_clear_blueprint_drops()
	mission_active = true
	deploy_requested.emit(false, sector)

func send_station_position(x: float, facing: float, animation: String) -> void:
	if room_size >= 2 and not mission_active and is_instance_valid(relay):
		station_positions[relay.get_client_id()] = x
		relay.call_func_unreliable(_receive_partner_position, x, facing, animation, local_name)

func _receive_partner_position(x: float, facing: float, animation: String, display_name: String) -> void:
	var sender: int = relay.get_sender_id()
	if mission_active or room_size < 2 or sender == relay.get_client_id() or not relay.lobby_get_all_clients().has(sender):
		return
	if is_finite(x) and is_finite(facing) and animation in ["idle", "walk", "run"]:
		station_positions[sender] = clampf(x, -19.15, 19.15)
		partner_moved.emit(sender, clampf(x, -19.15, 19.15), clampf(facing, -1.57, 1.57), animation, Profile.clean_operator_name(display_name))

func return_to_station() -> void:
	if mission_active and relay.is_host():
		relay.call_func(_receive_return)
		relay.lobby_open()
		_finish_return()

func _receive_return() -> void:
	if mission_active and relay.get_sender_id() == relay.get_host():
		_finish_return()

func _finish_return() -> void:
	mission_active = false
	mission_roster.clear()
	_players_changed(0)
	mission_returned.emit()

func _peer_left(client_id: int) -> void:
	station_positions.erase(client_id)
	if relay.is_host() and not mission_active:
		for key in blueprint_drops.keys():
			if blueprint_drops[key].owner == client_id:
				_publish_blueprint_drop(key, "", client_id, 0.0)
	if mission_active:
		leave("Your partner left the mission.")
	else:
		_players_changed(client_id)

func leave(message := "Create a room or enter a friend’s room code.") -> void:
	_clear_blueprint_drops()
	var was_in_mission := mission_active
	mission_active = false
	mission_roster.clear()
	var was_joined := not connected_room.is_empty()
	var disconnect := not pending.is_empty() or was_joined
	pending = ""
	connected_room = ""
	pending_invite = 0
	room_code = ""
	room_size = 0
	request_timeout.stop()
	if disconnect and is_instance_valid(relay):
		if was_joined and relay.is_active():
			relay.lobby_leave()
		relay.stop_multiplayer()
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
