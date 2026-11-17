extends Node

signal failed(recipient: String)

const ENDPOINT := "riftcore_whisper_endpoint"
const LIVE_ROOT := "riftcore_live_whispers"
const MESSAGE_TTL := 40
const READ_INTERVAL := 2.5
const CHUNK_BYTES := 200

var directory
var crypto := Crypto.new()
var key: CryptoKey
var session_owner := ""
var session := ""
var preparing := false
var running := false
var elapsed := 0.0
var cursor := 0
var pending: Dictionary = {}
var writing: Dictionary = {}
var delivered: Dictionary = {}
var receipt_expiry: Dictionary[String, int] = {}

func _process(delta: float) -> void:
	if not directory.online() or directory.lobby.quitting:
		reset_session()
		return
	if directory.busy:
		return
	if session_owner != directory.username:
		reset_session()
		session_owner = directory.username
	elapsed += delta
	if preparing or running or elapsed < READ_INTERVAL:
		return
	elapsed = 0.0
	if not key:
		setup()
	else:
		poll()

func reset_session() -> void:
	if session_owner.is_empty():
		return
	session_owner = ""
	session = ""
	key = null
	cursor = 0
	pending.clear()
	writing.clear()
	delivered.clear()
	receipt_expiry.clear()
	RiftSocial.clear_whispers("account:")

func shutdown() -> void:
	var had_session := not session_owner.is_empty()
	reset_session()
	if had_session and directory.online():
		var relay = directory.lobby.relay
		relay.account_delete_document(ENDPOINT)
		await relay.account_delete_document(LIVE_ROOT)

func is_current(token: String) -> bool:
	return not token.is_empty() and session == token and session_owner == directory.username and directory.online() and not directory.lobby.quitting

func setup() -> void:
	preparing = true
	session = crypto.generate_random_bytes(16).hex_encode()
	var token := session
	var relay = directory.lobby.relay
	# Clear abandoned packets before making the new session discoverable.
	var cleared: int = await relay.account_delete_document(LIVE_ROOT)
	if is_current(token) and cleared in [0, directory.Codes.ACCOUNT_DELETE_DOCUMENT_RESPONSE_CODE.DOESNT_EXIST]:
		var candidate := crypto.generate_rsa(2048)
		if candidate and await relay.account_document_set(ENDPOINT, {"session": token, "pem": candidate.save_to_string(true)}, true) == 0 and is_current(token):
			key = candidate
			remove_legacy_history(token)
	preparing = false

func remove_legacy_history(token: String) -> void:
	var relay = directory.lobby.relay
	var reply: Dictionary = await relay.account_browse_collection("")
	var entries: Variant = reply.get("Result")
	if not entries is Array:
		return
	for entry in entries:
		if not is_current(token):
			return
		if not entry is Dictionary:
			continue
		var path := String(entry.get("Path", "")).trim_prefix("root/")
		var suffix := path.trim_prefix("riftcore_whisper_v1_")
		if path in ["riftcore_whisper_key_v1", "riftcore_whisper_private_v1"] or (path.begins_with("riftcore_whisper_v1_") and suffix.length() == 32 and suffix.is_valid_hex_number()):
			await relay.account_delete_document(path)

func document(response: Dictionary) -> Dictionary:
	var result: Variant = response.get("Result")
	return result if int(response.get("Code", 1)) == 0 and result is Dictionary else {}

func address(name: String, kind: String) -> String:
	return LIVE_ROOT + "/" + kind + "_" + name.to_lower().sha256_text().left(32)

func can_send(name: String) -> bool:
	return directory.online() and not directory.lobby.quitting and directory.friends.any(func(friend):
		return String(friend.get("Username", "")).nocasecmp_to(name) == 0 and directory.is_friend_online(friend))

func queue(name: String, body: String) -> bool:
	if not key or not can_send(name) or pending.has(name) or writing.has(name):
		return false
	writing[name] = true
	send(name, body, session)
	return true

