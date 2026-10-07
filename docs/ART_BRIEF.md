# Dino Duel: Art Brief for AI-Generated Card Paintings

How to make the 2D dinosaur paintings with ChatGPT image generation so every card looks like it belongs to one set.

## What each dino needs

| File | Shape | Used for |
|---|---|---|
| `<id>.png` | Portrait 2:3 (ChatGPT "1024×1536") | The card painting. Every card is full-art |
| `<id>_shiny.png` | Portrait 2:3 | Optional Shiny version: same animal and pose in a rare color morph. Falls back to the normal painting |

`<id>` is the dino's id: `coelophysis`, `stegosaurus`, `velociraptor`, `triceratops`, `t_rex`, `eudimorphodon`, `rhamphorhynchus`, `archaeopteryx`, `pteranodon`, `quetzalcoatlus`, `nothosaurus`, `ichthyosaurus`, `plesiosaurus`, `liopleurodon`, `mosasaurus`.

**Getting them into the game:** save ChatGPT's downloads into any folder with those file names, then run

```bash
python tools/prepare_art.py "path/to/your/downloads"
```

It resizes them for phones and saves WebP copies into `assets/dinos/`. The cards pick them up automatically; nothing else to wire up.

## Composition rules (match the concept sheet)

- Portrait 2:3, the dinosaur large and dynamic, filling the frame like the sample cards (mouth open, mid-stride, swimming toward the viewer).
- **Keep the head and the key action in the upper 55% of the image.** The bottom 40% sits under the name banner and stat boxes, and the two top corners under the tier crest and type medallion.
- Vivid, saturated, dramatic lighting with a bright habitat background, like the sample cards: Land in golden light, Sea in deep blue with light rays, Sky in bright blue sky.
- **Shiny:** identical composition; only the animal's coloring changes (e.g. pale silver-white with iridescent blue-green highlights).
- No text, frames, borders, logos or watermarks in the image. The card adds all of that.

## The master prompt

Jo's master prompt lives in [ART_PROMPT.md](ART_PROMPT.md). Paste it into ChatGPT and fill in the three placeholders from this table. Use the game's tier names for `[RARITY]` (the prompt also describes ULTRA RARE, which isn't a tier in the game; UR cards are LEGENDARY).

| id | `[DINOSAUR]` | `[TYPE]` | `[RARITY]` | Status |
|---|---|---|---|---|
| `t_rex` | Tyrannosaurus rex | LAND | LEGENDARY (UR) | Done |
| `quetzalcoatlus` | Quetzalcoatlus | SKY | EPIC (SSR) | |
| `triceratops` | Triceratops | LAND | SUPER RARE (SR) | |
| `pteranodon` | Pteranodon | SKY | SUPER RARE (SR) | |
| `mosasaurus` | Mosasaurus | SEA | SUPER RARE (SR) | |
| `velociraptor` | Velociraptor | LAND | RARE (R) | |
| `archaeopteryx` | Archaeopteryx | SKY | RARE (R) | |
| `plesiosaurus` | Plesiosaurus | SEA | RARE (R) | |
| `liopleurodon` | Liopleurodon | SEA | RARE (R) | |
| `coelophysis` | Coelophysis | LAND | COMMON (N) | |
| `stegosaurus` | Stegosaurus | LAND | COMMON (N) | |
| `eudimorphodon` | Eudimorphodon | SKY | COMMON (N) | |
| `rhamphorhynchus` | Rhamphorhynchus | SKY | COMMON (N) | |
| `nothosaurus` | Nothosaurus | SEA | COMMON (N) | |
| `ichthyosaurus` | Ichthyosaurus | SEA | COMMON (N) | |

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

## Rights and rules

- OpenAI's terms assign you ownership of the images you generate and allow commercial use, as long as you follow their usage policies. ([summary of the terms](https://conductatlas.com/platform/openai/openai-terms-of-use/user-content-ownership-and-output-rights/))
- Purely AI-generated images may not be protected by copyright, so others could reuse them, and another user could get a similar image. That's acceptable for a card game, but it's why keeping your prompts on file is worthwhile.
- Don't put living artists' names, other franchises (e.g. Jurassic Park), or logos in prompts.
- Don't use images from the DinosaurDatabase project unless they're licensed for commercial use.
