class_name SwampPlayer
extends CharacterBody3D

signal interact_pressed
signal flashlight_toggled(on: bool)

const WALK_SPEED: float = 84.0
const SPRINT_SPEED: float = 168.0
const JUMP_VELOCITY: float = 112.0
const BOB_AMPLITUDE: float = 0.030
const SWAY_AMPLITUDE: float = 0.014
const LEAN_AMPLITUDE: float = 0.055
const TILT_AMPLITUDE: float = 0.045
const TILT_SMOOTHING: float = 10.0
const STRAFE_SMOOTHING: float = 8.0
const FORWARD_TILT_SMOOTHING: float = 8.0
const BOB_OMEGA_SMOOTHING: float = 18.0
const BOB_HZ: float = 1.8
const BOB_DEADZONE: float = 8.4

const STANDING_HEAD_Y: float = 42.0
const CROUCHING_HEAD_Y: float = 22.4
const HEAD_FOLLOW_SMOOTHING: float = 12.0

const STANDING_CAPSULE_HEIGHT: float = 48.3
const STANDING_CAPSULE_CENTER_Y: float = 24.15
const CROUCHING_CAPSULE_HEIGHT: float = 30.8
const CROUCHING_CAPSULE_CENTER_Y: float = 16.8
const CROUCH_TRANSITION_SMOOTHING: float = 10.0
const UNCROUCH_CEILING_CLEARANCE: float = 1.4
const CROUCH_WALK_SPEED: float = 44.8

const ZOOM_FOV_MIN: float = 20.0
const ZOOM_FOV_MAX: float = 70.0
const ZOOM_SMOOTHING: float = 10.0
const ZOOM_SCROLL_STEP: float = 5.0
const ZOOM_MIN_STEPS: float = 2.0

const FLASHLIGHT_LAG_FACTOR: float = 0.4
const FLASHLIGHT_ROTATION_SMOOTHING: float = 12.0
const VM_MODEL_SCALE: float = 14.0
const VM_LIGHT_ENERGY: float = 5600.0
const VM_POSE_RESET: Vector3 = Vector3(16.716, -20.216, -9.1)
const VM_POSE_DRAW_START: Vector3 = Vector3(-16.884, -20.216, -9.1)
const VM_POSE_ON: Vector3 = Vector3(-16.884, -11.816, -11.9)
const VM_RO_LIMIT: Vector3 = Vector3(-1.5707964, 0, 0)
const VM_ROT_RESET: Vector3 = Vector3(-0.5235988, 0, 0)
const VM_LIGHT_OFFSET: Vector3 = Vector3(16.8, 11.2, 11.2)
const JUMP_CLEARANCE: float = 8.4

const VIEWMODEL_SHADER: Shader = preload("res://scripts/viewmodel.gdshader")
const FLASHLIGHT_ALBEDO: Texture2D = preload("res://assets/textures/flashlight_albedo.png")

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
var _forward_tilt: float = 0.0
var _bob_factor: float = 1.0
var _input_dir: Vector2 = Vector2.ZERO
var _head_pos: Vector3 = head_rest_pos
var _is_crouching: bool = false
var _crouch_blend: float = 0.0

var _zoom_fov: float = ZOOM_FOV_MAX
var _zoom_target: float = ZOOM_FOV_MAX
var _last_zoom: float = ZOOM_FOV_MAX - ZOOM_SCROLL_STEP * ZOOM_MIN_STEPS

var footstep_loop_stream: AudioStream
var footstep_oneshot_streams: Array[AudioStream] = []

var head: Node3D
var camera: Camera3D
var flashlight_container: Node3D
var flashlight_light: SpotLight3D
var flashlight_model_animator: AnimationPlayer
var flashlight_toggle_player: AudioStreamPlayer3D
var footstep_player: AudioStreamPlayer3D
var footstep_oneshot_player: AudioStreamPlayer3D
var _collider: CollisionShape3D
var _collider_shape: Shape3D

