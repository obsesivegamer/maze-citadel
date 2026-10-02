// River surface on a ribbon mesh: UV.x runs bank to bank (0..1), UV.y is
// metres downstream. Two scrolling ripple normal maps give the flow; low
// roughness picks up sun glints and sky; foam hugs the banks.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.04, 0.22, 0.4);
uniform vec3 shallow_color : source_color = vec3(0.12, 0.5, 0.58);
uniform vec3 foam_color : source_color = vec3(0.86, 0.94, 0.96);
uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform float flow_speed = 0.9;
uniform float width = 9.2;
uniform float roughness = 0.04;

void fragment() {
	vec2 uv = vec2(UV.x * width, UV.y);
	vec2 a = uv * 0.08 + vec2(0.0, -TIME * flow_speed * 0.08);
	vec2 b = uv * vec2(0.17, 0.13) + vec2(0.31, -TIME * flow_speed * 0.15);
	NORMAL_MAP = mix(texture(ripple, a).rgb, texture(ripple, b).rgb, 0.5);
	NORMAL_MAP_DEPTH = 0.7;

	float edge = abs(UV.x - 0.5) * 2.0;
	vec3 col = mix(deep_color, shallow_color, smoothstep(0.25, 1.0, edge));
	float n = texture(foam_noise, uv * vec2(0.25, 0.12) + vec2(0.0, -TIME * flow_speed * 0.12)).r;
	float foam = smoothstep(0.8, 0.98, edge + (n - 0.5) * 0.35);
	float s = texture(foam_noise, vec2(uv.x * 0.35, uv.y * 0.04 - TIME * flow_speed * 0.05)).r;
	float streak = smoothstep(0.66, 0.82, s) * 0.3;
	float f = max(foam, streak);
	ALBEDO = mix(col, foam_color, f);
	ROUGHNESS = mix(roughness, 0.55, f);
	SPECULAR = 0.65;
}
