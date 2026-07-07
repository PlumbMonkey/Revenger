shader_type spatial;
render_mode unshaded, blend_add, cull_back;

// Defender-style bolt: long thin additive streak cycling through a hand-picked
// 80s neon palette — hot pink, laser orange, neon yellow, neon green, electric
// cyan, electric purple. Blends are re-saturated (max channel forced to 1) so
// the color NEVER passes through a muddy in-between tone: always full neon.
// Dual sine wobble makes the bands morph fluidly along the bolt.

uniform float bolt_length = 12.0;
uniform float hue_cycles : hint_range(0.5, 6.0) = 2.5;    // neon bands visible at once
uniform float hue_speed : hint_range(0.0, 10.0) = 2.5;    // color flow speed
uniform float morph_amount : hint_range(0.0, 0.6) = 0.25; // sine wobble = fluid morphing
// Keep intensity near 1 — additive blending overexposes saturated color to
// white fast; neon reads as neon only when the channels stay in range.
uniform float intensity : hint_range(0.5, 8.0) = 2.2;
uniform float core_radius = 0.03;

varying vec3 local_pos;

const vec3 NEON[6] = {
	vec3(1.00, 0.10, 0.60),  // hot pink
	vec3(1.00, 0.45, 0.05),  // laser orange
	vec3(1.00, 0.95, 0.10),  // neon yellow
	vec3(0.30, 1.00, 0.15),  // neon green
	vec3(0.00, 0.95, 1.00),  // electric cyan
	vec3(0.65, 0.15, 1.00)   // electric purple
};

void vertex() {
	local_pos = VERTEX;
}

vec3 neon_palette(float t) {
	float s = fract(t) * 6.0;
	int i = int(s);
	float f = smoothstep(0.0, 1.0, fract(s));
	vec3 c = mix(NEON[i], NEON[(i + 1) % 6], f);
	// re-saturate: force the strongest channel back to full — no dull blends
	return c / max(max(c.r, c.g), max(c.b, 0.001));
}

void fragment() {
	float along = clamp(local_pos.z / bolt_length + 0.5, 0.0, 1.0);
	float t = along * hue_cycles - TIME * hue_speed
			+ morph_amount * sin(TIME * 1.7 + along * 9.0)
			+ morph_amount * 0.5 * sin(TIME * 3.1 - along * 4.0);
	vec3 neon = neon_palette(t);
	float core = 1.0 - smoothstep(0.0, core_radius * 2.0, length(local_pos.xy));
	vec3 color = mix(neon, vec3(1.0), core * 0.3);
	// fade the tail (+Z end) so the bolt reads as streaking forward
	float tail_fade = smoothstep(1.0, 0.55, along);
	ALBEDO = color * intensity;
	ALPHA = 0.9 * max(tail_fade, 0.3);
}
