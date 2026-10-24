extends Node

var rect: ColorRect
var mat: ShaderMaterial
var frames := 0
var last_usec := 0
var elapsed := 0.0

func _ready() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
const int iterations = 4000;
void fragment() {
	vec2 p = UV;
	float v = 0.0;
	for (int i = 0; i < iterations; i++) {
		p = fract(p * 1.0001 + vec2(0.0013, 0.0017));
		v += sin(p.x * 12.9898 + p.y * 78.233 + float(i));
	}
	COLOR = vec4(vec3(abs(v) * 0.0001), 1.0);
}
"""
	mat = ShaderMaterial.new()
	mat.shader = shader
	rect = ColorRect.new()
	rect.material = mat
	rect.position = Vector2.ZERO
	rect.size = get_viewport().get_visible_rect().size
	add_child(rect)
	last_usec = Time.get_ticks_usec()
	print("GPU BENCH start")

func _process(delta: float) -> void:
	frames += 1
	elapsed += delta
	if elapsed >= 1.0:
		var now := Time.get_ticks_usec()
		var wall := float(now - last_usec) / 1000000.0
		print("GPU BENCH engine_fps=%d wall_fps=%.1f frames=%d elapsed=%.2f proc=%.2f" % [Engine.get_frames_per_second(), frames / wall, frames, elapsed, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		frames = 0
		elapsed = 0.0
		last_usec = now
