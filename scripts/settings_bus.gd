extends Node

signal setting_changed(setting_name: StringName, value: Variant)

const SAVE_PATH := "user://settings.cfg"

var camera_effects_enabled := true
var mouse_sensitivity := 0.0024
var fullscreen_enabled := false
var vsync_enabled := true
var fps_limit := 0
var _config := ConfigFile.new()

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	if _config.load(SAVE_PATH) != OK:
		_apply_display()
		return
	camera_effects_enabled = bool(_config.get_value("video", "camera_effects_enabled", true))
	mouse_sensitivity = float(_config.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	fullscreen_enabled = bool(_config.get_value("video", "fullscreen_enabled", false))
	vsync_enabled = bool(_config.get_value("video", "vsync_enabled", true))
	fps_limit = int(_config.get_value("video", "fps_limit", 0))
	_apply_display()

func save_settings() -> void:
	_config.set_value("video", "camera_effects_enabled", camera_effects_enabled)
	_config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	_config.set_value("video", "fullscreen_enabled", fullscreen_enabled)
	_config.set_value("video", "vsync_enabled", vsync_enabled)
	_config.set_value("video", "fps_limit", fps_limit)
	_config.save(SAVE_PATH)

func _apply_display() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	if fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Engine.max_fps = 0 if fps_limit <= 0 or fps_limit >= 360 else fps_limit

func set_camera_effects(enabled: bool) -> void:
	camera_effects_enabled = enabled
	save_settings()
	setting_changed.emit(&"camera_effects_enabled", enabled)

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0004, 0.01)
	save_settings()
	setting_changed.emit(&"mouse_sensitivity", mouse_sensitivity)

func set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	_apply_display()
	save_settings()
	setting_changed.emit(&"fullscreen_enabled", enabled)
