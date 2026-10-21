extends Node

var game: Node
var fails := 0

func _ready() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in range(4):
		await get_tree().physics_frame
	var player: Node = game.player
	if player.footstep_surfaces == null:
		print("FAIL: footstep_surfaces not set")
		fails += 1
	var first: AudioStream = player.footstep_surfaces.get_random_sound(&"Default")
	if first == null:
		print("FAIL: Default surface empty")
		fails += 1
	else:
		print("default stream ok: ", first.resource_path.get_file())
	var second: AudioStream = player.footstep_surfaces.get_random_sound(&"Puddle")
	if second == null:
		print("FAIL: Puddle surface empty")
		fails += 1
	Input.action_press("move_forward")
	var played := false
	for i in range(240):
		await get_tree().physics_frame
		if player.footstep_player.playing and player.footstep_player.stream != null:
			played = true
			break
	if not played:
		print("FAIL: no footstep played while walking")
		fails += 1
	else:
		print("step playing: pitch=", player.footstep_player.pitch_scale, " vol=", player.footstep_player.volume_linear)
	Input.action_release("move_forward")
	print("FOOTSTEP FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)
