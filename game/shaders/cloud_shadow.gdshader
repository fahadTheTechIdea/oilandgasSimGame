shader_type spatial;
// Soft cloud shadows for a top-down RTS. A low-opacity dark layer driven by a
// seamless fBm texture that drifts with the wind. Kept subtle so it reads as
// cloud cover, never as a dirty overlay or a white sheet.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float opacity : hint_range(0.0, 1.0) = 0.12;
uniform vec2 wind = vec2(0.0);
uniform float scale = 0.0016;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * scale + wind * TIME * 0.004;
	float n = texture(noise_tex, uv).r;
	float a = smoothstep(0.35, 0.75, n) * opacity;
	ALBEDO = vec3(0.02, 0.03, 0.05);
	ALPHA = a;
}
