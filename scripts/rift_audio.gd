extends Node

const MENU_TRACK := preload("res://assets/audio/vintage_menu.mp3")
const SCORE_ROOT := "res://assets/audio/soundtrack"
# Each row follows sector order: exploration, Act I mini-boss, Act II main boss.
const SCORE := [
	["ember_foundry", "metallic_syncopation", "word_of_war"],
	["machine_jungle", "machine_pulse", "big_cut"],
	["frozen_reactor", "fractured", "it_s_time"],
	["abyssal_plant", "driven_down", "descent"],
	["buried_archives", "bit_crushed", "bones"],
	["sky_dock", "riff_led", "relentless_pulse"],
	["bio_lab", "breakdown", "2_sides"],
	["orbital_array", "metal_techno", "climax"],
	["scrapyard_expanse", "gears", "crushed"],
	["riftcore_nexus", "riftcore", "final_boss"],
]
const SCORE_CATEGORIES := ["level", "miniboss", "boss"]
const EFFECTS := {
	&"menu_move": [preload("res://assets/audio/menu_move.ogg"), -20.0, 1],
	&"menu_confirm": [preload("res://assets/audio/menu_confirm.ogg"), -13.0, 2],
	&"buster": [preload("res://assets/audio/buster.ogg"), -10.0, 3],
	&"armor_hit": [preload("res://assets/audio/armor_hit.ogg"), -8.0, 2],
	&"saber_swing": [preload("res://assets/audio/saber_swing.wav"), -12.0, 3],
	&"saber_impact": [preload("res://assets/audio/saber_impact.wav"), -11.0, 3],
	&"saber_charge_release": [preload("res://assets/audio/saber_charge_release.wav"), -9.0, 2],
	&"ground_slide": [preload("res://assets/audio/ground_slide.wav"), -14.0, 2],
	&"barricade_crack": [preload("res://assets/audio/barricade_crack.wav"), -9.0, 2],
	&"dash": [preload("res://assets/audio/dash.ogg"), -13.0, 1],
	&"deploy_zap": [preload("res://assets/audio/buster_charged.ogg"), -10.0, 1],
	&"titan_windup": [preload("res://assets/audio/buster_charge.ogg"), -12.0, 1],
	&"buster_charge": [preload("res://assets/audio/buster_charge.ogg"), -16.0, 1],
	&"buster_charged": [preload("res://assets/audio/buster_charged.ogg"), -7.0, 2],
	&"enemy_break": [preload("res://assets/audio/enemy_break.ogg"), -15.0, 2],
	&"pickup": [preload("res://assets/audio/pickup.ogg"), -14.0, 2],
	&"level_up": [preload("res://assets/audio/level_up.ogg"), -9.0, 1],
	&"achievement_unlocked": [preload("res://assets/audio/achievement_unlocked.wav"), -7.0, 1],
	&"checkpoint": [preload("res://assets/audio/checkpoint.ogg"), -10.0, 1],
}

const FOUNDRY_SOUNDS := {
	&"warden_ignition": preload("res://assets/neon_factory/foundry/warden_ignition.wav"),
	&"fire_jet": preload("res://assets/neon_factory/foundry/fire_jet.wav"),
	&"boulder_roll": preload("res://assets/neon_factory/foundry/boulder_roll.wav"),
	&"barricade_crack": preload("res://assets/audio/barricade_crack.wav"),
}

func foundry_sound(cue: StringName, at: Vector3) -> void:
	if shutting_down or not get_viewport().get_camera_3d() or absf(get_viewport().get_camera_3d().global_position.x - at.x) > 27.0:
		return
	var voice := AudioStreamPlayer3D.new()
	voice.stream = FOUNDRY_SOUNDS[cue]
	voice.bus = &"SFX"
	voice.volume_db = -11.0
	voice.max_distance = 30.0
	add_child(voice)
	voice.global_position = at
	voice.finished.connect(voice.queue_free)
	voice.play()

var requested_track: AudioStream
var music: AudioStreamPlayer
var music_tail: AudioStreamPlayer
var menu_track: AudioStreamMP3
var voices: Dictionary[StringName, AudioStreamPlayer] = {}
var music_fade: Tween
var dash_fade: Tween
const ENEMY_SHOTS := [preload("res://assets/audio/enemy_pulse.wav"),preload("res://assets/audio/enemy_heavy.wav")]
var last_enemy_volley := {"at": Vector3.INF, "time": -100}
var last_menu_move := -100
var shutting_down := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = make_music_player()
	music_tail = make_music_player()
	menu_track = MENU_TRACK.duplicate() as AudioStreamMP3
	menu_track.loop = true
	for cue in EFFECTS:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		voice.stream = EFFECTS[cue][0]
		voice.volume_db = EFFECTS[cue][1]
		voice.max_polyphony = EFFECTS[cue][2]
		add_child(voice)
		voices[cue] = voice

func play_music(in_level: bool, sector := 1) -> void:
	if in_level:
		play_sector_score(sector, 0)
	else:
		switch_music(menu_track, -14.0)

func play_boss_music(sector: int, act: int) -> void:
	play_sector_score(sector, clampi(act, 1, 2))

func play_sector_score(sector: int, category: int) -> void:
	if shutting_down:
		return
	var tracks: Array = SCORE[clampi(sector - 1, 0, SCORE.size() - 1)]
	var path := "%s/%s/%s.ogg" % [SCORE_ROOT, SCORE_CATEGORIES[category], tracks[category]]
	if is_instance_valid(requested_track) and requested_track.resource_path == path:
		return
	var track := load(path) as AudioStreamOggVorbis
	if track:
		track.loop = true
		switch_music(track, -16.0)

