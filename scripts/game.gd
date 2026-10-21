extends Node3D

const WORLD_HALF := 2000.0
const TREE_COUNT := 40
const TREE_RADIUS := 64.0
const TOTAL_PAGES := 8
const START_TIME := 90.0
const KILL_RADIUS := 70.0
const CAMERA_HEIGHT := 44.0
const ONION_RANGE := 360.0

const THREAT_RANGE := 950.0
const ENEMY_FOLLOW_BASE := 60.0
const ENEMY_FOLLOW_PER_PAGE := 12.0
const ENEMY_SPEED_CAP := 160.0
const OBSERVED_FACTOR := 0.35
const OBSERVE_DOT := 0.62
const OBSERVE_RANGE := 1100.0

const TREE_TEXTURES := [
	"res://assets/images/trees/tree1.png",
	"res://assets/images/trees/tree2.png",
	"res://assets/images/trees/tree5.png",
]

const PHASES := [
	{"top": Color(0.3, 0.52, 0.85), "horizon": Color(0.8, 0.88, 0.86), "fog": 0.00016, "sun": 1.35, "sun_color": Color(1.0, 0.97, 0.9), "ambient_energy": 1.0, "grass": Color(0.5, 0.68, 0.4), "sky_affect": 0.12, "day": 1.0},
	{"top": Color(0.42, 0.64, 0.95), "horizon": Color(0.88, 0.94, 0.94), "fog": 0.00012, "sun": 1.6, "sun_color": Color(1.0, 1.0, 0.98), "ambient_energy": 1.15, "grass": Color(0.55, 0.74, 0.44), "sky_affect": 0.1, "day": 1.0},
	{"top": Color(0.36, 0.55, 0.8), "horizon": Color(0.85, 0.82, 0.7), "fog": 0.0002, "sun": 1.3, "sun_color": Color(1.0, 0.93, 0.82), "ambient_energy": 1.0, "grass": Color(0.5, 0.66, 0.4), "sky_affect": 0.16, "day": 0.85},
	{"top": Color(0.3, 0.4, 0.62), "horizon": Color(0.9, 0.7, 0.48), "fog": 0.00025, "sun": 1.05, "sun_color": Color(1.0, 0.78, 0.55), "ambient_energy": 0.85, "grass": Color(0.46, 0.58, 0.34), "sky_affect": 0.2, "day": 0.6},
	{"top": Color(0.22, 0.24, 0.42), "horizon": Color(0.75, 0.5, 0.35), "fog": 0.0006, "sun": 0.7, "sun_color": Color(1.0, 0.55, 0.35), "ambient_energy": 0.62, "grass": Color(0.38, 0.44, 0.26), "sky_affect": 0.24, "day": 0.4},
	{"top": Color(0.1, 0.11, 0.26), "horizon": Color(0.35, 0.26, 0.3), "fog": 0.0012, "sun": 0.4, "sun_color": Color(0.7, 0.4, 0.45), "ambient_energy": 0.45, "grass": Color(0.26, 0.3, 0.2), "sky_affect": 0.28, "day": 0.2},
	{"top": Color(0.045, 0.055, 0.15), "horizon": Color(0.12, 0.1, 0.14), "fog": 0.0022, "sun": 0.22, "sun_color": Color(0.4, 0.32, 0.55), "ambient_energy": 0.32, "grass": Color(0.16, 0.2, 0.13), "sky_affect": 0.32, "day": 0.05},
	{"top": Color(0.012, 0.02, 0.05), "horizon": Color(0.035, 0.045, 0.06), "fog": 0.0035, "sun": 0.1, "sun_color": Color(0.3, 0.35, 0.55), "ambient_energy": 0.22, "grass": Color(0.11, 0.15, 0.1), "sky_affect": 0.36, "day": 0.0},
	{"top": Color(0.004, 0.008, 0.02), "horizon": Color(0.012, 0.015, 0.02), "fog": 0.005, "sun": 0.03, "sun_color": Color(0.2, 0.25, 0.4), "ambient_energy": 0.14, "grass": Color(0.08, 0.12, 0.08), "sky_affect": 0.4, "day": 0.0},
]

