extends Node

signal microphone_test_changed(message: String, level: float)

const MIC_ICON := preload("res://assets/ui/party-microphone.svg")
const SAMPLE_RATE := 12000
const PACKET_MS := 40
const SAMPLES := SAMPLE_RATE * PACKET_MS / 1000
const IDLE_MS := 280
const BUFFER_PACKETS := 3
const VOICE_READY := "rift_voice_v1"
const SPEECH_GATE := 0.006
const MIC_TEST_BUFFER := 0.06

var lobby: Node
var capturing := false
var retry_at := 0
var sequence := 0
var streams: Dictionary = {}
var last_transmit := -IDLE_MS
var test_owner: WeakRef
var last_test_meter_at := 0
var test_meter_peak := 0.0
var test_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RiftSettings.voice_settings_changed.connect(settings_changed)

func settings_changed() -> void:
	stop_microphone_test("Microphone settings changed.")
	reset()
	publish_preference()

func publish_preference() -> void:
	if not lobby.connected_room.is_empty() and is_instance_valid(lobby.relay):
		lobby.relay.player_set_data(VOICE_READY, RiftSettings.voice_enabled)

func available() -> bool:
	return RiftSettings.voice_enabled and not lobby.connected_room.is_empty() and lobby.room_size > 1 and is_instance_valid(lobby.relay)

func indicator_visible(id: int) -> bool:
	return available() and (id == lobby.relay.get_client_id() or lobby.relay.player_get_data(id, VOICE_READY, false) == true)

func indicator_tint(id: int) -> Color:
	var last := last_transmit if id == lobby.relay.get_client_id() else int(streams.get(id, {}).get("last_at", -IDLE_MS))
	var elapsed := Time.get_ticks_msec() - last
	if elapsed >= IDLE_MS:
		return Color("8397ac")
	return Color("61ffcf").lerp(Color("d8fffa"), (sin(float(Time.get_ticks_msec()) * 0.021) + 1.0) * 0.5)

func start_microphone_test(owner: Control) -> void:
	stop_microphone_test()
	reset()
	if DisplayServer.get_name() == "headless" or AudioServer.set_input_device_active(true) != OK:
		microphone_test_changed.emit("Could not open the selected microphone.", 0.0)
		return
	var mix_rate := AudioServer.get_input_mix_rate()
	if mix_rate <= 0:
		AudioServer.set_input_device_active(false)
		microphone_test_changed.emit("The selected microphone is unavailable.", 0.0)
		return
	test_owner = weakref(owner)
	owner.tree_exiting.connect(func():
		if test_owner != null and test_owner.get_ref() == owner:
			stop_microphone_test()
	, CONNECT_ONE_SHOT)
	AudioServer.get_input_frames(AudioServer.get_input_frames_available())
	last_test_meter_at = Time.get_ticks_msec()
	var monitor := AudioStreamGenerator.new()
	monitor.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	monitor.mix_rate = mix_rate
	monitor.buffer_length = MIC_TEST_BUFFER
	test_player = AudioStreamPlayer.new()
	test_player.stream = monitor
	test_player.bus = &"Voice"
	add_child(test_player)
	test_player.play()
	microphone_test_changed.emit("Live monitoring is on. Speak to hear yourself in your headset.", 0.0)

func is_testing_microphone() -> bool:
	return test_owner != null

func stop_microphone_test(message := "Microphone test stopped.") -> void:
	if test_owner == null:
		return
	test_owner = null
	test_meter_peak = 0.0
	AudioServer.set_input_device_active(false)
	if is_instance_valid(test_player):
		test_player.stop()
		test_player.queue_free()
		test_player = null
	microphone_test_changed.emit(message, 0.0)

func update_microphone_test() -> void:
	var owner := test_owner.get_ref() as Control
	if owner == null or not owner.is_visible_in_tree():
		stop_microphone_test()
		return
	var playback := test_player.get_stream_playback() as AudioStreamGeneratorPlayback
	var available_frames := AudioServer.get_input_frames_available()
	if playback != null and available_frames > 0:
		var count := mini(available_frames, playback.get_frames_available())
		# Keep the newest samples after a slow render frame.
		if count < available_frames:
			AudioServer.get_input_frames(available_frames - count)
		if count > 0:
			var samples := AudioServer.get_input_frames(count)
			for index in samples.size():
				var sample := samples[index]
				var mono := (sample.x + sample.y) * 0.5
				test_meter_peak = maxf(test_meter_peak, absf(mono))
				samples[index] = Vector2(mono, mono)
			playback.push_buffer(samples)
	var now := Time.get_ticks_msec()
	if now - last_test_meter_at >= 60:
		microphone_test_changed.emit("Live monitoring is on. Speak to hear yourself in your headset.", clampf(sqrt(test_meter_peak), 0.0, 1.0))
		last_test_meter_at = now
		test_meter_peak = 0.0

func wants_microphone() -> bool:
	if DisplayServer.get_name() == "headless" or not get_window().has_focus():
		return false
	if not RiftSettings.voice_push_to_talk:
		return true
	var focused := get_viewport().gui_get_focus_owner()
	return Input.is_action_pressed(&"push_to_talk") and not (focused is LineEdit or focused is TextEdit)

func _process(_delta: float) -> void:
	if is_testing_microphone():
		update_microphone_test()
		return
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
	if peak >= SPEECH_GATE:
		last_transmit = Time.get_ticks_msec()
		sequence += 1
		for id in recipients:
			lobby.relay.call_func_on_unreliable(id, receive_voice, sequence, packet)

func receive_voice(serial: int, packet: PackedByteArray) -> void:
	if not available() or is_testing_microphone() or packet.size() != SAMPLES or serial <= 0:
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
	last_transmit = -IDLE_MS
	for id in streams.keys():
		remove_speaker(id)
