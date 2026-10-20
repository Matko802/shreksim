extends Node

var game: Node

func _ready() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	print("PROBE start")
	game.player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.5).timeout
	print("PROBE fogoff done")
	game.env.fog_enabled = false
	await get_tree().create_timer(0.4).timeout
	print("PROBE fogoff2 done")
	game.env.fog_enabled = true
	print("PROBE walk")
	Input.action_press("move_forward")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("move_forward")
	game._collect(game.onions[0])
	game._apply_phase(2)
	await get_tree().create_timer(0.7).timeout
	print("PROBE phase3")
	game._apply_phase(3)
	await get_tree().create_timer(0.7).timeout
	print("PROBE phase4")
	game._apply_phase(4)
	await get_tree().create_timer(0.7).timeout
	game.enemy.global_position = Vector3(5000, 125, 5000)
	await get_tree().create_timer(0.3).timeout
	print("PROBE toggle off")
	game.player.toggle_flashlight()
	await get_tree().create_timer(0.3).timeout
	print("PROBE toggle on")
	game.player.toggle_flashlight()
	await get_tree().create_timer(0.5).timeout
	print("PROBE pause")
	game._toggle_pause()
	await get_tree().create_timer(0.8).timeout
	print("PROBE quit")
	get_tree().quit(0)
