extends Node

func _ready() -> void:
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in range(60):
		await get_tree().process_frame
	var dbg = game.get_node("DebugMenu")
	dbg.visible = true
	dbg.set_process(true)
	Engine.max_fps = 2
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < 6000000:
		await get_tree().process_frame
		frames += 1
	var wall := float(Time.get_ticks_usec() - start) / 1000000.0
	print("DEBUGFPS wall_fps=%.2f engine_fps=%d" % [frames / wall, Engine.get_frames_per_second()])
	print("LABEL:")
	print(dbg.label.text)
	Engine.max_fps = 0
	get_tree().quit()
