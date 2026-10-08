class_name Economy
extends RefCounted
## Every collecting and reward number in one place. First-pass values; tune after playtests.

const EGGS_PER_CLUTCH := 3
## Chance per egg, indexed by DinoDef.Rarity. Must add up to 1.
const RARITY_ODDS: Array[float] = [0.50, 0.30, 0.13, 0.05, 0.02]
const SHINY_ODDS := 1.0 / 40.0
## A clutch is guaranteed an Epic or better if the previous (PITY_CLUTCHES - 1) clutches had none.
const PITY_CLUTCHES := 10
## Odds for the guaranteed egg, indexed by rarity (only Epic and Legendary).
const PITY_ODDS: Array[float] = [0.0, 0.0, 0.0, 0.8, 0.2]

## Amber for a duplicate, indexed by rarity.
const MELT_VALUE: Array[int] = [7, 25, 60, 180, 480]
## Amber to craft a specific dino, indexed by rarity.
const CRAFT_COST: Array[int] = [40, 100, 400, 1000, 2000]

const WIN_AMBER := 25
const WIN_CLUTCHES := 1
const LOSS_AMBER := 10
const CLUTCH_PRICE := 150
const DAILY_CLUTCHES := 1

## New players get these 5, then pick one partner from STARTER_PARTNERS to make the 6 they bring.
## Stegosaurus, Rhamphorhynchus and Ichthyosaurus are a ready-made Jurassic party (era bond and
## Balanced); Tanystropheus completes a Triassic one with Coelophysis and Eudimorphodon.
const STARTER_BASICS: Array[StringName] = [
	&"coelophysis", &"eudimorphodon", &"stegosaurus", &"rhamphorhynchus", &"ichthyosaurus",
]
## The first-launch partner choice: one Land, one Sky, one Sea, all Rare.
const STARTER_PARTNERS: Array[StringName] = [&"dilophosaurus", &"archaeopteryx", &"tanystropheus"]
const STARTER_CLUTCHES := 2
