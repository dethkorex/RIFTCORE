extends Node

signal failed(recipient: String)

const ENDPOINT := "riftcore_whisper_endpoint"
const LIVE_ROOT := "riftcore_live_whispers"
const MESSAGE_TTL := 40
const CLOCK_SKEW := 30
const QUEUE_TTL_MS := 90_000
const MAX_QUEUED := 5
const READ_INTERVAL := 2.5
const ENDPOINT_REFRESH := 18_000
const PACKET_RETRY := 10_000
const CHUNK_BYTES := 200

var directory
var crypto := Crypto.new()
var key: CryptoKey
var key_thread := Thread.new()
var session_owner := ""
var session := ""
var preparing := false
var reading := false
var sending := false
var elapsed := 0.0
var announce_at := 0
var cursor := 0
var offline_cursor := 0
var offline_elapsed := 0.0
var outbox: Dictionary[String, Array] = {}
var delivered: Dictionary = {}
var receipts: Dictionary[String, Dictionary] = {}

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
	offline_elapsed += delta
	if elapsed < READ_INTERVAL:
		return
	elapsed = 0.0
	if not key:
		if not preparing:
			setup()
	else:
		if not preparing and Time.get_ticks_msec() >= announce_at:
			announce_endpoint(key, session)
		if not reading:
			poll_inbox()
		if not sending and not outbox.is_empty():
			poll_outbox()

func reset_session() -> void:
	if session_owner.is_empty():
		return
	session_owner = ""
	session = ""
	key = null
	announce_at = 0
	cursor = 0
	offline_cursor = 0
	offline_elapsed = 0.0
	outbox.clear()
	delivered.clear()
	receipts.clear()
	RiftSocial.clear_whispers("account:")

func shutdown() -> void:
	var had_session := not session_owner.is_empty()
	reset_session()
	if had_session:
		await clear_cloud()

func clear_cloud() -> void:
	if directory.online():
		var relay = directory.lobby.relay
		await relay.account_delete_document(LIVE_ROOT)
		if directory.online():
			await relay.account_delete_document(ENDPOINT)

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
		var candidate := await generate_session_key()
		if candidate and is_current(token):
			await announce_endpoint(candidate, token)
			if is_current(token) and key:
				remove_legacy_history(token)
	preparing = false

# Key generation can take many frames. Only the private Crypto instance runs
# on the worker. Account checks and endpoint publication stay on the main thread.
func generate_session_key() -> CryptoKey:
	var generator := Crypto.new()
	if key_thread.start(generator.generate_rsa.bind(2048), Thread.PRIORITY_LOW) != OK:
		return null
	var tree := get_tree()
	while key_thread.is_alive():
		await tree.process_frame
	return key_thread.wait_to_finish() as CryptoKey if key_thread.is_started() else null

func _exit_tree() -> void:
	if key_thread.is_started():
		key_thread.wait_to_finish()

func announce_endpoint(candidate: CryptoKey, token: String) -> void:
	preparing = true
	var result: int = await directory.lobby.relay.account_document_set(ENDPOINT, {"session": token, "pem": candidate.save_to_string(true)}, true)
	if is_current(token) and result == 0:
		key = candidate
		announce_at = Time.get_ticks_msec() + ENDPOINT_REFRESH
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
	if not can_send(name):
		return false
	if session_owner != directory.username:
		reset_session()
		session_owner = directory.username
	var messages: Array = outbox.get(name, [])
	if messages.size() >= MAX_QUEUED:
		return false
	messages.append({
		"id": crypto.generate_random_bytes(12).hex_encode(),
		"body": body,
		"deadline": Time.get_ticks_msec() + QUEUE_TTL_MS,
		"packet": {},
		"attempted": false,
		"retry_at": 0,
	})
	outbox[name] = messages
	return true

func accepted(friend: Dictionary) -> bool:
	return int(friend.get("FriendStatus", 0)) == directory.Codes.FRIEND_STATUS.FRIEND

func still_friends(name: String) -> bool:
	return directory.friends.any(func(friend): return accepted(friend) and String(friend.get("Username", "")).nocasecmp_to(name) == 0)

func prepare_packet(name: String, item: Dictionary, token: String) -> void:
	var endpoint := document(await directory.lobby.relay.account_get_external_document(name, ENDPOINT))
	if not is_current(token):
		return
	var destination := String(endpoint.get("session", ""))
	var pem := String(endpoint.get("pem", ""))
	var recipient := CryptoKey.new()
	if destination.length() == 32 and pem.length() <= 1024 and recipient.load_from_string(pem, true) == OK:
		var chunks := encode(recipient, item.body)
		if not chunks.is_empty():
			item.packet = {"id": item.id, "to": destination, "parts": chunks}

