class_name EnemyNav
extends RefCounted

const CELL := 2.0
const GRID_SIZE := 128
const WORLD_HALF := 128.0
const WALL_MARGIN := 3.0
const PERC_MARGIN := 0.6

var blocked := PackedByteArray()
var clearance := PackedFloat32Array()
var _seen := PackedInt32Array()
var _g_cost := PackedFloat32Array()
var _came := PackedInt32Array()
var _stamp := 0
var _heap_id := PackedInt32Array()
var _heap_p := PackedFloat32Array()

func build(tree_pts_x: PackedFloat32Array, tree_pts_y: PackedFloat32Array, tree_radii: PackedFloat32Array) -> void:
	blocked.resize(GRID_SIZE * GRID_SIZE)
	blocked.fill(0)
	for k in range(tree_pts_x.size()):
		var cx := tree_pts_x[k]
		var cz := tree_pts_y[k]
		var r := tree_radii[k] + PERC_MARGIN
		var gx := maxi(int(floor((cx - r + WORLD_HALF) / CELL)), 0)
		var gz := maxi(int(floor((cz - r + WORLD_HALF) / CELL)), 0)
		var gx_end := mini(int(ceil((cx + r + WORLD_HALF) / CELL)), GRID_SIZE)
		var gz_end := mini(int(ceil((cz + r + WORLD_HALF) / CELL)), GRID_SIZE)
		for ix in range(gx, gx_end):
			for iz in range(gz, gz_end):
				var wxc := (float(ix) + 0.5) * CELL - WORLD_HALF
				var wzc := (float(iz) + 0.5) * CELL - WORLD_HALF
				if (wxc - cx) * (wxc - cx) + (wzc - cz) * (wzc - cz) < r * r:
					blocked[iz * GRID_SIZE + ix] = 1
	var border := int(WALL_MARGIN / CELL)
	for ix in range(GRID_SIZE):
		for iz in range(GRID_SIZE):
			if ix < border or iz < border or ix >= GRID_SIZE - border or iz >= GRID_SIZE - border:
				blocked[iz * GRID_SIZE + ix] = 1
	_build_clearance(tree_pts_x, tree_pts_y)

func _build_clearance(tree_pts_x: PackedFloat32Array, tree_pts_y: PackedFloat32Array) -> void:
	var n := GRID_SIZE * GRID_SIZE
	clearance.resize(n)
	clearance.fill(1e9)
	for k in range(tree_pts_x.size()):
		var cx := tree_pts_x[k]
		var cz := tree_pts_y[k]
		var gx := maxi(int(floor((cx - 10.0 + WORLD_HALF) / CELL)), 0)
		var gz := maxi(int(floor((cz - 10.0 + WORLD_HALF) / CELL)), 0)
		var gx_end := mini(int(ceil((cx + 10.0 + WORLD_HALF) / CELL)), GRID_SIZE)
		var gz_end := mini(int(ceil((cz + 10.0 + WORLD_HALF) / CELL)), GRID_SIZE)
		for ix in range(gx, gx_end):
			for iz in range(gz, gz_end):
				var wxc := (float(ix) + 0.5) * CELL - WORLD_HALF
				var wzc := (float(iz) + 0.5) * CELL - WORLD_HALF
				var d := sqrt((wxc - cx) * (wxc - cx) + (wzc - cz) * (wzc - cz))
				var i := iz * GRID_SIZE + ix
				if d < clearance[i]:
					clearance[i] = d
	var diag := CELL * 1.4142
	for iz in range(GRID_SIZE):
		for ix in range(GRID_SIZE):
			var i := iz * GRID_SIZE + ix
			var d := clearance[i]
			if ix > 0:
				d = minf(d, clearance[i - 1] + CELL)
				if iz > 0:
					d = minf(d, clearance[i - GRID_SIZE - 1] + diag)
				if iz < GRID_SIZE - 1:
					d = minf(d, clearance[i + GRID_SIZE - 1] + diag)
			if iz > 0:
				d = minf(d, clearance[i - GRID_SIZE] + CELL)
			clearance[i] = d
	for iz in range(GRID_SIZE - 1, -1, -1):
		for ix in range(GRID_SIZE - 1, -1, -1):
			var i := iz * GRID_SIZE + ix
			var d := clearance[i]
			if ix < GRID_SIZE - 1:
				d = minf(d, clearance[i + 1] + CELL)
				if iz < GRID_SIZE - 1:
					d = minf(d, clearance[i + GRID_SIZE + 1] + diag)
				if iz > 0:
					d = minf(d, clearance[i - GRID_SIZE + 1] + diag)
			if iz < GRID_SIZE - 1:
				d = minf(d, clearance[i + GRID_SIZE] + CELL)
			clearance[i] = d

