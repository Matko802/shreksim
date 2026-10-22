extends SceneTree

const OUT_DIR := "res://assets/maps/terrain3d/"
const ASSETS_PATH := "res://assets/maps/terrain3d_assets.tres"
const MATERIAL_PATH := "res://assets/maps/terrain3d_material.tres"
const TERRAIN_PATH := "res://assets/maps/terrain_data.tres"
const GRID_N := 241
const HALF_W := 256.0
const SPACING: float = 512.0 / 240.0
const DIRT_ID := 2
const GROUND_TINT := Color(0.5, 0.68, 0.4, 1.0)

const SLOT_DEFS: Array = [
	["Swamp Grass", "res://assets/textures/terrain_grass.png", true],
	["Grass Top", "res://assets/textures/godotcraft/grass_top.png", false],
	["Dirt", "res://assets/textures/godotcraft/dirt.png", false],
	["Stone", "res://assets/textures/godotcraft/stone.png", false],
	["Sand", "res://assets/textures/godotcraft/Sand.png", false],
	["Wood Top", "res://assets/textures/godotcraft/oak_wood_top.png", false],
	["Wood Side", "res://assets/textures/godotcraft/oak_wood_side.png", false],
	["Bedrock", "res://assets/textures/godotcraft/bedrock.png", false],
	["Obsidian", "res://assets/textures/godotcraft/obsidian.png", false],
]

const PATH_WPTS: Array = [
	Vector2(0, 0), Vector2(34, -20), Vector2(70, -42), Vector2(98, -14),
	Vector2(62, 18), Vector2(26, 40), Vector2(66, 64), Vector2(98, 90),
	Vector2(58, 110), Vector2(12, 86), Vector2(-30, 58), Vector2(-64, 28),
	Vector2(-42, 2), Vector2(-72, -28), Vector2(-98, -54), Vector2(-62, -82),
	Vector2(-18, -64), Vector2(26, -76), Vector2(68, -90), Vector2(96, -72),
]

const PATH_CORE := 1.15
const PATH_EDGE := 2.9
const TRAIL_STEP := 1.2

static func rot_bits(gx: int, gz: int) -> int:
	return (((gx + 128) * 31 + (gz + 128) * 17) / 4) % 4 << 10

static func ctl_base(gx: int, gz: int) -> int:
	return rot_bits(gx, gz)

static func ctl_path(gx: int, gz: int, blend: int) -> int:
	return (DIRT_ID << 22) | (blend << 14) | rot_bits(gx, gz)

func _mid(k: int) -> float:
	return (float(k) + 0.5) * SPACING

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

func _init() -> void:
	var container: Resource = load(TERRAIN_PATH)
	var heights: PackedFloat32Array = container.get("heights") as PackedFloat32Array
	if int(container.get("grid_size")) != GRID_N or heights.size() != GRID_N * GRID_N:
		push_error("unexpected terrain data shape")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var world := Node3D.new()
	get_root().add_child(world)
	var t := Terrain3D.new()
	t.region_size = Terrain3D.SIZE_128
	t.vertex_spacing = SPACING
	world.add_child(t)
	for i in 8:
		await process_frame
	var data := t.get("data") as Terrain3DData
	if data == null:
		push_error("terrain data did not initialize")
		quit(1)
		return
	var v_min := data.world_to_vgrid(Vector3(_mid(-120), 0.0, _mid(-120)))
	var v_max := data.world_to_vgrid(Vector3(_mid(120), 0.0, _mid(120)))
	print("vgrid corners: ", v_min, " ", v_max)
	if v_min.x != -120 or v_min.y != -120 or v_max.x != 120 or v_max.y != 120:
		push_error("vertex spacing lattice drift")
		quit(1)
		return
	for ry in [-1, 0]:
		for rx in [-1, 0]:
			data.add_region_blank(Vector2i(rx, ry), true)
	var touched: Dictionary = {}
	var samples := _path_samples()
	print("path samples: ", samples.size())
	for p: Vector2 in samples:
		var cf := p / SPACING
		var cx := int(floor(cf.x))
		var cz := int(floor(cf.y))
		var cell_r := int(ceil(PATH_EDGE / SPACING)) + 1
		for gz in range(cz - cell_r, cz + cell_r + 1):
			for gx in range(cx - cell_r, cx + cell_r + 1):
				var dv := p.distance_to(Vector2(_mid(gx), _mid(gz)))
				if dv > PATH_EDGE:
					continue
				var key := Vector2i(gx, gz)
				var got := float(touched.get(key, 1e7))
				if dv < got:
					touched[key] = dv
	print("path touched lattice: ", touched.size())
	for gz in range(-128, 128):
		for gx in range(-128, 128):
			var idx := clampi(gx + 120, 0, 240)
			var jdx := clampi(gz + 120, 0, 240)
			var wp := Vector3(_mid(gx), 0.0, _mid(gz))
			data.set_height(wp, heights[jdx * GRID_N + idx])
			if not touched.has(Vector2i(gx, gz)):
				data.set_control(wp, ctl_base(gx, gz))
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
		var wp := Vector3(_mid(key.x), 0.0, _mid(key.y))
		data.set_control(wp, ctl_path(key.x, key.y, blend))
		painted += 1
	print("path painted lattice: ", painted)
	for probe: Vector3 in [Vector3(-256, 0, -256), Vector3(0, 0, 0), Vector3(256, 0, 256), Vector3(64.3, 0, -19.1)]:
		var nk := int(roundf((probe.x - 0.5 * SPACING) / SPACING))
		var nl := int(roundf((probe.z - 0.5 * SPACING) / SPACING))
		var near := Vector3(_mid(nk), 0.0, _mid(nl))
		print("height at ", near, " -> ", data.get_height(near))
	print("texture id path start: ", data.get_texture_id(Vector3(_mid(0), 0.0, _mid(0))))
	print("texture id off path: ", data.get_texture_id(Vector3(_mid(-94), 0.0, _mid(-94))))
	print("regions active: ", data.get_regions_active())
	_build_assets(t)
	data.save_directory(OUT_DIR)
	print("region files: ", DirAccess.get_files_at(OUT_DIR).size())
	var assets := t.get("assets") as Terrain3DAssets
	var assets_save: int = assets.save(ASSETS_PATH)
	print("assets save err: ", assets_save)
	var mat := t.get("material") as Terrain3DMaterial
	if mat == null:
		mat = Terrain3DMaterial.new()
		t.set_material(mat)
	print("material save err: ", ResourceSaver.save(mat, MATERIAL_PATH))
	print("assets count: ", assets.get_texture_count())
	world.free()
	quit()

func _build_assets(t: Terrain3D) -> void:
	var assets := Terrain3DAssets.new()
	var list: Array[Terrain3DTextureAsset] = []
	for def: Array in SLOT_DEFS:
		var ta := Terrain3DTextureAsset.new()
		ta.set_asset_name(String(def[0]))
		ta.set_albedo_texture(load(String(def[1])))
		ta.set_uv_scale(1.0)
		if bool(def[2]):
			ta.set_albedo_color(GROUND_TINT)
		list.append(ta)
	assets.set_texture_list(list)
	t.set_assets(assets)
	assets.update_texture_list()
