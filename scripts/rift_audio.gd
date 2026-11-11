extends Node

const MENU_TRACK := preload("res://assets/audio/vintage_menu.mp3")
const LEVEL_TRACK := preload("res://assets/audio/space_boss_battle.ogg")
const JUNGLE_TRACK := preload("res://assets/audio/machine_jungle.ogg")
const EFFECTS := {
	&"menu_move": [preload("res://assets/audio/menu_move.ogg"), -20.0, 1],
	&"menu_confirm": [preload("res://assets/audio/menu_confirm.ogg"), -13.0, 2],
	&"buster": [preload("res://assets/audio/buster.ogg"), -10.0, 3],
	&"armor_hit": [preload("res://assets/audio/armor_hit.ogg"), -8.0, 2],
	&"saber_swing": [preload("res://assets/audio/dash.ogg"), -18.0, 3],
	&"dash": [preload("res://assets/audio/dash.ogg"), -13.0, 1],
	&"deploy_zap": [preload("res://assets/audio/buster_charged.ogg"), -10.0, 1],
	&"titan_windup": [preload("res://assets/audio/buster_charge.ogg"), -12.0, 1],
	&"buster_charge": [preload("res://assets/audio/buster_charge.ogg"), -16.0, 1],
	&"buster_charged": [preload("res://assets/audio/buster_charged.ogg"), -7.0, 2],
	&"enemy_break": [preload("res://assets/audio/enemy_break.ogg"), -15.0, 2],
	&"pickup": [preload("res://assets/audio/pickup.ogg"), -14.0, 2],
	&"level_up": [preload("res://assets/audio/level_up.ogg"), -9.0, 1],
	&"checkpoint": [preload("res://assets/audio/checkpoint.ogg"), -10.0, 1],
}

var music: AudioStreamPlayer
var menu_track: AudioStreamMP3
var level_track: AudioStreamOggVorbis
var jungle_track: AudioStreamOggVorbis
var voices: Dictionary[StringName, AudioStreamPlayer] = {}
var music_fade: Tween
var dash_fade: Tween
var last_menu_move := -100

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.bus = &"Music"
	add_child(music)
	menu_track = MENU_TRACK.duplicate() as AudioStreamMP3
	level_track = LEVEL_TRACK.duplicate() as AudioStreamOggVorbis
	jungle_track = JUNGLE_TRACK.duplicate() as AudioStreamOggVorbis
	menu_track.loop = true
	level_track.loop = true
	jungle_track.loop = true
	for cue in EFFECTS:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		voice.stream = EFFECTS[cue][0]
		voice.volume_db = EFFECTS[cue][1]
		voice.max_polyphony = EFFECTS[cue][2]
		add_child(voice)
		voices[cue] = voice

func play_music(in_level: bool, sector := 1) -> void:
	var track: AudioStream = (jungle_track if sector == 2 else level_track) if in_level else menu_track
	var volume := -16.0 if in_level else -14.0
	if music.stream == track and music.playing:
		return
	if music_fade and music_fade.is_valid():
		music_fade.kill()
	music_fade = create_tween()
	if music.playing:
		music_fade.tween_property(music, "volume_db", -45.0, 0.18)
	music_fade.tween_callback(func():
		music.stream = track
		music.volume_db = -38.0
		music.play()
	)
	music_fade.tween_property(music, "volume_db", volume, 0.4)

func play_effect(cue: StringName) -> void:
	if cue == &"voice_start" or cue == &"voice_level_up":
		for extension in ["ogg", "wav", "mp3"]:
			var path := "res://assets/audio/%s.%s" % [cue, extension]
			if not ResourceLoader.exists(path):
				continue
			var voice := AudioStreamPlayer.new()
			voice.bus = &"SFX"
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
	voice.pitch_scale = randf_range(0.95, 1.05) if cue == &"buster" or cue == &"armor_hit" else 1.0
	if cue == &"dash":
		if dash_fade and dash_fade.is_valid():
			dash_fade.kill()
		voice.volume_db = EFFECTS[cue][1]
		dash_fade = create_tween()
		dash_fade.tween_interval(0.15)
		dash_fade.tween_property(voice, "volume_db", -42.0, 0.15)
		dash_fade.tween_callback(voice.stop)
	voice.play()

func stop_effect(cue: StringName) -> void:
	voices[cue].stop()
