# Dino Duel: Art Brief for AI-Generated Card Paintings

How to make the 2D dinosaur paintings with ChatGPT image generation so every card looks like it belongs to one set.

## What each dino needs

| File | Shape | Used for |
|---|---|---|
| `<id>.png` | Portrait 2:3 (ChatGPT "1024×1536") | The card painting. Every card is full-art |
| `<id>_shiny.png` | Portrait 2:3 | Optional Shiny version: same animal and pose in a rare color morph. Falls back to the normal painting |

`<id>` is the dino's id, as listed in the first column of the table below (it's also the file name in `data/dinos/`).

**Getting them into the game:** save ChatGPT's downloads into any folder with those file names, then run

```bash
python tools/prepare_art.py "path/to/your/downloads"
```

It resizes them for phones and saves WebP copies into `assets/dinos/`. The cards pick them up automatically; nothing else to wire up.

## Composition rules

- Portrait 2:3. Cards show the painting at the full width inside the frame, anchored to the top, so **nothing is cropped**.
- **The bottom fifth fades into the dark panel behind the name banner and stat boxes**, so keep the head and key action in the top 80%.
- **The top corners** (about a quarter of the width and the top fifth on each side) sit under the tier crest and type medallion. Keep eyes and jaws out of them.
- **Shiny:** identical composition; only the animal's coloring changes (e.g. pale silver-white with iridescent blue-green highlights).
- No text, frames, borders, logos or watermarks in the image. The card adds all of that.

## The master prompt

