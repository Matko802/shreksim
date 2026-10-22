extends Node3D

const WORLD_HALF := 128.0
const ONION_RADII := [22.4, 25.6, 28.0, 42.4, 46.0, 62.4, 65.2, 78.0, 84.0, 98.0, 104.0, 116.0]
const TERRAIN_DATA := preload("res://assets/maps/terrain_data.tres")
const NAV := preload("res://scripts/enemy_nav.gd")
const TOTAL_PAGES := 8
const START_TIME := 150.0
const KILL_RADIUS := 2.8
const ENEMY_CHASE_RADIUS := 200.0
const ENEMY_REAPPEAR_MIN := 8.0
const ENEMY_REAPPEAR_MAX := 14.0
const ENEMY_STALK_DIST_MIN := 17.0
const ENEMY_STALK_DIST_MAX := 25.0
const CAMERA_HEIGHT := 1.76
const ONION_RANGE := 14.4
const STATIC_MAX_ALPHA := 0.25

const THREAT_RANGE := 38.0
const ENEMY_FOLLOW_BASE := 2.4
const ENEMY_FOLLOW_PER_PAGE := 0.48
const ENEMY_SPEED_CAP := 6.4
const ENEMY_FOV_HALF := 0.85
const ENEMY_VISION_DIST := 30.0
const ENEMY_HEAR_RUN := 16.0
const ENEMY_MEMORY := 2.5
const ENEMY_SEARCH_TIME := 6.0
const ENEMY_PATH_INTERVAL := 0.6
const ENEMY_WHISKER_DIST := 3.2
const WALL_SAFE := 6.0
const TREE_EDGE_DOT := 0.18

