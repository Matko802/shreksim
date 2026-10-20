extends Node

var game: Node

func _ready() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.enemy.global_position = Vector3(6000, 125, 6000)
	print("DEEP start phase=", game.phase)
	var stages := [0, 1, 2, 4, 6, 8]
	for s in stages:
		game._apply_phase(s)
		print("DEEP phase=", s)
		await get_tree().create_timer(1.6).timeout
	get_tree().quit(0)
