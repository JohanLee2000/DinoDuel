# Dino Duel: Game Design

Living document. Decisions marked **(decided)** were chosen by Jo; everything else is a working proposal to tune in playtests.

## Pitch
A portrait mobile game about collecting and battling prehistoric creatures. You play a time-traveling fossil hunter: hatch fossil eggs to grow your collection, pick a herd, and beat a journey of rival collectors from the Triassic to the Cretaceous. 1v1 against AI now, against people later. Offline, saves on device.

## Cards (decided)
Every card is a dinosaur (broadly: Land, Sky and Sea creatures).

| Field | Values |
|---|---|
| Type | Land, Sky, Sea |
| Era | Triassic, Jurassic, Cretaceous |
| Rarity | Common, Uncommon, Rare, Epic, Legendary |
| Stats | Attack, Defense, Speed, Health |
| Ability | None at launch of M1. Decide after the M1 playtest. The data model reserves an `ability_id`. |

Shiny variants: same stats, special look, shareable. Cosmetic only.

## Herd Battle (decided)
- Each side **brings 6** dinos, both lineups are revealed, then each side **secretly picks 3**.
- One dino is **active**, the other two wait on the **bench**. Knock out the whole enemy herd to win.
- Each turn both players secretly choose one action. The AI's choice is **hidden**, the same as future PvP.

| Action | Effect |
|---|---|
| **Bite** | Normal damage. Bites resolve in Speed order (ties hit simultaneously). |
| **Charge** | Double damage that ignores Brace. Resolves after all Bites. Cancelled if the charger was bitten this turn. |
| **Brace** | Blocks a Bite completely and counter-bites. Can't be used two turns in a row. |
| **Swap** | Resolves first. The incoming dino takes whatever was aimed at the active slot. |

Triangle: **Bite beats Charge, Charge beats Brace, Brace beats Bite.**

### Resolution order
1. Swaps
2. Braces are raised
3. Bites in Speed order (blocked Bites trigger the bracer's counter-bite)
4. Charges in Speed order (skipped if the charger was bitten or knocked out)
5. End of turn: benched dinos heal 1 HP, KOs are replaced, winner is checked

### Damage (decided: type edge = +50%)
`damage = max(1, floor(Attack × 1.5 if type advantage × 2 if Charge) − Defense)`

Type triangle: **Land beats Sky, Sky beats Sea, Sea beats Land.** Land pounces on pterosaurs on the ground, Sky dives on marine reptiles, Sea ambushes land dinos at the water's edge.

### Herd rules (proposal)
- Herd Points: Common 1, Uncommon 2, Rare 3, Epic 4, Legendary 5. The 3 you pick must total **9 or less**. Journey levels may change the cap.
- **Era bond:** all 3 from the same era: +1 Attack and +1 Speed each.
- **Balanced herd:** one Land, one Sky, one Sea: +2 max Health each.
- **Meteor shower (stall breaker):** from turn 20, both active dinos take rising damage at the end of each turn. It can bring a dino to 1 HP but never knocks one out itself (this cut draws from ~13% to under 1% in the balance sim).

### AI rivals
The AI simulates every (its move, your move) pair one turn ahead, guesses your move from both reasoning and **your habits so far** (it learns if you always Bite), then picks with some randomness. `temperature` is the difficulty knob per rival; `*_bias` values give a rival a learnable personality. Balance sim (600 battles): the AI beats always-Bite 91%, always-Charge 100%, always-Brace 87%.

## Collection (decided)
- Packs are **fossil eggs**: tap to crack them open. They are **earned only** (journey wins, daily egg, Amber). No real-money packs.
- Duplicates **melt into Amber**, which crafts a specific card.
- Proposal: 5 cards per egg (3 Common, 1 Uncommon, 1 Rare+ slot at Rare 75% / Epic 20% / Legendary 5%), 1-in-40 Shiny chance, every 10th egg guaranteed Epic+. Odds shown in-game.
- Starter collection: the 6 Commons, which form two ready-made herds (Triassic trio and Jurassic trio, each era-bonded and balanced).

## Journey (proposal)
Chapters by era: Triassic, Jurassic, Cretaceous. About 6 rivals per chapter plus a boss with an Alpha dino. Each rival has a learnable habit (e.g. always Braces after being hit). Final boss: the meteor. Up to 3 stars per level: win, win without losing a dino, win within N turns.

## Monetization (decided)
Free to play. IAP sells era expansions (new chapter plus its cards in eggs) and cosmetics. No paid randomized packs, nothing that buys power.

## Sharing (from the brief)
Deck codes and "ghost duels" (fight a friend's herd as AI), challenge codes with fixed seeds, Shiny pull and end-of-battle share images. Later: daily challenge, Play Games leaderboards, Expedition (roguelike) mode on the same battle engine.

## PvP (future)
Needs a server for online play (Play Games multiplayer APIs were shut down in 2020). The battle engine is pure, deterministic code with no UI dependencies so it can run on a server later.

## First set: 15 dinos (first pass)
| Dino | Type | Era | Rarity | Atk | Def | Spd | HP |
|---|---|---|---|---|---|---|---|
| Coelophysis | Land | Triassic | C | 5 | 1 | 7 | 10 |
| Stegosaurus | Land | Jurassic | C | 4 | 2 | 2 | 13 |
| Velociraptor | Land | Cretaceous | U | 6 | 1 | 9 | 11 |
| Triceratops | Land | Cretaceous | R | 6 | 3 | 3 | 17 |
| T. rex | Land | Cretaceous | L | 9 | 2 | 4 | 20 |
| Eudimorphodon | Sky | Triassic | C | 4 | 0 | 9 | 10 |
| Rhamphorhynchus | Sky | Jurassic | C | 5 | 0 | 8 | 9 |
| Archaeopteryx | Sky | Jurassic | U | 6 | 1 | 10 | 11 |
| Pteranodon | Sky | Cretaceous | R | 7 | 1 | 8 | 14 |
| Quetzalcoatlus | Sky | Cretaceous | E | 8 | 2 | 6 | 17 |
| Nothosaurus | Sea | Triassic | C | 5 | 1 | 4 | 11 |
| Ichthyosaurus | Sea | Jurassic | C | 5 | 0 | 7 | 11 |
| Plesiosaurus | Sea | Jurassic | U | 6 | 1 | 5 | 13 |
| Liopleurodon | Sea | Jurassic | U | 7 | 2 | 3 | 13 |
| Mosasaurus | Sea | Cretaceous | R | 8 | 1 | 4 | 15 |

## Milestones
1. **M1: Battle on your phone.** Battle engine + tests + balance sim, herd pick and battle screens with placeholder cards, one AI rival, Android debug build.
2. **M2: Collecting.** Eggs, Amber, Dino Dex, herd builder (bring 6), save file.
3. **M3: Journey.** Rivals, boss, stars, rewards. Start recruiting closed-test testers.
4. Then: Blender art pipeline, sharing, IAP, store listing, closed test.
