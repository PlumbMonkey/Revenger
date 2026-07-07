shader_type spatial;
render_mode unshaded, blend_add, cull_back;

// Slow enemy pulse shot: a glowing orb that visibly breathes — the sphere
// swells and its brightness throbs in sync, with a fresnel rim so the edge
// glows hotter than the center. Tint per enemy type via `color`.

uniform vec3 color : source_color = vec3(0.25, 1.0, 0.65);
uniform float pulse_speed : hint_range(1.0, 15.0) = 6.0;
uniform float swell : hint_range(0.0, 0.2) = 0.08;
uniform float intensity : hint_range(0.5, 4.0) = 1.6;

void vertex() {
	VERTEX *= 1.0 + swell * sin(TIME * pulse_speed);
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 1.6);
	float throb = 0.75 + 0.25 * sin(TIME * pulse_speed);
	ALBEDO = color * intensity * throb * (0.45 + 0.8 * fresnel);
	ALPHA = clamp(0.5 + 0.5 * fresnel, 0.0, 1.0);
}
