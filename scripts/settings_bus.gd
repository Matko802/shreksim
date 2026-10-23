extends Node

signal setting_changed(setting_name: StringName, value: Variant)

enum AntiAliasingMode { OFF = 0, FXAA = 1, MSAA_2X = 2, MSAA_4X = 3, MSAA_8X = 4, TAA = 5 }

const SAVE_PATH := "user://settings.cfg"
const SETTINGS_VERSION := 2

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
	var mobile := OS.has_feature("android") or OS.has_feature("ios")
	if mobile:
		fullscreen_enabled = true
		_apply_display()
	_apply_anti_aliasing.call_deferred(anti_aliasing_mode)

func _is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

func load_settings() -> void:
	var had_file := _config.load(SAVE_PATH) == OK
	if had_file:
		var version := int(_config.get_value("core", "version", 0))
		camera_effects_enabled = bool(_config.get_value("video", "camera_effects_enabled", true))
		mouse_sensitivity = float(_config.get_value("input", "mouse_sensitivity", mouse_sensitivity))
		fullscreen_enabled = bool(_config.get_value("video", "fullscreen_enabled", false))
		vsync_enabled = bool(_config.get_value("video", "vsync_enabled", true))
		fps_limit = int(_config.get_value("video", "fps_limit", 0))
		anti_aliasing_mode = int(_config.get_value("video", "anti_aliasing_mode", AntiAliasingMode.MSAA_2X))
		language = str(_config.get_value("locale", "language", ""))
		if _is_mobile():
			vsync_enabled = false
			anti_aliasing_mode = AntiAliasingMode.FXAA
		if version != SETTINGS_VERSION:
			_config.set_value("core", "version", SETTINGS_VERSION)
			save_settings()
	_apply_display()
	_apply_language()

func save_settings() -> void:
	_config.set_value("core", "version", SETTINGS_VERSION)
	_config.set_value("video", "camera_effects_enabled", camera_effects_enabled)
	_config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	_config.set_value("video", "fullscreen_enabled", fullscreen_enabled)
	_config.set_value("video", "vsync_enabled", vsync_enabled)
	_config.set_value("video", "fps_limit", fps_limit)
	_config.set_value("video", "anti_aliasing_mode", anti_aliasing_mode)
	_config.set_value("locale", "language", language)
	_config.save(SAVE_PATH)

func taa_supported() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus" or ProjectSettings.get_setting("rendering/renderer/rendering_method", "mobile") == "forward_plus" or ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "mobile") == "forward_plus"

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
	vsync_enabled = enabled and not _is_mobile()
	_apply_display()
	save_settings()
	setting_changed.emit(&"vsync_enabled", vsync_enabled)

func set_fps_limit(limit: int) -> void:
	fps_limit = clampi(limit, 0, 360)
	_apply_display()
	save_settings()
	setting_changed.emit(&"fps_limit", fps_limit)

func set_anti_aliasing_mode(mode: int) -> void:
	if _is_mobile():
		mode = AntiAliasingMode.FXAA
	if mode == AntiAliasingMode.TAA and not taa_supported():
		mode = AntiAliasingMode.FXAA
	anti_aliasing_mode = clampi(mode, 0, AntiAliasingMode.TAA)
	_apply_anti_aliasing(anti_aliasing_mode)
	save_settings()
	setting_changed.emit(&"anti_aliasing_mode", anti_aliasing_mode)

func _apply_anti_aliasing(mode: int) -> void:
	var method := String(RenderingServer.get_current_rendering_method())
	if mode == AntiAliasingMode.TAA and method != "forward_plus":
		mode = AntiAliasingMode.FXAA
	var root := get_tree().root
	var msaa_value := Viewport.MSAA_DISABLED
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
			msaa_value = Viewport.MSAA_2X
		AntiAliasingMode.MSAA_4X:
			msaa_value = Viewport.MSAA_4X
		AntiAliasingMode.MSAA_8X:
			msaa_value = Viewport.MSAA_8X
		AntiAliasingMode.TAA:
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.use_taa = true
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	if msaa_value != Viewport.MSAA_DISABLED:
		root.msaa_3d = msaa_value
		root.use_taa = false
		root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if method != "forward_plus" else Viewport.SCREEN_SPACE_AA_DISABLED

func reset_settings() -> void:
	camera_effects_enabled = true
	mouse_sensitivity = 0.0024
	fullscreen_enabled = false
	vsync_enabled = true
	fps_limit = 0
	anti_aliasing_mode = AntiAliasingMode.MSAA_2X
	language = ""
	if _is_mobile():
		fullscreen_enabled = true
		vsync_enabled = false
		anti_aliasing_mode = AntiAliasingMode.FXAA
	_apply_anti_aliasing(anti_aliasing_mode)
	_apply_display()
	_apply_language()
	save_settings()
	setting_changed.emit(&"language", language)
