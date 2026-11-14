extends Node

signal changed

const Keys := preload("res://addons/GD-Sync/Scripts/KeyStore.gd")
const Client := preload("res://addons/GD-Sync/MultiplayerClient.gd")
const RelayEnums := preload("res://addons/GD-Sync/Scripts/Enums/Enums.gd")
const Codes := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CodeLength := 10
const RELAY_UNAVAILABLE := "Online rooms are unavailable. Solo play is available."

var status := "Create a room or enter a friend’s room code."
var connected_room := ""
var pending := ""
var room_code := ""
var room_size := 0
var available := false
var pending_invite := 0

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
		if not has_password and lobby_name.begins_with("riftcore-v05-"):
			join_room(lobby_name.trim_prefix("riftcore-v05-"))
	)
	relay.client_joined.connect(_players_changed)
	relay.client_left.connect(_players_changed)
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

func invite_friend(steam_id: int) -> void:
	if not available or not RiftSocial.ready_to_query or not RiftSocial.steam.loggedOn():
		return
	if room_size >= 2 or pending_invite != 0 or not pending.is_empty():
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
			relay.lobby_create(_room_name(), "", false, 2)
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
	connected_room = room_code
	pending = ""
	_players_changed(0)
	if pending_invite != 0:
		_send_pending_invite.call_deferred()

func _room_failed(lobby_name: String, error: int) -> void:
	if pending.is_empty() or lobby_name != _room_name():
		return
	var message := "Could not create a room. Try again." if pending == "host" else "Could not join this room. Check the code and ask your friend to keep the room open."
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
	_update("%d / 2 players connected" % room_size)

func leave(message := "Create a room or enter a friend’s room code.") -> void:
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

func _room_name() -> String:
	return "riftcore-v05-" + room_code

func _update(message: String) -> void:
	status = message
	changed.emit()
