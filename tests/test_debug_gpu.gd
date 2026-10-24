extends Node

func _ready() -> void:
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in range(30):
		await get_tree().process_frame
	var dbg = game.get_node("DebugMenu")
	SettingsBus.set_debug_info(true)
	for i in range(20):
		await get_tree().process_frame
	print("LABEL:")
	print(dbg.label.text)
	get_tree().quit()
