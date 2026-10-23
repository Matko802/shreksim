shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color;
uniform float tree_near = 50.0;
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);

varying float view_dist;

void vertex() {
	view_dist = length(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz);
}

void fragment() {
	if (view_dist > tree_near) {
		discard;
	}
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * tint.rgb;
	ALPHA = t.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
