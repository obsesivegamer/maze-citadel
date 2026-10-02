shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/foliage.gdshaderinc"

void fragment() {
	vec4 c = foliage_color(UV, COLOR);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
	ROUGHNESS = roughness;
	// Sunlight through the leaves.
	BACKLIGHT = c.rgb * 0.35;
}
