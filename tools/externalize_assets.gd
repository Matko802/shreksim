extends SceneTree

const ASSETS_PATH := "res://assets/maps/terrain3d_assets.tres"
const OUT_DIR := "res://assets/textures/terrain3d/"


func src_path() -> String:
	var env := OS.get_environment("EXT_ASSETS_SRC")
	if env != "":
		return env
	return ASSETS_PATH


func needs_dump(p: String) -> bool:
	return p == "" or p.contains("ImageTexture") or p.contains("_orig_assets")


func slug(s: String) -> String:
	var out := ""
	for ch: String in s.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch == " " or ch == "-":
			if out.right(1) != "_" and not out.is_empty():
				out += "_"
	while out.right(1) == "_":
		out = out.left(out.length() - 1)
	return out


func dump(path: String) -> void:
	var assets := load(path) as Terrain3DAssets
	var n := 0
	for ta: Terrain3DTextureAsset in assets.get_texture_list():
		if ta == null:
			continue
		n += 1
		var base := "%02d_%s" % [n, slug(str(ta.get_name()))]
		for kind in ["albedo_texture", "normal_texture"]:
			var tex: Texture2D = ta.get(kind)
			if tex == null:
				print("slot %02d %s %s MISSING" % [n, str(ta.get_name()), kind])
				continue
			var p: String = tex.resource_path
			if not needs_dump(p):
				continue
			var img := tex.get_image()
			img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var fpath: String = OUT_DIR + base + "_" + kind + ".png"
			var werr: int = img.save_png(fpath)
			print("slot %02d %s %s src='%s' -> %s err=%d size=%s" % [n, str(ta.get_name()), kind, p, fpath, werr, img.get_size()])
	quit(0)


func link(path: String) -> void:
	var assets := load(path) as Terrain3DAssets
	var n := 0
	var replaced := 0
	for ta: Terrain3DTextureAsset in assets.get_texture_list():
		if ta == null:
			continue
		n += 1
		var base := "%02d_%s" % [n, slug(str(ta.get_name()))]
		for kind in ["albedo_texture", "normal_texture"]:
			var cur: Texture2D = ta.get(kind)
			if cur != null and not needs_dump(cur.resource_path):
				continue
			var fpath: String = OUT_DIR + base + "_" + kind + ".png"
			if not FileAccess.file_exists(fpath):
				continue
			var fresh: Texture2D = load(fpath)
			if fresh == null:
				continue
			ta.set(kind, fresh)
			replaced += 1
	var err: int = assets.save(ASSETS_PATH)
	var f := FileAccess.open(ASSETS_PATH, FileAccess.READ)
	print("saved=", err, " slots=", n, " replaced=", replaced, " bytes=", f.get_length())
	f.flush()
	f.seek(0)
	print("header=", f.get_line())


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR) or DirAccess.get_files_at(OUT_DIR.substr(6)).is_empty():
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
		dump(src_path())
	else:
		link(ASSETS_PATH)
	quit(0)
