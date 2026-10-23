class_name VirtualJoystick
extends Control

enum JoystickMode { JOYSTICK_FIXED, JOYSTICK_DYNAMIC }
enum VisibilityMode { VISIBILITY_ALWAYS, VISIBILITY_TOUCH_ONLY }

signal pressed
signal released(value: Vector2)
signal flicked(value: Vector2)
signal tapped

var joystick_mode: int = JoystickMode.JOYSTICK_FIXED
var visibility_mode: int = VisibilityMode.VISIBILITY_ALWAYS
var joystick_size: float = 100.0:
	set(value):
		joystick_size = maxf(value, 32.0)
		_layout()
var tip_size: float = 60.0:
	set(value):
		tip_size = maxf(value, 16.0)
		_layout()
var deadzone_ratio: float = 0.2
var action_left: StringName = &""
var action_right: StringName = &""
var action_up: StringName = &""
var action_down: StringName = &""

var _base: Panel
var _tip: Panel
var _touch_index: int = -1
var _center: Vector2
var _output: Vector2
var _press_msec: int = 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base = Panel.new()
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip = Panel.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base)
	add_child(_tip)

func _ready() -> void:
	_sync_styles()
	_layout()
	_update_visibility()
	resized.connect(_on_resized)
	set_process(false)

func _on_resized() -> void:
	_layout()

func _layout() -> void:
	if _base == null:
		return
	_base.custom_minimum_size = Vector2(joystick_size, joystick_size)
	_tip.custom_minimum_size = Vector2(tip_size, tip_size)
	_tip.size = Vector2(tip_size, tip_size)
	if is_inside_tree() and size.x > 0.0 and _touch_index == -1:
		_tip.position = (size - _tip.size) * 0.5

func _sync_styles() -> void:
	_base.add_theme_stylebox_override("panel", _style("normal_joystick", Color(0, 0, 0, 0.45), 180.0))
	_tip.add_theme_stylebox_override("panel", _style("normal_tip", Color(1, 1, 1, 0.5), 180.0))

func _style(name: String, fallback_color: Color, corner: float) -> StyleBox:
	var sb := get_theme_stylebox(name)
	if sb == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = fallback_color
		flat.set_corner_radius_all(int(corner))
		return flat
	return sb

func _set_pressed_style(on: bool) -> void:
	if on:
		_base.add_theme_stylebox_override("panel", _style("pressed_joystick", Color(0, 0, 0, 0.62), 180.0))
		_tip.add_theme_stylebox_override("panel", _style("pressed_tip", Color(1, 1, 1, 0.92), 180.0))
	else:
		_sync_styles()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _touch_index != -1 or not get_global_rect().has_point(t.position):
				return
			_touch_index = t.index
			_press_msec = Time.get_ticks_msec()
			_update_visibility()
			if joystick_mode == JoystickMode.JOYSTICK_DYNAMIC:
				_center = t.position - get_global_rect().position
			else:
				_center = size * 0.5
			_set_pressed_style(true)
			pressed.emit()
			_apply_tip(t.position - get_global_rect().position)
			get_viewport().set_input_as_handled()
		else:
			if t.index != _touch_index:
				return
			_finish(t.position - get_global_rect().position)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != _touch_index:
			return
		_apply_tip(d.position - get_global_rect().position)
		get_viewport().set_input_as_handled()

func _apply_tip(local_pos: Vector2) -> void:
	var radius := maxf((joystick_size - tip_size) * 0.5, 1.0)
	var off := local_pos - _center
	var mag := off.length()
	if mag > radius:
		off = off * (radius / mag)
	_output = off / radius
	_tip.position = _center + off - _tip.size * 0.5
	_update_actions()

func _update_actions() -> void:
	var mag := _output.length()
	if mag <= deadzone_ratio:
		_release_all()
		return
	var strength := clampf((mag - deadzone_ratio) / (1.0 - deadzone_ratio), 0.0, 1.0)
	var dir := _output.normalized()
	_drive(action_left, -dir.x * strength)
	_drive(action_right, dir.x * strength)
	_drive(action_up, -dir.y * strength)
	_drive(action_down, dir.y * strength)

func _drive(action: StringName, strength: float) -> void:
	if action == &"":
		return
	if strength > 0.01:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)

func _release_all() -> void:
	Input.action_release(action_left)
	Input.action_release(action_right)
	Input.action_release(action_up)
	Input.action_release(action_down)

func _release_visual() -> void:
	_output = Vector2.ZERO
	_touch_index = -1
	_set_pressed_style(false)
	_tip.position = (size - _tip.size) * 0.5

func _update_visibility() -> void:
	visible = visibility_mode == VisibilityMode.VISIBILITY_ALWAYS or _touch_index != -1

func _finish(local_pos: Vector2) -> void:
	_apply_tip(local_pos)
	var hold := float(Time.get_ticks_msec() - _press_msec) * 0.001
	var v := _output
	_release_all()
	_release_visual()
	_update_visibility()
	if v.length() <= deadzone_ratio and hold < 0.25:
		tapped.emit()
	elif v.length() > 0.5:
		flicked.emit(v)
	released.emit(v)
