extends Node3D

const FX := preload("res://scripts/combat_vfx.gd")
const COUNT := 14
var motes: Array[Sprite3D] = []
var hot_spot: Sprite3D
var blade: Node3D
var progress := 0.0
var phase := 0.0
var tint := Color.WHITE
var muzzle := Vector3.ZERO

func _ready() -> void:
	for i in COUNT:
		var texture := FX.SPARK if i % 3 == 0 else FX.FLASH
		var mote := FX.sprite(self, texture, Vector3.ZERO, .32, Color.WHITE)
		mote.shaded = false
		mote.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		motes.append(mote)
	hot_spot = FX.sprite(self, FX.FLASH, Vector3.ZERO, .43, Color.WHITE)
	hot_spot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hot_spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stop()

func energize(amount: float, color: Color, hand: Node3D, barrel: Vector3) -> void:
	progress = clampf(amount, 0.0, 1.0)
	tint = color
	blade = hand
	muzzle = barrel
	if not visible:
		phase = 0.0
		show()
		set_process(true)
		_process(0.0)

func stop() -> void:
	hide()
	set_process(false)

func _process(delta: float) -> void:
	phase = fposmod(phase + delta * lerpf(.95, 1.65, progress), 32.0)
	var origin := to_local(blade.to_global(Vector3(.45, 0, 0))) if is_instance_valid(blade) else to_local(muzzle)
	var tip := to_local(blade.to_global(Vector3(1.83, 0, 0))) if is_instance_valid(blade) else origin
	var active := roundi(lerpf(6.0, float(COUNT), progress))
	for i in COUNT:
		var mote := motes[i]
		mote.visible = i < active
		if not mote.visible:
			continue
		var t := fposmod(phase + float(i) * .618034, 1.0)
		var angle := i * 2.39996 + t * .9
		var start := Vector3(cos(angle) * 1.02, sin(angle) * .90 + .02, .46 + .17 * cos(i * 1.7))
		var target := origin.lerp(tip, .24 * progress * (i % 4))
		mote.position = start.lerp(target, t * t) + Vector3(0, .11 * sin(PI*t), 0)
		mote.modulate = Color(tint.lerp(Color.WHITE, .30 + .40*t), sin(PI*t) * .96)
		mote.scale = Vector3.ONE * (.60 + .68*t + .17*progress)
	var pulse := .5 + .5 * cos(phase * TAU)
	hot_spot.position = origin + Vector3(0, 0, .08)
	hot_spot.scale = Vector3.ONE * (.48 + .55*progress + .22*pulse)
	hot_spot.modulate = Color(tint.lerp(Color.WHITE, .38), .55 + .39*progress)
