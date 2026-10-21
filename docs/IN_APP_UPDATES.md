# In-app updates (experiment, 2026-10-16)

Closed testers weren't getting new versions on their own (Play's auto-update is slow and only runs on Play's schedule), so Jo is trying **Google Play's in-app update prompt**. It's an experiment: it may be removed again (see the end of this page).

**Tested 2026-10-16:** Jo's phone had 0.6.1 (code 12) from Play; once 0.6.2 (code 13) was live on closed testing, the update strip appeared on launch.

## What players see
- Once per launch, when the main screen opens, the game asks the Play Store whether a newer version is out.
- If one is, a gold-edged strip appears under the top bar: **"A new version of Dino Duel is out!"** with **Later** and **Update**.
  - **Update** opens Play's small "Update?" sheet; after that it downloads in the background while they keep playing ("Downloading the update… 45%").
  - When it's downloaded: **"Update ready. Restart to play the new version."** with **Restart**, which installs it and reopens the game.
  - **Later** hides the strip until the next launch.
- If an update has been waiting for **7 days** (`UpdateCheck.IMMEDIATE_AFTER_DAYS`), Play's full-screen update prompt shows instead.
- It only works for copies installed from Google Play (closed testers included). USB debug builds don't have the plugin at all, and nothing shows.

## How it's built
- `android_plugin_src/inapp_update/`: the Android side, a small Kotlin plugin from [InappUpdate](https://github.com/icecube092/GodotInAppUpdate) by icecube092 (MIT, see its `LICENSE`), rebuilt against Godot 4.7.2. It wraps Google's `com.google.android.play:app-update:2.1.0`.
- `addons/inapp_update/`: the Godot plugin (enabled in Project Settings > Plugins): the built AARs in `bin/`, the export script that adds them and Google's library to **Gradle builds only** (the "Google Play" preset; the USB debug preset is untouched), and the `InappUpdate` GDScript wrapper (unchanged from upstream).
- `app/update_check.gd` (`UpdateCheck`): asks Play once per launch and tracks the state. `ui/main/update_banner.gd` (`UpdateBanner`): the strip. `ui/main/main.gd` adds the strip (3 lines, marked "Experiment").
- Permissions: none. Checked the manifests of the plugin and of Google's `app-update`, `app-update-ktx` and `core-common` (2026-10-16): no `uses-permission`. `core-common` adds one hidden, non-exported activity Play uses for its dialogs.
- Data: Google says the library sends Play the device metadata, the app's version and the installed modules, to see whether an update exists and how big it is (encrypted, not shared, deleted after a set period). Jo kept the prompt (2026-10-21): the privacy policy now has an "Update checks" section. The Data safety answer is still Jo's call (the two options are in docs/store/STORE_LISTING.md).

## Rebuilding the plugin (only if the Kotlin code or Godot version changes)
```bash
cd android_plugin_src/inapp_update
"../../android/build/gradlew" -p . assembleDebug assembleRelease --no-daemon
cp build/outputs/aar/InappUpdatePlugin-debug.aar ../../addons/inapp_update/bin/debug/
cp build/outputs/aar/InappUpdatePlugin-release.aar ../../addons/inapp_update/bin/release/
```
Uses Godot's own Gradle wrapper from the Android build template (Gradle 8.11.1); AGP 8.6.1, Kotlin 2.1.21 and `godotVersion` match Godot 4.7.2's template. It compiles against Android SDK 35 (the one installed). `local.properties` (the SDK path) and `build/` aren't committed.

## Testing it
In-app updates can only be tested through Play:
1. Upload a build **with** the plugin (e.g. version code 12) to the closed or internal testing track, and install or update to it **from Play** on the phone.
2. Upload a newer build (code 13).
3. Open the game. The strip should appear (Play can take a little while to notice the new version; reopening the app checks again).

Faster alternative without review delays: [internal app sharing](https://developer.android.com/guide/playcore/in-app-updates/test) (install the older build from its sharing link, then open the newer build's link but don't install from that page, and open the game).

## Removing it
1. Project Settings > Plugins: turn off **InappUpdate** (or delete `"res://addons/inapp_update/plugin.cfg"` from `[editor_plugins]` in `project.godot` with the editor closed).
2. Delete `addons/inapp_update/`, `android_plugin_src/`, `app/update_check.gd`, `ui/main/update_banner.gd` (and their `.uid` files).
3. Remove the 3 "Experiment" lines in `ui/main/main.gd`, and this page.
Or `git revert` the commit that added it (it touches nothing else).
