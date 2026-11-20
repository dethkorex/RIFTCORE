extends SceneTree

const Launcher := preload("res://launcher.gd")
const Client := preload("res://update_client.gd")
const START := "v6.3.25-preview"
const BRIDGE := "v6.3.26-preview"
const LARGE := "v6.4.0-preview"

class TestClient extends "res://update_client.gd":
	var manifest: Variant
	var url := ""
	func fetch_manifest() -> Variant:
		return manifest
	func release_url(_tag: String, filename: String) -> String:
		return url + "/" + filename

var failed := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, text: String) -> bool:
	print("PASS " if ok else "FAIL ", text)
	failed += int(not ok)
	return ok

func create_launcher(info: Variant, url: String) -> Launcher:
	var launcher := preload("res://launcher.tscn").instantiate() as Launcher
	launcher.client.free()
	var fixture := TestClient.new()
	fixture.manifest = info
	fixture.url = url
	launcher.client = fixture
	root.add_child(launcher)
	return launcher

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var client := Client.new()
	client.preview_channel = true
	var releases := [
		{"tag_name": START, "assets": [{"name": Client.LEGACY_MANIFEST}]},
		{"tag_name": LARGE, "assets": [{"name": Client.LARGE_MANIFEST}]},
		{"tag_name": BRIDGE, "assets": [{"name": Client.LEGACY_MANIFEST}]},
	]
	check(client.select_release(releases) == LARGE, "Launcher 0.3 finds releases with the larger package manifest")
	check(client.manifest_file(releases[1]) == Client.LARGE_MANIFEST, "Large packages use their own discovery manifest")
	var large_entry := {"file": "RIFTCORE-%s.zip" % client.target_platform, "size": 600 * 1024 * 1024, "sha256": "a".repeat(64)}
	var large_update := {"tag": LARGE, "assets": {client.target_platform: large_entry}}
	check(not client.package_entry(large_update).is_empty(), "A 600 MiB download is valid")
	large_entry.size = Client.MAX_PACKAGE + 1
	check(client.package_entry(large_update).is_empty(), "Packages over 1 GiB still have a bounded rejection")
	client.free()
	var url := args[1]
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("fixture.json")))
	var first := create_launcher(manifest, url)
	check(first.busy and first.installed.is_empty() and first.play.disabled, "A fresh launcher begins installing on open")
	for attempt in 220:
		if not first.busy:
			break
		await create_timer(.025).timeout
	check(first.installed == BRIDGE and not first.play.disabled and first.client.newest_installed() == BRIDGE, "Verified automatic install unlocks Play")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.size.x >= 700 and first.size.x >= 700, "Launcher layout fills its window")
		root.get_texture().get_image().save_png(args[0].path_join("launcher.png"))
	first.queue_free()
	await process_frame
	var offline := create_launcher(null, "")
	check(offline.installed == BRIDGE and not offline.play.disabled and offline.update.visible, "Offline startup offers Play and Retry")
	offline.queue_free()
	await process_frame
	manifest.tag = LARGE
	manifest.assets.values()[0].sha256 = "f".repeat(64)
	var broken := create_launcher(manifest, url)
	for attempt in 220:
		if not broken.busy:
			break
		await create_timer(.025).timeout
	check(not broken.busy and broken.installed == BRIDGE and not broken.play.disabled and broken.update.visible,
		"A failed checksum keeps the installed game playable")
	broken.queue_free()
	await process_frame
	quit(failed)
