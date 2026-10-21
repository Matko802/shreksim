shader_type spatial;

uniform sampler2D grass : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.5, 0.68, 0.4, 1.0);
uniform float cell_size = 0.72;
uniform float variation = 0.12;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 scaled = world_pos.xz / cell_size;
	vec2 cell = floor(scaled);
	float angle = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453) * 6.28318530718;
	vec2 local = scaled - cell - 0.5;
	float s = sin(angle);
	float c = cos(angle);
	vec2 rotated = vec2(local.x * c - local.y * s, local.x * s + local.y * c) + 0.5;
	float brightness = 1.0 - variation * fract(sin(dot(cell + 0.5, vec2(269.5, 183.3))) * 43758.5453);
	vec3 tile = texture(grass, rotated).rgb * brightness;
	ALBEDO = tint.rgb * tile;
}