const SKY_CUBE_SHADER: String = """
shader_type sky;

uniform sampler2D face : source_color, filter_linear_mipmap;
uniform vec3 day_top : source_color = vec3(0.24, 0.53, 0.88);
uniform vec3 day_horizon : source_color = vec3(0.68, 0.83, 1.0);
uniform float day_mix : hint_range(0.0, 1.0) = 0.0;

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 a = vec3(abs(dir.x), abs(dir.y), abs(dir.z));
	vec2 uv;
	if (a.x > a.y && a.x > a.z) {
		uv = vec2(-dir.z, dir.y) / a.x;
	} else if (a.y > a.x && a.y > a.z) {
		uv = vec2(dir.x, -dir.z) / a.y;
	} else {
		uv = vec2(dir.x, dir.y) / a.z;
	}
	vec3 night_col = texture(face, uv * 0.5 + 0.5).rgb;
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 day_col = mix(day_horizon, day_top, pow(h, 0.75));
	COLOR = mix(night_col, day_col, day_mix);
}
"""

const PHASE_SMOOTHING := 1.6

var endless := false
var game_over := false
var phase := 0
var _phase_target: Dictionary = {}
var _phase_started := false
var won := false
var paused := false
var pages := 0
var time_left := START_TIME

var player: SwampPlayer
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var _day_mix := 1.0
var ground_mat: StandardMaterial3D

var enemy: Sprite3D
var enemy_active := false
var enemy_bob_t := 0.0
var threat := 0.0

var onions: Array[Area3D] = []
var onion_bob_t := 0.0
var tree_positions: Array[Vector2] = []

var hud: CanvasLayer
var pause_menu: CanvasLayer
var static_frames: Array[Texture2D] = []
var static_time := 0.0
var static_playing := false

