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

## Amber for a duplicate, indexed by rarity. Lowered by Jo (2026-10-15): at 7/25/60/180/480 a
## clutch of duplicates melted back into ~75% of its price, so buying clutches paid for itself.
const MELT_VALUE: Array[int] = [5, 10, 30, 60, 300]
## Amber to craft a specific dino, indexed by rarity.
const CRAFT_COST: Array[int] = [40, 100, 400, 1000, 2000]

## Rare clutches (Jo, 2026-10-09): same 3 eggs and the same hatch, better odds, bought with Amber
## (and the 7th day of the daily check-in). Indexed by rarity; must add up to 1.
const RARE_CLUTCH_PRICE := 500
const RARE_CLUTCH_ODDS: Array[float] = [0.30, 0.40, 0.16, 0.09, 0.05]

## Daily check-in: each day gives DAILY_CLUTCHES plus the bonus for the streak day it's on, then
## moves to the next day (after day 7, back to day 1). Missing a day pauses the streak instead of
## resetting it (Jo, 2026-10-09). Keys: "amber", "clutches", "rare_clutches".
const CHECKIN_BONUSES: Array[Dictionary] = [
	{"amber": 25}, {"amber": 50}, {"clutches": 1}, {"amber": 75}, {"amber": 100}, {"clutches": 1},
	{"rare_clutches": 1},
]

## A win always gives WIN_CLUTCHES. Outside the Journey (sims, old calls) a win also gives WIN_AMBER.
const WIN_AMBER := 25
const WIN_CLUTCHES := 1
const LOSS_AMBER := 10
## The Journey (Jo, 2026-10-15), indexed by chapter (Triassic, Jurassic, Cretaceous, finale).
## First clear of a stage: JOURNEY_WIN_AMBER + JOURNEY_FIRST_CLEAR_AMBER; a boss's first clear
## gives BOSS_FIRST_CLEAR_RARE_CLUTCHES instead of the Amber bonus (the finale's
## FINALE_FIRST_CLEAR_RARE_CLUTCHES). Replays (any win after the first): REPLAY_AMBER.
const JOURNEY_WIN_AMBER: Array[int] = [25, 35, 50, 50]
const JOURNEY_FIRST_CLEAR_AMBER: Array[int] = [50, 100, 150, 0]
const BOSS_FIRST_CLEAR_RARE_CLUTCHES := 1
const FINALE_FIRST_CLEAR_RARE_CLUTCHES := 2
const REPLAY_AMBER := 10
const CLUTCH_PRICE := 150
const DAILY_CLUTCHES := 1

## New players get these 5 Commons, then pick one partner from STARTER_PARTNERS to make the 6 they
## bring. Protoceratops, Rhamphorhynchus and Hesperornis make a Balanced party (Land, Sky, Sea);
## Tanystropheus completes a Triassic one with Coelophysis and Eudimorphodon (era bond + Balanced).
## All Commons on purpose: the rival ladder (tools/rival_ladder.gd) is tuned to this strength.
const STARTER_BASICS: Array[StringName] = [
	&"coelophysis", &"eudimorphodon", &"protoceratops", &"rhamphorhynchus", &"hesperornis",
]
## The first-launch partner choice: one Land, one Sky, one Sea, all Rare.
const STARTER_PARTNERS: Array[StringName] = [&"dilophosaurus", &"archaeopteryx", &"tanystropheus"]
const STARTER_CLUTCHES := 1
## Reward for finishing the new-player "First steps" checklist.
const FIRST_STEPS_CLUTCHES := 1
