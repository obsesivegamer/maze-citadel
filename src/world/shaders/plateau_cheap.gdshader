// plateau.gdshader with fewer texture reads, for the terrain-cheap
// performance switch (PerfFlags); the look is the same. The second grass is
// read only where the two grasses blend, dirt only on the rim and under ruins,
// cobbles only on the paved strips, and the ruin mask only when the map has
// ruins. One screen-space footprint of the position stands in for three of
// the four fwidth() calls, and sampling takes gradients from before any
// branch, so mip selection stays right on pixels next to a mask edge.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform vec2 grid_half = vec2(20.0, 28.0);
uniform float tile = 2.0;
uniform float line_width = 0.045;
uniform float line_strength = 0.3;
uniform float checker_strength = 0.05;
uniform vec3 grass_tint : source_color = vec3(1.0);
uniform vec3 rim_tint : source_color = vec3(0.8, 0.78, 0.7);
uniform vec3 cobble_tint : source_color = vec3(1.0);
// Paved strips as (x0, z0, x1, z1).
uniform vec4 paved_north = vec4(-2.0, -40.0, 2.0, -26.0);
uniform vec4 paved_south = vec4(-2.0, 26.0, 2.0, 40.0);
// Ruin tiles (one texel per tile, white = ruin); black when the map has none.
uniform sampler2D ruins : hint_default_black, filter_linear, repeat_disable;
uniform bool has_ruins = false;
uniform vec3 ruin_tint : source_color = vec3(0.72, 0.66, 0.58);
uniform vec2 blight_center = vec2(0.0, -34.0);
uniform float blight_radius = 9.0;
uniform vec3 blight_tint : source_color = vec3(0.45, 0.2, 0.17);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// fw is fwidth(p); the box distance's footprint is its dominant axis's.
float rect_mask(vec2 p, vec4 r, vec2 fw) {
	vec2 c = (r.xy + r.zw) * 0.5;
	vec2 h = (r.zw - r.xy) * 0.5;
	vec2 d = abs(p - c) - h;
	float o = max(d.x, d.y);
	float aa = d.x > d.y ? fw.x : fw.y;
	return 1.0 - smoothstep(-aa, aa, o);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 pdx = dFdx(p);
	vec2 pdy = dFdy(p);
	vec2 fw = abs(pdx) + abs(pdy);
	float m = texture(macro, p * 0.035).r;
	float m2 = texture(macro, p * 0.11 + 0.3).r;
	float blend = smoothstep(0.35, 0.65, m);
	vec3 grass;
	if (blend <= 0.0) {
		grass = textureGrad(grass_a, p * 0.21, pdx * 0.21, pdy * 0.21).rgb;
	} else if (blend >= 1.0) {
		grass = textureGrad(grass_b, p * 0.16 + 0.37, pdx * 0.16, pdy * 0.16).rgb;
	} else {
		vec3 g1 = textureGrad(grass_a, p * 0.21, pdx * 0.21, pdy * 0.21).rgb;
		vec3 g2 = textureGrad(grass_b, p * 0.16 + 0.37, pdx * 0.16, pdy * 0.16).rgb;
		grass = mix(g1, g2, blend);
	}
	grass *= grass_tint * (0.94 + 0.12 * m2);

	vec2 dg = abs(p) - grid_half;
	float outside = max(dg.x, dg.y);
	float aa = dg.x > dg.y ? fw.x : fw.y;
	float in_grid = 1.0 - smoothstep(-aa, aa, outside);
	float ruin = 0.0;
	if (has_ruins && in_grid > 0.0) {
		vec2 ruin_uv = (p + grid_half) / (2.0 * grid_half);
		ruin = smoothstep(0.1, 0.6, textureLod(ruins, ruin_uv, 0.0).r) * in_grid;
	}
	vec3 d = vec3(0.0);
	if (in_grid < 1.0 || ruin > 0.0) {
		d = textureGrad(dirt, p * 0.23, pdx * 0.23, pdy * 0.23).rgb;
	}
	vec3 col = grass;
	if (in_grid < 1.0) {
		vec3 rim = mix(d, grass * 0.8, smoothstep(0.35, 0.75, m2 + 0.1)) * rim_tint;
		col = mix(rim, grass, in_grid);
	}

	vec2 g = (p + grid_half) / tile;
	vec2 dist = (0.5 - abs(fract(g) - 0.5)) * tile;
	float dl = min(dist.x, dist.y);
	float w = fwidth(dl);
	float line = 1.0 - smoothstep(line_width - w, line_width + w, dl);
	float checker = mod(floor(g.x) + floor(g.y), 2.0) - 0.5;
	col *= 1.0 + checker * checker_strength * in_grid;
	col = mix(col, col * (1.0 - line_strength), line * in_grid);
	float frame = 1.0 - smoothstep(0.1 - aa, 0.1 + aa, abs(outside));
	col = mix(col, col * 0.62, frame);

	if (ruin > 0.0) {
		vec3 rubble = mix(d, d * ruin_tint, smoothstep(0.3, 0.7, m2));
		col = mix(col, rubble, ruin * 0.85);
	}

	float pave = max(rect_mask(p, paved_north, fw), rect_mask(p, paved_south, fw));
	if (pave > 0.0) {
		vec3 cob = textureGrad(cobble, p * 0.3, pdx * 0.3, pdy * 0.3).rgb * cobble_tint;
		col = mix(col, cob, pave);
	}

	float b = 1.0 - smoothstep(blight_radius * 0.25, blight_radius, distance(p, blight_center));
	col = mix(col, col * blight_tint * 1.6, b * (1.0 - in_grid * 0.7));

	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.8, pave);
}
