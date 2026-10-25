extends Node

var game: Node
var fails := 0

func _ready() -> void:
	SettingsBus._mobile = false
	SettingsBus.set_quality_preset(2)
	SettingsBus.set_render_distance(200.0)
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in range(60):
		await get_tree().physics_frame
	var terrain := game._terrain as Terrain3D
	_check(terrain != null, "terrain missing")
	if terrain == null:
		_finish()
		return
	_check(game.terrain_target != null, "terrain target missing")
	_check(terrain.clipmap_target == game.terrain_target, "clipmap target not terrain target")
	_check(terrain.collision_target == game.player, "collision target not player")
	_check(terrain.light_target == game.sun, "light target not sun")
	_check(game.player.footstep_player.position == Vector3.ZERO, "footstep offset %s" % game.player.footstep_player.position)
	_check_close(game.player.camera.far, 200.0, "camera far")
	_check(game.env.fog_mode == Environment.FOG_MODE_DEPTH, "fog mode not depth")
	_check_close(game.env.fog_depth_end, 150.0, "fog edge at 200")
	_check_close(game.env.fog_density, 1.0, "fog not opaque at edge")
	_check_close(game.env.fog_depth_begin, 150.0 * 0.85, "day fog begins too early", 0.5)
	_check(game.env.fog_depth_begin < game.env.fog_depth_end, "fog begin past edge")
	_check(game.fog_wall_materials.size() == 8, "fog wall layers %d" % game.fog_wall_materials.size())
	for mat in game.fog_wall_materials:
		_check(mat.get_shader_parameter("fog_color") != null, "fog wall color missing")
		_check(float(mat.get_shader_parameter("opacity")) > 0.5, "fog wall too faint")
		_check(float(mat.get_shader_parameter("wall_height")) >= 30.0, "fog wall too short")

	for mat in game.far_tree_materials:
		_check(mat.get_shader_parameter("render_origin") == null, "far tree still has render_origin")
	for mat in game.near_tree_materials:
		_check(mat.get_shader_parameter("render_origin") == null, "near tree still has render_origin")

	SettingsBus.set_render_distance(96.0)
	await get_tree().process_frame
	_check_close(game.player.camera.far, 96.0, "camera far after change")
	_check_close(game.env.fog_depth_end, 96.0, "fog edge after change")
	for mat in game.far_tree_materials:
		_check_close(float(mat.get_shader_parameter("tree_far")), 96.0, "far tree cull after change")
		_check_close(float(mat.get_shader_parameter("tree_near")), 21.12, "far tree near after change")
	for mat in game.near_tree_materials:
		_check_close(float(mat.get_shader_parameter("tree_near")), 21.12, "near tree cull after change")
	SettingsBus.set_render_distance(200.0)
	await get_tree().process_frame
	_check_close(game.player.camera.far, 200.0, "camera far restored")
	_check_close(game.env.fog_depth_end, 150.0, "fog edge restored")
	var retreat_target: Vector2 = game._pick_retreat_target()
	var player_flat := Vector2(game.player.global_position.x, game.player.global_position.z)
	_check(retreat_target.distance_to(player_flat) >= 100.0, "retreat target too close: %s" % retreat_target)
	_check(absf(retreat_target.x) <= game.WORLD_HALF - game.WALL_SAFE + 0.01, "retreat target past wall x")
	_check(absf(retreat_target.y) <= game.WORLD_HALF - game.WALL_SAFE + 0.01, "retreat target past wall z")
	_check(game.ENEMY_RETREAT_SPEED >= 25.0, "retreat not fast")

	var terrain_node := game.get_node("Map/Terrain") as Node3D
	var terrain_xform := terrain_node.global_transform
	var trees := game.get_node_or_null("Map/Trees") as Node3D
	var trees_xform := trees.global_transform if trees != null else Transform3D.IDENTITY

	game.player.set_physics_process(false)
	game.player.velocity = Vector3.ZERO
	game.player.global_position = Vector3(96.0, 0.0, -96.0)
	game.player.rotation.y = 1.1
	for i in range(4):
		await get_tree().physics_frame
	_check_close(game.terrain_target.global_position.x, game.player.global_position.x, "target x")
	_check_close(game.terrain_target.global_position.z, game.player.global_position.z, "target z")
	_check(terrain_node.global_transform == terrain_xform, "terrain moved")
	if trees != null:
		_check(trees.global_transform == trees_xform, "trees moved")

	game.enemy_anchor.global_position = game.player.global_position + Vector3(0.0, 3.0, -6.0)
	game.enemy.visible = true
	await get_tree().physics_frame
	_check_close(game.enemy.global_position.x, game.enemy_anchor.global_position.x, "enemy x offset")
	_check_close(game.enemy.global_position.z, game.enemy_anchor.global_position.z, "enemy z offset")

	for area in game.get_node("Map/OnionSpots").get_children():
		if not area is Area3D:
			continue
		var sprite := (area as Area3D).get_node_or_null("Sprite") as Sprite3D
		if sprite != null:
			_check(not sprite.top_level, "onion sprite is still top level")

	await get_tree().process_frame
	await get_tree().process_frame
	var rendered_camera: Transform3D = game.player.camera.get_global_transform_interpolated()
	_check_close(rendered_camera.origin.x, game.player.global_position.x, "camera x offset", 0.02)
	_check_close(rendered_camera.origin.z, game.player.global_position.z, "camera z offset", 0.02)
	var eye: Vector3 = game.player.camera.project_ray_origin(game._vsize() * 0.5)
	_check_close(eye.x, game.player.global_position.x, "ray origin x", 0.05)
	_check_close(eye.z, game.player.global_position.z, "ray origin z", 0.05)
	_check_close(eye.y, game.player.global_position.y + 1.68, "ray origin y", 0.08)
	_finish()

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	fails += 1
	print("FAIL: ", message)

func _check_close(value: float, expected: float, label: String, tolerance: float = 0.001) -> void:
	_check(absf(value - expected) <= tolerance, "%s %f want %f" % [label, value, expected])

func _finish() -> void:
	print("WORLD SPACE FAILS=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
