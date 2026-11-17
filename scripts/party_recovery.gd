extends Node

signal changed
signal resumed(roster: Array)

const GRACE_MS := 90_000
const RETRY_MS := 2_000

var lobby
var room := ""
var password := ""
var mission_id := ""
var slot := -1
var ticket := ""
var ticket_hashes: Array = []
var founder_key: CryptoKey
var founder_client := -1
var candidate: Array = []
var roster_acks: Dictionary[int, int] = {}
var deadline := 0
var retry_at := 0
var retrying := false
var crypto := Crypto.new()

func new_mission(roster: Array, sector: int, mode: int) -> bool:
	var key := crypto.generate_rsa(2048)
	if not key:
		return false
	var tickets := PackedStringArray()
	var hashes := []
	for _id in roster:
		var secret := crypto.generate_random_bytes(24).hex_encode()
		tickets.append(secret)
		hashes.append(secret.sha256_text())
	var id := crypto.generate_random_bytes(16).hex_encode()
	var join_password := crypto.generate_random_bytes(8).hex_encode()
	configure(roster, id, join_password, tickets[0], hashes, key)
	var relay = lobby.relay
	# The relay keeps the room joinable to existing operators via this private password.
	relay.lobby_change_password(password)
	relay._session_controller.lobby_password = password
	relay._data_controller.schedule_friend_status()
	var public_key := Marshalls.utf8_to_base64(key.save_to_string(true))
	for index in range(1, roster.size()):
		var credentials := {"id": id, "password": join_password, "ticket": tickets[index], "hashes": hashes, "founder": public_key}
		relay.call_func_on(roster[index], lobby._receive_deploy, sector, roster, mode, credentials)
	return true

func accept_mission(roster: Array, credentials: Dictionary) -> bool:
	var id := String(credentials.get("id", ""))
	var join_password := String(credentials.get("password", ""))
	var secret := String(credentials.get("ticket", ""))
	var public_key := String(credentials.get("founder", ""))
	var hashes: Variant = credentials.get("hashes", [])
	if not hashes is Array:
		return false
	if id.length() != 32 or join_password.length() != 16 or secret.length() != 48 or public_key.length() > 1024 or hashes.size() != roster.size():
		return false
	var index := roster.find(lobby.relay.get_client_id())
	if index <= 0 or hashes[index] != secret.sha256_text():
		return false
	var key := CryptoKey.new()
	if key.load_from_string(Marshalls.base64_to_utf8(public_key), true) != OK:
		return false
	configure(roster, id, join_password, secret, hashes, key)
	return true

func configure(roster: Array, id: String, join_password: String, secret: String, hashes: Array, key: CryptoKey) -> void:
	clear()
	room = lobby.connected_room
	mission_id = id
	password = join_password
	ticket = secret
	ticket_hashes = hashes
	slot = roster.find(lobby.relay.get_client_id())
	candidate = roster.duplicate()
	founder_key = key
	founder_client = candidate[0]

func expose() -> void:
	var relay = lobby.relay
	relay.expose_func(claim_seat)
	relay.expose_func(founder_ready)
	relay.expose_func(check_roster)
	relay.expose_func(acknowledge_roster)
	relay.expose_func(restore_roster)

func active() -> bool:
	return deadline != 0

func begin() -> void:
	if mission_id.is_empty() or active():
		return
	deadline = Time.get_ticks_msec() + GRACE_MS
	retry_at = 0
	roster_acks.clear()
	changed.emit()

func start_rejoin() -> void:
	if active() and lobby.connected_room.is_empty():
		retrying = true
		retry_at = 0
		changed.emit()

func transport_lost() -> void:
	retrying = false
	begin()
	changed.emit()

func attempt_failed() -> void:
	retry_at = Time.get_ticks_msec() + RETRY_MS
	changed.emit()

func remaining_seconds() -> int:
	return maxi(0, ceili(float(deadline - Time.get_ticks_msec()) / 1000.0))