const PHASES := [
	{"top": Color(0.3, 0.52, 0.85), "horizon": Color(0.8, 0.88, 0.86), "fog": 0.004, "sun": 1.35, "sun_color": Color(1.0, 0.97, 0.9), "ambient_energy": 1.0, "grass": Color(0.5, 0.68, 0.4), "sky_affect": 0.12, "day": 1.0},
	{"top": Color(0.42, 0.64, 0.95), "horizon": Color(0.88, 0.94, 0.94), "fog": 0.003, "sun": 1.6, "sun_color": Color(1.0, 1.0, 0.98), "ambient_energy": 1.15, "grass": Color(0.55, 0.74, 0.44), "sky_affect": 0.1, "day": 1.0},
	{"top": Color(0.36, 0.55, 0.8), "horizon": Color(0.85, 0.82, 0.7), "fog": 0.005, "sun": 1.3, "sun_color": Color(1.0, 0.93, 0.82), "ambient_energy": 1.0, "grass": Color(0.5, 0.66, 0.4), "sky_affect": 0.16, "day": 0.85},
	{"top": Color(0.3, 0.4, 0.62), "horizon": Color(0.9, 0.7, 0.48), "fog": 0.00625, "sun": 1.05, "sun_color": Color(1.0, 0.78, 0.55), "ambient_energy": 0.85, "grass": Color(0.46, 0.58, 0.34), "sky_affect": 0.2, "day": 0.6},
	{"top": Color(0.22, 0.24, 0.42), "horizon": Color(0.75, 0.5, 0.35), "fog": 0.015, "sun": 0.7, "sun_color": Color(1.0, 0.55, 0.35), "ambient_energy": 0.62, "grass": Color(0.38, 0.44, 0.26), "sky_affect": 0.24, "day": 0.4},
	{"top": Color(0.1, 0.11, 0.26), "horizon": Color(0.35, 0.26, 0.3), "fog": 0.03, "sun": 0.4, "sun_color": Color(0.7, 0.4, 0.45), "ambient_energy": 0.45, "grass": Color(0.26, 0.3, 0.2), "sky_affect": 0.28, "day": 0.2},
	{"top": Color(0.045, 0.055, 0.15), "horizon": Color(0.12, 0.1, 0.14), "fog": 0.055, "sun": 0.22, "sun_color": Color(0.4, 0.32, 0.55), "ambient_energy": 0.32, "grass": Color(0.16, 0.2, 0.13), "sky_affect": 0.32, "day": 0.05},
	{"top": Color(0.012, 0.02, 0.05), "horizon": Color(0.035, 0.045, 0.06), "fog": 0.0875, "sun": 0.1, "sun_color": Color(0.3, 0.35, 0.55), "ambient_energy": 0.22, "grass": Color(0.11, 0.15, 0.1), "sky_affect": 0.36, "day": 0.0},
	{"top": Color(0.004, 0.008, 0.02), "horizon": Color(0.012, 0.015, 0.02), "fog": 0.125, "sun": 0.03, "sun_color": Color(0.2, 0.25, 0.4), "ambient_energy": 0.14, "grass": Color(0.08, 0.12, 0.08), "sky_affect": 0.4, "day": 0.0},
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
const PROMPT_INTERVAL := 0.1

var endless := false
var game_over := false
var phase := 0
var _phase_target: Dictionary = {}
var _phase_started := false
var _phase_converged := false
var won := false
var paused := false
var pages := 0
var time_left := START_TIME

var player: SwampPlayer
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var _day_mix := 1.0
var ground_mat: ShaderMaterial
var tree_planes: Array = []
var tree_sight_time := 0.0
var onion_spot := -1

var enemy: Sprite3D
var enemy_active := false
var enemy_bob_t := 0.0
var threat := 0.0
var nav: EnemyNav
var enemy_mode := "wander"
var enemy_path := PackedVector2Array()
var enemy_path_i := 0
var enemy_path_time := 0.0
var enemy_arrived := false
var enemy_goal_ok := false
var enemy_goal := Vector2.ZERO
var enemy_pause := 0.0
var enemy_reappear_time := 0.0
var enemy_chase_audio: AudioStreamPlayer3D
var music_phase := 0
var enemy_yaw := 0.0
var enemy_lose_time := 0.0
var enemy_search_time := 0.0
var last_seen := Vector2.ZERO
var sees_cache := false
var sees_timer := 0.0
var _grab_shown := false
var _prompt_timer := 0.0

var onions: Array[Area3D] = []
var onion_bob_t := 0.0

var hud: CanvasLayer
var pause_menu: CanvasLayer
var _touch: Node
var static_frames: Array[Texture2D] = []
var threat_frames: Array[Texture2D] = []
var static_time := 0.0
var static_playing := false

var music: AudioStreamPlayer
var music_streams: Array[AudioStream] = []
var static_sound: AudioStreamPlayer
var onion_sound: AudioStreamPlayer
var allstar: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	endless = GameState.game_type == "endless"
	set_meta("best_start", GameState.best_endless)
	_build_world()
	_build_player()
	_build_onions()
	_build_enemy()
	_build_ui()
	_build_audio()
	_apply_phase(0)
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
	var touch := (load("res://scenes/touch_ui.tscn") as PackedScene).instantiate()
	add_child(touch)
	_touch = touch
	pause_menu.resume_requested.connect(_toggle_pause)
	pause_menu.restart_requested.connect(_restart)
	pause_menu.menu_requested.connect(_to_menu)
	for i in 5:
		static_frames.append(load("res://assets/images/static/static%d.png" % i))
	threat_frames.assign([static_frames[0], static_frames[2], static_frames[3], static_frames[4]])

func _build_player() -> void:
	player = SwampPlayer.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector3(0, CAMERA_HEIGHT, 0)
	add_child(player)

func _terrain_height(x: float, z: float) -> float:
	var n: int = TERRAIN_DATA.grid_size
	var half: float = TERRAIN_DATA.grid_half
	var fx := clampf((x + half) / (half * 2.0), 0.0, 1.0) * float(n - 1)
	var fz := clampf((z + half) / (half * 2.0), 0.0, 1.0) * float(n - 1)
	var ix := clampi(int(fx), 0, n - 2)
	var iz := clampi(int(fz), 0, n - 2)
	var diff_x := fx - float(ix)
	var diff_z := fz - float(iz)
	var hs: PackedFloat32Array = TERRAIN_DATA.heights
	var h00 := hs[iz * n + ix]
	var h10 := hs[iz * n + ix + 1]
	var h01 := hs[(iz + 1) * n + ix]
	var h11 := hs[(iz + 1) * n + ix + 1]
	return lerp(lerp(h00, h10, diff_x), lerp(h01, h11, diff_x), diff_z)

func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	ground_mat = (get_node("Map/Terrain") as MeshInstance3D).material_override
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
	sun.rotation_degrees = Vector3(-36, 32, 0)
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	var trees := get_node("Map/Trees")
	for c in trees.get_children():
		var a := c.get_node_or_null("CrossA") as Sprite3D
		var b := c.get_node_or_null("CrossB") as Sprite3D
		var flat := c.get_node_or_null("Flat") as Sprite3D
		if a != null and b != null and flat != null:
			tree_planes.append([a, b, flat])

func _update_tree_sight() -> void:
	var px := player.global_position.x
	var pz := player.global_position.z
	for pair in tree_planes:
		var a := pair[0] as Sprite3D
		var b := pair[1] as Sprite3D
		var tpos: Vector3 = a.global_position
		var vx := tpos.x - px
		var vz := tpos.z - pz
		var vlen := sqrt(vx * vx + vz * vz)
		if vlen < 0.001:
			continue
		vx /= vlen
		vz /= vlen
		var na := a.global_basis.z
		var dota := absf(na.x * vx + na.z * vz)
		var nb := b.global_basis.z
		var dotb := absf(nb.x * vx + nb.z * vz)
		var a_on := dota >= TREE_EDGE_DOT
		var b_on := dotb >= TREE_EDGE_DOT
		if not a_on and not b_on:
			a_on = dota >= dotb
			b_on = not a_on
		a.visible = a_on
		b.visible = b_on

func _authored_spot(j: int) -> Vector2:
	var ang := 2.399963229728653 * float(j)
	return Vector2(cos(ang), sin(ang)) * ONION_RADII[j % ONION_RADII.size()]

func _next_onion_spot() -> Vector2:
	onion_spot += 1
	return _authored_spot(onion_spot)

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
	sprite.pixel_size = 0.0124
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = Vector3(0, 2.56, 0)
	area.add_child(sprite)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.36
	shape.shape = sphere
	shape.position = Vector3(0, 2.56, 0)
	area.add_child(shape)

	var pos := _next_onion_spot()
	var gh := _terrain_height(pos.x, pos.y)
	area.position = Vector3(pos.x, gh, pos.y)
	area.set_meta("onion", true)
	area.set_meta("base_y", gh)
	add_child(area)
	return area

func _build_enemy() -> void:
	enemy = Sprite3D.new()
	var tex := GameState.skin_texture()
	enemy.texture = tex
	enemy.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	enemy.shaded = false
	enemy.pixel_size = 10.0 / float(tex.get_height())
	enemy.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	enemy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	enemy.position = Vector3(0, 5, 0)
	enemy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	enemy.visible = false
	add_child(enemy)
	enemy_chase_audio = AudioStreamPlayer3D.new()
	enemy_chase_audio.max_distance = ENEMY_CHASE_RADIUS
	enemy_chase_audio.unit_size = 16.0
	enemy_chase_audio.bus = &"Master"
	enemy.add_child(enemy_chase_audio)

func _build_audio() -> void:
	onion_sound = AudioStreamPlayer.new()
	onion_sound.stream = load("res://assets/sounds/sfx_onion.ogg")
	add_child(onion_sound)

	for path in ["", "res://assets/sounds/music_pages_1_2.ogg", "res://assets/sounds/music_pages_3_4.ogg", "res://assets/sounds/music_pages_5_6.ogg", "res://assets/sounds/music_pages_7_8.ogg"]:
		music_streams.append(load(path) if path != "" else null)
	for s in music_streams:
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true

func _objective_text() -> void:
	if endless:
		hud.show_objective(tr("ENDLESS SWAMP - grab all the onions you want"))
	else:
		hud.show_objective(tr("Collect 8 onions before the 150 seconds run out"))

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
			o.position.y = float(o.get_meta("base_y")) + sin(onion_bob_t * 2.0 + o.position.x * 0.01) * 0.12
			o.rotation.y += delta * 0.9
	_update_threat(delta)
	tree_sight_time -= delta
	if tree_sight_time <= 0.0:
		tree_sight_time = 0.12
		_update_tree_sight()
	_prompt_timer -= delta
	if _prompt_timer <= 0.0:
		_prompt_timer = PROMPT_INTERVAL
		_update_prompt()
	if not endless:
		_time_tick(delta)
	_lerp_phase(clampf(1.0 - exp(-PHASE_SMOOTHING * delta), 0.0, 1.0))

func _update_threat(delta: float) -> void:
	if not enemy_active or enemy == null or not enemy.visible:
		hud.hide_static()
		threat = 0.0
		return
	var to := enemy.global_position - player.global_position
	to.y = 0.0
	var dist := to.length()
	var t := clampf(1.0 - dist / THREAT_RANGE, 0.0, 1.0)
	threat = lerpf(threat, t, clampf(delta * 5.0, 0.0, 1.0))
	var alpha := threat * STATIC_MAX_ALPHA
	if alpha <= 0.005:
		hud.hide_static()
		return
	static_time += delta
	hud.show_static(threat_frames[int(static_time / 0.07) % threat_frames.size()], alpha)

func _update_prompt() -> void:
	var grab_now := _ray_onion() != null and (endless or pages < TOTAL_PAGES)
	hud.set_prompt(tr("[E]  Grab onion") if grab_now else "")
	_set_touch_grab(grab_now)

func _set_touch_grab(v: bool) -> void:
	if _touch != null and not is_instance_valid(_touch):
		_touch = null
	if _grab_shown == v:
		return
	_grab_shown = v
	if _touch != null:
		_touch.set_grab_visible(v)

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
	if endless and pages > GameState.best_endless:
		GameState.best_endless = pages
	GameState.save_stats()
	hud.set_pages_text(_pages_text())
	onions.erase(onion)
	onion.queue_free()
	if endless:
		onions.append(_spawn_onion())
		_apply_phase(mini(pages, 8))
		return
	_apply_phase(pages)
	if pages >= TOTAL_PAGES:
		_win()

func _apply_phase(ph: int) -> void:
	phase = ph
	_phase_target = PHASES[ph]
	_phase_converged = false
	if not _phase_started:
		_phase_started = true
		_lerp_phase(1.0)
	var day_v := float(PHASES[ph]["day"])
	var lit := clampf(0.55 + 0.45 * day_v, 0.55, 1.0)
	var tint_v := Color(lit, lit, lit)
	for o in onions:
		if is_instance_valid(o):
			(o.get_child(0) as Sprite3D).modulate = tint_v
	for tr in tree_planes:
		(tr[0] as Sprite3D).modulate = tint_v
		(tr[1] as Sprite3D).modulate = tint_v
		(tr[2] as Sprite3D).modulate = tint_v

func _color_close(a: Color, b: Color, eps: float) -> bool:
	return absf(a.r - b.r) < eps and absf(a.g - b.g) < eps and absf(a.b - b.b) < eps and absf(a.a - b.a) < eps

func _lerp_phase(weight: float) -> void:
	if _phase_converged:
		return
	var t: Dictionary = _phase_target
	var top_c: Color = t["top"]
	var horizon_c: Color = t["horizon"]
	var fog_color_t: Color = horizon_c * 0.55 + top_c * 0.45
	var fog_t := float(t["fog"])
	var affect_t := float(t["sky_affect"])
	var amb_t := float(t["ambient_energy"])
	var day_t := float(t["day"])
	var sun_t := float(t["sun"])
	var sun_c: Color = t["sun_color"]
	var grass_c: Color = t["grass"]
	env.fog_light_color = env.fog_light_color.lerp(fog_color_t, weight)
	env.fog_density = lerpf(env.fog_density, fog_t, weight)
	env.fog_sky_affect = lerpf(env.fog_sky_affect, affect_t, weight)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, amb_t, weight)
	_day_mix = lerpf(_day_mix, day_t, weight)
	sky_mat.set_shader_parameter("day_mix", _day_mix)
	sun.light_energy = lerpf(sun.light_energy, sun_t, weight)
	sun.light_color = sun.light_color.lerp(sun_c, weight)
	set_ground_tint(_tint().lerp(grass_c, weight))
	var settled := true
	settled = settled and _color_close(env.fog_light_color, fog_color_t, 0.004)
	settled = settled and absf(env.fog_density - fog_t) < 0.000002
	settled = settled and absf(env.fog_sky_affect - affect_t) < 0.0004
	settled = settled and absf(env.ambient_light_energy - amb_t) < 0.001
	settled = settled and absf(_day_mix - day_t) < 0.002
	settled = settled and absf(sun.light_energy - sun_t) < 0.001
	settled = settled and _color_close(sun.light_color, sun_c, 0.004)
	settled = settled and _color_close(_tint(), grass_c, 0.004)
	if settled:
		env.fog_light_color = fog_color_t
		env.fog_density = fog_t
		env.fog_sky_affect = affect_t
		env.ambient_light_energy = amb_t
		_day_mix = day_t
		sky_mat.set_shader_parameter("day_mix", _day_mix)
		sun.light_energy = sun_t
		sun.light_color = sun_c
		set_ground_tint(grass_c)
		_phase_converged = true

