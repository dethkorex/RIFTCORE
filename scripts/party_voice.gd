extends Node

const SAMPLE_RATE := 12000
const PACKET_MS := 40
const SAMPLES := SAMPLE_RATE * PACKET_MS / 1000
const IDLE_MS := 280
const BUFFER_PACKETS := 3
const VOICE_READY := "rift_voice_v1"

var lobby: Node
var capturing := false
var retry_at := 0
var sequence := 0
var streams: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RiftSettings.voice_settings_changed.connect(settings_changed)

func settings_changed() -> void:
	reset()
	publish_preference()

func publish_preference() -> void:
	if not lobby.connected_room.is_empty() and is_instance_valid(lobby.relay):
		lobby.relay.player_set_data(VOICE_READY, RiftSettings.voice_enabled)

func available() -> bool:
	return RiftSettings.voice_enabled and not lobby.connected_room.is_empty() and lobby.room_size > 1 and is_instance_valid(lobby.relay)

func wants_microphone() -> bool:
	if DisplayServer.get_name() == "headless" or not get_window().has_focus():
		return false
	if not RiftSettings.voice_push_to_talk:
		return true
	var focused := get_viewport().gui_get_focus_owner()
	return Input.is_action_pressed(&"push_to_talk") and not (focused is LineEdit or focused is TextEdit)

func _process(_delta: float) -> void:
	if not available():
		if capturing or not streams.is_empty():
			reset()
		return
	var now := Time.get_ticks_msec()
	for sender in streams.keys():
		if now - int(streams[sender].last_at) > IDLE_MS:
			remove_speaker(sender)
		else:
			play_queued(streams[sender], now)
	var recipients: Array = lobby.relay.lobby_get_all_clients().filter(func(id: int):
		return id != lobby.relay.get_client_id() and lobby.relay.player_get_data(id, VOICE_READY, false) == true)
	if recipients.is_empty() or not wants_microphone():
		stop_capture()
		return
	if not capturing and now >= retry_at:
		capturing = AudioServer.set_input_device_active(true) == OK
		retry_at = now + 1000
		if capturing:
			AudioServer.get_input_frames(AudioServer.get_input_frames_available())
	if capturing:
		send_capture(recipients)

func send_capture(recipients: Array) -> void:
	var input_frames := roundi(AudioServer.get_input_mix_rate() * PACKET_MS / 1000.0)
	var available_frames := AudioServer.get_input_frames_available()
	if input_frames <= 0 or available_frames < input_frames:
		return
	# Keep the current packet after a slow frame. Older queued speech would add delay.
	if available_frames >= input_frames * 2:
		AudioServer.get_input_frames(available_frames - input_frames)
	var frames := AudioServer.get_input_frames(input_frames)
	if frames.size() != input_frames:
		return
	var peak := 0.0
	var packet := PackedByteArray()
	packet.resize(SAMPLES)
	for sample in SAMPLES:
		var start := sample * input_frames / SAMPLES
		var end := maxi(start + 1, (sample + 1) * input_frames / SAMPLES)
		var total := 0.0
		for index in range(start, end):
			total += (frames[index].x + frames[index].y) * 0.5
		var value := clampf(total / (end - start), -1.0, 1.0)
		peak = maxf(peak, absf(value))
		packet[sample] = 128 + roundi(signf(value) * sqrt(absf(value)) * 127.0)
	if peak >= 0.006:
		sequence += 1
		for id in recipients:
			lobby.relay.call_func_on_unreliable(id, receive_voice, sequence, packet)

func receive_voice(serial: int, packet: PackedByteArray) -> void:
	if not available() or packet.size() != SAMPLES or serial <= 0:
		return
	var sender: int = lobby.relay.get_sender_id()
	if sender == lobby.relay.get_client_id() or not lobby.relay.lobby_get_all_clients().has(sender):
		return
	var now := Time.get_ticks_msec()
	if not streams.has(sender):
		streams[sender] = {"last_sequence": 0, "last_at": now, "queued_at": now, "packets": [], "player": null, "playback": null}
	var stream: Dictionary = streams[sender]
	# The sender advances once per 40 ms packet. Allow nearby arrivals after jitter.
	if serial <= int(stream.last_sequence) or (int(stream.last_sequence) > 0 and now - int(stream.last_at) < 12):
		return
	stream.last_sequence = serial
	stream.last_at = now
	if stream.packets.is_empty():
		stream.queued_at = now
	if stream.packets.size() >= BUFFER_PACKETS:
		stream.packets.pop_front()
	stream.packets.push_back(packet)

func play_queued(stream: Dictionary, now: int) -> void:
	if stream.packets.is_empty():
		return
	if stream.player == null:
		if stream.packets.size() < 2 and now - int(stream.queued_at) < PACKET_MS:
			return
		var audio := AudioStreamGenerator.new()
		audio.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
		audio.mix_rate = SAMPLE_RATE
		audio.buffer_length = 0.14
		var player := AudioStreamPlayer.new()
		player.bus = &"Voice"
		player.stream = audio
		add_child(player)
		player.play()
		stream.player = player
		stream.playback = player.get_stream_playback()
	var playback: AudioStreamGeneratorPlayback = stream.playback
	if playback == null:
		return
	while not stream.packets.is_empty() and playback.can_push_buffer(SAMPLES):
		var packet: PackedByteArray = stream.packets.pop_front()
		var samples := PackedVector2Array()
		samples.resize(SAMPLES)
		for i in SAMPLES:
			var compressed := (float(packet[i]) - 128.0) / 127.0
			samples[i] = Vector2.ONE * clampf(compressed * absf(compressed), -1.0, 1.0)
		playback.push_buffer(samples)

func stop_capture() -> void:
	if capturing:
		AudioServer.set_input_device_active(false)
		capturing = false
		retry_at = 0

func remove_speaker(id: int) -> void:
	if streams.has(id):
		var player: AudioStreamPlayer = streams[id].player
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
		streams.erase(id)

func reset() -> void:
	stop_capture()
	for id in streams.keys():
		remove_speaker(id)
