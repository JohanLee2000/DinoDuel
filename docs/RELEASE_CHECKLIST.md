# Release Checklist

Go through this before building a production release (signed `.aab` for Google Play).

## Remove development tools
- [x] (Deleted 2026-10-25.) **Delete the DEV "unlock all stages" button** in `ui/tabs/battle_tab.gd` and `Journey.dev_unlock_all` in `core/collection/journey.gd` (debug builds only, doesn't touch the save, but it shouldn't ship).
- [x] (Deleted 2026-10-25.) **Delete the DEV "unlock all dinos" button** in `ui/tabs/dex_tab.gd`, plus `PlayerProfile.unlock_all()` in `core/collection/player_profile.gd` and its test `test_unlock_all_keeps_shinies` in `tests/test_collection.gd`. It only shows in debug builds, but it shouldn't ship at all.
  Jo's call (2026-10-08): keep it through closed testing (Play builds are release builds, so testers never see it), delete it before the production release.

## In-app update prompt (kept, 2026-10-21)
- [x] (Done 2026-10-25, the cautious answer.) **Answer the Data safety form for the update check** (options in `docs/store/STORE_LISTING.md`). The privacy policy already covers it ("Update checks").

## Rating card and What's new (1.0.3, 2026-10-28)
- [ ] **Data safety for the rating card**: Jo's call between the two answers in `docs/store/STORE_LISTING.md`. The privacy policy already covers it ("Rating the game").
- Every release: add its notes to `WhatsNew.RELEASES` (`app/whats_new.gd`) before bumping `version/name`; a test fails if the exported version has no notes.

## Signing
- [x] Create the release keystore and **back it up with its password** (done: Jo confirmed the backup on 2026-10-09) somewhere safe (password manager plus an offline copy). Losing it means you can't update the app on Google Play. Never commit it (`.gitignore` already blocks `*.keystore` and `*.jks`).

## Google Play listing (decided)
- Package name: `com.dinoduelstudios.dinoduel` (can't change once uploaded).
- Target audience: **13+ only** (Jo, 2026-10-08), so Google's Families policy doesn't apply. Including under-13s later would bring those extra rules, including for in-app purchases.
