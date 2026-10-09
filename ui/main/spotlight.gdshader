shader_type canvas_item;
// Dims the whole screen except one rounded rectangle (the "hole"), with a soft edge. Used by
// Professor Saurus's tour to point at a tab or the top bar. A zero-size hole dims everything.

uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec4 hole = vec4(0.0);   // x, y, width, height in pixels
uniform float radius = 14.0;
uniform float feather = 10.0;
uniform float dim = 0.7;

void fragment() {
	vec2 p = UV * rect_size;
	float alpha = dim;
	if (hole.z > 0.0 && hole.w > 0.0) {
		vec2 half_size = hole.zw * 0.5;
		vec2 q = abs(p - (hole.xy + half_size)) - half_size + radius;
		float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
		alpha = dim * smoothstep(0.0, feather, d);
	}
	COLOR = vec4(0.02, 0.04, 0.09, alpha);
}