Jo's master prompt lives in [ART_PROMPT.md](ART_PROMPT.md). Paste it into ChatGPT and fill in the three placeholders from this table. Use the game's tier names for `[RARITY]` (the prompt also describes ULTRA RARE, which isn't a tier in the game; UR cards are LEGENDARY).

| id | `[DINOSAUR]` | `[TYPE]` | `[RARITY]` | Status |
|---|---|---|---|---|
| `t_rex` | Tyrannosaurus rex | LAND | LEGENDARY (UR) | Done |
| `quetzalcoatlus` | Quetzalcoatlus | SKY | EPIC (SSR) | Done |
| `triceratops` | Triceratops | LAND | SUPER RARE (SR) | Done |
| `pteranodon` | Pteranodon | SKY | SUPER RARE (SR) | In game; the painting shows teeth, but Pteranodon was toothless |
| `mosasaurus` | Mosasaurus | SEA | LEGENDARY (UR) | Done |
| `velociraptor` | Velociraptor | LAND | SUPER RARE (SR) | Done |
| `archaeopteryx` | Archaeopteryx | SKY | RARE (R) | Done |
| `plesiosaurus` | Plesiosaurus | SEA | RARE (R) | Done |
| `liopleurodon` | Liopleurodon | SEA | EPIC (SSR) | Done |
| `coelophysis` | Coelophysis | LAND | COMMON (N) | Done |
| `stegosaurus` | Stegosaurus | LAND | RARE (R) | Done |
| `eudimorphodon` | Eudimorphodon | SKY | COMMON (N) | Done |
| `rhamphorhynchus` | Rhamphorhynchus | SKY | COMMON (N) | Done |
| `nothosaurus` | Nothosaurus | SEA | RARE (R) | Done |
| `ichthyosaurus` | Ichthyosaurus | SEA | COMMON (N) | Done |
| `postosuchus` | Postosuchus | LAND | RARE (R) | Done |
| `plateosaurus` | Plateosaurus | LAND | COMMON (N) | Done |
| `icarosaurus` | Icarosaurus | SKY | COMMON (N) | Done |
| `tanystropheus` | Tanystropheus | SEA | RARE (R) | Done |
| `shonisaurus` | Shonisaurus | SEA | EPIC (SSR) | Done |
| `allosaurus` | Allosaurus | LAND | SUPER RARE (SR) | Done |
| `brachiosaurus` | Brachiosaurus | LAND | LEGENDARY (UR) | Done |
| `dilophosaurus` | Dilophosaurus | LAND | RARE (R) | Done |
| `dimorphodon` | Dimorphodon | SKY | COMMON (N) | Done |
| `pterodactylus` | Pterodactylus | SKY | COMMON (N) | Done |
| `spinosaurus` | Spinosaurus | LAND | EPIC (SSR) | Done |
| `ankylosaurus` | Ankylosaurus | LAND | SUPER RARE (SR) | Done |
| `parasaurolophus` | Parasaurolophus | LAND | COMMON (N) | Done |
| `archelon` | Archelon | SEA | RARE (R) | Done |
| `microraptor` | Microraptor | SKY | RARE (R) | Done |

Adding the species notes below to `[DINOSAUR]` (e.g. "Velociraptor, turkey-sized and fully feathered") helps ChatGPT get the anatomy right.

## Species notes (the accuracy details that matter)

| id | Subject and habitat |
|---|---|
| `coelophysis` | A Coelophysis, a slender Late Triassic theropod about 3 m long, long neck, narrow head with small serrated teeth, light build, scaly skin. Habitat: dry Triassic floodplain with conifers, ferns and reddish soil. |
| `stegosaurus` | A Stegosaurus, Late Jurassic plated dinosaur: two alternating rows of tall diamond-shaped back plates, four long tail spikes, small head held low. Habitat: Jurassic floodplain with ferns, cycads and tall conifers. |
| `velociraptor` | A Velociraptor, a turkey-sized Late Cretaceous dromaeosaur **fully covered in feathers**, feathered arms like small wings, long stiff tail, enlarged sickle claw on each foot. Habitat: windswept Cretaceous desert with sand dunes (Mongolia). |
| `triceratops` | A Triceratops, a large Late Cretaceous horned dinosaur: two long brow horns, a short nose horn, a broad solid bony frill, parrot-like beak, heavy four-legged body. Habitat: lush Cretaceous river plain with conifers and early flowering plants. |
| `t_rex` | A Tyrannosaurus rex, a massive Late Cretaceous tyrannosaur: deep powerful skull, forward-facing eyes, **lips covering the teeth when the mouth is closed**, small two-fingered arms, scaly skin. Habitat: misty Cretaceous forest edge at dawn. |
| `eudimorphodon` | A Eudimorphodon, a small Late Triassic pterosaur with about a 1 m wingspan, short head with many tiny teeth, long tail, skin-membrane wings, fine fuzzy body covering. Habitat: flying over a Triassic coastal lagoon. |
| `rhamphorhynchus` | A Rhamphorhynchus, a Late Jurassic long-tailed pterosaur: diamond-shaped vane at the tail tip, long jaws with forward-pointing needle teeth, catching a fish. Habitat: skimming a shallow Jurassic lagoon. |
| `archaeopteryx` | An Archaeopteryx, a crow-sized Late Jurassic feathered dinosaur: fully feathered wings with three clawed fingers, long feathered bony tail, small toothed jaws, mostly black feathers. Habitat: perched on a branch on an arid Jurassic island (Solnhofen, Germany). |
| `pteranodon` | A Pteranodon, a large Late Cretaceous pterosaur with about a 6 m wingspan, long **toothless** beak and a long backswept head crest, soaring. Habitat: over a Cretaceous inland sea with distant cliffs. |
| `quetzalcoatlus` | A Quetzalcoatlus, a giant pterosaur with about a 10 m wingspan, very long stiff neck and huge pointed beak, **standing on all four limbs with wings folded**, stalking prey on the ground like a giant stork. Habitat: open Late Cretaceous plain. |
| `nothosaurus` | A Nothosaurus, a Triassic marine reptile about 3 m long: long neck and tail, flat head with long interlocking fang-like teeth, paddle-like webbed limbs, swimming. Habitat: shallow sunlit Triassic sea with a rocky shore. |
| `ichthyosaurus` | An Ichthyosaurus, a dolphin-shaped Early Jurassic marine reptile about 2 m long: large eyes, long narrow snout, dorsal fin, crescent-shaped tail fin, dark back and lighter belly. Habitat: open Jurassic ocean with sunbeams from above. |
| `plesiosaurus` | A Plesiosaurus, an Early Jurassic marine reptile about 3.5 m long: small head on a long neck, broad body, four long flippers, short tail. Habitat: underwater Jurassic sea with ammonites. |
| `liopleurodon` | A Liopleurodon, a Jurassic pliosaur about 6–7 m long (not giant): short neck, massive elongated head with conical teeth, four powerful flippers. Habitat: deep blue Jurassic sea. |
| `mosasaurus` | A Mosasaurus, a giant Late Cretaceous marine lizard: long powerful body, large jaws with conical teeth, paddle flippers, shark-like tail fluke. Habitat: Cretaceous ocean near the surface, dramatic light. |
| `postosuchus` | A Postosuchus, a Late Triassic crocodile-line predator (rauisuchid) about 5 m long: deep narrow skull with large serrated teeth, rows of bony armor plates along the back, long tail, standing tall on fairly upright legs. Not a dinosaur. Habitat: dry Triassic river valley with conifers. |
| `plateosaurus` | A Plateosaurus, a Late Triassic plant-eating dinosaur 5–10 m long: long neck, small head, bulky body, walking on its hind legs, grasping hands with a large thumb claw. Habitat: Triassic floodplain with conifers and ferns. |
| `icarosaurus` | An Icarosaurus, a tiny Late Triassic gliding reptile about 10 cm long: lizard-like body with long ribs extended sideways supporting thin skin wings, gliding between trees. Not a pterosaur. Habitat: Triassic forest canopy, close-up with large leaves and sunbeams. |
| `tanystropheus` | A Tanystropheus, a Middle Triassic marine reptile about 6 m long: an extremely long, stiff neck making up half its body, small head with sharp teeth, lizard-like body and limbs, ambushing fish underwater. Habitat: shallow murky Triassic lagoon. |
| `shonisaurus` | A Shonisaurus, a giant Late Triassic ichthyosaur about 15 m long (whale-sized): deep rounded body, long narrow snout, long paddle flippers, crescent tail fin. Habitat: open Triassic ocean with huge scale and light rays from above. |
| `allosaurus` | An Allosaurus, a Late Jurassic predator about 8.5 m long: large head with small hornlets above the eyes, blade-like teeth, strong three-fingered arms with big claws, scaly skin. Habitat: Jurassic floodplain with conifers. |
| `brachiosaurus` | A Brachiosaurus, a Late Jurassic sauropod about 22 m long: front legs longer than back legs, body sloping upward, very long neck held high, small head with a bony arch over the nose, reaching treetops. Habitat: Jurassic forest of tall conifers. |
| `dilophosaurus` | A Dilophosaurus, an Early Jurassic predator about 7 m long: two thin parallel bony crests on the head, slender snout with a notch in the upper jaw, no neck frill. Habitat: Early Jurassic riverbank. |
| `dimorphodon` | A Dimorphodon, an Early Jurassic pterosaur with about a 1.4 m wingspan: very large deep head like a puffin's, two kinds of teeth, long tail, skin-membrane wings. Habitat: Jurassic coastal cliffs. |
| `pterodactylus` | A Pterodactylus, a Late Jurassic pterosaur with about a 1 m wingspan: long narrow jaws with small teeth, a short tail, small soft head crest, slender wings. Habitat: Late Jurassic lagoon islands (Solnhofen, Germany). |
| `spinosaurus` | A Spinosaurus, a mid-Cretaceous predator about 14 m long: tall sail on its back, long narrow crocodile-like snout with conical teeth, paddle-like tail, hunting fish in a river. Habitat: vast Cretaceous river system in North Africa. |
| `ankylosaurus` | An Ankylosaurus, a Late Cretaceous armored dinosaur about 7 m long: low wide body covered in bony plates and spikes, armored head with horns at the back corners, heavy bony club at the end of the tail. Habitat: Late Cretaceous forest clearing. |
| `parasaurolophus` | A Parasaurolophus, a Late Cretaceous duck-billed dinosaur about 9.5 m long: long backward-curving hollow tube crest on its head, duck-like beak, walking on all fours or two legs, calling. Habitat: Late Cretaceous swampy forest. |
| `archelon` | An Archelon, a Late Cretaceous giant sea turtle about 4.6 m long: huge flippers, hooked beak, broad leathery shell rather than a hard one. Habitat: warm shallow Cretaceous sea with light rays. |
| `microraptor` | A Microraptor, an Early Cretaceous crow-sized feathered dinosaur: long flight feathers on both arms and legs (four wings), glossy iridescent black feathers, long tail with a feather fan, gliding between trees. Habitat: Early Cretaceous forest in China. |

## Rights and rules

- OpenAI's terms assign you ownership of the images you generate and allow commercial use, as long as you follow their usage policies. ([summary of the terms](https://conductatlas.com/platform/openai/openai-terms-of-use/user-content-ownership-and-output-rights/))
- Purely AI-generated images may not be protected by copyright, so others could reuse them, and another user could get a similar image. That's acceptable for a card game, but it's why keeping your prompts on file is worthwhile.
- Don't put living artists' names, other franchises (e.g. Jurassic Park), or logos in prompts.
- Don't use images from the DinosaurDatabase project unless they're licensed for commercial use.

## Story intro panels

**Status: all four done (Jo, 2026-10-08)** in `assets/story/`. The new-player intro (`ui/main/story_intro.gd`) shows them in order; if one is ever missing it falls back to a scene built from the battle backgrounds, an amber-glowing egg and two cards. To replace one, generate a **2:3 portrait (1024 x 1536)**, keep the **bottom third calm and dark** (the caption sits there), and save it as `assets/story/panel_N.webp`; the game picks it up automatically. Same painterly, cinematic style as the cards. No text, logos or UI in the image.

| File | Caption | Prompt idea |
|---|---|---|
| `panel_1.webp` | 66 million years ago, the dinosaurs vanished. Their fossils didn't. | A vast prehistoric landscape at the moment of the asteroid impact: a fiery streak in an orange sky over volcanoes and a lone silhouetted dinosaur, the lower third fading into dark cracked earth with a half-buried fossil skull. |
| `panel_2.webp` | You've found a way to wake them: fossil eggs sealed in amber, ready to hatch. | A modern fossil hunter's lantern-lit dig site at night; in the centre a large speckled dinosaur egg cradled in glowing golden amber, cracks of warm light on its shell, tools and brushes around it; dark rock in the lower third. |
| `panel_3.webp` | Other collectors are hunting too. Battle them, win their eggs, and fill your Dino Dex. | Two rival dinosaurs facing off across a rocky arena under a stormy sky, a Tyrannosaurus and a Mosasaurus rising from crashing surf, dramatic rim light, dust and spray; dark foreground in the lower third. |
| `panel_4.webp` | Every hunter needs a partner. Choose yours. | Three small young dinosaurs side by side on a sunlit ridge at dawn, a Dilophosaurus, an Archaeopteryx perched on a rock and a Tanystropheus at the water's edge, looking toward the viewer; soft clouds below the ridge in the lower third. |

## The Professaur portrait (needed)

The Professaur (a human paleontologist; the name is a pun on professor + saur) guides new players through the tabs (`ui/main/professor_tour.gd`). Until a portrait exists he's a simple drawn placeholder (pith helmet, round glasses, white mustache). Generate a **square (1024 x 1024)** head-and-shoulders portrait, face centred, plain softly lit background (it's shown in a round frame), same painterly style as the cards, and save it as `assets/characters/professaur.webp`; the tour uses it automatically.

Prompt idea: *A friendly elderly paleontologist, head and shoulders, warm smile, round wire glasses, bushy white mustache, weathered khaki field shirt and a dusty pith helmet, a small fossil brush in his shirt pocket, soft golden lantern light, painterly cinematic style, plain dark warm background, centred, no text.*

## Eggs and hatching (done, Jo 2026-10-08)

In `assets/eggs/`: the egg in three stages (intact, first crack, about to burst), 8 shell pieces, the hatch backdrop (`hatch_background.webp`, dig site at night; the egg sits on the slab at 74% of its height) and the Eggs tab banner (`clutch_banner.webp`). `tools/prepare_eggs.py whole.png crack1.png crack2.png shards.png` crops the frames to one box and splits each crack frame into the shell and its light (`egg_crack_N_light.webp`), which the game tints with the rarity color, so the light in new crack art should be white or warm white. The animation itself (wobble, shakes, light flicker, shell pieces, sparks) is code in `ui/eggs/egg_view.gd` and `hatch_view.gd`.

