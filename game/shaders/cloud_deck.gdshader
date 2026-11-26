shader_type spatial;
// Textured cloud / shadow / dusting layer. The cloud map is white-on-black, so
// the red channel is cloud density. The layer is world-anchored and scrolls
// with the wind, so puffs visibly drift across the lease.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D cloud_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.5;
uniform float coverage : hint_range(0.0, 1.0) = 0.5;
uniform vec2 wind = vec2(0.0);
uniform float scale = 0.004;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * scale + wind * TIME * 0.010;
	float n = texture(cloud_tex, uv).r;
	// coverage lowers the threshold, but the layer stays patchy
	float threshold = mix(0.72, 0.30, clamp(coverage, 0.0, 1.0));
	float a = smoothstep(threshold, threshold + 0.22, n);
	ALBEDO = tint.rgb;
	ALPHA = a * opacity;
}
