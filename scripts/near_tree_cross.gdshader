shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float tree_near = 50.0;
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float view_dist = length(CAMERA_POSITION_WORLD - origin);
	if (view_dist > tree_near) {
		VERTEX = vec3(0.0, -100000.0, 0.0);
	}
}

void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * tint.rgb;
	ALPHA = t.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
