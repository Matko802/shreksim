extends Node

var game: Node
var fails := 0

func _ready() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in range(60):
		await get_tree().physics_frame
	var trees: Node3D = game.get_node("Map/Trees")
	_check(game.far_instances.size() == 554, "far instances %d" % game.far_instances.size())
	_check(game.near_instances.size() == 354, "near instances %d" % game.near_instances.size())
	_check(game.player.camera.far >= 200.0, "camera far %f" % game.player.camera.far)
	var batches := 0
	for c in trees.get_children():
		if c is MultiMeshInstance3D:
			batches += 1
	_check(batches == 6, "batches %d" % batches)
	for m in game.far_tree_materials:
		_check(is_equal_approx(float(m.get_shader_parameter("tree_far")), 150.0), "far cull")
		_check(is_equal_approx(float(m.get_shader_parameter("tree_near")), 32.0), "far near")
	for m in game.near_tree_materials:
		_check(is_equal_approx(float(m.get_shader_parameter("tree_near")), 32.0), "near cull")
	var tree: Node3D = trees.get_node("Tree003")
	_check(tree.get_node_or_null("CrossA") == null, "source sprite not freed")
	_check(game.far_instances.has(tree), "Tree003 not in far batch")
	_check(game.near_instances.has(tree), "Tree003 not in near batch")
	var buried := 0
	for c in game.far_instances.keys():
		var t: Transform3D = game.far_instances[c][2]
		var wp: Vector3 = trees.global_transform * t.origin
		var h: float = t.basis.get_scale().y
		var g: float = game._terrain_height(wp.x, wp.z)
		if wp.y - h * 0.5 < g - 0.05:
			buried += 1
	_check(buried == 0, "buried %d" % buried)
	var onions_off := 0
	for spot in game.get_node("Map/OnionSpots").get_children():
		var area := spot as Area3D
		var sprite := area.get_node_or_null("Sprite") as Sprite3D
		if sprite == null:
			continue
		var box := sprite.get_aabb()
		var center: Vector3 = sprite.global_transform * box.get_center()
		var height := box.size.y * sprite.global_basis.y.length()
		var ground: float = game._terrain_height(area.global_position.x, area.global_position.z)
		if absf(center.y - height * 0.5 - ground) > 0.02:
			onions_off += 1
		if absf(area.global_position.y - ground) > 0.02:
			onions_off += 1
	_check(onions_off == 0, "onions off ground %d" % onions_off)
	print("TREE LOD FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: ", msg)
		fails += 1
