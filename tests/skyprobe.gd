extends Node3D

func _ready() -> void:
	print("SKYPROBE ready children=", get_child_count())
	var env := Environment.new()
	var sky_shader := Shader.new()
	sky_shader.code = """
shader_type sky;

uniform sampler2D face : source_color, filter_linear_mipmap;

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 a = vec3(abs(dir.x), abs(dir.y), abs(dir.z));
	vec2 uv;
	if (a.x > a.y && a.x > a.z) {
		uv = vec2(-dir.z, dir.y) / a.x;
	} else if (a.y > a.x && a.y > a.z) {
		uv = vec2(dir.x, -dir.z) / a.y;
	} else {
		uv = vec2(dir.x, dir.y) / a.z;
	}
	COLOR = texture(face, uv * 0.5 + 0.5).rgb;
}
"""
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sky_shader
	sky_mat.set_shader_parameter("face", load("res://assets/images/sky_shrek.png"))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.background_energy_multiplier = 0.2
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.26, 0.2)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.rotation.x = deg_to_rad(-33.0)
	cam.fov = 80.0

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		print("SKY NO CAMERA")
		return
	cam.rotation.x = deg_to_rad(60.0)
	rotation.y += deg_to_rad(15.0)

