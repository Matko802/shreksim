extends Node

func _ready() -> void:
	var menu = (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu._show_stats_panel()
	print("BEST=", menu.get_node("%BestLabel").text)
	print("PAGES=", menu.get_node("%PagesLabel").text)
	print("ESC=", menu.get_node("%EscLabel").text)
	get_tree().quit()