func _ready() -> void:
	physics_interpolation_mode = Node3D.PHYSICS_INTERPOLATION_MODE_ON
	collision_layer = 2
	collision_mask = 1

	var capsule := CapsuleShape3D.new()
	capsule.radius = 5.6
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
	camera.near = 0.3
	camera.far = 12000.0
	camera.cull_mask = 3
	head.add_child(camera)

	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.unit_size = 168.0
	footstep_player.max_distance = 700.0
	footstep_player.max_polyphony = 2
	add_child(footstep_player)

	footstep_oneshot_player = AudioStreamPlayer3D.new()
	footstep_oneshot_player.unit_size = 168.0
	footstep_oneshot_player.max_distance = 700.0
	footstep_oneshot_player.max_polyphony = 2
	add_child(footstep_oneshot_player)

	flashlight_toggle_player = AudioStreamPlayer3D.new()
	flashlight_toggle_player.stream = load("res://assets/sounds/sfx_flashlight_toggle.wav")
	flashlight_toggle_player.unit_size = 168.0
	flashlight_toggle_player.max_distance = 700.0
	add_child(flashlight_toggle_player)

	_build_flashlight_viewmodel()
	flashlight_model_animator.play(&"model_draw")

	if footstep_loop_stream != null:
		footstep_player.stream = footstep_loop_stream

func _build_flashlight_viewmodel() -> void:
	flashlight_container = Node3D.new()
	flashlight_container.transform = Transform3D(Basis.IDENTITY, VM_POSE_RESET)
	flashlight_container.rotation = VM_ROT_RESET
	camera.add_child(flashlight_container)

	var model: Node3D = (load("res://assets/models/flashlight.glb") as PackedScene).instantiate()
	model.scale = Vector3(VM_MODEL_SCALE, VM_MODEL_SCALE, VM_MODEL_SCALE)
	flashlight_container.add_child(model)
	var mat := ShaderMaterial.new()
	mat.shader = VIEWMODEL_SHADER
	mat.set_shader_parameter("albedo_texture", FLASHLIGHT_ALBEDO)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		mi.material_override = mat
		mi.layers = 2
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	flashlight_light = SpotLight3D.new()
	flashlight_light.transform = Transform3D(Basis.IDENTITY, VM_LIGHT_OFFSET)
	flashlight_light.light_energy = VM_LIGHT_ENERGY
	flashlight_light.shadow_enabled = false
	flashlight_light.spot_range = 420.0
	flashlight_light.spot_angle = 25.0
	flashlight_light.spot_angle_attenuation = 2.0
	flashlight_container.add_child(flashlight_light)

	var lib := AnimationLibrary.new()
	lib.add_animation(&"RESET", _viewmodel_reset_anim())
	lib.add_animation(&"model_draw", _viewmodel_draw_anim())
	lib.add_animation(&"model_holster", _viewmodel_holster_anim())
	flashlight_model_animator = AnimationPlayer.new()
	flashlight_model_animator.libraries = {"": lib}
	flashlight_model_animator.root_node = NodePath("..")
	flashlight_container.add_child(flashlight_model_animator)

func _viewmodel_reset_anim() -> Animation:
	var a := Animation.new()
	a.length = 0.001
	a.add_track(Animation.TYPE_VALUE)
	var t_pos := a.get_track_count() - 1
	a.track_set_path(t_pos, ".:position")
	a.track_set_interpolation_type(t_pos, Animation.INTERPOLATION_LINEAR)
	a.track_insert_key(t_pos, 0.0, VM_POSE_RESET)
	a.add_track(Animation.TYPE_VALUE)
	var t_rot := a.get_track_count() - 1
	a.track_set_path(t_rot, ".:rotation")
	a.track_set_interpolation_type(t_rot, Animation.INTERPOLATION_LINEAR)
	a.track_insert_key(t_rot, 0.0, VM_ROT_RESET)
	a.add_track(Animation.TYPE_VALUE)
	var t_vis := a.get_track_count() - 1
	a.track_set_path(t_vis, ".:visible")
	a.track_insert_key(t_vis, 0.0, false)
	return a

func _viewmodel_draw_anim() -> Animation:
	var a := Animation.new()
	a.length = 0.3
	a.step = 0.01
	a.add_track(Animation.TYPE_VALUE)
	var t_pos := a.get_track_count() - 1
	a.track_set_path(t_pos, ".:position")
	a.track_set_interpolation_type(t_pos, Animation.INTERPOLATION_LINEAR)
	a.track_insert_key(t_pos, 0.0, VM_POSE_DRAW_START)
	a.track_insert_key(t_pos, 0.3, VM_POSE_ON)
	a.add_track(Animation.TYPE_VALUE)
	var t_vis := a.get_track_count() - 1
	a.track_set_path(t_vis, ".:visible")
	a.track_insert_key(t_vis, 0.0, true)
	a.add_track(Animation.TYPE_VALUE)
	var t_rot := a.get_track_count() - 1
	a.track_set_path(t_rot, ".:rotation")
	a.track_set_interpolation_type(t_rot, Animation.INTERPOLATION_LINEAR)
	a.track_insert_key(t_rot, 0.0, VM_RO_LIMIT)
	a.track_insert_key(t_rot, 0.3, Vector3.ZERO)
	return a

