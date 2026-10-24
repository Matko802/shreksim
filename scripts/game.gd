extends Node3D

const WORLD_HALF := 128.0
const FLOATING_ORIGIN_CELL := 32.0
const NAV := preload("res://scripts/enemy_nav.gd")
const TOTAL_PAGES := 8
const START_TIME := 150.0
const KILL_RADIUS := 2.8
const ENEMY_CHASE_RADIUS := 200.0
const ENEMY_RESPAWN_DIST_MIN := 20.0
const ENEMY_RESPAWN_DIST_MAX := 25.0
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
const ENEMY_MEMORY := 5.0
const ENEMY_RETREAT_FADE := 3.0
const ENEMY_RETREAT_SPEED := 15.0
const ENEMY_RETREAT_DIST_MIN := 70.0
const ENEMY_RETREAT_DIST_MAX := 110.0
const ENEMY_PATH_INTERVAL := 0.6
const ENEMY_WHISKER_DIST := 3.2
const ENEMY_WHISKER_INTERVAL := 0.1
const WALL_SAFE := 6.0

const FAR_TREE_SHADER: Shader = preload("res://scripts/far_tree_billboard.gdshader")
const NEAR_TREE_SHADER: Shader = preload("res://scripts/near_tree_cross.gdshader")
const TERRAIN_SHADER: Shader = preload("res://scripts/mobile_terrain_lite.gdshader")
const FAR_TREE_CULL := 150.0
const TREE_NEAR := 32.0
const MOBILE_PHYSICS_TICKS := 30
const MOBILE_MAX_PHYSICS_STEPS := 4

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
var _terrain: Terrain3D
var _mobile := false
var render_origin := Vector3.ZERO
var terrain_render_target: Node3D
var onion_sprites: Dictionary = {}
var onion_visuals: Array[Area3D] = []
var far_tree_materials: Array[ShaderMaterial] = []
var near_tree_materials: Array[ShaderMaterial] = []
var snap_pending: Array = []
var far_instances: Dictionary = {}
var near_instances: Dictionary = {}
var far_bake_ticks := 0
var _snap_tick := 0.0
var _far_trees_baked := false
var _far_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
var _phase_fog := 0.0
var onion_spot := -1

var enemy: Sprite3D
var enemy_anchor: Node3D
var enemy_active := false
var enemy_bob_t := 0.0
var threat := 0.0
var nav: EnemyNav
var enemy_mode := "hidden"
var enemy_path := PackedVector2Array()
var enemy_path_i := 0
var enemy_path_time := 0.0
var enemy_arrived := false
var enemy_goal_ok := false
var enemy_goal := Vector2.ZERO
var enemy_chase_audio: AudioStreamPlayer3D
var music_phase := 0
var enemy_yaw := 0.0
var enemy_lose_time := 0.0
var enemy_retreat_time := 0.0
var enemy_retreat_goal_ok := false
var enemy_fade := 1.0
var enemy_whisker_timer := 0.0
var enemy_whisker_offset := 0.0
var enemy_whisker_last := Vector2.ZERO
var last_seen := Vector2.ZERO
var sees_cache := false
var sees_timer := 0.0
var _grab_shown := false
var _prompt_timer := 0.0

var onions: Array[Area3D] = []

var hud: CanvasLayer
var pause_menu: CanvasLayer
var _touch: Node
var loading_layer: CanvasLayer
var _loading_rect: ColorRect
var static_frames: Array[Texture2D] = []
var threat_frames: Array[Texture2D] = []
var static_time := 0.0
var static_playing := false
var _static_frame_idx := -1
var _static_alpha := -1.0

var music: AudioStreamPlayer
var music_streams: Array[AudioStream] = []
var static_sound: AudioStreamPlayer
var onion_sound: AudioStreamPlayer
var allstar: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mobile = SettingsBus._is_mobile()
	if _mobile:
		Engine.physics_ticks_per_second = MOBILE_PHYSICS_TICKS
		Engine.max_physics_steps_per_frame = MOBILE_MAX_PHYSICS_STEPS
	endless = GameState.game_type == "endless"
	set_meta("best_start", GameState.best_endless)
	_build_world()
	_build_player()
	_build_onion_visuals()
	_build_onions()
	_build_enemy()
	_set_render_origin(Vector3.ZERO)
	_build_ui()
	_build_audio()
	_apply_phase(0)
	hud.set_timer_visible(not endless)
	hud.set_pages_text(_pages_text())
	_objective_text()
	player.interact_pressed.connect(_try_collect_center)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _mobile:
		_run_load_sequence()

