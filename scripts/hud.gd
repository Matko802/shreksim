extends CanvasLayer

@onready var crosshair: TextureRect = %Crosshair
@onready var pages_label: Label = %PagesLabel
@onready var timer_label: Label = %TimerLabel
@onready var prompt_label: Label = %PromptLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var static_overlay: TextureRect = %StaticOverlay
@onready var result_label: Label = %ResultLabel
@onready var run_label: Label = %RunLabel

var _objective_tween: Tween
var _last_prompt := " "
var _last_time := -1
var _last_low := false
var _run_base_pos := Vector2.ZERO
var _run_shake_t := 0.0

func _ready() -> void:
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	static_overlay.modulate = Color(1, 1, 1, 0.0)
	_run_base_pos = run_label.position

func _process(delta: float) -> void:
	if not run_label.visible:
		return
	_run_shake_t += delta
	var amp := 7.0 + 3.0 * sin(_run_shake_t * 17.0)
	run_label.position = _run_base_pos + Vector2(randf_range(-amp, amp), randf_range(-amp, amp))

func show_run() -> void:
	_run_shake_t = 0.0
	run_label.position = _run_base_pos
	run_label.visible = true

func hide_run() -> void:
	run_label.visible = false
	run_label.position = _run_base_pos

func set_pages_text(t: String) -> void:
	pages_label.text = t

func set_timer_visible(v: bool) -> void:
	timer_label.visible = v

func set_time(t: int, low: bool) -> void:
	if t == _last_time and low == _last_low:
		return
	_last_time = t
	_last_low = low
	timer_label.text = str(t)
	timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.25) if low else Color.WHITE)

func set_prompt(t: String) -> void:
	if t == _last_prompt:
		return
	_last_prompt = t
	prompt_label.text = t

func set_crosshair(v: bool) -> void:
	crosshair.visible = v

func show_objective(t: String) -> void:
	objective_label.text = t
	objective_label.modulate = Color(1, 1, 1, 1)
	if _objective_tween != null and _objective_tween.is_valid():
		_objective_tween.kill()
	_objective_tween = create_tween()
	_objective_tween.tween_property(objective_label, "modulate:a", 0.0, 1.2).set_delay(3.0)

func show_static(tex: Texture2D, alpha: float) -> void:
	if static_overlay.texture != tex:
		static_overlay.texture = tex
	if not static_overlay.visible:
		static_overlay.visible = true
	static_overlay.modulate = Color(1, 1, 1, alpha)

func hide_static() -> void:
	if static_overlay.visible:
		static_overlay.visible = false

func show_result(tex: Texture2D, show_click: bool, text: String = "") -> void:
	static_overlay.texture = tex
	static_overlay.modulate = Color(1, 1, 1, 1)
	if not static_overlay.visible:
		static_overlay.visible = true
	if text != "":
		result_label.text = text
	result_label.visible = show_click
