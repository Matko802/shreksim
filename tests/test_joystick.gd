extends Control

func _ready() -> void:
	await get_tree().process_frame
	var joy := SwampVirtualJoystick.new()
	joy.action_left = &"move_left"
	joy.action_right = &"move_right"
	joy.action_up = &"move_forward"
	joy.action_down = &"move_back"
	add_child(joy)
	joy.position = Vector2.ZERO
	joy.size = Vector2(200, 200)
	joy.pressed.connect(func() -> void: print("JOY PRESSED"))
	joy.flicked.connect(func(v: Vector2) -> void: print("JOY FLICK ", v))
	Input.emulate_mouse_from_touch = false
	var t := InputEventScreenTouch.new()
	t.index = 3
	t.pressed = true
	t.position = Vector2(100, 40)
	Input.parse_input_event(t)
	await get_tree().process_frame
	await get_tree().process_frame
	print("up strength=", Input.get_action_strength("move_forward"))
	var t2 := InputEventScreenDrag.new()
	t2.index = 3
	t2.position = Vector2(150, 45)
	t2.relative = Vector2(50, 5)
	t2.velocity = Vector2.ZERO
	Input.parse_input_event(t2)
	await get_tree().process_frame
	await get_tree().process_frame
	print("right strength=", Input.get_action_strength("move_right"), " up strength=", Input.get_action_strength("move_forward"))
	var t3 := InputEventScreenTouch.new()
	t3.index = 3
	t3.pressed = false
	t3.position = Vector2(150, 45)
	Input.parse_input_event(t3)
	await get_tree().process_frame
	await get_tree().process_frame
	print("released, up strength=", Input.get_action_strength("move_forward"))
	get_tree().quit(0 if Input.get_action_strength("move_forward") == 0.0 else 1)