const WARMUP_PITCHES: Array[float] = [-1.45, -0.7, 0.0, 1.0]
const WARMUP_YAWS: Array[float] = [0.0, 2.0943951, 4.1887902]

func _run_load_sequence() -> void:
	var guard := 0
	while (not _far_trees_baked or not snap_pending.is_empty()) and guard < 600:
		guard += 1
		await RenderingServer.frame_post_draw
	await _warmup_shaders()
	var tw := create_tween()
	tw.tween_property(_loading_rect, "modulate:a", 0.0, 0.35)
	await tw.finished
	loading_layer.queue_free()
	loading_layer = null
	_loading_rect = null

func _warmup_shaders() -> void:
	var head := player.head
	var prev_rot := head.rotation
	var prev_pos := head.position
	var enemy_was := enemy.visible
	var fl_was := player.flashlight_light.visible
	player.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.visible = true
	player.flashlight_light.visible = true
	for yaw in WARMUP_YAWS:
		player.rotate_y(yaw)
		for pitch in WARMUP_PITCHES:
			head.rotation = Vector3(pitch, 0.0, 0.0)
			await RenderingServer.frame_post_draw
	head.rotation = prev_rot
	head.position = prev_pos
	enemy.visible = enemy_was
	player.flashlight_light.visible = fl_was
	player.process_mode = Node.PROCESS_MODE_PAUSABLE

func _build_ui() -> void:
	hud = (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	pause_menu = (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
	add_child(pause_menu)
	var touch := (load("res://scenes/touch_ui.tscn") as PackedScene).instantiate()
	add_child(touch)
	_touch = touch
	if _mobile:
		loading_layer = CanvasLayer.new()
		loading_layer.layer = 95
		add_child(loading_layer)
		_loading_rect = ColorRect.new()
		_loading_rect.color = Color(0.02, 0.05, 0.02, 1.0)
		_loading_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_loading_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		loading_layer.add_child(_loading_rect)
		var box := VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_CENTER)
		box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		box.grow_vertical = Control.GROW_DIRECTION_BOTH
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		_loading_rect.add_child(box)
		var title := Label.new()
		title.text = "SWAMP HORROR SIMULATOR 3D"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 34)
		title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
		box.add_child(title)
		var sub := Label.new()
		sub.text = "Loading..."
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 18)
		box.add_child(sub)
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
	terrain_render_target = Node3D.new()
	terrain_render_target.name = "TerrainRenderTarget"
	terrain_render_target.physics_interpolation_mode = Node3D.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(terrain_render_target)
	if _terrain != null:
		_terrain.clipmap_target = terrain_render_target
		_terrain.collision_target = player
		_terrain.light_target = sun
	_sync_terrain_target()

func _update_render_origin() -> void:
	if player == null:
		return
	var shift := Vector3.ZERO
	var delta := player.global_position - render_origin
	if absf(delta.x) >= FLOATING_ORIGIN_CELL:
		shift.x = signf(delta.x) * FLOATING_ORIGIN_CELL
	if absf(delta.z) >= FLOATING_ORIGIN_CELL:
		shift.z = signf(delta.z) * FLOATING_ORIGIN_CELL
	if shift != Vector3.ZERO:
		_set_render_origin(render_origin + shift)

func _sync_terrain_target() -> void:
	if terrain_render_target == null or player == null:
		return
	terrain_render_target.global_position = Vector3(
		player.global_position.x - render_origin.x,
		0.0,
		player.global_position.z - render_origin.z)

func _set_render_origin(origin: Vector3) -> void:
	render_origin = Vector3(origin.x, 0.0, origin.z)
	var offset := -render_origin
	if player != null:
		player.set_render_offset(offset)
	_sync_terrain_target()
	if enemy != null:
		enemy.position = Vector3(offset.x, 0.0, offset.z)
		enemy.reset_physics_interpolation()
	if _terrain != null:
		var terrain_mat := _terrain.material as Terrain3DMaterial
		if terrain_mat != null:
			terrain_mat.set_shader_param(&"render_origin", render_origin)
	_apply_tree_render_origin()
	for area in onion_visuals:
		if is_instance_valid(area):
			_place_onion_sprite(area)

