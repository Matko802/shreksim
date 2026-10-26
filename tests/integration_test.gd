extends Node

func _ready() -> void:
	await get_tree().process_frame
	var failures := 0
	GameState.total_pages = 0
	GameState.total_escapes = 0
	GameState.save_stats()
	GameState.game_type = "eight_pages"
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	if game.pages != 0:
		failures += 1
		print("FAIL start pages")
	if game.hud == null or game.pause_menu == null:
		failures += 1
		print("FAIL native UI scenes missing")
	if game.player == null or not game.player is SwampPlayer:
		failures += 1
		print("FAIL player missing")
	if game.far_tree_materials.size() != 3:
		failures += 1
		print("FAIL far tree batches: ", game.far_tree_materials.size())
	if game.near_tree_materials.size() != 3:
		failures += 1
		print("FAIL near tree batches: ", game.near_tree_materials.size())
	if game.player.flashlight_container.visible:
		failures += 1
		print("FAIL flashlight visible by default")
	if game.nav == null:
		failures += 1
		print("FAIL nav not prebuilt")
	var pool: Array = game.onions.duplicate()

	game._collect(pool[0])
	var cutscene_start := Vector2(game.enemy_anchor.global_position.x - game.player.global_position.x, game.enemy_anchor.global_position.z - game.player.global_position.z).length()
	if cutscene_start < 90.0:
		failures += 1
		print("FAIL cutscene did not start in fog: ", cutscene_start)
	if game.enemy_mode != "cutscene":
		failures += 1
		print("FAIL cutscene enemy mode: ", game.enemy_mode)
	if game.enemy_chase_audio == null or not game.enemy_chase_audio.playing:
		failures += 1
		print("FAIL cutscene music did not start")
	var saw_cutscene := false
	var saw_run := false
	var cutscene_closed := false
	var saw_follow := false
	for i in range(600):
		if game.cutscene_active:
			saw_cutscene = true
			var fwd3: Vector3 = -game.player.camera.global_basis.z
			var to_enemy3: Vector3 = game.enemy_anchor.global_position - game.player.global_position
			fwd3.y = 0.0
			to_enemy3.y = 0.0
			if to_enemy3.length() > 20.0 and fwd3.normalized().dot(to_enemy3.normalized()) > 0.97:
				saw_follow = true
		if game.hud.run_label.visible:
			saw_run = true
		var current_dist := Vector2(game.enemy_anchor.global_position.x - game.player.global_position.x, game.enemy_anchor.global_position.z - game.player.global_position.z).length()
		if current_dist < cutscene_start - 20.0:
			cutscene_closed = true
		if saw_cutscene and not game.cutscene_active:
			break
		await get_tree().physics_frame
	if not saw_cutscene:
		failures += 1
		print("FAIL first onion cutscene missing")
	if not cutscene_closed:
		failures += 1
		print("FAIL cutscene enemy did not travel from fog")
	if not saw_follow:
		failures += 1
		print("FAIL cutscene camera did not follow Shrek")
	if not saw_run:
		failures += 1
		print("FAIL RUN text missing")
	if game.player.controls_locked:
		failures += 1
		print("FAIL controls still locked after cutscene")
	if absf(angle_difference(0.0, game.player.rotation.y)) < 2.0:
		failures += 1
		print("FAIL cutscene did not turn player: ", game.player.rotation.y)
	if not game.enemy.visible or game.enemy_mode != "hunt":
		failures += 1
		print("FAIL enemy not hunting after cutscene")

	var body_yaw: float = game.player.rotation.y
	Input.action_press("look_behind")
	for i in range(30):
		await get_tree().process_frame
	var head_yaw: float = game.player.head.rotation.y
	if absf(angle_difference(0.0, head_yaw)) < 2.0:
		failures += 1
		print("FAIL look behind did not move camera: ", head_yaw)
	if absf(angle_difference(body_yaw, game.player.rotation.y)) > 0.01:
		failures += 1
		print("FAIL look behind turned body: ", game.player.rotation.y)
	var to_enemy: Vector3 = game.enemy_anchor.global_position - game.player.global_position
	to_enemy.y = 0.0
	var cam_fwd: Vector3 = -game.player.camera.global_basis.z
	cam_fwd.y = 0.0
	if to_enemy.length() > 1.0 and cam_fwd.normalized().dot(to_enemy.normalized()) < 0.9:
		failures += 1
		print("FAIL look behind camera not tracking Shrek: ", cam_fwd, " ", to_enemy)
	if game.hud.direction_arrow == null or not game.hud.direction_arrow.visible:
		failures += 1
		print("FAIL direction arrow missing while looking behind")
	var yaw_before: float = game.player._look_yaw_target
	game.player.touch_look(Vector2(400.0, 0.0))
	if absf(game.player._look_yaw_target - yaw_before) > 0.0001:
		failures += 1
		print("FAIL touch look changed camera while looking behind")
	Input.action_release("look_behind")
	for i in range(30):
		await get_tree().process_frame
	if absf(game.player.head.rotation.y) > 0.1:
		failures += 1
		print("FAIL look behind did not return: ", game.player.head.rotation.y)
	if game.hud.direction_arrow != null and game.hud.direction_arrow.visible:
		failures += 1
		print("FAIL direction arrow still visible")
	var crouch_has_c := false
	for ev: InputEvent in InputMap.action_get_events("crouch"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_C:
			crouch_has_c = true
	if crouch_has_c:
		failures += 1
		print("FAIL crouch still bound to C")
	var look_has_tab := false
	var look_has_c := false
	for ev: InputEvent in InputMap.action_get_events("look_behind"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_TAB:
			look_has_tab = true
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_C:
			look_has_c = true
	if not look_has_tab:
		failures += 1
		print("FAIL look behind not bound to Tab")
	if look_has_c:
		failures += 1
		print("FAIL look behind still bound to C")
	await get_tree().physics_frame
	await get_tree().physics_frame
	if game.pages != 1:
		failures += 1
		print("FAIL collect pages")
	if GameState.total_pages != 1:
		failures += 1
		print("FAIL total pages")
	if not game.enemy_active:
		failures += 1
		print("FAIL enemy never activated")
	var track: String = ""
	if game.music != null and game.music.stream != null:
		track = game.music.stream.resource_path
	if game.music != null and game.music.playing:
		failures += 1
		print("FAIL music should never play: ", track)
	if game.player.is_flashlight_on():
		failures += 1
		print("FAIL flashlight should start off")

	var prev_speed: float = game.player.WALK_SPEED
	Input.action_press("move_forward")
	var waited := 0.0
	while waited < 0.5:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
		if Vector2(game.player.velocity.x, game.player.velocity.z).length() > 0.4:
			break
	var hs: float = Vector2(game.player.velocity.x, game.player.velocity.z).length()
	Input.action_release("move_forward")
	if hs < 0.5 * prev_speed or hs > 1.5 * prev_speed:
		failures += 1
		print("FAIL walk speed: ", hs)

	game.enemy_anchor.global_position = game.player.global_position + Vector3(0, 0, 24.0)
	game.enemy_anchor.reset_physics_interpolation()
	for i in range(60):
		await get_tree().physics_frame
	var to_e: Vector3 = game.enemy_anchor.global_position - game.player.global_position
	to_e.y = 0.0
	var chased: float = to_e.length()
	if chased >= 22.8:
		failures += 1
		print("FAIL enemy did not chase: ", chased)
	if not game.hud.static_overlay.visible:
		failures += 1
		print("FAIL static overlay missing at threat")
	game.enemy_anchor.global_position = game.player.global_position + Vector3(0, 0, 48.0)
	game.enemy_anchor.reset_physics_interpolation()
	for i in range(50):
		await get_tree().physics_frame
	await get_tree().process_frame
	if game.hud.static_overlay.visible:
		failures += 1
		print("FAIL static overlay should fade far away")

	game._collect(pool[1])
	game._collect(pool[2])
	var pano: ShaderMaterial = game.env.sky.sky_material
	if pano.get_shader_parameter("face") == null:
		failures += 1
		print("FAIL custom sky missing")

	for i in range(3, 7):
		game._collect(pool[i])
		await get_tree().process_frame
	game._lerp_phase(1.0)
	print("DEBUG pages=", game.pages, " fog_begin=", game.env.fog_depth_begin, " fog_end=", game.env.fog_depth_end, " phase7fog=", game.PHASES[7]["fog"])
	if game.pages != 7:
		failures += 1
		print("FAIL pages count after 7")
	if not is_equal_approx(game._phase_fog, game.PHASES[7]["fog"]):
		failures += 1
		print("FAIL deep night fog")
	if game.env.fog_mode != Environment.FOG_MODE_DEPTH or not is_equal_approx(game.env.fog_depth_end, game._fog_distance()):
		failures += 1
		print("FAIL fog edge")
	if not is_equal_approx(game.env.fog_density, 1.0):
		failures += 1
		print("FAIL fog not opaque")
	if not is_equal_approx(game.env.fog_depth_begin, game._fog_distance() * game._fog_begin_ratio()):
		failures += 1
		print("FAIL night fog begin")
	if game._fog_begin_ratio() < game.FOG_NIGHT_RATIO or game._fog_begin_ratio() > game.FOG_EDGE_RATIO:
		failures += 1
		print("FAIL fog begin ratio")
	if game._far_tint.r > 0.15:
		failures += 1
		print("FAIL trees lit at night: ", game._far_tint)
	for mat in game.far_tree_materials:
		var tint: Color = mat.get_shader_parameter("tint")
		if tint.r > 0.15:
			failures += 1
			print("FAIL far trees lit at night")
	for mat in game.near_tree_materials:
		var tint: Color = mat.get_shader_parameter("tint")
		if tint.r > 0.15:
			failures += 1
			print("FAIL near trees lit at night")

	game._collect(pool[7])
	await get_tree().process_frame
	if not game.won or not game.game_over:
		failures += 1
		print("FAIL win not registered")
	await _wait(0.8)
	if not game.hud.static_overlay.visible or not game.hud.result_label.visible:
		failures += 1
		print("FAIL win screen missing")
	if GameState.total_escapes != 1:
		failures += 1
		print("FAIL escapes stat")

	var g2: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(g2)
	await get_tree().process_frame
	await get_tree().physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	g2._die()
	if not g2.static_playing:
		failures += 1
		print("FAIL static not playing")
	g2._static_tick(0.01)
	var tex1: Texture2D = g2.hud.static_overlay.texture
	if tex1 == null or tex1.resource_path != "res://assets/images/static/static1.png":
		failures += 1
		print("FAIL first static frame: ", tex1.resource_path if tex1 else "null")
	g2._static_tick(0.5)
	var tex2: Texture2D = g2.hud.static_overlay.texture
	if tex2 == null or tex2 == tex1:
		failures += 1
		print("FAIL second static frame")
	g2._static_tick(0.5)
	var tex3: Texture2D = g2.hud.static_overlay.texture
	if tex3 == null or tex3 == tex2:
		failures += 1
		print("FAIL third static frame")
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		failures += 1
		print("FAIL mouse locked during static")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	g2._unhandled_input(click)
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		failures += 1
		print("FAIL mouse recaptured during static")
	g2._static_tick(0.5)
	if g2.static_playing:
		failures += 1
		print("FAIL static did not finish")
	var tex: Texture2D = g2.hud.static_overlay.texture
	if tex == null or tex.resource_path != "res://assets/images/results/fail2.png":
		failures += 1
		print("FAIL fail screen texture: ", tex.resource_path if tex else "null")

	GameState.game_type = "endless"
	var g3: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(g3)
	await get_tree().process_frame
	await get_tree().physics_frame
	if g3.enemy == null or g3.enemy.visible:
		failures += 1
		print("FAIL endless enemy should start hidden")
	if g3.hud.timer_label.visible:
		failures += 1
		print("FAIL endless should have no timer")
	var op: Area3D = g3.onions[0]
	g3._collect(op)
	await get_tree().process_frame
	if g3.pages != 1:
		failures += 1
		print("FAIL endless collect")
	var respawned: Area3D = g3.onions[g3.onions.size() - 1]
	if respawned == null or respawned == op or not respawned.visible:
		failures += 1
		print("FAIL endless did not respawn onion")
	if op.visible or op.has_meta("onion"):
		failures += 1
		print("FAIL endless onion not deactivated")
	if g3.hud.pages_label.text != "1":
		failures += 1
		print("FAIL endless label: ", g3.hud.pages_label.text)
	for i in range(20):
		await get_tree().physics_frame
	if not g3.enemy_active:
		failures += 1
		print("FAIL endless enemy not active")
	if not g3.enemy.visible:
		failures += 1
		print("FAIL endless enemy not spawned")
	var prev_best := GameState.best_endless
	g3._collect(g3.onions[0])
	if GameState.best_endless != maxi(prev_best, 2):
		failures += 1
		print("FAIL endless best: ", GameState.best_endless)
	GameState.best_endless = prev_best

	GameState.game_type = "eight_pages"
	if failures == 0:
		print("ALL TESTS OK")
	else:
		print("FAILURES: ", failures)
	get_tree().quit(failures)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
