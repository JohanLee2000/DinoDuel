# Closed test kit

Everything needed to publish a closed-test release and invite testers. Goal: 12+ testers opted in for 14 days in a row (recruit 15-20), then apply for production.

## Release 0.1.0 (version code 1)

**App bundle:** `build/play/dino_duel.aab` (signed with the upload key; build with `"$GODOT" --headless --path . --export-release "Google Play" build/play/dino_duel.aab`).

**Release name:** `0.1.0`

**Release notes** (paste as is; Play reads the language tag, 500 characters max):

```
<en-US>
First test build of Dino Duel!
- Hatch fossil eggs and collect 30 prehistoric creatures
- Battle 5 rivals, from Rookie Rae to Rival Rory
- Plays fully offline and saves on your phone
Found a bug or have an idea? Email dinoduelstudios@gmail.com
</en-US>
```

**Play App Signing:** accept the default (Google-generated app signing key). Our keystore is only the upload key.

**Track settings (Testing > Closed testing > Manage track):**
- Countries/regions: every country a tester lives in.
- Testers: the Google Group. Feedback URL or email: `dinoduelstudios@gmail.com`.

**Every later upload:** bump `version/code` (and usually `version/name`) in both presets in `export_presets.cfg` with the Godot editor closed, rebuild, and create a new release on the same track.

## Release 0.2.0 (version code 2)

**Release notes:**

```
<en-US>
Dino Duel 0.2.0
- New: your first battle comes with a coach that teaches Bite, Charge, Brace and Swap
- New: How to play pages (tap ? in any battle, or the gear in the top bar)
- New: music and sound effects, with volume sliders in Settings
Thanks for testing! Feedback: dinoduelstudios@gmail.com
</en-US>
```

## Release 0.3.1 (version code 4)

Same game as 0.3.0, plus 32-bit ARM (armeabi-v7a) in the Play build so phones running 32-bit Android (e.g. Redmi A3, Android Go) can install it.

```
<en-US>
Dino Duel 0.3.1
- Now installs on more phones (32-bit Android, like the Redmi A3)
- New players choose a starter partner: Dilophosaurus, Archaeopteryx or Tanystropheus, plus 2 egg clutches
- Battle backgrounds for Land, Sea and Sky
- Bigger text, a clear panel to pick your next dino after a knockout, and a Leave button
Thanks for testing! Feedback: dinoduelstudios@gmail.com
</en-US>
```

## Release 0.3.0 (version code 3)

**Release notes:**

```
<en-US>
Dino Duel 0.3.0
- New players choose a starter partner: Dilophosaurus, Archaeopteryx or Tanystropheus, plus 2 egg clutches
- Battle backgrounds for Land, Sea and Sky
- Bigger text, and a clear panel to pick your next dino after a knockout
- Leave button to quit a battle (counts as a loss)
Thanks for testing! Feedback: dinoduelstudios@gmail.com
</en-US>
```

## Links

- Opt-in (testers tap "Become a tester"): https://play.google.com/apps/testing/com.dinoduelstudios.dinoduel
- Store page (install after opting in): https://play.google.com/store/apps/details?id=com.dinoduelstudios.dinoduel
- Tester group: https://groups.google.com/g/dino-duel-testers (dino-duel-testers@googlegroups.com; share this form, without /u/N/)

Both Play links only work once the closed-test release is approved, and only for accounts in the tester group.

## Invitation message

Send after the release is approved (the opt-in link only works then). Fill in the two links: the group's join link, and the opt-in link from the Testers tab ("Copy link").

```
Hi! I made a mobile game called Dino Duel: you hatch fossil eggs, collect dinosaur cards, and battle rivals in quick mind-game duels. It's in a closed test on Google Play and I need testers for 14 days. Could you help?

It needs an Android phone. Use the same Google account that's signed in to the Play Store on your phone.

1. Join the tester group: [GROUP LINK]
2. Open this link and tap "Become a tester": [OPT-IN LINK]
3. On that page, tap the Google Play link and install Dino Duel.

Please stay in the test for at least 14 days (Google requires it before the game can launch), and play whenever you like. Bugs, confusing bits, or ideas: reply here or email dinoduelstudios@gmail.com.

Thank you!
```

## What to ask testers

- Did anything crash, freeze or look broken? Which phone?
- Was it clear how battles work (Bite, Charge, Brace, Swap)? Where did you get stuck?
- Which rivals felt too easy or too hard?
- Was hatching eggs exciting? Did you want more eggs or Amber?
- Anything you wished the game had?

## Notes for the production application

Google asks how testers were recruited, what feedback came in, and what changed because of it. Keep a running log here.

| Date | Feedback | What changed (version) |
|---|---|---|
| 2026-10-08 | (before tester feedback) New players had no explanation of the moves; the game was silent | 0.2.0: coached first battle, How to play pages, music, sound effects, volume settings |
| 2026-10-08 | Jo playtest: text too small, unclear what to do after a knockout, no way to quit a battle | 0.3.0: bigger text, knocked-out panel, Leave button; also starter partners and battle backgrounds |
| 2026-10-08 | Tester with a Redmi A3: "device isn't compatible" (32-bit Android) | 0.3.1: Play build includes armeabi-v7a |
| | | |