func _apply_tree_render_origin() -> void:
	for mat in far_tree_materials:
		if mat != null:
			mat.set_shader_parameter("render_origin", render_origin)
	for mat in near_tree_materials:
		if mat != null:
			mat.set_shader_parameter("render_origin", render_origin)

func _build_onion_visuals() -> void:
	for c in get_node("Map/OnionSpots").get_children():
		if c is Area3D:
			var area := c as Area3D
			var sprite := area.get_node_or_null("Sprite") as Sprite3D
			if sprite == null:
				continue
			var base := sprite.position
			sprite.top_level = true
			onion_sprites[area] = [sprite, base]
			onion_visuals.append(area)
			_place_onion_sprite(area)

func _place_onion_sprite(area: Area3D) -> void:
	if not is_instance_valid(area) or not onion_sprites.has(area):
		return
	var entry: Array = onion_sprites[area]
	var sprite := entry[0] as Sprite3D
	var base := entry[1] as Vector3
	if sprite != null:
		sprite.global_position = area.global_transform * base - render_origin

func _terrain_height(x: float, z: float) -> float:
	if _terrain == null or _terrain.data == null:
		return 0.0
	var p := Vector3(clampf(x, -255.0, 255.0), 0.0, clampf(z, -255.0, 255.0))
	var h := _terrain.data.get_height(p)
	if is_nan(h):
		return 0.0
	return h

static var _sky_shader: Shader

func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	_terrain = get_node_or_null("Map/Terrain") as Terrain3D
	if _terrain != null:
		_terrain.cast_shadows = RenderingServer.SHADOW_CASTING_SETTING_OFF
		var terrain_mat := _terrain.material as Terrain3DMaterial
		if terrain_mat != null:
			terrain_mat.output_specular = false
			terrain_mat.max_regions = 64
			terrain_mat.shader_override = TERRAIN_SHADER
			terrain_mat.shader_override_enabled = true
			terrain_mat.update()
	_build_border_walls()
	if _sky_shader == null:
		_sky_shader = Shader.new()
		_sky_shader.code = SKY_CUBE_SHADER
	var sky_shader := _sky_shader
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
	_build_nav()

func _build_border_walls() -> void:
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(WORLD_HALF * 2.0 + 18.0, 40.0, 2.0)
	for i in 4:
		var wall := StaticBody3D.new()
		wall.position = Vector3(0.0, 20.0, WORLD_HALF + 1.5) if i < 2 else Vector3(WORLD_HALF + 1.5, 20.0, 0.0)
		if i == 1 or i == 3:
			wall.position.x = -wall.position.x
			wall.position.z = -wall.position.z
		if i >= 2:
			wall.rotation.y = 1.5707963
		var col := CollisionShape3D.new()
		col.shape = wall_shape
		wall.add_child(col)
		add_child(wall)

	var trees := get_node("Map/Trees")
	for c in trees.find_children("*", "Node3D", true, false):
		var a := c.get_node_or_null("CrossA") as Sprite3D
		var b := c.get_node_or_null("CrossB") as Sprite3D
		if a == null or b == null:
			continue
		a.visible = false
		b.visible = false
		c.set_meta("far_tree", true)
		snap_pending.append(c)
	for c in get_node("Map/OnionSpots").get_children():
		if c is Area3D:
			snap_pending.append(c)
	_snap_pending_trees()

func _snap_pending_trees() -> void:
	if _terrain == null or _terrain.data == null:
		return
	if snap_pending.is_empty():
		if not _far_trees_baked:
			far_bake_ticks += 1
			if far_bake_ticks >= 2:
				_bake_far_trees()
		return
	var keep: Array = []
	for c in snap_pending:
		var n := c as Node3D
		if n == null:
			continue
		var raw := _terrain.data.get_height(Vector3(n.global_position.x, 0.0, n.global_position.z))
		if is_nan(raw):
			keep.append(n)
			continue
		var dy: float = raw - n.position.y
		if far_instances.has(c):
			var inst: Array = far_instances[c]
			var t: Transform3D = inst[2]
			t.origin.y += dy
			inst[2] = t
			(inst[0] as MultiMesh).set_instance_transform(inst[1], t)
		if near_instances.has(c):
			var ninst: Array = near_instances[c]
			var nt: Transform3D = ninst[2]
			nt.origin.y += dy
			ninst[2] = nt
			(ninst[0] as MultiMesh).set_instance_transform(ninst[1], nt)
		n.position.y = raw
		var o := n as Area3D
		if o != null and o.has_meta("base_y"):
			o.set_meta("base_y", raw)
			_place_onion_sprite(o)
	snap_pending = keep
	if not _far_trees_baked:
		far_bake_ticks += 1
		if far_bake_ticks >= 2:
			_bake_far_trees()

