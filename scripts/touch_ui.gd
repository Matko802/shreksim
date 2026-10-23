extends CanvasLayer

var ui_scale := 1.0
var look_pointer := -1
var look_last := Vector2.ZERO
var btn_pointers := {}
var grab_button: Panel
var joystick: SwampVirtualJoystick
var tap_release_queue: Array = []
var sprint_on := false
var buttons := {}
var screen := Vector2.ZERO

func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		queue_free()
		return
	Input.emulate_mouse_from_touch = false
	var dpi := float(DisplayServer.screen_get_dpi())
	ui_scale = clampf(dpi / 220.0, 0.9, 1.6)
	_build_ui()

func _exit_tree() -> void:
	if DisplayServer.is_touchscreen_available():
		Input.emulate_mouse_from_touch = true

func _safe_insets() -> Vector4:
	var disp := Vector2(DisplayServer.screen_get_size())
	var l := 0.0
	var t := 0.0
	var r := 0.0
	var b := 0.0
	if disp.x > 1.0 and disp.y > 1.0:
		var raw := DisplayServer.get_display_safe_area()
		var vis := get_viewport().get_visible_rect().size
		var kx := vis.x / disp.x
		var ky := vis.y / disp.y
		l = maxf(0.0, float(raw.position.x) * kx)
		t = maxf(0.0, float(raw.position.y) * ky)
		r = maxf(0.0, float(disp.x - raw.position.x - raw.size.x) * kx)
		b = maxf(0.0, float(disp.y - raw.position.y - raw.size.y) * ky)
	return Vector4(l, t, r, b)

func _circle_panel(size: float) -> Panel:
	var p := Panel.new()
	p.size = Vector2(size, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(int(size * 0.5))
	p.add_theme_stylebox_override("panel", sb)
	return p

func _label_of(p: Panel, text: String, size: float) -> void:
	var lab := Label.new()
	lab.text = text
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", int(size * 0.2))
	lab.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	lab.add_theme_constant_override("outline_size", 3)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lab)

func _joy_style(size: float, color: Color, border: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size * 0.5))
	sb.set_border_width_all(maxi(1, roundi(border)))
	sb.border_color = Color(1, 1, 1, color.a)
	return sb

func _place(p: Control, ax: float, ay: float, off_left: float, off_top: float, w: float, h: float) -> void:
	p.anchor_left = ax
	p.anchor_right = ax
	p.anchor_top = ay
	p.anchor_bottom = ay
	p.offset_left = off_left
	p.offset_top = off_top
	p.offset_right = off_left + w
	p.offset_bottom = off_top + h
	p.pivot_offset = Vector2(w, h) * 0.5