func _viewmodel_holster_anim() -> Animation:
	var a := Animation.new()
	a.length = 0.3
	a.step = 0.01
	a.add_track(Animation.TYPE_VALUE)
	var t_pos := a.get_track_count() - 1
	a.track_set_path(t_pos, ".:position")
	a.track_set_interpolation_type(t_pos, Animation.INTERPOLATION_LINEAR)
	a.track_insert_key(t_pos, 0.0, VM_POSE_ON)
	a.track_insert_key(t_pos, 0.3, VM_POSE_RESET)
	a.add_track(Animation.TYPE_VALUE)
	var t_vis := a.get_track_count() - 1
	a.track_set_path(t_vis, ".:visible")
	a.track_insert_key(t_vis, 0.3, false)
	a.add_track(Animation.TYPE_VALUE)
	var t_rot := a.get_track_count() - 1
	a.track_set_path(t_rot, ".:rotation")
	a.track_set_interpolation_type(t_rot, Animation.INTERPOLATION_LINEAR)
	a.track_insert_key(t_rot, 0.0, Vector3.ZERO)
	a.track_insert_key(t_rot, 0.3, VM_RO_LIMIT)
	return a

func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-ZOOM_SMOOTHING * delta)
	_zoom_fov = lerpf(_zoom_fov, _zoom_target, k)
	if absf(_zoom_fov - _zoom_target) < 0.1:
		_zoom_fov = _zoom_target
	camera.fov = _zoom_fov

func set_footstep_streams(loop: AudioStream, one_shots: Array[AudioStream]) -> void:
	footstep_loop_stream = loop
	footstep_oneshot_streams = one_shots
	if loop != null:
		var wav := loop as AudioStreamWAV
		if wav != null:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	if footstep_player != null and footstep_loop_stream != null:
		footstep_player.stream = footstep_loop_stream

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
	var pending_yaw: float = _look_yaw_target - _last_applied_yaw
	if absf(pending_yaw) > 0.00001:
		rotate_y(pending_yaw)
		_last_applied_yaw = _look_yaw_target
		if SettingsBus.camera_effects_enabled:
			flashlight_container.rotate_y(-pending_yaw * FLASHLIGHT_LAG_FACTOR)
	var pending_pitch: float = _look_pitch - _look_pitch_applied
	if absf(pending_pitch) > 0.00001 and SettingsBus.camera_effects_enabled:
		flashlight_container.rotate_x(-pending_pitch * FLASHLIGHT_LAG_FACTOR)
	_look_yaw_applied = _look_yaw_target
	_look_pitch_applied = _look_pitch

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

	_update_camera_tilt(delta)
	_update_head_position(delta)
	_apply_head_transform()
	_update_flashlight_rotation(delta)

func _update_flashlight_rotation(delta: float) -> void:
	var k: float = 1.0 - exp(-FLASHLIGHT_ROTATION_SMOOTHING * delta)
	flashlight_container.quaternion = flashlight_container.quaternion.slerp(Quaternion.IDENTITY, k)
	if flashlight_container.quaternion.is_equal_approx(Quaternion.IDENTITY):
		flashlight_container.quaternion = Quaternion.IDENTITY

func _is_sprinting() -> bool:
	if _is_crouching:
		return false
	return Input.is_action_pressed("sprint")

