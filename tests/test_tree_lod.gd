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
	print("TREE LOD FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)

func _num(node: Node3D, key: String, expected: float) -> int:
	var got: float = node.get("visibility_range_" + key)
	if absf(got - expected) > 0.001:
		print("FAIL range ", key, " got ", got, " want ", expected)
		return 1
	return 0
