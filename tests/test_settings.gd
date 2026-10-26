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
	if bus.master_volume != 1.0 or bus.music_volume != 1.0 or bus.sfx_volume != 1.0:
		print("FAIL: default volumes ", bus.master_volume, " ", bus.music_volume, " ", bus.sfx_volume)
		fails += 1
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			print("FAIL: missing audio bus ", bus_name)
			fails += 1
	bus.set_master_volume(0.5)
	bus.set_music_volume(0.25)
	bus.set_sfx_volume(0.0)
	if absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")) - linear_to_db(0.5)) > 0.01:
		print("FAIL: master volume db")
		fails += 1
	if absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.25)) > 0.01:
		print("FAIL: music volume db")
		fails += 1
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")):
		print("FAIL: sfx zero not muted")
		fails += 1
	bus.reset_settings()
	if bus.master_volume != 1.0 or bus.music_volume != 1.0 or bus.sfx_volume != 1.0:
		print("FAIL: volume reset")
		fails += 1
	if AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")):
		print("FAIL: sfx still muted")
		fails += 1
	var bus_player := AudioStreamPlayer.new()
	bus_player.stream = load("res://assets/sounds/music_title.ogg")
	add_child(bus_player)
	await get_tree().process_frame
	await get_tree().process_frame
	if bus_player.bus != &"Music":
		print("FAIL: music player bus ", bus_player.bus)
		fails += 1
	bus_player.queue_free()
	if bus.quality_preset != 2 or absf(bus.render_distance - 200.0) > 0.001:
		print("FAIL: desktop quality defaults ", bus.quality_preset, " ", bus.render_distance)
		fails += 1
	if bus.anti_aliasing_mode != 1 or root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA:
		print("FAIL: default aa ", bus.anti_aliasing_mode, " ", root_vp.screen_space_aa)
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
	if bus.anti_aliasing_mode != 1 or root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA:
		print("FAIL: reset aa ", bus.anti_aliasing_mode, " ", root_vp.screen_space_aa)
		fails += 1
	if bus.render_distance != 200.0 or absf(root_vp.scaling_3d_scale - 1.0) > 0.001:
		print("FAIL: reset quality values ", bus.render_distance, " ", root_vp.scaling_3d_scale)
		fails += 1
	if bus.fps_limit != 0 or Engine.max_fps != 0:
		print("FAIL: reset fps")
		fails += 1
	if bus.vsync_enabled != true:
		print("FAIL: reset vsync")
		fails += 1
	bus.set_anti_aliasing_mode(0)
	if bus.anti_aliasing_mode != 0 or root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_DISABLED:
		print("FAIL: desktop off aa ", bus.anti_aliasing_mode, " ", root_vp.screen_space_aa)
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
	if bus.anti_aliasing_mode != 1 or root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA:
		print("FAIL: desktop migration aa ", bus.anti_aliasing_mode)
		fails += 1
	if absf(root_vp.scaling_3d_scale - 1.0) > 0.001:
		print("FAIL: desktop migration render scale ", root_vp.scaling_3d_scale)
		fails += 1
	if bus.render_distance != 200.0:
		print("FAIL: desktop migration distance ", bus.render_distance)
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
	if bus.anti_aliasing_mode != 1 or root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA:
		print("FAIL: mobile migration aa ", bus.anti_aliasing_mode, " ", root_vp.screen_space_aa)
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
	if absf(bus.render_distance - 128.0) > 0.001:
		print("FAIL: medium preset distance ", bus.render_distance)
		fails += 1
	bus.set_quality_preset(2)
	if bus.quality_preset != 2 or absf(root_vp.scaling_3d_scale - 1.0) > 0.001 or root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA:
		print("FAIL: high preset ", bus.quality_preset, " ", root_vp.scaling_3d_scale, " ", root_vp.screen_space_aa)
		fails += 1
	if absf(bus.render_distance - 200.0) > 0.001:
		print("FAIL: high preset distance ", bus.render_distance)
		fails += 1
	bus.set_quality_preset(0)
	if bus.quality_preset != 0 or absf(root_vp.scaling_3d_scale - 0.65) > 0.001 or root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA:
		print("FAIL: low preset ", bus.quality_preset, " ", root_vp.scaling_3d_scale, " ", root_vp.screen_space_aa)
		fails += 1
	if absf(bus.render_distance - 64.0) > 0.001:
		print("FAIL: low preset distance ", bus.render_distance)
		fails += 1
	bus.set_quality_preset(1)
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
	bus.set_anti_aliasing_mode(0)
	if bus.anti_aliasing_mode != 1 or root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA:
		print("FAIL: mobile forced fxaa ", bus.anti_aliasing_mode, " ", root_vp.screen_space_aa)
		fails += 1
	bus.reset_settings()
	if bus.fps_limit != 0 or bus.anti_aliasing_mode != 1:
		print("FAIL: mobile reset")
		fails += 1
	if root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA:
		print("FAIL: mobile reset aa ", root_vp.screen_space_aa)
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
	if bus.anti_aliasing_mode != 1 or root_vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_FXAA or absf(root_vp.scaling_3d_scale - 1.0) > 0.001:
		print("FAIL: desktop reload graphics ", bus.anti_aliasing_mode, " ", root_vp.screen_space_aa, " ", root_vp.scaling_3d_scale)
		fails += 1
	bus._mobile = true
	var pause_menu := (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
	add_child(pause_menu)
	await get_tree().process_frame
	if pause_menu._aa_modes.has(0) or not pause_menu._aa_modes.has(1):
		print("FAIL: mobile aa list ", pause_menu._aa_modes)
		fails += 1
	if pause_menu.aa_option.item_count != 4:
		print("FAIL: mobile aa option count ", pause_menu.aa_option.item_count)
		fails += 1
	for i in pause_menu.aa_option.item_count:
		if pause_menu.aa_option.get_item_text(i) == "Off":
			print("FAIL: mobile aa still lists Off")
			fails += 1
	if pause_menu.settings_tabs == null or pause_menu.tab_buttons.size() != 3:
		print("FAIL: settings tabs missing")
		fails += 1
	if pause_menu.master_slider == null or pause_menu.music_slider == null or pause_menu.sfx_slider == null:
		print("FAIL: volume sliders missing")
		fails += 1
	else:
		pause_menu._select_tab(1)
		if not pause_menu.audio_page.visible or pause_menu.video_page.visible:
			print("FAIL: audio tab not shown")
			fails += 1
		pause_menu.master_slider.value = 40.0
		pause_menu.music_slider.value = 30.0
		pause_menu.sfx_slider.value = 20.0
		if absf(bus.master_volume - 0.4) > 0.001 or absf(bus.music_volume - 0.3) > 0.001 or absf(bus.sfx_volume - 0.2) > 0.001:
			print("FAIL: volume sliders ", bus.master_volume, " ", bus.music_volume, " ", bus.sfx_volume)
			fails += 1
		pause_menu._select_tab(0)
		if not pause_menu.video_page.visible or pause_menu.audio_page.visible:
			print("FAIL: video tab not shown")
			fails += 1
	pause_menu.queue_free()
	bus.reset_settings()
	var final_cleanup := DirAccess.open("user://")
	if final_cleanup != null and final_cleanup.file_exists("settings.cfg"):
		final_cleanup.remove("settings.cfg")
	print("SETTINGS FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)
