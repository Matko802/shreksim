extends Node

var game: Node
var fails := 0

func _ready() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in range(60):
		await get_tree().physics_frame
	var terrain := game.get_node_or_null("Map/Terrain") as Terrain3D
	_check(terrain != null, "terrain missing")
	if terrain == null:
		_finish()
		return
	_check(game.get_node_or_null("Map/Ground") == null, "old ground still present")
	_check(terrain.data != null, "terrain data missing")
	if terrain.data == null:
		_finish()
		return
	_check(terrain.data.get_region_count() == 4, "region count %d" % terrain.data.get_region_count())
	_check(terrain.mesh_lods <= 5, "mesh lods %d" % terrain.mesh_lods)
	_check(terrain.mesh_size <= 32, "mesh size %d" % terrain.mesh_size)
	_check(terrain.tessellation_level == 0, "tessellation enabled")
	_check(terrain.collision_mode != 0, "terrain collision disabled")
	_check(terrain.cull_margin == 0.0, "cull margin %f" % terrain.cull_margin)

	var h0 := terrain.data.get_height(Vector3(0.0, 0.0, 0.0))
	_check(is_finite(h0) and absf(h0) < 0.1, "origin height %f" % h0)
	var h1 := terrain.data.get_height(Vector3(40.0, 0.0, -30.0))
	_check(is_finite(h1), "sample height not finite")

	game.player.global_position = Vector3(0.0, 20.0, 0.0)
	game.player.velocity = Vector3.ZERO
	for i in range(180):
		await get_tree().physics_frame
	var py: float = game.player.global_position.y
	var gy: float = game._terrain_height(game.player.global_position.x, game.player.global_position.z)
	_check(absf(py - gy) < 0.35, "player not on terrain: player=%f terrain=%f" % [py, gy])

	var tree := game.get_node_or_null("Map/Trees/Tree003") as Node3D
	_check(tree != null, "tree missing")
	if tree != null:
		var tg: float = game._terrain_height(tree.global_position.x, tree.global_position.z)
		_check(absf(tree.global_position.y - tg) < 0.05, "tree off terrain %f vs %f" % [tree.global_position.y, tg])

	var onions_off := 0
	for area in game.onions:
		var a := area as Area3D
		var ag: float = game._terrain_height(a.global_position.x, a.global_position.z)
		if absf(a.global_position.y - ag) > 0.05:
			onions_off += 1
	_check(onions_off == 0, "onions off terrain %d" % onions_off)
	_finish()

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: ", msg)
		fails += 1

func _finish() -> void:
	print("GROUND FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)