func _add_button(id: String, text: String, size: float) -> void:
	var p := _circle_panel(size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_of(p, text, size)
	p.set_meta("base", Color(0, 0, 0, 0.55))
	add_child(p)
	buttons[id] = p

func _build_ui() -> void:
	var insets := _safe_insets()
	var m := 20.0 * ui_scale
	var small := 58.0 * ui_scale
	var jump := 88.0 * ui_scale
	var gap := 12.0 * ui_scale
	_add_button("jump", tr("JUMP"), jump)
	_add_button("sprint", tr("RUN"), small)
	_add_button("crouch", tr("DUCK"), small)
	_add_button("light", tr("LIGHT"), small)
	_add_button("grab", tr("GRAB"), small)
	_add_button("pauseb", "I I", small * 0.82)
	_place(buttons["jump"], 1.0, 1.0, -(m + insets[2] + jump), -(m + insets[3] + jump), jump, jump)
	_place(buttons["sprint"], 1.0, 1.0, -(m + insets[2] + small), -(m + insets[3] + jump + gap + small), small, small)
	_place(buttons["crouch"], 1.0, 1.0, -(m + insets[2] + jump + gap + small), -(m + insets[3] + small), small, small)
	_place(buttons["light"], 1.0, 1.0, -(m + insets[2] + jump + gap + small), -(m + insets[3] + small * 2.0 + gap), small, small)
	_place(buttons["grab"], 1.0, 0.58, -(m + insets[2] + small * 1.2), -small * 0.5, small, small)
	_place(buttons["pauseb"], 1.0, 0.0, -(m + insets[2] + small * 0.82), m + insets[1], small * 0.82, small * 0.82)
	var joy_size := 160.0 * ui_scale
	joystick = SwampVirtualJoystick.new()
	joystick.joystick_mode = SwampVirtualJoystick.JoystickMode.JOYSTICK_FIXED
	joystick.visibility_mode = SwampVirtualJoystick.VisibilityMode.VISIBILITY_ALWAYS
	joystick.joystick_size = joy_size
	joystick.tip_size = 60.0 * ui_scale
	joystick.deadzone_ratio = 0.2
	joystick.action_left = &"move_left"
	joystick.action_right = &"move_right"
	joystick.action_up = &"move_forward"
	joystick.action_down = &"move_back"
	_place(joystick, 0.0, 1.0, m + insets[0], -(m + insets[3] + joy_size), joy_size, joy_size)
	joystick.add_theme_stylebox_override("normal_joystick", _joy_style(joy_size, Color(0, 0, 0, 0.45), 3.0 * ui_scale))
	joystick.add_theme_stylebox_override("pressed_joystick", _joy_style(joy_size, Color(0, 0, 0, 0.62), 3.0 * ui_scale))
	joystick.add_theme_stylebox_override("normal_tip", _joy_style(60.0 * ui_scale, Color(0, 0, 0, 0.55), 2.4 * ui_scale))
	joystick.add_theme_stylebox_override("pressed_tip", _joy_style(60.0 * ui_scale, Color(1, 1, 1, 0.92), 0.0))
	add_child(joystick)
	grab_button = buttons["grab"]
	grab_button.visible = false

func set_grab_visible(v: bool) -> void:
	if grab_button != null and grab_button.visible != v:
		grab_button.visible = v

func _game_paused() -> bool:
	var g := get_parent()
	if g == null:
		return false
	var pv = g.get("paused")
	return pv != null and (pv as bool)

func _game_over() -> bool:
	var g := get_parent()
	if g == null:
		return false
	var ov = g.get("game_over")
	return ov != null and (ov as bool)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if _game_over():
			if t.pressed:
				_send_click()
			return
		var want_mouse := _game_paused()
		if Input.emulate_mouse_from_touch != want_mouse:
			Input.emulate_mouse_from_touch = want_mouse
		if want_mouse:
			return
		if t.pressed:
			_handle_press(t.index, t.position)
		else:
			_handle_release(t.index)
	elif event is InputEventScreenDrag:
		if _game_paused() or _game_over():
			return
		var d := event as InputEventScreenDrag
		_handle_drag(d.index, d.position, d.relative)

func _send_click() -> void:
	var e := InputEventMouseButton.new()
	screen = get_viewport().get_visible_rect().size
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = screen * 0.5
	e.global_position = e.position
	Input.parse_input_event(e)
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = false
	r.position = e.position
	r.global_position = e.position
	Input.parse_input_event(r)

func _fire_action(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)

func _handle_press(idx: int, pos: Vector2) -> void:
	for id in buttons.keys():
		var p: Panel = buttons[id]
		if not p.visible:
			continue
		if not p.get_global_rect().has_point(pos):
			continue
		btn_pointers[idx] = id
		var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
		sb.bg_color = Color(1, 1, 1, 0.9)
		match id:
			"jump":
				Input.action_press("jump")
			"crouch":
				Input.action_press("crouch")
				tap_release_queue.append(["crouch", 2])
			"sprint":
				sprint_on = not sprint_on
				if sprint_on:
					Input.action_press("sprint")
				else:
					Input.action_release("sprint")
			"light":
				_fire_action("flashlight")
			"grab":
				_fire_action("interact")
			"pauseb":
				_fire_action("pause")
		return
	if joystick.get_global_rect().has_point(pos):
		return
	screen = get_viewport().get_visible_rect().size
	if look_pointer == -1 and pos.x > screen.x * 0.28:
		look_pointer = idx
		look_last = pos

func _handle_release(idx: int) -> void:
	if btn_pointers.has(idx):
		var id: String = btn_pointers[idx]
		btn_pointers.erase(idx)
		var p: Panel = buttons[id]
		var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
		if id == "sprint" and sprint_on:
			sb.bg_color = Color(1, 1, 1, 0.9)
		else:
			sb.bg_color = p.get_meta("base") as Color
		if id == "jump":
			Input.action_release("jump")
		return
	if idx == look_pointer:
		look_pointer = -1

func _handle_drag(idx: int, pos: Vector2, _rel: Vector2) -> void:
	if idx == look_pointer:
		var delta := pos - look_last
		look_last = pos
		_send_look(delta)

func _send_look(delta: Vector2) -> void:
	var g := get_parent()
	if g != null and g.has_method("_touch_look"):
		g._touch_look(delta)

func _process(_delta: float) -> void:
	var over := _game_over()
	if joystick != null and joystick.visible == over:
		joystick.visible = not over
	var i := 0
	while i < tap_release_queue.size():
		var item: Array = tap_release_queue[i]
		var frames: int = item[1]
		frames -= 1
		if frames <= 0:
			Input.action_release(item[0])
			tap_release_queue.remove_at(i)
		else:
			item[1] = frames
			i += 1
