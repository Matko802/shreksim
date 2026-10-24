extends Node

var game: Node
var fails := 0

func _ready() -> void:
	SettingsBus._mobile = false
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in range(60):
		await get_tree().physics_frame
	var terrain := game._terrain as Terrain3D
	_check(terrain != null, "terrain missing")
	if terrain == null:
		_finish()
		return
	_check(game.terrain_render_target != null, "terrain target missing")
	_check(terrain.clipmap_target == game.terrain_render_target, "clipmap target not render target")
	_check(terrain.collision_target == game.player, "collision target not player")
	_check(terrain.light_target == game.sun, "light target not sun")
	_check(game.player.head.physics_interpolation_mode == Node3D.PHYSICS_INTERPOLATION_MODE_OFF, "head interpolation must be off")
	_check(game.player.camera.physics_interpolation_mode == Node3D.PHYSICS_INTERPOLATION_MODE_OFF, "camera interpolation must be off")
	_check(game.player.footstep_player.physics_interpolation_mode == Node3D.PHYSICS_INTERPOLATION_MODE_OFF, "footstep interpolation must be off")
	_check(game.render_origin == Vector3.ZERO, "initial origin %s" % game.render_origin)

	game.player.set_physics_process(false)
	game.player.velocity = Vector3.ZERO

	game.player.global_position = Vector3(31.5, 0.0, -31.5)
	await _ticks(3)
	_check(game.render_origin == Vector3.ZERO, "origin shifted below cell %s" % game.render_origin)
	_check_close(game.terrain_render_target.global_position.x, 31.5, "target x below cell")
	_check_close(game.terrain_render_target.global_position.z, -31.5, "target z below cell")

	game.player.global_position = Vector3(32.5, 0.0, -31.5)
	await _ticks(3)
	_assert_origin(Vector3(32.0, 0.0, 0.0), "x cell")
	_check(game.player.render_offset == Vector3(-32.0, 0.0, 0.0), "player offset %s" % game.player.render_offset)
	_check_target_offset("x cell")
	_check_material_params("x cell")
	_check_onions("x cell")

	game.enemy_anchor.global_position = game.player.global_position + Vector3(0.0, 3.0, 0.0)
	game.enemy.visible = true
	await _ticks(2)
	_check_close(game.enemy.global_position.x, game.enemy_anchor.global_position.x - game.render_origin.x, "enemy x offset")
	_check_close(game.enemy.global_position.z, game.enemy_anchor.global_position.z - game.render_origin.z, "enemy z offset")

	game.player.global_position = Vector3(32.5, 0.0, -32.5)
	await _ticks(3)
	_assert_origin(Vector3(32.0, 0.0, -32.0), "z cell")
	_check_target_offset("z cell")
	_check_material_params("z cell")

	game.player.global_position = Vector3(-100.0, 0.0, 100.0)
	await _ticks(7)
	_check(absf(game.render_origin.x - game.player.global_position.x) < 32.0, "x catch-up %s" % game.render_origin)
	_check(absf(game.render_origin.z - game.player.global_position.z) < 32.0, "z catch-up %s" % game.render_origin)
	_check(absf(game.terrain_render_target.global_position.x) < 32.0, "target x out of cell")
	_check(absf(game.terrain_render_target.global_position.z) < 32.0, "target z out of cell")
	_check_target_offset("catch-up")

	await get_tree().process_frame
	await get_tree().process_frame
	var eye: Vector3 = game.player.camera.project_ray_origin(game._vsize() * 0.5) + game.render_origin
	_check_close(eye.x, game.player.global_position.x, "ray origin x", 0.05)
	_check_close(eye.z, game.player.global_position.z, "ray origin z", 0.05)
	_check_close(eye.y, game.player.global_position.y + 1.68, "ray origin y", 0.08)

	var orbit := 0.0
	var exercised := 0
	for i in range(80):
		game.player.rotate_y(0.05)
		await get_tree().process_frame
		var rendered_player: Transform3D = game.player.get_global_transform_interpolated()
		if absf(rendered_player.basis.get_euler().y - game.player.rotation.y) <= 0.001:
			continue
		exercised += 1
		game.player._apply_head_transform()
		rendered_player = game.player.get_global_transform_interpolated()
		var rendered_camera: Transform3D = rendered_player * game.player.head.transform
		var deviation := Vector2(
			rendered_camera.origin.x - rendered_player.origin.x + game.render_origin.x,
			rendered_camera.origin.z - rendered_player.origin.z + game.render_origin.z).length()
		orbit = maxf(orbit, deviation)
	_check(exercised > 0, "rotation interpolation not exercised")
	_check(orbit < 0.001, "camera orbits during rotation at origin %s: %f" % [game.render_origin, orbit])
	_finish()

func _assert_origin(expected: Vector3, label: String) -> void:
	_check(game.render_origin == expected, "%s origin %s want %s" % [label, game.render_origin, expected])

func _check_target_offset(label: String) -> void:
	var want := Vector3(
		game.player.global_position.x - game.render_origin.x,
		0.0,
		game.player.global_position.z - game.render_origin.z)
	_check(game.terrain_render_target.global_position.distance_to(want) < 0.001, "%s target %s want %s" % [label, game.terrain_render_target.global_position, want])

func _check_material_params(label: String) -> void:
	var terrain_mat := game._terrain.material as Terrain3DMaterial
	var param: Variant = terrain_mat.get_shader_param(&"render_origin")
	if param != null:
		_check(param == game.render_origin, "%s terrain param %s want %s" % [label, param, game.render_origin])
	for mat in game.far_tree_materials:
		_check(mat.get_shader_parameter("render_origin") == game.render_origin, "%s far tree param" % label)
	for mat in game.near_tree_materials:
		_check(mat.get_shader_parameter("render_origin") == game.render_origin, "%s near tree param" % label)

func _check_onions(label: String) -> void:
	for area in game.onion_visuals:
		var entry: Array = game.onion_sprites.get(area, [])
		_check(entry.size() == 2, "%s onion entry missing" % label)
		if entry.size() != 2:
			continue
		var sprite := entry[0] as Sprite3D
		var want: Vector3 = (area as Area3D).global_transform * (entry[1] as Vector3) - game.render_origin
		_check(sprite.top_level, "%s onion not top level" % label)
		_check(sprite.global_position.distance_to(want) < 0.001, "%s onion sprite %s want %s" % [label, sprite.global_position, want])

func _ticks(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame

func _check_close(a: float, b: float, label: String, tol := 0.001) -> void:
	_check(absf(a - b) <= tol, "%s: %f vs %f" % [label, a, b])

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: ", msg)
		fails += 1

func _finish() -> void:
	print("FLOATING ORIGIN FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)
