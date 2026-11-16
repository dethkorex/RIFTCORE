extends Node

signal failed(recipient: String)

const PUBLIC_KEY := "riftcore_whisper_key_v1"
const PRIVATE_KEY := "riftcore_whisper_private_v1"
const MAX_THREADS := 32
const MAX_MESSAGES := 6
const TTL := 86400 * 2
const CHUNK_BYTES := 200

var directory
var crypto := Crypto.new()
var key: CryptoKey
var owned_by := ""
var preparing := false
var sending := false
var elapsed := 0.0
var cursor := 0
var reading := false
var received: Dictionary = {}
var sent: Dictionary = {}

func _process(delta: float) -> void:
	if not directory.online():
		return
	if owned_by != directory.username:
		key = null
		owned_by = directory.username
		received.clear()
		sent.clear()
	if not key and not preparing:
		elapsed += delta
		if elapsed >= 2.0:
			elapsed = 0.0
			setup()
	elif key and not reading:
		elapsed += delta
		if elapsed >= 3.0:
			elapsed = 0.0
			read_next()

func setup() -> void:
	preparing = true
	var owner := owned_by
	var relay = directory.lobby.relay
	var private: Dictionary = await relay.account_get_document(PRIVATE_KEY)
	if owner == directory.username and directory.online():
		var pem := String(document(private).get("pem", ""))
		var candidate: CryptoKey
		if int(private.get("Code", 1)) == 0 and pem.length() <= 8192:
			candidate = CryptoKey.new()
			if candidate.load_from_string(pem, false) != OK:
				candidate = null
		elif int(private.get("Code", 1)) == 6:
			candidate = crypto.generate_rsa(2048)
			if candidate and await relay.account_document_set(PRIVATE_KEY, {"pem": candidate.save_to_string(false)}, false) != 0:
				candidate = null
		if candidate and owner == directory.username and directory.online():
			var public_pem := candidate.save_to_string(true)
			var published: Dictionary = await relay.account_get_document(PUBLIC_KEY)
			if owner == directory.username and directory.online():
				var ready: bool = document(published).get("pem", "") == public_pem
				if not ready:
					ready = await relay.account_document_set(PUBLIC_KEY, {"pem": public_pem}, true) == 0
				if ready and owner == directory.username:
					key = candidate
	preparing = false

func document(response: Dictionary) -> Dictionary:
	var result: Variant = response.get("Result")
	return result if result is Dictionary else {}

func address(name: String) -> String:
	return "riftcore_whisper_v1_" + name.to_lower().sha256_text().left(32)

func can_send(name: String) -> bool:
	return directory.online() and directory.friends.any(func(friend):
		return int(friend.get("FriendStatus", 0)) == directory.Codes.FRIEND_STATUS.FRIEND and String(friend.get("Username", "")).nocasecmp_to(name) == 0)

func queue(name: String, body: String) -> bool:
	if not key or sending or not can_send(name):
		return false
	if not sent.has(name) and sent.size() >= MAX_THREADS:
		sent.erase(sent.keys().front())
	sending = true
	send(name, body)
	return true

func send(name: String, body: String) -> void:
	var owner := owned_by
	var relay = directory.lobby.relay
	var address_path := address(name)
	var success := false
	var public: Dictionary = await relay.account_get_external_document(name, PUBLIC_KEY)
	if int(public.get("Code", 1)) == 0 and owner == directory.username and can_send(name):
		var recipient := CryptoKey.new()
		var pem := String(document(public).get("pem", ""))
		if pem.length() <= 1024 and recipient.load_from_string(pem, true) == OK:
			var chunks := encode(recipient, body)
			if not chunks.is_empty():
				var previous: Dictionary = await relay.account_get_document(address_path)
				var saved: Variant = document(previous).get("messages")
				var entries: Array = saved if saved is Array else []
				var now := int(Time.get_unix_time_from_system())
				entries = entries.filter(func(row): return row is Dictionary and int(row.get("at", 0)) >= now - TTL)
				var random_id := crypto.generate_random_bytes(12).hex_encode()
				entries.append({"id": random_id, "at": now, "parts": chunks})
				entries = entries.slice(maxi(0, entries.size() - MAX_MESSAGES))
				if int(previous.get("Code", 1)) in [0, 6] and owner == directory.username and can_send(name):
					success = await relay.account_document_set(address_path, {"messages": entries}, true) == 0
	if owner == directory.username:
		if success:
			sent[name] = true
			RiftSocial.add_whisper("account:" + name, body, true)
		else:
			failed.emit(name)
	sending = false

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

func read_next() -> void:
	var friends: Array = directory.friends.filter(func(friend):
		return int(friend.get("FriendStatus", 0)) == directory.Codes.FRIEND_STATUS.FRIEND)
	if friends.is_empty():
		return
	var sender: String = friends[cursor % friends.size()].Username
	cursor += 1
	var owner := owned_by
	reading = true
	var reply: Dictionary = await directory.lobby.relay.account_get_external_document(sender, address(owner))
	if directory.online() and owner == directory.username and key and can_send(sender) and int(reply.get("Code", 1)) == 0:
		var entries: Variant = document(reply).get("messages")
		if entries is Array and entries.size() <= MAX_MESSAGES:
			var now := int(Time.get_unix_time_from_system())
			for entry in entries:
				if not entry is Dictionary or not entry.get("id") is String or String(entry.id).length() != 24:
					continue
				var id := sender + ":" + String(entry.id)
				if received.has(id) or int(entry.get("at", 0)) < now - TTL or int(entry.get("at", 0)) > now + 300:
					continue
				var message := decode(entry.get("parts", []))
				if not message.is_empty():
					received[id] = true
					if received.size() > 512:
						received.erase(received.keys().front())
					RiftSocial.receive_whisper("account:" + sender, message)
	reading = false
