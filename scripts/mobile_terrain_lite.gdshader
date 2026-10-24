shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_lambert,specular_disabled,skip_vertex_transform;

#define MAX_REGIONS 64
#define COLOR_MAP vec4(1.0, 1.0, 1.0, 0.5)
#define DIV_255 0.003921568627450

#define DECODE_BLEND(control) float(control >>14u & 0xFFu) * DIV_255
#define DECODE_AUTO(control) bool(control & 0x1u)
#define DECODE_BASE(control) int(control >>27u & 0x1Fu)
#define DECODE_OVER(control) int(control >>22u & 0x1Fu)
#define DECODE_HOLE(control) bool(control >>2u & 0x1u)

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    #define fma(a, b, c) ((a) * (b) + (c))
    #define dFdxCoarse(a) dFdx(a)
    #define dFdyCoarse(a) dFdy(a)
#endif

group_uniforms private;
uniform vec3 _target_pos = vec3(0.f);
uniform float _mesh_size = 48.f;
uniform uint _background_mode = 1u;
uniform uint _mouse_layer = 0x80000000u;
uniform float _vertex_spacing = 1.0;
uniform float _vertex_density = 1.0;
uniform float _subdiv = 1.0;
uniform float _region_size = 1024.0;
uniform float _region_texel_size = 0.0009765625;
uniform int _region_map_size = 32;
uniform int _region_map[1024];
uniform vec2 _region_locations[MAX_REGIONS];
uniform float _texture_normal_depth_array[32];
uniform float _texture_ao_strength_array[32];
uniform float _texture_ao_affect_array[32];
uniform float _texture_roughness_mod_array[32];
uniform float _texture_uv_scale_array[32];
uniform vec4 _texture_color_array[32];
uniform highp sampler2DArray _height_maps : repeat_disable;
uniform highp sampler2DArray _control_maps : repeat_disable;
uniform highp sampler2DArray _color_maps : source_color, filter_linear_mipmap, repeat_disable;
uniform highp sampler2DArray _texture_array_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform highp sampler2DArray _texture_array_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
group_uniforms;

group_uniforms general_uniforms;
uniform float ground_level : hint_range(-1000., 1000.) = 0.0;
uniform float region_blend : hint_range(.001, 1., 0.001) = 0.25;
uniform bool flat_terrain_normals = false;
uniform bool textures_enabled = true;
uniform float blend_sharpness : hint_range(0, 1) = 0.5;
group_uniforms;

group_uniforms auto_shader;
uniform float auto_slope : hint_range(0, 10) = 1.0;
uniform float auto_height_reduction : hint_range(0, 1) = 0.1;
uniform int auto_base_texture : hint_range(0, 31) = 0;
uniform int auto_overlay_texture : hint_range(0, 31) = 1;
group_uniforms;

group_uniforms macro_variation;
uniform bool macro_variation_enabled = true;
uniform vec3 macro_variation1 : source_color = vec3(1.);
uniform vec3 macro_variation2 : source_color = vec3(1.);
uniform float macro_variation_slope : hint_range(0., 1.)  = 0.333;
uniform highp sampler2D noise_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float noise1_scale : hint_range(0.001, 1.) = 0.04;
uniform float noise1_angle : hint_range(0, 6.283) = 0.;
uniform vec2 noise1_offset = vec2(0.5);
uniform float noise2_scale : hint_range(0.001, 1.) = 0.076;
group_uniforms;

varying vec3 v_vertex;
varying vec3 v_normal;

ivec3 get_index_coord(const vec2 uv) {
	vec2 r_uv = round(uv);
	ivec2 pos = ivec2(floor(r_uv * _region_texel_size)) + (_region_map_size / 2);
	int bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
	int map_val = _region_map[pos.y * _region_map_size + pos.x];
	int raw_index = map_val - 1;

	int is_region = bounds * int(raw_index >= 0) * int(raw_index < MAX_REGIONS);

	int is_dummy = bounds * int(map_val < 0);
	int layer_index = is_region * raw_index
	               + is_dummy * (map_val - 1)
	               - (1 - is_region - is_dummy);
	return ivec3(ivec2(mod(r_uv, _region_size)), layer_index);
}

vec3 get_index_uv(const vec2 uv2) {
	ivec2 pos = ivec2(floor(uv2)) + (_region_map_size / 2);
	int bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
	int map_val = _region_map[pos.y * _region_map_size + pos.x];
	int raw_index = map_val - 1;
	int is_region = bounds * int(raw_index >= 0) * int(raw_index < MAX_REGIONS);
	int is_dummy = bounds * int(map_val < 0);
	int layer_index = is_region * raw_index
	               + is_dummy * (map_val - 1)
	               - (1 - is_region - is_dummy);
	return vec3(uv2 - _region_locations[layer_index], float(layer_index));
}

