class_name ReviewPrompt
extends RefCounted
## Google Play's rating card (in-app review, Jo 2026-10-28), through addons/inapp_review. After a
## Journey win, once the player has won a few, the game asks Play to show it. Play decides whether
## it actually appears (it limits how often) and never says whether the player rated. Following
## Google's rules: no "Do you like the game?" question first, and no button that opens the card
## (Settings > Rate Dino Duel opens the store page instead). See docs/IN_APP_REVIEW.md.

const PACKAGE := "com.dinoduelstudios.dinoduel"
const SINGLETON := "InappReviewPlugin"
## Journey wins before the first ask.
const MIN_WINS := 5
const DAYS_BETWEEN := 30
const MAX_ASKS := 3


## Whether it's time to ask, from the save alone (wins, how often and when it last asked).
static func should_ask(profile: PlayerProfile, today: int) -> bool:
	return profile.wins >= MIN_WINS and profile.review_asks < MAX_ASKS \
			and (profile.review_asked_day < 0 or today - profile.review_asked_day >= DAYS_BETWEEN)


## Only builds installed through Google Play have the plugin (not USB debug builds or the PC).
static func available() -> bool:
	return Engine.has_singleton(SINGLETON)


## Asks Play for its rating card if it's time. Returns whether it asked (then save the profile).
static func ask(profile: PlayerProfile, today: int) -> bool:
	if not available() or not should_ask(profile, today):
		return false
	profile.review_asks += 1
	profile.review_asked_day = today
	Engine.get_singleton(SINGLETON).requestReview()
	return true


## Settings > Rate Dino Duel: the game's Play Store page.
static func open_store_page() -> void:
	if OS.get_name() == "Android" and OS.shell_open("market://details?id=" + PACKAGE) == OK:
		return
	OS.shell_open("https://play.google.com/store/apps/details?id=" + PACKAGE)
