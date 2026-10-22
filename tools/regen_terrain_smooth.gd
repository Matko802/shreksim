extends SceneTree

const OUT_DIR := "res://assets/maps/terrain3d/"
const TERRAIN_PATH := "res://assets/maps/terrain_data.tres"
const OLD_N := 241
const NEW_SPACING := 1.0
const NEW_N := 513
const NEW_HALF := 256.0
const REGION_SIZE := 128
const DIRT_ID := 2
const PATH_CORE := 1.15
const PATH_EDGE := 2.9
const TRAIL_STEP := 1.2

const PATH_WPTS: Array = [
	Vector2(0, 0), Vector2(34, -20), Vector2(70, -42), Vector2(98, -14),
	Vector2(62, 18), Vector2(26, 40), Vector2(66, 64), Vector2(98, 90),
	Vector2(58, 110), Vector2(12, 86), Vector2(-30, 58), Vector2(-64, 28),
	Vector2(-42, 2), Vector2(-72, -28), Vector2(-98, -54), Vector2(-62, -82),
	Vector2(-18, -64), Vector2(26, -76), Vector2(68, -90), Vector2(96, -72),
]


static func rot_bits(gx: int, gz: int) -> int:
	return (((gx + 256) * 31 + (gz + 256) * 17) / 4) % 4 << 10


static func ctl_base(gx: int, gz: int) -> int:
	return rot_bits(gx, gz)


static func ctl_path(gx: int, gz: int, blend: int) -> int:
	return (DIRT_ID << 22) | (blend << 14) | rot_bits(gx, gz)


func _path_samples() -> Array:
	var pts: Array = []
	var w: Array = PATH_WPTS
	pts.append(w[0])
	for k in range(1, w.size() - 1):
		var p0: Vector2 = w[k - 1]
		var p1: Vector2 = w[k]
		var p2: Vector2 = w[k + 1]
		var p3: Vector2 = p2 + (p2 - p1)
		if k + 2 < w.size():
			p3 = w[k + 2]
		var steps := maxi(2, int(ceil(p1.distance_to(p2) / TRAIL_STEP)))
		for st in range(steps):
			var u := float(st) / float(steps)
			var u2 := u * u
			var u3 := u2 * u
			pts.append(p1 + 0.5 * (-p0 + p2) * u + 0.5 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + 0.5 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)
	pts.append(w[0])
	pts.append(w[w.size() - 1])
	return pts


func _old_h(heights: PackedFloat32Array, n: int, half: float, x: float, z: float) -> float:
	var step: float = (half * 2.0) / float(n - 1)
	var fx := clampf((x + half) / step, 0.0, float(n - 1))
	var fz := clampf((z + half) / step, 0.0, float(n - 1))
	var ix := mini(int(floor(fx)), n - 2)
	var iz := mini(int(floor(fz)), n - 2)
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	var h00 := heights[iz * n + ix]
	var h10 := heights[iz * n + ix + 1]
	var h01 := heights[(iz + 1) * n + ix]
	var h11 := heights[(iz + 1) * n + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _init() -> void:
	var container: Resource = load(TERRAIN_PATH)
	var src_heights: PackedFloat32Array = container.get("heights") as PackedFloat32Array
	var src_n: int = int(container.get("grid_size"))
	var src_half: float = float(container.get("grid_half"))
	if src_heights.size() != src_n * src_n or (src_n != OLD_N and src_n != NEW_N):
		push_error("unexpected terrain data shape")
		quit(1)
		return
	var world := Node3D.new()
	get_root().add_child(world)
	var t := Terrain3D.new()
	t.vertex_spacing = NEW_SPACING
	world.add_child(t)
	for i in 8:
		await process_frame
	var data := t.get("data") as Terrain3DData
	if data == null:
		push_error("terrain data did not initialize")
		quit(1)
		return
	var v0 := data.world_to_vgrid(Vector3(-120, 0, -120))
	var v1 := data.world_to_vgrid(Vector3(120, 0, 120))
	print("region size: ", t.get_region_size(), " spacing: ", t.get_vertex_spacing())
	print("vgrid corners: ", v0, " ", v1)
	if absf(v0.x - (-120.0)) > 0.001 or absf(v1.y - 120.0) > 0.001:
		push_error("vertex spacing lattice drift")
		quit(1)
		return
	for ry in [-1, 0]:
		for rx in [-1, 0]:
			data.add_region_blank(Vector2i(rx, ry), true)
	var samples := _path_samples()
	print("path samples: ", samples.size())
	var touched: Dictionary = {}
	for p: Vector2 in samples:
		var cx := int(floor(p.x))
		var cz := int(floor(p.y))
		var cell_r := int(ceil(PATH_EDGE / NEW_SPACING)) + 1
		for gz in range(cz - cell_r, cz + cell_r + 1):
			for gx in range(cx - cell_r, cx + cell_r + 1):
				var dv := p.distance_to(Vector2(float(gx) + 0.5, float(gz) + 0.5))
				if dv > PATH_EDGE:
					continue
				var key := Vector2i(gx, gz)
				var got := float(touched.get(key, 1e7))
				if dv < got:
					touched[key] = dv
	print("path touched lattice: ", touched.size())
	var set_calls := 0
	for gz in range(-256, 256):
		for gx in range(-256, 256):
			var wp := Vector3(float(gx), 0.0, float(gz))
			data.set_height(wp, _old_h(src_heights, src_n, src_half, float(gx), float(gz)))
			if not touched.has(Vector2i(gx, gz)):
				data.set_control(wp, ctl_base(gx, gz))
			set_calls += 1
	var painted := 0
	for key: Vector2i in touched.keys():
		var d := float(touched[key])
		if d >= PATH_EDGE:
			continue
		var blend := 255
		if d > PATH_CORE:
			var un := clampf((d - PATH_CORE) / (PATH_EDGE - PATH_CORE), 0.0, 1.0)
			blend = int(round(255.0 * (1.0 - un * un * (3.0 - 2.0 * un))))
			if blend <= 0:
				continue
		var wp := Vector3(float(key.x), 0.0, float(key.y))
		data.set_control(wp, ctl_path(key.x, key.y, blend))
		painted += 1
	print("set calls: ", set_calls, " path painted: ", painted)
	for probe: Vector2 in [Vector2(0, 0), Vector2(10, 10), Vector2(-200.5, 88.5), Vector2(255.5, 255.5)]:
		print("height ", probe, " -> ", data.get_height(Vector3(probe.x, 0.0, probe.y)))
	print("texture id at path: ", data.get_texture_id(Vector3(0, 0, 0)))
	print("texture id off path: ", data.get_texture_id(Vector3(-94, 0, -94)))
	print("regions active: ", data.get_regions_active())
	for f in DirAccess.get_files_at(OUT_DIR.substr(6)):
		DirAccess.remove_absolute(OUT_DIR.substr(6) + "/" + f)
	data.save_directory(OUT_DIR)
	print("region files: ", DirAccess.get_files_at(OUT_DIR.substr(6)).size())
	world.free()
	if src_n != NEW_N:
		var new_heights := PackedFloat32Array()
		new_heights.resize(NEW_N * NEW_N)
		for j in NEW_N:
			for i in NEW_N:
				new_heights[j * NEW_N + i] = _old_h(src_heights, src_n, src_half, float(i) - NEW_HALF, float(j) - NEW_HALF)
		container.set("heights", new_heights)
		container.set("grid_size", NEW_N)
		var terr_res: int = ResourceSaver.save(container, TERRAIN_PATH)
		print("terrain_data save err: ", terr_res)
	quit(0)
