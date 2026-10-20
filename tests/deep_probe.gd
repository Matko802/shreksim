extends Node

var game: Node
var count := 0
var applied := 0
var stages: Array[int] = [0, 1, 2, 4, 6, 8]

func _ready() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.enemy.global_position = Vector3(6000, 125, 6000)
	print("DEEP start")

func _process(_delta: float) -> void:
	count += 1
	if count % 60 != 1:
		return
	if applied >= stages.size():
		if count > stages.size() * 60 + 30:
			print("DEEP done")
			get_tree().quit(0)
		return
	game._apply_phase(stages[applied])
	game._lerp_phase(1.0)
	print("DEEP phase=", stages[applied])
	applied += 1