var music: AudioStreamPlayer
var static_sound: AudioStreamPlayer
var onion_sound: AudioStreamPlayer
var allstar: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	endless = GameState.game_type == "endless"
	_build_world()
	_build_player()
	_build_onions()
	if not endless:
		_build_enemy()
	_build_ui()
	_build_audio()
	_apply_phase(0)
	_start_music_phase(0)
	hud.set_timer_visible(not endless)
	hud.set_pages_text(_pages_text())
	_objective_text()
	player.interact_pressed.connect(_try_collect_center)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
	hud = (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	pause_menu = (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
	add_child(pause_menu)
	add_child((load("res://scenes/touch_ui.tscn") as PackedScene).instantiate())
	pause_menu.resume_requested.connect(_toggle_pause)
	pause_menu.restart_requested.connect(_restart)
	pause_menu.menu_requested.connect(_to_menu)
	for i in 5:
		static_frames.append(load("res://assets/images/static/static%d.png" % i))

func _build_player() -> void:
	player = SwampPlayer.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector3(0, CAMERA_HEIGHT, 0)
	add_child(player)

func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var ground_noise := FastNoiseLite.new()
	ground_noise.seed = 7
	ground_noise.frequency = 0.02
	ground_noise.fractal_octaves = 3
	ground_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var half := 128
	var base := Image.create(half, half, false, Image.FORMAT_RGB8)
	for y in half:
		for x in half:
			var v := ground_noise.get_noise_2d(x * 1.0, y * 1.0)
			var t := clampf(0.5 + v * 0.5, 0.0, 1.0)
			var lum := lerpf(0.8, 1.15, t)
			var b := lum * lerpf(0.9, 1.04, t)
			base.set_pixel(x, y, Color(lum * 0.97, lum, b))
	var img := Image.create(half * 2, half * 2, false, Image.FORMAT_RGB8)
	for y2 in half * 2:
		for x2 in half * 2:
			var sx := x2 if x2 < half else half * 2 - 1 - x2
			var sy := y2 if y2 < half else half * 2 - 1 - y2
			img.set_pixel(x2, y2, base.get_pixel(sx, sy))
	var nt := ImageTexture.create_from_image(img)
	ground_mat = StandardMaterial3D.new()
	ground_mat.roughness = 1.0
	ground_mat.albedo_texture = nt
	ground_mat.uv1_scale = Vector3(90, 90, 90)
	ground_mat.albedo_color = PHASES[0]["grass"]
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(24000, 24000)
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.material_override = ground_mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var ground_body := StaticBody3D.new()
	ground_body.collision_layer = 1
	var gb_shape := CollisionShape3D.new()
	var plane_shape := WorldBoundaryShape3D.new()
	gb_shape.shape = plane_shape
	ground_body.add_child(gb_shape)
	add_child(ground_body)

	var walls := StaticBody3D.new()
	walls.collision_layer = 1
	var wall_positions := [
		[Vector3(WORLD_HALF, 200, 0), Vector3(6, 400, WORLD_HALF * 2.4)],
		[Vector3(-WORLD_HALF, 200, 0), Vector3(6, 400, WORLD_HALF * 2.4)],
		[Vector3(0, 200, WORLD_HALF), Vector3(WORLD_HALF * 2.4, 400, 6)],
		[Vector3(0, 200, -WORLD_HALF), Vector3(WORLD_HALF * 2.4, 400, 6)],
	]
	for wp in wall_positions:
		var ws := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wp[1]
		ws.shape = box
		ws.position = wp[0]
		walls.add_child(ws)
	add_child(walls)

	var sky_shader := Shader.new()
	sky_shader.code = SKY_CUBE_SHADER
	var sky_mat_ref := ShaderMaterial.new()
	sky_mat_ref.shader = sky_shader
	sky_mat_ref.set_shader_parameter("face", load("res://assets/images/sky/sky_starface.png"))
	sky_mat_ref.set_shader_parameter("day_mix", 1.0)
	sky_mat = sky_mat_ref
	var sky := Sky.new()
	sky.sky_material = sky_mat_ref
	env.sky = sky
	env.background_energy_multiplier = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.26, 0.2)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 1000.0
	add_child(sun)

	var trees := StaticBody3D.new()
	trees.collision_layer = 1
	add_child(trees)
	tree_positions.clear()

	for i in TREE_COUNT:
		var pos := _tree_pos()
		tree_positions.append(pos)
		var use_tex := randi() % TREE_TEXTURES.size()
		var tex_path: String = TREE_TEXTURES[use_tex]
		var tex: Texture2D = load(tex_path)
		var s := randf_range(0.75, 1.35)
		var h := tex.get_height() * 0.22 * s
		for ang in [45.0, -45.0]:
			var tr := Sprite3D.new()
			tr.texture = tex
			tr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			tr.shaded = true
			tr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			tr.pixel_size = 0.22
			tr.scale = Vector3(s, s, s)
			tr.position = Vector3(pos.x, h * 0.46, pos.y)
			tr.rotation.y = deg_to_rad(ang)
			tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tr)
		var cshape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = TREE_RADIUS * s * 0.55
		cyl.height = 800.0
		cshape.shape = cyl
		cshape.position = Vector3(pos.x, 400, pos.y)
		trees.add_child(cshape)

func _tree_pos() -> Vector2:
	for attempt in 40:
		var ang := randf() * TAU
		var rad := sqrt(lerpf(460.0 * 460.0, 1150.0 * 1150.0, randf()))
		var p := Vector2(cos(ang), sin(ang)) * rad
		var ok := true
		for tp in tree_positions:
			if tp.distance_to(p) < 260.0:
				ok = false
				break
		if ok:
			return p
	return Vector2(460, 0)

