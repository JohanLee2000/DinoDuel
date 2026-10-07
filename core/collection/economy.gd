class_name Economy
extends RefCounted
## Every collecting and reward number in one place. First-pass values; tune after playtests.

const EGGS_PER_CLUTCH := 3
## Chance per egg, indexed by DinoDef.Rarity. Must add up to 1.
const RARITY_ODDS: Array[float] = [0.60, 0.25, 0.10, 0.04, 0.01]
const SHINY_ODDS := 1.0 / 40.0
## A clutch is guaranteed an Epic or better if the previous (PITY_CLUTCHES - 1) clutches had none.
const PITY_CLUTCHES := 10
## Odds for the guaranteed egg, indexed by rarity (only Epic and Legendary).
const PITY_ODDS: Array[float] = [0.0, 0.0, 0.0, 0.8, 0.2]

## Amber for a duplicate, indexed by rarity.
const MELT_VALUE: Array[int] = [5, 20, 50, 150, 400]
## Amber to craft a specific dino, indexed by rarity.
const CRAFT_COST: Array[int] = [40, 100, 400, 1000, 2000]

const WIN_AMBER := 25
const WIN_CLUTCHES := 1
const LOSS_AMBER := 10
const CLUTCH_PRICE := 150
const DAILY_CLUTCHES := 1

const STARTER_DINOS: Array[StringName] = [
	&"coelophysis", &"eudimorphodon", &"nothosaurus",
	&"stegosaurus", &"rhamphorhynchus", &"ichthyosaurus",
]
const STARTER_CLUTCHES := 1
