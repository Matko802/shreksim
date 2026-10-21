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
	var pool: Array = game.onions.duplicate()

	game._collect(pool[0])
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
	if track != "res://assets/sounds/music_pages_1_2.ogg":
		failures += 1
		print("FAIL phase music track: ", track)
	if not game.player.is_flashlight_on():
		failures += 1
		print("FAIL flashlight should start on")

	var prev_speed: float = game.player.WALK_SPEED
	Input.action_press("move_forward")
	var waited := 0.0
	while waited < 0.5:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
		if Vector2(game.player.velocity.x, game.player.velocity.z).length() > 10.0:
			break
	var hs: float = Vector2(game.player.velocity.x, game.player.velocity.z).length()
	Input.action_release("move_forward")
	if hs < 0.5 * prev_speed or hs > 1.5 * prev_speed:
		failures += 1
		print("FAIL walk speed: ", hs)

	game.enemy.global_position = game.player.global_position + Vector3(0, 0, 600)
	for i in range(60):
		await get_tree().physics_frame
	var to_e: Vector3 = game.enemy.global_position - game.player.global_position
	to_e.y = 0.0
	var chased: float = to_e.length()
	if chased >= 570.0:
		failures += 1
		print("FAIL enemy did not chase: ", chased)
	if not game.hud.static_overlay.visible:
		failures += 1
		print("FAIL static overlay missing at threat")
	game.enemy.global_position = game.player.global_position + Vector3(0, 0, 1200)
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
	print("DEBUG pages=", game.pages, " fog=", game.env.fog_density, " phase7fog=", game.PHASES[7]["fog"])
	if game.pages != 7:
		failures += 1
		print("FAIL pages count after 7")
	if not is_equal_approx(game.env.fog_density, game.PHASES[7]["fog"]):
		failures += 1
		print("FAIL deep night fog")

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
	g2._die()
	await _wait(0.4)
	if not g2.static_playing:
		failures += 1
		print("FAIL static not playing")
	await _wait(2.6)
	var tex: Texture2D = g2.hud.static_overlay.texture
	if tex == null or tex.resource_path != "res://assets/images/results/fail2.png":
		failures += 1
		print("FAIL fail screen texture: ", tex.resource_path if tex else "null")

	GameState.game_type = "endless"
	var g3: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(g3)
	await get_tree().process_frame
	await get_tree().physics_frame
	if g3.enemy != null:
		failures += 1
		print("FAIL endless should have no enemy")
	if g3.hud.timer_label.visible:
		failures += 1
		print("FAIL endless should have no timer")
	var op: Area3D = g3.onions[0]
	g3._collect(op)
	await get_tree().process_frame
	if g3.pages != 1:
		failures += 1
		print("FAIL endless collect")
	if is_instance_valid(op):
		failures += 1
		print("FAIL endless did not respawn onion")
	if g3.hud.pages_label.text != "1":
		failures += 1
		print("FAIL endless label: ", g3.hud.pages_label.text)

	GameState.game_type = "eight_pages"
	if failures == 0:
		print("ALL TESTS OK")
	else:
		print("FAILURES: ", failures)
	get_tree().quit(failures)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
