extends SceneTree

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		quit(2)
		return
	var svg := FileAccess.get_file_as_string(arguments[0])
	var file := FileAccess.open(arguments[1], FileAccess.WRITE)
	var icon := Image.new()
	if not file or icon.load_svg_from_string(svg) != OK:
		quit(1)
		return
	var sizes := [16, 32, 48, 64, 128, 256]
	var chunks: Array[PackedByteArray] = []
	for dimension in sizes:
		var frame := icon.duplicate() as Image
		frame.resize(dimension, dimension, Image.INTERPOLATE_LANCZOS)
		chunks.append(frame.save_png_to_buffer())
	file.store_16(0)
	file.store_16(1)
	file.store_16(sizes.size())
	var offset := 6 + 16 * sizes.size()
	for index in range(sizes.size()):
		var dimension: int = sizes[index] % 256
		var length := chunks[index].size()
		file.store_8(dimension)
		file.store_8(dimension)
		file.store_16(0)
		file.store_16(1)
		file.store_16(32)
		file.store_32(length)
		file.store_32(offset)
		offset += length
	for chunk in chunks:
		file.store_buffer(chunk)
	file.close()
	quit()