func make_music_player() -> AudioStreamPlayer:
	var deck := AudioStreamPlayer.new()
	deck.bus = &"Music"
	add_child(deck)
	return deck

func switch_music(track: AudioStream, volume: float) -> void:
	if shutting_down or requested_track == track:
		return
	requested_track = track
	if music_fade and music_fade.is_valid():
		music_fade.kill()
	if music_tail.playing and music_tail.stream == track:
		swap_music_players()
	else:
		# On a rapid switch, keep the louder source as the outgoing track.
		if music_tail.playing and music_tail.volume_db > music.volume_db:
			swap_music_players()
		swap_music_players()
		music.stop()
		music.stream = track
		music.volume_db = -80.0
		music.play()

	var incoming_start := db_to_linear(music.volume_db)
	var incoming_target := db_to_linear(volume)
	var outgoing_start := db_to_linear(music_tail.volume_db) if music_tail.playing else 0.0
	music_fade = create_tween()
	music_fade.tween_method(func(progress: float):
		var angle := progress * PI * 0.5
		music.volume_db = linear_to_db(maxf(0.0001, lerpf(incoming_start, incoming_target, sin(angle))))
		music_tail.volume_db = linear_to_db(maxf(0.0001, outgoing_start * cos(angle)))
	, 0.0, 1.0, 0.85 if music_tail.playing else 0.40)
	music_fade.tween_callback(func():
		music_tail.stop()
		music_tail.stream = null
	)

func swap_music_players() -> void:
	var previous := music
	music = music_tail
	music_tail = previous

func play_effect(cue: StringName) -> void:
	if shutting_down:
		return
	if cue == &"voice_start" or cue == &"voice_level_up":
		for extension in ["ogg", "wav", "mp3"]:
			var path := "res://assets/audio/%s.%s" % [cue, extension]
			if not ResourceLoader.exists(path):
				continue
			var voice := AudioStreamPlayer.new()
			voice.bus = &"Voice"
			voice.stream = load(path)
			voice.volume_db = -7.0
			add_child(voice)
			voice.finished.connect(voice.queue_free)
			voice.play()
			break
		return
	var voice := voices[cue]
	if cue == &"menu_move":
		var now := Time.get_ticks_msec()
		if now - last_menu_move < 85:
			return
		last_menu_move = now
	voice.pitch_scale = randf_range(0.95, 1.05) if cue == &"buster" or cue == &"armor_hit" or cue == &"saber_swing" else 1.0
	if cue == &"dash":
		if dash_fade and dash_fade.is_valid():
			dash_fade.kill()
		voice.volume_db = EFFECTS[cue][1]
		dash_fade = create_tween()
		dash_fade.tween_interval(0.15)
		dash_fade.tween_property(voice, "volume_db", -42.0, 0.15)
		dash_fade.tween_callback(voice.stop)
	voice.play()

func enemy_shot(at: Vector3, heavy: bool) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or absf(camera.global_position.x - at.x) > 31.0:
		return
	var now := Time.get_ticks_msec()
	# A spread has one muzzle report, even though multiple projectiles replicate.
	if now - int(last_enemy_volley.time) < 70 and at.distance_squared_to(last_enemy_volley.at) < 1.4:
		return
	last_enemy_volley = {"at": at, "time": now}
	play_enemy_sound(ENEMY_SHOTS[int(heavy)], at, -10.0 if heavy else -12.5)

const OPERATOR_SHOT_CUES := [&"buster", &"buster_charged", &"saber_swing", &"saber_charge_release"]

func play_operator_sound(cue: StringName, at: Vector3) -> void:
	if cue not in OPERATOR_SHOT_CUES or not at.is_finite():
		return
	var camera := get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_squared_to(at) < 33.0 * 33.0:
		play_enemy_sound(EFFECTS[cue][0], at, EFFECTS[cue][1])

func enemy_damage(at: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_squared_to(at) < 33.0 * 33.0:
		play_enemy_sound(preload("res://assets/audio/enemy_damage.wav"), at, -10.5)

func play_enemy_sound(stream: AudioStream, at: Vector3, gain_db: float) -> void:
	if shutting_down:
		return
	var voice := AudioStreamPlayer3D.new()
	voice.bus = &"SFX"
	voice.stream = stream
	voice.volume_db = gain_db
	voice.unit_size = 11.0
	voice.max_distance = 33.0
	voice.pitch_scale = randf_range(0.94,1.06)
	add_child(voice)
	voice.global_position = at
	voice.finished.connect(voice.queue_free)
	voice.play()

func stop_effect(cue: StringName) -> void:
	voices[cue].stop()

func quit_after_audio(exit_code := 0) -> void:
	if shutting_down:
		return
	shutting_down = true
	var tree := get_tree()
	tree.paused = true
	for fade in [music_fade, dash_fade]:
		if fade and fade.is_valid():
			fade.kill()
	for type in [&"AudioStreamPlayer", &"AudioStreamPlayer2D", &"AudioStreamPlayer3D", &"VideoStreamPlayer"]:
		for player in tree.root.find_children("*", type, true, false):
			player.stop()
			player.stream = null
	requested_track = null
	# Stopped streams are retired by the mixer. Fixed-FPS tests still use real audio time.
	var mix_interval := maxf(AudioServer.get_output_latency(), AudioServer.get_time_to_next_mix())
	var deadline := Time.get_ticks_msec() + ceili(clampf(mix_interval * 3.0, .09, .30) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
	await tree.process_frame
	tree.quit(exit_code)
