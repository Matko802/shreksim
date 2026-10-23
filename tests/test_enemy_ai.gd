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
		print("ENEMY AI FAILS=", fails)
		get_tree().quit(1)
		return
	var nav = game.nav
	var trunk: Node3D = game.get_node("Map/Trees/Tree003")
	if not nav.is_free_point(Vector2(0.0, 0.0)):
		print("FAIL: origin marked blocked")
		fails += 1
	if nav.is_free_point(Vector2(trunk.global_position.x + 0.4, trunk.global_position.z)):
		print("FAIL: tree interior marked free")
		fails += 1
	var start_pt: Vector2 = Vector2(game.player.global_position.x, game.player.global_position.z)
	var path_v: PackedVector2Array = nav.find_path(start_pt, Vector2(start_pt.x + 40.0, start_pt.y + 40.0))
	if path_v.size() == 0:
		print("FAIL: empty path")
		fails += 1
	for wp in path_v:
		if not nav.is_free_point(wp) or absf(wp.x) > 124.0 or absf(wp.y) > 124.0:
			print("FAIL: invalid waypoint ", wp)
			fails += 1
	var trunk_vec: Vector2 = Vector2(trunk.global_position.x, trunk.global_position.z)
	if nav.has_los(trunk_vec, trunk_vec + Vector2(0.8, 0.8)) != false:
		print("FAIL: los through trunk")
		fails += 1
	print("hunt phase")
	var waited := 0
	while waited < 120 and game.enemy_mode != "hunt":
		await get_tree().physics_frame
		waited += 1
	if game.enemy_mode != "hunt":
		print("FAIL: no hunt, mode=", game.enemy_mode)
		fails += 1
	print("hidden phase")
	var epos2: Vector2 = Vector2(game.enemy.global_position.x, game.enemy.global_position.z)
	var back := Vector2(cos(game.enemy_yaw), sin(game.enemy_yaw))
	var hide_pos: Vector2 = epos2 - back * 50.0
	hide_pos.x = clampf(hide_pos.x, -120.0, 120.0)
	hide_pos.y = clampf(hide_pos.y, -120.0, 120.0)
	game.player.global_position = Vector3(hide_pos.x, game._terrain_height(hide_pos.x, hide_pos.y) + 2.0, hide_pos.y)
	waited = 0
	var entered_retreat := false
	var retreat_visible := true
	while waited < 1200:
		await get_tree().physics_frame
		waited += 1
		if game.enemy_mode == "retreat":
			entered_retreat = true
			if not game.enemy.visible:
				retreat_visible = false
		if game.enemy_mode == "wander":
			break
	if game.enemy_mode != "wander":
		print("FAIL: never wandered, mode=", game.enemy_mode)
		fails += 1
	if not entered_retreat:
		print("FAIL: never retreated")
		fails += 1
	if not retreat_visible:
		print("FAIL: retreat was invisible")
		fails += 1
	var ep: Vector3 = Vector3(game.enemy.global_position.x, game.enemy.global_position.y, game.enemy.global_position.z)
	for i in range(600):
		await get_tree().physics_frame
	var moved: float = (game.enemy.global_position - ep).length()
	if moved < 2.0:
		print("FAIL: enemy not moving in wander, moved=", moved)
		fails += 1
	print("ENEMY AI FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)
