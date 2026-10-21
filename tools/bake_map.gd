extends SceneTree

const WORLD_HALF := 3200.0
const TOWER_SCALE := 800.0
const GRASS_BLOCKS := [
	"res://assets/textures/godotcraft/grass_top.png",
]
const LOOKOUT_SPOTS := [[Vector2(1060, 140), 187.0], [Vector2(-1140, 1080), 317.0], [Vector2(1620, -1130), 145.0], [Vector2(60, -1090), 93.0]]

func terrain_h(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	var edge := clampf((WORLD_HALF - dist) / 900.0, 0.0, 1.0)
	var spawn := clampf((dist - 240.0) / 400.0, 0.0, 1.0)
	var tops := sin(x * 0.0012 + 1.7) * cos(z * 0.0009 - 2.3) * 95.0
	var ridge := sin(dist * 0.0011 + 1.3) * 55.0
	var mids := sin((x + z) * 0.0016 - 0.8) * 32.0
	var bumps := sin(x * 0.0041) * cos(z * 0.0043) * 8.0
	return (tops + ridge + mids + bumps) * edge * spawn

func apron_h(x: float, z: float) -> float:
	var out := clampf((maxf(absf(x), absf(z)) - WORLD_HALF) / 1800.0, 0.0, 1.0)
	var tops := sin(x * 0.0012 + 1.7) * cos(z * 0.0009 - 2.3) * 60.0
	var mids := sin((x + z) * 0.0016 - 0.8) * 20.0
	var bumps := sin(x * 0.0041) * cos(z * 0.0043) * 8.0
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
	for tex_path in GRASS_BLOCKS:
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
			uvs.append(Vector2(x / 24000.0 + 0.5, z / 24000.0 + 0.5))
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

func save_terrain_collision() -> void:
	var mesh := load("res://assets/maps/terrain_mesh.res") as ArrayMesh
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	var err := ResourceSaver.save(shape, "res://assets/maps/terrain_collision.res")
	print("BAKE shape err %d" % err)

func save_material() -> void:
	var text := "[gd_resource type=\"StandardMaterial3D\" load_steps=2 format=3]\n\n"
	text += "[ext_resource type=\"Texture2D\" path=\"res://assets/textures/terrain_grass.png\" id=\"1_grass\"]\n\n"
	text += "[resource]\ncull_mode = 2\nalbedo_color = Color(0.5, 0.68, 0.4, 1)\nalbedo_texture = ExtResource(\"1_grass\")\nuv1_scale = Vector3(90, 90, 90)\ntexture_filter = 2\n"
	var f := FileAccess.open("res://assets/maps/terrain_mat.tres", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("BAKE mat written")

func tf_string(b: Basis, origin: Vector3) -> String:
	return "Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)" % [b[0][0], b[0][1], b[0][2], b[1][0], b[1][1], b[1][2], b[2][0], b[2][1], b[2][2], origin.x, origin.y, origin.z]

func save_map_scene() -> void:
	var ids := {
		mesh = "1_mesh",
		material = "2_material",
		shape = "3_shape",
		tower = "4_tower",
	}
	var text := ""
	text += "[gd_scene load_steps=9 format=3 uid=\"uid://bswampmap0001\"]\n\n"
	text += "[ext_resource type=\"Mesh\" path=\"res://assets/maps/terrain_mesh.res\" id=\"%s\"]\n" % ids.mesh
	text += "[ext_resource type=\"Material\" path=\"res://assets/maps/terrain_mat.tres\" id=\"%s\"]\n" % ids.material
	text += "[ext_resource type=\"Shape3D\" path=\"res://assets/maps/terrain_collision.res\" id=\"%s\"]\n" % ids.shape
	text += "[ext_resource type=\"PackedScene\" path=\"res://assets/models/watchtower.glb\" id=\"%s\"]\n\n" % ids.tower
	text += "[sub_resource type=\"BoxShape3D\" id=\"wall_ns\"]\nsize = Vector3(%s, 400, 6)\n\n" % (WORLD_HALF * 2.4)
	text += "[sub_resource type=\"BoxShape3D\" id=\"wall_ew\"]\nsize = Vector3(6, 400, %s)\n\n" % (WORLD_HALF * 2.4)
	text += "[sub_resource type=\"BoxShape3D\" id=\"floor_safety\"]\nsize = Vector3(9600, 2, 9600)\n\n"
	text += "[sub_resource type=\"BoxShape3D\" id=\"shaft_box\"]\nsize = Vector3(%s, %s, %s)\n\n" % [0.45 * TOWER_SCALE, 0.45 * TOWER_SCALE, 0.50 * TOWER_SCALE]
	text += "[sub_resource type=\"BoxShape3D\" id=\"deck_box\"]\nsize = Vector3(%s, %s, %s)\n\n" % [0.60 * TOWER_SCALE, 0.03 * TOWER_SCALE, 0.60 * TOWER_SCALE]
	text += "[sub_resource type=\"BoxShape3D\" id=\"rail_side\"]\nsize = Vector3(%s, %s, %s)\n\n" % [0.02 * TOWER_SCALE, 0.05 * TOWER_SCALE, 0.60 * TOWER_SCALE]
	text += "[sub_resource type=\"BoxShape3D\" id=\"rail_back\"]\nsize = Vector3(%s, %s, %s)\n\n" % [0.60 * TOWER_SCALE, 0.05 * TOWER_SCALE, 0.02 * TOWER_SCALE]
	text += "[sub_resource type=\"BoxShape3D\" id=\"ramp_box\"]\nsize = Vector3(%s, %s, %s)\n\n" % [0.05 * TOWER_SCALE, 0.04 * TOWER_SCALE, 0.785 * TOWER_SCALE]
	text += "[node name=\"Map\" type=\"Node3D\"]\n\n"
	text += "[node name=\"Terrain\" type=\"MeshInstance3D\" parent=\".\"]\n"
	text += "mesh = ExtResource(\"%s\")\n" % ids.mesh
	text += "material_override = ExtResource(\"%s\")\n" % ids.material
	text += "cast_shadow = 0\n\n"
	text += "[node name=\"Boundary\" type=\"StaticBody3D\" parent=\"Terrain\"]\n"
	text += "collision_layer = 1\n\n"
	text += "[node name=\"TerrainShape\" type=\"CollisionShape3D\" parent=\"Terrain/Boundary\"]\n"
	text += "shape = ExtResource(\"%s\")\n\n" % ids.shape
	text += "[node name=\"SafetyFloor\" type=\"StaticBody3D\" parent=\".\"]\n"
	text += "collision_layer = 1\n\n"
	text += "[node name=\"Shape\" type=\"CollisionShape3D\" parent=\"SafetyFloor\"]\n"
	text += "shape = SubResource(\"floor_safety\")\n"
	text += "position = Vector3(0, -260, 0)\n\n"
	var walls := [
		["WallEast", Vector3(WORLD_HALF, 145, 0), "wall_ew"],
		["WallWest", Vector3(-WORLD_HALF, 145, 0), "wall_ew"],
		["WallSouth", Vector3(0, 145, WORLD_HALF), "wall_ns"],
		["WallNorth", Vector3(0, 145, -WORLD_HALF), "wall_ns"],
	]
	for w in walls:
		var wp: Vector3 = w[1]
		text += "[node name=\"%s\" type=\"StaticBody3D\" parent=\".\"]\n" % w[0]
		text += "collision_layer = 1\n\n"
		text += "[node name=\"Shape\" type=\"CollisionShape3D\" parent=\"%s\"]\n" % w[0]
		text += "shape = SubResource(\"%s\")\n" % w[2]
		text += "position = Vector3(%s, %s, %s)\n\n" % [wp.x, wp.y, wp.z]
	var li := 1
	for entry in LOOKOUT_SPOTS:
		var base: Vector2 = entry[0]
		var facing: float = entry[1]
		var gh := terrain_h(base.x, base.y)
		var yaw := Basis(Vector3(0, 1, 0), deg_to_rad(facing))
		var ramp_basis := Basis(Vector3(1, 0, 0), deg_to_rad(35.0))
		text += "[node name=\"Lookout%d\" type=\"StaticBody3D\" parent=\".\"]\n" % li
		text += "collision_layer = 1\n"
		text += "transform = %s\n\n" % tf_string(yaw, Vector3(base.x, 0.0, base.y))
		text += "[node name=\"Tower\" parent=\"Lookout%d\" instance=ExtResource(\"%s\")]\n" % [li, ids.tower]
		text += "transform = %s\n\n" % tf_string(Basis.from_scale(Vector3(TOWER_SCALE, TOWER_SCALE, TOWER_SCALE)), Vector3(0, gh, 0))
		text += "[node name=\"Shaft\" type=\"CollisionShape3D\" parent=\"Lookout%d\"]\n" % li
		text += "shape = SubResource(\"shaft_box\")\n"
		text += "position = Vector3(0, %s, %s)\n\n" % [gh + 0.225 * TOWER_SCALE, 0.02 * TOWER_SCALE]
		text += "[node name=\"Deck\" type=\"CollisionShape3D\" parent=\"Lookout%d\"]\n" % li
		text += "shape = SubResource(\"deck_box\")\n"
		text += "position = Vector3(0, %s, %s)\n\n" % [gh + 0.435 * TOWER_SCALE, 0.02 * TOWER_SCALE]
		text += "[node name=\"RailEast\" type=\"CollisionShape3D\" parent=\"Lookout%d\"]\n" % li
		text += "shape = SubResource(\"rail_side\")\n"
		text += "position = Vector3(%s, %s, %s)\n\n" % [0.28 * TOWER_SCALE, gh + 0.475 * TOWER_SCALE, 0.02 * TOWER_SCALE]
		text += "[node name=\"RailWest\" type=\"CollisionShape3D\" parent=\"Lookout%d\"]\n" % li
		text += "shape = SubResource(\"rail_side\")\n"
		text += "position = Vector3(%s, %s, %s)\n\n" % [-0.28 * TOWER_SCALE, gh + 0.475 * TOWER_SCALE, 0.02 * TOWER_SCALE]
		text += "[node name=\"RailBack\" type=\"CollisionShape3D\" parent=\"Lookout%d\"]\n" % li
		text += "shape = SubResource(\"rail_back\")\n"
		text += "position = Vector3(0, %s, %s)\n\n" % [gh + 0.475 * TOWER_SCALE, -0.26 * TOWER_SCALE]
		text += "[node name=\"Ramp\" type=\"CollisionShape3D\" parent=\"Lookout%d\"]\n" % li
		text += "shape = SubResource(\"ramp_box\")\n"
		text += "transform = %s\n\n" % tf_string(ramp_basis, Vector3(0, gh + 0.225 * TOWER_SCALE, 0.641 * TOWER_SCALE))
		li += 1
	var f := FileAccess.open("res://scenes/map.tscn", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var check := load("res://scenes/map.tscn") as PackedScene
	var inst := check.instantiate() as Node3D
	var towers := 0
	for c in inst.get_children():
		if c is StaticBody3D and c.name.begins_with("Lookout"):
			towers += 1
	print("BAKE map towers %d terrain_mesh %s" % [towers, (inst.get_node("Terrain") as MeshInstance3D).mesh != null])

func _init() -> void:
	make_ground_texture()
	save_terrain_data()
	save_terrain_mesh()
	save_terrain_collision()
	save_material()
	save_map_scene()
	quit()
