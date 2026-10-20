extends Node

var game: Node

func _ready() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.3).timeout
	game._die(true)
	print("CAUGHT SETUP")
	await get_tree().create_timer(3.5).timeout
	get_tree().quit(0)