func _is_free_w(wx: float, wz: float) -> bool:
	if absf(wx) > WORLD_HALF - WALL_MARGIN or absf(wz) > WORLD_HALF - WALL_MARGIN:
		return false
	var ix := clampi(int((wx + WORLD_HALF) / CELL), 0, GRID_SIZE - 1)
	var iz := clampi(int((wz + WORLD_HALF) / CELL), 0, GRID_SIZE - 1)
	return blocked[iz * GRID_SIZE + ix] == 0

func _nearest_free_cell(ix: int, iz: int) -> int:
	if blocked[iz * GRID_SIZE + ix] == 0:
		return iz * GRID_SIZE + ix
	for r in range(1, 7):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var nx := ix + dx
				var nz := iz + dz
				if nx < 0 or nz < 0 or nx >= GRID_SIZE or nz >= GRID_SIZE:
					continue
				if blocked[nz * GRID_SIZE + nx] == 0:
					return nz * GRID_SIZE + nx
	return -1

func _ensure_workspace() -> void:
	var n := GRID_SIZE * GRID_SIZE
	if _seen.size() == n:
		return
	_seen.resize(n)
	_seen.fill(0)
	_g_cost.resize(n)
	_came.resize(n)
	_stamp = 0

func find_path(from_w: Vector2, to_w: Vector2) -> PackedVector2Array:
	var start := _nearest_free_cell(clampi(int((from_w.x + WORLD_HALF) / CELL), 0, GRID_SIZE - 1), clampi(int((from_w.y + WORLD_HALF) / CELL), 0, GRID_SIZE - 1))
	var goal := _nearest_free_cell(clampi(int((to_w.x + WORLD_HALF) / CELL), 0, GRID_SIZE - 1), clampi(int((to_w.y + WORLD_HALF) / CELL), 0, GRID_SIZE - 1))
	if start < 0 or goal < 0:
		return PackedVector2Array()
	if start == goal:
		if _is_free_w(to_w.x, to_w.y):
			return PackedVector2Array([to_w])
		return PackedVector2Array([_cell_world(start)])
	_ensure_workspace()
	_stamp += 1
	if _stamp >= 2147483647:
		_seen.fill(0)
		_stamp = 1
	_seen[start] = _stamp
	_g_cost[start] = 0.0
	_came[start] = -1
	_heap_id.resize(0)
	_heap_p.resize(0)
	_heap_id.append(start)
	_heap_p.append(0.0)
	var goal_x := goal % GRID_SIZE
	var goal_z := goal / GRID_SIZE
	var found := false
	while _heap_id.size() > 0:
		var root_p := _heap_p[0]
		var cur := _heap_id[0]
		if _heap_id.size() > 1:
			_heap_id[0] = _heap_id[_heap_id.size() - 1]
			_heap_p[0] = _heap_p[_heap_id.size() - 1]
		_heap_id.resize(_heap_id.size() - 1)
		_heap_p.resize(_heap_p.size() - 1)
		var sift := 0
		while true:
			var l_child := sift * 2 + 1
			var r_child := l_child + 1
			var sm := sift
			if l_child < _heap_id.size() and _heap_p[l_child] < _heap_p[sm]:
				sm = l_child
			if r_child < _heap_id.size() and _heap_p[r_child] < _heap_p[sm]:
				sm = r_child
			if sm == sift:
				break
			var ti := _heap_id[sift]
			var tp := _heap_p[sift]
			_heap_id[sift] = _heap_id[sm]
			_heap_p[sift] = _heap_p[sm]
			_heap_id[sm] = ti
			_heap_p[sm] = tp
			sift = sm
		if cur == goal:
			found = true
			break
		var cx := cur % GRID_SIZE
		var cz := cur / GRID_SIZE
		var hx0 := absf(float(goal_x - cx))
		var hz0 := absf(float(goal_z - cz))
		var f_cur := _g_cost[cur] + hx0 + hz0 - 0.5858 * minf(hx0, hz0)
		if root_p > f_cur + 0.0001:
			continue
		for dir_n in range(8):
			var nx := cx
			var nz := cz
			var diag := false
			match dir_n:
				0:
					nx += 1
				1:
					nx -= 1
				2:
					nz += 1
				3:
					nz -= 1
				4:
					nx += 1
					nz += 1
					diag = true
				5:
					nx += 1
					nz -= 1
					diag = true
				6:
					nx -= 1
					nz += 1
					diag = true
				7:
					nx -= 1
					nz -= 1
					diag = true
			if nx < 0 or nz < 0 or nx >= GRID_SIZE or nz >= GRID_SIZE:
				continue
			var ni := nz * GRID_SIZE + nx
			if blocked[ni] != 0:
				continue
			if diag and (blocked[cz * GRID_SIZE + nx] != 0 or blocked[nz * GRID_SIZE + cx] != 0):
				continue
			var step := 1.0 if not diag else 1.4142
			var ng := _g_cost[cur] + step
			if _seen[ni] == _stamp and ng >= _g_cost[ni]:
				continue
			_seen[ni] = _stamp
			_g_cost[ni] = ng
			_came[ni] = cur
			var hx := absf(float(goal_x - nx))
			var hz := absf(float(goal_z - nz))
			var heur := hx + hz - 0.5858 * minf(hx, hz)
			_heap_id.append(ni)
			_heap_p.append(ng + heur)
			var child := _heap_id.size() - 1
			while child > 0:
				var par := (child - 1) / 2
				if _heap_p[child] >= _heap_p[par]:
					break
				var ti := _heap_id[child]
				var tp := _heap_p[child]
				_heap_id[child] = _heap_id[par]
				_heap_p[child] = _heap_p[par]
				_heap_id[par] = ti
				_heap_p[par] = tp
				child = par
	if not found:
		return PackedVector2Array()
	var cells := PackedInt32Array()
	var walk := goal
	while walk != -1:
		cells.append(walk)
		walk = _came[walk]
	cells.reverse()
	var raw := PackedVector2Array()
	for i in range(1, cells.size()):
		raw.append(_cell_world(cells[i]))
	raw.append(to_w if _is_free_w(to_w.x, to_w.y) else _cell_world(goal))
	return _smooth(raw, from_w)

