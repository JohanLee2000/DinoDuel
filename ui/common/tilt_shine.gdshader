shader_type canvas_item;
render_mode blend_add;
// Light glare for UR and Shiny cards in the full-screen card view: a soft highlight and a
// rainbow band that slide across the card as the phone tilts (or the card is dragged).
// `tilt` runs from -1 to 1 on each axis; 0 is how the player held the phone when the card opened.

uniform vec2 rect_size = vec2(400.0, 600.0);
uniform float radius = 8.0;
uniform vec2 tilt = vec2(0.0);
uniform float rainbow = 1.0;
uniform float strength = 0.6;

void fragment() {
	// The highlight moves against the tilt, like a lamp above the phone.
	vec2 spot = vec2(0.5, 0.32) - tilt * vec2(0.6, 0.5);
	vec2 d = (UV - spot) * vec2(rect_size.x / rect_size.y, 1.0);
	float glare = exp(-dot(d, d) * 10.0);
	// A diagonal rainbow band that sweeps across with the tilt.
	float band = fract((UV.x * 0.7 + UV.y * 0.9) * 1.1 + tilt.x * 0.7 + tilt.y * 0.5);
	vec3 spectrum = 0.55 + 0.45 * cos(6.2831 * (band * 1.4 + vec3(0.0, 0.33, 0.67)));
	float sweep = smoothstep(0.0, 0.22, band) * smoothstep(0.55, 0.28, band);
	vec2 px = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(px - half_size) - (half_size - radius);
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float mask = 1.0 - smoothstep(-1.0, 1.0, dist);
	vec3 light = vec3(1.0) * glare * 0.5 + mix(vec3(1.0), spectrum, rainbow) * sweep * 0.22;
	COLOR = vec4(light * strength * mask, 1.0);
}
