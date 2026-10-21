extends Resource
class_name FootstepSurfaces

@export var surfaces: Array[SurfaceEntry] = []

func get_random_sound(surface_name: StringName) -> AudioStream:
	if surface_name == &"":
		return null
	for entry: SurfaceEntry in surfaces:
		if entry.name == surface_name:
			if entry.sounds.is_empty():
				return null
			return entry.sounds[randi() % entry.sounds.size()]
	return null