func _cell_world(i: int) -> Vector2:
	var row := int(float(i) / float(GRID_SIZE))
	return Vector2((float(i % GRID_SIZE) + 0.5) * CELL - WORLD_HALF, (float(row) + 0.5) * CELL - WORLD_HALF)

func _walk_line_clear(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := maxi(int(dist / (CELL * 0.4)) + 1, 1)
	for i in range(1, steps):
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		if not _is_free_w(p.x, p.y):
			return false
	return true

func _smooth(raw: PackedVector2Array, start: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cur := start
	var i := 0
	while i < raw.size():
		var far_idx := i
		for j in range(raw.size() - 1, i, -1):
			if _walk_line_clear(cur, raw[j]):
				far_idx = j
				break
		out.append(raw[far_idx])
		cur = raw[far_idx]
		i = far_idx + 1
	return out

func has_los(a_w: Vector2, b_w: Vector2) -> bool:
	var dist := a_w.distance_to(b_w)
	var steps := maxi(int(dist / 0.8) + 1, 1)
	for i in range(1, steps):
		var t := float(i) / float(steps)
		var px := a_w.x + (b_w.x - a_w.x) * t
		var pz := a_w.y + (b_w.y - a_w.y) * t
		if not _is_free_w(px, pz):
			return false
	return true

func spawn_clearance(a_w: Vector2, b_w: Vector2) -> float:
	var dist := a_w.distance_to(b_w)
	if dist <= 0.001:
		return float(WORLD_HALF)
	var steps := maxi(int(dist / 0.8) + 1, 1)
	var best := dist
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var px := a_w.x + (b_w.x - a_w.x) * t
		var pz := a_w.y + (b_w.y - a_w.y) * t
		if absf(px) > WORLD_HALF - WALL_MARGIN or absf(pz) > WORLD_HALF - WALL_MARGIN:
			return 0.0
		var ix := clampi(int((px + WORLD_HALF) / CELL), 0, GRID_SIZE - 1)
		var iz := clampi(int((pz + WORLD_HALF) / CELL), 0, GRID_SIZE - 1)
		var d := clearance[iz * GRID_SIZE + ix]
		if d < best:
			best = d
	return best

func is_free_point(w: Vector2) -> bool:
	return _is_free_w(w.x, w.y)
