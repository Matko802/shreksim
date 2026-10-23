class_name SwampPlayer
extends CharacterBody3D

signal interact_pressed
signal flashlight_toggled(on: bool)

const WALK_SPEED: float = 3.36
const SPRINT_SPEED: float = 6.72
const JUMP_VELOCITY: float = 4.48
const BOB_AMPLITUDE: float = 0.030
const SWAY_AMPLITUDE: float = 0.014
const TILT_AMPLITUDE: float = 0.045
const TILT_SMOOTHING: float = 10.0
const STRAFE_SMOOTHING: float = 8.0
const BOB_OMEGA_SMOOTHING: float = 18.0
const BOB_HZ: float = 1.8
const BOB_DEADZONE: float = 0.3

const STANDING_HEAD_Y: float = 1.68
const CROUCHING_HEAD_Y: float = 0.896
const HEAD_FOLLOW_SMOOTHING: float = 12.0

const STANDING_CAPSULE_HEIGHT: float = 1.932
const STANDING_CAPSULE_CENTER_Y: float = 0.966
const CROUCHING_CAPSULE_HEIGHT: float = 1.232
const CROUCHING_CAPSULE_CENTER_Y: float = 0.672
const CROUCH_TRANSITION_SMOOTHING: float = 10.0
const UNCROUCH_CEILING_CLEARANCE: float = 0.056
const CROUCH_WALK_SPEED: float = 1.792
const STEP_INTERVAL_MIN: float = 0.32
const STEP_INTERVAL_MAX: float = 0.55
const FOOTSTEP_SURFACES: Resource = preload("res://assets/footsteps/footstep_surfaces.tres")
const FLASHLIGHT_LAG_FACTOR: float = 0.4
const FLASHLIGHT_ROTATION_SMOOTHING: float = 12.0

const ZOOM_FOV_MIN: float = 20.0
const ZOOM_FOV_MAX: float = 70.0
const ZOOM_SMOOTHING: float = 10.0
const ZOOM_SCROLL_STEP: float = 5.0
const ZOOM_MIN_STEPS: float = 2.0

const JUMP_CLEARANCE: float = 0.336

var head_rest_pos: Vector3 = Vector3(0.0, STANDING_HEAD_Y, 0.0)

var _flashlight_on: bool = true
var _look_yaw_target: float = 0.0
var _look_pitch: float = 0.0
var _look_yaw_applied: float = 0.0
var _look_pitch_applied: float = 0.0
var _last_applied_yaw: float = 0.0

var _land_bounce: float = 0.0
var _was_on_floor: bool = true
var _step_radians: float = PI * 0.5
var _step_omega: float = 0.0
var _move_factor: float = 0.0
var _strafe_tilt: float = 0.0
var _bob_factor: float = 1.0
var _input_dir: Vector2 = Vector2.ZERO
var _head_pos: Vector3 = head_rest_pos
var _is_crouching: bool = false
var _crouch_blend: float = 0.0

var _zoom_fov: float = ZOOM_FOV_MAX
var _zoom_target: float = ZOOM_FOV_MAX
var _last_zoom: float = ZOOM_FOV_MAX - ZOOM_SCROLL_STEP * ZOOM_MIN_STEPS

var footstep_surfaces: Resource = FOOTSTEP_SURFACES
var _footstep_timer: float = 0.0
var _step_side: bool = false
var head: Node3D
var camera: Camera3D
var flashlight_container: Node3D
var flashlight_light: SpotLight3D
var flashlight_model: Node3D
var flashlight_model_animator: AnimationPlayer
var flashlight_toggle_player: AudioStreamPlayer3D
var footstep_player: AudioStreamPlayer3D
var _collider: CollisionShape3D
var _collider_shape: Shape3D

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	reset_physics_interpolation()
	physics_interpolation_mode = Node3D.PHYSICS_INTERPOLATION_MODE_ON
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 1.6

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.224
	capsule.height = STANDING_CAPSULE_HEIGHT
	_collider = CollisionShape3D.new()
	_collider.shape = capsule
	_collider.position = Vector3(0, STANDING_CAPSULE_CENTER_Y, 0)
	_collider_shape = _collider.shape
	add_child(_collider)

	head = Node3D.new()
	head.position = Vector3(0, STANDING_HEAD_Y, 0)
	add_child(head)

	camera = Camera3D.new()
	camera.fov = ZOOM_FOV_MAX
	camera.near = 0.05
	camera.far = 260.0
	camera.cull_mask = 3
	head.add_child(camera)

	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	footstep_player.unit_size = 4.0
	footstep_player.max_distance = 30.0
	footstep_player.max_polyphony = 2
	footstep_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(footstep_player)

	flashlight_container = (load("res://scenes/flashlight.tscn") as PackedScene).instantiate() as Node3D
	camera.add_child(flashlight_container)
	flashlight_light = flashlight_container.get_node("%FlashlightLight") as SpotLight3D
	flashlight_model = flashlight_container.get_node("Model") as Node3D
	flashlight_model_animator = flashlight_container.get_node("%ModelAnimator") as AnimationPlayer
	flashlight_toggle_player = flashlight_container.get_node("%TogglePlayer") as AudioStreamPlayer3D
	flashlight_model_animator.play(&"model_draw")

