extends Node

var game: Node
var fails := 0

func _ready() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in range(4):
		await get_tree().physics_frame
	game.pages = 1
	for i in range(12):
		await get_tree().physics_frame
	if not game.enemy_active or game.nav == null:
		print("FAIL: enemy/nav not active")
		fails += 1
		_finish()
		return
	var nav = game.nav
	var trunk: Node3D = game.get_node("Map/Trees/Tree003")
	_check(nav.is_free_point(Vector2(0.0, 0.0)), "origin marked blocked")
	_check(not nav.is_free_point(Vector2(trunk.global_position.x + 0.4, trunk.global_position.z)), "tree interior marked free")
	var start_pt: Vector2 = Vector2(game.player.global_position.x, game.player.global_position.z)
	var path_v: PackedVector2Array = nav.find_path(start_pt, Vector2(start_pt.x + 40.0, start_pt.y + 40.0))
	_check(path_v.size() > 0, "empty path")
	for wp in path_v:
		if not nav.is_free_point(wp) or absf(wp.x) > 124.0 or absf(wp.y) > 124.0:
			_check(false, "invalid waypoint %s" % str(wp))
	var trunk_vec: Vector2 = Vector2(trunk.global_position.x, trunk.global_position.z)
	_check(not nav.has_los(trunk_vec, trunk_vec + Vector2(0.8, 0.8)), "los through trunk")

	_check(game.enemy_mode == "hunt", "first spawn not hunting: %s" % game.enemy_mode)
	_check(game.enemy.visible, "first spawn invisible")
	var first := _enemy_offset()
	_check(first.length() >= 18.0 and first.length() <= 26.0, "first spawn distance %f" % first.length())
	_check(first.normalized().dot(_front()) > 0.3, "first spawn not in front")

	var epos2: Vector2 = Vector2(game.enemy.global_position.x, game.enemy.global_position.z)
	var back := Vector2(cos(game.enemy_yaw), sin(game.enemy_yaw))
	var hide_pos: Vector2 = epos2 - back * 50.0
	hide_pos.x = clampf(hide_pos.x, -120.0, 120.0)
	hide_pos.y = clampf(hide_pos.y, -120.0, 120.0)
	game.player.global_position = Vector3(hide_pos.x, game._terrain_height(hide_pos.x, hide_pos.y) + 2.0, hide_pos.y)

	var waited := 0
	var entered_retreat := false
	var retreat_visible := true
	var fade_dropped := false
	var retreat_start := Vector2.ZERO
	while waited < 1200:
		await get_tree().physics_frame
		waited += 1
		if game.enemy_mode == "retreat":
			if not entered_retreat:
				entered_retreat = true
				retreat_start = Vector2(game.enemy.global_position.x, game.enemy.global_position.z)
			if not game.enemy.visible:
				retreat_visible = false
			if game.enemy_fade < 0.95:
				fade_dropped = true
		if game.enemy_mode == "hidden":
			break
	_check(entered_retreat, "never retreated")
	_check(retreat_visible, "retreat was invisible")
	_check(fade_dropped, "retreat did not fade")
	_check(game.enemy_mode == "hidden", "never hid: %s" % game.enemy_mode)
	_check(not game.enemy.visible, "hidden enemy visible")
	var retreat_moved: float = Vector2(game.enemy.global_position.x, game.enemy.global_position.z).distance_to(retreat_start)
	_check(retreat_moved > 15.0, "retreat moved only %f" % retreat_moved)

	for i in range(300):
		await get_tree().physics_frame
	_check(game.enemy_mode == "hidden", "respawned on a timer: %s" % game.enemy_mode)

	var onion: Area3D = game.onions[0] if not game.onions.is_empty() else null
	_check(onion != null, "no onion available")
	if onion != null:
		game._collect(onion)
		for i in range(4):
			await get_tree().physics_frame
		_check(game.enemy_mode == "hunt", "onion did not respawn enemy: %s" % game.enemy_mode)
		_check(game.enemy.visible, "respawned enemy invisible")
		var rel := _enemy_offset()
		_check(rel.length() >= 18.0 and rel.length() <= 26.0, "respawn distance %f" % rel.length())
		_check(rel.normalized().dot(_front()) > 0.3, "respawn not in front")
	_finish()

func _enemy_offset() -> Vector2:
	return Vector2(game.enemy.global_position.x - game.player.global_position.x, game.enemy.global_position.z - game.player.global_position.z)

func _front() -> Vector2:
	var fwd: Vector3 = -game.player.camera.global_basis.z
	return Vector2(fwd.x, fwd.z).normalized()

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: ", msg)
		fails += 1

func _finish() -> void:
	print("ENEMY AI FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)
