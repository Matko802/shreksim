extends SceneTree

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var fails := 0
	fails += await _probe_flashlight()
	fails += await _probe_trees()
	fails += await _probe_joystick()
	print("PROBE FAILS=", fails)
	quit(1 if fails > 0 else 0)

func _probe_flashlight() -> int:
	var f := 0
	var container = (load("res://scenes/flashlight.tscn") as PackedScene).instantiate()
	if container == null:
		print("FAIL: flashlight instance")
		return 1
	var light := container.get_node("%FlashlightLight") as SpotLight3D
	var anim := container.get_node("%ModelAnimator") as AnimationPlayer
	var sound := container.get_node("%TogglePlayer") as AudioStreamPlayer3D
	if light == null or anim == null or sound == null:
		print("FAIL: flashlight nodes missing")
		return 1
	if not anim.has_animation("model_draw") or not anim.has_animation("model_holster") or not anim.has_animation("RESET"):
		print("FAIL: flashlight anims missing")
		f += 1
	if absf(anim.get_animation("model_draw").length - 0.3) > 0.001:
		print("FAIL: draw length")
		f += 1
	if light.light_energy != 16.0:
		print("FAIL: light energy")
		f += 1
	if Vector3(0.66864, -0.80864, -0.364).distance_to(container.position) > 0.0001:
		print("FAIL: container pose ", container.position)
		f += 1
	var meshes := container.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		print("FAIL: no meshes in flashlight model")
		f += 1
	else:
		var mi := meshes[0] as MeshInstance3D
		if mi.material_override == null:
			print("FAIL: no material override")
			f += 1
		if mi.layers != 2:
			print("FAIL: mesh layers ", mi.layers)
			f += 1
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			print("FAIL: mesh shadows on")
			f += 1
	if sound.stream == null:
		print("FAIL: no toggle stream")
		f += 1
	print("flashlight ok=", f)
	return f

func _probe_trees() -> int:
	var f := 0
	var map = (load("res://scenes/map.tscn") as PackedScene).instantiate()
	var trees := map.get_node("Trees")
	var count := trees.get_child_count()
	print("trees=", count)
	var visible_flat := 0
	var hidden_pair := 0
	for t in trees.get_children():
		if t.get_node_or_null("TreeMesh") != null:
			print("FAIL: leftover tree mesh on ", t.name)
			f += 1
		var a := t.get_node_or_null("CrossA") as Sprite3D
		var b := t.get_node_or_null("CrossB") as Sprite3D
		var flat := t.get_node_or_null("Flat")
		if flat != null:
			print("FAIL: old flat billboard on ", t.name)
			f += 1
		if a == null or b == null:
			print("FAIL: missing sprites on ", t.name)
			f += 1
			continue
		if a.visibility_range_end != 0.0 or b.visibility_range_end != 0.0:
			print("FAIL: limited range on ", t.name)
			f += 1
		if t is StaticBody3D:
			var col := t.get_node_or_null("Collision") as CollisionShape3D
			if col == null or col.shape == null:
				print("FAIL: collision missing on ", t.name)
				f += 1
	print("editor flat visible=", visible_flat, " crossed hidden=", hidden_pair)
	print("trees ok=", f)
	return f

func _probe_joystick() -> int:
	var f := 0
	var joy := VirtualJoystick.new()
	joy.action_left = &"move_left"
	joy.action_right = &"move_right"
	joy.action_up = &"move_forward"
	joy.action_down = &"move_back"
	root.add_child(joy)
	joy.position = Vector2(0, 0)
	joy.size = Vector2(200, 200)
	Input.emulate_mouse_from_touch = false
	await process_frame
	joy.pressed.connect(func() -> void: print("JOY PRESSED"))
	joy.released.connect(func(v: Vector2) -> void: print("JOY RELEASED ", v))
	joy.flicked.connect(func(v: Vector2) -> void: print("JOY FLICK ", v))
	joy.tapped.connect(func() -> void: print("JOY TAPPED"))
	var t := InputEventScreenTouch.new()
	t.index = 7
	t.pressed = true
	t.position = Vector2(100, 40)
	root.push_input(t)
	await process_frame
	print("joy rect=", joy.get_global_rect(), " size=", joy.size)
	if not Input.is_action_pressed("move_forward"):
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = true
		m.position = Vector2(100, 40)
		m.global_position = m.position
		root.push_input(m)
		await process_frame
		print("after mouse press strength=", Input.get_action_strength("move_forward"))
		var mr := InputEventMouseButton.new()
		mr.button_index = MOUSE_BUTTON_LEFT
		mr.pressed = false
		mr.position = m.position
		mr.global_position = m.position
		root.push_input(mr)
		await process_frame
		var t3 := t.duplicate() as InputEventScreenTouch
		print("FAIL: joystick up not pressed, strength=", Input.get_action_strength("move_forward"))
		f += 1
	else:
		print("joystick up strength=", Input.get_action_strength("move_forward"))
	var r := InputEventScreenTouch.new()
	r.index = 7
	r.pressed = false
	r.position = Vector2(100, 40)
	Input.parse_input_event(r)
	await process_frame
	if Input.is_action_pressed("move_forward") or Input.get_action_strength("move_forward") > 0.0:
		print("FAIL: joystick release not applied")
		f += 1
	root.remove_child(joy)
	joy.free()
	print("joystick ok=", f)
	return f

func _probe_pause() -> int:
	var menu = (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
	if menu == null:
		print("FAIL: pause menu instance")
		return 1
	for u in ["%SettingsCenter", "%SettingsBtn", "%BackSettings", "%ResetBtn", "%SensSlider", "%SensValue", "%FXCheck", "%FSCheck", "%LangOption", "%ResumeBtn", "%RestartBtn", "%MenuBtn"]:
		if menu.get_node_or_null(NodePath(u)) == null:
			print("FAIL: missing ui node ", u)
			return 1
	print("pause structure ok")
	return 0
