# Release Checklist

Go through this before building a production release (signed `.aab` for Google Play).

## Remove development tools
- [ ] **Delete the DEV "unlock all dinos" button** in `ui/tabs/dex_tab.gd`, plus `PlayerProfile.unlock_all()` in `core/collection/player_profile.gd` and its test `test_unlock_all_keeps_shinies` in `tests/test_collection.gd`. It only shows in debug builds, but it shouldn't ship at all.
  Jo's call (2026-10-08): keep it through closed testing (Play builds are release builds, so testers never see it), delete it before the production release.

## Signing
- [x] Create the release keystore and **back it up with its password** (done: Jo confirmed the backup on 2026-10-09) somewhere safe (password manager plus an offline copy). Losing it means you can't update the app on Google Play. Never commit it (`.gitignore` already blocks `*.keystore` and `*.jks`).

## Google Play listing (decided)
- Package name: `com.dinoduelstudios.dinoduel` (can't change once uploaded).
- Target audience: **13+ only** (Jo, 2026-10-08), so Google's Families policy doesn't apply. Including under-13s later would bring those extra rules, including for in-app purchases.
