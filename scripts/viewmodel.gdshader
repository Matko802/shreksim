shader_type spatial;
render_mode depth_test_disabled, depth_draw_opaque, cull_back, blend_mix;

uniform sampler2D albedo_texture : source_color;

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb;
	ALPHA = texture(albedo_texture, UV).a;
}
