shader_type canvas_item;
// Neon trading-card frame from the concept sheet: an outer glow in the tier color, a bevelled
// metallic band, a bright inner edge line, and a transparent center for the art.
// Drawn on a rect larger than the card by `glow` pixels on every side.

uniform vec2 rect_size = vec2(300.0, 460.0);
uniform vec2 card_size = vec2(260.0, 420.0);
uniform float glow = 20.0;
uniform float border = 10.0;
uniform float radius = 14.0;
uniform vec4 tier_color : source_color = vec4(1.0, 0.7, 0.18, 1.0);
uniform float glow_strength = 0.8;
uniform float rainbow = 0.0;
uniform float pulse = 0.0;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - (half_size - r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec2 px = UV * rect_size - vec2(glow);
	vec2 center = card_size * 0.5;
	float d = rounded_box(px - center, center, radius);
	// Position around the card, 0..1, used for the diagonal sheen and the rainbow.
	float diag = (px.x / card_size.x + px.y / card_size.y) * 0.5;
	vec3 tint = tier_color.rgb;
	if (rainbow > 0.0) {
		tint = mix(tint, hue(fract(diag * 0.8 + TIME * 0.12)) * 0.6 + 0.4, rainbow);
	}
	float breathe = 1.0 + pulse * 0.25 * sin(TIME * 2.4);

	vec4 col = vec4(0.0);
	if (d > 0.0) {
		float a = exp(-d / (glow * 0.32)) * glow_strength * breathe;
		col = vec4(tint, clamp(a, 0.0, 1.0));
	} else if (d > -border) {
		float t = -d / border;
		// Metallic band: light along the outer edge, dark in the middle, a sheen across it.
		vec3 light = mix(tint, vec3(1.0), 0.55);
		vec3 dark = tint * 0.35;
		vec3 metal = mix(light, dark, smoothstep(0.0, 0.6, t));
		float sheen = smoothstep(0.08, 0.0, abs(fract(diag * 1.5 - TIME * 0.08) - 0.5) - 0.42);
		metal += sheen * 0.25;
		// Bright neon line on the inner edge.
		float inner = smoothstep(0.78, 0.95, t);
		metal = mix(metal, mix(tint, vec3(1.0), 0.35) * 1.3, inner);
		col = vec4(metal, 1.0);
	} else {
		// Inner glow spilling onto the art.
		float inset = -d - border;
		col = vec4(tint, exp(-inset / (border * 0.5)) * 0.45);
	}
	COLOR = col;
}
