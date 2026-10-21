extends SceneTree

func _init() -> void:
	var nav: Object = load("res://scripts/enemy_nav.gd").new()
	nav.build(PackedFloat32Array([10.0]), PackedFloat32Array([10.0]), PackedFloat32Array([1.0]))
	print("origin free=", nav.is_free_point(Vector2(0, 0)))
	print("goal free=", nav.is_free_point(Vector2(40, 40)))
	var path: PackedVector2Array = nav.find_path(Vector2(0, 0), Vector2(40, 40))
	print("path size=", path.size())
	if path.size() > 0:
		print("first=", path[0], " last=", path[path.size() - 1])
	var los: bool = nav.has_los(Vector2(0, 0), Vector2(40, 40))
	print("los=", los)
	quit(0)
