class_name Palette
extends RefCounted
## Placeholder colors until the Blender card art exists.

const BACKGROUND := Color("1b2130")
const PANEL := Color("262e40")
const TEXT := Color("f2f4f8")
const TEXT_DIM := Color("aab2c5")
const DAMAGE := Color("ff6b5e")
const HEAL := Color("7be38b")
const HIGHLIGHT := Color("ffd166")

## Indexed by DinoDef.DinoType.
const TYPE_COLORS: Array[Color] = [Color("6b7f3a"), Color("3d8ccf"), Color("1f5a7a")]
## Indexed by DinoDef.Rarity.
const RARITY_COLORS: Array[Color] = [
	Color("a0a4ab"), Color("57c26a"), Color("4aa8ff"), Color("b46bff"), Color("ffc23d"),
]


static func health_color(fraction: float) -> Color:
	if fraction > 0.5:
		return Color("5fd068")
	if fraction > 0.25:
		return Color("f2c94c")
	return Color("eb5757")