func _process(delta: float) -> void:
	var pending_yaw := _look_yaw_target - _last_applied_yaw
	if absf(pending_yaw) > 0.00001:
		rotate_y(pending_yaw)
		_last_applied_yaw = _look_yaw_target
		if SettingsBus.camera_effects_enabled:
			flashlight_light.rotate_y(-pending_yaw * FLASHLIGHT_LAG_FACTOR)
			flashlight_model.rotate_y(-pending_yaw * FLASHLIGHT_LAG_FACTOR)
	var pending_pitch := _look_pitch - _look_pitch_applied
	if absf(pending_pitch) > 0.00001 and SettingsBus.camera_effects_enabled:
		flashlight_light.rotate_x(-pending_pitch * FLASHLIGHT_LAG_FACTOR)
		flashlight_model.rotate_x(-pending_pitch * FLASHLIGHT_LAG_FACTOR)
	_look_yaw_applied = _look_yaw_target
	_look_pitch_applied = _look_pitch
	_update_camera_tilt(delta)
	_update_head_position(delta)
	_apply_head_transform()
	_update_flashlight_rotation(delta)
	if _zoom_fov != _zoom_target:
		var k: float = 1.0 - exp(-ZOOM_SMOOTHING * delta)
		_zoom_fov = lerpf(_zoom_fov, _zoom_target, k)
		if absf(_zoom_fov - _zoom_target) < 0.1:
			_zoom_fov = _zoom_target
	if camera.fov != _zoom_fov:
		camera.fov = _zoom_fov

func toggle_flashlight() -> void:
	_flashlight_on = not _flashlight_on
	flashlight_light.visible = _flashlight_on
	flashlight_model_animator.play(&"model_draw" if _flashlight_on else &"model_holster")
	flashlight_toggle_player.play()
	flashlight_toggled.emit(_flashlight_on)

func set_flashlight_on(on: bool) -> void:
	if _flashlight_on == on:
		return
	_flashlight_on = on
	flashlight_light.visible = on
	flashlight_model_animator.play(&"model_draw" if on else &"model_holster")

func is_flashlight_on() -> bool:
	return _flashlight_on

