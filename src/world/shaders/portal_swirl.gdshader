// Demonic vortex filling the portal arch: noise arms wound in polar space,
// a hot core, dark-red body and a glowing rim. The noise texture is seamless,
// so the whole-turn jump in the angle coordinate leaves no seam.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 hot : source_color = vec3(1.0, 0.62, 0.2);
uniform vec3 mid : source_color = vec3(0.95, 0.1, 0.03);
uniform vec3 dark : source_color = vec3(0.16, 0.0, 0.03);
uniform float energy = 3.2;
uniform float spin = 0.16;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x) / 6.2831853;
	float swirl = ang + r * 0.85 - TIME * spin;
	float n = texture(noise_tex, vec2(swirl * 2.0, r * 0.7 - TIME * 0.3)).r;
	float n2 = texture(noise_tex, vec2(swirl * 5.0 + 0.3, r * 1.5 - TIME * 0.55)).r;
	float arms = smoothstep(0.35, 0.78, n * 0.7 + n2 * 0.5);
	float core = 1.0 - smoothstep(0.0, 0.4, r);
	float rim = smoothstep(0.62, 0.97, r);
	vec3 col = mix(dark, mid, arms);
	col = mix(col, hot, clamp(arms * arms * (1.0 - r) + rim * 0.75 * n2, 0.0, 1.0));
	col += hot * core * (0.5 + 0.3 * sin(TIME * 3.0));
	ALBEDO = col * energy;
	ALPHA = smoothstep(1.0, 0.86, r);
}
