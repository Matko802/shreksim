extends Node

var game: Node
var fails := 0

func _ready() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in range(4):
		await get_tree().physics_frame
	var tree: Node3D = game.get_node("Map/Trees/Tree003")
	var pos: Vector3 = tree.global_position
	var player: Node3D = game.player
	player.global_position = Vector3(pos.x, pos.y + 2.0, pos.z + 1.0)
	for i in range(40):
		await get_tree().physics_frame
	fails += _check("near", tree, true)
	player.global_position = Vector3(pos.x, pos.y + 2.0, pos.z + 50.0)
	for i in range(40):
		await get_tree().physics_frame
	fails += _check("far", tree, false)
	print("TREE LOD FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)

func _check(tag: String, tree: Node3D, want_cross: bool) -> int:
	var a: Node3D = tree.get_node("CrossA")
	var b: Node3D = tree.get_node("CrossB")
	var flat: Node3D = tree.get_node("Flat")
	if a.visible != want_cross or b.visible != want_cross or flat.visible == want_cross:
		print("FAIL ", tag, " crossA=", a.visible, " crossB=", b.visible, " flat=", flat.visible, " want_cross=", want_cross)
		return 1
	return 0
