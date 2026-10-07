shader_type canvas_item;
// Textured card material: fossil stone, parchment, or brushed metal, depending on the uniforms.
// Value-noise grain, optional speckles, vignette, a bevelled edge, and rounded corners.

uniform vec4 base_color : source_color = vec4(0.45, 0.42, 0.37, 1.0);
uniform vec4 dark_color : source_color = vec4(0.25, 0.23, 0.2, 1.0);
uniform float grain = 0.6;
uniform float noise_scale = 0.03;
uniform float speckles = 0.0;
uniform float streaks = 0.0;
uniform float vignette = 0.0;
uniform float bevel = 0.0;
uniform vec2 rect_size = vec2(200.0, 280.0);
uniform float radius = 10.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 p = px * noise_scale + vec2(seed * 17.0, seed * 3.0);
	float n = fbm(p);
	if (streaks > 0.0) {
		// Brushed-metal look: stretch the noise horizontally.
		n = mix(n, fbm(vec2(p.x * 0.08, p.y * 3.0)), streaks);
	}
	vec3 col = mix(dark_color.rgb, base_color.rgb, mix(0.55, n * 1.25, grain));
	if (speckles > 0.0) {
		float s = hash(floor(px * 0.6) + seed);
		col = mix(col, dark_color.rgb * 0.75, step(1.0 - speckles * 0.04, s));
	}
	vec2 c = UV - 0.5;
	col *= 1.0 - vignette * dot(c, c) * 1.8;

	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(px - half_size) - (half_size - radius);
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	if (bevel > 0.0) {
		float edge = 1.0 - clamp(-dist / bevel, 0.0, 1.0);
		vec2 dir = (px - half_size) / half_size;
		float light = clamp(-(dir.x * 0.4 + dir.y), -1.0, 1.0);
		col += edge * light * 0.22;
	}
	COLOR = vec4(col, base_color.a * (1.0 - smoothstep(-1.0, 1.0, dist)));
}