func is_sprinting() -> bool:
	return _is_sprinting() and Vector2(velocity.x, velocity.z).length() > 5.0

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
	var target_forward_tilt: float = _input_dir.y
	if SettingsBus.camera_effects_enabled:
		_strafe_tilt = lerpf(_strafe_tilt, target_strafe_tilt, clampf(STRAFE_SMOOTHING * delta, 0.0, 1.0))
		_forward_tilt = lerpf(_forward_tilt, target_forward_tilt, clampf(FORWARD_TILT_SMOOTHING * delta, 0.0, 1.0))
	else:
		_strafe_tilt = 0.0
		_forward_tilt = 0.0
	var target_hz: float = BOB_HZ * (horizontal_speed / SPRINT_SPEED)
	var target_omega: float = TAU * target_hz * 0.5
	_step_omega = lerpf(_step_omega, target_omega, clampf(BOB_OMEGA_SMOOTHING * delta, 0.0, 1.0))
	_step_radians += _step_omega * delta
	_bob_factor = lerpf(_bob_factor, 1.0 if is_on_floor() else 0.0, clampf(TILT_SMOOTHING * delta, 0.0, 1.0))
	if _move_factor < 0.001 and absf(_strafe_tilt) < 0.001 and absf(_forward_tilt) < 0.001:
		_move_factor = 0.0
		_strafe_tilt = 0.0
		_forward_tilt = 0.0
		_step_omega = 0.0
		_step_radians = PI * 0.5

func _apply_head_transform() -> void:
	var phase: float = fposmod(_step_radians, TAU)
	var bob_shape: float = sin(phase * 2.0)
	bob_shape = bob_shape * bob_shape
	var bob: float = bob_shape * BOB_AMPLITUDE * _move_factor * _bob_factor
	var sway: float = sin(phase * 2.0) * SWAY_AMPLITUDE * _move_factor * _bob_factor
	var roll_amount: float = -_strafe_tilt * TILT_AMPLITUDE * _move_factor
	var forward_lean: float = -_forward_tilt * LEAN_AMPLITUDE * _move_factor
	head.rotation = Vector3(_look_pitch_applied + bob + forward_lean, sway, roll_amount)
	head.position = _head_pos + Vector3(0.0, _land_bounce, 0.0)

func _update_head_position(delta: float) -> void:
	var target_pos: Vector3 = head_rest_pos
	var k: float = 1.0 - exp(-HEAD_FOLLOW_SMOOTHING * delta)
	_head_pos = _head_pos.lerp(target_pos, k)
	_land_bounce = lerpf(_land_bounce, 0.0, clampf(14.0 * delta, 0.0, 1.0))
	if absf(_land_bounce) < 0.05:
		_land_bounce = 0.0
	if _head_pos.distance_to(head_rest_pos) < 0.1:
		_head_pos = head_rest_pos

func _update_crouch_transition(delta: float) -> void:
	var target := 1.0 if _is_crouching else 0.0
	var k: float = 1.0 - exp(-CROUCH_TRANSITION_SMOOTHING * delta)
	_crouch_blend = lerpf(_crouch_blend, target, k)
	if absf(target - _crouch_blend) < 0.0005:
		_crouch_blend = target
	head_rest_pos = Vector3(0.0, lerpf(STANDING_HEAD_Y, CROUCHING_HEAD_Y, _crouch_blend), 0.0)
	_collider.shape.height = lerpf(STANDING_CAPSULE_HEIGHT, CROUCHING_CAPSULE_HEIGHT, _crouch_blend)
	_collider.position.y = lerpf(STANDING_CAPSULE_CENTER_Y, CROUCHING_CAPSULE_CENTER_Y, _crouch_blend)

func _update_footsteps(_delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var on_floor := is_on_floor()

	if _was_on_floor and not on_floor and velocity.y > 0.0:
		_play_step_oneshot(randf_range(1.25, 1.45), 0.5)
	elif not _was_on_floor and on_floor:
		_land_bounce = -1.2
		_play_step_oneshot(randf_range(0.75, 0.95), 1.0)
	_was_on_floor = on_floor

	var walking := on_floor and horizontal_speed > 2.0
	if not walking:
		if footstep_player.playing:
			footstep_player.stop()
		return
	var cadence: float = clampf((horizontal_speed - WALK_SPEED) / (SPRINT_SPEED - WALK_SPEED), 0.0, 1.0)
	footstep_player.pitch_scale = 2.0 + cadence * 0.3
	if not footstep_player.playing and footstep_loop_stream != null:
		footstep_player.stream = footstep_loop_stream
		footstep_player.volume_db = 0.0
		footstep_player.play()

func _play_step_oneshot(pitch: float, volume: float) -> void:
	if footstep_oneshot_streams.is_empty():
		return
	footstep_oneshot_player.stream = footstep_oneshot_streams[randi() % footstep_oneshot_streams.size()]
	footstep_oneshot_player.pitch_scale = pitch
	footstep_oneshot_player.volume_db = linear_to_db(volume)
	footstep_oneshot_player.play()
