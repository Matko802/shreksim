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
const TAB_NAMES := ["VIDEO", "AUDIO", "CONTROLS"]
var _aa_modes: Array[int] = []
var settings_tabs: HBoxContainer
var settings_pages: VBoxContainer
var video_page: VBoxContainer
var audio_page: VBoxContainer
var controls_page: VBoxContainer
var tab_buttons: Array[Button] = []
var master_slider: HSlider
var master_value: Label
var music_slider: HSlider
var music_value: Label
var sfx_slider: HSlider
var sfx_value: Label
var _settings_tab := 0

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
	if SettingsBus._is_mobile():
		_aa_modes.remove_at(0)
	elif SettingsBus.taa_supported():
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
	_build_settings_tabs()
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
		&"master_volume":
			master_slider.set_value_no_signal(SettingsBus.master_volume * 100.0)
			_update_volume_value(master_value, SettingsBus.master_volume * 100.0)
		&"music_volume":
			music_slider.set_value_no_signal(SettingsBus.music_volume * 100.0)
			_update_volume_value(music_value, SettingsBus.music_volume * 100.0)
		&"sfx_volume":
			sfx_slider.set_value_no_signal(SettingsBus.sfx_volume * 100.0)
			_update_volume_value(sfx_value, SettingsBus.sfx_volume * 100.0)

func set_open(open: bool) -> void:
	visible = open
	if open:
		_hide_settings()
		_sync_controls()

func _show_settings() -> void:
	center.visible = false
	settings_center.visible = true
	_select_tab(_settings_tab)

func _hide_settings() -> void:
	settings_center.visible = false
	center.visible = true

func _build_settings_tabs() -> void:
	var box := settings_center.get_node("SettingsPanel/Box") as VBoxContainer
	settings_tabs = HBoxContainer.new()
	settings_tabs.name = "Tabs"
	settings_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_tabs.add_theme_constant_override("separation", 8)
	for i in TAB_NAMES.size():
		var btn := Button.new()
		btn.text = tr(TAB_NAMES[i])
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(112.0, 38.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_stylebox_override("normal", _tab_style(Color(0.02, 0.18, 0.06)))
		btn.add_theme_stylebox_override("hover", _tab_style(Color(0.0, 0.5, 0.16)))
		btn.add_theme_stylebox_override("pressed", _tab_style(Color(0.0, 0.6, 0.21)))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(_select_tab.bind(i))
		settings_tabs.add_child(btn)
		tab_buttons.append(btn)
	box.add_child(settings_tabs)
	box.move_child(settings_tabs, 1)
	settings_pages = VBoxContainer.new()
	settings_pages.name = "Pages"
	settings_pages.add_theme_constant_override("separation", 12)
	box.add_child(settings_pages)
	box.move_child(settings_pages, 2)
	video_page = _make_page("VideoPage")
	audio_page = _make_page("AudioPage")
	controls_page = _make_page("ControlsPage")
	_move_controls(video_page, ["QualityRow", "DistanceRow", "RenderScaleRow", "AARow", "FPSRow", "VSyncCheck", "FSCheck", "FXCheck", "DebugCheck"])
	_move_controls(controls_page, ["SensRow", "LangRow"])
	_build_volume_controls()
	_select_tab(0)

func _make_page(page_name: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = page_name
	page.add_theme_constant_override("separation", 12)
	settings_pages.add_child(page)
	return page

func _move_controls(page: VBoxContainer, names: Array[String]) -> void:
	var box := settings_center.get_node("SettingsPanel/Box") as VBoxContainer
	for node_name in names:
		var node := box.get_node_or_null(node_name)
		if node != null:
			node.reparent(page, false)

func _tab_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	return sb

func _build_volume_controls() -> void:
	var master_row := _add_volume_row(audio_page, tr("Master volume"), SettingsBus.master_volume)
	master_slider = master_row[0] as HSlider
	master_value = master_row[1] as Label
	var music_row := _add_volume_row(audio_page, tr("Music volume"), SettingsBus.music_volume)
	music_slider = music_row[0] as HSlider
	music_value = music_row[1] as Label
	var sfx_row := _add_volume_row(audio_page, tr("Effects volume"), SettingsBus.sfx_volume)
	sfx_slider = sfx_row[0] as HSlider
	sfx_value = sfx_row[1] as Label
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

func _add_volume_row(page: VBoxContainer, title: String, value: float) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(150.0, 28.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = value * 100.0
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(58.0, 0.0)
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d%%" % roundi(value * 100.0)
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)
	page.add_child(row)
	return [slider, value_label]

func _select_tab(idx: int) -> void:
	_settings_tab = clampi(idx, 0, tab_buttons.size() - 1)
	for i in tab_buttons.size():
		tab_buttons[i].set_pressed_no_signal(i == _settings_tab)
	if video_page != null:
		video_page.visible = _settings_tab == 0
	if audio_page != null:
		audio_page.visible = _settings_tab == 1
	if controls_page != null:
		controls_page.visible = _settings_tab == 2

func _on_master_volume_changed(value: float) -> void:
	SettingsBus.set_master_volume(value / 100.0)
	_update_volume_value(master_value, value)

func _on_music_volume_changed(value: float) -> void:
	SettingsBus.set_music_volume(value / 100.0)
	_update_volume_value(music_value, value)

func _on_sfx_volume_changed(value: float) -> void:
	SettingsBus.set_sfx_volume(value / 100.0)
	_update_volume_value(sfx_value, value)

func _update_volume_value(label: Label, value: float) -> void:
	if label != null:
		label.text = "%d%%" % roundi(value)

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
	master_slider.set_value_no_signal(SettingsBus.master_volume * 100.0)
	_update_volume_value(master_value, SettingsBus.master_volume * 100.0)
	music_slider.set_value_no_signal(SettingsBus.music_volume * 100.0)
	_update_volume_value(music_value, SettingsBus.music_volume * 100.0)
	sfx_slider.set_value_no_signal(SettingsBus.sfx_volume * 100.0)
	_update_volume_value(sfx_value, SettingsBus.sfx_volume * 100.0)
	lang_option.selected = SettingsBus.language_index()

func _update_sens_value(value: float) -> void:
	sens_value.text = "%.1f" % (value * 1000.0)
