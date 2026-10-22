extends Node

var game: Node
var fails := 0

func _ready() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in range(4):
		await get_tree().physics_frame
	var tree: Node3D = game.get_node("Map/Trees/Tree003")
	var cross: Node3D = tree.get_node("CrossA")
	var flat: Node3D = tree.get_node("Flat")
	fails += _num(cross, "end", 34.0)
	fails += _num(cross, "end_margin", 4.0)
	fails += _num(flat, "begin", 27.0)
	fails += _num(flat, "begin_margin", 4.0)
	fails += _num(flat, "end", 110.0)
	fails += _num(flat, "end_margin", 20.0)
	if not flat.visible:
		print("FAIL flat not visible by default")
		fails += 1
	if not cross.visible:
		print("FAIL cross not visible by default")
		fails += 1
	if cross.shaded or flat.shaded:
		print("FAIL tree sprites shaded")
		fails += 1
	var tor: Node3D = game.get_node("Map/Trees/Tree010")
	var c2: Node3D = tor.get_node("CrossB")
	if c2.visibility_range_end != 34.0:
		print("FAIL CrossB range")
		fails += 1
	var na: Vector3 = cross.global_basis.z
	var tp: Vector3 = tree.global_position
	var nl: float = sqrt(na.x * na.x + na.z * na.z)
	game.player.global_position = Vector3(tp.x + na.x / nl * 4.0, tp.y + 2.0, tp.z + na.z / nl * 4.0)
	game._update_tree_sight()
	if not cross.visible:
		print("FAIL face-on crossA hidden")
		fails += 1
	var c2b: Node3D = tree.get_node("CrossB")
	var nb: Vector3 = c2b.global_basis.z
	var ml: float = sqrt(nb.x * nb.x + nb.z * nb.z)
	game.player.global_position = Vector3(tp.x + nb.x / ml * 4.0, tp.y + 2.0, tp.z + nb.z / ml * 4.0)
	game._update_tree_sight()
	if cross.visible or not c2b.visible:
		print("FAIL edge-on sides mismatched")
		fails += 1
	print("TREE LOD FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)

func _num(node: Node3D, key: String, expected: float) -> int:
	var got: float = node.get("visibility_range_" + key)
	if absf(got - expected) > 0.001:
		print("FAIL range ", key, " got ", got, " want ", expected)
		return 1
	return 0