func _tint() -> Color:
	return ground_mat.get_shader_parameter("tint") as Color

func set_ground_tint(c: Color) -> void:
	ground_mat.set_shader_parameter("tint", c)

func _start_music_phase(ph: int) -> void:
	music_phase = ph
	if allstar != null and allstar.playing:
		return
	var stream: AudioStream = music_streams[ph] if ph >= 0 and ph < music_streams.size() else null
	if stream == null:
		if music != null and music.playing:
			music.stop()
		return
	if music == null:
		music = AudioStreamPlayer.new()
		music.finished.connect(func() -> void: music.play())
		add_child(music)
	if music.stream == stream and music.playing:
		return
	music.stream = stream
	music.play()

func _physics_process(delta: float) -> void:
	if game_over or paused:
		return
	_tick_enemy(delta)

func _tick_enemy(delta: float) -> void:
	if not enemy_active and pages >= 1:
		enemy_active = true
		_spawn_enemy_behind()
		if nav == null:
			_build_nav()
	if not enemy_active:
		return
	enemy_bob_t += delta
	sees_timer -= delta
	if sees_timer <= 0.0:
		sees_timer = 0.1
		sees_cache = _enemy_sees_player()
	if sees_cache:
		enemy_lose_time = 0.0
		last_seen = Vector2(player.global_position.x, player.global_position.z)
		enemy_mode = "hunt"
		enemy_arrived = false
	else:
		enemy_lose_time += delta
		if enemy_mode == "hunt" and enemy_lose_time > ENEMY_MEMORY:
			enemy_mode = "search"
			enemy_search_time = 0.0
			enemy_pause = 0.0
			enemy_path = PackedVector2Array()
			enemy_path_i = 0
	var to_p := player.global_position - enemy.global_position
	to_p.y = 0.0
	if enemy_mode == "hunt" and to_p.length() < KILL_RADIUS:
		_die()
		return
	var base := minf(ENEMY_FOLLOW_BASE + ENEMY_FOLLOW_PER_PAGE * pages, ENEMY_SPEED_CAP)
	if enemy_mode == "hunt":
		_enemy_advance(delta, last_seen, base)
	elif enemy_mode == "search":
		enemy_search_time += delta
		if enemy_search_time > ENEMY_SEARCH_TIME:
			_set_enemy_mode("wander")
		else:
			var pos2 := Vector2(enemy.global_position.x, enemy.global_position.z)
			if pos2.distance_to(last_seen) < 2.5:
				enemy_pause += delta
				enemy_yaw += delta * 0.5
				if enemy_pause >= 2.0:
					_set_enemy_mode("wander")
			else:
				_enemy_advance(delta, last_seen, base * 0.8)
	else:
		enemy_reappear_time -= delta
		if enemy_reappear_time <= 0.0:
			_stalk_reappear()
			return
		var pos := Vector2(enemy.global_position.x, enemy.global_position.z)
		if enemy_pause > 0.0:
			enemy_pause -= delta
			enemy_yaw += delta * 0.5
		else:
			if not enemy_goal_ok:
				enemy_goal = _pick_wander_target()
				enemy_goal_ok = true
				enemy_arrived = false
				enemy_path = PackedVector2Array()
				enemy_path_time = 0.0
			_enemy_advance(delta, enemy_goal, base * 0.5)
			if enemy_arrived:
				enemy_goal_ok = false
				enemy_pause = randf_range(1.2, 2.6)
	var chasing := enemy_mode == "hunt"
	if enemy_chase_audio != null:
		if chasing:
			var track: AudioStream = music_streams[mini((pages + 1) / 2, 4)]
			if track != null and enemy_chase_audio.stream != track:
				enemy_chase_audio.stream = track
				enemy_chase_audio.play()
			elif track != null and not enemy_chase_audio.playing:
				enemy_chase_audio.play()
		elif enemy_chase_audio.playing:
			enemy_chase_audio.stop()
	enemy.visible = chasing
	enemy.global_position.y = _terrain_height(enemy.global_position.x, enemy.global_position.z) + 5.0 + sin(enemy_bob_t * 2.2) * 0.24