func poll_outbox() -> void:
	sending = true
	var token := session
	for name in outbox.keys():
		if not is_current(token):
			break
		await advance_outbox(name, token)
	sending = false

func advance_outbox(name: String, token: String) -> void:
	var messages: Array = outbox[name]
	var item: Dictionary = messages.front()
	var relay = directory.lobby.relay
	if not still_friends(name):
		outbox.erase(name)
		failed.emit(name)
		return
	var expired := Time.get_ticks_msec() >= int(item.deadline)
	if item.packet.is_empty() and not expired:
		if not can_send(name):
			return
		await prepare_packet(name, item, token)
		if not is_current(token):
			return
	var acknowledged := false
	if item.attempted:
		var receipt := document(await relay.account_get_external_document(name, address(session_owner, "receipt")))
		if not is_current(token):
			return
		acknowledged = receipt.get("id") == item.id and receipt.get("session") == item.packet.to
	if not acknowledged and not expired:
		if not item.packet.is_empty() and Time.get_ticks_msec() >= int(item.retry_at):
			# An ambiguous write can be retried without creating a second message.
			item.attempted = true
			item.packet.expires = int(Time.get_unix_time_from_system()) + MESSAGE_TTL
			var result: int = await relay.account_document_set(address(name, "message"), item.packet, true)
			if is_current(token):
				item.retry_at = Time.get_ticks_msec() + (PACKET_RETRY if result == 0 else 0)
		return
	# Finish deletion before letting the next queued packet reuse this address.
	if item.attempted:
		await relay.account_delete_document(address(name, "message"))
		if not is_current(token):
			return
	messages.pop_front()
	if messages.is_empty():
		outbox.erase(name)
	if acknowledged:
		RiftSocial.add_whisper("account:" + name, item.body, true)
	else:
		failed.emit(name)

func poll_inbox() -> void:
	reading = true
	var token := session
	var friends: Array = directory.friends.filter(accepted)
	var online_friends := friends.filter(func(friend): return directory.is_friend_online(friend))
	for i in mini(2, online_friends.size()):
		if not is_current(token):
			break
		var name: String = online_friends[cursor % online_friends.size()].Username
		cursor = (cursor + 1) % online_friends.size()
		await receive(name, token)
	if is_current(token) and offline_elapsed >= 8.0:
		offline_elapsed = 0.0
		var other_friends := friends.filter(func(friend): return not directory.is_friend_online(friend))
		if not other_friends.is_empty():
			var name: String = other_friends[offline_cursor % other_friends.size()].Username
			offline_cursor = (offline_cursor + 1) % other_friends.size()
			await receive(name, token)
	for name in receipts.keys():
		if not is_current(token):
			break
		var receipt: Dictionary = receipts[name]
		var relay = directory.lobby.relay
		if receipt.expires <= Time.get_ticks_msec():
			var result: int = await relay.account_delete_document(address(name, "receipt"))
			if is_current(token) and deleted(result):
				receipts.erase(name)
		elif not receipt.sent:
			var result: int = await relay.account_document_set(address(name, "receipt"), {"id": receipt.id, "session": token}, true)
			if is_current(token):
				receipt.sent = result == 0
	reading = false

func receive(name: String, token: String) -> void:
	var packet := document(await directory.lobby.relay.account_get_external_document(name, address(session_owner, "message")))
	var id := String(packet.get("id", ""))
	var expires := int(packet.get("expires", 0))
	var now := int(Time.get_unix_time_from_system())
	if not is_current(token) or not still_friends(name) or packet.get("to") != token or expires < now - CLOCK_SKEW or expires > now + MESSAGE_TTL + CLOCK_SKEW or id.length() != 24 or not id.is_valid_hex_number():
		return
	if delivered.get(name) == id:
		var receipt: Dictionary = receipts.get(name, {})
		if not receipt.is_empty() and expires > int(receipt.wire_expiry):
			receipt.wire_expiry = expires
			receipt.sent = false
		return
	var body := decode(packet.get("parts", []))
	if body.is_empty():
		return
	delivered[name] = id
	receipts[name] = {"id": id, "expires": Time.get_ticks_msec() + QUEUE_TTL_MS, "wire_expiry": expires, "sent": false}
	RiftSocial.receive_whisper("account:" + name, body)

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