bool is_none_bg(const vec2 uv) {
	ivec4 regions = ivec4(
		get_index_coord(uv - vec2(0.5, 0.0)).z,
		get_index_coord(uv - vec2(0.0, 0.5)).z,
		get_index_coord(uv + vec2(1.0, 0.0)).z,
		get_index_coord(uv + vec2(0.0, 1.0)).z);
	return any(equal(regions, ivec4(-1)));
}

float check_region(const vec2 uv2) {
	ivec2 pos = ivec2(floor(uv2)) + (_region_map_size / 2);
    int bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
    int raw_index = _region_map[pos.y * _region_map_size + pos.x] - 1;
    int is_valid = bounds * int(raw_index >= 0) * int(raw_index < MAX_REGIONS);
	return float(is_valid);
}

float get_region_blend(vec2 uv2) {
	uv2 -= 0.5011;
	const vec2 offset = vec2(0.0, 1.0);
	float a = check_region(uv2 + offset.xy);
	float b = check_region(uv2 + offset.yy);
	float c = check_region(uv2 + offset.yx);
	float d = check_region(uv2 + offset.xx);
	vec2 blend_factor = vec2(2.0 + 126.0 * (1.0 - region_blend));
	vec2 f = fract(uv2);
	vec2 w = 1.0 / (1.0 + exp(blend_factor * log((1.0 - f) / f)));
	float blend = mix(mix(d, c, w.x), mix(a, b, w.x), w.y);
	return (1.0 - blend) * 2.0;
}

float interpolated_height(vec2 pos) {
	const vec2 offsets = vec2(0, 1);
	vec2 index_id = floor(pos);
	ivec3 index[4];
	index[0] = get_index_coord(index_id + offsets.xy);
	index[1] = get_index_coord(index_id + offsets.yy);
	index[2] = get_index_coord(index_id + offsets.yx);
	index[3] = get_index_coord(index_id + offsets.xx);
	float h0 = texelFetch(_height_maps, index[0], 0).r;
	float h1 = texelFetch(_height_maps, index[1], 0).r;
	float h2 = texelFetch(_height_maps, index[2], 0).r;
	float h3 = texelFetch(_height_maps, index[3], 0).r;
	vec2 f = fract(pos);
	vec2 i = 1.0 - f;
	vec4 w = vec4(i.x * f.y, f.x * f.y, f.x * i.y, i.x * i.y);
	float h = h0 * w[0] + h1 * w[1] + h2 * w[2] + h3 * w[3];
	return h;
}

