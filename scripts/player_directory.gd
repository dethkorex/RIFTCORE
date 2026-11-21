extends Node

signal changed
signal friend_request_received(username: String)
signal presence_published
signal gamer_score_changed

const GamerScore := preload("res://scripts/gamer_score.gd")
const CloudProgress := preload("res://scripts/cloud_progress.gd")
const Codes := preload("res://addons/GD-Sync/Scripts/Enums/Enums.gd")
const LINK_PATH := "user://riftcore_directory.cfg"
# GD-Sync returns and expects the dashboard's URL-encoded leaderboard name.
const DIRECTORY_BOARD := "Global%20Leaderboard"
const PRESENCE_PATH := "riftcore_presence"
const SESSION_TIME := 604800.0
const PRESENCE_INTERVAL := 38.0
const PRESENCE_TTL := 120.0

var lobby: Node
var progress: CloudProgress
var whispers: Node
var saved_account_name := ""
var username := ""
var linked := false
var remember_sign_in := true
var busy := false
var needs_verification := false
var status := "Connect your profile to find RIFTCORE friends."
var friends: Array[Dictionary] = []
var presence: Dictionary = {}
var seen_invites: Dictionary = {}
var refresh_elapsed := 0.0
var displayed_contacts: Array = []
var incoming_names: Array[String] = []
var directory_index_ready := false
var last_connection := false
var presence_elapsed := 0.0
var publishing_presence := false
var published_room := ""
var refreshing := false
var gamer_score := GamerScore.new()
var gamer_sync_elapsed := 30.0
var gamer_sync_busy := false
var published_gamer_score := -1
var party_request := {}
var served_party_requests: Dictionary[String, String] = {}
var retry_at := 0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	progress = CloudProgress.new()
	progress.directory = self
	add_child(progress)
	whispers = preload("res://scripts/directory_whispers.gd").new()
	whispers.directory = self
	add_child(whispers)
	var saved := ConfigFile.new()
	if saved.load(LINK_PATH) == OK:
		saved_account_name = String(saved.get_value("account", "username", saved.get_value("profile", "name", "")))
		linked = not saved_account_name.is_empty()
		remember_sign_in = bool(saved.get_value("profile", "remember", true))

func configure(_local_operator_name: String = "") -> void:
	if not linked or not remember_sign_in or not username.is_empty() or busy:
		return
	busy = true
	if await connect_service():
		var result: int = await lobby.relay.account_login_from_session(SESSION_TIME)
		if result == Codes.ACCOUNT_LOGIN_RESPONSE_CODE.SUCCESS:
			await finish_sign_in()
		else:
			status = "Sign in to restore your RIFTCORE friends."
	else:
		status = "Directory unavailable. Solo play and room codes are still available."
	busy = false
	changed.emit()

func connect_service() -> bool:
	if not lobby.available:
		return false
	lobby.ensure_relay()
	for attempt in 120:
		if has_connection():
			return true
		await get_tree().create_timer(0.1).timeout
	return false

func has_connection() -> bool:
	return is_instance_valid(lobby.relay) and lobby.relay_ready and lobby.relay.is_active()

func online() -> bool:
	return has_connection() and not username.is_empty() and lobby.relay.account_is_logged_in()

func register_account(email: String, password: String, raw_name: String) -> Dictionary:
	if busy or online():
		return {"created": false, "message": "Finish the current account session first."}
	var name := raw_name.strip_edges()
	if name.length() < 3 or name.length() > 20:
		return {"created": false, "message": "Enter a username of 3 to 20 characters."}
	if not valid_credentials(email, password):
		return {"created": false, "message": "Enter your email and a password of 3 to 20 characters."}
	busy = true
	var code := Codes.ACCOUNT_CREATION_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER
	if await connect_service():
		code = await lobby.relay.account_create(email, name, password)
	busy = false
	var message: String
	match code:
		Codes.ACCOUNT_CREATION_RESPONSE_CODE.SUCCESS:
			return {"created": true}
		Codes.ACCOUNT_CREATION_RESPONSE_CODE.USERNAME_ALREADY_EXISTS:
			message = "That username is already taken. Choose another or sign in."
		Codes.ACCOUNT_CREATION_RESPONSE_CODE.EMAIL_ALREADY_EXISTS:
			message = "That email already has an account. Sign in to continue."
		Codes.ACCOUNT_CREATION_RESPONSE_CODE.INVALID_EMAIL:
			message = "Enter a valid email address."
		Codes.ACCOUNT_CREATION_RESPONSE_CODE.INVALID_USERNAME:
			message = "Choose a username that uses letters and numbers."
		Codes.ACCOUNT_CREATION_RESPONSE_CODE.STORAGE_FULL:
			message = "Account storage is full. Contact RIFTCORE support."
		_:
			message = response_message("Could not create your account", code)
	return {"created": false, "message": message}

