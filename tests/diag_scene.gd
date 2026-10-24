extends Node

func _ready() -> void:
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in range(180):
		await get_tree().process_frame
	var trees = game.get_node("Map/Trees")
	var nodes := 0
	var sprites := 0
	var static_bodies := 0
	var collision_shapes := 0
	var multimeshes := 0
	var instances := 0
	for c in trees.find_children("*", "Node3D", true, false):
		nodes += 1
		if c is Sprite3D:
			sprites += 1
		if c is StaticBody3D:
			static_bodies += 1
		if c is CollisionShape3D:
			collision_shapes += 1
		if c is MultiMeshInstance3D:
			multimeshes += 1
			instances += (c as MultiMeshInstance3D).multimesh.instance_count
	print("trees nodes=%d sprites=%d static_bodies=%d collision_shapes=%d multimeshes=%d instances=%d" % [nodes, sprites, static_bodies, collision_shapes, multimeshes, instances])
	var total_nodes := 0
	for c in game.find_children("*", "Node", true, false):
		total_nodes += 1
	print("total_nodes=", total_nodes)
	print("onions=", game.onions.size())
	var terrain = game.get_node("Map/Terrain")
	print("terrain regions=", terrain.data.get_region_count(), " collision_mode=", terrain.collision_mode, " radius=", terrain.collision_radius)
	print("prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objs=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	print("fps=", Engine.get_frames_per_second())
	get_tree().quit()
