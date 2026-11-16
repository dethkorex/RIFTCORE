extends Node

signal changed
signal friend_request_received(username: String)

const CloudProgress := preload("res://scripts/cloud_progress.gd")
const Codes := preload("res://addons/GD-Sync/Scripts/Enums/Enums.gd")
const LINK_PATH := "user://riftcore_directory.cfg"
const DIRECTORY_BOARD := "RIFTCORE Players"
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
var refreshing := false
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

func sign_in(email: String, password: String, create: bool, verification_code := "", registration_name := "") -> String:
	if busy or online():
		return status
	var name := registration_name.strip_edges()
	if create and (name.length() < 3 or name.length() > 20):
		return "Enter a username of 3 to 20 characters to create an account."
	if not email.contains("@") or password.length() < 3 or password.length() > 20:
		return "Enter your email and a password of 3 to 20 characters."
	busy = true
	var result := "Could not reach the directory. Try again."
	if await connect_service():
		result = await authenticate(email, password, create, verification_code, name)
	busy = false
	status = result
	changed.emit()
	return result

func authenticate(email: String, password: String, create: bool, verification_code: String, registration_name := "") -> String:
	if create:
		var code: int = await lobby.relay.account_create(email, registration_name, password)
		match code:
			Codes.ACCOUNT_CREATION_RESPONSE_CODE.SUCCESS:
				pass
			Codes.ACCOUNT_CREATION_RESPONSE_CODE.USERNAME_ALREADY_EXISTS:
				return "That profile name is already registered. Sign in if it belongs to you."
			Codes.ACCOUNT_CREATION_RESPONSE_CODE.EMAIL_ALREADY_EXISTS:
				return "That email is already registered. Choose Sign In."
			Codes.ACCOUNT_CREATION_RESPONSE_CODE.INVALID_USERNAME:
				return "GD Sync rejected this profile name. The local profile can still play offline."
			_:
				return response_message("Could not register this profile", code)
	if not create and not verification_code.is_empty():
		var code: int = await lobby.relay.account_verify(email, verification_code.strip_edges(), SESSION_TIME)
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
			return "Enter the verification code sent to your email."
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
			return "GD Sync accepted the resend. Check your inbox and spam folder."
		Codes.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.ON_COOLDOWN:
			return "Wait a moment before requesting another code."
		Codes.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.EMAIL_OR_PASSWORD_INCORRECT:
			return "Check your email and password. If the unverified account expired, register again."
		Codes.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.ALREADY_VERIFIED:
			return "This email is already verified. Select Sign In."
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
	await refresh_friends()
	register_directory_listing()

func save_link() -> Error:
	var saved := ConfigFile.new()
	saved.set_value("account", "username", saved_account_name)
	saved.set_value("profile", "remember", remember_sign_in)
	return saved.save(LINK_PATH)

func set_remember_sign_in(enabled: bool) -> void:
	remember_sign_in = enabled
	save_link()

func sign_out() -> void:
	if busy or username.is_empty():
		return
	busy = true
	if not lobby.connected_room.is_empty():
		lobby.leave()
	await lobby.relay.account_logout()
	username = ""
	friends.clear()
	incoming_names.clear()
	directory_index_ready = false
	presence.clear()
	seen_invites.clear()
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
	if username.is_empty() or busy:
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
	presence_elapsed += delta
	if presence_elapsed >= PRESENCE_INTERVAL:
		presence_elapsed = 0.0
		lobby.relay.account_document_set(PRESENCE_PATH, {"seen": int(Time.get_unix_time_from_system())}, true)
	refresh_elapsed += delta
	if refresh_elapsed >= 8.0 and not refreshing:
		refresh_elapsed = 0.0
		poll()

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
	for friend in updated:
		if checked >= 4 or not online():
			break
		var id: String = friend.Username
		if int(friend.get("FriendStatus", 0)) == Codes.FRIEND_STATUS.FRIEND and now - float(presence.get(id, {}).get("checked", 0.0)) >= 45.0:
			checked += 1
			var heartbeat: Dictionary = await lobby.relay.account_get_external_document(id, PRESENCE_PATH)
			var seen := float(presence.get(id, {}).get("seen", 0.0))
			if int(heartbeat.get("Code", 1)) in [0, Codes.ACCOUNT_GET_DOCUMENT_RESPONSE_CODE.DOESNT_EXIST]:
				var value: Variant = heartbeat.get("Result", {})
				seen = float(value.get("seen", 0.0)) if value is Dictionary else 0.0
			presence[id] = {"checked": now, "seen": seen}
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
			snapshot.append([friend.Username, friend.get("FriendStatus", 0), is_friend_online(friend)])
		for id in presence.keys():
			if not friends.any(func(friend): return friend.Username == id):
				presence.erase(id)
		if snapshot != displayed_contacts:
			displayed_contacts = snapshot
			changed.emit()

func is_friend_online(friend: Dictionary) -> bool:
	if not online() or int(friend.get("FriendStatus", 0)) != Codes.FRIEND_STATUS.FRIEND:
		return false
	var current_lobby: Variant = friend.get("Lobby", {})
	if current_lobby is Dictionary and String(current_lobby.get("Name", "")).begins_with(lobby.ROOM_PREFIX):
		return true
	if friend.get("Online") is bool and friend.Online:
		return true
	var seen := float(presence.get(friend.Username, {}).get("seen", 0.0))
	var age := Time.get_unix_time_from_system() - seen
	return age >= -15.0 and age < PRESENCE_TTL

func refresh_invites() -> void:
	var result: Dictionary = await lobby.relay.account_get_lobby_invitations()
	if not online() or result.get("Code", 1) != 0 or not result.get("Result") is Array:
		return
	var active := {}
	for invite in result.Result:
		if not invite is Dictionary or not String(invite.get("Password", "")).is_empty():
			continue
		var room := String(invite.get("LobbyName", ""))
		if not room.begins_with(lobby.ROOM_PREFIX):
			continue
		var code: String = room.trim_prefix(lobby.ROOM_PREFIX)
		if not lobby.valid_code(code):
			continue
		active[code] = true
		if not seen_invites.has(code) and not RiftSocial.invites.has(code) and code != lobby.connected_room:
			lobby.invite_received.emit(lobby.Profile.clean_operator_name(String(invite.get("Username", "A friend"))), code)
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