func valid_credentials(email: String, password: String) -> bool:
	return email.contains("@") and password.length() >= 3 and password.length() <= 20

func sign_in(email: String, password: String, verification_code := "") -> String:
	if busy or online():
		return status
	if not valid_credentials(email, password):
		return "Enter your email and a password of 3 to 20 characters."
	busy = true
	var result := "Could not reach the directory. Try again."
	if await connect_service():
		result = await authenticate(email, password, verification_code)
	busy = false
	status = result
	changed.emit()
	return result

func authenticate(email: String, password: String, verification_code: String) -> String:
	needs_verification = false
	if not verification_code.is_empty():
		var code: int = await lobby.relay.account_verify(email, verification_code.strip_edges(), SESSION_TIME)
		needs_verification = true
		if code == Codes.ACCOUNT_VERIFICATION_RESPONSE_CODE.SUCCESS and lobby.relay.account_is_logged_in():
			await finish_sign_in()
			return status
		if code == Codes.ACCOUNT_VERIFICATION_RESPONSE_CODE.INCORRECT_CODE:
			return "That code did not match. Paste the latest code from your email."
		if code == Codes.ACCOUNT_VERIFICATION_RESPONSE_CODE.CODE_EXPIRED:
			return "That code expired. Request a new code."
		if code not in [Codes.ACCOUNT_VERIFICATION_RESPONSE_CODE.SUCCESS, Codes.ACCOUNT_VERIFICATION_RESPONSE_CODE.ALREADY_VERIFIED]:
			return response_message("Could not verify that code", code)
	var login: Dictionary = await lobby.relay.account_login(email, password, SESSION_TIME)
	match int(login.get("Code", 1)):
		Codes.ACCOUNT_LOGIN_RESPONSE_CODE.SUCCESS:
			await finish_sign_in()
			return status
		Codes.ACCOUNT_LOGIN_RESPONSE_CODE.NOT_VERIFIED:
			needs_verification = true
			return "This account still needs verification. Enter the latest code or request a new one."
		Codes.ACCOUNT_LOGIN_RESPONSE_CODE.EMAIL_OR_PASSWORD_INCORRECT:
			return "Check your email and password."
	return response_message("Could not sign in", int(login.get("Code", 1)))

func resend_code(email: String, password: String) -> String:
	if busy:
		return "Wait for the current request to finish."
	if not email.contains("@") or password.is_empty():
		return "Enter the email and password you used to register."
	busy = true
	if not await connect_service():
		busy = false
		return "The directory is offline. Try again once connected."
	var code: int = await lobby.relay.account_resend_verification_code(email, password)
	busy = false
	match code:
		Codes.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.SUCCESS:
			needs_verification = true
			return "Verification email requested. Check your inbox and spam folder."
		Codes.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.ON_COOLDOWN:
			needs_verification = true
			return "The last code is still valid. Try again after the 10-minute limit."
		Codes.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.EMAIL_OR_PASSWORD_INCORRECT:
			return "Check your email and password. If the unverified account expired, register again."
		Codes.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.ALREADY_VERIFIED:
			return "This email is already verified. Select Sign In."
		Codes.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.VERIFICATION_DISABLED:
			return "Email verification is disabled for this server. Select Sign In."
	return response_message("Could not resend the code", code)

