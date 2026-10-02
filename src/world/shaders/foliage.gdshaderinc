// Shared by foliage.gdshader (bark, opaque) and foliage_cutout.gdshader
// (leaves). Reproduces the imported StandardMaterial3D look (texture, colour,
// vertex colour) and bends the whole plant along a world-space wind so bark
// and leaves stay attached. Works per MultiMesh instance: MODEL_MATRIX holds
// the instance transform, so each tree gets its own phase.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float roughness = 0.9;
uniform float scissor = 0.5;
// Model-space height of the plant's top; the bend grows with (y / height)^2.
uniform float height = 7.0;
// Sway at the top, in world metres.
uniform float amp = 0.2;
// Leaf shiver along the normal, in model units.
uniform float flutter = 0.0;
uniform vec3 wind_dir = vec3(0.82, 0.0, -0.57);

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = dot(origin.xz, vec2(0.11, 0.07));
	float h = clamp(VERTEX.y / height, 0.0, 1.0);
	float gust = sin(TIME * 0.9 + phase) * 0.55 + sin(TIME * 1.7 + phase * 1.9) * 0.25 + 0.3;
	vec3 world_off = wind_dir * (gust * amp * h * h);
	// Instances are rotated and uniformly scaled: M^-1 = M^T / s^2.
	float s2 = dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
	VERTEX += transpose(mat3(MODEL_MATRIX)) * world_off / s2;
	if (flutter > 0.0) {
		float f = sin(TIME * 6.5 + dot(VERTEX, vec3(3.1, 2.3, 2.7)) + phase * 3.0);
		VERTEX += NORMAL * f * flutter * h;
	}
}

vec4 foliage_color(vec2 uv, vec4 vcol) {
	vec4 c = texture(albedo_tex, uv) * albedo;
	if (use_vertex_color) {
		c.rgb *= vcol.rgb;
	}
	return c;
}
