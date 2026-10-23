shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords;

uniform sampler2D tex : source_color;
uniform float tree_far = 150.0;
uniform float tree_near = 50.0;
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);

varying float view_dist;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	vec3 dir = to_cam;
	dir.y = 0.0;
	float l = length(dir);
	dir = l > 0.0001 ? dir / l : vec3(0.0, 0.0, 1.0);
	vec3 right = vec3(dir.z, 0.0, -dir.x);
	float w = length(MODEL_MATRIX[0].xyz);
	float h = length(MODEL_MATRIX[1].xyz);
	vec3 local = vec3(UV.x - 0.5, 0.5 - UV.y, 0.0);
	VERTEX = origin + right * (local.x * w) + vec3(0.0, 1.0, 0.0) * (local.y * h);
	view_dist = length(to_cam);
}

void fragment() {
	if (view_dist < tree_near || view_dist > tree_far) {
		discard;
	}
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * tint.rgb;
	ALPHA = t.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
