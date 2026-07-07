shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

// Defender-style bolt: long thin additive streak. Color comes from a cosine
// palette (smooth, always-saturated neon blends — no hard RGB corners) with a
// sine wobble on top so the hues visibly MORPH along the bolt rather than
// just scrolling. White-hot core down the centerline, tail fade at +Z.

uniform float bolt_length = 12.0;
uniform float hue_cycles : hint_range(0.5, 6.0) = 1.5;   // rainbow repeats along the bolt
uniform float hue_speed : hint_range(0.0, 10.0) = 2.5;   // hue flow speed
uniform float morph_amount : hint_range(0.0, 0.6) = 0.22; // sine wobble = fluid morphing
uniform float intensity : hint_range(0.5, 8.0) = 3.5;
uniform float core_radius = 0.08;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// IQ cosine palette tuned for bright neon: never desaturates, blends fluidly
vec3 neon_palette(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	float along = clamp(local_pos.z / bolt_length + 0.5, 0.0, 1.0);
	float t = along * hue_cycles - TIME * hue_speed
			+ morph_amount * sin(TIME * 1.7 + along * 9.0)
			+ morph_amount * 0.5 * sin(TIME * 3.1 - along * 4.0);
	vec3 neon = neon_palette(t);
	float core = 1.0 - smoothstep(0.0, core_radius * 2.0, length(local_pos.xy));
	vec3 color = mix(neon, vec3(1.0), core * 0.7);
	// fade the tail (+Z end) so the bolt reads as streaking forward
	float tail_fade = smoothstep(1.0, 0.55, along);
	ALBEDO = color * intensity;
	ALPHA = 0.9 * max(tail_fade, 0.3);
}
