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
@onready var fs_check: CheckButton = %FSCheck
@onready var lang_option: OptionButton = %LangOption

func _ready() -> void:
	visible = false
	settings_center.visible = false
	for entry in SettingsBus.LANGUAGES:
		lang_option.add_item(entry[1])
	slider.value_changed.connect(_on_sensitivity_changed)
	fx_check.toggled.connect(_on_fx_toggled)
	fs_check.toggled.connect(_on_fs_toggled)
	lang_option.item_selected.connect(_on_language_selected)
	settings_btn.pressed.connect(_show_settings)
	back_settings_btn.pressed.connect(_hide_settings)
	reset_btn.pressed.connect(_on_reset_pressed)
	%ResumeBtn.pressed.connect(func() -> void: resume_requested.emit())
	%RestartBtn.pressed.connect(func() -> void: restart_requested.emit())
	%MenuBtn.pressed.connect(func() -> void: menu_requested.emit())

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

func _on_fs_toggled(on: bool) -> void:
	SettingsBus.set_fullscreen(on)

func _on_language_selected(idx: int) -> void:
	SettingsBus.set_language(SettingsBus.LANGUAGES[idx][0])

func _on_reset_pressed() -> void:
	SettingsBus.reset_settings()
	_sync_controls()

func _sync_controls() -> void:
	slider.value = SettingsBus.mouse_sensitivity
	_update_sens_value(SettingsBus.mouse_sensitivity)
	fx_check.button_pressed = SettingsBus.camera_effects_enabled
	fs_check.button_pressed = SettingsBus.fullscreen_enabled
	lang_option.selected = SettingsBus.language_index()

func _update_sens_value(value: float) -> void:
	sens_value.text = "%.1f" % (value * 1000.0)
