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
	if bus.quality_preset != 2 or absf(bus.render_distance - 200.0) > 0.001:
		print("FAIL: desktop quality defaults ", bus.quality_preset, " ", bus.render_distance)
		fails += 1
	if bus.anti_aliasing_mode != 0:
		print("FAIL: default aa ", bus.anti_aliasing_mode)
		fails += 1
	if root_vp.msaa_3d != Viewport.MSAA_DISABLED:
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
	var f11 := InputEventKey.new()
	f11.physical_keycode = KEY_F11
	f11.pressed = true
	bus._input(f11)
	if not bus.fullscreen_enabled:
		print("FAIL: F11 fullscreen")
		fails += 1
	bus._input(f11)
	if bus.fullscreen_enabled:
		print("FAIL: F11 windowed")
		fails += 1
	bus.reset_settings()
	if bus.anti_aliasing_mode != 0 or root_vp.msaa_3d != Viewport.MSAA_DISABLED:
		print("FAIL: reset aa")
		fails += 1
	if bus.fps_limit != 0 or Engine.max_fps != 0:
		print("FAIL: reset fps")
		fails += 1
	if bus.vsync_enabled != true:
		print("FAIL: reset vsync")
		fails += 1
	bus.set_render_scale(0.8)
	if absf(root_vp.scaling_3d_scale - 0.8) > 0.001:
		print("FAIL: desktop render scale apply ", root_vp.scaling_3d_scale)
		fails += 1
	var cfg3 := ConfigFile.new()
	cfg3.set_value("core", "version", 5)
	cfg3.set_value("video", "anti_aliasing_mode", 2)
	cfg3.set_value("video", "render_scale", 0.7)
	cfg3.save("user://settings.cfg")
	bus.load_settings()
	if bus.anti_aliasing_mode != 0 or root_vp.msaa_3d != Viewport.MSAA_DISABLED:
		print("FAIL: desktop migration aa ", bus.anti_aliasing_mode)
		fails += 1
	if absf(root_vp.scaling_3d_scale - 1.0) > 0.001:
		print("FAIL: desktop migration render scale ", root_vp.scaling_3d_scale)
		fails += 1
	bus._mobile = true
	var cfg2 := ConfigFile.new()
	cfg2.set_value("core", "version", 2)
	cfg2.set_value("video", "fps_limit", 60)
	cfg2.set_value("video", "anti_aliasing_mode", 1)
	cfg2.save("user://settings.cfg")
	bus.load_settings()
	if bus.fps_limit != 0:
		print("FAIL: mobile migration fps ", bus.fps_limit)
		fails += 1
	if bus.anti_aliasing_mode != 0 or root_vp.msaa_3d != Viewport.MSAA_DISABLED:
		print("FAIL: mobile migration aa ", bus.anti_aliasing_mode)
		fails += 1
	if absf(root_vp.scaling_3d_scale - 0.65) > 0.001:
		print("FAIL: mobile render scale ", root_vp.scaling_3d_scale)
		fails += 1
	if bus.quality_preset != 0 or absf(bus.render_distance - 64.0) > 0.001:
		print("FAIL: mobile quality defaults ", bus.quality_preset, " ", bus.render_distance)
		fails += 1
	bus.set_quality_preset(1)
	if bus.quality_preset != 1 or absf(root_vp.scaling_3d_scale - 0.8) > 0.001 or root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA:
		print("FAIL: medium preset ", bus.quality_preset, " ", root_vp.scaling_3d_scale, " ", root_vp.screen_space_aa)
		fails += 1
	bus.set_render_distance(96.0)
	if absf(bus.render_distance - 96.0) > 0.001:
		print("FAIL: render distance setter ", bus.render_distance)
		fails += 1
	bus.set_fps_limit(144)
	if bus.fps_limit != 144 or Engine.max_fps != 144:
		print("FAIL: mobile fps not uncapped ", bus.fps_limit, " ", Engine.max_fps)
		fails += 1
	bus.set_anti_aliasing_mode(3)
	if bus.anti_aliasing_mode != 3 or root_vp.msaa_3d != Viewport.MSAA_4X:
		print("FAIL: mobile aa option ", bus.anti_aliasing_mode)
		fails += 1
	if root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_DISABLED:
		print("FAIL: mobile msaa still fxaa ", root_vp.screen_space_aa)
		fails += 1
	bus.reset_settings()
	if bus.fps_limit != 0 or bus.anti_aliasing_mode != 0:
		print("FAIL: mobile reset")
		fails += 1
	if absf(root_vp.scaling_3d_scale - 0.65) > 0.001:
		print("FAIL: mobile reset render scale ", root_vp.scaling_3d_scale)
		fails += 1
	if bus.quality_preset != 0 or absf(bus.render_distance - 64.0) > 0.001:
		print("FAIL: mobile reset quality ", bus.quality_preset, " ", bus.render_distance)
		fails += 1
	var cleanup := DirAccess.open("user://")
	if cleanup != null and cleanup.file_exists("settings.cfg"):
		cleanup.remove("settings.cfg")
	bus._mobile = false
	bus.load_settings()
	if bus.quality_preset != 2 or absf(bus.render_distance - 200.0) > 0.001:
		print("FAIL: desktop reload quality ", bus.quality_preset, " ", bus.render_distance)
		fails += 1
	print("SETTINGS FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)
