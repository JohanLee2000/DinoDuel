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
| | | |
