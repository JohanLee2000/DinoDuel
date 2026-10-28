class_name WhatsNew
extends RefCounted
## What's new (Jo, 2026-10-28): after an update, the main screen shows what changed once
## (WhatsNewView), and Settings shows it any time. ADD AN ENTRY HERE FOR EVERY RELEASE, newest first,
## with the same version as the export presets (version/name).

const RELEASES: Array[Dictionary] = [
	{"version": "1.0.3", "items": [
		"What's new: this popup, after every update (and any time in Settings).",
		"Rate Dino Duel from Settings.",
		"Fixed: the battle music now plays after a Rematch.",
	]},
	{"version": "1.0.2", "items": [
		"Duel your friends: Share gives a code for your party, and Duel a friend battles theirs.",
		"A friends list keeps your record against each friend.",
		"A roomier Party tab, with Share and Duel up top.",
		"How to play: card tiers explained, and a crafting tip.",
	]},
]
## At most this many releases at once (someone who skipped several updates sees the latest ones).
const MAX_SHOWN := 3


static func latest() -> String:
	return RELEASES[0]["version"]


## The releases newer than `seen` (the version whose notes the player last saw). A save from before
## What's new existed ("") gets every release listed.
static func unseen(seen: String) -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for release in RELEASES:
		if release["version"] == seen or shown.size() >= MAX_SHOWN:
			break
		shown.append(release)
	return shown