func finish_sign_in() -> void:
	var signed_in: String = lobby.relay.player_get_username()
	if signed_in.is_empty() or (linked and not saved_account_name.is_empty() and signed_in.nocasecmp_to(saved_account_name) != 0):
		await lobby.relay.account_logout()
		status = "This installation is linked to the account %s." % saved_account_name
		return
	username = signed_in
	saved_account_name = signed_in
	needs_verification = false
	linked = true
	var saved_session := save_link() == OK
	status = "Connected as %s" % username
	if not saved_session:
		status += " · Sign-in could not be remembered"
	presence_elapsed = PRESENCE_INTERVAL
	refresh_elapsed = 8.0
	register_directory_listing.call_deferred()

func save_link() -> Error:
	var saved := ConfigFile.new()
	saved.set_value("account", "username", saved_account_name)
	saved.set_value("profile", "remember", remember_sign_in)
	return saved.save(LINK_PATH)

func reset_local_link() -> Error:
	for path in [LINK_PATH, "user://GD-Sync/DataController.conf"]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(path)
			if error != OK:
				return error
	linked = false
	saved_account_name = ""
	return OK

func set_remember_sign_in(enabled: bool) -> void:
	remember_sign_in = enabled
	save_link()

func sign_out() -> void:
	if busy or username.is_empty():
		return
	busy = true
	if not lobby.connected_room.is_empty():
		lobby.leave()
	await whispers.shutdown()
	await unpublish_presence()
	await lobby.relay.account_logout()
	username = ""
	friends.clear()
	incoming_names.clear()
	directory_index_ready = false
	presence.clear()
	seen_invites.clear()
	party_request.clear()
	served_party_requests.clear()
	last_connection = false
	progress.remote.clear()
	progress.conflict = false
	progress.last_checked_hash = ""
	status = "Signed out. Local play is available."
	busy = false
	changed.emit()

func change_username(name: String) -> String:
	name = name.strip_edges()
	if not online() or busy or progress.busy:
		return "Wait for the current save or sign-in to finish."
	if name.length() < 3 or name.length() > 20:
		return "Enter a username of 3 to 20 characters."
	if name == username:
		return "This is your current username."
	busy = true
	var code: int = await lobby.relay.account_change_username(name)
	busy = false
	match code:
		Codes.ACCOUNT_CHANGE_USERNAME_RESPONSE_CODE.SUCCESS:
			var previous := username
			username = name
			saved_account_name = name
			lobby.relay.player_set_username(name)
			save_link()
			progress.rename_owner(previous, name)
			changed.emit()
			return "Username updated."
		Codes.ACCOUNT_CHANGE_USERNAME_RESPONSE_CODE.USERNAME_ALREADY_EXISTS:
			return "That username is taken."
		Codes.ACCOUNT_CHANGE_USERNAME_RESPONSE_CODE.ON_COOLDOWN:
			return "You recently updated your username. Try again later."
		Codes.ACCOUNT_CHANGE_USERNAME_RESPONSE_CODE.INVALID_USERNAME:
			return "That username has characters this account service does not accept."
	return response_message("Could not update your username", code)

func change_password(email: String, old_password: String, new_password: String) -> String:
	if not online() or busy:
		return "Sign in before updating your password."
	if not email.contains("@") or old_password.is_empty() or new_password.length() < 8 or new_password.length() > 20:
		return "Enter your email, current password, and a new password of 8 to 20 characters."
	if old_password == new_password:
		return "Choose a different password."
	busy = true
	var code: int = await lobby.relay.account_change_password(email, old_password, new_password)
	busy = false
	match code:
		Codes.ACCOUNT_CHANGE_PASSWORD_RESPONSE_CODE.SUCCESS:
			await sign_out()
			return "Password updated. Sign in again with the new password."
		Codes.ACCOUNT_CHANGE_PASSWORD_RESPONSE_CODE.EMAIL_OR_PASSWORD_INCORRECT:
			return "Check the account email and current password."
		Codes.ACCOUNT_CHANGE_PASSWORD_RESPONSE_CODE.ON_COOLDOWN:
			return "You recently updated your password. Try again later."
	return response_message("Could not update your password", code)