func _bake_far_trees() -> void:
	_far_trees_baked = true
	var rows := []
	var groups := {}
	var trees := get_node("Map/Trees") as Node3D
	var inv := trees.global_transform.affine_inverse()
	var candidates: Array = []
	for c in trees.find_children("*", "Node3D", true, false):
		if c.has_meta("far_tree"):
			candidates.append(c)
	for c in candidates:
		var a := c.get_node_or_null("CrossA") as Sprite3D
		var b: Node = c.get_node_or_null("CrossB")
		var row := [c, null, 0.0, 0.0, inv * c.global_position, c is StaticBody3D]
		if a != null:
			var tex: Texture2D = a.texture
			if tex != null:
				var box := a.get_aabb()
				var w := box.size.x * a.global_basis.x.length()
				var h := box.size.y * a.global_basis.y.length()
				if w > 0.01 and h > 0.01:
					row[1] = tex
					row[2] = w
					row[3] = h
					var center: Vector3 = inv * (a.global_transform * box.get_center())
					var base: Vector3 = inv * c.global_position
					row[4] = Vector3(center.x, base.y + h * 0.5, center.z)
		rows.append(row)
		if a != null:
			a.free()
		if b != null:
			b.free()
	for row in rows:
		if row[1] == null:
			continue
		var key := str((row[1] as Texture2D).get_instance_id())
		var g: Dictionary = groups.get(key, {})
		if g.is_empty():
			g["tex"] = row[1]
			g["count"] = 0
			g["near_count"] = 0
			g["cursor"] = 0
			g["near_cursor"] = 0
			groups[key] = g
		g["count"] += 1
		if row[5]:
			g["near_count"] += 1
	var cross := _make_cross_mesh()
	var tree_far := FAR_TREE_CULL
	var tree_near := TREE_NEAR
	for key in groups:
		var g: Dictionary = groups[key]
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var mat := ShaderMaterial.new()
		mat.shader = FAR_TREE_SHADER
		mat.set_shader_parameter("tex", g["tex"])
		mat.set_shader_parameter("tint", _far_tint)
		mat.set_shader_parameter("tree_far", tree_far)
		mat.set_shader_parameter("tree_near", tree_near)
		mat.set_shader_parameter("render_origin", render_origin)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = g["count"]
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trees.add_child(node)
		far_tree_materials.append(mat)
		g["mm"] = mm
		if g["near_count"] > 0:
			var nmat := ShaderMaterial.new()
			nmat.shader = NEAR_TREE_SHADER
			nmat.set_shader_parameter("tex", g["tex"])
			nmat.set_shader_parameter("tint", _far_tint)
			nmat.set_shader_parameter("tree_near", tree_near)
			nmat.set_shader_parameter("render_origin", render_origin)
			var nmm := MultiMesh.new()
			nmm.transform_format = MultiMesh.TRANSFORM_3D
			nmm.mesh = cross
			nmm.instance_count = g["near_count"]
			var nnode := MultiMeshInstance3D.new()
			nnode.multimesh = nmm
			nnode.material_override = nmat
			nnode.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trees.add_child(nnode)
			near_tree_materials.append(nmat)
			g["nmm"] = nmm
	for row in rows:
		if row[1] == null:
			continue
		var key := str((row[1] as Texture2D).get_instance_id())
		var g: Dictionary = groups[key]
		var idx: int = g["cursor"]
		g["cursor"] = idx + 1
		var origin: Vector3 = row[4]
		var t := Transform3D(Basis.from_scale(Vector3(row[2], row[3], 1.0)), origin)
		(g["mm"] as MultiMesh).set_instance_transform(idx, t)
		far_instances[row[0]] = [g["mm"], idx, t]
		if row[5]:
			var nidx: int = g["near_cursor"]
			g["near_cursor"] = nidx + 1
			var nt := Transform3D(Basis.from_scale(Vector3(row[2], row[3], row[2])), origin)
			(g["nmm"] as MultiMesh).set_instance_transform(nidx, nt)
			near_instances[row[0]] = [g["nmm"], nidx, nt]

