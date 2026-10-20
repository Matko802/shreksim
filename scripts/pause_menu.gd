extends CanvasLayer

signal resume_requested
signal restart_requested
signal menu_requested

@onready var slider: HSlider = %SensSlider
@onready var fx_check: CheckButton = %FXCheck
@onready var fs_check: CheckButton = %FSCheck

func _ready() -> void:
	visible = false
	slider.value = SettingsBus.mouse_sensitivity
	slider.value_changed.connect(func(v: float) -> void: SettingsBus.set_mouse_sensitivity(v))
	fx_check.button_pressed = SettingsBus.camera_effects_enabled
	fx_check.toggled.connect(func(on: bool) -> void: SettingsBus.set_camera_effects(on))
	fs_check.button_pressed = SettingsBus.fullscreen_enabled
	fs_check.toggled.connect(func(on: bool) -> void: SettingsBus.set_fullscreen(on))
	%ResumeBtn.pressed.connect(func() -> void: resume_requested.emit())
	%RestartBtn.pressed.connect(func() -> void: restart_requested.emit())
	%MenuBtn.pressed.connect(func() -> void: menu_requested.emit())

func set_open(open: bool) -> void:
	visible = open
