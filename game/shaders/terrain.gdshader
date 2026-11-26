shader_type spatial;
render_mode cull_back;

// Terrain material: two world-space samples of the same ground texture at very
// different scales kill the visible tiling, and the mesh vertex colour tints
// low/high ground. No UV layout required.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float macro_scale = 0.045;
uniform float detail_scale = 0.33;
uniform float detail_mix = 0.38;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz;
	vec3 macro = texture(albedo_tex, uv * macro_scale).rgb;
	vec3 detail = texture(albedo_tex, uv * detail_scale).rgb;
	vec3 col = mix(macro, macro * detail * 1.25, detail_mix);
	col *= COLOR.rgb;
	ALBEDO = col * tint;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