func _make_cross_mesh() -> ArrayMesh:
	var h := 0.35355338
	var verts := PackedVector3Array([
		Vector3(-h, -0.5, -h), Vector3(h, -0.5, h), Vector3(h, 0.5, h), Vector3(-h, 0.5, -h),
		Vector3(-h, -0.5, h), Vector3(h, -0.5, -h), Vector3(h, 0.5, -h), Vector3(-h, 0.5, h),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0),
		Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0),
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _next_onion() -> Area3D:
	var spots := get_node("Map/OnionSpots").get_children()
	for i in spots.size():
		onion_spot = (onion_spot + 1) % spots.size()
		var spot := spots[onion_spot] as Area3D
		if spot == null or spot.visible or spot.has_meta("onion"):
			continue
		return spot
	return null

func _build_onions() -> void:
	for c in get_node("Map/OnionSpots").get_children():
		if c is Area3D:
			_onion_deactivate(c)
	var count := TOTAL_PAGES if not endless else 5
	for i in count:
		var spot := _next_onion()
		if spot == null:
			break
		_onion_activate(spot)

func _onion_activate(area: Area3D) -> void:
	if _terrain != null and _terrain.data != null:
		var h := _terrain.data.get_height(Vector3(area.global_position.x, 0.0, area.global_position.z))
		if not is_nan(h):
			area.position.y = h
	area.collision_layer = 2
	area.visible = true
	area.set_meta("onion", true)
	area.set_meta("base_y", area.position.y)
	onions.append(area)
	_place_onion_sprite(area)

func _onion_deactivate(area: Area3D) -> void:
	var base_y := float(area.get_meta("base_y")) if area.has_meta("base_y") else area.position.y
	area.collision_layer = 0
	area.visible = false
	area.rotation = Vector3.ZERO
	area.position.y = base_y
	area.remove_meta("onion")
	area.remove_meta("base_y")

func _build_enemy() -> void:
	enemy_anchor = Node3D.new()
	enemy_anchor.physics_interpolation_mode = Node3D.PHYSICS_INTERPOLATION_MODE_ON
	enemy_anchor.position = Vector3(0, 5, 0)
	add_child(enemy_anchor)
	enemy = Sprite3D.new()
	enemy.physics_interpolation_mode = Node3D.PHYSICS_INTERPOLATION_MODE_OFF
	var tex := GameState.skin_texture()
	enemy.texture = tex
	enemy.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	enemy.shaded = false
	enemy.pixel_size = 10.0 / float(tex.get_height())
	enemy.transparent = true
	enemy.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	enemy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	enemy.modulate = Color(1.0, 1.0, 1.0, 1.0)
	enemy.position = Vector3.ZERO
	enemy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	enemy.visible = false
	enemy_anchor.add_child(enemy)
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
	_snap_tick -= delta
	if _snap_tick <= 0.0 and (not _far_trees_baked or not snap_pending.is_empty()):
		_snap_tick = 0.12
		_snap_pending_trees()
	if static_playing:
		_static_tick(delta)
		return
	if game_over or paused:
		return
	for o in onions:
		if is_instance_valid(o):
			o.position.y = float(o.get_meta("base_y"))
			o.rotation.y += delta * 0.9
	_update_threat(delta)
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
		_static_frame_idx = -1
		_static_alpha = -1.0
		return
	var to := enemy_anchor.global_position - player.global_position
	to.y = 0.0
	var dist := to.length()
	var t := clampf(1.0 - dist / THREAT_RANGE, 0.0, 1.0)
	threat = lerpf(threat, t, clampf(delta * 5.0, 0.0, 1.0))
	var alpha := threat * STATIC_MAX_ALPHA
	if alpha <= 0.005:
		hud.hide_static()
		_static_frame_idx = -1
		_static_alpha = -1.0
		return
	static_time += delta
	var frame_idx := int(static_time / 0.07) % threat_frames.size()
	if frame_idx != _static_frame_idx or absf(alpha - _static_alpha) >= 0.02:
		_static_frame_idx = frame_idx
		_static_alpha = alpha
		hud.show_static(threat_frames[frame_idx], alpha)