func _process(delta: float) -> void:
	if username.is_empty() or busy or lobby.quitting:
		return
	var connected := online()
	if last_connection != connected:
		last_connection = connected
		changed.emit()
	if not connected:
		if Time.get_ticks_msec() >= retry_at and not has_connection():
			retry_at = Time.get_ticks_msec() + 20000
			lobby.ensure_relay()
		return
	var owner := username.to_lower()
	if gamer_score.owner != owner:
		gamer_score.use_account(owner)
		gamer_sync_elapsed = 30.0
		published_gamer_score = -1
	gamer_sync_elapsed += delta
	if not gamer_sync_busy and gamer_sync_elapsed >= 30.0:
		sync_gamer_score()
	presence_elapsed += delta
	var open_room: String = lobby.joinable_room()
	if not publishing_presence and presence_elapsed >= 0.0 and (presence_elapsed >= PRESENCE_INTERVAL or published_room != open_room or published_gamer_score != gamer_score.score()):
		publish_presence(open_room)
	refresh_elapsed += delta
	if refresh_elapsed >= 8.0 and not refreshing:
		refresh_elapsed = 0.0
		poll()

func record_gamer_score(sector: int, mode: int, run: Dictionary) -> Dictionary:
	if not online():
		return {"points": 0, "awards": []}
	gamer_score.use_account(username)
	var before := gamer_score.earned.duplicate()
	var points := gamer_score.record_clear(sector, mode, run)
	gamer_sync_elapsed = 30.0
	var awards := gamer_score.earned.filter(func(id: String): return id not in before)
	if not awards.is_empty():
		changed.emit()
	return {"points": points, "awards": awards}

func register_gamer_finishes(finishes: Array) -> void:
	if online():
		gamer_score.use_account(username)
		gamer_score.record_finishes(finishes)
		gamer_sync_elapsed = 30.0

func sync_gamer_score() -> void:
	gamer_sync_busy = true
	gamer_sync_elapsed = 0.0
	var owner := username
	var remote: Dictionary = await lobby.relay.account_get_document(GamerScore.DOCUMENT)
	var code := int(remote.get("Code", 1))
	if online() and username == owner and code in [0, Codes.ACCOUNT_GET_DOCUMENT_RESPONSE_CODE.DOESNT_EXIST]:
		var previous := gamer_score.snapshot()
		var saved := GamerScore.new()
		saved.merge(remote.get("Result", {}))
		gamer_score.merge(saved.snapshot())
		if previous != gamer_score.snapshot():
			gamer_score.save()
			gamer_score_changed.emit()
			changed.emit()
		var local := gamer_score.snapshot()
		if local != saved.snapshot():
			await lobby.relay.account_document_set(GamerScore.DOCUMENT, local, true)
	gamer_sync_busy = false

func publish_presence(open_room: String) -> void:
	publishing_presence = true
	presence_elapsed = 0.0
	# GD-Sync supplies the actual room name through the accepted friend relationship.
	# A public heartbeat only confirms which room is open for joining.
	var proof := "" if open_room.is_empty() else open_room.sha256_text()
	var access: String = lobby.room_access if not open_room.is_empty() else ""
	var score := gamer_score.score()
	var heartbeat := {"seen": int(Time.get_unix_time_from_system()), "room_proof": proof, "party_access": access, "gamer_score": score}
	if not party_request.is_empty():
		heartbeat["party_request"] = party_request.duplicate()
	var result: int = await lobby.relay.account_document_set(PRESENCE_PATH, heartbeat, true)
	if result == 0:
		published_room = open_room
		published_gamer_score = score
	else:
		presence_elapsed = -5.0
	publishing_presence = false
	presence_published.emit()

func unpublish_presence() -> void:
	if publishing_presence:
		await presence_published
	if online():
		await lobby.relay.account_document_set(PRESENCE_PATH, {"seen": 0, "room_proof": "", "gamer_score": gamer_score.score()}, true)
	published_room = ""

