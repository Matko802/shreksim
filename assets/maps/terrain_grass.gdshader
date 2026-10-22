shader_type spatial;

uniform sampler2D grass : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.5, 0.68, 0.4, 1.0);
uniform float cell_size = 0.72;
uniform float variation = 0.08;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 scaled = world_pos.xz / cell_size;
	vec2 cell = floor(scaled);
	vec2 f = scaled - cell;
	float k = floor(hash2(cell) * 4.0);
	float ca = cos(k * 1.5707963);
	float sa = sin(k * 1.5707963);
	vec2 local = f - 0.5;
	vec2 uv = vec2(local.x * ca - local.y * sa, local.x * sa + local.y * ca) + 0.5;
	float lod = log2(max(length(dFdx(scaled)), length(dFdy(scaled))));
	vec3 tile = textureLod(grass, uv, lod).rgb;
	float h00 = hash2(cell);
	float h10 = hash2(cell + vec2(1.0, 0.0));
	float h01 = hash2(cell + vec2(0.0, 1.0));
	float h11 = hash2(cell + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	float bright = 1.0 - variation * mix(mix(h00, h10, u.x), mix(h01, h11, u.x), u.y);
	ALBEDO = tint.rgb * tile * bright;
}
