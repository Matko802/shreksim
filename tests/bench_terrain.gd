extends Node

var game: Node
var terrain: Terrain3D
var mat: Terrain3DMaterial
var current_shader: Shader
var lite_shader: Shader

func _ready() -> void:
	SettingsBus._mobile = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(3840, 2160)
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in range(120):
		await get_tree().process_frame
	terrain = game.get_node("Map/Terrain")
	mat = terrain.material as Terrain3DMaterial
	current_shader = mat.shader_override
	lite_shader = load("res://scripts/mobile_terrain_lite.gdshader") as Shader
	game.get_node("Map/Trees").visible = false
	game.env.background_mode = Environment.BG_COLOR
	game.env.background_color = Color(0.1, 0.1, 0.1)
	game.env.fog_enabled = false
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = 2.0
	print("BENCH window=%s viewport=%s scale=%.2f" % [str(get_window().size), str(get_viewport().get_visible_rect().size), get_viewport().scaling_3d_scale])
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await _measure("current")
	_set_shader(lite_shader)
	await _measure("lite")
	_set_shader(current_shader)
	await _measure("current_again")
	terrain.visible = false
	await _measure("no_terrain")
	terrain.visible = true
	get_viewport().msaa_3d = Viewport.MSAA_2X
	await _measure("current_msaa2")
	_set_shader(lite_shader)
	await _measure("lite_msaa2")
	get_tree().quit()

func _set_shader(s: Shader) -> void:
	mat.shader_override = s
	mat.shader_override_enabled = true
	mat.update()

func _measure(label: String) -> void:
	for i in range(30):
		await get_tree().process_frame
	var rid: RID = get_viewport().get_viewport_rid()
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
	print("TERRAIN %s gpu_avg=%.2f gpu_max=%.2f wall_fps=%.1f draws=%d prims=%d" % [label, avg, worst, 120.0 / wall, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