func poll() -> void:
	refreshing = true
	await refresh_invites()
	if online():
		await refresh_friends()
	refreshing = false

func register_directory_listing() -> void:
	var backend: Node = lobby.relay
	var owner := username
	if not online() or not backend.has_method("leaderboard_exists"):
		return
	var board: Dictionary = await backend.leaderboard_exists(DIRECTORY_BOARD)
	if username != owner or not online() or not bool(board.get("Result", board.get("Exists", false))):
		return
	directory_index_ready = await backend.leaderboard_submit_score(DIRECTORY_BOARD, 1, {}) == 0
	changed.emit()

func browse_registered_players(page: int) -> Dictionary:
	if not online():
		return {"Code": ERR_UNAVAILABLE}
	return await lobby.relay.leaderboard_browse_scores(DIRECTORY_BOARD, 24, maxi(1, page))

func request_count() -> int:
	return incoming_names.size()

func refresh_friends() -> void:
	if not online():
		return
	var result: Dictionary = await lobby.relay.account_get_friends()
	if not online():
		return
	if result.get("Code", 1) == Codes.ACCOUNT_GET_FRIENDS_RESPONSE_CODE.NOT_LOGGED_IN:
		await lobby.relay.account_logout()
		username = ""
		status = "Your online session expired. Sign in again to see your friends."
		changed.emit()
		return
	if result.get("Code", 1) != 0 or not result.get("Result") is Array:
		return
	var updated: Array[Dictionary] = []
	for friend in result.Result:
		if friend is Dictionary and friend.get("Username") is String:
			updated.append(friend)
	# Refresh a few accepted contacts per pass to stay within cloud request limits.
	var now := Time.get_unix_time_from_system()
	var checked := 0
	var due := updated.duplicate()
	due.sort_custom(func(a, b): return float(presence.get(a.Username, {}).get("checked", 0.0)) < float(presence.get(b.Username, {}).get("checked", 0.0)))
	for friend in due:
		if checked >= 4 or not online():
			break
		var id: String = friend.Username
		if int(friend.get("FriendStatus", 0)) == Codes.FRIEND_STATUS.FRIEND and now - float(presence.get(id, {}).get("checked", 0.0)) >= 8.0:
			checked += 1
			var heartbeat: Dictionary = await lobby.relay.account_get_external_document(id, PRESENCE_PATH)
			var seen := float(presence.get(id, {}).get("seen", 0.0))
			var last: Dictionary = presence.get(id, {}).duplicate()
			if int(heartbeat.get("Code", 1)) in [0, Codes.ACCOUNT_GET_DOCUMENT_RESPONSE_CODE.DOESNT_EXIST]:
				var value: Variant = heartbeat.get("Result", {})
				last = value if value is Dictionary else {}
				serve_friends_party_request(id, last.get("party_request"))
			last["checked"] = now
			last["seen"] = last.get("seen", seen)
			presence[id] = last
	if online():
		friends = updated
		var requests: Array[String] = []
		for entry in friends:
			if int(entry.get("FriendStatus", 0)) == Codes.FRIEND_STATUS.INCOMING_REQUEST:
				var sender: String = entry.Username
				if not incoming_names.has(sender):
					friend_request_received.emit(sender)
				requests.append(sender)
		incoming_names = requests
		var snapshot := []
		for friend in friends:
			var present := is_friend_online(friend)
			snapshot.append([friend.Username, friend.get("FriendStatus", 0), present, friend_room_code(friend), friend_gamer_score(friend.Username)])
		for id in RiftSocial.whispers.keys():
			if id is String and id.begins_with("account:") and not whispers.still_friends(id.trim_prefix("account:")):
				RiftSocial.clear_whisper(id)
		for id in presence.keys():
			if not friends.any(func(friend): return friend.Username == id):
				presence.erase(id)
		if snapshot != displayed_contacts:
			displayed_contacts = snapshot
			changed.emit()

