extends SceneTree

const Client := preload("res://scripts/update_client.gd")

func _initialize() -> void:
	verify.call_deferred()

func verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var client := Client.new()
	root.add_child(client)
	client.install_root = args[1]
	var tag := "v5.9.2-preview"
	var folder := client.install_root.path_join("versions").path_join(tag)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		quit(1)
		return
	var incomplete := FileAccess.open(folder.path_join(client.game_filename), FileAccess.WRITE)
	if incomplete == null:
		quit(1)
		return
	incomplete.store_string("interrupted update")
	incomplete.close()
	var error := client.unpack_version(args[0], tag)
	if not error.is_empty():
		printerr(error)
		quit(1)
		return
	if client.newest_installed() != tag or FileAccess.get_size(folder.path_join("RIFTCORE.pck")) < 1000000:
		printerr("Package was not installed or selected.")
		quit(1)
		return
	error = client.unpack_version(args[0], tag)
	if not error.is_empty():
		printerr("Idempotent install failed: ", error)
		quit(1)
		return
	var install_test := OS.execute(folder.path_join(client.game_filename),
		PackedStringArray(["--headless", "--quit-after", "40", "--", "--verify-social"]), [], true)
	if install_test != 0:
		printerr("The updated executable could not start: ", install_test)
		quit(1)
		return
	print("UPDATE INSTALL PASS")
	quit()
