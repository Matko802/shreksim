extends SceneTree

const SIDES := 1095
const HALF := 547


func _initialize() -> void:
	var scn := load("res://scenes/map.tscn") as PackedScene
	var map := scn.instantiate()
	root.add_child(map)
	for i in range(8):
		await process_frame
	var t: Terrain3D = map.get_node("Terrain")
	var data := t.data
	var sh := HeightMapShape3D.new()
	sh.map_width = SIDES
	sh.map_depth = SIDES
	var arr := PackedFloat32Array()
	arr.resize(SIDES * SIDES)
	var mn := 1e9
	var mx := -1e9
	var in_mn := 1e9
	var in_mx := -1e9
	var nan_count := 0
	for j in range(SIDES):
		var z := clampf(j - HALF, -545.5, 543.5)
		var row := j * SIDES
		for i in range(SIDES):
			var x := clampf(i - HALF, -255.9, 255.9)
			var h := data.get_height(Vector3(x, 0, clampf(z, -255.9, 255.9)))
			if is_nan(h):
				h = 0.0
				nan_count += 1
			arr[row + i] = h
			mn = minf(mn, h)
			mx = maxf(mx, h)
			if absf(x) < 127.9 and absf(z) < 127.9:
				in_mn = minf(in_mn, h)
				in_mx = maxf(in_mx, h)
	sh.map_data = arr
	print("span_min=", mn, " span_max=", mx, " fence_min=", in_mn, " fence_max=", in_mx, " nan_clamped=", nan_count)
	var err := ResourceSaver.save(sh, "res://assets/maps/terrain_collision.res", ResourceSaver.FLAG_COMPRESS)
	var f := FileAccess.open("res://assets/maps/terrain_collision.res", FileAccess.READ)
	print("saved=", err, " bytes=", f.get_length())
	quit(0)
