class_name Palette
extends RefCounted
## Colors from the concept sheet (docs/concept/): deep navy UI, neon tier colors, glossy types.

const BACKGROUND := Color("0a111f")
const PANEL := Color("101b2e")
const PANEL_BORDER := Color("22406a")
const TEXT := Color("eaf2ff")
const TEXT_DIM := Color("8fa3bf")
const ACCENT := Color("4da8ff")
const HIGHLIGHT := Color("ffd34d")
const DAMAGE := Color("ff5a6a")
const HEAL := Color("4cd964")
const INK := Color("0b1220")
const OUTLINE := Color("05080f")

## Indexed by DinoDef.DinoType: Land gold, Sky pale blue, Sea ocean blue.
const TYPE_COLORS: Array[Color] = [Color("f2a93b"), Color("8fd3ff"), Color("2e8bff")]
const TYPE_LABELS: Array[String] = ["LAND", "SKY", "SEA"]
## Indexed by DinoDef.Rarity (N, R, SR, SSR, UR). UR also cycles through colors on cards.
const RARITY_COLORS: Array[Color] = [
	Color("9db0c8"), Color("3ddc84"), Color("b05cff"), Color("ffb22e"), Color("ff4fb0"),
]
## Attack, Defense, Speed, Health.
const STAT_COLORS: Array[Color] = [Color("ff4d5e"), Color("3e8bff"), Color("4cd964"), Color("ff6fb5")]
const STAT_ICONS: Array[StringName] = [&"stat_attack", &"stat_defense", &"stat_speed", &"stat_health"]
const STAT_NAMES: Array[String] = ["Attack", "Defense", "Speed", "Health"]
const STAT_CODES: Array[String] = ["ATK", "DEF", "SPD", "HP"]


static func health_color(fraction: float) -> Color:
	if fraction > 0.5:
		return Color("4cd964")
	if fraction > 0.25:
		return Color("ffb22e")
	return Color("ff4d5e")
