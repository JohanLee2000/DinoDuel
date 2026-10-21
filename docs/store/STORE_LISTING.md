# Google Play store listing

Draft text and answers for Play Console. Jo edits the wording; character limits are Google's.

## Main store listing

**App name** (30 max): Dino Duel

**Short description** (80 max):

> Hatch fossil eggs, collect 65+ prehistoric beasts and outsmart rival collectors.

**Full description** (4000 max):

> Travel back through time as a fossil hunter, hatch prehistoric creatures from fossil eggs, and battle your way from the Triassic to the meteor in quick, tactical card duels.
>
> COLLECT 65+ PREHISTORIC CREATURES
> Dinosaurs, pterosaurs and sea reptiles from the Triassic, Jurassic and Cretaceous, each painted as a full-art card with its real size, era and a fossil fact. Five tiers from Common to Legendary, plus rare Shiny versions with a holographic look.
>
> A JOURNEY THROUGH TIME
> Follow the trail across the Triassic, Jurassic and Cretaceous. Fifteen rival collectors stand in your way, each with a habit to read: one always Braces after a hit, another copies your last move. At the end of every era your rival Rory waits with an Alpha creature. Win with your dinos still standing to earn stars, fill star chests, and survive Extinction Day before the meteor falls.
>
> HATCH FOSSIL EGGS
> Every win earns a clutch of three eggs. Tap to crack each one, and its glow tells you how rare it is before it hatches. Save up for a Rare clutch with better odds. Duplicates melt into Amber, which you can spend to craft the exact dino you're missing.
>
> MIND GAMES, NOT LUCK
> Bring six dinos, see your rival's six, then secretly pick three. Each turn both sides choose at the same time: Bite beats Charge, Charge smashes through Brace, Brace blocks Bite, and Swap goes first. Read your rival, bait their move and strike.
>
> LAND, SKY AND SEA
> Land beats Sky, Sky beats Sea, Sea beats Land. Build a balanced party, match eras for a bonus, and swap at the right moment to turn a fight around.
>
> DAILY GOALS
> Check in every day for a free clutch and a bonus that builds all week. Three new quests a day, collection sets to complete for badges, and 21 achievements to chase.
>
> PLAY ANYWHERE
> Fully offline. No account, no ads, and your collection is saved on your device. Eggs are earned by playing, never sold for real money.

**Category:** Game › Card. Tags to consider: Card battler, Collectible card game, Dinosaurs.

**Contact details:** email `dinoduelstudios@gmail.com` (public on the store page). Website is optional; the GitHub Pages site works if you want one.

**Privacy policy URL:** see `docs/privacy-policy.html`. Once GitHub Pages is on (Settings › Pages › Deploy from a branch › `main` / `/docs`), it's at
`https://johanlee2000.github.io/DinoDuel/privacy-policy.html`.

## Graphics (in `docs/store/`)

| Asset | File | Play requirement |
|---|---|---|
| App icon | `assets/branding/app_icon_512.png` | 512 x 512 PNG |
| Feature graphic | `feature_graphic.png` (rendered by `tools/feature_graphic.tscn`) | 1024 x 500 PNG/JPEG, no alpha |
| Phone screenshots | `screenshots/01..08_*.png` (1142 x 2280; 2026-10-15 for 0.6.0: battle, Journey map, Legendary hatch, Shiny T. rex, Rory, Dex, coached battle, Goals). More in `screenshots/extra/` for the website | 2-8 images, 320-3840 px, at most 2:1 |

Screenshots come from the phone with the debug-only `--store-shots` showcase save (see `app/session.gd`), so the DEV button never appears. To retake, put the flags in `user://dev_args.txt` on the phone (adb push + `run-as ... cp`), relaunch, and `adb exec-out screencap -p`. Delete `dev_args.txt` afterwards or every launch uses it.

## App content answers (Policy › App content)

| Section | Answer |
|---|---|
| Privacy policy | URL above |
| App access | All functionality is available without special access (no login) |
| Ads | No, the app does not contain ads |
| Content rating | IARC questionnaire: category Game. Cartoon-style animal combat with no blood or gore, no user interaction or chat, no purchases yet. Expect the lowest or second-lowest rating band. |
| Target audience | **13 and over only** (decided 2026-10-08). Not designed for children. |
| Data safety | The app itself collects and shares nothing: it has no internet permission and progress stays on the device. **Since 0.6.1 (in-app update prompt):** Google's Play In-App Updates library has the Play Store app send Google Play the device metadata, app version and installed modules to check for updates (encrypted, not shared, deleted after a set period). Google says it's the developer's call how to answer the form. Two ways: (a) keep "no data collected", treating it as the Play Store's own processing under the Play Terms; or (b) the cautious answer: declare **App info and performance** (other), collected, not shared, purpose **App functionality**, encrypted in transit, not optional. The privacy policy explains the update check either way (updated 2026-10-21). |
| Government apps / Financial features / Health / News | No |

When in-app purchases are added (content and cosmetics only), update the Data safety form (purchase history handled by Google Play Billing), the content rating questionnaire ("in-app purchases" yes), and the privacy policy.
