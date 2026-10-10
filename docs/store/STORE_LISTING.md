# Google Play store listing

Draft text and answers for Play Console. Jo edits the wording; character limits are Google's.

## Main store listing

**App name** (30 max): Dino Duel

**Short description** (80 max):

> Hatch fossil eggs, collect 65+ prehistoric beasts and outsmart rival collectors.

**Full description** (4000 max):

> Travel back through time as a fossil hunter, hatch prehistoric creatures from fossil eggs, and battle rival collectors in quick, tactical card duels.
>
> COLLECT 65+ PREHISTORIC CREATURES
> Dinosaurs, pterosaurs and sea reptiles from the Triassic, Jurassic and Cretaceous, each painted as a full-art card with its real size, era and a fossil fact. Five tiers from Common to Legendary, plus rare Shiny versions with a holographic look.
>
> HATCH FOSSIL EGGS
> Win battles to earn clutches of three eggs. Tap to crack each one, and its glow tells you how rare it is before it hatches. Duplicates melt into Amber, which you can spend to craft the exact dino you're missing.
>
> MIND GAMES, NOT LUCK
> Bring six dinos, see your rival's six, then secretly pick three. Each turn both sides choose at the same time: Bite beats Charge, Charge smashes through Brace, Brace blocks Bite, and Swap goes first. Read your rival, bait their move and strike.
>
> LAND, SKY AND SEA
> Land beats Sky, Sky beats Sea, Sea beats Land. Build a balanced party, match eras for a bonus, and swap at the right moment to turn a fight around.
>
> RIVALS WITH PERSONALITIES
> From Rookie Rae, who loves to Bite, to Rival Rory, who learns your habits. Every rival plays differently, and every win brings more eggs.
>
> DAILY GOALS
> Three new quests every day, rewards as your collection grows, and 18 achievements to chase.
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
| Phone screenshots | `screenshots/01..08_*.png` (1142 x 2280; retaken 2026-10-09 for 0.5.0) | 2-8 images, 320-3840 px, at most 2:1 |

Screenshots come from the phone with the debug-only `--store-shots` showcase save (see `app/session.gd`), so the DEV button never appears. To retake, put the flags in `user://dev_args.txt` on the phone (adb push + `run-as ... cp`), relaunch, and `adb exec-out screencap -p`. Delete `dev_args.txt` afterwards or every launch uses it.

## App content answers (Policy › App content)

| Section | Answer |
|---|---|
| Privacy policy | URL above |
| App access | All functionality is available without special access (no login) |
| Ads | No, the app does not contain ads |
| Content rating | IARC questionnaire: category Game. Cartoon-style animal combat with no blood or gore, no user interaction or chat, no purchases yet. Expect the lowest or second-lowest rating band. |
| Target audience | **13 and over only** (decided 2026-10-08). Not designed for children. |
| Data safety | Collects no data, shares no data. The app has no internet permission; progress is stored only on the device. |
| Government apps / Financial features / Health / News | No |

When in-app purchases are added (content and cosmetics only), update the Data safety form (purchase history handled by Google Play Billing), the content rating questionnaire ("in-app purchases" yes), and the privacy policy.
