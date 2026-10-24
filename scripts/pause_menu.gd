extends CanvasLayer

signal resume_requested
signal restart_requested
signal menu_requested

@onready var center: Control = get_node("Center")
@onready var settings_center: Control = %SettingsCenter
@onready var settings_btn: Button = %SettingsBtn
@onready var back_settings_btn: Button = %BackSettings
@onready var reset_btn: Button = %ResetBtn
@onready var slider: HSlider = %SensSlider
@onready var sens_value: Label = %SensValue
@onready var fx_check: CheckButton = %FXCheck
@onready var debug_check: CheckButton = %DebugCheck
@onready var fs_check: CheckButton = %FSCheck
@onready var lang_option: OptionButton = %LangOption
@onready var vsync_check: CheckButton = %VSyncCheck
@onready var aa_option: OptionButton = %AAOption
@onready var fps_slider: HSlider = %FPSLimitSlider
@onready var fps_label: Label = %FPSLimitLabel
@onready var quality_option: OptionButton = %QualityOption
@onready var distance_slider: HSlider = %DistanceSlider
@onready var distance_value: Label = %DistanceValue
@onready var render_scale_slider: HSlider = %RenderScaleSlider
@onready var render_scale_value: Label = %RenderScaleValue

const AA_LABELS := ["Off", "FXAA", "MSAA 2x", "MSAA 4x", "MSAA 8x", "TAA"]
var _aa_modes: Array[int] = []

