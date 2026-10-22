extends Node

signal setting_changed(setting_name: StringName, value: Variant)

enum AntiAliasingMode { OFF = 0, FXAA = 1, MSAA_2X = 2, MSAA_4X = 3, MSAA_8X = 4, TAA = 5 }

const SAVE_PATH := "user://settings.cfg"

const LANGUAGES := [
	["en", "English"],
	["sk", "Slovenčina"],
	["cs", "Čeština"],
	["pl", "Polski"],
	["hu", "Magyar"],
	["de", "Deutsch"],
	["es", "Español"],
	["fr", "Français"],
]

var camera_effects_enabled := true
var mouse_sensitivity := 0.0024
var fullscreen_enabled := false
var vsync_enabled := true
var fps_limit := 0
var anti_aliasing_mode: int = AntiAliasingMode.MSAA_2X
var language := ""
var _config := ConfigFile.new()

func _ready() -> void:
	load_settings()
	_apply_anti_aliasing.call_deferred(anti_aliasing_mode)

func load_settings() -> void:
	if _config.load(SAVE_PATH) == OK:
		camera_effects_enabled = bool(_config.get_value("video", "camera_effects_enabled", true))
		mouse_sensitivity = float(_config.get_value("input", "mouse_sensitivity", mouse_sensitivity))
		fullscreen_enabled = bool(_config.get_value("video", "fullscreen_enabled", false))
		vsync_enabled = bool(_config.get_value("video", "vsync_enabled", true))
		fps_limit = int(_config.get_value("video", "fps_limit", 0))
		anti_aliasing_mode = int(_config.get_value("video", "anti_aliasing_mode", AntiAliasingMode.MSAA_2X))
		language = str(_config.get_value("locale", "language", ""))
	_apply_display()
	_apply_language()

func save_settings() -> void:
	_config.set_value("video", "camera_effects_enabled", camera_effects_enabled)
	_config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	_config.set_value("video", "fullscreen_enabled", fullscreen_enabled)
	_config.set_value("video", "vsync_enabled", vsync_enabled)
	_config.set_value("video", "fps_limit", fps_limit)
	_config.set_value("video", "anti_aliasing_mode", anti_aliasing_mode)
	_config.set_value("locale", "language", language)
	_config.save(SAVE_PATH)

func _apply_display() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	Engine.max_fps = 0 if fps_limit <= 0 or fps_limit >= 360 else fps_limit

func _apply_language() -> void:
	if language == "":
		var os_lang := OS.get_locale_language()
		for entry in LANGUAGES:
			if entry[0] == os_lang:
				language = os_lang
				break
	if language == "" or not _is_known_language(language):
		language = "en"
	TranslationServer.set_locale(language)

func _is_known_language(code: String) -> bool:
	for entry in LANGUAGES:
		if entry[0] == code:
			return true
	return false

func language_index() -> int:
	for i in LANGUAGES.size():
		if LANGUAGES[i][0] == language:
			return i
	return 0

func set_language(code: String) -> void:
	language = code if _is_known_language(code) else "en"
	TranslationServer.set_locale(language)
	save_settings()
	setting_changed.emit(&"language", language)

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

func set_vsync_enabled(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply_display()
	save_settings()
	setting_changed.emit(&"vsync_enabled", enabled)

func set_fps_limit(limit: int) -> void:
	fps_limit = clampi(limit, 0, 360)
	_apply_display()
	save_settings()
	setting_changed.emit(&"fps_limit", fps_limit)

func set_anti_aliasing_mode(mode: int) -> void:
	anti_aliasing_mode = clampi(mode, 0, AntiAliasingMode.TAA)
	_apply_anti_aliasing(anti_aliasing_mode)
	save_settings()
	setting_changed.emit(&"anti_aliasing_mode", anti_aliasing_mode)

func _apply_anti_aliasing(mode: int) -> void:
	var root := get_tree().root
	match mode:
		AntiAliasingMode.OFF:
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.use_taa = false
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		AntiAliasingMode.FXAA:
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.use_taa = false
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		AntiAliasingMode.MSAA_2X:
			root.msaa_3d = Viewport.MSAA_2X
			root.use_taa = false
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		AntiAliasingMode.MSAA_4X:
			root.msaa_3d = Viewport.MSAA_4X
			root.use_taa = false
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		AntiAliasingMode.MSAA_8X:
			root.msaa_3d = Viewport.MSAA_8X
			root.use_taa = false
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		AntiAliasingMode.TAA:
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.use_taa = true
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

func reset_settings() -> void:
	camera_effects_enabled = true
	mouse_sensitivity = 0.0024
	fullscreen_enabled = false
	vsync_enabled = true
	fps_limit = 0
	anti_aliasing_mode = AntiAliasingMode.MSAA_2X
	language = ""
	_apply_anti_aliasing(anti_aliasing_mode)
	_apply_display()
	_apply_language()
	save_settings()
	setting_changed.emit(&"language", language)
