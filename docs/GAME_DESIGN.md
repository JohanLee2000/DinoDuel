# Dino Duel: Game Design

Living document. Decisions marked **(decided)** were chosen by Jo; everything else is a working proposal to tune in playtests.

## Pitch
A portrait mobile game about collecting and battling prehistoric creatures. You play a time-traveling fossil hunter: hatch fossil eggs to grow your collection, pick a party, and beat a journey of rival collectors from the Triassic to the Cretaceous. 1v1 against AI now, against people later. Offline, saves on device.

## Cards (decided)
Every card is a dinosaur (broadly: Land, Sky and Sea creatures).

| Field | Values |
|---|---|
| Type | Land, Sky, Sea |
| Era | Triassic, Jurassic, Cretaceous |
| Tier (rarity) | N Common, R Rare, SR Super Rare, SSR Epic, UR Legendary |
| Stats | Attack, Defense, Speed, Health |
| Ability | None at launch of M1. Decide after the M1 playtest. The data model reserves an `ability_id`. |

Shiny variants: same stats, special look, shareable. Cosmetic only.

## Party Battle (decided)
- Each side **brings 6** dinos, both lineups are revealed, then each side **secretly picks 3**.
- One dino is **active**, the other two wait on the **bench**. Knock out the whole enemy party to win.
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

### Party rules (proposal)
- Party Points: N 1, R 2, SR 3, SSR 4, UR 5. The 3 you pick must total **10 or less**. Journey levels may change the cap. A party of 6 whose 3 cheapest cost more than the cap can't battle; the Party and Battle tabs say so.
- **Era bond:** all 3 from the same era: +1 Attack and +1 Speed each.
- **Balanced party:** one Land, one Sky, one Sea: +2 max Health each.
- **Meteor shower (stall breaker):** from turn 20, both active dinos take rising damage at the end of each turn. It can bring a dino to 1 HP but never knocks one out itself (this cut draws from ~13% to under 1% in the balance sim).

### AI rivals
The AI simulates every (its move, your move) pair one turn ahead, guesses your move from both reasoning and **your habits so far** (it learns if you always Bite), then picks with some randomness. `temperature` is the difficulty knob per rival; `*_bias` values give a rival a learnable personality. Balance sim (600 battles): the AI beats always-Bite 91%, always-Charge 100%, always-Brace 87%.

## Collection (decided)
- Rewards come as a **clutch of 3 fossil eggs**; each egg hatches **one dino**. First tap cracks the egg and its **glow shows the rarity**; second tap hatches it.
- Clutches are **earned only**: win a battle (1 clutch + 25 Amber; a loss gives 10 Amber), one free clutch per calendar day, or buy one for 150 Amber. No real-money eggs.
- Odds per egg: N 50%, R 30%, SR 13%, SSR 5%, UR 2%. Shiny 1 in 40 (cosmetic). If 9 clutches in a row had no Epic+, the 10th is guaranteed one (SSR 80% / UR 20%). Odds are shown on the Eggs tab.
- **Duplicates auto-melt into Amber** (N 7, R 25, SR 60, SSR 180, UR 480). A Shiny duplicate upgrades a non-Shiny copy instead.
- **Crafting** from the Dex: N 40, R 100, SR 400, SSR 1000, UR 2000 Amber.
- New players start with Coelophysis, Eudimorphodon, Nothosaurus, Stegosaurus, Rhamphorhynchus and Ichthyosaurus (two ready-made parties) and 1 clutch.
- **Party:** you bring 6; before each battle you see the rival's 6 and pick 3.
- **Dino Dex:** grouped by era; owned dinos show in full, dinos you've faced show faded, the rest are "???".
- Results are rolled and saved before the hatch animation plays, so closing the app can't reroll a clutch.

