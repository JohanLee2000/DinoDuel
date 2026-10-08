shader_type canvas_item;
// Battle background: the rival's type scene fills the top, the player's the bottom, blended across
// the middle. Both drift slowly (the far, top one less) for a parallax feel. Dimmed overall, with
// soft shadows behind the two active cards and across the battle log so they stay readable.

uniform sampler2D rival_tex : filter_linear, repeat_disable;
uniform sampler2D player_tex : filter_linear, repeat_disable;
uniform float rect_aspect = 0.46;   // width / height of the area drawn
uniform float image_aspect = 0.6667;
uniform float blend_center = 0.5;
uniform float blend_width = 0.24;
uniform float dim = 0.72;
uniform vec2 rival_focus = vec2(0.5, 0.2);   // UV centres of the active cards
uniform vec2 player_focus = vec2(0.5, 0.75);
uniform float focus_radius = 0.22;
uniform float focus_dark = 0.3;

// Cover-fits the image to the area, zoomed in a little so the drift never shows an edge.
vec2 cover_uv(vec2 uv, float depth, float phase) {
	vec2 centered = uv - 0.5;
	centered.x *= rect_aspect / image_aspect;
	vec2 drift = vec2(sin(TIME * 0.045 + phase), cos(TIME * 0.032 + phase * 1.7)) * vec2(0.03, 0.012) * depth;
	return centered / 1.08 + 0.5 + drift;
}

float shadow(vec2 uv, vec2 focus) {
	vec2 d = (uv - focus) * vec2(rect_aspect, 1.0);
	return focus_dark * exp(-dot(d, d) / (focus_radius * focus_radius));
}

void fragment() {
	vec3 top = texture(rival_tex, cover_uv(UV, 0.55, 0.0)).rgb;
	vec3 bottom = texture(player_tex, cover_uv(UV, 1.0, 2.3)).rgb;
	float t = smoothstep(blend_center - blend_width * 0.5, blend_center + blend_width * 0.5, UV.y);
	vec3 col = mix(top, bottom, t);
	float light = dim;
	light *= 1.0 - 0.16 * exp(-pow((UV.y - blend_center) / 0.1, 2.0));
	light *= 1.0 - shadow(UV, rival_focus) - shadow(UV, player_focus);
	vec2 v = (UV - 0.5) * vec2(1.3, 1.0);
	light *= clamp(1.0 - 0.6 * dot(v, v), 0.0, 1.0);
	COLOR = vec4(col * light, 1.0);
}