func _ready() -> void:
	visible = false
	settings_center.visible = false
	if SettingsBus._is_mobile():
		fs_check.visible = false
		vsync_check.visible = false
	for entry in SettingsBus.LANGUAGES:
		lang_option.add_item(entry[1])
	for label in SettingsBus.QUALITY_LABELS:
		quality_option.add_item(tr(label))
	_aa_modes = [0, 1, 2, 3, 4]
	if SettingsBus.taa_supported():
		_aa_modes.append(5)
	for mode in _aa_modes:
		aa_option.add_item(AA_LABELS[mode])
	slider.value_changed.connect(_on_sensitivity_changed)
	fx_check.toggled.connect(_on_fx_toggled)
	debug_check.toggled.connect(_on_debug_toggled)
	fs_check.toggled.connect(_on_fs_toggled)
	lang_option.item_selected.connect(_on_language_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	aa_option.item_selected.connect(_on_aa_selected)
	fps_slider.value_changed.connect(_on_fps_changed)
	quality_option.item_selected.connect(_on_quality_selected)
	distance_slider.value_changed.connect(_on_distance_changed)
	render_scale_slider.value_changed.connect(_on_render_scale_changed)
	settings_btn.pressed.connect(_show_settings)
	back_settings_btn.pressed.connect(_hide_settings)
	reset_btn.pressed.connect(_on_reset_pressed)
	%ResumeBtn.pressed.connect(func() -> void: resume_requested.emit())
	%RestartBtn.pressed.connect(func() -> void: restart_requested.emit())
	%MenuBtn.pressed.connect(func() -> void: menu_requested.emit())
	SettingsBus.setting_changed.connect(_on_external_setting)

func _on_external_setting(setting_name: StringName, _value: Variant) -> void:
	if not settings_center.visible:
		return
	match setting_name:
		&"fullscreen_enabled":
			fs_check.set_pressed_no_signal(SettingsBus.fullscreen_enabled)
		&"debug_info_enabled":
			debug_check.set_pressed_no_signal(SettingsBus.debug_info_enabled)
		&"vsync_enabled":
			vsync_check.set_pressed_no_signal(SettingsBus.vsync_enabled)
		&"anti_aliasing_mode":
			aa_option.selected = clampi(_aa_modes.find(SettingsBus.anti_aliasing_mode), 0, _aa_modes.size() - 1)
		&"fps_limit":
			fps_slider.set_value_no_signal(360.0 if SettingsBus.fps_limit <= 0 or SettingsBus.fps_limit >= 360 else float(SettingsBus.fps_limit))
			_update_fps_label(SettingsBus.fps_limit)
		&"quality_preset":
			quality_option.selected = SettingsBus.quality_preset
		&"render_distance":
			distance_slider.set_value_no_signal(SettingsBus.render_distance)
			_update_distance_value(SettingsBus.render_distance)
		&"render_scale":
			render_scale_slider.set_value_no_signal(SettingsBus.render_scale * 100.0)
			_update_render_scale_value(SettingsBus.render_scale * 100.0)

func set_open(open: bool) -> void:
	visible = open
	if open:
		_hide_settings()
		_sync_controls()

func _show_settings() -> void:
	center.visible = false
	settings_center.visible = true

func _hide_settings() -> void:
	settings_center.visible = false
	center.visible = true

func _on_sensitivity_changed(value: float) -> void:
	SettingsBus.set_mouse_sensitivity(value)
	_update_sens_value(value)

func _on_fx_toggled(on: bool) -> void:
	SettingsBus.set_camera_effects(on)

func _on_debug_toggled(on: bool) -> void:
	SettingsBus.set_debug_info(on)

func _on_fs_toggled(on: bool) -> void:
	SettingsBus.set_fullscreen(on)

func _on_language_selected(idx: int) -> void:
	SettingsBus.set_language(SettingsBus.LANGUAGES[idx][0])

func _on_vsync_toggled(on: bool) -> void:
	SettingsBus.set_vsync_enabled(on)

func _on_aa_selected(idx: int) -> void:
	if idx >= 0 and idx < _aa_modes.size():
		SettingsBus.set_anti_aliasing_mode(_aa_modes[idx])

func _on_fps_changed(value: float) -> void:
	var limit := int(round(value))
	if limit >= 360:
		limit = 0
	SettingsBus.set_fps_limit(limit)
	_update_fps_label(SettingsBus.fps_limit)

func _on_quality_selected(idx: int) -> void:
	SettingsBus.set_quality_preset(idx)
	_sync_controls()

func _on_distance_changed(value: float) -> void:
	SettingsBus.set_render_distance(value)
	_update_distance_value(SettingsBus.render_distance)

func _on_render_scale_changed(value: float) -> void:
	SettingsBus.set_render_scale(value / 100.0)
	_update_render_scale_value(SettingsBus.render_scale * 100.0)

func _update_fps_label(limit: int) -> void:
	fps_label.text = "Off" if limit <= 0 else str(limit)

func _update_distance_value(value: float) -> void:
	distance_value.text = "%d m" % int(round(value))

func _update_render_scale_value(value: float) -> void:
	render_scale_value.text = "%d%%" % int(round(value))

func _on_reset_pressed() -> void:
	SettingsBus.reset_settings()
	_sync_controls()

func _sync_controls() -> void:
	slider.value = SettingsBus.mouse_sensitivity
	_update_sens_value(SettingsBus.mouse_sensitivity)
	fx_check.set_pressed_no_signal(SettingsBus.camera_effects_enabled)
	debug_check.set_pressed_no_signal(SettingsBus.debug_info_enabled)
	fs_check.set_pressed_no_signal(SettingsBus.fullscreen_enabled)
	vsync_check.set_pressed_no_signal(SettingsBus.vsync_enabled)
	aa_option.selected = clampi(_aa_modes.find(SettingsBus.anti_aliasing_mode), 0, _aa_modes.size() - 1)
	fps_slider.set_value_no_signal(360.0 if SettingsBus.fps_limit <= 0 or SettingsBus.fps_limit >= 360 else float(SettingsBus.fps_limit))
	_update_fps_label(SettingsBus.fps_limit)
	quality_option.selected = SettingsBus.quality_preset
	distance_slider.set_value_no_signal(SettingsBus.render_distance)
	_update_distance_value(SettingsBus.render_distance)
	render_scale_slider.set_value_no_signal(SettingsBus.render_scale * 100.0)
	_update_render_scale_value(SettingsBus.render_scale * 100.0)
	lang_option.selected = SettingsBus.language_index()

func _update_sens_value(value: float) -> void:
	sens_value.text = "%.1f" % (value * 1000.0)
