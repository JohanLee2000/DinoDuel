shader_type canvas_item;
// Animated holographic sheen for Legendary and Shiny cards. Drawn on top of the art.

uniform vec2 rect_size = vec2(200.0, 280.0);
uniform float radius = 8.0;
uniform float strength = 0.3;
uniform float rainbow = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.45, 1.0);
// Shifts the sheen with the phone's tilt in the full-screen card view (see CardViewer).
uniform vec2 tilt = vec2(0.0);

void fragment() {
	float t = TIME * 0.18;
	float band = fract((UV.x * 0.8 + UV.y) * 1.1 - t + tilt.x * 0.6 + tilt.y * 0.4);
	vec3 spectrum = 0.55 + 0.45 * cos(6.2831 * (band * 1.5 + vec3(0.0, 0.33, 0.67)));
	vec3 col = mix(tint.rgb, spectrum, rainbow);
	float shine = smoothstep(0.0, 0.35, band) * smoothstep(0.75, 0.35, band);
	float sparkle = step(0.997, fract(sin(dot(floor(UV * rect_size / 3.0), vec2(12.9898, 78.233))) * 43758.5453 + t * 0.3));
	vec2 px = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(px - half_size) - (half_size - radius);
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float mask = 1.0 - smoothstep(-1.0, 1.0, dist);
	COLOR = vec4(col, (strength * (0.25 + 0.75 * shine) + sparkle * 0.6) * mask);
}
