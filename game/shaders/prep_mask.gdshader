shader_type spatial;
render_mode cull_disabled;

// Bare-earth pad driven by a paintable mask. The bulldozer stamps `mask_tex`
// as it drives, so only ground it has worked changes. The dirt texture is
// static (no scrolling) and the cut edge is broken up with noise so the
// finished pad does not read as a perfect rectangle.

uniform float min_x = 0.0;
uniform float max_x = 1.0;
uniform float min_z = 0.0;
uniform float max_z = 1.0;
uniform float uv_scale = 0.06;
uniform vec4 dirt : source_color = vec4(0.42, 0.32, 0.21, 1.0);
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_tex : filter_linear, repeat_disable;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float nx = clamp((wpos.x - min_x) / max(max_x - min_x, 0.001), 0.0, 1.0);
	float nz = clamp((wpos.z - min_z) / max(max_z - min_z, 0.001), 0.0, 1.0);
	float m = texture(mask_tex, vec2(nx, nz)).r;

	// ragged, noisy boundary instead of a clean rectangle
	float n = hash(floor(wpos.xz * 2.0));
	float n2 = hash(floor(wpos.xz * 7.0) + 11.0);
	float thr = 0.33 + (n - 0.5) * 0.20 + (n2 - 0.5) * 0.10;
	if (m < thr) {
		discard;
	}

	vec3 base = mix(dirt.rgb, texture(dirt_tex, wpos.xz * uv_scale).rgb, 0.85);
	// dark track ruts left by the machine (green channel of the mask)
	float tread = texture(mask_tex, vec2(nx, nz)).g;
	base *= mix(1.0, 0.76, clamp(tread, 0.0, 1.0));
	// fresh cut earth is a touch lighter right at the work front
	float fresh = 1.0 - smoothstep(0.42, 0.68, m);
	base = mix(base, base * 1.12, fresh * 0.5);
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
