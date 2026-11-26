shader_type sky;
// Sky-shader clouds (Godot 4 sky shader). The cloud map is projected onto a
// virtual plane, so coverage and wind read naturally as the camera looks up.
// Animated in real time by Sky.process_mode = REALTIME.
render_mode use_half_res_pass;

uniform vec4 sky_top : source_color = vec4(0.24, 0.34, 0.46, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.68, 0.70, 0.58, 1.0);
uniform vec4 cloud_tint : source_color = vec4(0.92, 0.94, 0.97, 1.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform vec2 wind = vec2(0.0);
uniform sampler2D cloud_tex : repeat_enable, filter_linear_mipmap;

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(sky_horizon.rgb, sky_top.rgb, pow(up, 0.55)) * brightness;

	// project the dome onto a virtual cloud plane; fade it out at the horizon
	// so the stretched UVs cannot produce stripes
	float horizon = smoothstep(0.02, 0.30, up);
	vec2 uv = dir.xz / max(0.30, up + 0.30) * 0.45 + wind * TIME * 0.004;
	float c = texture(cloud_tex, uv).r;
	float threshold = 0.72 - clamp(coverage, 0.0, 1.0) * 0.42;
	float mask = smoothstep(threshold, threshold + 0.23, c);
	vec3 cloud_col = cloud_tint.rgb * (0.55 + 0.45 * brightness);
	col = mix(col, cloud_col, mask * horizon * clamp(coverage + 0.08, 0.0, 1.0));

	COLOR = col;
}
