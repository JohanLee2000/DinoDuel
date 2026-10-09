class_name Icons
extends RefCounted
## Vector icons stored as SVG markup and rendered at whatever pixel size they're shown at, so
## they stay crisp from a tiny bench card to the full-screen card view.
## Style follows the concept sheet in docs/concept/: glossy medallions with glowing rims.

const SVG := {
	# Types: Land = mountain, Sea = wave, Sky = bird.
	&"type_land": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
<defs><linearGradient id="rim" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff2c4"/><stop offset="0.5" stop-color="#e8a93a"/><stop offset="1" stop-color="#7a4b0c"/></linearGradient>
<radialGradient id="bg" cx="50%" cy="35%" r="70%"><stop offset="0" stop-color="#2a2a33"/><stop offset="1" stop-color="#0b0d14"/></radialGradient>
<linearGradient id="m" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff0b8"/><stop offset="0.45" stop-color="#f2b13c"/><stop offset="1" stop-color="#a8620f"/></linearGradient></defs>
<circle cx="64" cy="64" r="61" fill="url(#rim)"/><circle cx="64" cy="64" r="54" fill="url(#bg)"/>
<path d="M22 84 L52 38 L64 56 L76 40 L106 84 Z" fill="url(#m)" stroke="#4a2c06" stroke-width="3" stroke-linejoin="round"/>
<path d="M52 38 L60 50 L54 48 L48 54 Z M76 40 L84 52 L78 50 L72 55 Z" fill="#fffbe8"/></svg>""",
	&"type_sea": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
<defs><linearGradient id="rim" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#d6f0ff"/><stop offset="0.5" stop-color="#2e8bff"/><stop offset="1" stop-color="#0a2f6e"/></linearGradient>
<radialGradient id="bg" cx="50%" cy="35%" r="70%"><stop offset="0" stop-color="#14325e"/><stop offset="1" stop-color="#06122a"/></radialGradient>
<linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e8f8ff"/><stop offset="0.5" stop-color="#5fc0ff"/><stop offset="1" stop-color="#1468d8"/></linearGradient></defs>
<circle cx="64" cy="64" r="61" fill="url(#rim)"/><circle cx="64" cy="64" r="54" fill="url(#bg)"/>
<path d="M20 82 C30 60 52 38 78 40 C96 42 104 56 98 66 C92 76 78 72 78 62 C78 56 84 54 88 56 C86 48 74 46 64 52 C50 60 46 76 54 84 C62 92 86 90 108 80 L108 90 C90 98 54 100 20 90 Z"
 fill="url(#w)" stroke="#06265a" stroke-width="3" stroke-linejoin="round"/></svg>""",
	&"type_sky": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
<defs><linearGradient id="rim" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="0.5" stop-color="#7cc8ff"/><stop offset="1" stop-color="#1b4f8f"/></linearGradient>
<radialGradient id="bg" cx="50%" cy="35%" r="70%"><stop offset="0" stop-color="#3f7fd0"/><stop offset="1" stop-color="#0d2a5c"/></radialGradient>
<linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#b9e2ff"/></linearGradient></defs>
<circle cx="64" cy="64" r="61" fill="url(#rim)"/><circle cx="64" cy="64" r="54" fill="url(#bg)"/>
<path d="M18 50 C38 46 54 52 62 64 C70 46 86 32 110 28 C98 40 90 54 84 66 C80 76 72 86 60 90 L64 100 L52 92 C44 90 40 84 42 76 C34 68 26 60 18 50 Z"
 fill="url(#b)" stroke="#0b2c5e" stroke-width="3" stroke-linejoin="round"/></svg>""",
	# Stats: Attack = sword, Defense = shield, Speed = feather, Health = heart.
	&"stat_attack": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffb3b8"/><stop offset="1" stop-color="#e01e37"/></linearGradient></defs>
<path d="M52 6 L58 6 L58 12 L28 42 L22 36 Z" fill="url(#g)" stroke="#5a0a14" stroke-width="2.5" stroke-linejoin="round"/>
<path d="M14 34 L30 50 L26 54 L22 50 L14 58 L8 52 L16 44 L10 38 Z" fill="#ff5a6a" stroke="#5a0a14" stroke-width="2.5" stroke-linejoin="round"/></svg>""",
	&"stat_defense": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#bfe0ff"/><stop offset="1" stop-color="#1f6fe0"/></linearGradient></defs>
<path d="M32 4 L56 12 C56 36 47 51 32 60 C17 51 8 36 8 12 Z" fill="url(#g)" stroke="#06265a" stroke-width="3" stroke-linejoin="round"/>
<path d="M32 12 L48 17 C48 34 42 44 32 51 Z" fill="#ffffff" fill-opacity="0.35"/></svg>""",
	&"stat_speed": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#d4ffd0"/><stop offset="1" stop-color="#22b04a"/></linearGradient></defs>
<path d="M14 54 C12 32 28 12 56 6 C54 30 38 50 14 54 Z" fill="url(#g)" stroke="#0b4a1c" stroke-width="2.5" stroke-linejoin="round"/>
<path d="M8 60 L46 18" stroke="#0b4a1c" stroke-width="3" stroke-linecap="round"/></svg>""",
	&"stat_health": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd1ea"/><stop offset="1" stop-color="#ff3f9a"/></linearGradient></defs>
<path d="M32 57 C9 41 4 28 8 18 C12 7 27 6 32 18 C37 6 52 7 56 18 C60 28 55 41 32 57 Z" fill="url(#g)" stroke="#5a0a35" stroke-width="3" stroke-linejoin="round"/>
<ellipse cx="20" cy="20" rx="5" ry="3.5" fill="#ffffff" fill-opacity="0.6" transform="rotate(-30 20 20)"/></svg>""",
	&"crown": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 40">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3b0"/><stop offset="1" stop-color="#d98b10"/></linearGradient></defs>
<path d="M6 34 L4 10 L18 22 L32 4 L46 22 L60 10 L58 34 Z" fill="url(#g)" stroke="#5a3404" stroke-width="3" stroke-linejoin="round"/>
<circle cx="32" cy="24" r="4" fill="#ff4fb0"/></svg>""",
	&"star": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3b0"/><stop offset="1" stop-color="#f0a020"/></linearGradient></defs>
<path d="M32 4 L40 23 L60 24 L44 37 L50 58 L32 46 L14 58 L20 37 L4 24 L24 23 Z" fill="url(#g)" stroke="#5a3404" stroke-width="3" stroke-linejoin="round"/></svg>""",
	&"star_empty": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<path d="M32 4 L40 23 L60 24 L44 37 L50 58 L32 46 L14 58 L20 37 L4 24 L24 23 Z" fill="#1c2c48" stroke="#4d6a96" stroke-width="3" stroke-linejoin="round"/></svg>""",
	# Professor Saurus placeholder portrait (until assets/characters/professor_saurus.webp exists).
	&"professor": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
<circle cx="64" cy="64" r="61" fill="#1c2c48" stroke="#ffd34d" stroke-width="5"/>
<path d="M22 124 Q28 94 64 90 Q100 94 106 124 Z" fill="#b89a5e"/>
<path d="M56 90 L64 102 L72 90 Z" fill="#f4ecd8"/>
<circle cx="38" cy="72" r="6" fill="#e2b088"/><circle cx="90" cy="72" r="6" fill="#e2b088"/>
<circle cx="64" cy="70" r="26" fill="#f1c9a0"/>
<path d="M44 84 Q55 76 64 82 Q73 76 84 84 Q75 93 64 86 Q53 93 44 84 Z" fill="#ece6da"/>
<circle cx="54" cy="66" r="8" fill="#ffffff" fill-opacity="0.35" stroke="#2b1d10" stroke-width="3"/>
<circle cx="74" cy="66" r="8" fill="#ffffff" fill-opacity="0.35" stroke="#2b1d10" stroke-width="3"/>
<path d="M62 66 L66 66" stroke="#2b1d10" stroke-width="3"/>
<circle cx="54" cy="67" r="2.5" fill="#2b1d10"/><circle cx="74" cy="67" r="2.5" fill="#2b1d10"/>
<path d="M46 56 Q54 52 60 56 M68 56 Q74 52 82 56" stroke="#ece6da" stroke-width="3" fill="none" stroke-linecap="round"/>
<path d="M32 52 Q34 20 64 18 Q94 20 96 52 Z" fill="#d8c08a"/>
<rect x="33" y="44" width="62" height="7" fill="#7a5a2e"/>
<ellipse cx="64" cy="53" rx="42" ry="8" fill="#c4a96e"/>
</svg>""",
	# Volume slider knob.
	&"knob": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><circle cx="32" cy="32" r="28" fill="#ffd34d" stroke="#0b1220" stroke-width="4"/><circle cx="32" cy="32" r="10" fill="#fff2c4"/></svg>""",
	# Settings button.
	&"gear": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><g fill="#cfe0ff"><rect x="27" y="3" width="10" height="14" rx="2" transform="rotate(0 32 32)"/><rect x="27" y="3" width="10" height="14" rx="2" transform="rotate(45 32 32)"/><rect x="27" y="3" width="10" height="14" rx="2" transform="rotate(90 32 32)"/><rect x="27" y="3" width="10" height="14" rx="2" transform="rotate(135 32 32)"/><rect x="27" y="3" width="10" height="14" rx="2" transform="rotate(180 32 32)"/><rect x="27" y="3" width="10" height="14" rx="2" transform="rotate(225 32 32)"/><rect x="27" y="3" width="10" height="14" rx="2" transform="rotate(270 32 32)"/><rect x="27" y="3" width="10" height="14" rx="2" transform="rotate(315 32 32)"/><circle cx="32" cy="32" r="20"/></g><circle cx="32" cy="32" r="8" fill="#101b2e"/></svg>""",
	# Currency: a drop of amber with a tiny trapped insect.
	&"amber": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs><radialGradient id="a" cx="40%" cy="38%" r="65%"><stop offset="0" stop-color="#ffe7a6"/>
<stop offset="0.5" stop-color="#e3952a"/><stop offset="1" stop-color="#7a3f0c"/></radialGradient></defs>
<path d="M32 4 C44 18 54 30 54 40 C54 52 44 60 32 60 C20 60 10 52 10 40 C10 30 20 18 32 4 Z" fill="url(#a)" stroke="#4a2606" stroke-width="2"/>
<ellipse cx="24" cy="34" rx="4.5" ry="9" fill="#fff6d8" fill-opacity="0.55" transform="rotate(-20 24 34)"/>
<ellipse cx="35" cy="42" rx="2.5" ry="1.6" fill="#4a2606" fill-opacity="0.6"/></svg>""",
	&"egg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs><radialGradient id="e" cx="38%" cy="32%" r="70%"><stop offset="0" stop-color="#fffaf0"/>
<stop offset="0.6" stop-color="#e9dcc0"/><stop offset="1" stop-color="#a8956e"/></radialGradient></defs>
<path d="M32 4 C46 4 54 26 54 40 C54 53 44 60 32 60 C20 60 10 53 10 40 C10 26 18 4 32 4 Z" fill="url(#e)" stroke="#5b4a2e" stroke-width="2"/>
<g fill="#8a7350" fill-opacity="0.7"><circle cx="26" cy="22" r="2"/><circle cx="38" cy="30" r="2.5"/><circle cx="24" cy="40" r="1.8"/><circle cx="40" cy="46" r="2"/></g></svg>""",
	# Placeholder silhouettes, one per type, until the paintings exist.
	&"silhouette_land": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
<g fill="#1a1410">
<path d="M6 78 Q60 58 108 66 L108 94 Q60 92 6 78 Z"/><path d="M104 102 L96 146 L116 146 L128 106 Z"/>
<path d="M134 100 L138 146 L156 146 L148 100 Z"/><ellipse cx="124" cy="84" rx="42" ry="28"/>
<path d="M144 70 Q158 50 172 40 L186 54 Q170 72 158 90 Z"/>
<path d="M166 24 L216 28 Q230 32 226 46 L202 50 L224 58 Q220 68 208 68 L176 64 Q162 50 166 24 Z"/>
<path d="M158 84 L172 96 L166 102 L154 92 Z"/></g></svg>""",
	&"silhouette_sky": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
<g fill="#13233a">
<path d="M110 82 Q64 52 8 92 Q58 86 112 100 Z"/><path d="M130 82 Q176 52 232 92 Q182 86 128 100 Z"/>
<ellipse cx="120" cy="92" rx="22" ry="13"/><path d="M104 84 L52 72 L100 96 Z"/>
<path d="M108 82 L94 52 L118 78 Z"/><path d="M138 92 L160 98 L138 100 Z"/></g></svg>""",
	&"silhouette_sea": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
<g fill="#04172e">
<path d="M150 96 Q170 76 190 70 Q182 92 168 104 Z"/><path d="M176 100 L232 108 L178 116 Z"/>
<path d="M112 110 Q96 138 74 146 Q104 134 132 116 Z"/><path d="M162 110 Q154 138 138 148 Q164 136 180 112 Z"/>
<ellipse cx="140" cy="104" rx="50" ry="22"/><path d="M100 98 Q70 70 58 40 L72 34 Q86 62 114 88 Z"/>
<path d="M66 42 Q48 44 30 36 Q44 26 70 30 Z"/></g></svg>""",
}

static var _cache: Dictionary = {}


## Returns the icon rendered `pixels` tall (and proportionally wide). Rendered at 2x so it stays
## sharp when the game is scaled up on high-density phone screens.
static func texture(icon: StringName, pixels: int) -> Texture2D:
	var key := "%s@%d" % [icon, pixels]
	if _cache.has(key):
		return _cache[key]
	var markup: String = SVG[icon]
	var image := Image.new()
	image.load_svg_from_string(markup, maxf(0.05, pixels * 2.0 / _view_height(markup)))
	var tex := ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex


static func type_icon(dino_type: DinoDef.DinoType) -> StringName:
	return [&"type_land", &"type_sky", &"type_sea"][dino_type]


static func silhouette(dino_type: DinoDef.DinoType) -> StringName:
	return [&"silhouette_land", &"silhouette_sky", &"silhouette_sea"][dino_type]


static func _view_height(markup: String) -> float:
	var start := markup.find("viewBox=\"") + 9
	var parts := markup.substr(start, markup.find("\"", start) - start).split(" ")
	return float(parts[3])
