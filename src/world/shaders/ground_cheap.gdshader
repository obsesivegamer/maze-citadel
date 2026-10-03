// ground.gdshader with fewer texture reads, for the terrain-cheap performance
// switch (PerfFlags); the look is the same. The second grass is read only
// where the two grasses blend, and sand, dirt and rock only where their masks
// are non-zero. Sampling takes gradients from before any branch, so mip
// selection stays right on pixels next to a mask edge. With macro_from_uv the
// coarse macro noise comes per vertex in UV.x (WorldTerrain bakes it), which
// shifts the grass blend edges slightly.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform bool macro_from_uv = false;
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
	vec3 wdx = dFdx(wpos);
	vec3 wdy = dFdy(wpos);
	float m;
	if (macro_from_uv) {
		m = UV.x;
	} else {
		m = texture(macro, p * 0.004).r;
	}
	float m2 = texture(macro, p * 0.021 + 0.5).r;
	float blend = smoothstep(0.38, 0.62, m);
	float sa = grass_scale;
	float sb = grass_scale * 0.71;
	vec3 col;
	if (blend <= 0.0) {
		col = textureGrad(grass_a, p * sa, wdx.xz * sa, wdy.xz * sa).rgb;
	} else if (blend >= 1.0) {
		col = textureGrad(grass_b, p * sb + 0.37, wdx.xz * sb, wdy.xz * sb).rgb;
	} else {
		vec3 ga = textureGrad(grass_a, p * sa, wdx.xz * sa, wdy.xz * sa).rgb;
		vec3 gb = textureGrad(grass_b, p * sb + 0.37, wdx.xz * sb, wdy.xz * sb).rgb;
		col = mix(ga, gb, blend);
	}
	col *= grass_tint;
	col *= mix(vec3(1.0), meadow_tint, smoothstep(0.45, 0.75, m2));
	col *= 0.9 + 0.2 * m2;

	float bank = smoothstep(0.25, 0.75, COLOR.g + (m2 - 0.5) * 0.35);
	if (bank > 0.0) {
		vec3 s = textureGrad(sand, p * 0.22, wdx.xz * 0.22, wdy.xz * 0.22).rgb;
		col = mix(col, s, bank);
	}
	float field = smoothstep(0.3, 0.7, COLOR.a);
	float road = smoothstep(0.3, 0.7, COLOR.r + (m2 - 0.5) * 0.3);
	if (field > 0.0 || road > 0.0) {
		vec3 d = textureGrad(dirt, p * 0.2, wdx.xz * 0.2, wdy.xz * 0.2).rgb;
		vec3 rows = d * field_tint * (0.8 + 0.2 * sin(p.x * 3.5));
		col = mix(col, rows, field);
		col = mix(col, d, road);
	}
	col = mix(col, col * blight_tint * 2.2, smoothstep(0.1, 0.9, COLOR.b));

	float steep = smoothstep(0.82, 0.62, wnormal.y);
	if (steep > 0.0) {
		vec2 rdx = wdx.xz * 0.08 + wdx.y * 0.05;
		vec2 rdy = wdy.xz * 0.08 + wdy.y * 0.05;
		vec3 r = textureGrad(rock, p * 0.08 + wpos.y * 0.05, rdx, rdy).rgb;
		col = mix(col, r, steep);
	}

	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.8, bank);
}
