# Rating card (in-app review, 2026-10-28)

Jo wanted a rate-the-game prompt. Google Play's **in-app review** shows its own rating card over the game, and the player can rate and review without leaving it.

## When it's asked for
- After a **Journey win** (not a friend duel, not autoplay), 1.5 s after the results appear, once the player has **5 or more wins**, at most **3 times**, at least **30 days** apart (`app/review_prompt.gd`; the counts are saved as `review_asks` and `review_asked_day`).
- Play decides whether the card actually shows (it limits how often), and never tells the game whether the player rated. The game just carries on.
- Google's rules, followed: no "Do you like the game?" question first, nothing drawn over the card, and no button that opens it. **Settings > Rate Dino Duel** opens the game's Play Store page instead (`market://details?id=com.dinoduelstudios.dinoduel`).

## How it's built
- `android_plugin_src/inapp_review/`: a small Kotlin Godot plugin around `com.google.android.play:review:2.0.2` (`requestReview()`, signals `review_finished` and `review_failed`). Built like the in-app update plugin, against Godot 4.7.2's Android template.
- `addons/inapp_review/`: the AARs and the export script that adds them to **Gradle builds only** (the "Google Play" preset). USB debug builds and the PC have no plugin, so nothing is asked there.
- Permissions: none (checked the review library's manifest, 2026-10-28).
- Data: Google says the library handles the user-entered rating and review, published on the Play Store (privately for test tracks). Privacy policy: "Rating the game". Data safety: see `docs/store/STORE_LISTING.md`.

## Rebuilding the plugin
```bash
cd android_plugin_src/inapp_review
"../../android/build/gradlew" -p . assembleDebug assembleRelease --no-daemon
cp build/outputs/aar/InappReviewPlugin-debug.aar ../../addons/inapp_review/bin/debug/
cp build/outputs/aar/InappReviewPlugin-release.aar ../../addons/inapp_review/bin/release/
```
(`local.properties` with `sdk.dir=` your Android SDK path, not committed.)

## Testing it
Only builds installed from Google Play can show the card: use the internal testing track. To trigger it sooner while testing, a save needs 5 wins; the card may still not appear if Play's limit is reached (on test tracks, reviews go privately to the developer).

## Removing it
Turn off **InappReview** in Project Settings > Plugins (or remove it from `[editor_plugins]` in `project.godot` with the editor closed), delete `addons/inapp_review/` and `android_plugin_src/inapp_review/`, and remove the `ReviewPrompt.ask` call in `ui/battle/battle_screen.gd`. `ReviewPrompt.available()` is false without the plugin, so nothing else breaks.
