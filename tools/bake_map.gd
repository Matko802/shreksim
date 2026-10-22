extends SceneTree

const WORLD_HALF := 128.0

func terrain_h(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	var edge := clampf((WORLD_HALF - dist) / 36.0, 0.0, 1.0)
	var spawn := clampf((dist - 9.6) / 16.0, 0.0, 1.0)
	var tops := sin(x * 0.03 + 1.7) * cos(z * 0.0225 - 2.3) * 3.8
	var ridge := sin(dist * 0.0275 + 1.3) * 2.2
	var mids := sin((x + z) * 0.04 - 0.8) * 1.28
	var bumps := sin(x * 0.1025) * cos(z * 0.1075) * 0.32
	return (tops + ridge + mids + bumps) * edge * spawn

func apron_h(x: float, z: float) -> float:
	var out := clampf((maxf(absf(x), absf(z)) - WORLD_HALF) / 72.0, 0.0, 1.0)
	var tops := sin(x * 0.03 + 1.7) * cos(z * 0.0225 - 2.3) * 2.4
	var mids := sin((x + z) * 0.04 - 0.8) * 0.8
	var bumps := sin(x * 0.1025) * cos(z * 0.1075) * 0.32
	return (tops + mids + bumps) * out

func surface_h(x: float, z: float) -> float:
	if maxf(absf(x), absf(z)) <= WORLD_HALF:
		return terrain_h(x, z)
	return apron_h(x, z)

func make_ground_texture() -> void:
	var block := 16
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	var grid := img.get_width() / block
	var variants: Array[Image] = []
	var tex_path := "res://assets/textures/godotcraft/grass_top.png"
	var crop := (load(tex_path) as Texture2D).get_image()
	crop.convert(Image.FORMAT_RGBA8)
	variants.append(crop)
	var fx := crop.duplicate() as Image
	fx.flip_x()
	variants.append(fx)
	var fy := crop.duplicate() as Image
	fy.flip_y()
	variants.append(fy)
	var fxy := crop.duplicate() as Image
	fxy.flip_x()
	fxy.flip_y()
	variants.append(fxy)
	var full := Rect2i(0, 0, block, block)
	for gy in grid:
		for gx in grid:
			img.blit_rect(variants[((gx * 7 + gy * 13 + gx * gy * 5) + 3) % variants.size()], full, Vector2i(gx * block, gy * block))
	img.generate_mipmaps()
	img.save_png("res://assets/textures/terrain_grass.png")

func save_terrain_data() -> void:
	var n := 241
	var half := WORLD_HALF * 2.0
	var step := half * 2.0 / float(n - 1)
	var data: Resource = load("res://scripts/terrain_data.gd").new()
	data.grid_half = half
	data.grid_size = n
	data.heights = PackedFloat32Array()
	data.heights.resize(n * n)
	for gy in n:
		for gx in n:
			var x := -half + float(gx) * step
			var z := -half + float(gy) * step
			data.heights[gy * n + gx] = surface_h(x, z)
	var err := ResourceSaver.save(data, "res://assets/maps/terrain_data.tres")
	print("BAKE data err %d" % err)

func save_terrain_mesh() -> void:
	var n := 241
	var half := WORLD_HALF * 2.0
	var step := half * 2.0 / float(n - 1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	for gy in n:
		for gx in n:
			var x := -half + float(gx) * step
			var z := -half + float(gy) * step
			var e := step
			var dhx := (surface_h(x + e, z) - surface_h(x - e, z)) / (2.0 * e)
			var dhz := (surface_h(x, z + e) - surface_h(x, z - e)) / (2.0 * e)
			verts.append(Vector3(x, surface_h(x, z), z))
			norms.append(Vector3(-dhx, 1.0, -dhz).normalized())
			uvs.append(Vector2(x / 960.0 + 0.5, z / 960.0 + 0.5))
	var idx := PackedInt32Array()
	for gy in n - 1:
		for gx in n - 1:
			var a := n * gy + gx
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var err := ResourceSaver.save(mesh, "res://assets/maps/terrain_mesh.res")
	print("BAKE mesh tris %d err %d" % [idx.size() / 6, err])

func save_material() -> void:
	var text := "[gd_resource type=\"StandardMaterial3D\" load_steps=2 format=3]\n\n"
	text += "[ext_resource type=\"Texture2D\" path=\"res://assets/textures/terrain_grass.png\" id=\"1_grass\"]\n\n"
	text += "[resource]\ncull_mode = 2\nalbedo_color = Color(0.5, 0.68, 0.4, 1)\nalbedo_texture = ExtResource(\"1_grass\")\nuv1_scale = Vector3(90, 90, 90)\ntexture_filter = 2\n"
	var f := FileAccess.open("res://assets/maps/terrain_mat.tres", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("BAKE mat written")

func save_map_scene() -> void:
	var text := ""
	text += "[gd_scene load_steps=6 format=3 uid=\"uid://bswampmap0001\"]\n\n"
	text += "[ext_resource type=\"Mesh\" path=\"res://assets/maps/terrain_mesh.res\" id=\"1_mesh\"]\n"
	text += "[ext_resource type=\"Material\" path=\"res://assets/maps/terrain_mat.tres\" id=\"2_material\"]\n\n"
	text += "[sub_resource type=\"BoxShape3D\" id=\"wall_ns\"]\nsize = Vector3(%s, 16, 0.24)\n\n" % (WORLD_HALF * 2.4)
	text += "[sub_resource type=\"BoxShape3D\" id=\"wall_ew\"]\nsize = Vector3(0.24, 16, %s)\n\n" % (WORLD_HALF * 2.4)
	text += "[sub_resource type=\"BoxShape3D\" id=\"floor_safety\"]\nsize = Vector3(384, 0.08, 384)\n\n"
	text += "[node name=\"Map\" type=\"Node3D\"]\n\n"
	text += "[node name=\"Terrain\" type=\"MeshInstance3D\" parent=\".\"]\n"
	text += "mesh = ExtResource(\"1_mesh\")\n"
	text += "material_override = ExtResource(\"2_material\")\n"
	text += "cast_shadow = 0\n\n"
	text += "[node name=\"SafetyFloor\" type=\"StaticBody3D\" parent=\".\"]\n"
	text += "collision_layer = 1\n\n"
	text += "[node name=\"Shape\" type=\"CollisionShape3D\" parent=\"SafetyFloor\"]\n"
	text += "shape = SubResource(\"floor_safety\")\n"
	text += "position = Vector3(0, -10.4, 0)\n\n"
	var walls := [
		["WallEast", Vector3(WORLD_HALF, 5.8, 0), "wall_ew"],
		["WallWest", Vector3(-WORLD_HALF, 5.8, 0), "wall_ew"],
		["WallSouth", Vector3(0, 5.8, WORLD_HALF), "wall_ns"],
		["WallNorth", Vector3(0, 5.8, -WORLD_HALF), "wall_ns"],
	]
	for w in walls:
		var wp: Vector3 = w[1]
		text += "[node name=\"%s\" type=\"StaticBody3D\" parent=\".\"]\n" % w[0]
		text += "collision_layer = 1\n\n"
		text += "[node name=\"Shape\" type=\"CollisionShape3D\" parent=\"%s\"]\n" % w[0]
		text += "shape = SubResource(\"%s\")\n" % w[2]
		text += "position = Vector3(%s, %s, %s)\n\n" % [wp.x, wp.y, wp.z]
	var f := FileAccess.open("res://scenes/map.tscn", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var check := load("res://scenes/map.tscn") as PackedScene
	var inst := check.instantiate() as Node3D
	print("BAKE map written terrain_mesh %s" % [(inst.get_node("Terrain") as MeshInstance3D).mesh != null])

func _init() -> void:
	make_ground_texture()
	save_terrain_data()
	save_terrain_mesh()
	save_material()
	save_map_scene()
	quit()