func _build_onions() -> void:
	var count := TOTAL_PAGES if not endless else 5
	for i in count:
		onions.append(_spawn_onion())

func _spawn_onion() -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 2

	var sprite := Sprite3D.new()
	sprite.texture = load("res://assets/images/items/onion.png")
	sprite.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.pixel_size = 0.31
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = Vector3(0, 64, 0)
	area.add_child(sprite)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 34.0
	shape.shape = sphere
	shape.position = Vector3(0, 64, 0)
	area.add_child(shape)

	var pos := _onion_pos()
	area.position = Vector3(pos.x, 0, pos.y)
	area.set_meta("onion", true)
	area.set_meta("base_y", 0.0)
	add_child(area)
	return area

func _onion_pos() -> Vector2:
	for attempt in 40:
		var ang := randf() * TAU
		var rad := sqrt(lerpf(520.0 * 520.0, 1150.0 * 1150.0, randf()))
		var p := Vector2(cos(ang), sin(ang)) * rad
		if p.length() <= 520.0:
			continue
		var ok := true
		for tp in tree_positions:
			if tp.distance_to(p) < TREE_RADIUS + 70.0:
				ok = false
				break
		if not ok:
			continue
		for o in onions:
			if not is_instance_valid(o):
				continue
			if Vector2(o.position.x, o.position.z).distance_to(p) < 350.0:
				ok = false
				break
		if ok:
			return p
	return Vector2(WORLD_HALF * 0.6, 0)

func _build_enemy() -> void:
	enemy = Sprite3D.new()
	var tex := GameState.skin_texture()
	enemy.texture = tex
	enemy.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	enemy.shaded = false
	enemy.pixel_size = 250.0 / float(tex.get_height())
	enemy.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	enemy.position = Vector3(0, 125, 0)
	enemy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	enemy.visible = false
	add_child(enemy)

func _build_audio() -> void:
	onion_sound = AudioStreamPlayer.new()
	onion_sound.stream = load("res://assets/sounds/sfx_onion.ogg")
	add_child(onion_sound)

	player.set_footstep_streams(load("res://assets/sounds/sfx_footstep1.ogg"))

func _objective_text() -> void:
	if endless:
		hud.show_objective("ENDLESS SWAMP - grab all the onions you want")
	else:
		hud.show_objective("Collect 8 onions before the 90 seconds run out")

func _pages_text() -> String:
	if endless:
		return "%d" % pages
	return "%d / %d" % [pages, TOTAL_PAGES]

func _vsize() -> Vector2:
	return get_viewport().get_visible_rect().size

func _process(delta: float) -> void:
	if static_playing:
		_static_tick(delta)
		return
	if game_over or paused:
		return
	onion_bob_t += delta
	for o in onions:
		if is_instance_valid(o):
			o.position.y = sin(onion_bob_t * 2.0 + o.position.x * 0.01) * 3.0
			o.rotation.y += delta * 0.9
	_update_threat(delta)
	_update_prompt()
	if not endless:
		_time_tick(delta)
	_lerp_phase(clampf(1.0 - exp(-PHASE_SMOOTHING * delta), 0.0, 1.0))

func _update_threat(delta: float) -> void:
	if not enemy_active or enemy == null or not enemy.visible:
		hud.hide_static()
		return
	var to := enemy.global_position - player.global_position
	to.y = 0.0
	var dist := to.length()
	var t := clampf(1.0 - dist / THREAT_RANGE, 0.0, 1.0)
	threat = lerpf(threat, t, clampf(delta * 5.0, 0.0, 1.0))
	if threat <= 0.015:
		hud.hide_static()
		return
	static_time += delta
	var threat_frames: Array[Texture2D] = [static_frames[0], static_frames[2], static_frames[3], static_frames[4]]
	hud.show_static(threat_frames[int(static_time / 0.07) % threat_frames.size()], pow(threat, 1.6) * 0.5)

