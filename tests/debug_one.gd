extends Node

func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://swampsim_stats.cfg")
	print("loaded stats: ", cfg.get_value("stats", "pages", 0), " / ", cfg.get_value("stats", "escapes", 0))
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	game._collect(game.onions[0])
	await get_tree().process_frame
	print("music: ", game.music, " stream: ", game.music.stream if game.music else null, " playing: ", game.music.playing if game.music else "n/a")
	for i in range(3, 8):
		game._collect(game.onions[i])
		await get_tree().process_frame
	print("pages: ", game.pages)
	print("fog actual: ", game.env.fog_density, " expect: ", game.PHASES[4]["fog"], " equal: ", absf(game.env.fog_density - game.PHASES[4]["fog"]) < 0.0001)
	print("phase sky actual: ", game.env.background_color, " expect: ", game.PHASES[4]["sky"])
	get_tree().quit()