func _enemy_sees_player() -> bool:
	var to_p := player.global_position - enemy.global_position
	to_p.y = 0.0
	var dist := to_p.length()
	if dist < 0.001:
		return true
	var fwd := Vector2(cos(enemy_yaw), sin(enemy_yaw))
	var pdir := Vector2(to_p.x, to_p.z) / dist
	if dist <= ENEMY_VISION_DIST and (dist <= 3.0 or absf(fwd.angle_to(pdir)) <= ENEMY_FOV_HALF):
		var p2 := Vector2(player.global_position.x, player.global_position.z)
		if nav != null and nav.has_los(Vector2(enemy.global_position.x, enemy.global_position.z), p2):
			return true
	return player.is_sprinting() and dist <= ENEMY_HEAR_RUN

func _enemy_advance(delta: float, target: Vector2, speed: float) -> void:
	enemy_path_time -= delta
	if enemy_path_time <= 0.0 or enemy_path.is_empty():
		enemy_path_time = ENEMY_PATH_INTERVAL
		enemy_path = nav.find_path(Vector2(enemy.global_position.x, enemy.global_position.z), target)
		enemy_path_i = 0
		enemy_arrived = enemy_path.is_empty()
	var pos := Vector2(enemy.global_position.x, enemy.global_position.z)
	var steer := target
	if enemy_path_i < enemy_path.size():
		steer = enemy_path[enemy_path_i]
		while steer.distance_to(pos) < 1.6:
			enemy_path_i += 1
			if enemy_path_i >= enemy_path.size():
				enemy_arrived = true
				break
			steer = enemy_path[enemy_path_i]
	if enemy_arrived and enemy_mode != "hunt":
		return
	var dir := steer - pos
	var d := dir.length()
	if d > 0.001:
		dir = dir / d
		dir = _whisker_dir(dir)
		var next_pos := enemy.global_position
		next_pos.x += dir.x * speed * delta
		next_pos.z += dir.y * speed * delta
		enemy.global_position = next_pos
		enemy_yaw = lerp_angle(enemy_yaw, dir.angle(), clampf(6.0 * delta, 0.0, 1.0))

