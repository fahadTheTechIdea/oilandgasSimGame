shader_type canvas_item;
// Screen-space precipitation built from real rain/snow textures. The textures
// are white-on-black, so the red channel is density. Two scrolling layers give
// depth without the harsh procedural dashes. Cloud shadows are handled by the
// world-anchored shadow plane, not here.
render_mode unshaded, blend_mix;

uniform sampler2D rain_tex : repeat_enable, filter_linear_mipmap;
uniform float rain = 0.0;
uniform float snow = 0.0;
uniform float cloud = 0.0;
uniform vec2 wind = vec2(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec4 col = vec4(0.02, 0.03, 0.05, cloud * 0.02);

	if (rain > 0.01) {
		vec2 ruv = uv;
		ruv.x += uv.y * 0.22;
		ruv.x -= wind.x * TIME * 0.003;
		ruv.y -= TIME * 0.55;
		float r1 = texture(rain_tex, ruv).r;
		float r2 = texture(rain_tex, ruv * 1.7 + vec2(0.31, 0.47)).r;
		float streak = clamp(r1 * 0.75 + r2 * 0.45, 0.0, 1.0);
		col.rgb = mix(col.rgb, vec3(0.62, 0.74, 0.90), streak);
		col.a = max(col.a, streak * clamp(rain, 0.0, 1.6) * 0.30);
	}

	if (snow > 0.01) {
		// two layers of very small dots falling downward
		for (int layer = 0; layer < 2; layer++) {
			float sc = layer == 0 ? 1.0 : 1.7;
			vec2 suv = uv * sc;
			suv.x += sin(uv.y * 8.0 + TIME * 0.6) * 0.004 + wind.x * TIME * 0.0015;
			suv.y -= TIME * (0.12 + float(layer) * 0.05);
			vec2 g = suv * vec2(110.0, 70.0);
			vec2 id = floor(g);
			vec2 f = fract(g) - 0.5;
			float h = hash(id + float(layer) * 19.0);
			f.x += sin(TIME * (0.8 + h) + h * 6.283) * 0.12;
			float r = 0.08 + h * 0.05;
			float flake = smoothstep(r, r * 0.2, length(f));
			float on = step(0.86, h);
			float a = flake * on * clamp(snow, 0.0, 1.0) * (layer == 0 ? 0.55 : 0.30);
			col.rgb = mix(col.rgb, vec3(1.0), flake * on);
			col.a = max(col.a, a);
		}
		col.rgb = mix(col.rgb, vec3(0.94, 0.96, 1.0), snow * 0.10);
		col.a = max(col.a, snow * 0.012);
	}

	COLOR = col;
}
