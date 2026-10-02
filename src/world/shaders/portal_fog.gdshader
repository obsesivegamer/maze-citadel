// Red volumetric plume over the portal: a column that widens as it rises,
// eaten by scrolling 3D noise so wisps climb out of the vortex.
shader_type fog;

uniform sampler3D noise3d : repeat_enable;
uniform vec3 albedo : source_color = vec3(1.0, 0.3, 0.2);
uniform vec3 emission : source_color = vec3(0.7, 0.07, 0.02);
uniform float density = 1.2;

void fog() {
	float y = UVW.y;
	float radius = 0.16 + 0.26 * y;
	float radial = 1.0 - smoothstep(radius * 0.5, radius, length(UVW.xz - 0.5));
	float rise = texture(noise3d, UVW * vec3(1.4, 0.9, 1.4) + vec3(0.0, -TIME * 0.11, 0.0)).r;
	float fade = smoothstep(0.0, 0.12, y) * (1.0 - smoothstep(0.5, 1.0, y));
	DENSITY = density * radial * fade * smoothstep(0.3, 0.72, rise);
	ALBEDO = albedo;
	EMISSION = emission * (0.5 + rise);
}