## Art and UI direction (decided)
The look follows Jo's ChatGPT concept sheet, saved at `docs/concept/card_concept_sheet.webp` (it replaced two earlier directions: cartoony "Bright and bold", then a realistic stone-frame card).
- **Cards (every tier):** full-bleed portrait painting inside a glowing neon frame in the tier color. Top-left: tier crest (N, R, SR, SSR, UR; SSR and UR wear a crown) with the Party Point cost under it. Top-right: type medallion with LAND / SKY / SEA under it. Bottom: angled name banner with the dino's title (e.g. "King of the Cretaceous"), then four stat boxes (ATK sword, DEF shield, SPD feather, HP heart). Card proportions about 1 : 1.68. The 2:3 painting is shown at the full width inside the frame, top-aligned, so it's never cropped; it fades into the dark panel behind the name and stats at the bottom.
- **Tier colors:** N steel, R green, SR purple, SSR gold, UR magenta with a color-cycling frame. SSR and UR frames pulse.
- **Shiny:** color-shifting frame plus a rainbow holo sheen over the painting.
- **Types:** Land = gold mountain, Sea = blue wave, Sky = white bird, each in a glossy round medallion.
- **Card back:** dark stone with blue claw marks and the logo. Used for undiscovered Dex entries and for the hatch reveal (the card pops up face down, then flips).
- **Branding:** the DINO DUEL wordmark sits in the app's top bar, on the splash screen and on the app icon. The current files are cut from the concept sheet (`tools/extract_branding.py`); full-resolution exports can replace them in `assets/branding/` under the same names.
- **Fonts:** Barlow (body) and Barlow Condensed bold italic (names, numbers, headings, buttons). SIL Open Font License.
- **App UI:** deep navy textured background, navy panels with steel-blue borders, glowing gold primary buttons, uppercase italic headings.
- **Dino art:** one 2:3 portrait painting per dino (plus an optional Shiny version), generated by Jo with ChatGPT. See docs/ART_BRIEF.md. Until a painting exists, cards show a habitat gradient with a silhouette.
- **Card details** that don't fit on the face (group, era, size, matchups, Party Points, the real fact) show in the full-screen view when a card is held.
- **Hatching:** one egg at a time. Tap: shake, crack, rarity-colored glow. Tap again: escalating shake (longer for rarer), shell pieces burst, rays in the tier color, the card pops up face down and flips; SSR and UR add a screen shake and flash. Summary of the clutch at the end, with a skip button.

## App layout (decided)
Bottom tabs: **Battle** (rivals), **Party** (pick your 6), **Eggs** (hatch, daily, buy, odds), **Dex** (collection, crafting). Top bar shows Amber and clutches.

## Journey (proposal)
Chapters by era: Triassic, Jurassic, Cretaceous. About 6 rivals per chapter plus a boss with an Alpha dino. Each rival has a learnable habit (e.g. always Braces after being hit). Final boss: the meteor. Up to 3 stars per level: win, win without losing a dino, win within N turns.

## Monetization (decided)
Free to play. IAP sells era expansions (new chapter plus its cards in eggs) and cosmetics. No paid randomized packs, nothing that buys power.

## Sharing (from the brief)
Deck codes and "ghost duels" (fight a friend's party as AI), challenge codes with fixed seeds, Shiny pull and end-of-battle share images. Later: daily challenge, Play Games leaderboards, Expedition (roguelike) mode on the same battle engine.

## PvP (future)
Needs a server for online play (Play Games multiplayer APIs were shut down in 2020). The battle engine is pure, deterministic code with no UI dependencies so it can run on a server later.

## First set: 15 dinos (first pass)
| Dino | Type | Era | Tier | Atk | Def | Spd | HP |
|---|---|---|---|---|---|---|---|
| Coelophysis | Land | Triassic | N | 5 | 1 | 7 | 10 |
| Stegosaurus | Land | Jurassic | R | 3 | 4 | 2 | 15 |
| Velociraptor | Land | Cretaceous | SR | 6 | 1 | 9 | 11 |
| Triceratops | Land | Cretaceous | SR | 6 | 3 | 3 | 17 |
| T. rex | Land | Cretaceous | UR | 9 | 2 | 4 | 20 |
| Eudimorphodon | Sky | Triassic | N | 4 | 0 | 9 | 10 |
| Rhamphorhynchus | Sky | Jurassic | N | 5 | 0 | 8 | 9 |
| Archaeopteryx | Sky | Jurassic | R | 6 | 1 | 10 | 11 |
| Pteranodon | Sky | Cretaceous | SR | 7 | 1 | 8 | 14 |
| Quetzalcoatlus | Sky | Cretaceous | SSR | 8 | 2 | 6 | 17 |
| Nothosaurus | Sea | Triassic | R | 6 | 1 | 6 | 13 |
| Ichthyosaurus | Sea | Jurassic | N | 5 | 0 | 7 | 11 |
| Plesiosaurus | Sea | Jurassic | R | 6 | 1 | 5 | 13 |
| Liopleurodon | Sea | Jurassic | SSR | 9 | 2 | 3 | 16 |
| Mosasaurus | Sea | Cretaceous | UR | 10 | 1 | 5 | 20 |

## Milestones
1. **M1: Battle on your phone.** Battle engine + tests + balance sim, party pick and battle screens with placeholder cards, one AI rival, Android debug build.
2. **M2: Collecting.** Egg clutches, Amber, Dino Dex with crafting, party of 6, bottom tabs, save file.
3. **M3: Journey.** Rivals, boss, stars, rewards. Start recruiting closed-test testers.
4. Then: Blender art pipeline, sharing, IAP, store listing, closed test.
