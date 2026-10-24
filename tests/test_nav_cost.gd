extends Node

func _ready() -> void:
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in range(120):
		await get_tree().process_frame
	game.pages = 1
	for i in range(30):
		await get_tree().physics_frame
	var nav = game.nav
	if nav == null:
		print("NO NAV")
		get_tree().quit()
		return
	var t0 := Time.get_ticks_usec()
	for i in range(200):
		nav.find_path(Vector2(0, 0), Vector2(randf_range(-100, 100), randf_range(-100, 100)))
	var t1 := Time.get_ticks_usec()
	print("PATH avg_us=%.1f total_ms=%.1f" % [float(t1 - t0) / 200.0, float(t1 - t0) / 1000.0])
	t0 = Time.get_ticks_usec()
	game._build_nav()
	t1 = Time.get_ticks_usec()
	print("BUILD_NAV ms=%.1f" % [float(t1 - t0) / 1000.0])
	t0 = Time.get_ticks_usec()
	for i in range(200):
		nav.has_los(Vector2(0, 0), Vector2(randf_range(-100, 100), randf_range(-100, 100)))
	t1 = Time.get_ticks_usec()
	print("LOS avg_us=%.1f" % [float(t1 - t0) / 200.0])
	get_tree().quit()
