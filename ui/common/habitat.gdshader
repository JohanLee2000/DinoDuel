shader_type canvas_item;
// Placeholder painting backdrop until the real art exists: a soft three-stop sky/ground or
// underwater gradient with haze, plus light rays for the sea.

uniform vec4 top_color : source_color = vec4(0.95, 0.75, 0.5, 1.0);
uniform vec4 mid_color : source_color = vec4(0.8, 0.5, 0.3, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.3, 0.2, 0.12, 1.0);
uniform float horizon = 0.72;
uniform float rays = 0.0;
uniform vec2 rect_size = vec2(200.0, 120.0);
uniform float radius = 4.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float y = UV.y;
	vec3 col = y < horizon ? mix(top_color.rgb, mid_color.rgb, y / horizon)
			: mix(mid_color.rgb, bottom_color.rgb, (y - horizon) / (1.0 - horizon));
	if (rays > 0.0) {
		float r = sin(UV.x * 14.0 + UV.y * 5.0) * 0.5 + 0.5;
		col += rays * pow(r, 6.0) * (1.0 - y) * 0.35;
	}
	col += (hash(UV * rect_size) - 0.5) * 0.025;
	vec2 px = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(px - half_size) - (half_size - radius);
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = vec4(col, 1.0 - smoothstep(-1.0, 1.0, dist));
}
