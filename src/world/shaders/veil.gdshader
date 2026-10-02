// The gate's glowing blue veil: additive, rising shimmer bands, soft edges.
// `flash` (0..1) is driven by World on every leak.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 color : source_color = vec3(0.3, 0.6, 1.0);
uniform float energy = 1.3;
uniform float flash = 0.0;

void fragment() {
	vec2 uv = UV;
	float h = 1.0 - uv.y;
	float edge = smoothstep(0.0, 0.14, uv.x) * smoothstep(1.0, 0.86, uv.x);
	edge *= smoothstep(1.0, 0.7, h) * smoothstep(0.0, 0.05, h);
	float n = texture(noise_tex, vec2(uv.x * 1.3, uv.y * 0.7 + TIME * 0.22)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 2.7 - TIME * 0.07, uv.y * 1.9 + TIME * 0.45)).r;
	float bands = 0.5 + 0.5 * sin(h * 16.0 - TIME * 2.6 + n * 5.0);
	float a = edge * (0.3 + 0.45 * n * n2 + 0.25 * bands * (1.0 - h * 0.6));
	a *= 1.0 + flash * 3.5;
	ALBEDO = (color * energy + vec3(0.6, 0.8, 1.0) * flash) * a;
}
