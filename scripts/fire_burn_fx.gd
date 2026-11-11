extends Node3D

var motes: Array[MeshInstance3D] = []
var clock := 0.0

func _ready() -> void:
	var glow := RiftProjectile.add_glow(self, Color("ff5a15"), 1.12)
	glow.position = Vector3(0, 0.15, 0.29)
	for i in range(6):
		var ember := RiftProjectile.part(self, RiftProjectile.cached_mesh("Orb"), RiftProjectile.light_paint(Color("ff6220").lerp(Color("ffcf6b"), i * 0.10), 1.9), Vector3.ZERO, Vector3.ONE)
		motes.append(ember)

func _process(delta: float) -> void:
	clock += delta
	for i in range(motes.size()):
		var life := fposmod(clock * 1.75 + i / float(motes.size()), 1.0)
		var swirl := i * 2.39 + clock * 7.8
		var width := 0.14 * (1.0 - life)
		motes[i].position = Vector3(cos(swirl) * 0.37, -0.35 + life * 1.16, 0.31 + sin(swirl) * 0.17)
		motes[i].scale = Vector3(width, width * 2.2, width)
