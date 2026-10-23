shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color;
uniform vec3 cam_pos = vec3(0.0, 0.0, 0.0);
uniform float tree_far = 150.0;
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);

varying float view_dist;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 dir = cam_pos - origin;
	dir.y = 0.0;
	float l = length(dir);
	dir = l > 0.0001 ? dir / l : vec3(0.0, 0.0, 1.0);
	vec3 right = vec3(dir.z, 0.0, -dir.x);
	mat3 billboard = mat3(right, vec3(0.0, 1.0, 0.0), dir);
	VERTEX = billboard * VERTEX;
	view_dist = l;
}

void fragment() {
	if (view_dist > tree_far) {
		discard;
	}
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * tint.rgb;
	ALPHA = t.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
