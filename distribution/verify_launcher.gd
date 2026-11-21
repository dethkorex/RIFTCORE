extends SceneTree

const Launcher := preload("res://launcher.gd")
const Client := preload("res://update_client.gd")
const START := "v6.3.25-preview"
const BRIDGE := "v6.3.27-preview"
const LARGE := "v6.4.0-preview"
const ROLLBACK := "v6.3.26-preview"

class TestClient extends "res://update_client.gd":
	var manifest: Variant
	var url := ""
	var another_instance := false
	func fetch_manifest() -> Variant:
		return manifest
	func release_url(_tag: String, filename: String) -> String:
		return url + "/" + filename
	func other_riftcore_running() -> bool:
		return another_instance or super.other_riftcore_running()

var failed := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, text: String) -> bool:
	print("PASS " if ok else "FAIL ", text)
	failed += int(not ok)
	return ok

func create_launcher(info: Variant, url: String, another_instance := false) -> Launcher:
	var launcher := preload("res://launcher.tscn").instantiate() as Launcher
	launcher.client.free()
	var fixture := TestClient.new()
	fixture.manifest = info
	fixture.url = url
	fixture.another_instance = another_instance
	launcher.client = fixture
	root.add_child(launcher)
	return launcher

func put_file(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("preserve or remove according to ownership")
	else:
		check(false, "Could not write fixture: " + path)

func install_cleanup_fixtures(base: String, binary: String) -> void:
	for folder in [START, Client.LEGACY_MIGRATION_TAG, ROLLBACK, "v6.3.24-preview"]:
		var executable := base.path_join("versions").path_join(folder).path_join(binary)
		put_file(executable)
		if OS.get_name() != "Windows":
			FileAccess.set_unix_permissions(executable, 493)
		put_file(executable.get_base_dir().path_join("RIFTCORE.pck"))
	for path in ["versions/v6.3.24-preview/.player-data",
		"versions/v6.3.21-preview-superseded-1/RIFTCORE.pck",
		"versions/v6.3.27-preview-install-42-1-incomplete/" + binary,
		"versions/v6.3.28-preview-install-42-2/RIFTCORE.pck",
		"versions/v6.5.0-preview/RIFTCORE.pck",
		"downloads/v6.3.28-preview-42-1.zip", "downloads/v6.3.27-preview-42-2.zip",
		"downloads/launcher-42-1/" + binary, "downloads/launcher-42-2/personal.zip",
		"downloads/personal.zip", "settings.cfg"]:
		put_file(base.path_join(path))

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
		check(first.play.get_global_rect().end.y <= first.size.y - 10.0, "The Play button stays visible under the description")
		root.get_texture().get_image().save_png(args[0].path_join("launcher.png"))
	var binary := first.client.game_filename
	first.queue_free()
	await process_frame
	var base := args[0]
	install_cleanup_fixtures(base, binary)
	var parallel := create_launcher(null, "", true)
	await process_frame
	check(DirAccess.dir_exists_absolute(base.path_join("versions").path_join(START)) and
		FileAccess.file_exists(base.path_join("downloads/v6.3.28-preview-42-1.zip")),
		"Another running copy delays cleanup")
	parallel.queue_free()
	await process_frame
	var offline := create_launcher(null, "")
	await process_frame
	check(offline.installed == BRIDGE and not offline.play.disabled and offline.update.visible, "Offline startup offers Play and Retry")
	for path in ["versions/" + START, "versions/" + Client.LEGACY_MIGRATION_TAG,
		"versions/v6.3.21-preview-superseded-1", "versions/v6.3.27-preview-install-42-1-incomplete",
		"versions/v6.3.28-preview-install-42-2", "downloads/v6.3.28-preview-42-1.zip",
		"downloads/v6.3.27-preview-42-2.zip", "downloads/launcher-42-1"]:
		check(not FileAccess.file_exists(base.path_join(path)) and not DirAccess.dir_exists_absolute(base.path_join(path)),
			"Retired managed path removed: " + path)
	for path in ["versions/" + BRIDGE + "/RIFTCORE.pck", "versions/" + ROLLBACK + "/RIFTCORE.pck",
		"versions/v6.3.24-preview/.player-data", "versions/v6.3.24-preview/RIFTCORE.pck",
		"versions/v6.5.0-preview/RIFTCORE.pck", "downloads/launcher-42-2/personal.zip", "downloads/personal.zip", "settings.cfg"]:
		check(FileAccess.file_exists(base.path_join(path)), "Protected file retained: " + path)
	if DirAccess.dir_exists_absolute(base.path_join("linked-sentinel")):
		check(DirAccess.dir_exists_absolute(base.path_join("versions/v6.3.20-preview")) and
			FileAccess.file_exists(base.path_join("linked-sentinel/RIFTCORE.pck")), "Linked version directory is untouched")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(offline.update.get_global_rect().end.y <= offline.size.y - 10.0, "The Retry update button stays visible offline")
	offline.queue_free()
	await process_frame
	manifest.tag = LARGE
	var valid_hash: String = manifest.assets.values()[0].sha256
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
	manifest.assets.values()[0].sha256 = valid_hash
	var upgraded := create_launcher(manifest, url)
	for attempt in 220:
		if not upgraded.busy:
			break
		await create_timer(.025).timeout
	check(upgraded.installed == LARGE and not upgraded.play.disabled, "A verified replacement becomes playable")
	check(FileAccess.get_file_as_string(base.path_join("versions/" + LARGE + "/RIFTCORE.pck")) == "Launcher verification fixture",
		"The new game uses the assets in the replacement package")
	check(FileAccess.file_exists(base.path_join("versions/" + BRIDGE + "/RIFTCORE.pck")) and
		not DirAccess.dir_exists_absolute(base.path_join("versions/" + ROLLBACK)), "Each update rotates the fallback")
	upgraded.queue_free()
	await process_frame
	quit(failed)