void vertex() {


	vec3 render_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_vertex = render_pos;


	float scale = MODEL_MATRIX[0][0];
	float inv_scale = 1.0 / scale;
	float max_xz = max(abs(render_pos.x - _target_pos.x), abs(render_pos.z - _target_pos.z));
	float vertex_lerp = smoothstep(0.0, 1.0, (max_xz * inv_scale - _mesh_size - 4.0) / (_mesh_size - 4.0));
	vec2 vertex_fract = fract(VERTEX.xz * 0.5) * 2.0;

	vec2 shift = (scale < _vertex_spacing / _subdiv + 1e-6) ?

		mix(vertex_fract, vec2(vertex_fract.x, -vertex_fract.y),
			round(fract(round(mod(render_pos.z * inv_scale, 4.0)) *
			round(mod(render_pos.x * inv_scale, 4.0)) * 0.25))) :

		vertex_fract * round((fract(render_pos.xz * 0.25 * inv_scale) - 0.5) * 4.0);
	vec2 start_pos = v_vertex.xz * _vertex_density;
	vec2 end_pos = (v_vertex.xz - shift * scale) * _vertex_density;
	v_vertex.xz -= shift * scale * vertex_lerp;

	UV = v_vertex.xz * _vertex_density;

	UV2 = fma(UV, vec2(_region_texel_size), vec2(0.5 * _region_texel_size));

	ivec3 v_region = get_index_coord(start_pos);
	uint control = floatBitsToUint(texelFetch(_control_maps, v_region, 0)).r;
	bool hole = DECODE_HOLE(control);

	if ( !(CAMERA_VISIBLE_LAYERS == _mouse_layer) &&
			(hole || (_background_mode == 0u && is_none_bg(UV)))) {
		v_vertex.x = 0. / 0.;
	} else {

		float h, u, v;

		if (scale < _vertex_spacing) {
			h = interpolated_height(UV);
			u = interpolated_height(UV + vec2(1, 0));
			v = interpolated_height(UV + vec2(0, 1));
		} else {
			ivec3 coord_a = get_index_coord(start_pos);
			ivec3 coord_b = get_index_coord(end_pos);
			ivec3 coord_ua = get_index_coord(start_pos + vec2(1, 0));
			ivec3 coord_ub = get_index_coord(end_pos + vec2(1, 0));
			ivec3 coord_va = get_index_coord(start_pos + vec2(0, 1));
			ivec3 coord_vb = get_index_coord(end_pos + vec2(0, 1));
			h = mix(texelFetch(_height_maps, coord_a, 0).r, texelFetch(_height_maps, coord_b, 0).r, vertex_lerp);
			u = mix(texelFetch(_height_maps, coord_ua, 0).r, texelFetch(_height_maps, coord_ub, 0).r, vertex_lerp);
			v = mix(texelFetch(_height_maps, coord_va, 0).r, texelFetch(_height_maps, coord_vb, 0).r, vertex_lerp);
		}

		vec2 ruv = UV * _region_texel_size;
		h = mix(h, ground_level, smoothstep(0.0, 1.0, get_region_blend(ruv)));
		u = mix(u, ground_level, smoothstep(0.0, 1.0, get_region_blend(ruv + vec2(_region_texel_size, 0.0))));
		v = mix(v, ground_level, smoothstep(0.0, 1.0, get_region_blend(ruv + vec2(0.0, _region_texel_size))));

		v_vertex.y = h;
		v_normal = normalize(vec3(h - u, _vertex_spacing, h - v));
	}

	VERTEX = (VIEW_MATRIX * vec4(v_vertex, 1.0)).xyz;

	NORMAL = normalize((VIEW_MATRIX * vec4(v_normal, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV;
	vec2 uv2 = UV2;
	vec3 region_uv = get_index_uv(uv2);
	vec4 color_map = region_uv.z > -1.0 ? texture(_color_maps, region_uv) : COLOR_MAP;

	vec2 index_id = floor(uv);
	vec2 f = fract(uv);
	vec2 inv = 1.0 - f;
	vec4 weights = vec4(inv.x * f.y, f.x * f.y, f.x * inv.y, inv.x * inv.y);
	uvec4 control = uvec4(
		floatBitsToUint(texelFetch(_control_maps, get_index_coord(index_id + vec2(0.0, 1.0)), 0).r),
		floatBitsToUint(texelFetch(_control_maps, get_index_coord(index_id + vec2(1.0, 1.0)), 0).r),
		floatBitsToUint(texelFetch(_control_maps, get_index_coord(index_id + vec2(1.0, 0.0)), 0).r),
		floatBitsToUint(texelFetch(_control_maps, get_index_coord(index_id + vec2(0.0, 0.0)), 0).r));
	vec4 blends = vec4(control >> uvec4(14u) & uvec4(0xFFu)) * DIV_255;
	float blend = smoothstep(0.4, 0.6, dot(blends, weights));
	int ci = 0;
	float mw = weights.x;
	if (weights.y > mw) { ci = 1; mw = weights.y; }
	if (weights.z > mw) { ci = 2; mw = weights.z; }
	if (weights.w > mw) { ci = 3; }
	uint center = control[ci];
	int base_id = int(center >> 27u & 0x1Fu);
	int over_id = int(center >> 22u & 0x1Fu);

	vec2 world_uv = v_vertex.xz;
	vec2 base_uv = fma(world_uv, vec2(_texture_uv_scale_array[base_id] * 0.5), vec2(0.5));
	vec2 over_uv = fma(world_uv, vec2(_texture_uv_scale_array[over_id] * 0.5), vec2(0.5));
	vec4 base_alb = texture(_texture_array_albedo, vec3(base_uv, float(base_id)));
	vec4 over_alb = texture(_texture_array_albedo, vec3(over_uv, float(over_id)));
	vec4 alb = mix(base_alb, over_alb, blend);
	vec3 tint = mix(_texture_color_array[base_id].rgb, _texture_color_array[over_id].rgb, blend);
	ALBEDO = alb.rgb * tint * color_map.rgb;
	ROUGHNESS = clamp(fma(color_map.a - 0.5, 2.0, 0.7), 0.0, 1.0);
	SPECULAR = 0.0;
}