func _process(_delta: float) -> void:
	if not active() or lobby.quitting:
		return
	var now := Time.get_ticks_msec()
	if now >= deadline:
		lobby.leave("Rejoin time expired. The party returned to the station.")
		return
	if now < retry_at:
		return
	retry_at = now + RETRY_MS
	if lobby.connected_room.is_empty():
		if retrying and lobby.pending.is_empty():
			lobby._open("rejoin_mission", room)
		return
	var relay = lobby.relay
	var own: int = relay.get_client_id()
	var host_id: int = relay.get_host()
	if host_id < 0:
		return
	if slot == 0 and own == host_id:
		var proof := sign_founder(own)
		if candidate[0] != own:
			roster_acks.clear()
		candidate[0] = own
		founder_client = own
		relay.call_func(founder_ready, mission_id, proof)
		var members: Array = relay.lobby_get_all_clients()
		if candidate.all(func(id): return members.has(id)):
			var guests := candidate.slice(1)
			if guests.all(func(id): return roster_acks.get(id, 0) == 2):
				finish(candidate)
				return
			for id in guests:
				match roster_acks.get(id, 0):
					0: relay.call_func_on(id, check_roster, mission_id, candidate, proof)
					1: relay.call_func_on(id, restore_roster, mission_id, candidate, proof)
	elif slot == 0:
		relay.call_func_on(host_id, claim_seat, mission_id, slot, "", sign_founder(own))
	elif host_id == founder_client:
		relay.call_func_on(host_id, claim_seat, mission_id, slot, ticket, "")

func founder_digest(client: int) -> PackedByteArray:
	return ("RIFTCORE party founder %s %d" % [mission_id, client]).sha256_buffer()

func sign_founder(client: int) -> String:
	return Marshalls.raw_to_base64(crypto.sign(HashingContext.HASH_SHA256, founder_digest(client), founder_key))

func verify_founder(client: int, proof: String) -> bool:
	return proof.length() == 344 and crypto.verify(HashingContext.HASH_SHA256, founder_digest(client), Marshalls.base64_to_raw(proof), founder_key)

func claim_seat(id: String, index: int, secret: String, proof: String) -> void:
	if not active() or mission_id != id or not lobby.relay.is_host() or index < 0 or index >= candidate.size():
		return
	var relay = lobby.relay
	var sender: int = relay.get_sender_id()
	var members: Array = relay.lobby_get_all_clients()
	if not members.has(sender) or sender == relay.get_client_id():
		return
	if index == 0:
		if slot != 0 and not members.has(candidate[0]) and verify_founder(sender, proof):
			relay.set_host(sender)
		return
	if slot != 0 or secret.length() != 48 or secret.sha256_text() != ticket_hashes[index]:
		return
	if (members.has(candidate[index]) and candidate[index] != sender) or (candidate.has(sender) and candidate[index] != sender):
		return
	if candidate[index] != sender:
		candidate[index] = sender
		roster_acks.clear()
		retry_at = 0

func founder_ready(id: String, proof: String) -> void:
	if not active() or mission_id != id:
		return
	var sender: int = lobby.relay.get_sender_id()
	if sender == lobby.relay.get_host() and verify_founder(sender, proof) and founder_client != sender:
		founder_client = sender
		retry_at = 0

func matches_roster(id: String, roster: Array, proof: String) -> bool:
	if slot <= 0 or mission_id != id or roster.size() != candidate.size():
		return false
	var relay = lobby.relay
	var sender: int = relay.get_sender_id()
	if sender != relay.get_host() or roster[0] != sender or roster[slot] != relay.get_client_id() or not verify_founder(sender, proof):
		return false
	return not roster.any(func(client): return not client is int or roster.count(client) != 1)

func check_roster(id: String, roster: Array, proof: String) -> void:
	if active() and matches_roster(id, roster, proof):
		lobby.relay.call_func_on(roster[0], acknowledge_roster, id, roster, false)

func acknowledge_roster(id: String, roster: Array, confirmed: bool) -> void:
	if not active() or slot != 0 or mission_id != id or roster != candidate or not lobby.relay.is_host():
		return
	var sender: int = lobby.relay.get_sender_id()
	if candidate.find(sender) > 0:
		roster_acks[sender] = maxi(roster_acks.get(sender, 0), 2 if confirmed else 1)
		retry_at = 0

func restore_roster(id: String, roster: Array, proof: String) -> void:
	if not matches_roster(id, roster, proof) or (not active() and roster != candidate):
		return
	lobby.relay.call_func_on(roster[0], acknowledge_roster, id, roster, true)
	if active():
		founder_client = roster[0]
		finish(roster)

func finish(roster: Array) -> void:
	candidate = roster.duplicate()
	deadline = 0
	retrying = false
	resumed.emit(candidate.duplicate())
	changed.emit()

func clear() -> void:
	room = ""
	mission_id = ""
	password = ""
	ticket = ""
	ticket_hashes = []
	roster_acks.clear()
	founder_key = null
	founder_client = -1
	slot = -1
	candidate.clear()
	deadline = 0
	retrying = false
	retry_at = 0
