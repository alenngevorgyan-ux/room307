extends SceneTree
## Tiles PNGs into contact sheets (headless):  godot --headless -s res://tools/contact_sheet.gd -- <dir> [cols] [per_sheet]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var cols := int(a[1]) if a.size() > 1 else 3
	var per := int(a[2]) if a.size() > 2 else 6
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png") and not f.begins_with("sheet_"):
			files.append(f)
	files.sort()
	var tw := 640
	var th := 360
	var n := 0
	while n * per < files.size():
		var chunk := files.slice(n * per, (n + 1) * per)
		var rows := int(ceil(chunk.size() / float(cols)))
		var sheet := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
		for i in chunk.size():
			var img := Image.load_from_file(dir.path_join(chunk[i]))
			img.convert(Image.FORMAT_RGB8)
			img.resize(tw, th, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
		sheet.save_jpg(dir.path_join("sheet_%d.jpg" % n), 0.85)
		print("sheet_%d: %s" % [n, ", ".join(chunk)])
		n += 1
	quit()
