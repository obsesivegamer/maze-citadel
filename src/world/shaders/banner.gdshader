// Wall-hung cloth banner (KayKit dungeon banners): keeps the model texture and
// ripples the cloth below `cloth_top` outward from the wall (+Z), stronger
// toward the hem. Model space, so it scales with the instance.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform vec3 tint : source_color = vec3(1.0);
uniform float cloth_top = 3.35;
uniform float cloth_bottom = 0.5;
uniform float amp = 0.16;
uniform float speed = 1.0;

void vertex() {
	float w = clamp((cloth_top - VERTEX.y) / (cloth_top - cloth_bottom), 0.0, 1.0);
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = dot(o.xz, vec2(0.37, 0.23));
	float t = TIME * speed;
	float wave = sin(t * 2.3 + ph - VERTEX.y * 1.7) * 0.65;
	wave += sin(t * 3.9 + ph * 1.3 - VERTEX.y * 2.6 + VERTEX.x * 2.2) * 0.35;
	VERTEX.z += (wave + 0.7) * amp * w;
	VERTEX.x += sin(t * 1.6 + ph) * amp * 0.4 * w * w;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * tint;
	ALBEDO = c;
	ROUGHNESS = 0.85;
	BACKLIGHT = c * 0.25;
}