func _update_prompt() -> void:
	var grab_now := (endless or pages < TOTAL_PAGES) and _ray_onion() != null
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
	var from := player.camera.project_ray_origin(center) + render_origin
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
	_onion_deactivate(onion)
	_on_onion_collected()
	if endless:
		var spot := _next_onion()
		if spot != null:
			_onion_activate(spot)
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
	_far_tint = tint_v
	for m in far_tree_materials:
		m.set_shader_parameter("tint", tint_v)
	for m in near_tree_materials:
		m.set_shader_parameter("tint", tint_v)
	for o in onions:
		if is_instance_valid(o):
			(o.get_child(0) as Sprite3D).modulate = tint_v

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
	env.fog_light_color = env.fog_light_color.lerp(fog_color_t, weight)
	_phase_fog = lerpf(_phase_fog, fog_t, weight)
	env.fog_density = _phase_fog
	env.fog_sky_affect = lerpf(env.fog_sky_affect, affect_t, weight)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, amb_t, weight)
	_day_mix = lerpf(_day_mix, day_t, weight)
	sky_mat.set_shader_parameter("day_mix", _day_mix)
	sun.light_energy = lerpf(sun.light_energy, sun_t, weight)
	sun.light_color = sun.light_color.lerp(sun_c, weight)
	var settled := true
	settled = settled and _color_close(env.fog_light_color, fog_color_t, 0.004)
	settled = settled and absf(_phase_fog - fog_t) < 0.000002
	settled = settled and absf(env.fog_sky_affect - affect_t) < 0.0004
	settled = settled and absf(env.ambient_light_energy - amb_t) < 0.001
	settled = settled and absf(_day_mix - day_t) < 0.002
	settled = settled and absf(sun.light_energy - sun_t) < 0.001
	settled = settled and _color_close(sun.light_color, sun_c, 0.004)
	if settled:
		env.fog_light_color = fog_color_t
		_phase_fog = fog_t
		env.fog_density = _phase_fog
		env.fog_sky_affect = affect_t
		env.ambient_light_energy = amb_t
		_day_mix = day_t
		sky_mat.set_shader_parameter("day_mix", _day_mix)
		sun.light_energy = sun_t
		sun.light_color = sun_c
		_phase_converged = true

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
	_update_render_origin()
	_sync_terrain_target()
	_tick_enemy(delta)

func _tick_enemy(delta: float) -> void:
	if not enemy_active and pages >= 1:
		enemy_active = true
		if nav == null:
			_build_nav()
		_spawn_enemy_front()
	if not enemy_active or enemy_mode == "hidden":
		return
	enemy_bob_t += delta
	if enemy_mode == "hunt":
		sees_timer -= delta
		if sees_timer <= 0.0:
			sees_timer = 0.1
			sees_cache = _enemy_sees_player()
		if sees_cache:
			enemy_lose_time = 0.0
			last_seen = Vector2(player.global_position.x, player.global_position.z)
		else:
			enemy_lose_time += delta
			if enemy_lose_time > ENEMY_MEMORY:
				_begin_retreat()
		if enemy_mode == "hunt":
			var to_p := player.global_position - enemy_anchor.global_position
			to_p.y = 0.0
			if to_p.length() < KILL_RADIUS:
				_die()
				return
			var base := minf(ENEMY_FOLLOW_BASE + ENEMY_FOLLOW_PER_PAGE * pages, ENEMY_SPEED_CAP)
			_enemy_advance(delta, last_seen, base)
	if enemy_mode == "retreat":
		enemy_retreat_time += delta
		if not enemy_retreat_goal_ok:
			enemy_goal = _pick_retreat_target()
			enemy_retreat_goal_ok = true
		_enemy_retreat_advance(delta)
		enemy_fade = maxf(0.0, 1.0 - enemy_retreat_time / ENEMY_RETREAT_FADE)
		if enemy_fade <= 0.0:
			_set_enemy_mode("hidden")
			return
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
	enemy.visible = true
	enemy.modulate = Color(1.0, 1.0, 1.0, enemy_fade)
	enemy_anchor.global_position.y = _terrain_height(enemy_anchor.global_position.x, enemy_anchor.global_position.z) + 5.0 + sin(enemy_bob_t * 2.2) * 0.24

