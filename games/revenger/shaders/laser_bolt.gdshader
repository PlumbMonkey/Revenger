shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

// Defender-style bolt: a long additive streak with the hue cycling along its
// length and over time, plus a white-hot core near the centerline. Sized for
// the default 8m BoxMesh — bolt_length just rescales the gradient.

uniform float bolt_length = 8.0;
uniform float hue_cycles : hint_range(0.5, 6.0) = 2.0;  // rainbow repeats along the bolt
uniform float hue_speed : hint_range(0.0, 10.0) = 3.0;  // hue scroll speed
uniform float intensity : hint_range(0.5, 6.0) = 2.5;
uniform float core_radius = 0.12;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

vec3 hue2rgb(float h) {
	h = fract(h);
	return clamp(vec3(
		abs(h * 6.0 - 3.0) - 1.0,
		2.0 - abs(h * 6.0 - 2.0),
		2.0 - abs(h * 6.0 - 4.0)), 0.0, 1.0);
}

void fragment() {
	float along = clamp(local_pos.z / bolt_length + 0.5, 0.0, 1.0);
	vec3 rainbow = hue2rgb(along * hue_cycles - TIME * hue_speed);
	float core = 1.0 - smoothstep(0.0, core_radius * 2.0, length(local_pos.xy));
	vec3 color = mix(rainbow, vec3(1.0), core * 0.65);
	// fade the tail (+Z end) so the bolt reads as streaking forward
	float tail_fade = smoothstep(1.0, 0.55, along);
	ALBEDO = color * intensity;
	ALPHA = 0.9 * max(tail_fade, 0.35);
}
