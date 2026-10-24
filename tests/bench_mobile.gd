extends Node

var game: Node
var rid: RID

func _ready() -> void:
	SettingsBus._mobile = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in range(120):
		await get_tree().process_frame
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = 2.0
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	print("BENCH viewport=%s scale=%.2f" % [str(get_viewport().get_visible_rect().size), get_viewport().scaling_3d_scale])
	var terrain = game.get_node("Map/Terrain")
	var trees = game.get_node("Map/Trees")
	await _measure("baseline")
	terrain.visible = false
	await _measure("no_terrain")
	terrain.visible = true
	trees.visible = false
	await _measure("no_trees")
	trees.visible = true
	game.env.fog_enabled = false
	await _measure("no_fog")
	game.env.fog_enabled = true
	game.env.background_mode = Environment.BG_COLOR
	game.env.background_color = Color(0.2, 0.2, 0.2)
	await _measure("no_sky")
	game.env.background_mode = Environment.BG_SKY
	get_viewport().msaa_3d = Viewport.MSAA_2X
	await _measure("msaa2")
	terrain.visible = false
	trees.visible = false
	game.env.fog_enabled = false
	game.env.background_mode = Environment.BG_COLOR
	await _measure("all_off")
	get_tree().quit()

func _measure(label: String) -> void:
	for i in range(30):
		await get_tree().process_frame
	var total := 0.0
	var count := 0
	var worst := 0.0
	var start := Time.get_ticks_usec()
	for i in range(120):
		await get_tree().process_frame
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
		if gpu > 0.0:
			total += gpu
			count += 1
			worst = maxf(worst, gpu)
	var wall := float(Time.get_ticks_usec() - start) / 1000000.0
	var avg := total / float(count) if count > 0 else 0.0
	print("BENCH %s gpu_avg=%.2f gpu_max=%.2f wall_fps=%.1f draws=%d prims=%d" % [label, avg, worst, 120.0 / wall, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
