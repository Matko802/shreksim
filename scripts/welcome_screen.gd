extends Control

@onready var logo: TextureRect = $Logo

const WELCOME_FPS := 60

func _ready() -> void:
	Engine.max_fps = WELCOME_FPS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	logo.modulate.a = 0.0
	logo.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(logo, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(logo, "scale", Vector2.ONE, 0.8).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.tween_interval(3.4)
	tween.chain()
	tween.tween_property(logo, "modulate:a", 0.0, 0.8)
	tween.chain()
	tween.tween_callback(_transition_to_menu)

func _input(event: InputEvent) -> void:
	if event.is_pressed():
		_transition_to_menu()

func _transition_to_menu() -> void:
	if not is_queued_for_deletion():
		Engine.max_fps = 0 if SettingsBus.fps_limit <= 0 or SettingsBus.fps_limit >= 360 else SettingsBus.fps_limit
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
