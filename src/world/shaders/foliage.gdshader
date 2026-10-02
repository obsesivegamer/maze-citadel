shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/foliage.gdshaderinc"

void fragment() {
	ALBEDO = foliage_color(UV, COLOR).rgb;
	ROUGHNESS = roughness;
}
