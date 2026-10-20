extends CanvasLayer

var ui_scale := 1.0
var screen := Vector2.ZERO
var joy_pointer := -1
var joy_center := Vector2.ZERO
var joy_radius := 88.0
var look_pointer := -1
var look_last := Vector2.ZERO
var btn_pointers := {}
var tap_release_queue: Array = []
var sprint_on := false
var joy_base: Panel
var joy_knob: Panel
var buttons := {}

func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		queue_free()
		return
	Input.emulate_mouse_from_touch = false
	var dpi := float(DisplayServer.screen_get_dpi())
	ui_scale = clampf(dpi / 220.0, 0.9, 1.6)
	screen = get_viewport().get_visible_rect().size
	joy_radius = 76.0 * ui_scale
	_build_ui()

func _exit_tree() -> void:
	if DisplayServer.is_touchscreen_available():
		Input.emulate_mouse_from_touch = true

func _safe_rect() -> Rect2:
	var disp := Vector2(DisplayServer.screen_get_size())
	if disp.x <= 1.0 or disp.y <= 1.0:
		return Rect2(Vector2.ZERO, screen)
	var raw := DisplayServer.get_display_safe_area()
	var k := screen / disp
	var pos := Vector2(raw.position) * k
	var size := Vector2(raw.size) * k
	size = Vector2(minf(size.x, screen.x - pos.x), minf(size.y, screen.y - pos.y))
	return Rect2(pos, size)

func _circle_panel(size: float, color: Color) -> Panel:
	var p := Panel.new()
	p.size = Vector2(size, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
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

func _add_button(id: String, text: String, size: float, center: Vector2, color: Color) -> void:
	var p := _circle_panel(size, color)
	p.position = center - Vector2(size, size) * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_of(p, text, size)
	p.set_meta("base", color)
	add_child(p)
	buttons[id] = p
	p.set_meta("rect", Rect2(p.position, p.size))

func _build_ui() -> void:
	var safe := _safe_rect()
	var m := 20.0 * ui_scale
	var end := safe.position + safe.size
	var small := 58.0 * ui_scale
	var jump := 88.0 * ui_scale
	var gap := 12.0 * ui_scale

	_add_button("jump", "JUMP", jump, end - Vector2(m + jump * 0.5, m + jump * 0.5), Color(0.18, 0.5, 0.24, 0.42))
	_add_button("sprint", "RUN", small, end - Vector2(m + small * 0.5, m + jump + gap + small * 0.5), Color(0.5, 0.38, 0.12, 0.42))
	_add_button("crouch", "DUCK", small, end - Vector2(m + jump + gap + small * 0.5, m + small * 0.5), Color(0.22, 0.38, 0.48, 0.42))
	_add_button("light", "LIGHT", small, end - Vector2(m + jump + gap + small * 0.5, m + small * 1.5 + gap), Color(0.62, 0.52, 0.16, 0.42))
	_add_button("grab", "GRAB", small, end - Vector2(m + small * 0.7, safe.position.y + safe.size.y * 0.58), Color(0.55, 0.28, 0.18, 0.42))
	_add_button("pauseb", "I I", small * 0.82, Vector2(end.x - m - small * 0.5, safe.position.y + m + small * 0.45), Color(0.25, 0.25, 0.28, 0.45))

	joy_base = _circle_panel(joy_radius * 2.1, Color(0, 0, 0, 0.0))
	joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := _circle_panel(joy_radius * 2.1, Color(1, 1, 1, 0.09))
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_base.add_child(ring)
	var knob_size := joy_radius * 0.78
	joy_knob = _circle_panel(knob_size, Color(1.0, 0.97, 0.88, 0.5))
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_base.add_child(joy_knob)
	joy_knob.position = Vector2(joy_radius * 2.1, joy_radius * 2.1) * 0.5 - Vector2(knob_size, knob_size) * 0.5
	joy_base.visible = false
	add_child(joy_base)

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
		var rect: Rect2 = buttons[id].get_meta("rect")
		if not rect.has_point(pos):
			continue
		btn_pointers[idx] = id
		var p: Panel = buttons[id]
		p.modulate = Color(1.25, 1.25, 1.25)
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
				var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
				sb.bg_color = Color(0.85, 0.62, 0.1, 0.75) if sprint_on else (p.get_meta("base") as Color)
			"light":
				_fire_action("flashlight")
			"grab":
				_fire_action("interact")
			"pauseb":
				_fire_action("pause")
		return
	if joy_pointer == -1 and pos.x < screen.x * 0.45 and pos.y > screen.y * 0.32:
		joy_pointer = idx
		joy_center = pos
		joy_base.position = pos - Vector2(joy_radius * 2.1, joy_radius * 2.1) * 0.5
		joy_base.visible = true
		joy_base.modulate = Color(1, 1, 1)
		return
	if look_pointer == -1 and pos.x > screen.x * 0.28:
		look_pointer = idx
		look_last = pos

func _handle_release(idx: int) -> void:
	if idx == joy_pointer:
		if joy_pointer != -1:
			joy_pointer = -1
			joy_vector_reset()
			joy_base.visible = false
		return
	if btn_pointers.has(idx):
		var id: String = btn_pointers[idx]
		btn_pointers.erase(idx)
		var p: Panel = buttons[id]
		p.modulate = Color(1, 1, 1)
		if id == "jump":
			Input.action_release("jump")
		return
	if idx == look_pointer:
		look_pointer = -1

func _handle_drag(idx: int, pos: Vector2, _rel: Vector2) -> void:
	if idx == joy_pointer:
		joy_update(pos)
	elif idx == look_pointer:
		var delta := pos - look_last
		look_last = pos
		_send_look(delta)

func _send_look(delta: Vector2) -> void:
	var g := get_parent()
	if g != null and g.has_method("_touch_look"):
		g._touch_look(delta)

func _joy_axis(v: float) -> float:
	return clampf(v, -1.0, 1.0)

func joy_vector_reset() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("move_right")

func joy_update(pos: Vector2) -> void:
	var offset := pos - joy_center
	if offset.length() > joy_radius:
		joy_center = pos - offset.normalized() * joy_radius
		offset = pos - joy_center
		joy_base.position = joy_center - Vector2(joy_radius * 2.1, joy_radius * 2.1) * 0.5
	var knob_size := joy_knob.size.x
	joy_knob.position = Vector2(joy_radius * 2.1, joy_radius * 2.1) * 0.5 - Vector2(knob_size, knob_size) * 0.5 + offset
	var up := _joy_axis(-offset.y / joy_radius)
	var down := _joy_axis(offset.y / joy_radius)
	var right := _joy_axis(offset.x / joy_radius)
	var left := _joy_axis(-offset.x / joy_radius)
	Input.action_press("move_forward", up)
	Input.action_press("move_back", down)
	Input.action_press("move_right", right)
	Input.action_press("move_left", left)
	if up < 0.05:
		Input.action_release("move_forward")
	if down < 0.05:
		Input.action_release("move_back")
	if right < 0.05:
		Input.action_release("move_right")
	if left < 0.05:
		Input.action_release("move_left")

func _process(_delta: float) -> void:
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