func _update_prompt() -> void:
	var hit := _ray_onion()
	if hit == null:
		hud.set_prompt("")
		return
	if not endless and pages >= TOTAL_PAGES:
		hud.set_prompt("")
		return
	hud.set_prompt("[E]  Grab onion")

func _ray_onion() -> Area3D:
	var center := _vsize() * 0.5
	if player == null or player.camera == null:
		return null
	var from := player.camera.project_ray_origin(center)
	var to := from + player.camera.project_ray_normal(center) * ONION_RANGE
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = 2
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return null
	var col: Object = hit["collider"]
	if col is Area3D and (col as Area3D).has_meta("onion"):
		return col
	return null

func _time_tick(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		hud.set_time(int(ceil(time_left)), true)
		_die(false)
		return
	hud.set_time(int(ceil(time_left)), time_left < 20.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_over and not static_playing:
			_to_menu()
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if not paused and not game_over:
			var on: Area3D = _ray_onion()
			if on != null:
				_collect(on)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_7:
			if allstar == null:
				allstar = AudioStreamPlayer.new()
				allstar.stream = load("res://assets/sounds/music_allstar.ogg")
				add_child(allstar)
			allstar.stop()
			allstar.play()

func _try_collect_center() -> void:
	if game_over or paused:
		return
	var on: Area3D = _ray_onion()
	if on != null:
		_collect(on)

func _collect(onion: Area3D) -> void:
	if game_over:
		return
	onion_sound.play()
	pages += 1
	GameState.total_pages += 1
	GameState.save_stats()
	hud.set_pages_text(_pages_text())
	onions.erase(onion)
	onion.queue_free()
	if endless:
		onions.append(_spawn_onion())
		_apply_phase(mini(pages, 8))
		_start_music_phase(mini((pages + 1) / 2, 4))
		return
	var pp := mini((pages + 1) / 2, 4)
	_apply_phase(pages)
	_start_music_phase(pp)
	if pages >= TOTAL_PAGES:
		_win()

func _apply_phase(ph: int) -> void:
	phase = ph
	_phase_target = PHASES[ph]
	if not _phase_started:
		_phase_started = true
		_lerp_phase(1.0)
	for o in onions:
		if is_instance_valid(o):
			(o.get_child(0) as Sprite3D).shaded = ph < 4

func _lerp_phase(weight: float) -> void:
	var t: Dictionary = _phase_target
	env.fog_light_color = env.fog_light_color.lerp(t["horizon"] * 0.55 + t["top"] * 0.45, weight)
	env.fog_density = lerpf(env.fog_density, t["fog"], weight)
	env.fog_sky_affect = lerpf(env.fog_sky_affect, t["sky_affect"], weight)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, t["ambient_energy"], weight)
	_day_mix = lerpf(_day_mix, t["day"], weight)
	sky_mat.set_shader_parameter("day_mix", _day_mix)
	sun.light_energy = lerpf(sun.light_energy, t["sun"], weight)
	sun.light_color = sun.light_color.lerp(t["sun_color"], weight)
	ground_mat.albedo_color = ground_mat.albedo_color.lerp(t["grass"], weight)

func _start_music_phase(ph: int) -> void:
	if allstar != null and allstar.playing:
		return
	var tracks := [
		"",
		"res://assets/sounds/music_pages_1_2.ogg",
		"res://assets/sounds/music_pages_3_4.ogg",
		"res://assets/sounds/music_pages_5_6.ogg",
		"res://assets/sounds/music_pages_7_8.ogg",
	]
	var path: String = tracks[ph]
	if path == "":
		if music != null and music.playing:
			music.stop()
		return
	if music == null:
		music = AudioStreamPlayer.new()
		music.finished.connect(func() -> void: music.play())
		add_child(music)
	var stream: AudioStream = load(path)
	if music.stream == stream and music.playing:
		return
	music.stream = stream
	music.play()

func _physics_process(delta: float) -> void:
	if game_over or paused:
		return
	if endless:
		return
	_tick_enemy(delta)

func _tick_enemy(delta: float) -> void:
	if not enemy_active and pages >= 1:
		enemy_active = true
		_spawn_enemy_behind()
	if not enemy_active:
		return
	enemy_bob_t += delta
	var to_p := player.global_position - enemy.global_position
	to_p.y = 0.0
	var dist := to_p.length()
	if dist < KILL_RADIUS:
		_die()
		return
	var dir := to_p / maxf(dist, 0.001)
	var speed: float = ENEMY_FOLLOW_BASE + ENEMY_FOLLOW_PER_PAGE * pages
	speed = minf(speed, ENEMY_SPEED_CAP)
	if _player_observing():
		speed *= OBSERVED_FACTOR
	enemy.global_position += Vector3(dir.x, 0.0, dir.z) * speed * delta
	enemy.position.y = 125.0 + sin(enemy_bob_t * 2.2) * 6.0

func _player_observing() -> bool:
	var fwd := -player.camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var to := enemy.global_position - player.global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= 0.001 or dist > OBSERVE_RANGE:
		return false
	return fwd.dot(to / dist) > OBSERVE_DOT

func _spawn_enemy_behind() -> void:
	var fwd := -player.camera.global_basis.z
	var behind := Vector2(-fwd.x, -fwd.z).normalized().rotated(randf_range(-1.0, 1.0))
	var d := randf_range(480.0, 640.0)
	var p := Vector2(player.global_position.x, player.global_position.z) + behind * d
	p.x = clampf(p.x, -WORLD_HALF + 140, WORLD_HALF - 140)
	p.y = clampf(p.y, -WORLD_HALF + 140, WORLD_HALF - 140)
	enemy.global_position = Vector3(p.x, 125.0, p.y)
	enemy.visible = true

func _win() -> void:
	won = true
	game_over = true
	GameState.total_escapes += 1
	GameState.save_stats()
	_end_sequence("res://assets/images/results/win2.png", false)

func _die(caught: bool = true) -> void:
	if game_over:
		return
	game_over = true
	_end_sequence("res://assets/images/results/fail2.png", caught)

func _end_sequence(result_path: String, with_static: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_crosshair(false)
	hud.set_prompt("")
	hud.hide_static()
	if music != null:
		music.stop()
	set_meta("result_path", result_path)
	if with_static:
		static_playing = true
		static_time = 0.0
		if static_sound == null:
			static_sound = AudioStreamPlayer.new()
			static_sound.stream = load("res://assets/sounds/sfx_static.ogg")
			add_child(static_sound)
		static_sound.play()
		hud.show_static(static_frames[1], 1.0)
		hud.result_label.visible = false
	else:
		hud.show_result(load(result_path), true)

func _static_tick(delta: float) -> void:
	static_time += delta
	var slot := int(static_time / 1.0)
	if slot == 0:
		hud.show_static(static_frames[1], 1.0)
	elif slot == 1:
		hud.show_static(static_frames[2], 1.0)
	else:
		static_playing = false
		if static_sound != null and static_sound.playing:
			static_sound.stop()
		hud.show_result(load(get_meta("result_path")), true)

func _toggle_pause() -> void:
	if game_over:
		return
	paused = not paused
	get_tree().paused = paused
	_pause_audio(paused)
	pause_menu.set_open(paused)
	hud.set_crosshair(not paused)
	hud.set_prompt("")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func _touch_look(delta: Vector2) -> void:
	if player:
		player.touch_look(delta)

func _pause_audio(on: bool) -> void:
	for node in find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stream_paused = on
	for node in find_children("*", "AudioStreamPlayer3D", true, false):
		(node as AudioStreamPlayer3D).stream_paused = on

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _to_menu() -> void:
	get_tree().paused = false
	GameState.save_stats()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
