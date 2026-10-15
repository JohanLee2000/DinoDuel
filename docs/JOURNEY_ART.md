# Journey art: era maps and rival portraits

Prompts for ChatGPT, in the same style as the card paintings ([ART_PROMPT.md](ART_PROMPT.md)): paste a master prompt, then replace its `[...]` block with one entry below. One image per message works best.

When you have them, paste them in chat in any order and say which is which; they'll go into `assets/journey/` (maps) and `assets/rivals/` (sprites).

| Art | Size | File | Status |
|---|---|---|---|
| Era maps (3) + finale | 1024 x 1536 portrait | `map_triassic`, `map_jurassic`, `map_cretaceous`, `map_finale` | Done (2026-10-15) |
| Rival sprites (16) | 1024 x 1024 square, pixel art | `<rival id>` (e.g. `rae`, `rory`) | Waiting |
| Professaur (optional) | 1024 x 1024 square, pixel art | `professaur` | Waiting |

---

## Era maps

The game draws the stage markers (portraits, stars, the boss crown) on top of these, so the paintings must have **no text, no numbers, no markers and no people**, and the six stops must be clear, empty spots on the trail.

### Map master prompt

```
Create a single premium hand-painted adventure map for the mobile game DINO DUEL, used as a level-select screen.
Portrait format, 1024 x 1536.

ERA
[ERA]

VIEW AND LAYOUT
- A three-quarter top-down view of one continuous prehistoric landscape, like a beautifully painted world map in a AAA mobile adventure game.
- One clear, light-colored winding trail climbs from the bottom center of the image to the upper part, zig-zagging left and right so it fills the frame.
- Along the trail are exactly SIX stopping points, evenly spaced from bottom to top, each an open, flat, empty clearing about the size of a coin on the map:
  stop 1 near the bottom center, stop 2 lower right, stop 3 middle left, stop 4 middle right, stop 5 upper left,
  and stop 6 near the top center: a larger, dramatic landmark plateau for the chapter boss.
- Keep every stop at least 10% away from the image edges, and keep each clearing empty: no creatures, rocks or plants on top of them.
- The trail must stay easy to follow at a glance, with good contrast against the scenery.

STYLE
- Rich, cinematic, painterly game art with golden-hour lighting, atmospheric depth, mist and light rays.
- Same quality and color richness as premium collectible card art: vivid but natural colors, detailed textures, no cartoon look.
- Small prehistoric creatures may appear in the scenery away from the trail (herds in the distance, flyers in the sky), tiny and in scale, never on a stop.

DO NOT include: any text, letters, numbers, labels, map legends, icons, markers, pins, flags, arrows, UI, borders, frames, people, buildings or roads.
```

### Era fill-ins

**Triassic** (`map_triassic`)
```
The Triassic period, about 230 million years ago, on the supercontinent Pangaea.
A warm, arid land of red and orange sandstone mesas, dry riverbeds and sun-baked flats, with green oases of ferns, horsetails, cycads and early conifers along a winding river.
A shallow sea glitters along one side. Small early dinosaurs and crocodile-like reptiles in the far distance, a few gliding reptiles in the sky.
Warm dawn light. The boss plateau at the top is a towering red sandstone mesa with a flat summit.
```

**Jurassic** (`map_jurassic`)
```
The Jurassic period, about 150 million years ago.
A lush green world of towering conifer and araucaria forests, giant ferns, waterfalls, a river delta and blue lagoons.
Herds of long-necked sauropods far in the distance, pterosaurs circling above the lagoon.
Bright midday sun breaking through mist. The boss plateau at the top is a high cliff overlooking a waterfall and lagoon.
```

**Cretaceous** (`map_cretaceous`)
```
The Late Cretaceous period, about 68 million years ago.
Floodplains with the first flowering plants (magnolias), open grassland-like meadows of ferns, a wide river and an inland seaway coastline, with a smoking volcano on the horizon.
Herds of horned and duck-billed dinosaurs far in the distance, giant pterosaurs over the sea.
Dramatic sunset light. The boss plateau at the top is a rocky outcrop near the volcano.
High in the sky, a faint, bright comet streak foreshadows what's coming.
```

