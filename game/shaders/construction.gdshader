shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

// C&C-style construction: the unbuilt part of the structure is a flickering
// hologram; it materialises from the ground up behind a bright scan line.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float base_y = 0.0;
uniform float build_height = 8.0;
uniform vec4 ghost : source_color = vec4(0.35, 0.78, 0.95, 1.0);
uniform vec4 solid : source_color = vec4(0.56, 0.60, 0.64, 1.0);
uniform vec4 scan : source_color = vec4(0.80, 1.0, 1.0, 1.0);

varying float wy;

void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float t = clamp((wy - base_y) / max(build_height, 0.001), 0.0, 1.0);
	float edge = 1.0 - smoothstep(0.0, 0.06, progress - t);
	if (t > progress) {
		// hologram: see-through, pulsing cyan
		float flick = 0.14 + 0.05 * sin(TIME * 7.0 + wy * 2.5);
		ALBEDO = ghost.rgb;
		EMISSION = ghost.rgb * 0.7;
		ALPHA = flick;
	} else {
		ALBEDO = mix(solid.rgb, scan.rgb, edge);
		EMISSION = scan.rgb * edge * 1.6;
		ALPHA = 1.0;
	}
	ROUGHNESS = 0.55;
	METALLIC = 0.15;
}
