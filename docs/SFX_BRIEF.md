# Sound effects brief

Prompts for replacing the Kenney placeholder effects with AI-generated ones. Use a tool and plan whose terms allow commercial use (keep a note of which). Anything not replaced keeps its Kenney sound.

To put a sound in (or upload it in chat and I'll do it):

```bash
python tools/prepare_sfx.py "C:/Users/johan/Downloads/my_bite.wav" bite          # replaces all bite variants
python tools/prepare_sfx.py "C:/Users/johan/Downloads/my_bite2.wav" bite --add   # adds another variant
```

It trims the silence, levels the loudness (so the per-sound volumes in `app/sound.gd` stay right) and writes `assets/audio/sfx/<name>.ogg` or `<name>_N.ogg`. The game finds variants by file name; no code changes needed.

Tips:
- Keep effects **dry** (little or no reverb) and **starting instantly** (no silence or build-up before the sound).
- Where it says 2 or 3 variants, generate that many takes; the game picks one at random so repeated hits don't sound copy-pasted. More takes are fine (`bite_4`, ...).
- Style: realistic prehistoric with a punchy mobile-game feel, matching the painted cards. Interface sounds are organic (wood, stone, bone, amber), not electronic beeps.
- Victory and defeat are tiny pieces of music; the music tool may do them better than an effects tool.

| File | Plays when | Length | Prompt |
|---|---|---|---|
| `tap` (done: Jo's click) | Any button press | 0.1 s | A single short, soft click of a small smooth pebble tapped on a wooden board, crisp and dry, no reverb |
| `error` | Tapping something not allowed (e.g. over the point cap) | 0.3 s | Two quick muted knocks on hollow wood, low and friendly, a gentle "nope" for a game menu, dry |
| `card_open` | Holding a card to see it full size | 0.5 s | A thick trading card sliding quickly out of a stack and lifted up, crisp card slide with a soft airy whoosh |
| `card_pick` | Picking or removing a dino for your party | 0.3 s | A thick trading card snapped down onto a wooden table, crisp short card slap |
| `card_flip` | A hatched card flips face up | 0.4 s | A stiff playing card flipped over fast in the air, quick paper flick with a light whoosh |
| `swap_1`, `swap_2` | A dino swaps in or comes in after a knockout | 0.6 s | A fast whoosh of a card sliding away followed by a heavy dinosaur footstep landing on dirt |
| `clutch_open` (done: Jo's sound) | Starting to hatch a clutch, claiming the daily clutch | 1.0 s | Three large stone-like fossil eggs set down one after another on a stone slab, soft heavy clunks, then a faint mysterious shimmer |
| `bite_1`..`bite_3` (synthesized: `tools/synth_sfx.py`) | A Bite or counter-bite lands | 0.5 s | A large predator dinosaur bite, powerful jaws snapping shut with a meaty crunch and a short snarl, close and punchy game impact |
| `charge_1`..`charge_3` (synthesized) | Starts when a Charge lunges; **the big impact must land 0.27 s in**, on the hit | 1.1 s | A heavy dinosaur ramming its target: two fast thundering footsteps then a massive body-slam thud with a short roar, punchy game impact |
| `brace_1`, `brace_2` (synthesized) | A dino raises Brace (shield up) | 0.8 s | A shimmering protective barrier snapping into place: a quick rising crystalline whoosh ending in a bright glassy ting, video game shield sound |
| `block_1`, `block_2` | A Brace blocks a Bite | 0.4 s | Teeth clacking hard against a bony armored plate, a solid blocked hit with a short grunt, punchy and dry |
| `interrupted` | A Charge is cancelled by a Bite | 0.4 s | A dinosaur stumbling mid-run, feet skidding in dirt with a short frustrated snort |
| `ko` | A dino is knocked out | 1.2 s | A large dinosaur collapsing onto the ground, heavy body-fall thud with a fading low groan and dust settling |
| `meteor_1`, `meteor_2` | Meteor shower damage (turn 20 and later) | 1.2 s | A small flaming meteor whistling down and slamming into rocky ground, short descending whistle then a deep rumbling impact with debris |
| `victory` | You win a battle | 2.5 s | Short triumphant victory jingle for a prehistoric adventure game: tribal drums and a bold brass fanfare rising to a bright final chord |
| `defeat` | You lose a battle | 2.0 s | Short defeat jingle for a prehistoric adventure game: one low tribal drum hit and a soft descending horn phrase, disappointed but not gloomy |
| `egg_crack_1`..`egg_crack_3` | First tap on an egg | 0.4 s | A large eggshell cracking under a tap, crisp brittle crack with tiny shell fragments, close up and dry |
| `egg_burst` | The egg breaks open | 0.8 s | A big eggshell bursting apart, shell pieces shattering outward with a bright magical pop |
| `glow` | The cracked egg starts to glow (played higher for rarer eggs) | 0.6 s | A single soft magical chime, like a small crystal bell, with a short gentle sparkle tail |
| `reveal_rare` | A Rare or Super Rare card is revealed | 1.2 s | Short exciting reveal sting for a rare collectible card: quick rising orchestral swell ending on a bright hit with sparkles |
| `reveal_epic` | An Epic or Legendary card is revealed | 2.0 s | Big epic reveal for a legendary collectible card: a thunderous drum hit, a rising choir and brass swell, and a shimmering burst at the end |
| `new_dino` | You hatched or crafted a dino you didn't have | 0.7 s | A bright, happy "new item collected" sound: two rising marimba notes with a light sparkle |
| `shiny` | A Shiny dino | 1.0 s | Glittering holographic shimmer, a cascade of high crystal chimes sweeping upward, magical and premium |
| `amber` | Gaining or spending Amber (duplicates, buying, crafting) | 0.6 s | A few small amber gemstones clinking together and dropping into a leather pouch, bright and satisfying |