**Finale: Extinction Day** (`map_finale`)
```
The last day of the Cretaceous, 66 million years ago.
Instead of six stops, the trail leads to ONE large, flat rocky arena on a crater rim in the upper middle of the image (ignore the six-stop layout above).
A blazing meteor streaks across a burning orange and violet sky, with smaller fireballs and glowing embers falling.
The Cretaceous landscape below lies in long shadows and smoke: forests, a river, a volcano. Awe-inspiring and dramatic, not gory.
```

---

## Rival sprites (pixel art)

Jo chose pixel-art trainer sprites (2026-10-15), like the battle sprites in classic handheld monster-collecting RPGs: full body, a battle pose, plain background. The prompt describes that style instead of naming a game, because image generators often refuse brand names and a store game shouldn't look like a copy of one.

The game shows the whole sprite in the rival's details and on the battle intro, and a crop of the head and shoulders in the round map markers. It snaps the art to a clean pixel grid and draws it with hard edges, so it stays crisp at any size.

### Sprite master prompt

```
Create a single pixel-art character sprite for the mobile game DINO DUEL: a rival dinosaur-card collector the player battles.
Square canvas, 1024 x 1024.

CHARACTER
[CHARACTER]

PIXEL ART STYLE
- A retro handheld RPG "trainer" battle sprite, like mid-2000s 2D handheld monster-collecting games: crisp pixel art, a limited palette, flat shading with 2-3 tones per color, and a clean dark 1-pixel outline.
- Drawn on a visible pixel grid, as if the original sprite were about 96 x 96 pixels scaled up with hard edges: no blur, no anti-aliasing, no gradients, no painterly texture, no 3D.
- Bright, readable colors and a clear silhouette that still reads at small sizes.

POSE AND FRAMING
- Full body, standing, facing the viewer at a slight three-quarter angle, in a confident battle pose that shows their personality (see CHARACTER).
- Centered, with the whole figure inside the canvas: head near the top, feet near the bottom, a little empty space all around.
- Use the same scale and framing for every character in this series, so they line up side by side.

BACKGROUND
- Transparent background. If transparency isn't possible, one flat pale grey (#E8E8E8) and nothing else.

DO NOT include: text, letters, names, numbers, logos, frames, borders, UI, ground shadows, other characters, creatures, or scenery.
```

### Character fill-ins

Rory has one sprite, used for all four of his battles.

**Rookie Rae** (`rae`): Triassic
```
A cheerful young teen girl, about 13, just starting out as a collector. Freckles, a messy auburn ponytail under a slightly too-big khaki explorer cap,
an oversized backpack, a fossil-tooth necklace, shorts and sneakers.
Pose: leaning forward with one fist pumped and a big eager grin. Accent colors: warm red and sand.
```

**Ranger Fern** (`fern`): Triassic
```
A calm park ranger in her thirties, Black, with short natural hair under a ranger's hat, a green ranger uniform with a fern-leaf patch, and hiking boots.
Pose: arms folded, feet planted, a patient knowing half-smile. Accent colors: forest green and tan.
```

**Captain Cora** (`cora`): Triassic
```
A bold sea captain in her forties, Latina, with a long dark braid, a navy captain's coat and cap with gold buttons, and tall boots.
Pose: pointing forward as if ordering a charge, with a fearless grin. Accent colors: navy and gold.
```

**Glider Gus** (`gus`): Triassic
```
A playful young man in his early twenties, East Asian, with windswept hair, aviator goggles pushed up on his forehead,
a brown leather flight jacket, a long scarf flowing behind him, and cargo pants.
Pose: one arm raised mid-throw, with a quick mischievous smile. Accent colors: brown and sky blue.
```

**Dusty Dunes** (`dusty`): Triassic
```
A rugged old desert prospector in his sixties, white, with a dusty wide-brimmed hat, a red bandana, a bushy grey mustache,
a worn vest and boots, and a pickaxe over one shoulder.
Pose: hand on hip, squinting, unimpressed. Accent colors: dusty red and brown.
```

