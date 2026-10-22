extends Node

var fails := 0

func _ready() -> void:
	var bus: Node = get_node("/root/SettingsBus")
	if bus == null:
		print("FAIL: no SettingsBus")
		get_tree().quit(1)
		return
	var cfg := DirAccess.open("user://")
	if cfg != null and cfg.file_exists("settings.cfg"):
		cfg.remove("settings.cfg")
	bus.load_settings()
	bus.reset_settings()
	await get_tree().process_frame
	var root_vp: Viewport = get_tree().root
	if bus.anti_aliasing_mode != 2:
		print("FAIL: default aa ", bus.anti_aliasing_mode)
		fails += 1
	if root_vp.msaa_3d != Viewport.MSAA_2X:
		print("FAIL: boot msaa ", root_vp.msaa_3d)
		fails += 1
	bus.set_anti_aliasing_mode(5)
	if root_vp.use_taa != true or root_vp.msaa_3d != Viewport.MSAA_DISABLED:
		print("FAIL: taa apply taa=", root_vp.use_taa, " msaa=", root_vp.msaa_3d)
		fails += 1
	bus.set_anti_aliasing_mode(1)
	if root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA:
		print("FAIL: fxaa apply ", root_vp.screen_space_aa)
		fails += 1
	bus.set_vsync_enabled(false)
	if bus.vsync_enabled != false:
		print("FAIL: vsync setter")
		fails += 1
	bus.set_fps_limit(144)
	if Engine.max_fps != 144:
		print("FAIL: fps limit ", Engine.max_fps)
		fails += 1
	bus.set_fps_limit(360)
	if Engine.max_fps != 0:
		print("FAIL: unlimited fps ", Engine.max_fps)
		fails += 1
	bus.reset_settings()
	if bus.anti_aliasing_mode != 2 or root_vp.msaa_3d != Viewport.MSAA_2X:
		print("FAIL: reset aa")
		fails += 1
	if bus.fps_limit != 0 or Engine.max_fps != 0:
		print("FAIL: reset fps")
		fails += 1
	if bus.vsync_enabled != true:
		print("FAIL: reset vsync")
		fails += 1
	print("SETTINGS FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)
