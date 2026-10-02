// Lowland terrain: two painterly grasses broken up by macro noise, with dirt
// roads, sandy riverbanks, tilled fields and scorched blight painted in by
// vertex colour (R road, G bank, B blight, A field). Rock shows on steep hills.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform float grass_scale = 0.16;
uniform vec3 grass_tint : source_color = vec3(1.0);
uniform vec3 meadow_tint : source_color = vec3(1.0);
uniform vec3 field_tint : source_color = vec3(0.75, 0.6, 0.42);
uniform vec3 blight_tint : source_color = vec3(0.32, 0.16, 0.14);

varying vec3 wpos;
varying vec3 wnormal;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec2 p = wpos.xz;
	float m = texture(macro, p * 0.004).r;
	float m2 = texture(macro, p * 0.021 + 0.5).r;
	vec3 ga = texture(grass_a, p * grass_scale).rgb;
	vec3 gb = texture(grass_b, p * grass_scale * 0.71 + 0.37).rgb;
	vec3 col = mix(ga, gb, smoothstep(0.38, 0.62, m)) * grass_tint;
	col *= mix(vec3(1.0), meadow_tint, smoothstep(0.45, 0.75, m2));
	col *= 0.9 + 0.2 * m2;

	vec3 d = texture(dirt, p * 0.2).rgb;
	vec3 s = texture(sand, p * 0.22).rgb;
	float bank = smoothstep(0.25, 0.75, COLOR.g + (m2 - 0.5) * 0.35);
	col = mix(col, s, bank);
	float field = smoothstep(0.3, 0.7, COLOR.a);
	vec3 rows = d * field_tint * (0.8 + 0.2 * sin(p.x * 3.5));
	col = mix(col, rows, field);
	float road = smoothstep(0.3, 0.7, COLOR.r + (m2 - 0.5) * 0.3);
	col = mix(col, d, road);
	col = mix(col, col * blight_tint * 2.2, smoothstep(0.1, 0.9, COLOR.b));

	float steep = smoothstep(0.82, 0.62, wnormal.y);
	vec3 r = texture(rock, p * 0.08 + wpos.y * 0.05).rgb;
	col = mix(col, r, steep);

	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.8, bank);
}
