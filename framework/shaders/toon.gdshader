shader_type spatial;
render_mode blend_mix, cull_back, diffuse_toon, specular_toon;

// Stepped-band NPR shader for the Shared Arcade Framework. Reads a flat
// albedo (texture or tint, matching the source .blend material's Base
// Color) and does all shading here at runtime - Blender/glTF never bakes
// lighting into this look, since glTF only carries PBR data.

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int band_count : hint_range(2, 6) = 3;
uniform float shadow_softness : hint_range(0.0, 0.3) = 0.05;

uniform vec4 rim_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.5;
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.6;

varying vec3 world_normal;
varying vec3 view_dir;

void vertex() {
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	view_dir = normalize(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = (tex.rgb * albedo_tint.rgb);

	float rim = pow(1.0 - clamp(dot(normalize(view_dir), world_normal), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * rim * rim_intensity;
}

// diffuse_toon/specular_toon (render_mode above) already band the built-in
// lighting response; this override adds our own quantization on top so
// band_count is actually configurable per material instance.
void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float banded = floor(clamp(ndotl, 0.0, 1.0) * float(band_count)) / float(band_count);
	banded = smoothstep(banded - shadow_softness, banded + shadow_softness, ndotl);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * banded * ATTENUATION;
}
