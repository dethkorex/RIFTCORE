extends Node

signal changed

const Keys := preload("res://addons/GD-Sync/Scripts/KeyStore.gd")
const Client := preload("res://addons/GD-Sync/MultiplayerClient.gd")
const Codes := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CodeLength := 10

var status := "Create a room or enter a friend’s room code."
var connected_room := ""
var pending := ""
var room_code := ""
var room_size := 0

var relay: Node
var request_timeout: Timer

func _ready() -> void:
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
	if RiftSocial.ready_to_query and Keys.has_keys():
		_initialize_client()

func invite_friend(steam_id: int) -> void:
	if connected_room.is_empty() or not RiftSocial.ready_to_query:
		return
	if room_size >= 2:
		_update("Your room is full.")
		return
	var lobby: int = relay._steam.steam_lobby_id
	if lobby == 0:
		_update("Steam invite is unavailable. You can share your room code.")
		return
	var sent: bool = RiftSocial.steam.inviteUserToLobby(lobby, steam_id)
	_update("Steam invitation sent." if sent else "Steam couldn't send the invite. You can share your room code.")

func valid_code(code: String) -> bool:
	if code.length() != CodeLength:
		return false
	for character in code:
		if not Codes.contains(character):
			return false
	return true

func _open(operation: String, code: String) -> void:
	if not Keys.has_keys():
		_update("Online rooms are unavailable in this build.")
		return
	_initialize_client()
	room_code = code
	pending = operation
	_update("Connecting to the online relay…")
	request_timeout.start()
	relay.start_multiplayer()

func _request_room() -> void:
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

func _room_failed(lobby_name: String, _error: int) -> void:
	if pending.is_empty() or lobby_name != _room_name():
		return
	var message := "Could not create a room. Try again." if pending == "host" else "Could not join this room. Check the code and ask your friend to keep the room open."
	leave(message)

func _connection_failed(_error: int) -> void:
	if not pending.is_empty():
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
	room_code = ""
	room_size = 0
	request_timeout.stop()
	if disconnect and is_instance_valid(relay):
		if was_joined and relay.is_active():
			relay.lobby_leave()
		relay.stop_multiplayer()
	_update(message)

func _room_name() -> String:
	return "riftcore-v05-" + room_code

func _update(message: String) -> void:
	status = message
	changed.emit()
