extends RefCounted

const ART := "res://assets/ui/steam/"
const SUFFIXES := {"cover": "p", "header": "", "hero": "_hero", "logo": "_logo", "icon": "_icon"}

static func apply(install_root: String) -> void:
	var raw := OS.get_environment("HOME")
	var roots := PackedStringArray()
	if OS.get_name() == "Windows":
		var args := PackedStringArray(["query", "HKCU\\Software\\Valve\\Steam", "/v", "SteamPath"])
		var output: Array = []
		if OS.execute("reg.exe", args, output) == 0 and not output.is_empty():
			for line in String(output[0]).split("\n"):
				if line.contains("REG_SZ"):
					roots.append(line.get_slice("REG_SZ", 1).strip_edges())
		for key in ["ProgramFiles(x86)", "ProgramFiles"]:
			var base := OS.get_environment(key)
			if not base.is_empty():
				roots.append(base.path_join("Steam"))
	elif OS.get_name() == "Linux" and not raw.is_empty():
		roots.append_array([raw.path_join(".steam/steam"), raw.path_join(".local/share/Steam"),
			raw.path_join(".var/app/com.valvesoftware.Steam/.local/share/Steam")])
		var data := OS.get_environment("XDG_DATA_HOME")
		if data.is_absolute_path():
			roots.append(data.path_join("Steam"))
	apply_roots(install_root, roots)

static func apply_roots(install_root: String, roots: PackedStringArray) -> void:
	var art := {}
	var install := normalized_path(install_root)
	for steam_root in roots:
		var users := steam_root.path_join("userdata")
		var directory := DirAccess.open(users)
		if directory == null:
			continue
		for account in directory.get_directories():
			if not account.is_valid_int():
				continue
			var config := users.path_join(account).path_join("config")
			for shortcut in read_shortcuts(config.path_join("shortcuts.vdf")):
				var path := normalized_path(shortcut.get("exe", ""))
				if not matches_install(path, install):
					continue
				var id: int = shortcut.get("appid", 0)
				if id >= 0x80000000:
					if art.is_empty():
						art = load_art()
					if not art.is_empty():
						fill_grid(config.path_join("grid"), str(id), art)

static func load_art() -> Dictionary:
	var art := {}
	for name in SUFFIXES:
		var extension := ".png" if name in ["logo", "icon"] else ".jpg"
		var texture := load(ART + name + extension) as Texture2D
		if texture == null:
			return {}
		art[name] = texture.get_image()
	return art

static func normalized_path(path: String) -> String:
	var result := path.strip_edges().trim_prefix('"').trim_suffix('"').replace("\\", "/").simplify_path()
	return result.to_lower() if OS.get_name() == "Windows" else result

static func matches_install(path: String, install: String) -> bool:
	var name := "RIFTCORE.exe" if OS.get_name() == "Windows" else "RIFTCORE"
	if OS.get_name() == "Windows":
		name = name.to_lower()
	if path == install.path_join(name) or (OS.get_name() == "Linux" and path == install.path_join("start-riftcore")):
		return true
	return path.get_file() == name and path.get_base_dir().get_base_dir() == install.path_join("versions")

static func fill_grid(grid: String, id: String, art: Dictionary) -> void:
	if DirAccess.make_dir_recursive_absolute(grid) != OK:
		return
	for name in SUFFIXES:
		var stem := grid.path_join(id + SUFFIXES[name])
		if [".png", ".jpg", ".jpeg", ".webp", ".gif"].any(func(ext): return FileAccess.file_exists(stem + ext)):
			continue
		if name in ["logo", "icon"]:
			art[name].save_png(stem + ".png")
		else:
			art[name].save_jpg(stem + ".jpg", 0.91)

static func read_shortcuts(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 8 * 1024 * 1024:
		return []
	var bytes := file.get_buffer(file.get_length())
	var pos := 0
	var depth := 0
	var entry := {}
	var result: Array[Dictionary] = []
	while pos < bytes.size():
		var kind := bytes[pos]
		pos += 1
		if kind == 8:
			if depth == 2:
				result.append(entry)
			depth -= 1
			if depth <= 0:
				return result
			continue
		var end := nul(bytes, pos)
		if end < 0:
			return []
		var key := bytes.slice(pos, end).get_string_from_utf8().to_lower()
		pos = end + 1
		match kind:
			0:
				if depth == 0 and key != "shortcuts":
					return []
				depth += 1
				if depth == 2:
					entry = {}
			1:
				end = nul(bytes, pos)
				if end < 0:
					return []
				if depth == 2 and key == "exe":
					entry[key] = bytes.slice(pos, end).get_string_from_utf8()
				pos = end + 1
			2:
				if pos + 4 > bytes.size():
					return []
				if depth == 2 and key == "appid":
					entry[key] = bytes.decode_u32(pos)
				pos += 4
			_:
				return []
	return []

static func nul(bytes: PackedByteArray, start: int) -> int:
	for index in range(start, bytes.size()):
		if bytes[index] == 0:
			return index
	return -1