**Rival Rory** (`rory`): all eras
```
The player's recurring rival: a confident teen boy, about 16, South Asian, with spiky styled black hair, a sleek red-and-black explorer jacket,
a glowing time-travel device on his wrist, a fossil claw pendant, dark pants and sneakers.
Pose: smirking and pointing straight at the viewer as a challenge. Accent colors: red, black and glowing cyan.
```

**Pilot Pip** (`pip`): Jurassic
```
A small, energetic young pilot in their late teens, Pacific Islander, with a feathered aviator cap, a bomber jacket covered in feather patches, and flight boots.
Pose: a cheeky salute with one eyebrow raised and a copycat grin. Accent colors: orange and teal.
```

**Marina Marsh** (`marina`): Jurassic
```
A marine biologist in her late twenties, Southeast Asian, with damp dark hair, a black-and-teal wetsuit, a dive mask pushed up on her head,
and swim fins hooked on her belt.
Pose: a calm, balanced stance with one hand raised, ready to strike. Accent colors: teal and black.
```

**Hiker Hank** (`hank`): Jurassic
```
A burly hiker in his fifties, white, with a big ginger beard, heavy padded hiking gear like armor, a large backpack and a walking staff.
Pose: a wide planted stance, staff thumped on the ground, with a stubborn frown. Accent colors: olive and orange.
```

**Sage Sela** (`sela`): Jurassic
```
A wise strategist in her sixties, Middle Eastern, with silver hair in a loose bun, round glasses, layered scarves and a long coat,
holding an open notebook full of battle notes.
Pose: pushing up her glasses with a knowing smile. Accent colors: plum and gold.
```

**Boulder Bo** (`bo`): Jurassic
```
A huge, gentle giant of a man in his thirties, Black, with a shaved head, very broad shoulders, a rock-climbing harness with a coiled rope,
and chalk-dusted hands.
Pose: arms crossed, towering and calm, with an unshakeable expression. Accent colors: stone grey and rust orange.
```

**Tracker Tia** (`tia`): Cretaceous
```
A sharp-eyed tracker in her twenties, Indigenous South American, with a hooded cloak, striped face paint, a claw-shaped earring,
leather wraps and sandals.
Pose: crouched forward like a hunter about to pounce, with an intense gaze. Accent colors: earthy brown and deep green.
```

**Storm Sully** (`sully`): Cretaceous
```
A wild storm chaser in his thirties, Irish, with messy red hair, a soaked yellow raincoat flapping in the wind, rubber boots,
and a handheld weather gauge.
Pose: one arm thrown up in excitement, with a daredevil grin. Accent colors: yellow and storm grey.
```

**Deep-Sea Della** (`della`): Cretaceous
```
A deep-sea diver in her forties, Black, with short grey-streaked hair, a vintage brass-and-canvas diving suit,
and the round brass helmet tucked under one arm.
Pose: a calm, cool stance with a confident look. Accent colors: brass and deep blue.
```

**Vera Volcano** (`vera`): Cretaceous
```
A fearless volcanologist in her thirties, Latina, with dark curls, a reflective silver heat suit with the hood down, ash smudges on her cheeks,
and heavy gloves.
Pose: one fist raised, with a fierce, confident smile. Accent colors: silver and lava orange.
```

**Old Grit** (`grit`): Cretaceous
```
A legendary veteran collector in his seventies, East Asian, with a weathered fedora, a scarred face, a long grey beard, a long dusty coat,
an amber pendant with a trapped insect, and a cane.
Pose: leaning on his cane, calm and quietly dangerous. Accent colors: dark brown and amber.
```

**The Professaur** (`professaur`, optional): replaces the drawn placeholder in his speech box
```
A cheerful, eccentric paleontology professor in his sixties, with wild grey hair, a safari hat, a tweed jacket with elbow patches,
a dinosaur-patterned bow tie and khaki trousers, holding a magnifying glass.
Pose: wagging one finger mid-lecture, slightly smug, as if he refuses to take questions. Accent colors: tweed brown and green.
```