func _begin_retreat() -> void:
	enemy_mode = "retreat"
	enemy_retreat_time = 0.0
	enemy_retreat_goal_ok = false
	enemy_fade = 1.0
	enemy_goal_ok = false
	enemy_whisker_timer = 0.0
	enemy_whisker_offset = 0.0
	enemy_path = PackedVector2Array()
	enemy_path_i = 0
	enemy_path_time = 0.0
	enemy_arrived = false

func _pick_retreat_target() -> Vector2:
	var pc := Vector2(player.global_position.x, player.global_position.z)
	var ec := Vector2(enemy_anchor.global_position.x, enemy_anchor.global_position.z)
	var away := ec - pc
	if away.length() < 0.5:
		away = Vector2(cos(enemy_yaw), sin(enemy_yaw))
	away = away.normalized()
	var best := ec
	for i in 24:
		var p: Vector2 = ec + away.rotated(randf_range(-0.7, 0.7)) * randf_range(ENEMY_RETREAT_DIST_MIN, ENEMY_RETREAT_DIST_MAX)
		p.x = clampf(p.x, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
		p.y = clampf(p.y, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
		best = p
		if nav == null or nav.is_free_point(p):
			return p
	return best

func _enemy_retreat_advance(delta: float) -> void:
	var pos := Vector2(enemy_anchor.global_position.x, enemy_anchor.global_position.z)
	var dir := enemy_goal - pos
	if dir.length() < 0.5:
		enemy_goal = _pick_retreat_target()
		return
	dir = dir.normalized()
	dir = _whisker_dir(dir, delta)
	var next_pos := enemy_anchor.global_position
	next_pos.x += dir.x * ENEMY_RETREAT_SPEED * delta
	next_pos.z += dir.y * ENEMY_RETREAT_SPEED * delta
	enemy_anchor.global_position = next_pos
	enemy_yaw = lerp_angle(enemy_yaw, dir.angle(), clampf(10.0 * delta, 0.0, 1.0))

func _enemy_sees_player() -> bool:
	var to_p := player.global_position - enemy_anchor.global_position
	to_p.y = 0.0
	var dist := to_p.length()
	if dist < 0.001:
		return true
	var fwd := Vector2(cos(enemy_yaw), sin(enemy_yaw))
	var pdir := Vector2(to_p.x, to_p.z) / dist
	if dist <= ENEMY_VISION_DIST and (dist <= 3.0 or absf(fwd.angle_to(pdir)) <= ENEMY_FOV_HALF):
		var p2 := Vector2(player.global_position.x, player.global_position.z)
		if nav != null and nav.has_los(Vector2(enemy_anchor.global_position.x, enemy_anchor.global_position.z), p2):
			return true
	return player.is_sprinting() and dist <= ENEMY_HEAR_RUN

func _enemy_advance(delta: float, target: Vector2, speed: float) -> void:
	enemy_path_time -= delta
	if enemy_path_time <= 0.0:
		enemy_path_time = ENEMY_PATH_INTERVAL
		enemy_path = nav.find_path(Vector2(enemy_anchor.global_position.x, enemy_anchor.global_position.z), target)
		enemy_path_i = 0
		enemy_arrived = enemy_path.is_empty()
	var pos := Vector2(enemy_anchor.global_position.x, enemy_anchor.global_position.z)
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
		dir = _whisker_dir(dir, delta)
		var next_pos := enemy_anchor.global_position
		next_pos.x += dir.x * speed * delta
		next_pos.z += dir.y * speed * delta
		enemy_anchor.global_position = next_pos
		enemy_yaw = lerp_angle(enemy_yaw, dir.angle(), clampf(6.0 * delta, 0.0, 1.0))

func _whisker_dir(dir: Vector2, delta: float) -> Vector2:
	enemy_whisker_timer -= delta
	if enemy_whisker_timer > 0.0 and enemy_whisker_last.dot(dir) > 0.7:
		return dir.rotated(enemy_whisker_offset)
	enemy_whisker_timer = ENEMY_WHISKER_INTERVAL
	enemy_whisker_last = dir
	var space := get_world_3d().direct_space_state
	var y := _terrain_height(enemy_anchor.global_position.x, enemy_anchor.global_position.z) + 4.5
	var origin := Vector3(enemy_anchor.global_position.x, y, enemy_anchor.global_position.z)
	var to := origin + Vector3(dir.x, 0.0, dir.y) * ENEMY_WHISKER_DIST
	var mid := PhysicsRayQueryParameters3D.create(origin, to, 1)
	if space.intersect_ray(mid).is_empty():
		enemy_whisker_offset = 0.0
		return dir
	var best := dir
	for a in [-1.0, 1.0]:
		var alt := dir.rotated(1.05 * a)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + Vector3(alt.x, 0.0, alt.y) * ENEMY_WHISKER_DIST * 1.4, 1)
		var h := space.intersect_ray(q)
		if h.is_empty():
			best = alt
			break
	enemy_whisker_offset = dir.angle_to(best)
	return best

func _set_enemy_mode(m: String) -> void:
	enemy_mode = m
	enemy_goal_ok = false
	enemy_path = PackedVector2Array()
	enemy_path_i = 0
	enemy_path_time = 0.0
	enemy_arrived = false
	if m == "hidden":
		enemy_fade = 0.0
		enemy.visible = false
		enemy.modulate = Color(1.0, 1.0, 1.0, 0.0)
		enemy_retreat_goal_ok = false
		if enemy_chase_audio != null and enemy_chase_audio.playing:
			enemy_chase_audio.stop()

func _on_onion_collected() -> void:
	if enemy_active and enemy_mode == "hidden":
		_spawn_enemy_front()

func _build_nav() -> void:
	nav = NAV.new()
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	var rs := PackedFloat32Array()
	for t in get_node("Map/Trees").find_children("*", "StaticBody3D", true, false):
		if not (t is StaticBody3D):
			continue
		var col := t.get_node("Collision") as CollisionShape3D
		var cyl := col.shape as CylinderShape3D
		var gp: Vector3 = t.global_position
		xs.append(gp.x)
		zs.append(gp.z)
		rs.append(cyl.radius)
	nav.build(xs, zs, rs)

func _spawn_enemy_front() -> void:
	var fwd := -player.camera.global_basis.z
	var front := Vector2(fwd.x, fwd.z).normalized()
	var pc := Vector2(player.global_position.x, player.global_position.z)
	var p: Vector2 = _pick_spawn_point(pc, front)
	enemy_anchor.global_position = Vector3(p.x, _terrain_height(p.x, p.y) + 5.0, p.y)
	enemy_anchor.reset_physics_interpolation()
	enemy.visible = true
	enemy.modulate = Color(1.0, 1.0, 1.0, 1.0)
	enemy_yaw = (pc - p).angle()
	enemy_mode = "hunt"
	enemy_arrived = false
	enemy_goal_ok = false
	enemy_path = PackedVector2Array()
	enemy_path_i = 0
	enemy_path_time = 0.0
	enemy_lose_time = 0.0
	enemy_retreat_time = 0.0
	enemy_retreat_goal_ok = false
	enemy_fade = 1.0
	enemy_whisker_timer = 0.0
	enemy_whisker_offset = 0.0
	last_seen = pc
	sees_cache = false
	sees_timer = 0.0

func _pick_spawn_point(from: Vector2, first_dir: Vector2) -> Vector2:
	var dirs: Array[Vector2] = [first_dir, first_dir.rotated(0.5), first_dir.rotated(-0.5)]
	for i in range(12):
		dirs.append(first_dir.rotated(-0.7 + 1.4 * float(i) / 11.0))
	var best_clear := -1.0
	var best := Vector2(from.x, from.y + 22.0)
	for dir in dirs:
		var d := randf_range(ENEMY_RESPAWN_DIST_MIN, ENEMY_RESPAWN_DIST_MAX)
		var p := Vector2(from.x + dir.x * d, from.y + dir.y * d)
		p.x = clampf(p.x, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
		p.y = clampf(p.y, -WORLD_HALF + WALL_SAFE, WORLD_HALF - WALL_SAFE)
		var clear: float = float(WORLD_HALF) if nav == null else nav.spawn_clearance(from, p)
		if clear > best_clear:
			best_clear = clear
			best = p
	return best

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