func send(name: String, body: String, token: String) -> void:
	var relay = directory.lobby.relay
	var response: Dictionary = await relay.account_get_external_document(name, ENDPOINT)
	if int(response.get("Code", 1)) in [1, 3] and is_current(token) and can_send(name):
		await get_tree().create_timer(1.0).timeout
		if is_current(token) and can_send(name):
			response = await relay.account_get_external_document(name, ENDPOINT)
	var endpoint := document(response)
	var destination := String(endpoint.get("session", ""))
	var pem := String(endpoint.get("pem", ""))
	var recipient := CryptoKey.new()
	if is_current(token) and can_send(name) and destination.length() == 32 and pem.length() <= 1024 and recipient.load_from_string(pem, true) == OK:
		var chunks := encode(recipient, body)
		if not chunks.is_empty():
			var id := crypto.generate_random_bytes(12).hex_encode()
			var expires := int(Time.get_unix_time_from_system()) + MESSAGE_TTL
			var packet := {"id": id, "to": destination, "expires": expires, "parts": chunks}
			var result: int = await relay.account_document_set(address(name, "message"), packet, true)
			if result in [1, 3] and is_current(token) and can_send(name):
				await get_tree().create_timer(1.0).timeout
				if is_current(token) and can_send(name):
					result = await relay.account_document_set(address(name, "message"), packet, true)
			if is_current(token) and result == 0:
				pending[name] = {"id": id, "body": body, "expires": expires, "to": destination}
				writing.erase(name)
				return
			if result == 0 and directory.online() and session_owner.is_empty():
				relay.account_delete_document(address(name, "message"))
	if is_current(token):
		writing.erase(name)
		failed.emit(name)

func poll() -> void:
	running = true
	var token := session
	var friends: Array = directory.friends.filter(func(friend): return directory.is_friend_online(friend))
	for i in mini(2, friends.size()):
		if not is_current(token):
			break
		var friend: String = friends[cursor % friends.size()].Username
		cursor = (cursor + 1) % friends.size()
		await receive(friend, token)
	for name: String in pending.keys():
		if not is_current(token):
			break
		await check_delivery(name, token)
	for name: String in receipt_expiry.keys():
		if not is_current(token):
			break
		if receipt_expiry[name] <= int(Time.get_unix_time_from_system()):
			var result: int = await directory.lobby.relay.account_delete_document(address(name, "receipt"))
			if is_current(token) and deleted(result):
				receipt_expiry.erase(name)
	running = false

func receive(name: String, token: String) -> void:
	var relay = directory.lobby.relay
	var packet := document(await relay.account_get_external_document(name, address(session_owner, "message")))
	var id := String(packet.get("id", ""))
	var expires := int(packet.get("expires", 0))
	var now := int(Time.get_unix_time_from_system())
	if not is_current(token) or not can_send(name) or packet.get("to") != token or expires < now or expires > now + MESSAGE_TTL + 4 or id.length() != 24 or delivered.get(name) == id:
		return
	var body := decode(packet.get("parts", []))
	if body.is_empty():
		return
	var result: int = await relay.account_document_set(address(name, "receipt"), {"id": id, "session": token}, true)
	if result == 0 and is_current(token):
		delivered[name] = id
		receipt_expiry[name] = expires + 4
		RiftSocial.receive_whisper("account:" + name, body)

func check_delivery(name: String, token: String) -> void:
	var item: Dictionary = pending[name]
	var relay = directory.lobby.relay
	if not item.get("confirmed", false):
		var receipt := document(await relay.account_get_external_document(name, address(session_owner, "receipt")))
		if not is_current(token):
			return
		item.confirmed = receipt.get("id") == item.id and receipt.get("session") == item.to
		if not item.confirmed and can_send(name) and int(Time.get_unix_time_from_system()) < item.expires:
			return
	# Keep the slot occupied until deletion completes so it cannot erase a newer send.
	var result: int = await relay.account_delete_document(address(name, "message"))
	if not is_current(token) or not deleted(result):
		return
	pending.erase(name)
	if item.confirmed:
		RiftSocial.add_whisper("account:" + name, item.body, true)
	else:
		failed.emit(name)

func deleted(result: int) -> bool:
	return result in [0, directory.Codes.ACCOUNT_DELETE_DOCUMENT_RESPONSE_CODE.DOESNT_EXIST]

func encode(recipient: CryptoKey, body: String) -> Array[String]:
	var bytes := body.to_utf8_buffer()
	var chunks: Array[String] = []
	for start in range(0, bytes.size(), CHUNK_BYTES):
		var encrypted := crypto.encrypt(recipient, bytes.slice(start, start + CHUNK_BYTES))
		if encrypted.size() != 256:
			return []
		chunks.append(Marshalls.raw_to_base64(encrypted))
	return chunks

func decode(parts: Variant) -> String:
	if not parts is Array or parts.is_empty() or parts.size() > ceili(float(RiftSocial.WHISPER_LIMIT * 4) / CHUNK_BYTES):
		return ""
	var plain := PackedByteArray()
	for part in parts:
		if not part is String or part.length() != 344:
			return ""
		var block := crypto.decrypt(key, Marshalls.base64_to_raw(part))
		if block.is_empty():
			return ""
		plain.append_array(block)
	return RiftSocial.clean_whisper(plain.get_string_from_utf8())
