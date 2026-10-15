# Journey art: era maps and rival portraits

Prompts for ChatGPT, in the same style as the card paintings ([ART_PROMPT.md](ART_PROMPT.md)): paste a master prompt, then replace its `[...]` block with one entry below. One image per message works best.

When you have them, paste them in chat in any order and say which is which; they'll go into `assets/journey/` (maps) and `assets/rivals/` (portraits).

| Art | Size | File |
|---|---|---|
| Era maps (3) + finale | 1024 x 1536 portrait | `map_triassic`, `map_jurassic`, `map_cretaceous`, `map_finale` |
| Rival portraits (16) | 1024 x 1024 square | `<rival id>` (e.g. `rae`, `rory`) |
| Professaur (optional) | 1024 x 1024 square | `professaur` |

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

## Rival portraits

The game shows portraits **cropped to a circle** (with a gold rim), so the face and shoulders must sit inside the middle of the square.

### Portrait master prompt

```
Create a single premium character portrait for the mobile game DINO DUEL: a rival dinosaur-card collector the player battles.
Square format, 1024 x 1024.

CHARACTER
[CHARACTER]

STYLE
- Premium AAA mobile game character art: painterly but realistic, expressive, with cinematic lighting, a warm rim light and rich color.
- Same quality and color richness as premium collectible card art; not a cartoon, not a photo.
- The character is a friendly-but-competitive adventurer in a world where collectors travel through prehistoric eras. Suitable for players aged 13+.

COMPOSITION
- Head and shoulders, facing the viewer or slightly turned, with a strong, readable expression that shows their personality.
- The portrait will be cropped to a CIRCLE: keep the whole face, hair and shoulders inside the central circle, with nothing important near the corners.
- Softly blurred prehistoric background that matches their era, with simple shapes so the face stands out.

DO NOT include: any text, letters, logos, names, numbers, frames, borders, badges, UI, or other people.
```

### Character fill-ins

The background era follows their chapter. Rory has one portrait, used for all four of his battles.

**Rookie Rae** (`rae`): Triassic
```
A cheerful young teen girl, about 13, just starting out as a collector. Freckles, a messy auburn ponytail under a slightly too-big explorer cap,
an oversized backpack strap on her shoulder and a toy-like fossil tooth necklace. A big eager grin, ready to bite into her first battle.
Background: warm red-rock Triassic desert at dawn.
```

**Ranger Fern** (`fern`): Triassic
```
A calm park ranger in her thirties, Black, with short natural hair under a ranger's hat, a green ranger uniform with a fern-leaf patch.
Arms folded in a steady, defensive stance and a patient, knowing half-smile. Background: a green Triassic oasis of ferns and cycads.
```

**Captain Cora** (`cora`): Triassic
```
A bold sea captain in her forties, Latina, with a long dark braid, a weathered navy captain's coat and cap, sea spray in the air.
A fearless, charging-forward grin. Background: a sunlit Triassic shoreline with waves.
```

**Glider Gus** (`gus`): Triassic
```
A playful young man in his early twenties, East Asian, with windswept hair, aviator goggles pushed up on his forehead,
a leather flight jacket and a scarf blowing in the wind. A mischievous, quick-thinking smile. Background: open Triassic sky over red cliffs.
```

**Dusty Dunes** (`dusty`): Triassic
```
A rugged old desert prospector in his sixties, white, with a dust-covered wide-brimmed hat, a red bandana, a bushy grey mustache and sun-creased skin.
Squinting, tough and unimpressed. Background: dusty red Triassic badlands under a hot sun.
```

**Rival Rory** (`rory`): all eras
```
The player's recurring rival: a confident teen boy, about 16, South Asian, with sharp styled black hair, a sleek red-and-black explorer jacket,
a glowing high-tech time-travel device on his wrist and a fossil claw pendant. A cocky, challenging smirk: always one era ahead.
Background: a swirl of prehistoric scenery with a hint of glowing time-travel light.
```

**Pilot Pip** (`pip`): Jurassic
```
A small, energetic young pilot in their late teens, Pacific Islander, with a feathered aviator cap and a bomber jacket covered in feather patches.
A mischievous copycat grin, one eyebrow raised. Background: a Jurassic sky with pterosaurs over a lagoon.
```

**Marina Marsh** (`marina`): Jurassic
```
A focused marine biologist in her late twenties, Southeast Asian, with damp dark hair, a wetsuit and a dive mask pushed up on her head.
Calm, patient eyes that suddenly look ready to strike. Background: blue-green Jurassic lagoon water and sunbeams.
```

**Hiker Hank** (`hank`): Jurassic
```
A burly hiker in his fifties, white, with a big ginger beard, heavy padded hiking gear like armor and a walking staff.
A stubborn, determined frown. Background: a misty Jurassic conifer forest.
```

**Sage Sela** (`sela`): Jurassic
```
A wise strategist in her sixties, Middle Eastern, with silver hair in a loose bun, round glasses, layered scarves and a battered notebook full of battle notes.
A knowing smile, as if she already knows your next move. Background: a quiet Jurassic forest clearing with soft light.
```

**Boulder Bo** (`bo`): Jurassic
```
A huge, gentle giant of a man in his thirties, Black, with a shaved head, broad shoulders, rock-climbing gear and chalk-dusted hands.
A calm, unshakeable expression. Background: giant Jurassic cliffs with sauropods in the far distance.
```

**Tracker Tia** (`tia`): Cretaceous
```
A sharp-eyed tracker in her twenties, Indigenous South American, with a hooded cloak, striped face paint and a claw-shaped earring.
An intense, hunting gaze. Background: a Cretaceous floodplain with tall grass-like ferns.
```

**Storm Sully** (`sully`): Cretaceous
```
A wild storm chaser in his thirties, Irish, with messy red hair, a soaked yellow raincoat and wind whipping around him.
An excited, daredevil grin. Background: a stormy Cretaceous sky with lightning and pterosaurs.
```

**Deep-Sea Della** (`della`): Cretaceous
```
A deep-sea diver in her forties, Black, with short grey-streaked hair, a vintage brass diving suit with the helmet tucked under one arm.
A cool, deep-water calm. Background: dark blue Cretaceous ocean with glowing bioluminescence and the shadow of a huge sea reptile.
```

**Vera Volcano** (`vera`): Cretaceous
```
A fearless volcanologist in her thirties, Latina, with a reflective silver heat suit, the hood down, ash on her cheeks and dark curls.
A fierce, confident smile. Background: a glowing orange Cretaceous lava field and an erupting volcano.
```

**Old Grit** (`grit`): Cretaceous
```
A legendary veteran collector in his seventies, East Asian, with a weathered fedora, a scarred face, a long grey beard and an amber pendant with a trapped insect.
Calm, quietly dangerous eyes. Background: a dramatic Cretaceous sunset with a T. rex silhouette far away.
```

**The Professaur** (`professaur`, optional): matches the new portraits; replaces the drawn placeholder in his speech box
```
A cheerful, eccentric paleontology professor in his sixties, with wild grey hair, a tweed jacket with elbow patches, a safari hat,
a magnifying glass and a dinosaur-patterned bow tie. A warm, slightly smug expression, as if he refuses to take questions.
Background: a fossil camp with tents and dig sites, soft morning light.
```