func _whisker_dir(dir: Vector2) -> Vector2:
	var space := get_world_3d().direct_space_state
	var y := _terrain_height(enemy.global_position.x, enemy.global_position.z) + 4.5
	var origin := Vector3(enemy.global_position.x, y, enemy.global_position.z)
	var to := origin + Vector3(dir.x, 0.0, dir.y) * ENEMY_WHISKER_DIST
	var mid := PhysicsRayQueryParameters3D.create(origin, to, 1)
	if space.intersect_ray(mid).is_empty():
		return dir
	var best := dir
	var best_free := false
	for a in [-1.0, 1.0]:
		var alt := dir.rotated(1.05 * a)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + Vector3(alt.x, 0.0, alt.y) * ENEMY_WHISKER_DIST * 1.4, 1)
		var h := space.intersect_ray(q)
		if h.is_empty():
			return alt
	return best

func _pick_wander_target() -> Vector2:
	var target := Vector2.ZERO
	var attempts := 0
	while attempts < 24:
		attempts += 1
		var pc := Vector2(player.global_position.x, player.global_position.z)
		if randf() < 0.4:
			var ang := randf() * TAU
			target = pc + Vector2(cos(ang), sin(ang)) * randf_range(26.0, 52.0)
		else:
			target = Vector2(randf_range(-WORLD_HALF + 10.0, WORLD_HALF - 10.0), randf_range(-WORLD_HALF + 10.0, WORLD_HALF - 10.0))
		target.x = clampf(target.x, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
		target.y = clampf(target.y, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
		if nav.is_free_point(target):
			return target
	return target

func _set_enemy_mode(m: String) -> void:
	enemy_mode = m
	if m == "wander":
		enemy_reappear_time = randf_range(ENEMY_REAPPEAR_MIN, ENEMY_REAPPEAR_MAX)
		enemy_goal_ok = false
		enemy_path = PackedVector2Array()
		enemy_path_i = 0
		enemy_path_time = 0.0

func _stalk_reappear() -> void:
	var fwd := -player.camera.global_basis.z
	var pc := Vector2(player.global_position.x, player.global_position.z)
	var dir := Vector2(-fwd.x, -fwd.z).normalized().rotated(randf_range(-1.2, 1.2))
	var p := pc + dir * randf_range(ENEMY_STALK_DIST_MIN, ENEMY_STALK_DIST_MAX)
	p.x = clampf(p.x, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
	p.y = clampf(p.y, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
	var tries := 8
	while tries > 0 and nav != null and not nav.is_free_point(p):
		tries -= 1
		dir = Vector2(-fwd.x, -fwd.z).normalized().rotated(randf_range(-1.2, 1.2))
		p = pc + dir * randf_range(ENEMY_STALK_DIST_MIN, ENEMY_STALK_DIST_MAX)
		p.x = clampf(p.x, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
		p.y = clampf(p.y, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
	enemy.global_position = Vector3(p.x, _terrain_height(p.x, p.y) + 5.0, p.y)
	enemy_yaw = (pc - p).angle()
	enemy_arrived = false
	enemy_lose_time = 0.0
	enemy_pause = 0.0
	sees_timer = 0.0
	sees_cache = false
	last_seen = pc
	enemy_mode = "hunt"

func _build_nav() -> void:
	nav = NAV.new()
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	var rs := PackedFloat32Array()
	for t in get_node("Map/Trees").get_children():
		if not (t is StaticBody3D):
			continue
		var col := t.get_node("Collision") as CollisionShape3D
		var cyl := col.shape as CylinderShape3D
		var gp: Vector3 = t.global_position
		xs.append(gp.x)
		zs.append(gp.z)
		rs.append(cyl.radius)
	nav.build(xs, zs, rs)

func _spawn_enemy_behind() -> void:
	var fwd := -player.camera.global_basis.z
	var behind := Vector2(-fwd.x, -fwd.z).normalized().rotated(randf_range(-1.0, 1.0))
	var d := randf_range(19.2, 25.6)
	var p := Vector2(player.global_position.x, player.global_position.z) + behind * d
	p.x = clampf(p.x, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
	p.y = clampf(p.y, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
	enemy.global_position = Vector3(p.x, _terrain_height(p.x, p.y) + 5.0, p.y)
	enemy.visible = false
	enemy_yaw = Vector2(player.global_position.x - p.x, player.global_position.z - p.y).angle()
	_set_enemy_mode("wander")
	enemy_arrived = false
	enemy_lose_time = 0.0
	enemy_pause = 0.0
	last_seen = Vector2(player.global_position.x, player.global_position.z)
	sees_cache = false
	sees_timer = 0.0

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
	_set_touch_grab(false)
	hud.hide_static()
	if music != null:
		music.stop()
	if enemy_chase_audio != null:
		enemy_chase_audio.stop()
	var result_text := _result_text()
	if endless:
		GameState.best_endless = maxi(GameState.best_endless, pages)
		GameState.save_stats()
	set_meta("result_path", result_path)
	set_meta("result_text", result_text)
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
		hud.show_result(load(result_path), true, result_text)

func _result_text() -> String:
	if not endless:
		return ""
	if pages > int(get_meta("best_start", GameState.best_endless)):
		return tr("You grabbed %d onions - NEW HIGH SCORE!") % pages
	return tr("You grabbed %d onions - high score %d") % [pages, GameState.best_endless]

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
		hud.show_result(load(get_meta("result_path")), true, get_meta("result_text"))

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
