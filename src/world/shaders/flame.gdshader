// Torch / brazier flame: a Y-axis billboard quad with a flickering noise
// flame, additive and HDR so it blooms.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 hot : source_color = vec3(1.0, 0.78, 0.35);
uniform vec3 cool : source_color = vec3(1.0, 0.28, 0.05);
uniform float energy = 4.0;

varying float phase;

void vertex() {
	phase = dot(MODEL_MATRIX[3].xyz, vec3(0.71, 0.37, 0.53));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float h = 1.0 - UV.y;
	float n = texture(noise_tex, vec2(UV.x * 1.1 + phase, UV.y * 0.8 + TIME * 1.7)).r;
	float width = (1.0 - h) * 0.4 + 0.05;
	float d = abs(UV.x - 0.5 + (n - 0.5) * 0.3 * h);
	float shape = smoothstep(width, width * 0.35, d);
	shape *= smoothstep(1.0, 0.5, h + n * 0.4) * smoothstep(0.0, 0.1, h);
	vec3 col = mix(cool, hot, smoothstep(0.25, 0.85, shape * (1.0 - h * 0.7)));
	ALBEDO = col * shape * energy * (0.85 + 0.15 * sin(TIME * 17.0 + phase * 9.0));
}
