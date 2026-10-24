extends Node

var game: Node
var terrain: Terrain3D
var mat: Terrain3DMaterial

func _ready() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in range(90):
		await get_tree().process_frame
	terrain = game.get_node("Map/Terrain")
	mat = terrain.material as Terrain3DMaterial
	game.player.head.rotation.x = -0.55
	game.player.rotation.y = 0.7
	for i in range(10):
		await get_tree().process_frame
	await _shot("current")
	var lite := load("res://scripts/mobile_terrain_lite.gdshader") as Shader
	mat.shader_override = lite
	mat.shader_override_enabled = true
	mat.update()
	for i in range(20):
		await get_tree().process_frame
	await _shot("lite")
	get_tree().quit()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/opencode/shots/%s.png" % name)
	print("SHOT ", name, " ", img.get_width(), "x", img.get_height())
