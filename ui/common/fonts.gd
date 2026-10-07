class_name Fonts
extends RefCounted
## Barlow (body) and Barlow Condensed (names, numbers, titles, buttons), both SIL Open Font
## License; license files sit next to the fonts in res://assets/fonts/. The bold italic
## condensed style matches the concept sheet's card names and headings.

const BARLOW := "res://assets/fonts/Barlow-Medium.ttf"
const BARLOW_BOLD := "res://assets/fonts/Barlow-Bold.ttf"
const CONDENSED := "res://assets/fonts/BarlowCondensed-SemiBold.ttf"
const CONDENSED_BOLD := "res://assets/fonts/BarlowCondensed-Bold.ttf"
const ITALIC_SLANT := 0.18

static var _cache: Dictionary = {}


## Card names, tier codes and big numbers: bold condensed italic.
static func display() -> Font:
	return _cached(&"display", func() -> Font: return _slanted(CONDENSED_BOLD, 0))


## Screen titles and section headings: like display(), with wider letter spacing.
static func title() -> Font:
	return _cached(&"title", func() -> Font: return _slanted(CONDENSED_BOLD, 2))


## Body text.
static func body() -> Font:
	return _cached(&"body", func() -> Font: return load(BARLOW))


static func bold() -> Font:
	return _cached(&"bold", func() -> Font: return load(BARLOW_BOLD))


## Slanted body text for subtitles and flavor text.
static func italic() -> Font:
	return _cached(&"italic", func() -> Font: return _slanted(BARLOW, 0))


## Stat labels and small caps text.
static func condensed() -> Font:
	return _cached(&"condensed", func() -> Font: return load(CONDENSED))


static func condensed_bold() -> Font:
	return _cached(&"condensed_bold", func() -> Font: return load(CONDENSED_BOLD))


static func _cached(key: StringName, make: Callable) -> Font:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


static func _slanted(path: String, letter_spacing: int) -> Font:
	var variation := FontVariation.new()
	variation.base_font = load(path)
	variation.variation_transform = Transform2D(Vector2(1, 0), Vector2(-ITALIC_SLANT, 1), Vector2.ZERO)
	variation.spacing_glyph = letter_spacing
	return variation
