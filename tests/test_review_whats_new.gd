extends "res://tests/test_case.gd"
## When the game asks for Google Play's rating card (ReviewPrompt), and which What's new to show.


func test_review_waits_for_wins_and_spaces_out_asks() -> void:
	var p := PlayerProfile.new_game(50)
	p.wins = ReviewPrompt.MIN_WINS - 1
	assert_false(ReviewPrompt.should_ask(p, 100), "not before a few wins")
	p.wins = ReviewPrompt.MIN_WINS
	assert_true(ReviewPrompt.should_ask(p, 100))
	p.review_asks = 1
	p.review_asked_day = 100
	assert_false(ReviewPrompt.should_ask(p, 100 + ReviewPrompt.DAYS_BETWEEN - 1), "spaced out")
	assert_true(ReviewPrompt.should_ask(p, 100 + ReviewPrompt.DAYS_BETWEEN))
	p.review_asks = ReviewPrompt.MAX_ASKS
	assert_false(ReviewPrompt.should_ask(p, 1000), "and only a few times")
	assert_false(ReviewPrompt.available(), "no plugin outside Play builds")
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), DinoCatalog.load_default())
	assert_eq([loaded.review_asks, loaded.review_asked_day], [p.review_asks, p.review_asked_day], "saved")


func test_whats_new_shows_the_releases_since_last_seen() -> void:
	assert_eq(WhatsNew.unseen(WhatsNew.latest()).size(), 0, "nothing after seeing the latest")
	assert_eq(WhatsNew.unseen("")[0]["version"], WhatsNew.latest(), "older saves see the newest first")
	assert_true(WhatsNew.unseen("").size() <= WhatsNew.MAX_SHOWN)
	if WhatsNew.RELEASES.size() > 1:
		assert_eq(WhatsNew.unseen(WhatsNew.RELEASES[1]["version"]).size(), 1, "one update behind: one release")
	var versions := {}
	for release in WhatsNew.RELEASES:
		assert_false(versions.has(release["version"]), "each version once")
		versions[release["version"]] = true
		assert_false((release["items"] as Array).is_empty())


func test_the_exported_version_has_whats_new_notes() -> void:
	# Notes can be written ahead of the version bump, but a build needs notes for its own version.
	var listed := WhatsNew.RELEASES.map(func(release: Dictionary) -> String: return release["version"])
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	for section in presets.get_sections():
		if section.ends_with(".options"):
			var version: String = presets.get_value(section, "version/name")
			assert_true(version in listed, "add a WhatsNew entry for version %s (app/whats_new.gd)" % version)