func is_friend_online(friend: Dictionary) -> bool:
	if not online() or int(friend.get("FriendStatus", 0)) != Codes.FRIEND_STATUS.FRIEND:
		return false
	if friend.get("Online", false) or fresh_presence(presence.get(friend.get("Username", ""), {})):
		return true
	if friend.get("Online") is bool:
		return false
	if String(friend_lobby(friend).get("Name", "")).begins_with(lobby.ROOM_PREFIX):
		return true
	return false

func fresh_presence(record: Dictionary) -> bool:
	var seen := float(record.get("seen", 0.0))
	var age := Time.get_unix_time_from_system() - seen
	return age >= -15.0 and age < PRESENCE_TTL

func friend_lobby(friend: Dictionary) -> Dictionary:
	var info: Variant = friend.get("Lobby")
	return info if info is Dictionary else {}

func friend_gamer_score(friend: String) -> int:
	return clampi(int(presence.get(friend, {}).get("gamer_score", 0)), 0, GamerScore.score_limit)

func friend_room_code(friend: Dictionary) -> String:
	return room_code_from_friend(friend, presence.get(friend.get("Username", ""), {}))

func room_code_from_friend(friend: Dictionary, record: Dictionary) -> String:
	if not online() or int(friend.get("FriendStatus", 0)) != Codes.FRIEND_STATUS.FRIEND:
		return ""
	var room := friend_lobby(friend)
	var name := String(room.get("Name", ""))
	var friends_only: bool = record.get("party_access") == "friends" and fresh_presence(record)
	if not name.begins_with(lobby.ROOM_PREFIX) or (room.get("HasPassword", true) != false and not friends_only) or room.get("Open", true) == false:
		return ""
	var limit := int(room.get("PlayerLimit", lobby.MAX_PLAYERS))
	if limit > 0 and int(room.get("PlayerCount", 0)) >= limit:
		return ""
	var code: String = name.trim_prefix(lobby.ROOM_PREFIX)
	if not lobby.valid_code(code):
		return ""
	var live_room: bool = fresh_presence(record) and record.get("room_proof") == code.sha256_text()
	if live_room or (not friends_only and friend.get("Online", true) and room.get("Open", false) == true):
		return code
	return ""

func entry_for_friend(friend: Dictionary, heartbeat: Dictionary) -> Dictionary:
	var code := room_code_from_friend(friend, heartbeat)
	if code.is_empty():
		return {}
	return {"code": code, "access": "friends" if friend_lobby(friend).get("HasPassword", true) else "public"}

func lookup_open_room(name: String) -> Dictionary:
	var reply: Dictionary = await lookup(name)
	var code := int(reply.get("Code", Codes.ACCOUNT_GET_FRIEND_STATUS_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER))
	if code in [Codes.ACCOUNT_GET_FRIEND_STATUS_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER, Codes.ACCOUNT_GET_FRIEND_STATUS_RESPONSE_CODE.RATE_LIMIT_EXCEEDED]:
		# A temporary directory failure should not hide a recently advertised room.
		# The relay still checks the room's current state when the guest joins.
		for contact in friends:
			if String(contact.get("Username", "")).nocasecmp_to(name) == 0:
				return entry_for_friend(contact, presence.get(contact.Username, {}))
	var friend: Variant = reply.get("Result", {})
	if code != 0 or not friend is Dictionary:
		return {}
	var current := entry_for_friend(friend, {})
	if not current.is_empty() or friend_lobby(friend).is_empty() or not online():
		return current
	var heartbeat: Dictionary = await lobby.relay.account_get_external_document(name, PRESENCE_PATH)
	if int(heartbeat.get("Code", 1)) in [Codes.ACCOUNT_GET_DOCUMENT_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER, Codes.ACCOUNT_GET_DOCUMENT_RESPONSE_CODE.RATE_LIMIT_EXCEEDED]:
		return entry_for_friend(friend, presence.get(String(friend.get("Username", name)), {}))
	var record: Variant = heartbeat.get("Result", {})
	return entry_for_friend(friend, record) if heartbeat.get("Code", 1) == 0 and record is Dictionary else {}