func touch_look(delta: Vector2) -> void:
	_look_yaw_target += -delta.x * SettingsBus.mouse_sensitivity
	_look_pitch += -delta.y * SettingsBus.mouse_sensitivity
	_look_pitch = clampf(_look_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_look_yaw_target += -event.relative.x * SettingsBus.mouse_sensitivity
		_look_pitch += -event.relative.y * SettingsBus.mouse_sensitivity
		_look_pitch = clampf(_look_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact"):
		interact_pressed.emit()
		get_viewport().set_input_as_handled()
	var max_zoom_out: float = ZOOM_FOV_MAX - ZOOM_SCROLL_STEP * ZOOM_MIN_STEPS
	if event is InputEventMouseButton and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_zoom_target = _last_zoom
			else:
				_last_zoom = clampf(_zoom_fov, ZOOM_FOV_MIN, max_zoom_out)
				_zoom_target = ZOOM_FOV_MAX
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_zoom_target = clampf(_zoom_target - ZOOM_SCROLL_STEP, ZOOM_FOV_MIN, max_zoom_out)
			_last_zoom = _zoom_target
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_zoom_target = clampf(_zoom_target + ZOOM_SCROLL_STEP, ZOOM_FOV_MIN, max_zoom_out)
			_last_zoom = _zoom_target

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("crouch"):
		if _is_crouching and not _can_stand_up():
			pass
		else:
			_is_crouching = not _is_crouching

	if _is_crouching and Input.is_action_just_pressed("jump") and _can_stand_up():
		_is_crouching = false

	if _is_crouching and _is_sprinting() and _can_stand_up():
		_is_crouching = false

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouching and _has_jump_clearance():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_input_dir = input_dir
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed: float = CROUCH_WALK_SPEED if _is_crouching else (SPRINT_SPEED if _is_sprinting() else WALK_SPEED)
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

	_update_crouch_transition(delta)
	_update_footsteps(delta)

func _update_flashlight_rotation(delta: float) -> void:
	var k: float = 1.0 - exp(-FLASHLIGHT_ROTATION_SMOOTHING * delta)
	flashlight_light.quaternion = flashlight_light.quaternion.slerp(Quaternion.IDENTITY, k)
	if flashlight_light.quaternion.is_equal_approx(Quaternion.IDENTITY):
		flashlight_light.quaternion = Quaternion.IDENTITY
	flashlight_model.quaternion = flashlight_model.quaternion.slerp(Quaternion.IDENTITY, k)
	if flashlight_model.quaternion.is_equal_approx(Quaternion.IDENTITY):
		flashlight_model.quaternion = Quaternion.IDENTITY

func _is_sprinting() -> bool:
	if _is_crouching:
		return false
	return Input.is_action_pressed("sprint")

func is_sprinting() -> bool:
	return _is_sprinting() and Vector2(velocity.x, velocity.z).length() > 0.2

func is_crouching() -> bool:
	return _is_crouching

func _can_stand_up() -> bool:
	var stand_shape: Shape3D = _collider_shape.duplicate()
	(stand_shape as CapsuleShape3D).height = STANDING_CAPSULE_HEIGHT - UNCROUCH_CEILING_CLEARANCE * 2.0
	var stand_center := global_position + Vector3(0.0, STANDING_CAPSULE_CENTER_Y, 0.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = stand_shape
	query.transform = Transform3D(Basis.IDENTITY, stand_center)
	query.exclude = [self.get_rid()]
	query.collide_with_areas = false
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	return space.intersect_shape(query, 1).is_empty()

func _has_jump_clearance() -> bool:
	var head_pos := global_position + Vector3(0.0, STANDING_HEAD_Y, 0.0)
	var query := PhysicsRayQueryParameters3D.create(head_pos, head_pos + Vector3(0.0, JUMP_CLEARANCE, 0.0))
	query.exclude = [self.get_rid()]
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _update_camera_tilt(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var speed_ratio := 0.0
	if horizontal_speed > BOB_DEADZONE:
		speed_ratio = clampf((horizontal_speed - BOB_DEADZONE) / (WALK_SPEED - BOB_DEADZONE), 0.0, 1.0)

	_move_factor = lerpf(_move_factor, speed_ratio, clampf(TILT_SMOOTHING * delta, 0.0, 1.0))
	var target_strafe_tilt: float = _input_dir.x
	if SettingsBus.camera_effects_enabled:
		_strafe_tilt = lerpf(_strafe_tilt, target_strafe_tilt, clampf(STRAFE_SMOOTHING * delta, 0.0, 1.0))
	else:
		_strafe_tilt = 0.0
	var target_hz: float = BOB_HZ * (horizontal_speed / SPRINT_SPEED)
	var target_omega: float = TAU * target_hz * 0.5
	_step_omega = lerpf(_step_omega, target_omega, clampf(BOB_OMEGA_SMOOTHING * delta, 0.0, 1.0))
	_step_radians += _step_omega * delta
	_bob_factor = lerpf(_bob_factor, 1.0 if is_on_floor() else 0.0, clampf(TILT_SMOOTHING * delta, 0.0, 1.0))
	if _move_factor < 0.001 and absf(_strafe_tilt) < 0.001:
		_move_factor = 0.0
		_strafe_tilt = 0.0
		_step_omega = 0.0
		_step_radians = PI * 0.5

func _apply_head_transform() -> void:
	var fx: float = 1.0 if SettingsBus.camera_effects_enabled else 0.0
	var phase: float = fposmod(_step_radians, TAU)
	var bob_shape: float = sin(phase * 2.0)
	bob_shape = bob_shape * bob_shape
	var bob: float = bob_shape * BOB_AMPLITUDE * _move_factor * _bob_factor * fx
	var sway: float = sin(phase * 2.0) * SWAY_AMPLITUDE * _move_factor * _bob_factor * fx
	var roll_amount: float = -_strafe_tilt * TILT_AMPLITUDE * _move_factor * fx
	var target_rotation := Vector3(_look_pitch_applied + bob, sway, roll_amount)
	if head.rotation != target_rotation:
		head.rotation = target_rotation
	var target_position := _head_pos + Vector3(0.0, _land_bounce, 0.0)
	if head.position != target_position:
		head.position = target_position

func _update_head_position(delta: float) -> void:
	var target_pos: Vector3 = head_rest_pos
	var k: float = 1.0 - exp(-HEAD_FOLLOW_SMOOTHING * delta)
	_head_pos = _head_pos.lerp(target_pos, k)
	_land_bounce = lerpf(_land_bounce, 0.0, clampf(14.0 * delta, 0.0, 1.0))
	if absf(_land_bounce) < 0.002:
		_land_bounce = 0.0
	if _head_pos.distance_to(head_rest_pos) < 0.004:
		_head_pos = head_rest_pos

func _update_crouch_transition(delta: float) -> void:
	var target := 1.0 if _is_crouching else 0.0
	if _crouch_blend == target:
		return
	var k: float = 1.0 - exp(-CROUCH_TRANSITION_SMOOTHING * delta)
	_crouch_blend = lerpf(_crouch_blend, target, k)
	if absf(target - _crouch_blend) < 0.0005:
		_crouch_blend = target
	head_rest_pos = Vector3(0.0, lerpf(STANDING_HEAD_Y, CROUCHING_HEAD_Y, _crouch_blend), 0.0)
	_collider.shape.height = lerpf(STANDING_CAPSULE_HEIGHT, CROUCHING_CAPSULE_HEIGHT, _crouch_blend)
	_collider.position.y = lerpf(STANDING_CAPSULE_CENTER_Y, CROUCHING_CAPSULE_CENTER_Y, _crouch_blend)

func _update_footsteps(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var on_floor: bool = is_on_floor()

	if _was_on_floor and not on_floor and velocity.y > 0.0:
		if footstep_surfaces != null:
			var jump_stream: AudioStream = footstep_surfaces.get_random_sound(&"Default")
			if jump_stream != null:
				footstep_player.stream = jump_stream
				footstep_player.pitch_scale = randf_range(0.95, 1.35)
				footstep_player.volume_linear = randf_range(0.3, 0.6)
				footstep_player.play()

	if not _was_on_floor and on_floor:
		_footstep_timer = 0.0
		_land_bounce = -0.045
		if footstep_surfaces != null:
			var land_stream: AudioStream = footstep_surfaces.get_random_sound(&"Default")
			if land_stream != null:
				footstep_player.stream = land_stream
				footstep_player.pitch_scale = randf_range(0.55, 0.9)
				footstep_player.volume_linear = randf_range(0.8, 1.4)
				footstep_player.play()

	_was_on_floor = on_floor

	if not on_floor or horizontal_speed < 0.1:
		return

	var speed_ratio: float = clamp(horizontal_speed / SPRINT_SPEED, 0.0, 1.0)
	var interval: float = lerp(STEP_INTERVAL_MAX, STEP_INTERVAL_MIN, speed_ratio)

	_footstep_timer += delta
	if _footstep_timer < interval:
		return

	_footstep_timer = 0.0
	footstep_player.volume_linear = randf_range(0.8, 1.2)
	if footstep_surfaces != null:
		var side := StringName(&"DefaultL") if _step_side else StringName(&"DefaultR")
		_step_side = not _step_side
		var step_stream: AudioStream = footstep_surfaces.get_random_sound(side)
		if step_stream == null:
			step_stream = footstep_surfaces.get_random_sound(&"Default")
		if step_stream != null:
			footstep_player.stream = step_stream
			footstep_player.pitch_scale = randf_range(0.85, 1.15)
			footstep_player.play()
