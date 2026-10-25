shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 fog_color : source_color = vec4(0.72, 0.78, 0.75, 1.0);
uniform float opacity = 0.9;
uniform float wall_height = 30.0;
uniform float seed = 0.0;
uniform float scroll_speed = 0.02;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise2(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp(world_pos.y / wall_height, 0.0, 1.0);
	vec2 flow = vec2(TIME * scroll_speed + seed, -TIME * scroll_speed * 0.35);
	float n = fbm(world_pos.xz * 0.055 + flow);
	float bands = fbm(vec2(world_pos.x + world_pos.z, world_pos.y * 0.12) * 0.16 + flow * 0.6);
	float top = 1.0 - smoothstep(0.62, 1.0, h);
	float bottom = smoothstep(0.0, 0.04, h);
	float body = 0.5 + 0.5 * smoothstep(0.18, 0.72, n * 0.65 + bands * 0.35);
	ALBEDO = fog_color.rgb;
	ALPHA = clamp(opacity * body * top * bottom, 0.0, 1.0);
}