func request_friends_party(host: String, room: String) -> void:
	var nonce := Crypto.new().generate_random_bytes(8).hex_encode()
	party_request = {"host": host.to_lower(), "proof": room.sha256_text(),
		"nonce": nonce, "expires": int(Time.get_unix_time_from_system()) + 90}
	lobby.checking_friend_room = true
	lobby._update("Waiting for access to %s’s friends-only party…" % host)
	presence_elapsed = PRESENCE_INTERVAL
	refresh_elapsed = 8.0
	get_tree().create_timer(90.0).timeout.connect(func():
		if party_request.get("nonce") == nonce:
			clear_friends_party_request()
			if lobby.can_receive_invite():
				lobby._update("The friends-only party did not respond. Try Join Game again.")
	)

func clear_friends_party_request() -> void:
	if not party_request.is_empty():
		party_request.clear()
		presence_elapsed = PRESENCE_INTERVAL
	lobby.checking_friend_room = false

func serve_friends_party_request(friend: String, request: Variant) -> void:
	if not request is Dictionary or lobby.room_access != "friends" or not lobby.can_invite_to_party():
		return
	var room: String = lobby.connected_room
	if room.is_empty() or request.get("host") != username.to_lower() or request.get("proof") != room.sha256_text():
		return
	var remaining := float(request.get("expires", 0)) - Time.get_unix_time_from_system()
	var nonce := String(request.get("nonce", ""))
	if remaining <= 0 or remaining > 100 or nonce.length() != 16 or served_party_requests.get(friend) == nonce:
		return
	served_party_requests[friend] = nonce
	# Only a server-confirmed friend can request a password-bearing native invite.
	var result: int = await lobby.relay.account_invite_friend_to_lobby(friend)
	if result != 0 and served_party_requests.get(friend) == nonce:
		served_party_requests.erase(friend)

func refresh_invites() -> void:
	var result: Dictionary = await lobby.relay.account_get_lobby_invitations()
	if not online() or result.get("Code", 1) != 0 or not result.get("Result") is Array:
		return
	var active := {}
	for invite in result.Result:
		if not invite is Dictionary:
			continue
		var room := String(invite.get("LobbyName", ""))
		if not room.begins_with(lobby.ROOM_PREFIX):
			continue
		var code: String = room.trim_prefix(lobby.ROOM_PREFIX)
		if not lobby.valid_code(code):
			continue
		var password := String(invite.get("Password", ""))
		var host := String(invite.get("Username", "A friend"))
		if password.length() > 16:
			continue
		active[code] = true
		if not password.is_empty() and party_request.get("proof") == code.sha256_text() 				and party_request.get("host") == host.to_lower() and lobby.can_receive_invite():
			clear_friends_party_request()
			lobby.join_room(code, password)
		elif not seen_invites.has(code) and not RiftSocial.invites.has(code) and code != lobby.connected_room:
			lobby.invite_received.emit(lobby.Profile.clean_operator_name(host), code, password)
	seen_invites = active

func lookup(name: String) -> Dictionary:
	if not online():
		return {"Code": Codes.ACCOUNT_GET_FRIEND_STATUS_RESPONSE_CODE.NOT_LOGGED_IN}
	return await lobby.relay.account_get_friend_status(name)

func friend_action(name: String, action: String) -> String:
	if not online():
		return "Sign in to manage RIFTCORE friends."
	var code: int
	match action:
		"request":
			code = await lobby.relay.account_send_friend_request(name)
		"accept":
			code = await lobby.relay.account_accept_friend_request(name)
		_:
			code = await lobby.relay.account_remove_friend(name)
	if code == 0:
		if action == "accept":
			whispers.announce_at = 0
		await refresh_friends()
		match action:
			"request": return "Friend request sent."
			"accept": return "Friend request accepted."
			_: return "Contact removed."
	return response_message("Could not update this friend request", code)

func response_message(action: String, code: int) -> String:
	match code:
		1: return action + ". Check your connection and try again."
		2: return "The directory has reached its data limit."
		3: return "The directory is busy. Try again shortly."
		4: return "The RIFTCORE database is unavailable."
	return "%s (GD Sync %d)." % [action, code]
